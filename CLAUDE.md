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
- **Skills auto-discover** from `~/.openclaw/skills/` and `<workspace>/skills/` — no `skills` section needed in `openclaw.json` unless configuring env vars
- **Secrets CLI**: `openclaw secrets configure` (interactive wizard), `openclaw secrets audit`, `openclaw secrets reload` — there is NO `openclaw secrets set` command
- **dmPolicy**: Use `"allowlist"` with `allowFrom` to restrict access. `"pairing"` ignores `allowFrom`
- **SOUL.md path**: Must be in the workspace dir from `agents.defaults.workspace` (e.g., `~/openclaw/workspace/SOUL.md`), NOT in `~/.openclaw/workspace/`
- **SystemCallFilter**: Do NOT deny `@debug` — it causes core dumps with Telegram channel
- **Sandbox caching**: Clear `~/.openclaw/sandboxes/agent-main-*` when SOUL.md changes aren't picked up, then send `/new` in Telegram
- **tools.exec.security**: Does NOT exist as a config key
- **Root-level keys**: `sandbox`, `dmPolicy`, `security`, `tools.blocked` at root level are NOT recognized — they go inside `agents.defaults` or per-channel config

### Script conventions
- Scripts use `set -euo pipefail` and colored output (info/warn/error/ask functions)
- Scripts are interactive with user prompts for optional features
- Scripts generate configs via heredocs, not via `openclaw` CLI commands (more reliable)

### Commit conventions
- Prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Keep messages concise, focused on the "why"

## Server details (live deployment)
- Provider: Hetzner
- OS: Ubuntu 24.04
- User: `openclaw`
- Access: Tailscale only (no public SSH)
- OpenClaw version: 2026.3.2
- Model: Kimi for Coding (k2p5)
- Telegram bot: configured with allowlist
- Email: IONOS (info@corbat.tech) via imap-smtp-email skill
