# 5. Instalar OpenClaw

> **TL;DR**: Instalar Node.js 22+, configurar OpenClaw con el Gateway daemon, aplicar permisos mínimos y ejecutar como servicio systemd con sandboxing completo.

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
    │   └── skills/              # Skills instalados
    └── credentials/             # Credenciales OAuth (si se usa)

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

### Instalar Docker (requerido para sandbox)

Docker es necesario para el modo sandbox `all` — la configuración de seguridad recomendada:

```bash
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
├── workspace/
│   ├── SOUL.md             # Identidad y límites del agente
│   ├── TOOLS.md            # Configuración de herramientas
│   └── skills/             # Skills instalados
└── credentials/            # Credenciales (si se usa OAuth)

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
        "primary": "kimi-coding/k2p5"
      },
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "all"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "tools": {
    "profile": "coding",
    "allow": ["group:web"],
    "deny": ["group:automation", "process"]
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token"
    },
    "tls": {},
    "tailscale": {
      "mode": "off"
    },
    "nodes": {
    }
  }
}
```

!!! danger "Configuración de seguridad crítica"
    - `bind: "loopback"` — Solo escucha en localhost (nunca `0.0.0.0`)
    - `sandbox.mode: "all"` — **Toda** ejecución de herramientas containerizada (nivel más seguro)
    - `auth.mode: "token"` — Acceso al Gateway requiere token de autenticación
    - `session.dmScope: "per-channel-peer"` — Aísla sesiones DM para prevenir filtración de contexto
    - `tls: {}` — TLS habilitado con valores por defecto

!!! warning "Eliminado en v2026.3.x"
    Las claves `dmPolicy`, `security` y `tools.blocked` a nivel raíz **no son reconocidas** por OpenClaw 2026.3.x. La política de DM se configura por canal cuando los añades. Ejecuta `openclaw doctor` para validar tu config.

!!! info "Sandbox 'all' vs 'always'"
    A partir de OpenClaw v2026.2.x, el modo `"all"` reemplaza a `"always"` y containeriza **toda** ejecución de herramientas (incluyendo el hilo principal). Es el modo más seguro para producción.

### Configurar credenciales con SecretRef (RECOMENDADO)

A partir de OpenClaw v2026.3.x, el mecanismo **SecretRef** permite gestionar credenciales de forma segura sin archivos `.env` en texto plano. Soporta hasta 64 targets.

```bash
# Añadir API key de forma segura (se almacena cifrada)
openclaw secrets set ANTHROPIC_API_KEY
# Te pedirá el valor de forma interactiva (no se muestra en pantalla)

# Verificar que se guardó
openclaw secrets list

# Usar en openclaw.json con SecretRef
```

En `openclaw.json`, referencia los secrets así:

```json
{
  "agent": {
    "model": "anthropic/claude-sonnet-4-5",
    "apiKey": { "$secretRef": "ANTHROPIC_API_KEY" }
  }
}
```

!!! success "SecretRef vs .env"
    | Característica | SecretRef | .env |
    |---|---|---|
    | Almacenamiento | Cifrado en disco | Texto plano |
    | Riesgo de prompt injection | Bajo | Alto (agente puede leer el archivo) |
    | Filtración en shell history | No | Sí (si usas `export`) |
    | Rotación | `openclaw secrets set` | Editar archivo manualmente |

### Alternativa: Archivo .env (método legacy)

Si prefieres el método tradicional o tu versión de OpenClaw no soporta SecretRef:

```bash
nano ~/openclaw/.env
```

```bash
# ============================================================
# OpenClaw Environment Variables
# NUNCA versionar este archivo - chmod 600
# ============================================================

# --- API Keys ---
# Usa solo UNA de estas opciones

# Opción 1: Anthropic (recomendado)
ANTHROPIC_API_KEY=sk-ant-...

# Opción 2: OpenAI
# OPENAI_API_KEY=sk-...

# Opción 3: NVIDIA NIM (Kimi K2.5 gratis)
# NVIDIA_API_KEY=nvapi-...

# --- Canales (opcional) ---
# TELEGRAM_BOT_TOKEN=...
# DISCORD_BOT_TOKEN=...
# SLACK_BOT_TOKEN=...

# --- Búsqueda web (recomendado) ---
# BRAVE_SEARCH_API_KEY=...
```

