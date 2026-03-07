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

On the VPS, run:

```bash
sudo tailscale up --advertise-tags=tag:vps --reset
```

!!! warning "The --reset flag resets state"
    This applies the new tag configuration. You'll need to re-authenticate if already connected.

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
echo "# === Listen ONLY on Tailscale ===" | sudo tee -a /etc/ssh/sshd_config.d/99-hardening.conf
echo "ListenAddress $(tailscale ip -4)" | sudo tee -a /etc/ssh/sshd_config.d/99-hardening.conf

# Verify it was added correctly
tail -2 /etc/ssh/sshd_config.d/99-hardening.conf
```

**Expected output:**
```
# === Listen ONLY on Tailscale ===
ListenAddress 100.64.0.1
```

!!! warning "Example IP"
    Your IP will be different (something like `100.x.x.x`). The command automatically uses your actual IP.

### Step 2: Verify syntax

```bash
sudo sshd -t
```

**If there are errors, do NOT restart SSH.** Fix them first.

### Step 3: Restart SSH

```bash
sudo systemctl restart sshd
```

### Step 4: Remove firewall rule

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

### Lost public SSH access and Tailscale isn't working

**Solution**:
1. Access via the VPS provider's web console (Hetzner/DigitalOcean have VNC)
2. Revert ListenAddress changes in `/etc/ssh/sshd_config.d/99-hardening.conf`
3. `sudo systemctl restart sshd`

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
