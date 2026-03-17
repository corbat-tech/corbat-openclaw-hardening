# 4. Private Access with Tailscale

> **TL;DR**: Install Tailscale securely, configure mandatory ACLs for zero-trust, close public SSH, and optionally enable Tailnet Lock.

> **Estimated time**: 20-30 minutes

> **Required level**: Intermediate

## Prerequisites

- [ ] Section 3 (System security) completed
- [ ] User `openclaw` working
- [ ] Tailscale account created (with MFA on identity provider)

## Objectives

By the end of this section you will have:

- Tailscale installed and verified on the VPS
- ACLs configured (zero-trust, no permit-all)
- Public SSH removed (access only via Tailscale)
- Optionally: Tailnet Lock and alert webhooks

---

## What is Tailscale?

- Peer-to-peer mesh VPN based on WireGuard
- Free tier: up to 100 devices, 3 users
- Each device gets a private IP like `100.x.x.x`
- End-to-end encryption

```
┌─────────────────────────────────────────────┐
│              INTERNET                       │
│                  ❌                         │
│    No direct access to VPS                  │
└─────────────────────────────────────────────┘
          ▲
          │ Tailscale VPN (WireGuard)
          │ E2E Encryption
          ▼
┌─────────────────────────────────────────────┐
│         YOUR DEVICE                         │
│  Tailscale IP: 100.y.y.y                    │
└─────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────┐
│              VPS                            │
│  Tailscale IP: 100.x.x.x (only path)        │
│  Public IP: closed                          │
└─────────────────────────────────────────────┘
```

!!! info "Placeholders in this section"
    In the examples in this section:

    - `<YOUR_TAILSCALE_IP>` or `100.x.x.x` = Tailscale IP of your VPS (obtained with `tailscale ip -4`)
    - `100.y.y.y` = Tailscale IP of your local device
    - `<YOUR_PUBLIC_IP>` = Public IP of the VPS (the one the provider gave you)

    Replace these values with your actual IPs in each command.

---

## Install Tailscale on the VPS

Connect to the VPS (still via public IP):

```bash
ssh openclaw@<YOUR_PUBLIC_IP>
```

### Option A: Installation from APT repository (RECOMMENDED)

This option is more secure because it verifies package signatures.

```bash
# Add Tailscale GPG key
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null

# Add repository
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list

# Install
sudo apt update
sudo apt install -y tailscale

# Verify it was installed from official repo
apt-cache policy tailscale
```

**Expected output:**
```
tailscale:
  Installed: 1.XX.X
  Candidate: 1.XX.X
  Version table:
 *** 1.XX.X 500
        500 https://pkgs.tailscale.com/stable/ubuntu noble/main amd64 Packages
```

### Option B: Installation script (with verification)

If you prefer the official script, verify it before executing:

```bash
# 1. Download script
curl -fsSL https://tailscale.com/install.sh -o /tmp/tailscale-install.sh

# 2. Verify content (look for suspicious commands)
# Check that it only downloads from tailscale.com/pkgs.tailscale.com domains
less /tmp/tailscale-install.sh

# 3. If everything looks correct, execute
sudo bash /tmp/tailscale-install.sh

# 4. Clean up
rm /tmp/tailscale-install.sh
```

---

## Start Tailscale

```bash
sudo tailscale up
```

It will give you a URL to authenticate. Open it in your browser and sign in with your Tailscale account.

### Verify connection

```bash
# View assigned Tailscale IP
tailscale ip -4

# View full status
tailscale status
```

**Expected output:**
```
100.x.x.x    your-vps     linux   -
100.y.y.y    your-laptop  macOS   active; relay "nyc", tx 1234 rx 5678
```

Note the Tailscale IP of the VPS (something like `100.x.x.x`). This will be your **new way to access**.

---

## Install Tailscale on your device

### macOS

```bash
# With Homebrew
brew install --cask tailscale
```