**Proteger el archivo:**

```bash
chmod 600 ~/openclaw/.env
chown openclaw:openclaw ~/openclaw/.env

# Verificar permisos
ls -la ~/openclaw/.env
```

**Salida esperada:**
```
-rw------- 1 openclaw openclaw 512 Feb  1 10:00 /home/openclaw/openclaw/.env
```

!!! warning "Limitaciones del archivo .env"
    Los archivos `.env` en texto plano son vulnerables a:

    - **Prompt injection** — un agente comprometido puede intentar leer el archivo
    - **Filtración en logs** — las variables se expanden en shell history
    - **Acceso por otros procesos** — cualquier proceso del usuario puede leerlo

    Usa **SecretRef** cuando sea posible.

### Configurar SOUL.md (identidad del agente)

OpenClaw usa archivos Markdown para configurar la identidad del agente:

```bash
nano ~/.openclaw/workspace/SOUL.md
```

```markdown
# OpenClaw Assistant

## Identidad
Eres un asistente de desarrollo y automatización que opera en un VPS aislado.

## Límites estrictos de comportamiento

### Filesystem
- Solo acceder a archivos dentro de `/home/openclaw/openclaw/workspace`
- No eliminar archivos recursivamente (rm -rf)
- No modificar permisos de archivos del sistema
- No acceder a `/home/openclaw/.ssh`, `/home/openclaw/.env`, `/etc`, `/var`

### Ejecución
- No ejecutar comandos como root/sudo
- No instalar software sin aprobación explícita
- No modificar configuración del sistema

### Comunicación
- No enviar emails sin confirmación explícita del usuario
- No hacer commits/push a repositorios sin revisión
- No llamar a APIs no incluidas en la allowlist

### Datos sensibles
- No exponer API keys, tokens o credenciales en respuestas
- No almacenar información sensible en logs
- Redactar cualquier secret que aparezca en outputs

## Tono
Profesional, conciso, técnico. Responde en español por defecto.
```

!!! info "Archivos SOUL, TOOLS y AGENTS"
    OpenClaw inyecta automáticamente estos archivos Markdown en el contexto del agente:

    - `SOUL.md` — Identidad y restricciones del agente
    - `TOOLS.md` — Configuración de herramientas disponibles
    - `AGENTS.md` — Definición de agentes especializados

### Configurar TOOLS.md (herramientas)

```bash
nano ~/.openclaw/workspace/TOOLS.md
```

```markdown
# Configuración de Herramientas

## Herramientas habilitadas

### Filesystem
- **Paths permitidos**: `/home/openclaw/openclaw/workspace`
- **Operaciones permitidas**: read, write, list, create_directory
- **Operaciones bloqueadas**: delete_recursive, change_permissions, symlinks

### Git
- **Operaciones permitidas**: clone, status, diff, log, branch, checkout
- **Operaciones bloqueadas**: push, force-push, reset --hard, clean

### HTTP Client
- **Dominios permitidos**:
  - api.anthropic.com
  - api.openai.com
  - integrate.api.nvidia.com
  - api.github.com
  - api.telegram.org
- **Dominios bloqueados**: *.onion, localhost, rangos privados (10.*, 192.168.*, 169.254.*)

## Herramientas deshabilitadas

### Shell (bash/exec)
DESHABILITADO - Riesgo de ejecución arbitraria de comandos.

### Browser
DESHABILITADO - Usar http_client para requests HTTP.

### Canvas/Nodes
DESHABILITADO - No requerido para este deployment.
```

### Configurar sandbox en openclaw.json

Edita la configuración para forzar sandbox y limitar herramientas:

```bash
nano ~/.openclaw/openclaw.json
```

Añade o modifica la sección de sandbox:

