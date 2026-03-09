# AGENTS.md — OpenClaw VPS Hardening: Agent Knowledge Base

> **For any AI agent** (OpenClaw, Claude Code, Cursor, Copilot, etc.) working with this repository or assisting with deployment. This is the single source of truth for all OpenClaw deployment knowledge discovered through real production use.

---

## What is this project?

OpenClaw VPS Hardening Guide — a bilingual (EN/ES) documentation site that guides users through deploying OpenClaw on a hardened VPS. Built with MkDocs Material and hosted on GitHub Pages.

### Repository structure

```
docs/
  en/          # English documentation (01-preparation through 10-final-checklist)
  es/          # Spanish documentation (mirrors EN exactly)
scripts/
  harden.sh          # VPS hardening automation (sections 3-4)
  install-openclaw.sh # OpenClaw installation automation (section 5)
  verify-hardening.sh # Security compliance checker
  setup.sh            # Master script (harden + install)
mkdocs.yml           # MkDocs configuration with i18n
AGENTS.md            # This file — agent knowledge base
CLAUDE.md            # Claude Code pointer (references this file)
```

---

## Reference deployment

- **Provider**: Hetzner (any VPS provider works)
- **OS**: Ubuntu 24.04
- **User**: `openclaw` (dedicated non-root user)
- **Access**: Tailscale only (no public SSH)
- **OpenClaw version**: 2026.3.x
- **Primary model**: kimi-coding/kimi-for-coding (subscription)
- **Fallback model**: google/gemini-2.5-flash (free tier + web_search)
- **Google Gemini API**: `openai-completions` with baseUrl `https://generativelanguage.googleapis.com/v1beta/openai` and `compat.supportsStore: false`
- **Channels**: Telegram with allowlist
- **Email**: Gmail with app password via himalaya skill

---

## Deployment flow (step by step)

Step-by-step reference for an AI agent assisting a user with OpenClaw deployment on a fresh VPS.

1. **Provision VPS** — User creates Hetzner CPX22 (or equivalent), Ubuntu 24.04, pasting cloud-init from section 02 during creation.
2. **First SSH** — User connects as `root` via public IP, downloads `harden.sh` and `install-openclaw.sh` from this repo.
3. **Run harden.sh** — Executes sections 3-4: creates `openclaw` user, hardens SSH, configures UFW, installs Tailscale.
4. **Approve Tailscale** — User opens the auth URL printed by the script and approves the node in the Tailscale admin console.
5. **Reconnect via Tailscale** — User disconnects public SSH, reconnects as `openclaw@<tailscale-ip>`. Disable public SSH in Hetzner firewall.
6. **Run install-openclaw.sh** — Executes section 5: installs OpenClaw, generates `openclaw.json`, creates systemd unit.
7. **Configure API keys** — Create `/etc/openclaw/env` with all secrets (see Required env vars below). Add `EnvironmentFile=/etc/openclaw/env` to the systemd override.
8. **Start service** — `sudo systemctl start openclaw && sudo journalctl -u openclaw -f` — verify clean startup, no auth errors.
9. **Test Telegram** — If Telegram channel configured, send a test message to the bot and confirm response.
10. **Run verification** — Execute the final checklist script or manually walk through section 10.

---

## Self-configuration checklist

When asked to configure or verify a deployment, follow these steps in order:

### 1. Verify environment

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

### 2. Verify API keys

All secrets must be in `/etc/openclaw/env` (mode `600`, `root:openclaw`), loaded via `EnvironmentFile=` in the systemd override:

```bash
# Check if override exists with EnvironmentFile
cat /etc/systemd/system/openclaw.service.d/override.conf 2>/dev/null

# Check if env file exists with correct permissions
sudo ls -la /etc/openclaw/env
```

