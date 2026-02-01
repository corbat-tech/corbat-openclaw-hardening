# Glosario

Definiciones de términos técnicos utilizados en esta guía.

---

## A

### ACL (Access Control List)
Lista de reglas que define qué entidades pueden acceder a qué recursos. En Tailscale, las ACLs definen qué dispositivos pueden comunicarse entre sí.

### Agente AI
Software que utiliza inteligencia artificial para realizar tareas de forma autónoma, tomando decisiones basadas en su entorno y objetivos.

### AIDE (Advanced Intrusion Detection Environment)
Sistema de detección de intrusiones basado en host que monitorea cambios en archivos del sistema.

### Allowlist
Lista de elementos explícitamente permitidos. Más seguro que una denylist porque bloquea todo excepto lo especificado.

### API Key
Credencial secreta que identifica a una aplicación o usuario ante un servicio API.

### AppArmor
Sistema de control de acceso obligatorio (MAC) para Linux que restringe las capacidades de programas individuales.

### Auditd
Demonio de auditoría de Linux que registra eventos de seguridad del sistema.

---

## B

### Backup
Copia de seguridad de datos importantes para poder recuperarlos en caso de pérdida.

### Banner SSH
Mensaje que se muestra a los usuarios antes de autenticarse por SSH, típicamente con advertencias legales.

### Brute-force
Ataque que intenta adivinar credenciales probando múltiples combinaciones de forma sistemática.

---

## C

### CIS Benchmark
Guías de configuración segura publicadas por el Center for Internet Security, reconocidas como estándar de la industria.

### Cipher
Algoritmo criptográfico utilizado para cifrar datos. En SSH, define cómo se cifra la comunicación.

### CLI (Command Line Interface)
Interfaz de línea de comandos, donde el usuario interactúa con el sistema mediante texto.

---

## D

### Denylist
Lista de elementos explícitamente bloqueados. Menos seguro que una allowlist porque permite todo excepto lo especificado.

### Disaster Recovery
Procedimientos para recuperar sistemas y datos después de un incidente grave.

---

## E

### Ed25519
Algoritmo de firma digital moderno utilizado para claves SSH, más seguro y eficiente que RSA.

### Endpoint
Punto final de comunicación en una red, como un dispositivo o servicio.

### Environment Variables (.env)
Variables de entorno almacenadas en un archivo, típicamente usado para configuración sensible como API keys.

---

## F

### Fail2ban
Software que protege contra ataques de fuerza bruta baneando IPs que muestran comportamiento malicioso.

### Firewall
Sistema que controla el tráfico de red entrante y saliente según reglas definidas.

### Fingerprint
Identificador único derivado criptográficamente de una clave, usado para verificar su autenticidad.

---

## G

### GPG (GNU Privacy Guard)
Herramienta de cifrado que implementa el estándar OpenPGP para cifrado y firma de datos.

### Guardrails
Restricciones de seguridad que limitan el comportamiento de un sistema o agente AI.

---

## H

### Hardening
Proceso de asegurar un sistema reduciendo su superficie de ataque mediante configuración restrictiva.

### Host
Computadora o servidor conectado a una red.

### HTTPS
HTTP Secure, protocolo de comunicación cifrada para la web.

### Human-in-the-loop
Patrón de diseño donde se requiere aprobación humana para ciertas acciones críticas.

---

## I

### Identity Provider (IdP)
Servicio que autentica usuarios y proporciona información de identidad (Google, GitHub, etc.).

### Input Validation
Proceso de verificar que los datos de entrada cumplen con criterios esperados antes de procesarlos.

---

## J

### JIT (Just-In-Time) Compilation
Técnica donde el código se compila durante la ejecución, usada por Node.js (V8).

---

## K

### KEX (Key Exchange)
Algoritmo usado para intercambiar claves de cifrado de forma segura entre dos partes.

### Key Rotation
Práctica de reemplazar periódicamente claves y credenciales por nuevas.

---

## L

### LLM (Large Language Model)
Modelo de inteligencia artificial entrenado en grandes cantidades de texto, capaz de generar y entender lenguaje natural.

### Localhost
Dirección de red (127.0.0.1) que se refiere al propio dispositivo.

### LogLevel
Configuración que determina cuánto detalle se registra en los logs (ERROR, WARN, INFO, DEBUG, VERBOSE).

### LTS (Long Term Support)
Versión de software con soporte extendido, típicamente 5 años para Ubuntu.

---

## M

### MAC (Message Authentication Code)
Código que verifica tanto la integridad como la autenticidad de un mensaje.

### MCP (Model Context Protocol)
Protocolo estándar desarrollado por Anthropic que permite a los agentes AI conectarse e interactuar con herramientas y servicios externos de forma estandarizada. OpenClaw usa MCP para integrarse con 100+ servicios.

### MFA/2FA (Multi-Factor Authentication)
Autenticación que requiere múltiples formas de verificación (algo que sabes + algo que tienes).

