# Contributing to Multi-Agent OS

Thanks for your interest in contributing. This file documents the **process** for contributions; the **technical contract** for agents (build/test, conventions, key directories, architecture decisions) lives in [`AGENTS.md`](AGENTS.md) — read it first. This document covers what AGENTS.md does **not**: PR/release/rollback gates and AI-involvement disclosure.

## Contributor Types

| Type | Examples |
|---|---|
| Human contributor | Direct edits, design review, manual testing |
| AI-assisted contributor | Human author who used an AI agent (Copilot, Cursor, Claude Code, Codex, etc.) for parts of the change |
| AI-generated draft (reviewed) | Change drafted end-to-end by an AI agent and reviewed by a named human before submission |

All three types are welcome. The PR template's **AI Involvement** checkbox is required — disclose honestly.

## Workflow

1. **Open an issue** (or comment on an existing one) describing the change before non-trivial work.
2. **Branch + worktree**: never commit directly to `main`. Use `git worktree add .worktrees/<slug> -b <type>/<scope>`. The GaaS hook (`plugin-scripts/governance/`) blocks direct-main commits unless `GOVERNANCE_OVERRIDE=1 GOVERNANCE_OVERRIDE_REASON="<rationale>"` is set by the operator.
3. **Build & test** per [`AGENTS.md` § Build & Test](AGENTS.md#build--test). Pre-commit `gitleaks` is enforced — `--no-verify` is not permitted.
4. **Conventional Commits** + `Co-Authored-By:` footer for AI involvement (see [`AGENTS.md` § Commit & PR Guidelines](AGENTS.md#commit--pr-guidelines)).
5. **Open the PR** using the `.github/pull_request_template.md` template. Fill every section — `Summary`, `Type`, `AI Involvement`, `Evidence`, `Risks`, `Rollback`, `Checklist`.
6. **Bot review convergence** is required before merge — CodeRabbit, Amazon Q Developer, Qodo Merge, gitleaks workflow, and any required CI checks must all be GREEN or resolved. Address `:stop_sign:` / Security / Logic Error severity findings with either a fix-commit or an in-thread rationale.
7. **Merge gate**: maintainer (or HITL-authorized agent) squash-merges with `--delete-branch`. Self-approve via Comment-Only path when GitHub blocks formal APPROVE on own PRs.
8. **Post-merge cleanup**: `git worktree remove .worktrees/<slug>` + `git branch -D` + sync local main.

## Reviews

- Reviewers should focus on the contract impact (`AGENTS.md`, `CLAUDE.md`, `plugin.json`, `hooks.json`, protocols) and on whether bot findings were genuinely addressed (not waved away).
- For substantive guidance on what makes a useful PR review, see `.claude/rules/pr-reviewer-communication.md`.

## Release Gates

Maintainer-only operations. A release MUST:

1. Update `CHANGELOG.md` (Keep a Changelog format, SemVer).
2. Bump `.claude-plugin/plugin.json` `version`.
3. Tag the release (`v<version>`) and verify the downstream marketplace entry in [`ekson73/eko-claude-plugins`](https://github.com/ekson73/eko-claude-plugins) SHA-pins the validated commit.
4. Confirm CI version-sync workflow passes.

## Rollback

If a merged change causes regression in production usage:

1. Revert via `gh pr create` opening a `revert: ` PR against the offending commit (do not `git push --force`).
2. Roll back the marketplace SHA pin if the change shipped to consumers.
3. Document the incident in `docs/` and open a follow-up to prevent recurrence.

## Code of Conduct

Be technically rigorous, treat bot and human reviewers with the same respect, and prefer evidence over speculation. Disagreement is welcome; performative review is not.

## Reference

- [`AGENTS.md`](AGENTS.md) — agent contract (build, test, conventions, key dirs, architecture decisions, security)
- [`CLAUDE.md`](CLAUDE.md) — Claude Code-specific notes and MVV
- [`SECURITY.md`](SECURITY.md) — vulnerability disclosure
- [`CHANGELOG.md`](CHANGELOG.md) — release history
- [`.github/pull_request_template.md`](.github/pull_request_template.md) — PR template (added separately)
- [`.github/copilot-instructions.md`](.github/copilot-instructions.md) — Copilot pointer to AGENTS.md (added separately)
