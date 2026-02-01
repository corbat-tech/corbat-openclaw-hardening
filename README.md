# OpenClaw VPS Hardening Guide

[![Documentation](https://img.shields.io/badge/docs-live-brightgreen)](https://corbat.github.io/corbat-openclaw-hardening/)
[![Quality Score](https://img.shields.io/badge/quality-9.32%2F10-blue)](AUDIT_LOG.md)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)
[![Languages](https://img.shields.io/badge/languages-EN%20%7C%20ES-orange)](#documentation)

Complete security guide for deploying [OpenClaw](https://openclaw.ai) AI agents on a VPS with enterprise-grade hardening.

## Documentation

📖 **[Read in English](https://corbat.github.io/corbat-openclaw-hardening/)** | **[Leer en Español](https://corbat.github.io/corbat-openclaw-hardening/es/)**

## Security Standards Implemented

| Standard | Coverage |
|----------|----------|
| **CIS Benchmark Ubuntu 24.04 L1** | SSH hardening, sysctl, file permissions |
| **Tailscale Security Hardening** | ACLs, tags, MagicDNS, Tailnet Lock |
| **OWASP Agentic Top 10 2026** | AA1-AA10 mitigations |
| **Systemd Sandboxing** | ProtectSystem, NoNewPrivileges, CapabilityBoundingSet |

## What's Covered

1. **Preparation** - Requirements and planning
2. **VPS Provisioning** - Hetzner, DigitalOcean, Vultr setup
3. **System Security** - User creation, SSH hardening, firewall, fail2ban
4. **Private Access** - Tailscale VPN, removing public SSH
5. **OpenClaw Installation** - Node.js, systemd service with sandboxing
6. **LLM APIs** - Provider comparison, spending limits, key rotation
7. **Use Cases** - Configuration profiles for different scenarios
8. **Agent Security** - Input validation, output filtering, guardrails
9. **Maintenance** - Updates, backups, disaster recovery
10. **Final Checklist** - Complete security verification

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

## Project Structure

```
├── docs/
│   ├── en/          # English documentation
│   └── es/          # Spanish documentation
├── mkdocs.yml       # MkDocs configuration
├── AUDIT_LOG.md     # Quality audit history
└── AUDIT_PROMPT.md  # Audit methodology
```

## Quality Assurance

This guide has been audited for accuracy and completeness:

- **Score**: 9.32/10 (Final Version)
- **Audits**: 4 iterations with delta convergence
- **Standards**: CIS, Tailscale, OWASP Agentic verified

See [AUDIT_LOG.md](AUDIT_LOG.md) for detailed audit history.

## Contributing

Contributions are welcome! Please ensure any changes maintain compatibility with the security standards referenced.

## License

MIT License - See [LICENSE](LICENSE) for details.

---

Made with security in mind by [CORBAT](https://github.com/corbat)
