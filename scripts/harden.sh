#!/bin/bash
# =============================================================================
# OpenClaw VPS Hardening Script
# Automates sections 3 and 4 of the hardening guide.
# Run this AFTER cloud-init provisioning on a fresh Ubuntu 24.04 VPS.
#
# Usage:
#   ssh openclaw@<PUBLIC_IP>
#   curl -fsSL https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/harden.sh | sudo bash
#
# Or download and review first (recommended):
#   curl -fsSL -o /tmp/harden.sh https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main/scripts/harden.sh
#   less /tmp/harden.sh
#   sudo bash /tmp/harden.sh
# =============================================================================

set -euo pipefail

REPO_BASE="https://raw.githubusercontent.com/corbat-tech/corbat-openclaw-hardening/main"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

# --- Pre-checks ---
if [ "$(id -u)" -ne 0 ]; then
    error "This script must be run as root (use sudo)."
    exit 1
fi

if ! grep -q "24.04" /etc/os-release 2>/dev/null; then
    warn "This script is designed for Ubuntu 24.04 LTS. Proceeding anyway..."
fi

if ! id openclaw &>/dev/null; then
    error "User 'openclaw' not found. Run cloud-init first or create the user manually."
    exit 1
fi

echo ""
echo "========================================================"
echo "  OpenClaw VPS Hardening Script"
echo "  $(date '+%Y-%m-%d %H:%M:%S')"
echo "========================================================"
echo ""

# =============================================================================
# SECTION 3: System Security
# =============================================================================

info "=== SECTION 3: System Security ==="

# --- 3.1 SSH Hardening ---
info "Downloading SSH hardening config (CIS Benchmark 5.2)..."
curl -fsSL -o /etc/ssh/sshd_config.d/99-openclaw-hardening.conf \
    "${REPO_BASE}/scripts/99-openclaw-hardening.conf"

info "Creating legal warning banner..."
cat > /etc/issue.net << 'BANNER'
*********************************************
  Authorized access only.
  All activity is monitored and logged.
  Unauthorized access is prohibited.
*********************************************
BANNER

info "Applying CIS file permissions..."
chmod 600 /etc/ssh/sshd_config
chown root:root /etc/ssh/sshd_config
chmod 600 /etc/ssh/ssh_host_*_key
chown root:root /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
chown root:root /etc/ssh/ssh_host_*_key.pub
chmod 600 /etc/ssh/sshd_config.d/99-openclaw-hardening.conf
chown root:root /etc/ssh/sshd_config.d/99-openclaw-hardening.conf

info "Verifying SSH config syntax..."
if sshd -t; then
    info "SSH config OK. Restarting SSH..."
    systemctl restart ssh
else
    error "SSH config has errors. Fix manually before continuing."
    exit 1
fi

# --- 3.2 Fail2ban ---
info "Configuring fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
maxretry = 3
bantime = 86400
EOF
systemctl enable fail2ban
systemctl restart fail2ban

# --- 3.3 Auditd ---
info "Configuring audit rules..."
cat > /etc/audit/rules.d/openclaw.rules << 'EOF'
-D
-b 8192
-f 1
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d -p wa -k sshd_config
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes
-w /home/openclaw/.ssh -p wa -k ssh_keys
-w /root/.ssh -p wa -k ssh_keys
-w /var/log/sudo.log -p wa -k sudo_log
-w /etc/systemd/system -p wa -k systemd_changes
-w /lib/systemd/system -p wa -k systemd_changes
-w /var/log/lastlog -p wa -k logins
-w /var/log/faillog -p wa -k logins
-e 2
EOF
augenrules --load 2>/dev/null || true
systemctl restart auditd

# --- 3.4 Kernel hardening ---
info "Applying kernel hardening (sysctl)..."
cat > /etc/sysctl.d/99-security-hardening.conf << 'EOF'
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF
sysctl -p /etc/sysctl.d/99-security-hardening.conf > /dev/null

