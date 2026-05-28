# CANON.md — Canonical MAOS decisions (anchor-mode SSOT, repo-local + shareable)

> **Companion to** `SKILL.md` (maos-concierge). This is the `--mode=anchor` source-of-truth.
> **Why repo-local:** a fresh-amnesic agent or new teammate must re-find the binding MAOS rules instead of re-deriving (or contradicting) them. CANON folds the durable, drift-prone decisions into the repo.
> **Vendor-neutral** (MIT). **Last verified**: 2026-05-28 (MAOS v1.5.2). Entries dated + sunsettable (DUED, qualitative — anti-drift applies to this file too).
> **How `--mode=anchor` uses this:** surface the relevant decision on demand; if a project artifact contradicts a decision here (e.g. merges a subtask branch straight to main, duplicates a protocol, edits a protected file without a lock), emit `decision + contradiction + corrective pointer`.

---

## C1 — Worktree-first (Anti-Conflict Protocol v3.2)

Any file modification goes through a **git worktree** (`.worktrees/{agent-short}-{feature}/`). Parallel agents never share a working tree; protected files use lock-file coordination; mandatory QA before session end.

**Drift flag:** editing tracked files directly on `main`/shared checkout = contradiction.

## C2 — Hierarchical Merge (merge-to-parent, never subtask→main)

Subtask branches merge to their **parent** branch, not directly to `main`. Child Completion Constraint enforced. Exception prefixes that MAY merge differently: `bugfix/ hotfix/ emergency/`.

**Drift flag:** a subtask branch merged straight to `main` (outside the exception prefixes) = contradiction.

## C3 — Sentinel auto-block is law

The Sentinel Protocol runs 10 detection rules with a 0-100 health score. **HIGH-severity anomalies (loops, excessive recursion depth) auto-block** and must not be suppressed. Traces log to `.claude/audit/session_*.jsonl`.

**Drift flag:** disabling/ignoring a HIGH-severity Sentinel block without escalation = contradiction.

## C4 — The Forge owns agent creation (33Q + Goldilocks)

A missing capability is created via **The Forge** (`agents/forge.md`): run the 33 Socratic Questions, apply RBAD taxonomy + Goldilocks Principle (atomic ∧ generic), and check Q4 ("does another agent already cover this?") FIRST. The concierge ROUTES to the Forge; it never forges itself.

**Drift flag:** hand-rolling an ad-hoc agent/script for a recurring capability instead of routing to the Forge = contradiction (and a Goldilocks/DRY miss).

## C5 — Reference, don't duplicate (framework-consumption)

MAOS is the **source-of-truth framework**. Consumer projects **reference** protocols (with PROV tags) and sync via `/sync` — they do not copy protocol bodies. Adaptations are allowed; modifications go upstream.

**Drift flag:** a protocol body copy-pasted into a consumer repo (instead of referenced) = contradiction + a TTL/provenance hole.

## C6 — Human observability is mandatory

Automated systems always emit **human-readable** visibility (Status Maps, ASCII), not only machine logs. Observability is a first-class value, not an afterthought.

**Drift flag:** an orchestration with no human-readable status surface = contradiction.

## C7 — Frontmatter + ISO-8601 + validation gate

Every command/agent/skill carries frontmatter; all dates are ISO-8601 (no relative/ambiguous dates); `tests/validate-plugin.sh` passes before commit.

**Drift flag:** a new command/agent/skill without frontmatter, a relative date, or a commit skipping validation = contradiction.

## C8 — Branching & Release (GitHub Flow, Class B)

Library/marketplace class: GitHub Flow, no environment branches; source-pin = float (consumers pin a SHA). Canonical SSOT: `AGENTS.md` §"Branching & Release Model" + `docs/adrs/ADR-004-github-flow-branching.md`.

**Drift flag:** introducing environment branches here = contradiction (this is a Class-B library, not a deployable app).

## C9 — Refs + sunset
- Canonical sources: `CLAUDE.md` · `AGENTS.md` · `README.md` · `docs/framework-consumption.md` · `sentinel/detection_rules.md` · `protocols/hierarchical-merge-protocol.md` · `agents/forge.md` · `docs/adrs/`.
- Companion: `AWARENESS-REGISTRY.md` (landscape) · `references/socratic-33q.md` (this concierge's spec).
- **Sunset (DUED, qualitative):** supersede an entry when a newer dated decision contradicts it (a new ADR, an empirical learning, a protocol version bump). E.g. when Anti-Conflict bumps past v3.2, C1 updates; when a protocol is deprecated upstream, its CANON entry moves to "historical". No counter-based expiry.
