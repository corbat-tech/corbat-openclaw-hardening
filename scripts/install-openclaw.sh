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
        MODEL_ID="k2p5"
        MODEL_PRIMARY="kimi-coding/k2p5"
        AUTH_MODE="api_key"
        PROVIDER_CONFIG=$(cat <<'PCONF'
    "providers": {
      "kimi-coding": {
        "baseUrl": "https://api.kimi.com/coding/",
        "api": "anthropic-messages",
        "models": [
          {
            "id": "k2p5",
            "name": "Kimi for Coding",
            "reasoning": true,
            "input": ["text", "image"],
            "cost": { "input": 0, "output": 0, "cacheRead": 0, "cacheWrite": 0 },
            "contextWindow": 262144,
            "maxTokens": 32768
          }
        ]
      }
    }
PCONF
        )
        info "Selected: Kimi Code (k2p5)"
        info "You'll need to run 'openclaw onboard' after to enter your API key,"
        info "or set it manually with 'openclaw models auth add'."
        ;;
    2)
        PROVIDER="anthropic"
        PROVIDER_NAME="Claude"
        MODEL_ID="claude-sonnet-4-5-20250514"
        MODEL_PRIMARY="anthropic/claude-sonnet-4-5-20250514"
        AUTH_MODE="api_key"
        PROVIDER_CONFIG='"providers": {}'
        info "Selected: Anthropic. Run 'openclaw models auth add' after to set your API key."
        ;;
    3)
        PROVIDER="openai"
        PROVIDER_NAME="GPT"
        MODEL_ID="gpt-4o"
        MODEL_PRIMARY="openai/gpt-4o"
        AUTH_MODE="api_key"
        PROVIDER_CONFIG='"providers": {}'
        info "Selected: OpenAI. Run 'openclaw models auth add' after to set your API key."
        ;;
    4)
        PROVIDER="none"
        MODEL_PRIMARY="change-me/model"
        PROVIDER_CONFIG='"providers": {}'
        info "Skipped. Configure manually with 'openclaw configure' or edit ~/.openclaw/openclaw.json"
        ;;
    *)
        error "Invalid selection. Defaulting to skip."
        PROVIDER="none"
        MODEL_PRIMARY="change-me/model"
        PROVIDER_CONFIG='"providers": {}'
        ;;
esac

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
  "auth": {
    "profiles": {
      "${PROVIDER}:default": {
        "provider": "${PROVIDER}",
        "mode": "${AUTH_MODE:-api_key}"
      }
    }
  },
  "models": {
    "mode": "merge",
    ${PROVIDER_CONFIG}
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "${MODEL_PRIMARY}"
      },
      "workspace": "/home/openclaw/openclaw/workspace",
      "sandbox": {
        "mode": "all"
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
    "profile": "messaging"
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
    "nodes": {
      "denyCommands": [
        "camera.snap",
        "camera.clip",
        "screen.record",
        "contacts.add",
        "calendar.add",
        "reminders.add",
        "sms.send"
      ]
    }
  },
  "meta": {
    "lastTouchedVersion": "$(openclaw --version 2>/dev/null || echo '2026.3.x')",
    "lastTouchedAt": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
  }
}
OCEOF

# =============================================================================
# 5.7 Set file permissions
# =============================================================================

info "=== Setting file permissions ==="

chmod 700 ~/.openclaw
chmod 600 ~/.openclaw/*.json 2>/dev/null || true
chmod 600 ~/openclaw/.env 2>/dev/null || true

# =============================================================================
# 5.8 Configure SOUL.md
# =============================================================================

info "=== Creating SOUL.md ==="

cat > ~/.openclaw/workspace/SOUL.md << 'SOUL'
# OpenClaw Assistant

## Identity
You are a development and automation assistant operating on an isolated VPS.

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
- Do not send emails without explicit user confirmation
- Do not make commits/push to repositories without review
- Do not call APIs not included in the allowlist

### Sensitive data
- Do not expose API keys, tokens, or credentials in responses
- Do not store sensitive information in logs
- Redact any secrets that appear in outputs

## Tone
Professional, concise, technical. Respond in English by default.
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
StartLimitBurst=5
StartLimitIntervalSec=300

# === SYSTEMD HARDENING ===
ProtectSystem=strict
ProtectHome=read-only
ReadWritePaths=/home/openclaw/openclaw/workspace
ReadWritePaths=/home/openclaw/openclaw/logs
ReadWritePaths=/home/openclaw/.openclaw
PrivateTmp=true
NoNewPrivileges=true
CapabilityBoundingSet=
AmbientCapabilities=
RestrictAddressFamilies=AF_INET AF_INET6 AF_UNIX
SystemCallFilter=@system-service
SystemCallFilter=~@privileged @resources @mount @clock @reboot @swap @raw-io @cpu-emulation @debug
SystemCallArchitectures=native
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectKernelLogs=true
ProtectControlGroups=true
PrivateDevices=true
ProtectHostname=true
ProtectClock=true
RestrictRealtime=true
RestrictSUIDSGID=true
LockPersonality=true

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
-w /home/openclaw/openclaw/.env -p r -k env_access
AUDIT
    sudo augenrules --load 2>/dev/null || true
fi

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
echo "  Sandbox:        all (fully containerized)"
echo "  Bind:           loopback only"
echo ""
echo "  SAVE YOUR GATEWAY TOKEN — you'll need it for remote access."
echo ""
echo "  NEXT STEPS:"
echo "  1. Configure your API key:"
echo "     openclaw models auth add"
echo "  2. Start the service:"
echo "     sudo systemctl start openclaw"
echo "  3. Check status:"
echo "     sudo systemctl status openclaw"
echo "  4. Access from your Mac (via SSH tunnel):"
echo "     ssh -L 18789:127.0.0.1:18789 openclaw@<TAILSCALE_IP>"
echo "     Then open: http://localhost:18789"
echo "  5. Run security audit:"
echo "     openclaw security audit"
echo ""
echo "  To view logs:"
echo "     sudo journalctl -u openclaw -f"
echo ""
echo "========================================================"
