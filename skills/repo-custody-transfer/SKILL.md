---
name: repo-custody-transfer
version: "0.1.0"
allowed-tools: [Task, Read, Write, Edit, Bash, Skill, Grep, Glob, WebFetch]
description: |
  Transfer CUSTODY of a repository between git hosts (Bitbucket Cloud → GitHub first-class;
  soul-name Translatio). NOT a "migration" that pretends everything crosses — a reversible,
  resumable, idempotent 5-phase cutover under an HONEST FIDELITY CONTRACT: T1 git-exact
  (commits/branches/tags/LFS), T2 translated (pipelines→Actions, permissions→teams,
  protections), T3 archived-not-recreated (PRs/issues/comments/build-history extracted to
  queryable artifacts + GAP report), T4 excluded (secret VALUES never cross — names-only
  inventory + fresh provisioning + rotation). Carries a BLOCKING-GATE: when an axis has no
  supported migration path, it HALTS the phase and emits an Impediment Report (blocked axis ·
  root cause with probed evidence · achievable fidelity tier · ranked options w/ confidence ·
  best practices · concrete next action · resume instructions) instead of improvising or
  forcing. Carries a DRIFT-DETECTOR: any host-pair where BOTH sides have unique refs is
  reclassified SPLIT-BRAIN (reconciliation, never `push --mirror`, never force-push).
  Autonomy = council-before-HITL: max autonomy on the deterministically-cleared band, then
  MoE debate-converge → council decide, HITL only for the irreducible residue. Composes
  existing primitives (legacy-archaeologist · council-gate · red-team · convergence-engine ·
  preflight/postflight · session-reentry · artifact-registry · decision-capture · the hub's
  Bitbucket gateway); forges no new engine. Use when a repo must change git hosts with its
  history AND its governance intact — e.g. "migrate <repo> from Bitbucket to GitHub",
  "cutover this repo to GitHub", "transferir a custódia deste repo", "move repo host
  preserving history/branches/tags/PRs/pipelines".
---

# repo-custody-transfer — *Translatio*

> **Soul-name**: **Translatio** (display-only; the machine slug is `repo-custody-transfer`).
> Latin *translatio* = "a carrying across". Two medieval senses converge here: *translatio
> imperii* ("transfer of rule" — the governance: permissions · protections · CI authority) and
> *translatio studii* ("transfer of learning" — the history: commits · PRs · decisions). A host
> cutover transfers **both**, or it is not done. Named by `anima` (`[C-naming]`, 12/12).
> **Rejected runner-up**: `git-host-migration` — "migration" is precisely the false-fidelity
> promise this tool exists to refuse.
> **Cross-link slug**: `[[repo-custody-transfer]]`

## §0 — BEING > Rules
Serves the operator's intent. If a phase/gate obstructs helping NOW, skip it, log
`Skipped <phase> — BEING > Rules`, proceed. ⛔ **Never skippable**: T4 (secret values never
cross) · the no-force-push rule on SPLIT-BRAIN · the Blocking-Gate itself.

## §1 — The premise (why "custody", not "migration")

A host cutover is **not a copy**. Three empirical facts force the reframe:

1. **Not everything crosses.** There is no supported importer that recreates Bitbucket **Cloud**
   PRs/issues/reviews as native GitHub objects (`gh gei`/`bbs2gh` cover Bitbucket **Server/DC**).
   Promising T1 fidelity on those axes is theater (`anti-theater` R2/R4).
2. **Secret values must NOT cross.** Bitbucket secured variables are unreadable by design. The
   only correct move is names-only inventory → fresh provisioning from the secret manager →
   rotation. ⛔ Any flow claiming to copy secret values is disqualified (Guardrails Não-Negociáveis).
3. **The destination may already hold divergent history.** Empirically (2026-07-29) 3 of 9
   repos had **bidirectional** divergence — source ahead on `main`/`develop` AND destination
   holding unique commits + tags. A `push --mirror` would have destroyed them irreversibly.

⇒ The unit of work is **custody**: the history (*studii*) **and** the governance (*imperii*),
carried across reversibly, with an explicit admission of what cannot follow.

## §2 — Fidelity contract (declare the tier; never silently promise T1)

