# 7. Casos de uso y herramientas

> **TL;DR**: Configuraciones prácticas para diferentes casos de uso, herramientas recomendadas, consejos de seguridad operacional y orientación para aprovechar OpenClaw una vez instalado.

> **Tiempo estimado**: 20-30 minutos (según configuración elegida)

> **Nivel requerido**: Intermedio

## Prerrequisitos

- [ ] Sección 6 (APIs de LLM) completada
- [ ] OpenClaw funcionando con sandbox mode `"all"`

## Objetivos

Al terminar esta sección tendrás:

- Configuración adaptada a tu caso de uso
- Herramientas y canales configurados
- Output filtering para prevenir filtración de datos
- Consejos de seguridad operacional aplicados

---

## Consejos de seguridad operacional

!!! danger "Lee esto antes de configurar cualquier caso de uso"

### Crea cuentas dedicadas para OpenClaw

| Servicio | Recomendación | Por qué |
|----------|---------------|---------|
| **Email** | Crear email nuevo exclusivo (ej: `mi-openclaw@proton.me`) | Si el agente se compromete, no expone tu email personal, contactos ni historial |
| **GitHub** | Crear cuenta/organización separada | Evita que un agente comprometido haga push a tus repos reales |
| **Telegram/Discord** | Crear bot dedicado, no usar cuenta personal | Los tokens de bot son revocables sin afectar tu cuenta |
| **Calendario** | Usar calendario secundario o de solo lectura | Previene que el agente modifique o cancele tus eventos reales |
| **CRM/Negocio** | Cuenta con permisos de solo lectura cuando sea posible | Principio de mínimo privilegio |

!!! warning "Nunca conectes tu cuenta de email personal"
    Un agente AI con acceso a tu email real puede:

    - Leer información confidencial (contratos, datos bancarios, conversaciones privadas)
    - Enviar emails en tu nombre sin tu supervisión
    - Ser manipulado via prompt injection para filtrar datos a terceros
    - Exponer tu lista de contactos

    **Crea siempre un email dedicado** para las integraciones del agente.

### Principios de configuración segura

1. **Empieza con todo deshabilitado** — habilita solo lo que necesites
2. **Usa allowlists, nunca denylists** como único control
3. **Revisa el código de cada skill** antes de instalarlo (recuerda: 20% de ClawHub era malicioso)
4. **Ejecuta `openclaw security audit`** después de cada cambio
5. **Activa human-in-the-loop** para acciones irreversibles

---

## Herramientas y canales disponibles (v2026.3.x)

### Canales de comunicación

| Canal | Configuración | Notas de seguridad |
|-------|--------------|-------------------|
| **Telegram** | Bot via @BotFather | Recomendado: usar `dmPolicy: "pairing"` |
| **WhatsApp** | Via WhatsApp Business API | Requiere número dedicado |
| **Discord** | Bot con permisos limitados | Restringir a canales específicos |
| **Slack** | App con scopes mínimos | Solo canales necesarios |
| **Signal** | Via Signal CLI | Más privado, más complejo de configurar |
| **Email** | Via IMAP/SMTP | Usar cuenta dedicada (ver arriba) |

### Herramientas integradas

| Herramienta | Función | Riesgo | Recomendación |
|-------------|---------|--------|---------------|
| `filesystem` | Leer/escribir archivos | Medio | Restringir a workspace |
| `git` | Operaciones Git | Medio | Solo lectura por defecto |
| `http_client` | Peticiones HTTP | Alto | Allowlist de dominios estricta |
| `browser` | Navegación web | Muy alto | Deshabilitado por defecto |
| `shell` | Ejecución de comandos | Muy alto | Deshabilitado por defecto |
| `email` | Enviar/recibir email | Alto | Solo cuenta dedicada |
| `calendar` | Gestión calendario | Medio | Solo lectura preferible |
| `pdf` | Análisis de PDFs | Bajo | Nuevo en v2026.3.2 |

### Servidores MCP (Model Context Protocol)

