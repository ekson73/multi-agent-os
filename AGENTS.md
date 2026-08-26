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
- **CHANGELOG entry**: a PR that changes the *consumable contract* must add an entry under `## [Unreleased]`. "Contract" is not a path pattern — it is decided by `scripts/entry-classifier.sh`, the **same `is_entry()` predicate `tests/validate-plugin.sh` uses**, plus skill `profiles/` (parameterisation a consumer loads). So nested entries count (`agents/consultants/*.md`, `commands/*/*.md`) while ALL-CAPS documents (`agents/README.md`, `agents/COWORK-AUTONOMY-POLICY.md`) and a skill's sub-documents (`examples/`, `EVAL-REPORT-*.md`) do not. Enforced by `changelog-required.yml`, which runs the classifier from a **trusted checkout of `main`** and never checks out head — only the file *list* comes from the API. **Escape**: the `no-changelog` label, logged in the job, never silent. Ships in **WARN** mode (`ENFORCE: '0'`); promotion to BLOCK is an operator decision (see #278)

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
- **Release PRs**: a `.claude-plugin/plugin.json` version delta travels in a separate, rebased PR containing exactly one commit whose subject is `chore(release): ...`; it changes only the manifest `version` field and adds exactly one matching, additive `CHANGELOG.md` section. Repository squash is configured as `COMMIT_OR_PR_TITLE + COMMIT_MESSAGES`, so that single commit subject survives on `main`. README/CLAUDE versions remain derived by `version-sync`. The trusted-base workflow is authoritative evidence for maintainers, but remains advisory until a dedicated publisher identity or organization-level required workflow can authenticate its verdict without same-repository status spoofing.
- **Agents MUST**: never commit to `main` directly · always open a PR · never create env-branches here · treat tagging/release as a human/operator gate.
- **Versioning & consumer source-pin**: governed by the companion **ADR-003** (`version-ssot-float`) + Jira — source `ref = main` during MVP (TTL'd). Do **not** re-decide it here.

<!-- gitnexus:start -->
# GitNexus — Code Intelligence

This project is indexed by GitNexus as **multi-agent-os** (9779 symbols, 14033 relationships, 300 execution flows). Use the GitNexus MCP tools to understand code, assess impact, and navigate safely.

> Index stale? Run `node .gitnexus/run.cjs analyze` from the project root — it auto-selects an available runner. No `.gitnexus/run.cjs` yet? `npx gitnexus analyze` (npm 11 crash → `npm i -g gitnexus`; #1939).

## Always Do

- **MUST run impact analysis before editing any symbol.** Before modifying a function, class, or method, run `impact({target: "symbolName", direction: "upstream"})` and report the blast radius (direct callers, affected processes, risk level) to the user.
- **MUST run `detect_changes()` before committing** to verify your changes only affect expected symbols and execution flows. For regression review, compare against the default branch: `detect_changes({scope: "compare", base_ref: "main"})`.
- **MUST warn the user** if impact analysis returns HIGH or CRITICAL risk before proceeding with edits.
- When exploring unfamiliar code, use `query({search_query: "concept"})` to find execution flows instead of grepping. It returns process-grouped results ranked by relevance.
- When you need full context on a specific symbol — callers, callees, which execution flows it participates in — use `context({name: "symbolName"})`.
- For security review, `explain({target: "fileOrSymbol"})` lists taint findings (source→sink flows; needs `analyze --pdg`).

## Never Do

- NEVER edit a function, class, or method without first running `impact` on it.
- NEVER ignore HIGH or CRITICAL risk warnings from impact analysis.
- NEVER rename symbols with find-and-replace — use `rename` which understands the call graph.
- NEVER commit changes without running `detect_changes()` to check affected scope.

## Resources

| Resource | Use for |
|----------|---------|
| `gitnexus://repo/multi-agent-os/context` | Codebase overview, check index freshness |
| `gitnexus://repo/multi-agent-os/clusters` | All functional areas |
| `gitnexus://repo/multi-agent-os/processes` | All execution flows |
| `gitnexus://repo/multi-agent-os/process/{name}` | Step-by-step execution trace |

## CLI

| Task | Read this skill file |
|------|---------------------|
| Understand architecture / "How does X work?" | `.claude/skills/gitnexus/gitnexus-exploring/SKILL.md` |
| Blast radius / "What breaks if I change X?" | `.claude/skills/gitnexus/gitnexus-impact-analysis/SKILL.md` |
| Trace bugs / "Why is X failing?" | `.claude/skills/gitnexus/gitnexus-debugging/SKILL.md` |
| Rename / extract / split / refactor | `.claude/skills/gitnexus/gitnexus-refactoring/SKILL.md` |
| Tools, resources, schema reference | `.claude/skills/gitnexus/gitnexus-guide/SKILL.md` |
| Index, status, clean, wiki CLI commands | `.claude/skills/gitnexus/gitnexus-cli/SKILL.md` |

<!-- gitnexus:end -->
