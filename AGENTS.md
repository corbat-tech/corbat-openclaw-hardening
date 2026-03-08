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
  "auth": {
    "profiles": {
      "google:default": { "provider": "google", "mode": "api_key" }
    }
  },
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_BOT_TOKEN}",
      "dmPolicy": "allowlist",
      "allowFrom": ["YOUR_TELEGRAM_USER_ID"]
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
          "input": ["text", "image"],
          "contextWindow": 1048576,
          "maxTokens": 65536,
          "compat": { "supportsStore": false }
        }]
      }
    }
  },
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
      "sandbox": { "mode": "off" },
      "compaction": { "mode": "safeguard" }
    }
  },
  "tools": {
    "profile": "coding",
    "allow": ["group:web", "group:ui", "pdf", "cron"]
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
| Channel tokens (Telegram) | `~/openclaw/.env` (chmod 600) or systemd override | `${TELEGRAM_BOT_TOKEN}` |
| Gateway token | `sudo systemctl edit openclaw` → `Environment="GATEWAY_TOKEN=value"` | `${GATEWAY_TOKEN}` |

After editing systemd overrides: `sudo systemctl daemon-reload && sudo systemctl restart openclaw`

### 9. Security rules

- **Never** store API keys in openclaw.json — use `${VAR_NAME}` references
- **Never** add `SystemCallFilter` in override.conf — causes NAMESPACE errors
- **Never** deny `process` in tools — skills need it to run scripts
- **Always** use `tools.profile: "coding"` with explicit allow list — exclude `gateway` for VPS security
- **Always** use sandbox `"off"` on dedicated VPS with systemd hardening
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
