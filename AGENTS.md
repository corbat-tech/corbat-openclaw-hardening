# AGENTS.md — Agentic Self-Configuration Guide

> This file is for you, the AI agent. Follow these steps to configure this OpenClaw deployment correctly.

## Who am I?

You are an AI assistant deployed on a hardened VPS following this guide.
Configure your identity in `~/.openclaw/AGENTS.md` on the server.

## Self-configuration checklist

When asked to configure or verify your setup, follow these steps in order:

### 1. Verify your environment

```bash
# Check OpenClaw version
openclaw --version

# Check your model
grep '"primary"' ~/.openclaw/openclaw.json

# Check service status
systemctl status openclaw --no-pager

# Check skills
openclaw skills list
```

### 2. Verify API keys are configured

API keys must be stored in systemd overrides, NOT in openclaw.json or .bashrc:

```bash
# Check if override exists
cat /etc/systemd/system/openclaw.service.d/override.conf 2>/dev/null
```

If API keys are missing, guide the user to add them:
```bash
sudo systemctl edit openclaw
# Add:
#   [Service]
#   Environment="MOONSHOT_API_KEY=sk-..."
#   Environment="GOOGLE_API_KEY=..."
#   Environment="GEMINI_API_KEY=..."  # same value as GOOGLE_API_KEY, needed for web search
```

### 3. Verify network connectivity

The Hetzner Cloud Firewall must allow these outbound ports:

| Port | Protocol | Purpose |
|------|----------|---------|
| 443  | TCP      | HTTPS (LLM APIs) |
| 80   | TCP      | HTTP (updates) |
| 587  | TCP      | SMTP (email sending) |
| 993  | TCP      | IMAP (email reading) |
| 41641 | UDP     | Tailscale (WireGuard) |
| 3478 | UDP      | STUN (Tailscale NAT traversal) |
| 53   | UDP      | DNS |

Test connectivity:
```bash
nc -zv smtp.gmail.com 587 -w 5
nc -zv imap.gmail.com 993 -w 5
```

### 4. Recommended openclaw.json structure

```json
{
  "agents": {
    "defaults": {
      "compaction": { "mode": "safeguard" },
      "maxConcurrent": 1,
      "model": {
        "primary": "kimi-coding/kimi-for-coding",
        "fallbacks": ["google/gemini-2.5-flash"]
      },
      "models": {
        "kimi-coding/kimi-for-coding": { "alias": "Kimi Coding" },
        "google/gemini-2.5-flash": { "alias": "Gemini 2.5 Flash" }
      },
      "sandbox": { "mode": "off" },
      "subagents": { "maxConcurrent": 3 },
      "workspace": "/home/openclaw/openclaw/workspace"
    }
  },
  "auth": {
    "profiles": {
      "google:default": { "provider": "google", "mode": "api_key" },
      "kimi-coding:default": { "provider": "kimi-coding", "mode": "api_key" }
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
  "approvals": {
    "exec": {
      "enabled": true,
      "mode": "session",
      "targets": [
        { "channel": "telegram", "to": "YOUR_TELEGRAM_USER_ID" }
      ]
    }
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true
  },
  "gateway": {
    "auth": { "mode": "token", "token": "${GATEWAY_TOKEN}" },
    "bind": "loopback",
    "mode": "local",
    "port": 18789
  },
  "models": {
    "mode": "merge",
    "providers": {
      "google": {
        "api": "openai-completions",
        "apiKey": "${GOOGLE_API_KEY}",
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai",
        "models": [{
          "id": "gemini-2.5-flash",
          "name": "Gemini 2.5 Flash",
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65536,
          "reasoning": false,
          "compat": { "supportsStore": false }
        }]
      },
      "kimi-coding": {
        "api": "anthropic-messages",
        "apiKey": "${KIMI_API_KEY}",
        "baseUrl": "https://api.kimi.com/coding",
        "headers": { "User-Agent": "claude-code/0.1.0" },
        "models": [{
          "id": "kimi-for-coding",
          "name": "Kimi Coding",
          "input": ["text"],
          "contextWindow": 262144,
          "maxTokens": 32768,
          "reasoning": false
        }]
      }
    }
  },
  "session": { "dmScope": "per-channel-peer" },
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
  }
}
```