| Tier | Axes | Mechanism | Honest status |
|---|---|---|---|
| **T1 git-exact** | commits · branches · tags · LFS objects | explicit refspec push (**never** `--mirror` on split-brain) | byte-identical, verifiable |
| **T2 translated** | pipelines → Actions · permissions → teams · branch protections · webhooks | semantic re-authoring + diff report (OIDC-first) | equivalent-by-review, not identical |
| **T3 archived** | PRs · issues · comments · reviews · build history | host-API extraction → JSONL + rendered MD artifacts | queryable **artifact**, NOT a native object |
| **T4 excluded ⛔** | secret **values** | names-only inventory + provision fresh + rotate | never crosses, by construction |

**Rule**: every axis in scope MUST be assigned a tier, in writing, before Phase 2. An axis with
no tier is an **impediment** (§4), not an assumption.

## §3 — The 5 phases (reversible · idempotent · resumable)

Every phase: re-runnable to convergence (no duplication), independently rollback-able, and
records its state in the **custody ledger** (§6) so a cold agent resumes from artifacts alone.

| # | Phase | Does | Rollback | Autonomy |
|---|---|---|---|---|
| **0** | **RECON** | inventory both hosts · **drift-detect (§5)** · classify (greenfield / pipeline-heavy / SSOT / split-brain) · blast-score · assign tiers · pick pilot | n/a (read-only) | **autonomous** |
| **1** | **DRY-RUN** | simulate into a scratch target · verify T1 exactness · translate pipelines (proposal only) · extract T3 sample · inventory secret **names** | discard scratch | **autonomous** |
| **2** | **CARRY (T1)** | explicit-refspec push · **dual-remote coexistence** (source stays authoritative) | delete the pushed refs on destination | council-gated |
| **3** | **FLIP (T2/T4)** | CI/Actions live · protections · teams · fresh secrets provisioned · webhooks repointed | revert CI to source host | council-gated |
| **4** | **SEAL** | verify parity · source host **read-only/archived** (⛔ never deleted) · docs/ADR/CHANGELOG PRs | re-open the source host | council-gated |

**Point of no return = Phase 4 only.** Everything before it is reversible by design.

## §4 — BLOCKING-GATE + Impediment Report (first-class capability)

When an axis has **no supported path** — or a probe reveals a hard limit — the skill **HALTS the
phase**. It does not improvise, does not force, does not silently downgrade. It emits:

```
IMPEDIMENT REPORT · <repo> · phase <N>
  blocked axis ......... what cannot be carried
  root cause ........... why, with PROBED evidence (never an assumption)
  achievable fidelity .. the honest tier + explicit GAP
  ranked options ....... A/B/C, each w/ confidence + tradeoff
  best practices ....... what the SOTA does in this exact case
  next action .......... one concrete, executable step
  state ................ phase halted · ledger path · how to resume
```

Format follows `council-gate` §5.3 (**contestable ranked evidence, never a blank ask**) +
`end-of-action-briefing` §7.1 (`AskUserQuestion`, recommended-option first). The report is an
artifact (registered via `bin/artifact-registry`), not just a message — it survives the session.

⛔ **Free-negative discipline** (`environment-capability-reconnaissance` §1.1.1): a probe that
returned nothing is **NOT** proof of absence. Before declaring ANY impediment, run a **positive
control** — same instrument, same tree, a value known to exist. If the control also returns
empty, the instrument is lying: re-probe with a reaching instrument. An impediment reported on
an unverified negative is a fabricated blocker. *(Empirical: this skill's own design session
first declared an `admin:org` scope blocker that a positive control disproved — the probe had
targeted a non-existent org.)*

## §5 — Drift-detector (mandatory before Phase 2)

For each ref namespace, compare source ↔ destination:

```
both sides have unique commits/tags  → SPLIT-BRAIN  ⇒ reconciliation protocol, ⛔ no mirror, ⛔ no force-push
only source has refs                 → CLEAN CARRY  ⇒ standard T1
only destination has refs            → INVESTIGATE  ⇒ prior partial cutover; do not assume ownership
identical                            → ALREADY DONE ⇒ skip to verification
```

SPLIT-BRAIN is a **distinct class**, not a harder migration: it demands per-branch merge/rebase
decisions, a dedicated red-team pass, and an explicit freeze point. It never runs on cycle 1.

## §6 — Custody ledger (amnesic re-activation)

