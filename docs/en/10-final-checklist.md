# 10. Final Security Checklist

> **TL;DR**: Consolidated verification of all implemented security controls. Use this checklist to confirm your installation complies with CIS Benchmark, Tailscale Hardening, and OWASP Agentic Top 10.

---

## Usage instructions

1. Run each verification in order
2. Mark each control as ✅ (compliant) or ❌ (non-compliant)
3. Don't put OpenClaw in production until all critical controls are ✅
4. Save this completed checklist as configuration evidence

---

## Automatic verification script

Run this script to automatically verify most controls:

```bash
#!/bin/bash
# verify_security.sh - Complete security verification

echo "========================================================"
echo "  SECURITY VERIFICATION - OpenClaw VPS"
echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Hostname: $(hostname)"
echo "========================================================"
echo ""

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local result="$2"
    local critical="$3"

    if [ "$result" = "pass" ]; then
        echo "✅ $name"
        ((PASS++))
    elif [ "$result" = "warn" ]; then
        echo "⚠️  $name"
        ((WARN++))
    else
        if [ "$critical" = "critical" ]; then
            echo "❌ [CRITICAL] $name"
        else
            echo "❌ $name"
        fi
        ((FAIL++))
    fi
}

echo "=== 1. OPERATING SYSTEM ==="

# User openclaw exists
if id openclaw &>/dev/null; then
    check "User openclaw exists" "pass"
else
    check "User openclaw exists" "fail" "critical"
fi

# User openclaw is not root
if [ "$(id -u openclaw 2>/dev/null)" != "0" ]; then
    check "User openclaw is not root" "pass"
else
    check "User openclaw is not root" "fail" "critical"
fi

# UFW active
if sudo ufw status | grep -q "Status: active"; then
    check "Firewall UFW active" "pass"
else
    check "Firewall UFW active" "fail" "critical"
fi

# Fail2ban active
if systemctl is-active fail2ban &>/dev/null; then
    check "Fail2ban active" "pass"
else
    check "Fail2ban active" "fail"
fi

# Unattended upgrades
if systemctl is-active unattended-upgrades &>/dev/null; then
    check "Automatic updates" "pass"
else
    check "Automatic updates" "fail"
fi

# Auditd active
if systemctl is-active auditd &>/dev/null; then
    check "Auditd active" "pass"
else
    check "Auditd active" "warn"
fi

# AIDE initialized
if [ -f /var/lib/aide/aide.db ]; then
    check "AIDE initialized" "pass"
else
    check "AIDE initialized" "warn"
fi

echo ""
echo "=== 2. SSH HARDENING (CIS Benchmark) ==="

# PasswordAuthentication no
if sudo sshd -T 2>/dev/null | grep -qi "passwordauthentication no"; then
    check "SSH: PasswordAuthentication no" "pass"
else
    check "SSH: PasswordAuthentication no" "fail" "critical"
fi

# PermitRootLogin no
if sudo sshd -T 2>/dev/null | grep -qi "permitrootlogin no"; then
    check "SSH: PermitRootLogin no" "pass"
else
    check "SSH: PermitRootLogin no" "fail" "critical"
fi

# AllowUsers configured
if sudo sshd -T 2>/dev/null | grep -qi "allowusers"; then
    check "SSH: AllowUsers configured" "pass"
else
    check "SSH: AllowUsers configured" "fail"
fi

# MaxAuthTries <= 4
MAX_AUTH=$(sudo sshd -T 2>/dev/null | grep -i maxauthtries | awk '{print $2}')
if [ -n "$MAX_AUTH" ] && [ "$MAX_AUTH" -le 4 ]; then
    check "SSH: MaxAuthTries <= 4" "pass"
else
    check "SSH: MaxAuthTries <= 4" "fail"
fi

# X11Forwarding no
if sudo sshd -T 2>/dev/null | grep -qi "x11forwarding no"; then
    check "SSH: X11Forwarding no" "pass"
else
    check "SSH: X11Forwarding no" "fail"
fi

# LogLevel VERBOSE
if sudo sshd -T 2>/dev/null | grep -qi "loglevel verbose"; then
    check "SSH: LogLevel VERBOSE" "pass"
else
    check "SSH: LogLevel VERBOSE" "warn"
fi

# Permissions sshd_config
SSHD_PERMS=$(stat -c "%a" /etc/ssh/sshd_config 2>/dev/null)
if [ "$SSHD_PERMS" = "600" ]; then
    check "SSH: sshd_config permissions 600" "pass"
else
    check "SSH: sshd_config permissions 600" "fail"
fi

echo ""
echo "=== 3. TAILSCALE ==="

# Tailscale installed and active
if systemctl is-active tailscaled &>/dev/null; then
    check "Tailscale active" "pass"
else
    check "Tailscale active" "fail" "critical"
fi

# SSH listening only on Tailscale
SSH_LISTEN=$(sudo ss -tlnp | grep sshd | awk '{print $4}')
if echo "$SSH_LISTEN" | grep -q "100\."; then
    check "SSH only on Tailscale interface" "pass"
elif echo "$SSH_LISTEN" | grep -q "0\.0\.0\.0"; then
    check "SSH only on Tailscale interface" "fail" "critical"
else
    check "SSH only on Tailscale interface" "warn"
fi

# Port 22 closed in UFW (no rule for SSH)
if ! sudo ufw status | grep -E "22/tcp.*ALLOW.*Anywhere" | grep -v "100\." &>/dev/null; then
    check "Public port 22 closed" "pass"
else
    check "Public port 22 closed" "fail" "critical"
fi

# Tag vps configured
if tailscale status 2>/dev/null | grep -q "tagged"; then
    check "Tag 'vps' configured" "pass"
else
    check "Tag 'vps' configured" "warn"
fi

echo ""
echo "=== 4. OPENCLAW ==="

# Service active
if systemctl is-active openclaw &>/dev/null; then
    check "OpenClaw service active" "pass"
else
    check "OpenClaw service active" "warn"
fi

# Listening on localhost (not 0.0.0.0)
OPENCLAW_LISTEN=$(sudo ss -tlnp | grep 18789 | awk '{print $4}')
if echo "$OPENCLAW_LISTEN" | grep -q "127\.0\.0\.1"; then
    check "OpenClaw on localhost (127.0.0.1:18789)" "pass"
elif echo "$OPENCLAW_LISTEN" | grep -q "0\.0\.0\.0"; then
    check "OpenClaw on localhost (127.0.0.1:18789)" "fail" "critical"
else
    check "OpenClaw on localhost (127.0.0.1:18789)" "warn"
fi

# /etc/openclaw/env with permissions 600 and owner root
ENV_PERMS=$(stat -c "%a" /etc/openclaw/env 2>/dev/null)
ENV_OWNER=$(stat -c "%U" /etc/openclaw/env 2>/dev/null)
if [ "$ENV_PERMS" = "600" ] && [ "$ENV_OWNER" = "root" ]; then
    check "/etc/openclaw/env permissions 600, owner root" "pass"
elif [ "$ENV_PERMS" = "600" ]; then
    check "/etc/openclaw/env owner should be root (is $ENV_OWNER)" "fail" "critical"
else
    check "/etc/openclaw/env permissions 600" "fail" "critical"
fi

# Systemd score < 5
SECURITY_SCORE=$(systemd-analyze security openclaw.service 2>/dev/null | grep "Overall" | grep -oE "[0-9]+\.[0-9]+" | head -1)
if [ -n "$SECURITY_SCORE" ]; then
    # Extract integer part for comparison (no bc dependency)
    SCORE_INT=${SECURITY_SCORE%%.*}
    if [ -n "$SCORE_INT" ] && [ "$SCORE_INT" -lt 5 ]; then
        check "Systemd hardening (score < 5.0): $SECURITY_SCORE" "pass"
    elif [ -n "$SCORE_INT" ] && [ "$SCORE_INT" -ge 5 ]; then
        check "Systemd hardening (score < 5.0): $SECURITY_SCORE" "fail"
    else
        check "Systemd hardening (score parse error)" "warn"
    fi
else
    check "Systemd hardening" "warn"
fi

echo ""
echo "=== 5. OPENCLAW CONFIGURATION ==="

CONFIG_FILE="/home/openclaw/.openclaw/openclaw.json"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME/.openclaw/openclaw.json"
fi

if [ -f "$CONFIG_FILE" ]; then
    # Sandbox mode configured (off = dedicated VPS with systemd hardening, all = Docker)
    if grep -q '"sandbox"' "$CONFIG_FILE" && grep -A2 '"sandbox"' "$CONFIG_FILE" | grep -qE '"mode":\s*"(all|off)"'; then
        SANDBOX_MODE=$(grep -A2 '"sandbox"' "$CONFIG_FILE" | grep -oE '"(all|off)"' | tr -d '"')
        check "Sandbox mode configured ($SANDBOX_MODE)" "pass"
    else
        check "Sandbox mode configured" "fail" "critical"
    fi

    # dmPolicy configured
    if grep -q '"dmPolicy":\s*"pairing"' "$CONFIG_FILE" || grep -q '"dmPolicy":\s*"closed"' "$CONFIG_FILE"; then
        check "dmPolicy configured (pairing/closed)" "pass"
    elif grep -q '"dmPolicy":\s*"open"' "$CONFIG_FILE"; then
        check "dmPolicy configured (pairing/closed)" "fail" "critical"
    else
        check "dmPolicy configured (pairing/closed)" "warn"
    fi

    # Gateway on localhost
    if grep -q '"host":\s*"127.0.0.1"' "$CONFIG_FILE"; then
        check "Gateway host = 127.0.0.1" "pass"
    else
        check "Gateway host = 127.0.0.1" "fail" "critical"
    fi

    # Gateway TLS pairing
    if grep -q '"pairing":\s*true' "$CONFIG_FILE"; then
        check "Gateway TLS pairing enabled" "pass"
    else
        check "Gateway TLS pairing enabled" "warn"
    fi
else
    check "File openclaw.json exists" "fail"
fi

# Verify TOOLS.md (tools allowlist)
TOOLS_FILE="/home/openclaw/.openclaw/workspace/TOOLS.md"
if [ ! -f "$TOOLS_FILE" ]; then
    TOOLS_FILE="$HOME/.openclaw/workspace/TOOLS.md"
fi

if [ -f "$TOOLS_FILE" ]; then
    check "TOOLS.md (allowlist) exists" "pass"
else
    check "TOOLS.md (allowlist) exists" "warn"
fi

echo ""
echo "=== 6. MONITORING AND AUDITING ==="

# Audit rules for openclaw
if sudo auditctl -l 2>/dev/null | grep -q "openclaw"; then
    check "Audit rules configured" "pass"
else
    check "Audit rules configured" "warn"
fi

# Monitoring script exists
if [ -x /home/openclaw/openclaw/scripts/monitor_behavior.sh ] || [ -x ~/openclaw/scripts/monitor_behavior.sh ]; then
    check "Monitoring script exists" "pass"
else
    check "Monitoring script exists" "warn"
fi

# Backup script exists
if [ -x /home/openclaw/openclaw/scripts/backup.sh ] || [ -x ~/openclaw/scripts/backup.sh ]; then
    check "Backup script exists" "pass"
else
    check "Backup script exists" "warn"
fi

echo ""
echo "========================================================"
echo "  SUMMARY"
echo "========================================================"
echo "  ✅ Passed: $PASS"
echo "  ⚠️  Warnings: $WARN"
echo "  ❌ Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "  🎉 All critical controls passed"
    exit 0
else
    echo "  ⚠️  There are failed controls that must be corrected"
    exit 1
fi
```

