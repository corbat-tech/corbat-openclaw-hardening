# 7. Use cases

> **TL;DR**: Practical examples of skill configuration for different user profiles, including output filtering to prevent data leakage (OWASP AA2).

> **Estimated time**: 15-20 minutes (depending on chosen configuration)

> **Required level**: Intermediate

## Prerequisites

- [ ] Section 6 (LLM APIs) completed
- [ ] OpenClaw running

## Objectives

By the end of this section you will have:

- Skill configuration adapted to your use case
- Output filtering to prevent data leakage
- Knowledge of prohibited configurations

---

## Configuration profiles

### Developers

| Use case | Required skills | HTTP allowlist |
|----------|-----------------|----------------|
| Code review | `filesystem`, `git` | `api.github.com` |
| Generate documentation | `filesystem` | — |
| Run tests | `shell` (VERY limited) | — |
| Repo analysis | `filesystem`, `git`, `http_client` | `api.github.com`, `api.gitlab.com` |

### Freelancers / SMBs

| Use case | Required skills | Notes |
|----------|-----------------|-------|
| Summarize PDFs/documents | `filesystem` | Documents folder only |
| Organize files | `filesystem` | With `move`, `copy` |
| Email drafts | `filesystem` | No direct sending |
| Data analysis | `filesystem` | Read-only |

### Researchers

| Use case | Required skills | HTTP allowlist |
|----------|-----------------|----------------|
| Search papers | `http_client` | `api.semanticscholar.org`, `arxiv.org` |
| Summarize literature | `filesystem` | — |
| Organize bibliography | `filesystem` | — |

---

## Example: Code reviewer (Developer)

### skills.json

```json
{
  "_comment": "Configuration for code reviewer",

  "filesystem": {
    "enabled": true,
    "allowed_paths": [
      "/home/openclaw/openclaw/workspace"
    ],
    "denied_paths": [
      "/home/openclaw/.ssh",
      "/home/openclaw/.env",
      "/etc",
      "/var"
    ],
    "allowed_operations": [
      "read",
      "list"
    ],
    "denied_operations": [
      "write",
      "delete",
      "delete_recursive",
      "change_permissions"
    ]
  },

  "git": {
    "enabled": true,
    "allowed_operations": [
      "clone",
      "status",
      "diff",
      "log",
      "branch",
      "show"
    ],
    "denied_operations": [
      "push",
      "force-push",
      "commit",
      "reset",
      "clean"
    ]
  },

  "http_client": {
    "enabled": true,
    "allowlist": [
      "api.github.com"
    ],
    "timeout_seconds": 30
  },

  "shell": {
    "enabled": false
  }
}
```

### soul.yaml

```yaml
name: "CodeReviewer"
role: "Code reviewer"
version: "1.0"

limits:
  - "Only read code, never modify"
  - "Do not make commits or push"
  - "Do not access files outside workspace"
  - "Report security vulnerabilities found"

tone: "technical, constructive"
```

---

## Example: Document assistant (Freelancer)

### skills.json

```json
{
  "_comment": "Configuration for document management",

  "filesystem": {
    "enabled": true,
    "allowed_paths": [
      "/home/openclaw/openclaw/workspace/documents",
      "/home/openclaw/openclaw/workspace/output"
    ],
    "allowed_operations": [
      "read",
      "write",
      "list",
      "create_directory",
      "move",
      "copy"
    ],
    "denied_operations": [
      "delete_recursive",
      "change_permissions"
    ],
    "max_file_size_mb": 50
  },

  "git": {
    "enabled": false
  },

  "http_client": {
    "enabled": false
  },

  "shell": {
    "enabled": false
  }
}
```

---

## Example: Dev with Telegram notifications

### .env

```bash
# LLM API
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-...

# Telegram
TELEGRAM_BOT_TOKEN=123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11
TELEGRAM_CHAT_ID=987654321

# Network
HOST=127.0.0.1
PORT=3000
```

### Get Telegram token

