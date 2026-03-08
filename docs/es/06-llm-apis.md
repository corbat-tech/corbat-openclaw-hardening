# 6. APIs de LLM

> **TL;DR**: Configurar API keys de proveedores LLM, establecer límites de gasto obligatorios y configurar alertas de uso.

> **Tiempo estimado**: 10-15 minutos

> **Nivel requerido**: Principiante

!!! warning "URLs de proveedores"
    Las URLs de consolas y dashboards de proveedores LLM pueden cambiar con el tiempo.
    Si algún enlace no funciona, busca la sección equivalente en el sitio del proveedor.

    **Última verificación de URLs:** 2026-02

## Prerrequisitos

- [ ] Sección 5 (OpenClaw) completada
- [ ] Cuenta en al menos un proveedor LLM

## Objetivos

Al terminar esta sección tendrás:

- API key configurada en el VPS
- Límites de gasto establecidos
- Alertas de uso configuradas
- Conocimiento de cuándo rotar las keys

---

## Comparativa de proveedores (marzo 2026)

| Proveedor | Modelo recomendado | Calidad | Precio | Mejor para |
|-----------|-------------------|---------|--------|------------|
| **Kimi/Moonshot** | Kimi K2.5 | ⭐⭐⭐⭐⭐ | **GRATIS** | Empezar sin coste |
| **Anthropic** | Claude Sonnet 4.6 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Razonamiento complejo, coding |
| **Anthropic** | Claude Opus 4.6 | ⭐⭐⭐⭐⭐⭐ | ⭐⭐ | Máxima calidad |
| **OpenAI** | GPT-5 mini | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | Uso general, estable |
| **DeepSeek** | DeepSeek V3 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Alto volumen, bajo coste |
| **Google** | Gemini Flash | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | Alto volumen |

!!! success "Kimi K2.5 gratis"
    Kimi K2.5 (lanzado enero 2026) está disponible **gratis** a través de NVIDIA NIM.
    Excelente opción para empezar sin coste y probar OpenClaw.

---

## Recomendación por caso de uso

### Uso personal / pruebas

- **Modelo:** Kimi K2.5 (gratis)
- **Presupuesto:** 0€/mes
- **Por qué:** Gratis en NVIDIA NIM, calidad suficiente para probar

### Desarrollo / uso diario

- **Modelo:** Claude Sonnet 4.6 o GPT-5 mini
- **Presupuesto:** 30-50€/mes
- **Por qué:** Buen equilibrio calidad/coste

### Producción / uso intensivo

- **Modelo:** Claude Sonnet 4.6 (principal) + DeepSeek V3 (tareas simples)
- **Presupuesto:** 80-150€/mes
- **Por qué:** Calidad para tareas complejas, bajo coste para volumen

---

## Configurar API Keys

### Kimi K2.5 (GRATIS vía NVIDIA NIM)

!!! success "Opción gratuita recomendada"
    Ideal para empezar sin gastar dinero.