### 5. Model selection guide

| Model | Provider | Tool calls | Cost | Best for |
|-------|----------|-----------|------|----------|
| `moonshot/kimi-k2.5` | Moonshot | Yes | Free tier | General assistant, coding |
| `google/gemini-2.5-flash` | Google | Yes | Free tier | Fast responses, large context (1M tokens) |
| `kimi-coding/kimi-for-coding` | Kimi Code | Limited | Subscription | Coding tasks (tool calls may fail with reasoning enabled) |

To switch models, change `agents.defaults.model.primary` and restart:
```bash
sudo systemctl restart openclaw
```

### 6. Skills installation

```bash
# Install a skill
npx playbooks add skill openclaw/skills --skill <name>

# IMPORTANT: always install npm dependencies after
cd ~/.agents/skills/<name> && npm install

# Verify installation
openclaw skills list
```

Skills auto-discover from `~/.agents/skills/`. No config needed in openclaw.json.

### 7. Email setup (himalaya)

```bash
# Install skill
npx playbooks add skill openclaw/skills --skill himalaya

# Install CLI binary
curl -sL https://github.com/pimalaya/himalaya/releases/latest/download/himalaya-x86_64-linux-gnu.tar.gz | sudo tar xz -C /usr/local/bin/

# Configure Gmail
mkdir -p ~/.config/himalaya
cat > ~/.config/himalaya/config.toml << 'EOF'
[accounts.gmail]
default = true
email = "your-email@gmail.com"
display-name = "Your Name"

backend.type = "imap"
backend.host = "imap.gmail.com"
backend.port = 993
backend.encryption = "tls"
backend.login = "your-email@gmail.com"
backend.auth.type = "password"
backend.auth.raw = "your-app-password"

message.send.backend.type = "smtp"
message.send.backend.host = "smtp.gmail.com"
message.send.backend.port = 587
message.send.backend.encryption = "start-tls"
message.send.backend.login = "your-email@gmail.com"
message.send.backend.auth.type = "password"
message.send.backend.auth.raw = "your-app-password"
EOF

# Verify
himalaya envelope list
```

### 8. Secrets storage

Store all sensitive values securely — **never** as plaintext in `openclaw.json`:

| Secret type | Where to store | How to reference |
|-------------|---------------|-----------------|
| API keys (LLM providers) | `sudo systemctl edit openclaw` → `Environment="KEY=value"` | `${KEY}` in openclaw.json |
| Channel tokens (Telegram) | `~/.openclaw/.env` (chmod 600) or systemd override | `${TELEGRAM_BOT_TOKEN}` |
| Gateway token | `sudo systemctl edit openclaw` → `Environment="GATEWAY_TOKEN=value"` | `${GATEWAY_TOKEN}` |

After editing systemd overrides: `sudo systemctl daemon-reload && sudo systemctl restart openclaw`

### 8b. Execution approvals (exec-approvals.json)

The install script generates `~/.openclaw/exec-approvals.json` with a unique socket token. Structure:

