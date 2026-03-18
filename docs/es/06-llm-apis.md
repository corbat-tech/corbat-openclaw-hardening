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

| Proveedor | Modelo | ID del modelo | Precio | Contexto | Mejor para |
|-----------|--------|---------------|--------|----------|------------|
| **xAI** | Grok 4.1 Fast | `grok-4-1-fast-reasoning` | $0.20 / $0.50 per MTok | 2M | Mejor relación precio/rendimiento, tool calling agéntico |
| **Kimi Coding** | Kimi for Coding | `kimi-for-coding` | **Free** (con suscripción Kimi Code) | 262K | Uso diario, coding, tooling |
| **Kimi/Moonshot** | Kimi K2.5 | `kimi-k2.5` | ~$0.50 / $1.50 per MTok | 262K | Multilingüe, coding, buen razonamiento |
| **Google** | Gemini 2.5 Flash | `gemini-2.5-flash` | $0.30 / $2.50 per MTok | 1M | Búsqueda web, gran contexto |
| **DeepSeek** | DeepSeek V3.2 | `deepseek-chat` | $0.28 / $0.42 per MTok | 128K | Campeón de presupuesto, razonamiento + herramientas |
| **Anthropic** | Claude Sonnet 4.6 | `claude-sonnet-4-6` | $3.00 / $15.00 per MTok | 1M | Misión crítica, máxima fiabilidad |
| **Anthropic** | Claude Opus 4.6 | `claude-opus-4-6` | $5.00 / $25.00 per MTok | 1M | Máxima calidad |
| **OpenAI** | GPT-5 mini | `gpt-5-mini` | $1.75 / $14.00 per MTok | 128K | Uso general, estable |

---

## Configuraciones recomendadas (marzo 2026)

!!! tip "Consenso de la comunidad: Grok 4.1 Fast es el mejor valor general"
    2M tokens de contexto, mejor tool calling agéntico, y $0.20/$0.50 per MTok. La variante **reasoning** puntúa 64 vs 38 (non-reasoning) en benchmarks al mismo precio por token — solo consume más tokens para chain-of-thought.

### Coste casi nulo (con suscripción Kimi Code)

| Rol | Modelo | Coste |
|-----|--------|-------|
| Principal | Kimi for Coding (gratis con suscripción) | $0 |
| Fallback | Grok 4.1 Fast Reasoning | $0.20/$0.50 per MTok |
| Búsqueda web | Brave (gratis ~1,000 consultas/mes) | $0 |

**Estimado: <$1/mes.** La suscripción Kimi Code cubre el principal. Grok solo se activa cuando Kimi falla, así que el consumo es mínimo.

### Mejor relación precio/rendimiento

| Rol | Modelo | Coste |
|-----|--------|-------|
| Principal | Grok 4.1 Fast Reasoning | $0.20/$0.50 per MTok |
| Fallback | DeepSeek V3.2 | $0.28/$0.42 per MTok |
| Búsqueda web | Brave | Free |

**Estimado: ~$10-30/mes.** Grok como principal ofrece 2M de contexto y el mejor rendimiento agéntico. DeepSeek como fallback económico y capaz.

### Presupuesto mínimo (sin suscripciones)

| Rol | Modelo | Coste |
|-----|--------|-------|
| Principal | Kimi K2.5 | ~$0.50/$1.50 per MTok |
| Fallback | MiniMax M2.5 o MiMo-V2-Flash | Muy bajo |
| Búsqueda web | Brave (gratis) o SearXNG (self-hosted) | Free |

**Estimado: ~$15/mes.**

### Máxima fiabilidad

| Rol | Modelo | Coste |
|-----|--------|-------|
| Principal | Claude Sonnet 4.6 | $3/$15 per MTok |
| Fallback | Grok 4.1 Fast Reasoning | $0.20/$0.50 per MTok |
| Búsqueda web | Brave o Gemini | Bajo |

**Estimado: ~$50-200/mes dependiendo del uso.**

!!! info "Consejo para ahorrar"
    Usa DeepSeek V3.2 o Gemini Flash para subagentes y heartbeats en lugar del modelo principal — ahorro estimado de $40-60/mes.

---

## Proveedores de búsqueda web

