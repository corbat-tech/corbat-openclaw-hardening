# Referencia rápida

> Comandos del día a día para gestionar tu VPS con OpenClaw. Guarda esta página en favoritos.

---

## Gestión del servicio

```bash
# Ver estado del servicio
sudo systemctl status openclaw --no-pager

# Reiniciar OpenClaw
sudo systemctl restart openclaw

# Parar / Iniciar
sudo systemctl stop openclaw
sudo systemctl start openclaw

# Ver logs recientes (últimas 50 líneas, salida limpia)
sudo journalctl -u openclaw -n 50 --no-pager -o cat

# Seguir logs en tiempo real (Ctrl+C para parar)
sudo journalctl -u openclaw -f --no-pager -o cat

# Logs solo desde el último arranque
sudo journalctl -u openclaw -b --no-pager -o cat

# Filtrar solo errores
sudo journalctl -u openclaw -p err --no-pager -o cat
```

---

## CLI de OpenClaw

```bash
# Ver versión instalada
openclaw --version

# Estado completo (servicio + config + conectividad)
openclaw status --all

# Actualizar OpenClaw
openclaw update

# Ver canal de actualización
openclaw update --channel

# Cambiar a canal estable
openclaw update --channel stable

# Asistente de configuración inicial (solo primera vez)
openclaw onboard

# Diagnosticar problemas de configuración
openclaw doctor

# Validar configuración de sandbox
openclaw sandbox explain
```

!!! danger "Nunca ejecutes `openclaw doctor --fix` después de configurar manualmente"
    `--fix` sobreescribe tu configuración manual de proveedores (especialmente Kimi Coding) con plantillas por defecto rotas. Usa `openclaw doctor` sin `--fix` para diagnosticar, y luego corrige manualmente.

---

## Gestión de secretos

```bash
# Configurar un secreto interactivamente (valor no visible en pantalla)
openclaw secrets configure ANTHROPIC_API_KEY

# Listar secretos configurados
openclaw secrets list

# Auditar configuración de secretos
openclaw secrets audit

# Recargar secretos tras cambios
openclaw secrets reload

# Eliminar un secreto
openclaw secrets delete ANTHROPIC_API_KEY
```

!!! tip "Después de cambiar secretos en `/etc/openclaw/env`, siempre reinicia"
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl restart openclaw
    ```
    El `daemon-reload` es obligatorio — sin él, systemd sigue usando el entorno antiguo.

---

## Configuración de proveedores

### Cambiar de proveedor LLM

Edita el archivo de entorno y reinicia:

```bash
# Editar secretos/variables de entorno
sudo nano /etc/openclaw/env

# Aplicar cambios (AMBOS comandos son necesarios)
sudo systemctl daemon-reload
sudo systemctl restart openclaw

# Verificar que el nuevo proveedor responde
sudo journalctl -u openclaw -n 10 --no-pager -o cat
```

### Referencia de variables por proveedor

| Proveedor | Variables | ID del modelo |
|-----------|-----------|---------------|
| **OpenAI** | `OPENAI_API_KEY` | `gpt-5-mini`, `gpt-5` |
| **Anthropic** | `ANTHROPIC_API_KEY` | `claude-sonnet-4-5-20250514`, `claude-opus-4-6` |
| **Google** | `GEMINI_API_KEY` | `gemini-2.5-flash`, `gemini-2.5-pro` |
| **DeepSeek** | `DEEPSEEK_API_KEY` | `deepseek-chat`, `deepseek-reasoner` |
| **NVIDIA NIM** | `NVIDIA_API_KEY` | `moonshotai/kimi-k2.5` |
| **Kimi Coding** | `KIMI_API_KEY` | `kimi-for-coding` (suscripción) |

### Añadir OpenAI (ChatGPT) como proveedor

1. Obtén tu API key en [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Configura límites de gasto en [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits)
3. Configura en el VPS:

```bash
sudo nano /etc/openclaw/env
```

Añade:
```bash
OPENAI_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

4. Edita la config de OpenClaw para usar OpenAI:

```bash
nano ~/.openclaw/openclaw.json
```

Añade OpenAI como proveedor en la sección `providers`:
```json
{
  "providers": {
    "openai": {
      "model": "gpt-5-mini"
    }
  }
}
```

5. Aplica:
```bash
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

### Configuración multi-proveedor (primario + respaldo)

Un patrón común es usar un modelo de razonamiento como primario y uno rápido para búsqueda web y tareas simples:

```json
{
  "providers": {
    "kimi-coding": {
      "model": "kimi-for-coding",
      "baseUrl": "https://api.kimi.com/coding/v1",
      "headers": { "User-Agent": "claude-code/0.1.0" },
      "reasoning": false
    },
    "gemini": {
      "model": "gemini-2.5-flash",
      "maxTokens": 65536,
      "compat": { "supportsStore": false }
    }
  }
}
```

---

## Bot de Telegram

```bash
# Ver solicitudes de emparejamiento
openclaw pairing list

