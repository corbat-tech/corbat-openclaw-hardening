# 10. Checklist Final de Seguridad

> **TL;DR**: Verificación consolidada de todos los controles de seguridad implementados. Usa este checklist para confirmar que tu instalación cumple con CIS Benchmark, Tailscale Hardening y OWASP Agentic Top 10.

---

## Instrucciones de uso

1. Ejecuta cada verificación en orden
2. Marca cada control como ✅ (cumple) o ❌ (no cumple)
3. No pongas OpenClaw en producción hasta que todos los controles críticos estén en ✅
4. Guarda este checklist completado como evidencia de configuración

---

## Script de verificación automática

Ejecuta este script para verificar automáticamente la mayoría de controles:

```bash
#!/bin/bash
# verificar_seguridad.sh - Verificación completa de seguridad

echo "========================================================"
echo "  VERIFICACIÓN DE SEGURIDAD - OpenClaw VPS"
echo "  Fecha: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Hostname: $(hostname)"
echo "========================================================"
echo ""

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local result="$2"
    local critical="$3"

    if [ "$result" = "pass" ]; then
        echo "✅ $name"
        ((PASS++))
    elif [ "$result" = "warn" ]; then
        echo "⚠️  $name"
        ((WARN++))
    else
        if [ "$critical" = "critical" ]; then
            echo "❌ [CRÍTICO] $name"
        else
            echo "❌ $name"
        fi
        ((FAIL++))
    fi
}

echo "=== 1. SISTEMA OPERATIVO ==="

# Usuario openclaw existe
if id openclaw &>/dev/null; then
    check "Usuario openclaw existe" "pass"
else
    check "Usuario openclaw existe" "fail" "critical"
fi

# Usuario openclaw no es root
if [ "$(id -u openclaw 2>/dev/null)" != "0" ]; then
    check "Usuario openclaw no es root" "pass"
else
    check "Usuario openclaw no es root" "fail" "critical"
fi

# UFW activo
if sudo ufw status | grep -q "Status: active"; then
    check "Firewall UFW activo" "pass"
else
    check "Firewall UFW activo" "fail" "critical"
fi

# Fail2ban activo
if systemctl is-active fail2ban &>/dev/null; then
    check "Fail2ban activo" "pass"
else
    check "Fail2ban activo" "fail"
fi

# Unattended upgrades
if systemctl is-active unattended-upgrades &>/dev/null; then
    check "Actualizaciones automáticas" "pass"
else
    check "Actualizaciones automáticas" "fail"
fi

# Auditd activo
if systemctl is-active auditd &>/dev/null; then
    check "Auditd activo" "pass"
else
    check "Auditd activo" "warn"
fi

# AIDE inicializado
if [ -f /var/lib/aide/aide.db ]; then
    check "AIDE inicializado" "pass"
else
    check "AIDE inicializado" "warn"
fi

echo ""
echo "=== 2. SSH HARDENING (CIS Benchmark) ==="

# PasswordAuthentication no
if sudo sshd -T 2>/dev/null | grep -qi "passwordauthentication no"; then
    check "SSH: PasswordAuthentication no" "pass"
else
    check "SSH: PasswordAuthentication no" "fail" "critical"
fi

# PermitRootLogin no
if sudo sshd -T 2>/dev/null | grep -qi "permitrootlogin no"; then
    check "SSH: PermitRootLogin no" "pass"
else
    check "SSH: PermitRootLogin no" "fail" "critical"
fi

# AllowUsers configurado
if sudo sshd -T 2>/dev/null | grep -qi "allowusers"; then
    check "SSH: AllowUsers configurado" "pass"
else
    check "SSH: AllowUsers configurado" "fail"
fi

# MaxAuthTries <= 4
MAX_AUTH=$(sudo sshd -T 2>/dev/null | grep -i maxauthtries | awk '{print $2}')
if [ -n "$MAX_AUTH" ] && [ "$MAX_AUTH" -le 4 ]; then
    check "SSH: MaxAuthTries <= 4" "pass"
else
    check "SSH: MaxAuthTries <= 4" "fail"
fi

# X11Forwarding no
if sudo sshd -T 2>/dev/null | grep -qi "x11forwarding no"; then
    check "SSH: X11Forwarding no" "pass"
else
    check "SSH: X11Forwarding no" "fail"
fi

# LogLevel VERBOSE
if sudo sshd -T 2>/dev/null | grep -qi "loglevel verbose"; then
    check "SSH: LogLevel VERBOSE" "pass"
else
    check "SSH: LogLevel VERBOSE" "warn"
fi

# Permisos sshd_config
SSHD_PERMS=$(stat -c "%a" /etc/ssh/sshd_config 2>/dev/null)
if [ "$SSHD_PERMS" = "600" ]; then
    check "SSH: sshd_config permisos 600" "pass"
else
    check "SSH: sshd_config permisos 600" "fail"
fi

echo ""
echo "=== 3. TAILSCALE ==="

# Tailscale instalado y activo
if systemctl is-active tailscaled &>/dev/null; then
    check "Tailscale activo" "pass"
else
    check "Tailscale activo" "fail" "critical"
fi

# SSH escuchando solo en Tailscale
SSH_LISTEN=$(sudo ss -tlnp | grep sshd | awk '{print $4}')
if echo "$SSH_LISTEN" | grep -q "100\."; then
    check "SSH solo en interfaz Tailscale" "pass"
elif echo "$SSH_LISTEN" | grep -q "0\.0\.0\.0"; then
    check "SSH solo en interfaz Tailscale" "fail" "critical"
else
    check "SSH solo en interfaz Tailscale" "warn"
fi

# Puerto 22 cerrado en UFW (no debe haber regla para SSH)
if ! sudo ufw status | grep -E "22/tcp.*ALLOW.*Anywhere" | grep -v "100\." &>/dev/null; then
    check "Puerto 22 público cerrado" "pass"
else
    check "Puerto 22 público cerrado" "fail" "critical"
fi

# Tag vps configurado
if tailscale status 2>/dev/null | grep -q "tagged"; then
    check "Tag 'vps' configurado" "pass"
else
    check "Tag 'vps' configurado" "warn"
fi

echo ""
echo "=== 4. OPENCLAW ==="

# Servicio activo
if systemctl is-active openclaw &>/dev/null; then
    check "Servicio OpenClaw activo" "pass"
else
    check "Servicio OpenClaw activo" "warn"
fi

# Escuchando en localhost (no 0.0.0.0)
OPENCLAW_LISTEN=$(sudo ss -tlnp | grep 18789 | awk '{print $4}')
if echo "$OPENCLAW_LISTEN" | grep -q "127\.0\.0\.1"; then
    check "OpenClaw en localhost (127.0.0.1:18789)" "pass"
elif echo "$OPENCLAW_LISTEN" | grep -q "0\.0\.0\.0"; then
    check "OpenClaw en localhost (127.0.0.1:18789)" "fail" "critical"
else
    check "OpenClaw en localhost (127.0.0.1:18789)" "warn"
fi

# .env con permisos 600
ENV_PERMS=$(stat -c "%a" /home/openclaw/openclaw/.env 2>/dev/null || stat -c "%a" ~/openclaw/.env 2>/dev/null)
if [ "$ENV_PERMS" = "600" ]; then
    check ".env permisos 600" "pass"
else
    check ".env permisos 600" "fail" "critical"
fi

# Puntuación systemd < 5
SECURITY_SCORE=$(systemd-analyze security openclaw.service 2>/dev/null | grep "Overall" | grep -oE "[0-9]+\.[0-9]+" | head -1)
if [ -n "$SECURITY_SCORE" ]; then
    # Extraer parte entera para comparación (sin dependencia de bc)
    SCORE_INT=${SECURITY_SCORE%%.*}
    if [ -n "$SCORE_INT" ] && [ "$SCORE_INT" -lt 5 ]; then
        check "Systemd hardening (score < 5.0): $SECURITY_SCORE" "pass"
    elif [ -n "$SCORE_INT" ] && [ "$SCORE_INT" -ge 5 ]; then
        check "Systemd hardening (score < 5.0): $SECURITY_SCORE" "fail"
    else
        check "Systemd hardening (score parse error)" "warn"
    fi
else
    check "Systemd hardening" "warn"
fi

echo ""
echo "=== 5. CONFIGURACIÓN DE OPENCLAW ==="

CONFIG_FILE="/home/openclaw/.openclaw/openclaw.json"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME/.openclaw/openclaw.json"
fi

if [ -f "$CONFIG_FILE" ]; then
    # Sandbox mode activo
    if grep -q '"sandbox"' "$CONFIG_FILE" && grep -A2 '"sandbox"' "$CONFIG_FILE" | grep -q '"mode":\s*"all"'; then
        check "Sandbox mode activo" "pass"
    else
        check "Sandbox mode activo" "fail" "critical"
    fi

    # dmPolicy configurado
    if grep -q '"dmPolicy":\s*"pairing"' "$CONFIG_FILE" || grep -q '"dmPolicy":\s*"closed"' "$CONFIG_FILE"; then
        check "dmPolicy configurado (pairing/closed)" "pass"
    elif grep -q '"dmPolicy":\s*"open"' "$CONFIG_FILE"; then
        check "dmPolicy configurado (pairing/closed)" "fail" "critical"
    else
        check "dmPolicy configurado (pairing/closed)" "warn"
    fi

    # Gateway en localhost
    if grep -q '"host":\s*"127.0.0.1"' "$CONFIG_FILE"; then
        check "Gateway host = 127.0.0.1" "pass"
    else
        check "Gateway host = 127.0.0.1" "fail" "critical"
    fi

    # Gateway TLS pairing
    if grep -q '"pairing":\s*true' "$CONFIG_FILE"; then
        check "Gateway TLS pairing habilitado" "pass"
    else
        check "Gateway TLS pairing habilitado" "warn"
    fi
else
    check "Archivo openclaw.json existe" "fail"
fi

# Verificar TOOLS.md (allowlist de herramientas)
TOOLS_FILE="/home/openclaw/.openclaw/workspace/TOOLS.md"
if [ ! -f "$TOOLS_FILE" ]; then
    TOOLS_FILE="$HOME/.openclaw/workspace/TOOLS.md"
fi

if [ -f "$TOOLS_FILE" ]; then
    check "TOOLS.md (allowlist) existe" "pass"
else
    check "TOOLS.md (allowlist) existe" "warn"
fi

echo ""
echo "=== 6. MONITOREO Y AUDITORÍA ==="

# Reglas de audit para openclaw
if sudo auditctl -l 2>/dev/null | grep -q "openclaw"; then
    check "Reglas de auditoría configuradas" "pass"
else
    check "Reglas de auditoría configuradas" "warn"
fi

# Script de monitoreo existe
if [ -x /home/openclaw/openclaw/scripts/monitor_behavior.sh ] || [ -x ~/openclaw/scripts/monitor_behavior.sh ]; then
    check "Script de monitoreo existe" "pass"
else
    check "Script de monitoreo existe" "warn"
fi

# Backup script existe
if [ -x /home/openclaw/openclaw/scripts/backup.sh ] || [ -x ~/openclaw/scripts/backup.sh ]; then
    check "Script de backup existe" "pass"
else
    check "Script de backup existe" "warn"
fi

echo ""
echo "========================================================"
echo "  RESUMEN"
echo "========================================================"
echo "  ✅ Pasados: $PASS"
echo "  ⚠️  Advertencias: $WARN"
echo "  ❌ Fallidos: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "  🎉 Todos los controles críticos pasados"
    exit 0
else
    echo "  ⚠️  Hay controles fallidos que deben corregirse"
    exit 1
fi
```

