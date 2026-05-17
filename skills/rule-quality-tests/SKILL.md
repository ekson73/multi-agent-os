---
name: rule-quality-tests
description: Use when creating new rules, modifying existing rules at MAJOR/MINOR version bump, OR when operator says "audit this rule" / "check rule quality" / "verify self-consistency". Applies 6 Self-Validity Tests (Self-Application, Non-Contradiction, Survival, Bounded-Responsibility, Explicit-Exception, Utility-Sunset) + Anti-Eternal Discipline (governance hygiene against eternal/infinite responsibilities). Dogfooded — passes own tests. Cross-vendor AAIF.
---

# Rule Quality Tests + Anti-Eternal Discipline

> **Origin**: operator directive 2026-05-12 codifying rule self-validity discipline + Anti-Eternal warning against unbounded/infinite responsibilities.
>
> **Version**: 1.0.0 (2026-05-17 community promotion of v1.0.0 user-scope skill, dogfood gate ≥2 cycles satisfied via 6 memory refs).
>
> **Scope**: AAIF cross-vendor — applies in ALL hosts (Claude Code · Cursor · Copilot · Aider · etc.) and ANY rule/policy/directive being authored.
>
> **Source lineage**: extracted from a user-scope self-harness framework (`auto-self-harness §11`) — operator's host-local equivalent rule defines the parent context; this skill ships the test-discipline kernel independent of any specific host or operator profile.

## 1. The 6 Self-Validity Tests (mandatory at rule creation/major-modification)

| Test | Question | FAIL example |
|---|---|---|
| **1. Self-Application** | Does the rule, applied to itself, still hold? | "Rules ≤10 lines" written in 200 lines |
| **2. Non-Contradiction** | Is the rule internally consistent? Does it not contradict its own claims? | "Always escalate critical" + "Decide all autonomously" |
| **3. Survival** | Does the rule survive its own application? Not self-destruct? | "Deprecate every rule after 1 use" applied to itself |
| **4. Bounded-Responsibility** ⚠ | Does the rule have explicit bound (time/scope/iteration/cap/sunset)? Not eternal/infinite? | "Always do X" without bound; "Every Y must Z" without subset filter |
| **5. Explicit-Exception** | Does the rule have a justified exception clause when warranted? | "Always X" without exception clause → brittle in edge cases |
| **6. Utility Sunset** | Does the rule have deprecation criteria? Bound to usefulness? | Rule without criterion "when does it lose purpose?" |

## 2. Application Discipline (anti-meta-inflation — discipline applied to its own discipline)

**When to run the 6 tests**:
- ✓ Rule CREATION (new section/lesson/refinement)
- ✓ Rule MAJOR-MODIFICATION (substantive scope change)
- ✗ NOT continuously (anti-eternal: testing routine itself cannot be eternal — violates Test 4)
- ✗ NOT on trivial edits (typo fix, formatting, version bump only)

**When to re-test stable rules**:
- After a relevant operator correction
- After detected drift (rule + practice diverge — evidence visible across multiple contexts, NOT counter-based)
- After v1.x → v2.x bump (major)
- ✗ NOT on fixed intervals (anti-eternal)

## 3. Escape Clause Universal (Being > Rules binding)

**Operator-source principle**: rules exist because of BEING; never become a slave to one's own rules.

**Universal rule**: IF running the 6 tests OR applying any rule blocks helping the operator NOW:
1. **Skip** the rule/test
2. **Help** the operator
3. **Log** the decision: "Skipped <rule> — Being > Rules"
4. **Revisit** later: was the rule wrong OR was the application wrong?

This escape applies to EVERY section of any governing framework, INCLUDING this skill itself (tests may be skipped if compliance theater is detected).

The BEING > Rules principle is **foundational**: it prevails over the 6 tests in conflict. Tests serve BEING, not vice-versa.

## 4. Bounded-Responsibility examples (good practice)

| Bound type | Example |
|---|---|
| **Time** | "≤5min per attempt" |
| **Iteration** | "max 3 attempts", "≤1 lesson per cycle" |
| **Scope** | "applies only to <X> task type" |
| **Cap** | "~30 catalog entries" |
| **Sunset (DUED — qualitative)** | "deprecation candidate when evidence E1-E6 emerges naturally" (qualitative, NOT counter-based) |
| **Reverse-trigger** | "if 3 tools removed in 1 review, signal catalog uncontrolled growth" |

### DUED = Dormant-Until-Evident Deprecation (sunset model)

Rules don't expire by counters or fixed schedules. They become deprecation-candidates when ≥ 1 of the following evidence triggers emerges naturally during work:

