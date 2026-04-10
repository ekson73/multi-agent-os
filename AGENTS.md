# AGENTS.md

> Guide for AI coding agents working on this repository.
> Follows the [AGENTS.md open standard](https://agents.md) (AAIF / Linux Foundation, 60k+ projects).

## Project Overview

Multi-Agent OS (MAOS) is a Claude Code plugin for orchestrating AI agents in software development workflows. It provides Sentinel Protocol (anomaly detection), GaaS (Governance-as-a-Service), worktree coordination, and response compression.

## Build & Test

```bash
# Validate plugin structure
bash tests/validate-plugin.sh

# Test hook scripts
echo '{"tool_name":"Task","tool_input":{"prompt":"test"}}' | bash plugin-scripts/governance/token-budget-gate.sh

# Validate JSON configs
python3 -m json.tool hooks/hooks.json > /dev/null
python3 -m json.tool sentinel/config.json > /dev/null

# Run plugin locally (self-referential)
claude --plugin-dir .
```

## Code Conventions

- **Skills**: subdirectory format with `SKILL.md` (follows [Agent Skills open standard](https://agentskills.io))
- **Commands**: markdown files with YAML frontmatter in `commands/`
- **Agents**: markdown files with YAML frontmatter in `agents/`
- **Hook scripts**: bash with `set -euo pipefail`, source `lib/common.sh` and `lib/json-rpc.sh`
- **Config**: JSON with `_comment` fields for documentation
- **Naming**: lowercase-hyphenated for skills/commands/agents. No `maos-` prefix on internal artifacts.

## Testing Instructions

Before committing any changes:

1. Run `bash tests/validate-plugin.sh` — must pass (1 pre-existing error about plugin.json hooks field is known)
2. Verify all JSON files are valid: `python3 -m json.tool <file>`
3. Verify hook scripts are executable and return valid JSON
4. New skills must pass the 10-item validation checklist in `skills/skill-writer/SKILL.md`

## Commit & PR Guidelines

- **Branch naming**: `{type}/{scope}-{description}` (e.g., `feat/response-compression`)
- **Commit style**: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`)
- **Co-author**: Include `Co-Authored-By: <Agent Name> <noreply@provider.com>`
- **Worktree**: Never commit directly to main. Use `git worktree add` (enforced by GaaS hook)
- **Secret scan**: gitleaks runs on pre-commit (enforced by GaaS hook)
- **PR review**: Bot reviewers (CodeRabbit, Copilot, Qodo) run automatically

## Key Directories

| Directory | Purpose |
|-----------|---------|
| `skills/` | Agent Skills (SKILL.md format, compatible with 30+ AI tools) |
| `commands/` | Slash commands (auto-discovered by Claude Code) |
| `agents/` | Agent persona definitions |
| `sentinel/` | Anomaly detection config and rules |
| `plugin-scripts/governance/` | GaaS enforcement hooks |
| `protocols/` | Governance protocols (merge, delegation, exit hygiene) |
| `docs/` | Research, specs, guides |

## Architecture Decisions

- **GaaS principle**: deterministic hooks > probabilistic prompts
- **Sentinel**: 10 detection rules, enforcement modes (soft/moderate/strict)
- **Skills are Agent Skills standard**: compatible with Claude Code, Cursor, Codex, Gemini CLI, Kiro, VS Code, Goose, and 25+ other tools
- **No `maos-` prefix** on internal skills/commands/agents (namespaced by plugin)
- **Framework Consumption Model**: this repo is source of truth; consumers reference, don't duplicate

## Security

- Never commit secrets (enforced by gitleaks pre-commit hook)
- Never use `--no-verify` to bypass hooks
- Never push --force to protected branches
- Treat hook scripts as security-critical (they have elevated permissions)
