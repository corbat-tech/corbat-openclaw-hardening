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

## Provider comparison (2026)

| Provider | Recommended model | Quality | Price | Best for |
|----------|-------------------|---------|-------|----------|
| **Kimi/Moonshot** | Kimi K2.5 | ⭐⭐⭐⭐⭐ | **FREE** | Getting started at no cost |
| **OpenAI** | GPT-5 mini | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | General use, stable |
| **Anthropic** | Claude Sonnet 4.5 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | Complex reasoning |
| **Anthropic** | Claude Opus 4.5 | ⭐⭐⭐⭐⭐⭐ | ⭐⭐ | Maximum quality |
| **DeepSeek** | DeepSeek V3 | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | High volume, low cost |
| **Google** | Gemini Flash | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | High volume |

!!! success "Kimi K2.5 free"
    Kimi K2.5 (launched January 2026) is available **for free** through NVIDIA NIM.
    Excellent option to get started at no cost and test OpenClaw.

---

## Recommendation by use case

### Personal use / testing

- **Model:** Kimi K2.5 (free)
- **Budget:** $0/month
- **Why:** Free on NVIDIA NIM, sufficient quality for testing

### Development / daily use

- **Model:** Claude Sonnet 4.5 or GPT-5 mini
- **Budget:** $30-50/month
- **Why:** Good quality/cost balance

### Production / intensive use

- **Model:** Claude Sonnet 4.5 (primary) + DeepSeek V3 (simple tasks)
- **Budget:** $80-150/month
- **Why:** Quality for complex tasks, low cost for volume

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
# On the VPS, edit .env
nano ~/openclaw/.env
```

```bash
# Kimi K2.5 via NVIDIA NIM (free)
LLM_PROVIDER=nvidia
NVIDIA_API_KEY=nvapi-XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
NVIDIA_BASE_URL=https://integrate.api.nvidia.com/v1
DEFAULT_MODEL=moonshotai/kimi-k2.5
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

### .env file permissions

```bash
# Verify .env has restrictive permissions
ls -la ~/openclaw/.env
# Should show: -rw------- (600)

# If not, fix:
chmod 600 ~/openclaw/.env
```

### Don't expose keys in logs

Verify your logging configuration doesn't print API keys:

```yaml
# In config/settings.yaml
logging:
  level: "info"
  redact_secrets: true  # Important
```

### API key rotation

!!! warning "Rotate your API keys every 90 days"
    API keys are credentials that should be rotated periodically.

**Rotation procedure:**

1. **Generate new key** in the provider's panel
2. **Update .env** on the VPS:
   ```bash
   nano ~/openclaw/.env
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

## Multi-model configuration (advanced)

If OpenClaw supports it, you can use different models for different tasks:

```yaml
# config/models.yaml (example)
routing:
  # Complex tasks: powerful model
  complex_reasoning:
    provider: anthropic
    model: claude-sonnet-4-5-20250514

  # Simple tasks: economical model
  simple_tasks:
    provider: deepseek
    model: deepseek-chat

  # Default: free model
  default:
    provider: nvidia
    model: moonshotai/kimi-k2.5
```

---

## Troubleshooting

### Error: "API key invalid" or "Unauthorized"

**Cause:** Incorrect or expired key.

**Solution:**
```bash
# Verify key is copied correctly (no spaces)
grep API_KEY ~/openclaw/.env

# Verify no hidden characters
cat -A ~/openclaw/.env | grep API_KEY
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
# OpenAI: gpt-5-mini, gpt-5
# Anthropic: claude-sonnet-4-5-20250514, claude-opus-4-5-20251101
# NVIDIA: moonshotai/kimi-k2.5
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
