# CLAUDE.md — Project Rules

> All OpenClaw deployment knowledge, configuration facts, and troubleshooting is in **[AGENTS.md](AGENTS.md)**. Read it first.

## Repository rules (for contributors and AI agents editing this repo)

### EN/ES parity
- Every change to `docs/en/` MUST have an equivalent change in `docs/es/`
- Same structure, same sections, same code blocks — only prose is translated
- Code blocks, commands, and JSON configs are identical in both languages

### Documentation accuracy
- Never guess OpenClaw configuration — verify against official docs (docs.openclaw.ai)
- When discovering issues during real deployment, update docs AND scripts
- Mark field-tested configurations clearly vs theoretical recommendations

### Script conventions
- Scripts use `set -euo pipefail` and colored output (info/warn/error/ask functions)
- Scripts are interactive with user prompts for optional features
- Scripts generate configs via heredocs, not via `openclaw` CLI commands (more reliable)

### Commit conventions
- Prefixes: `feat:`, `fix:`, `docs:`, `refactor:`, `chore:`
- Keep messages concise, focused on the "why"