# Aprobar emparejamiento de Telegram
openclaw pairing approve telegram <CÓDIGO>

# Reiniciar bot tras cambios de config
sudo systemctl restart openclaw

# Verificar que el bot está conectado
sudo journalctl -u openclaw -n 20 --no-pager -o cat | grep -i telegram
```

---

## Skills y agentes

```bash
# Listar skills instaladas
openclaw skills list

# Instalar una skill
openclaw skills install <nombre-skill>

# Probar skill en sandbox primero
openclaw skills install <nombre-skill> --sandbox

# Enviar mensaje directo al agente
openclaw agent --message "resume los logs de hoy"
```

!!! info "Las skills se instalan en `~/.agents/skills/`"
    Las skills son globales, NO están dentro de `~/.openclaw/skills/`.

---

## Tailscale y SSH

```bash
# Ver estado de Tailscale
sudo tailscale status

# Reiniciar Tailscale
sudo systemctl restart tailscaled

# Reiniciar SSH (si falló al hacer bind tras reinicio)
sudo systemctl daemon-reload
sudo systemctl restart ssh

# Verificar que SSH escucha solo en IP de Tailscale
sudo ss -tlnp | grep sshd
```

---

## Salud del sistema

```bash
# Uso de disco
df -h /

# Uso de memoria
free -h

# Vista general de CPU y procesos
htop    # o: top -bn1 | head -20

# Recursos del proceso OpenClaw
ps aux | grep openclaw

# Conexiones de red activas (OpenClaw)
sudo ss -tp | grep node

# Verificar que todos los servicios hardened están corriendo
sudo systemctl is-active tailscaled ssh openclaw

# Estado del firewall
sudo ufw status
```

---

## Después de un reinicio del VPS

Si no puedes conectar por SSH tras un reinicio, conéctate por la **consola VNC de Hetzner** y ejecuta:

```bash
# 1. Verificar que Tailscale está corriendo
sudo tailscale status

# 2. Si Tailscale está caído, iniciarlo
sudo systemctl start tailscaled
sudo tailscale up

# 3. Reiniciar SSH (puede haber fallado al hacer bind antes de que Tailscale estuviera listo)
sudo systemctl daemon-reload
sudo systemctl restart ssh

# 4. Verificar que SSH está escuchando
sudo ss -tlnp | grep sshd

# 5. Verificar que OpenClaw está corriendo
sudo systemctl status openclaw --no-pager
```

!!! tip "Con el drop-in de systemd instalado, esto debería ser automático"
    Si seguiste la [sección 4](04-acceso-privado.md#paso-3-asegurar-que-ssh-arranque-despues-de-tailscale), SSH espera a Tailscale y se reinicia automáticamente si falla. Estos pasos manuales solo son necesarios si algo inesperado ocurre.

---

## Archivos de configuración

| Archivo | Propósito | Editar con |
|---------|-----------|------------|
| `/etc/openclaw/env` | Claves API y secretos (modo 600) | `sudo nano /etc/openclaw/env` |
| `~/.openclaw/openclaw.json` | Config principal (proveedores, herramientas, perfiles) | `nano ~/.openclaw/openclaw.json` |
| `~/openclaw/workspace/SOUL.md` | Personalidad y reglas de comportamiento del agente | `nano ~/openclaw/workspace/SOUL.md` |
| `~/.openclaw/exec-approvals.json` | Reglas de auto-aprobación de comandos | `nano ~/.openclaw/exec-approvals.json` |
| `~/.openclaw/agents/main/agent/auth-profiles.json` | Overrides de auth por proveedor (puede causar 401s) | `nano ~/.openclaw/agents/main/agent/auth-profiles.json` |
| `/etc/ssh/sshd_config.d/99-openclaw-hardening.conf` | Config de hardening SSH | `sudo nano /etc/ssh/sshd_config.d/99-openclaw-hardening.conf` |
| `/etc/systemd/system/ssh.service.d/after-tailscale.conf` | Drop-in de orden de arranque SSH | `sudo nano /etc/systemd/system/ssh.service.d/after-tailscale.conf` |

---

## Soluciones rápidas

| Problema | Solución |
|----------|----------|
| No puedo hacer SSH tras reinicio | Consola VNC → `sudo systemctl restart ssh` |
| OpenClaw no responde | `sudo systemctl restart openclaw` |
| Errores 401 tras cambiar clave | `echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json` y reiniciar |
| Cambios de config no se aplican | `sudo systemctl daemon-reload && sudo systemctl restart openclaw` |
| Puerto 18789 en uso | `sudo kill $(sudo lsof -t -i:18789) && sudo systemctl restart openclaw` |
| Disco lleno | `sudo journalctl --vacuum-size=500M && sudo apt autoremove -y` |
| Tailscale caído | `sudo systemctl restart tailscaled && sudo tailscale up` |
| `openclaw doctor --fix` rompió la config | Restaurar backup: `cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json` |
