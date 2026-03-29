# Co-Author Standard for AI-Generated Commits

> **Version**: 2.1.0
> **Date**: 2026-03-20
> **Status**: MANDATORY for all AI agents
> **Scope**: All repos in the ecosystem (git-provider agnostic)

---

## Purpose

When AI agents create or co-create commits, the git history MUST capture the identity
of **3 entities** involved: the **human user**, the **AI provider**, and the **LLM/agent**.
This ensures traceability, accountability, and transparency in an ai-first project.

---

## Standard Format

The human author is always set via `git config user.name` / `user.email` (this populates the
standard `Author` field in git; there is no `Authored-By` trailer -- do NOT add one to commits).
The AI agent adds a `Co-Authored-By` git trailer:

```text
Co-Authored-By: {AgentName} ({Provider}/{Model}) <noreply+{agent}@{provider-domain}>
```

### Components

| Component | Description | Example |
|-----------|-------------|---------|
| `AgentName` | The unique name/identity of the agent instance | `Antigravity`, `Claude-Code`, `Amazon-Q`, `Copilot` |
| `Provider` | The AI provider company | `Google`, `Anthropic`, `OpenAI`, `Amazon`, `GitHub` |
| `Model` | The specific LLM being used | `Gemini-2.5-Pro`, `Claude-4-Sonnet`, `GPT-4o`, `Nova-Pro` |
| `noreply-email` | Provider's noreply email (or agent-specific email) | `noreply+antigravity@google.com` |

> **Note**: The `noreply+{agent}@{provider}` pattern is a convention for traceability.
> If the provider has a different noreply format (e.g., `noreply@users.github.com`),
> adapt accordingly. The key requirement is that all 3 entities are identifiable.

---

## Examples

```bash
# Google Gemini via Antigravity agent
Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>

# Anthropic Claude via Claude Code CLI
Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>

# Amazon Q Developer
Co-Authored-By: Amazon-Q (Amazon/Nova-Pro) <noreply+amazon-q@amazon.com>

# GitHub Copilot (uses GitHub noreply format)
Co-Authored-By: Copilot (GitHub/GPT-4o) <copilot@users.noreply.github.com>

# OpenAI Codex
Co-Authored-By: Codex (OpenAI/o3) <noreply+codex@openai.com>

# Goose by Block
Co-Authored-By: Goose (Block/Goose) <noreply+goose@block.xyz>

# Qwen by Alibaba
Co-Authored-By: Qwen (Alibaba/Qwen-2.5) <noreply+qwen@alibaba.com>

# Qoder by Qodo
Co-Authored-By: Qoder (Qodo/Qoder) <noreply+qoder@qodo.ai>
```

---

## Multi-Agent Commits

When multiple agents collaborate on a single commit:

```bash
git commit -m "feat(auth): implement OAuth2 flow

Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>
Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>"
```

---

## Human + Agent Commits (Supervised)

The human is the primary author via `git config`. The agent adds the trailer:

```bash
# Human identity (git config)
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Agent adds Co-Authored-By trailer
git commit -m "fix(tests): re-enable disabled test suite

Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>"
```

Result in `git log`:

```text
Author: Your Name <your.email@example.com>
Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>
```

---

## Autonomous Agent Commits (No Human Present)

When an agent acts fully autonomously (e.g., scheduled CI/CD bots, cron tasks):

- The agent becomes the primary `Author` (via git config)
- The commit message MUST include the `[autonomous]` tag
- No `Co-Authored-By` is needed (the agent IS the author)

```bash
git config user.name "Antigravity (Google/Gemini-2.5-Pro)"
git config user.email "noreply+antigravity@google.com"

git commit -m "[autonomous] chore: update dependency checksums"
```

---

## Rules

1. **MANDATORY**: Every **supervised** commit involving an AI agent MUST include `Co-Authored-By`
2. **FORMAT**: Must follow `{AgentName} ({Provider}/{Model})` — all 3 entities required
3. **SUPERVISED**: When a human supervises, the human is `Author` (git config) and
   the agent is `Co-Authored-By`
4. **AUTONOMOUS**: When no human supervises, the agent is `Author` (git config) and
   the commit includes `[autonomous]` tag — no `Co-Authored-By` needed
5. **TRACEABILITY**: The `Provider/Model` component enables historical analysis of which
   LLMs contributed to the codebase over time

---

## Validation

Agents SHOULD validate their Co-Author format before committing:

```bash
# Regex validation: Name (Provider/Model) <email>
# Uses grep -E for POSIX/macOS portability (not grep -P which is GNU-only)
echo "$CO_AUTHOR" | grep -qE '^[^()<>]+ \([A-Za-z0-9.-]+/[A-Za-z0-9._-]+\) <[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}>$' \
  && echo "VALID" || echo "INVALID"
```

---

*v2.1.0 | 2026-03-27 | Fixed: stricter validation regex, Authored-By clarification, tightened grep pattern*
*v2.0.0 | 2026-03-20 | Fixed: rule contradiction (human/autonomous), grep portability, email format note, git-provider agnostic*
*v1.0.0 | 2026-03-20 | Initial version*

Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>
