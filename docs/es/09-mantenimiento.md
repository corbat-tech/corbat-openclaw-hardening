# 9. Mantenimiento

> **TL;DR**: Procedimientos de mantenimiento regular para mantener el sistema seguro: actualizaciones, rotación de secrets, backups y monitoreo continuo.

> **Tiempo estimado**: Variable (tareas periódicas)

> **Nivel requerido**: Intermedio

## Prerrequisitos

- [ ] Secciones 1-8 completadas
- [ ] Sistema funcionando correctamente

## Objetivos

Esta sección cubre:

- Actualizaciones del sistema, Tailscale y OpenClaw
- Rotación periódica de API keys y SSH keys
- Estrategia de backups
- Monitoreo continuo
- Procedimiento de disaster recovery

---

## Calendario de mantenimiento

| Tarea | Frecuencia | Criticidad |
|-------|------------|------------|
| Actualizaciones de seguridad | Automático (diario) | Alta |
| Revisar logs de seguridad | Semanal | Media |
| Backup de configuración | Semanal | Alta |
| Actualizar OpenClaw | Mensual | Media |
| Rotar API keys | Cada 90 días | Alta |
| Rotar SSH keys | Anual | Media |
| Revisar ACLs de Tailscale | Trimestral | Media |
| Actualizar base AIDE | Después de cambios | Media |
| Test de disaster recovery | Semestral | Alta |

---

## Actualizaciones del sistema

### Actualizaciones automáticas (ya configuradas)

Las actualizaciones de seguridad se aplican automáticamente gracias a `unattended-upgrades`.

**Verificar que funciona:**

```bash
# Ver estado de actualizaciones automáticas
sudo systemctl status unattended-upgrades

# Ver log de actualizaciones recientes
cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -50
```

### Canonical Livepatch (parches de kernel sin reboot)

