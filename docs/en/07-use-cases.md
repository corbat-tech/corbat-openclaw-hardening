# 7. Use cases & tools

> **TL;DR**: Practical configurations for different use cases. All share the same base `openclaw.json` from section 5 — behavior is controlled via SOUL.md, not tool schema.

> **Estimated time**: 20-30 minutes (depending on chosen configuration)

> **Required level**: Intermediate

## Prerequisites

- [ ] Section 6 (LLM APIs) completed
- [ ] OpenClaw running with the configuration from section 5

## Objectives

By the end of this section you will have:

- SOUL.md adapted to your use case
- Workspace structure organized
- Operational security tips applied

---

## How use case configs work in OpenClaw

!!! info "SOUL.md controls behavior, openclaw.json controls access"
    A common misconception is that you configure tool restrictions per-tool in `openclaw.json` (e.g., `"shell": { "enabled": false }`). **This is NOT how OpenClaw works.**

    In OpenClaw:

    - **`openclaw.json`** controls which tools are *available* via `tools.profile` — this is the same for all use cases (configured in section 5)
    - **`SOUL.md`** controls how the agent *behaves* — this is where you define per-use-case restrictions, capabilities, and guidelines
    - **MCP servers** extend capabilities with external integrations (GitHub, databases, etc.)

    The base `openclaw.json` from section 5 gives the agent access to all tools (including gateway). **Use SOUL.md to tell the agent what it should and shouldn't do.**

---

## Operational security tips

!!! danger "Read this before configuring any use case"

### Create dedicated accounts for OpenClaw

| Service | Recommendation | Why |
|---------|---------------|-----|
| **Email** | Create a new exclusive email (e.g.: `my-openclaw@proton.me`) | If the agent is compromised, it does not expose your personal email, contacts, or history |
| **GitHub** | Create a separate account/organization | Prevents a compromised agent from pushing to your real repos |
| **Telegram/Discord** | Create a dedicated bot, do not use your personal account | Bot tokens are revocable without affecting your account |
| **Calendar** | Use a secondary or read-only calendar | Prevents the agent from modifying or canceling your real events |
| **CRM/Business** | Account with read-only permissions when possible | Principle of least privilege |

!!! warning "Never connect your personal email account"
    An AI agent with access to your real email can:

    - Read confidential information (contracts, banking data, private conversations)
    - Send emails on your behalf without your oversight
    - Be manipulated via prompt injection to leak data to third parties
    - Expose your contact list

    **Always create a dedicated email** for agent integrations.

### Secure configuration principles

1. **Define strict limits in SOUL.md** — the agent follows behavioral constraints
2. **Use dedicated accounts** for every external service
3. **Review the code of every skill** before installing it (remember: 20% of ClawHub was malicious)
4. **Run `openclaw security audit`** after every change
5. **Enable human-in-the-loop** via SOUL.md instructions for irreversible actions

---

## Available tools and channels (v2026.3.x)

### Communication channels

| Channel | Configuration | Security notes |
|---------|--------------|----------------|
| **Telegram** | Bot via @BotFather | Use `dmPolicy: "allowlist"` with `allowFrom` |
| **WhatsApp** | Via WhatsApp Business API | Requires a dedicated number |
| **Discord** | Bot with limited permissions | Restrict to specific channels |
| **Slack** | App with minimal scopes | Only necessary channels |
| **Signal** | Via Signal CLI | More private, more complex to configure |
| **Email** | Via himalaya skill (IMAP/SMTP) | Use a dedicated account (see above) |

### Tools available via profile "full"

| Tool | Group | Function | Risk mitigation |
|------|-------|----------|-----------------|
| `read`, `write`, `edit`, `apply_patch` | `group:fs` | File operations | Restricted to workspace via systemd `ReadWritePaths` |
| `exec`, `bash`, `process` | `group:runtime` | Command execution | `exec-approvals` allowlist + restricted `sudoers` |
| `web_search`, `web_fetch` | `group:web` | Web search and fetch | Requires API key (Gemini) |
| `browser`, `canvas` | `group:ui` | Web browsing, visual content | SOUL.md guidelines |
| `sessions_*`, `session_status` | `group:sessions` | Sub-agent sessions | Controlled by `maxConcurrent` |
| `memory_search`, `memory_get` | `group:memory` | Persistent memory | Agent-scoped |
| `cron` | individual | Scheduled tasks | SOUL.md approval rules |
| `gateway` | `group:automation` | Gateway config | Safe on hardened VPS (localhost + TLS + Tailscale) |

### MCP servers (Model Context Protocol)