If API keys are missing, guide the user:
```bash
# Create the env file
sudo mkdir -p /etc/openclaw
sudo nano /etc/openclaw/env
# Add: KIMI_API_KEY=sk-...
# Add: GOOGLE_API_KEY=...
# Add: GEMINI_API_KEY=...  (same value as GOOGLE_API_KEY)
# Add: GATEWAY_TOKEN=...
# Add: TELEGRAM_BOT_TOKEN=...  (if using Telegram)

sudo chmod 600 /etc/openclaw/env
sudo chown root:openclaw /etc/openclaw/env

# Add EnvironmentFile to systemd override
sudo systemctl edit openclaw
# Add:
#   [Service]
#   EnvironmentFile=/etc/openclaw/env
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
| 53   | UDP+TCP  | DNS (UDP primary, TCP fallback) |

Test connectivity:
```bash
nc -zv smtp.gmail.com 587 -w 5
nc -zv imap.gmail.com 993 -w 5
```

---

## Recommended openclaw.json

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

---

## OpenClaw configuration facts (verified v2026.3.x)

These are field-tested, not theoretical. Discovered through real production deployment.

### Sandbox & architecture
- **Sandbox**: Use `"off"` for dedicated single-user VPS (bare-metal approach — no Docker needed). Use `"all"` only for shared/multi-user servers (requires Docker, env vars don't pass through). The VPS itself functions as the sandbox when protected by Tailscale + exec-approvals + sudoers
- **No Docker**: Architectural decision — dedicated VPS + Tailscale eliminates multi-tenancy/network risks. Docker adds operational complexity without security benefit in this threat model

### Skills
- **Skills install path**: `npx playbooks add skill` installs to `~/.agents/skills/<skill-name>/` (global scope), NOT `~/.openclaw/skills/`
- **Skills auto-discover** from `~/.agents/skills/`, `~/.openclaw/skills/`, and `<workspace>/skills/` — no `skills` section needed in `openclaw.json`
- **Skills require `npm install`**: OpenClaw marks skills "ready" based on SKILL.md presence, but does NOT auto-install npm dependencies
- **Verify skill paths**: Always run `find /home/openclaw -name "SKILL.md" -path "*<skill-name>*"` to confirm

### Secrets & auth
- **Secrets CLI**: `openclaw secrets configure` (interactive wizard), `openclaw secrets audit`, `openclaw secrets reload` — there is NO `openclaw secrets set` command
- **Secrets storage**: Store ALL API keys and tokens in `/etc/openclaw/env` (mode `600`, `root:openclaw`), loaded via `EnvironmentFile=` in the systemd override. NOT in `.bashrc`, `~/.openclaw/.env`, or plaintext in `openclaw.json`. Reference with `${VAR_NAME}`
- **Google Gemini requires two env vars**: Both `GOOGLE_API_KEY` and `GEMINI_API_KEY` must be set (same value). `GOOGLE_API_KEY` for LLM completions, `GEMINI_API_KEY` for web search/grounding
- **`auth-profiles.json`**: `~/.openclaw/agents/main/agent/auth-profiles.json` overrides env vars — if it has a stale key, it blocks auth even with correct systemd env vars. Fix: `echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json`

### Config structure
- **dmPolicy**: Use `"allowlist"` with `allowFrom` to restrict access. `"pairing"` ignores `allowFrom`
- **SOUL.md path**: Must be in the workspace dir from `agents.defaults.workspace` (e.g., `~/openclaw/workspace/SOUL.md`), NOT in `~/.openclaw/workspace/`
- **Root-level keys**: `sandbox`, `dmPolicy`, `security`, `tools.blocked` at root level are NOT recognized — they go inside `agents.defaults` or per-channel config
- **Tools config**: Use `profile: "full"` with `deny: ["gateway"]`. The `coding` profile has a bug where `web_search` doesn't enable correctly. Do NOT deny `process` — skills need it. The correct Telegram streaming field is `streaming` (NOT `streamMode`)
- **Invalid schema fields**: `sendOptions`, `requestOptions`, `passthrough`, `extraBody`, `streamMode` — all cause "Config invalid" errors

### Systemd hardening
- **SystemCallFilter**: Disabled (reset via `SystemCallFilter=` in override.conf) for sudo/apt compatibility. Only `SystemCallArchitectures=native` remains in base service. Security enforced by exec-approvals + sudoers instead
- **Systemd hardening (moderate)**: Base service + override.conf pattern. Override resets `SystemCallFilter=` (empty), sets `CapabilityBoundingSet=CAP_SETUID CAP_SETGID CAP_AUDIT_WRITE CAP_CHOWN CAP_DAC_OVERRIDE CAP_FOWNER`, `ProtectSystem=false`, `PrivateDevices/LockPersonality/RestrictRealtime/ProtectKernelTunables/ProtectKernelModules=false`. With `ProtectSystem=false` and `ProtectHome=false`, ReadWritePaths are unnecessary. Only `PrivateTmp=true` remains. API keys stored in `/etc/openclaw/env` (mode `600`, `root:openclaw`) loaded via `EnvironmentFile=` — keys never appear in `systemctl show` output
- **daemon-reload is mandatory**: Between `systemctl edit` and restart — without it, env var changes are NOT applied
- **Service name**: The systemd service is `openclaw.service`, NOT `openclaw-gateway.service`

### Model compatibility
- **Kimi Coding**: `kimi-coding/kimi-for-coding` requires `User-Agent: claude-code/0.1.0` header, `reasoning: false`, and baseUrl without trailing slash (`https://api.kimi.com/coding`)
- **Gemini**: `google/gemini-2.5-flash` requires `compat.supportsStore: false`
- **Moonshot ≠ Kimi Coding**: Separate providers with different API keys (`MOONSHOT_API_KEY` vs `KIMI_API_KEY`) and endpoints