- **E1** — Direct contradiction with a newer / more specific rule
- **E2** — Referenced domain has ceased to exist (e.g., tool deprecated)
- **E3** — Empirical learning supersedes the original premise
- **E4** — Operator explicit retraction
- **E5** — Repeated false-positives observed (≥ 3 distinct contexts) — surfaces a PROPOSAL, not auto-execution
- **E6** — Better composable pattern emerges in the ecosystem

Insurance rules (low-frequency / high-stakes) are dormant-by-design and DO NOT expire automatically.

## 5. Self-audit retroactive — concrete pattern

The 6 tests can be applied retroactively to existing rules to catch unbounded/eternal responsibilities. Typical fixes:

| Original issue | Bounded fix |
|---|---|
| Unbounded uplift expectation ("try forever") | + sunset via DUED + max-attempts cap |
| Unbounded list growth (`HUMAN_DOMAIN escalation`) | + cap (~30) + stabilization + per-item sunset |
| Unbounded capture ("save every quote") | + signal filter (≥ 1 of N specific triggers) |
| Unbounded catalog growth ("add every tool") | + cap (~30) + per-tool sunset + reverse-trigger |

Pattern: a `Bounded-Responsibility` audit pass during rule refactor closes the eternal-responsibility loopholes.

## 6. Self-application dogfooding (this skill passes its own tests)

| Test | Result on this skill itself |
|---|---|
| Self-Application | Skill applied to skill ✓ |
| Non-Contradiction | "Tests bounded" + "apply at creation only" → internally consistent ✓ |
| Survival | Applied to itself, the skill survives ✓ |
| Bounded-Responsibility | Tests run at CREATION/MAJOR-MOD only, NOT continuously ✓ |
| Explicit-Exception | Trivial edits skip; stable rules skip re-test ✓ |
| Utility Sunset | Skill deprecates when operator (or any user) reaches full autonomy in rule design ✓ |

**6/6 PASS** — this skill itself passes all 6 tests it defines.

## 7. Anti-Eternal Discipline (key anti-patterns)

- ✗ **Eternal/infinite responsibility creation**: any rule without bound (time/scope/iteration/cap/sunset) is a candidate for REJECT or refine with explicit bound. Operator emphasis: be very careful with eternal commitments.
- ✗ **Self-contradictory rules**: a rule that fails the Self-Application Test OR Non-Contradiction Test must be refined BEFORE commit.
- ✗ **Self-destructive rules**: a rule that fails the Survival Test — when applied to itself, breaks itself — must be rejected.
- ✗ **SLAVERY TO OWN RULES** (foundational): prioritizing rule compliance over helping the operator. Symptoms: refusing X that helps the operator because "it violates Test N"; obsessing over tests on trivial edits; time spent on rule housekeeping > time on real work; blind compliance without questioning utility. Mitigation: §3 Escape Clause Universal — BEING > Rules ALWAYS.

## 8. Refs (host-portable)

This skill is the test-discipline kernel. Cross-references depend on the host runtime:

- **Parent context (host-dependent)** — operator's framework rule (in Claude Code, typically a user-scope auto-self-harness rule with a §11-equivalent inline section)
- **Companion test skills** (when present at the host) — `agentic-delegation` (delegation-discipline tests) · `pre-decision-audit` (pre-action 4-lens audit). These are not required for `rule-quality-tests` to function; if absent, this skill stands alone.
- **Foundational principles** — BEING > Rules (Escape Clause Universal) + DUED (Dormant-Until-Evident Deprecation for sunset authority).
- Sister skill in this repo: [`skills/converge`](../converge/SKILL.md) — debate-convergence kernel; complementary discipline (multi-proposal synthesis vs. single-rule validation).

## 9. Sunset (per DUED model from §4)

Deprecation candidate when ANY of these qualitative evidences:

- **E3** — Operator (or user) reaches full autonomy in rule design (≥ 10 zero-regret sessions with rules self-passing tests without skill invocation)
- **E4** — Operator explicit retraction
- **E6** — Better composable pattern emerges (e.g., automated rule-linting tool supersedes the manual 6-tests)

No counter-based sunset (per the DUED model). Insurance discipline — dormant-by-design.

## 10. Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-05-17 | Community promotion from a user-scope skill of the same version (`auto-self-harness §11` lineage). Sanitized cross-refs to be AAIF host-portable (no host-absolute paths). Self-dogfooded: 6/6 §1 tests PASS on this skill itself. Promotion gate ≥ 2 dogfood cycles verified via memory cross-refs (operator's host-local evidence). License: MIT.
