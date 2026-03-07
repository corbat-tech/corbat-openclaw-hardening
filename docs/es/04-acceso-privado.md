# 4. Acceso privado con Tailscale

> **TL;DR**: Instalar Tailscale de forma segura, configurar ACLs obligatorias para zero-trust, cerrar SSH público y opcionalmente habilitar Tailnet Lock.

> **Tiempo estimado**: 20-30 minutos

> **Nivel requerido**: Intermedio

## Prerrequisitos

- [ ] Sección 3 (Seguridad del sistema) completada
- [ ] Usuario `openclaw` funcionando
- [ ] Cuenta Tailscale creada (con MFA en identity provider)

## Objetivos

Al terminar esta sección tendrás:

- Tailscale instalado y verificado en el VPS
- ACLs configuradas (zero-trust, no permit-all)
- SSH público eliminado (solo acceso por Tailscale)
- Opcionalmente: Tailnet Lock y webhooks de alertas

---

## ¿Qué es Tailscale?

- VPN mesh peer-to-peer basada en WireGuard
- Free tier: hasta 100 dispositivos, 3 usuarios
- Cada dispositivo recibe una IP privada tipo `100.x.x.x`
- Cifrado de extremo a extremo

```
┌─────────────────────────────────────────────┐
│              INTERNET                       │
│                  ❌                         │
│    Sin acceso directo al VPS               │
└─────────────────────────────────────────────┘
          ▲
          │ Tailscale VPN (WireGuard)
          │ Cifrado E2E
          ▼
┌─────────────────────────────────────────────┐
│         TU DISPOSITIVO                      │
│  IP Tailscale: 100.y.y.y                    │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│              VPS                            │
│  IP Tailscale: 100.x.x.x (única vía)        │
│  IP pública: cerrada                        │
└─────────────────────────────────────────────┘
```

!!! info "Placeholders en esta sección"
    En los ejemplos de esta sección:

    - `<TU_TAILSCALE_IP>` o `100.x.x.x` = IP de Tailscale de tu VPS (obtenida con `tailscale ip -4`)
    - `100.y.y.y` = IP de Tailscale de tu dispositivo local
    - `<TU_IP_PUBLICA>` = IP pública del VPS (la que te dio el proveedor)

    Reemplaza estos valores con tus IPs reales en cada comando.

---

## Instalar Tailscale en el VPS

Conéctate al VPS (todavía por IP pública):

```bash
ssh openclaw@<TU_IP_PUBLICA>
```

### Opción A: Instalación desde repositorio APT (RECOMENDADO)

Esta opción es más segura porque verifica firmas de paquetes.

```bash
# Añadir clave GPG de Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Añadir repositorio
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Instalar
sudo apt update
sudo apt install -y tailscale

# Verificar que se instaló desde el repo oficial
apt-cache policy tailscale
```

**Salida esperada:**
```
tailscale:
  Installed: 1.XX.X
  Candidate: 1.XX.X
  Version table:
 *** 1.XX.X 500
        500 https://pkgs.tailscale.com/stable/ubuntu noble/main amd64 Packages
```

### Opción B: Script de instalación (con verificación)

Si prefieres el script oficial, verifícalo antes de ejecutar:

```bash
# 1. Descargar script
curl -fsSL https://tailscale.com/install.sh -o /tmp/tailscale-install.sh

# 2. Verificar contenido (buscar comandos sospechosos)
# Revisa que solo descarga de dominios tailscale.com/pkgs.tailscale.com
less /tmp/tailscale-install.sh

# 3. Si todo parece correcto, ejecutar
sudo bash /tmp/tailscale-install.sh

# 4. Limpiar
rm /tmp/tailscale-install.sh
```

---

## Iniciar Tailscale

```bash
sudo tailscale up
```

Te dará una URL para autenticar. Ábrela en tu navegador e inicia sesión con tu cuenta Tailscale.

### Verificar conexión

