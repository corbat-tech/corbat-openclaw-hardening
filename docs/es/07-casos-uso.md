# 7. Casos de uso y herramientas

> **TL;DR**: Configuraciones prácticas para diferentes casos de uso. Todos comparten el mismo `openclaw.json` base de la sección 5 — el comportamiento se controla via SOUL.md, no via schema de herramientas.

> **Tiempo estimado**: 20-30 minutos (según configuración elegida)

> **Nivel requerido**: Intermedio

## Prerrequisitos

- [ ] Sección 6 (APIs de LLM) completada
- [ ] OpenClaw funcionando con la configuración de la sección 5

## Objetivos

Al terminar esta sección tendrás:

- SOUL.md adaptado a tu caso de uso
- Estructura de workspace organizada
- Consejos de seguridad operacional aplicados

---

## Cómo funcionan las configs por caso de uso en OpenClaw

!!! info "SOUL.md controla el comportamiento, openclaw.json controla el acceso"
    Un error común es pensar que se configuran restricciones por herramienta en `openclaw.json` (ej: `"shell": { "enabled": false }`). **Así NO funciona OpenClaw.**

    En OpenClaw:

    - **`openclaw.json`** controla qué herramientas están *disponibles* via `tools.profile` y `tools.deny` — es igual para todos los casos de uso (configurado en sección 5)
    - **`SOUL.md`** controla cómo se *comporta* el agente — aquí defines restricciones, capacidades y directrices por caso de uso
    - **Servidores MCP** extienden capacidades con integraciones externas (GitHub, bases de datos, etc.)

    El `openclaw.json` base de la sección 5 da al agente acceso a todas las herramientas excepto `gateway`. **Usa SOUL.md para decirle al agente qué debe y qué no debe hacer.**

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

1. **Define límites estrictos en SOUL.md** — el agente sigue restricciones de comportamiento
2. **Usa cuentas dedicadas** para cada servicio externo
3. **Revisa el código de cada skill** antes de instalarlo (recuerda: 20% de ClawHub era malicioso)
4. **Ejecuta `openclaw security audit`** después de cada cambio
5. **Activa human-in-the-loop** via instrucciones en SOUL.md para acciones irreversibles

---

## Herramientas y canales disponibles (v2026.3.x)

### Canales de comunicación

| Canal | Configuración | Notas de seguridad |
|-------|--------------|-------------------|
| **Telegram** | Bot via @BotFather | Usar `dmPolicy: "allowlist"` con `allowFrom` |
| **WhatsApp** | Via WhatsApp Business API | Requiere número dedicado |
| **Discord** | Bot con permisos limitados | Restringir a canales específicos |
| **Slack** | App con scopes mínimos | Solo canales necesarios |
| **Signal** | Via Signal CLI | Más privado, más complejo de configurar |
| **Email** | Via skill himalaya (IMAP/SMTP) | Usar cuenta dedicada (ver arriba) |

### Herramientas disponibles via profile "full"

| Herramienta | Grupo | Función | Mitigación de riesgo |
|-------------|-------|---------|---------------------|
| `read`, `write`, `edit`, `apply_patch` | `group:fs` | Operaciones de archivos | Restringido a workspace via systemd `ReadWritePaths` |
| `exec`, `bash`, `process` | `group:runtime` | Ejecución de comandos | Systemd `CapabilityBoundingSet`, `NoNewPrivileges` |
| `web_search`, `web_fetch` | `group:web` | Búsqueda web y fetch | Requiere API key (Gemini) |
| `browser`, `canvas` | `group:ui` | Navegación web, contenido visual | Directrices en SOUL.md |
| `sessions_*`, `session_status` | `group:sessions` | Sesiones de sub-agentes | Controlado por `maxConcurrent` |
| `memory_search`, `memory_get` | `group:memory` | Memoria persistente | Scope por agente |
| `cron` | individual | Tareas programadas | Reglas de aprobación en SOUL.md |
| `gateway` | individual | Config del gateway | **DENEGADO** — riesgo de seguridad |

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

No se necesitan cambios en `openclaw.json` — la config base de la sección 5 funciona para todos los casos de uso. El comportamiento se controla via SOUL.md:

