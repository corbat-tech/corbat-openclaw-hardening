# 3. Seguridad del sistema

> **TL;DR**: Crear usuario no-root, asegurar SSH según CIS Benchmark, configurar firewall, fail2ban, auditoría y monitoreo de integridad.

> **Tiempo estimado**: 30-40 minutos

> **Nivel requerido**: Intermedio

## Prerrequisitos

- [ ] VPS creado con Ubuntu 24.04 LTS
- [ ] Acceso root por SSH funcionando
- [ ] Clave SSH Ed25519 generada localmente

## Objetivos

Al terminar esta sección tendrás:

- Usuario `openclaw` dedicado sin privilegios de root
- SSH hardening completo según CIS Benchmark Ubuntu 24.04 L1
- Firewall UFW con política deny-all
- Fail2ban protegiendo contra brute-force
- Actualizaciones de seguridad automáticas
- Auditoría de eventos críticos (auditd)
- Monitoreo de integridad de archivos (AIDE)

---

## Crear usuario dedicado

!!! danger "Nunca ejecutes OpenClaw como root"
    Un agente AI con acceso root puede comprometer completamente el sistema.

```bash
# Crear usuario 'openclaw' con home directory
adduser openclaw
```

Te pedirá:

- **Contraseña:** usa una fuerte (mínimo 16 caracteres)
- **Nombre completo, etc.:** puedes dejar en blanco (Enter)

```bash
# Dar permisos de sudo (necesario para instalación inicial)
usermod -aG sudo openclaw
```

### Verificar creación

```bash
# Verificar que el usuario existe
id openclaw
```

**Salida esperada:**
```
uid=1001(openclaw) gid=1001(openclaw) groups=1001(openclaw),27(sudo)
```

---

## Configurar SSH para el nuevo usuario

### Copiar la clave SSH al usuario

```bash
# Crear directorio .ssh para el usuario
mkdir -p /home/openclaw/.ssh

# Copiar las claves autorizadas
cp /root/.ssh/authorized_keys /home/openclaw/.ssh/

# Ajustar permisos (CRÍTICO para seguridad)
chown -R openclaw:openclaw /home/openclaw/.ssh
chmod 700 /home/openclaw/.ssh
chmod 600 /home/openclaw/.ssh/authorized_keys
```

### Verificar acceso antes de continuar

!!! danger "No sigas sin probar esto"
    Abre una **nueva terminal** (sin cerrar la actual) y prueba:

```bash
# Desde tu máquina local, en una NUEVA terminal
ssh openclaw@<TU_IP_PUBLICA>
```

Si funciona, continúa. Si no, revisa los permisos antes de seguir.

---

## Asegurar SSH (CIS Benchmark 5.2 completo)

Esta configuración cumple con el **CIS Benchmark Ubuntu 24.04 LTS Level 1** para SSH.

### Crear backup de configuración original

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
```

### Crear configuración hardened

```bash
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
# ============================================================
# SSH Hardening - CIS Benchmark Ubuntu 24.04 LTS L1
# Fecha: 2026-02
# Referencia: https://www.cisecurity.org/benchmark/ubuntu_linux
# ============================================================

# --- 5.2.4 - Ciphers seguros ---
# Solo algoritmos de cifrado modernos y seguros
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# --- 5.2.5 - MACs seguros ---
# Solo algoritmos de autenticación de mensajes seguros
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# --- 5.2.6 - Key Exchange seguros ---
# Solo algoritmos de intercambio de claves seguros
# Incluye sntrup761x25519-sha512 para resistencia post-cuántica (recomendado desde abril 2025)
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256

# --- 5.2.7 - Banner de advertencia ---
Banner /etc/issue.net

# --- 5.2.8 - Logging detallado ---
LogLevel VERBOSE

# --- 5.2.9 - Desactivar X11 forwarding ---
X11Forwarding no

# --- 5.2.10 - MaxAuthTries ---
# Máximo 4 intentos de autenticación por conexión
MaxAuthTries 4

# --- 5.2.11 - Ignorar rhosts ---
IgnoreRhosts yes

