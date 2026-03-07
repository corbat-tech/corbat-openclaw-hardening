# 2. Provision VPS

> **TL;DR**: Create a VPS with Ubuntu 24.04 LTS, verify image integrity, configure timezone, and perform initial update.

> **Estimated time**: 10-15 minutes

> **Required level**: Beginner

## Prerequisites

- [ ] Section 1 (Preparation) completed
- [ ] SSH key generated (`~/.ssh/id_ed25519.pub`)
- [ ] Account with VPS provider with payment method

## Objectives

By the end of this section you will have:

- VPS created with Ubuntu 24.04 LTS
- SSH access as root working
- System updated
- Timezone configured

---

## Recommended providers

| Provider | Recommended plan | RAM | CPU | Disk | Price | Notes |
|----------|------------------|-----|-----|------|-------|-------|
| **[Hetzner](https://www.hetzner.com/cloud)** | CPX22 | 4 GB | 2 vCPU | 40 GB NVMe | ~$8/month | **Recommended** -- Best performance/price |
| [Hostinger](https://www.hostinger.com/vps) | KVM 2 | 8 GB | 2 vCPU | 100 GB | ~$8/month | Alternative for beginners (hPanel) |
| [DigitalOcean](https://www.digitalocean.com) | Basic Droplet | 4 GB | 2 vCPU | 80 GB | ~$24/month | Good documentation, full ecosystem |
| [Vultr](https://www.vultr.com) | Cloud Compute | 4 GB | 2 vCPU | 80 GB | ~$24/month | Many global datacenters |
| [Contabo](https://contabo.com/en/vps/) | VPS S | 8 GB | 4 vCPU | 100 GB | ~$5/month | Budget option, worse support |

!!! tip "Recommendation: Hetzner Cloud"
    **Hetzner** is the primary choice in this guide because of:

    - **60% cheaper** than DigitalOcean/Vultr for equivalent specs
    - **Free cloud firewall** -- additional perimeter security layer (see below)
    - **Cloud-init** -- automated provisioning from first boot
    - **GDPR-compliant** -- German company, EU data centers
    - **20 TB monthly traffic** included (vs 4 TB on DigitalOcean)
    - **NVMe RAID10** -- 40.9k IOPS, excellent disk performance
    - **AMD EPYC** -- ~939 Geekbench 6 single-core

    **Hostinger** is still a good alternative for beginners (more guided hPanel interface, 1-click OpenClaw templates).

!!! warning "Avoid"
    - Providers without established reputation
    - Offers that are too cheap (< $3/month)
    - "Unlimited" VPS or with excessive shared resources

    A compromised VPS = your AI agent compromised.

!!! note "Note on Hetzner pricing"
    Hetzner prices will increase by 30-37% starting April 2026 (CPX22 from ~$6 to ~$8/month). Even so, they remain significantly cheaper than the competition.

---

## VPS minimum requirements

| Resource | Minimum | Recommended | Heavy usage |
|----------|---------|-------------|-------------|
| RAM | 4 GB | 8 GB | 16 GB |
| CPU | 1 vCPU | 2 vCPU | 4 vCPU |
| Disk | 40 GB | 80 GB | 160 GB |
| OS | Ubuntu 22.04 LTS | **Ubuntu 24.04 LTS** | Ubuntu 24.04 LTS |
| Network | 1 Gbps | 1 Gbps | 10 Gbps |

---

## Hetzner Cloud Firewall (perimeter security layer)

!!! success "Hetzner exclusive -- free defense layer"
    Hetzner offers **stateful firewalls at the infrastructure level** at no additional cost.
    This adds a security layer **before** traffic reaches your VPS (defense in depth).

### Create firewall before the VPS

1. Go to [console.hetzner.cloud](https://console.hetzner.cloud) -> **Firewalls** -> **Create Firewall**
2. Name: `openclaw-fw`
3. Configure the rules:

| Direction | Protocol | Port | Source | Description |
|-----------|----------|------|--------|-------------|
| **Inbound** | TCP | 22 | Any | SSH (temporary, will be closed after Tailscale) |
| **Outbound** | TCP | 443 | Any | HTTPS (LLM APIs) |
| **Outbound** | TCP | 80 | Any | HTTP (updates) |
| **Outbound** | UDP | 41641 | Any | Tailscale (WireGuard) |
| **Outbound** | UDP | 53 | Any | DNS |

!!! info "Inbound deny-all by default"
    Hetzner Cloud Firewall has an **implicit deny-all policy** for inbound traffic.
    Only explicitly allowed traffic reaches the server.

4. In the **Apply to** tab, select the server you will create next.

### Double-layer firewall architecture

```
Internet -> [Hetzner Cloud Firewall] -> [UFW on VPS] -> [OpenClaw Sandbox]
             Layer 1: Perimeter          Layer 2: Host    Layer 3: App
             (deny-all inbound)          (deny-all inbound) (sandbox "all")
```

!!! tip "After configuring Tailscale"
    Once Tailscale is running (section 4), go back to the Hetzner firewall and **remove the inbound SSH rule (port 22)**. All communication will go through the Tailscale WireGuard tunnel.

---

## Cloud-init (automated provisioning on Hetzner)

!!! tip "Optional but recommended"
    If you use Hetzner, you can automate the initial VPS configuration with cloud-init.
    This ensures reproducible and hardened provisioning from the first boot.

When creating the VPS on Hetzner, in the **Cloud config** section, paste this YAML:

```yaml
#cloud-config
# OpenClaw VPS - Hardened initial provisioning
# Reference: https://community.hetzner.com/tutorials/basic-cloud-config/

# --- Create openclaw user ---
users:
  - name: openclaw
    groups: sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 AAAAC3... YOUR_PUBLIC_KEY_HERE

# --- Disable root SSH ---
disable_root: true
ssh_pwauth: false

# --- Automatic updates ---
package_update: true
package_upgrade: true
packages:
  - ufw
  - fail2ban
  - unattended-upgrades
  - auditd
  - aide
  - curl
  - git
  - gnupg

# --- Configure UFW ---
runcmd:
  - ufw default deny incoming
  - ufw default allow outgoing
  - ufw allow ssh
  - ufw --force enable
  - systemctl enable fail2ban
  - systemctl start fail2ban
  - systemctl enable unattended-upgrades
  - timedatectl set-timezone America/New_York
```

!!! warning "Remove NOPASSWD after initial setup"
    Cloud-init uses `NOPASSWD` so you can run `sudo` immediately after first login (there is no password set yet). After completing sections 3-5, you **must** secure this:

    ```bash
    # 1. Set a strong password for the openclaw user
    sudo passwd openclaw

    # 2. Remove passwordless sudo
    sudo sed -i 's/ALL=(ALL) NOPASSWD:ALL/ALL=(ALL) ALL/' /etc/sudoers.d/90-cloud-init-users

    # 3. Verify sudo now requires password (open a new SSH session)
    sudo whoami  # Should prompt for password
    ```

    Leaving `NOPASSWD` permanently means any process running as `openclaw` can escalate to root without a password prompt.

!!! warning "Replace the SSH key"
    Replace `ssh-ed25519 AAAAC3... YOUR_PUBLIC_KEY_HERE` with your actual public key (`cat ~/.ssh/id_ed25519.pub`).

If you use cloud-init, you can skip the "First access" and "Update system" sections because they will have already run automatically. Go directly to [Section 3](03-system-security.md) for full SSH hardening.

---

## Create the VPS

The steps are similar across all providers:

### 1. Operating system

Select: **Ubuntu 24.04 LTS** (or the most recent LTS available)

!!! info "Why Ubuntu LTS?"
    - 5+ years of security support
    - Extensive documentation
    - Compatible with most software
    - Automatic security updates

### 2. Datacenter location

Choose the datacenter closest to you for lower latency:

| Your location | Recommended datacenter |
|---------------|------------------------|
| US East | New York, Virginia |
| US West | San Francisco, Los Angeles |
| Europe | Germany (Frankfurt) or Netherlands |
| UK | London or Netherlands |
| Asia | Singapore or Tokyo |

### 3. SSH key

During VPS creation, add your SSH public key:

```bash
# On your local machine, copy the public key
cat ~/.ssh/id_ed25519.pub
```

**Expected output:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... openclaw-vps-2026
```

Copy the **complete** content (starts with `ssh-ed25519...`) and paste it in the "SSH Key" field of the provider.

### 4. Root password (if requested)

Some providers ask for a root password. Make it strong but **you won't use it** — you'll access only via SSH key.

```bash
# Generate random password (save it just in case)
openssl rand -base64 20
```

---

## First access

Once the VPS is created (may take 1-5 minutes), the provider will show you the **public IP**.

### Connect as root

```bash
# Connect via SSH (first time will ask if you trust the host)
ssh root@<YOUR_PUBLIC_IP>

# If you used an SSH key in a non-default location:
ssh -i ~/.ssh/id_ed25519 root@<YOUR_PUBLIC_IP>
```

**First connection - verify fingerprint:**
```
The authenticity of host 'xxx.xxx.xxx.xxx' can't be established.
ED25519 key fingerprint is SHA256:XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
```

!!! tip "Verify fingerprint"
    Some providers show the fingerprint in their panel. Compare it before typing "yes".

---

## Verify system integrity

Before configuring anything, verify that the VPS has a clean image.

### Verify operating system

```bash
# Verify it's official Ubuntu
cat /etc/os-release
```

**Expected output:**
```
PRETTY_NAME="Ubuntu 24.04 LTS"
NAME="Ubuntu"
VERSION_ID="24.04"
VERSION="24.04 LTS (Noble Numbat)"
...
```

### Verify existing users

```bash
# View users with login shell
cat /etc/passwd | grep -E ":/bin/(bash|sh|zsh)$"
```

**Expected output (only root and system users):**
```
root:x:0:0:root:/root:/bin/bash
```

!!! danger "If you see unknown users"
    If there are users you don't recognize (not root or system accounts like nobody, daemon, etc.), contact the provider or destroy the VPS and create a new one.

### Verify running processes

```bash
# View processes sorted by memory usage
ps aux --sort=-%mem | head -20
```

You should see only system processes (systemd, sshd, etc.). There should be no web services, crypto miners, or other suspicious processes.

### Verify network connections

```bash
# View listening ports
ss -tlnp
```

**Expected output (only SSH):**
```
State   Recv-Q  Send-Q  Local Address:Port  Peer Address:Port  Process
LISTEN  0       128     0.0.0.0:22          0.0.0.0:*          users:(("sshd",pid=XXX,fd=3))
LISTEN  0       128     [::]:22             [::]:*             users:(("sshd",pid=XXX,fd=4))
```

!!! warning "If you see other open ports"
    Some providers install monitoring agents. Identify them before continuing.

---

## Configure timezone and locale

### Configure timezone

```bash
# View current timezone
timedatectl

# List available timezones
timedatectl list-timezones | grep -E "America|Europe"

# Configure timezone (example: US Eastern)
sudo timedatectl set-timezone America/New_York

# Verify
date
```

**Expected output:**
```
Sat Feb  1 10:30:00 EST 2026
```

### Configure locale (optional)

```bash
# Generate US locale (recommended for readable logs)
sudo locale-gen en_US.UTF-8

# Verify
locale
```

---

## Update system

```bash
# Update package list
apt update

# Apply updates
apt upgrade -y
```

!!! info "Held packages"
    If you see "The following packages have been kept back", you can ignore it for now or run:
    ```bash
    apt dist-upgrade -y
    ```

### Reboot if necessary

```bash
# Check if reboot is pending
[ -f /var/run/reboot-required ] && echo "Reboot required" || echo "No reboot required"

# If necessary, reboot
reboot
```

Wait 30-60 seconds and reconnect:

```bash
ssh root@<YOUR_PUBLIC_IP>
```

---

## Data to save

Save this information in a secure place (password manager):

| Data | Value | Notes |
|------|-------|-------|
| Provider | _______________ | Hetzner, Hostinger, etc. |
| Public IP | `___.___.___.___` | You'll stop using this later |
| Temporary user | `root` | Only for initial setup |
| Datacenter | _______________ | For reference |

!!! info "You'll stop using this public IP"
    After configuring Tailscale, you'll only access via Tailscale's private IP.

---

## Troubleshooting

### Error: "Connection refused"

**Cause:** The VPS hasn't finished starting or SSH isn't running.

**Solution:**
- Wait 2-3 minutes
- Verify in the provider's panel that the VPS is "Running"
- Some providers have web console to access without SSH

### Error: "Permission denied (publickey)"

**Cause:** The SSH key is not correctly configured.

**Solution:**
```bash
# Verify you're using the correct key
ssh -v -i ~/.ssh/id_ed25519 root@<YOUR_PUBLIC_IP>

# The -v flag shows debug info
```

### Error: "Host key verification failed"

**Cause:** The server fingerprint changed (possible reinstall or MITM attack).

**Solution:**
```bash
# If you reinstalled the VPS, remove the old entry
ssh-keygen -R <YOUR_PUBLIC_IP>

# Reconnect
ssh root@<YOUR_PUBLIC_IP>
```

!!! danger "If you did NOT reinstall the VPS"
    An unexpected host key change may indicate a man-in-the-middle attack.
    Contact the provider before continuing.

### System is very slow

**Cause:** Could be an oversold VPS or datacenter issues.

**Solution:**
```bash
# Check resources
free -h        # Memory
df -h          # Disk
top            # CPU and processes

# If resources look fine but still slow, contact provider
```

---

## Summary

| Configuration | Expected status |
|---------------|-----------------|
| VPS created | ✅ |
| Ubuntu 24.04 LTS | ✅ |
| SSH working | ✅ |
| Image verified | ✅ |
| Timezone configured | ✅ |
| System updated | ✅ |

---

**Next:** [3. System security](03-system-security.md) — Create user, SSH hardening, firewall.
