# 6. LLM APIs

> **TL;DR**: Configure LLM provider API keys, set mandatory spending limits, and configure usage alerts.

> **Estimated time**: 10-15 minutes

> **Required level**: Beginner

!!! warning "Provider URLs"
    LLM provider console and dashboard URLs may change over time.
    If any link doesn't work, look for the equivalent section on the provider's site.

    **Last URL verification:** 2026-02

## Prerequisites

- [ ] Section 5 (OpenClaw) completed
- [ ] Account with at least one LLM provider

## Objectives

By the end of this section you will have:

- API key configured on the VPS
- Spending limits established
- Usage alerts configured
- Knowledge of when to rotate keys

---

## Provider comparison (March 2026)

| Provider | Model | Model ID | Pricing | Context | Best for |
|----------|-------|----------|---------|---------|----------|
| **xAI** | Grok 4.1 Fast | `grok-4-1-fast-reasoning` | $0.20 / $0.50 per MTok | 2M | Best price/performance, agentic tool calling |
| **Kimi Coding** | Kimi for Coding | `kimi-for-coding` | **Free** (with Kimi Code subscription) | 262K | Daily use, coding, tooling |
| **Kimi/Moonshot** | Kimi K2.5 | `kimi-k2.5` | ~$0.50 / $1.50 per MTok | 262K | Multilingual, coding, good reasoning |
| **Google** | Gemini 2.5 Flash | `gemini-2.5-flash` | $0.30 / $2.50 per MTok | 1M | Web search, large context |
| **DeepSeek** | DeepSeek V3.2 | `deepseek-chat` | $0.28 / $0.42 per MTok | 128K | Budget champion, reasoning + tools |
| **Anthropic** | Claude Sonnet 4.6 | `claude-sonnet-4-6` | $3.00 / $15.00 per MTok | 1M | Mission-critical, maximum reliability |
| **Anthropic** | Claude Opus 4.6 | `claude-opus-4-6` | $5.00 / $25.00 per MTok | 1M | Maximum quality |
| **OpenAI** | GPT-5 mini | `gpt-5-mini` | $1.75 / $14.00 per MTok | 128K | General use, stable |

---

## Recommended setups (March 2026)

!!! tip "Community consensus: Grok 4.1 Fast is the best overall value"
    2M token context, best agentic tool calling, and $0.20/$0.50 per MTok. The **reasoning** variant scores 64 vs 38 (non-reasoning) on benchmarks at the same price per token — it just consumes more tokens for chain-of-thought.

### Near-zero cost (with Kimi Code subscription)

| Role | Model | Cost |
|------|-------|------|
| Primary | Kimi for Coding (free with subscription) | $0 |
| Fallback | Grok 4.1 Fast Reasoning | $0.20/$0.50 per MTok |
| Web search | Brave (free ~1,000 queries/month) | $0 |

**Estimated: <$1/month.** The Kimi Code subscription covers the primary. Grok only activates when Kimi fails, so consumption is minimal.

### Best price/performance

| Role | Model | Cost |
|------|-------|------|
| Primary | Grok 4.1 Fast Reasoning | $0.20/$0.50 per MTok |
| Fallback | DeepSeek V3.2 | $0.28/$0.42 per MTok |
| Web search | Brave | Free |

**Estimated: ~$10-30/month.** Grok as primary offers 2M context and the best agentic performance. DeepSeek as a cheap and capable fallback.

### Budget minimum (no subscriptions)

| Role | Model | Cost |
|------|-------|------|
| Primary | Kimi K2.5 | ~$0.50/$1.50 per MTok |
| Fallback | MiniMax M2.5 or MiMo-V2-Flash | Very low |
| Web search | Brave (free) or SearXNG (self-hosted) | Free |

**Estimated: ~$15/month.**

### Maximum reliability

| Role | Model | Cost |
|------|-------|------|
| Primary | Claude Sonnet 4.6 | $3/$15 per MTok |
| Fallback | Grok 4.1 Fast Reasoning | $0.20/$0.50 per MTok |
| Web search | Brave or Gemini | Low |

**Estimated: ~$50-200/month depending on usage.**