Save and run:

```bash
nano ~/openclaw/scripts/verify_security.sh
chmod +x ~/openclaw/scripts/verify_security.sh
~/openclaw/scripts/verify_security.sh
```

---

## Detailed manual checklist

### 1. Operating System

| # | Control | Verification | Status |
|---|---------|--------------|--------|
| 1.1 | User `openclaw` created | `id openclaw` | ⬜ |
| 1.2 | User is not root | `id -u openclaw` ≠ 0 | ⬜ |
| 1.3 | User has sudo | `groups openclaw` includes sudo | ⬜ |
| 1.4 | UFW active | `sudo ufw status` = active | ⬜ |
| 1.5 | UFW default deny incoming | `sudo ufw status verbose` | ⬜ |
| 1.6 | Fail2ban active | `systemctl is-active fail2ban` | ⬜ |
| 1.7 | Fail2ban protecting SSH | `sudo fail2ban-client status sshd` | ⬜ |
| 1.8 | Automatic updates | `systemctl is-active unattended-upgrades` | ⬜ |
| 1.9 | Auditd active | `systemctl is-active auditd` | ⬜ |
| 1.10 | Audit rules for OpenClaw | `sudo auditctl -l \| grep openclaw` | ⬜ |
| 1.11 | AIDE initialized | `ls /var/lib/aide/aide.db` | ⬜ |