# --- 5.2.12 - Desactivar autenticación basada en host ---
HostbasedAuthentication no

# --- 5.2.13 - Desactivar login root ---
PermitRootLogin no

# --- 5.2.14 - Desactivar contraseñas vacías ---
PermitEmptyPasswords no

# --- 5.2.15 - Desactivar environment de usuario ---
PermitUserEnvironment no

# --- 5.2.17 - Timeout de conexión ---
# Desconectar clientes inactivos después de 15 minutos (300s * 3)
ClientAliveInterval 300
ClientAliveCountMax 3

# --- 5.2.18 - Tiempo de gracia para login ---
# Solo 60 segundos para completar autenticación
LoginGraceTime 60

# --- 5.2.19 - Limitar usuarios ---
# CRÍTICO: Solo el usuario openclaw puede conectarse
AllowUsers openclaw

# --- 5.2.20 - MaxStartups (anti-DoS) ---
# Limitar conexiones simultáneas no autenticadas
MaxStartups 10:30:60

# --- 5.2.21 - MaxSessions ---
MaxSessions 10

# --- 5.2.22 - Desactivar autenticación por contraseña ---
PasswordAuthentication no
KbdInteractiveAuthentication no

# --- 5.2.23 - Usar solo claves públicas ---
PubkeyAuthentication yes

# --- Configuración adicional de seguridad ---

# Allow local forwarding only (needed for OpenClaw access via SSH tunnel)
AllowTcpForwarding local
AllowAgentForwarding no

# Desactivar túneles
PermitTunnel no

# Nota: "Protocol 2" es obsoleto en OpenSSH 9.x (ya solo soporta v2)
# ListenAddress se configurará después de instalar Tailscale
# para escuchar solo en la interfaz de Tailscale
EOF
```

### Crear banner de advertencia legal

```bash
sudo tee /etc/issue.net << 'EOF'
***************************************************************************
                            SISTEMA PRIVADO

  El acceso no autorizado está prohibido. Todas las actividades son
  monitoreadas y registradas. El uso de este sistema implica aceptación
  de las políticas de seguridad.

  Unauthorized access is prohibited. All activities are monitored and
  logged. Use of this system implies acceptance of security policies.
***************************************************************************
EOF
```

### Aplicar permisos CIS

```bash
# 5.2.1 - Permisos sshd_config
sudo chmod 600 /etc/ssh/sshd_config
sudo chown root:root /etc/ssh/sshd_config

# 5.2.2 - Permisos claves privadas del host
sudo chmod 600 /etc/ssh/ssh_host_*_key
sudo chown root:root /etc/ssh/ssh_host_*_key

# 5.2.3 - Permisos claves públicas del host
sudo chmod 644 /etc/ssh/ssh_host_*_key.pub
sudo chown root:root /etc/ssh/ssh_host_*_key.pub

# Permisos del archivo de configuración hardening
sudo chmod 600 /etc/ssh/sshd_config.d/99-hardening.conf
sudo chown root:root /etc/ssh/sshd_config.d/99-hardening.conf
```

### Verificar configuración antes de aplicar

!!! danger "CRÍTICO: Verifica sintaxis antes de reiniciar"
    Un error de sintaxis puede dejarte sin acceso SSH.

```bash
# Verificar sintaxis
sudo sshd -t
```

**Salida esperada:** ningún output (silencio = éxito)

Si hay errores, corrígelos antes de continuar.

```bash
# Si no hay errores, reiniciar SSH
sudo systemctl restart sshd

