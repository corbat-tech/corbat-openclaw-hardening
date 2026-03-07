# 3. System Security

> **TL;DR**: Create non-root user, secure SSH per CIS Benchmark, configure firewall, fail2ban, auditing, and integrity monitoring.

> **Estimated time**: 30-40 minutes

> **Required level**: Intermediate

## Prerequisites

- [ ] VPS created with Ubuntu 24.04 LTS
- [ ] Root SSH access working
- [ ] Ed25519 SSH key generated locally

## Objectives

By the end of this section you will have:

- Dedicated `openclaw` user without root privileges
- Complete SSH hardening per CIS Benchmark Ubuntu 24.04 L1
- UFW firewall with deny-all policy
- Fail2ban protecting against brute-force
- Automatic security updates
- Critical event auditing (auditd)
- File integrity monitoring (AIDE)

---

## Create dedicated user

!!! danger "Never run OpenClaw as root"
    An AI agent with root access can completely compromise the system.

```bash
# Create 'openclaw' user with home directory
adduser openclaw
```

It will ask for:

- **Password:** use a strong one (minimum 16 characters)
- **Full name, etc.:** you can leave blank (Enter)

```bash
# Give sudo permissions (needed for initial setup)
usermod -aG sudo openclaw
```

### Verify creation

```bash
# Verify user exists
id openclaw
```

**Expected output:**
```
uid=1001(openclaw) gid=1001(openclaw) groups=1001(openclaw),27(sudo)
```

---

## Configure SSH for the new user

### Copy SSH key to user

```bash
# Create .ssh directory for user
mkdir -p /home/openclaw/.ssh

# Copy authorized keys
cp /root/.ssh/authorized_keys /home/openclaw/.ssh/

# Adjust permissions (CRITICAL for security)
chown -R openclaw:openclaw /home/openclaw/.ssh
chmod 700 /home/openclaw/.ssh
chmod 600 /home/openclaw/.ssh/authorized_keys
```

### Verify access before continuing

!!! danger "Don't proceed without testing this"
    Open a **new terminal** (without closing the current one) and test:

```bash
# From your local machine, in a NEW terminal
ssh openclaw@<YOUR_PUBLIC_IP>
```

If it works, continue. If not, review permissions before proceeding.

---

## Secure SSH (CIS Benchmark 5.2 complete)

This configuration complies with **CIS Benchmark Ubuntu 24.04 LTS Level 1** for SSH.

### Create backup of original configuration

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
```

### Create hardened configuration

```bash
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf << 'EOF'
# ============================================================
# SSH Hardening - CIS Benchmark Ubuntu 24.04 LTS L1
# Date: 2026-02
# Reference: https://www.cisecurity.org/benchmark/ubuntu_linux
# ============================================================

# --- 5.2.4 - Secure ciphers ---
# Only modern and secure encryption algorithms
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr

# --- 5.2.5 - Secure MACs ---
# Only secure message authentication algorithms
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256

# --- 5.2.6 - Secure Key Exchange ---
# Only secure key exchange algorithms
# Includes sntrup761x25519-sha512 for post-quantum resistance (recommended since April 2025)
KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org,ecdh-sha2-nistp521,ecdh-sha2-nistp384,ecdh-sha2-nistp256,diffie-hellman-group-exchange-sha256

# --- 5.2.7 - Warning banner ---
Banner /etc/issue.net

# --- 5.2.8 - Detailed logging ---
LogLevel VERBOSE

# --- 5.2.9 - Disable X11 forwarding ---
X11Forwarding no

# --- 5.2.10 - MaxAuthTries ---
# Maximum 4 authentication attempts per connection
MaxAuthTries 4

# --- 5.2.11 - Ignore rhosts ---
IgnoreRhosts yes

# --- 5.2.12 - Disable host-based authentication ---
HostbasedAuthentication no

# --- 5.2.13 - Disable root login ---
PermitRootLogin no

# --- 5.2.14 - Disable empty passwords ---
PermitEmptyPasswords no

# --- 5.2.15 - Disable user environment ---
PermitUserEnvironment no

# --- 5.2.17 - Connection timeout ---
# Disconnect inactive clients after 15 minutes (300s * 3)
ClientAliveInterval 300
ClientAliveCountMax 3

# --- 5.2.18 - Login grace time ---
# Only 60 seconds to complete authentication
LoginGraceTime 60

# --- 5.2.19 - Limit users ---
# CRITICAL: Only openclaw user can connect
AllowUsers openclaw