Guarda y ejecuta:

```bash
nano ~/openclaw/scripts/verificar_seguridad.sh
chmod +x ~/openclaw/scripts/verificar_seguridad.sh
~/openclaw/scripts/verificar_seguridad.sh
```

---

## Checklist manual detallado

### 1. Sistema Operativo

| # | Control | Verificación | Estado |
|---|---------|--------------|--------|
| 1.1 | Usuario `openclaw` creado | `id openclaw` | ⬜ |
| 1.2 | Usuario no es root | `id -u openclaw` ≠ 0 | ⬜ |
| 1.3 | Usuario tiene sudo | `groups openclaw` incluye sudo | ⬜ |
| 1.4 | UFW activo | `sudo ufw status` = active | ⬜ |
| 1.5 | UFW default deny incoming | `sudo ufw status verbose` | ⬜ |
| 1.6 | Fail2ban activo | `systemctl is-active fail2ban` | ⬜ |
| 1.7 | Fail2ban protegiendo SSH | `sudo fail2ban-client status sshd` | ⬜ |
| 1.8 | Actualizaciones automáticas | `systemctl is-active unattended-upgrades` | ⬜ |
| 1.9 | Auditd activo | `systemctl is-active auditd` | ⬜ |
| 1.10 | Reglas audit para OpenClaw | `sudo auditctl -l \| grep openclaw` | ⬜ |
| 1.11 | AIDE inicializado | `ls /var/lib/aide/aide.db` | ⬜ |