# Verificar que está corriendo
sudo systemctl status sshd
```

### Verificar controles aplicados

```bash
# Script de verificación CIS SSH
echo "=== Verificación CIS SSH ==="
echo -n "PasswordAuthentication: "
sudo sshd -T | grep -i "^passwordauthentication"
echo -n "PermitRootLogin: "
sudo sshd -T | grep -i "^permitrootlogin"
echo -n "MaxAuthTries: "
sudo sshd -T | grep -i "^maxauthtries"
echo -n "X11Forwarding: "
sudo sshd -T | grep -i "^x11forwarding"
echo -n "LogLevel: "
sudo sshd -T | grep -i "^loglevel"
echo -n "AllowUsers: "
sudo sshd -T | grep -i "^allowusers"
echo -n "Ciphers: "
sudo sshd -T | grep -i "^ciphers"
```

**Salida esperada:**
```
=== Verificación CIS SSH ===
PasswordAuthentication: passwordauthentication no
PermitRootLogin: permitrootlogin no
MaxAuthTries: maxauthtries 4
X11Forwarding: x11forwarding no
LogLevel: loglevel VERBOSE
AllowUsers: allowusers openclaw
Ciphers: ciphers chacha20-poly1305@openssh.com,...
```

### Verificar acceso con nueva configuración

!!! warning "Mantén tu sesión actual abierta"
    No cierres tu sesión hasta verificar el nuevo acceso.

En una **nueva terminal**:

```bash
# Esto debe funcionar
ssh openclaw@<TU_IP_PUBLICA>

# Esto debe FALLAR (root desactivado)
ssh root@<TU_IP_PUBLICA>
# Esperado: Permission denied (publickey)
```

---

## Configurar firewall (UFW)

```bash
# Configurar políticas por defecto
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Permitir SSH (temporal, se eliminará tras Tailscale)
sudo ufw allow ssh

# Habilitar firewall
sudo ufw enable
# Confirma con 'y'
```

### Verificar firewall

```bash
sudo ufw status verbose
```

**Salida esperada:**
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

---

## Fail2ban (protección brute-force)

Fail2ban banea IPs que intentan múltiples logins fallidos.

!!! info "Versión verificada"
    Esta configuración fue probada con fail2ban **1.0.2** en Ubuntu 24.04 LTS.
    Verifica tu versión con: `fail2ban-client --version`

```bash
# Instalar
sudo apt install -y fail2ban

# Crear configuración local (no se sobreescribe en updates)
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban por 1 hora
bantime = 3600
# Ventana de tiempo para contar fallos
findtime = 600
# Máximo de fallos antes de ban
maxretry = 5
# Usar systemd para logs
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
# No se necesita logpath: el backend systemd (configurado en [DEFAULT]) lee desde journald
maxretry = 3
bantime = 86400
EOF

# Habilitar y arrancar
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Verificar fail2ban

```bash
sudo fail2ban-client status sshd
```

**Salida esperada:**
```
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- File list:        /var/log/auth.log
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:
```

---

## Alternativa: CrowdSec (protección colaborativa)

!!! tip "CrowdSec vs Fail2Ban"
    CrowdSec es una alternativa moderna a Fail2Ban con inteligencia de amenazas comunitaria.

    | Característica | Fail2Ban | CrowdSec |
    |---|---|---|
    | **Recursos** | Muy bajos | Moderados |
    | **Intel comunitaria** | No | Sí (blocklists compartidas) |
    | **Detección** | Reactiva (log-based) | Proactiva (behavioral) |
    | **Mejor para** | VPS simple, bajo tráfico | Producción, multi-servidor |
    | **Integración nftables** | Via acciones | Nativa |

    **Para un VPS personal con OpenClaw**, Fail2Ban es suficiente. Considera CrowdSec si planeas escalar o necesitas protección proactiva.

### Instalar CrowdSec (opcional, alternativa a Fail2Ban)

```bash
# Download and inspect the install script first
curl -sO https://install.crowdsec.net/install.sh
less install.sh  # Review the script
sudo bash install.sh
rm install.sh

# Instalar CrowdSec
sudo apt install -y crowdsec crowdsec-firewall-bouncer-nftables

# Verificar instalación
sudo cscli version

# Ver decisiones activas (IPs bloqueadas)
sudo cscli decisions list

# Ver alertas
sudo cscli alerts list
```

!!! warning "No uses Fail2Ban y CrowdSec simultáneamente para SSH"
    Elige uno u otro para evitar conflictos. Si instalas CrowdSec, desactiva la jail SSH de Fail2Ban.

