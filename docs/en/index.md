# OpenClaw on VPS

A guide to install and run **OpenClaw** in a **private, isolated, and secure** manner on a VPS.

---

## What is OpenClaw?

[OpenClaw](https://github.com/openclaw/openclaw) is an open-source personal AI assistant that you can run on your own devices. Unlike traditional chatbots, OpenClaw is an **autonomous agent** that can execute shell commands, manage files, automate browsers, and connect to multiple channels (WhatsApp, Telegram, Slack, Discord, etc.).

!!! info "About OpenClaw"
    OpenClaw (formerly Clawdbot/Moltbot) reached 100k+ stars on GitHub in 2026, becoming one of the fastest-growing projects. It uses the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/) to integrate with 100+ external services.

!!! warning "Fundamental principle"
    **OpenClaw is not exposed publicly.** It must be isolated, restricted, and accessed only through a private network. A misconfigured agent with tool access is a serious security risk.

---

## Who is this guide for?

- **Developers** who want an AI agent to automate technical tasks
- **Freelancers and small businesses** who need assistance with documents and organization
- **Technical users** who value privacy and control over their tools

---

## Knowledge requirements

| Concept | Required level | Where to learn |
|---------|----------------|----------------|
| Terminal/Bash | Basic | [LinuxCommand.org](https://linuxcommand.org/) |
| SSH | Basic | Section 3 of this guide |
| Networking (IP, ports) | Conceptual | [DigitalOcean - Understanding IP](https://www.digitalocean.com/community/tutorials/understanding-ip-addresses-subnets-and-cidr-notation-for-networking) |
| VPN | Conceptual | Explained in section 4 |
| YAML/JSON | Basic | For configuration files |

---

## Estimated time

| Section | Time | Level |
|---------|------|-------|
| 1. Preparation | 15-20 min | Beginner |
| 2. Provision VPS | 10-15 min | Beginner |
| 3. System security | 30-40 min | Intermediate |
| 4. Private access | 20-30 min | Intermediate |
| 5. Install OpenClaw | 25-35 min | Intermediate |
| 6. LLM APIs | 10-15 min | Beginner |
| 7. Use cases | 15-20 min | Intermediate |
| 8. Agent security | 30-45 min | Advanced |
| 9. Maintenance | Reference | Intermediate |
| 10. Final checklist | 10 min | - |
| **Total** | **~3 hours** | |

---

## What will you achieve?

A private server with OpenClaw that:

- **Is not exposed to the Internet** — zero public ports
- **Is only accessible via VPN** (Tailscale)
- **Runs with minimal privileges** — dedicated user, no root
- **Has limited permissions** — only accesses what you configure
- **Complies with security standards** — CIS Benchmark, OWASP Agentic Top 10

---

## Target architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      INTERNET                               │
│                         ❌                                  │
│              (No open ports)                                │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                       YOUR VPS                              │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Ubuntu 24.04 LTS                                     │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Layer 1: UFW Firewall (deny all incoming)      │  │  │
│  │  │  ┌─────────────────────────────────────────┐    │  │  │
│  │  │  │  Layer 2: Tailscale VPN                 │    │  │  │
│  │  │  │  └─> SSH only via Tailscale IP          │    │  │  │
│  │  │  │  └─> Zero-trust ACLs                    │    │  │  │
│  │  │  │  ┌─────────────────────────────────┐    │    │  │  │
│  │  │  │  │  Layer 3: Systemd Sandboxing    │    │    │  │  │
│  │  │  │  │  └─> OpenClaw on localhost      │    │    │  │  │
│  │  │  │  │  └─> ProtectSystem=strict       │    │    │  │  │
│  │  │  │  │  └─> Skills with allowlist      │    │    │  │  │
│  │  │  │  └─────────────────────────────────┘    │    │  │  │
│  │  │  └─────────────────────────────────────────┘    │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  │  User: openclaw (non-root)                            │  │
│  │  Auditd + AIDE for monitoring                         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
          ▲
          │ Tailscale VPN (WireGuard encryption)
          │ Only owner can connect (ACLs)
          ▼
┌─────────────────────────────────────────────────────────────┐
│              YOUR DEVICE                                    │
│  (laptop, mobile — also with Tailscale)                     │
│  SSH + Port forwarding to access OpenClaw                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Estimated cost

| Item | Monthly price |
|------|---------------|
| VPS (4-8GB RAM, 2 vCPU) | $4-12/month |
| Tailscale (free tier) | $0 |
| LLM API | $0-80/month |
| **Total** | **~$4-90/month** |

!!! tip "Free option"
    Using Kimi K2.5 on NVIDIA NIM (free) + budget VPS (~$5), you can have OpenClaw running for less than $5/month.

---

## Security standards covered

| Standard | Coverage | Sections |
|----------|----------|----------|
| **CIS Benchmark Ubuntu 24.04 L1** | 100% (SSH + kernel hardening) | 3 |
| **Tailscale Security Hardening** | 100% | 4 |
| **OWASP Agentic Top 10 2026** | 90%+ | 5, 7, 8 |
| **Systemd Hardening** | Complete | 5 |

---

## AI agent security risks

!!! danger "AI agents with tools are dangerous if misconfigured"

According to [security research](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare):

| Risk | Description | Mitigation in this guide |
|------|-------------|--------------------------|
| **API key leakage** | Agent can expose credentials | `.env` with chmod 600, output filtering |
| **Prompt injection** | Malicious inputs manipulate the agent | Input validation, guardrails |
| **Vulnerable skills** | 26% of skills have vulnerabilities | Strict allowlist, code review |
| **Excessive access** | Filesystem/shell without limits | Least privilege, specific paths |

---

## What NOT to do

!!! danger "Critical mistakes"
    - ❌ Run OpenClaw as root
    - ❌ Open ports "just to test"
    - ❌ Use passwords for SSH
    - ❌ Give full filesystem access
    - ❌ Install it on your personal work machine
    - ❌ Install skills without reviewing their code
    - ❌ Use `curl | bash` without verifying the script
    - ❌ Leave Tailscale ACLs on "permit all"

---

## What this guide does NOT cover

- High availability (HA) or clustering
- Automated cloud backups (manual only)
- CI/CD for automatic deployment
- Multiple agents communicating with each other
- Kubernetes integration
- Enterprise production use (requires additional auditing)

---

## Guide structure

| # | Section | Description |
|---|---------|-------------|
| 1 | **[Preparation](01-preparation.md)** | Accounts, SSH keys, spending limits |
| 2 | **[Provision VPS](02-vps.md)** | Providers, image verification |
| 3 | **[System security](03-system-security.md)** | User, SSH hardening CIS, firewall, auditd |
| 4 | **[Private access](04-private-access.md)** | Tailscale, ACLs, remove public SSH |
| 5 | **[Install OpenClaw](05-openclaw.md)** | Node.js, configuration, systemd hardening |
| 6 | **[LLM APIs](06-llm-apis.md)** | Configuration, limits, rotation |
| 7 | **[Use cases](07-use-cases.md)** | Practical examples, output filtering |
| 8 | **[Agent security](08-agent-security.md)** | OWASP Agentic, guardrails, AppArmor |
| 9 | **[Maintenance](09-maintenance.md)** | Updates, rotation, backups, DR |
| 10 | **[Final checklist](10-final-checklist.md)** | Verification of all controls |
| - | **[Glossary](glossary.md)** | Term definitions |

---

## References

- [OpenClaw - Official Documentation](https://docs.openclaw.ai/)
- [OpenClaw - Security](https://docs.openclaw.ai/gateway/security)
- [CIS Ubuntu Linux 24.04 LTS Benchmark](https://www.cisecurity.org/benchmark/ubuntu_linux)
- [Tailscale Security Hardening](https://tailscale.com/kb/1196/security-hardening)
- [OWASP Top 10 for Agentic Applications 2026](https://genai.owasp.org/resource/owasp-top-10-for-agentic-applications-for-2026/)
- [OWASP Top 10 for LLM Applications 2025](https://genai.owasp.org/resource/owasp-top-10-for-llm-applications-2025/)
- [systemd Hardening](https://www.freedesktop.org/software/systemd/man/systemd.exec.html#Sandboxing)
- [Cisco - AI Agent Security Risks](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare)

---

## Get started

**Next:** [1. Preparation](01-preparation.md) — What you need before starting.
