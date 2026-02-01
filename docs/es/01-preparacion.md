# 1. Preparación

> **TL;DR**: Crear cuentas necesarias, generar clave SSH segura con passphrase, verificar herramientas locales y configurar límites de gasto en APIs.

> **Tiempo estimado**: 15-20 minutos

> **Nivel requerido**: Principiante

## Prerrequisitos

- Acceso a terminal (macOS/Linux) o PowerShell (Windows)
- Navegador web
- Tarjeta de crédito para VPS (~5-10€/mes)

## Objetivos

Al terminar esta sección tendrás:

- Cuenta en proveedor de VPS
- Cuenta en Tailscale (con MFA activado)
- Clave SSH Ed25519 con passphrase segura
- Límites de gasto configurados en APIs de LLM

---

## Verificar herramientas locales

Antes de empezar, verifica que tienes las herramientas necesarias en tu máquina local.

### macOS / Linux

```bash
# Verificar SSH (debe ser OpenSSH 8.0+)
ssh -V
```

**Salida esperada:**
```
OpenSSH_9.x, ...
```

```bash
# Verificar curl
curl --version
```

```bash
# Verificar GPG (opcional, para verificar firmas)
gpg --version
```

### Windows

Abre PowerShell y ejecuta:

```powershell
# Verificar SSH
ssh -V

# Si no está instalado, usar:
# Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

---

## Cuentas necesarias

| Servicio | Enlace | Notas |
|----------|--------|-------|
| VPS (Hetzner/Hostinger) | [hetzner.com](https://www.hetzner.com) / [hostinger.es](https://www.hostinger.es) | ~5-10€/mes |
| Tailscale | [tailscale.com](https://tailscale.com) | Gratis (login con Google/GitHub/Microsoft) |
| LLM API | Ver [sección 6](06-llm-apis.md) | Kimi K2.5 gratis en NVIDIA NIM |

### Crear cuenta Tailscale

1. Ve a [login.tailscale.com](https://login.tailscale.com)
2. Inicia sesión con Google, GitHub, Microsoft u otro proveedor
3. Sigue el wizard inicial (puedes saltarlo, lo configuraremos después)

!!! danger "Activa MFA en tu identity provider"
    Tailscale hereda la seguridad de tu identity provider. Si alguien compromete tu cuenta de Google/GitHub, compromete tu Tailnet (y tu VPS).

    **Activa 2FA/MFA en tu cuenta de Google/GitHub/Microsoft AHORA:**

    - **Google:** [myaccount.google.com/security](https://myaccount.google.com/security)
    - **GitHub:** Settings → Password and authentication → Two-factor authentication
    - **Microsoft:** [account.microsoft.com/security](https://account.microsoft.com/security)

---

## Generar clave SSH

Las claves SSH son más seguras que las contraseñas y son **obligatorias** para esta guía.

### Crear passphrase segura

Primero, genera una passphrase segura para proteger tu clave SSH:

```bash
# Generar passphrase aleatoria de 24 caracteres
openssl rand -base64 24
```

**Salida esperada:**
```
K7mP2xQ9vR4tY8wE3nL6jH1fG5bA0cD=
```

!!! tip "Guarda la passphrase"
    Guarda esta passphrase en un gestor de contraseñas (1Password, Bitwarden, etc.).
    La necesitarás cada vez que uses la clave SSH.

### Generar clave Ed25519

```bash
# Generar clave Ed25519 (más segura que RSA)
ssh-keygen -t ed25519 -C "openclaw-vps-$(date +%Y)"
```

Te preguntará:

1. **Ubicación:** Acepta el default (`~/.ssh/id_ed25519`) o especifica una ruta
2. **Passphrase:** Usa la passphrase que generaste arriba

**Salida esperada:**
```
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/user/.ssh/id_ed25519):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/user/.ssh/id_ed25519
Your public key has been saved in /home/user/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:XXXXX openclaw-vps-2026
```

### Verificar que la clave se generó correctamente

```bash
# Ver la clave pública (esto es lo que subirás a Hostinger/Hetzner)
cat ~/.ssh/id_ed25519.pub
```

**Salida esperada:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... openclaw-vps-2026
```

