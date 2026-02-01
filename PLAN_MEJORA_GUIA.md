# Plan de Mejora: Guía OpenClaw en VPS

> **Objetivo**: Transformar la guía actual en una referencia de nivel profesional que cumpla con estándares de la industria (CIS Benchmarks, Tailscale Hardening, OWASP Agentic Top 10 2026) y sea accesible para desarrolladores de todos los niveles.

---

## Índice

1. [Resumen Ejecutivo](#1-resumen-ejecutivo)
2. [Principios de Diseño](#2-principios-de-diseño)
3. [Mejoras de Contenido Técnico](#3-mejoras-de-contenido-técnico)
4. [Mejoras de Estructura y UX](#4-mejoras-de-estructura-y-ux)
5. [Nuevas Secciones Requeridas](#5-nuevas-secciones-requeridas)
6. [Checklist de Calidad](#6-checklist-de-calidad)
7. [Instrucciones para el Agente](#7-instrucciones-para-el-agente)

---

## 1. Resumen Ejecutivo

### Estado Actual
- **Puntuación global**: 7.0/10
- **Fortalezas**: Estructura clara, flujo lógico, sin redundancia
- **Debilidades**: SSH hardening incompleto, scripts sin verificar, falta sandboxing, OWASP Agentic no cubierto

### Estado Objetivo
- **Puntuación objetivo**: 9.5/10
- **Conformidad CIS Benchmark Ubuntu 24.04 L1**: 100%
- **Conformidad Tailscale Hardening**: 100%
- **Conformidad OWASP Agentic Top 10 2026**: 90%+

---

## 2. Principios de Diseño

### 2.1 Usabilidad

| Principio | Implementación |
|-----------|----------------|
| **Copy-paste friendly** | Todos los comandos deben funcionar al copiar. Sin placeholders ambiguos |
| **Placeholders consistentes** | Usar formato `<PLACEHOLDER>` con nombres descriptivos en MAYÚSCULAS |
| **Verificación en cada paso** | Después de cada acción crítica, comando para verificar éxito |
| **Puntos de no retorno** | Advertencia clara antes de acciones irreversibles |
| **Recuperación de errores** | Qué hacer si algo falla en cada sección |

### 2.2 Claridad

| Principio | Implementación |
|-----------|----------------|
| **Audiencia explícita** | Indicar nivel requerido al inicio de cada sección |
| **Glosario inline** | Explicar términos técnicos la primera vez que aparecen |
| **Diagramas ASCII** | Un diagrama por sección mostrando estado antes/después |
| **Ejemplos reales** | Outputs esperados para cada comando de verificación |
| **TL;DR por sección** | Resumen de 2-3 líneas al inicio de cada archivo |

### 2.3 Seguridad

| Principio | Implementación |
|-----------|----------------|
| **Defense in depth** | Múltiples capas de protección documentadas |
| **Fail secure** | Defaults seguros, opt-in para features peligrosas |
| **Verify then trust** | Verificar integridad de todo lo descargado |
| **Least privilege** | Documentar exactamente qué permisos y por qué |
| **Audit trail** | Cómo verificar que cada control está activo |

### 2.4 Mantenibilidad

| Principio | Implementación |
|-----------|----------------|
| **Versionado** | Indicar versiones de software probadas |
| **Fecha de última verificación** | En cada archivo |
| **Enlaces verificables** | URLs que se pueden comprobar automáticamente |
| **Sin dependencias ocultas** | Listar todo lo que se instala |

---

## 3. Mejoras de Contenido Técnico

### 3.1 Archivo: `docs/index.md`

#### Añadir

```markdown
## Requisitos de conocimiento

| Concepto | Nivel requerido | Dónde aprenderlo |
|----------|-----------------|------------------|
| Terminal/Bash | Básico | [Linux Journey](https://linuxjourney.com/) |
| SSH | Básico | Sección 3 de esta guía |
| Redes (IP, puertos) | Conceptual | [Networking 101](https://www.digitalocean.com/community/tutorials/understanding-ip-addresses-subnets-and-cidr-notation-for-networking) |
| VPN | Conceptual | Se explica en sección 4 |

## Tiempo estimado

| Sección | Tiempo |
|---------|--------|
| Preparación | 15 min |
| Contratar VPS | 10 min |
| Seguridad sistema | 30 min |
| Acceso privado | 20 min |
| Instalar OpenClaw | 25 min |
| APIs LLM | 10 min |
| **Total** | ~2 horas |
```

#### Modificar

- Actualizar diagrama de arquitectura para incluir capas de seguridad (firewall, Tailscale, sandboxing)
- Añadir sección "Qué NO cubre esta guía" (HA, backups automatizados, CI/CD)

---

### 3.2 Archivo: `docs/01-preparacion.md`

#### Añadir

```markdown
## Verificar herramientas locales

Antes de empezar, verifica que tienes las herramientas necesarias:

\`\`\`bash
# macOS/Linux
ssh -V          # Debe mostrar OpenSSH 8.0+
curl --version  # Cualquier versión reciente
gpg --version   # Para verificar firmas (opcional pero recomendado)
\`\`\`

## Crear passphrase segura

Para la clave SSH, usa una passphrase de al menos 20 caracteres:

\`\`\`bash
# Generar passphrase aleatoria (guárdala en tu gestor de contraseñas)
openssl rand -base64 24
\`\`\`
```

#### Modificar

- Expandir sección de límites de gasto con capturas de pantalla o descripciones paso a paso
- Añadir verificación de que la clave SSH se generó correctamente

---

### 3.3 Archivo: `docs/02-vps.md`

#### Añadir

```markdown
## Verificar imagen del sistema

Después del primer acceso, verifica la integridad básica:

\`\`\`bash
# Verificar que es Ubuntu oficial
cat /etc/os-release | grep -E "^(NAME|VERSION)="

# Verificar que no hay usuarios sospechosos
cat /etc/passwd | grep -E ":/bin/(bash|sh)$"

# Verificar procesos en ejecución
ps aux --sort=-%mem | head -20
\`\`\`

## Configurar timezone y locale

\`\`\`bash
sudo timedatectl set-timezone Europe/Madrid  # Ajusta a tu zona
sudo locale-gen es_ES.UTF-8  # Opcional
\`\`\`
```

---

### 3.4 Archivo: `docs/03-seguridad-sistema.md` ⚠️ CRÍTICO

#### Reescribir sección SSH completa

```markdown
## Asegurar SSH (CIS Benchmark 5.2 completo)

### Crear configuración hardened

\`\`\`bash
# Backup de configuración original
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)

# Crear configuración segura
sudo tee /etc/ssh/sshd_config.d/hardening.conf << 'EOF'
# === CIS Benchmark Ubuntu 24.04 - Sección 5.2 ===

# 5.2.1 - Permisos del archivo sshd_config
# (se aplica con chmod después)

# 5.2.2 - Permisos de claves privadas SSH
# (se aplica con chmod después)

# 5.2.4 - Ciphers seguros
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# 5.2.5 - MACs seguros
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# 5.2.6 - Key Exchange seguros
KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256

# 5.2.7 - Banner de advertencia
Banner /etc/issue.net

# 5.2.8 - Logging detallado
LogLevel VERBOSE

# 5.2.9 - Desactivar X11 forwarding
X11Forwarding no

# 5.2.10 - MaxAuthTries
MaxAuthTries 4

# 5.2.11 - Ignorar rhosts
IgnoreRhosts yes

# 5.2.12 - Desactivar autenticación basada en host
HostbasedAuthentication no

# 5.2.13 - Desactivar login root
PermitRootLogin no

# 5.2.14 - Desactivar contraseñas vacías
PermitEmptyPasswords no

# 5.2.15 - Desactivar environment de usuario
PermitUserEnvironment no

# 5.2.16 - Solo protocolo 2 (default en OpenSSH moderno)
Protocol 2

# 5.2.17 - Timeout de conexión
ClientAliveInterval 300
ClientAliveCountMax 3

# 5.2.18 - Tiempo de gracia para login
LoginGraceTime 60

# 5.2.19 - Limitar usuarios
AllowUsers openclaw

# 5.2.20 - MaxStartups (anti-DoS)
MaxStartups 10:30:60

# 5.2.21 - MaxSessions
MaxSessions 10

# 5.2.22 - Desactivar autenticación por contraseña
PasswordAuthentication no
ChallengeResponseAuthentication no

# 5.2.23 - Usar solo claves públicas
PubkeyAuthentication yes

# Adicional: Solo escuchar en Tailscale (se configura después)
# ListenAddress 100.x.x.x
EOF
\`\`\`

### Crear banner de advertencia

\`\`\`bash
sudo tee /etc/issue.net << 'EOF'
***************************************************************************
                            SISTEMA PRIVADO

  El acceso no autorizado está prohibido. Todas las actividades son
  monitoreadas y registradas. El uso de este sistema implica aceptación
  de las políticas de seguridad.
***************************************************************************
EOF
\`\`\`

### Aplicar permisos CIS

\`\`\`bash
# 5.2.1 - Permisos sshd_config
sudo chmod 600 /etc/ssh/sshd_config
sudo chown root:root /etc/ssh/sshd_config

# 5.2.2 - Permisos claves privadas del host
sudo chmod 600 /etc/ssh/ssh_host_*_key
sudo chown root:root /etc/ssh/ssh_host_*_key

# 5.2.3 - Permisos claves públicas del host
sudo chmod 644 /etc/ssh/ssh_host_*_key.pub
sudo chown root:root /etc/ssh/ssh_host_*_key.pub
\`\`\`

### Verificar configuración antes de aplicar

\`\`\`bash
# CRÍTICO: Verificar sintaxis antes de reiniciar
sudo sshd -t

# Si no hay errores, reiniciar
sudo systemctl restart sshd

# Verificar que está corriendo
sudo systemctl status sshd
\`\`\`

### Verificar controles aplicados

\`\`\`bash
# Script de verificación
echo "=== Verificación CIS SSH ==="
echo -n "PasswordAuthentication: "; sudo sshd -T | grep -i passwordauthentication
echo -n "PermitRootLogin: "; sudo sshd -T | grep -i permitrootlogin
echo -n "MaxAuthTries: "; sudo sshd -T | grep -i maxauthtries
echo -n "X11Forwarding: "; sudo sshd -T | grep -i x11forwarding
echo -n "LogLevel: "; sudo sshd -T | grep -i loglevel
\`\`\`
```

#### Añadir sección de auditoría

```markdown
## Configurar auditoría básica (auditd)

\`\`\`bash
# Instalar auditd
sudo apt install -y auditd audispd-plugins

# Habilitar servicio
sudo systemctl enable auditd
sudo systemctl start auditd

# Reglas básicas de auditoría
sudo tee /etc/audit/rules.d/openclaw.rules << 'EOF'
# Monitorear cambios en archivos críticos
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /home/openclaw/.ssh -p wa -k ssh_keys

# Monitorear comandos sudo
-w /var/log/sudo.log -p wa -k sudo_log

# Monitorear cambios en openclaw
-w /home/openclaw/openclaw -p wa -k openclaw_changes
EOF

# Recargar reglas
sudo augenrules --load
sudo systemctl restart auditd
\`\`\`

### Verificar auditoría

\`\`\`bash
# Ver reglas activas
sudo auditctl -l

# Ver eventos recientes
sudo ausearch -ts recent
\`\`\`
```

#### Añadir sección de integridad

```markdown
## Monitoreo de integridad (AIDE)

\`\`\`bash
# Instalar AIDE
sudo apt install -y aide

# Configurar paths a monitorear
sudo tee -a /etc/aide/aide.conf.d/openclaw << 'EOF'
/home/openclaw/openclaw/config CONTENT_EX
/home/openclaw/openclaw/.env PERMS
/etc/ssh CONTENT_EX
EOF

# Inicializar base de datos (tarda unos minutos)
sudo aideinit

# Mover base de datos
sudo mv /var/lib/aide/aide.db.new /var/lib/aide/aide.db

# Verificar integridad (ejecutar periódicamente)
sudo aide --check
\`\`\`
```

---

### 3.5 Archivo: `docs/04-acceso-privado.md` ⚠️ CRÍTICO

#### Modificar instalación de Tailscale

```markdown
## Instalar Tailscale (con verificación)

### Opción A: Verificación manual (RECOMENDADO)

\`\`\`bash
# 1. Descargar script
curl -fsSL https://tailscale.com/install.sh -o /tmp/tailscale-install.sh

# 2. Verificar contenido (buscar comandos sospechosos)
less /tmp/tailscale-install.sh
# Busca: curl/wget a dominios no-tailscale, eval, base64 decode

# 3. Si todo parece correcto, ejecutar
sudo bash /tmp/tailscale-install.sh

# 4. Limpiar
rm /tmp/tailscale-install.sh
\`\`\`

### Opción B: Instalación desde repositorio APT (más seguro)

\`\`\`bash
# Añadir clave GPG de Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Añadir repositorio
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Instalar
sudo apt update
sudo apt install -y tailscale

# Verificar firma del paquete
apt-cache policy tailscale
\`\`\`
```

#### Cambiar ACLs de "opcional" a "obligatorio"

```markdown
## Configurar ACLs (OBLIGATORIO)

!!! danger "No saltes este paso"
    Sin ACLs, cualquier dispositivo en tu Tailnet puede acceder a cualquier otro.
    Esto viola el principio de zero-trust.

### ACL mínima recomendada

1. Ve a [login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls)
2. Reemplaza el contenido con:

\`\`\`json
{
  "acls": [
    // Solo tú puedes acceder al VPS
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:vps:*"]
    },
    // El VPS no puede iniciar conexiones (solo responder)
    {
      "action": "accept",
      "src": ["tag:vps"],
      "dst": ["autogroup:internet:*"]
    }
  ],
  "tagOwners": {
    "tag:vps": ["autogroup:owner"]
  },
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:vps"],
      "users": ["openclaw"]
    }
  ],
  "tests": [
    // Verificar que owner puede acceder al VPS
    {
      "src": "autogroup:owner",
      "accept": ["tag:vps:22", "tag:vps:3000"]
    },
    // Verificar que VPS no puede acceder a otros dispositivos
    {
      "src": "tag:vps",
      "deny": ["autogroup:owner:*"]
    }
  ]
}
\`\`\`

3. En el VPS, añade el tag:

\`\`\`bash
sudo tailscale up --advertise-tags=tag:vps --reset
\`\`\`
```

#### Añadir Tailnet Lock

```markdown
## Tailnet Lock (recomendado para máxima seguridad)

Tailnet Lock asegura que incluso si Tailscale (la empresa) fuera comprometida,
no podrían inyectar dispositivos maliciosos en tu red.

\`\`\`bash
# 1. Inicializar Tailnet Lock desde tu dispositivo principal (no el VPS)
tailscale lock init

# 2. Ver tu clave de firma
tailscale lock status

# 3. Firmar el VPS desde tu dispositivo principal
tailscale lock sign <NODE_KEY_DEL_VPS>
\`\`\`

!!! warning "Guarda las claves de recuperación"
    Si pierdes acceso a todos los dispositivos firmantes, perderás acceso a la red.
    Guarda las claves en un lugar seguro offline.
```

#### Añadir webhooks

```markdown
## Alertas con Webhooks

Recibe notificaciones cuando algo cambie en tu Tailnet:

1. Ve a [login.tailscale.com/admin/settings/webhooks](https://login.tailscale.com/admin/settings/webhooks)
2. Añade un webhook (Slack, Discord, o tu endpoint)
3. Selecciona eventos:
   - `nodeCreated` - Nuevo dispositivo
   - `nodeDeleted` - Dispositivo eliminado
   - `nodeApproved` - Dispositivo aprobado
   - `userCreated` - Nuevo usuario
```

---

### 3.6 Archivo: `docs/05-openclaw.md` ⚠️ CRÍTICO

#### Modificar instalación de Node.js

```markdown
## Instalar Node.js (con verificación)

### Opción A: Usando nvm (RECOMENDADO)

\`\`\`bash
# Verificar checksum del script nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh -o /tmp/nvm-install.sh
echo "Verificar visualmente el script:"
head -50 /tmp/nvm-install.sh
# Ejecutar si es correcto
bash /tmp/nvm-install.sh

# Recargar shell
source ~/.bashrc

# Instalar Node LTS
nvm install --lts
nvm use --lts

# Verificar
node --version
\`\`\`

### Opción B: Repositorio NodeSource

\`\`\`bash
# Descargar y verificar
curl -fsSL https://deb.nodesource.com/setup_lts.x -o /tmp/nodesource-setup.sh

# Verificar que el script solo añade repos de nodesource.com
grep -E "^(curl|wget)" /tmp/nodesource-setup.sh

# Si parece seguro
sudo -E bash /tmp/nodesource-setup.sh
sudo apt install -y nodejs
\`\`\`
```

#### Corregir servicio systemd

```markdown
## Ejecutar como servicio (systemd)

\`\`\`bash
sudo nano /etc/systemd/system/openclaw.service
\`\`\`

\`\`\`ini
[Unit]
Description=OpenClaw Agent
After=network.target tailscaled.service
Wants=tailscaled.service

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw/openclaw

# Cargar variables de entorno
EnvironmentFile=/home/openclaw/openclaw/.env

# Comando de inicio
ExecStart=/usr/bin/node /home/openclaw/openclaw/index.js
# o para Python:
# ExecStart=/usr/bin/python3 /home/openclaw/openclaw/main.py

# Reinicio automático
Restart=on-failure
RestartSec=10
StartLimitBurst=5
StartLimitIntervalSec=60

# === HARDENING SYSTEMD ===

# Proteger sistema de archivos
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/openclaw/openclaw/workspace
ReadWritePaths=/home/openclaw/openclaw/logs

# Restringir capacidades
NoNewPrivileges=true
CapabilityBoundingSet=
AmbientCapabilities=

# Aislar red (solo localhost y Tailscale)
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX

# Restringir syscalls
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources
SystemCallArchitectures=native

# Proteger kernel
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true

# Otros
PrivateTmp=true
PrivateDevices=true
ProtectHostname=true
ProtectClock=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
\`\`\`

### Verificar hardening

\`\`\`bash
# Analizar seguridad del servicio
systemd-analyze security openclaw.service

# Objetivo: puntuación < 5.0 (de 10, menor es mejor)
\`\`\`
```

#### Añadir rate limiting

```markdown
## Rate limiting para APIs

Protege contra uso excesivo (bugs o ataques):

### Opción A: Configuración en OpenClaw (si soportado)

\`\`\`yaml
# config/settings.yaml
rate_limiting:
  requests_per_minute: 30
  tokens_per_hour: 100000
  circuit_breaker:
    failures_threshold: 5
    recovery_time_seconds: 300
\`\`\`

### Opción B: Wrapper script

\`\`\`bash
# /home/openclaw/openclaw/rate-limit-wrapper.sh
#!/bin/bash

MAX_REQUESTS_PER_MINUTE=30
COUNTER_FILE="/tmp/openclaw_requests"

# Contar requests en el último minuto
current_minute=$(date +%Y%m%d%H%M)
count=$(grep -c "^$current_minute" "$COUNTER_FILE" 2>/dev/null || echo 0)

if [ "$count" -ge "$MAX_REQUESTS_PER_MINUTE" ]; then
    echo "Rate limit exceeded" >&2
    exit 1
fi

echo "$current_minute" >> "$COUNTER_FILE"

# Limpiar entradas antiguas (más de 2 minutos)
temp_file=$(mktemp)
tail -n 100 "$COUNTER_FILE" > "$temp_file"
mv "$temp_file" "$COUNTER_FILE"

# Ejecutar comando original
exec "$@"
\`\`\`
```

---

### 3.7 Archivo: `docs/06-llm-apis.md`

#### Añadir

```markdown
## Seguridad de API Keys

### Rotación de claves

Rota tus API keys cada 90 días:

1. Genera nueva key en el proveedor
2. Actualiza `.env` en el VPS
3. Reinicia el servicio: `sudo systemctl restart openclaw`
4. Verifica funcionamiento
5. Revoca la key antigua en el proveedor

### Monitoreo de uso anómalo

Configura alertas para detectar uso sospechoso:

| Proveedor | Configurar alertas |
|-----------|-------------------|
| OpenAI | Settings → Usage → Set up alerts |
| Anthropic | Settings → Alerts |

**Indicadores de compromiso:**
- Uso fuera de horario habitual
- Picos de tokens inusuales
- Requests desde IPs desconocidas (si el proveedor lo muestra)
```

---

### 3.8 Archivo: `docs/07-casos-uso.md`

#### Añadir ejemplos de output filtering

```markdown
## Prevenir filtración de datos (OWASP AA2)

### Configurar output filtering

Antes de que el agente envíe cualquier respuesta, filtra información sensible:

\`\`\`python
# filters/output_filter.py
import re

SENSITIVE_PATTERNS = [
    (r'sk-[a-zA-Z0-9]{32,}', '[REDACTED_API_KEY]'),           # OpenAI
    (r'sk-ant-[a-zA-Z0-9-]{32,}', '[REDACTED_API_KEY]'),      # Anthropic
    (r'ghp_[a-zA-Z0-9]{36}', '[REDACTED_GITHUB_TOKEN]'),      # GitHub
    (r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}', '[REDACTED_EMAIL]'),
    (r'\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b', '[REDACTED_CARD]'),
]

def filter_output(text: str) -> str:
    for pattern, replacement in SENSITIVE_PATTERNS:
        text = re.sub(pattern, replacement, text)
    return text
\`\`\`

### Configurar en skills.json

\`\`\`json
{
  "output_filtering": {
    "enabled": true,
    "filters": ["api_keys", "emails", "credit_cards", "ip_addresses"],
    "log_redactions": true
  }
}
\`\`\`
```

---

## 4. Mejoras de Estructura y UX

### 4.1 Formato consistente para cada archivo

Cada archivo `.md` debe seguir esta estructura:

```markdown
# N. Título de la sección

> **TL;DR**: Resumen de 2-3 líneas de lo que se logra en esta sección.

> **Tiempo estimado**: X minutos

> **Nivel requerido**: Principiante | Intermedio | Avanzado

## Prerrequisitos

- [ ] Paso anterior completado
- [ ] Herramienta X disponible

## Objetivos

Al terminar esta sección tendrás:
- Objetivo 1
- Objetivo 2

---

## Contenido principal

[...]

---

## Verificación

\`\`\`bash
# Comandos para verificar que todo está correcto
\`\`\`

**Salida esperada:**
\`\`\`
[ejemplo de output correcto]
\`\`\`

## Troubleshooting

### Error: "mensaje de error común"

**Causa**: Explicación
**Solución**: Pasos para resolver

---

## Resumen

| Configuración | Estado esperado |
|---------------|-----------------|
| Item 1 | ✅ Completado |
| Item 2 | ✅ Completado |

**Siguiente**: [N+1. Siguiente sección](0X-siguiente.md)
```

### 4.2 Sistema de placeholders

Usar formato consistente en toda la guía:

| Placeholder | Descripción | Ejemplo |
|-------------|-------------|---------|
| `<TU_IP_PUBLICA>` | IP pública del VPS | `203.0.113.50` |
| `<TU_IP_TAILSCALE>` | IP de Tailscale del VPS | `100.64.0.1` |
| `<TU_USUARIO>` | Usuario del VPS | `openclaw` |
| `<TU_API_KEY>` | API key del proveedor | `sk-...` |
| `<TU_DOMINIO>` | Dominio si aplica | `mi-vps.tail1234.ts.net` |

### 4.3 Admonitions consistentes

```markdown
!!! tip "Título"
    Consejo útil pero opcional

!!! info "Título"
    Información contextual

!!! warning "Título"
    Precaución importante

!!! danger "Título"
    Riesgo de seguridad o pérdida de acceso

!!! success "Título"
    Confirmación de paso completado

!!! example "Título"
    Ejemplo práctico
```

---

## 5. Nuevas Secciones Requeridas

### 5.1 Nueva: `docs/08-seguridad-agente.md`

Crear archivo nuevo cubriendo:

1. **OWASP Agentic Top 10 2026** - Explicación de cada riesgo y mitigación
2. **Guardrails técnicos** - No solo soul.yaml (sugerencias), sino controles enforced
3. **Sandbox del proceso** - systemd hardening, seccomp, AppArmor
4. **Monitoreo de comportamiento** - Detectar anomalías
5. **Respuesta a incidentes** - Qué hacer si el agente se comporta mal

### 5.2 Nueva: `docs/09-mantenimiento.md`

Crear archivo nuevo cubriendo:

1. **Actualizaciones** - Sistema, Tailscale, OpenClaw
2. **Rotación de secrets** - API keys, SSH keys
3. **Backups** - .env, config, workspace
4. **Monitoreo continuo** - Logs, métricas
5. **Disaster recovery** - Restaurar desde cero

### 5.3 Nueva: `docs/10-checklist-final.md`

Checklist consolidado de todos los controles:

```markdown
## Checklist de Seguridad

### Sistema operativo
- [ ] Usuario no-root creado
- [ ] SSH hardening CIS completo
- [ ] Firewall UFW activo
- [ ] Fail2ban configurado
- [ ] Actualizaciones automáticas
- [ ] Auditd configurado
- [ ] AIDE inicializado

### Red
- [ ] Tailscale instalado
- [ ] ACLs configuradas (no permit-all)
- [ ] SSH solo en interfaz Tailscale
- [ ] Puerto 22 público cerrado
- [ ] Tailnet Lock (opcional)
- [ ] Webhooks configurados (opcional)

### OpenClaw
- [ ] Ejecutando como usuario openclaw
- [ ] .env con chmod 600
- [ ] HOST=127.0.0.1
- [ ] Skills con allowlist
- [ ] http_client con allowlist
- [ ] shell deshabilitado
- [ ] systemd hardening aplicado

### APIs
- [ ] Límites de gasto configurados
- [ ] Alertas de uso configuradas
- [ ] Keys rotadas recientemente
```

### 5.4 Nueva: `docs/glosario.md`

Definiciones de términos técnicos usados en la guía.

---

## 6. Checklist de Calidad

### 6.1 Técnico

- [ ] Todos los comandos probados en Ubuntu 24.04 LTS limpio
- [ ] Scripts de verificación después de cada sección crítica
- [ ] CIS Benchmark L1 100% cubierto
- [ ] Tailscale hardening 100% cubierto
- [ ] OWASP Agentic Top 10 90%+ cubierto
- [ ] Sin `curl | sh` sin verificación
- [ ] Systemd service con hardening

### 6.2 Usabilidad

- [ ] TL;DR en cada sección
- [ ] Tiempo estimado en cada sección
- [ ] Nivel requerido especificado
- [ ] Placeholders consistentes
- [ ] Outputs esperados mostrados
- [ ] Troubleshooting en cada sección
- [ ] Links verificados

### 6.3 Mantenibilidad

- [ ] Versiones de software especificadas
- [ ] Fecha de última verificación
- [ ] Fuentes citadas (CIS, OWASP, Tailscale docs)

---

## 7. Instrucciones para el Agente

### Contexto

Eres un agente especializado en documentación técnica de seguridad. Tu tarea es mejorar la guía de instalación de OpenClaw en VPS siguiendo el plan detallado en este documento.

### Archivos a modificar

1. `docs/index.md` - Añadir requisitos de conocimiento, tiempo estimado
2. `docs/01-preparacion.md` - Añadir verificación de herramientas, passphrase
3. `docs/02-vps.md` - Añadir verificación de imagen, timezone
4. `docs/03-seguridad-sistema.md` - **REESCRIBIR** SSH hardening completo CIS
5. `docs/04-acceso-privado.md` - **MODIFICAR** instalación verificada, ACLs obligatorio
6. `docs/05-openclaw.md` - **MODIFICAR** Node.js verificado, systemd hardening
7. `docs/06-llm-apis.md` - Añadir rotación de keys, monitoreo
8. `docs/07-casos-uso.md` - Añadir output filtering

### Archivos a crear

9. `docs/08-seguridad-agente.md` - OWASP Agentic, guardrails, sandbox
10. `docs/09-mantenimiento.md` - Updates, rotación, backups
11. `docs/10-checklist-final.md` - Checklist consolidado
12. `docs/glosario.md` - Definiciones

### Reglas

1. **No elimines contenido existente** a menos que sea incorrecto
2. **Mantén el tono** de la guía original (profesional, conciso)
3. **Usa los admonitions** de MkDocs correctamente
4. **Verifica que los comandos** sean copy-paste friendly
5. **Incluye outputs esperados** para comandos de verificación
6. **Cita fuentes** (CIS, OWASP, Tailscale) cuando corresponda
7. **Mantén consistencia** en placeholders y formato

### Orden de ejecución

1. Primero: Archivos críticos (03, 04, 05) - Son bloqueantes
2. Segundo: Nuevos archivos (08, 09, 10) - Completan la guía
3. Tercero: Mejoras menores (01, 02, 06, 07) - Polish
4. Cuarto: Index y glosario - Finalización

### Verificación

Después de cada archivo, verifica:
- [ ] Sintaxis markdown correcta
- [ ] Links internos funcionan
- [ ] Comandos tienen ``` correcto
- [ ] Admonitions bien formateados
- [ ] Estructura consistente con plantilla

### Output esperado

Al finalizar, la guía debe:
- Pasar auditoría con puntuación 9.5/10
- Cumplir CIS Benchmark Ubuntu 24.04 L1 al 100%
- Cumplir Tailscale Hardening al 100%
- Cumplir OWASP Agentic Top 10 al 90%+
- Ser ejecutable por un desarrollador junior sin ayuda externa

---

## Referencias

- [CIS Ubuntu Linux 24.04 LTS Benchmark v1.0.0](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Tailscale Security Hardening](https://tailscale.com/kb/1196/security-hardening)
- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/)
- [systemd Hardening](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Sandboxing)

---

*Documento generado: 2026-02-01*
*Versión: 1.0*
