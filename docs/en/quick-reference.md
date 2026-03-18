# Quick Reference

> Day-to-day commands for managing your OpenClaw VPS. Keep this page bookmarked.

---

## Service management

```bash
# Check service status
sudo systemctl status openclaw --no-pager

# Restart OpenClaw
sudo systemctl restart openclaw

# Stop / Start
sudo systemctl stop openclaw
sudo systemctl start openclaw

# View recent logs (last 50 lines, clean output)
sudo journalctl -u openclaw -n 50 --no-pager -o cat

# Follow logs in real time (Ctrl+C to stop)
sudo journalctl -u openclaw -f --no-pager -o cat

# Logs since last boot only
sudo journalctl -u openclaw -b --no-pager -o cat

# Filter errors only
sudo journalctl -u openclaw -p err --no-pager -o cat
```

---

## OpenClaw CLI

```bash
# Check installed version
openclaw --version

# Full status (service + config + connectivity)
openclaw status --all

# Update OpenClaw
openclaw update

# Check update channel
openclaw update --channel

# Switch to stable channel
openclaw update --channel stable

# Interactive setup wizard (first-time only)
openclaw onboard

# Diagnose configuration issues
openclaw doctor

# Validate sandbox configuration
openclaw sandbox explain

# Validate that configured LLM providers respond correctly
openclaw models status --probe
```

!!! danger "Never run `openclaw doctor --fix` after manual configuration"
    `--fix` overwrites your manual provider settings (especially Kimi Coding) with broken built-in templates. Use `openclaw doctor` without `--fix` to diagnose, then fix manually.

---

## Secrets management

```bash
# Configure a secret interactively (value not shown on screen)
openclaw secrets configure ANTHROPIC_API_KEY

# List configured secrets
openclaw secrets list

# Audit secrets configuration
openclaw secrets audit

# Reload secrets after changes
openclaw secrets reload

# Delete a secret
openclaw secrets delete ANTHROPIC_API_KEY
```

!!! tip "After changing secrets in `/etc/openclaw/env`, always restart"
    ```bash
    sudo systemctl daemon-reload
    sudo systemctl restart openclaw
    ```
    The `daemon-reload` is mandatory — without it, systemd keeps using the old environment.

---

## Provider configuration

### Switch LLM provider

Edit the environment file and restart:

```bash
# Edit secrets/env vars
sudo nano /etc/openclaw/env

# Apply changes (BOTH commands required)
sudo systemctl daemon-reload
sudo systemctl restart openclaw

# Verify the new provider responds
sudo journalctl -u openclaw -n 10 --no-pager -o cat
```

### Provider env vars reference

| Provider | Variables | Model ID | Notes |
|----------|-----------|----------|-------|
| **Kimi Coding** | `KIMI_API_KEY` | `kimi-for-coding` | Free with subscription, recommended primary |
| **xAI** | `XAI_API_KEY` | `grok-4-1-fast-reasoning` | $0.20/$0.50 per MTok, recommended fallback |
| **Google** | `GOOGLE_API_KEY` | `gemini-2.5-flash` | $0.30/$2.50 per MTok, optional LLM fallback |
| **Brave** | `BRAVE_SEARCH_API_KEY` | — | Free ~1,000 queries/month, recommended web search |
| **Anthropic** | `ANTHROPIC_API_KEY` | `claude-sonnet-4-6`, `claude-opus-4-6` | Premium quality |
| **OpenAI** | `OPENAI_API_KEY` | `gpt-5-mini`, `gpt-5` | General use |
| **DeepSeek** | `DEEPSEEK_API_KEY` | `deepseek-chat` | Budget option |

### Add OpenAI (ChatGPT) as provider