### Execution control
- **Execution approvals**: `~/.openclaw/exec-approvals.json` — schema v1 with `socket` (path + auto-generated token), `agents.main.allowlist` with `{ "pattern": "/usr/bin/..." }` entries (absolute paths, glob supported). 44 auto-approved patterns including `/usr/local/bin/safe-apt-install` and `/usr/local/bin/safe-systemctl` (NOT raw `/usr/bin/sudo`). Destructive commands (`rm`, `kill`, `chmod`, `ssh`) require Telegram approval. `su`, `dd`, `reboot` never allowed
- **Restricted sudo**: `/etc/sudoers.d/openclaw` with `NOPASSWD` for wrapper scripts only: `safe-apt-install` (validates packages against allowlist of ~230 trusted packages), `safe-systemctl` (validates service name against allowlist of ~12 services), `apt-get update`, `pip3 install`. Raw `sudo apt-get install` is NOT allowed — must go through safe-apt-install wrapper
- **safe-apt-install**: `/usr/local/bin/safe-apt-install` — validates each package against a curated allowlist of ~230 packages from official Ubuntu repos (images, PDF, email, fonts, dev tools, etc.). Rejects unknown packages, flags, and version specifiers. Edit the script to add new packages
- **safe-systemctl**: `/usr/local/bin/safe-systemctl` — only allows actions (restart/start/stop/status/enable/disable/reload) on approved services (openclaw, tailscaled, ssh, fail2ban, auditd, docker, cron, etc.)

### Web search
- **web_search**: Requires `GEMINI_API_KEY` env var (auto-detect) or explicit `tools.web.search.provider` config. Detection order: Brave → Gemini → Kimi → Perplexity → Grok
- **web_search config**: Needs 3 fields: `enabled: true`, `gemini.model` explicit, `fetch.enabled: true`
- **web_search apiKey**: Must be nested under provider: `gemini.apiKey`, NOT `search.apiKey`

### Dangerous commands
- **`openclaw doctor --fix`**: Do NOT run after manual config — it overwrites provider settings (especially Kimi) with broken defaults
- **Hetzner Cloud Firewall**: Must include outbound TCP 587 (SMTP), TCP 993 (IMAP), UDP 3478 (STUN), TCP 53 (DNS fallback) in addition to 443, 80, 41641, UDP 53

---

## Config precedence (important for debugging)

```
auth-profiles.json > process.env (systemd/EnvironmentFile) > ~/.openclaw/.env > openclaw.json env.vars
```

Our guide centralizes all secrets in `/etc/openclaw/env` (loaded via `EnvironmentFile=-/etc/openclaw/env` in the base systemd service — no override needed), so they arrive as process.env — second highest priority. The `-` prefix means the service won't fail if the file doesn't exist yet.

If auth fails despite correct env vars, check `~/.openclaw/agents/main/agent/auth-profiles.json` for stale keys.

---

## Required env vars