!!! info "Cost-saving tip"
    Use DeepSeek V3.2 or Gemini Flash for subagents and heartbeats instead of the primary model — estimated savings of $40-60/month.

---

## Web search providers

OpenClaw supports multiple web search providers. **Only one provider** can be active — there is no fallback chain for web search (feature request [#2317](https://github.com/openclaw/openclaw/issues/2317)).

Auto-detection order (if no explicit provider configured): Brave → Gemini → Perplexity → Grok.

| Provider | Cost | Free tier | Quality | Notes |
|----------|------|-----------|---------|-------|
| **Brave** (recommended) | $5/1K queries | $5 credits/month (~1,000 queries) | Own index, clean results | Requires card (no charge within credits) |
| **Gemini** | $14-35/1K (grounding) | 1,500 requests/day free | Google Search grounding | Most generous free tier |
| **Grok** | $5/1K tool calls | No | AI-synthesized + citations | Reuses your `XAI_API_KEY` |
| **Kimi** | $0.005/call + tokens | No | Moonshot native | Requires `MOONSHOT_API_KEY` (Kimi Code key does NOT work) |
| **Perplexity** | Paid | No | AI-synthesized answers | Good quality, more expensive |
| **SearXNG** | Free (self-hosted) | Unlimited | Variable | Requires Docker, maximum privacy |

---

## Configure API Keys

### Kimi K2.5 (FREE via NVIDIA NIM)

!!! success "Recommended free option"
    Ideal to get started without spending money.

1. Go to [build.nvidia.com](https://build.nvidia.com/moonshotai/kimi-k2.5)
2. Create NVIDIA account (free)
3. Click "Get API Key"
4. Copy the key starting with `nvapi-...`

```bash
# On the VPS, edit the env file (root-owned, loaded by systemd)
sudo nano /etc/openclaw/env
```

```bash
# Kimi K2.5 via NVIDIA NIM (free)
LLM_PROVIDER=nvidia
NVIDIA_API_KEY=nvapi-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
DEFAULT_MODEL=moonshotai/kimi-k2.5
```

### xAI (Grok 4.1 Fast)

1. Go to [console.x.ai](https://console.x.ai/home) and create an account
2. In the left sidebar, go to **Billing** and add a payment method
3. Go to **API Keys** → **Create API Key**
4. Copy the key starting with `xai-...`

```bash
# In /etc/openclaw/env
XAI_API_KEY=xai-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### OpenAI

1. Go to [platform.openai.com/api-keys](https://platform.openai.com/api-keys)
2. Click "Create new secret key"
3. Give it a descriptive name: "openclaw-vps"
4. Copy the key (only shown once)

```bash
# In .env
LLM_PROVIDER=openai
OPENAI_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
DEFAULT_MODEL=gpt-5-mini
```

### Anthropic

1. Go to [console.anthropic.com/settings/keys](https://console.anthropic.com/settings/keys)
2. Click "Create Key"
3. Give it a name: "openclaw-vps"
4. Copy the key

```bash
# In .env
LLM_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-ant-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
DEFAULT_MODEL=claude-sonnet-4-5-20250514
```

### DeepSeek

1. Go to [platform.deepseek.com](https://platform.deepseek.com)
2. Create account and generate API key

```bash
# In .env
LLM_PROVIDER=deepseek
DEEPSEEK_API_KEY=sk-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
DEFAULT_MODEL=deepseek-chat
```

---

## Spending limits (MANDATORY)

!!! danger "Configure this BEFORE using the API"
    Without limits, a bug, infinite loop, or excessive usage can generate bills of hundreds or thousands of dollars.

### OpenAI

1. Go to [platform.openai.com/settings/organization/limits](https://platform.openai.com/settings/organization/limits)
2. Configure:
   - **Hard limit:** $50 (stops when reached)
   - **Soft limit:** $30 (notifies you by email)

### Anthropic

1. Go to [console.anthropic.com/settings/limits](https://console.anthropic.com/settings/limits)
2. Set **Monthly spending limit:** $50

### xAI (Grok)

1. Go to [console.x.ai](https://console.x.ai/home) → **Billing**
2. Set a monthly spending cap (xAI supports hard limits)

### NVIDIA NIM (Kimi K2.5)

- The free tier already has built-in rate limits
- You don't need to configure additional limits

### Recommended limits

| Profile | Monthly hard limit | Soft limit |
|---------|-------------------|------------|
| Testing | $20 | $10 |
| Development | $50 | $30 |
| Personal production | $100 | $70 |

---

## Configure usage alerts

### OpenAI

1. Go to [platform.openai.com/settings/organization/notifications](https://platform.openai.com/settings/organization/notifications)
2. Enable email alerts for:
   - 50% of limit reached
   - 80% of limit reached
   - Limit reached

### Anthropic

1. Go to [console.anthropic.com/settings/notifications](https://console.anthropic.com/settings/notifications)
2. Configure similar alerts

### Manual monitoring

Review usage periodically:

- **OpenAI:** [platform.openai.com/usage](https://platform.openai.com/usage)
- **Anthropic:** [console.anthropic.com/settings/usage](https://console.anthropic.com/settings/usage)
- **NVIDIA NIM:** Dashboard at build.nvidia.com

---

## API Key security

!!! danger "Do not store API keys in plaintext `.env` files if you can avoid it"
    `.env` files are vulnerable to prompt injection, leak in shell history and logs, and any process from the user can read them.

### Option 1: OpenClaw SecretRef (RECOMMENDED)

Starting from v2026.3.x, OpenClaw includes **SecretRef** for secure credential management:

```bash
# Store API key securely (encrypted on disk)
openclaw secrets configure ANTHROPIC_API_KEY
# Enter the value interactively (not shown on screen)

# List stored secrets
openclaw secrets list

# Delete a secret
openclaw secrets delete ANTHROPIC_API_KEY
```

In `openclaw.json`, reference the secrets:
```json
{
  "agent": {
    "apiKey": { "$secretRef": "ANTHROPIC_API_KEY" }
  }
}
```

### Option 2: lkr (LLM Key Ring)

[lkr](https://github.com/yotta/lkr) is a client-side encryption tool for API keys:

```bash
# Install lkr
npm install -g lkr

# Store key (encrypted with XChaCha20-Poly1305)
lkr set ANTHROPIC_API_KEY

# Use in scripts
export ANTHROPIC_API_KEY=$(lkr get ANTHROPIC_API_KEY)
```

### Option 3: .env file (legacy)

If you must use `.env`, apply restrictive permissions:

```bash
# Verify env file has restrictive permissions
ls -la /etc/openclaw/env
# Should show: -rw------- (600), owner root:openclaw

# If not, fix:
sudo chmod 600 /etc/openclaw/env
sudo chown root:openclaw /etc/openclaw/env
```

### Don't expose keys in logs

Verify your logging configuration doesn't print API keys:

```yaml
# In config/settings.yaml (create if needed)
logging:
  level: "info"
  redact_secrets: true  # Important
```

### API key rotation

!!! warning "Rotate your API keys every 90 days"
    API keys are credentials that should be rotated periodically.

**Rotation procedure:**

1. **Generate new key** in the provider's panel
2. **Update env file** on the VPS:
   ```bash
   sudo nano /etc/openclaw/env
   # Replace the old key with the new one
   ```
3. **Restart service:**
   ```bash
   sudo systemctl restart openclaw
   ```
4. **Verify operation** in the logs:
   ```bash
   sudo journalctl -u openclaw -n 20
   ```
5. **Revoke old key** in the provider's panel (only after verification)

**Record rotation date:**

```bash
# Save date of last rotation
echo $(date +%Y-%m-%d) > ~/openclaw/.last_key_rotation

# Check when the last rotation was
cat ~/openclaw/.last_key_rotation
```

---

## Anomalous usage monitoring

### Indicators of possible compromise

| Signal | Possible cause | Action |
|--------|----------------|--------|
| Usage outside business hours | Compromised key or bug | Review logs, consider rotating key |
| Unusual token spikes | Infinite loop or abuse | Stop service, investigate |
| Requests from unknown IPs | Leaked key | Rotate key immediately |
| Usage after stopping service | Key used externally | Rotate key immediately |

### Usage verification script

```bash
nano ~/openclaw/scripts/check_api_usage.sh
```

```bash
#!/bin/bash
# Verify API usage

echo "=== API Usage Verification ==="
echo "Date: $(date)"
echo ""

# Reminder to check dashboards
echo "Review usage at:"
echo "- OpenAI: https://platform.openai.com/usage"
echo "- Anthropic: https://console.anthropic.com/settings/usage"
echo "- NVIDIA: https://build.nvidia.com (dashboard)"
echo ""

# Verify last key rotation
if [ -f ~/openclaw/.last_key_rotation ]; then
    LAST_ROTATION=$(cat ~/openclaw/.last_key_rotation)
    echo "Last API key rotation: $LAST_ROTATION"

    # Calculate days since last rotation
    LAST_TS=$(date -d "$LAST_ROTATION" +%s 2>/dev/null || echo 0)
    NOW_TS=$(date +%s)
    DAYS=$(( (NOW_TS - LAST_TS) / 86400 ))

    if [ "$DAYS" -gt 90 ]; then
        echo "⚠️  ALERT: $DAYS days have passed. Consider rotating API keys."
    else
        echo "✅ Keys rotated $DAYS days ago (< 90 days)"
    fi
else
    echo "⚠️  No record of last rotation"
    echo "   Run: echo \$(date +%Y-%m-%d) > ~/openclaw/.last_key_rotation"
fi
```

```bash
chmod +x ~/openclaw/scripts/check_api_usage.sh
```

---

## Multi-model configuration with fallbacks

OpenClaw supports a primary model with automatic fallbacks. Here is the recommended
configuration for `~/.openclaw/openclaw.json` using our reference setup (Kimi Coding +
Grok 4.1 Fast Reasoning + Brave for web search):

```json
{
  "models": {
    "mode": "merge",
    "providers": {
      "kimi-coding": {
        "baseUrl": "https://api.kimi.com/coding",
        "apiKey": "${KIMI_API_KEY}",
        "api": "anthropic-messages",
        "headers": {
          "User-Agent": "claude-code/0.1.0"
        },
        "models": [
          {
            "id": "kimi-for-coding",
            "name": "Kimi Coding",
            "reasoning": false,
            "input": ["text"],
            "contextWindow": 262144,
            "maxTokens": 32768
          }
        ]
      },
      "xai": {
        "baseUrl": "https://api.x.ai/v1",
        "apiKey": "${XAI_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "grok-4-1-fast-reasoning",
            "name": "Grok 4.1 Fast",
            "reasoning": false,
            "input": ["text", "image"],
            "contextWindow": 2097152,
            "maxTokens": 131072
          }
        ]
      },
      "google": {
        "baseUrl": "https://generativelanguage.googleapis.com/v1beta/openai",
        "apiKey": "${GOOGLE_API_KEY}",
        "api": "openai-completions",
        "models": [
          {
            "id": "gemini-2.5-flash",
            "name": "Gemini 2.5 Flash",
            "reasoning": false,
            "input": ["text", "image"],
            "contextWindow": 1048576,
            "maxTokens": 65536,
            "compat": {
              "supportsStore": false
            }
          }
        ]
      }
    }
  },
  "agents": {
    "defaults": {
      "model": {
        "primary": "kimi-coding/kimi-for-coding",
        "fallbacks": [
          "xai/grok-4-1-fast-reasoning"
        ]
      }
    }
  },
  "tools": {
    "profile": "full",
    "web": {
      "search": {
        "enabled": true,
        "provider": "brave",
        "apiKey": "${BRAVE_SEARCH_API_KEY}"
      },
      "fetch": {
        "enabled": true
      }
    }
  }
}
```

!!! info "Key details about this configuration"
    - **Kimi Coding** uses `anthropic-messages` API (not `openai-completions`)
    - **Kimi Coding** `baseUrl` has no trailing `/v1` — it's `https://api.kimi.com/coding`
    - **Kimi Coding** requires the `User-Agent` header or requests will fail
    - **Grok** model ID is `grok-4-1-fast-reasoning` (the **reasoning** variant — scores 64 vs 38 at same price/token)
    - **Grok** `reasoning: false` in the model definition is correct — this controls OpenClaw's prompt handling, not the model's internal reasoning
    - **Gemini** requires `compat.supportsStore: false` (see Issue #22704)
    - **Web search** uses Brave with a dedicated API key (`BRAVE_SEARCH_API_KEY`)
    - Environment variables (`${VAR}`) are resolved from `/etc/openclaw/env`
    - **Hot reload**: OpenClaw detects changes to `openclaw.json` automatically — restart is not always needed

### Required environment variables

Add these to `/etc/openclaw/env`:

```bash
# Primary: Kimi Coding (subscription)
KIMI_API_KEY=kimi-XXXXXXXXXXXXXXXXXXXXXXXX

# Fallback: xAI Grok
XAI_API_KEY=xai-XXXXXXXXXXXXXXXXXXXXXXXX

# Optional LLM: Google Gemini (if using as fallback)
GOOGLE_API_KEY=AIzaSyXXXXXXXXXXXXXXXXXXXXXXXXXXX

# Web search: Brave
BRAVE_SEARCH_API_KEY=BSAxxxxxxxxxxxxxxxxxxxxxxxxx
```

Then apply:

```bash
sudo systemctl daemon-reload
sudo systemctl restart openclaw
```

---

## Technical notes

!!! warning "Important configuration details"
    These are field-tested findings from real deployments, not theoretical recommendations.

- **Hot reload**: OpenClaw detects changes to `openclaw.json` automatically — a service restart is not always needed, but recommended for env var changes
- **Brave web search config**: The `apiKey` goes in `tools.web.search.apiKey`, NOT inside `tools.web.search.brave.apiKey` (schema validation error if nested incorrectly)
- **Kimi auth keys**: The Kimi Code subscription key (`sk-kimi-*`) and the Moonshot platform API key (`sk-*`) are different credentials. Web search via Kimi in OpenClaw requires the Moonshot key, not the Kimi Code key
- **Grok reasoning vs non-reasoning**: Variants of the same model (`grok-4-1-fast-reasoning` / `grok-4-1-fast-non-reasoning`). Same price per token, but reasoning consumes more tokens for chain-of-thought. Quality difference is significant (64 vs 38 on benchmarks)
- **Config sync**: `models.json` (agent-level) and `openclaw.json` (global) define providers redundantly — keep them synchronized to avoid inconsistencies
- **Web search has no fallback**: OpenClaw only allows one provider for `web_search` — there is no fallback chain. Feature request [#2317](https://github.com/openclaw/openclaw/issues/2317) is open

---

## Troubleshooting

### Error: "API key invalid" or "Unauthorized"

**Cause:** Incorrect or expired key.

**Solution:**
```bash
# Verify key is copied correctly (no spaces)
sudo grep API_KEY /etc/openclaw/env

# Verify no hidden characters
sudo cat -A /etc/openclaw/env | grep API_KEY
```

### Error: "Rate limit exceeded"

**Cause:** Too many requests in a short time.

**Solution:**
- Implement exponential backoff
- Reduce request frequency
- Consider a model with higher limits

### Error: "Insufficient quota"

**Cause:** Credit depleted or reached limit.

**Solution:**
- Add more credit in the provider's panel
- Wait for the next billing cycle
- Use a free model in the meantime

### Error: "Model not found"

**Cause:** Incorrect model name.

**Solution:**
```bash
# Verify exact model names in official documentation
# Kimi Coding: kimi-for-coding
# xAI Grok: grok-4-1-fast-reasoning (reasoning variant)
# Google: gemini-2.5-flash
# OpenAI: gpt-5-mini, gpt-5
# Anthropic: claude-sonnet-4-6, claude-opus-4-6
# DeepSeek: deepseek-chat
```

---

## Summary

| Configuration | Status |
|---------------|--------|
| API key configured | ✅ |
| .env permissions = 600 | ✅ |
| Spending limit configured | ✅ |
| Usage alerts enabled | ✅ |
| Rotation date recorded | ✅ |

---

**Next:** [7. Use cases](07-use-cases.md) — Practical configuration examples.
