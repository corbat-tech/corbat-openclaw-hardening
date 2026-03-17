# 9. Maintenance

> **TL;DR**: Regular maintenance procedures to keep the system secure: updates, secret rotation, backups, and continuous monitoring.

> **Estimated time**: Variable (periodic tasks)

> **Required level**: Intermediate

## Prerequisites

- [ ] Sections 1-8 completed
- [ ] System running correctly

## Objectives

This section covers:

- System, Tailscale, and OpenClaw updates
- Periodic rotation of API keys and SSH keys
- Backup strategy
- Continuous monitoring
- Disaster recovery procedure

---

## Maintenance calendar

| Task | Frequency | Criticality |
|------|-----------|-------------|
| Security updates | Automatic (daily) | High |
| Review security logs | Weekly | Medium |
| Configuration backup | Weekly | High |
| Update OpenClaw | Monthly | Medium |
| Rotate API keys | Every 90 days | High |
| Rotate SSH keys | Annual | Medium |
| Review Tailscale ACLs | Quarterly | Medium |
| Update AIDE database | After changes | Medium |
| Disaster recovery test | Semi-annual | High |

---

## System updates

### Automatic updates (already configured)

Security updates are applied automatically thanks to `unattended-upgrades`.

**Verify it's working:**

```bash
# View automatic updates status
sudo systemctl status unattended-upgrades

# View recent update log
cat /var/log/unattended-upgrades/unattended-upgrades.log | tail -50
```

### Canonical Livepatch (kernel patches without reboot)

