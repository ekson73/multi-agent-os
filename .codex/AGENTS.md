# ECC for Codex CLI

This supplements the root `AGENTS.md` with a repo-local ECC baseline.

## Repo Skill

- Repo-generated Codex skill: `.agents/skills/multi-agent-os/SKILL.md`
- Claude-facing companion skill: `.claude/skills/multi-agent-os/SKILL.md`
- Keep user-specific credentials and private MCPs in `~/.codex/config.toml`, not in this repo.

## MCP Baseline

Treat `.codex/config.toml` as the default ECC-safe baseline for work in this repository.
The generated baseline enables GitHub, Context7, Exa, Memory, Playwright, and Sequential Thinking.

Context7 is registered here as `context7_baseline` (keyless remote), not `context7`, so it never
merges with a user-scope `context7` entry of another transport. It does not inherit headers or the
`enabled` flag of a user `context7` entry. To turn the baseline off, set
`[mcp_servers.context7_baseline] enabled = false` in `~/.codex/config.toml`.

## Multi-Agent Support

- Explorer: read-only evidence gathering
- Reviewer: correctness, security, and regression review
- Docs researcher: API and release-note verification

## Workflow Files

- No dedicated workflow command files were generated for this repo.

Use these workflow files as reusable task scaffolds when the detected repository workflows recur.