### 2. SSH Hardening (CIS Benchmark 5.2)

| # | Control | Verification command | Expected value | Status |
|---|---------|---------------------|----------------|--------|
| 2.1 | PasswordAuthentication | `sudo sshd -T \| grep passwordauthentication` | no | ⬜ |
| 2.2 | PermitRootLogin | `sudo sshd -T \| grep permitrootlogin` | no | ⬜ |
| 2.3 | PermitEmptyPasswords | `sudo sshd -T \| grep permitemptypasswords` | no | ⬜ |
| 2.4 | MaxAuthTries | `sudo sshd -T \| grep maxauthtries` | ≤ 4 | ⬜ |
| 2.5 | X11Forwarding | `sudo sshd -T \| grep x11forwarding` | no | ⬜ |
| 2.6 | AllowTcpForwarding | `sudo sshd -T \| grep allowtcpforwarding` | local | ⬜ |
| 2.7 | LogLevel | `sudo sshd -T \| grep loglevel` | VERBOSE | ⬜ |
| 2.8 | ClientAliveInterval | `sudo sshd -T \| grep clientaliveinterval` | > 0 | ⬜ |
| 2.9 | LoginGraceTime | `sudo sshd -T \| grep logingracetime` | ≤ 60 | ⬜ |
| 2.10 | AllowUsers | `sudo sshd -T \| grep allowusers` | openclaw | ⬜ |
| 2.11 | Banner | `sudo sshd -T \| grep banner` | /etc/issue.net | ⬜ |
| 2.12 | Secure ciphers | `sudo sshd -T \| grep ciphers` | No arcfour, 3des | ⬜ |
| 2.13 | Post-quantum KexAlgorithms | `sudo sshd -T \| grep kexalgorithms` | Includes sntrup761 | ⬜ |
| 2.14 | sshd_config permissions | `stat -c %a /etc/ssh/sshd_config` | 600 | ⬜ |
| 2.15 | sshd_config owner | `stat -c %U:%G /etc/ssh/sshd_config` | root:root | ⬜ |

