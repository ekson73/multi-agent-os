# Co-Author Standard for AI-Generated Commits

> **Version**: 1.0.0
> **Date**: 2026-03-20
> **Status**: MANDATORY for all AI agents
> **Scope**: All repos in the ecosystem

---

## Purpose

When AI agents create or co-create commits, the git history MUST capture the identity
of **3 entities** involved: the **human user**, the **AI provider**, and the **LLM/agent**.
This ensures traceability, accountability, and transparency in an ai-first project.

---

## Standard Format

```
Authored-By:    git config user.name / user.email (human — always the primary author)
Co-Authored-By: {AgentName} ({Provider}/{Model}) <{noreply-email}>
```

### Template

```
Co-Authored-By: {AgentName} ({Provider}/{Model}) <noreply+{agent}@{provider-domain}>
```

### Components

| Component | Description | Example |
|-----------|-------------|---------|
| `AgentName` | The unique name/identity of the agent instance | `Antigravity`, `Claude-Code`, `Amazon-Q`, `Copilot` |
| `Provider` | The AI provider company | `Google`, `Anthropic`, `OpenAI`, `Amazon`, `GitHub` |
| `Model` | The specific LLM being used | `Gemini-2.5-Pro`, `Claude-4-Sonnet`, `GPT-4o`, `Nova-Pro` |
| `noreply-email` | Provider's noreply email pattern | `noreply+antigravity@google.com` |

---

## Examples

```bash
# Google Gemini via Antigravity agent
Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>

# Anthropic Claude via Claude Code CLI
Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>

# Amazon Q Developer
Co-Authored-By: Amazon-Q (Amazon/Nova-Pro) <noreply+amazon-q@amazon.com>

# GitHub Copilot
Co-Authored-By: Copilot (GitHub/GPT-4o) <noreply+copilot@github.com>

# OpenAI Codex
Co-Authored-By: Codex (OpenAI/o3) <noreply+codex@openai.com>

# Goose by Block
Co-Authored-By: Goose (Block/Goose) <noreply+goose@block.xyz>

# Qwen by Alibaba
Co-Authored-By: Qwen (Alibaba/Qwen-2.5) <noreply+qwen@alibaba.com>

# Qoder
Co-Authored-By: Qoder (Qodo/Qoder) <noreply+qoder@qodo.ai>
```

---

## Multi-Agent Commits

When multiple agents collaborate on a single commit:

```bash
git commit -m "feat(auth): implement OAuth2 flow

Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>
Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>
```

---

## Human + Agent Commits

The human is ALWAYS the primary author via `git config`:

```bash
# git config (human is primary)
git config user.name "Emilson Moraes"
git config user.email "emilson.moraes@vectorinf.com.br"

# Agent adds Co-Authored-By trailer
git commit -m "fix(tests): re-enable disabled test suite

Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>"
```

Result in `git log`:

```
Author: Emilson Moraes <emilson.moraes@vectorinf.com.br>
Co-Authored-By: Antigravity (Google/Gemini-2.5-Pro) <noreply+antigravity@google.com>
```

---

## Rules

1. **MANDATORY**: Every commit created by an AI agent MUST include `Co-Authored-By`
2. **FORMAT**: Must follow `{AgentName} ({Provider}/{Model})` — all 3 entities required
3. **HUMAN PRIMARY**: The human is always `Author` (via git config), never `Co-Authored-By`
4. **NO agent-only commits**: If no human is supervising, the commit message MUST include
   `[autonomous]` tag and the agent is `Author` with its own name/email
5. **TRACEABILITY**: The `Provider/Model` component enables historical analysis of which
   LLMs contributed to the codebase over time

---

## Autonomous Agent Commits (No Human Present)

When an agent acts fully autonomously (e.g., scheduled CI/CD bots):

```bash
git config user.name "Antigravity (Google/Gemini-2.5-Pro)"
git config user.email "noreply+antigravity@google.com"

git commit -m "[autonomous] chore: update dependency checksums"
```

---

## Validation

Agents SHOULD validate their Co-Author format before committing:

```bash
# Regex validation: Name (Provider/Model) <email>
echo "$CO_AUTHOR" | grep -qP '^.+ \(.+/.+\) <.+@.+>$' && echo "VALID" || echo "INVALID"
```

---

*Created: 2026-03-20 | Author: Antigravity (Google/Gemini-2.5-Pro)*
*Trigger: Self-audit found GW-5 violation — no Co-Author standard existed*