# --- 5.2.20 - MaxStartups (anti-DoS) ---
# Limit simultaneous unauthenticated connections
MaxStartups 10:30:60

# --- 5.2.21 - MaxSessions ---
MaxSessions 10

# --- 5.2.22 - Disable password authentication ---
PasswordAuthentication no
KbdInteractiveAuthentication no

# --- 5.2.23 - Use only public keys ---
PubkeyAuthentication yes

# --- Additional security configuration ---

# Allow local forwarding only (needed for OpenClaw access via SSH tunnel)
AllowTcpForwarding local
AllowAgentForwarding no

# Disable tunnels
PermitTunnel no

# Note: "Protocol 2" is obsolete in OpenSSH 9.x (only supports v2)
# ListenAddress will be configured after installing Tailscale
# to listen only on the Tailscale interface
EOF
```

### Create legal warning banner

```bash
sudo tee /etc/issue.net << 'EOF'
***************************************************************************
                            PRIVATE SYSTEM

  Unauthorized access is prohibited. All activities are monitored and
  logged. Use of this system implies acceptance of security policies.
***************************************************************************
EOF
```

### Apply CIS permissions

```bash
# 5.2.1 - sshd_config permissions
sudo chmod 600 /etc/ssh/sshd_config
sudo chown root:root /etc/ssh/sshd_config

# 5.2.2 - Host private key permissions
sudo chmod 600 /etc/ssh/ssh_host_*_key
sudo chown root:root /etc/ssh/ssh_host_*_key

# 5.2.3 - Host public key permissions
sudo chmod 644 /etc/ssh/ssh_host_*_key.pub
sudo chown root:root /etc/ssh/ssh_host_*_key.pub

# Hardening config file permissions
sudo chmod 600 /etc/ssh/sshd_config.d/99-hardening.conf
sudo chown root:root /etc/ssh/sshd_config.d/99-hardening.conf
```

### Verify configuration before applying

!!! danger "CRITICAL: Verify syntax before restarting"
    A syntax error can lock you out of SSH.

```bash
# Verify syntax
sudo sshd -t
```

**Expected output:** no output (silence = success)

If there are errors, fix them before continuing.

```bash
# If no errors, restart SSH
sudo systemctl restart sshd

# Verify it's running
sudo systemctl status sshd
```

### Verify applied controls

```bash
# CIS SSH verification script
echo "=== CIS SSH Verification ==="
echo -n "PasswordAuthentication: "
sudo sshd -T | grep -i "^passwordauthentication"
echo -n "PermitRootLogin: "
sudo sshd -T | grep -i "^permitrootlogin"
echo -n "MaxAuthTries: "
sudo sshd -T | grep -i "^maxauthtries"
echo -n "X11Forwarding: "
sudo sshd -T | grep -i "^x11forwarding"
echo -n "LogLevel: "
sudo sshd -T | grep -i "^loglevel"
echo -n "AllowUsers: "
sudo sshd -T | grep -i "^allowusers"
echo -n "Ciphers: "
sudo sshd -T | grep -i "^ciphers"
```

**Expected output:**
```
=== CIS SSH Verification ===
PasswordAuthentication: passwordauthentication no
PermitRootLogin: permitrootlogin no
MaxAuthTries: maxauthtries 4
X11Forwarding: x11forwarding no
LogLevel: loglevel VERBOSE
AllowUsers: allowusers openclaw
Ciphers: ciphers chacha20-poly1305@openssh.com,...
```

### Verify access with new configuration

!!! warning "Keep your current session open"
    Don't close your session until you verify new access.

In a **new terminal**:

```bash
# This should work
ssh openclaw@<YOUR_PUBLIC_IP>

# This should FAIL (root disabled)
ssh root@<YOUR_PUBLIC_IP>
# Expected: Permission denied (publickey)
```

---

## Configure firewall (UFW)

```bash
# Configure default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH (temporary, will be removed after Tailscale)
sudo ufw allow ssh

# Enable firewall
sudo ufw enable
# Confirm with 'y'
```

### Verify firewall

```bash
sudo ufw status verbose
```

**Expected output:**
```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
New profiles: skip

To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
22/tcp (v6)                ALLOW IN    Anywhere (v6)
```

---

## Fail2ban (brute-force protection)

Fail2ban bans IPs that attempt multiple failed logins.

!!! info "Verified version"
    This configuration was tested with fail2ban **1.0.2** on Ubuntu 24.04 LTS.
    Check your version with: `fail2ban-client --version`

```bash
# Install
sudo apt install -y fail2ban