!!! tip "Recommended: hot kernel patches"
    [Canonical Livepatch](https://ubuntu.com/security/livepatch) applies security patches to the kernel **without needing to reboot**. It complements `unattended-upgrades` (which covers packages but not the running kernel).

```bash
# Activate Livepatch (free for personal use, up to 5 machines)
sudo snap install canonical-livepatch
sudo canonical-livepatch enable <YOUR_TOKEN>
```

Get your token at [ubuntu.com/security/livepatch](https://ubuntu.com/security/livepatch) (login with Ubuntu One).

```bash
# Verify status
sudo canonical-livepatch status --verbose
```

### Manual updates

For complete updates (not just security):

```bash
# Update package list
sudo apt update

# View available updates
apt list --upgradable

# Apply all updates
sudo apt upgrade -y

# Distribution upgrade (with care)
sudo apt dist-upgrade -y

# Clean obsolete packages
sudo apt autoremove -y
```

!!! warning "Reboot if necessary"
    After kernel updates (if not using Livepatch):
    ```bash
    # Check if reboot is pending
    [ -f /var/run/reboot-required ] && echo "Reboot required"

    # Reboot (scheduled)
    sudo shutdown -r +5 "Reboot for updates in 5 minutes"
    ```

---

## Update Tailscale

### Check current version

```bash
tailscale version
```

### Update

```bash
# Update from APT repository
sudo apt update
sudo apt install --only-upgrade tailscale

# Verify new version
tailscale version

# Verify it's still working
tailscale status
```

### After updating

```bash
# Verify tags are still configured
tailscale status | grep tag

# If necessary, re-apply tags
sudo tailscale up --advertise-tags=tag:vps --reset
```

---

## Update OpenClaw

### Backup before updating

```bash
# Backup configuration
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.backup.$(date +%Y%m%d)
sudo cp /etc/openclaw/env /etc/openclaw/env.backup.$(date +%Y%m%d)
```

### Update OpenClaw

```bash
# Check current channel
openclaw update --channel

# Update OpenClaw (stable channel)
npm install -g openclaw@latest

# Or use the native update command
openclaw update

# Verify installed version
openclaw --version

# Restart service
sudo systemctl restart openclaw

# Verify it's working
sudo systemctl status openclaw
```

### Verify after updating

```bash
# Verify version
openclaw --version

# Run full diagnostics
openclaw doctor

# Run security audit
openclaw security audit

# Check logs for errors
sudo journalctl -u openclaw -n 50

# Verify security score (should not worsen)
systemd-analyze security openclaw.service
```

!!! warning "Check release notes before updating"
    OpenClaw v2026.3.x introduced **breaking changes**. Check the [release notes](https://github.com/openclaw/openclaw/releases/) before updating. Always backup your configuration first.

---

## API Key Rotation

!!! danger "Rotate API keys every 90 days"
    API keys are sensitive credentials that should be rotated regularly.

### Rotation procedure

#### 1. Generate new key at the provider

| Provider | URL |
|----------|-----|
| OpenAI | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) |
| Anthropic | [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys) |
| NVIDIA NIM | [build.nvidia.com](https://build.nvidia.com) |

#### 2. Update .env on the VPS

```bash
# Backup current env file
sudo cp /etc/openclaw/env /etc/openclaw/env.backup.$(date +%Y%m%d)

# Edit env file
sudo nano /etc/openclaw/env

# Replace the old key with the new one
# Example: ANTHROPIC_API_KEY=sk-ant-NEW_KEY_HERE
```

#### 3. Restart service

```bash
sudo systemctl restart openclaw
```

#### 4. Verify operation

```bash
# Check logs to confirm it connects correctly
sudo journalctl -u openclaw -n 20

# Make a test request if possible
```

#### 5. Revoke old key

!!! warning "Only after verifying the new one works"
    Go back to the provider's panel and delete/revoke the old key.

### Reminder script

```bash
mkdir -p ~/openclaw/scripts
nano ~/openclaw/scripts/key_rotation_reminder.sh
```

```bash
#!/bin/bash
# API key rotation reminder

LAST_ROTATION_FILE="$HOME/.openclaw/.last_key_rotation"
MAX_DAYS=90

if [ -f "$LAST_ROTATION_FILE" ]; then
    LAST_DATE=$(cat "$LAST_ROTATION_FILE")
    LAST_TS=$(date -d "$LAST_DATE" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DIFF_DAYS=$(( (NOW_TS - LAST_TS) / 86400 ))

    if [ "$DIFF_DAYS" -ge "$MAX_DAYS" ]; then
        echo "⚠️  ALERT: $DIFF_DAYS days have passed since the last API key rotation"
        echo "   Last rotation: $LAST_DATE"
        echo "   Execute the rotation procedure documented in docs/09-maintenance.md"
    fi
else
    echo "⚠️  No record of last API key rotation"
    echo "   Create the file: echo $(date +%Y-%m-%d) > $LAST_ROTATION_FILE"
fi
```

```bash
chmod +x ~/openclaw/scripts/key_rotation_reminder.sh

# Record date of last rotation
echo $(date +%Y-%m-%d) > ~/.openclaw/.last_key_rotation
```

Add to cron for weekly check:

```bash
crontab -e
```

```cron
# Key rotation reminder every Monday
0 9 * * 1 /home/openclaw/openclaw/scripts/key_rotation_reminder.sh | logger -t key-rotation
```

---

## SSH Key Rotation

### When to rotate

- Annually as hygiene practice
- Immediately if you suspect compromise
- When you change devices

### Procedure

#### 1. Generate new key on your local machine

```bash
# On your local machine
ssh-keygen -t ed25519 -C "openclaw-vps-$(date +%Y)" -f ~/.ssh/id_ed25519_openclaw_new
```

#### 2. Add new key to VPS (while the old one still works)

```bash
# Copy new public key
cat ~/.ssh/id_ed25519_openclaw_new.pub

# On the VPS, add to authorized_keys
ssh openclaw@<YOUR_TAILSCALE_IP>
echo "PASTE_NEW_PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
exit
```

#### 3. Test new key

```bash
# Test connection with new key
ssh -i ~/.ssh/id_ed25519_openclaw_new openclaw@<YOUR_TAILSCALE_IP>
```

#### 4. Remove old key

```bash
# On the VPS, edit authorized_keys
nano ~/.ssh/authorized_keys
# Remove the line with the old key
```

#### 5. Update your local configuration

```bash
# Rename keys
mv ~/.ssh/id_ed25519_openclaw ~/.ssh/id_ed25519_openclaw_old
mv ~/.ssh/id_ed25519_openclaw_new ~/.ssh/id_ed25519_openclaw
mv ~/.ssh/id_ed25519_openclaw_new.pub ~/.ssh/id_ed25519_openclaw.pub

# Update SSH config if necessary
nano ~/.ssh/config
```

---

## Backups

### Strategy overview

Your OpenClaw agent's personality, memory, and configuration are stored in files on the VPS. If the server is lost, you lose your agent's identity. The recommended strategy is to back up non-sensitive files to a **private Git repository**, which gives you:

- **Automatic offsite backup** — data lives outside the VPS
- **Version history** — see how your agent's memory and personality evolve
- **Easy restore** — `git clone` on a new server and you're back
- **No manual downloads** — cron handles everything

!!! info "OpenClaw also has `openclaw backup create`"
    This creates a local tarball of `~/.openclaw` + workspace. It's useful for one-off snapshots before upgrades, but it stays on the VPS — if the server dies, so does the backup. The Git approach below solves this by pushing offsite automatically.

### What to back up

| Category | Files | Goes to Git? |
|----------|-------|:---:|
| **Agent identity** | `~/openclaw/workspace/SOUL.md` | Yes |
| **Agent memory** | `~/openclaw/workspace/MEMORY.md`, `~/openclaw/workspace/memory/` | Yes |
| **Agent workspace** | `~/openclaw/workspace/AGENTS.md`, `IDENTITY.md`, `USER.md`, `TOOLS.md` | Yes |
| **OpenClaw config** | `~/.openclaw/openclaw.json` | Yes |
| **Exec approvals** | `~/.openclaw/exec-approvals.json` | Yes |
| **systemd overrides** | `/etc/systemd/system/openclaw.service.d/*.conf` | Yes |
| **SSH hardening** | `/etc/ssh/sshd_config.d/99-openclaw-hardening.conf` | Yes |
| **SSH boot order** | `/etc/systemd/system/ssh.service.d/after-tailscale.conf` | Yes |
| **SSH authorized keys** | `~/.ssh/authorized_keys` | Yes |
| **API keys / secrets** | `/etc/openclaw/env` | **NEVER** |
| **Auth profiles** | `~/.openclaw/agents/main/agent/auth-profiles.json` | **NEVER** (may contain keys) |
| **State directory** | `~/.openclaw/` (full) | **NEVER** (contains tokens, sessions) |

### Step 1: Create a private GitHub repository

1. Create a **dedicated GitHub account** for your OpenClaw instance (recommended) or use your personal account
2. Create a **private** repository (e.g., `openclaw-backup`)
3. Do **NOT** initialize it with a README

!!! tip "Why a dedicated account?"
    A separate account with its own SSH key limits the blast radius — if the VPS is compromised, only the backup repo is accessible, not your personal GitHub. It also keeps the bot's activity separate from yours.

### Step 2: Set up SSH key for Git access

On the VPS, generate a deploy key:

```bash
# Generate an SSH key for Git (no passphrase for automated use)
ssh-keygen -t ed25519 -C "openclaw-backup" -f ~/.ssh/git_backup_key -N ""

# Show the public key
cat ~/.ssh/git_backup_key.pub
```

Add the public key to your GitHub repo:

- Go to your repo → **Settings** → **Deploy keys** → **Add deploy key**
- Paste the public key
- Check **Allow write access**
- Click **Add key**

Configure SSH to use this key for GitHub:

```bash
cat >> ~/.ssh/config << 'EOF'

# Git backup
Host github-backup
    HostName github.com
    User git
    IdentityFile ~/.ssh/git_backup_key
    IdentitiesOnly yes
EOF

chmod 600 ~/.ssh/config
```

### Step 3: Initialize the backup repository

```bash
# Create the backup staging directory
mkdir -p ~/openclaw-backup
cd ~/openclaw-backup
git init
git remote add origin git@github-backup:<YOUR_GITHUB_USER>/openclaw-backup.git
```

Create a `.gitignore` to prevent secrets from ever being committed:

```bash
cat > ~/openclaw-backup/.gitignore << 'EOF'
# NEVER commit secrets
.env
*.env
env
*.gpg
*.pem
*.key
auth-profiles.json
credentials/
secrets/

# OS files
.DS_Store
*.swp
*.swo
*~
EOF
```

Do an initial commit:

```bash
cd ~/openclaw-backup
git add .gitignore
git commit -m "chore: initial commit with .gitignore"
git branch -M main
git push -u origin main
```

### Step 4: Create the backup script

```bash
nano ~/openclaw/scripts/git-backup.sh
```

```bash
#!/bin/bash
# Automated Git backup for OpenClaw workspace and configuration
# Backs up non-sensitive files to a private GitHub repository
set -euo pipefail

BACKUP_DIR="$HOME/openclaw-backup"
LOG_FILE="$HOME/openclaw/logs/git-backup.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"; }

log "Starting backup..."

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"/{workspace,config,system}

# --- Workspace files (agent identity, memory, personality) ---
if [ -d "$HOME/openclaw/workspace" ]; then
    rsync -a --delete \
        --exclude='*.env' \
        --exclude='credentials/' \
        --exclude='secrets/' \
        "$HOME/openclaw/workspace/" "$BACKUP_DIR/workspace/"
    log "Workspace synced"
fi

# --- OpenClaw configuration (non-sensitive) ---
cp "$HOME/.openclaw/openclaw.json" "$BACKUP_DIR/config/" 2>/dev/null || true
cp "$HOME/.openclaw/exec-approvals.json" "$BACKUP_DIR/config/" 2>/dev/null || true
log "Config files copied"

# --- System configuration ---
cp /etc/ssh/sshd_config.d/99-openclaw-hardening.conf "$BACKUP_DIR/system/" 2>/dev/null || true
cp /etc/systemd/system/ssh.service.d/after-tailscale.conf "$BACKUP_DIR/system/" 2>/dev/null || true
cp "$HOME/.ssh/authorized_keys" "$BACKUP_DIR/system/" 2>/dev/null || true

# Copy systemd overrides if they exist
if [ -d /etc/systemd/system/openclaw.service.d ]; then
    mkdir -p "$BACKUP_DIR/system/openclaw.service.d"
    cp /etc/systemd/system/openclaw.service.d/*.conf "$BACKUP_DIR/system/openclaw.service.d/" 2>/dev/null || true
fi
log "System config copied"

# --- Server info (for restore reference) ---
cat > "$BACKUP_DIR/SERVER_INFO.md" << EOF
# Server Information

- **Last backup**: $(date -u '+%Y-%m-%d %H:%M:%S UTC')
- **Hostname**: $(hostname)
- **Tailscale IP**: $(tailscale ip -4 2>/dev/null || echo "unknown")
- **OpenClaw version**: $(openclaw --version 2>/dev/null || echo "unknown")
- **OS**: $(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
- **Node.js**: $(node --version 2>/dev/null || echo "unknown")
EOF
log "Server info updated"

# --- Safety check: ensure no secrets are staged ---
cd "$BACKUP_DIR"
if grep -rl 'sk-ant-\|sk-\|nvapi-\|OPENAI_API_KEY=\|ANTHROPIC_API_KEY=\|GEMINI_API_KEY=' . \
    --include='*.json' --include='*.md' --include='*.conf' --include='*.env' 2>/dev/null | grep -v '.git/'; then
    log "ERROR: Potential secrets detected in backup files! Aborting."
    echo "ERROR: Potential secrets detected. Backup aborted." >&2
    exit 1
fi

# --- Commit and push ---
cd "$BACKUP_DIR"
git add -A

if git diff --cached --quiet; then
    log "No changes to commit"
else
    git commit -m "backup: $(date '+%Y-%m-%d %H:%M') — $(hostname)"
    git push origin main
    log "Changes pushed to GitHub"
fi

log "Backup complete"
```

```bash
chmod +x ~/openclaw/scripts/git-backup.sh
mkdir -p ~/openclaw/logs
```

### Step 5: Test the backup

```bash
# Run it manually first
~/openclaw/scripts/git-backup.sh

# Check the log
cat ~/openclaw/logs/git-backup.log

# Verify on GitHub that files appeared in your private repo
```

### Step 6: Schedule automatic backups

```bash
crontab -e
```

Add:

```cron
# Daily Git backup at 4:00 AM
0 4 * * * /home/openclaw/openclaw/scripts/git-backup.sh >> /home/openclaw/openclaw/logs/git-backup.log 2>&1
```

!!! tip "Frequency"
    Daily is sufficient for most setups. If your agent is very active and accumulates memory quickly, you can increase to every 6 hours: `0 */6 * * *`.

### Step 7: Verify backups are running

After a day, check:

```bash
# Check cron ran successfully
tail -20 ~/openclaw/logs/git-backup.log

# Check last commit date on the repo
cd ~/openclaw-backup && git log --oneline -5
```

### Restore to a new server

If your VPS is lost, restoring is straightforward:

1. Provision a new VPS following sections 1-5 of this guide
2. Clone your backup:

```bash
git clone git@github.com:<YOUR_GITHUB_USER>/openclaw-backup.git ~/openclaw-backup
```

3. Restore files to their locations:

```bash
# Restore workspace (agent identity and memory)
cp -r ~/openclaw-backup/workspace/* ~/openclaw/workspace/

# Restore OpenClaw configuration
cp ~/openclaw-backup/config/openclaw.json ~/.openclaw/
cp ~/openclaw-backup/config/exec-approvals.json ~/.openclaw/ 2>/dev/null || true

# Restore system configuration
sudo cp ~/openclaw-backup/system/99-openclaw-hardening.conf /etc/ssh/sshd_config.d/
sudo mkdir -p /etc/systemd/system/ssh.service.d
sudo cp ~/openclaw-backup/system/after-tailscale.conf /etc/systemd/system/ssh.service.d/
cp ~/openclaw-backup/system/authorized_keys ~/.ssh/

# Restore systemd overrides
if [ -d ~/openclaw-backup/system/openclaw.service.d ]; then
    sudo cp -r ~/openclaw-backup/system/openclaw.service.d /etc/systemd/system/
fi

sudo systemctl daemon-reload
```

4. Re-configure secrets (these are NOT in the backup — you need your API keys):

```bash
sudo nano /etc/openclaw/env
# Add your API keys, Telegram token, etc.
```

5. Restart services:

```bash
sudo systemctl restart ssh
sudo systemctl restart openclaw
```

!!! success "Your agent is back"
    With the workspace restored, your agent retains its personality (SOUL.md), memory (MEMORY.md + memory/), and all configuration. Only secrets need to be re-entered.

### Pre-update snapshot

Before major changes (OpenClaw updates, provider switches), take a manual snapshot:

```bash
# Quick backup via OpenClaw CLI
openclaw backup create

# Or trigger your Git backup immediately
~/openclaw/scripts/git-backup.sh
```

---

## Continuous monitoring

### Quick status dashboard

```bash
nano ~/openclaw/scripts/status.sh
```

```bash
#!/bin/bash
# OpenClaw status dashboard

clear
echo "========================================"
echo "      OPENCLAW VPS STATUS              "
echo "      $(date '+%Y-%m-%d %H:%M:%S')     "
echo "========================================"
echo ""

# System
echo "--- SYSTEM ---"
echo "Uptime: $(uptime -p)"
echo "Load: $(cat /proc/loadavg | cut -d' ' -f1-3)"
echo "RAM: $(free -h | grep Mem | awk '{print $3"/"$2}')"
echo "Disk: $(df -h / | tail -1 | awk '{print $3"/"$2" ("$5")"}')"
echo ""

# Services
echo "--- SERVICES ---"
for service in openclaw tailscaled fail2ban auditd; do
    status=$(systemctl is-active $service 2>/dev/null)
    if [ "$status" = "active" ]; then
        echo "✅ $service"
    else
        echo "❌ $service ($status)"
    fi
done
echo ""

# Network
echo "--- NETWORK ---"
echo "Tailscale IP: $(tailscale ip -4 2>/dev/null || echo 'N/A')"
echo "SSH listening: $(ss -tlnp | grep sshd | awk '{print $4}')"
echo "OpenClaw listening: $(ss -tlnp | grep 18789 | awk '{print $4}')"
echo ""

# Security
echo "--- SECURITY ---"
BANNED=$(sudo fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}')
echo "Banned IPs (fail2ban): ${BANNED:-0}"
ALERTS=$(wc -l < ~/openclaw/logs/security_alerts.log 2>/dev/null || echo 0)
echo "Security alerts: $ALERTS"
echo ""

# Recent events
echo "--- RECENT LOGS ---"
echo "OpenClaw:"
sudo journalctl -u openclaw -n 3 --no-pager 2>/dev/null | tail -3
echo ""

echo "========================================"
```

```bash
chmod +x ~/openclaw/scripts/status.sh
```

### Email alerts (optional)

If you want to receive email alerts, configure `msmtp` or similar:

```bash
sudo apt install -y msmtp msmtp-mta

# Configure (example with Gmail)
nano ~/.msmtprc
```

```
account gmail
host smtp.gmail.com
port 587
auth on
user your-email@gmail.com
password your-app-password
tls on
tls_starttls on
from your-email@gmail.com

account default : gmail
```

```bash
chmod 600 ~/.msmtprc
```

---

## Disaster Recovery

### Scenario: Total VPS loss

If your VPS is destroyed and you have Git backups configured (see [Backups](#backups) above), recovery is straightforward.

#### Step 1: Create and harden a new VPS

Follow sections 1-4 of this guide:

- [2. Provision VPS](02-vps.md) — create a new server
- [3. System security](03-system-security.md) — create user, harden SSH
- [4. Private access](04-private-access.md) — install Tailscale, close public SSH

#### Step 2: Install OpenClaw

Follow [Section 5](05-openclaw.md) to install OpenClaw on the new server.

#### Step 3: Restore from Git backup

```bash
# Clone your backup repository
git clone git@github.com:<YOUR_GITHUB_USER>/openclaw-backup.git ~/openclaw-backup

# Restore workspace (agent identity, memory, personality)
cp -r ~/openclaw-backup/workspace/* ~/openclaw/workspace/

# Restore OpenClaw configuration
cp ~/openclaw-backup/config/openclaw.json ~/.openclaw/
cp ~/openclaw-backup/config/exec-approvals.json ~/.openclaw/ 2>/dev/null || true

# Restore system configuration
sudo cp ~/openclaw-backup/system/99-openclaw-hardening.conf /etc/ssh/sshd_config.d/
sudo mkdir -p /etc/systemd/system/ssh.service.d
sudo cp ~/openclaw-backup/system/after-tailscale.conf /etc/systemd/system/ssh.service.d/
cp ~/openclaw-backup/system/authorized_keys ~/.ssh/

# Restore systemd overrides
if [ -d ~/openclaw-backup/system/openclaw.service.d ]; then
    sudo cp -r ~/openclaw-backup/system/openclaw.service.d /etc/systemd/system/
fi
```

#### Step 4: Re-configure secrets

Secrets are never stored in the backup. You need to re-enter your API keys:

```bash
sudo nano /etc/openclaw/env
# Add: API keys, Telegram bot token, and any other secrets

sudo chmod 600 /etc/openclaw/env
sudo chown root:openclaw /etc/openclaw/env
```

#### Step 5: Apply and verify

```bash
sudo systemctl daemon-reload
sudo systemctl restart ssh
sudo systemctl restart openclaw

# Verify everything is running
sudo systemctl is-active tailscaled ssh openclaw
openclaw status --all
```

#### Step 6: Re-enable backups on the new server

Follow [Step 2](#step-2-set-up-ssh-key-for-git-access) onwards from the Backups section to set up the SSH key and cron job on the new server.

!!! tip "Keep your API keys safe outside the VPS"
    Store your API keys in a password manager (Bitwarden, 1Password, etc.) so you can re-enter them during recovery without depending on the VPS.

### Disaster recovery test

!!! tip "Do this test every 6 months"
    The only way to know if your backups work is to test them.

1. Create a temporary VPS
2. Try to restore from backup
3. Verify everything works
4. Delete the temporary VPS

---

## Monthly maintenance checklist

```markdown
## Monthly maintenance - [MONTH/YEAR]

### System
- [ ] Verify automatic updates working
- [ ] Review security logs
- [ ] Verify disk space (< 80%)
- [ ] Review resource usage

### Tailscale
- [ ] Verify version is updated
- [ ] Review connected devices
- [ ] Verify ACLs are still correct

### OpenClaw
- [ ] Update if new version available
- [ ] Review logs for errors
- [ ] Verify systemd score

### Security
- [ ] Review IPs banned by fail2ban
- [ ] Verify security alerts
- [ ] Run AIDE integrity check
- [ ] Review audit rules

### Backups
- [ ] Verify Git backup cron is running (`tail -5 ~/openclaw/logs/git-backup.log`)
- [ ] Check last commit date (`cd ~/openclaw-backup && git log --oneline -1`)
- [ ] Verify restore works (quarterly)

### Secret rotation
- [ ] Have 90 days passed since last API key rotation?
- [ ] Has 1 year passed since SSH key rotation?

### Notes
_Any observations or pending tasks_
```

---

**Next:** [10. Final checklist](10-final-checklist.md) — Consolidated verification of all controls.