Or download from [tailscale.com/download](https://tailscale.com/download)

### Linux

```bash
# Using APT repository (Ubuntu/Debian)
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.noarmor.gpg | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/noble.tailscale-keyring.list | sudo tee /etc/apt/sources.list.d/tailscale.list
sudo apt update && sudo apt install -y tailscale
sudo tailscale up
```

### Windows / iOS / Android

Download the app from the corresponding store or [tailscale.com/download](https://tailscale.com/download)

---

## Test connection via Tailscale

From your local device (with Tailscale activated):

```bash
# Use the VPS Tailscale IP
ssh openclaw@<YOUR_TAILSCALE_IP>
```

!!! success "If it works, you now have private access"
    From now on, use this IP for everything.

---

## Configure ACLs (MANDATORY)

!!! danger "Don't skip this step"
    Without ACLs, any device in your Tailnet can access any other.
    This violates the zero-trust principle and is a security risk.

By default, Tailscale allows all devices to communicate with each other (`"*": ["*:*"]`). This is NOT secure for a server with OpenClaw.

### Configure restrictive ACL

1. Go to [login.tailscale.com/admin/acls](https://login.tailscale.com/admin/acls)
2. Replace the **entire** content with:

```json
{
  // === ACLs for OpenClaw VPS ===
  // Reference: https://tailscale.com/kb/1196/security-hardening

  "acls": [
    // Only owner can access the VPS
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:vps:*"]
    },
    // VPS can access Internet (for LLM APIs)
    {
      "action": "accept",
      "src": ["tag:vps"],
      "dst": ["autogroup:internet:*"]
    }
    // NOTE: VPS cannot initiate connections to other devices
  ],

  // Tags and their owners
  "tagOwners": {
    "tag:vps": ["autogroup:owner"]
  },

  // Tailscale SSH configuration
  "ssh": [
    {
      "action": "accept",
      "src": ["autogroup:owner"],
      "dst": ["tag:vps"],
      "users": ["openclaw"]
    }
  ],

  // Tests to validate ACLs
  "tests": [
    // Verify owner can access VPS
    {
      "src": "autogroup:owner",
      "accept": ["tag:vps:22", "tag:vps:3000"]
    },
    // Verify VPS can access Internet
    {
      "src": "tag:vps",
      "accept": ["8.8.8.8:443"]
    },
    // Verify VPS cannot access owner's devices
    {
      "src": "tag:vps",
      "deny": ["autogroup:owner:22", "autogroup:owner:80"]
    }
  ]
}
```

3. Click **Save** and verify that tests pass.

### Apply tag to VPS

!!! danger "NEVER run `tailscale down` once public SSH is closed"
    If Tailscale is your only way to access the server and you run `tailscale down`, you will lose all access. The only recovery is via the provider's rescue mode (see Troubleshooting below). Always use `--reset` to reconfigure without dropping connectivity.

On the VPS, run:

```bash
sudo tailscale up --advertise-tags=tag:vps --reset
```

It will print a URL to re-authenticate. Open it in your browser and authorize. **Do NOT use `tailscale down` + `tailscale up` — that will cut your connection.**

### Verify tags

```bash
tailscale status
```

**Expected output:**
```
100.x.x.x    your-vps        tagged-devices  linux   -
```

The VPS should appear as `tagged-devices` instead of your email.

---

## Remove public SSH access

This is the critical step. Once Tailscale is verified, **close public port 22**.

### Step 1: Configure SSH to listen only on Tailscale

```bash
# Get your Tailscale IP
TAILSCALE_IP=$(tailscale ip -4)
echo "Tailscale IP: $TAILSCALE_IP"
```

Add the ListenAddress directive automatically (avoids manual copy errors):

```bash
# Add ListenAddress with your actual Tailscale IP
echo "# === Listen ONLY on Tailscale ===" | sudo tee -a /etc/ssh/sshd_config.d/99-openclaw-hardening.conf
echo "ListenAddress $(tailscale ip -4)" | sudo tee -a /etc/ssh/sshd_config.d/99-openclaw-hardening.conf

# Verify it was added correctly
tail -2 /etc/ssh/sshd_config.d/99-openclaw-hardening.conf
```

**Expected output:**
```
# === Listen ONLY on Tailscale ===
ListenAddress 100.64.0.1
```

!!! warning "Example IP"
    Your IP will be different (something like `100.x.x.x`). The command automatically uses your actual IP.

### Step 2: Disable ssh.socket (Ubuntu 24.04)

!!! warning "Critical: Ubuntu 24.04 uses socket activation by default"
    Ubuntu 24.04 starts SSH via `ssh.socket` (systemd socket activation), which listens on `0.0.0.0:22` and **ignores the `ListenAddress` directive** in sshd_config. You must disable it and switch to the traditional `ssh.service` for `ListenAddress` to take effect.

```bash
# Disable socket activation (ignores ListenAddress)
sudo systemctl disable --now ssh.socket

# Enable traditional ssh service (respects ListenAddress)
sudo systemctl enable ssh.service

# Create privilege separation directory (normally created by ssh.socket)
sudo mkdir -p /run/sshd

# Kill any leftover sshd processes from socket activation
sudo kill $(cat /run/sshd.pid 2>/dev/null) 2>/dev/null || true
```

### Step 3: Ensure SSH starts after Tailscale on boot

!!! danger "Critical: without this, SSH will fail after every reboot"
    Since SSH is configured to listen only on the Tailscale IP (`ListenAddress`), it **must**
    wait for Tailscale to be ready before starting. Without this drop-in, SSH tries to bind
    to the Tailscale IP before it exists, fails with "Cannot assign requested address", and
    you lose SSH access until you manually restart it via the VNC console.

```bash
# Create systemd drop-in so SSH waits for Tailscale
sudo mkdir -p /etc/systemd/system/ssh.service.d
sudo tee /etc/systemd/system/ssh.service.d/after-tailscale.conf > /dev/null << 'EOF'
[Unit]
After=tailscaled.service
Wants=tailscaled.service

[Service]
RestartSec=5
Restart=on-failure
EOF

sudo systemctl daemon-reload
```

This ensures:

- SSH **waits** for `tailscaled` to start before binding
- SSH **automatically restarts** if it fails (e.g., Tailscale was slow to assign the IP)

### Step 4: Verify syntax

```bash
sudo sshd -t
```

**If there are errors, do NOT restart SSH.** Fix them first.

### Step 5: Restart SSH

```bash
sudo systemctl restart ssh
```

### Step 6: Remove firewall rule

```bash
# Remove rule that allows SSH from anywhere
sudo ufw delete allow ssh

# Verify status
sudo ufw status
```

**Expected output:**
```
Status: active

To                         Action      From
--                         ------      ----
(no SSH rules)
```

---

## Final verification

!!! danger "Test BEFORE closing your current session"

### In a NEW terminal:

```bash
# 1. Connect via Tailscale (MUST work)
ssh openclaw@<YOUR_TAILSCALE_IP>

# 2. Verify public SSH does NOT work
ssh openclaw@<YOUR_PUBLIC_IP>
# Expected: Connection timed out or Connection refused
```

### Verify SSH only listens on Tailscale

```bash
sudo ss -tlnp | grep sshd
```

**Expected output:**
```
LISTEN  0  128  100.x.x.x:22  0.0.0.0:*  users:(("sshd",pid=XXX,fd=3))
```

!!! warning "Verify console access before closing your session"
    Your local password is the only recovery path if Tailscale fails to start after a reboot.
    Open the **Hetzner VNC console** (Console icon in the panel) and verify you can login
    with your `openclaw` user password. If you skipped setting a password during user creation,
    set one now with `sudo passwd openclaw` — SSH password authentication remains disabled
    regardless.

!!! success "If you see only your Tailscale IP, hardening is complete"

---

## Tailnet Lock (Advanced Security)

!!! tip "Recommended for maximum security"
    Tailnet Lock ensures that even if Tailscale (the company) were compromised,
    they couldn't inject malicious devices into your network.

### What is Tailnet Lock?

- Requires cryptographic signatures to add devices
- Trusted devices sign new devices
- Even Tailscale (the company) cannot add devices without your signature

### Activate Tailnet Lock

**From your main device (NOT the VPS):**

```bash
# 1. Initialize Tailnet Lock
tailscale lock init
```

It will show you a signing key. **Store it in a secure offline location.**

```bash
# 2. View your signing key and nodes
tailscale lock status
```

```bash
# 3. View the VPS node key (you need this to sign it)
tailscale status
# Find the VPS line and copy the node key
```

```bash
# 4. Sign the VPS from your main device
tailscale lock sign nodekey:<VPS_NODE_KEY>
```

### Verify Tailnet Lock

```bash
tailscale lock status
```

**Expected output:**
```
Tailnet lock is ENABLED
...
Trusted signing keys:
  - nlpub:XXXX (this node)

Filtered nodes:
  (none, if all are signed)
```

!!! warning "Save the recovery keys"
    If you lose access to all signing devices, you'll lose access to the network.
    Store the keys in a password manager or secure offline location.

---

## Alert Webhooks (Optional)

Receive notifications when something changes in your Tailnet.

### Configure webhooks

1. Go to [login.tailscale.com/admin/settings/webhooks](https://login.tailscale.com/admin/settings/webhooks)

2. Add a webhook:
   - **Slack**: Incoming webhook URL
   - **Discord**: Discord webhook URL
   - **Custom**: Your HTTP/HTTPS endpoint

3. Select events to monitor:

| Event | Description | Recommendation |
|-------|-------------|----------------|
| `nodeCreated` | New device added | ✅ Enable |
| `nodeDeleted` | Device removed | ✅ Enable |
| `nodeApproved` | Device approved | ✅ Enable |
| `nodeKeyExpiring` | Key about to expire | ✅ Enable |
| `userCreated` | New user | ✅ Enable |
| `userDeleted` | User removed | ✅ Enable |

### Webhook payload example

```json
{
  "timestamp": "2026-02-01T10:30:00Z",
  "event": "nodeCreated",
  "tailnet": "your-tailnet.ts.net",
  "node": {
    "name": "new-device",
    "addresses": ["100.x.x.x"]
  }
}
```

---

## MagicDNS Hardening

MagicDNS allows resolving device names within your Tailnet. For enhanced security:

### Verify MagicDNS configuration

1. Go to [login.tailscale.com/admin/dns](https://login.tailscale.com/admin/dns)
2. Configure:
   - **MagicDNS:** Enabled (to resolve internal names)
   - **Override local DNS:** Enabled (to prevent DNS leaks)
   - **Global nameservers:** Configure secure DNS servers (e.g., `1.1.1.1`, `9.9.9.9`)

### Add Split DNS (optional)

If you need to resolve specific internal domains:

```json
{
  "dns": {
    "nameservers": ["1.1.1.1", "9.9.9.9"],
    "magicDNS": true,
    "overrideLocalDNS": true
  }
}
```

!!! tip "Advantage of Override local DNS"
    With `overrideLocalDNS: true`, all VPS DNS traffic goes through the servers configured in Tailscale, preventing potential DNS leaks through the VPS provider.

---

## Node key expiration

By default, Tailscale node keys expire every 180 days. You must renew them or disable expiration for the VPS.

### Option A: Disable expiration (recommended for servers)

1. Go to [login.tailscale.com/admin/machines](https://login.tailscale.com/admin/machines)
2. Find your VPS in the list
3. Click the **...** menu → **Disable key expiry**

!!! warning "Security implication"
    Disabling expiration means the node will remain authorized indefinitely.
    This is acceptable for servers that don't change ownership.
    For personal devices, keep expiration active.

### Option B: Renew manually

If you prefer to keep expiration active, renew before it expires:

```bash
# View when current key expires
tailscale status --json | jq '.Self.KeyExpiry'

# Renew (requires re-authentication)
sudo tailscale up --reset
```

### Configure expiration alert

Add a weekly check to cron:

```bash
crontab -e
```

```cron
# Check Tailscale key expiration every Monday
0 9 * * 1 tailscale status --json | jq -r '.Self.KeyExpiry // "no-expiry"' | logger -t tailscale-expiry
```

---

## Current system state

```
┌─────────────────────────────────────────────┐
│              INTERNET                       │
│                  ❌                         │
│    Port 22 closed / not accessible          │
│    No public ports                          │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│         VPS (Hetzner/other)                  │
│  Public IP: xxx.xxx.xxx.xxx (NOT used)      │
│  Tailscale IP: 100.x.x.x (only path)        │
│  Tag: tag:vps                               │
│  ┌─────────────────────────────────────┐    │
│  │  SSH listening on 100.x.x.x:22      │    │
│  │  Firewall: deny all incoming        │    │
│  │  ACLs: only owner can access        │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
          ▲
          │ Tailscale VPN (WireGuard encryption)
          │ Verified ACLs
          ▼
┌─────────────────────────────────────────────┐
│         YOUR DEVICE (owner)                 │
│  Tailscale IP: 100.y.y.y                    │
│  Can: SSH to VPS, access port 3000          │
└─────────────────────────────────────────────┘
```

---

## Useful Tailscale commands

```bash
# View all devices in your network
tailscale status

# View your Tailscale IP
tailscale ip -4

# Ping another device by name
tailscale ping vps-name

# View Tailscale logs
sudo journalctl -u tailscaled -f

# Disconnect temporarily
tailscale down

# Reconnect
tailscale up

# View current configuration
tailscale debug prefs
```

---

## Upload files to the VPS

Now that you only have access via Tailscale, use these commands to transfer files:

```bash
# Upload a file
scp file.txt openclaw@<YOUR_TAILSCALE_IP>:~/workspace/

# Upload a folder
scp -r my-folder/ openclaw@<YOUR_TAILSCALE_IP>:~/workspace/

# Sync folder (more efficient for updates)
rsync -avz my-folder/ openclaw@<YOUR_TAILSCALE_IP>:~/workspace/my-folder/

# Download file from VPS
scp openclaw@<YOUR_TAILSCALE_IP>:~/workspace/result.txt ./
```

---

## Troubleshooting

### Error: "Tailscale not running"

**Cause**: The tailscaled service is not active.

**Solution**:
```bash
sudo systemctl start tailscaled
sudo systemctl enable tailscaled
tailscale up
```

### Error: "Not authorized" when using tags

**Cause**: ACLs don't allow the tag or you're not the tag owner.

**Solution**:
1. Verify that `tagOwners` includes your user or `autogroup:owner`
2. Verify that you saved the ACLs in the Tailscale panel

### Error: "Connection timed out" via Tailscale

**Cause**: Local or network firewall blocking WireGuard.

**Solution**:
```bash
# Verify tailscaled is listening
sudo ss -ulnp | grep tailscale

# Check connectivity
tailscale netcheck
```

### SSH still accessible on public IP after setting ListenAddress

**Cause**: Ubuntu 24.04 uses `ssh.socket` (systemd socket activation) which listens on `0.0.0.0:22` and ignores `ListenAddress`.

**Solution**:
```bash
# Check if ssh.socket is active
systemctl is-active ssh.socket

# If active, disable it and switch to traditional service
sudo systemctl disable --now ssh.socket
sudo systemctl enable ssh.service
sudo mkdir -p /run/sshd
sudo kill $(cat /run/sshd.pid 2>/dev/null) 2>/dev/null || true
sudo systemctl restart ssh

# Verify it now only listens on Tailscale IP
ss -tln | grep :22
```

### SSH fails after reboot: "Cannot assign requested address"

**Cause**: SSH tried to bind to the Tailscale IP before `tailscaled` had assigned it. This happens when the systemd drop-in (`/etc/systemd/system/ssh.service.d/after-tailscale.conf`) is missing or when Tailscale was slow to start.

**Quick fix** (from VNC console or existing session):
```bash
sudo systemctl daemon-reload
sudo systemctl restart ssh
```

**Permanent fix** — install the drop-in if missing:
```bash
sudo mkdir -p /etc/systemd/system/ssh.service.d
sudo tee /etc/systemd/system/ssh.service.d/after-tailscale.conf > /dev/null << 'EOF'
[Unit]
After=tailscaled.service
Wants=tailscaled.service

[Service]
RestartSec=5
Restart=on-failure
EOF

sudo systemctl daemon-reload
sudo systemctl restart ssh
```

!!! tip "Post-reboot checklist"
    After every VPS reboot, if you can't SSH in, login via the **Hetzner VNC console** and run:
    ```bash
    sudo tailscale status          # Is Tailscale connected?
    sudo systemctl restart ssh     # Restart SSH after Tailscale is up
    ```
    With the drop-in installed, this should be automatic — but if something goes wrong, these two commands fix it.

### Error: "Cannot bind any address" or "Address already in use"

**Cause**: After disabling `ssh.socket`, leftover sshd processes from socket activation are still holding the port.

**Solution**:
```bash
# Kill leftover sshd process
sudo kill $(cat /run/sshd.pid 2>/dev/null) 2>/dev/null || true
sudo systemctl restart ssh
```

### Error: "Missing privilege separation directory: /run/sshd"

**Cause**: The `/run/sshd` directory is normally created by `ssh.socket`. After disabling it, the directory doesn't exist.

**Solution**:
```bash
sudo mkdir -p /run/sshd
sudo systemctl restart ssh
```

### Lost access: public SSH closed and Tailscale is down

**Cause**: You ran `tailscale down`, Tailscale crashed, or `tailscaled` was not enabled and didn't start after a reboot. The VPS console login won't work either if your user has no password.

**Solution — Hetzner Rescue Mode:**

1. In Hetzner Cloud panel → your server → **Rescue** tab → **Enable Rescue & Power Cycle**
2. Copy the **root password** shown in the panel
3. Go to the **Power** tab → **Power cycle** the server (it will boot into rescue)
4. Access the rescue system via **one** of these methods:
    - **VNC Console** (recommended): Click the Console icon (`>_`) in the Hetzner panel. Login with `root` and the rescue password. No network or firewall needed.
    - **SSH** (if your Cloud Firewall allows port 22):
        ```bash
        ssh-keygen -R <YOUR_PUBLIC_IP>
        ssh root@<YOUR_PUBLIC_IP>
        ```
        Use the rescue root password from step 2.
5. Mount your disk and enter chroot:
    ```bash
    mount /dev/sda1 /mnt
    mount --bind /dev /mnt/dev
    mount --bind /proc /mnt/proc
    mount --bind /sys /mnt/sys
    chroot /mnt
    ```
6. Fix the issue — set passwords and ensure Tailscale starts on boot:
    ```bash
    # Set local passwords (recovery access via VNC console)
    passwd root
    passwd openclaw

    # Ensure Tailscale starts on boot
    systemctl enable tailscaled

    # Check what went wrong (optional)
    journalctl -u tailscaled --no-pager -n 50
    ```
7. Exit chroot and reboot into normal mode:
    ```bash
    exit
    umount -R /mnt
    reboot
    ```
8. In Hetzner panel → **Rescue** tab → **Disable Rescue** so the next reboot is normal.
9. Login via **VNC console** with the password you just set and verify:
    ```bash
    sudo tailscale status
    ```

!!! tip "Non-US keyboard in VNC console"
    The rescue system defaults to US keyboard layout. If you have a Spanish keyboard, run `loadkeys es` first. Alternatively, use the **paste button** in the VNC console toolbar to avoid keyboard mapping issues.

!!! tip "Hetzner Cloud Firewall"
    Rescue mode boots a different OS that ignores UFW, but it still respects the **Hetzner Cloud Firewall**. If SSH to rescue is refused, use the **VNC console** instead, or go to the **Firewalls** tab and temporarily add an inbound rule allowing TCP port 22.

---

## Summary

| Configuration | Status |
|---------------|--------|
| Tailscale installed | ✅ |
| Verified from official repo | ✅ |
| ACLs configured (not permit-all) | ✅ |
| Tag `vps` assigned | ✅ |
| SSH only on Tailscale interface | ✅ |
| Public port 22 closed | ✅ |
| Tailnet Lock (optional) | ⬜ |
| Webhooks configured (optional) | ⬜ |

---

**Next:** [5. Install OpenClaw](05-openclaw.md)