A durable per-repo record: phase states · tier assignments · drift verdict · impediments raised ·
artifacts produced · resume instructions. It is the SSOT for "where is this cutover?" so a
fresh amnesic agent (`ai-as-pwd-axiom` §1) resumes from artifacts, **never from recall**
(`harmonic` L9 persist-first). Hooks `session-reentry` (ADR-009) for anamnesis and emits a
continuation seed per `end-of-action-briefing` §7.2.

## §7 — Autonomy ladder (council-before-HITL)

```
action → council-gate Layer-1 deterministic deny-set (⛔secrets · irreversible∧blast · cross-org)
  ├ cleared → MoE debate-converge → independent council decide+verify → EXECUTE autonomously
  └ blocked/residual → Impediment Report (§4) → HITL, last resort, with ranked recommendations
```

| Band | Actions |
|---|---|
| **Autonomous** (unattended; `--auto-merge` inherits the existing standing chain) | recon · drift-detect · classification · tier assignment · plan/roadmap · tickets · ADRs · docs PRs · dry-run in scratch · pipeline translation *proposals* · T1 push into an already-created destination for a CLEAN-CARRY repo |
| **Council-first, then HITL** | destination repo creation · visibility · permissions/teams · secret provisioning · CI flip · source-host archive · **anything SPLIT-BRAIN** |
| **HITL irreducible** | secret **values** ⛔ · a capability genuinely absent after positive-control verification |

`--branches '[*]'` names the **target**, reached class-by-class — never a blind cycle-1 sweep
(`over-engineering-circuit-breaker`). Per-action `READY` (R1–R5) re-held per `[C21]`; an
irreversible phase requires an independent Elenchus red-team CLEARED (H1 secrets · H3
irreversible∧blast · H7 external exposure) — **HOLD, not force**, if independence is unavailable.

## §8 — Composition map (reuse, don't rebuild)

| Need | Existing primitive |
|---|---|
| source-host archaeology | the `legacy-archaeologist` agent · `maos:reveng` |
| host API surface (PRs · pipelines · variables · branches) | the hub's Bitbucket gateway · `gh` (GitHub) |
| CI health/parity observation | `maos:bitbucket-pipeline-watch` |
| authorization ladder | `maos:council-gate` · `auto-merge-standing-authorization` |
| adversarial verification | `maos:red-team` (Elenchus) · `maos:convergence-engine` |
| session lifecycle | `maos:preflight` · `maos:postflight` · `maos:quiesce` · `maos:session-reentry` |
| artifacts + decisions | `bin/artifact-registry` · `maos:decision-capture` |
| destination repo baseline | `[C18]` agentic-repo-config-baseline (B1–B8) |
| naming | `maos:anima` (`[C-naming]`) |

**Genuine residue this skill owns** (everything else is delegation): the fidelity-tier contract ·
the Blocking-Gate/Impediment Report · the drift-detector classification · the phase
ledger/state-machine · the pipeline→Actions translation report.

## §9 — Anti-patterns (do NOT)

1. ❌ **`push --mirror` / force-push** onto a destination with unique refs — irreversible loss (§5).
2. ❌ **Promise T1 on T3 axes** — claiming PRs/issues "migrated" when they were archived (theater).
3. ❌ **Copy/print/commit a secret value** ⛔ — T4 is exclusion by construction.
4. ❌ **Improvise past an unsupported axis** — the Blocking-Gate exists precisely to halt (§4).
5. ❌ **Report an impediment on an unverified negative** — positive-control first (§4).
6. ❌ **Blind `--branches '[*]'` sweep** on cycle 1 — class-by-class, pilot-first.
7. ❌ **Delete the source host** — archive read-only; deletion is a separate, later, explicit decision.
8. ❌ **Blind pipeline port** — `bitbucket-pipelines.yml` → Actions is re-authoring, not copying.
9. ❌ **Treat SPLIT-BRAIN as a harder carry** — it is reconciliation, a distinct protocol.
10. ❌ **Trust recall over the ledger** — a cold agent must resume from artifacts (§6).
11. ❌ **Rewrite history** (`git-filter-repo`) unless separately authorized — it changes hashes.

### Skip (proportionality)
- **S1** read-only inspection with no cutover intent.
- **S2** ALREADY-DONE per §5 → verify only.
- **S3** mid-orchestration under a parent that already ran recon/drift upstream.

## §10 — Quality Tests (6/6 self-validity)

