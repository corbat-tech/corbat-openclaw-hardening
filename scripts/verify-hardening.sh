#!/bin/bash
# =============================================================================
# OpenClaw VPS Hardening Verification Script
# Verifies all security controls documented in the hardening guide.
# Run this after completing the installation to confirm compliance.
# =============================================================================

set -euo pipefail

PASS=0
FAIL=0
WARN=0

check() {
    local name="$1"
    local result="$2"
    local critical="${3:-}"

    if [ "$result" = "pass" ]; then
        echo "  [PASS] $name"
        PASS=$((PASS + 1))
    elif [ "$result" = "warn" ]; then
        echo "  [WARN] $name"
        WARN=$((WARN + 1))
    else
        if [ "$critical" = "critical" ]; then
            echo "  [FAIL] [CRITICAL] $name"
        else
            echo "  [FAIL] $name"
        fi
        FAIL=$((FAIL + 1))
    fi
}

echo "========================================================"
echo "  OpenClaw VPS Hardening Verification"
echo "  Date: $(date '+%Y-%m-%d %H:%M:%S')"
echo "  Host: $(hostname)"
echo "========================================================"
echo ""

# --- 1. SYSTEM ---
echo "=== 1. OPERATING SYSTEM ==="

if id openclaw &>/dev/null; then
    check "User 'openclaw' exists" "pass"
else
    check "User 'openclaw' exists" "fail" "critical"
fi

if [ "$(id -u openclaw 2>/dev/null)" != "0" ]; then
    check "User 'openclaw' is not root" "pass"
else
    check "User 'openclaw' is not root" "fail" "critical"
fi

if sudo ufw status 2>/dev/null | grep -q "Status: active"; then
    check "UFW firewall active" "pass"
else
    check "UFW firewall active" "fail" "critical"
fi

if systemctl is-active fail2ban &>/dev/null; then
    check "Fail2ban active" "pass"
else
    check "Fail2ban active" "fail"
fi

if systemctl is-active unattended-upgrades &>/dev/null; then
    check "Unattended upgrades active" "pass"
else
    check "Unattended upgrades active" "fail"
fi

if systemctl is-active auditd &>/dev/null; then
    check "Auditd active" "pass"
else
    check "Auditd active" "warn"
fi

if [ -f /var/lib/aide/aide.db ]; then
    check "AIDE initialized" "pass"
else
    check "AIDE initialized" "warn"
fi

echo ""

# --- 2. SSH ---
echo "=== 2. SSH HARDENING ==="

if sudo sshd -T 2>/dev/null | grep -qi "passwordauthentication no"; then
    check "SSH: PasswordAuthentication disabled" "pass"
else
    check "SSH: PasswordAuthentication disabled" "fail" "critical"
fi

if sudo sshd -T 2>/dev/null | grep -qi "permitrootlogin no"; then
    check "SSH: Root login disabled" "pass"
else
    check "SSH: Root login disabled" "fail" "critical"
fi

if sudo sshd -T 2>/dev/null | grep -qi "allowusers"; then
    check "SSH: AllowUsers configured" "pass"
else
    check "SSH: AllowUsers configured" "fail"
fi

MAX_AUTH=$(sudo sshd -T 2>/dev/null | grep -i maxauthtries | awk '{print $2}')
if [ -n "$MAX_AUTH" ] && [ "$MAX_AUTH" -le 4 ]; then
    check "SSH: MaxAuthTries <= 4" "pass"
else
    check "SSH: MaxAuthTries <= 4" "fail"
fi

if sudo sshd -T 2>/dev/null | grep -qi "x11forwarding no"; then
    check "SSH: X11Forwarding disabled" "pass"
else
    check "SSH: X11Forwarding disabled" "fail"
fi

if sudo sshd -T 2>/dev/null | grep -qi "sntrup761"; then
    check "SSH: Post-quantum KexAlgorithm (sntrup761)" "pass"
