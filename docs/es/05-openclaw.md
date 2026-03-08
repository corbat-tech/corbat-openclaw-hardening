# 5. Instalar OpenClaw

> **TL;DR**: Instalar Node.js 22+, configurar OpenClaw con el Gateway daemon, aplicar permisos mínimos y ejecutar como servicio systemd con aislamiento hardened.

> **Tiempo estimado**: 25-35 minutos

> **Nivel requerido**: Intermedio

!!! info "Requisitos de OpenClaw"
    OpenClaw requiere **Node.js 22 o superior**. Esta guía está actualizada para **OpenClaw v2026.3.x**.

    Consulta la [documentación oficial](https://docs.openclaw.ai/start/getting-started) para las instrucciones más actualizadas.

!!! danger "Alerta de seguridad: Incidente ClawHub (febrero 2026)"
    En febrero 2026 se descubrió el **mayor ataque de cadena de suministro contra infraestructura de agentes AI** hasta la fecha:

    - **1,184+ skills maliciosos** (~20% del registro ClawHub) distribuían malware (AMOS stealer) y reverse shells
    - Skills disfrazados de herramientas legítimas de crypto/trading
    - Otra vulnerabilidad ("ClawJacked") permitía a sitios web maliciosos secuestrar agentes locales via WebSocket

    **Medidas obligatorias:**

    - **Nunca instales skills sin auditar el código fuente primero**
    - Ejecuta skills nuevos **siempre en sandbox** con permisos mínimos
    - Usa `openclaw security audit` después de cada instalación de skills
    - Verifica el autor y el historial de contribuciones antes de confiar

    Fuentes: [The Hacker News](https://thehackernews.com/2026/02/researchers-find-341-malicious-clawhub.html), [Snyk - ToxicSkills](https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/)

## Prerrequisitos

- [ ] Sección 4 (Tailscale) completada
- [ ] Acceso SSH funcionando solo por Tailscale
- [ ] Usuario `openclaw` con sudo

## Setup rápido (script automatizado)

!!! tip "Salta los pasos manuales"
    Si completaste las secciones 3-4 (o usaste `harden.sh`), puedes automatizar la sección 5 con:

    ```bash
    curl -fsSL -o /tmp/install-openclaw.sh \
      https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/install-openclaw.sh
    less /tmp/install-openclaw.sh
    bash /tmp/install-openclaw.sh
    ```

    El script instala Node.js 22, OpenClaw, escribe un `openclaw.json` hardened, crea el servicio systemd y configura permisos. Te pedirá elegir un proveedor de modelo.

    **Después de que el script termine:**

    1. Configura tu API key: `openclaw models auth add`
    2. Inicia el servicio: `sudo systemctl start openclaw`
    3. Accede desde tu Mac: `ssh -L 18789:127.0.0.1:18789 openclaw@<TAILSCALE_IP>`
    4. Abre `http://localhost:18789` en tu navegador
    5. Ejecuta auditoría de seguridad: `openclaw security audit`

    O usa el **script de setup completo** para automatizar las secciones 3+4+5 de una vez en un VPS nuevo:
    ```bash
    curl -fsSL -o /tmp/setup.sh \
      https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/setup.sh
    less /tmp/setup.sh
    bash /tmp/setup.sh
    ```

    Si prefieres entender cada paso, continúa con las instrucciones manuales de abajo.

---

## Objetivos

Al terminar esta sección tendrás:

- Node.js 22+ instalado desde fuente verificada
- OpenClaw instalado con Gateway daemon
- Configuración de seguridad según [documentación oficial de seguridad](https://docs.openclaw.ai/gateway/security)
- Servicio systemd con hardening completo
- Verificación de seguridad del despliegue

---

## Conectar al VPS

```bash
ssh openclaw@<TU_TAILSCALE_IP>
```

---

## Instalar dependencias base

```bash
# Git y herramientas básicas
sudo apt install -y git curl wget gnupg

# Python (ya viene en Ubuntu, pero añade pip y venv)
sudo apt install -y python3-pip python3-venv
```

---

## Instalar Node.js (con verificación)

!!! warning "No uses `curl | bash` sin verificar"
    Siempre verifica los scripts antes de ejecutarlos.

### Opción A: Usando nvm (RECOMENDADO)

nvm (Node Version Manager) permite instalar y gestionar versiones de Node.js.

```bash
# 1. Descargar script de nvm
curl -o /tmp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh

# 2. Verificar el script (buscar comandos sospechosos)
echo "Primeras 50 líneas del script:"
head -50 /tmp/nvm-install.sh

# 3. Verificar checksum (opcional pero recomendado)
# Consulta el checksum oficial en: https://github.com/nvm-sh/nvm/releases
sha256sum /tmp/nvm-install.sh
```

!!! tip "Verificar checksum en GitHub"
    Para máxima seguridad, compara el checksum SHA256 con el publicado en
    [github.com/nvm-sh/nvm/releases](https://github.com/nvm-sh/nvm/releases)
    para la versión que estás instalando.

```bash
# 4. Si parece correcto, ejecutar
bash /tmp/nvm-install.sh

# 5. Limpiar
rm /tmp/nvm-install.sh

# 6. Recargar shell
source ~/.bashrc
```

```bash
# 7. Instalar Node.js 22 (requerido por OpenClaw)
nvm install 22
nvm use 22
nvm alias default 22

# 8. Verificar instalación
node --version
npm --version
```

**Salida esperada:**
```
v22.x.x
10.x.x
```

!!! warning "Node.js 22 es obligatorio"
    OpenClaw requiere Node.js 22 o superior. Versiones anteriores (18, 20) **no funcionarán**.

### Opción B: Repositorio NodeSource

```bash
# 1. Descargar script de configuración
curl -fsSL https://deb.nodesource.com/setup_lts.x -o /tmp/nodesource-setup.sh

# 2. Verificar que solo añade repos de nodesource.com
grep -E "^(curl|wget)" /tmp/nodesource-setup.sh
# Debe mostrar solo URLs de nodesource.com o nodejs.org

# 3. Revisar el script completo
less /tmp/nodesource-setup.sh

# 4. Si parece seguro, ejecutar
sudo -E bash /tmp/nodesource-setup.sh
sudo apt install -y nodejs

# 5. Limpiar
rm /tmp/nodesource-setup.sh

# 6. Verificar
node --version
npm --version
```

---

## Crear estructura de directorios

```bash
mkdir -p ~/openclaw/{workspace,config,logs,scripts}
mkdir -p ~/.openclaw/workspace
cd ~/openclaw
```

!!! warning "Diferencia entre ~/openclaw y ~/.openclaw"
    Esta guía usa **DOS directorios diferentes**. Es importante entender la diferencia:

    | Directorio | Path completo | Propósito |
    |------------|---------------|-----------|
    | `~/.openclaw/` | `/home/openclaw/.openclaw/` | **Configuración oficial de OpenClaw** (creado automáticamente por la CLI) |
    | `~/openclaw/` | `/home/openclaw/openclaw/` | **Directorio de trabajo de esta guía** (scripts, logs, workspace seguro) |

!!! info "Estructura detallada de directorios"

    ```
    ~/.openclaw/                 # CONFIGURACIÓN OFICIAL (creado por OpenClaw)
    ├── openclaw.json            # Configuración principal del Gateway
    ├── .env                     # Variables de entorno (API keys) - chmod 600
    ├── workspace/               # Workspace por defecto de OpenClaw
    │   ├── AGENTS.md            # Prompts de agentes
    │   ├── SOUL.md              # Identidad del agente
    │   ├── TOOLS.md             # Configuración de herramientas
    │   └── skills/              # Skills del workspace
    └── credentials/             # Credenciales OAuth (si se usa)

    ~/.agents/
    └── skills/                  # Skills instalados globalmente (npx playbooks add)
        └── imap-smtp-email/     # Ejemplo: skill de email
            ├── SKILL.md
            └── .env             # Credenciales del skill (chmod 600)

    ~/openclaw/                  # DIRECTORIO DE ESTA GUÍA (creado manualmente)
    ├── workspace/               # Workspace RESTRINGIDO (usado en openclaw.json)
    ├── logs/                    # Logs de la aplicación
    └── scripts/                 # Scripts de mantenimiento y verificación
    ```

!!! tip "¿Por qué dos directorios?"
    - `~/.openclaw/` es donde OpenClaw busca su configuración por defecto
    - `~/openclaw/workspace/` es un workspace más restringido que configuramos en `openclaw.json`
    - Esta separación permite que OpenClaw funcione normalmente mientras mantenemos control sobre dónde puede escribir el agente

### Verificar estructura

```bash
tree ~/openclaw 2>/dev/null || ls -la ~/openclaw
```

**Salida esperada:**
```
/home/openclaw/openclaw
├── config/
├── logs/
└── workspace/
```

---

## Instalar OpenClaw

!!! info "Documentación oficial"
    Consulta [docs.openclaw.ai](https://docs.openclaw.ai/start/getting-started) para instrucciones actualizadas.

### Método 1: Instalación global con npm (RECOMENDADO para VPS)

```bash
# Instalar OpenClaw globalmente
npm install -g openclaw@latest

# Verificar instalación
openclaw --version
```

**Salida esperada:**
```
openclaw v2026.3.x
```

### Método 2: Instalación con script oficial

```bash
# Descargar script de instalación
curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh

# Verificar contenido del script antes de ejecutar
less /tmp/openclaw-install.sh

# Si parece correcto, ejecutar
bash /tmp/openclaw-install.sh

# Limpiar
rm /tmp/openclaw-install.sh
```

### Instalar Docker (opcional — solo para sandbox mode "all")

Docker solo es necesario si quieres sandbox mode `all` (ejecución de herramientas en contenedores). Para VPS dedicado con hardening systemd (la configuración recomendada de esta guía), Docker **no es necesario** — sandbox mode `"off"` con aislamiento systemd proporciona seguridad equivalente.

```bash
# Solo instalar si quieres sandbox mode "all" (servidores multi-usuario)
sudo apt install -y docker.io
sudo usermod -aG docker openclaw

# Reconectar SSH para que el cambio de grupo tome efecto
exit
# Luego reconectar: ssh openclaw@<TAILSCALE_IP>

# Verificar que Docker funciona
docker ps
```

### Inicializar OpenClaw (onboarding)

```bash
# Ejecutar asistente de configuración
# IMPORTANTE: NO usar --install-daemon aún, lo configuraremos con systemd
openclaw onboard
```

El asistente te guiará para:

1. **Autenticación**: Elige "API key" (recomendado para servidores headless)
2. **Canales**: Configura los canales que necesites (Telegram, Discord, etc.)
3. **DM Policy**: Configura como "pairing" para seguridad

!!! warning "No instalar el daemon automático"
    El asistente puede ofrecer instalar un daemon (launchd/systemd). Rechaza esta opción porque configuraremos un servicio systemd con hardening completo más adelante.

### Verificar instalación

```bash
# Verificar estado
openclaw status

# Ejecutar diagnóstico completo
openclaw doctor
```

### Herramientas de seguridad integradas (v2026.3.x)

OpenClaw incluye herramientas de seguridad nativas que debes ejecutar después de la instalación:

```bash
# Auditoría de seguridad de configuración y entorno
openclaw security audit

# Auditoría con remediación automática
openclaw security audit --fix

# Verificar políticas de sandbox efectivas
openclaw sandbox explain

# Health check y auto-healing
openclaw doctor
```

!!! success "Ejecuta `openclaw security audit --fix` después de cada cambio de configuración"
    Esta herramienta verifica permisos, configuración del Gateway, sandbox mode, y vulnerabilidades conocidas.

### Canales de actualización

OpenClaw ofrece tres canales de actualización:

```bash
# Ver canal actual
openclaw update --channel

# Cambiar canal (recomendado: stable para producción)
openclaw update --channel stable

# Otros canales disponibles:
# openclaw update --channel beta    # Funcionalidades nuevas, posibles bugs
# openclaw update --channel dev     # Desarrollo, NO para producción
```

---

## Archivos de configuración

### Estructura de configuración de OpenClaw

OpenClaw usa `~/.openclaw/openclaw.json` como archivo de configuración principal:

```
~/.openclaw/
├── openclaw.json           # Configuración principal
├── exec-approvals.json     # Reglas de aprobación de ejecución (allowlist)
├── workspace/
│   ├── SOUL.md             # Identidad y límites del agente
│   ├── TOOLS.md            # Configuración de herramientas
│   └── skills/             # Skills del workspace
└── credentials/            # Credenciales (si se usa OAuth)

~/.agents/
└── skills/                 # Skills instalados globalmente (npx playbooks add)

~/openclaw/                 # Directorio de trabajo (esta guía)
├── config/                 # Configuraciones adicionales
├── workspace/              # Workspace restringido
├── logs/                   # Logs
└── scripts/                # Scripts de mantenimiento
```

### Configurar openclaw.json

```bash
nano ~/.openclaw/openclaw.json
```

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "kimi-coding/kimi-for-coding",
        "fallbacks": ["google/gemini-2.5-flash"]
      },
      "models": {
        "kimi-coding/kimi-for-coding": { "alias": "Kimi Coding" },
        "google/gemini-2.5-flash": { "alias": "Gemini 2.5 Flash" }
      },
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "off"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 1,
      "subagents": {
        "maxConcurrent": 3
      }
    }
  },
  "auth": {
    "profiles": {
      "kimi-coding:default": { "provider": "kimi-coding", "mode": "api_key" },
      "google:default": { "provider": "google", "mode": "api_key" }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "allowlist",
      "allowFrom": ["TU_TELEGRAM_USER_ID"],
      "streaming": "partial"
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "kimi-coding": {
        "api": "anthropic-messages",
        "apiKey": "${KIMI_API_KEY}",
        "baseUrl": "https://api.kimi.com/coding",
        "headers": { "User-Agent": "claude-code/0.1.0" },
        "models": [{
          "id": "kimi-for-coding",
          "name": "Kimi Coding",
          "reasoning": false,
          "input": ["text"],
          "contextWindow": 262144,
          "maxTokens": 32768
        }]
      },
      "google": {
        "api": "openai-completions",
        "apiKey": "${GOOGLE_API_KEY}",
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai",
        "models": [{
          "id": "gemini-2.5-flash",
          "name": "Gemini 2.5 Flash",
          "reasoning": false,
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65536,
          "compat": { "supportsStore": false }
        }]
      }
    }
  },
  "tools": {
    "profile": "full",
    "deny": ["gateway"],
    "web": {
      "search": {
        "enabled": true,
        "provider": "gemini",
        "gemini": {
          "apiKey": "${GEMINI_API_KEY}",
          "model": "gemini-2.5-flash"
        }
      },
      "fetch": {
        "enabled": true
      }
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "approvals": {
    "exec": {
      "enabled": true,
      "mode": "session",
      "targets": [
        { "channel": "telegram", "to": "YOUR_TELEGRAM_USER_ID" }
      ]
    }
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "${GATEWAY_TOKEN}"
    },
    "tls": {},
    "tailscale": {
      "mode": "off"
    },
    "nodes": {}
  }
}
```

### Configurar exec-approvals.json

El sistema de aprobación de ejecución controla qué comandos puede ejecutar el agente de forma autónoma y cuáles requieren tu aprobación explícita (reenviada a Telegram).

```bash
nano ~/.openclaw/exec-approvals.json
```

```json
{
  "version": 1,
  "socket": {
    "path": "/home/openclaw/.openclaw/exec-approvals.sock",
    "token": "GENERATED_BY_SCRIPT"
  },
  "defaults": {
    "security": "allowlist",
    "ask": "on-miss",
    "askFallback": "deny",
    "autoAllowSkills": true
  },
  "agents": {
    "main": {
      "security": "allowlist",
      "ask": "on-miss",
      "askFallback": "deny",
      "autoAllowSkills": true,
      "allowlist": [
        { "pattern": "/usr/bin/cat" },
        { "pattern": "/usr/bin/ls" },
        { "pattern": "/usr/bin/grep" },
        { "pattern": "/usr/bin/find" },
        { "pattern": "/usr/bin/diff" },
        { "pattern": "/usr/bin/stat" },
        { "pattern": "/usr/bin/du" },
        { "pattern": "/usr/bin/df" },
        { "pattern": "/usr/bin/sed" },
        { "pattern": "/usr/bin/awk" },
        { "pattern": "/usr/bin/touch" },
        { "pattern": "/usr/bin/mkdir" },
        { "pattern": "/usr/bin/cp" },
        { "pattern": "/usr/bin/mv" },
        { "pattern": "/usr/bin/tar" },
        { "pattern": "/usr/bin/date" },
        { "pattern": "/usr/bin/env" },
        { "pattern": "/usr/bin/whoami" },
        { "pattern": "/usr/bin/uname" },
        { "pattern": "/usr/bin/hostname" },
        { "pattern": "/usr/bin/uptime" },
        { "pattern": "/usr/bin/free" },
        { "pattern": "/usr/bin/top" },
        { "pattern": "/usr/bin/ps" },
        { "pattern": "/usr/bin/ss" },
        { "pattern": "/usr/bin/netstat" },
        { "pattern": "/usr/bin/lsof" },
        { "pattern": "/usr/bin/htop" },
        { "pattern": "/usr/bin/journalctl" },
        { "pattern": "/usr/bin/ping" },
        { "pattern": "/usr/bin/git" },
        { "pattern": "/usr/bin/docker" },
        { "pattern": "/usr/bin/curl" },
        { "pattern": "/usr/bin/wget" },
        { "pattern": "/usr/bin/python3" },
        { "pattern": "/home/openclaw/.nvm/**/node" },
        { "pattern": "/home/openclaw/.nvm/**/npm" },
        { "pattern": "/home/openclaw/.nvm/**/npx" },
        { "pattern": "/home/openclaw/.nvm/**/openclaw" },
        { "pattern": "/home/openclaw/.nvm/**/coco" },
        { "pattern": "/home/openclaw/.nvm/**/corepack" },
        { "pattern": "/home/openclaw/.local/bin/*" },
        { "pattern": "/usr/local/bin/*" },
        { "pattern": "/usr/bin/sudo" }
      ]
    }
  }
}
```

!!! note "El `socket.token` se genera automáticamente"
    El script de instalación genera un token único para el socket Unix. Este token es interno de OpenClaw y no necesita configuración manual.

| Campo | Valor | Descripción |
|-------|-------|-------------|
| `version` | `1` | Versión del esquema |
| `socket.path` | `...exec-approvals.sock` | Socket Unix para IPC de aprobaciones |
| `socket.token` | Auto-generado | Token de autenticación interno |
| `defaults.security` | `"allowlist"` | Por defecto global: solo los comandos listados se ejecutan sin preguntar |
| `defaults.ask` | `"on-miss"` | Los comandos fuera de la allowlist disparan solicitud de aprobación vía Telegram |
| `defaults.askFallback` | `"deny"` | Si la solicitud no se puede entregar, deniega por defecto |
| `defaults.autoAllowSkills` | `true` | Los skills instalados pueden ejecutar sus propios comandos sin preguntar |
| `agents.main` | `{...}` | Configuración por agente (hereda defaults, añade allowlist) |

**Estructura del allowlist**: Cada entrada usa `{ "pattern": "/ruta/absoluta/al/binario" }` con rutas absolutas. Se soportan patrones glob (`*`, `**`) para rutas variables (ej. binarios nvm).

**Comandos auto-aprobados (44 entradas):**

| Categoría | Patrones |
|-----------|----------|
| Lectura/búsqueda | `/usr/bin/cat`, `ls`, `grep`, `find`, `diff`, `stat`, `du`, `df` |
| Edición de archivos | `/usr/bin/sed`, `awk`, `touch`, `mkdir`, `cp`, `mv`, `tar` |
| Sistema/monitoreo | `/usr/bin/date`, `env`, `whoami`, `uname`, `hostname`, `uptime`, `free`, `top`, `ps`, `ss`, `netstat`, `lsof`, `htop`, `journalctl`, `ping` |
| Desarrollo | `/usr/bin/git`, `docker`, `python3`, `~/.nvm/**/node`, `npm`, `npx`, `corepack` |
| Red (dev) | `/usr/bin/curl`, `wget` |
| Binarios locales | `~/.nvm/**/openclaw`, `~/.nvm/**/coco`, `~/.local/bin/*`, `/usr/local/bin/*` |
| Sudo restringido | `/usr/bin/sudo` (limitado por sudoers — ver abajo) |

**Comandos que REQUIEREN aprobación vía Telegram:**

| Comando | Razón |
|---------|-------|
| `rm` / `rmdir` | Destructivo e irreversible |
| `kill` | Podría matar OpenClaw o servicios críticos |
| `chmod` | Cambio de permisos puede bloquear acceso |
| `ssh` / `scp` | Movimiento lateral a otros sistemas |

**Comandos NUNCA permitidos** (no están en ninguna lista — siempre denegados):

`su`, `dd`, `passwd`, `mkfs`, `fdisk`, `iptables`, `reboot`, `shutdown`

!!! info "Flujo de aprobación"
    1. El agente intenta ejecutar un comando que no está en la allowlist
    2. OpenClaw envía una solicitud de aprobación a tu Telegram
    3. Respondes: `/approve <id> allow-once` o `allow-always` o `deny`
    4. Si `allow-always`, el comando se agrega a la allowlist permanentemente

!!! warning "Reemplaza `YOUR_TELEGRAM_USER_ID` en ambos archivos"
    En `openclaw.json`, establece `approvals.exec.targets[0].to` con tu ID de usuario de Telegram (el mismo valor que `channels.telegram.allowFrom`).

### Configurar sudo restringido (sudoers)

El agente necesita `sudo` para instalar paquetes y gestionar servicios, pero un `sudo` sin restricciones sería un riesgo de seguridad. La solución: permitir `sudo` en el allowlist de exec-approvals, pero restringir lo que puede hacer mediante reglas sudoers a nivel de SO.

```bash
echo 'openclaw ALL=(ALL) NOPASSWD: /usr/bin/apt-get install *, /usr/bin/apt install *, /usr/bin/apt-get update, /usr/bin/apt update, /usr/bin/pip3 install *, /usr/bin/systemctl restart *, /usr/bin/systemctl status *, /usr/bin/systemctl start *, /usr/bin/systemctl stop *, /usr/bin/systemctl enable *, /usr/bin/systemctl disable *' \
  | sudo tee /etc/sudoers.d/openclaw > /dev/null \
  && sudo chmod 0440 /etc/sudoers.d/openclaw
```

Esto crea `/etc/sudoers.d/openclaw` con acceso NOPASSWD a **solo** estos comandos:

| Comando sudo permitido | Propósito |
|------------------------|-----------|
| `apt-get install *` / `apt install *` | Instalar paquetes |
| `apt-get update` / `apt update` | Actualizar listas de paquetes |
| `pip3 install *` | Instalar paquetes Python |
| `systemctl restart *` | Reiniciar servicios |
| `systemctl status *` | Verificar estado de servicios |
| `systemctl start *` / `stop *` | Iniciar/detener servicios |
| `systemctl enable *` / `disable *` | Habilitar/deshabilitar servicios |

!!! success "Defensa en profundidad: dos capas de protección"
    1. **OpenClaw exec-approvals**: Controla qué binarios puede invocar el agente (`sudo` está en la allowlist)
    2. **Sudoers del SO**: Controla qué puede hacer `sudo` realmente (solo los comandos listados arriba)

    Cualquier comando `sudo` que no esté en la lista de sudoers (ej. `sudo rm -rf /`, `sudo reboot`) será **rechazado por el SO** aunque OpenClaw permita la ejecución de `sudo`.

!!! warning "Este paso requiere acceso SSH"
    El archivo sudoers debe crearse manualmente vía SSH como root o con un usuario que ya tenga sudo. El script de instalación no puede crearlo porque el usuario `openclaw` no tiene sudo en ese momento.

!!! tip "Proveedores de modelos"
    Añade los proveedores de modelos elegidos en `models.providers`. Opciones comunes:

    | Proveedor | `api` | Input/Output ($/MTok) | Notas |
    |-----------|-------|----------------------|-------|
    | Google Gemini 2.5 Flash | `openai-completions` | $0.30 / $2.50 | Añadir `compat.supportsStore: false` (obligatorio) |
    | Google Gemini 2.5 Flash Lite | `openai-completions` | $0.10 / $0.40 | Ideal para heartbeats, modelo viable más barato |
    | DeepSeek V3 | `openai-completions` | $0.28 / $0.42 | Mejor valor — 90% rendimiento de GPT a 1/50 del coste |
    | Moonshot (Kimi K2.5) | `openai-completions` | $0.60 / $2.50 | Separado de Kimi Coding (key y endpoint diferentes) |
    | Kimi Coding | `anthropic-messages` | Suscripción (~$19/mes) | Añadir `headers.User-Agent: "claude-code/0.1.0"` (obligatorio) |
    | Anthropic Claude Sonnet 4.5 | `anthropic-messages` | $3.00 / $15.00 | |
    | Anthropic Claude Opus 4.6 | `anthropic-messages` | $5.00 / $25.00 | |

    **Referencia de tipos de API:**

    | Valor `api` | Usar para |
    |-------------|-----------|
    | `openai-completions` | Endpoints compatibles con OpenAI (Gemini, Moonshot, DeepSeek, vLLM, LM Studio) |
    | `anthropic-messages` | API Anthropic Messages (Claude, Kimi Coding) |
    | `google-generative-ai` | API nativa de Google Gemini (usa `.../v1beta` sin `/openai`) |
    | `openai-responses` | API de responses de OpenAI |
    | `ollama` | Modelos locales con Ollama |

    Configura `"fallbacks"` en `agents.defaults.model` para que el agente cambie automáticamente si el proveedor principal cae.

!!! warning "Problemas conocidos de Kimi Coding"
    - **Header User-Agent obligatorio**: La API de Kimi Coding rechaza peticiones sin `User-Agent: claude-code/0.1.0`. OpenClaw envía `OpenClaw-Gateway/1.0` por defecto, causando errores 401. Fix: añadir `"headers": { "User-Agent": "claude-code/0.1.0" }` a nivel de proveedor.
    - **El model ID debe ser `kimi-for-coding`**: No uses `k2p5` ni otros alias.
    - **`reasoning: true` puede fallar**: Los parámetros de extended-thinking pueden causar que Kimi rechace peticiones. Empieza con `false`.
    - **baseUrl sin trailing slash**: Usa `https://api.kimi.com/coding` (no `/coding/`). OpenClaw elimina trailing slashes automáticamente, pero mejor no ponerlo.
    - **`auth-profiles.json` tiene prioridad sobre env vars**: OpenClaw guarda API keys en `~/.openclaw/agents/main/agent/auth-profiles.json`. Si este archivo contiene una key inválida, tiene prioridad sobre `process.env.KIMI_API_KEY` de systemd, causando errores 401 persistentes incluso con la key correcta en el systemd override. Fix: vaciar el archivo (`echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json`) y reiniciar.
    - **`openclaw doctor --fix` sobreescribe config manual**: Revierte la configuración de Kimi a templates rotos por defecto. NO ejecutes `--fix` después de configurar manualmente.
    - **Moonshot ≠ Kimi Coding**: Son proveedores separados con API keys diferentes (`MOONSHOT_API_KEY` vs `KIMI_API_KEY`) y endpoints distintos.

!!! tip "`compat.supportsStore` de Gemini explicado"
    Sin `"compat": { "supportsStore": false }`, OpenClaw envía un parámetro `store` que Google rechaza con HTTP 400 (el body del error está comprimido con gzip, así que los logs muestran "400 no body"). Es **obligatorio** para todos los modelos Gemini via el endpoint de compatibilidad OpenAI.

    NO uses `"api": "google-generative-ai"` con una baseUrl que termine en `/openai` — causa errores 404. Usa:

    - `openai-completions` + `.../v1beta/openai` (recomendado, más fiable)
    - `google-generative-ai` + `.../v1beta` (nativo, sin `/openai`)

!!! info "Configuración de tools"
    La configuración recomendada usa `profile: "full"` con `deny: ["gateway"]`:

    - `"full"` habilita todas las herramientas incluyendo web search, browser, canvas, cron y shell
    - `"deny": ["gateway"]` impide que el agente modifique su propia configuración del gateway en runtime

    Usar `profile: "coding"` con `allow: ["group:web"]` NO habilita correctamente `web_search` (posible bug). Usa `"full"` + `"deny"` en su lugar.

    Para un agente sin restricciones: `"tools": {}`

    **Perfiles de tools:**

    | Perfil | Incluye |
    |--------|---------|
    | `full` | Todo (por defecto cuando no se especifica) |
    | `coding` | `group:fs`, `group:runtime`, `group:sessions`, `group:memory`, `image` |
    | `messaging` | `group:messaging`, `sessions_*`, `session_status` |
    | `minimal` | Solo `session_status` |

    **Grupos de tools:**

    | Grupo | Se expande a |
    |-------|-------------|
    | `group:runtime` | `exec`, `bash`, `process` |
    | `group:fs` | `read`, `write`, `edit`, `apply_patch` |
    | `group:sessions` | `sessions_list`, `sessions_history`, `sessions_send`, `sessions_spawn`, `session_status` |
    | `group:memory` | `memory_search`, `memory_get` |
    | `group:web` | `web_search`, `web_fetch` |
    | `group:ui` | `browser`, `canvas` |
    | `group:automation` | `cron`, `gateway` |
    | `group:messaging` | `message` |

    El perfil `coding` puede advertir sobre tools desconocidas (`apply_patch`, `image`) — es inofensivo, esas tools simplemente no se cargan sin sus plugins.

    !!! warning "Problema conocido: perfil `coding` y `web_search`"
        Usar `profile: "coding"` con `allow: ["group:web"]` NO habilita correctamente `web_search` (posible bug). Por eso recomendamos `profile: "full"` con `deny: ["gateway"]`.

!!! info "Configuración de `web_search`"
    La herramienta `web_search` requiere una API key de búsqueda. OpenClaw auto-detecta en este orden: Brave → Gemini → Kimi → Perplexity → Grok.

    **Opción A** — Auto-detección via variable de entorno (configura `GEMINI_API_KEY` en `.env` o systemd):
    ```env
    GEMINI_API_KEY=AIza...
    ```

    **Opción B** — Config explícita en `tools.web` (mostrada en el JSON de ejemplo arriba):
    ```json
    "tools": {
      "web": {
        "search": {
          "enabled": true,
          "provider": "gemini",
          "gemini": { "apiKey": "${GEMINI_API_KEY}", "model": "gemini-2.5-flash" }
        },
        "fetch": { "enabled": true }
      }
    }
    ```

    **Opción C** — Setup interactivo: `openclaw configure --section web`

    **Tres campos fáciles de olvidar:**

    - `tools.web.search.enabled = true` — web_search NO se activa por defecto aunque configures un provider
    - `tools.web.search.gemini.model` — La búsqueda con Gemini requiere un nombre de modelo explícito
    - `tools.web.fetch.enabled = true` — habilita la herramienta `web_fetch` para leer páginas web

    Nota: `GOOGLE_API_KEY` (para inferencia del modelo) y `GEMINI_API_KEY` (para búsqueda web) pueden usar el mismo valor de key, pero son nombres de variables diferentes.

!!! info "Sustitución de variables en openclaw.json"
    `openclaw.json` soporta `${VAR_NAME}` en valores string. Orden de resolución (gana la primera coincidencia):

    1. Entorno del proceso (systemd `Environment=`)
    2. `.env` en el directorio de trabajo actual
    3. `~/.openclaw/.env` (fallback global)
    4. `config.env.vars` en openclaw.json

    Solo se sustituyen nombres en mayúsculas que coincidan con `[A-Z_][A-Z0-9_]*`. Usa `$${VAR}` para producir un literal `${VAR}`.

!!! danger "Configuración de seguridad crítica"
    - `bind: "loopback"` — Solo escucha en localhost (nunca `0.0.0.0`)
    - `sandbox.mode: "off"` — Se apoya en el hardening de systemd para aislamiento (recomendado para VPS dedicada). Usa `"all"` para servidores compartidos
    - `auth.mode: "token"` — Acceso al Gateway requiere token de autenticación
    - **Todos los secrets usan referencias `${VAR_NAME}`** — Nunca guardes tokens o API keys como texto plano en este archivo
    - `session.dmScope: "per-channel-peer"` — Aísla las sesiones DM para prevenir filtración de contexto
    - `tls: {}` — TLS habilitado con valores por defecto

!!! warning "Eliminado en v2026.3.x"
    Las claves `dmPolicy`, `security` y `tools.blocked` a nivel raíz **no son reconocidas** por OpenClaw 2026.3.x. La política de DM se configura por canal cuando los añades. Ejecuta `openclaw doctor` para validar tu config.

!!! info "Sandbox 'all' vs 'off' — elegir el modo correcto"
    - **`"all"`** — Containeriza toda ejecución de herramientas en Docker. Más seguro, pero los archivos `.env` de skills y variables de entorno del host NO están disponibles dentro del contenedor. Requiere inyectar env vars via `skills.entries[name].env` en `openclaw.json`. Mejor para servidores compartidos o multi-usuario.
    - **`"off"`** — Sin containerización. Los archivos `.env` de skills funcionan normalmente, el auto-discovery es transparente. Se apoya en el hardening de systemd + restricciones de tools para seguridad. **Recomendado para VPS dedicada de un solo usuario** con el hardening de esta guía (aislamiento systemd + Tailscale + allowlist).

    A partir de OpenClaw v2026.2.x, el modo `"all"` reemplaza a `"always"`.

### Configurar secrets (API keys y tokens)

Todos los valores sensibles en `openclaw.json` usan referencias `${VAR_NAME}`. Los valores reales se almacenan por separado, nunca en el archivo JSON de configuración.

#### Método 1: Overrides de entorno en systemd (recomendado para VPS)

El método más seguro para despliegues en VPS dedicada. Los secrets se guardan en un archivo propiedad de root que solo systemd lee al arrancar.

```bash
sudo systemctl edit openclaw
```

Añade tus API keys y overrides de hardening:

```ini
[Service]
# === API Keys ===
Environment="KIMI_API_KEY=sk-kimi-tu-key"
Environment="GOOGLE_API_KEY=tu-api-key-de-google"
Environment="GEMINI_API_KEY=tu-api-key-de-google"
Environment="GATEWAY_TOKEN=tu-token-del-gateway"

# === Relajar hardening para apt-get (VPS dedicado) ===
# Permite escritura en /var (apt necesita /var/cache/apt, /var/lib/dpkg)
ProtectSystem=full

# Desactivar filtros que activan NoNewPrivs implícitamente
SystemCallFilter=
PrivateDevices=false
LockPersonality=false
RestrictRealtime=false
ProtectKernelTunables=false
ProtectKernelModules=false

# Añadir paths de escritura para apt
ReadWritePaths=/home/openclaw/openclaw/workspace
ReadWritePaths=/home/openclaw/openclaw/logs
ReadWritePaths=/home/openclaw/.openclaw
ReadWritePaths=/var/cache/apt
ReadWritePaths=/var/lib/apt
ReadWritePaths=/var/lib/dpkg
ReadWritePaths=/var/log/apt
ReadWritePaths=/tmp
```

!!! important "Variables de entorno necesarias"
    | Variable | Uso |
    |----------|-----|
    | `KIMI_API_KEY` | Modelo principal (Kimi Coding) |
    | `GOOGLE_API_KEY` | Modelo fallback (Gemini 2.5 Flash) |
    | `GEMINI_API_KEY` | Web search — mismo valor que `GOOGLE_API_KEY` pero necesario como variable separada |
    | `GATEWAY_TOKEN` | Autenticación del gateway |

    `TELEGRAM_BOT_TOKEN` va en `~/.openclaw/.env` (leído por el proceso del gateway), no en systemd overrides.

Guarda y aplica:

```bash
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

El archivo de override se guarda en `/etc/systemd/system/openclaw.service.d/override.conf` con permisos solo de root.

!!! note "Por qué el override incluye relajación de hardening"
    `SystemCallFilter=` (vacío) en el override **resetea** todos los filtros de syscalls del servicio base. Junto con `PrivateDevices=false`, `LockPersonality=false` y `RestrictRealtime=false`, permite que `sudo` funcione para instalar paquetes. La seguridad se aplica mediante `exec-approvals` allowlist + sudoers del SO.

#### Método 2: Archivo .env (para tokens de canales)

Algunos tokens (como el token del bot de Telegram) pueden guardarse en un archivo `.env`:

```bash
nano ~/.openclaw/.env
```

```bash
# Tokens de canales
TELEGRAM_BOT_TOKEN=tu-token-del-bot

# API keys adicionales (si no usas el método systemd)
# GOOGLE_API_KEY=tu-key
# GEMINI_API_KEY=tu-key  # Mismo valor que GOOGLE_API_KEY, necesario para búsqueda web
```

**Proteger el archivo:**

```bash
chmod 600 ~/.openclaw/.env
chown openclaw:openclaw ~/.openclaw/.env
```

#### Método 3: SecretRef (nativo de OpenClaw)

OpenClaw v2026.3.x soporta secrets cifrados via el wizard interactivo:

```bash
# Wizard interactivo de secrets
openclaw secrets configure

# Auditar por texto plano
openclaw secrets audit

# Recargar secrets en runtime (sin reiniciar)
openclaw secrets reload
```

!!! success "Comparación de métodos de secrets"
    | Característica | Override systemd | Archivo .env | SecretRef |
    |---|---|---|---|
    | Almacenamiento | Archivo propiedad de root | Texto plano del usuario | Cifrado en disco |
    | El agente puede leerlo | No | Sí (riesgo de prompt injection) | No |
    | Filtración en shell history | No | No | No |
    | Sobrevive actualizaciones | Sí | Sí | Sí |
    | Mejor para | API keys en VPS | Tokens de canales | Todos los secrets |

### Configurar SOUL.md (identidad del agente)

SOUL.md define quién es tu agente, qué puede hacer y cómo se comporta. OpenClaw inyecta este archivo en el contexto del agente en cada interacción.

```bash
nano ~/openclaw/workspace/SOUL.md
```

#### Secciones recomendadas

Un SOUL.md bien estructurado debería incluir estas secciones:

| Sección | Propósito |
|---------|-----------|
| **Identidad** | Quién es el agente y para quién trabaja |
| **Misión** | Qué debe optimizar (corrección, seguridad, valor, velocidad) |
| **Reglas de idioma** | Idioma de respuesta, idioma de código, idioma de comunicación de negocio |
| **Capacidades** | En qué puede ayudar (desarrollo, negocio, investigación, etc.) |
| **Puertas de aprobación** | Acciones que requieren confirmación explícita antes de ejecutarse |
| **Límites de filesystem** | Paths permitidos y prohibidos |
| **Reglas de seguridad** | Cómo manejar secrets, credenciales y datos sensibles |
| **Reglas de comunicación** | Tono, estilo y preferencias de formato de salida |
| **Continuidad** | Cómo usar archivos del workspace como memoria persistente entre sesiones |

#### Buenas prácticas

- **Sé específico con la identidad**: Dile al agente para quién trabaja y qué representa. Un genérico "eres un asistente" produce respuestas genéricas.
- **Define puertas de aprobación explícitamente**: Lista cada acción irreversible o externa que necesita confirmación (emails, commits, llamadas API, compras). El agente debe mostrar borradores antes de enviar.
- **Establece reglas de idioma claras**: Separa el idioma de conversación del idioma de código. Por ejemplo: "responde en español, escribe código y documentación en inglés."
- **Incluye límites de filesystem**: Siempre restringe el acceso al directorio workspace. Prohíbe explícitamente el acceso a `.ssh`, `.env`, `/etc` y `/var`.
- **Añade contexto de negocio si aplica**: Si el agente representa un negocio, incluye servicios ofrecidos, clientes ideales y reglas de estilo de comunicación comercial. Cuanto más contexto, mejor la calidad del output.
- **Define estructura de output**: Dile al agente cómo formatear diferentes tipos de respuestas (técnicas, investigación, borradores de negocio). Esto ahorra tiempo en aclaraciones.
- **Protege datos sensibles**: Indica explícitamente que secrets, credenciales e información personal nunca deben aparecer en outputs.
- **Usa la sección de continuidad**: Dile al agente que persista conocimiento reutilizable (investigación de clientes, preferencias, plantillas) en archivos del workspace para que se mantenga entre sesiones.

#### Ejemplo mínimo

```markdown
# Mi Asistente

## Identidad
Eres un asistente de desarrollo en un VPS aislado.
Trabajas para [tu nombre/empresa].

## Idioma
- Responde en [tu idioma]
- Escribe código, comentarios y documentación en inglés

## Puertas de aprobación
Pide siempre antes de: enviar emails, hacer push de commits, borrar archivos,
llamar a APIs externas, o cualquier acción irreversible.

## Filesystem
- Solo acceder a: /home/openclaw/openclaw/workspace
- Nunca acceder a: .ssh, .env, /etc, /var

## Seguridad
- Nunca exponer secrets, tokens o credenciales
- Redactar secrets en outputs

## Tono
Profesional, conciso, directo.
```

!!! tip "Itera sobre tu SOUL.md"
    Empieza con lo mínimo y amplía según descubras qué hace mal el agente. Si hace algo que no quieres, añade una regla. Si le falta contexto, añade información. El SOUL.md es un documento vivo.

!!! info "Archivos SOUL, TOOLS y AGENTS"
    OpenClaw inyecta automáticamente estos archivos Markdown en el contexto del agente:

    - `SOUL.md` — Identidad y restricciones del agente
    - `TOOLS.md` — Configuración de herramientas disponibles
    - `AGENTS.md` — Definición de agentes especializados

!!! warning "Ruta correcta para SOUL.md"
    Estos archivos deben estar en el **directorio workspace** configurado en `agents.defaults.workspace`, **no** en `~/.openclaw/workspace/`. Con nuestra configuración, la ruta correcta es:

    ```
    ~/openclaw/workspace/SOUL.md
    ```

    Si el agente ignora tu SOUL.md, verifica que la ruta coincide con tu configuración:
    `grep workspace ~/.openclaw/openclaw.json`

### Configurar TOOLS.md (herramientas)

TOOLS.md proporciona contexto al agente sobre cómo debe usar sus herramientas. NO impone restricciones — el acceso a herramientas lo controlan `tools.profile` y `tools.deny` en `openclaw.json`. Piensa en TOOLS.md como directrices, no barreras.

```bash
nano ~/openclaw/workspace/TOOLS.md
```

```markdown
# Herramientas

## Herramientas disponibles (via profile "full" − deny ["gateway"])

### Filesystem (group:fs)
- read, write, edit, apply_patch
- Workspace: /home/openclaw/openclaw/workspace

### Shell & Runtime (group:runtime)
- exec, bash, process
- Usar para: git, npm, comandos de sistema, scripts

### Web (group:web)
- web_search (con Gemini), web_fetch
- Usar para: investigación, consultas de documentación, llamadas API

### Browser & UI (group:ui)
- browser, canvas
- Usar para: web scraping, contenido visual

### Sessions (group:sessions)
- Crear y gestionar sesiones de sub-agentes

### Memory (group:memory)
- Memoria persistente entre sesiones

### Cron
- Programar tareas recurrentes

## NO disponible (excluido intencionalmente)

### Gateway
NO disponible — modificar la configuración del gateway en runtime es un riesgo de seguridad.

## Directrices

- Siempre preguntar antes de: enviar emails, push a repos remotos, borrar archivos
- Preferir rutas del workspace para todas las operaciones de archivos
- Nunca acceder a: ~/.ssh, ~/.openclaw/.env, /etc/systemd
- Nunca exponer secretos, tokens o credenciales en la salida
```

### Sandbox y restricciones de herramientas

Para un **VPS dedicado de un solo usuario** con el hardening systemd de esta guía, el modo sandbox `"off"` es la configuración recomendada. La seguridad se aplica mediante el aislamiento de systemd (ProtectSystem, ReadWritePaths, CapabilityBoundingSet, etc.) y las restricciones de herramientas (`tools.profile` + `tools.deny`).

El acceso a herramientas se controla en `openclaw.json` (ya configurado en el ejemplo JSON principal de arriba):

```json
"sandbox": { "mode": "off" },
"tools": {
  "profile": "full",
  "deny": ["gateway"]
}
```

Esto da al agente todas las herramientas (filesystem, shell, git, sessions, memory, web search, web fetch, browser, canvas, cron, etc.) excepto `gateway` — que se deniega porque permitiría al agente modificar su propia configuración del gateway en runtime.

!!! warning "Bug del perfil `coding` con `web_search`"
    Usar `profile: "coding"` con `allow: ["group:web"]` NO habilita correctamente `web_search` (posible bug de OpenClaw). Usa `"full"` + `"deny"` para asegurar que todas las herramientas funcionan correctamente.

!!! info "Cuándo usar sandbox mode 'all' en su lugar"
    Usa `"all"` solo en **servidores compartidos o multi-usuario** donde no puedas confiar en otros usuarios. Containeriza toda la ejecución de herramientas en Docker, lo que proporciona un aislamiento más fuerte pero requiere Docker instalado y hace que los archivos `.env` y las variables de entorno del host no estén disponibles dentro del contenedor.

    Para VPS dedicado con hardening systemd + Tailscale + allowlist, `"off"` ofrece seguridad equivalente con menos complejidad.

### Configurar DM Policy (seguridad de mensajes)

OpenClaw puede recibir mensajes de canales como Telegram, Discord, etc. La política de DMs se configura **por canal** cuando los añades (no a nivel raíz). El valor por defecto es `"pairing"` que requiere aprobación.

Con `dmPolicy: "pairing"` en un canal, los remitentes desconocidos reciben un código de emparejamiento que debes aprobar:

```bash
# Ver códigos de emparejamiento pendientes
openclaw pairing list

# Aprobar un código específico
openclaw pairing approve telegram ABC123
```

!!! danger "Nunca uses dmPolicy: 'open'"
    Esto permitiría que cualquiera envíe comandos a tu agente. Solo usa `pairing` o `closed`.

### Configurar canal de Telegram

**Paso 1 — Crear bot en Telegram:**

1. Abre Telegram y busca **@BotFather**
2. Envía `/newbot`
3. Elige un nombre (ej: "OpenClaw Assistant")
4. Elige un username que termine en `_bot` (ej: `openclaw_minombre_bot`)
5. BotFather te da un token (formato: `123456789:ABCdef...`) — guárdalo

**Paso 2 — Añadir canal a la config:**

```bash
nano ~/.openclaw/openclaw.json
```

Añade la sección `channels` a nivel raíz (antes del último `}`):

```json
"channels": {
  "telegram": {
    "enabled": true,
    "botToken": "TU_TOKEN_DE_BOTFATHER",
    "dmPolicy": "pairing"
  }
}
```

!!! tip "No olvides la coma"
    Añade una coma después del `}` de la sección anterior antes de `"channels"`.

!!! warning "Cambia a allowlist después del emparejamiento"
    Usa `"pairing"` solo para la configuración inicial. Después de aprobar tu cuenta (Paso 4), cambia a `"allowlist"` en el Paso 5 para bloquear el acceso.

**Paso 3 — Reiniciar y verificar:**

```bash
sudo systemctl restart openclaw
# Espera ~2 minutos, luego verifica que Telegram conectó:
sudo journalctl -u openclaw --since "3 min ago" --no-pager | grep telegram
```

Deberías ver: `[telegram] [default] starting provider (@tu_nombre_bot)`

**Paso 4 — Emparejar tu cuenta:**

1. Abre Telegram y envía cualquier mensaje a tu bot
2. El bot responde con un código de emparejamiento
3. Apruébalo en el VPS:

```bash
openclaw pairing approve telegram <CODIGO>
```

Después de aprobarlo, envía otro mensaje — el bot debería responder.

**Paso 5 — Restringir acceso solo a tu cuenta:**

Busca tu ID de Telegram — envía cualquier mensaje a **@raw_data_bot** en Telegram, te mostrará tu ID numérico.

Luego edita la config:

```bash
nano ~/.openclaw/openclaw.json
```

Cambia `dmPolicy` a `"allowlist"` y añade `allowFrom` con tu ID:

```json
"channels": {
  "telegram": {
    "enabled": true,
    "botToken": "TU_TOKEN",
    "dmPolicy": "allowlist",
    "allowFrom": ["TU_TELEGRAM_ID"]
  }
}
```

Reinicia: `sudo systemctl restart openclaw`

!!! danger "Usa dmPolicy 'allowlist' — no 'pairing'"
    Con `"pairing"`, **cualquiera** que encuentre tu bot puede pedir un código de emparejamiento — `allowFrom` se ignora.
    Con `"allowlist"`, **solo** los IDs en `allowFrom` pueden interactuar con el bot — el resto es ignorado silenciosamente.

#### Revocar acceso de un remitente aprobado previamente

Si aprobaste a alguien por error, edita el archivo de pairing:

```bash
# Ver remitentes aprobados
cat ~/.openclaw/credentials/telegram-default-allowFrom.json

# Eliminar un remitente (reemplaza SENDER_ID con el ID a eliminar)
python3 -c "
import json
f = '/home/openclaw/.openclaw/credentials/telegram-default-allowFrom.json'
with open(f) as fh:
    d = json.load(fh)
d['allowFrom'] = [x for x in d['allowFrom'] if x != 'SENDER_ID']
with open(f, 'w') as fh:
    json.dump(d, fh, indent=2)
print('Removed SENDER_ID')
"
sudo systemctl restart openclaw
```

!!! note "No hay comando CLI para revocar"
    OpenClaw no tiene un comando CLI para revocar remitentes aprobados. Los archivos de pairing en `~/.openclaw/credentials/` deben editarse manualmente.

!!! note "El wizard `openclaw channels add`"
    El wizard interactivo (`openclaw channels add`) puede no guardar la config correctamente. Si falla, usa el método manual de JSON descrito arriba — es más fiable.

#### Comandos útiles en Telegram

| Comando | Descripción |
|---------|-------------|
| `/new` | Inicia una sesión nueva (recarga SOUL.md y limpia contexto) |
| `/reset` | Igual que `/new` |
| `/compact` | Resume turnos antiguos de conversación para liberar contexto |

!!! tip "Reducir mensajes duplicados"
    Si el bot envía 2-3 respuestas por mensaje, añade `"blockStreaming": true` a la config del canal Telegram. Esto hace que el bot solo envíe la respuesta final.

    ```json
    "channels": {
      "telegram": {
        "blockStreaming": true,
        ...
      }
    }
    ```

!!! tip "¿Cambios en SOUL.md no toman efecto?"
    Envía `/new` al bot para iniciar una sesión nueva. Si no funciona, limpia el caché del sandbox:

    ```bash
    rm -rf ~/.openclaw/sandboxes/agent-main-*
    sudo systemctl restart openclaw
    ```
    Luego envía `/new` al bot de nuevo.

### Instalar y configurar skills

Los skills amplían las capacidades de tu agente (email, web scraping, calendario, etc.). Instálalos con el comando `npx playbooks`.

!!! danger "Audita siempre los skills antes de instalar"
    Tras el ataque a la cadena de suministro de ClawHub (febrero 2026), **nunca instales skills a ciegas**. Audita el código fuente, verifica la reputación del autor y ejecuta `openclaw security audit` después de la instalación.

**Instalar un skill globalmente** (recomendado para VPS dedicado):

```bash
npx playbooks add skill openclaw/skills --skill <nombre-skill>
# Cuando pregunte por el scope, selecciona "Global"
```

**Skills recomendados para uso empresarial/desarrollo:**

!!! tip "Registros de skills"
    Los skills se encuentran en [ClawHub](https://clawhub.com) (13.700+ skills) o [Playbooks](https://playbooks.com/skills/openclaw/skills) (18.300+ skills). Para una lista curada y filtrada por seguridad, consulta [awesome-openclaw-skills](https://github.com/VoltAgent/awesome-openclaw-skills) (5.494 skills verificados).

| Skill | Instalación | Propósito |
|-------|-------------|-----------|
| `imap-smtp-email` | `npx playbooks add skill openclaw/skills --skill imap-smtp-email` | Enviar y recibir emails via IMAP/SMTP con adjuntos |
| `github` | `npx clawhub@latest install github` | Gestionar repos, issues, PRs, CI de GitHub via `gh` CLI |
| `tavily-search` | `npx clawhub@latest install tavily-search` | Búsqueda web optimizada para IA, investigación y verificación |
| `gog` | `npx clawhub@latest install gog` | Google Workspace: Gmail, Calendar, Drive, Contactos, Sheets, Docs |
| `summarize` | `npx clawhub@latest install summarize` | Convertir contenido extenso en resúmenes estructurados |
| `obsidian` | `npx clawhub@latest install obsidian` | Interactuar con vaults de Obsidian, automatizar organización de notas |
| `memory` | `npx playbooks add skill openclaw/skills --skill memory` | Memoria persistente entre sesiones |
| `n8n-workflow-automation` | `npx clawhub@latest install n8n-workflow-automation` | Conectar OpenClaw con n8n para ejecutar/gestionar workflows |

!!! warning "Después de instalar cualquier skill"
    1. Ejecuta `cd ~/.agents/skills/<skill-name> && npm install` — OpenClaw NO instala las dependencias npm automáticamente
    2. Ejecuta `openclaw security audit` para verificar que el skill es seguro
    3. Reinicia OpenClaw: `sudo systemctl stop openclaw && sleep 2 && sudo systemctl start openclaw`

#### Configurar email (skill imap-smtp-email)

Después de instalar el skill `imap-smtp-email`, configura las credenciales.

**Paso 1 — Guardar credenciales con SecretRef (recomendado):**

```bash
openclaw secrets configure IMAP_HOST
# Introduce: imap.tu-proveedor.com

openclaw secrets configure IMAP_USER
# Introduce: tu@email.com

openclaw secrets configure IMAP_PASS
# Introduce: tu-contraseña-de-email

openclaw secrets configure SMTP_HOST
# Introduce: smtp.tu-proveedor.com

openclaw secrets configure SMTP_USER
# Introduce: tu@email.com

openclaw secrets configure SMTP_PASS
# Introduce: tu-contraseña-de-email

# Verifica que todos los secretos estén guardados
openclaw secrets list
```

**Paso 2 — Configurar skill en openclaw.json:**

```bash
nano ~/.openclaw/openclaw.json
```

Añade la sección `skills` a nivel raíz:

```json
"skills": {
  "entries": {
    "imap-smtp-email": {
      "enabled": true,
      "env": {
        "IMAP_HOST": { "$secretRef": "IMAP_HOST" },
        "IMAP_PORT": "993",
        "IMAP_USER": { "$secretRef": "IMAP_USER" },
        "IMAP_PASS": { "$secretRef": "IMAP_PASS" },
        "IMAP_TLS": "true",
        "IMAP_MAILBOX": "INBOX",
        "SMTP_HOST": { "$secretRef": "SMTP_HOST" },
        "SMTP_PORT": "587",
        "SMTP_SECURE": "false",
        "SMTP_USER": { "$secretRef": "SMTP_USER" },
        "SMTP_PASS": { "$secretRef": "SMTP_PASS" }
      }
    }
  }
}
```

**Paso 3 — Reiniciar y verificar:**

```bash
sudo systemctl restart openclaw
openclaw security audit
```

!!! info "Configuración IMAP/SMTP por proveedor"
    | Proveedor | Host IMAP | Puerto IMAP | Host SMTP | Puerto SMTP |
    |-----------|-----------|-------------|-----------|-------------|
    | IONOS | imap.ionos.com | 993 (SSL/TLS) | smtp.ionos.com | 587 (STARTTLS) |
    | Gmail | imap.gmail.com | 993 (SSL/TLS) | smtp.gmail.com | 587 (STARTTLS) |
    | Outlook | outlook.office365.com | 993 (SSL/TLS) | smtp.office365.com | 587 (STARTTLS) |

!!! warning "Gmail requiere contraseñas de aplicación"
    Si usas Gmail, activa 2FA y genera una contraseña de aplicación. No uses la contraseña de tu cuenta.

!!! tip "Alternativa: archivo .env en la carpeta del skill"
    Si `openclaw secrets configure` no funciona para tu setup, crea un archivo `.env` directamente en la carpeta de instalación del skill. **Importante:** verifica la ruta real primero — puede variar:

    ```bash
    # Buscar dónde se instaló realmente el skill
    find /home/openclaw -name "SKILL.md" -path "*imap*" 2>/dev/null
    ```

    Luego crea el `.env` en esa misma carpeta:

    ```bash
    mkdir -p ~/.agents/skills/imap-smtp-email
    nano ~/.agents/skills/imap-smtp-email/.env
    ```

    ```bash
    IMAP_HOST=imap.tu-proveedor.com
    IMAP_PORT=993
    IMAP_USER=tu@email.com
    IMAP_PASS=tu-contraseña
    IMAP_TLS=true
    IMAP_MAILBOX=INBOX
    SMTP_HOST=smtp.tu-proveedor.com
    SMTP_PORT=587
    SMTP_SECURE=false
    SMTP_USER=tu@email.com
    SMTP_PASS=tu-contraseña
    ```

    ```bash
    chmod 600 ~/.agents/skills/imap-smtp-email/.env
    ```

### Configurar AGENTS.md (agentes especializados)

AGENTS.md define agentes especializados a los que tu agente principal puede delegar tareas. Colócalo en el workspace:

```bash
nano ~/openclaw/workspace/AGENTS.md
```

```markdown
# Agents

## researcher
- Role: Web research, competitive analysis, market intelligence
- Tools: web-search, web-fetch
- Instructions: Always cite sources. Return structured summaries.

## email-drafter
- Role: Draft and review business emails, outreach campaigns
- Tools: imap-smtp-email
- Instructions: Never send without owner approval. Always show draft first.
  Match recipient's language. Professional but warm tone.

## developer
- Role: Code review, debugging, documentation, architecture
- Tools: read, write, edit, bash, glob, grep
- Instructions: Follow project conventions. Write tests for new features.
  Use English for code and comments.
```

!!! tip "Los agents son opcionales"
    Puedes empezar sin AGENTS.md — el agente principal maneja todo. Añade agentes especializados cuando quieras mejorar la calidad para tipos de tareas específicos.

---

## Ejecutar OpenClaw (prueba manual)

### Verificar que escucha solo en localhost

```bash
# Ejecutar el Gateway manualmente con variables de entorno cargadas en línea
# Esto evita filtrar secrets al entorno del shell y a /proc/*/environ
env $(grep -v '^#' ~/.openclaw/.env | xargs) openclaw gateway --port 18789 --verbose
```

!!! warning "No uses `export` para cargar secrets"
    Evita el patrón `export $(grep -v '^#' .env | xargs)`. Usar `export` inyecta todos los secrets en el entorno del shell, donde persisten durante toda la sesión y son legibles vía `/proc/*/environ` por cualquier proceso ejecutándose como el mismo usuario. El patrón con `env` anterior limita las variables a la invocación de un único comando. Para producción, la directiva `EnvironmentFile` de systemd (mostrada más abajo en la configuración del servicio) es el método preferido — carga las variables directamente en el servicio sin exponerlas a shells interactivos.

En **otra terminal SSH**, verifica:

```bash
# Debe mostrar que escucha en 127.0.0.1, NO en 0.0.0.0
ss -tlnp | grep 18789
```

**Salida esperada:**
```
LISTEN  0  128  127.0.0.1:18789  0.0.0.0:*  users:(("node",pid=1234,fd=3))
```

!!! danger "Si ves `0.0.0.0:18789`"
    Significa que está escuchando en todas las interfaces. Revisa la configuración en `~/.openclaw/openclaw.json` y asegúrate de que `gateway.host` es `"127.0.0.1"`. **No continúes hasta que esto esté correcto.**

### Probar el agente

```bash
# En otra terminal, enviar un mensaje de prueba
openclaw agent --message "Hola, ¿cuál es tu nombre?"
```

Detén el Gateway con `Ctrl+C`.

---

## Ejecutar como servicio systemd (con hardening)

### Crear archivo de servicio

```bash
sudo nano /etc/systemd/system/openclaw.service
```

```ini
# ============================================================
# OpenClaw Systemd Service - Con Hardening Completo
# Referencia: https://www.freedesktop.org/software/systemd/man/systemd.exec.html
# ============================================================

[Unit]
Description=OpenClaw AI Agent Gateway
Documentation=https://docs.openclaw.ai/
After=network.target tailscaled.service
Wants=tailscaled.service
StartLimitBurst=5
StartLimitIntervalSec=300

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw

# --- Cargar variables de entorno ---
EnvironmentFile=/home/openclaw/.openclaw/.env
Environment=NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
Environment=OPENCLAW_NO_RESPAWN=1

# --- Comando de inicio ---
# IMPORTANTE: Primero encuentra la ruta correcta ejecutando: which openclaw
# OpenClaw Gateway (puerto por defecto: 18789)
ExecStart=/home/openclaw/.local/bin/openclaw gateway --port 18789

# Si usaste nvm, ejecuta: which openclaw para obtener la ruta correcta
# Ejemplo con nvm (ajusta la versión según tu instalación):
# ExecStart=/home/openclaw/.nvm/versions/node/v22.x.x/bin/node /home/openclaw/.nvm/versions/node/v22.x.x/lib/node_modules/openclaw/dist/cli.js gateway --port 18789

# --- Reinicio automático ---
Restart=on-failure
RestartSec=10

# ============================================================
# HARDENING SYSTEMD - Sandboxing del proceso
# ============================================================

# --- Proteger sistema de archivos ---
# Enfoque bare-metal: VPS dedicado + Tailscale VPN, sin Docker.
# Seguridad aplicada por exec-approvals allowlist + sudoers del SO.
ProtectSystem=full
ProtectHome=read-only
ReadWritePaths=/home/openclaw/openclaw/workspace
ReadWritePaths=/home/openclaw/openclaw/logs
ReadWritePaths=/home/openclaw/.openclaw
ReadWritePaths=/var/tmp/openclaw-compile-cache
ReadWritePaths=/var/cache/apt
ReadWritePaths=/var/lib/apt
ReadWritePaths=/var/lib/dpkg
ReadWritePaths=/var/log/apt
ReadWritePaths=/tmp
PrivateTmp=true

# --- Control de privilegios ---
# NOTA: PrivateDevices, LockPersonality, RestrictRealtime fuerzan implícitamente
# NoNewPrivileges=true, así que también deben ser false para que sudo funcione
NoNewPrivileges=false
CapabilityBoundingSet=CAP_SETUID CAP_SETGID CAP_DAC_OVERRIDE CAP_FOWNER
AmbientCapabilities=
RestrictSUIDSGID=false
PrivateDevices=false
LockPersonality=false
RestrictRealtime=false

# --- Aislar red ---
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK

# --- Filtrado de syscalls ---
# Desactivado para compatibilidad con sudo/apt en VPS dedicado
# Seguridad aplicada por exec-approvals + sudoers
SystemCallArchitectures=native

# --- Proteger kernel (relajado para apt/dpkg) ---
ProtectKernelTunables=false
ProtectKernelModules=false
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectHostname=true
ProtectClock=true
# Prevenir ejecución de memoria escrita (JIT puede requerir desactivar esto)
# MemoryDenyWriteExecute=true

# --- Límites de recursos ---
# Máximo 50% CPU
CPUQuota=50%
# Máximo 2GB RAM
MemoryMax=2G
# Máximo 100 procesos/threads
TasksMax=100

# --- Logging ---
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
```

### Verificar ruta de OpenClaw antes de activar

```bash
# IMPORTANTE: Verifica la ruta correcta del binario
which openclaw

# Si la ruta es diferente a /home/openclaw/.local/bin/openclaw,
# edita el archivo de servicio y actualiza ExecStart con la ruta correcta
```

### Activar servicio

```bash
# Recargar configuración de systemd
sudo systemctl daemon-reload

# Habilitar inicio automático
sudo systemctl enable openclaw

# Iniciar servicio
sudo systemctl start openclaw

# Ver estado
sudo systemctl status openclaw
```

!!! info "Tiempo de inicio"
    El Gateway puede tardar **~2 minutos** en estar completamente operativo en un VPS de 4 GB.
    Si `systemctl status` muestra `active (running)` pero el puerto aún no responde, espera un poco.

**Salida esperada:**
```
● openclaw.service - OpenClaw AI Agent
     Loaded: loaded (/etc/systemd/system/openclaw.service; enabled; ...)
     Active: active (running) since ...
```

### Verificar logs

```bash
# Ver logs en tiempo real
sudo journalctl -u openclaw -f

# Ver últimos 50 logs
sudo journalctl -u openclaw -n 50
```

---

## Verificar hardening del servicio

systemd incluye una herramienta para analizar la seguridad de servicios:

```bash
systemd-analyze security openclaw.service
```

**Salida esperada:**
```
  NAME                                 DESCRIPTION                              EXPOSURE
✓ PrivateDevices=                      Service has no access to hardware devices    0.2
✓ PrivateTmp=                          Service has a private /tmp                   0.1
✓ ProtectSystem=                       Service has strict read-only access          0.1
...
→ Overall exposure level for openclaw.service: 2.4 OK
```

!!! success "Objetivo: puntuación < 5.0"
    Una puntuación de 10 es completamente inseguro. Menor a 5 es aceptable, menor a 3 es excelente.

---

## Acceder a OpenClaw

Desde tu dispositivo (con Tailscale):

### Opción 1: Port forwarding por SSH (RECOMENDADO)

```bash
# Reenviar puerto local 18789 al VPS
ssh -L 18789:127.0.0.1:18789 openclaw@<TU_TAILSCALE_IP>
```

Ahora accede en tu navegador: `http://localhost:18789`

#### Autenticarse en el Control UI

Al conectar por primera vez, el dashboard muestra **"unauthorized: gateway token missing"**. Pasa tu token por URL:

```
http://127.0.0.1:18789/?#token=TU_GATEWAY_TOKEN
```

Para obtener tu token:

```bash
openclaw config get gateway.auth.token
```

El token se guarda en el localStorage del navegador — solo necesitas hacerlo una vez por navegador.

#### Aliases recomendados para macOS/Linux

Añade estos a tu `~/.zshrc` o `~/.bashrc` en tu **máquina local** (no en el VPS):

```bash
# OPENCLAW
alias oclaw="ssh openclaw@<TU_TAILSCALE_IP>"
alias ooclaw='pkill -f "ssh.*18789.*openclaw" 2>/dev/null; sleep 0.5; ssh -f -L 18789:127.0.0.1:18789 openclaw@<TU_TAILSCALE_IP> sleep 9999 && sleep 1 && open http://127.0.0.1:18789'
alias closeclaw='pkill -f "ssh.*18789.*openclaw" 2>/dev/null; echo "Tunnel cerrado"'
```

| Alias | Descripción |
|-------|-------------|
| `oclaw` | SSH al VPS para administración |
| `ooclaw` | Abre dashboard (mata tunnel previo + crea nuevo + abre navegador) |
| `closeclaw` | Cierra el tunnel SSH |

!!! tip "Reemplaza `<TU_TAILSCALE_IP>`"
    Usa la IP Tailscale de tu VPS (ej: `100.x.x.x`). En Linux, reemplaza `open` con `xdg-open`.

### Opción 2: Tailscale Serve

```bash
# En el VPS - exponer puerto solo dentro de Tailscale
sudo tailscale serve --bg 18789
```

Esto expone el puerto solo dentro de tu red Tailscale en `https://tu-vps.tail1234.ts.net`

### Opción 3: Tailscale Funnel (NO RECOMENDADO)

!!! danger "No uses Funnel para OpenClaw"
    Tailscale Funnel expone el servicio a Internet. Esto viola el principio de aislamiento de esta guía.

---

## Verificación de seguridad final

```bash
echo "============================================"
echo "VERIFICACIÓN DE SEGURIDAD - OPENCLAW"
echo "============================================"
echo ""

echo "--- Puertos escuchando ---"
sudo ss -tlnp | grep -E "(18789|22)"
echo ""

echo "--- Verificar que OpenClaw NO está en 0.0.0.0 ---"
if sudo ss -tlnp | grep ":18789" | grep -q "0.0.0.0"; then
    echo "❌ PELIGRO: OpenClaw escucha en todas las interfaces!"
else
    echo "✅ OpenClaw solo escucha en localhost"
fi
echo ""

echo "--- Verificar permisos de .env ---"
perms=$(stat -c "%a" ~/.openclaw/.env 2>/dev/null)
if [ "$perms" = "600" ]; then
    echo "✅ .env tiene permisos 600"
else
    echo "❌ .env tiene permisos $perms (debe ser 600)"
fi
echo ""

echo "--- Verificar servicio systemd ---"
if systemctl is-active openclaw >/dev/null 2>&1; then
    echo "✅ Servicio openclaw activo"
else
    echo "❌ Servicio openclaw NO activo"
fi
echo ""

echo "--- Puntuación de seguridad systemd ---"
score=$(systemd-analyze security openclaw.service 2>/dev/null | grep "Overall" | awk '{print $NF}')
echo "Puntuación: $score"
echo ""

echo "============================================"
```

---

## Monitoreo básico

### Ver logs en tiempo real

```bash
# Logs de systemd
sudo journalctl -u openclaw -f

# Logs de la aplicación (si se configuraron)
tail -f ~/openclaw/logs/openclaw.log
```

### Detectar comportamiento anómalo

```bash
# Conexiones de red activas del proceso OpenClaw
sudo ss -tp | grep -E "(node|python)" | grep -v "127.0.0.1"

# Uso de CPU/memoria
ps aux | grep -E "(node|python)" | grep openclaw

# Archivos modificados recientemente en workspace
find ~/openclaw/workspace -mmin -60 -type f 2>/dev/null

# Verificar que no hay conexiones a IPs sospechosas
sudo ss -tp | grep -E "(node|python)" | awk '{print $5}' | cut -d: -f1 | sort -u
```

---

## Troubleshooting

### Errores comunes (referencia rápida)

| Error | Causa | Solución |
|-------|-------|----------|
| `400 status code (no body)` | El proveedor rechaza parámetros desconocidos | Añadir `"compat": { "supportsStore": false }` para Gemini. Revisar `reasoning` para Kimi. |
| `401 authentication_error` | API key inválida, User-Agent incorrecto, o `auth-profiles.json` obsoleto | Verificar key con curl (ver abajo). Añadir `"headers": { "User-Agent": "claude-code/0.1.0" }` para Kimi. Verificar `auth-profiles.json` (ver abajo). |
| `401` persiste tras arreglar API key | `auth-profiles.json` tiene una key obsoleta/inválida que sobreescribe env vars | Vaciar el archivo: `echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json` y reiniciar. |
| `404 Not Found` | Model ID o baseUrl incorrectos | Verificar model ID via endpoint `/v1/models` del proveedor. |
| `MissingEnvVarError` | `${VAR}` en config pero variable no definida | Añadir variable al override de systemd o `~/.openclaw/.env`. |
| `Config invalid: Unrecognized key` | Campo desconocido en openclaw.json | Eliminar el campo. Solo usar campos del schema documentado. |
| `tools.profile allowlist contains unknown entries` | El perfil referencia tools no instaladas | Warning inofensivo. Esas tools simplemente no se cargan. |
| `web_search not available` | Falta API key de búsqueda | Configurar `GEMINI_API_KEY` o `BRAVE_API_KEY` en `.env` o systemd override. |
| `EADDRINUSE: address already in use` | Puerto 18789 ya en uso | `sudo kill $(sudo lsof -t -i:18789) && sudo systemctl restart openclaw` |
| `Permission denied` accediendo a archivos | systemd hardening bloquea el path | Añadir `ReadWritePaths=/path/necesario` al archivo del servicio |
| `MemoryDenyWriteExecute` | V8 JIT necesita memoria ejecutable | Eliminar `MemoryDenyWriteExecute=true` del archivo del servicio |
| Errores `NAMESPACE` al arrancar | `SystemCallFilter` en override.conf | Eliminar líneas `SystemCallFilter` del override.conf — solo usar líneas `Environment` ahí |

### Verificar API keys directamente

Si el agente no responde o ves errores de autenticación, verifica tus API keys con curl:

```bash
# Verificar API key de Gemini
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash?key=TU_GOOGLE_API_KEY"

# Verificar API key de Kimi Coding
curl -s https://api.kimi.com/coding/v1/models \
  -H "x-api-key: TU_KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01"

# Test de mensaje Kimi Coding (end-to-end)
curl -s https://api.kimi.com/coding/v1/messages \
  -H "x-api-key: TU_KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"kimi-for-coding","max_tokens":256,"messages":[{"role":"user","content":"Hello"}]}'
```

### Comandos de diagnóstico

```bash
# Ver logs recientes (salida limpia)
sudo journalctl -u openclaw -n 30 --no-pager -o cat

# Seguir logs en tiempo real
sudo journalctl -u openclaw -f --no-pager -o cat

# Estado del servicio y config
openclaw status --all

# Validar config (AVISO: --fix sobreescribe configs manuales!)
openclaw doctor
```

!!! danger "NO ejecutar `openclaw doctor --fix` después de configurar manualmente"
    `openclaw doctor --fix` sobreescribe configuraciones manuales de proveedores (especialmente Kimi Coding) con templates por defecto que no funcionan. Usa `openclaw doctor` (sin `--fix`) para diagnosticar problemas, y luego corrígelos manualmente.

### Troubleshooting detallado

#### Error: "EADDRINUSE: address already in use"

**Causa**: El puerto 18789 ya está en uso.

**Solución**:
```bash
# Ver qué proceso usa el puerto
sudo ss -tlnp | grep 18789

# Matar el proceso si es necesario
sudo kill $(sudo lsof -t -i:18789)

# Reiniciar servicio
sudo systemctl restart openclaw
```

#### Error: "Permission denied" al acceder a archivos

**Causa**: El hardening de systemd bloquea acceso a paths no permitidos.

**Solución**:
```bash
# Añadir el path a ReadWritePaths en el servicio
sudo nano /etc/systemd/system/openclaw.service
# Añadir: ReadWritePaths=/path/necesario

sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

#### Error: "MemoryDenyWriteExecute" con Node.js

**Causa**: V8 (motor de JavaScript) necesita JIT que requiere memoria ejecutable.

**Solución**: Descomenta (elimina) la línea `MemoryDenyWriteExecute=true` en el servicio.

---

## Referencia rápida: comandos esenciales

### Gestión del servicio

```bash
# Reiniciar OpenClaw
sudo systemctl restart openclaw

# Ver estado del servicio
sudo systemctl status openclaw

# Detener OpenClaw
sudo systemctl stop openclaw

# Iniciar OpenClaw
sudo systemctl start openclaw
```

### Logs y depuración

```bash
# Ver logs recientes (últimas 50 líneas, salida limpia)
sudo journalctl -u openclaw -n 50 --no-pager -o cat

# Seguir logs en tiempo real (Ctrl+C para parar)
sudo journalctl -u openclaw -f --no-pager -o cat

# Ver log detallado del gateway (día actual)
cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | tail -100

# Filtrar logs solo errores
sudo journalctl -u openclaw --no-pager | grep -i error

# Validar config (NO usar --fix, sobreescribe configuraciones manuales)
openclaw doctor

# Estado completo
openclaw status --all
```

### Archivos de configuración

```bash
# Editar config principal (modelo, tools, canales)
nano ~/.openclaw/openclaw.json

# Editar personalidad e instrucciones del agente
nano ~/openclaw/workspace/SOUL.md

# Editar overrides de systemd (secrets, variables de entorno)
sudo systemctl edit openclaw
# — o directamente —
sudo nano /etc/systemd/system/openclaw.service.d/override.conf

# Después de editar overrides de systemd, siempre ejecutar:
sudo systemctl daemon-reload && sudo systemctl restart openclaw
```

### Secrets y API keys

```bash
# Guardar API keys de forma segura en systemd (recomendado para VPS)
sudo systemctl edit openclaw
# Añadir líneas como:
#   [Service]
#   Environment="MOONSHOT_API_KEY=sk-tu-key"
#   Environment="KIMI_API_KEY=sk-kimi-tu-key"
#   Environment="GOOGLE_API_KEY=tu-key"
#   Environment="GEMINI_API_KEY=tu-key"  # mismo valor que GOOGLE_API_KEY, para búsqueda web

# Referenciar en openclaw.json con: ${MOONSHOT_API_KEY}

# Wizard interactivo de secrets
openclaw secrets configure

# Auditar secrets configurados
openclaw secrets audit

# Verificar API keys directamente (ver Troubleshooting para más)
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash?key=TU_KEY"
```

### Gestión de modelos

```bash
# Cambiar modelo principal — editar openclaw.json:
#   "agents" → "defaults" → "model" → "primary"
# Ejemplos:
#   "moonshot/kimi-k2.5"      (Kimi — gratis)
#   "google/gemini-2.5-flash"  (Gemini — tier gratuito)

# Listar modelos disponibles
openclaw models list

# Reiniciar después de cambiar modelo
sudo systemctl restart openclaw
```

### Gestión de skills

```bash
# Listar skills instalados y su estado
openclaw skills list

# Instalar un skill desde ClawHub
npx playbooks add skill openclaw/skills --skill <nombre-skill>

# Los skills se instalan en:
ls ~/.agents/skills/

# Después de instalar un skill, verificar dependencias npm:
cd ~/.agents/skills/<nombre-skill> && npm install

# Eliminar un skill
rm -rf ~/.agents/skills/<nombre-skill>
```

### Red y conectividad

```bash
# Probar SMTP saliente (envío de email)
nc -zv smtp.gmail.com 587 -w 5

# Probar IMAP saliente (lectura de email)
nc -zv imap.gmail.com 993 -w 5

# Ver qué puerto usa el gateway de OpenClaw
sudo ss -tlnp | grep 18789

# Matar proceso huérfano del gateway (si restart falla)
sudo kill $(sudo lsof -t -i:18789)
```

### Salud y seguridad

```bash
# Ejecutar doctor de OpenClaw (diagnosticar — NO usar --fix)
openclaw doctor

# Auditoría de seguridad
openclaw security audit

# Reporte de estado completo
openclaw status --all

# Verificar permisos de archivos
ls -la ~/.openclaw/
# Debe ser: drwx------ (700) para el directorio
# Debe ser: -rw------- (600) para openclaw.json
```

!!! tip "Flujo de trabajo para cambios de configuración"
    El flujo típico para cualquier cambio de configuración es:

    1. Editar el archivo (`nano ~/.openclaw/openclaw.json`)
    2. Reiniciar el servicio (`sudo systemctl restart openclaw`)
    3. Revisar logs (`sudo journalctl -u openclaw -n 20 --no-pager`)
    4. Probar vía Telegram (`/new` → enviar un mensaje)

---

## Fixes probados en campo: lo que la documentación no dice

!!! success "Fixes aplicados a openclaw.json tras testing en producción"
    Estos problemas se descubrieron durante el despliegue real y no son obvios leyendo solo la documentación oficial.

    **1. `web_search` no funcionaba — 3 campos obligatorios faltaban:**

    | Campo | Por qué es necesario |
    |-------|---------------------|
    | `tools.web.search.enabled = true` | No se asume — hay que ponerlo explícitamente |
    | `tools.web.search.gemini.model = "gemini-2.5-flash"` | La búsqueda con Gemini requiere un modelo explícito |
    | `tools.web.fetch.enabled = true` | Habilita `web_fetch` para leer páginas web |

    **2. La `apiKey` de búsqueda estaba mal anidada:**

    ```
    MAL:   tools.web.search.apiKey = "..."
    BIEN:  tools.web.search.gemini.apiKey = "..."   (bajo el nombre del provider)
    ```

    **3. Streaming en Telegram para mejor UX:**

    `telegram.streaming = "partial"` — envía respuestas progresivas en vez de esperar a la respuesta completa. Nota: el campo correcto es `streaming`, NO `streamMode` (que causa error de validación del schema). `openclaw doctor` lo auto-corrige.

    **4. Validación de schema — campos que NO existen:**

    Estos campos causan errores `Config invalid`: `sendOptions`, `requestOptions`, `passthrough`, `extraBody`, `streamMode` (campo correcto: `streaming`).

    **5. `daemon-reload` es obligatorio antes de restart:**

    Después de editar systemd overrides (`sudo systemctl edit openclaw`), siempre ejecuta `sudo systemctl daemon-reload` antes de `sudo systemctl restart openclaw`. Sin daemon-reload, las nuevas variables de entorno NO se aplican.

!!! info "Nuestra config vs configs populares de la comunidad"
    Tras comparar con configuraciones de producción de la comunidad (fuentes abajo), estas son las diferencias clave y nuestra justificación:

    | Ajuste | Esta guía | Común en producción | Nuestra justificación |
    |--------|----------|--------------------|-----------------------|
    | `tools.profile` | `"full"` + `deny: ["gateway"]` | `"full"` | El perfil `coding` tiene un bug donde `web_search` no se habilita correctamente — usar `full` + `deny` |
    | `maxConcurrent` | `1` | `4` típico | Conservador para VPS de 4GB — aumentar a 2-4 para 8GB+ |
    | `heartbeat.model` | No configurado | Modelo barato cada 30m | Opcional — añadir si quieres check-ins proactivos del agente |
    | `subagents.model` | Hereda primary | Modelo diferente (más barato) | Ahorro de costes — usar DeepSeek V3 o Flash Lite para subagentes |
    | `telegram.dmPolicy` | `"allowlist"` | `"pairing"` | Seguridad: `allowlist` es más estricto — `pairing` permite a cualquiera solicitar acceso |
    | `telegram.streaming` | `"partial"` | Varía | Mejor UX — respuestas progresivas (el campo es `streaming`, NO `streamMode`) |

    **Para añadir heartbeats** (check-ins proactivos del agente cada 30 minutos):
    ```json
    "heartbeat": {
      "every": "30m",
      "model": "google/gemini-2.5-flash-lite"
    }
    ```

    **Para usar un modelo más barato en subagentes:**
    ```json
    "subagents": {
      "maxConcurrent": 3,
      "model": "deepseek/deepseek-chat"
    }
    ```

    **Fuentes consultadas:** [digitalknk production config](https://gist.github.com/digitalknk), [MoltFounders annotated reference](https://github.com/MoltFounders), [VelvetShark multi-model routing guide](https://velvetshark.com), [docs.openclaw.ai/tools/web](https://docs.openclaw.ai/tools/web), [docs.openclaw.ai/channels/telegram](https://docs.openclaw.ai/channels/telegram), [GitHub Issue #23058](https://github.com/openclaw/openclaw/issues/23058)

---

## Resumen

| Configuración | Estado |
|--------------|--------|
| Node.js instalado y verificado | ✅ |
| OpenClaw clonado | ✅ |
| .env con chmod 600 | ✅ |
| HOST=127.0.0.1 | ✅ |
| Skills con allowlist | ✅ |
| http_client con allowlist | ✅ |
| Herramientas restringidas via profile | ✅ |
| Servicio systemd configurado | ✅ |
| Hardening systemd aplicado | ✅ |
| Puntuación seguridad < 5.0 | ✅ |

---

## Rollback y desinstalación

### Detener y deshabilitar OpenClaw

```bash
# Detener el servicio
sudo systemctl stop openclaw

# Deshabilitar inicio automático
sudo systemctl disable openclaw

# Verificar que está detenido
sudo systemctl status openclaw
```

### Desinstalar OpenClaw

```bash
# Eliminar el paquete global de npm
npm uninstall -g openclaw

# Eliminar configuración (OPCIONAL - contiene secrets)
rm -rf ~/.openclaw

# Eliminar workspace y scripts (OPCIONAL - puede contener datos)
rm -rf ~/openclaw

# Eliminar servicio systemd
sudo rm /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload
```

!!! warning "Backup antes de eliminar"
    Antes de eliminar `~/.openclaw` o `~/openclaw`, asegúrate de tener un backup de:

    - `~/.openclaw/.env` (API keys)
    - `~/.openclaw/openclaw.json` (configuración)
    - `~/openclaw/workspace/` (datos de trabajo)

### Desinstalar Node.js (si ya no es necesario)

```bash
# Si usaste nvm
nvm deactivate
nvm uninstall 22

# Eliminar nvm completamente (opcional)
rm -rf ~/.nvm
# Luego elimina las líneas de nvm en ~/.bashrc
```

### Revertir hardening de systemd

El servicio systemd ya fue eliminado. No quedan cambios residuales de hardening.

### Verificar desinstalación completa

```bash
echo "=== Verificación de desinstalación ==="

# OpenClaw
which openclaw 2>/dev/null && echo "❌ OpenClaw aún instalado" || echo "✅ OpenClaw eliminado"

# Servicio systemd
[ -f /etc/systemd/system/openclaw.service ] && echo "❌ Servicio systemd existe" || echo "✅ Servicio eliminado"

# Configuración
[ -d ~/.openclaw ] && echo "⚠️  ~/.openclaw existe (eliminar manualmente si no se necesita)" || echo "✅ Configuración eliminada"

# Workspace
[ -d ~/openclaw ] && echo "⚠️  ~/openclaw existe (eliminar manualmente si no se necesita)" || echo "✅ Workspace eliminado"

echo "==================================="
```

---

**Siguiente:** [6. APIs de LLM](06-llm-apis.md) — Comparativa y recomendaciones de modelos.