### Mesh VPN
Red VPN donde todos los dispositivos pueden comunicarse directamente entre sí.

---

## N

### NAT (Network Address Translation)
Técnica que permite a múltiples dispositivos compartir una dirección IP pública.

### Node.js
Entorno de ejecución de JavaScript en el servidor.

### nvm (Node Version Manager)
Herramienta para instalar y gestionar múltiples versiones de Node.js.

---

## O

### Output Filtering
Proceso de revisar y sanitizar las salidas de un sistema antes de mostrarlas al usuario.

### OpenClaw
Framework open-source para ejecutar agentes de IA con acceso a herramientas (filesystem, git, APIs, shell). A diferencia de chatbots tradicionales, OpenClaw puede actuar en el sistema ejecutando comandos y modificando archivos.

### OWASP (Open Web Application Security Project)
Organización que publica estándares y guías de seguridad para aplicaciones.

---

## P

### Passphrase
Contraseña larga, típicamente una frase, usada para proteger claves criptográficas.

### Peer-to-peer (P2P)
Arquitectura de red donde los dispositivos se comunican directamente sin servidor central.

### PII (Personally Identifiable Information)
Información que puede identificar a una persona específica.

### Port Forwarding
Técnica para redirigir tráfico de red de un puerto a otro.

### Prompt Injection
Ataque donde se manipula el prompt de un LLM para alterar su comportamiento.

### Protocol
Conjunto de reglas que define cómo se comunican los sistemas.

---

## R

### Rate Limiting
Control que limita la frecuencia de operaciones para prevenir abuso.

### Redaction
Proceso de ocultar información sensible reemplazándola con marcadores.

### Root
Usuario administrador en sistemas Unix/Linux con acceso total al sistema.

---

## S

### Sandboxing
Técnica de aislamiento que restringe el acceso de un programa a recursos del sistema.

### Secrets
Información confidencial como contraseñas, API keys, tokens, etc.

### Shell
Interfaz de línea de comandos del sistema operativo (bash, zsh, etc.).

### Skills
Capacidades o herramientas que un agente AI puede utilizar para interactuar con su entorno. En OpenClaw, las skills incluyen acceso a filesystem, git, HTTP client, shell, etc. Se configuran mediante allowlists para limitar qué acciones puede realizar el agente.

### Soul (configuración)
Archivo de configuración (típicamente soul.yaml) que define la identidad, personalidad y límites de comportamiento de un agente AI. Establece restricciones como qué acciones están prohibidas y cómo debe responder el agente.

### SSH (Secure Shell)
Protocolo criptográfico para acceso remoto seguro a sistemas.

### Sudo
Comando que permite ejecutar acciones con privilegios de administrador.

### Systemd
Sistema de inicio y gestión de servicios en Linux moderno.

### Syscall
Llamada al sistema, la interfaz entre aplicaciones y el kernel del sistema operativo.

---

## T

### Tag (Tailscale)
Etiqueta que agrupa dispositivos en Tailscale para aplicar ACLs.

### Tailnet
Red privada creada por Tailscale que conecta tus dispositivos.

### Tailscale
Servicio de VPN mesh basado en WireGuard que crea redes privadas.

### Token
Cadena de caracteres que representa credenciales o autorización.

---

## U

### UFW (Uncomplicated Firewall)
Interfaz simplificada para gestionar iptables en Ubuntu.

### Unattended Upgrades
Sistema de Ubuntu para aplicar actualizaciones de seguridad automáticamente.

---

## V

### VPN (Virtual Private Network)
Red privada que extiende una red local a través de Internet de forma segura.

### VPS (Virtual Private Server)
Servidor virtual alojado en infraestructura compartida pero con recursos dedicados.

---

## W

### WireGuard
Protocolo VPN moderno, rápido y seguro. Base de Tailscale.

### Workspace
Directorio de trabajo donde el agente AI puede operar.

---

## Y

### YAML
Formato de serialización de datos legible por humanos, usado para configuración.

---

## Z

### Zero-trust
Modelo de seguridad que no confía en ninguna entidad por defecto, requiriendo verificación continua.

---

## Acrónimos frecuentes

| Acrónimo | Significado |
|----------|-------------|
| API | Application Programming Interface |
| CIS | Center for Internet Security |
| CPU | Central Processing Unit |
| DNS | Domain Name System |
| E2E | End-to-End (cifrado de extremo a extremo) |
| GB | Gigabyte |
| HTTP | Hypertext Transfer Protocol |
| IP | Internet Protocol |
| JSON | JavaScript Object Notation |
| LLM | Large Language Model |
| MAC | Message Authentication Code |
| MFA | Multi-Factor Authentication |
| NIM | NVIDIA Inference Microservices |
| OS | Operating System |
| OWASP | Open Web Application Security Project |
| RAM | Random Access Memory |
| SSH | Secure Shell |
| SSL/TLS | Secure Sockets Layer / Transport Layer Security |
| URL | Uniform Resource Locator |
| VPN | Virtual Private Network |
| VPS | Virtual Private Server |
