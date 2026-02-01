# 2. Contratar VPS

> **TL;DR**: Crear un VPS con Ubuntu 24.04 LTS, verificar la integridad de la imagen, configurar timezone y realizar actualización inicial.

> **Tiempo estimado**: 10-15 minutos

> **Nivel requerido**: Principiante

## Prerrequisitos

- [ ] Sección 1 (Preparación) completada
- [ ] Clave SSH generada (`~/.ssh/id_ed25519.pub`)
- [ ] Cuenta en proveedor VPS con método de pago

## Objetivos

Al terminar esta sección tendrás:

- VPS creado con Ubuntu 24.04 LTS
- Acceso SSH como root funcionando
- Sistema actualizado
- Timezone configurado

---

## Proveedores recomendados

| Proveedor | Plan recomendado | RAM | CPU | Disco | Precio | Notas |
|-----------|------------------|-----|-----|-------|--------|-------|
| **[Hetzner](https://www.hetzner.com/cloud)** | CX22 | 4 GB | 2 vCPU | 40 GB | ~4€/mes | ⭐ Mejor rendimiento/precio |
| **[Hostinger](https://www.hostinger.es/vps)** | KVM 2 | 8 GB | 2 vCPU | 100 GB | ~8€/mes | ⭐ Fácil para principiantes |
| [DigitalOcean](https://www.digitalocean.com) | Basic Droplet | 4 GB | 2 vCPU | 80 GB | ~12€/mes | Buena documentación |
| [Vultr](https://www.vultr.com) | Cloud Compute | 4 GB | 2 vCPU | 80 GB | ~12€/mes | Muchos datacenters |
| [Contabo](https://contabo.com/en/vps/) | VPS S | 8 GB | 4 vCPU | 100 GB | ~5€/mes | Económico, peor soporte |

!!! tip "Recomendación"
    **Hetzner** ofrece el mejor rendimiento por euro y tiene datacenters en Europa.
    **Hostinger** es más fácil para principiantes con su panel hPanel.

!!! warning "Evita"
    - Proveedores sin reputación establecida
    - Ofertas demasiado baratas (< 3€/mes)
    - VPS "ilimitados" o con recursos compartidos excesivos

    Un VPS comprometido = tu agente AI comprometido.

---

## Requisitos mínimos del VPS

| Recurso | Mínimo | Recomendado | Para uso intensivo |
|---------|--------|-------------|-------------------|
| RAM | 4 GB | 8 GB | 16 GB |
| CPU | 1 vCPU | 2 vCPU | 4 vCPU |
| Disco | 40 GB | 80 GB | 160 GB |
| SO | Ubuntu 22.04 LTS | **Ubuntu 24.04 LTS** | Ubuntu 24.04 LTS |
| Red | 1 Gbps | 1 Gbps | 10 Gbps |

---

## Crear el VPS

Los pasos son similares en todos los proveedores:

### 1. Sistema operativo

Selecciona: **Ubuntu 24.04 LTS** (o la LTS más reciente disponible)

!!! info "¿Por qué Ubuntu LTS?"
    - Soporte de seguridad por 5+ años
    - Amplia documentación
    - Compatible con la mayoría de software
    - Actualizaciones de seguridad automáticas

### 2. Ubicación del datacenter

Elige el datacenter más cercano a ti para menor latencia:

| Tu ubicación | Datacenter recomendado |
|--------------|------------------------|
| España | Alemania (Frankfurt) o Países Bajos |
| México/Centroamérica | USA (Dallas, Miami) |
| Sudamérica | USA (Miami) o Brasil |
| UK | Londres o Países Bajos |

### 3. Clave SSH

Durante la creación del VPS, añade tu clave SSH pública:

```bash
# En tu máquina local, copia la clave pública
cat ~/.ssh/id_ed25519.pub
```

**Salida esperada:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... openclaw-vps-2026
```

Copia el contenido **completo** (empieza con `ssh-ed25519...`) y pégalo en el campo "SSH Key" del proveedor.

### 4. Contraseña root (si la piden)

Algunos proveedores piden una contraseña root. Ponla fuerte pero **no la usarás** — accederás solo por SSH con clave.

```bash
# Generar contraseña aleatoria (guárdala por si acaso)
openssl rand -base64 20
```

---

## Primer acceso

Una vez creado el VPS (puede tardar 1-5 minutos), el proveedor te mostrará la **IP pública**.

### Conectar como root

```bash
# Conectar por SSH (la primera vez preguntará si confías en el host)
ssh root@<TU_IP_PUBLICA>

# Si usaste una clave SSH en ubicación no-default:
ssh -i ~/.ssh/id_ed25519 root@<TU_IP_PUBLICA>
```

**Primera conexión - verificar fingerprint:**
```
The authenticity of host 'xxx.xxx.xxx.xxx' can't be established.
ED25519 key fingerprint is SHA256:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

!!! tip "Verificar fingerprint"
    Algunos proveedores muestran el fingerprint en su panel. Compáralo antes de escribir "yes".

---

## Verificar integridad del sistema

Antes de configurar nada, verifica que el VPS tiene una imagen limpia.

### Verificar sistema operativo

```bash
# Verificar que es Ubuntu oficial
cat /etc/os-release
```

**Salida esperada:**
```
PRETTY_NAME="Ubuntu 24.04 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04 LTS (Noble Numbat)"
...
```

### Verificar usuarios existentes

```bash
# Ver usuarios con shell de login
cat /etc/passwd | grep -E ":/bin/(bash|sh|zsh)$"
```

**Salida esperada (solo root y usuarios del sistema):**
```
root:x:0:0:root:/root:/bin/bash
```

!!! danger "Si ves usuarios desconocidos"
    Si hay usuarios que no reconoces (no son root ni cuentas del sistema como nobody, daemon, etc.), contacta al proveedor o destruye el VPS y crea uno nuevo.

### Verificar procesos en ejecución

```bash
# Ver procesos ordenados por uso de memoria
ps aux --sort=-%mem | head -20
```

Deberías ver solo procesos del sistema (systemd, sshd, etc.). No debería haber servicios web, mineros de crypto, u otros procesos sospechosos.

### Verificar conexiones de red

```bash
# Ver puertos escuchando
ss -tlnp
```

**Salida esperada (solo SSH):**
```
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=XXX,fd=3))
LISTEN  0       128     [::]:22             [::]:*             users:(("sshd",pid=XXX,fd=4))
```

!!! warning "Si ves otros puertos abiertos"
    Algunos proveedores instalan agentes de monitoreo. Identifícalos antes de continuar.

---

## Configurar timezone y locale

### Configurar timezone

```bash
# Ver timezone actual
timedatectl

# Listar timezones disponibles
timedatectl list-timezones | grep -E "Europe|America"

# Configurar timezone (ejemplo: España peninsular)
sudo timedatectl set-timezone Europe/Madrid

# Verificar
date
```

**Salida esperada:**
```
Sat Feb  1 10:30:00 CET 2026
```

### Configurar locale (opcional)

```bash
# Generar locale español (opcional)
sudo locale-gen es_ES.UTF-8

# O mantener inglés (recomendado para logs legibles)
sudo locale-gen en_US.UTF-8

# Verificar
locale
```

---

## Actualizar sistema

```bash
# Actualizar lista de paquetes
apt update

# Aplicar actualizaciones
apt upgrade -y
```

!!! info "Paquetes retenidos"
    Si ves "The following packages have been kept back", puedes ignorarlo por ahora o ejecutar:
    ```bash
    apt dist-upgrade -y
    ```

### Reiniciar si es necesario

```bash
# Verificar si hay reinicio pendiente
[ -f /var/run/reboot-required ] && echo "Reinicio necesario" || echo "No requiere reinicio"

# Si es necesario, reiniciar
reboot
```

Espera 30-60 segundos y reconéctate:

```bash
ssh root@<TU_IP_PUBLICA>
```

---

## Datos a guardar

Guarda esta información en un lugar seguro (gestor de contraseñas):

| Dato | Valor | Notas |
|------|-------|-------|
| Proveedor | _______________ | Hetzner, Hostinger, etc. |
| IP pública | `___.___.___.___` | La dejarás de usar después |
| Usuario temporal | `root` | Solo para setup inicial |
| Datacenter | _______________ | Para referencia |

!!! info "Esta IP pública la dejarás de usar"
    Después de configurar Tailscale, solo accederás por la IP privada de Tailscale.

---

## Troubleshooting

### Error: "Connection refused"

**Causa:** El VPS aún no ha terminado de iniciar o SSH no está corriendo.

**Solución:**
- Espera 2-3 minutos
- Verifica en el panel del proveedor que el VPS está "Running"
- Algunos proveedores tienen consola web para acceder sin SSH

### Error: "Permission denied (publickey)"

**Causa:** La clave SSH no está correctamente configurada.

**Solución:**
```bash
# Verificar que usas la clave correcta
ssh -v -i ~/.ssh/id_ed25519 root@<TU_IP_PUBLICA>

# El flag -v muestra debug info
```

### Error: "Host key verification failed"

**Causa:** El fingerprint del servidor cambió (posible reinstalación o ataque MITM).

**Solución:**
```bash
# Si reinstalaste el VPS, eliminar la entrada antigua
ssh-keygen -R <TU_IP_PUBLICA>

# Volver a conectar
ssh root@<TU_IP_PUBLICA>
```

!!! danger "Si NO reinstalaste el VPS"
    Un cambio de host key inesperado puede indicar un ataque man-in-the-middle.
    Contacta al proveedor antes de continuar.

### El sistema está muy lento

**Causa:** Puede ser un VPS oversold o problemas del datacenter.

**Solución:**
```bash
# Verificar recursos
free -h        # Memoria
df -h          # Disco
top            # CPU y procesos

# Si los recursos están bien pero sigue lento, contacta al proveedor
```

---

## Resumen

| Configuración | Estado |
|--------------|--------|
| VPS creado | ✅ |
| Ubuntu 24.04 LTS | ✅ |
| SSH funcionando | ✅ |
| Imagen verificada | ✅ |
| Timezone configurado | ✅ |
| Sistema actualizado | ✅ |

---

**Siguiente:** [3. Seguridad del sistema](03-seguridad-sistema.md) — Crear usuario, hardening SSH, firewall.