# Create local configuration (won't be overwritten in updates)
sudo tee /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban for 1 hour
bantime = 3600
# Time window to count failures
findtime = 600
# Maximum failures before ban
maxretry = 5
# Use systemd for logs
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
# No logpath needed: systemd backend (set in [DEFAULT]) reads from journald
maxretry = 3
bantime = 86400
EOF

# Enable and start
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Verify fail2ban

```bash
sudo fail2ban-client status sshd
```

**Expected output:**
```
Status for the jail: sshd
|- Filter
|  |- Currently failed: 0
|  |- Total failed:     0
|  `- File list:        /var/log/auth.log
`- Actions
   |- Currently banned: 0
   |- Total banned:     0
   `- Banned IP list:
```

---

## Alternative: CrowdSec (collaborative protection)

!!! tip "CrowdSec vs Fail2Ban"
    CrowdSec is a modern alternative to Fail2Ban with community threat intelligence.

    | Feature | Fail2Ban | CrowdSec |
    |---|---|---|
    | **Resources** | Very low | Moderate |
    | **Community intel** | No | Yes (shared blocklists) |
    | **Detection** | Reactive (log-based) | Proactive (behavioral) |
    | **Best for** | Simple VPS, low traffic | Production, multi-server |
    | **nftables integration** | Via actions | Native |

    **For a personal VPS with OpenClaw**, Fail2Ban is sufficient. Consider CrowdSec if you plan to scale or need proactive protection.

### Install CrowdSec (optional, alternative to Fail2Ban)

```bash
# Download and inspect the install script first
curl -sO https://install.crowdsec.net/install.sh
less install.sh  # Review the script
sudo bash install.sh
rm install.sh

# Install CrowdSec
sudo apt install -y crowdsec crowdsec-firewall-bouncer-nftables

# Verify installation
sudo cscli version

# View active decisions (blocked IPs)
sudo cscli decisions list

# View alerts
sudo cscli alerts list
```

!!! warning "Do not use Fail2Ban and CrowdSec simultaneously for SSH"
    Choose one or the other to avoid conflicts. If you install CrowdSec, disable the SSH jail in Fail2Ban.

---

## Automatic security updates

```bash
# Install
sudo apt install -y unattended-upgrades

# Configure for automatic security updates
sudo dpkg-reconfigure -plow unattended-upgrades
# Select "Yes"
```

### Verify configuration

```bash
cat /etc/apt/apt.conf.d/20auto-upgrades
```

**Expected output:**
```
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
```

---

## Configure auditing (auditd)

The audit system records critical security events.

!!! info "Verified version"
    This configuration was tested with auditd **3.1.2** on Ubuntu 24.04 LTS.
    Check your version with: `auditctl -v`

```bash
# Install auditd
sudo apt install -y auditd audispd-plugins

# Enable service
sudo systemctl enable auditd
sudo systemctl start auditd
```

### Create audit rules

```bash
sudo tee /etc/audit/rules.d/openclaw.rules << 'EOF'
# ============================================================
# Audit Rules for OpenClaw VPS
# ============================================================

# Remove previous rules
-D

# Audit buffer
-b 8192

# What to do if buffer fills (0=silence, 1=printk, 2=panic)
-f 1

# --- Monitor critical system files ---
-w /etc/ssh/sshd_config -p wa -k sshd_config
-w /etc/ssh/sshd_config.d -p wa -k sshd_config
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudoers_changes
-w /etc/sudoers.d -p wa -k sudoers_changes

# --- Monitor SSH keys ---
-w /home/openclaw/.ssh -p wa -k ssh_keys
-w /root/.ssh -p wa -k ssh_keys

# --- Monitor OpenClaw ---
-w /home/openclaw/openclaw -p wa -k openclaw_changes
-w /home/openclaw/openclaw/.env -p r -k env_access

# --- Monitor sudo commands ---
-w /var/log/sudo.log -p wa -k sudo_log

# --- Monitor service changes ---
-w /etc/systemd/system -p wa -k systemd_changes
-w /lib/systemd/system -p wa -k systemd_changes

# --- Monitor logins ---
-w /var/log/lastlog -p wa -k logins
-w /var/log/faillog -p wa -k logins

# --- Make rules immutable (requires reboot to change) ---
-e 2
EOF
```

### Load rules

```bash
# Reload rules
sudo augenrules --load