```bash
# Ver IP de Tailscale asignada
tailscale ip -4

# Ver estado completo
tailscale status
```

**Salida esperada:**
```
100.x.x.x    tu-vps     linux   -
100.y.y.y    tu-laptop  macOS   active; relay "mad", tx 1234 rx 5678
```

Anota la IP de Tailscale del VPS (algo como `100.x.x.x`). Esta será tu **nueva forma de acceder**.

---

## Instalar Tailscale en tu dispositivo

### macOS

```bash
# Con Homebrew
brew install --cask tailscale
```

O descarga desde [tailscale.com/download](https://tailscale.com/download)

### Linux

```bash
# Usando repositorio APT (Ubuntu/Debian)
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
sudo apt update && sudo apt install -y tailscale
sudo tailscale up
```

### Windows / iOS / Android

Descarga la app desde la tienda correspondiente o [tailscale.com/download](https://tailscale.com/download)

---

## Probar conexión por Tailscale

Desde tu dispositivo local (con Tailscale activado):

```bash
# Usar la IP de Tailscale del VPS
ssh openclaw@<TU_TAILSCALE_IP>
```

!!! success "Si funciona, ya tienes acceso privado"
    A partir de ahora, usa esta IP para todo.

---

## Configurar ACLs (OBLIGATORIO)

!!! danger "No saltes este paso"
    Sin ACLs, cualquier dispositivo en tu Tailnet puede acceder a cualquier otro.
    Esto viola el principio de zero-trust y es un riesgo de seguridad.

Por defecto, Tailscale permite que todos los dispositivos se comuniquen entre sí (`"*": ["*:*"]`). Esto NO es seguro para un servidor con OpenClaw.

### Configurar ACL restrictiva

1. Ve a [login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls)
2. Reemplaza el contenido **completo** con:

```json
{
  // === ACLs para OpenClaw VPS ===
  // Referencia: https://tailscale.com/kb/1196/security-hardening

  "acls": [
    // Solo el owner puede acceder al VPS
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:vps:*"]
    },
    // El VPS puede acceder a Internet (para APIs de LLM)
    {
      "action": "accept",
      "src": ["tag:vps"],
      "dst": ["autogroup:internet:*"]
    }
    // NOTA: El VPS NO puede iniciar conexiones a otros dispositivos
  ],

  // Tags y sus propietarios
  "tagOwners": {
    "tag:vps": ["autogroup:owner"]
  },

  // Configuración de SSH por Tailscale
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:vps"],
      "users": ["openclaw"]
    }
  ],

  // Tests para validar las ACLs
  "tests": [
    // Verificar que owner puede acceder al VPS
    {
      "src": "autogroup:owner",
      "accept": ["tag:vps:22", "tag:vps:3000"]
    },
    // Verificar que VPS puede acceder a Internet
    {
      "src": "tag:vps",
      "accept": ["8.8.8.8:443"]
    },
    // Verificar que VPS NO puede acceder a dispositivos del owner
    {
      "src": "tag:vps",
      "deny": ["autogroup:owner:22", "autogroup:owner:80"]
    }
  ]
}
```

3. Haz clic en **Save** y verifica que los tests pasan.

### Aplicar tag al VPS

!!! danger "NUNCA ejecutes `tailscale down` una vez cerrado el SSH público"
    Si Tailscale es tu única forma de acceder al servidor y ejecutas `tailscale down`, perderás todo el acceso. La única recuperación es via el modo rescue del proveedor (ver Troubleshooting más abajo). Usa siempre `--reset` para reconfigurar sin cortar la conexión.

En el VPS, ejecuta:

```bash
sudo tailscale up --advertise-tags=tag:vps --reset
```

Te mostrará una URL para re-autenticar. Ábrela en el navegador y autoriza. **NO uses `tailscale down` + `tailscale up` — eso cortará tu conexión.**

### Verificar tags

```bash
tailscale status
```

**Salida esperada:**
```
100.x.x.x    tu-vps        tagged-devices  linux   -
```

El VPS debe aparecer como `tagged-devices` en lugar de tu email.

---

## Eliminar acceso SSH público

Este es el paso crítico. Una vez verificado Tailscale, **cierra el puerto 22 público**.

### Paso 1: Configurar SSH para escuchar solo en Tailscale

```bash
# Obtener tu IP de Tailscale
TAILSCALE_IP=$(tailscale ip -4)
echo "IP Tailscale: $TAILSCALE_IP"
```

Añade la directiva ListenAddress automáticamente (evita errores de copia manual):

```bash
# Añadir ListenAddress con tu IP real de Tailscale
echo "# === Escuchar SOLO en Tailscale ===" | sudo tee -a /etc/ssh/sshd_config.d/99-hardening.conf
echo "ListenAddress $(tailscale ip -4)" | sudo tee -a /etc/ssh/sshd_config.d/99-hardening.conf

# Verificar que se añadió correctamente
tail -2 /etc/ssh/sshd_config.d/99-hardening.conf
```

**Salida esperada:**
```
# === Escuchar SOLO en Tailscale ===
ListenAddress 100.64.0.1
```

!!! warning "IP de ejemplo"
    Tu IP será diferente (algo como `100.x.x.x`). El comando usa automáticamente tu IP real.

### Paso 2: Deshabilitar ssh.socket (Ubuntu 24.04)

!!! warning "Crítico: Ubuntu 24.04 usa activación por socket por defecto"
    Ubuntu 24.04 inicia SSH mediante `ssh.socket` (activación por socket de systemd), que escucha en `0.0.0.0:22` e **ignora la directiva `ListenAddress`** de sshd_config. Debes deshabilitarlo y cambiar al servicio tradicional `ssh.service` para que `ListenAddress` funcione.

```bash
# Deshabilitar activación por socket (ignora ListenAddress)
sudo systemctl disable --now ssh.socket

# Habilitar servicio SSH tradicional (respeta ListenAddress)
sudo systemctl enable ssh.service

# Crear directorio de separación de privilegios (normalmente lo crea ssh.socket)
sudo mkdir -p /run/sshd

# Matar procesos sshd residuales de la activación por socket
sudo kill $(cat /run/sshd.pid 2>/dev/null) 2>/dev/null || true
```

### Paso 3: Verificar sintaxis

```bash
sudo sshd -t
```

**Si hay errores, NO reinicies SSH.** Corrige primero.

### Paso 4: Reiniciar SSH

```bash
sudo systemctl restart ssh
```

### Paso 5: Eliminar regla de firewall

```bash
# Eliminar regla que permite SSH desde cualquier lugar
sudo ufw delete allow ssh

# Verificar estado
sudo ufw status
```

**Salida esperada:**
```
Status: active

To                         Action      From
--                         ------      ----
(sin reglas de SSH)
```

---

## Verificación final

!!! danger "Prueba ANTES de cerrar tu sesión actual"

### En una NUEVA terminal:

```bash
# 1. Conectar por Tailscale (DEBE funcionar)
ssh openclaw@<TU_TAILSCALE_IP>

# 2. Verificar que SSH público NO funciona
ssh openclaw@<TU_IP_PUBLICA>
# Esperado: Connection timed out o Connection refused
```

### Verificar que SSH solo escucha en Tailscale

```bash
sudo ss -tlnp | grep sshd
```

**Salida esperada:**
```
LISTEN  0  128  100.x.x.x:22  0.0.0.0:*  users:(("sshd",pid=XXX,fd=3))
```

!!! success "Si ves solo tu IP de Tailscale, el hardening está completo"

---

## Tailnet Lock (Seguridad avanzada)

!!! tip "Recomendado para máxima seguridad"
    Tailnet Lock asegura que incluso si Tailscale (la empresa) fuera comprometida,
    no podrían inyectar dispositivos maliciosos en tu red.

### ¿Qué es Tailnet Lock?

- Requiere firmas criptográficas para añadir dispositivos
- Los dispositivos de confianza firman nuevos dispositivos
- Incluso Tailscale (la empresa) no puede añadir dispositivos sin tu firma

### Activar Tailnet Lock

**Desde tu dispositivo principal (NO el VPS):**

```bash
# 1. Inicializar Tailnet Lock
tailscale lock init
```

Te mostrará una clave de firma. **Guárdala en lugar seguro offline.**

```bash
# 2. Ver tu clave de firma y nodos
tailscale lock status
```

```bash
# 3. Ver el node key del VPS (necesitas esto para firmarlo)
tailscale status
# Busca la línea del VPS y copia el node key
```

```bash
# 4. Firmar el VPS desde tu dispositivo principal
tailscale lock sign nodekey:<NODE_KEY_DEL_VPS>
```

### Verificar Tailnet Lock

```bash
tailscale lock status
```

**Salida esperada:**
```
Tailnet lock is ENABLED
...
Trusted signing keys:
  - nlpub:XXXX (this node)

Filtered nodes:
  (ninguno, si todos están firmados)
```

!!! warning "Guarda las claves de recuperación"
    Si pierdes acceso a todos los dispositivos firmantes, perderás acceso a la red.
    Guarda las claves en un gestor de contraseñas o lugar seguro offline.

---

## Webhooks de alertas (Opcional)

Recibe notificaciones cuando algo cambie en tu Tailnet.

### Configurar webhooks

1. Ve a [login.tailscale.com/admin/settings/webhooks](https://login.tailscale.com/admin/settings/webhooks)

2. Añade un webhook:
   - **Slack**: URL del incoming webhook
   - **Discord**: URL del webhook de Discord
   - **Custom**: Tu endpoint HTTP/HTTPS

3. Selecciona eventos a monitorear:

| Evento | Descripción | Recomendación |
|--------|-------------|---------------|
| `nodeCreated` | Nuevo dispositivo añadido | ✅ Activar |
| `nodeDeleted` | Dispositivo eliminado | ✅ Activar |
| `nodeApproved` | Dispositivo aprobado | ✅ Activar |
| `nodeKeyExpiring` | Clave a punto de expirar | ✅ Activar |
| `userCreated` | Nuevo usuario | ✅ Activar |
| `userDeleted` | Usuario eliminado | ✅ Activar |

### Ejemplo de payload de webhook

```json
{
  "timestamp": "2026-02-01T10:30:00Z",
  "event": "nodeCreated",
  "tailnet": "tu-tailnet.ts.net",
  "node": {
    "name": "nuevo-dispositivo",
    "addresses": ["100.x.x.x"]
  }
}
```

---

## MagicDNS Hardening

MagicDNS permite resolver nombres de dispositivos dentro de tu Tailnet. Para mayor seguridad:

### Verificar configuración de MagicDNS

1. Ve a [login.tailscale.com/admin/dns](https://login.tailscale.com/admin/dns)
2. Configura:
   - **MagicDNS:** Habilitado (para resolver nombres internos)
   - **Override local DNS:** Habilitado (para evitar DNS leaks)
   - **Global nameservers:** Configura servidores DNS seguros (ej: `1.1.1.1`, `9.9.9.9`)

### Añadir Split DNS (opcional)

Si necesitas resolver dominios internos específicos:

```json
{
  "dns": {
    "nameservers": ["1.1.1.1", "9.9.9.9"],
    "magicDNS": true,
    "overrideLocalDNS": true
  }
}
```

!!! tip "Ventaja de Override local DNS"
    Con `overrideLocalDNS: true`, todo el tráfico DNS del VPS pasa por los servidores configurados en Tailscale, evitando posibles DNS leaks a través del proveedor VPS.

---

## Expiración de claves de nodo

Por defecto, las claves de nodo de Tailscale expiran cada 180 días. Debes renovarlas o desactivar la expiración para el VPS.

### Opción A: Desactivar expiración (recomendado para servidores)

1. Ve a [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)
2. Encuentra tu VPS en la lista
3. Haz clic en el menú **...** → **Disable key expiry**

!!! warning "Implicación de seguridad"
    Desactivar la expiración significa que el nodo permanecerá autorizado indefinidamente.
    Esto es aceptable para servidores que no cambian de propietario.
    Para dispositivos personales, mantén la expiración activa.

### Opción B: Renovar manualmente

Si prefieres mantener la expiración activa, renueva antes de que expire:

```bash
# Ver cuándo expira la clave actual
tailscale status --json | jq '.Self.KeyExpiry'

# Renovar (requiere re-autenticación)
sudo tailscale up --reset
```

### Configurar alerta de expiración

Añade al cron una verificación semanal:

```bash
crontab -e
```

```cron
# Verificar expiración de clave Tailscale cada lunes
0 9 * * 1 tailscale status --json | jq -r '.Self.KeyExpiry // "no-expiry"' | logger -t tailscale-expiry
```

---

## Estado actual del sistema

```
┌─────────────────────────────────────────────┐
│              INTERNET                       │
│                  ❌                         │
│    Puerto 22 cerrado / no accesible         │
│    Sin puertos públicos                     │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│              VPS (Hetzner/otro)              │
│  IP pública: xxx.xxx.xxx.xxx (NO usada)     │
│  IP Tailscale: 100.x.x.x (única vía)        │
│  Tag: tag:vps                               │
│  ┌─────────────────────────────────────┐    │
│  │  SSH escuchando en 100.x.x.x:22     │    │
│  │  Firewall: deny all incoming        │    │
│  │  ACLs: solo owner puede acceder     │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
          ▲
          │ Tailscale VPN (cifrado WireGuard)
          │ ACLs verificadas
          ▼
┌─────────────────────────────────────────────┐
│         TU DISPOSITIVO (owner)              │
│  IP Tailscale: 100.y.y.y                    │
│  Puede: SSH a VPS, acceder a puerto 3000    │
└─────────────────────────────────────────────┘
```

---

## Comandos útiles de Tailscale

```bash
# Ver todos los dispositivos en tu red
tailscale status

# Ver tu IP de Tailscale
tailscale ip -4

# Ping a otro dispositivo por nombre
tailscale ping nombre-vps

# Ver logs de Tailscale
sudo journalctl -u tailscaled -f

# Desconectar temporalmente
tailscale down

# Reconectar
tailscale up

# Ver configuración actual
tailscale debug prefs
```

---

## Subir archivos al VPS

Ahora que solo tienes acceso por Tailscale, usa estos comandos para transferir archivos:

```bash
# Subir un archivo
scp archivo.txt openclaw@<TU_TAILSCALE_IP>:~/workspace/

# Subir una carpeta
scp -r mi-carpeta/ openclaw@<TU_TAILSCALE_IP>:~/workspace/

# Sincronizar carpeta (más eficiente para actualizaciones)
rsync -avz mi-carpeta/ openclaw@<TU_TAILSCALE_IP>:~/workspace/mi-carpeta/

# Descargar archivo del VPS
scp openclaw@<TU_TAILSCALE_IP>:~/workspace/resultado.txt ./
```

---

## Troubleshooting

### Error: "Tailscale not running"

**Causa**: El servicio tailscaled no está activo.

**Solución**:
```bash
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
tailscale up
```

### Error: "Not authorized" al usar tags

**Causa**: Las ACLs no permiten el tag o no eres owner del tag.

**Solución**:
1. Verifica que `tagOwners` incluye tu usuario o `autogroup:owner`
2. Verifica que guardaste las ACLs en el panel de Tailscale

### Error: "Connection timed out" por Tailscale

**Causa**: Firewall local o de red bloqueando WireGuard.

**Solución**:
```bash
# Verificar que tailscaled está escuchando
sudo ss -ulnp | grep tailscale

# Verificar conectividad
tailscale netcheck
```

### SSH sigue accesible en la IP pública tras configurar ListenAddress

**Causa**: Ubuntu 24.04 usa `ssh.socket` (activación por socket de systemd) que escucha en `0.0.0.0:22` e ignora `ListenAddress`.

**Solución**:
```bash
# Verificar si ssh.socket está activo
systemctl is-active ssh.socket

# Si está activo, deshabilitarlo y cambiar al servicio tradicional
sudo systemctl disable --now ssh.socket
sudo systemctl enable ssh.service
sudo mkdir -p /run/sshd
sudo kill $(cat /run/sshd.pid 2>/dev/null) 2>/dev/null || true
sudo systemctl restart ssh

# Verificar que solo escucha en la IP de Tailscale
ss -tln | grep :22
```

### Error: "Cannot bind any address" o "Address already in use"

**Causa**: Tras deshabilitar `ssh.socket`, quedan procesos sshd residuales de la activación por socket que siguen ocupando el puerto.

**Solución**:
```bash
# Matar proceso sshd residual
sudo kill $(cat /run/sshd.pid 2>/dev/null) 2>/dev/null || true
sudo systemctl restart ssh
```

### Error: "Missing privilege separation directory: /run/sshd"

**Causa**: El directorio `/run/sshd` normalmente lo crea `ssh.socket`. Tras deshabilitarlo, el directorio no existe.

**Solución**:
```bash
sudo mkdir -p /run/sshd
sudo systemctl restart ssh
```

### Perdí el acceso: SSH público cerrado y Tailscale caído

**Causa**: Ejecutaste `tailscale down` o Tailscale se detuvo cuando el SSH público ya estaba cerrado. La consola del VPS tampoco funciona si tu usuario no tiene contraseña (autenticación solo por clave SSH).

**Solución — Modo Rescue de Hetzner:**

1. En el panel de Hetzner Cloud → tu servidor → pestaña **Rescue** → **Enable Rescue & Power Cycle**
2. Copia la **contraseña de root** que muestra el panel
3. Ve a la pestaña **Power** → **Power cycle** el servidor (arrancará en rescue)
4. Desde tu máquina local, elimina la clave antigua y conecta:
    ```bash
    ssh-keygen -R <TU_IP_PUBLICA>
    ssh root@<TU_IP_PUBLICA>
    ```
    Usa la contraseña de root del rescue del paso 2.
5. Monta tu disco y levanta Tailscale:
    ```bash
    # Montar el sistema de archivos del servidor
    mount /dev/sda1 /mnt

    # Chroot a tu sistema
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    chroot /mnt

    # Levantar Tailscale
    tailscale up --advertise-tags=tag:vps
    ```
6. Tras re-autenticar, sal del chroot y reinicia en modo normal:
    ```bash
    exit
    umount -R /mnt
    reboot
    ```
7. En el panel de Hetzner → pestaña **Rescue** → **Disable Rescue** para que el siguiente reinicio sea normal.

!!! tip "Cloud Firewall de Hetzner"
    El modo rescue arranca un sistema diferente que ignora UFW, pero sí respeta el **Cloud Firewall de Hetzner**. Si SSH al rescue es rechazado, ve a la pestaña **Firewalls** y añade temporalmente una regla de entrada permitiendo TCP puerto 22.

---

## Resumen

| Configuración | Estado |
|--------------|--------|
| Tailscale instalado | ✅ |
| Verificado desde repo oficial | ✅ |
| ACLs configuradas (no permit-all) | ✅ |
| Tag `vps` asignado | ✅ |
| SSH solo en interfaz Tailscale | ✅ |
| Puerto 22 público cerrado | ✅ |
| Tailnet Lock (opcional) | ⬜ |
| Webhooks configurados (opcional) | ⬜ |

---

**Siguiente:** [5. Instalar OpenClaw](05-openclaw.md)
