#!/bin/bash
# =============================================================================
# OpenClaw Installation Script (Section 5)
# Installs Node.js 22, OpenClaw, configures security, and creates systemd service.
# Run this AFTER harden.sh (sections 3-4) as the openclaw user (NOT root).
#
# Usage:
#   curl -fsSL -o /tmp/install-openclaw.sh \
#     https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/install-openclaw.sh
#   less /tmp/install-openclaw.sh
#   bash /tmp/install-openclaw.sh
#
# NOTE: This script must be run as the openclaw user, NOT as root.
# =============================================================================

set -euo pipefail

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }
ask()   { echo -e "${CYAN}[INPUT]${NC} $1"; }

# --- Pre-checks ---
if [ "$(id -u)" -eq 0 ]; then
    error "Do NOT run this script as root. Run as the openclaw user."
    exit 1
fi

if [ "$(whoami)" != "openclaw" ]; then
    warn "Expected user 'openclaw', running as '$(whoami)'. Continuing..."
fi

echo ""
echo "========================================================"
echo "  OpenClaw Installation Script (Section 5)"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================"
echo ""

# =============================================================================
# 5.1 Install Node.js 22 via nvm
# =============================================================================

info "=== Installing Node.js 22 via nvm ==="

if command -v node &>/dev/null && [[ "$(node --version)" == v22* ]]; then
    info "Node.js 22 already installed: $(node --version)"
else
    info "Installing nvm..."
    curl -fsSL -o /tmp/nvm-install.sh https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh
    bash /tmp/nvm-install.sh
    rm /tmp/nvm-install.sh

    # Load nvm into current shell
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    info "Installing Node.js 22..."
    nvm install 22
    nvm alias default 22
    info "Node.js $(node --version) installed."
fi

# Ensure nvm is loaded
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

# =============================================================================
# 5.2 Install OpenClaw
# =============================================================================

info "=== Installing OpenClaw ==="

if command -v openclaw &>/dev/null; then
    info "OpenClaw already installed: $(openclaw --version 2>/dev/null || echo 'unknown')"
    ask "Reinstall/upgrade? (y/N): "
    read -r REINSTALL
    if [[ "$REINSTALL" =~ ^[Yy]$ ]]; then
        npm install -g openclaw@latest
    fi
else
    npm install -g openclaw@latest
fi

info "OpenClaw version: $(openclaw --version 2>/dev/null || echo 'installed')"

# =============================================================================
# 5.2b Install Docker (required for sandbox mode)
# =============================================================================

info "=== Installing Docker (for sandbox isolation) ==="

if command -v docker &>/dev/null; then
    info "Docker already installed: $(docker --version)"
else
    info "Installing Docker..."
    sudo apt-get install -y docker.io
    info "Docker installed."
fi

# Add openclaw user to docker group
if id -nG openclaw | grep -qw docker; then
    info "User openclaw already in docker group."
else
    sudo usermod -aG docker openclaw
    info "Added openclaw to docker group."
    warn "Docker group will take effect after next login or service restart."
fi

# =============================================================================
# 5.3 Create directory structure
# =============================================================================

info "=== Creating directory structure ==="

mkdir -p ~/openclaw/{workspace,logs,scripts}
mkdir -p ~/.openclaw/workspace

# =============================================================================
# 5.4 Configure provider
# =============================================================================

echo ""
echo "========================================================"
echo "  MODEL PROVIDER SELECTION"
echo "========================================================"
echo ""
echo "  1) Kimi Code (Moonshot AI) — subscription"
echo "  2) Anthropic — API key"
echo "  3) OpenAI — API key"
echo "  4) Skip (configure manually later)"
echo ""
ask "Select provider [1-4]: "
read -r PROVIDER_CHOICE

