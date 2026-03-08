# 5. Install OpenClaw

> **TL;DR**: Install Node.js 22+, configure OpenClaw with the Gateway daemon, apply minimal permissions, and run as a systemd service with complete sandboxing.

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

### Install Docker (required for sandbox)

Docker is required for sandbox mode `all` — the recommended security setting:

```bash
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
        "primary": "kimi-coding/k2p5"
      },
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "off"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 4,
      "subagents": {
        "maxConcurrent": 8
      }
    }
  },
  "tools": {
    "profile": "coding",
    "allow": ["group:web"],
    "deny": ["group:automation", "process"]
  },
  "session": {
    "dmScope": "per-channel-peer"
  },
  "gateway": {
    "port": 18789,
    "mode": "local",
    "bind": "loopback",
    "auth": {
      "mode": "token"
    },
    "tls": {},
    "tailscale": {
      "mode": "off"
    },
    "nodes": {
    }
  }
}
```

!!! danger "Critical security configuration"
    - `bind: "loopback"` — Only listens on localhost (never `0.0.0.0`)
    - `sandbox.mode: "off"` — Relies on systemd hardening for isolation (recommended for dedicated VPS). Use `"all"` for shared servers
    - `auth.mode: "token"` — Gateway access requires authentication token
    - `session.dmScope: "per-channel-peer"` — Isolates DM sessions to prevent context leakage
    - `tls: {}` — TLS enabled with defaults

!!! warning "Removed in v2026.3.x"
    The keys `dmPolicy`, `security`, and `tools.blocked` at root level are **not recognized** by OpenClaw 2026.3.x. DM policy is configured per channel when you add channels. Run `openclaw doctor` to validate your config.

!!! info "Sandbox 'all' vs 'off' — choosing the right mode"
    - **`"all"`** — Containerizes all tool execution in Docker. Most secure, but skills `.env` files and host environment variables are NOT available inside the container. Requires injecting env vars via `skills.entries[name].env` in `openclaw.json`. Best for multi-user or shared servers.
    - **`"off"`** — No containerization. Skills `.env` files work normally, auto-discovery is seamless. Relies on systemd hardening + tools restrictions for security. **Recommended for dedicated single-user VPS** with the hardening from this guide (systemd isolation + Tailscale + allowlist).

    Starting with OpenClaw v2026.2.x, mode `"all"` replaces `"always"`.

### Configure credentials with SecretRef (RECOMMENDED)

Starting with OpenClaw v2026.3.x, the **SecretRef** mechanism allows managing credentials securely without plaintext `.env` files. Supports up to 64 targets.

```bash
# Interactive secrets wizard (configures providers + maps refs)
openclaw secrets configure

# Audit secrets for plaintext leaks or unresolved refs
openclaw secrets audit

# Reload secrets at runtime (no restart needed)
openclaw secrets reload

# Use in openclaw.json with SecretRef
```

In `openclaw.json`, reference secrets like this:

```json
{
  "agent": {
    "model": "anthropic/claude-sonnet-4-5",
    "apiKey": { "$secretRef": "ANTHROPIC_API_KEY" }
  }
}
```

!!! success "SecretRef vs .env"
    | Feature | SecretRef | .env |
    |---|---|---|
    | Storage | Encrypted on disk | Plaintext |
    | Prompt injection risk | Low | High (agent can read the file) |
    | Shell history leakage | No | Yes (if using `export`) |
    | Rotation | `openclaw secrets set` | Edit file manually |

### Alternative: .env file (legacy method)

If you prefer the traditional method or your OpenClaw version does not support SecretRef:

```bash
nano ~/openclaw/.env
```

```bash
# ============================================================
# OpenClaw Environment Variables
# NEVER version this file - chmod 600
# ============================================================

# --- API Keys ---
# Use only ONE of these options

# Option 1: Anthropic (recommended)
ANTHROPIC_API_KEY=sk-ant-...

# Option 2: OpenAI
# OPENAI_API_KEY=sk-...

# Option 3: NVIDIA NIM (Kimi K2.5 free)
# NVIDIA_API_KEY=nvapi-...

# --- Channels (optional) ---
# TELEGRAM_BOT_TOKEN=...
# DISCORD_BOT_TOKEN=...
# SLACK_BOT_TOKEN=...

# --- Web search (recommended) ---
# BRAVE_SEARCH_API_KEY=...
```