```bash
# Verificar permisos (deben ser restrictivos)
ls -la ~/.ssh/id_ed25519*
```

**Salida esperada:**
```
-rw------- 1 user user  464 Feb  1 10:00 /home/user/.ssh/id_ed25519
-rw-r--r-- 1 user user  105 Feb  1 10:00 /home/user/.ssh/id_ed25519.pub
```

!!! warning "La clave privada (sin .pub) nunca se comparte"
    - `id_ed25519` = Clave PRIVADA (nunca compartir, nunca subir)
    - `id_ed25519.pub` = Clave PÚBLICA (esta se sube al VPS)

### Configurar SSH agent (opcional pero recomendado)

Para no tener que escribir la passphrase cada vez:

```bash
# Iniciar SSH agent
eval "$(ssh-agent -s)"

# Añadir clave (te pedirá la passphrase una vez)
ssh-add ~/.ssh/id_ed25519
```

En macOS, puedes guardar la passphrase en Keychain:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

---

## Configurar límite de gasto en LLM

!!! danger "Hazlo ANTES de usar cualquier API de pago"
    Sin límites configurados, un bug o uso excesivo puede generar facturas inesperadas de cientos o miles de euros.

### OpenAI

1. Ve a [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits)
2. En **Usage limits**:
   - **Hard limit:** 50€ (se detiene al llegar)
   - **Soft limit:** 30€ (te avisa)

### Anthropic

1. Ve a [console.anthropic.com/settings/limits](https://console.anthropic.com/settings/limits)
2. Establece un **Monthly spending limit**: 50€

### NVIDIA NIM (Kimi K2.5 gratis)

- No necesitas configurar límites
- El tier gratuito tiene rate limits incorporados

### Recomendación de límites iniciales

| Perfil de uso | Límite mensual recomendado |
|---------------|---------------------------|
| Pruebas/Aprendizaje | 20€ |
| Desarrollo personal | 50€ |
| Producción pequeña | 100€ |

---

## Backup de la clave SSH

!!! tip "Haz backup de tu clave SSH"
    Si pierdes la clave privada, perderás acceso al VPS.

### Opción 1: Gestor de contraseñas

Guarda el contenido de `~/.ssh/id_ed25519` (clave privada) en tu gestor de contraseñas como nota segura.

### Opción 2: Backup cifrado

```bash
# Crear backup cifrado con GPG
gpg --symmetric --cipher-algo AES256 -o ~/id_ed25519.backup.gpg ~/.ssh/id_ed25519

# Guarda ~/id_ed25519.backup.gpg en lugar seguro (USB, nube cifrada, etc.)
```

Para restaurar:

```bash
gpg -d ~/id_ed25519.backup.gpg > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

---

## Troubleshooting

### Error: "Permissions are too open" al usar SSH

**Causa:** Los permisos de la clave privada son muy permisivos.

**Solución:**
```bash
chmod 600 ~/.ssh/id_ed25519
chmod 700 ~/.ssh
```

### Error: "Could not open a connection to your authentication agent"

**Causa:** SSH agent no está corriendo.

**Solución:**
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Error: "No such file or directory" al ver la clave

**Causa:** La clave no se generó o está en otra ubicación.

**Solución:**
```bash
# Ver todas las claves disponibles
ls -la ~/.ssh/

# Si no hay ninguna, genera una nueva
ssh-keygen -t ed25519 -C "openclaw-vps"
```

---

## Checklist de preparación

- [ ] Cuenta en proveedor VPS (Hetzner/Hostinger) con método de pago
- [ ] Cuenta en Tailscale creada
- [ ] MFA/2FA activado en tu identity provider (Google/GitHub/Microsoft)
- [ ] Clave SSH Ed25519 generada (`~/.ssh/id_ed25519.pub`)
- [ ] Passphrase guardada en gestor de contraseñas
- [ ] Backup de clave privada realizado
- [ ] (Si usas API de pago) Límite de gasto configurado

---

**Siguiente:** [2. Contratar VPS](02-vps.md) — Crear el servidor virtual.