1. Get your API key from [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Set spending limits at [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits)
3. Configure on the VPS:

```bash
sudo nano /etc/openclaw/env
```

Add:
```bash
OPENAI_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

4. Edit the OpenClaw config to use OpenAI:

```bash
nano ~/.openclaw/openclaw.json
```

Add OpenAI as a provider in the `providers` section:
```json
{
  "providers": {
    "openai": {
      "model": "gpt-5-mini"
    }
  }
}
```

5. Apply:
```bash
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

### Multi-provider setup (primary + fallback)

A common pattern is using Kimi Coding as primary with Grok 4.1 Fast Reasoning as fallback and Brave for web search.
See [section 6](06-llm-apis.md#multi-model-configuration-with-fallbacks) for the full `openclaw.json` configuration
```

---

## Telegram bot

```bash
# Check pairing requests
openclaw pairing list

# Approve a Telegram pairing
openclaw pairing approve telegram <CODE>

# Restart bot after config changes
sudo systemctl restart openclaw

# Check bot is connected
sudo journalctl -u openclaw -n 20 --no-pager -o cat | grep -i telegram
```

---

## Skills & agents

```bash
# List installed skills
openclaw skills list

# Install a skill
openclaw skills install <skill-name>

# Test a skill in sandbox first
openclaw skills install <skill-name> --sandbox

# Send a direct message to the agent
openclaw agent --message "summarize today's logs"
```

!!! info "Skills install to `~/.agents/skills/`"
    Skills are global, NOT inside `~/.openclaw/skills/`.

---

## Tailscale & SSH

```bash
# Check Tailscale status
sudo tailscale status

# Restart Tailscale
sudo systemctl restart tailscaled

# Restart SSH (if it failed to bind after reboot)
sudo systemctl daemon-reload
sudo systemctl restart ssh

# Verify SSH is listening on Tailscale IP only
sudo ss -tlnp | grep sshd
```

---

## System health

```bash
# Disk usage
df -h /

# Memory usage
free -h

# CPU and process overview
htop    # or: top -bn1 | head -20

# OpenClaw process resources
ps aux | grep openclaw

# Active network connections (OpenClaw)
sudo ss -tp | grep node

# Check all hardened services are running
sudo systemctl is-active tailscaled ssh openclaw

# Firewall status
sudo ufw status
```

---

## After a VPS reboot

If you can't SSH in after a reboot, connect via the **Hetzner VNC console** and run:

```bash
# 1. Check Tailscale is running
sudo tailscale status

# 2. If Tailscale is down, start it
sudo systemctl start tailscaled
sudo tailscale up

# 3. Restart SSH (it may have failed to bind before Tailscale was ready)
sudo systemctl daemon-reload
sudo systemctl restart ssh

# 4. Verify SSH is listening
sudo ss -tlnp | grep sshd

# 5. Verify OpenClaw is running
sudo systemctl status openclaw --no-pager
```

!!! tip "With the systemd drop-in installed, this should be automatic"
    If you followed [section 4](04-private-access.md#step-3-ensure-ssh-starts-after-tailscale-on-boot), SSH waits for Tailscale and auto-restarts on failure. These manual steps are only needed if something unexpected happens.

---

## Configuration files

| File | Purpose | Edit with |
|------|---------|-----------|
| `/etc/openclaw/env` | API keys and secrets (mode 600) | `sudo nano /etc/openclaw/env` |
| `~/.openclaw/openclaw.json` | Main config (providers, tools, profiles) | `nano ~/.openclaw/openclaw.json` |
| `~/openclaw/workspace/SOUL.md` | Agent personality and behavior rules | `nano ~/openclaw/workspace/SOUL.md` |
| `~/.openclaw/exec-approvals.json` | Auto-approve rules for commands | `nano ~/.openclaw/exec-approvals.json` |
| `~/.openclaw/agents/main/agent/auth-profiles.json` | Provider auth overrides (can cause 401s) | `nano ~/.openclaw/agents/main/agent/auth-profiles.json` |
| `/etc/ssh/sshd_config.d/99-openclaw-hardening.conf` | SSH hardening config | `sudo nano /etc/ssh/sshd_config.d/99-openclaw-hardening.conf` |
| `/etc/systemd/system/ssh.service.d/after-tailscale.conf` | SSH boot order drop-in | `sudo nano /etc/systemd/system/ssh.service.d/after-tailscale.conf` |

---

## Common fixes

| Problem | Quick fix |
|---------|----------|
| Can't SSH after reboot | VNC console → `sudo systemctl restart ssh` |
| OpenClaw not responding | `sudo systemctl restart openclaw` |
| 401 errors after key change | `echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json` then restart |
| Config changes not applied | `sudo systemctl daemon-reload && sudo systemctl restart openclaw` |
| Port 18789 in use | `sudo kill $(sudo lsof -t -i:18789) && sudo systemctl restart openclaw` |
| Disk full | `sudo journalctl --vacuum-size=500M && sudo apt autoremove -y` |
| Tailscale down | `sudo systemctl restart tailscaled && sudo tailscale up` |
| `openclaw doctor --fix` broke config | Restore from backup: `cp ~/.openclaw/openclaw.json.bak ~/.openclaw/openclaw.json` |