# --- 3.5 AIDE ---
info "Initializing AIDE (this takes 5-10 minutes)..."
aideinit 2>/dev/null && cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db || warn "AIDE init failed — run 'sudo aideinit' manually."

# --- 3.6 AIDE cron ---
cat > /etc/cron.daily/aide-check << 'CRON'
#!/bin/bash
/usr/bin/aide --check > /var/log/aide-check.log 2>&1
if [ $? -ne 0 ]; then
    echo "AIDE detected changes - review /var/log/aide-check.log" | logger -t aide
fi
CRON
chmod +x /etc/cron.daily/aide-check

info "=== Section 3 complete ==="
echo ""

# =============================================================================
# SECTION 4: Private Access (Tailscale)
# =============================================================================

info "=== SECTION 4: Private Access (Tailscale) ==="

# --- 4.1 Install Tailscale ---
if ! command -v tailscale &>/dev/null; then
    info "Installing Tailscale from official repo..."
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
    apt-get update -qq
    apt-get install -y -qq tailscale
else
    info "Tailscale already installed."
fi

# --- 4.2 Start Tailscale with tag ---
info "Starting Tailscale..."
echo ""
echo "========================================================"
echo "  MANUAL STEP REQUIRED"
echo "  Tailscale will print a URL below."
echo "  Open it in your browser to authenticate."
echo "========================================================"
echo ""

tailscale up --advertise-tags=tag:vps

# Wait for Tailscale to get an IP
sleep 3
TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || true)

if [ -z "$TAILSCALE_IP" ]; then
    error "Could not get Tailscale IP. Authenticate and run the script again."
    exit 1
fi

info "Tailscale IP: $TAILSCALE_IP"

# --- 4.3 Lock SSH to Tailscale only ---
info "Configuring SSH to listen only on Tailscale ($TAILSCALE_IP)..."

# Disable ssh.socket (Ubuntu 24.04 socket activation ignores ListenAddress)
systemctl disable --now ssh.socket 2>/dev/null || true
systemctl enable ssh.service
mkdir -p /run/sshd

# Add ListenAddress
echo "" >> /etc/ssh/sshd_config.d/99-openclaw-hardening.conf
echo "# === Listen ONLY on Tailscale ===" >> /etc/ssh/sshd_config.d/99-openclaw-hardening.conf
echo "ListenAddress $TAILSCALE_IP" >> /etc/ssh/sshd_config.d/99-openclaw-hardening.conf

# Kill leftover sshd from socket activation and restart
kill "$(cat /run/sshd.pid 2>/dev/null)" 2>/dev/null || pkill sshd 2>/dev/null || true
sleep 1

if sshd -t; then
    systemctl restart ssh
    info "SSH now listening only on $TAILSCALE_IP:22"
else
    error "SSH config error. Fix before continuing."
    exit 1
fi

# --- 4.4 Remove public SSH from UFW ---
info "Removing public SSH rule from UFW..."
ufw delete allow ssh 2>/dev/null || true

echo ""
info "=== Section 4 complete ==="
echo ""

# =============================================================================
# SUMMARY
# =============================================================================

echo "========================================================"
echo "  HARDENING COMPLETE"
echo "========================================================"
echo ""
echo "  Tailscale IP:  $TAILSCALE_IP"
echo "  SSH access:    ssh openclaw@$TAILSCALE_IP"
echo "  Public SSH:    CLOSED"
echo ""
echo "  REMAINING MANUAL STEPS:"
echo "  1. Configure ACLs in Tailscale admin panel:"
echo "     https://login.tailscale.com/admin/acls"
echo "  2. Remove inbound SSH rule from Hetzner Cloud Firewall"
echo "  3. Disable key expiry for the VPS in Tailscale admin:"
echo "     https://login.tailscale.com/admin/machines"
echo ""
echo "  IMPORTANT: NEVER run 'tailscale down' on this server."
echo "  If you lose access, use Hetzner Rescue Mode."
echo ""
echo "  To verify hardening, run:"
echo "    curl -fsSL ${REPO_BASE}/scripts/verify-hardening.sh | sudo bash"
echo ""
echo "========================================================"
