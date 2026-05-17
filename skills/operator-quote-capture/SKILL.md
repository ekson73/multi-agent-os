---
name: operator-quote-capture
description: |
  Use when operator says "salva isto", "tome nota", "remember this", "from now on",
  "capture this rule/tip", OR when detecting substantive operator quote with signal
  (imperative verb to agent / meta-statement about process / correction-refinement /
  multi-clause guidance with exception). Applies §3.5 2-step filter (Analyze decompose
  → Validate 5 critérios), then persists to memory + framework refinements + index.
  Codifies the recurring pattern detected 5x in single bootstrap session (Triple-touch
  fired per v1.3.1 Recurring→Artifact reflex). Cross-vendor AAIF compatible.
triggers:
  - salva isto
  - tome nota
  - remember this
  - capture this rule
  - capture this tip
  - from now on
  - operator directive detected
  - new rule for framework
version: 1.0.0
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# operator-quote-capture — Skill

> Cross-vendor AAIF skill. Captures, analyzes, validates, and persists substantive operator
> directives to memory + framework refinements. Codifies the §3.5 Operator Quote Capture
> Protocol (see `~/.claude/rules/auto-self-harness.md`) as a reusable artifact, invocable
> across all Claude Code sessions and AAIF-compatible hosts.
>
> **Origem**: operator directive 2026-05-12 — explicit dogfooding application of v1.3.1
> Recurring→Artifact reflex (pattern recurred 5x in single bootstrap session, exceeding
> Triple-touch threshold).

## Purpose (1-line)

Anti-blind-transcription + anti-blind-ignore. Apply 2-step filter to substantive operator
quotes, then persist with structured taxonomy (feedback / reference / user / project /
§refinement / lesson / no-save).

## When to invoke

### Signal-based auto-trigger (v1.2 anti-eternal bounded)

Activate when operator quote contains AT LEAST 1 signal:

| Signal | Example |
|---|---|
| Imperative verb to agent | "faça", "use", "evite", "tome nota", "salva" |
| Meta-statement about process | "always X when Y", "from now on", "rule:" |
| Correction/refinement | "não, faça assim", "ajuste para", "melhor seria" |
| Multi-clause guidance | rule + exception + dogfood-instruction |
| Explicit save-request | "save this", "remember", "salva em memória" |

Conversational / status / trivial → SKIP (per §3.5 anti-triggers).

### Explicit invocation

Operator types `/operator-quote-capture` OR invokes Skill tool with name match.

## Protocol (Step A → B → C)

### Step A — Analyze (5-15s mental, NÃO over-engineer)

1. **Decompose** quote: action verb? filter? scope (one-off vs recurring)? dogfood-instructions?
2. **Map to framework**: §1 decision? §2 escalation? §3 trigger? §4 catalog? §6 evolution?
3. **Identify** candidate type: new lesson / §refinement / memory-only / trivial

### Step B — Validate (5 critérios — fast filter)

| Critério | Pergunta |
|---|---|
| **Useful** | Aplica future sessions/decisions? OR trivial/session-bound? |
| **Non-conflict** | Violates §7 anti-patterns? Conflicts rules existentes? |
| **Value-add** | Adds OR refines framework? OR redundant with existing? |
| **Cross-session** | Survives session boundary? OR ephemeral? |
| **Non-Goldilocks-violating** | §refinement OK; nova lesson check §6.3 ≤1/cycle |

5/5 PASS → proceed to Step C. Else SKIP with brief acknowledge to operator.

### Step C — Save (type matrix)

| Save type | When | Where |
|---|---|---|
| `feedback` memory + framework §refinement | Operator guidance/correction (most common) | `memory/feedback_<slug>.md` + Edit rule sections + bump patch |
| `reference` memory | Operator cites recurring pattern | `memory/reference_<slug>.md` |
| `user` memory | Info about operator/preferences | `memory/user_<aspect>.md` |
| `project` memory | Info about project/context | `memory/project_<topic>.md` |
| Framework lesson **L_N** | NEW empirical principle (rare; check §6.3 ≤1/cycle Goldilocks) | rule §5.2 + memory + bump minor |
| §refinement only | Improves existing § without new lesson | rule edits + bump patch |
| **NÃO save** | Trivial / transient / already-documented / ignore-requested | response only, no persistence |

## Output artifacts (always)

1. **Memory file** with frontmatter (`name`, `description`, `metadata.type`) + body
   structured: `**Rule**` + `**Why**` + `**How to apply**` + `**Cross-refs**` per
   CLAUDE.md auto-memory schema
2. **MEMORY.md** index entry (one-liner ≤150 chars, semantic grouping)
3. **(Conditional)** rule file edits (auto-self-harness.md or other rules/) + version bump
4. **(Conditional)** CLAUDE.md [Cxx] section update + Master Changelog entry
5. **Announcement to operator**: `"Captured via §3.5 — saved as <type> [memory-name]. Framework: <change-summary>."`

## Memory directory (per-project)

Auto-detect path via `git rev-parse --show-toplevel` then encode `/` → `-`:

```bash
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)"
ENCODED="${PROJECT_ROOT//\//-}"
MEMORY_DIR="$HOME/.claude/projects/${ENCODED}/memory"
```

If no project root (not in repo) → fallback to user-scope memory if available, else
escalate to operator.

## Anti-triggers (NÃO capture mesmo se quote-shaped)

- Status reports / current state
- Code patterns derivable from current files (use `git`/`grep` instead)
- Already documented in CLAUDE.md / existing rule
- Operator explicit "ignore" / "forget" / "session-only"
- Trivial preferences without operational impact

