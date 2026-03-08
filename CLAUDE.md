# CLAUDE.md — Project Context for AI Assistants

## What is this project?

OpenClaw VPS Hardening Guide — a bilingual (EN/ES) documentation site that guides users through deploying OpenClaw on a hardened VPS. Built with MkDocs Material and hosted on GitHub Pages.

## Repository structure

```
docs/
  en/          # English documentation (01-preparation through 10-final-checklist)
  es/          # Spanish documentation (mirrors EN exactly)
scripts/
  harden.sh          # VPS hardening automation (sections 3-4)
  install-openclaw.sh # OpenClaw installation automation (section 5)
mkdocs.yml           # MkDocs configuration with i18n
AGENTS.md            # Agentic self-configuration guide for OpenClaw agents
```

## Key rules

### EN/ES parity
- Every change to `docs/en/` MUST have an equivalent change in `docs/es/`
- Same structure, same sections, same code blocks — only prose is translated
- Code blocks, commands, and JSON configs are identical in both languages

### Documentation accuracy
- Never guess OpenClaw configuration — verify against official docs (docs.openclaw.ai)
- When discovering issues during real deployment, update docs AND scripts
- Mark field-tested configurations clearly vs theoretical recommendations

### OpenClaw configuration facts (verified v2026.3.x)
- **Sandbox**: Use `"off"` for dedicated single-user VPS with systemd hardening. Use `"all"` only for shared/multi-user servers (requires Docker, env vars don't pass through)
- **Skills install path**: `npx playbooks add skill` installs to `~/.agents/skills/<skill-name>/` (global scope), NOT `~/.openclaw/skills/`
- **Skills auto-discover** from `~/.agents/skills/`, `~/.openclaw/skills/`, and `<workspace>/skills/` — no `skills` section needed in `openclaw.json`
- **Verify skill paths**: Always run `find /home/openclaw -name "SKILL.md" -path "*<skill-name>*"` to confirm
- **Secrets CLI**: `openclaw secrets configure` (interactive wizard), `openclaw secrets audit`, `openclaw secrets reload` — there is NO `openclaw secrets set` command
- **Secrets storage**: Store API keys in systemd overrides (`sudo systemctl edit openclaw`), NOT in `.bashrc` or plaintext in `openclaw.json`. Reference with `${VAR_NAME}`
- **Google Gemini requires two env vars**: Both `GOOGLE_API_KEY` and `GEMINI_API_KEY` must be set (same value). `GOOGLE_API_KEY` for LLM completions, `GEMINI_API_KEY` for web search/grounding
- **dmPolicy**: Use `"allowlist"` with `allowFrom` to restrict access. `"pairing"` ignores `allowFrom`
- **SOUL.md path**: Must be in the workspace dir from `agents.defaults.workspace` (e.g., `~/openclaw/workspace/SOUL.md`), NOT in `~/.openclaw/workspace/`
- **SystemCallFilter**: Do NOT deny `@debug` — it causes core dumps with Telegram channel. Do NOT add `SystemCallFilter` in override.conf — causes NAMESPACE errors
- **Tools config**: Use `profile: "full"` with `deny: ["gateway"]`. The `coding` profile has a bug where `web_search` doesn't enable correctly. Do NOT deny `process` — skills need it. The correct Telegram streaming field is `streaming` (NOT `streamMode`)
- **Execution approvals**: `~/.openclaw/exec-approvals.json` with `security: "allowlist"`, `ask: "on-miss"`, `askFallback: "deny"`, `autoAllowSkills: true`. 48 auto-approved commands (read, edit, system, dev, network). Destructive commands (`rm`, `kill`, `systemctl`, `chmod`, `ssh`) require Telegram approval. `sudo`, `su`, `dd`, `reboot` never allowed. Approval requests forwarded via `approvals.exec` in `openclaw.json`
- **Skills require `npm install`**: OpenClaw marks skills "ready" based on SKILL.md presence, but does NOT auto-install npm dependencies
- **Root-level keys**: `sandbox`, `dmPolicy`, `security`, `tools.blocked` at root level are NOT recognized — they go inside `agents.defaults` or per-channel config
- **Model compatibility**: `kimi-coding/kimi-for-coding` (primary) requires `User-Agent: claude-code/0.1.0` header, `reasoning: false`, and baseUrl without trailing slash (`https://api.kimi.com/coding`). `google/gemini-2.5-flash` (fallback) requires `compat.supportsStore: false`
- **`auth-profiles.json`**: `~/.openclaw/agents/main/agent/auth-profiles.json` overrides env vars — if it has a stale key, it blocks auth even with correct systemd env vars. Fix: `echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json`
- **`openclaw doctor --fix`**: Do NOT run after manual config — it overwrites provider settings (especially Kimi) with broken defaults
- **web_search**: Requires `GEMINI_API_KEY` env var (auto-detect) or explicit `tools.web.search.provider` config. Detection order: Brave → Gemini → Kimi → Perplexity → Grok
- **Moonshot ≠ Kimi Coding**: Separate providers with different API keys (`MOONSHOT_API_KEY` vs `KIMI_API_KEY`) and endpoints
- **Hetzner Cloud Firewall**: Must include outbound TCP 587 (SMTP), TCP 993 (IMAP), UDP 3478 (STUN), TCP 53 (DNS fallback) in addition to 443, 80, 41641, UDP 53
- **Service name**: The systemd service is `openclaw.service`, NOT `openclaw-gateway.service`

### Script conventions
- Scripts use `set -euo pipefail` and colored output (info/warn/error/ask functions)
- Scripts are interactive with user prompts for optional features
- Scripts generate configs via heredocs, not via `openclaw` CLI commands (more reliable)

### Commit conventions
- Prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Keep messages concise, focused on the "why"

## Reference deployment
- Provider: Hetzner (any VPS provider works)
- OS: Ubuntu 24.04
- User: `openclaw` (dedicated non-root user)
- Access: Tailscale only (no public SSH)
- OpenClaw version: 2026.3.x
- Recommended models: kimi-coding/kimi-for-coding (subscription, primary), google/gemini-2.5-flash (free tier, fallback + web_search)
- Google Gemini API: use `openai-completions` api with baseUrl `https://generativelanguage.googleapis.com/v1beta/openai` and `compat.supportsStore: false`
- Channels: Telegram with allowlist
- Email: Gmail with app password via himalaya skill

## Agent Deployment Guide

Step-by-step reference for an AI agent assisting a user with OpenClaw deployment on a fresh VPS.

### Deployment flow (step by step)

1. **Provision VPS** — User creates Hetzner CPX22 (or equivalent), Ubuntu 24.04, pasting cloud-init from section 02 during creation.
2. **First SSH** — User connects as `root` via public IP, downloads `harden.sh` and `install-openclaw.sh` from this repo.
3. **Run harden.sh** — Executes sections 3-4: creates `openclaw` user, hardens SSH, configures UFW, installs Tailscale.
4. **Approve Tailscale** — User opens the auth URL printed by the script and approves the node in the Tailscale admin console.
5. **Reconnect via Tailscale** — User disconnects public SSH, reconnects as `openclaw@<tailscale-ip>`. Disable public SSH in Hetzner firewall.
6. **Run install-openclaw.sh** — Executes section 5: installs OpenClaw, generates `openclaw.json`, creates systemd unit.
7. **Configure API keys** — Run `sudo systemctl edit openclaw` and add env vars in the `[Service]` section (see Required env vars below).
8. **Start service** — `sudo systemctl start openclaw && sudo journalctl -u openclaw -f` — verify clean startup, no auth errors.
9. **Test Telegram** — If Telegram channel configured, send a test message to the bot and confirm response.
10. **Run verification** — Execute the final checklist script or manually walk through section 10.

### Config precedence (important for debugging)

```
auth-profiles.json > process.env (systemd) > ~/.openclaw/.env > openclaw.json env.vars
```

If auth fails despite correct systemd env vars, check `~/.openclaw/agents/main/agent/auth-profiles.json` for stale keys.

### Required env vars

| Variable | Where | Purpose |
|---|---|---|
| `KIMI_API_KEY` | systemd override | Kimi Coding LLM (primary model) |
| `GOOGLE_API_KEY` | systemd override | Google Gemini LLM completions |
| `GEMINI_API_KEY` | systemd override | Gemini web search/grounding (same value as GOOGLE_API_KEY) |
| `GATEWAY_TOKEN` | systemd override | OpenClaw gateway authentication |
| `TELEGRAM_BOT_TOKEN` | `~/.openclaw/.env` | Telegram channel (if configured) |

### Quick diagnostic commands

```bash
# Service status and recent logs
sudo systemctl status openclaw
sudo journalctl -u openclaw -n 50 --no-pager

# Live log stream (use during startup/testing)
sudo journalctl -u openclaw -f

# Check effective env vars reaching the process
sudo cat /proc/$(pidof openclaw)/environ | tr '\0' '\n' | sort

# Verify config files
cat ~/.openclaw/openclaw.json | jq .
cat ~/.openclaw/agents/main/agent/auth-profiles.json

# Reset stale auth profiles
echo '{}' > ~/.openclaw/agents/main/agent/auth-profiles.json

# Restart after config changes
sudo systemctl daemon-reload && sudo systemctl restart openclaw

# Tailscale connectivity
tailscale status
tailscale ping <peer>
```
