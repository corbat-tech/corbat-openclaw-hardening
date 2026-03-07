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
cp ~/openclaw/.env ~/openclaw/.env.backup.$(date +%Y%m%d)
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
# Backup current .env
cp ~/openclaw/.env ~/openclaw/.env.backup.$(date +%Y%m%d)

# Edit .env
nano ~/openclaw/.env

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

### What to include in backups

| File/Directory | Criticality | Frequency |
|----------------|-------------|-----------|
| `~/.openclaw/openclaw.json` | Critical | Weekly |
| `~/openclaw/.env` | Critical | Weekly |
| `~/openclaw/workspace/` | Medium | Daily (if data exists) |
| SSH keys (`.ssh/`) | High | After rotation |
| systemd configuration | Medium | After changes |

### Backup script

```bash
nano ~/openclaw/scripts/backup.sh
```

```bash
#!/bin/bash
# OpenClaw configuration backup
# Run weekly

set -e

BACKUP_DIR="$HOME/backups"
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="openclaw_backup_$DATE"
BACKUP_PATH="$BACKUP_DIR/$BACKUP_NAME"

# Create backup directory
mkdir -p "$BACKUP_PATH"

echo "Creating backup: $BACKUP_NAME"

# Backup OpenClaw configuration (encrypted)
echo "- Backing up OpenClaw configuration..."
if [ -f "$HOME/openclaw/.env" ]; then
    gpg --symmetric --cipher-algo AES256 -o "$BACKUP_PATH/env.gpg" "$HOME/openclaw/.env"
fi
cp "$HOME/.openclaw/openclaw.json" "$BACKUP_PATH/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/SOUL.md" "$BACKUP_PATH/" 2>/dev/null || true
cp "$HOME/.openclaw/workspace/TOOLS.md" "$BACKUP_PATH/" 2>/dev/null || true

# Backup maintenance scripts
echo "- Backing up scripts..."
cp -r "$HOME/openclaw/scripts" "$BACKUP_PATH/" 2>/dev/null || true

# Backup systemd configuration
echo "- Backing up systemd service..."
sudo cp /etc/systemd/system/openclaw.service "$BACKUP_PATH/"

# Backup SSH authorized_keys
echo "- Backing up SSH keys..."
cp "$HOME/.ssh/authorized_keys" "$BACKUP_PATH/"

# Backup audit rules
echo "- Backing up audit rules..."
sudo cp /etc/audit/rules.d/openclaw.rules "$BACKUP_PATH/" 2>/dev/null || true

# Create info file
cat > "$BACKUP_PATH/backup_info.txt" << EOF
Backup created: $(date)
Hostname: $(hostname)
Tailscale IP: $(tailscale ip -4)
OpenClaw version: $(openclaw --version 2>/dev/null || echo "unknown")
EOF

# Compress backup
echo "- Compressing..."
cd "$BACKUP_DIR"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"
rm -rf "$BACKUP_PATH"

# Clean old backups (keep last 4)
echo "- Cleaning old backups..."
ls -t "$BACKUP_DIR"/openclaw_backup_*.tar.gz | tail -n +5 | xargs -r rm

echo "Backup completed: $BACKUP_DIR/$BACKUP_NAME.tar.gz"
echo "Size: $(du -h "$BACKUP_DIR/$BACKUP_NAME.tar.gz" | cut -f1)"

# Reminder to download backup
echo ""
echo "⚠️  IMPORTANT: Download the backup to your local machine:"
echo "   scp openclaw@<YOUR_TAILSCALE_IP>:$BACKUP_DIR/$BACKUP_NAME.tar.gz ./"
```

```bash
chmod +x ~/openclaw/scripts/backup.sh
```

### Schedule automatic backups

```bash
crontab -e
```

```cron
# Weekly backup (Sundays at 3am)
0 3 * * 0 /home/openclaw/openclaw/scripts/backup.sh >> /home/openclaw/openclaw/logs/backup.log 2>&1
```

### Download backups to your local machine

!!! danger "Backups on the VPS are not enough"
    If you lose the VPS, you lose the backups. Download regularly to your local machine.

```bash
# From your local machine
scp openclaw@<YOUR_TAILSCALE_IP>:~/backups/openclaw_backup_*.tar.gz ~/backups/vps/
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

#### Step 1: Create new VPS

Follow the instructions in [Section 2](02-vps.md) to create a new VPS.

#### Step 2: Restore from backup

```bash
# Upload backup to new VPS
scp openclaw_backup_DATE.tar.gz root@NEW_VPS:/tmp/

# On the new VPS
tar -xzf /tmp/openclaw_backup_DATE.tar.gz -C /tmp/
```

#### Step 3: Run initial setup

```bash
# Create user (Section 3)
adduser openclaw
usermod -aG sudo openclaw

# Restore authorized_keys
mkdir -p /home/openclaw/.ssh
cp /tmp/openclaw_backup_*/authorized_keys /home/openclaw/.ssh/
chown -R openclaw:openclaw /home/openclaw/.ssh
chmod 700 /home/openclaw/.ssh
chmod 600 /home/openclaw/.ssh/authorized_keys
```

#### Step 4: Restore configuration

```bash
# As openclaw user
su - openclaw

# Install OpenClaw
npm install -g openclaw@latest

# Create structure
mkdir -p ~/.openclaw
mkdir -p ~/openclaw/{workspace,logs,scripts}

# Restore OpenClaw configuration
cp /tmp/openclaw_backup_*/openclaw.json ~/.openclaw/
cp /tmp/openclaw_backup_*/SOUL.md ~/.openclaw/workspace/ 2>/dev/null || true
cp /tmp/openclaw_backup_*/TOOLS.md ~/.openclaw/workspace/ 2>/dev/null || true
cp -r /tmp/openclaw_backup_*/scripts/* ~/openclaw/scripts/ 2>/dev/null || true

# Restore .env (decrypt)
gpg -d /tmp/openclaw_backup_*/env.gpg > ~/openclaw/.env
chmod 600 ~/openclaw/.env

# Restore systemd service
sudo cp /tmp/openclaw_backup_*/openclaw.service /etc/systemd/system/
sudo systemctl daemon-reload
```

#### Step 5: Re-run hardening

Follow the relevant sections:

- [3. System security](03-system-security.md) - SSH hardening
- [4. Private access](04-private-access.md) - Tailscale
- [5. OpenClaw](05-openclaw.md) - Installation

#### Step 6: Verify

```bash
# Run verification script
~/openclaw/scripts/verify_permissions.sh

# Verify services
~/openclaw/scripts/status.sh
```

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
- [ ] Verify automatic backups
- [ ] Download backup to local
- [ ] Verify restore works (quarterly)

### Secret rotation
- [ ] Have 90 days passed since last API key rotation?
- [ ] Has 1 year passed since SSH key rotation?

### Notes
_Any observations or pending tasks_
```

---

**Next:** [10. Final checklist](10-final-checklist.md) — Consolidated verification of all controls.