case "$PROVIDER_CHOICE" in
    1)
        PROVIDER="kimi-coding"
        PROVIDER_NAME="Kimi for Coding"
        MODEL_ID="kimi-for-coding"
        MODEL_PRIMARY="kimi-coding/kimi-for-coding"
        MODEL_JSON='{ "primary": "kimi-coding/kimi-for-coding", "fallbacks": ["google/gemini-2.5-flash"] }'
        AUTH_MODE="api_key"
        PROVIDER_CONFIG=$(cat <<'PCONF'
    "providers": {
      "kimi-coding": {
        "baseUrl": "https://api.kimi.com/coding",
        "api": "anthropic-messages",
        "headers": { "User-Agent": "claude-code/0.1.0" },
        "models": [
          {
            "id": "kimi-for-coding",
            "name": "Kimi for Coding",
            "reasoning": false,
            "input": ["text"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 262144,
            "maxTokens": 32768
          }
        ]
      },
      "google": {
        "models": [
          {
            "id": "gemini-2.5-flash",
            "name": "Gemini 2.5 Flash",
            "maxTokens": 65536
          }
        ]
      }
    }
PCONF
        )
        info "Selected: Kimi Code (kimi-for-coding)"
        info "You'll need to run 'openclaw onboard' after to enter your API key,"
        info "or set it manually with 'openclaw models auth add'."
        ;;
    2)
        PROVIDER="anthropic"
        PROVIDER_NAME="Claude"
        MODEL_ID="claude-sonnet-4-5-20250514"
        MODEL_PRIMARY="anthropic/claude-sonnet-4-5-20250514"
        MODEL_JSON='{ "primary": "anthropic/claude-sonnet-4-5-20250514" }'
        AUTH_MODE="api_key"
        PROVIDER_CONFIG='"providers": {}'
        info "Selected: Anthropic. Run 'openclaw models auth add' after to set your API key."
        ;;
    3)
        PROVIDER="openai"
        PROVIDER_NAME="GPT"
        MODEL_ID="gpt-4o"
        MODEL_PRIMARY="openai/gpt-4o"
        MODEL_JSON='{ "primary": "openai/gpt-4o" }'
        AUTH_MODE="api_key"
        PROVIDER_CONFIG='"providers": {}'
        info "Selected: OpenAI. Run 'openclaw models auth add' after to set your API key."
        ;;
    4)
        PROVIDER="none"
        MODEL_PRIMARY="change-me/model"
        MODEL_JSON='{ "primary": "change-me/model" }'
        PROVIDER_CONFIG='"providers": {}'
        info "Skipped. Configure manually with 'openclaw configure' or edit ~/.openclaw/openclaw.json"
        ;;
    *)
        error "Invalid selection. Defaulting to skip."
        PROVIDER="none"
        MODEL_PRIMARY="change-me/model"
        MODEL_JSON='{ "primary": "change-me/model" }'
        PROVIDER_CONFIG='"providers": {}'
        ;;
esac

# =============================================================================
# 5.4b Configure Telegram channel (optional)
# =============================================================================

echo ""
echo "========================================================"
echo "  TELEGRAM CHANNEL (optional)"
echo "========================================================"
echo ""
echo "  To connect Telegram, you need a bot token from @BotFather."
echo "  1) Open Telegram → search @BotFather"
echo "  2) Send /newbot → follow prompts"
echo "  3) Copy the token (format: 123456789:ABCdef...)"
echo ""
ask "Enter Telegram bot token (or press Enter to skip): "
read -r TELEGRAM_TOKEN

if [ -n "$TELEGRAM_TOKEN" ]; then
    echo ""
    ask "Enter your Telegram user ID (send a message to @raw_data_bot to find it, or press Enter to skip): "
    read -r TELEGRAM_USER_ID

    if [ -n "$TELEGRAM_USER_ID" ]; then
        TELEGRAM_DM_POLICY="allowlist"
        ALLOW_FROM="\"allowFrom\": [\"${TELEGRAM_USER_ID}\"],"
        info "Telegram will be restricted to your account only (allowlist mode)."
    else
        TELEGRAM_DM_POLICY="pairing"
        ALLOW_FROM=""
        warn "No user ID set — using pairing mode. After first message, approve with:"
        warn "  openclaw pairing approve telegram <CODE>"
        warn "Then switch to dmPolicy: allowlist in ~/.openclaw/openclaw.json"
    fi

    CHANNELS_CONFIG=$(cat <<CHCONF
  "channels": {
    "telegram": {
      "enabled": true,
      "botToken": "${TELEGRAM_TOKEN}",
      "dmPolicy": "${TELEGRAM_DM_POLICY}",
      ${ALLOW_FROM}
      "streaming": "partial",
      "groupPolicy": "allowlist"
    }
  },
CHCONF
    )
    info "Telegram configured with dmPolicy: ${TELEGRAM_DM_POLICY}"