### SOUL.md para asistente de negocio

```bash
nano ~/openclaw/workspace/SOUL.md
```

```markdown
# Asistente de Negocio

## Identidad
Eres un asistente de administración y organización empresarial.

## Capacidades
- Resumir y organizar documentos (facturas, contratos, informes)
- Gestionar una base de datos CRM en archivos CSV/JSON
- Redactar borradores de email (NUNCA enviar sin aprobación)
- Crear eventos de calendario via cron
- Generar informes y reportes
- Buscar información de negocio en la web

## Límites estrictos
- No enviar emails sin confirmación explícita del usuario
- No eliminar archivos ni datos de clientes
- No acceder a información fuera del workspace
- No ejecutar comandos de shell salvo que se pida explícitamente
- No hacer push a ningún repositorio git
- Redactar cualquier dato sensible (DNI, números de cuenta, etc.)
- Siempre preguntar antes de cualquier acción irreversible
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

### SOUL.md para agente de programación

```markdown
# Agente de Desarrollo

## Identidad
Eres un asistente de desarrollo de software especializado en revisión de código, testing y documentación.

## Capacidades
- Clonar y analizar repositorios
- Revisar código y sugerir mejoras
- Ejecutar tests (npm test, pytest, make test) y reportar resultados
- Generar documentación técnica
- Crear commits (con aprobación)
- Buscar documentación y APIs en la web

## Límites estrictos
- No hacer push a repositorios remotos sin aprobación explícita
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

### SOUL.md para asistente de investigación

```markdown
# Asistente de Investigación

## Identidad
Eres un asistente de investigación especializado en encontrar, resumir y organizar información académica y técnica.

## Capacidades
- Buscar papers, artículos y documentación en la web
- Obtener y resumir páginas web y PDFs
- Organizar notas de investigación por tema en el workspace
- Generar bibliografías y listas de citas
- Comparar y sintetizar información de múltiples fuentes

## Límites estrictos
- No ejecutar comandos de shell salvo para organizar archivos
- No modificar archivos fuera de los directorios de investigación del workspace
- No enviar comunicaciones sin aprobación
- Siempre citar fuentes al resumir información
- No acceder ni almacenar datos personales
```

### Estructura de workspace

```bash
mkdir -p ~/openclaw/workspace/{research,notes,output,bibliography}
```

### Tareas típicas

- "Busca papers recientes sobre [tema] usando web search"
- "Descarga y resume esta página web: [URL]"
- "Organiza mis notas de investigación por tema"
- "Genera una bibliografía en formato APA de estas notas"
- "Compara las conclusiones de estos 3 artículos"

---

## Caso de uso 4: Automatización personal y productividad

### Perfil: Asistente personal via Telegram

Para usuarios que quieren un asistente accesible desde el móvil para tareas diarias.

### SOUL.md para asistente personal

```markdown
# Asistente Personal

## Identidad
Eres un asistente de productividad personal accesible via Telegram.

## Capacidades
- Crear y gestionar recordatorios via cron
- Resumir documentos y páginas web
- Buscar información en la web
- Gestionar listas y notas en el workspace
- Leer y redactar emails (via skill himalaya, si instalado)

## Límites estrictos
- No enviar emails sin aprobación explícita
- No ejecutar comandos de shell salvo para tareas programadas
- No acceder a archivos fuera del workspace
- No hacer push a repositorios git
- Siempre confirmar antes de crear eventos o recordatorios
- Nunca compartir información personal en respuestas
```

### Obtener token de Telegram