### 2. SSH Hardening (CIS Benchmark 5.2)

| # | Control | Comando de verificación | Valor esperado | Estado |
|---|---------|------------------------|----------------|--------|
| 2.1 | PasswordAuthentication | `sudo sshd -T \| grep passwordauthentication` | no | ⬜ |
| 2.2 | PermitRootLogin | `sudo sshd -T \| grep permitrootlogin` | no | ⬜ |
| 2.3 | PermitEmptyPasswords | `sudo sshd -T \| grep permitemptypasswords` | no | ⬜ |
| 2.4 | MaxAuthTries | `sudo sshd -T \| grep maxauthtries` | ≤ 4 | ⬜ |
| 2.5 | X11Forwarding | `sudo sshd -T \| grep x11forwarding` | no | ⬜ |
| 2.6 | AllowTcpForwarding | `sudo sshd -T \| grep allowtcpforwarding` | local | ⬜ |
| 2.7 | LogLevel | `sudo sshd -T \| grep loglevel` | VERBOSE | ⬜ |
| 2.8 | ClientAliveInterval | `sudo sshd -T \| grep clientaliveinterval` | > 0 | ⬜ |
| 2.9 | LoginGraceTime | `sudo sshd -T \| grep logingracetime` | ≤ 60 | ⬜ |
| 2.10 | AllowUsers | `sudo sshd -T \| grep allowusers` | openclaw | ⬜ |
| 2.11 | Banner | `sudo sshd -T \| grep banner` | /etc/issue.net | ⬜ |
| 2.12 | Ciphers seguros | `sudo sshd -T \| grep ciphers` | Sin arcfour, 3des | ⬜ |
| 2.13 | KexAlgorithms post-cuántico | `sudo sshd -T \| grep kexalgorithms` | Incluye sntrup761 | ⬜ |
| 2.14 | Permisos sshd_config | `stat -c %a /etc/ssh/sshd_config` | 600 | ⬜ |
| 2.15 | Propietario sshd_config | `stat -c %U:%G /etc/ssh/sshd_config` | root:root | ⬜ |