---

## Actualizaciones automáticas de seguridad

```bash
# Instalar
sudo apt install -y unattended-upgrades

# Configurar para actualizaciones automáticas de seguridad
sudo dpkg-reconfigure -plow unattended-upgrades
# Selecciona "Yes"
```

### Verificar configuración

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades
```

**Salida esperada:**
```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

---

## Configurar auditoría (auditd)

El sistema de auditoría registra eventos de seguridad críticos.

!!! info "Versión verificada"
    Esta configuración fue probada con auditd **3.1.2** en Ubuntu 24.04 LTS.
    Verifica tu versión con: `auditctl -v`

```bash
# Instalar auditd
sudo apt install -y auditd audispd-plugins

# Habilitar servicio
sudo systemctl enable auditd
sudo systemctl start auditd
```

### Crear reglas de auditoría

```bash
sudo tee /etc/audit/rules.d/openclaw.rules << 'EOF'
# ============================================================
# Reglas de Auditoría para OpenClaw VPS
# ============================================================

# Eliminar reglas anteriores
-D

# Buffer de auditoría
-b 8192

# Qué hacer si el buffer se llena (0=silencio, 1=printk, 2=panic)
-f 1

# --- Monitorear archivos críticos del sistema ---
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d -p wa -k sshd_config
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes

# --- Monitorear claves SSH ---
-w /home/openclaw/.ssh -p wa -k ssh_keys
-w /root/.ssh -p wa -k ssh_keys

# --- Monitorear OpenClaw ---
-w /home/openclaw/openclaw -p wa -k openclaw_changes
-w /home/openclaw/openclaw/.env -p r -k env_access

# --- Monitorear comandos sudo ---
-w /var/log/sudo.log -p wa -k sudo_log

# --- Monitorear cambios en servicios ---
-w /etc/systemd/system -p wa -k systemd_changes
-w /lib/systemd/system -p wa -k systemd_changes

# --- Monitorear logins ---
-w /var/log/lastlog -p wa -k logins
-w /var/log/faillog -p wa -k logins

# --- Hacer reglas inmutables (requiere reboot para cambiar) ---
-e 2
EOF
```

### Cargar reglas

```bash
# Recargar reglas
sudo augenrules --load

# Reiniciar servicio
sudo systemctl restart auditd
```

### Verificar auditoría

```bash
# Ver reglas activas
sudo auditctl -l
```

**Salida esperada:** Lista de reglas `-w` configuradas

```bash
# Ver eventos recientes (puede estar vacío inicialmente)
sudo ausearch -ts recent
```

---

## Monitoreo de integridad (AIDE)

AIDE (Advanced Intrusion Detection Environment) detecta cambios no autorizados en archivos.

!!! info "Versión verificada"
    Esta configuración fue probada con AIDE **0.18.6** en Ubuntu 24.04 LTS.
    Verifica tu versión con: `aide --version`

```bash
# Instalar AIDE
sudo apt install -y aide aide-common
```

### Configurar paths a monitorear

```bash
sudo tee /etc/aide/aide.conf.d/99-openclaw << 'EOF'
# Archivos críticos de OpenClaw
/home/openclaw/openclaw/config CONTENT_EX
/home/openclaw/openclaw/.env PERMS
/home/openclaw/.ssh CONTENT_EX

# Archivos críticos del sistema
/etc/ssh CONTENT_EX
/etc/passwd CONTENT_EX
/etc/shadow PERMS
/etc/sudoers CONTENT_EX
EOF
```

### Inicializar base de datos

!!! info "Este proceso tarda varios minutos"
    AIDE escanea todo el sistema para crear la base de datos inicial.

```bash
# Inicializar base de datos (puede tardar 5-10 minutos)
sudo aideinit
```