1. Habla con [@BotFather](https://t.me/BotFather) en Telegram
2. Envía `/newbot`
3. Sigue las instrucciones para crear el bot
4. Almacena el token:
   ```bash
   openclaw secrets configure
   # Sigue el wizard interactivo para añadir TELEGRAM_BOT_TOKEN
   ```

### Tareas típicas via Telegram

- "Recuérdame mañana a las 9 que tengo reunión"
- "Resume este documento que te envío"
- "Busca en la web sobre [tema] y dame un resumen"
- "Crea una lista de compras basada en las recetas de la semana"

---

## Caso de uso 5: DevOps y monitorización

### Perfil: Asistente de infraestructura

Para administradores de sistemas que quieren un agente que monitorice y alerte sobre problemas.

### SOUL.md para asistente DevOps

```markdown
# Asistente DevOps

## Identidad
Eres un asistente de monitorización de infraestructura. Tu rol principal es observar, analizar y alertar — NO modificar sistemas.

## Capacidades
- Comprobar estado del sistema: disco, memoria, CPU, uptime
- Leer logs del sistema (journalctl, /var/log)
- Comprobar estado de servicios (systemctl)
- Comprobar conexiones de red (ss)
- Enviar alertas via Telegram cuando se superen umbrales
- Programar checks de monitorización via cron

## Límites estrictos
- NUNCA ejecutar comandos destructivos (rm, kill, reboot, shutdown)
- NUNCA usar sudo
- NUNCA modificar configuración del sistema
- NUNCA cambiar permisos de archivos
- NUNCA instalar o eliminar paquetes
- Solo LEER información del sistema — nunca ESCRIBIR en rutas del sistema
- Preguntar antes de reiniciar cualquier servicio
```

!!! tip "Alertas automáticas"
    Combina este caso de uso con un canal de Telegram y cron para recibir alertas:
    "Programa un check cada 30 minutos — si el uso de disco supera el 80%, avísame por Telegram"

---

## Prevenir filtración de datos

El output filtering previene que el agente exponga datos sensibles en sus respuestas. En OpenClaw, esto se aplica via **instrucciones en SOUL.md**:

### Añadir a cualquier SOUL.md

```markdown
## Reglas de protección de datos
- NUNCA incluir API keys, tokens o contraseñas en respuestas
- NUNCA mostrar el contenido de archivos .env o systemd overrides
- Redactar emails, números de tarjeta de crédito y DNIs en la salida
- No exponer rutas de archivos que contengan /home/usuario/.ssh o similar
- Si se pide leer archivos sensibles (~/.openclaw/.env, /etc/shadow, etc.), rechazar
```

!!! info "Defensa en profundidad"
    SOUL.md proporciona guardrails de comportamiento. Combinado con hardening systemd (`ProtectSystem=strict`, `ReadWritePaths` limitado al workspace), incluso si el agente ignora las instrucciones de SOUL.md, no puede acceder a la mayoría de archivos sensibles a nivel de SO.

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

## Prácticas PROHIBIDAS

!!! danger "Nunca hagas esto"

| Práctica | Por qué es peligroso |
|----------|---------------------|
| Conectar tu email personal al agente | Expone datos confidenciales, contactos e historial |
| Usar `dmPolicy: "open"` en cualquier canal | Cualquiera puede enviar comandos a tu agente |
| Saltarse los límites de SOUL.md | El agente no tiene restricciones sobre qué hace con sus herramientas |
| Instalar skills sin revisar el código | 20% de skills de ClawHub eran maliciosos (Feb 2026) |
| Ejecutar `openclaw doctor --fix` tras config manual | Sobreescribe tu configuración de proveedores con defaults rotos |
| Dar al agente acceso a tus cuentas reales de GitHub/Git | Un agente comprometido puede hacer push de código malicioso |

---

## Resumen de configuraciones por caso de uso

Todos los casos comparten el mismo `openclaw.json` base (sección 5). Las diferencias están en SOUL.md:

| Caso de uso | Uso de shell | Acceso web | Scope de archivos | Regla clave de SOUL.md |
|-------------|-------------|------------|-------------------|----------------------|
| Empresa/CRM | Mínimo | Web search | workspace/ | No emails sin aprobación |
| Programación | Tests, git | API GitHub | workspace/ | No push sin aprobación |
| Investigación | Mínimo | Web search + fetch | workspace/ | Siempre citar fuentes |
| Personal | Tareas programadas | Web search | workspace/ | Confirmar antes de actuar |
| DevOps | Solo lectura monitorización | Solo alertas | Logs (lectura) | NUNCA comandos destructivos |

---

**Siguiente:** [8. Seguridad del Agente](08-seguridad-agente.md) — OWASP Agentic, guardrails y sandboxing avanzado.