### 3. Tailscale

| # | Control | Verificación | Estado |
|---|---------|--------------|--------|
| 3.1 | Tailscale instalado | `tailscale version` | ⬜ |
| 3.2 | Tailscaled activo | `systemctl is-active tailscaled` | ⬜ |
| 3.3 | Conectado a Tailnet | `tailscale status` muestra dispositivos | ⬜ |
| 3.4 | Tag 'vps' asignado | `tailscale status` muestra tagged | ⬜ |
| 3.5 | ACLs configuradas (no permit-all) | Verificar en panel Tailscale | ⬜ |
| 3.6 | SSH escucha solo en IP Tailscale | `ss -tlnp \| grep sshd` = <TU_TAILSCALE_IP> | ⬜ |
| 3.7 | Puerto 22 público cerrado | `ssh user@IP_PUBLICA` falla | ⬜ |
| 3.8 | Acceso por Tailscale funciona | `ssh user@IP_TAILSCALE` funciona | ⬜ |
| 3.9 | (Opcional) Tailnet Lock activo | `tailscale lock status` | ⬜ |
| 3.10 | (Opcional) Webhooks configurados | Verificar en panel Tailscale | ⬜ |

### 4. OpenClaw

| # | Control | Verificación | Estado |
|---|---------|--------------|--------|
| 4.1 | Directorio estructura correcta | `ls ~/.openclaw/` | ⬜ |
| 4.2 | openclaw.json existe | `ls ~/.openclaw/openclaw.json` | ⬜ |
| 4.3 | .env existe y permisos 600 | `stat -c %a ~/openclaw/.env` = 600 | ⬜ |
| 4.4 | .env propietario correcto | `stat -c %U ~/openclaw/.env` = openclaw | ⬜ |
| 4.5 | Gateway host = 127.0.0.1 | `grep host ~/.openclaw/openclaw.json` | ⬜ |
| 4.6 | OpenClaw escucha localhost:18789 | `ss -tlnp \| grep 18789` = 127.0.0.1 | ⬜ |
| 4.7 | No escucha en 0.0.0.0 | `ss -tlnp \| grep 18789` ≠ 0.0.0.0 | ⬜ |
| 4.8 | Servicio systemd creado | `systemctl status openclaw` | ⬜ |
| 4.9 | Servicio habilitado | `systemctl is-enabled openclaw` | ⬜ |
| 4.10 | Hardening systemd aplicado | Ver archivo service | ⬜ |
| 4.11 | Puntuación systemd < 5 | `systemd-analyze security openclaw` | ⬜ |

### 5. Seguridad OpenClaw (OWASP AA4/AA5)

