# 5. Install OpenClaw

> **TL;DR**: Install Node.js 22+, configure OpenClaw with the Gateway daemon, apply minimal permissions, and run as a systemd service with hardened isolation.

> **Estimated time**: 25-35 minutes

> **Required level**: Intermediate

!!! info "OpenClaw requirements"
    OpenClaw requires **Node.js 22 or higher**. This guide is updated for **OpenClaw v2026.3.x**.

    Refer to the [official documentation](https://docs.openclaw.ai/start/getting-started) for the most up-to-date instructions.

!!! danger "Security alert: ClawHub incident (February 2026)"
    In February 2026, the **largest supply chain attack against AI agent infrastructure** to date was discovered:

    - **1,184+ malicious skills** (~20% of the ClawHub registry) distributed malware (AMOS stealer) and reverse shells
    - Skills disguised as legitimate crypto/trading tools
    - Another vulnerability ("ClawJacked") allowed malicious websites to hijack local agents via WebSocket

    **Mandatory measures:**

    - **Never install skills without auditing the source code first**
    - Run new skills **always in sandbox** with minimal permissions
    - Use `openclaw security audit` after every skill installation
    - Verify the author and contribution history before trusting

    Sources: [The Hacker News](https://thehackernews.com/2026/02/researchers-find-341-malicious-clawhub.html), [Snyk - ToxicSkills](https://snyk.io/blog/toxicskills-malicious-ai-agent-skills-clawhub/)

## Prerequisites

- [ ] Section 4 (Tailscale) completed
- [ ] SSH access working only via Tailscale
- [ ] User `openclaw` with sudo

## Quick setup (automated script)

!!! tip "Skip the manual steps"
    If you completed sections 3-4 (or used `harden.sh`), you can automate section 5 with:

    ```bash
    curl -fsSL -o /tmp/install-openclaw.sh \
      https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/install-openclaw.sh
    less /tmp/install-openclaw.sh
    bash /tmp/install-openclaw.sh
    ```

    The script installs Node.js 22, OpenClaw, writes a hardened `openclaw.json`, creates the systemd service, and sets permissions. It will ask you to choose a model provider.

    **After the script completes:**

    1. Configure your API key: `openclaw models auth add`
    2. Start the service: `sudo systemctl start openclaw`
    3. Access from your Mac: `ssh -L 18789:127.0.0.1:18789 openclaw@<TAILSCALE_IP>`
    4. Open `http://localhost:18789` in your browser
    5. Run security audit: `openclaw security audit`

    Or use the **full setup script** to automate sections 3+4+5 in one go on a fresh VPS:
    ```bash
    curl -fsSL -o /tmp/setup.sh \
      https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/setup.sh
    less /tmp/setup.sh
    bash /tmp/setup.sh
    ```

    If you prefer to understand each step, continue with the manual instructions below.

---

## Objectives

By the end of this section you will have:

- Node.js 22+ installed from verified source
- OpenClaw installed with Gateway daemon
- Security configuration according to [official security documentation](https://docs.openclaw.ai/gateway/security)
- Systemd service with complete hardening
- Security verification of the deployment

---

## Connect to VPS

```bash
ssh openclaw@<YOUR_TAILSCALE_IP>
```

---

## Install base dependencies

```bash
# Git and basic tools
sudo apt install -y git curl wget gnupg

# Python (already comes with Ubuntu, but add pip and venv)
sudo apt install -y python3-pip python3-venv
```

---

## Install Node.js (with verification)

!!! warning "Don't use `curl | bash` without verifying"
    Always verify scripts before executing them.

### Option A: Using nvm (RECOMMENDED)

nvm (Node Version Manager) allows you to install and manage Node.js versions.

```bash
# 1. Download nvm script
curl -o /tmp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh

# 2. Verify the script (look for suspicious commands)
echo "First 50 lines of the script:"
head -50 /tmp/nvm-install.sh

# 3. Verify checksum (optional but recommended)
# Check the official checksum at: https://github.com/nvm-sh/nvm/releases
sha256sum /tmp/nvm-install.sh
```

!!! tip "Verify checksum on GitHub"
    For maximum security, compare the SHA256 checksum with the one published at
    [github.com/nvm-sh/nvm/releases](https://github.com/nvm-sh/nvm/releases)
    for the version you're installing.

```bash
# 4. If it looks correct, execute
bash /tmp/nvm-install.sh

# 5. Clean up
rm /tmp/nvm-install.sh

# 6. Reload shell
source ~/.bashrc
```

```bash
# 7. Install Node.js 22 (required by OpenClaw)
nvm install 22
nvm use 22
nvm alias default 22

# 8. Verify installation
node --version
npm --version
```

**Expected output:**
```
v22.x.x
10.x.x
```

!!! warning "Node.js 22 is mandatory"
    OpenClaw requires Node.js 22 or higher. Earlier versions (18, 20) **will not work**.

### Option B: NodeSource repository

```bash
# 1. Download setup script
curl -fsSL https://deb.nodesource.com/setup_lts.x -o /tmp/nodesource-setup.sh

# 2. Verify it only adds repos from nodesource.com
grep -E "^(curl|wget)" /tmp/nodesource-setup.sh
# Should only show URLs from nodesource.com or nodejs.org

# 3. Review the complete script
less /tmp/nodesource-setup.sh

# 4. If it looks safe, execute
sudo -E bash /tmp/nodesource-setup.sh
sudo apt install -y nodejs

# 5. Clean up
rm /tmp/nodesource-setup.sh

# 6. Verify
node --version
npm --version
```

---

## Create directory structure

```bash
mkdir -p ~/openclaw/{workspace,config,logs,scripts}
mkdir -p ~/.openclaw/workspace
cd ~/openclaw
```

!!! warning "Difference between ~/openclaw and ~/.openclaw"
    This guide uses **TWO different directories**. It's important to understand the difference:

    | Directory | Full path | Purpose |
    |-----------|-----------|---------|
    | `~/.openclaw/` | `/home/openclaw/.openclaw/` | **Official OpenClaw configuration** (created automatically by the CLI) |
    | `~/openclaw/` | `/home/openclaw/openclaw/` | **Working directory for this guide** (scripts, logs, secure workspace) |

!!! info "Detailed directory structure"

    ```
    ~/.openclaw/                 # OFFICIAL CONFIGURATION (created by OpenClaw)
    ├── openclaw.json            # Main Gateway configuration
    ├── .env                     # Environment variables (API keys) - chmod 600
    ├── workspace/               # Default OpenClaw workspace
    │   ├── AGENTS.md            # Agent prompts
    │   ├── SOUL.md              # Agent identity
    │   ├── TOOLS.md             # Tools configuration
    │   └── skills/              # Workspace-scoped skills
    └── credentials/             # OAuth credentials (if used)

    ~/.agents/
    └── skills/                  # Globally installed skills (npx playbooks add)
        └── imap-smtp-email/     # Example: email skill
            ├── SKILL.md
            └── .env             # Skill credentials (chmod 600)

    ~/openclaw/                  # THIS GUIDE'S DIRECTORY (created manually)
    ├── workspace/               # RESTRICTED workspace (used in openclaw.json)
    ├── logs/                    # Application logs
    └── scripts/                 # Maintenance and verification scripts
    ```

!!! tip "Why two directories?"
    - `~/.openclaw/` is where OpenClaw looks for its configuration by default
    - `~/openclaw/workspace/` is a more restricted workspace that we configure in `openclaw.json`
    - This separation allows OpenClaw to function normally while maintaining control over where the agent can write

### Verify structure

```bash
tree ~/openclaw 2>/dev/null || ls -la ~/openclaw
```

**Expected output:**
```
/home/openclaw/openclaw
├── config/
├── logs/
└── workspace/
```

---

## Install OpenClaw

!!! info "Official documentation"
    Refer to [docs.openclaw.ai](https://docs.openclaw.ai/start/getting-started) for updated instructions.

### Method 1: Global installation with npm (RECOMMENDED for VPS)

```bash
# Install OpenClaw globally
npm install -g openclaw@latest

# Verify installation
openclaw --version
```

**Expected output:**
```
openclaw v2026.3.x
```

### Method 2: Installation with official script

```bash
# Download installation script
curl -fsSL https://openclaw.ai/install.sh -o /tmp/openclaw-install.sh

# Verify script contents before executing
less /tmp/openclaw-install.sh

# If it looks correct, execute
bash /tmp/openclaw-install.sh

# Clean up
rm /tmp/openclaw-install.sh
```

### Install Docker (optional — only for sandbox mode "all")

Docker is only needed if you want sandbox mode `all` (containerized tool execution). For dedicated single-user VPS with systemd hardening (this guide's recommended setup), Docker is **not required** — sandbox mode `"off"` with systemd isolation provides equivalent security.

```bash
# Only install if you want sandbox mode "all" (multi-user servers)
sudo apt install -y docker.io
sudo usermod -aG docker openclaw

# Reconnect SSH for the group change to take effect
exit
# Then reconnect: ssh openclaw@<TAILSCALE_IP>

# Verify Docker works
docker ps
```

### Initialize OpenClaw (onboarding)

```bash
# Run configuration wizard
# IMPORTANT: DO NOT use --install-daemon yet, we'll configure it with systemd
openclaw onboard
```

The wizard will guide you through:

1. **Authentication**: Choose "API key" (recommended for headless servers)
2. **Channels**: Configure the channels you need (Telegram, Discord, etc.)
3. **DM Policy**: Configure as "pairing" for security

!!! warning "Don't install the automatic daemon"
    The wizard may offer to install a daemon (launchd/systemd). Reject this option because we'll configure a systemd service with complete hardening later.

### Verify installation

```bash
# Verify status
openclaw status

# Run diagnostics
openclaw doctor
```

### Built-in security tools (v2026.3.x)

OpenClaw includes native security tools that you should run after installation:

```bash
# Security audit of configuration and environment
openclaw security audit

# Audit with automatic remediation
openclaw security audit --fix

# Verify effective sandbox policies
openclaw sandbox explain

# Health check and auto-healing
openclaw doctor
```

!!! success "Run `openclaw security audit --fix` after every configuration change"
    This tool verifies permissions, Gateway configuration, sandbox mode, and known vulnerabilities.

### Update channels

OpenClaw offers three update channels:

```bash
# View current channel
openclaw update --channel

# Change channel (recommended: stable for production)
openclaw update --channel stable

# Other available channels:
# openclaw update --channel beta    # New features, possible bugs
# openclaw update --channel dev     # Development, NOT for production
```

---

## Configuration files

### OpenClaw configuration structure

OpenClaw uses `~/.openclaw/openclaw.json` as the main configuration file:

```
~/.openclaw/
├── openclaw.json           # Main configuration
├── workspace/
│   ├── SOUL.md             # Agent identity and limits
│   ├── TOOLS.md            # Tools configuration
│   └── skills/             # Workspace-scoped skills
└── credentials/            # Credentials (if using OAuth)

~/.agents/
└── skills/                 # Globally installed skills (npx playbooks add)

~/openclaw/                 # Working directory (this guide)
├── config/                 # Additional configurations
├── workspace/              # Restricted workspace
├── logs/                   # Logs
└── scripts/                # Maintenance scripts
```

### Configure openclaw.json

```bash
nano ~/.openclaw/openclaw.json
```

```json
{
  "agents": {
    "defaults": {
      "model": {
        "primary": "google/gemini-2.5-flash",
        "fallbacks": ["your-fallback-provider/model"]
      },
      "models": {
        "google/gemini-2.5-flash": { "alias": "Gemini 2.5 Flash" },
        "your-fallback-provider/model": { "alias": "Fallback Model" }
      },
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "off"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 2,
      "subagents": {
        "maxConcurrent": 3
      }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "allowlist",
      "allowFrom": ["YOUR_TELEGRAM_USER_ID"],
      "streaming": "partial"
    }
  },
  "models": {
    "mode": "merge",
    "providers": {
      "google": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai",
        "apiKey": "${GOOGLE_API_KEY}",
        "api": "openai-completions",
        "models": [{
          "id": "gemini-2.5-flash",
          "name": "Gemini 2.5 Flash",
          "reasoning": false,
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65535,
          "compat": { "supportsStore": false }
        }]
      }
    }
  },
  "tools": {
    "profile": "full",
    "deny": ["gateway"],
    "web": {
      "search": {
        "enabled": true,
        "provider": "gemini",
        "gemini": {
          "apiKey": "${GEMINI_API_KEY}",
          "model": "gemini-2.5-flash"
        }
      },
      "fetch": {
        "enabled": true
      }
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token",
      "token": "${GATEWAY_TOKEN}"
    },
    "tls": {},
    "tailscale": {
      "mode": "off"
    },
    "nodes": {}
  }
}
```

!!! tip "Model providers"
    Add your chosen model provider(s) to `models.providers`. Common options:

    | Provider | `api` | Input/Output ($/MTok) | Notes |
    |----------|-------|----------------------|-------|
    | Google Gemini 2.5 Flash | `openai-completions` | $0.30 / $2.50 | Add `compat.supportsStore: false` (required) |
    | Google Gemini 2.5 Flash Lite | `openai-completions` | $0.10 / $0.40 | Ideal for heartbeats, cheapest viable model |
    | DeepSeek V3 | `openai-completions` | $0.28 / $0.42 | Best value — 90% of GPT performance at 1/50th cost |
    | Moonshot (Kimi K2.5) | `openai-completions` | $0.60 / $2.50 | Separate from Kimi Coding (different key and endpoint) |
    | Kimi Coding | `anthropic-messages` | Subscription (~$19/mo) | Add `headers.User-Agent: "claude-code/0.1.0"` (required) |
    | Anthropic Claude Sonnet 4.5 | `anthropic-messages` | $3.00 / $15.00 | |
    | Anthropic Claude Opus 4.6 | `anthropic-messages` | $5.00 / $25.00 | |

    **API type reference:**

    | `api` value | Use for |
    |-------------|---------|
    | `openai-completions` | OpenAI-compatible endpoints (Gemini, Moonshot, DeepSeek, vLLM, LM Studio) |
    | `anthropic-messages` | Anthropic Messages API (Claude, Kimi Coding) |
    | `google-generative-ai` | Google Gemini native API (use `.../v1beta` without `/openai`) |
    | `openai-responses` | OpenAI responses API |
    | `ollama` | Local Ollama models |

    Set `"fallbacks"` in `agents.defaults.model` so the agent auto-switches if the primary provider is down.

!!! warning "Kimi Coding known issues"
    - **User-Agent header required**: Kimi Coding API rejects requests without `User-Agent: claude-code/0.1.0`. OpenClaw sends `OpenClaw-Gateway/1.0` by default, causing 401 errors. Fix: add `"headers": { "User-Agent": "claude-code/0.1.0" }` at provider level.
    - **Model ID must be `kimi-for-coding`**: Do not use `k2p5` or other aliases.
    - **`reasoning: true` may break**: Extended-thinking parameters can cause Kimi to reject requests. Start with `false`.
    - **`openclaw doctor --fix` overwrites manual config**: It reverts Kimi provider settings to broken built-in templates. Do NOT run `--fix` after manual configuration.
    - **Moonshot ≠ Kimi Coding**: They are separate providers with different API keys (`MOONSHOT_API_KEY` vs `KIMI_API_KEY`) and endpoints.

!!! tip "Gemini `compat.supportsStore` explained"
    Without `"compat": { "supportsStore": false }`, OpenClaw sends a `store` parameter that Google rejects with HTTP 400 (the error body is gzip-compressed, so logs show "400 no body"). This is **required** for all Gemini models via the OpenAI compatibility endpoint.

    Do NOT use `"api": "google-generative-ai"` with a baseUrl ending in `/openai` — it causes 404 errors. Use either:

    - `openai-completions` + `.../v1beta/openai` (recommended, more reliable)
    - `google-generative-ai` + `.../v1beta` (native, without `/openai`)

!!! info "Tools configuration"
    The recommended tools config uses `profile: "full"` with `deny: ["gateway"]`:

    - `"full"` enables all tools including web search, browser, canvas, cron, and shell
    - `"deny": ["gateway"]` prevents the agent from modifying its own gateway config at runtime

    Using `profile: "coding"` with `allow: ["group:web"]` does NOT correctly enable `web_search` (possible bug). Use `"full"` + `"deny"` instead.

    For a fully unrestricted agent: `"tools": {}`

    **Tool profiles:**

    | Profile | Includes |
    |---------|----------|
    | `full` | Everything (default when unset) |
    | `coding` | `group:fs`, `group:runtime`, `group:sessions`, `group:memory`, `image` |
    | `messaging` | `group:messaging`, `sessions_*`, `session_status` |
    | `minimal` | `session_status` only |

    **Tool groups:**

    | Group | Expands to |
    |-------|------------|
    | `group:runtime` | `exec`, `bash`, `process` |
    | `group:fs` | `read`, `write`, `edit`, `apply_patch` |
    | `group:sessions` | `sessions_list`, `sessions_history`, `sessions_send`, `sessions_spawn`, `session_status` |
    | `group:memory` | `memory_search`, `memory_get` |
    | `group:web` | `web_search`, `web_fetch` |
    | `group:ui` | `browser`, `canvas` |
    | `group:automation` | `cron`, `gateway` |
    | `group:messaging` | `message` |

    The `coding` profile may warn about unknown tools (`apply_patch`, `image`) — this is harmless, those tools simply won't load without their plugins.

    !!! warning "Known issue: `coding` profile and `web_search`"
        Using `profile: "coding"` with `allow: ["group:web"]` does NOT correctly enable `web_search` (possible bug). This is why we recommend `profile: "full"` with `deny: ["gateway"]` instead.

!!! info "`web_search` setup"
    The `web_search` tool requires a search provider API key. OpenClaw auto-detects in this order: Brave → Gemini → Kimi → Perplexity → Grok.

    **Option A** — Auto-detect via env var (set `GEMINI_API_KEY` in `.env` or systemd):
    ```env
    GEMINI_API_KEY=AIza...
    ```

    **Option B** — Explicit config in `tools.web` (shown in the JSON example above):
    ```json
    "tools": {
      "web": {
        "search": {
          "enabled": true,
          "provider": "gemini",
          "gemini": { "apiKey": "${GEMINI_API_KEY}", "model": "gemini-2.5-flash" }
        },
        "fetch": { "enabled": true }
      }
    }
    ```

    **Option C** — Interactive setup: `openclaw configure --section web`

    **Three fields that are easy to miss:**

    - `tools.web.search.enabled = true` — web_search is NOT enabled by default even if you set a provider
    - `tools.web.search.gemini.model` — Gemini search requires an explicit model name
    - `tools.web.fetch.enabled = true` — enables the `web_fetch` tool for reading web pages

    Note: `GOOGLE_API_KEY` (for model inference) and `GEMINI_API_KEY` (for web search) can use the same key value, but they are different env var names.

!!! info "Variable substitution in openclaw.json"
    `openclaw.json` supports `${VAR_NAME}` in string values. Resolution order (first match wins):

    1. Process environment (systemd `Environment=`)
    2. `.env` in the current working directory
    3. `~/.openclaw/.env` (global fallback)
    4. `config.env.vars` in openclaw.json

    Only uppercase names matching `[A-Z_][A-Z0-9_]*` are substituted. Use `$${VAR}` to produce a literal `${VAR}`.

!!! danger "Critical security configuration"
    - `bind: "loopback"` — Only listens on localhost (never `0.0.0.0`)
    - `sandbox.mode: "off"` — Relies on systemd hardening for isolation (recommended for dedicated VPS). Use `"all"` for shared servers
    - `auth.mode: "token"` — Gateway access requires authentication token
    - **All secrets use `${VAR_NAME}` references** — Never store tokens or API keys as plaintext in this file
    - `session.dmScope: "per-channel-peer"` — Isolates DM sessions to prevent context leakage
    - `tls: {}` — TLS enabled with defaults

!!! warning "Removed in v2026.3.x"
    The keys `dmPolicy`, `security`, and `tools.blocked` at root level are **not recognized** by OpenClaw 2026.3.x. DM policy is configured per channel when you add channels. Run `openclaw doctor` to validate your config.

!!! info "Sandbox 'all' vs 'off' — choosing the right mode"
    - **`"all"`** — Containerizes all tool execution in Docker. Most secure, but skills `.env` files and host environment variables are NOT available inside the container. Requires injecting env vars via `skills.entries[name].env` in `openclaw.json`. Best for multi-user or shared servers.
    - **`"off"`** — No containerization. Skills `.env` files work normally, auto-discovery is seamless. Relies on systemd hardening + tools restrictions for security. **Recommended for dedicated single-user VPS** with the hardening from this guide (systemd isolation + Tailscale + allowlist).

    Starting with OpenClaw v2026.2.x, mode `"all"` replaces `"always"`.

### Configure secrets (API keys and tokens)

All sensitive values in `openclaw.json` use `${VAR_NAME}` references. The actual values are stored separately, never in the JSON config file.

#### Method 1: systemd environment overrides (recommended for VPS)

This is the most secure method for dedicated VPS deployments. Secrets are stored in a root-owned file that only systemd reads at startup.

```bash
sudo systemctl edit openclaw
```

Add your API keys and tokens:

```ini
[Service]
Environment="GOOGLE_API_KEY=your-google-api-key"
Environment="GEMINI_API_KEY=your-google-api-key"
Environment="MOONSHOT_API_KEY=sk-your-moonshot-key"
Environment="GATEWAY_TOKEN=your-gateway-token"
```

!!! important "Both GOOGLE_API_KEY and GEMINI_API_KEY are required"
    Google Gemini requires **both** environment variables set (they can have the same value).
    `GOOGLE_API_KEY` is used by the LLM provider for chat completions, while `GEMINI_API_KEY` is used internally by OpenClaw for web search (grounding) and other Google-specific features. If you only set one, web search will not work.

Save and apply:

```bash
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

The override file is stored at `/etc/systemd/system/openclaw.service.d/override.conf` with root-only permissions.

!!! warning "Do NOT add SystemCallFilter in the override"
    Adding `SystemCallFilter` lines in `override.conf` causes `NAMESPACE` errors and prevents the service from starting. Only add `Environment` lines here.

#### Method 2: .env file (for channel tokens)

Some tokens (like Telegram bot token) can be stored in a `.env` file:

```bash
nano ~/openclaw/.env
```

```bash
# Channel tokens
TELEGRAM_BOT_TOKEN=your-bot-token

# Additional API keys (if not using systemd method)
# GOOGLE_API_KEY=your-key
# GEMINI_API_KEY=your-key  # Same value as GOOGLE_API_KEY, needed for web search
```

**Protect the file:**

```bash
chmod 600 ~/openclaw/.env
chown openclaw:openclaw ~/openclaw/.env
```

#### Method 3: SecretRef (OpenClaw native)

OpenClaw v2026.3.x supports encrypted secrets via the interactive wizard:

```bash
# Interactive secrets wizard
openclaw secrets configure

# Audit for plaintext leaks
openclaw secrets audit

# Reload secrets at runtime (no restart needed)
openclaw secrets reload
```

!!! success "Secrets methods comparison"
    | Feature | systemd override | .env file | SecretRef |
    |---|---|---|---|
    | Storage | Root-owned file | User-owned plaintext | Encrypted on disk |
    | Agent can read it | No | Yes (prompt injection risk) | No |
    | Shell history leakage | No | No | No |
    | Survives OpenClaw updates | Yes | Yes | Yes |
    | Best for | API keys on VPS | Channel tokens | All secrets |

### Configure SOUL.md (agent identity)

SOUL.md defines who your agent is, what it can do, and how it behaves. OpenClaw injects this file into the agent's context at every interaction.

```bash
nano ~/openclaw/workspace/SOUL.md
```

#### Recommended sections

A well-structured SOUL.md should include these sections:

| Section | Purpose |
|---------|---------|
| **Identity** | Who the agent is and who it works for |
| **Mission** | What it should optimize for (correctness, security, value, speed) |
| **Language rules** | Response language, code language, business communication language |
| **Capabilities** | What the agent can help with (development, business, research, etc.) |
| **Approval gates** | Actions that require explicit owner confirmation before executing |
| **Filesystem boundaries** | Allowed and forbidden paths |
| **Security rules** | How to handle secrets, credentials, and sensitive data |
| **Communication rules** | Tone, style, and output structure preferences |
| **Continuity** | How to use workspace files as persistent memory across sessions |

#### Best practices

- **Be specific about identity**: Tell the agent who it works for and what it represents. A generic "you are an assistant" produces generic responses.
- **Define approval gates explicitly**: List every irreversible or external action that needs confirmation (emails, commits, API calls, purchases). The agent should always show drafts before sending.
- **Set language rules clearly**: Separate conversation language from code language. For example: "respond in Spanish, write code and documentation in English."
- **Include filesystem boundaries**: Always restrict access to the workspace directory. Explicitly forbid access to `.ssh`, `.env`, `/etc`, and `/var`.
- **Add business context if applicable**: If the agent represents a business, include services offered, ideal clients, and outreach style rules. The more context, the better the output quality.
- **Define output structure**: Tell the agent how to format different types of responses (technical, research, business drafts). This saves time on follow-up clarifications.
- **Protect sensitive data**: Explicitly state that secrets, credentials, and personal information must never appear in outputs.
- **Use the continuity section**: Tell the agent to persist reusable knowledge (client research, preferences, templates) in workspace files so it carries over across sessions.

#### Minimal example

```markdown
# My Assistant

## Identity
You are a development assistant on an isolated VPS.
You work for [your name/company].

## Language
- Respond in [your language]
- Write code, comments, and documentation in English

## Approval gates
Always ask before: sending emails, pushing commits, deleting files,
calling external APIs, or any irreversible action.

## Filesystem
- Only access: /home/openclaw/openclaw/workspace
- Never access: .ssh, .env, /etc, /var

## Security
- Never expose secrets, tokens, or credentials
- Redact secrets in outputs

## Tone
Professional, concise, direct.
```

!!! tip "Iterate on your SOUL.md"
    Start minimal and expand as you discover what the agent gets wrong. If it does something you don't want, add a rule. If it misses context, add background information. The SOUL.md is a living document.

!!! info "SOUL, TOOLS, and AGENTS files"
    OpenClaw automatically injects these Markdown files into the agent's context:

    - `SOUL.md` — Agent identity and restrictions
    - `TOOLS.md` — Available tools configuration
    - `AGENTS.md` — Specialized agents definition

!!! warning "Correct path for SOUL.md"
    These files must be in the **workspace directory** configured in `agents.defaults.workspace`, **not** in `~/.openclaw/workspace/`. With our configuration, the correct path is:

    ```
    ~/openclaw/workspace/SOUL.md
    ```

    If the agent ignores your SOUL.md, verify the path matches your workspace setting:
    `grep workspace ~/.openclaw/openclaw.json`

### Configure TOOLS.md (tools)

TOOLS.md provides context to the agent about how it should use its tools. It does NOT enforce restrictions — tool access is controlled by `tools.profile` and `tools.deny` in `openclaw.json`. Think of TOOLS.md as guidelines, not guardrails.

```bash
nano ~/openclaw/workspace/TOOLS.md
```

```markdown
# Tools

## Available tools (via profile "full" − deny ["gateway"])

### Filesystem (group:fs)
- read, write, edit, apply_patch
- Workspace: /home/openclaw/openclaw/workspace

### Shell & Runtime (group:runtime)
- exec, bash, process
- Use for: git, npm, system commands, scripts

### Web (group:web)
- web_search (Gemini-powered), web_fetch
- Use for: research, documentation lookups, API calls

### Browser & UI (group:ui)
- browser, canvas
- Use for: web scraping, visual content

### Sessions (group:sessions)
- Spawn and manage sub-agent sessions

### Memory (group:memory)
- Persistent memory across sessions

### Cron
- Schedule recurring tasks

## NOT available (intentionally excluded)

### Gateway
NOT available — modifying gateway config at runtime is a security risk.

## Guidelines

- Always ask before: sending emails, pushing to remote repos, deleting files
- Prefer workspace paths for all file operations
- Never access: ~/.ssh, ~/.openclaw/.env, /etc/systemd
- Never expose secrets, tokens, or credentials in outputs
```

### Sandbox and tool restrictions

For a **dedicated single-user VPS** with the systemd hardening from this guide, sandbox mode `"off"` is the recommended setting. Security is enforced by systemd isolation (ProtectSystem, ReadWritePaths, CapabilityBoundingSet, etc.) and tool restrictions (`tools.profile` + `tools.deny`).

Tool access is controlled in `openclaw.json` (already configured in the main JSON example above):

```json
"sandbox": { "mode": "off" },
"tools": {
  "profile": "full",
  "deny": ["gateway"]
}
```

This gives the agent all tools (filesystem, shell, git, sessions, memory, web search, web fetch, browser, canvas, cron, etc.) except `gateway` — which is denied because it would let the agent modify its own gateway configuration at runtime.

!!! warning "`coding` profile bug with web_search"
    Using `profile: "coding"` with `allow: ["group:web"]` does NOT correctly enable `web_search` (possible OpenClaw bug). Use `"full"` + `"deny"` to ensure all tools work correctly.

!!! info "When to use sandbox mode 'all' instead"
    Use `"all"` only on **shared or multi-user servers** where you cannot trust other users. It containerizes all tool execution in Docker, which provides stronger isolation but requires Docker installed and makes `.env` files and host environment variables unavailable inside the container.

    For dedicated VPS with systemd hardening + Tailscale + allowlist, `"off"` is equivalent security with less complexity.

### Configure DM Policy (message security)

OpenClaw can receive messages from channels like Telegram, Discord, etc. DM policy is configured **per channel** when you add them (not at root level). The default is `"pairing"` which requires approval.

With `dmPolicy: "pairing"` on a channel, unknown senders receive a pairing code that you must approve:

```bash
# View pending pairing codes
openclaw pairing list

# Approve a specific code
openclaw pairing approve telegram ABC123
```

!!! danger "Never use dmPolicy: 'open'"
    This would allow anyone to send commands to your agent. Only use `pairing` or `closed`.

### Configure Telegram channel

**Step 1 — Create bot in Telegram:**

1. Open Telegram and chat with **@BotFather**
2. Send `/newbot`
3. Choose a display name (e.g., "OpenClaw Assistant")
4. Choose a username ending in `_bot` (e.g., `openclaw_myname_bot`)
5. BotFather gives you a token (format: `123456789:ABCdef...`) — save it

**Step 2 — Add channel to config:**

```bash
nano ~/.openclaw/openclaw.json
```

Add the `channels` section at root level (before the last `}`):

```json
"channels": {
  "telegram": {
    "enabled": true,
    "botToken": "YOUR_BOTFATHER_TOKEN",
    "dmPolicy": "pairing"
  }
}
```

!!! tip "Don't forget the comma"
    Add a comma after the closing `}` of the previous section before `"channels"`.

!!! warning "Switch to allowlist after pairing"
    Use `"pairing"` only for the initial setup. After approving your account (Step 4), switch to `"allowlist"` in Step 5 to lock down access.

**Step 3 — Restart and verify:**

```bash
sudo systemctl restart openclaw
# Wait ~2 minutes, then verify Telegram connected:
sudo journalctl -u openclaw --since "3 min ago" --no-pager | grep telegram
```

You should see: `[telegram] [default] starting provider (@your_bot_name)`

**Step 4 — Pair your account:**

1. Open Telegram and send any message to your bot
2. The bot replies with a pairing code
3. Approve it on the VPS:

```bash
openclaw pairing approve telegram <CODE>
```

After approval, send another message — the bot should respond.

**Step 5 — Restrict access to your account only:**

Find your Telegram user ID — send any message to **@raw_data_bot** on Telegram, it will show your numeric ID.

Then edit the config:

```bash
nano ~/.openclaw/openclaw.json
```

Change `dmPolicy` to `"allowlist"` and add `allowFrom` with your ID:

```json
"channels": {
  "telegram": {
    "enabled": true,
    "botToken": "YOUR_TOKEN",
    "dmPolicy": "allowlist",
    "allowFrom": ["YOUR_TELEGRAM_ID"]
  }
}
```

Restart: `sudo systemctl restart openclaw`

!!! danger "Use dmPolicy 'allowlist' — not 'pairing'"
    With `"pairing"`, **anyone** who finds your bot can request a pairing code — `allowFrom` is ignored.
    With `"allowlist"`, **only** the IDs in `allowFrom` can interact with the bot — all others are silently ignored.

#### Revoke access from a previously approved sender

If you approved someone by mistake, you need to edit the pairing store file:

```bash
# View currently approved senders
cat ~/.openclaw/credentials/telegram-default-allowFrom.json

# Remove a sender (replace SENDER_ID with the ID to remove)
python3 -c "
import json
f = '/home/openclaw/.openclaw/credentials/telegram-default-allowFrom.json'
with open(f) as fh:
    d = json.load(fh)
d['allowFrom'] = [x for x in d['allowFrom'] if x != 'SENDER_ID']
with open(f, 'w') as fh:
    json.dump(d, fh, indent=2)
print('Removed SENDER_ID')
"
sudo systemctl restart openclaw
```

!!! note "No CLI command for revocation"
    OpenClaw does not have a CLI command to revoke approved senders. The pairing store files in `~/.openclaw/credentials/` must be edited manually.

!!! note "The `openclaw channels add` wizard"
    The interactive CLI wizard (`openclaw channels add`) may not always save the config correctly. If it fails, use the manual JSON method above — it is more reliable.

#### Useful Telegram commands

| Command | Description |
|---------|-------------|
| `/new` | Start a fresh session (reloads SOUL.md and clears context) |
| `/reset` | Same as `/new` |
| `/compact` | Summarize older conversation turns to free up context |

!!! tip "Reduce duplicate messages"
    If the bot sends 2-3 replies per message, add `"blockStreaming": true` to the Telegram channel config. This makes the bot send only the final response instead of intermediate messages.

    ```json
    "channels": {
      "telegram": {
        "blockStreaming": true,
        ...
      }
    }
    ```

!!! tip "SOUL.md changes not taking effect?"
    Send `/new` to the bot to start a fresh session. If that doesn't work, clear the sandbox cache:

    ```bash
    rm -rf ~/.openclaw/sandboxes/agent-main-*
    sudo systemctl restart openclaw
    ```
    Then send `/new` to the bot again.

### Install and configure skills

Skills extend your agent's capabilities (email, web scraping, calendar, etc.). Install them with the `npx playbooks` command.

!!! danger "Always audit skills before installing"
    After the ClawHub supply chain attack (February 2026), **never install skills blindly**. Audit source code, check author reputation, and verify with `openclaw security audit` after installation.

**Install a skill globally** (recommended for dedicated VPS):

```bash
npx playbooks add skill openclaw/skills --skill <skill-name>
# When prompted for scope, select "Global"
```

**Recommended skills for business/development use:**

!!! tip "Skill registries"
    Skills can be found on [ClawHub](https://clawhub.com) (13,700+ skills) or [Playbooks](https://playbooks.com/skills/openclaw/skills) (18,300+ skills). For a curated, security-filtered list, see [awesome-openclaw-skills](https://github.com/VoltAgent/awesome-openclaw-skills) (5,494 vetted skills).

| Skill | Install | Purpose |
|-------|---------|---------|
| `imap-smtp-email` | `npx playbooks add skill openclaw/skills --skill imap-smtp-email` | Send and receive emails via IMAP/SMTP with attachments |
| `github` | `npx clawhub@latest install github` | Manage GitHub repos, issues, PRs, CI via `gh` CLI |
| `tavily-search` | `npx clawhub@latest install tavily-search` | AI-optimized web search for research and fact-finding |
| `gog` | `npx clawhub@latest install gog` | Google Workspace: Gmail, Calendar, Drive, Contacts, Sheets, Docs |
| `summarize` | `npx clawhub@latest install summarize` | Convert long content into structured summaries |
| `obsidian` | `npx clawhub@latest install obsidian` | Interact with Obsidian vaults, automate note organization |
| `memory` | `npx playbooks add skill openclaw/skills --skill memory` | Persistent memory across sessions |
| `n8n-workflow-automation` | `npx clawhub@latest install n8n-workflow-automation` | Connect OpenClaw with n8n to trigger/manage workflows |

!!! warning "After installing any skill"
    1. Run `cd ~/.agents/skills/<skill-name> && npm install` — OpenClaw does NOT auto-install npm dependencies
    2. Run `openclaw security audit` to verify the skill is safe
    3. Restart OpenClaw: `sudo systemctl stop openclaw && sleep 2 && sudo systemctl start openclaw`

#### Configure email (imap-smtp-email skill)

After installing the `imap-smtp-email` skill, configure credentials.

**Step 1 — Store credentials with SecretRef (recommended):**

```bash
openclaw secrets configure IMAP_HOST
# Enter: imap.your-provider.com

openclaw secrets configure IMAP_USER
# Enter: your@email.com

openclaw secrets configure IMAP_PASS
# Enter: your-email-password

openclaw secrets configure SMTP_HOST
# Enter: smtp.your-provider.com

openclaw secrets configure SMTP_USER
# Enter: your@email.com

openclaw secrets configure SMTP_PASS
# Enter: your-email-password

# Verify all secrets are stored
openclaw secrets list
```

**Step 2 — Configure skill in openclaw.json:**

```bash
nano ~/.openclaw/openclaw.json
```

Add the `skills` section at root level:

```json
"skills": {
  "entries": {
    "imap-smtp-email": {
      "enabled": true,
      "env": {
        "IMAP_HOST": { "$secretRef": "IMAP_HOST" },
        "IMAP_PORT": "993",
        "IMAP_USER": { "$secretRef": "IMAP_USER" },
        "IMAP_PASS": { "$secretRef": "IMAP_PASS" },
        "IMAP_TLS": "true",
        "IMAP_MAILBOX": "INBOX",
        "SMTP_HOST": { "$secretRef": "SMTP_HOST" },
        "SMTP_PORT": "587",
        "SMTP_SECURE": "false",
        "SMTP_USER": { "$secretRef": "SMTP_USER" },
        "SMTP_PASS": { "$secretRef": "SMTP_PASS" }
      }
    }
  }
}
```

**Step 3 — Restart and verify:**

```bash
sudo systemctl restart openclaw
openclaw security audit
```

!!! info "Common IMAP/SMTP settings"
    | Provider | IMAP Host | IMAP Port | SMTP Host | SMTP Port |
    |----------|-----------|-----------|-----------|-----------|
    | IONOS | imap.ionos.com | 993 (SSL/TLS) | smtp.ionos.com | 587 (STARTTLS) |
    | Gmail | imap.gmail.com | 993 (SSL/TLS) | smtp.gmail.com | 587 (STARTTLS) |
    | Outlook | outlook.office365.com | 993 (SSL/TLS) | smtp.office365.com | 587 (STARTTLS) |

!!! warning "Gmail requires app-specific passwords"
    If using Gmail, enable 2FA and generate an app-specific password. Do not use your account password.

!!! tip "Alternative: .env file in the skill folder"
    If `openclaw secrets configure` doesn't work for your setup, create a `.env` file directly in the skill's install folder. **Important:** verify the actual install path first — it may vary:

    ```bash
    # Find where the skill was actually installed
    find /home/openclaw -name "SKILL.md" -path "*imap*" 2>/dev/null
    ```

    Then create the `.env` in that same folder:

    ```bash
    mkdir -p ~/.agents/skills/imap-smtp-email
    nano ~/.agents/skills/imap-smtp-email/.env
    ```

    ```bash
    IMAP_HOST=imap.your-provider.com
    IMAP_PORT=993
    IMAP_USER=your@email.com
    IMAP_PASS=your-password
    IMAP_TLS=true
    IMAP_MAILBOX=INBOX
    SMTP_HOST=smtp.your-provider.com
    SMTP_PORT=587
    SMTP_SECURE=false
    SMTP_USER=your@email.com
    SMTP_PASS=your-password
    ```

    ```bash
    chmod 600 ~/.agents/skills/imap-smtp-email/.env
    ```

### Configure AGENTS.md (specialized agents)

AGENTS.md defines specialized agents that your main agent can delegate tasks to. Place it in the workspace:

```bash
nano ~/openclaw/workspace/AGENTS.md
```

```markdown
# Agents

## researcher
- Role: Web research, competitive analysis, market intelligence
- Tools: web-search, web-fetch
- Instructions: Always cite sources. Return structured summaries.

## email-drafter
- Role: Draft and review business emails, outreach campaigns
- Tools: imap-smtp-email
- Instructions: Never send without owner approval. Always show draft first.
  Match recipient's language. Professional but warm tone.

## developer
- Role: Code review, debugging, documentation, architecture
- Tools: read, write, edit, bash, glob, grep
- Instructions: Follow project conventions. Write tests for new features.
  Use English for code and comments.
```

!!! tip "Agents are optional"
    You can start without AGENTS.md — the main agent handles everything. Add specialized agents when you want to improve quality for specific task types.

---

## Run OpenClaw (manual test)

### Verify it only listens on localhost

```bash
# Run the Gateway manually with environment variables loaded inline
# This avoids leaking secrets into the shell environment and /proc/*/environ
env $(grep -v '^#' ~/openclaw/.env | xargs) openclaw gateway --port 18789 --verbose
```

!!! warning "Do not use `export` to load secrets"
    Avoid the pattern `export $(grep -v '^#' .env | xargs)`. Using `export` injects all secrets into the shell environment, where they persist for the lifetime of the session and are readable via `/proc/*/environ` by any process running as the same user. The `env` pattern above limits the variables to the single command invocation. For production, the systemd `EnvironmentFile` directive (shown below in the service configuration) is the preferred method — it loads variables directly into the service without exposing them to interactive shells.

In **another SSH terminal**, verify:

```bash
# Should show listening on 127.0.0.1, NOT on 0.0.0.0
ss -tlnp | grep 18789
```

**Expected output:**
```
LISTEN  0  128  127.0.0.1:18789  0.0.0.0:*  users:(("node",pid=1234,fd=3))
```

!!! danger "If you see `0.0.0.0:18789`"
    This means it's listening on all interfaces. Check the configuration in `~/.openclaw/openclaw.json` and make sure `gateway.host` is `"127.0.0.1"`. **Do not continue until this is correct.**

### Test the agent

```bash
# In another terminal, send a test message
openclaw agent --message "Hello, what is your name?"
```

Stop the Gateway with `Ctrl+C`.

---

## Run as systemd service (with hardening)

### Create service file

```bash
sudo nano /etc/systemd/system/openclaw.service
```

```ini
# ============================================================
# OpenClaw Systemd Service - With Complete Hardening
# Reference: https://www.freedesktop.org/software/systemd/man/systemd.exec.html
# ============================================================

[Unit]
Description=OpenClaw AI Agent Gateway
Documentation=https://docs.openclaw.ai/
After=network.target tailscaled.service
Wants=tailscaled.service
StartLimitBurst=5
StartLimitIntervalSec=300

[Service]
Type=simple
User=openclaw
Group=openclaw
WorkingDirectory=/home/openclaw

# --- Load environment variables ---
EnvironmentFile=/home/openclaw/openclaw/.env
Environment=NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
Environment=OPENCLAW_NO_RESPAWN=1

# --- Start command ---
# IMPORTANT: First find the correct path by running: which openclaw
# If you used nvm: /home/openclaw/.nvm/versions/node/v22.x.x/bin/openclaw
ExecStart=/home/openclaw/.nvm/versions/node/v22.x.x/bin/openclaw gateway --port 18789

# --- Automatic restart ---
Restart=on-failure
RestartSec=10

# ============================================================
# SYSTEMD HARDENING - Process sandboxing
# ============================================================

# --- Protect filesystem ---
# Root filesystem read-only
ProtectSystem=strict
# Other users' home not accessible
ProtectHome=read-only
# Specific paths with write access allowed
ReadWritePaths=/home/openclaw/openclaw/workspace
ReadWritePaths=/home/openclaw/openclaw/logs
ReadWritePaths=/home/openclaw/.openclaw
ReadWritePaths=/var/tmp/openclaw-compile-cache
# Private temp (isolated)
PrivateTmp=true

# --- Restrict capabilities ---
# Don't allow gaining new privileges
NoNewPrivileges=true
# No special capabilities
CapabilityBoundingSet=
AmbientCapabilities=

# --- Isolate network ---
# AF_NETLINK required for OpenClaw to list network interfaces
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK

# --- Restrict syscalls ---
# Relaxed filter — @system-service + @debug is required for Telegram channel
# The strict filter (without @debug) causes core dumps when Telegram connects
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources @mount @clock @reboot @swap @raw-io @cpu-emulation
# Native architecture only
SystemCallArchitectures=native

# --- Protect kernel ---
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true

# --- Additional isolation ---
# No access to physical devices
PrivateDevices=true
# Isolated hostname
ProtectHostname=true
# System clock protected
ProtectClock=true
# No real-time scheduling
RestrictRealtime=true
# No SUID/SGID binaries
RestrictSUIDSGID=true
# Block personality changes
LockPersonality=true
# Prevent written memory execution (JIT may require disabling this)
# MemoryDenyWriteExecute=true

# --- Resource limits ---
# Maximum 50% CPU
CPUQuota=50%
# Maximum 2GB RAM
MemoryMax=2G
# Maximum 100 processes/threads
TasksMax=100

# --- Logging ---
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
```

### Verify OpenClaw path before activating

```bash
# IMPORTANT: Verify the correct binary path
which openclaw

# If the path is different from /home/openclaw/.local/bin/openclaw,
# edit the service file and update ExecStart with the correct path
```

### Activate service

```bash
# Reload systemd configuration
sudo systemctl daemon-reload

# Enable automatic startup
sudo systemctl enable openclaw

# Start service
sudo systemctl start openclaw

# View status
sudo systemctl status openclaw
```

**Expected output:**
```
● openclaw.service - OpenClaw AI Agent
     Loaded: loaded (/etc/systemd/system/openclaw.service; enabled; ...)
     Active: active (running) since ...
```

!!! info "Gateway startup time"
    On a 4GB VPS, the gateway can take **1-2 minutes** to fully start and begin listening on port 18789. Use `ss -tln | grep 18789` to verify it's ready. If it doesn't show immediately, wait and retry.

### Verify logs

```bash
# View logs in real-time
sudo journalctl -u openclaw -f

# View last 50 logs
sudo journalctl -u openclaw -n 50
```

---

## Verify service hardening

systemd includes a tool to analyze service security:

```bash
systemd-analyze security openclaw.service
```

**Expected output:**
```
  NAME                                 DESCRIPTION                              EXPOSURE
✓ PrivateDevices=                      Service has no access to hardware devices    0.2
✓ PrivateTmp=                          Service has a private /tmp                   0.1
✓ ProtectSystem=                       Service has strict read-only access          0.1
...
→ Overall exposure level for openclaw.service: 2.4 OK
```

!!! success "Target: score < 5.0"
    A score of 10 is completely insecure. Less than 5 is acceptable, less than 3 is excellent.

---

## Access OpenClaw

From your device (with Tailscale):

### Option 1: Port forwarding via SSH (RECOMMENDED)

```bash
# Forward local port 18789 to VPS
ssh -L 18789:127.0.0.1:18789 openclaw@<YOUR_TAILSCALE_IP>
```

Now access in your browser: `http://localhost:18789`

#### Authenticate in the Control UI

On first connect, the dashboard shows **"unauthorized: gateway token missing"**. Pass your token via URL:

```
http://127.0.0.1:18789/?#token=YOUR_GATEWAY_TOKEN
```

To find your token:

```bash
openclaw config get gateway.auth.token
```

The token is stored in the browser's localStorage — you only need to do this once per browser.

#### Recommended aliases for macOS/Linux

Add these to your `~/.zshrc` or `~/.bashrc` on your **local machine** (not the VPS):

```bash
# OPENCLAW
alias oclaw="ssh openclaw@<YOUR_TAILSCALE_IP>"
alias ooclaw='pkill -f "ssh.*18789.*openclaw" 2>/dev/null; sleep 0.5; ssh -f -L 18789:127.0.0.1:18789 openclaw@<YOUR_TAILSCALE_IP> sleep 9999 && sleep 1 && open http://127.0.0.1:18789'
alias closeclaw='pkill -f "ssh.*18789.*openclaw" 2>/dev/null; echo "Tunnel closed"'
```

| Alias | Description |
|-------|-------------|
| `oclaw` | SSH into the VPS for administration |
| `ooclaw` | Opens dashboard (kills previous tunnel + creates new one + opens browser) |
| `closeclaw` | Closes the SSH tunnel |

!!! tip "Replace `<YOUR_TAILSCALE_IP>`"
    Use your VPS Tailscale IP (e.g., `100.x.x.x`). On Linux, replace `open` with `xdg-open`.

### Option 2: Tailscale Serve

```bash
# On the VPS - expose port only within Tailscale
sudo tailscale serve --bg 18789
```

This exposes the port only within your Tailscale network at `https://your-vps.tail1234.ts.net`

### Option 3: Tailscale Funnel (NOT RECOMMENDED)

!!! danger "Don't use Funnel for OpenClaw"
    Tailscale Funnel exposes the service to the Internet. This violates the isolation principle of this guide.

---

## Final security verification

```bash
echo "============================================"
echo "SECURITY VERIFICATION - OPENCLAW"
echo "============================================"
echo ""

echo "--- Listening ports ---"
sudo ss -tlnp | grep -E "(18789|22)"
echo ""

echo "--- Verify OpenClaw is NOT on 0.0.0.0 ---"
if sudo ss -tlnp | grep ":18789" | grep -q "0.0.0.0"; then
    echo "❌ DANGER: OpenClaw listening on all interfaces!"
else
    echo "✅ OpenClaw only listening on localhost"
fi
echo ""

echo "--- Verify .env permissions ---"
perms=$(stat -c "%a" ~/openclaw/.env 2>/dev/null)
if [ "$perms" = "600" ]; then
    echo "✅ .env has permissions 600"
else
    echo "❌ .env has permissions $perms (should be 600)"
fi
echo ""

echo "--- Verify systemd service ---"
if systemctl is-active openclaw >/dev/null 2>&1; then
    echo "✅ openclaw service active"
else
    echo "❌ openclaw service NOT active"
fi
echo ""

echo "--- systemd security score ---"
score=$(systemd-analyze security openclaw.service 2>/dev/null | grep "Overall" | awk '{print $NF}')
echo "Score: $score"
echo ""

echo "============================================"
```

---

## Basic monitoring

### View logs in real-time

```bash
# systemd logs
sudo journalctl -u openclaw -f

# Application logs (if configured)
tail -f ~/openclaw/logs/openclaw.log
```

### Detect anomalous behavior

```bash
# Active network connections from OpenClaw process
sudo ss -tp | grep -E "(node|python)" | grep -v "127.0.0.1"

# CPU/memory usage
ps aux | grep -E "(node|python)" | grep openclaw

# Recently modified files in workspace
find ~/openclaw/workspace -mmin -60 -type f 2>/dev/null

# Verify no connections to suspicious IPs
sudo ss -tp | grep -E "(node|python)" | awk '{print $5}' | cut -d: -f1 | sort -u
```

---

## Troubleshooting

### Common errors (quick reference)

| Error | Cause | Fix |
|-------|-------|-----|
| `400 status code (no body)` | Provider rejects unknown parameters | Add `"compat": { "supportsStore": false }` for Gemini. Check `reasoning` setting for Kimi. |
| `401 authentication_error` | Invalid API key or wrong User-Agent | Verify key with curl (see below). Add `"headers": { "User-Agent": "claude-code/0.1.0" }` for Kimi Coding. |
| `404 Not Found` | Wrong model ID or baseUrl | Verify model ID via provider's `/v1/models` endpoint. |
| `MissingEnvVarError` | `${VAR}` in config but var not set | Add var to systemd override or `~/.openclaw/.env`. |
| `Config invalid: Unrecognized key` | Unknown field in openclaw.json | Remove the field. Only use documented schema fields. |
| `tools.profile allowlist contains unknown entries` | Profile references uninstalled tools | Harmless warning. Those tools simply won't load. |
| `web_search not available` | Missing search API key | Set `GEMINI_API_KEY` or `BRAVE_API_KEY` in `.env` or systemd override. |
| `EADDRINUSE: address already in use` | Port 18789 already in use | `sudo kill $(sudo lsof -t -i:18789) && sudo systemctl restart openclaw` |
| `Permission denied` accessing files | systemd hardening blocks path | Add `ReadWritePaths=/needed/path` to the service file |
| `MemoryDenyWriteExecute` | V8 JIT needs executable memory | Remove `MemoryDenyWriteExecute=true` from the service file |
| `NAMESPACE` errors on start | `SystemCallFilter` in override.conf | Remove `SystemCallFilter` lines from override.conf — only use `Environment` lines there |

### Testing API keys directly

If the agent won't respond or you see authentication errors, verify your API keys with curl:

```bash
# Test Gemini API key
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash?key=YOUR_GOOGLE_API_KEY"

# Test Kimi Coding API key
curl -s https://api.kimi.com/coding/v1/models \
  -H "x-api-key: YOUR_KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01"

# Test Kimi Coding message (end-to-end)
curl -s https://api.kimi.com/coding/v1/messages \
  -H "x-api-key: YOUR_KIMI_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"kimi-for-coding","max_tokens":256,"messages":[{"role":"user","content":"Hello"}]}'
```

### Diagnostic commands

```bash
# View recent logs (clean output)
sudo journalctl -u openclaw -n 30 --no-pager -o cat

# Follow logs in real time
sudo journalctl -u openclaw -f --no-pager -o cat

# Service and config status
openclaw status --all

# Validate config (WARNING: --fix overwrites manual configs!)
openclaw doctor
```

!!! danger "Do NOT run `openclaw doctor --fix` after manual configuration"
    `openclaw doctor --fix` overwrites manual provider configs (especially Kimi Coding) with broken built-in templates. Use `openclaw doctor` (without `--fix`) to diagnose issues, then fix them manually.

### Detailed troubleshooting

#### Error: "EADDRINUSE: address already in use"

**Cause**: Port 18789 is already in use.

**Solution**:
```bash
# See what process is using the port
sudo ss -tlnp | grep 18789

# Kill the process if necessary
sudo kill $(sudo lsof -t -i:18789)

# Restart service
sudo systemctl restart openclaw
```

#### Error: "Permission denied" when accessing files

**Cause**: systemd hardening blocks access to non-allowed paths.

**Solution**:
```bash
# Add the path to ReadWritePaths in the service
sudo nano /etc/systemd/system/openclaw.service
# Add: ReadWritePaths=/needed/path

sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

#### Error: "MemoryDenyWriteExecute" with Node.js

**Cause**: V8 (JavaScript engine) needs JIT which requires executable memory.

**Solution**: Uncomment (remove) the line `MemoryDenyWriteExecute=true` in the service.

---

## Quick reference: essential commands

### Service management

```bash
# Restart OpenClaw
sudo systemctl restart openclaw

# Check service status
sudo systemctl status openclaw

# Stop OpenClaw
sudo systemctl stop openclaw

# Start OpenClaw
sudo systemctl start openclaw
```

### Logs and debugging

```bash
# View recent logs (last 50 lines, clean output)
sudo journalctl -u openclaw -n 50 --no-pager -o cat

# Follow logs in real time (Ctrl+C to stop)
sudo journalctl -u openclaw -f --no-pager -o cat

# View detailed gateway log (current day)
cat /tmp/openclaw/openclaw-$(date +%Y-%m-%d).log | tail -100

# Filter logs for errors only
sudo journalctl -u openclaw --no-pager | grep -i error

# Validate config (do NOT use --fix, it overwrites manual settings)
openclaw doctor

# Full status
openclaw status --all
```

### Configuration files

```bash
# Edit main config (model, tools, channels)
nano ~/.openclaw/openclaw.json

# Edit agent personality and instructions
nano ~/openclaw/workspace/SOUL.md

# Edit systemd overrides (secrets, env vars)
sudo systemctl edit openclaw
# — or directly —
sudo nano /etc/systemd/system/openclaw.service.d/override.conf

# After editing systemd overrides, always run:
sudo systemctl daemon-reload && sudo systemctl restart openclaw
```

### Secrets and API keys

```bash
# Store API keys securely in systemd (recommended for VPS)
sudo systemctl edit openclaw
# Add lines like:
#   [Service]
#   Environment="MOONSHOT_API_KEY=sk-your-key"
#   Environment="KIMI_API_KEY=sk-kimi-your-key"
#   Environment="GOOGLE_API_KEY=your-key"
#   Environment="GEMINI_API_KEY=your-key"  # same value as GOOGLE_API_KEY, for web search

# Reference in openclaw.json with: ${MOONSHOT_API_KEY}

# Interactive secrets wizard
openclaw secrets configure

# Audit configured secrets
openclaw secrets audit

# Test API keys directly (see Troubleshooting for more)
curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash?key=YOUR_KEY"
```

### Model management

```bash
# Change primary model — edit openclaw.json:
#   "agents" → "defaults" → "model" → "primary"
# Examples:
#   "moonshot/kimi-k2.5"    (Kimi — free)
#   "google/gemini-2.5-flash" (Gemini — free tier)

# List available models
openclaw models list

# Restart after changing model
sudo systemctl restart openclaw
```

### Skills management

```bash
# List installed skills and their status
openclaw skills list

# Install a skill from ClawHub
npx playbooks add skill openclaw/skills --skill <skill-name>

# Skills are installed at:
ls ~/.agents/skills/

# After installing a skill, check for npm dependencies:
cd ~/.agents/skills/<skill-name> && npm install

# Remove a skill
rm -rf ~/.agents/skills/<skill-name>
```

### Network and connectivity

```bash
# Test outbound SMTP (email sending)
nc -zv smtp.gmail.com 587 -w 5

# Test outbound IMAP (email reading)
nc -zv imap.gmail.com 993 -w 5

# Check what port OpenClaw gateway is using
sudo ss -tlnp | grep 18789

# Kill orphan gateway process (if restart fails)
sudo kill $(sudo lsof -t -i:18789)
```

### Health and security

```bash
# Run OpenClaw doctor (diagnose only — do NOT use --fix)
openclaw doctor

# Security audit
openclaw security audit

# Full status report
openclaw status --all

# Check file permissions
ls -la ~/.openclaw/
# Should be: drwx------ (700) for directory
# Should be: -rw------- (600) for openclaw.json
```

!!! tip "Workflow for config changes"
    The typical workflow for any configuration change is:

    1. Edit the file (`nano ~/.openclaw/openclaw.json`)
    2. Restart the service (`sudo systemctl restart openclaw`)
    3. Check logs (`sudo journalctl -u openclaw -n 20 --no-pager`)
    4. Test via Telegram (`/new` → send a message)

---

## Field-tested fixes: what the docs don't tell you

!!! success "Fixes applied to openclaw.json after real-world testing"
    These issues were discovered during production deployment and are not obvious from the official documentation alone.

    **1. `web_search` didn't work — 3 mandatory fields were missing:**

    | Field | Why it's needed |
    |-------|-----------------|
    | `tools.web.search.enabled = true` | Not assumed — must be set explicitly |
    | `tools.web.search.gemini.model = "gemini-2.5-flash"` | Gemini search requires an explicit model |
    | `tools.web.fetch.enabled = true` | Enables `web_fetch` for reading web pages |

    **2. Search `apiKey` was incorrectly nested:**

    ```
    WRONG:  tools.web.search.apiKey = "..."
    RIGHT:  tools.web.search.gemini.apiKey = "..."   (nested under the provider name)
    ```

    **3. Telegram streaming for better UX:**

    `telegram.streaming = "partial"` — sends progressive responses instead of waiting for the full answer. Note: the correct field is `streaming`, NOT `streamMode` (which causes a schema validation error). `openclaw doctor` auto-corrects this.

    **4. Schema validation — fields that do NOT exist:**

    These fields cause `Config invalid` errors: `sendOptions`, `requestOptions`, `passthrough`, `extraBody`, `streamMode` (correct field: `streaming`).

    **5. `daemon-reload` is mandatory before restart:**

    After editing systemd overrides (`sudo systemctl edit openclaw`), always run `sudo systemctl daemon-reload` before `sudo systemctl restart openclaw`. Without daemon-reload, the new environment variables are NOT applied.

!!! info "Our config vs popular community configs"
    After comparing with production configs from the community (sources below), here are the key differences and our rationale:

    | Setting | This guide | Common in production | Our rationale |
    |---------|-----------|---------------------|---------------|
    | `tools.profile` | `"full"` + `deny: ["gateway"]` | `"full"` | `coding` profile has a bug where `web_search` doesn't enable correctly — use `full` + `deny` |
    | `maxConcurrent` | `2` | `4` typical | Balanced for 4GB VPS — increase to 4 for 8GB+ |
    | `heartbeat.model` | Not configured | Cheap model every 30m | Optional — add if you want proactive agent check-ins |
    | `subagents.model` | Inherits primary | Different (cheaper) model | Cost saving — set to DeepSeek V3 or Flash Lite for subagents |
    | `telegram.dmPolicy` | `"allowlist"` | `"pairing"` | Security: `allowlist` is stricter — `pairing` allows anyone to request access |
    | `telegram.streaming` | `"partial"` | Varies | Better UX — progressive responses (field is `streaming`, NOT `streamMode`) |

    **To add heartbeats** (proactive agent check-ins every 30 minutes):
    ```json
    "heartbeat": {
      "every": "30m",
      "model": "google/gemini-2.5-flash-lite"
    }
    ```

    **To use a cheaper model for subagents:**
    ```json
    "subagents": {
      "maxConcurrent": 3,
      "model": "deepseek/deepseek-chat"
    }
    ```

    **Sources consulted:** [digitalknk production config](https://gist.github.com/digitalknk), [MoltFounders annotated reference](https://github.com/MoltFounders), [VelvetShark multi-model routing guide](https://velvetshark.com), [docs.openclaw.ai/tools/web](https://docs.openclaw.ai/tools/web), [docs.openclaw.ai/channels/telegram](https://docs.openclaw.ai/channels/telegram), [GitHub Issue #23058](https://github.com/openclaw/openclaw/issues/23058)

---

## Summary

| Configuration | Status |
|---------------|--------|
| Node.js installed and verified | ✅ |
| OpenClaw cloned | ✅ |
| .env with chmod 600 | ✅ |
| HOST=127.0.0.1 | ✅ |
| Skills with allowlist | ✅ |
| http_client with allowlist | ✅ |
| Tools restricted via profile | ✅ |
| systemd service configured | ✅ |
| systemd hardening applied | ✅ |
| Security score < 5.0 | ✅ |

---

## Rollback and uninstallation

### Stop and disable OpenClaw

```bash
# Stop the service
sudo systemctl stop openclaw

# Disable automatic startup
sudo systemctl disable openclaw

# Verify it's stopped
sudo systemctl status openclaw
```

### Uninstall OpenClaw

```bash
# Remove the global npm package
npm uninstall -g openclaw

# Remove configuration (OPTIONAL - contains secrets)
rm -rf ~/.openclaw

# Remove workspace and scripts (OPTIONAL - may contain data)
rm -rf ~/openclaw

# Remove systemd service
sudo rm /etc/systemd/system/openclaw.service
sudo systemctl daemon-reload
```

!!! warning "Backup before removing"
    Before removing `~/.openclaw` or `~/openclaw`, make sure you have a backup of:

    - `~/openclaw/.env` (API keys)
    - `~/.openclaw/openclaw.json` (configuration)
    - `~/openclaw/workspace/` (work data)

### Uninstall Node.js (if no longer needed)

```bash
# If you used nvm
nvm deactivate
nvm uninstall 22

# Remove nvm completely (optional)
rm -rf ~/.nvm
# Then remove the nvm lines from ~/.bashrc
```

### Revert systemd hardening

The systemd service has already been removed. No residual hardening changes remain.

### Verify complete uninstallation

```bash
echo "=== Uninstallation verification ==="

# OpenClaw
which openclaw 2>/dev/null && echo "❌ OpenClaw still installed" || echo "✅ OpenClaw removed"

# systemd service
[ -f /etc/systemd/system/openclaw.service ] && echo "❌ systemd service exists" || echo "✅ Service removed"

# Configuration
[ -d ~/.openclaw ] && echo "⚠️  ~/.openclaw exists (remove manually if not needed)" || echo "✅ Configuration removed"

# Workspace
[ -d ~/openclaw ] && echo "⚠️  ~/openclaw exists (remove manually if not needed)" || echo "✅ Workspace removed"

echo "==================================="
```

---

**Next:** [6. LLM APIs](06-llm-apis.md) — Model comparison and recommendations.