else
    check "SSH: Post-quantum KexAlgorithm (sntrup761)" "warn"
fi

SSHD_PERMS=$(stat -c "%a" /etc/ssh/sshd_config 2>/dev/null)
if [ "$SSHD_PERMS" = "600" ]; then
    check "SSH: sshd_config permissions 600" "pass"
else
    check "SSH: sshd_config permissions 600" "fail"
fi

echo ""

# --- 3. TAILSCALE ---
echo "=== 3. TAILSCALE ==="

if systemctl is-active tailscaled &>/dev/null; then
    check "Tailscale active" "pass"
else
    check "Tailscale active" "fail" "critical"
fi

SSH_LISTEN=$(sudo ss -tlnp 2>/dev/null | grep sshd | awk '{print $4}')
if echo "$SSH_LISTEN" | grep -q "100\."; then
    check "SSH listening only on Tailscale interface" "pass"
elif echo "$SSH_LISTEN" | grep -q "0\.0\.0\.0"; then
    check "SSH listening only on Tailscale interface" "fail" "critical"
else
    check "SSH listening only on Tailscale interface" "warn"
fi

echo ""

# --- 4. OPENCLAW ---
echo "=== 4. OPENCLAW ==="

if systemctl is-active openclaw &>/dev/null; then
    check "OpenClaw service active" "pass"
else
    check "OpenClaw service active" "warn"
fi

OPENCLAW_LISTEN=$(sudo ss -tlnp 2>/dev/null | grep 18789 | awk '{print $4}')
if echo "$OPENCLAW_LISTEN" | grep -q "127\.0\.0\.1"; then
    check "OpenClaw on localhost (127.0.0.1:18789)" "pass"
elif echo "$OPENCLAW_LISTEN" | grep -q "0\.0\.0\.0"; then
    check "OpenClaw on localhost (127.0.0.1:18789)" "fail" "critical"
else
    check "OpenClaw on localhost (127.0.0.1:18789)" "warn"
fi

CONFIG_FILE="/home/openclaw/.openclaw/openclaw.json"
if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE="$HOME/.openclaw/openclaw.json"
fi

if [ -f "$CONFIG_FILE" ]; then
    if grep -qE '"sandbox"\s*:\s*\{' "$CONFIG_FILE" && grep -A2 '"sandbox"' "$CONFIG_FILE" | grep -qE '"mode"\s*:\s*"off"'; then
        check "Sandbox mode = off (dedicated VPS)" "pass"
    else
        check "Sandbox mode = off (dedicated VPS)" "warn"
    fi

    if grep -qE '"dmPolicy"\s*:\s*"(pairing|closed|allowlist)"' "$CONFIG_FILE"; then
        check "dmPolicy = pairing, closed, or allowlist" "pass"
    elif grep -qE '"dmPolicy"\s*:\s*"open"' "$CONFIG_FILE"; then
        check "dmPolicy = pairing, closed, or allowlist" "fail" "critical"
    else
        check "dmPolicy = pairing, closed, or allowlist" "warn"
    fi

    if grep -qE '"bind"\s*:\s*"loopback"' "$CONFIG_FILE" || grep -q '"127.0.0.1"' "$CONFIG_FILE"; then
        check "Gateway bound to loopback" "pass"
    else
        check "Gateway bound to loopback" "fail" "critical"
    fi

    if grep -qE '"gateway"\s*:' "$CONFIG_FILE" && grep -qE '"token"' "$CONFIG_FILE"; then
        check "Gateway token auth configured" "pass"
    else
        check "Gateway token auth configured" "fail" "critical"
    fi
else
    check "openclaw.json exists" "fail"
fi