1. Talk to [@BotFather](https://t.me/BotFather) on Telegram
2. Send `/newbot`
3. Follow the instructions to create the bot
4. Copy the token it gives you

### Get your chat_id

1. Send any message to your new bot
2. Visit in your browser:
   ```
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```
3. Look for `"chat":{"id":123456789}` - that number is your `chat_id`

### skills.json

```json
{
  "filesystem": {
    "enabled": true,
    "allowed_paths": ["/home/openclaw/openclaw/workspace"],
    "denied_operations": ["delete_recursive"]
  },

  "git": {
    "enabled": true,
    "allowed_operations": ["clone", "status", "diff", "log"]
  },

  "http_client": {
    "enabled": true,
    "allowlist": [
      "api.anthropic.com",
      "api.github.com",
      "api.telegram.org"
    ]
  },

  "telegram": {
    "enabled": true,
    "allowed_operations": ["send_message"],
    "denied_operations": ["send_photo", "send_file", "forward_message"]
  },

  "shell": {
    "enabled": false
  }
}
```

---

## Prevent data leakage (OWASP AA2)

Output filtering prevents the agent from exposing sensitive data in its responses.

### Configure output filtering

```yaml
# In config/settings.yaml

output_filtering:
  enabled: true
  filters:
    # API Keys
    - name: "openai_key"
      pattern: "sk-[a-zA-Z0-9]{32,}"
      replacement: "[REDACTED_API_KEY]"

    - name: "anthropic_key"
      pattern: "sk-ant-[a-zA-Z0-9-]{32,}"
      replacement: "[REDACTED_API_KEY]"

    - name: "github_token"
      pattern: "ghp_[a-zA-Z0-9]{36}"
      replacement: "[REDACTED_TOKEN]"

    # Personal data
    - name: "email"
      pattern: "[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}"
      replacement: "[REDACTED_EMAIL]"

    - name: "credit_card"
      pattern: "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b"
      replacement: "[REDACTED_CARD]"

    # Sensitive paths
    - name: "env_path"
      pattern: "/home/[^/]+/\\.env"
      replacement: "[REDACTED_PATH]"

    - name: "ssh_path"
      pattern: "/home/[^/]+/\\.ssh/[^\\s]+"
      replacement: "[REDACTED_PATH]"

  # Log when data is redacted
  log_redactions: true

  # Block response completely if it contains secrets (stricter)
  block_if_contains_secrets: false
```

### Implement filter in code

If OpenClaw doesn't have native filtering, add a module:

```python
# ~/openclaw/app/security/output_filter.py

import re
from typing import Tuple, List

class OutputFilter:
    PATTERNS = [
        (r"sk-[a-zA-Z0-9]{32,}", "[REDACTED_API_KEY]"),
        (r"sk-ant-[a-zA-Z0-9-]{32,}", "[REDACTED_API_KEY]"),
        (r"ghp_[a-zA-Z0-9]{36}", "[REDACTED_TOKEN]"),
        (r"nvapi-[a-zA-Z0-9-]{32,}", "[REDACTED_API_KEY]"),
        (r"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}", "[REDACTED_EMAIL]"),
        (r"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b", "[REDACTED_CARD]"),
        (r"-----BEGIN[^-]+PRIVATE KEY-----[\s\S]*?-----END[^-]+PRIVATE KEY-----", "[REDACTED_KEY]"),
    ]

    def __init__(self):
        self.compiled = [(re.compile(p), r) for p, r in self.PATTERNS]

    def filter(self, text: str) -> Tuple[str, List[str]]:
        """Filter sensitive data and return (filtered_text, list_of_redactions)"""
        filtered = text
        redactions = []

        for pattern, replacement in self.compiled:
            if pattern.search(filtered):
                filtered = pattern.sub(replacement, filtered)
                redactions.append(replacement)

        return filtered, redactions

# Usage
filter = OutputFilter()
safe_output, redacted = filter.filter(agent_response)
if redacted:
    log.warning(f"Sensitive data redacted: {redacted}")
```

### Node.js/TypeScript implementation

If your project uses Node.js:

```javascript
// ~/openclaw/app/security/outputFilter.js

const SENSITIVE_PATTERNS = [
  { pattern: /sk-[a-zA-Z0-9]{32,}/g, replacement: '[REDACTED_API_KEY]' },
  { pattern: /sk-ant-[a-zA-Z0-9-]{32,}/g, replacement: '[REDACTED_API_KEY]' },
  { pattern: /ghp_[a-zA-Z0-9]{36}/g, replacement: '[REDACTED_TOKEN]' },
  { pattern: /nvapi-[a-zA-Z0-9-]{32,}/g, replacement: '[REDACTED_API_KEY]' },
  { pattern: /[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/g, replacement: '[REDACTED_EMAIL]' },
  { pattern: /\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b/g, replacement: '[REDACTED_CARD]' },
  { pattern: /-----BEGIN[^-]+PRIVATE KEY-----[\s\S]*?-----END[^-]+PRIVATE KEY-----/g, replacement: '[REDACTED_KEY]' },
];

/**
 * Filter sensitive data from text
 * @param {string} text - Text to filter
 * @returns {{ filtered: string, redactions: string[] }}
 */
function filterOutput(text) {
  let filtered = text;
  const redactions = [];

  for (const { pattern, replacement } of SENSITIVE_PATTERNS) {
    if (pattern.test(filtered)) {
      filtered = filtered.replace(pattern, replacement);
      redactions.push(replacement);
    }
    // Reset regex lastIndex for global patterns
    pattern.lastIndex = 0;
  }

  return { filtered, redactions };
}

// Usage
const result = filterOutput(agentResponse);
if (result.redactions.length > 0) {
  console.warn('Sensitive data redacted:', result.redactions);
}

module.exports = { filterOutput };
```

---

## Validate skills before installing

!!! warning "26% of skills have vulnerabilities"
    According to [security research](https://blogs.cisco.com/ai/personal-ai-agents-like-openclaw-are-a-security-nightmare), many third-party skills contain malicious or vulnerable code.

### Before installing any skill

1. **Review the source code:**
```bash
# Look for dangerous calls
grep -rE "(exec|eval|subprocess|os\.system|fetch|axios|request)" skills/new-skill/

# Look for hardcoded URLs
grep -rE "https?://" skills/new-skill/
```

2. **Verify the author:**
   - Are they known in the community?
   - Do they have a contribution history?
   - Are there reported security issues?

3. **Check requested permissions:**
   - Does it ask for more access than necessary?
   - Does it need full shell/filesystem access?

4. **Search for security issues:**
```bash
# Search on GitHub
gh search issues --repo author/skill "security vulnerability"
```

---

## PROHIBITED configurations

!!! danger "Never use these configurations"

| Configuration | Why it's dangerous |
|---------------|-------------------|
| `"shell": { "enabled": true, "allow_all": true }` | Arbitrary command execution |
| `"filesystem": { "allowed_paths": ["/"] }` | Access to entire system, including keys |
| `"http_client": { "allow_all_domains": true }` | Can leak data to any server |
| `"browser": { "use_real_profile": true }` | Access to your real sessions and cookies |

### Example of what NOT to do

```json
// ❌ NEVER do this
{
  "shell": {
    "enabled": true,
    "allowed_commands": ["*"]
  },
  "filesystem": {
    "enabled": true,
    "allowed_paths": ["/"]
  },
  "http_client": {
    "enabled": true,
    "allow_all_domains": true
  }
}
```

### Secure equivalent configuration

```json
// ✅ Secure version
{
  "shell": {
    "enabled": false
  },
  "filesystem": {
    "enabled": true,
    "allowed_paths": ["/home/openclaw/openclaw/workspace"]
  },
  "http_client": {
    "enabled": true,
    "allowlist": ["api.needed.com"]
  }
}
```

---

## Principle of least privilege

!!! tip "Start with the minimum"
    1. Start with almost everything disabled
    2. Add skills only when you need them
    3. Use allowlists, never denylists as the only control
    4. Periodically review which skills are enabled

### Checklist before enabling a skill

- [ ] Do I really need this skill?
- [ ] Have I reviewed the code if it's from a third party?
- [ ] Have I configured the most restrictive permissions possible?
- [ ] Have I added only the necessary domains/paths to the allowlist?
- [ ] Have I verified that output filtering is active?

---

## Configuration summary by profile

| Profile | Shell | Filesystem | Git | HTTP | Telegram |
|---------|-------|------------|-----|------|----------|
| Code reviewer | ❌ | Read-only | Read-only | GitHub | ❌ |
| Documents | ❌ | workspace/ | ❌ | ❌ | ❌ |
| Dev + Telegram | ❌ | workspace/ | Read-only | GitHub, Telegram | ✅ |
| Researcher | ❌ | workspace/ | ❌ | Paper APIs | ❌ |

---

**Next:** [8. Agent Security](08-agent-security.md) — OWASP Agentic, guardrails, and advanced sandboxing.