!!! tip "Recomendado: parches de kernel en caliente"
    [Canonical Livepatch](https://ubuntu.com/security/livepatch) aplica parches de seguridad al kernel **sin necesidad de reiniciar**. Complementa `unattended-upgrades` (que cubre paquetes pero no el kernel en ejecución).

```bash
# Activar Livepatch (gratis para uso personal, hasta 5 máquinas)
sudo snap install canonical-livepatch
sudo canonical-livepatch enable <TU_TOKEN>
```

Obtén tu token en [ubuntu.com/security/livepatch](https://ubuntu.com/security/livepatch) (login con Ubuntu One).

```bash
# Verificar estado
sudo canonical-livepatch status --verbose
```

### Actualizaciones manuales

Para actualizaciones completas (no solo seguridad):

```bash
# Actualizar lista de paquetes
sudo apt update

# Ver actualizaciones disponibles
apt list --upgradable

# Aplicar todas las actualizaciones
sudo apt upgrade -y

# Actualizar distribución (con cuidado)
sudo apt dist-upgrade -y

# Limpiar paquetes obsoletos
sudo apt autoremove -y
```

!!! warning "Reiniciar si es necesario"
    Después de actualizar el kernel (si no usas Livepatch):
    ```bash
    # Verificar si hay reinicio pendiente
    [ -f /var/run/reboot-required ] && echo "Reinicio necesario"

    # Reiniciar (planificado)
    sudo shutdown -r +5 "Reinicio por actualizaciones en 5 minutos"
    ```

---

## Actualizar Tailscale

### Verificar versión actual

```bash
tailscale version
```

### Actualizar

```bash
# Actualizar desde repositorio APT
sudo apt update
sudo apt install --only-upgrade tailscale

# Verificar nueva versión
tailscale version

# Verificar que sigue funcionando
tailscale status
```

### Después de actualizar

```bash
# Verificar que los tags siguen configurados
tailscale status | grep tag

# Si es necesario, re-aplicar tags
sudo tailscale up --advertise-tags=tag:vps --reset
```

---

## Actualizar OpenClaw

### Backup antes de actualizar

```bash
# Backup de configuración
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup.$(date +%Y%m%d)
sudo cp /etc/openclaw/env /etc/openclaw/env.backup.$(date +%Y%m%d)
```

### Actualizar OpenClaw

```bash
# Verificar canal actual
openclaw update --channel

# Actualizar OpenClaw (canal estable)
npm install -g openclaw@latest

# O usar el comando nativo de actualización
openclaw update

# Verificar versión instalada
openclaw --version

# Reiniciar servicio
sudo systemctl restart openclaw

# Verificar que funciona
sudo systemctl status openclaw
```

### Verificar después de actualizar

```bash
# Verificar versión
openclaw --version

# Ejecutar diagnóstico completo
openclaw doctor

# Ejecutar auditoría de seguridad
openclaw security audit

# Ver logs por errores
sudo journalctl -u openclaw -n 50

# Verificar puntuación de seguridad systemd (no debe empeorar)
systemd-analyze security openclaw.service
```

!!! warning "Revisa las notas de versión antes de actualizar"
    OpenClaw v2026.3.x introdujo **breaking changes**. Consulta las [release notes](https://github.com/openclaw/openclaw/releases/) antes de actualizar. Haz siempre backup de la configuración primero.

---

## Rotación de API Keys

!!! danger "Rotar API keys cada 90 días"
    Las API keys son credenciales sensibles que deben rotarse regularmente.

### Procedimiento de rotación

#### 1. Generar nueva key en el proveedor

| Proveedor | URL |
|-----------|-----|
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| Anthropic | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) |
| NVIDIA NIM | [build.nvidia.com](https://build.nvidia.com) |

#### 2. Actualizar .env en el VPS

```bash
# Backup del archivo env actual
sudo cp /etc/openclaw/env /etc/openclaw/env.backup.$(date +%Y%m%d)

# Editar archivo env
sudo nano /etc/openclaw/env

# Reemplazar la key antigua por la nueva
# Ejemplo: ANTHROPIC_API_KEY=sk-ant-NUEVA_KEY_AQUI
```

#### 3. Reiniciar servicio

```bash
sudo systemctl restart openclaw
```

#### 4. Verificar funcionamiento

```bash
# Ver logs para confirmar que conecta correctamente
sudo journalctl -u openclaw -n 20

# Hacer una petición de prueba si es posible
```

#### 5. Revocar key antigua

!!! warning "Solo después de verificar que la nueva funciona"
    Vuelve al panel del proveedor y elimina/revoca la key antigua.

### Script de recordatorio

```bash
mkdir -p ~/openclaw/scripts
nano ~/openclaw/scripts/key_rotation_reminder.sh
```

```bash
#!/bin/bash
# Recordatorio de rotación de API keys

LAST_ROTATION_FILE="$HOME/.openclaw/.last_key_rotation"
MAX_DAYS=90

if [ -f "$LAST_ROTATION_FILE" ]; then
    LAST_DATE=$(cat "$LAST_ROTATION_FILE")
    LAST_TS=$(date -d "$LAST_DATE" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DIFF_DAYS=$(( (NOW_TS - LAST_TS) / 86400 ))

    if [ "$DIFF_DAYS" -ge "$MAX_DAYS" ]; then
        echo "⚠️  ALERTA: Han pasado $DIFF_DAYS días desde la última rotación de API keys"
        echo "   Última rotación: $LAST_DATE"
        echo "   Ejecuta el procedimiento de rotación documentado en docs/09-mantenimiento.md"
    fi
else
    echo "⚠️  No hay registro de última rotación de API keys"
    echo "   Crea el archivo: echo $(date +%Y-%m-%d) > $LAST_ROTATION_FILE"
fi
```

```bash
chmod +x ~/openclaw/scripts/key_rotation_reminder.sh

# Registrar fecha de última rotación
echo $(date +%Y-%m-%d) > ~/.openclaw/.last_key_rotation
```

Añade a cron para verificación semanal:

```bash
crontab -e
```

```cron
# Recordatorio de rotación de keys cada lunes
0 9 * * 1 /home/openclaw/openclaw/scripts/key_rotation_reminder.sh | logger -t key-rotation
```

---

## Rotación de SSH Keys

### Cuándo rotar

- Anualmente como práctica de higiene
- Inmediatamente si sospechas compromiso
- Cuando cambias de dispositivo

### Procedimiento

#### 1. Generar nueva key en tu máquina local

```bash
# En tu máquina local
ssh-keygen -t ed25519 -C "openclaw-vps-$(date +%Y)" -f ~/.ssh/id_ed25519_openclaw_new
```

#### 2. Añadir nueva key al VPS (mientras la antigua funciona)

```bash
# Copiar nueva clave pública
cat ~/.ssh/id_ed25519_openclaw_new.pub

# En el VPS, añadir a authorized_keys
ssh openclaw@<TU_TAILSCALE_IP>
echo "PEGA_AQUI_LA_NUEVA_CLAVE_PUBLICA" >> ~/.ssh/authorized_keys
exit
```

#### 3. Probar nueva key

```bash
# Probar conexión con nueva key
ssh -i ~/.ssh/id_ed25519_openclaw_new openclaw@<TU_TAILSCALE_IP>
```

#### 4. Eliminar key antigua

```bash
# En el VPS, editar authorized_keys
nano ~/.ssh/authorized_keys
# Eliminar la línea de la key antigua
```

#### 5. Actualizar tu configuración local

```bash
# Renombrar keys
mv ~/.ssh/id_ed25519_openclaw ~/.ssh/id_ed25519_openclaw_old
mv ~/.ssh/id_ed25519_openclaw_new ~/.ssh/id_ed25519_openclaw
mv ~/.ssh/id_ed25519_openclaw_new.pub ~/.ssh/id_ed25519_openclaw.pub

# Actualizar SSH config si es necesario
nano ~/.ssh/config
```

---

## Backups

### Visión general de la estrategia

La personalidad, memoria y configuración de tu agente OpenClaw están en archivos del VPS. Si pierdes el servidor, pierdes la identidad de tu agente. La estrategia recomendada es respaldar los archivos no sensibles en un **repositorio privado de Git**, lo que te da:

- **Backup offsite automático** — los datos viven fuera del VPS
- **Historial de versiones** — ves cómo evoluciona la memoria y personalidad de tu agente
- **Restauración fácil** — `git clone` en un servidor nuevo y listo
- **Sin descargas manuales** — cron se encarga de todo

!!! info "OpenClaw también tiene `openclaw backup create`"
    Crea un tarball local de `~/.openclaw` + workspace. Es útil para snapshots puntuales antes de actualizaciones, pero se queda en el VPS — si el servidor muere, también muere el backup. El enfoque Git resuelve esto enviando los datos fuera automáticamente.

### Qué respaldar

| Categoría | Archivos | ¿Va a Git? |
|-----------|----------|:---:|
| **Identidad del agente** | `~/openclaw/workspace/SOUL.md` | Sí |
| **Memoria del agente** | `~/openclaw/workspace/MEMORY.md`, `~/openclaw/workspace/memory/` | Sí |
| **Workspace del agente** | `~/openclaw/workspace/AGENTS.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md` | Sí |
| **Config de OpenClaw** | `~/.openclaw/openclaw.json` | Sí |
| **Exec approvals** | `~/.openclaw/exec-approvals.json` | Sí |
| **Overrides de systemd** | `/etc/systemd/system/openclaw.service.d/*.conf` | Sí |
| **Hardening SSH** | `/etc/ssh/sshd_config.d/99-openclaw-hardening.conf` | Sí |
| **Orden de arranque SSH** | `/etc/systemd/system/ssh.service.d/after-tailscale.conf` | Sí |
| **SSH authorized keys** | `~/.ssh/authorized_keys` | Sí |
| **API keys / secretos** | `/etc/openclaw/env` | **NUNCA** |
| **Auth profiles** | `~/.openclaw/agents/main/agent/auth-profiles.json` | **NUNCA** (puede contener keys) |
| **Directorio de estado** | `~/.openclaw/` (completo) | **NUNCA** (contiene tokens, sesiones) |

### Paso 1: Crear un repositorio privado en GitHub

1. Crea una **cuenta de GitHub dedicada** para tu instancia de OpenClaw (recomendado) o usa tu cuenta personal
2. Crea un repositorio **privado** (ej: `openclaw-backup`)
3. **NO** lo inicialices con README

!!! tip "¿Por qué una cuenta dedicada?"
    Una cuenta separada con su propia clave SSH limita el radio de impacto — si el VPS es comprometido, solo se accede al repo de backup, no a tu GitHub personal. También mantiene la actividad del bot separada de la tuya.

### Paso 2: Configurar clave SSH para acceso Git

En el VPS, genera una deploy key:

```bash
# Generar clave SSH para Git (sin passphrase para uso automatizado)
ssh-keygen -t ed25519 -C "openclaw-backup" -f ~/.ssh/git_backup_key -N ""

# Mostrar la clave pública
cat ~/.ssh/git_backup_key.pub
```

Añade la clave pública a tu repo de GitHub:

- Ve a tu repo → **Settings** → **Deploy keys** → **Add deploy key**
- Pega la clave pública
- Marca **Allow write access**
- Haz clic en **Add key**

Configura SSH para usar esta clave con GitHub:

```bash
cat >> ~/.ssh/config << 'EOF'

# Git backup
Host github-backup
    HostName github.com
    User git
    IdentityFile ~/.ssh/git_backup_key
    IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
```

### Paso 3: Inicializar el repositorio de backup

```bash
# Crear el directorio de staging del backup
mkdir -p ~/openclaw-backup
cd ~/openclaw-backup
git init
git remote add origin git@github-backup:<TU_USUARIO_GITHUB>/openclaw-backup.git
```

Crea un `.gitignore` para evitar que los secretos se commiteen jamás:

```bash
cat > ~/openclaw-backup/.gitignore << 'EOF'
# NUNCA commitear secretos
.env
*.env
env
*.gpg
*.pem
*.key
auth-profiles.json
credentials/
secrets/

# Archivos del sistema
.DS_Store
*.swp
*.swo
*~
EOF
```

Haz el commit inicial:

```bash
cd ~/openclaw-backup
git add .gitignore
git commit -m "chore: initial commit with .gitignore"
git branch -M main
git push -u origin main
```

### Paso 4: Crear el script de backup

```bash
nano ~/openclaw/scripts/git-backup.sh
```

```bash
#!/bin/bash
# Backup automático por Git para workspace y configuración de OpenClaw
# Respalda archivos no sensibles a un repositorio privado de GitHub
set -euo pipefail

BACKUP_DIR="$HOME/openclaw-backup"
LOG_FILE="$HOME/openclaw/logs/git-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

log "Starting backup..."

# Asegurar que el directorio de backup existe
mkdir -p "$BACKUP_DIR"/{workspace,config,system}

# --- Archivos del workspace (identidad, memoria, personalidad) ---
if [ -d "$HOME/openclaw/workspace" ]; then
    rsync -a --delete \
        --exclude='*.env' \
        --exclude='credentials/' \
        --exclude='secrets/' \
        "$HOME/openclaw/workspace/" "$BACKUP_DIR/workspace/"
    log "Workspace synced"
fi

# --- Configuración de OpenClaw (no sensible) ---
cp "$HOME/.openclaw/openclaw.json" "$BACKUP_DIR/config/" 2>/dev/null || true
cp "$HOME/.openclaw/exec-approvals.json" "$BACKUP_DIR/config/" 2>/dev/null || true
log "Config files copied"

# --- Configuración del sistema ---
cp /etc/ssh/sshd_config.d/99-openclaw-hardening.conf "$BACKUP_DIR/system/" 2>/dev/null || true
cp /etc/systemd/system/ssh.service.d/after-tailscale.conf "$BACKUP_DIR/system/" 2>/dev/null || true
cp "$HOME/.ssh/authorized_keys" "$BACKUP_DIR/system/" 2>/dev/null || true

# Copiar overrides de systemd si existen
if [ -d /etc/systemd/system/openclaw.service.d ]; then
    mkdir -p "$BACKUP_DIR/system/openclaw.service.d"
    cp /etc/systemd/system/openclaw.service.d/*.conf "$BACKUP_DIR/system/openclaw.service.d/" 2>/dev/null || true
fi
log "System config copied"

# --- Info del servidor (referencia para restaurar) ---
cat > "$BACKUP_DIR/SERVER_INFO.md" << EOF
# Server Information

- **Last backup**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Hostname**: $(hostname)
- **Tailscale IP**: $(tailscale ip -4 2>/dev/null || echo "unknown")
- **OpenClaw version**: $(openclaw --version 2>/dev/null || echo "unknown")
- **OS**: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- **Node.js**: $(node --version 2>/dev/null || echo "unknown")
EOF
log "Server info updated"

# --- Comprobación de seguridad: asegurar que no se suben secretos ---
cd "$BACKUP_DIR"
if grep -rl 'sk-ant-\|sk-\|nvapi-\|OPENAI_API_KEY=\|ANTHROPIC_API_KEY=\|GEMINI_API_KEY=' . \
    --include='*.json' --include='*.md' --include='*.conf' --include='*.env' 2>/dev/null | grep -v '.git/'; then
    log "ERROR: Potential secrets detected in backup files! Aborting."
    echo "ERROR: Potential secrets detected. Backup aborted." >&2
    exit 1
fi

# --- Commit y push ---
cd "$BACKUP_DIR"
git add -A

if git diff --cached --quiet; then
    log "No changes to commit"
else
    git commit -m "backup: $(date '+%Y-%m-%d %H:%M') — $(hostname)"
    git push origin main
    log "Changes pushed to GitHub"
fi

log "Backup complete"
```

```bash
chmod +x ~/openclaw/scripts/git-backup.sh
mkdir -p ~/openclaw/logs
```

### Paso 5: Probar el backup

```bash
# Ejecutar manualmente primero
~/openclaw/scripts/git-backup.sh

# Verificar el log
cat ~/openclaw/logs/git-backup.log

# Verificar en GitHub que los archivos aparecieron en tu repo privado
```

### Paso 6: Programar backups automáticos

```bash
crontab -e
```

Añadir:

```cron
# Backup diario por Git a las 4:00 AM
0 4 * * * /home/openclaw/openclaw/scripts/git-backup.sh >> /home/openclaw/openclaw/logs/git-backup.log 2>&1
```

!!! tip "Frecuencia"
    Diario es suficiente para la mayoría de setups. Si tu agente es muy activo y acumula memoria rápidamente, puedes aumentar a cada 6 horas: `0 */6 * * *`.

### Paso 7: Verificar que los backups funcionan

Después de un día, comprueba:

```bash
# Verificar que cron ejecutó correctamente
tail -20 ~/openclaw/logs/git-backup.log

# Ver fecha del último commit en el repo
cd ~/openclaw-backup && git log --oneline -5
```

### Restaurar en un nuevo servidor

Si pierdes el VPS, restaurar es directo:

1. Provisiona un nuevo VPS siguiendo las secciones 1-5 de esta guía
2. Clona tu backup:

```bash
git clone git@github.com:<TU_USUARIO_GITHUB>/openclaw-backup.git ~/openclaw-backup
```

3. Restaura los archivos a sus ubicaciones:

```bash
# Restaurar workspace (identidad y memoria del agente)
cp -r ~/openclaw-backup/workspace/* ~/openclaw/workspace/

# Restaurar configuración de OpenClaw
cp ~/openclaw-backup/config/openclaw.json ~/.openclaw/
cp ~/openclaw-backup/config/exec-approvals.json ~/.openclaw/ 2>/dev/null || true

# Restaurar configuración del sistema
sudo cp ~/openclaw-backup/system/99-openclaw-hardening.conf /etc/ssh/sshd_config.d/
sudo mkdir -p /etc/systemd/system/ssh.service.d
sudo cp ~/openclaw-backup/system/after-tailscale.conf /etc/systemd/system/ssh.service.d/
cp ~/openclaw-backup/system/authorized_keys ~/.ssh/

# Restaurar overrides de systemd
if [ -d ~/openclaw-backup/system/openclaw.service.d ]; then
    sudo cp -r ~/openclaw-backup/system/openclaw.service.d /etc/systemd/system/
fi

sudo systemctl daemon-reload
```

4. Re-configurar secretos (NO están en el backup — necesitas tus API keys):

```bash
sudo nano /etc/openclaw/env
# Añade tus API keys, token de Telegram, etc.
```

5. Reiniciar servicios:

```bash
sudo systemctl restart ssh
sudo systemctl restart openclaw
```

!!! success "Tu agente ha vuelto"
    Con el workspace restaurado, tu agente conserva su personalidad (SOUL.md), memoria (MEMORY.md + memory/), y toda la configuración. Solo los secretos necesitan ser re-introducidos.

### Snapshot antes de actualizaciones

Antes de cambios importantes (actualizaciones de OpenClaw, cambio de proveedor), haz un snapshot manual:

```bash
# Backup rápido con el CLI de OpenClaw
openclaw backup create

# O lanza tu backup Git inmediatamente
~/openclaw/scripts/git-backup.sh
```

---

## Monitoreo continuo

### Dashboard de estado rápido

```bash
nano ~/openclaw/scripts/status.sh
```

```bash
#!/bin/bash
# Dashboard de estado de OpenClaw

clear
echo "========================================"
echo "      ESTADO DE OPENCLAW VPS           "
echo "      $(date '+%Y-%m-%d %H:%M:%S')     "
echo "========================================"
echo ""

# Sistema
echo "--- SISTEMA ---"
echo "Uptime: $(uptime -p)"
echo "Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo "RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "Disco: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
echo ""

# Servicios
echo "--- SERVICIOS ---"
for service in openclaw tailscaled fail2ban auditd; do
    status=$(systemctl is-active $service 2>/dev/null)
    if [ "$status" = "active" ]; then
        echo "✅ $service"
    else
        echo "❌ $service ($status)"
    fi
done
echo ""

# Red
echo "--- RED ---"
echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
echo "SSH escuchando: $(ss -tlnp | grep sshd | awk '{print $4}')"
echo "OpenClaw escuchando: $(ss -tlnp | grep 18789 | awk '{print $4}')"
echo ""

# Seguridad
echo "--- SEGURIDAD ---"
BANNED=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
echo "IPs baneadas (fail2ban): ${BANNED:-0}"
ALERTS=$(wc -l < ~/openclaw/logs/security_alerts.log 2>/dev/null || echo 0)
echo "Alertas de seguridad: $ALERTS"
echo ""

# Últimos eventos
echo "--- ÚLTIMOS LOGS ---"
echo "OpenClaw:"
sudo journalctl -u openclaw -n 3 --no-pager 2>/dev/null | tail -3
echo ""

echo "========================================"
```

```bash
chmod +x ~/openclaw/scripts/status.sh
```

### Alertas por email (opcional)

Si quieres recibir alertas por email, configura `msmtp` o similar:

```bash
sudo apt install -y msmtp msmtp-mta

# Configurar (ejemplo con Gmail)
nano ~/.msmtprc
```

```
account gmail
host smtp.gmail.com
port 587
auth on
user tu-email@gmail.com
password tu-app-password
tls on
tls_starttls on
from tu-email@gmail.com

account default : gmail
```

```bash
chmod 600 ~/.msmtprc
```

---

## Disaster Recovery

### Escenario: Pérdida total del VPS

Si tu VPS es destruido y tienes backups por Git configurados (ver [Backups](#backups) arriba), la recuperación es directa.

#### Paso 1: Crear y endurecer un nuevo VPS

Sigue las secciones 1-4 de esta guía:

- [2. Contratar VPS](02-vps.md) — crear un nuevo servidor
- [3. Seguridad del sistema](03-seguridad-sistema.md) — crear usuario, endurecer SSH
- [4. Acceso privado](04-acceso-privado.md) — instalar Tailscale, cerrar SSH público

#### Paso 2: Instalar OpenClaw

Sigue la [Sección 5](05-openclaw.md) para instalar OpenClaw en el nuevo servidor.

#### Paso 3: Restaurar desde backup Git

```bash
# Clonar tu repositorio de backup
git clone git@github.com:<TU_USUARIO_GITHUB>/openclaw-backup.git ~/openclaw-backup

# Restaurar workspace (identidad, memoria, personalidad del agente)
cp -r ~/openclaw-backup/workspace/* ~/openclaw/workspace/

# Restaurar configuración de OpenClaw
cp ~/openclaw-backup/config/openclaw.json ~/.openclaw/
cp ~/openclaw-backup/config/exec-approvals.json ~/.openclaw/ 2>/dev/null || true

# Restaurar configuración del sistema
sudo cp ~/openclaw-backup/system/99-openclaw-hardening.conf /etc/ssh/sshd_config.d/
sudo mkdir -p /etc/systemd/system/ssh.service.d
sudo cp ~/openclaw-backup/system/after-tailscale.conf /etc/systemd/system/ssh.service.d/
cp ~/openclaw-backup/system/authorized_keys ~/.ssh/

# Restaurar overrides de systemd
if [ -d ~/openclaw-backup/system/openclaw.service.d ]; then
    sudo cp -r ~/openclaw-backup/system/openclaw.service.d /etc/systemd/system/
fi
```

#### Paso 4: Re-configurar secretos

Los secretos nunca se almacenan en el backup. Necesitas re-introducir tus API keys:

```bash
sudo nano /etc/openclaw/env
# Añadir: API keys, token de Telegram, y cualquier otro secreto

sudo chmod 600 /etc/openclaw/env
sudo chown root:openclaw /etc/openclaw/env
```

#### Paso 5: Aplicar y verificar

```bash
sudo systemctl daemon-reload
sudo systemctl restart ssh
sudo systemctl restart openclaw

# Verificar que todo está corriendo
sudo systemctl is-active tailscaled ssh openclaw
openclaw status --all
```

#### Paso 6: Re-habilitar backups en el nuevo servidor

Sigue el [Paso 2](#paso-2-configurar-clave-ssh-para-acceso-git) en adelante de la sección de Backups para configurar la clave SSH y el cron job en el nuevo servidor.

!!! tip "Guarda tus API keys fuera del VPS"
    Almacena tus API keys en un gestor de contraseñas (Bitwarden, 1Password, etc.) para poder re-introducirlas durante la recuperación sin depender del VPS.

### Test de disaster recovery

!!! tip "Haz este test cada 6 meses"
    La única forma de saber si tus backups funcionan es probarlos.

1. Crea un VPS temporal
2. Intenta restaurar desde backup
3. Verifica que todo funciona
4. Elimina el VPS temporal

---

## Checklist de mantenimiento mensual

```markdown
## Mantenimiento mensual - [MES/AÑO]

### Sistema
- [ ] Verificar actualizaciones automáticas funcionando
- [ ] Revisar logs de seguridad
- [ ] Verificar espacio en disco (< 80%)
- [ ] Revisar uso de recursos

### Tailscale
- [ ] Verificar versión actualizada
- [ ] Revisar dispositivos conectados
- [ ] Verificar ACLs siguen correctas

### OpenClaw
- [ ] Actualizar si hay nueva versión
- [ ] Revisar logs por errores
- [ ] Verificar puntuación systemd

### Seguridad
- [ ] Revisar IPs baneadas por fail2ban
- [ ] Verificar alertas de seguridad
- [ ] Ejecutar verificación de integridad AIDE
- [ ] Revisar reglas de auditoría

### Backups
- [ ] Verificar que el cron de Git backup funciona (`tail -5 ~/openclaw/logs/git-backup.log`)
- [ ] Comprobar fecha del último commit (`cd ~/openclaw-backup && git log --oneline -1`)
- [ ] Verificar que se puede restaurar (trimestral)

### Rotación de secrets
- [ ] ¿Han pasado 90 días desde última rotación de API keys?
- [ ] ¿Ha pasado 1 año desde rotación de SSH keys?

### Notas
_Cualquier observación o tarea pendiente_
```

---

**Siguiente:** [10. Checklist final](10-checklist-final.md) — Verificación consolidada de todos los controles.