**Protect the file:**

```bash
chmod 600 ~/openclaw/.env
chown openclaw:openclaw ~/openclaw/.env

# Verify permissions
ls -la ~/openclaw/.env
```

**Expected output:**
```
-rw------- 1 openclaw openclaw 512 Feb  1 10:00 /home/openclaw/openclaw/.env
```

!!! warning ".env file limitations"
    Plaintext `.env` files are vulnerable to:

    - **Prompt injection** — a compromised agent can try to read the file
    - **Log leakage** — variables expand in shell history
    - **Access by other processes** — any user process can read it

    Use **SecretRef** when possible.

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

```bash
nano ~/.openclaw/workspace/TOOLS.md
```

```markdown
# Tools Configuration

## Enabled tools

### Filesystem
- **Allowed paths**: `/home/openclaw/openclaw/workspace`
- **Allowed operations**: read, write, list, create_directory
- **Blocked operations**: delete_recursive, change_permissions, symlinks

### Git
- **Allowed operations**: clone, status, diff, log, branch, checkout
- **Blocked operations**: push, force-push, reset --hard, clean

### HTTP Client
- **Allowed domains**:
  - api.anthropic.com
  - api.openai.com
  - integrate.api.nvidia.com
  - api.github.com
  - api.telegram.org
- **Blocked domains**: *.onion, localhost, private ranges (10.*, 192.168.*, 169.254.*)

## Disabled tools

### Shell (bash/exec)
DISABLED - Risk of arbitrary command execution.

### Browser
DISABLED - Use http_client for HTTP requests.

### Canvas/Nodes
DISABLED - Not required for this deployment.
```

### Configure sandbox in openclaw.json

Edit the configuration to force sandbox and limit tools:

```bash
nano ~/.openclaw/openclaw.json
```

Add or modify the sandbox section:

```json
{
  "agents": {
    "defaults": {
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "all",
        "allowedTools": [
          "bash",
          "read",
          "write",
          "edit"
        ],
        "blockedTools": [
          "browser",
          "canvas",
          "nodes",
          "cron",
          "gateway"
        ]
      }
    }
  }
}
```

!!! warning "Sandbox mode 'all' requires Docker"
    Mode `all` containerizes all tool execution in Docker — it is the most secure for servers. **Docker must be installed** or the agent will fail with: `Sandbox mode requires Docker, but the "docker" command was not found`.

    Install Docker:

    ```bash
    sudo apt install -y docker.io
    sudo usermod -aG docker openclaw
    # Reconnect SSH for group to take effect
    ```

    If you cannot use Docker, set `"mode": "off"` and add compensating tool restrictions:

    ```json
    "sandbox": { "mode": "off" },
    "tools": {
      "profile": "coding",
      "allow": ["group:web"],
      "deny": ["group:automation", "process"]
    }
    ```

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

| Skill | Purpose |
|-------|---------|
| `imap-smtp-email` | Send and receive emails via IMAP/SMTP |
| `web-search` | Search the web for information |
| `github` | Interact with GitHub repositories |
| `memory` | Persistent memory across sessions |

#### Configure email (imap-smtp-email skill)

After installing the `imap-smtp-email` skill, configure credentials.

**Step 1 — Store credentials with SecretRef (recommended):**

```bash
openclaw secrets set IMAP_HOST
# Enter: imap.your-provider.com

openclaw secrets set IMAP_USER
# Enter: your@email.com

openclaw secrets set IMAP_PASS
# Enter: your-email-password

openclaw secrets set SMTP_HOST
# Enter: smtp.your-provider.com

openclaw secrets set SMTP_USER
# Enter: your@email.com

openclaw secrets set SMTP_PASS
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

### Error: "EADDRINUSE: address already in use"

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

### Error: "Permission denied" when accessing files

**Cause**: systemd hardening blocks access to non-allowed paths.

**Solution**:
```bash
# Add the path to ReadWritePaths in the service
sudo nano /etc/systemd/system/openclaw.service
# Add: ReadWritePaths=/needed/path

sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

### Error: "MemoryDenyWriteExecute" with Node.js

**Cause**: V8 (JavaScript engine) needs JIT which requires executable memory.

**Solution**: Uncomment (remove) the line `MemoryDenyWriteExecute=true` in the service.

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
| shell disabled | ✅ |
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
