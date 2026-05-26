# GitHub Copilot — Repository Instructions

This file is GitHub Copilot's entry point. **The canonical agent contract is [`AGENTS.md`](../AGENTS.md)** — read that first. This file is a pointer, not a duplicate, in keeping with the DRY principle (`scope-discipline-pre-creation.md` §Q2).

## Read order

1. [`AGENTS.md`](../AGENTS.md) — project overview, build/test, conventions, key directories, architecture decisions, security
2. [`CONTRIBUTING.md`](../CONTRIBUTING.md) — PR workflow, AI-involvement disclosure, release/rollback gates
3. [`CLAUDE.md`](../CLAUDE.md) — Claude Code-specific notes (most cross-vendor guidance lives in AGENTS.md)
4. [`SECURITY.md`](../SECURITY.md) — vulnerability disclosure
5. `.github/pull_request_template.md` — PR template (mandatory fields)

## Must

- Use a `git worktree` for any edits (`AGENTS.md` § Commit & PR Guidelines). Direct-main commits are blocked by GaaS hook.
- Run `bash tests/validate-plugin.sh` before committing (`AGENTS.md` § Testing Instructions).
- Conventional Commits with `Co-Authored-By:` footer when AI assistance is used.
- Disclose AI involvement honestly in the PR template's `AI Involvement` section.

## Must Not

- Use `--no-verify` to bypass pre-commit hooks (gitleaks is non-negotiable).
- Commit secrets, tokens, `.env`, or PAT credentials.
- Edit `.claude-plugin/plugin.json` `version` or `name` without coordinating the downstream marketplace pin in [`ekson73/eko-claude-plugins`](https://github.com/ekson73/eko-claude-plugins).
- Mass-create governance scaffolding (`.ai/`, ADRs, EVALS yaml, etc.) without Triple-touch evidence (`AGENTS.md` § Architecture Decisions + 3 occurrences of need).

## Code style

See `AGENTS.md` § Code Conventions. Bash hooks use `set -euo pipefail` and source `lib/common.sh` + `lib/json-rpc.sh`. Skills follow the `SKILL.md` subdirectory format (Agent Skills open standard).

## Tests

`AGENTS.md` § Build & Test enumerates the canonical commands. The CI workflows in `.github/workflows/` (`ai-governance-linter`, `converge-tests`, `ontology-validation`, `supply-chain-sentinel`, `version-sync`) run on every PR — local Copilot suggestions should not break them.

## Branching & Release

Model = **GitHub Flow (Class B — library/marketplace)**. SSOT = [`AGENTS.md`](../AGENTS.md) §"Branching & Release Model" (+ `docs/adrs/ADR-004`). Never create environment branches here; never commit to `main` directly; PR → squash → delete-branch. Consumer source-pin = float per ADR-003.
