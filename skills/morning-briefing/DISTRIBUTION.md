# morning-briefing — distribution & SSOT

> **SSOT**: `ekson73/multi-agent-os` → `skills/morning-briefing/SKILL.md`. This is the
> **single source of truth** for the skill. Every other copy on the machine is a
> *projection* of this file and must never be hand-edited — edit here, open a PR, let
> the projections refresh.

## Why this note

Per the operator's SSOT directive, MAOS agentic-tools (skills/commands/agents) have
**one** authoritative home and are distributed to each AI-harness following that
harness's own best practice — **preferably a symlink** so there is no drift, and a
**copy** only where a loader ignores symlinks. A second owner writing into a shared
skill root is the root cause of skill-name shadowing (first-writer-wins, silent); the
fix is structural — one owner, one SSOT, projections downstream.

## How each harness gets it (best-practice per loader)

| Harness / loader | Mechanism | Symlink-safe? |
|---|---|---|
| Claude Code (`~/.claude/skills`, plugin marketplace) | plugin install / `npx skills add` | **copy** — Claude Desktop skips symlinked skills (claude-code #37435) |
| kiro-cli + Kiro IDE (`~/.kiro/skills`) | `npx skills add ekson73/multi-agent-os -g -a kiro-cli` (writes real **copies**; each becomes a `/slash` command) | copy (CLI default) |
| Kiro Crew (`~/.kiro/crew/skills` + `skills.extra_paths`) | point `skills.extra_paths` at `~/.kiro/skills` — zero-copy, hot-reloaded | **symlink/zero-copy** (the preferred form) |
| opencode (`~/.config/opencode/skills`), agentskills roots | `npx skills add … -a '*' --copy` for loaders that ignore symlinks; symlink otherwise | mixed |

Detail and the verified facts behind this table live in `docs/kiro-cohabitation.md`
(the authoritative co-habitation reference) and in the steering note
`~/.kiro/steering/ai-harness-cohabitation.md`.

## The rule

1. **Edit only the SSOT** (`skills/morning-briefing/SKILL.md`) → PR → merge.
2. **Never hand-edit a projected copy** in any harness root — the edit is lost on the
   next refresh and creates a shadowing/drift bug.
3. **Prefer a symlink / zero-copy pointer** (e.g. Kiro Crew `extra_paths`); fall back to
   a **copy** only for loaders that demonstrably ignore symlinks (Claude Desktop,
   Antigravity, symlinked `commands/*.md`).
4. Refresh copies with the loader's own updater (`npx skills update`), never by hand.