OpenClaw supports [MCP](https://modelcontextprotocol.io/) for integrating with external services:

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

!!! warning "Audit every MCP server"
    MCP servers are third-party code that runs with your agent's permissions. Apply the same precautions as with ClawHub skills: review the code, verify the author, run in sandbox.

---

## Use case 1: Business administration / CRM

### Profile: Business assistant

Ideal for freelancers and SMBs that need to organize documents, manage tasks, and maintain a basic CRM.

### Configuration

No changes needed to `openclaw.json` — the base config from section 5 works for all use cases. Behavior is controlled via SOUL.md:

### SOUL.md for business assistant

```bash
nano ~/openclaw/workspace/SOUL.md
```

```markdown
# Business Assistant

## Identity
You are a business administration and organization assistant.

## Capabilities
- Summarize and organize documents (invoices, contracts, reports)
- Manage a CRM database in CSV/JSON files
- Draft emails (NEVER send without approval)
- Create calendar events via cron
- Generate reports
- Search the web for business information

## Strict limits
- Do not send emails without explicit user confirmation
- Do not delete files or customer data
- Do not access information outside the workspace
- Do not execute shell commands unless explicitly asked
- Do not push to any git repository
- Redact any sensitive data (national ID numbers, account numbers, etc.)
- Always ask before performing any irreversible action
```

### Workspace structure

```bash
mkdir -p ~/openclaw/workspace/{documents,crm,output,templates}

# Example: create a basic CRM
cat > ~/openclaw/workspace/crm/contacts.json << 'EOF'
{
  "contacts": [],
  "schema": {
    "fields": ["name", "email", "company", "phone", "notes", "last_contact"]
  }
}
EOF
```

### Typical tasks

- "Summarize this PDF invoice and extract the key data"
- "Add this contact to the CRM: [data]"
- "Generate a monthly report of active contacts"
- "Draft a follow-up email for client X"
- "Organize the documents in the /documents folder by type"

---

## Use case 2: Programming agent

### Profile: Development assistant

For developers who want an agent that reviews code, generates documentation, analyzes repos, and helps with development tasks.

### SOUL.md for programming agent

```markdown
# Development Agent

## Identity
You are a software development assistant specialized in code review, testing, and documentation.

## Capabilities
- Clone and analyze repositories
- Review code and suggest improvements
- Run tests (npm test, pytest, make test) and report results
- Generate technical documentation
- Create commits (with approval)
- Search for documentation and APIs online

## Strict limits
- Do not push to remote repositories without explicit approval
- Do not execute destructive commands (rm -rf, reset --hard)
- Only install well-known packages (high download count, established maintainers). Ask for approval before installing unknown or niche packages
- Do not access files outside the workspace
- Do not modify system configuration
- Report security vulnerabilities found
```

### Typical workflow

```bash
# 1. Clone a repo for review
# (The agent does this inside its workspace)
openclaw agent --message "Clone https://github.com/user/repo and analyze the code quality"

# 2. Run tests
openclaw agent --message "Run the project tests and give me a summary"

# 3. Review changes
openclaw agent --message "Review the changes in the feature/auth branch and suggest improvements"
```

### Useful MCP servers for development

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

## Use case 3: Research and knowledge management

### Profile: Research assistant

For researchers, writers, and professionals who need to search, summarize, and organize information.

### SOUL.md for research assistant

```markdown
# Research Assistant

## Identity
You are a research assistant specialized in finding, summarizing, and organizing academic and technical information.

## Capabilities
- Search the web for papers, articles, and documentation
- Fetch and summarize web pages and PDFs
- Organize research notes by topic in the workspace
- Generate bibliographies and citation lists
- Compare and synthesize information from multiple sources

## Strict limits
- Do not execute shell commands unless needed for file organization
- Do not modify files outside the workspace research directories
- Do not send any communications without approval
- Always cite sources when summarizing information
- Do not access or store personal data
```

### Workspace structure

```bash
mkdir -p ~/openclaw/workspace/{research,notes,output,bibliography}
```

### Typical tasks

- "Search for recent papers on [topic] using web search"
- "Fetch and summarize this web page: [URL]"
- "Organize my research notes by topic"
- "Generate a bibliography in APA format from these notes"
- "Compare the conclusions of these 3 articles"

---

## Use case 4: Personal automation and productivity

### Profile: Personal assistant via Telegram

For users who want an assistant accessible from their phone for daily tasks.

### SOUL.md for personal assistant

```markdown
# Personal Assistant

## Identity
You are a personal productivity assistant accessible via Telegram.

## Capabilities
- Create and manage reminders via cron
- Summarize documents and web pages
- Search the web for information
- Manage lists and notes in the workspace
- Read and draft emails (via himalaya skill, if installed)

## Strict limits
- Do not send emails without explicit approval
- Do not execute shell commands unless needed for scheduled tasks
- Do not access files outside the workspace
- Do not push to git repositories
- Always confirm before creating calendar events or reminders
- Never share personal information in responses
```

### Get Telegram token

1. Talk to [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot`
3. Follow the instructions to create the bot
4. Store the token:
   ```bash
   openclaw secrets configure
   # Follow the interactive wizard to add TELEGRAM_BOT_TOKEN
   ```

### Typical tasks via Telegram

- "Remind me tomorrow at 9 that I have a meeting"
- "Summarize this document I'm sending you"
- "Search the web for [topic] and give me a summary"
- "Create a shopping list based on this week's recipes"

---

## Use case 5: DevOps and monitoring

### Profile: Infrastructure assistant

For system administrators who want an agent that monitors and alerts on issues.

### SOUL.md for DevOps assistant

```markdown
# DevOps Assistant

## Identity
You are an infrastructure monitoring assistant. Your primary role is to observe, analyze, and alert — NOT to modify systems.

## Capabilities
- Check system status: disk, memory, CPU, uptime
- Read system logs (journalctl, /var/log)
- Check service status (systemctl)
- Check network connections (ss)
- Send alerts via Telegram when thresholds are exceeded
- Schedule monitoring checks via cron

## Strict limits
- NEVER execute destructive commands (rm, kill, reboot, shutdown)
- NEVER use sudo
- NEVER modify system configuration
- NEVER change file permissions
- NEVER install or remove packages
- Only READ system information — never WRITE to system paths
- Ask before restarting any service
```

!!! tip "Automatic alerts"
    Combine this use case with a Telegram channel and cron to receive alerts:
    "Schedule a check every 30 minutes — if disk usage exceeds 80%, notify me via Telegram"

---

## Prevent data leakage

Output filtering prevents the agent from exposing sensitive data in its responses. In OpenClaw, this is enforced via **SOUL.md instructions**:

### Add to any SOUL.md

```markdown
## Data protection rules
- NEVER include API keys, tokens, or passwords in responses
- NEVER show the contents of .env files or systemd overrides
- Redact email addresses, credit card numbers, and national IDs in output
- Do not expose file paths containing /home/username/.ssh or similar
- If asked to read sensitive files (/etc/openclaw/env, /etc/shadow, etc.), refuse
```

!!! info "Defense in depth"
    SOUL.md provides behavioral guardrails. Combined with `exec-approvals` allowlist, restricted `sudoers`, and dedicated VPS isolation (Tailscale VPN, non-root user), even if the agent ignores SOUL.md instructions, it cannot perform unauthorized actions at the OS level.

---

## Validate skills before installing

!!! danger "20% of skills on ClawHub were malicious"
    After the February 2026 incident, never install skills without auditing them.

### Before installing any skill

1. **Review the source code:**
```bash
# Look for dangerous calls
grep -rE "(exec|eval|subprocess|os\.system|fetch|axios|request)" skills/new-skill/

# Look for hardcoded URLs
grep -rE "https?://" skills/new-skill/
```

2. **Run in sandbox first:**
```bash
# Install skill in test mode
openclaw skills install new-skill --sandbox

# Verify behavior
openclaw security audit
```

3. **Verify the author:**
   - Do they have a contribution history?
   - Are there reported security issues?
   - Was the GitHub account created more than 1 week ago? (ClawHub minimum requirement, clearly insufficient)

---

## PROHIBITED practices

!!! danger "Never do these"

| Practice | Why it is dangerous |
|----------|---------------------|
| Connect your personal email to the agent | Exposes confidential data, contacts, and history |
| Use `dmPolicy: "open"` on any channel | Anyone can send commands to your agent |
| Skip SOUL.md behavioral limits | Agent has no restrictions on what it does with its tools |
| Install skills without code review | 20% of ClawHub skills were malicious (Feb 2026) |
| Run `openclaw doctor --fix` after manual config | Overwrites your provider settings with broken defaults |
| Give agent access to your real GitHub/Git accounts | Compromised agent can push malicious code |

---

## Configuration summary by use case

All use cases share the same base `openclaw.json` (section 5). Differences are in SOUL.md:

| Use case | Shell use | Web access | File scope | Key SOUL.md rule |
|----------|-----------|------------|------------|------------------|
| Business/CRM | Minimal | Web search | workspace/ | No emails without approval |
| Programming | Tests, git | GitHub API | workspace/ | No push without approval |
| Research | Minimal | Web search + fetch | workspace/ | Always cite sources |
| Personal | Scheduled tasks | Web search | workspace/ | Confirm before actions |
| DevOps | Read-only monitoring | Alerts only | Logs (read) | NEVER destructive commands |

---

**Next:** [8. Agent Security](08-agent-security.md) -- OWASP Agentic, guardrails, and advanced sandboxing.