OpenClaw soporta múltiples proveedores de búsqueda web. **Solo un proveedor** puede estar activo — no hay cadena de fallback para búsqueda web (feature request [#2317](https://github.com/openclaw/openclaw/issues/2317)).

Orden de auto-detección (si no hay proveedor explícito configurado): Brave → Gemini → Perplexity → Grok.

| Proveedor | Coste | Tier gratuito | Calidad | Notas |
|-----------|-------|---------------|---------|-------|
| **Brave** (recomendado) | $5/1K queries | $5 créditos/mes (~1,000 queries) | Índice propio, resultados limpios | Requiere tarjeta (sin cobro dentro de créditos) |
| **Gemini** | $14-35/1K (grounding) | 1,500 requests/día gratis | Google Search grounding | Tier gratuito más generoso |
| **Grok** | $5/1K tool calls | No | Sintetizado por IA + citas | Reutiliza tu `XAI_API_KEY` |
| **Kimi** | $0.005/call + tokens | No | Moonshot nativo | Requiere `MOONSHOT_API_KEY` (la key de Kimi Code NO funciona) |
| **Perplexity** | Pago | No | Respuestas sintetizadas por IA | Buena calidad, más caro |
| **SearXNG** | Gratis (self-hosted) | Ilimitado | Variable | Requiere Docker, máxima privacidad |

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
# En el VPS, edita el archivo env (propiedad de root, cargado por systemd)
sudo nano /etc/openclaw/env
```

```bash
# Kimi K2.5 vía NVIDIA NIM (gratis)
LLM_PROVIDER=nvidia
NVIDIA_API_KEY=nvapi-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
DEFAULT_MODEL=moonshotai/kimi-k2.5
```

### xAI (Grok 4.1 Fast)

1. Ve a [console.x.ai](https://console.x.ai/home) y crea una cuenta
2. En el sidebar izquierdo, ve a **Billing** y añade un método de pago
3. Ve a **API Keys** → **Create API Key**
4. Copia la key que empieza con `xai-...`

```bash
# En /etc/openclaw/env
XAI_API_KEY=xai-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
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
    Sin límites, un bug, loop infinito o uso excesivo puede generar facturas de cientos o miles de dólares.

### OpenAI

1. Ve a [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits)
2. Configura:
   - **Hard limit:** $50 (se detiene al llegar)
   - **Soft limit:** $30 (te avisa por email)

### Anthropic

1. Ve a [console.anthropic.com/settings/limits](https://console.anthropic.com/settings/limits)
2. Establece **Monthly spending limit:** $50

### xAI (Grok)

1. Ve a [console.x.ai](https://console.x.ai/home) → **Billing**
2. Configura un tope de gasto mensual (xAI soporta hard limits)

### NVIDIA NIM (Kimi K2.5)

- El tier gratuito ya tiene rate limits incorporados
- No necesitas configurar límites adicionales

### Límites recomendados

| Perfil | Hard limit mensual | Soft limit |
|--------|-------------------|------------|
| Pruebas | $20 | $10 |
| Desarrollo | $50 | $30 |
| Producción personal | $100 | $70 |

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
# Verificar que el archivo env tiene permisos restrictivos
ls -la /etc/openclaw/env
# Debe mostrar: -rw------- (600), propietario root:openclaw

# Si no, corregir:
sudo chmod 600 /etc/openclaw/env
sudo chown root:openclaw /etc/openclaw/env
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
2. **Actualizar archivo env** en el VPS:
   ```bash
   sudo nano /etc/openclaw/env
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
# Verify API usage

echo "=== API Usage Verification ==="
echo "Date: $(date)"
echo ""

# Reminder to check dashboards
echo "Review usage at:"
echo "- OpenAI: https://platform.openai.com/usage"
echo "- Anthropic: https://console.anthropic.com/settings/usage"
echo "- NVIDIA: https://build.nvidia.com (dashboard)"
echo ""

# Verify last key rotation
if [ -f ~/openclaw/.last_key_rotation ]; then
    LAST_ROTATION=$(cat ~/openclaw/.last_key_rotation)
    echo "Last API key rotation: $LAST_ROTATION"

    # Calculate days since last rotation
    LAST_TS=$(date -d "$LAST_ROTATION" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DAYS=$(( (NOW_TS - LAST_TS) / 86400 ))

    if [ "$DAYS" -gt 90 ]; then
        echo "⚠️  ALERT: $DAYS days have passed. Consider rotating API keys."
    else
        echo "✅ Keys rotated $DAYS days ago (< 90 days)"
    fi
else
    echo "⚠️  No record of last rotation"
    echo "   Run: echo \$(date +%Y-%m-%d) > ~/openclaw/.last_key_rotation"
fi
```

```bash
chmod +x ~/openclaw/scripts/check_api_usage.sh
```

---

## Configuración multi-modelo con fallbacks

OpenClaw soporta un modelo principal con fallbacks automáticos. Esta es la configuración
recomendada para `~/.openclaw/openclaw.json` usando nuestra configuración de referencia (Kimi Coding +
Grok 4.1 Fast Reasoning + Brave para búsqueda web):

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "kimi-coding": {
        "baseUrl": "https://api.kimi.com/coding",
        "apiKey": "${KIMI_API_KEY}",
        "api": "anthropic-messages",
        "headers": {
          "User-Agent": "claude-code/0.1.0"
        },
        "models": [
          {
            "id": "kimi-for-coding",
            "name": "Kimi Coding",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 262144,
            "maxTokens": 32768
          }
        ]
      },
      "xai": {
        "baseUrl": "https://api.x.ai/v1",
        "apiKey": "${XAI_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "grok-4-1-fast-reasoning",
            "name": "Grok 4.1 Fast",
            "reasoning": false,
            "input": ["text", "image"],
            "contextWindow": 2097152,
            "maxTokens": 131072
          }
        ]
      },
      "google": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai",
        "apiKey": "${GOOGLE_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "gemini-2.5-flash",
            "name": "Gemini 2.5 Flash",
            "reasoning": false,
            "input": ["text", "image"],
            "contextWindow": 1048576,
            "maxTokens": 65536,
            "compat": {
              "supportsStore": false
            }
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "kimi-coding/kimi-for-coding",
        "fallbacks": [
          "xai/grok-4-1-fast-reasoning"
        ]
      }
    }
  },
  "tools": {
    "profile": "full",
    "web": {
      "search": {
        "enabled": true,
        "provider": "brave",
        "apiKey": "${BRAVE_SEARCH_API_KEY}"
      },
      "fetch": {
        "enabled": true
      }
    }
  }
}
```

!!! info "Detalles importantes de esta configuración"
    - **Kimi Coding** usa API `anthropic-messages` (no `openai-completions`)
    - **Kimi Coding** `baseUrl` no lleva `/v1` al final — es `https://api.kimi.com/coding`
    - **Kimi Coding** requiere la cabecera `User-Agent` o las peticiones fallarán
    - **Grok** el ID del modelo es `grok-4-1-fast-reasoning` (la variante **reasoning** — puntúa 64 vs 38 al mismo precio/token)
    - **Grok** `reasoning: false` en la definición del modelo es correcto — controla el manejo de prompts de OpenClaw, no el razonamiento interno del modelo
    - **Gemini** requiere `compat.supportsStore: false` (ver Issue #22704)
    - **Búsqueda web** usa Brave con una API key dedicada (`BRAVE_SEARCH_API_KEY`)
    - Las variables de entorno (`${VAR}`) se resuelven desde `/etc/openclaw/env`
    - **Hot reload**: OpenClaw detecta cambios en `openclaw.json` automáticamente — no siempre es necesario reiniciar

### Variables de entorno necesarias

Añade estas a `/etc/openclaw/env`:

```bash
# Principal: Kimi Coding (suscripción)
KIMI_API_KEY=kimi-XXXXXXXXXXXXXXXXXXXXXXXX

# Fallback: xAI Grok
XAI_API_KEY=xai-XXXXXXXXXXXXXXXXXXXXXXXX

# LLM opcional: Google Gemini (si se usa como fallback)
GOOGLE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Búsqueda web: Brave
BRAVE_SEARCH_API_KEY=BSAxxxxxxxxxxxxxxxxxxxxxxxxx
```

Luego aplica:

```bash
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

---

## Notas técnicas

!!! warning "Detalles importantes de configuración"
    Estos son hallazgos probados en campo en despliegues reales, no recomendaciones teóricas.

- **Hot reload**: OpenClaw detecta cambios en `openclaw.json` automáticamente — no siempre es necesario reiniciar el servicio, pero se recomienda para cambios en variables de entorno
- **Configuración de búsqueda web Brave**: La `apiKey` va en `tools.web.search.apiKey`, NO dentro de `tools.web.search.brave.apiKey` (error de validación de schema si se anida incorrectamente)
- **Keys de autenticación Kimi**: La key de suscripción Kimi Code (`sk-kimi-*`) y la API key de la plataforma Moonshot (`sk-*`) son credenciales diferentes. La búsqueda web vía Kimi en OpenClaw requiere la key de Moonshot, no la de Kimi Code
- **Grok reasoning vs non-reasoning**: Variantes del mismo modelo (`grok-4-1-fast-reasoning` / `grok-4-1-fast-non-reasoning`). Mismo precio por token, pero reasoning consume más tokens para chain-of-thought. La diferencia de calidad es significativa (64 vs 38 en benchmarks)
- **Sincronización de config**: `models.json` (nivel de agente) y `openclaw.json` (global) definen proveedores de forma redundante — mantenlos sincronizados para evitar inconsistencias
- **Búsqueda web no tiene fallback**: OpenClaw solo permite un proveedor para `web_search` — no hay cadena de fallback. La feature request [#2317](https://github.com/openclaw/openclaw/issues/2317) está abierta

---

## Troubleshooting

### Error: "API key invalid" o "Unauthorized"

**Causa:** Key incorrecta o expirada.

**Solución:**
```bash
# Verificar que la key está bien copiada (sin espacios)
sudo grep API_KEY /etc/openclaw/env

# Verificar que no hay caracteres ocultos
sudo cat -A /etc/openclaw/env | grep API_KEY
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
# Kimi Coding: kimi-for-coding
# xAI Grok: grok-4-1-fast-reasoning (reasoning variant)
# Google: gemini-2.5-flash
# OpenAI: gpt-5-mini, gpt-5
# Anthropic: claude-sonnet-4-6, claude-opus-4-6
# DeepSeek: deepseek-chat
```

---

## Resumen

| Configuración | Estado |
|---------------|--------|
| API key configurada | ✅ |
| Permisos .env = 600 | ✅ |
| Límite de gasto configurado | ✅ |
| Alertas de uso activadas | ✅ |
| Fecha de rotación registrada | ✅ |

---

**Siguiente:** [7. Casos de uso](07-casos-uso.md) — Ejemplos prácticos de configuración.