# Restart service
sudo systemctl restart auditd
```

### Verify auditing

```bash
# View active rules
sudo auditctl -l
```

**Expected output:** List of `-w` rules configured

```bash
# View recent events (may be empty initially)
sudo ausearch -ts recent
```

---

## Integrity monitoring (AIDE)

AIDE (Advanced Intrusion Detection Environment) detects unauthorized file changes.

!!! info "Verified version"
    This configuration was tested with AIDE **0.18.6** on Ubuntu 24.04 LTS.
    Check your version with: `aide --version`

```bash
# Install AIDE
sudo apt install -y aide aide-common
```

### Configure paths to monitor

```bash
sudo tee /etc/aide/aide.conf.d/99-openclaw << 'EOF'
# Critical OpenClaw files
/home/openclaw/openclaw/config CONTENT_EX
/home/openclaw/openclaw/.env PERMS
/home/openclaw/.ssh CONTENT_EX

# Critical system files
/etc/ssh CONTENT_EX
/etc/passwd CONTENT_EX
/etc/shadow PERMS
/etc/sudoers CONTENT_EX
EOF
```

### Initialize database

!!! info "This process takes several minutes"
    AIDE scans the entire system to create the initial database.

```bash
# Initialize database (may take 5-10 minutes)
sudo aideinit
```

```bash
# Move database to active location
sudo cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db
```

### Verify integrity

```bash
# Run verification (run periodically or via cron)
sudo aide --check
```

**Expected output (if no changes):**
```
AIDE found NO differences between database and filesystem. Looks okay!!
```

### Schedule automatic verification

```bash
# Create cron job for daily verification
sudo tee /etc/cron.daily/aide-check << 'EOF'
#!/bin/bash
/usr/bin/aide --check > /var/log/aide-check.log 2>&1
if [ $? -ne 0 ]; then
    echo "AIDE detected changes - review /var/log/aide-check.log" | logger -t aide
fi
EOF

sudo chmod +x /etc/cron.daily/aide-check
```

---

## Kernel hardening (sysctl)

Configure kernel parameters for enhanced network security.

### Create security configuration

```bash
sudo tee /etc/sysctl.d/99-security-hardening.conf << 'EOF'
# ============================================================
# Kernel Security Hardening
# Reference: CIS Benchmark Ubuntu 24.04 - Section 3.2
# ============================================================

# --- Disable IP forwarding (3.2.1) ---
net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0

# --- Disable sending redirects (3.2.2) ---
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0

# --- Don't accept source routing (3.2.3) ---
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv6.conf.all.accept_source_route = 0
net.ipv6.conf.default.accept_source_route = 0

# --- Don't accept ICMP redirects (3.2.4) ---
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0

# --- Don't accept secure ICMP redirects (3.2.5) ---
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0

# --- Log suspicious packets (3.2.6) ---
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1

# --- Ignore broadcast ICMP (3.2.7) ---
net.ipv4.icmp_echo_ignore_broadcasts = 1

# --- Ignore bogus ICMP responses (3.2.8) ---
net.ipv4.icmp_ignore_bogus_error_responses = 1

# --- Enable reverse path filtering (3.2.9) ---
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1

# --- Enable TCP SYN Cookies (3.2.10) ---
net.ipv4.tcp_syncookies = 1

# --- Don't accept IPv6 router advertisements (3.2.11) ---
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF
```

!!! note "Tailscale compatibility"
    If you plan to use this VPS as a Tailscale subnet router or exit node, change `ip_forward` to `1`. For a standard OpenClaw deployment (the scope of this guide), `0` is correct.

### Apply configuration

```bash
# Apply immediately
sudo sysctl -p /etc/sysctl.d/99-security-hardening.conf

# Verify it was applied
sudo sysctl net.ipv4.ip_forward
sudo sysctl net.ipv4.conf.all.send_redirects
```

**Expected output:**

```
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
```

---

## Final security verification

Run this script to verify all controls:

```bash
echo "============================================"
echo "SYSTEM SECURITY VERIFICATION"
echo "============================================"
echo ""

echo "--- openclaw user ---"
id openclaw && echo "✅ User exists" || echo "❌ User does NOT exist"
echo ""

echo "--- SSH Hardening ---"
sudo sshd -T 2>/dev/null | grep -q "passwordauthentication no" && echo "✅ Password auth disabled" || echo "❌ Password auth ACTIVE"
sudo sshd -T 2>/dev/null | grep -q "permitrootlogin no" && echo "✅ Root login disabled" || echo "❌ Root login ACTIVE"
sudo sshd -T 2>/dev/null | grep -q "allowusers openclaw" && echo "✅ AllowUsers configured" || echo "❌ AllowUsers NOT configured"
echo ""

