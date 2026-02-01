# Glossary

Definitions of technical terms used in this guide.

---

## A

### ACL (Access Control List)
List of rules that defines which entities can access which resources. In Tailscale, ACLs define which devices can communicate with each other.

### AI Agent
Software that uses artificial intelligence to perform tasks autonomously, making decisions based on its environment and objectives.

### AIDE (Advanced Intrusion Detection Environment)
Host-based intrusion detection system that monitors changes to system files.

### Allowlist
List of explicitly permitted elements. More secure than a denylist because it blocks everything except what's specified.

### API Key
Secret credential that identifies an application or user to an API service.

### AppArmor
Mandatory access control (MAC) system for Linux that restricts the capabilities of individual programs.

### Auditd
Linux audit daemon that records system security events.

---

## B

### Backup
Copy of important data to be able to recover it in case of loss.

### SSH Banner
Message displayed to users before SSH authentication, typically with legal warnings.

### Brute-force
Attack that attempts to guess credentials by systematically trying multiple combinations.

---

## C

### CIS Benchmark
Secure configuration guides published by the Center for Internet Security, recognized as an industry standard.

### Cipher
Cryptographic algorithm used to encrypt data. In SSH, it defines how communication is encrypted.

### CLI (Command Line Interface)
Command line interface, where the user interacts with the system through text.

---

## D

### Denylist
List of explicitly blocked elements. Less secure than an allowlist because it allows everything except what's specified.

### Disaster Recovery
Procedures to recover systems and data after a serious incident.

---

## E

### Ed25519
Modern digital signature algorithm used for SSH keys, more secure and efficient than RSA.

### Endpoint
Communication endpoint in a network, such as a device or service.

### Environment Variables (.env)
Environment variables stored in a file, typically used for sensitive configuration like API keys.

---

## F

### Fail2ban
Software that protects against brute-force attacks by banning IPs that show malicious behavior.

### Firewall
System that controls incoming and outgoing network traffic according to defined rules.

### Fingerprint
Unique identifier cryptographically derived from a key, used to verify its authenticity.

---

## G

### GPG (GNU Privacy Guard)
Encryption tool that implements the OpenPGP standard for data encryption and signing.

### Guardrails
Security restrictions that limit the behavior of a system or AI agent.

---

## H

### Hardening
Process of securing a system by reducing its attack surface through restrictive configuration.

### Host
Computer or server connected to a network.

### HTTPS
HTTP Secure, encrypted communication protocol for the web.

### Human-in-the-loop
Design pattern where human approval is required for certain critical actions.

---

## I

### Identity Provider (IdP)
Service that authenticates users and provides identity information (Google, GitHub, etc.).

### Input Validation
Process of verifying that input data meets expected criteria before processing it.

---

## J

### JIT (Just-In-Time) Compilation
Technique where code is compiled during execution, used by Node.js (V8).

---

## K

### KEX (Key Exchange)
Algorithm used to securely exchange encryption keys between two parties.

### Key Rotation
Practice of periodically replacing keys and credentials with new ones.

---

## L

### LLM (Large Language Model)
Artificial intelligence model trained on large amounts of text, capable of generating and understanding natural language.

### Localhost
Network address (127.0.0.1) that refers to the device itself.

### LogLevel
Configuration that determines how much detail is recorded in logs (ERROR, WARN, INFO, DEBUG, VERBOSE).

### LTS (Long Term Support)
Software version with extended support, typically 5 years for Ubuntu.

---

## M

### MAC (Message Authentication Code)
Code that verifies both the integrity and authenticity of a message.

### MCP (Model Context Protocol)
Standard protocol developed by Anthropic that allows AI agents to connect and interact with external tools and services in a standardized way. OpenClaw uses MCP to integrate with 100+ services.

### MFA/2FA (Multi-Factor Authentication)
Authentication that requires multiple forms of verification (something you know + something you have).

### Mesh VPN
VPN network where all devices can communicate directly with each other.

---

## N

### NAT (Network Address Translation)
Technique that allows multiple devices to share a public IP address.

### Node.js
JavaScript runtime environment on the server.

### nvm (Node Version Manager)
Tool to install and manage multiple Node.js versions.

---

## O

### Output Filtering
Process of reviewing and sanitizing system outputs before showing them to the user.

### OpenClaw
Open-source framework for running AI agents with tool access (filesystem, git, APIs, shell). Unlike traditional chatbots, OpenClaw can act on the system by executing commands and modifying files.

### OWASP (Open Web Application Security Project)
Organization that publishes security standards and guides for applications.

---

## P

### Passphrase
Long password, typically a phrase, used to protect cryptographic keys.

### Peer-to-peer (P2P)
Network architecture where devices communicate directly without a central server.

### PII (Personally Identifiable Information)
Information that can identify a specific person.

### Port Forwarding
Technique for redirecting network traffic from one port to another.

### Prompt Injection
Attack where an LLM's prompt is manipulated to alter its behavior.

### Protocol
Set of rules that defines how systems communicate.

---

## R

### Rate Limiting
Control that limits the frequency of operations to prevent abuse.

### Redaction
Process of hiding sensitive information by replacing it with markers.

### Root
Administrator user in Unix/Linux systems with total system access.

---

## S

### Sandboxing
Isolation technique that restricts a program's access to system resources.

### Secrets
Confidential information such as passwords, API keys, tokens, etc.

### Shell
Operating system command line interface (bash, zsh, etc.).

### Skills
Capabilities or tools that an AI agent can use to interact with its environment. In OpenClaw, skills include filesystem access, git, HTTP client, shell, etc. They are configured using allowlists to limit what actions the agent can perform.

### Soul (configuration)
Configuration file (typically soul.yaml) that defines the identity, personality, and behavior limits of an AI agent. It establishes restrictions such as which actions are prohibited and how the agent should respond.

### SSH (Secure Shell)
Cryptographic protocol for secure remote system access.

### Sudo
Command that allows executing actions with administrator privileges.

### Systemd
Init and service management system in modern Linux.

### Syscall
System call, the interface between applications and the operating system kernel.

---

## T

### Tag (Tailscale)
Label that groups devices in Tailscale to apply ACLs.

### Tailnet
Private network created by Tailscale that connects your devices.

### Tailscale
WireGuard-based mesh VPN service that creates private networks.

### Token
String of characters that represents credentials or authorization.

---

## U

### UFW (Uncomplicated Firewall)
Simplified interface for managing iptables on Ubuntu.

### Unattended Upgrades
Ubuntu system for applying security updates automatically.

---

## V

### VPN (Virtual Private Network)
Private network that securely extends a local network across the Internet.

### VPS (Virtual Private Server)
Virtual server hosted on shared infrastructure but with dedicated resources.

---

## W

### WireGuard
Modern, fast, and secure VPN protocol. Tailscale's foundation.

### Workspace
Working directory where the AI agent can operate.

---

## Y

### YAML
Human-readable data serialization format, used for configuration.

---

## Z

### Zero-trust
Security model that doesn't trust any entity by default, requiring continuous verification.

---

## Common acronyms

| Acronym | Meaning |
|---------|---------|
| API | Application Programming Interface |
| CIS | Center for Internet Security |
| CPU | Central Processing Unit |
| DNS | Domain Name System |
| E2E | End-to-End (end-to-end encryption) |
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