| Variable | Where | Purpose |
|---|---|---|
| `KIMI_API_KEY` | `/etc/openclaw/env` | Kimi Coding LLM (primary model) |
| `GOOGLE_API_KEY` | `/etc/openclaw/env` | Google Gemini LLM completions |
| `GEMINI_API_KEY` | `/etc/openclaw/env` | Gemini web search/grounding (same value as GOOGLE_API_KEY) |
| `GATEWAY_TOKEN` | `/etc/openclaw/env` | OpenClaw gateway authentication |
| `TELEGRAM_BOT_TOKEN` | `/etc/openclaw/env` | Telegram channel (if configured) |

---

## Model selection guide

| Model | Provider | Tool calls | Cost | Best for |
|-------|----------|-----------|------|----------|
| `moonshot/kimi-k2.5` | Moonshot | Yes | Free tier | General assistant, coding |
| `google/gemini-2.5-flash` | Google | Yes | Free tier | Fast responses, large context (1M tokens) |
| `kimi-coding/kimi-for-coding` | Kimi Code | Limited | Subscription | Coding tasks (tool calls may fail with reasoning enabled) |

To switch models, change `agents.defaults.model.primary` and restart:
```bash
sudo systemctl restart openclaw
```

---

## Skills installation

```bash
# Install a skill
npx playbooks add skill openclaw/skills --skill <name>

# IMPORTANT: always install npm dependencies after
cd ~/.agents/skills/<name> && npm install

# Verify installation
openclaw skills list
```

Skills auto-discover from `~/.agents/skills/`. No config needed in openclaw.json.

---

## Email setup (himalaya)

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

---

## Execution approvals (exec-approvals.json)

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
        { "pattern": "/usr/local/bin/*" },
        { "pattern": "/usr/bin/sudo" }
      ]
    }
  }
}
```

`sudo` is in the allowlist but restricted by OS sudoers (`/etc/sudoers.d/openclaw`) to only: `apt install`, `apt update`, `pip3 install`, `systemctl restart/start/stop/status/enable/disable`.

Commands not in the allowlist (`rm`, `kill`, `chmod`, `ssh`, `scp`) require approval via Telegram. Commands like `su`, `dd`, `reboot` are never allowed (not in any list).

---

## Security rules

- **Never** store API keys in openclaw.json — use `${VAR_NAME}` references
- **Never** add `SystemCallFilter` in override.conf — causes NAMESPACE errors
- **Never** deny `process` in tools — skills need it to run scripts
- **Never** run `openclaw doctor --fix` after manual config — it overwrites provider settings
- **Always** use `tools.profile: "full"` with `deny: ["gateway"]` — `coding` profile has a bug where `web_search` doesn't enable correctly
- **Always** use sandbox `"off"` on dedicated VPS with systemd hardening
- **Always** configure `exec-approvals.json` with `security: "allowlist"` — prevents uncontrolled command execution
- **Always** create `/etc/sudoers.d/openclaw` to restrict `sudo` to apt, pip3, systemctl only
- **Always** restart after config changes: `sudo systemctl daemon-reload && sudo systemctl restart openclaw`

---

## Quick diagnostic commands

```bash
# Service status and recent logs
sudo systemctl status openclaw
sudo journalctl -u openclaw -n 50 --no-pager

# Live log stream (use during startup/testing)
sudo journalctl -u openclaw -f

# Check effective env vars reaching the process
sudo cat /proc/$(pidof openclaw)/environ | tr '\0' '\n' | sort

# Verify config files
cat ~/.openclaw/openclaw.json | jq .
cat ~/.openclaw/agents/main/agent/auth-profiles.json

# Reset stale auth profiles
echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json

# Restart after config changes
sudo systemctl daemon-reload && sudo systemctl restart openclaw

# Verify systemd hardening
sudo systemctl show openclaw | grep -E 'ProtectHome|ProtectSystem|NoNewPrivileges'

# Tailscale connectivity
tailscale status
tailscale ping <peer>

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

---

## Documentation

The full hardening guide is in this repository:
- English: `docs/en/` (sections 01 through 10)
- Spanish: `docs/es/` (mirrors EN exactly)

Refer to `docs/en/05-openclaw.md` (or `docs/es/05-openclaw.md`) for the complete installation and configuration guide.