1. Ve a [build.nvidia.com](https://build.nvidia.com/moonshotai/kimi-k2.5)
2. Crea cuenta NVIDIA (gratis)
3. Haz clic en "Get API Key"
4. Copia la key que empieza con `nvapi-...`

```bash
# En el VPS, edita .env
nano ~/.openclaw/.env
```

```bash
# Kimi K2.5 vía NVIDIA NIM (gratis)
LLM_PROVIDER=nvidia
NVIDIA_API_KEY=nvapi-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
DEFAULT_MODEL=moonshotai/kimi-k2.5
```

### OpenAI

1. Ve a [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Haz clic en "Create new secret key"
3. Dale un nombre descriptivo: "openclaw-vps"
4. Copia la key (solo se muestra una vez)

```bash
# En .env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
DEFAULT_MODEL=gpt-5-mini
```

### Anthropic

1. Ve a [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
2. Haz clic en "Create Key"
3. Dale un nombre: "openclaw-vps"
4. Copia la key

```bash
# En .env
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
DEFAULT_MODEL=claude-sonnet-4-5-20250514
```

### DeepSeek

1. Ve a [platform.deepseek.com](https://platform.deepseek.com)
2. Crea cuenta y genera API key

```bash
# En .env
LLM_PROVIDER=deepseek
DEEPSEEK_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
DEFAULT_MODEL=deepseek-chat
```

---

## Límites de gasto (OBLIGATORIO)

!!! danger "Configura esto ANTES de usar la API"
    Sin límites, un bug, loop infinito o uso excesivo puede generar facturas de cientos o miles de euros.

### OpenAI

1. Ve a [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits)
2. Configura:
   - **Hard limit:** 50€ (se detiene al llegar)
   - **Soft limit:** 30€ (te avisa por email)

### Anthropic

1. Ve a [console.anthropic.com/settings/limits](https://console.anthropic.com/settings/limits)
2. Establece **Monthly spending limit:** 50€

### NVIDIA NIM (Kimi K2.5)

- El tier gratuito ya tiene rate limits incorporados
- No necesitas configurar límites adicionales

### Recomendación de límites

| Perfil | Hard limit mensual | Soft limit |
|--------|-------------------|------------|
| Pruebas | 20€ | 10€ |
| Desarrollo | 50€ | 30€ |
| Producción personal | 100€ | 70€ |

---

## Configurar alertas de uso

### OpenAI

1. Ve a [platform.openai.com/settings/organization/notifications](https://platform.openai.com/settings/organization/notifications)
2. Activa alertas por email para:
   - 50% del límite alcanzado
   - 80% del límite alcanzado
   - Límite alcanzado

### Anthropic

1. Ve a [console.anthropic.com/settings/notifications](https://console.anthropic.com/settings/notifications)
2. Configura alertas similares

### Monitoreo manual

Revisa el uso periódicamente:

- **OpenAI:** [platform.openai.com/usage](https://platform.openai.com/usage)
- **Anthropic:** [console.anthropic.com/settings/usage](https://console.anthropic.com/settings/usage)
- **NVIDIA NIM:** Dashboard en build.nvidia.com

---

## Seguridad de API Keys

!!! danger "No almacenes API keys en archivos `.env` de texto plano si puedes evitarlo"
    Los archivos `.env` son vulnerables a prompt injection, se filtran en shell history y logs, y cualquier proceso del usuario puede leerlos.

### Opción 1: SecretRef de OpenClaw (RECOMENDADO)

A partir de v2026.3.x, OpenClaw incluye **SecretRef** para gestión segura de credenciales:

```bash
# Almacenar API key de forma segura (cifrada en disco)
openclaw secrets configure ANTHROPIC_API_KEY
# Introduce el valor de forma interactiva (no se muestra en pantalla)

# Listar secrets almacenados
openclaw secrets list

# Eliminar un secret
openclaw secrets delete ANTHROPIC_API_KEY
```

En `openclaw.json`, referencia los secrets:
```json
{
  "agent": {
    "apiKey": { "$secretRef": "ANTHROPIC_API_KEY" }
  }
}
```

### Opción 2: lkr (LLM Key Ring)

[lkr](https://github.com/yotta/lkr) es una herramienta de cifrado client-side para API keys:

```bash
# Instalar lkr
npm install -g lkr

# Almacenar key (cifrada con XChaCha20-Poly1305)
lkr set ANTHROPIC_API_KEY

# Usar en scripts
export ANTHROPIC_API_KEY=$(lkr get ANTHROPIC_API_KEY)
```

### Opción 3: Archivo .env (legacy)

Si debes usar `.env`, aplica permisos restrictivos:

```bash
# Verificar que .env tiene permisos restrictivos
ls -la ~/.openclaw/.env
# Debe mostrar: -rw------- (600)

# Si no, corregir:
chmod 600 ~/.openclaw/.env
```

### No exponer keys en logs

Verifica que tu configuración de logging no imprime las API keys:

```yaml
# En config/settings.yaml (crear si no existe)
logging:
  level: "info"
  redact_secrets: true  # Importante
```

### Rotación de API keys

!!! warning "Rota tus API keys cada 90 días"
    Las API keys son credenciales que deben rotarse periódicamente.

**Procedimiento de rotación:**

1. **Generar nueva key** en el panel del proveedor
2. **Actualizar .env** en el VPS:
   ```bash
   nano ~/.openclaw/.env
   # Reemplazar la key antigua por la nueva
   ```
3. **Reiniciar servicio:**
   ```bash
   sudo systemctl restart openclaw
   ```
4. **Verificar funcionamiento** en los logs:
   ```bash
   sudo journalctl -u openclaw -n 20
   ```
5. **Revocar key antigua** en el panel del proveedor (solo después de verificar)

**Registrar fecha de rotación:**

```bash
# Guardar fecha de última rotación
echo $(date +%Y-%m-%d) > ~/openclaw/.last_key_rotation

# Verificar cuándo fue la última rotación
cat ~/openclaw/.last_key_rotation
```

---

## Monitoreo de uso anómalo

### Indicadores de posible compromiso

| Señal | Posible causa | Acción |
|-------|--------------|--------|
| Uso fuera de horario | Key comprometida o bug | Revisar logs, considerar rotar key |
| Picos de tokens inusuales | Loop infinito o abuso | Detener servicio, investigar |
| Requests desde IPs desconocidas | Key filtrada | Rotar key inmediatamente |
| Uso después de detener servicio | Key usada externamente | Rotar key inmediatamente |

### Script de verificación de uso

```bash
nano ~/openclaw/scripts/check_api_usage.sh
```

```bash
#!/bin/bash
# Verificar uso de APIs

echo "=== Verificación de uso de APIs ==="
echo "Fecha: $(date)"
echo ""

# Recordatorio de revisar dashboards
echo "Revisar uso en:"
echo "- OpenAI: https://platform.openai.com/usage"
echo "- Anthropic: https://console.anthropic.com/settings/usage"
echo "- NVIDIA: https://build.nvidia.com (dashboard)"
echo ""

# Verificar última rotación de keys
if [ -f ~/openclaw/.last_key_rotation ]; then
    LAST_ROTATION=$(cat ~/openclaw/.last_key_rotation)
    echo "Última rotación de API keys: $LAST_ROTATION"

    # Calcular días desde última rotación
    LAST_TS=$(date -d "$LAST_ROTATION" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DAYS=$(( (NOW_TS - LAST_TS) / 86400 ))

    if [ "$DAYS" -gt 90 ]; then
        echo "⚠️  ALERTA: Han pasado $DAYS días. Considera rotar las API keys."
    else
        echo "✅ Keys rotadas hace $DAYS días (< 90 días)"
    fi
else
    echo "⚠️  No hay registro de última rotación"
    echo "   Ejecuta: echo \$(date +%Y-%m-%d) > ~/openclaw/.last_key_rotation"
fi
```

```bash
chmod +x ~/openclaw/scripts/check_api_usage.sh
```

---

## Configuración multi-modelo (avanzado)

Si OpenClaw lo soporta, puedes usar diferentes modelos para diferentes tareas:

```yaml
# config/models.yaml (ejemplo)
routing:
  # Tareas complejas: modelo potente
  complex_reasoning:
    provider: anthropic
    model: claude-sonnet-4-5-20250514

  # Tareas simples: modelo económico
  simple_tasks:
    provider: deepseek
    model: deepseek-chat

  # Por defecto: modelo gratuito
  default:
    provider: nvidia
    model: moonshotai/kimi-k2.5
```

---

## Troubleshooting

### Error: "API key invalid" o "Unauthorized"

**Causa:** Key incorrecta o expirada.

**Solución:**
```bash
# Verificar que la key está bien copiada (sin espacios)
grep API_KEY ~/.openclaw/.env

# Verificar que no hay caracteres ocultos
cat -A ~/.openclaw/.env | grep API_KEY
```

### Error: "Rate limit exceeded"

**Causa:** Demasiadas peticiones en poco tiempo.

**Solución:**
- Implementar backoff exponencial
- Reducir frecuencia de requests
- Considerar modelo con mayores límites

### Error: "Insufficient quota"

**Causa:** Se acabó el crédito o llegaste al límite.

**Solución:**
- Añadir más crédito en el panel del proveedor
- Esperar al siguiente ciclo de facturación
- Usar modelo gratuito mientras tanto

### Error: "Model not found"

**Causa:** Nombre del modelo incorrecto.

**Solución:**
```bash
# Verificar nombres exactos de modelos en documentación oficial
# OpenAI: gpt-5-mini, gpt-5
# Anthropic: claude-sonnet-4-5-20250514, claude-opus-4-5-20251101
# NVIDIA: moonshotai/kimi-k2.5
```

---

## Resumen

| Configuración | Estado |
|--------------|--------|
| API key configurada | ✅ |
| Permisos .env = 600 | ✅ |
| Límite de gasto configurado | ✅ |
| Alertas de uso activadas | ✅ |
| Fecha de rotación registrada | ✅ |

---

**Siguiente:** [7. Casos de uso](07-casos-uso.md) — Ejemplos prácticos de configuración.