# Systemd security score
SECURITY_SCORE=$(systemd-analyze security openclaw.service 2>/dev/null | grep "Overall" | grep -oE "[0-9]+\.[0-9]+" | head -1)
if [ -n "$SECURITY_SCORE" ]; then
    SCORE_INT=${SECURITY_SCORE%%.*}
    if [ -n "$SCORE_INT" ] && [ "$SCORE_INT" -lt 5 ]; then
        check "Systemd hardening score < 5.0: $SECURITY_SCORE" "pass"
    else
        check "Systemd hardening score < 5.0: $SECURITY_SCORE" "fail"
    fi
else
    check "Systemd hardening score" "warn"
fi

# OpenClaw security audit
if command -v openclaw &>/dev/null; then
    AUDIT_RESULT=$(openclaw security audit 2>&1 || true)
    if echo "$AUDIT_RESULT" | grep -qi "pass\|ok\|no issues"; then
        check "openclaw security audit passed" "pass"
    else
        check "openclaw security audit passed" "warn"
    fi
else
    check "openclaw binary found" "warn"
fi

echo ""

# --- 5. SUDOERS & WRAPPERS ---
echo "=== 5. SUDOERS & WRAPPERS ==="

if [ -f /etc/sudoers.d/openclaw ]; then
    SUDOERS_PERMS=$(stat -c "%a" /etc/sudoers.d/openclaw 2>/dev/null)
    if [ "$SUDOERS_PERMS" = "440" ]; then
        check "Sudoers file /etc/sudoers.d/openclaw (perms 0440)" "pass"
    else
        check "Sudoers file /etc/sudoers.d/openclaw (perms 0440, got $SUDOERS_PERMS)" "fail"
    fi
else
    check "Sudoers file /etc/sudoers.d/openclaw exists" "fail"
fi

if [ -x /usr/local/bin/safe-apt-install ]; then
    check "safe-apt-install wrapper installed" "pass"
else
    check "safe-apt-install wrapper installed" "warn"
fi

if [ -x /usr/local/bin/safe-systemctl ]; then
    check "safe-systemctl wrapper installed" "pass"
else
    check "safe-systemctl wrapper installed" "warn"
fi

if [ -x /usr/local/bin/safe-pip-install ]; then
    check "safe-pip-install wrapper installed" "pass"
else
    check "safe-pip-install wrapper installed" "warn"
fi

# Check that sudoers does NOT contain wildcard apt-get install *
SUDOERS_WILDCARDS=0
grep -q 'apt-get install \*' /etc/sudoers.d/openclaw 2>/dev/null && SUDOERS_WILDCARDS=1
grep -q 'apt install \*' /etc/sudoers.d/openclaw 2>/dev/null && SUDOERS_WILDCARDS=1
grep -q 'systemctl restart \*' /etc/sudoers.d/openclaw 2>/dev/null && SUDOERS_WILDCARDS=1
grep -q 'pip3 install \*' /etc/sudoers.d/openclaw 2>/dev/null && SUDOERS_WILDCARDS=1
if [ $SUDOERS_WILDCARDS -eq 1 ]; then
    check "Sudoers: no dangerous wildcards" "fail" "critical"
else
    check "Sudoers: no dangerous wildcards" "pass"
fi

echo ""

# --- 6. MONITORING ---
echo "=== 6. MONITORING ==="

if sudo auditctl -l 2>/dev/null | grep -q "openclaw"; then
    check "Audit rules for OpenClaw configured" "pass"
else
    check "Audit rules for OpenClaw configured" "warn"
fi

if [ -x /home/openclaw/openclaw/scripts/backup.sh ] || [ -x "$HOME/openclaw/scripts/backup.sh" ]; then
    check "Backup script exists" "pass"
else
    check "Backup script exists" "warn"
fi

echo ""

# --- SUMMARY ---
echo "========================================================"
echo "  SUMMARY"
echo "========================================================"
echo "  [PASS]: $PASS"
echo "  [WARN]: $WARN"
echo "  [FAIL]: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "  All critical controls passed."
    exit 0
else
    echo "  There are failed controls that must be fixed."
    exit 1
fi