### 3. Tailscale

| # | Control | Verification | Status |
|---|---------|--------------|--------|
| 3.1 | Tailscale installed | `tailscale version` | ⬜ |
| 3.2 | Tailscaled active | `systemctl is-active tailscaled` | ⬜ |
| 3.3 | Connected to Tailnet | `tailscale status` shows devices | ⬜ |
| 3.4 | Tag 'vps' assigned | `tailscale status` shows tagged | ⬜ |
| 3.5 | ACLs configured (not permit-all) | Verify in Tailscale panel | ⬜ |
| 3.6 | SSH listens only on Tailscale IP | `ss -tlnp \| grep sshd` = <YOUR_TAILSCALE_IP> | ⬜ |
| 3.7 | Public port 22 closed | `ssh user@PUBLIC_IP` fails | ⬜ |
| 3.8 | Tailscale access works | `ssh user@TAILSCALE_IP` works | ⬜ |
| 3.9 | (Optional) Tailnet Lock active | `tailscale lock status` | ⬜ |
| 3.10 | (Optional) Webhooks configured | Verify in Tailscale panel | ⬜ |

### 4. OpenClaw

| # | Control | Verification | Status |
|---|---------|--------------|--------|
| 4.1 | Correct directory structure | `ls ~/.openclaw/` | ⬜ |
| 4.2 | openclaw.json exists | `ls ~/.openclaw/openclaw.json` | ⬜ |
| 4.3 | env file exists and permissions 600 | `stat -c %a /etc/openclaw/env` = 600 | ⬜ |
| 4.4 | env file correct owner | `stat -c %U /etc/openclaw/env` = root | ⬜ |
| 4.5 | Gateway host = 127.0.0.1 | `grep host ~/.openclaw/openclaw.json` | ⬜ |
| 4.6 | OpenClaw listens localhost:18789 | `ss -tlnp \| grep 18789` = 127.0.0.1 | ⬜ |
| 4.7 | Not listening on 0.0.0.0 | `ss -tlnp \| grep 18789` ≠ 0.0.0.0 | ⬜ |
| 4.8 | systemd service created | `systemctl status openclaw` | ⬜ |
| 4.9 | Service enabled | `systemctl is-enabled openclaw` | ⬜ |
| 4.10 | systemd hardening applied | See service file | ⬜ |
| 4.11 | systemd score < 5 | `systemd-analyze security openclaw` | ⬜ |

### 5. OpenClaw Security (OWASP AA4/AA5)

