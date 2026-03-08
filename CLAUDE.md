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
- **dmPolicy**: Use `"allowlist"` with `allowFrom` to restrict access. `"pairing"` ignores `allowFrom`
- **SOUL.md path**: Must be in the workspace dir from `agents.defaults.workspace` (e.g., `~/openclaw/workspace/SOUL.md`), NOT in `~/.openclaw/workspace/`
- **SystemCallFilter**: Do NOT deny `@debug` — it causes core dumps with Telegram channel. Do NOT add `SystemCallFilter` in override.conf — causes NAMESPACE errors
- **Tools deny list**: Only deny `["group:automation"]` (cron + gateway). Do NOT deny `process` — skills need it to execute scripts
- **Skills require `npm install`**: OpenClaw marks skills "ready" based on SKILL.md presence, but does NOT auto-install npm dependencies
- **Root-level keys**: `sandbox`, `dmPolicy`, `security`, `tools.blocked` at root level are NOT recognized — they go inside `agents.defaults` or per-channel config
- **Model compatibility**: `kimi-coding/k2p5` does NOT execute tool calls (known bug). `moonshot/kimi-k2.5` works correctly with tools (exec, browser, etc.). `google/gemini-2.5-flash` also works
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
- Recommended models: moonshot/kimi-k2.5 (free), google/gemini-2.5-flash (free tier)
- Channels: Telegram with allowlist
- Email: Gmail with app password via himalaya skill