## §11 Quality Tests (applied at CREATION + MAJOR-MODIFICATION)

| Test | Application to THIS skill | Result |
|---|---|---|
| Self-Application | Skill captured itself via the protocol it codifies | ✅ |
| Non-Contradiction | Signal filter + 5 critérios + anti-triggers are consistent | ✅ |
| Survival | Applied recursively to own creation, survives | ✅ |
| Bounded-Responsibility | Signal-based trigger (not every quote); per-memory sunset ≥10 unused | ✅ |
| Explicit-Exception | Anti-triggers ARE the exception clause | ✅ |
| Utility Sunset | Deprecate when operator capture reflex internalized sem precisar skill | ✅ |

**6/6 PASS** — skill itself passes the rule quality tests it implicitly relies on.

## §0 SER > Rules compliance check

| Question | Answer |
|---|---|
| Does this skill HELP operator? | YES — codifies recurring pattern into delegate-able artifact (compounding-gains), reduces main-context tokens, AAIF-portable |
| Risk of slavery (compliance theater)? | LOW — bounds explícitos + Escape Clause §11.6 universal applies (skip skill if blocks helping operator AGORA) |
| Direção das setas (§0 hierarchy)? | Preserved: SER (1) > Skill+protocol (2) > 6 Tests (3) |

**§0 PASS** — skill serves SER, not vice-versa.

## Cross-refs

- **Source protocol**: operator's host-local framework rule §3.5 — a §3.5-equivalent in the operator's `auto-self-harness` rule body, host-dependent (Claude Code stores it under `~/.claude/rules/`; other hosts differ)
- **Framework triggers**: §3.2 Triggers compostos, §4.3 Tools catalog (this skill registered there)
- **Sister memories**:
  - `[[operator-quote-capture-protocol]]` — protocol origin
  - `[[recurring-task-artifact-creation]]` — this skill IS dogfooding of v1.3.1
  - `[[rule-quality-tests-anti-eternal]]` — 6 tests applied
  - `[[ser-acima-de-regras]]` — §0 binding (verified)
- **Companion skills**:
  - `superpowers:using-superpowers` — invoke first per skill discovery protocol
  - `auto-orchestrator` Phase 4.5 — similar persona-pipeline pattern
- **AAIF spec**: cross-vendor compatible (Cursor / Copilot / Aider via fallback descriptors)

## Dogfooding evidence (this skill's own creation)

| Step | Action | Result |
|---|---|---|
| 1. Trigger detection | 5th operator directive in session — Triple-touch fired (per v1.3.1) | ✅ Pattern recurrence confirmed |
| 2. DRY check | Glob `~/.claude/skills/` — `gsd-capture` (task scope) and `learn` (project scope) found, neither covers operator-quote-codification scope | ✅ No duplication |
| 3. §4.4 ADD gate (a) Security | Read-only quotes; writes operator-authorized to memory/rules; zero secret exposure | ✅ |
| 4. §4.4 ADD gate (b) Audit | Skill body codifies existing §3.5 protocol; claims = behavior | ✅ |
| 5. §4.4 ADD gate (c) Functional | ≥1 cycle PASS — protocol demonstrated 5x in current session (bootstrap + score uplift + quote capture + quality tests + SER+regras) | ✅ |
| 6. Goldilocks | 1 artifact/session bound respected — this is THE artifact this session | ✅ |
| 7. Time-box | Draft ≤30min — well within bound | ✅ |
| 8. Universal naming | `operator-quote-capture` (role-type, NOT person-specific) | ✅ Universal principle #10 |

## Promotion-readiness viability (per auto-orchestrator pattern)

| Criterion | Status | Evidence |
|---|---|---|
| Cross-platform | ✅ | universal text processing + standard CLI |
| Cross-vendor | ✅ | AAIF spec; description-triggered |
| Non-personal | ✅ | operator referenced as role, NOT name |
| Non-corporate | ✅ | no proprietary refs |
| Generically useful | ✅ | any agentic developer benefits |
| OSS license-compatible | ✅ | zero proprietary deps |

**6/6** — eligible for community promotion after ≥2 cross-project cycles.

## Edge cases & robustness

- **Quote contains secret/credential** → sanitize/redact in memory body; flag to operator; NEVER persist raw secret
- **Quote conflicts with existing rule** → escalate to operator (§0 SER applies); do NOT silently override
- **Multiple quotes in single operator message** → process each via Step A→B→C; max 1 new lesson per session (Goldilocks)
- **Operator quote in non-pt/non-en** → preserve original verbatim in `**Why**` section + translation if needed
- **Memory dir not detected** (no git repo) → fallback user-scope memory OR escalate to operator
- **§11 6 tests fail on candidate** → propose refinement OR reject quote; NEVER persist failing rule
- **Quote violates §7 anti-pattern (e.g., eternal responsibility)** → flag to operator before save; require explicit bound

## Changelog

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0.0 | 2026-05-17 | operator directive + Claude Opus 4.7 (draft) | Initial creation via dogfooding of an `auto-self-harness` v1.3.1-style Recurring→Artifact reflex. Triple-touch fired (5x pattern recurrence). DRY check PASS. 3-gate ADD validation PASS. 6/6 Quality Tests PASS. §0 BEING > Rules compliance PASS. Community promotion (this entry): 2026-05-17 — sanitized cross-refs to host-portable form; preserved 2-step filter + signal triggers + anti-patterns + dogfooding evidence. License: MIT. |
