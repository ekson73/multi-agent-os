---
name: morning-briefing
description: |
  Deliver a deterministic, scannable, evidence-backed briefing of the user's current work state across
  repos / PRs / tasks / memory — for fast context restoration after a sleep cycle, break, or post-compact
  fresh context. Produces a 7-section SitRep-inspired output (state · done · in-flight · blockers ·
  decisions-awaiting · risks · next-action) with optional narrative polish. Use when the user says
  "morning briefing", "good morning, where was I", "give me a state recap", "what's pending",
  or starts a session after a break. Capability-detected (git/gh/jq optional), cross-vendor (AAIF spec),
  no hardcoded vendors, open-source-promotable. Differs from /context-restore (no prior /context-save
  required — works cold) and /retro (daily, not weekly, decision-oriented not retrospective).
prompt_version: "1.0.0"
type: skill
spec: AAIF / agentskills.io
applicable_hosts: [Claude Code, Cursor, GitHub Copilot, Aider, any AAIF-compliant agent]
allowed-tools: [Bash, Read, Glob, Grep]
cycles_completed: 2
triggers:
  - morning briefing
  - state of work
  - state recap
  - where was i
  - what is pending
  - post-compact briefing
---

# morning-briefing

> Cross-vendor AAIF skill that produces a 7-section structured briefing of the user's current work state. Designed for fast post-sleep / post-break / post-compact context restoration. Deterministic core (cheap, ≤2s, ≤500 tokens) + optional narrative layer.

## Purpose & differentiation

Mature analogues exist but don't fit:

- `/context-restore` requires `/context-save` to have been called first (cold-start fails)
- `/retro` is weekly + retrospective + team-aware (not daily + forward-looking + user-centric)
- Single-project STATE.md patterns don't span cross-repo / cross-PR
- Daily standup template is meeting-format (not solo agent)
- Military SitRep is the closest structural analogue and inspires sections below

This skill answers: **"What is the state of MY work RIGHT NOW, across all artifacts, with the highest-value next action surfaced?"**

## Operator flags

| Flag | Effect |
|---|---|
| (none, default) | Deterministic 7-section briefing + 1-paragraph narrative |
| `--quick` | State + Next-action only (~150 tokens; ≤2s) |
| `--deep` | Default + memory cross-session highlights + risk drill-down |
| `--multi-repo` | Scan known sibling repo paths beyond cwd (capability-detected) |
| `--no-llm` | Skip narrative polish (deterministic-only) |
| `--format=md|json|console` | Output format (default md) |
| `--media=audio-voice` | **Opt-in** — ALSO speak the briefing aloud via `bin/speak.sh --play` + `skills/voice-director` (`--style executivo`). Default = text only; audio NEVER auto-plays (operator may be where sound is unwelcome). |

## Phase 0 — Capability detection (one-time)

Detect: platform (`uname -s`), `git` / `gh` / `jq` availability (`command -v`), whether inside a git repo (`git rev-parse --is-inside-work-tree`), network connectivity (HEAD to a known endpoint with short timeout), and host's memory-dir convention (host-dependent — Claude Code uses `~/.claude/projects/<encoded-cwd>/memory`; others differ).

Degrade gracefully: skip phases whose dependencies are missing; emit one-line diagnostic per skip.

### Memory location (host-dependent)

Derive memory dir from `git rev-parse --show-toplevel` + path-encoding (`/` → `-`) when the host uses an encoded-cwd convention. Fall back to `find <root> -maxdepth 2 -type d -name memory` filtered by repo basename if exact match fails. Other hosts: use `.cursor/memory/`, `aider.chat.history.md`, or the host's documented convention.

## Phase 1 — State probe (deterministic, parallel-safe)

Inventory in parallel where possible:

- Current branch (`git branch --show-current`)
- Recent commits (`git log --oneline -5` + since-24h subset)
- Working tree (`git status --short`)
- Worktrees (`git worktree list`)
- Open PRs (`gh pr list --state open --json number,title,author,createdAt,mergeable,reviewDecision`) — substitute platform-equivalent for GitLab / Bitbucket / etc.
- Per-worktree staged/uncommitted work

Optional task tool integration (host-specific): if the host has a TaskList equivalent, surface in_progress + blocked tasks.

## Phase 2 — Memory & cross-session context (skip if `--quick` or no memory-dir)

- Read MEMORY.md index (≤200 lines, fast)
- Surface recent feedback/project entries (last 3 by mtime)
- Filter for relevance: prefer entries tagged with current branch / repo / recent dates

## Phase 3 — Synthesis (7-section output)

Default output template (markdown):

```text
# 🌅 Morning Briefing — <repo or "multi-repo"> · <date> (<weekday>, <time> <tz>)

## 1. State (onde estamos)
- Branch: <branch> · Last commit: <sha> <time-ago>
- Worktrees: <count> (list paths if >1)
- Untracked/staged: <count> files

## 2. Done since last session
- Commits (last 24h): <n> (top 3 listed)
- PRs merged: <n> (links)
- Tasks completed: <n> (top 3)

## 3. In-flight
- Open PRs (author=user): <n> w/ status (mergeable/checks/reviewDecision)
- Staged commits awaiting push: <n>
- Tasks in_progress: <n>

## 4. Blockers / HITL
- Escalations awaiting user: list with brief context
- CI failures / security alerts: list
- Author-conflict PRs (need external reviewer): list

## 5. Decisions awaiting
- Open questions from prior session
- Option matrices (A/B/C/D) not yet resolved
- HITL-required action blocks unaddressed

## 6. Risks / heads-up
- Stale PRs (>7d open)
- Stale worktrees (>30d)
- Approaching deadlines (frontmatter `due:` if detected)
- Memory entries flagged 🔴 / 🚨

## 7. Recommended next action
**ONE highest-value next step** with: rationale (≤2 lines) + estimated effort + dependencies.

---

> Narrative (optional, skipped with --no-llm): 1-paragraph executive summary.
```

