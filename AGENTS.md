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
- **Naming**: lowercase-hyphenated for skills/commands/agents. **Sandwich Namespacing 5-layer pattern**:
  - **For skills/agents**: no `maos-` prefix in filename — Claude Code runtime auto-namespaces via plugin id (e.g., subagents surface as `maos:orchestrator`)
  - **For commands**: runtime auto-namespace is **empirically unreliable** (verified 2026-05-21: `/status` collided with Claude Code built-in `/status`). Use function-specific filenames (e.g., `agentic-status` not `status`) + declare namespace prefix in `.claude-plugin/plugin.json` `command_namespace` block (Layer 2) + lint against `vendor_reserved_audit.claude_code_builtins` (Layer 4 reference: [ekson73/vek-dot-claude:docs/vendor-reserved-words.md](https://github.com/ekson73/vek-dot-claude/blob/main/docs/vendor-reserved-words.md))
- **Delegation**: spawning sub-agents goes through `skills/delegate-governance/SKILL.md` (or `plugin-scripts/gaac/delegate.sh init|dna|finalize`) — canonical entry point for the GaaS/GaaC framework

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
| `protocols/delegation/` | GaaS/GaaC delegation framework: init/dna/finalize prompts + provider-matrix |
| `docs/` | Research, specs, guides |

## Architecture Decisions

- **GaaS principle**: deterministic hooks > probabilistic prompts
- **Sentinel**: 10 detection rules, enforcement modes (soft/moderate/strict)
- **Skills are Agent Skills standard**: compatible with Claude Code, Cursor, Codex, Gemini CLI, Kiro, VS Code, Goose, and 25+ other tools
- **No `maos-` prefix** in filenames for skills+agents (Claude Code runtime auto-namespaces via plugin name `maos`). For commands, runtime auto-namespace is unreliable; prefix declaration lives in `.claude-plugin/plugin.json` `command_namespace` block (Sandwich Namespacing Layer 2), not in filename. Defense-in-depth: vendor-reserved-words lint reference at sister-repo `ekson73/vek-dot-claude:docs/vendor-reserved-words.md` (Layer 4)
- **Framework Consumption Model**: this repo is source of truth; consumers reference, don't duplicate

## Security

- Never commit secrets (enforced by gitleaks pre-commit hook)
- Never use `--no-verify` to bypass hooks
- Never push --force to protected branches
- Treat hook scripts as security-critical (they have elevated permissions)

## Branching & Release Model — GitHub Flow (Class B: library/marketplace)

> This repo is **CONSUMED** by other repos/users — it does **not** deploy to environments. Model = **GitHub Flow + SemVer**. See [`docs/adrs/ADR-004-github-flow-branching.md`](./docs/adrs/ADR-004-github-flow-branching.md).

- **Trunk**: `main` is always releasable. **No environment branches** (no `homolog`/`ppe`/`prd` here — those exist only in Class A *deployed apps* like `vek-sales`/`vek-list`).
- **Work**: branch `feature/<id>-slug` · `fix/<id>-slug` · `hotfix/<id>-slug` · `docs/` · `chore/` off `main` → PR → **squash-merge** → **delete branch**.
- **Release PRs**: a `.claude-plugin/plugin.json` version delta travels in a separate, rebased, linear PR titled `chore(release): ...`; it changes only the manifest `version` field and adds exactly one matching, additive `CHANGELOG.md` section. README/CLAUDE versions remain derived by `version-sync`. The trusted-base CI gate enforces this squash-surviving artifact.
- **Agents MUST**: never commit to `main` directly · always open a PR · never create env-branches here · treat tagging/release as a human/operator gate.
- **Versioning & consumer source-pin**: governed by the companion **ADR-003** (`version-ssot-float`) + Jira — source `ref = main` during MVP (TTL'd). Do **not** re-decide it here.