OpenClaw soporta [MCP](https://modelcontextprotocol.io/) para integrarse con servicios externos:

```json
{
  "mcp": {
    "servers": {
      "github": {
        "command": "npx",
        "args": ["@modelcontextprotocol/server-github"],
        "env": { "GITHUB_TOKEN": { "$secretRef": "GITHUB_TOKEN" } }
      }
    }
  }
}
```

!!! warning "Audita cada servidor MCP"
    Los servidores MCP son código de terceros que se ejecuta con los permisos de tu agente. Aplica las mismas precauciones que con los skills de ClawHub: revisa el código, verifica el autor, ejecuta en sandbox.

---

## Caso de uso 1: Administración de empresa / CRM

### Perfil: Asistente de negocio

Ideal para autónomos y pymes que necesitan organizar documentos, gestionar tareas y mantener un CRM básico.

### Configuración

```json
{
  "agents": {
    "defaults": {
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": { "mode": "all" }
    }
  },

  "tools": {
    "filesystem": {
      "enabled": true,
      "allowed_paths": [
        "/home/openclaw/openclaw/workspace/documents",
        "/home/openclaw/openclaw/workspace/crm",
        "/home/openclaw/openclaw/workspace/output"
      ],
      "allowed_operations": ["read", "write", "list", "create_directory", "move", "copy"],
      "denied_operations": ["delete_recursive", "change_permissions"],
      "max_file_size_mb": 50
    },

    "email": {
      "enabled": true,
      "account": "mi-openclaw@proton.me",
      "allowed_operations": ["read", "draft"],
      "denied_operations": ["send", "delete", "forward"],
      "require_approval": ["send"]
    },

    "calendar": {
      "enabled": true,
      "allowed_operations": ["read", "create_event"],
      "denied_operations": ["delete_event", "modify_event"],
      "require_approval": ["create_event"]
    },

    "http_client": {
      "enabled": true,
      "allowlist": ["api.notion.com", "api.airtable.com"]
    },

    "git": { "enabled": false },
    "shell": { "enabled": false },
    "browser": { "enabled": false }
  }
}
```

### SOUL.md para asistente de negocio

```markdown
# Asistente de Negocio

## Identidad
Eres un asistente de administración y organización empresarial.

## Capacidades
- Resumir y organizar documentos (facturas, contratos, informes)
- Gestionar una base de datos CRM en archivos CSV/JSON
- Redactar borradores de email (NUNCA enviar sin aprobación)
- Crear eventos de calendario
- Generar informes y reportes

## Límites estrictos
- No enviar emails sin confirmación explícita del usuario
- No eliminar archivos ni datos de clientes
- No acceder a información fuera del workspace
- No hacer llamadas a APIs no incluidas en la allowlist
- Redactar cualquier dato sensible (DNI, números de cuenta, etc.)
```

### Estructura de workspace

```bash
mkdir -p ~/openclaw/workspace/{documents,crm,output,templates}

# Ejemplo: crear CRM básico
cat > ~/openclaw/workspace/crm/contacts.json << 'EOF'
{
  "contacts": [],
  "schema": {
    "fields": ["name", "email", "company", "phone", "notes", "last_contact"]
  }
}
EOF
```

### Tareas típicas

- "Resume esta factura PDF y extrae los datos clave"
- "Añade este contacto al CRM: [datos]"
- "Genera un informe mensual de los contactos activos"
- "Redacta un email de seguimiento para el cliente X"
- "Organiza los documentos de la carpeta /documents por tipo"

---

## Caso de uso 2: Agente de programación

### Perfil: Asistente de desarrollo

Para desarrolladores que quieren un agente que revise código, genere documentación, analice repos y ayude con tareas de desarrollo.

### Configuración

```json
{
  "agents": {
    "defaults": {
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": { "mode": "all" }
    }
  },

  "tools": {
    "filesystem": {
      "enabled": true,
      "allowed_paths": ["/home/openclaw/openclaw/workspace"],
      "allowed_operations": ["read", "write", "list", "create_directory"],
      "denied_operations": ["delete_recursive", "change_permissions"]
    },

    "git": {
      "enabled": true,
      "allowed_operations": ["clone", "status", "diff", "log", "branch", "checkout", "commit"],
      "denied_operations": ["push", "force-push", "reset --hard", "clean"],
      "require_approval": ["commit"]
    },

    "http_client": {
      "enabled": true,
      "allowlist": [
        "api.github.com",
        "api.gitlab.com",
        "registry.npmjs.org",
        "pypi.org"
      ]
    },

    "shell": {
      "enabled": true,
      "allowed_commands": ["npm test", "npm run lint", "python -m pytest", "make test"],
      "denied_commands": ["rm -rf", "sudo", "chmod", "curl", "wget"],
      "sandbox": "all"
    },

    "email": { "enabled": false },
    "browser": { "enabled": false }
  }
}
```

!!! warning "Shell habilitado con restricciones"
    En este caso de uso, shell está habilitado pero **estrictamente limitado** a comandos de testing y linting. Cada ejecución se containeriza en sandbox. Nunca habilites `"allowed_commands": ["*"]`.

### SOUL.md para agente de programación

```markdown
# Agente de Desarrollo

## Identidad
Eres un asistente de desarrollo de software especializado en revisión de código, testing y documentación.

## Capacidades
- Clonar y analizar repositorios
- Revisar código y sugerir mejoras
- Ejecutar tests y reportar resultados
- Generar documentación técnica
- Crear commits (con aprobación)

## Límites estrictos
- No hacer push a repositorios remotos
- No ejecutar comandos destructivos (rm -rf, reset --hard)
- No instalar dependencias sin aprobación
- No acceder a archivos fuera del workspace
- No modificar configuración del sistema
- Reportar vulnerabilidades de seguridad encontradas
```

### Flujo de trabajo típico

```bash
# 1. Clonar un repo para revisión
# (El agente lo hace dentro de su workspace)
openclaw agent --message "Clona https://github.com/user/repo y analiza la calidad del código"

# 2. Ejecutar tests
openclaw agent --message "Ejecuta los tests del proyecto y dame un resumen"

# 3. Revisar cambios
openclaw agent --message "Revisa los cambios en el branch feature/auth y sugiere mejoras"
```

### Servidores MCP útiles para desarrollo

```json
{
  "mcp": {
    "servers": {
      "github": {
        "command": "npx",
        "args": ["@modelcontextprotocol/server-github"],
        "env": { "GITHUB_TOKEN": { "$secretRef": "GITHUB_TOKEN" } }
      },
      "postgres": {
        "command": "npx",
        "args": ["@modelcontextprotocol/server-postgres"],
        "env": { "DATABASE_URL": { "$secretRef": "DATABASE_URL" } }
      }
    }
  }
}
```

---

## Caso de uso 3: Investigación y gestión de conocimiento

### Perfil: Asistente de investigación

Para investigadores, escritores y profesionales que necesitan buscar, resumir y organizar información de forma estructurada.

### Configuración

```json
{
  "tools": {
    "filesystem": {
      "enabled": true,
      "allowed_paths": [
        "/home/openclaw/openclaw/workspace/research",
        "/home/openclaw/openclaw/workspace/notes",
        "/home/openclaw/openclaw/workspace/output"
      ],
      "allowed_operations": ["read", "write", "list", "create_directory"]
    },

    "http_client": {
      "enabled": true,
      "allowlist": [
        "api.semanticscholar.org",
        "export.arxiv.org",
        "api.crossref.org",
        "api.openalex.org"
      ]
    },

    "pdf": {
      "enabled": true,
      "max_pages": 100
    },

    "git": { "enabled": false },
    "shell": { "enabled": false },
    "browser": { "enabled": false },
    "email": { "enabled": false }
  }
}
```

### Tareas típicas

- "Busca papers recientes sobre [tema] en Semantic Scholar"
- "Resume este PDF de 50 páginas y extrae los puntos clave"
- "Organiza mis notas de investigación por tema"
- "Genera una bibliografía en formato APA de estos papers"
- "Compara las conclusiones de estos 3 artículos"

---

## Caso de uso 4: Automatización personal y productividad

### Perfil: Asistente personal via Telegram/WhatsApp

Para usuarios que quieren un asistente accesible desde el móvil para tareas diarias.

### Configuración

```json
{
  "dmPolicy": "pairing",

  "channels": {
    "telegram": {
      "enabled": true,
      "bot_token": { "$secretRef": "TELEGRAM_BOT_TOKEN" }
    }
  },

  "tools": {
    "filesystem": {
      "enabled": true,
      "allowed_paths": ["/home/openclaw/openclaw/workspace"],
      "allowed_operations": ["read", "write", "list", "create_directory"]
    },

    "calendar": {
      "enabled": true,
      "allowed_operations": ["read", "create_event"],
      "require_approval": ["create_event"]
    },

    "http_client": {
      "enabled": true,
      "allowlist": [
        "api.openweathermap.org",
        "api.telegram.org"
      ]
    },

    "shell": { "enabled": false },
    "browser": { "enabled": false },
    "git": { "enabled": false }
  }
}
```

### Obtener token de Telegram

1. Habla con [@BotFather](https://t.me/BotFather) en Telegram
2. Envía `/newbot`
3. Sigue las instrucciones para crear el bot
4. Almacena el token con SecretRef:
   ```bash
   openclaw secrets set TELEGRAM_BOT_TOKEN
   ```

### Tareas típicas via Telegram

- "Recuérdame mañana a las 9 que tengo reunión"
- "Resume este documento que te envío"
- "¿Qué tengo en el calendario esta semana?"
- "Crea una lista de compras basada en las recetas de la semana"

---

## Caso de uso 5: DevOps y monitorización

### Perfil: Asistente de infraestructura

Para administradores de sistemas que quieren un agente que monitorice y alerte sobre problemas.

### Configuración

```json
{
  "tools": {
    "filesystem": {
      "enabled": true,
      "allowed_paths": [
        "/home/openclaw/openclaw/workspace",
        "/var/log"
      ],
      "allowed_operations": ["read", "list"]
    },

    "shell": {
      "enabled": true,
      "allowed_commands": [
        "df -h", "free -h", "uptime", "top -bn1",
        "systemctl status *", "journalctl -n 50 -u *",
        "docker ps", "docker logs *",
        "ss -tlnp", "fail2ban-client status *"
      ],
      "denied_commands": ["rm", "sudo", "chmod", "kill", "reboot", "shutdown"],
      "sandbox": "all"
    },

    "http_client": {
      "enabled": true,
      "allowlist": ["api.telegram.org"]
    },

    "git": { "enabled": false },
    "browser": { "enabled": false }
  }
}
```

!!! tip "Alertas automáticas"
    Combina este caso de uso con un canal de Telegram para recibir alertas:
    "Si el uso de disco supera el 80%, avísame por Telegram"

---

## Prevenir filtración de datos (OWASP AA2)

El output filtering previene que el agente exponga datos sensibles en sus respuestas. Esta configuración aplica a **todos los casos de uso**.

### Configurar output filtering

```yaml
# Agregar a config/settings.yaml (crear si no existe)
# Esta es una configuración de ejemplo — adaptar a tu despliegue

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

  log_redactions: true
  block_if_contains_secrets: false
```

---

## Validar skills antes de instalar

!!! danger "20% de skills en ClawHub eran maliciosos"
    Después del incidente de febrero 2026, nunca instales skills sin auditarlos.

### Antes de instalar cualquier skill

1. **Revisa el código fuente:**
```bash
# Buscar llamadas peligrosas
grep -rE "(exec|eval|subprocess|os\.system|fetch|axios|request)" skills/nueva-skill/

# Buscar URLs hardcodeadas
grep -rE "https?://" skills/nueva-skill/
```

2. **Ejecuta en sandbox primero:**
```bash
# Instalar skill en modo test
openclaw skills install nueva-skill --sandbox

# Verificar comportamiento
openclaw security audit
```

3. **Verifica el autor:**
   - ¿Tiene historial de contribuciones?
   - ¿Hay issues de seguridad reportados?
   - ¿Cuenta de GitHub creada hace más de 1 semana? (requisito mínimo de ClawHub, claramente insuficiente)

---

## Configuraciones PROHIBIDAS

!!! danger "Nunca uses estas configuraciones"

| Configuración | Por qué es peligroso |
|---------------|---------------------|
| `"shell": { "enabled": true, "allowed_commands": ["*"] }` | Ejecución arbitraria de comandos |
| `"filesystem": { "allowed_paths": ["/"] }` | Acceso a todo el sistema, incluyendo keys |
| `"http_client": { "allow_all_domains": true }` | Puede filtrar datos a cualquier servidor |
| `"browser": { "use_real_profile": true }` | Acceso a tus sesiones y cookies reales |
| `"dmPolicy": "open"` | Cualquiera puede enviar comandos al agente |
| `"sandbox": { "mode": "off" }` | Sin aislamiento, acceso completo al host |

---

## Resumen de configuraciones por perfil

| Perfil | Shell | Filesystem | Git | HTTP | Email | Telegram |
|--------|-------|------------|-----|------|-------|----------|
| Empresa/CRM | - | workspace/ | - | CRM APIs | Solo borradores | Opcional |
| Programación | Limitado | workspace/ | Lectura+commit | GitHub | - | - |
| Investigación | - | research/ | - | APIs papers | - | - |
| Personal | - | workspace/ | - | Limitado | - | Bot dedicado |
| DevOps | Solo lectura | logs/ | - | Telegram | - | Alertas |

---

**Siguiente:** [8. Seguridad del Agente](08-seguridad-agente.md) — OWASP Agentic, guardrails y sandboxing avanzado.
