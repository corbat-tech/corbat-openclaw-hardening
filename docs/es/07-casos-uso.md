# 7. Casos de uso

> **TL;DR**: Ejemplos prácticos de configuración de skills para diferentes perfiles de uso, incluyendo output filtering para prevenir filtración de datos (OWASP AA2).

> **Tiempo estimado**: 15-20 minutos (según configuración elegida)

> **Nivel requerido**: Intermedio

## Prerrequisitos

- [ ] Sección 6 (APIs de LLM) completada
- [ ] OpenClaw funcionando

## Objetivos

Al terminar esta sección tendrás:

- Configuración de skills adaptada a tu caso de uso
- Output filtering para prevenir filtración de datos
- Conocimiento de configuraciones prohibidas

---

## Perfiles de configuración

### Desarrolladores

| Caso de uso | Skills necesarias | Allowlist HTTP |
|-------------|-------------------|----------------|
| Revisión de código | `filesystem`, `git` | `api.github.com` |
| Generar documentación | `filesystem` | — |
| Ejecutar tests | `shell` (MUY limitado) | — |
| Análisis de repos | `filesystem`, `git`, `http_client` | `api.github.com`, `api.gitlab.com` |

### Autónomos / Pymes

| Caso de uso | Skills necesarias | Notas |
|-------------|-------------------|-------|
| Resumir PDFs/documentos | `filesystem` | Solo carpeta documentos |
| Organizar archivos | `filesystem` | Con `move`, `copy` |
| Borradores de email | `filesystem` | Sin envío directo |
| Análisis de datos | `filesystem` | Solo lectura |

### Investigadores

| Caso de uso | Skills necesarias | Allowlist HTTP |
|-------------|-------------------|----------------|
| Buscar papers | `http_client` | `api.semanticscholar.org`, `arxiv.org` |
| Resumir literatura | `filesystem` | — |
| Organizar bibliografía | `filesystem` | — |

---

## Ejemplo: Revisor de código (Desarrollador)

### skills.json

```json
{
  "_comment": "Configuración para revisor de código",

  "filesystem": {
    "enabled": true,
    "allowed_paths": [
      "/home/openclaw/openclaw/workspace"
    ],
    "denied_paths": [
      "/home/openclaw/.ssh",
      "/home/openclaw/.env",
      "/etc",
      "/var"
    ],
    "allowed_operations": [
      "read",
      "list"
    ],
    "denied_operations": [
      "write",
      "delete",
      "delete_recursive",
      "change_permissions"
    ]
  },

  "git": {
    "enabled": true,
    "allowed_operations": [
      "clone",
      "status",
      "diff",
      "log",
      "branch",
      "show"
    ],
    "denied_operations": [
      "push",
      "force-push",
      "commit",
      "reset",
      "clean"
    ]
  },

  "http_client": {
    "enabled": true,
    "allowlist": [
      "api.github.com"
    ],
    "timeout_seconds": 30
  },

  "shell": {
    "enabled": false
  }
}
```

### soul.yaml

```yaml
name: "CodeReviewer"
role: "Revisor de código"
version: "1.0"

limits:
  - "Solo leer código, nunca modificar"
  - "No hacer commits ni push"
  - "No acceder a archivos fuera de workspace"
  - "Reportar vulnerabilidades de seguridad encontradas"

tone: "técnico, constructivo"
```

---

## Ejemplo: Asistente de documentos (Autónomo)

### skills.json

```json
{
  "_comment": "Configuración para gestión de documentos",

  "filesystem": {
    "enabled": true,
    "allowed_paths": [
      "/home/openclaw/openclaw/workspace/documents",
      "/home/openclaw/openclaw/workspace/output"
    ],
    "allowed_operations": [
      "read",
      "write",
      "list",
      "create_directory",
      "move",
      "copy"
    ],
    "denied_operations": [
      "delete_recursive",
      "change_permissions"
    ],
    "max_file_size_mb": 50
  },

  "git": {
    "enabled": false
  },

  "http_client": {
    "enabled": false
  },

  "shell": {
    "enabled": false
  }
}
```

---

## Ejemplo: Dev con notificaciones Telegram

### .env

```bash
# API de LLM
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Telegram
TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
TELEGRAM_CHAT_ID=987654321

# Red
HOST=127.0.0.1
PORT=3000
```

### Obtener token de Telegram

