# OpenClaw VPS Hardening Guide

[![Documentation](https://img.shields.io/badge/docs-live-brightgreen)](https://corbat-tech.github.io/corbat-openclaw-hardening/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Languages](https://img.shields.io/badge/languages-EN%20%7C%20ES-orange)](#documentation)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-v2026.3.x-blue)](#whats-covered)

Complete security guide for deploying [OpenClaw](https://openclaw.ai) AI agents on a VPS with enterprise-grade hardening. Updated for OpenClaw v2026.3.x with post-ClawHub incident security measures.

## Documentation

**[Read in English](https://corbat-tech.github.io/corbat-openclaw-hardening/)** | **[Leer en Español](https://corbat-tech.github.io/corbat-openclaw-hardening/es/)**

## Security Standards Implemented

| Standard | Coverage |
|----------|----------|
| **CIS Benchmark Ubuntu 24.04 L1** | SSH hardening (incl. post-quantum KEX), sysctl, file permissions |
| **Tailscale Security Hardening** | ACLs, tags, MagicDNS, Tailnet Lock |
| **OWASP Agentic Top 10 2026** | AA1-AA10 mitigations |
| **NIST AI Agent Standards Initiative** | Identity, isolation, auditability, human control |
| **Systemd Sandboxing** | ProtectSystem, NoNewPrivileges, CapabilityBoundingSet |

## What's Covered

1. **Preparation** - Requirements, SSH keys, spending limits
2. **VPS Provisioning** - Hetzner (primary), cloud firewall, cloud-init
3. **System Security** - SSH hardening (CIS + post-quantum), UFW, Fail2Ban/CrowdSec, auditd, AIDE
4. **Private Access** - Tailscale VPN, zero-trust ACLs, removing public SSH
5. **OpenClaw Installation** - v2026.3.x, SecretRef, systemd hardening, Gateway TLS pairing, `openclaw security audit`
6. **LLM APIs** - Provider comparison, spending limits, SecretRef credential management
7. **Use Cases** - Business/CRM, programming agents, research, personal assistant, DevOps monitoring
8. **Agent Security** - OWASP Agentic, ClawHub/ClawJacked mitigations, input/output filtering
9. **Maintenance** - Updates, Livepatch, key rotation, backups, disaster recovery
10. **Final Checklist** - Complete security verification with automated script

## Key Security Features (v2)

- **ClawHub supply chain protection** - Guidance on auditing skills after the 1,184+ malicious skills incident
- **Post-quantum SSH** - `sntrup761x25519-sha512` key exchange algorithm
- **SecretRef** - Native encrypted credential management (replaces plaintext .env)
- **Gateway TLS pairing** - Protection against ClawJacked WebSocket hijacking
- **Systemd sandboxing** - ProtectSystem, NoNewPrivileges, CapabilityBoundingSet, ReadWritePaths
- **Double-layer firewall** - Hetzner Cloud Firewall (perimeter) + UFW (host)
- **CrowdSec option** - Community threat intelligence as Fail2Ban alternative
- **Canonical Livepatch** - Kernel patches without reboot
- **Operational security advice** - Dedicated accounts, never connect personal email

## For AI Agents (Claude Code, etc.)

This repository is designed to be used with an AI coding agent. Clone it on your VPS and ask the agent to guide you through the setup:

```
"Let's configure this VPS to install OpenClaw step by step, following this guide"
```

The agent will use:

- **`CLAUDE.md`** — Configuration facts, gotchas, and verified settings for v2026.3.x
- **`AGENTS.md`** — Self-configuration checklist for the deployed OpenClaw agent
- **`docs/en/`** — Full 10-section guide (sections 1-7: installation, 8-10: advanced security)
- **`scripts/`** — Automated scripts for hardening (`harden.sh`) and installation (`install-openclaw.sh`)

### Automated deployment (recommended)

```bash
# On the VPS as root:
curl -fsSL -o /tmp/harden.sh \
  https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/harden.sh
bash /tmp/harden.sh          # Sections 3-4: SSH hardening + Tailscale

# Reconnect via Tailscale, then as openclaw user:
curl -fsSL -o /tmp/install-openclaw.sh \
  https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/install-openclaw.sh
bash /tmp/install-openclaw.sh  # Section 5: OpenClaw + systemd
```

### Manual deployment (with agent assistance)

Clone this repo on your local machine, open it with Claude Code, and follow the guide section by section. The agent can read the docs, adapt commands to your setup, and troubleshoot in real time.

## Quick Start (local docs)

```bash
git clone https://github.com/corbat-tech/corbat-openclaw-hardening.git
pip install -r requirements.txt
mkdocs serve
# Open http://localhost:8000
```

## Verification Script

```bash
# Run the automated security verification on the VPS
./scripts/verify-hardening.sh
```

## Project Structure

```
├── CLAUDE.md            # AI agent context (config facts, gotchas)
├── AGENTS.md            # Self-configuration guide for deployed agents
├── docs/
│   ├── en/              # English documentation (10 sections)
│   └── es/              # Spanish documentation (mirror)
├── scripts/
│   ├── harden.sh        # System hardening (sections 3-4)
│   ├── install-openclaw.sh  # OpenClaw installation (section 5)
│   ├── setup.sh         # Full setup (sections 3-5)
│   └── verify-hardening.sh  # Security verification
├── mkdocs.yml           # MkDocs configuration
├── AUDIT_LOG.md         # Quality audit history
└── AUDIT_PROMPT.md      # Audit methodology
```

## Contributing

Contributions are welcome! Please ensure any changes maintain compatibility with the security standards referenced.

## License

MIT License - See [LICENSE](LICENSE) for details.

---

Made with security in mind by [CORBAT](https://github.com/corbat-tech)