```bash
# Mover base de datos a ubicación activa
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Verificar integridad

```bash
# Ejecutar verificación (ejecutar periódicamente o vía cron)
sudo aide --check
```

**Salida esperada (si no hay cambios):**
```
AIDE found NO differences between database and filesystem. Looks okay!!
```

### Programar verificación automática

```bash
# Crear cron job para verificación diaria
sudo tee /etc/cron.daily/aide-check << 'EOF'
#!/bin/bash
/usr/bin/aide --check > /var/log/aide-check.log 2>&1
if [ $? -ne 0 ]; then
    echo "AIDE detectó cambios - revisar /var/log/aide-check.log" | logger -t aide
fi
EOF

sudo chmod +x /etc/cron.daily/aide-check
```

---

## Hardening de kernel (sysctl)

Configurar parámetros del kernel para mayor seguridad de red.

### Crear configuración de seguridad

```bash
sudo tee /etc/sysctl.d/99-security-hardening.conf << 'EOF'
# ============================================================
# Kernel Security Hardening
# Referencia: CIS Benchmark Ubuntu 24.04 - Sección 3.2
# ============================================================

# --- Deshabilitar IP forwarding (3.2.1) ---
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# --- Deshabilitar envío de redirects (3.2.2) ---
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# --- No aceptar source routing (3.2.3) ---
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# --- No aceptar ICMP redirects (3.2.4) ---
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# --- No aceptar secure ICMP redirects (3.2.5) ---
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# --- Registrar paquetes sospechosos (3.2.6) ---
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# --- Ignorar broadcast ICMP (3.2.7) ---
net.ipv4.icmp_echo_ignore_broadcasts = 1

# --- Ignorar respuestas ICMP falsas (3.2.8) ---
net.ipv4.icmp_ignore_bogus_error_responses = 1

# --- Habilitar verificación de ruta reversa (3.2.9) ---
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# --- Habilitar TCP SYN Cookies (3.2.10) ---
net.ipv4.tcp_syncookies = 1

# --- No aceptar router advertisements IPv6 (3.2.11) ---
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF
```

!!! note "Compatibilidad con Tailscale"
    Si planeas usar este VPS como subnet router o exit node de Tailscale, cambia `ip_forward` a `1`. Para un despliegue estándar de OpenClaw (el alcance de esta guía), `0` es correcto.

### Aplicar configuración

```bash
# Aplicar inmediatamente
sudo sysctl -p /etc/sysctl.d/99-security-hardening.conf

# Verificar que se aplicó
sudo sysctl net.ipv4.ip_forward
sudo sysctl net.ipv4.conf.all.send_redirects
```

**Salida esperada:**

```
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
```

---

## Verificación final de seguridad

Ejecuta este script para verificar todos los controles:

```bash
echo "============================================"
echo "VERIFICACIÓN DE SEGURIDAD DEL SISTEMA"
echo "============================================"
echo ""

echo "--- Usuario openclaw ---"
id openclaw && echo "✅ Usuario existe" || echo "❌ Usuario NO existe"
echo ""

echo "--- SSH Hardening ---"
sudo sshd -T 2>/dev/null | grep -q "passwordauthentication no" && echo "✅ Password auth desactivado" || echo "❌ Password auth ACTIVO"
sudo sshd -T 2>/dev/null | grep -q "permitrootlogin no" && echo "✅ Root login desactivado" || echo "❌ Root login ACTIVO"
sudo sshd -T 2>/dev/null | grep -q "allowusers openclaw" && echo "✅ AllowUsers configurado" || echo "❌ AllowUsers NO configurado"
echo ""

echo "--- Firewall ---"
sudo ufw status | grep -q "Status: active" && echo "✅ UFW activo" || echo "❌ UFW NO activo"
echo ""

echo "--- Fail2ban ---"
systemctl is-active fail2ban >/dev/null && echo "✅ Fail2ban activo" || echo "❌ Fail2ban NO activo"
echo ""

echo "--- Unattended Upgrades ---"
systemctl is-active unattended-upgrades >/dev/null && echo "✅ Auto-updates activo" || echo "❌ Auto-updates NO activo"
echo ""

echo "--- Auditd ---"
systemctl is-active auditd >/dev/null && echo "✅ Auditd activo" || echo "❌ Auditd NO activo"
sudo auditctl -l | grep -q "openclaw" && echo "✅ Reglas OpenClaw cargadas" || echo "❌ Reglas OpenClaw NO cargadas"
echo ""

