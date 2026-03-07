# 7. Use cases & tools

> **TL;DR**: Practical configurations for different use cases, recommended tools, operational security tips, and guidance for getting the most out of OpenClaw once installed.

> **Estimated time**: 20-30 minutes (depending on chosen configuration)

> **Required level**: Intermediate

## Prerequisites

- [ ] Section 6 (LLM APIs) completed
- [ ] OpenClaw running with sandbox mode `"all"`

## Objectives

By the end of this section you will have:

- Configuration adapted to your use case
- Tools and channels configured
- Output filtering to prevent data leakage
- Operational security tips applied

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

1. **Start with everything disabled** -- enable only what you need
2. **Use allowlists, never denylists** as the only control
3. **Review the code of every skill** before installing it (remember: 20% of ClawHub was malicious)
4. **Run `openclaw security audit`** after every change
5. **Enable human-in-the-loop** for irreversible actions

---

## Available tools and channels (v2026.3.x)

### Communication channels

| Channel | Configuration | Security notes |
|---------|--------------|----------------|
| **Telegram** | Bot via @BotFather | Recommended: use `dmPolicy: "pairing"` |
| **WhatsApp** | Via WhatsApp Business API | Requires a dedicated number |
| **Discord** | Bot with limited permissions | Restrict to specific channels |
| **Slack** | App with minimal scopes | Only necessary channels |
| **Signal** | Via Signal CLI | More private, more complex to configure |
| **Email** | Via IMAP/SMTP | Use a dedicated account (see above) |

### Integrated tools

| Tool | Function | Risk | Recommendation |
|------|----------|------|----------------|
| `filesystem` | Read/write files | Medium | Restrict to workspace |
| `git` | Git operations | Medium | Read-only by default |
| `http_client` | HTTP requests | High | Strict domain allowlist |
| `browser` | Web browsing | Very high | Disabled by default |
| `shell` | Command execution | Very high | Disabled by default |
| `email` | Send/receive email | High | Dedicated account only |
| `calendar` | Calendar management | Medium | Read-only preferred |
| `pdf` | PDF analysis | Low | New in v2026.3.2 |

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
      "account": "my-openclaw@proton.me",
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

### SOUL.md for business assistant

```markdown
# Business Assistant

## Identity
You are a business administration and organization assistant.

## Capabilities
- Summarize and organize documents (invoices, contracts, reports)
- Manage a CRM database in CSV/JSON files
- Draft emails (NEVER send without approval)
- Create calendar events
- Generate reports

## Strict limits
- Do not send emails without explicit user confirmation
- Do not delete files or customer data
- Do not access information outside the workspace
- Do not make API calls not included in the allowlist
- Redact any sensitive data (national ID numbers, account numbers, etc.)
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

### Configuration

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

!!! warning "Shell enabled with restrictions"
    In this use case, shell is enabled but **strictly limited** to testing and linting commands. Every execution is containerized in a sandbox. Never enable `"allowed_commands": ["*"]`.

### SOUL.md for programming agent

```markdown
# Development Agent

## Identity
You are a software development assistant specialized in code review, testing, and documentation.

## Capabilities
- Clone and analyze repositories
- Review code and suggest improvements
- Run tests and report results
- Generate technical documentation
- Create commits (with approval)

## Strict limits
- Do not push to remote repositories
- Do not execute destructive commands (rm -rf, reset --hard)
- Do not install dependencies without approval
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

### Configuration

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

### Typical tasks

- "Search for recent papers on [topic] in Semantic Scholar"
- "Summarize this 50-page PDF and extract the key points"
- "Organize my research notes by topic"
- "Generate a bibliography in APA format from these papers"
- "Compare the conclusions of these 3 articles"

---

## Use case 4: Personal automation and productivity

### Profile: Personal assistant via Telegram/WhatsApp

For users who want an assistant accessible from their phone for daily tasks.

### Configuration

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

### Get Telegram token

1. Talk to [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot`
3. Follow the instructions to create the bot
4. Store the token with SecretRef:
   ```bash
   openclaw secrets set TELEGRAM_BOT_TOKEN
   ```

### Typical tasks via Telegram

- "Remind me tomorrow at 9 that I have a meeting"
- "Summarize this document I'm sending you"
- "What do I have on the calendar this week?"
- "Create a shopping list based on this week's recipes"

---

## Use case 5: DevOps and monitoring

### Profile: Infrastructure assistant

For system administrators who want an agent that monitors and alerts on issues.

### Configuration

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

!!! tip "Automatic alerts"
    Combine this use case with a Telegram channel to receive alerts:
    "If disk usage exceeds 80%, notify me via Telegram"

---

## Prevent data leakage (OWASP AA2)

Output filtering prevents the agent from exposing sensitive data in its responses. This configuration applies to **all use cases**.

### Configure output filtering

```yaml
# Add to config/settings.yaml (create if needed)
# This is an example configuration — adapt to your deployment

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

    # Personal data
    - name: "email"
      pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
      replacement: "[REDACTED_EMAIL]"

    - name: "credit_card"
      pattern: "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"
      replacement: "[REDACTED_CARD]"

    # Sensitive paths
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

## PROHIBITED configurations

!!! danger "Never use these configurations"

| Configuration | Why it is dangerous |
|---------------|---------------------|
| `"shell": { "enabled": true, "allowed_commands": ["*"] }` | Arbitrary command execution |
| `"filesystem": { "allowed_paths": ["/"] }` | Access to the entire system, including keys |
| `"http_client": { "allow_all_domains": true }` | Can leak data to any server |
| `"browser": { "use_real_profile": true }` | Access to your real sessions and cookies |
| `"dmPolicy": "open"` | Anyone can send commands to the agent |
| `"sandbox": { "mode": "off" }` | No isolation, full access to the host |

---

## Configuration summary by profile

| Profile | Shell | Filesystem | Git | HTTP | Email | Telegram |
|---------|-------|------------|-----|------|-------|----------|
| Business/CRM | - | workspace/ | - | CRM APIs | Drafts only | Optional |
| Programming | Limited | workspace/ | Read+commit | GitHub | - | - |
| Research | - | research/ | - | Paper APIs | - | - |
| Personal | - | workspace/ | - | Limited | - | Dedicated bot |
| DevOps | Read-only | logs/ | - | Telegram | - | Alerts |

---

**Next:** [8. Agent Security](08-agent-security.md) -- OWASP Agentic, guardrails, and advanced sandboxing.