1. Habla con [@BotFather](https://t.me/BotFather) en Telegram
2. Envía `/newbot`
3. Sigue las instrucciones para crear el bot
4. Copia el token que te da

### Obtener tu chat_id

1. Envía cualquier mensaje a tu nuevo bot
2. Visita en tu navegador:
   ```
   https://api.telegram.org/bot<TU_TOKEN>/getUpdates
   ```
3. Busca `"chat":{"id":123456789}` - ese número es tu `chat_id`

### skills.json

```json
{
  "filesystem": {
    "enabled": true,
    "allowed_paths": ["/home/openclaw/openclaw/workspace"],
    "denied_operations": ["delete_recursive"]
  },

  "git": {
    "enabled": true,
    "allowed_operations": ["clone", "status", "diff", "log"]
  },

  "http_client": {
    "enabled": true,
    "allowlist": [
      "api.anthropic.com",
      "api.github.com",
      "api.telegram.org"
    ]
  },

  "telegram": {
    "enabled": true,
    "allowed_operations": ["send_message"],
    "denied_operations": ["send_photo", "send_file", "forward_message"]
  },

  "shell": {
    "enabled": false
  }
}
```

---

## Prevenir filtración de datos (OWASP AA2)

El output filtering previene que el agente exponga datos sensibles en sus respuestas.

### Configurar output filtering

```yaml
# En config/settings.yaml

output_filtering:
  enabled: true
  filters:
    # API Keys
    - name: "openai_key"
      pattern: "sk-[a-zA-Z0-9]{32,}"
      replacement: "[REDACTED_API_KEY]"

    - name: "anthropic_key"
      pattern: "sk-ant-[a-zA-Z0-9-]{32,}"
      replacement: "[REDACTED_API_KEY]"

    - name: "github_token"
      pattern: "ghp_[a-zA-Z0-9]{36}"
      replacement: "[REDACTED_TOKEN]"

    # Datos personales
    - name: "email"
      pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
      replacement: "[REDACTED_EMAIL]"

    - name: "credit_card"
      pattern: "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"
      replacement: "[REDACTED_CARD]"

    # Paths sensibles
    - name: "env_path"
      pattern: "/home/[^/]+/\\.env"
      replacement: "[REDACTED_PATH]"

    - name: "ssh_path"
      pattern: "/home/[^/]+/\\.ssh/[^\\s]+"
      replacement: "[REDACTED_PATH]"

  # Registrar cuando se redactan datos
  log_redactions: true

  # Bloquear respuesta completamente si contiene secrets (más estricto)
  block_if_contains_secrets: false
```

### Implementar filtro en código

Si OpenClaw no tiene filtering nativo, añade un módulo:

```python
# ~/openclaw/app/security/output_filter.py

import re
from typing import Tuple, List

class OutputFilter:
    PATTERNS = [
        (r"sk-[a-zA-Z0-9]{32,}", "[REDACTED_API_KEY]"),
        (r"sk-ant-[a-zA-Z0-9-]{32,}", "[REDACTED_API_KEY]"),
        (r"ghp_[a-zA-Z0-9]{36}", "[REDACTED_TOKEN]"),
        (r"nvapi-[a-zA-Z0-9-]{32,}", "[REDACTED_API_KEY]"),
        (r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", "[REDACTED_EMAIL]"),
        (r"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b", "[REDACTED_CARD]"),
        (r"-----BEGIN[^-]+PRIVATE KEY-----[\s\S]*?-----END[^-]+PRIVATE KEY-----", "[REDACTED_KEY]"),
    ]

    def __init__(self):
        self.compiled = [(re.compile(p), r) for p, r in self.PATTERNS]

    def filter(self, text: str) -> Tuple[str, List[str]]:
        """Filtra datos sensibles y retorna (texto_filtrado, lista_de_redacciones)"""
        filtered = text
        redactions = []

        for pattern, replacement in self.compiled:
            if pattern.search(filtered):
                filtered = pattern.sub(replacement, filtered)
                redactions.append(replacement)

        return filtered, redactions

# Uso
filter = OutputFilter()
safe_output, redacted = filter.filter(agent_response)
if redacted:
    log.warning(f"Datos sensibles redactados: {redacted}")
```

### Implementación en Node.js/TypeScript

Si tu proyecto usa Node.js:

```javascript
// ~/openclaw/app/security/outputFilter.js

const SENSITIVE_PATTERNS = [
  { pattern: /sk-[a-zA-Z0-9]{32,}/g, replacement: '[REDACTED_API_KEY]' },
  { pattern: /sk-ant-[a-zA-Z0-9-]{32,}/g, replacement: '[REDACTED_API_KEY]' },
  { pattern: /ghp_[a-zA-Z0-9]{36}/g, replacement: '[REDACTED_TOKEN]' },
  { pattern: /nvapi-[a-zA-Z0-9-]{32,}/g, replacement: '[REDACTED_API_KEY]' },
  { pattern: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, replacement: '[REDACTED_EMAIL]' },
  { pattern: /\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b/g, replacement: '[REDACTED_CARD]' },
  { pattern: /-----BEGIN[^-]+PRIVATE KEY-----[\s\S]*?-----END[^-]+PRIVATE KEY-----/g, replacement: '[REDACTED_KEY]' },
];

/**
 * Filtra datos sensibles del texto
 * @param {string} text - Texto a filtrar
 * @returns {{ filtered: string, redactions: string[] }}
 */
function filterOutput(text) {
  let filtered = text;
  const redactions = [];

  for (const { pattern, replacement } of SENSITIVE_PATTERNS) {
    if (pattern.test(filtered)) {
      filtered = filtered.replace(pattern, replacement);
      redactions.push(replacement);
    }
    // Reset regex lastIndex for global patterns
    pattern.lastIndex = 0;
  }

  return { filtered, redactions };
}

// Uso
const result = filterOutput(agentResponse);
if (result.redactions.length > 0) {
  console.warn('Datos sensibles redactados:', result.redactions);
}

module.exports = { filterOutput };
```

---

## Validar skills antes de instalar

!!! warning "26% de skills tienen vulnerabilidades"
    Según [investigaciones de seguridad](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare), muchas skills de terceros contienen código malicioso o vulnerable.

### Antes de instalar cualquier skill

1. **Revisa el código fuente:**
```bash
# Buscar llamadas peligrosas
grep -rE "(exec|eval|subprocess|os\.system|fetch|axios|request)" skills/nueva-skill/

# Buscar URLs hardcodeadas
grep -rE "https?://" skills/nueva-skill/
```

2. **Verifica el autor:**
   - ¿Es conocido en la comunidad?
   - ¿Tiene historial de contribuciones?
   - ¿Hay issues de seguridad reportados?

3. **Comprueba permisos solicitados:**
   - ¿Pide más acceso del necesario?
   - ¿Necesita shell/filesystem completo?

4. **Busca issues de seguridad:**
```bash
# Buscar en GitHub
gh search issues --repo autor/skill "security vulnerability"
```

---

## Configuraciones PROHIBIDAS

!!! danger "Nunca uses estas configuraciones"

| Configuración | Por qué es peligroso |
|---------------|---------------------|
| `"shell": { "enabled": true, "allow_all": true }` | Ejecución arbitraria de comandos |
| `"filesystem": { "allowed_paths": ["/"] }` | Acceso a todo el sistema, incluyendo keys |
| `"http_client": { "allow_all_domains": true }` | Puede filtrar datos a cualquier servidor |
| `"browser": { "use_real_profile": true }` | Acceso a tus sesiones y cookies reales |

### Ejemplo de lo que NO hacer

```json
// ❌ NUNCA hagas esto
{
  "shell": {
    "enabled": true,
    "allowed_commands": ["*"]
  },
  "filesystem": {
    "enabled": true,
    "allowed_paths": ["/"]
  },
  "http_client": {
    "enabled": true,
    "allow_all_domains": true
  }
}
```

### Configuración segura equivalente

```json
// ✅ Versión segura
{
  "shell": {
    "enabled": false
  },
  "filesystem": {
    "enabled": true,
    "allowed_paths": ["/home/openclaw/openclaw/workspace"]
  },
  "http_client": {
    "enabled": true,
    "allowlist": ["api.necesaria.com"]
  }
}
```

---

## Principio de mínimo privilegio

!!! tip "Empieza con lo mínimo"
    1. Comienza con casi todo deshabilitado
    2. Añade skills solo cuando las necesites
    3. Usa allowlists, nunca denylists como único control
    4. Revisa periódicamente qué skills están habilitados

### Checklist antes de habilitar una skill

- [ ] ¿Realmente necesito esta skill?
- [ ] ¿He revisado el código si es de terceros?
- [ ] ¿He configurado los permisos más restrictivos posibles?
- [ ] ¿He añadido solo los dominios/paths necesarios al allowlist?
- [ ] ¿He verificado que output filtering está activo?

---

## Resumen de configuraciones por perfil

| Perfil | Shell | Filesystem | Git | HTTP | Telegram |
|--------|-------|------------|-----|------|----------|
| Revisor de código | ❌ | Solo lectura | Solo lectura | GitHub | ❌ |
| Documentos | ❌ | workspace/ | ❌ | ❌ | ❌ |
| Dev + Telegram | ❌ | workspace/ | Solo lectura | GitHub, Telegram | ✅ |
| Investigador | ❌ | workspace/ | ❌ | APIs papers | ❌ |

---

**Siguiente:** [8. Seguridad del Agente](08-seguridad-agente.md) — OWASP Agentic, guardrails y sandboxing avanzado.