## Phase 4 — Narrative polish (optional, LLM-augmented)

When enabled (default unless `--no-llm`): single concise paragraph synthesizing the 7 sections into a readable summary. Skip if token budget tight.

## Output formats

- **md** (default): rendered above
- **json**: machine-readable for chaining (e.g., into auto-orchestrator Phase 1)
- **console**: terse stdout for terminal-direct use

## Anti-patterns / Gotchas

1. **Status theater** — listing every commit/PR creates noise. Filter to *changed-since-last-briefing* + *high-signal items*. Cap each section to top 5 by default.
2. **Vanity metrics** — "10 PRs in flight" without indicating what's blocked vs. moving is meaningless. Always include status (mergeable/checks/reviewDecision) per item.
3. **Decision-less reports** — a briefing without a *recommended next action* is just data. Section 7 is mandatory.
4. **Author=user self-approve trap** — when the user authored ALL open PRs, they cannot self-merge meaningfully via formal review. Flag in section 4 with "needs external reviewer".
5. **PII leak** — never hardcode named people in briefing output. Use role abstractions (`@team-handle`, `@oncall`) or paths. Briefing is potentially shared.
6. **Cross-context memory leak** — if a memory-dir has private feedback notes, do NOT echo verbatim — surface only titles/links.
7. **Stale-state hallucination** — if `gh` is offline, do NOT fabricate PR status. Emit explicit `[network-offline: PR section skipped]`.
8. **Recursion** — invoking morning-briefing inside another morning-briefing wastes tokens. Idempotency check: if last briefing produced ≤5min ago, ask before re-running.
9. **Over-extending to multi-repo unbidden** — only scan sibling repos with explicit `--multi-repo` flag (else briefing balloons).
10. **Briefing-on-fresh-clone** — newly cloned repos with no history produce hollow briefings. Detect and emit `"Cold-start: no prior session detected — proposing scoping questions instead."`
11. **Ambiguous memory-dir detection** — `find ~/.claude/projects | head -1` returns first match, not current-project. Always derive from `git rev-parse --show-toplevel` + path-encoding, with basename-filter fallback. Empirically discovered during early dogfood cycles.

## Edge cases

- **No git repo in cwd** → fallback: scan known sibling project roots OR ask scoping question
- **No `gh`** → skip PR section, emit diagnostic
- **No network** → local-state-only briefing
- **User on multiple parallel sessions** → snapshot-time-stamped to avoid stale data
- **Memory absent / corrupt** → graceful degradation, suggest running cycle-update
- **Briefing requested at non-morning hour** → name is canonical use case; description allows any-time invocation. No behavior change.
- **Multi-language user** → detect from CLAUDE.md / MEMORY.md; default fallback en-US with mixed-language tolerance

## Capability-detected fallbacks (by host)

When this skill runs in a non-Claude-Code host (Cursor / Copilot / Aider):

- TaskList tool absent → skip Phase 1 task surfacing
- Memory dir convention differs → check `.cursor/memory/`, `aider.chat.history.md`, etc.
- AAIF spec compliance ensures the trigger + body + frontmatter format work cross-vendor

## Promotion-readiness viability matrix (6/6)

| Criterion | Status | Evidence |
|---|---|---|
| Cross-platform | ✓ | universal `uname` / `command -v` / no OS-bundled paths |
| Cross-vendor | ✓ | AAIF spec; works in Claude / Cursor / Copilot / Aider via fallbacks |
| Non-personal | ✓ | universal sections; no user-specific names |
| Non-corporate | ✓ | zero proprietary refs; standards citations only |
| Generically useful | ✓ | any agentic-developer post-break workflow benefits |
| OSS license-compatible | ✓ | zero proprietary deps; MIT |

## Dogfood evidence (cumulative)

Cycle 1 (early): the deterministic core was validated to produce a 7-section briefing that successfully surfaced a signing-helper blocker, staged-file count in an active worktree, open PR list, and a single highest-value next-action recommendation. Memory-awareness + recommendation framing both validated.

Cycle 2 (subsequent): the slash-command invocation path surfaced an ambiguous memory-dir detection gotcha (single-line `find | head -1` returned wrong project when multiple matched basenames existed). Fix codified in Anti-pattern #11 above.

Both cycles demonstrated: deterministic core works, memory awareness works, recommendation framing works.

## Refs

- AAIF cross-vendor spec — `agentskills.io/specification`
- SitRep structural analogue — military situation-report templates
- Daily standup format — agile cadence
- Hot/warm/cold session-tiering — context-engineering patterns
- Session-end state file pattern — claude-progress.txt-like artifacts

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-05-17 | Community promotion from a user-scope skill of the same version. Sanitized: removed user-specific cycle-evidence narrative (replaced with generic cycle-N descriptions); replaced an org-specific team-handle example with a generic placeholder; trimmed inline code blocks to descriptive prose for Goldilocks ≤12KB community ceiling. License: MIT.