echo "--- Firewall ---"
sudo ufw status | grep -q "Status: active" && echo "✅ UFW active" || echo "❌ UFW NOT active"
echo ""

echo "--- Fail2ban ---"
systemctl is-active fail2ban >/dev/null && echo "✅ Fail2ban active" || echo "❌ Fail2ban NOT active"
echo ""

echo "--- Unattended Upgrades ---"
systemctl is-active unattended-upgrades >/dev/null && echo "✅ Auto-updates active" || echo "❌ Auto-updates NOT active"
echo ""

echo "--- Auditd ---"
systemctl is-active auditd >/dev/null && echo "✅ Auditd active" || echo "❌ Auditd NOT active"
sudo auditctl -l | grep -q "openclaw" && echo "✅ OpenClaw rules loaded" || echo "❌ OpenClaw rules NOT loaded"
echo ""

echo "--- AIDE ---"
[ -f /var/lib/aide/aide.db ] && echo "✅ AIDE initialized" || echo "❌ AIDE NOT initialized"
echo ""

echo "============================================"
echo "Verification completed"
echo "============================================"
```

---

## Troubleshooting

### Error: "Permission denied (publickey)"

**Cause**: The SSH key is not correctly configured for the user.

**Solution**:
```bash
# Verify permissions
ls -la /home/openclaw/.ssh/
# authorized_keys must have permissions 600
# .ssh must have permissions 700

# Fix if necessary
sudo chmod 700 /home/openclaw/.ssh
sudo chmod 600 /home/openclaw/.ssh/authorized_keys
sudo chown -R openclaw:openclaw /home/openclaw/.ssh
```

### Error: "Connection refused" after restarting SSH

**Cause**: Syntax error in SSH configuration.

**Solution**:
```bash
# If you have another session open, check the error
sudo journalctl -u sshd -n 50

# Restore backup
sudo cp /etc/ssh/sshd_config.backup.* /etc/ssh/sshd_config
sudo rm /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl restart sshd
```

### Error: "Too many authentication failures"

**Cause**: You've been banned by fail2ban.

**Solution**:
```bash
# View banned IPs
sudo fail2ban-client status sshd

# Unban your IP
sudo fail2ban-client set sshd unbanip <YOUR_IP>
```

---

## Summary of completed work

| Configuration | Expected status | CIS Reference |
|---------------|-----------------|---------------|
| User `openclaw` created | ✅ | - |
| SSH with public key | ✅ | 5.2.23 |
| Password login disabled | ✅ | 5.2.22 |
| Root login disabled | ✅ | 5.2.13 |
| Secure ciphers | ✅ | 5.2.4 |
| Secure MACs | ✅ | 5.2.5 |
| MaxAuthTries = 4 | ✅ | 5.2.10 |
| Banner configured | ✅ | 5.2.7 |
| Firewall active (deny all) | ✅ | - |
| Fail2ban active | ✅ | - |
| Automatic updates | ✅ | - |
| Auditd configured | ✅ | - |
| AIDE initialized | ✅ | - |
| SSH allowed (temporary) | ✅ | - |

!!! info "Public SSH port is temporary"
    In the next step we'll configure Tailscale and **remove** public SSH access.

---

## Remove sudo from openclaw user

!!! danger "Principle of least privilege"
    The `openclaw` user was added to the `sudo` group to perform the initial setup in sections 3-5. Once all setup is complete (including Tailscale in section 4 and OpenClaw in section 5), sudo access should be removed. An AI agent user with permanent sudo is a critical risk — any compromise of the agent grants full root access.

After completing all setup steps in sections 3 through 5, remove sudo access from the `openclaw` user:

```bash
# Run this from a separate root or admin session, NOT as the openclaw user
sudo deluser openclaw sudo
```

Verify the change:

```bash
id openclaw
```

**Expected output (no `sudo` group):**
```
uid=1001(openclaw) gid=1001(openclaw) groups=1001(openclaw)
```

!!! warning "Keep a recovery session"
    Before removing sudo, make sure you have another way to administer the system (e.g., root access via the VPS provider's console or another admin user with sudo). If you need to perform administrative tasks later, you can temporarily re-add sudo access from that recovery session.

---

**Next:** [4. Private Access (Tailscale)](04-private-access.md) — Configure VPN and remove public access.