echo "--- AIDE ---"
[ -f /var/lib/aide/aide.db ] && echo "✅ AIDE inicializado" || echo "❌ AIDE NO inicializado"
echo ""

echo "============================================"
echo "Verificación completada"
echo "============================================"
```

---

## Troubleshooting

### Error: "Permission denied (publickey)"

**Causa**: La clave SSH no está correctamente configurada para el usuario.

**Solución**:
```bash
# Verificar permisos
ls -la /home/openclaw/.ssh/
# authorized_keys debe tener permisos 600
# .ssh debe tener permisos 700

# Corregir si es necesario
sudo chmod 700 /home/openclaw/.ssh
sudo chmod 600 /home/openclaw/.ssh/authorized_keys
sudo chown -R openclaw:openclaw /home/openclaw/.ssh
```

### Error: "Connection refused" después de reiniciar SSH

**Causa**: Error de sintaxis en la configuración SSH.

**Solución**:
```bash
# Si tienes otra sesión abierta, verifica el error
sudo journalctl -u sshd -n 50

# Restaurar backup
sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
sudo rm /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl restart sshd
```

### Error: "Too many authentication failures"

**Causa**: Has sido baneado por fail2ban.

**Solución**:
```bash
# Ver IPs baneadas
sudo fail2ban-client status sshd

# Desbanear tu IP
sudo fail2ban-client set sshd unbanip <TU_IP>
```

---

## Resumen de lo hecho

| Configuración | Estado esperado | Referencia CIS |
|--------------|-----------------|----------------|
| Usuario `openclaw` creado | ✅ | - |
| SSH con clave pública | ✅ | 5.2.23 |
| Password login desactivado | ✅ | 5.2.22 |
| Root login desactivado | ✅ | 5.2.13 |
| Ciphers seguros | ✅ | 5.2.4 |
| MACs seguros | ✅ | 5.2.5 |
| MaxAuthTries = 4 | ✅ | 5.2.10 |
| Banner configurado | ✅ | 5.2.7 |
| Firewall activo (deny all) | ✅ | - |
| Fail2ban activo | ✅ | - |
| Actualizaciones automáticas | ✅ | - |
| Auditd configurado | ✅ | - |
| AIDE inicializado | ✅ | - |
| SSH permitido (temporal) | ✅ | - |

!!! info "El puerto SSH público es temporal"
    En el siguiente paso configuraremos Tailscale y **eliminaremos** el acceso SSH público.

---

## Eliminar sudo del usuario openclaw

!!! danger "Principio de mínimo privilegio"
    El usuario `openclaw` fue añadido al grupo `sudo` para realizar la configuración inicial en las secciones 3-5. Una vez completada toda la configuración (incluyendo Tailscale en la sección 4 y OpenClaw en la sección 5), el acceso sudo debe eliminarse. Un usuario de agente AI con sudo permanente es un riesgo crítico — cualquier compromiso del agente otorga acceso root completo.

Tras completar todos los pasos de configuración de las secciones 3 a 5, elimina el acceso sudo del usuario `openclaw`:

```bash
# Ejecutar desde una sesión root o admin separada, NO como el usuario openclaw
sudo deluser openclaw sudo
```

Verifica el cambio:

```bash
id openclaw
```

**Salida esperada (sin grupo `sudo`):**
```
uid=1001(openclaw) gid=1001(openclaw) groups=1001(openclaw)
```

!!! warning "Mantén una sesión de recuperación"
    Antes de eliminar sudo, asegúrate de tener otra forma de administrar el sistema (por ejemplo, acceso root vía la consola del proveedor VPS u otro usuario admin con sudo). Si necesitas realizar tareas administrativas más adelante, puedes re-añadir temporalmente el acceso sudo desde esa sesión de recuperación.

---

**Siguiente:** [4. Acceso privado (Tailscale)](04-acceso-privado.md) — Configurar VPN y eliminar acceso público.