| # | Control | Verificación | Estado |
|---|---------|--------------|--------|
| 5.1 | openclaw.json existe | `ls ~/.openclaw/openclaw.json` | ⬜ |
| 5.2 | Sandbox mode = all | `grep sandbox ~/.openclaw/openclaw.json` | ⬜ |
| 5.3 | dmPolicy = pairing o closed | `grep dmPolicy ~/.openclaw/openclaw.json` | ⬜ |
| 5.4 | Gateway TLS pairing activo | `grep tls ~/.openclaw/openclaw.json` | ⬜ |
| 5.5 | TOOLS.md (allowlist) existe | `ls ~/openclaw/workspace/TOOLS.md` | ⬜ |
| 5.6 | SOUL.md (límites) existe | `ls ~/openclaw/workspace/SOUL.md` | ⬜ |
| 5.7 | No hay herramientas peligrosas | Revisar TOOLS.md manualmente | ⬜ |
| 5.8 | `openclaw security audit` sin errores | `openclaw security audit` | ⬜ |
| 5.9 | SecretRef configurado (no .env plano) | `openclaw secrets list` | ⬜ |
| 5.10 | Canal de actualización = stable | `openclaw update --channel` | ⬜ |

### 6. Seguridad del Agente (OWASP Agentic)

| # | Control | Referencia OWASP | Estado |
|---|---------|------------------|--------|
| 6.1 | Input validation configurado | AA1 | ⬜ |
| 6.2 | Output filtering activo | AA2 | ⬜ |
| 6.3 | Secrets redactados en outputs | AA2 | ⬜ |
| 6.4 | Principio mínimo privilegio | AA4 | ⬜ |
| 6.5 | Skills con allowlist | AA5 | ⬜ |
| 6.6 | Human-in-the-loop configurado | AA8 | ⬜ |
| 6.7 | Logging completo | AA10 | ⬜ |
| 6.8 | (Opcional) AppArmor perfil | AA4 | ⬜ |

### 7. Monitoreo y Mantenimiento

| # | Control | Verificación | Estado |
|---|---------|--------------|--------|
| 7.1 | Script de monitoreo existe | `ls ~/openclaw/scripts/monitor_behavior.sh` | ⬜ |
| 7.2 | Script de backup existe | `ls ~/openclaw/scripts/backup.sh` | ⬜ |
| 7.3 | Cron jobs configurados | `crontab -l` | ⬜ |
| 7.4 | Logs rotatados | `ls /etc/logrotate.d/openclaw` | ⬜ |
| 7.5 | Fecha última rotación API keys | `cat ~/.openclaw/.last_key_rotation` | ⬜ |
| 7.6 | Backup descargado a local | Verificar manualmente | ⬜ |

---

## Conformidad con estándares

### CIS Benchmark Ubuntu 24.04 L1

| Sección | Descripción | Cubierto |
|---------|-------------|----------|
| 5.2.1 | Permisos sshd_config | ✅ |
| 5.2.2 | Permisos claves SSH host | ✅ |
| 5.2.4 | Ciphers SSH | ✅ |
| 5.2.5 | MACs SSH | ✅ |
| 5.2.6 | KEX SSH | ✅ |
| 5.2.7 | Banner SSH | ✅ |
| 5.2.8 | LogLevel SSH | ✅ |
| 5.2.9-23 | Configuración SSH | ✅ |

### Tailscale Security Hardening

| Control | Descripción | Cubierto |
|---------|-------------|----------|
| ACLs | No usar permit-all | ✅ |
| Tags | Usar tags para segmentación | ✅ |
| SSH sobre Tailscale | Eliminar SSH público | ✅ |
| Tailnet Lock | Firmas criptográficas | ⬜ Opcional |
| Webhooks | Alertas de cambios | ⬜ Opcional |

### OWASP Agentic Top 10 2026

| ID | Riesgo | Mitigación | Cubierto |
|----|--------|------------|----------|
| AA1 | Agentic Injection | Input validation | ✅ |
| AA2 | Sensitive Data Exposure | Output filtering | ✅ |
| AA3 | Improper Output Handling | Sanitización | ✅ |
| AA4 | Excessive Agency | Mínimo privilegio | ✅ |
| AA5 | Tool Misuse | Skills allowlist | ✅ |
| AA6 | Insecure Memory | Memoria cifrada y con retención | ✅ |
| AA7 | Insufficient Identity | ACLs Tailscale | ✅ |
| AA8 | Unsafe Agentic Actions | Human-in-the-loop | ✅ |
| AA9 | Poor Multi-Agent Security | N/A (single agent) | ➖ |
| AA10 | Missing Audit Logs | Auditd, logging | ✅ |

---

## Firma de conformidad

```
Instalación verificada por: _________________________

Fecha: _________________________

Puntuación de verificación automática:
- Pasados: ____
- Advertencias: ____
- Fallidos: ____

Notas:
_________________________________________________
_________________________________________________
_________________________________________________
```

---

**Fin de la guía de instalación**

Para mantenimiento continuo, consulta [9. Mantenimiento](09-mantenimiento.md).
