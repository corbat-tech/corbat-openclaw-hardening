# OpenClaw VPS Hardening Guide

[![Documentation](https://img.shields.io/badge/docs-live-brightgreen)](https://corbat.github.io/corbat-openclaw-hardening/)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Languages](https://img.shields.io/badge/languages-EN%20%7C%20ES-orange)](#documentation)
[![OpenClaw](https://img.shields.io/badge/OpenClaw-v2026.3.x-blue)](#whats-covered)

Complete security guide for deploying [OpenClaw](https://openclaw.ai) AI agents on a VPS with enterprise-grade hardening. Updated for OpenClaw v2026.3.x with post-ClawHub incident security measures.

## Documentation

**[Read in English](https://corbat.github.io/corbat-openclaw-hardening/)** | **[Leer en Español](https://corbat.github.io/corbat-openclaw-hardening/es/)**

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
5. **OpenClaw Installation** - v2026.3.x, SecretRef, sandbox "all", Gateway TLS pairing, `openclaw security audit`
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
- **Sandbox mode "all"** - Every tool execution containerized
- **Double-layer firewall** - Hetzner Cloud Firewall (perimeter) + UFW (host)
- **CrowdSec option** - Community threat intelligence as Fail2Ban alternative
- **Canonical Livepatch** - Kernel patches without reboot
- **Operational security advice** - Dedicated accounts, never connect personal email

## Quick Start

```bash
# Clone the repository
git clone https://github.com/corbat/corbat-openclaw-hardening.git

# Install dependencies
pip install -r requirements.txt

# Serve locally
mkdocs serve

# Open http://localhost:8000
```

## Verification Script

```bash
# Run the automated security verification
./scripts/verify-hardening.sh
```

## Project Structure

```
├── docs/
│   ├── en/              # English documentation
│   └── es/              # Spanish documentation
├── scripts/
│   └── verify-hardening.sh  # Automated security verification
├── mkdocs.yml           # MkDocs configuration
├── AUDIT_LOG.md         # Quality audit history
└── AUDIT_PROMPT.md      # Audit methodology
```

## Contributing

Contributions are welcome! Please ensure any changes maintain compatibility with the security standards referenced.

## License

MIT License - See [LICENSE](LICENSE) for details.

---

Made with security in mind by [CORBAT](https://github.com/corbat)