| # | Control | Verification | Status |
|---|---------|--------------|--------|
| 5.1 | openclaw.json exists | `ls ~/.openclaw/openclaw.json` | ⬜ |
| 5.2 | Sandbox mode = all | `grep sandbox ~/.openclaw/openclaw.json` | ⬜ |
| 5.3 | dmPolicy = pairing or closed | `grep dmPolicy ~/.openclaw/openclaw.json` | ⬜ |
| 5.4 | Gateway TLS pairing active | `grep tls ~/.openclaw/openclaw.json` | ⬜ |
| 5.5 | TOOLS.md (allowlist) exists | `ls ~/openclaw/workspace/TOOLS.md` | ⬜ |
| 5.6 | SOUL.md (limits) exists | `ls ~/openclaw/workspace/SOUL.md` | ⬜ |
| 5.7 | No dangerous tools | Review TOOLS.md manually | ⬜ |
| 5.8 | `openclaw security audit` no errors | `openclaw security audit` | ⬜ |
| 5.9 | SecretRef configured (no plaintext .env) | `openclaw secrets list` | ⬜ |
| 5.10 | Update channel = stable | `openclaw update --channel` | ⬜ |

### 6. Agent Security (OWASP Agentic)

| # | Control | OWASP Reference | Status |
|---|---------|-----------------|--------|
| 6.1 | Input validation configured | AA1 | ⬜ |
| 6.2 | Output filtering active | AA2 | ⬜ |
| 6.3 | Secrets redacted in outputs | AA2 | ⬜ |
| 6.4 | Least privilege principle | AA4 | ⬜ |
| 6.5 | Skills with allowlist | AA5 | ⬜ |
| 6.6 | Human-in-the-loop configured | AA8 | ⬜ |
| 6.7 | Complete logging | AA10 | ⬜ |
| 6.8 | (Optional) AppArmor profile | AA4 | ⬜ |

### 7. Monitoring and Maintenance

| # | Control | Verification | Status |
|---|---------|--------------|--------|
| 7.1 | Monitoring script exists | `ls ~/openclaw/scripts/monitor_behavior.sh` | ⬜ |
| 7.2 | Backup script exists | `ls ~/openclaw/scripts/backup.sh` | ⬜ |
| 7.3 | Cron jobs configured | `crontab -l` | ⬜ |
| 7.4 | Logs rotated | `ls /etc/logrotate.d/openclaw` | ⬜ |
| 7.5 | Last API key rotation date | `cat ~/.openclaw/.last_key_rotation` | ⬜ |
| 7.6 | Backup downloaded locally | Verify manually | ⬜ |

---

## Standards compliance

### CIS Benchmark Ubuntu 24.04 L1

| Section | Description | Covered |
|---------|-------------|---------|
| 5.2.1 | sshd_config permissions | ✅ |
| 5.2.2 | SSH host key permissions | ✅ |
| 5.2.4 | SSH ciphers | ✅ |
| 5.2.5 | SSH MACs | ✅ |
| 5.2.6 | SSH KEX | ✅ |
| 5.2.7 | SSH banner | ✅ |
| 5.2.8 | SSH LogLevel | ✅ |
| 5.2.9-23 | SSH configuration | ✅ |

### Tailscale Security Hardening

| Control | Description | Covered |
|---------|-------------|---------|
| ACLs | Don't use permit-all | ✅ |
| Tags | Use tags for segmentation | ✅ |
| SSH over Tailscale | Remove public SSH | ✅ |
| Tailnet Lock | Cryptographic signatures | ⬜ Optional |
| Webhooks | Change alerts | ⬜ Optional |

### OWASP Agentic Top 10 2026

| ID | Risk | Mitigation | Covered |
|----|------|------------|---------|
| AA1 | Agentic Injection | Input validation | ✅ |
| AA2 | Sensitive Data Exposure | Output filtering | ✅ |
| AA3 | Improper Output Handling | Sanitization | ✅ |
| AA4 | Excessive Agency | Least privilege | ✅ |
| AA5 | Tool Misuse | Skills allowlist | ✅ |
| AA6 | Insecure Memory | Encrypted memory with retention | ✅ |
| AA7 | Insufficient Identity | Tailscale ACLs | ✅ |
| AA8 | Unsafe Agentic Actions | Human-in-the-loop | ✅ |
| AA9 | Poor Multi-Agent Security | N/A (single agent) | ➖ |
| AA10 | Missing Audit Logs | Auditd, logging | ✅ |

---

## Compliance signature

```
Installation verified by: _________________________

Date: _________________________

Automatic verification score:
- Passed: ____
- Warnings: ____
- Failed: ____

Notes:
_________________________________________________
_________________________________________________
_________________________________________________
```

---

**End of installation guide**

For ongoing maintenance, see [9. Maintenance](09-maintenance.md).