```json
{
  "agents": {
    "defaults": {
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "all",
        "allowedTools": [
          "bash",
          "read",
          "write",
          "edit"
        ],
        "blockedTools": [
          "browser",
          "canvas",
          "nodes",
          "cron",
          "gateway"
        ]
      }
    }
  }
}
```

!!! warning "Sandbox mode 'all' requiere Docker"
    El modo `all` containeriza toda la ejecución de herramientas en Docker — es el más seguro. **Docker debe estar instalado** o el agente fallará con: `Sandbox mode requires Docker, but the "docker" command was not found`.

    Instalar Docker:

    ```bash
    sudo apt install -y docker.io
    sudo usermod -aG docker openclaw
    # Reconectar SSH para que el grupo tome efecto
    ```

    Si no puedes usar Docker, usa `"mode": "off"` y añade restricciones compensatorias de herramientas:

    ```json
    "sandbox": { "mode": "off" },
    "tools": {
      "profile": "coding",
      "allow": ["group:web"],
      "deny": ["group:automation", "process"]
    }
    ```

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

!!! note "El wizard `openclaw channels add`"
    El wizard interactivo (`openclaw channels add`) puede no guardar la config correctamente. Si falla, usa el método manual de JSON descrito arriba — es más fiable.

---

## Ejecutar OpenClaw (prueba manual)

### Verificar que escucha solo en localhost

```bash
# Ejecutar el Gateway manualmente con variables de entorno cargadas en línea
# Esto evita filtrar secrets al entorno del shell y a /proc/*/environ
env $(grep -v '^#' ~/openclaw/.env | xargs) openclaw gateway --port 18789 --verbose
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
EnvironmentFile=/home/openclaw/openclaw/.env
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
# Sistema de archivos raíz en solo lectura
ProtectSystem=strict
# Home de otros usuarios no accesible
ProtectHome=read-only
# Paths específicos con escritura permitida
ReadWritePaths=/home/openclaw/openclaw/workspace
ReadWritePaths=/home/openclaw/openclaw/logs
ReadWritePaths=/home/openclaw/.openclaw
ReadWritePaths=/var/tmp/openclaw-compile-cache
# Temp privado (aislado)
PrivateTmp=true

# --- Restringir capacidades ---
# No permitir ganar nuevos privilegios
NoNewPrivileges=true
# Sin capacidades especiales
CapabilityBoundingSet=
AmbientCapabilities=

# --- Aislar red ---
# Solo permitir IPv4, IPv6, Unix sockets y Netlink (necesario para listar interfaces)
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK

# --- Restringir syscalls ---
# Filtro relajado — @system-service + @debug es necesario para el canal de Telegram
# El filtro estricto (sin @debug) causa core dumps cuando Telegram conecta
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources @mount @clock @reboot @swap @raw-io @cpu-emulation
# Solo arquitectura nativa
SystemCallArchitectures=native

# --- Proteger kernel ---
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true

# --- Aislamiento adicional ---
# Sin acceso a dispositivos físicos
PrivateDevices=true
# Hostname aislado
ProtectHostname=true
# Reloj del sistema protegido
ProtectClock=true
# Sin scheduling en tiempo real
RestrictRealtime=true
# Sin binarios SUID/SGID
RestrictSUIDSGID=true
# Bloquear cambios de personalidad
LockPersonality=true
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
perms=$(stat -c "%a" ~/openclaw/.env 2>/dev/null)
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

### Error: "EADDRINUSE: address already in use"

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

### Error: "Permission denied" al acceder a archivos

**Causa**: El hardening de systemd bloquea acceso a paths no permitidos.

**Solución**:
```bash
# Añadir el path a ReadWritePaths en el servicio
sudo nano /etc/systemd/system/openclaw.service
# Añadir: ReadWritePaths=/path/necesario

sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

### Error: "MemoryDenyWriteExecute" con Node.js

**Causa**: V8 (motor de JavaScript) necesita JIT que requiere memoria ejecutable.

**Solución**: Descomenta (elimina) la línea `MemoryDenyWriteExecute=true` en el servicio.

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
| shell deshabilitado | ✅ |
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

    - `~/openclaw/.env` (API keys)
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