```json
{
  "version": 1,
  "socket": {
    "path": "/home/openclaw/.openclaw/exec-approvals.sock",
    "token": "AUTO_GENERATED"
  },
  "defaults": {
    "security": "allowlist",
    "ask": "on-miss",
    "askFallback": "deny",
    "autoAllowSkills": true
  },
  "agents": {
    "main": {
      "security": "allowlist",
      "ask": "on-miss",
      "askFallback": "deny",
      "autoAllowSkills": true,
      "allowlist": [
        { "pattern": "/usr/bin/cat" },
        { "pattern": "/usr/bin/ls" },
        { "pattern": "/usr/bin/grep" },
        { "pattern": "/usr/bin/find" },
        { "pattern": "/usr/bin/diff" },
        { "pattern": "/usr/bin/stat" },
        { "pattern": "/usr/bin/du" },
        { "pattern": "/usr/bin/df" },
        { "pattern": "/usr/bin/sed" },
        { "pattern": "/usr/bin/awk" },
        { "pattern": "/usr/bin/touch" },
        { "pattern": "/usr/bin/mkdir" },
        { "pattern": "/usr/bin/cp" },
        { "pattern": "/usr/bin/mv" },
        { "pattern": "/usr/bin/tar" },
        { "pattern": "/usr/bin/date" },
        { "pattern": "/usr/bin/env" },
        { "pattern": "/usr/bin/whoami" },
        { "pattern": "/usr/bin/uname" },
        { "pattern": "/usr/bin/hostname" },
        { "pattern": "/usr/bin/uptime" },
        { "pattern": "/usr/bin/free" },
        { "pattern": "/usr/bin/top" },
        { "pattern": "/usr/bin/ps" },
        { "pattern": "/usr/bin/ss" },
        { "pattern": "/usr/bin/netstat" },
        { "pattern": "/usr/bin/lsof" },
        { "pattern": "/usr/bin/htop" },
        { "pattern": "/usr/bin/journalctl" },
        { "pattern": "/usr/bin/ping" },
        { "pattern": "/usr/bin/git" },
        { "pattern": "/usr/bin/docker" },
        { "pattern": "/usr/bin/curl" },
        { "pattern": "/usr/bin/wget" },
        { "pattern": "/usr/bin/python3" },
        { "pattern": "/home/openclaw/.nvm/**/node" },
        { "pattern": "/home/openclaw/.nvm/**/npm" },
        { "pattern": "/home/openclaw/.nvm/**/npx" },
        { "pattern": "/home/openclaw/.nvm/**/openclaw" },
        { "pattern": "/home/openclaw/.nvm/**/coco" },
        { "pattern": "/home/openclaw/.nvm/**/corepack" },
        { "pattern": "/home/openclaw/.local/bin/*" },
        { "pattern": "/usr/local/bin/*" }
      ]
    }
  }
}
```

Commands not in the allowlist (`rm`, `kill`, `systemctl`, `chmod`, `ssh`, `scp`) require approval via Telegram. Commands like `sudo`, `su`, `dd`, `reboot` are never allowed (not in any list).

### 9. Security rules

- **Never** store API keys in openclaw.json — use `${VAR_NAME}` references
- **Never** add `SystemCallFilter` in override.conf — causes NAMESPACE errors
- **Never** deny `process` in tools — skills need it to run scripts
- **Never** run `openclaw doctor --fix` after manual config — it overwrites provider settings
- **Always** use `tools.profile: "full"` with `deny: ["gateway"]` — `coding` profile has a bug where `web_search` doesn't enable correctly
- **Always** use sandbox `"off"` on dedicated VPS with systemd hardening
- **Always** configure `exec-approvals.json` with `security: "allowlist"` — prevents uncontrolled command execution
- **Always** restart after config changes: `sudo systemctl daemon-reload && sudo systemctl restart openclaw`

### 10. Troubleshooting

```bash
# Service won't start — check logs
sudo journalctl -u openclaw -n 30 --no-pager

# Port already in use
sudo kill $(sudo lsof -t -i:18789) && sudo systemctl restart openclaw

# Config parse error — validate JSON
python3 -c "import json; json.load(open('$HOME/.openclaw/openclaw.json'))"

# Skills not working — verify path
find /home/openclaw -name "SKILL.md" -path "*<skill-name>*"

# Email not connecting — check firewall ports
nc -zv smtp.gmail.com 587 -w 5
nc -zv imap.gmail.com 993 -w 5
```

## Documentation

The full hardening guide is in this repository:
- English: `docs/en/` (sections 01 through 10)
- Spanish: `docs/es/` (mirrors EN exactly)

Refer to `docs/en/05-openclaw.md` (or `docs/es/05-openclaw.md`) for the complete installation and configuration guide including the "Quick reference: essential commands" section.