else
    CHANNELS_CONFIG=""
    info "Skipped. Add Telegram later by editing ~/.openclaw/openclaw.json"
fi

# =============================================================================
# 5.5 Generate gateway token
# =============================================================================

GATEWAY_TOKEN=$(openssl rand -hex 24)
info "Generated gateway token."

# =============================================================================
# 5.6 Write openclaw.json (hardened)
# =============================================================================

info "=== Writing hardened openclaw.json ==="

cat > ~/.openclaw/openclaw.json << OCEOF
{
  ${CHANNELS_CONFIG}
  "auth": {
    "profiles": {
      "${PROVIDER}:default": {
        "provider": "${PROVIDER}",
        "mode": "${AUTH_MODE:-api_key}"
      }$(if [ "${PROVIDER}" = "kimi-coding" ]; then echo ',
      "google:default": {
        "provider": "google",
        "mode": "api_key"
      }'; fi)
    }
  },
  "models": {
    "mode": "merge",
    ${PROVIDER_CONFIG}
  },
  "agents": {
    "defaults": {
      "model": ${MODEL_JSON},
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "off"
      },
      "compaction": {
        "mode": "safeguard"
      },
      "maxConcurrent": 1,
      "subagents": {
        "maxConcurrent": 3
      }
    }
  },
  "tools": {
    "profile": "full",
    "deny": ["gateway"]$(if [ "${PROVIDER}" = "kimi-coding" ]; then echo ',
    "web": {
      "search": {
        "enabled": true,
        "provider": "gemini",
        "gemini": {
          "apiKey": "\${GEMINI_API_KEY}",
          "model": "gemini-2.5-flash"
        }
      },
      "fetch": { "enabled": true }
    }'; fi)
  },
  "messages": {
    "ackReactionScope": "group-mentions"
  },
  "commands": {
    "native": "auto",
    "nativeSkills": "auto",
    "restart": true,
    "ownerDisplay": "raw"
  },
  "approvals": {
    "exec": {
      "enabled": true,
      "mode": "session",
      "targets": [$(if [ -n "${TELEGRAM_USER_ID:-}" ]; then echo "
        { \"channel\": \"telegram\", \"to\": \"${TELEGRAM_USER_ID}\" }"; else echo ""; fi)
      ]
    }
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
      "mode": "off",
      "resetOnExit": false
    },
    "nodes": {}
  },
  "meta": {
    "lastTouchedVersion": "$(openclaw --version 2>/dev/null || echo '2026.3.x')",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  }
}
OCEOF

# =============================================================================
# 5.6b Write exec-approvals.json (execution approval rules)
# =============================================================================

info "=== Writing exec-approvals.json (allowlist mode) ==="

EXEC_APPROVALS_TOKEN=$(openssl rand -hex 24)

cat > ~/.openclaw/exec-approvals.json << EAEOF
{
  "version": 1,
  "socket": {
    "path": "/home/openclaw/.openclaw/exec-approvals.sock",
    "token": "${EXEC_APPROVALS_TOKEN}"
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
EAEOF

# =============================================================================
# 5.7 Set file permissions
# =============================================================================

info "=== Setting file permissions ==="

chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/*.json 2>/dev/null || true
chmod 600 ~/.openclaw/.env 2>/dev/null || true

# =============================================================================
# 5.8 Configure SOUL.md
# =============================================================================

info "=== Creating SOUL.md ==="

cat > ~/openclaw/workspace/SOUL.md << 'SOUL'
# OpenClaw Assistant

## Identity
You are a development, business, and automation assistant operating on an isolated VPS.
You work for the owner of this instance — follow their instructions and act in their best interest.

## Language
- Respond to the owner in their preferred language (ask on first interaction if unclear)
- Write code, comments, commit messages, and documentation in English
- Business communications (emails, proposals) match the recipient's language

## Capabilities
- Software development: architecture, coding, debugging, code review, documentation
- Business: draft emails, proposals, CRM management, client research, outreach
- Research: web search, document analysis, competitive analysis, market research
- Automation: scripts, workflows, data processing, report generation

## Strict behavior limits

### Filesystem
- Only access files within `/home/openclaw/openclaw/workspace`
- Do not delete files recursively (rm -rf)
- Do not modify system file permissions
- Do not access `/home/openclaw/.ssh`, `/home/openclaw/.env`, `/etc`, `/var`

### Execution
- Do not execute commands as root/sudo
- Do not install software without explicit approval
- Do not modify system configuration

### Communication
- Do not send emails without explicit owner confirmation (always show draft first)
- Do not make commits/push to repositories without review
- Do not call APIs not included in the allowlist
- Do not contact anyone on behalf of the owner without approval

### Sensitive data
- Do not expose API keys, tokens, or credentials in responses
- Do not store sensitive information in logs
- Redact any secrets that appear in outputs
- Do not share owner's personal information unless instructed

## Tone
Professional, concise, direct. Avoid filler. Lead with the answer, not the reasoning.
SOUL

# =============================================================================
# 5.9 Create systemd service (requires sudo)
# =============================================================================

info "=== Creating systemd service (requires sudo) ==="

# Find the correct openclaw binary path
OPENCLAW_BIN=$(which openclaw 2>/dev/null || echo "/home/openclaw/.nvm/versions/node/v22/bin/openclaw")
NODE_BIN=$(which node 2>/dev/null || echo "/home/openclaw/.nvm/versions/node/v22/bin/node")
NODE_PATH=$(dirname "$NODE_BIN")

sudo tee /etc/systemd/system/openclaw.service > /dev/null << SVCEOF
# ============================================================
# OpenClaw Systemd Service - With Complete Hardening
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
Environment=PATH=${NODE_PATH}:/usr/local/bin:/usr/bin:/bin
Environment=NVM_DIR=/home/openclaw/.nvm
Environment=NODE_COMPILE_CACHE=/var/tmp/openclaw-compile-cache
Environment=OPENCLAW_NO_RESPAWN=1

ExecStart=${OPENCLAW_BIN} gateway --port 18789
Restart=on-failure
RestartSec=10

# === SYSTEMD HARDENING ===
# Bare-metal approach: dedicated VPS + Tailscale VPN, no Docker needed.
# Security enforced by exec-approvals allowlist + OS sudoers instead of
# systemd privilege restrictions.

# Filesystem isolation
ProtectSystem=false
ProtectHome=read-only
ReadWritePaths=/home/openclaw/openclaw/workspace
ReadWritePaths=/home/openclaw/openclaw/logs
ReadWritePaths=/home/openclaw/.openclaw
ReadWritePaths=/var/tmp/openclaw-compile-cache
ReadWritePaths=/var/cache/apt
ReadWritePaths=/var/lib/apt
ReadWritePaths=/var/lib/apt/lists
ReadWritePaths=/var/lib/dpkg
ReadWritePaths=/var/log/apt
ReadWritePaths=/tmp
PrivateTmp=true

# Privilege control — relaxed for restricted sudo (see /etc/sudoers.d/openclaw)
# NOTE: PrivateDevices, LockPersonality, RestrictRealtime implicitly force
# NoNewPrivileges=true, so they must also be false for sudo to work
NoNewPrivileges=false
CapabilityBoundingSet=CAP_SETUID CAP_SETGID CAP_DAC_OVERRIDE CAP_FOWNER
AmbientCapabilities=
RestrictSUIDSGID=false
PrivateDevices=false
LockPersonality=false
RestrictRealtime=false

# Network restrictions
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX AF_NETLINK

# Syscall filtering — disabled for sudo/apt compatibility on dedicated VPS
# Security enforced by exec-approvals + sudoers instead
SystemCallArchitectures=native

# Kernel protection (relaxed for apt/dpkg)
ProtectKernelTunables=false
ProtectKernelModules=false
ProtectKernelLogs=true
ProtectControlGroups=true
ProtectHostname=true
ProtectClock=true

# === Resource limits ===
CPUQuota=50%
MemoryMax=2G
TasksMax=100

# === Logging ===
StandardOutput=journal
StandardError=journal
SyslogIdentifier=openclaw

[Install]
WantedBy=multi-user.target
SVCEOF

mkdir -p /var/tmp/openclaw-compile-cache

sudo systemctl daemon-reload
sudo systemctl enable openclaw

info "systemd service created and enabled."

# =============================================================================
# 5.10 Create AIDE cron for openclaw paths
# =============================================================================

info "=== Adding OpenClaw audit rules ==="

# Add openclaw-specific audit rules (if auditd is running)
if systemctl is-active auditd &>/dev/null; then
    sudo tee /etc/audit/rules.d/openclaw-app.rules > /dev/null << 'AUDIT'
-w /home/openclaw/openclaw -p wa -k openclaw_changes
-w /home/openclaw/.openclaw/.env -p r -k env_access
AUDIT
    sudo augenrules --load 2>/dev/null || true
fi

# =============================================================================
# 5.11 Configure restricted sudo (sudoers)
# =============================================================================

info "=== Configuring restricted sudo ==="

echo 'openclaw ALL=(ALL) NOPASSWD: /usr/bin/apt-get install *, /usr/bin/apt install *, /usr/bin/apt-get update, /usr/bin/apt update, /usr/bin/pip3 install *, /usr/bin/systemctl restart *, /usr/bin/systemctl status *, /usr/bin/systemctl start *, /usr/bin/systemctl stop *, /usr/bin/systemctl enable *, /usr/bin/systemctl disable *' \
  | sudo tee /etc/sudoers.d/openclaw > /dev/null \
  && sudo chmod 0440 /etc/sudoers.d/openclaw

info "Restricted sudo configured: apt, pip3, systemctl only."

# =============================================================================
# SUMMARY
# =============================================================================

echo ""
echo "========================================================"
echo "  OPENCLAW INSTALLATION COMPLETE"
echo "========================================================"
echo ""
echo "  Version:        $(openclaw --version 2>/dev/null || echo 'installed')"
echo "  Config:         ~/.openclaw/openclaw.json"
echo "  Workspace:      ~/openclaw/workspace"
echo "  Gateway:        127.0.0.1:18789"
echo "  Gateway token:  ${GATEWAY_TOKEN}"
echo "  Sandbox:        off (systemd hardening provides isolation)"
echo "  Docker:         $(docker --version 2>/dev/null || echo 'not found')"
echo "  Bind:           loopback only"
echo "  Tools:          full (gateway denied)"
echo "  Exec approvals: allowlist (44 patterns + sudo restricted)"
echo "  Sudo:           restricted (apt, pip3, systemctl only)"
if [ -n "$TELEGRAM_TOKEN" ]; then
echo "  Telegram:       configured (dmPolicy: ${TELEGRAM_DM_POLICY})"
fi
echo ""
echo "  SAVE YOUR GATEWAY TOKEN — you'll need it for remote access."
echo ""
echo "  NEXT STEPS:"
if [ "${PROVIDER}" = "kimi-coding" ]; then
echo "  1. Configure API keys via systemd override:"
echo "     sudo systemctl edit openclaw"
echo "     # Add under [Service]:"
echo "     #   Environment=\"KIMI_API_KEY=your-key\""
echo "     #   Environment=\"GOOGLE_API_KEY=your-key\""
echo "     #   Environment=\"GEMINI_API_KEY=your-google-key\"  # same as GOOGLE_API_KEY"
else
echo "  1. Configure your API key:"
echo "     openclaw models auth add"
fi
echo "  2. Start the service:"
echo "     sudo systemctl start openclaw"
echo "  3. Check status (wait ~2 min for gateway to start):"
echo "     sudo systemctl status openclaw"
echo "  4. Access from your Mac (via SSH tunnel):"
echo "     ssh -L 18789:127.0.0.1:18789 openclaw@<TAILSCALE_IP>"
echo "     Then open: http://127.0.0.1:18789/?#token=\${GATEWAY_TOKEN}"
if [ -n "$TELEGRAM_TOKEN" ]; then
echo "  5. Send a message to your bot in Telegram"
echo "     Then approve pairing: openclaw pairing approve telegram <CODE>"
echo "  6. Run security audit:"
else
echo "  5. Run security audit:"
fi
echo "     openclaw security audit"
echo ""
echo "  To view logs:"
echo "     sudo journalctl -u openclaw -f"
echo ""
echo "========================================================"