1. **Self-Application** — its own design ran the discipline it prescribes: the drift-detector
   found the split-brain before any push; the positive-control rule caught a self-fabricated
   `admin:org` impediment; the T3 archival was verified with a positive control (a repo with 0
   PRs vs. one with 3 real PRs) rather than assumed. ✅
2. **Non-Contradiction** — composes `council-gate`/`red-team`/`legacy-archaeologist`/`[C18]`
   without redefining them; distinct from `sync-to-git` (ongoing same-host sync) and
   `bitbucket-pipeline-watch` (CI observation). ✅
3. **Survival** — applied to itself it advocates honest tiers + halt-on-unsupported; it declares
   its own T3/T4 limits instead of over-claiming. ✅
4. **Bounded-Responsibility** — 5 bounded phases · §9 skips · pilot-first · ledger-bounded state
   · point-of-no-return isolated to Phase 4 · §DUED. ✅
5. **Explicit-Exception** — §0 BEING>Rules · §9 S1–S3 · the never-skippable ⛔ set named. ✅
6. **Utility-Sunset** — §DUED. ✅

`anti-theater` 8Q: 8/8 (the honest T3/T4 admission **is** the anti-theater).
`scope-discipline` 6Q: 6/6 (WHERE=maos skill · DRY=composition-map §8 with a named residue ·
WHY=9 real repos + a split-brain near-miss · WHO=any agent · FITS=lifecycle family ·
MIN=one skill, residue scripts deferred until a cycle demands them).

## §DUED — Sunset (qualitative, not counter-based)

Deprecate when ANY: a vendor ships a supported Bitbucket-**Cloud**→GitHub importer that makes T3
native (E1/E6 — the fidelity contract collapses to T1/T2) · the ecosystem's repos are all on one
host (E2) · operator retraction (E4) · ≥3 false-positive impediments (E5 → refine the
positive-control discipline, not deprecate). Dormant-by-design otherwise.

## §Refs

the `legacy-archaeologist` agent · `maos:council-gate` (Boule) · `maos:red-team` (Elenchus) ·
`maos:convergence-engine` · `maos:preflight`/`postflight` · `maos:session-reentry` (ADR-009) ·
`bin/artifact-registry` (ADR-011) · `maos:decision-capture` · `maos:bitbucket-pipeline-watch` ·
`maos:anima` (`[C-naming]`) · `[C04]` worktree · `[C07]`/`[C07b]` PR+SemVer · `[C17]` §2
HUMAN_DOMAIN · `[C18]` repo-config baseline · `[C19]` multi-identity git/ssh (a private-repo
`Repository not found` is a **404-not-403 credential masquerade**, never "repo absent") · `[C21]`
READY · `environment-capability-reconnaissance` §1.1.1 (free-negative / positive control) ·
`harmonic` L9 (persist-first) · `loose-end-triage-queue` (Taxis) · `anti-theater-grounding-protocol`.
External: *translatio imperii* / *translatio studii* (medieval historiography) · chain-of-custody
(forensics) · `gh gei`/`bbs2gh` (Bitbucket **Server/DC** scope — NOT Cloud).

## Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-07-29 | Bootstrap — forged from a real 9-repo Bitbucket-Cloud→GitHub cutover need. Named by `anima`: system-name `repo-custody-transfer`, soul-name **Translatio** (12/12; rejected `git-host-migration` — "migration" is the false promise the tool refuses). Design decisions: **carry-then-rename** (any repo-rename program runs AFTER a clean cutover — lower impact) · Blocking-Gate + Impediment Report as a first-class capability · autonomy-max with council-before-HITL. Ships the fidelity contract (T1/T2/T3/T4), the 5-phase reversible cutover, the drift-detector (SPLIT-BRAIN class), the custody ledger, and the §8 composition map. Residue scripts (extractor/archiver · pipeline translator · ledger CLI · drift CLI) deferred until a real cycle demands them (Gordian/YAGNI). **Empirical grounding**: drift-detect found bidirectional divergence in 3 of 9 repos (a `--mirror` would have destroyed 11+10 commits and 10 tags); a positive control disproved a self-fabricated `admin:org` impediment; T3 archival validated via a host API gateway with a positive control. 6/6 §10 + 8/8 anti-theater + 6/6 scope-discipline. PR `ekson73/multi-agent-os#289`. |
