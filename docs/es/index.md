# OpenClaw en VPS

Guía para instalar y ejecutar **OpenClaw** de forma **privada, aislada y segura** en un VPS.

---

## ¿Qué es OpenClaw?

[OpenClaw](https://github.com/openclaw/openclaw) es un asistente personal de IA open-source que puedes ejecutar en tus propios dispositivos. A diferencia de chatbots tradicionales, OpenClaw es un **agente autónomo** que puede ejecutar comandos shell, gestionar archivos, automatizar navegadores y conectarse a múltiples canales (WhatsApp, Telegram, Slack, Discord, etc.).

!!! info "Sobre OpenClaw"
    OpenClaw (anteriormente Clawdbot/Moltbot) alcanzó 100k+ estrellas en GitHub en 2026, convirtiéndose en uno de los proyectos de más rápido crecimiento. Usa el [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) para integrarse con 100+ servicios externos.

!!! warning "Principio fundamental"
    **OpenClaw no se publica.** Se aísla, se limita y se accede solo por red privada. Un agente con acceso a herramientas mal configurado es un riesgo de seguridad serio.

---

## ¿Para quién es esta guía?

- **Desarrolladores** que quieren un agente AI para automatizar tareas técnicas
- **Autónomos y pequeñas empresas** que necesitan asistencia con documentos y organización
- **Usuarios técnicos** que valoran la privacidad y el control sobre sus herramientas

---

## Requisitos de conocimiento

| Concepto | Nivel requerido | Dónde aprenderlo |
|----------|-----------------|------------------|
| Terminal/Bash | Básico | [LinuxCommand.org](https://linuxcommand.org/) |
| SSH | Básico | Sección 3 de esta guía |
| Redes (IP, puertos) | Conceptual | [DigitalOcean - Understanding IP](https://www.digitalocean.com/community/tutorials/understanding-ip-addresses-subnets-and-cidr-notation-for-networking) |
| VPN | Conceptual | Se explica en sección 4 |
| YAML/JSON | Básico | Para archivos de configuración |

---

## Tiempo estimado

| Sección | Tiempo | Nivel |
|---------|--------|-------|
| 1. Preparación | 15-20 min | Principiante |
| 2. Contratar VPS | 10-15 min | Principiante |
| 3. Seguridad sistema | 30-40 min | Intermedio |
| 4. Acceso privado | 20-30 min | Intermedio |
| 5. Instalar OpenClaw | 25-35 min | Intermedio |
| 6. APIs LLM | 10-15 min | Principiante |
| 7. Casos de uso | 15-20 min | Intermedio |
| 8. Seguridad agente | 30-45 min | Avanzado |
| 9. Mantenimiento | Referencia | Intermedio |
| 10. Checklist final | 10 min | - |
| **Total** | **~3 horas** | |

---

## ¿Qué vas a conseguir?

Un servidor privado con OpenClaw que:

- **No está expuesto a Internet** — cero puertos públicos
- **Solo es accesible por VPN** (Tailscale)
- **Ejecuta con privilegios mínimos** — usuario dedicado, sin root
- **Tiene permisos limitados** — solo accede a lo que tú configures
- **Cumple estándares de seguridad** — CIS Benchmark, OWASP Agentic Top 10

---

## Arquitectura objetivo

```
┌─────────────────────────────────────────────────────────────┐
│                      INTERNET                               │
│                         ❌                                  │
│              (Sin puertos abiertos)                         │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                       TU VPS                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Ubuntu 24.04 LTS                                     │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Capa 1: Firewall UFW (deny all incoming)       │  │  │
│  │  │  ┌─────────────────────────────────────────┐    │  │  │
│  │  │  │  Capa 2: Tailscale VPN                  │    │  │  │
│  │  │  │  └─> SSH solo por Tailscale IP          │    │  │  │
│  │  │  │  └─> ACLs zero-trust                    │    │  │  │
│  │  │  │  ┌─────────────────────────────────┐    │    │  │  │
│  │  │  │  │  Capa 3: Systemd + Sandbox      │    │    │  │  │
│  │  │  │  │  └─> OpenClaw en localhost      │    │    │  │  │
│  │  │  │  │  └─> Sandbox mode "all"         │    │    │  │  │
│  │  │  │  │  └─> Gateway TLS pairing        │    │    │  │  │
│  │  │  │  │  └─> Skills con allowlist       │    │    │  │  │
│  │  │  │  └─────────────────────────────────┘    │    │  │  │
│  │  │  └─────────────────────────────────────────┘    │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  Usuario: openclaw (no-root)                          │  │
│  │  Auditd + AIDE para monitoreo                         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          ▲
          │ Tailscale VPN (cifrado WireGuard)
          │ Solo owner puede conectar (ACLs)
          ▼
┌─────────────────────────────────────────────────────────────┐
│              TU DISPOSITIVO                                 │
│  (portátil, móvil — también con Tailscale)                  │
│  SSH + Port forwarding para acceder a OpenClaw              │
└─────────────────────────────────────────────────────────────┘
```

---

## Coste estimado

| Concepto | Precio mensual |
|----------|----------------|
| VPS (4-8GB RAM, 2 vCPU) | 4-10 €/mes |
| Tailscale (free tier) | 0 € |
| API LLM | 0-80 €/mes |
| **Total** | **~4-90 €/mes** |

!!! tip "Opción gratuita"
    Usando Kimi K2.5 en NVIDIA NIM (gratis) + VPS económico (~4€), puedes tener OpenClaw funcionando por menos de 5€/mes.

---

## Estándares de seguridad cubiertos

| Estándar | Cobertura | Secciones |
|----------|-----------|-----------|
| **CIS Benchmark Ubuntu 24.04 L1** | 100% (SSH + kernel hardening) | 3 |
| **Tailscale Security Hardening** | 100% | 4 |
| **OWASP Agentic Top 10 2026** | 90%+ | 5, 7, 8 |
| **Systemd Hardening** | Completo | 5 |

---

## Riesgos de seguridad de agentes AI

!!! danger "Los agentes AI con herramientas son peligrosos si se configuran mal"

Según [investigaciones de seguridad](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare):

| Riesgo | Descripción | Mitigación en esta guía |
|--------|-------------|-------------------------|
| **Filtración de API keys** | El agente puede exponer credenciales | SecretRef, output filtering |
| **Prompt injection** | Inputs maliciosos manipulan al agente | Input validation, guardrails |
| **Skills maliciosos (ClawHub)** | 20% de skills en ClawHub eran malware | Allowlist estricta, `openclaw security audit` |
| **ClawJacked (WebSocket)** | Sitios web secuestran agentes locales | Gateway TLS pairing, binding loopback |
| **Acceso excesivo** | Filesystem/shell sin límites | Sandbox "all", mínimo privilegio |

---

## Lo que NO debes hacer

!!! danger "Errores críticos"
    - ❌ Ejecutar OpenClaw como root
    - ❌ Abrir puertos "para probar"
    - ❌ Usar contraseñas en SSH
    - ❌ Dar acceso completo al filesystem
    - ❌ Instalarlo en tu máquina personal de trabajo
    - ❌ Instalar skills de ClawHub sin revisar su código (20% eran malware)
    - ❌ Conectar tu email personal al agente (crea uno dedicado)
    - ❌ Usar `dmPolicy: "open"` (permite comandos de cualquiera)
    - ❌ Desactivar sandbox (`mode: "off"`)
    - ❌ Usar `curl | bash` sin verificar el script
    - ❌ Dejar ACLs de Tailscale en "permit all"

---

## Lo que NO cubre esta guía

- Alta disponibilidad (HA) o clustering
- Backups automatizados a la nube (solo manual)
- CI/CD para despliegue automático
- Múltiples agentes comunicándose entre sí
- Integración con Kubernetes
- Uso en producción empresarial (requiere auditoría adicional)

---

## Estructura de la guía

| # | Sección | Descripción |
|---|---------|-------------|
| 1 | **[Preparación](01-preparacion.md)** | Cuentas, SSH keys, límites de gasto |
| 2 | **[Contratar VPS](02-vps.md)** | Proveedores, verificación de imagen |
| 3 | **[Seguridad del sistema](03-seguridad-sistema.md)** | Usuario, SSH hardening CIS, firewall, auditd |
| 4 | **[Acceso privado](04-acceso-privado.md)** | Tailscale, ACLs, eliminar SSH público |
| 5 | **[Instalar OpenClaw](05-openclaw.md)** | Node.js, configuración, systemd hardening |
| 6 | **[APIs de LLM](06-llm-apis.md)** | Configuración, límites, rotación |
| 7 | **[Casos de uso](07-casos-uso.md)** | Ejemplos prácticos, output filtering |
| 8 | **[Seguridad del agente](08-seguridad-agente.md)** | OWASP Agentic, guardrails, AppArmor |
| 9 | **[Mantenimiento](09-mantenimiento.md)** | Updates, rotación, backups, DR |
| 10 | **[Checklist final](10-checklist-final.md)** | Verificación de todos los controles |
| - | **[Glosario](glosario.md)** | Definiciones de términos |

---

## Referencias

- [OpenClaw - Documentación oficial](https://docs.openclaw.ai/)
- [OpenClaw - Seguridad](https://docs.openclaw.ai/gateway/security)
- [OpenClaw - Hardening Guide (Nebius)](https://nebius.com/blog/posts/openclaw-security)
- [CIS Ubuntu Linux 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Tailscale Security Hardening](https://tailscale.com/kb/1196/security-hardening)
- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/)
- [NIST AI Agent Standards Initiative (2026)](https://www.nist.gov/news-events/news/2026/02/announcing-ai-agent-standards-initiative-interoperable-and-secure)
- [systemd Hardening](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Sandboxing)
- [Cisco - Riesgos de agentes AI personales](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare)
- [ClawHub Supply Chain Attack (The Hacker News)](https://thehackernews.com/2026/02/researchers-find-341-malicious-clawhub.html)
- [Hetzner Cloud Review 2026 (Better Stack)](https://betterstack.com/community/guides/web-servers/hetzner-cloud-review/)
- [SSH Hardening Guides (ssh-audit)](https://www.sshaudit.com/hardening_guides.html)

---

## Empezar

**Siguiente:** [1. Preparación](01-preparacion.md) — Qué necesitas antes de empezar.
