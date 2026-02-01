# 1. Preparation

> **TL;DR**: Create necessary accounts, generate a secure SSH key with passphrase, verify local tools, and configure API spending limits.

> **Estimated time**: 15-20 minutes

> **Required level**: Beginner

## Prerequisites

- Access to terminal (macOS/Linux) or PowerShell (Windows)
- Web browser
- Credit card for VPS (~$5-12/month)

## Objectives

By the end of this section you will have:

- Account with a VPS provider
- Tailscale account (with MFA enabled)
- Ed25519 SSH key with secure passphrase
- Spending limits configured for LLM APIs

---

## Verify local tools

Before starting, verify that you have the necessary tools on your local machine.

### macOS / Linux

```bash
# Verify SSH (must be OpenSSH 8.0+)
ssh -V
```

**Expected output:**
```
OpenSSH_9.x, ...
```

```bash
# Verify curl
curl --version
```

```bash
# Verify GPG (optional, for signature verification)
gpg --version
```

### Windows

Open PowerShell and run:

```powershell
# Verify SSH
ssh -V

# If not installed, use:
# Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
```

---

## Required accounts

| Service | Link | Notes |
|---------|------|-------|
| VPS (Hetzner/DigitalOcean) | [hetzner.com](https://www.hetzner.com) / [digitalocean.com](https://www.digitalocean.com) | ~$5-12/month |
| Tailscale | [tailscale.com](https://tailscale.com) | Free (login with Google/GitHub/Microsoft) |
| LLM API | See [section 6](06-llm-apis.md) | Kimi K2.5 free on NVIDIA NIM |

### Create Tailscale account

1. Go to [login.tailscale.com](https://login.tailscale.com)
2. Sign in with Google, GitHub, Microsoft, or another provider
3. Follow the initial wizard (you can skip it, we'll configure it later)

!!! danger "Enable MFA on your identity provider"
    Tailscale inherits security from your identity provider. If someone compromises your Google/GitHub account, they compromise your Tailnet (and your VPS).

    **Enable 2FA/MFA on your Google/GitHub/Microsoft account NOW:**

    - **Google:** [myaccount.google.com/security](https://myaccount.google.com/security)
    - **GitHub:** Settings → Password and authentication → Two-factor authentication
    - **Microsoft:** [account.microsoft.com/security](https://account.microsoft.com/security)

---

## Generate SSH key

SSH keys are more secure than passwords and are **required** for this guide.

### Create secure passphrase

First, generate a secure passphrase to protect your SSH key:

```bash
# Generate random 24-character passphrase
openssl rand -base64 24
```

**Expected output:**
```
K7mP2xQ9vR4tY8wE3nL6jH1fG5bA0cD=
```

!!! tip "Save the passphrase"
    Save this passphrase in a password manager (1Password, Bitwarden, etc.).
    You'll need it every time you use the SSH key.

### Generate Ed25519 key

```bash
# Generate Ed25519 key (more secure than RSA)
ssh-keygen -t ed25519 -C "openclaw-vps-$(date +%Y)"
```

It will ask for:

1. **Location:** Accept the default (`~/.ssh/id_ed25519`) or specify a path
2. **Passphrase:** Use the passphrase you generated above

**Expected output:**
```
Generating public/private ed25519 key pair.
Enter file in which to save the key (/home/user/.ssh/id_ed25519):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /home/user/.ssh/id_ed25519
Your public key has been saved in /home/user/.ssh/id_ed25519.pub
The key fingerprint is:
SHA256:XXXXX openclaw-vps-2026
```

### Verify the key was generated correctly

```bash
# View the public key (this is what you'll upload to Hetzner/DigitalOcean)
cat ~/.ssh/id_ed25519.pub
```

**Expected output:**
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... openclaw-vps-2026
```

```bash
# Verify permissions (must be restrictive)
ls -la ~/.ssh/id_ed25519*
```

**Expected output:**
```
-rw------- 1 user user  464 Feb  1 10:00 /home/user/.ssh/id_ed25519
-rw-r--r-- 1 user user  105 Feb  1 10:00 /home/user/.ssh/id_ed25519.pub
```

!!! warning "The private key (without .pub) is never shared"
    - `id_ed25519` = PRIVATE key (never share, never upload)
    - `id_ed25519.pub` = PUBLIC key (this one gets uploaded to the VPS)

### Configure SSH agent (optional but recommended)

To avoid typing the passphrase every time:

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add key (will ask for passphrase once)
ssh-add ~/.ssh/id_ed25519
```

On macOS, you can save the passphrase in Keychain:

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519
```

---

## Configure LLM spending limit

!!! danger "Do this BEFORE using any paid API"
    Without limits configured, a bug or excessive usage can generate unexpected bills of hundreds or thousands of dollars.

### OpenAI

1. Go to [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits)
2. Under **Usage limits**:
   - **Hard limit:** $50 (stops when reached)
   - **Soft limit:** $30 (notifies you)

### Anthropic

1. Go to [console.anthropic.com/settings/limits](https://console.anthropic.com/settings/limits)
2. Set a **Monthly spending limit**: $50

### NVIDIA NIM (Kimi K2.5 free)

- No need to configure limits
- The free tier has built-in rate limits

### Recommended initial limits

| Usage profile | Recommended monthly limit |
|---------------|---------------------------|
| Testing/Learning | $20 |
| Personal development | $50 |
| Small production | $100 |

---

## SSH key backup

!!! tip "Back up your SSH key"
    If you lose the private key, you'll lose access to the VPS.

### Option 1: Password manager

Save the contents of `~/.ssh/id_ed25519` (private key) in your password manager as a secure note.

### Option 2: Encrypted backup

```bash
# Create encrypted backup with GPG
gpg --symmetric --cipher-algo AES256 -o ~/id_ed25519.backup.gpg ~/.ssh/id_ed25519

# Store ~/id_ed25519.backup.gpg in a safe place (USB, encrypted cloud, etc.)
```

To restore:

```bash
gpg -d ~/id_ed25519.backup.gpg > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
```

---

## Troubleshooting

### Error: "Permissions are too open" when using SSH

**Cause:** Private key permissions are too permissive.

**Solution:**
```bash
chmod 600 ~/.ssh/id_ed25519
chmod 700 ~/.ssh
```

### Error: "Could not open a connection to your authentication agent"

**Cause:** SSH agent is not running.

**Solution:**
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### Error: "No such file or directory" when viewing the key

**Cause:** The key was not generated or is in another location.

**Solution:**
```bash
# View all available keys
ls -la ~/.ssh/

# If there are none, generate a new one
ssh-keygen -t ed25519 -C "openclaw-vps"
```

---

## Preparation checklist

- [ ] Account with VPS provider (Hetzner/DigitalOcean) with payment method
- [ ] Tailscale account created
- [ ] MFA/2FA enabled on your identity provider (Google/GitHub/Microsoft)
- [ ] Ed25519 SSH key generated (`~/.ssh/id_ed25519.pub`)
- [ ] Passphrase saved in password manager
- [ ] Private key backup completed
- [ ] (If using paid API) Spending limit configured

---

**Next:** [2. Provision VPS](02-vps.md) — Create the virtual server.
