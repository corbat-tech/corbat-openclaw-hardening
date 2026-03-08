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
cp ~/.openclaw/.env ~/.openclaw/.env.backup.$(date +%Y%m%d)
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
# Backup de .env actual
cp ~/.openclaw/.env ~/.openclaw/.env.backup.$(date +%Y%m%d)

# Editar .env
nano ~/.openclaw/.env

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

### Qué incluir en backups

| Archivo/Directorio | Criticidad | Frecuencia |
|--------------------|------------|------------|
| `~/.openclaw/openclaw.json` | Crítica | Semanal |
| `~/.openclaw/.env` | Crítica | Semanal |
| `~/openclaw/workspace/` | Media | Diario (si hay datos) |
| SSH keys (`.ssh/`) | Alta | Después de rotación |
| Configuración systemd | Media | Después de cambios |

### Script de backup

```bash
nano ~/openclaw/scripts/backup.sh
```

```bash
#!/bin/bash
# Backup de configuración de OpenClaw
# Ejecutar semanalmente

set -e

BACKUP_DIR="$HOME/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openclaw_backup_$DATE"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Crear directorio de backup
mkdir -p "$BACKUP_PATH"

echo "Creando backup: $BACKUP_NAME"

# Backup de configuración OpenClaw (cifrado)
echo "- Backup de configuración OpenClaw..."
if [ -f "$HOME/openclaw/.env" ]; then
    gpg --symmetric --cipher-algo AES256 -o "$BACKUP_PATH/env.gpg" "$HOME/openclaw/.env"
fi
cp "$HOME/.openclaw/openclaw.json" "$BACKUP_PATH/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/SOUL.md" "$BACKUP_PATH/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/TOOLS.md" "$BACKUP_PATH/" 2>/dev/null || true

# Backup de scripts de mantenimiento
echo "- Backup de scripts..."
cp -r "$HOME/openclaw/scripts" "$BACKUP_PATH/" 2>/dev/null || true

# Backup de configuración systemd
echo "- Backup de systemd service..."
sudo cp /etc/systemd/system/openclaw.service "$BACKUP_PATH/"

# Backup de SSH authorized_keys
echo "- Backup de SSH keys..."
cp "$HOME/.ssh/authorized_keys" "$BACKUP_PATH/"

# Backup de reglas de audit
echo "- Backup de audit rules..."
sudo cp /etc/audit/rules.d/openclaw.rules "$BACKUP_PATH/" 2>/dev/null || true

# Crear archivo de información
cat > "$BACKUP_PATH/backup_info.txt" << EOF
Backup creado: $(date)
Hostname: $(hostname)
Tailscale IP: $(tailscale ip -4)
OpenClaw version: $(openclaw --version 2>/dev/null || echo "unknown")
EOF

# Comprimir backup
echo "- Comprimiendo..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_PATH"

# Limpiar backups antiguos (mantener últimos 4)
echo "- Limpiando backups antiguos..."
ls -t "$BACKUP_DIR"/openclaw_backup_*.tar.gz | tail -n +5 | xargs -r rm

echo "Backup completado: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Tamaño: $(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)"

# Recordatorio de descargar backup
echo ""
echo "⚠️  IMPORTANTE: Descarga el backup a tu máquina local:"
echo "   scp openclaw@<TU_TAILSCALE_IP>:$BACKUP_DIR/$BACKUP_NAME.tar.gz ./"
```

```bash
chmod +x ~/openclaw/scripts/backup.sh
```

### Programar backups automáticos

```bash
crontab -e
```

```cron
# Backup semanal (domingos a las 3am)
0 3 * * 0 /home/openclaw/openclaw/scripts/backup.sh >> /home/openclaw/openclaw/logs/backup.log 2>&1
```

### Descargar backups a tu máquina local

!!! danger "Los backups en el VPS no son suficientes"
    Si pierdes el VPS, pierdes los backups. Descarga regularmente a tu máquina local.

```bash
# Desde tu máquina local
scp openclaw@<TU_TAILSCALE_IP>:~/backups/openclaw_backup_*.tar.gz ~/backups/vps/
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

#### Paso 1: Crear nuevo VPS

Sigue las instrucciones de la [Sección 2](02-vps.md) para crear un nuevo VPS.

#### Paso 2: Restaurar desde backup

```bash
# Subir backup al nuevo VPS
scp openclaw_backup_FECHA.tar.gz root@NUEVO_VPS:/tmp/

# En el nuevo VPS
tar -xzf /tmp/openclaw_backup_FECHA.tar.gz -C /tmp/
```

#### Paso 3: Ejecutar setup inicial

```bash
# Crear usuario (Sección 3)
adduser openclaw
usermod -aG sudo openclaw

# Restaurar authorized_keys
mkdir -p /home/openclaw/.ssh
cp /tmp/openclaw_backup_*/authorized_keys /home/openclaw/.ssh/
chown -R openclaw:openclaw /home/openclaw/.ssh
chmod 700 /home/openclaw/.ssh
chmod 600 /home/openclaw/.ssh/authorized_keys
```

#### Paso 4: Restaurar configuración

```bash
# Como usuario openclaw
su - openclaw

# Instalar OpenClaw
npm install -g openclaw@latest

# Crear estructura
mkdir -p ~/.openclaw
mkdir -p ~/openclaw/{workspace,logs,scripts}

# Restaurar configuración OpenClaw
cp /tmp/openclaw_backup_*/openclaw.json ~/.openclaw/
cp /tmp/openclaw_backup_*/SOUL.md ~/.openclaw/workspace/ 2>/dev/null || true
cp /tmp/openclaw_backup_*/TOOLS.md ~/.openclaw/workspace/ 2>/dev/null || true
cp -r /tmp/openclaw_backup_*/scripts/* ~/openclaw/scripts/ 2>/dev/null || true

# Restaurar .env (descifrar)
gpg -d /tmp/openclaw_backup_*/env.gpg > ~/.openclaw/.env
chmod 600 ~/.openclaw/.env

# Restaurar servicio systemd
sudo cp /tmp/openclaw_backup_*/openclaw.service /etc/systemd/system/
sudo systemctl daemon-reload
```

#### Paso 5: Re-ejecutar hardening

Sigue las secciones relevantes:

- [3. Seguridad del sistema](03-seguridad-sistema.md) - SSH hardening
- [4. Acceso privado](04-acceso-privado.md) - Tailscale
- [5. OpenClaw](05-openclaw.md) - Instalación

#### Paso 6: Verificar

```bash
# Ejecutar script de verificación
~/openclaw/scripts/verify_permissions.sh

# Verificar servicios
~/openclaw/scripts/status.sh
```

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
- [ ] Verificar backups automáticos
- [ ] Descargar backup a local
- [ ] Verificar que se puede restaurar (trimestral)

### Rotación de secrets
- [ ] ¿Han pasado 90 días desde última rotación de API keys?
- [ ] ¿Ha pasado 1 año desde rotación de SSH keys?

### Notas
_Cualquier observación o tarea pendiente_
```

---

**Siguiente:** [10. Checklist final](10-checklist-final.md) — Verificación consolidada de todos los controles.
