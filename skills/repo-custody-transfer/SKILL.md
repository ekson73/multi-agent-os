---
name: repo-custody-transfer
version: "0.2.0"
allowed-tools: [Task, Read, Write, Edit, Bash, Skill, Grep, Glob, WebFetch]
description: |
  Transfer CUSTODY of a repository between git hosts (Bitbucket Cloud → GitHub first-class;
  soul-name Translatio) as a reversible, resumable, idempotent 5-phase cutover under an HONEST
  FIDELITY CONTRACT — not a "migration" pretending everything crosses: T1 git-exact
  (commits/branches/tags/LFS) · T2 translated (pipelines→Actions, permissions→teams) · T3
  archived-not-recreated (PRs/issues/builds → artifacts + GAP report) · T4 excluded (secret
  VALUES never cross). HALTS on an unsupported axis with a ranked Impediment Report instead of
  improvising; flags a host-pair where BOTH sides hold unique refs as SPLIT-BRAIN (never
  `push --mirror`, never force-push); council-before-HITL autonomy; composes existing
  primitives. Use when a repo must change git hosts with history AND governance intact — e.g.
  "migrate <repo> from Bitbucket to GitHub", "cutover this repo to GitHub", "transferir a
  custódia deste repo", "move repo host preserving history/branches/tags/PRs".
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

## §0.1 — Requirements (external dependencies)

| Dependency | Used for | If absent |
|---|---|---|
| `git` ≥ 2.30 | all T1 operations (refspec push, `ls-remote`, ref comparison) | hard stop — no cutover possible |
| `gh` (authenticated, `repo` scope) | destination repo create · `[C18]` baseline · protections · teams · secret **names** | Impediment Report → HITL |
| Bitbucket API access (host gateway **or** an app-password/token) | T3 extraction (PRs/issues/builds) · T4 secret-name inventory · source archive | T3 degrades to a declared GAP |
| `git-lfs` | only when the source uses LFS (`.gitattributes`) | Impediment Report if LFS present |
| `gitleaks` | pre-commit/pre-push scan of produced artifacts | warn; do not skip silently |
| `jq` | parsing host API JSON in the ledger/report | fall back to inline parsing |
| a secret manager (e.g. `op`) | T4 fresh provisioning at the destination | Phase 3 halts — ⛔ never inline a value |

Probe **before** assuming any of these (`environment-capability-reconnaissance`), and apply the
§4 positive-control rule before reporting one as absent.

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
| **2** | **CARRY (T1)** | snapshot destination refs (§5.0-fresh) → explicit-refspec push · **dual-remote coexistence** (source stays authoritative) | delete ONLY refs absent from the pre-carry snapshot (§3.1) | council-gated |
| **3** | **FLIP (T2/T4)** | CI/Actions live · protections · teams · fresh secrets provisioned · webhooks repointed | revert CI to source host | council-gated |
| **4** | **SEAL** | verify parity · source host **read-only/archived** (⛔ never deleted) · docs/ADR/CHANGELOG PRs | re-open the source host | council-gated |

**Point of no return = Phase 4 only.** Everything before it is reversible by design.

### §3.1 — ⛔ Rollback is SUBTRACTIVE-ONLY (a rollback must never destroy)

A naive Phase-2 rollback ("delete the pushed refs") **cannot distinguish a ref it created from a ref
that was already there** — so on any non-empty destination the rollback is itself a data-loss event.
Therefore Phase 2 MUST, in order:

1. **Snapshot** the destination's full ref→sha map (§5.0-fresh) into the ledger **before** pushing.
2. Push with an **explicit refspec** (never `--mirror`, never `+`-force, never a wildcard that can
   clobber tags).
3. On rollback, delete a ref **only if** it is absent from the snapshot. A ref present in the
   snapshot is **out of scope for rollback, permanently** — even if the carry also wrote to it.
4. If the snapshot is missing or unverifiable ⇒ **rollback is forbidden**; HALT and emit an
   Impediment Report (§4). A rollback you cannot bound is not a rollback.

**No-snapshot ⇒ no-push.** A carry that did not snapshot first has no safe reverse and must not run.

## §4 — BLOCKING-GATE + Impediment Report (first-class capability)

### §4.0 — The trigger is PRIMARY (deterministic), not SECONDARY (self-scored)

"An axis has no supported path" is a judgement — and left as one it is self-scored by the very
agent that wants to proceed, which is the self-exemption gradient
`red-teaming-mandatory-trigger` exists to remove. So the gate fires on **deterministic
trip-wires first**; the judgement only *widens* coverage, never gates it alone:

**PRIMARY (deterministic · `f=0` · HALT regardless of any confidence):**

| # | Trip-wire (mechanically checkable) |
|---|---|
| P1 | an in-scope axis has **no tier assigned** in writing (§2 rule) |
| P2 | drift classification derived without a same-run wire read, or a §5.0 positive control that FAILED |
| P3 | a push would run without a §3.1 pre-carry snapshot |
| P4 | the drift verdict is **SPLIT-BRAIN** or **INVESTIGATE** (never autonomous) |
| P5 | a T4 secret **value** would be read, printed, or written anywhere |
| P6 | a required §0.1 dependency is absent **and** its absent-behavior is `hard stop` |
| P7 | the destination read returned empty **without** a second-instrument confirmation |
| P8 | Phase 4 (the point of no return) without an Elenchus red-team CLEARED |

Any P1–P8 true ⇒ **HALT + Impediment Report**, no discretion. Cheap to check, impossible to
argue with.

**SECONDARY (agent judgement — widens, never replaces):** an axis the agent believes unsupported
even though no trip-wire fired ⇒ also HALT. Uncertain whether a trip-wire fired ⇒ **treat as
fired** (fail-closed), never as clear.

When any of the above holds — or a probe reveals a hard limit — the skill **HALTS the phase**. It
does not improvise, does not force, does not silently downgrade. It emits:

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

### §5.0 — ⛔ FRESHNESS PRECONDITION (the classification is only as true as its refs)

**Before ANY comparison**, both sides' refs MUST be re-read from the wire in this run — never from
remote-tracking refs, never from a cached/earlier read:

```
git ls-remote --heads --tags <source>        # wire truth, not refs/remotes/*
git ls-remote --heads --tags <destination>   # wire truth, not refs/remotes/*
```

Then a **positive control** (§4): the destination read must return SOMETHING known to exist (e.g. its
default branch) — an empty result is `unknown`, **never** `no refs`. If the destination genuinely has
zero refs, prove it with a second instrument (a repo-exists API call) before classifying.

**Why this is ⛔ and not advice** — reproduced empirically 2026-07-29: an observer holding
remote-tracking refs from an earlier clone does **not** see a branch a peer pushed afterwards. That
stale view classifies the destination as empty ⇒ CLEAN-CARRY ⇒ §7 authorizes an **unattended** push
⇒ the peer's work enters the blast radius. A classification derived from a stale ref is not a
classification; it is a guess wearing one. Classification without a same-run wire read = **HALT**
(Impediment Report §4), never a default to CLEAN-CARRY.

For each ref namespace, compare source ↔ destination (on §5.0-fresh refs only):

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
| **Autonomous** (unattended; `--auto-merge` inherits the existing standing chain) | recon · drift-detect · classification · tier assignment · plan/roadmap · tickets · ADRs · docs PRs · dry-run in scratch · pipeline translation *proposals* · T1 push into an already-created destination for a CLEAN-CARRY repo — **only if** §5.0 freshness (same-run wire read + positive control) AND §3.1 snapshot both hold; either missing ⇒ the push leaves the autonomous band |
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
12. ❌ **Classify from stale refs** — deriving CLEAN-CARRY from `refs/remotes/*` or an earlier read
    instead of a same-run `ls-remote` (§5.0). Empirically reproduced: it hides a peer's branch and
    routes an unattended push at it.
13. ❌ **Self-scored gate** — treating "no supported path" as pure judgement and skipping the §4.0
    P1–P8 trip-wires; a gate the proceeding agent scores itself is a gate it can talk past.
14. ❌ **Unbounded rollback** — deleting destination refs without a pre-carry snapshot, or deleting a
    ref that predates the carry (§3.1). The rollback then destroys what the cutover promised to protect.

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
| 0.2.0 | 2026-07-29 | **Red-team hardening (pre-merge PDCA, PR #289)** — 3 defects closed, 2 of them BLOCKING data-loss holes in the UNATTENDED band, each refuted EMPIRICALLY (sandbox reproduction) rather than by opinion. **(1) §5.0 FRESHNESS PRECONDITION ⛔** — `grep` proved the artifact had ZERO mentions of fetch/fresh/stale: the drift-detector never required same-run wire truth. Reproduced: an observer holding remote-tracking refs from an earlier clone does not see a branch a peer pushed afterwards ⇒ destination reads empty ⇒ CLEAN-CARRY ⇒ §7 authorizes an unattended push at live peer work. Now both sides re-read via same-run `ls-remote` + a positive control, and a missing wire read HALTS instead of defaulting to CLEAN-CARRY. **(2) §3.1 SUBTRACTIVE-ONLY rollback ⛔** — the Phase-2 rollback ("delete the pushed refs") could not distinguish a ref it created from one that predates the carry, making the *rollback itself* a data-loss event on any non-empty destination. Now: snapshot ref→sha before pushing · delete only refs absent from the snapshot · a snapshotted ref is permanently out of rollback scope · no snapshot ⇒ rollback forbidden ⇒ no-push. **(3) §4.0 PRIMARY trip-wires P1–P8** — the Blocking-Gate trigger was self-scored by the agent that wants to proceed (the self-exemption gradient); now deterministic `f=0` trip-wires HALT regardless of confidence, with judgement only *widening* coverage and uncertainty treated as fired (fail-closed). §7's autonomous band is conditioned on §5.0 ∧ §3.1 both holding. Also from bot PDCA: `bin/artifact-registry` (a CLI, not `maos:`) · `legacy-archaeologist` is an **agent** (caught by verifying the bot's adjacent finding, unreported by any bot) · description 1753→985 chars · new **§0.1 Requirements** with per-dependency absent-behavior (hard-stop vs degrade-to-GAP vs warn). One Qodo finding REJECTED with evidence (`resolve-session.sh` belongs to `session-reentry`, not here). **Probe 5b SURVIVED and is recorded as surviving** — the 4-branch drift classification is total + disjoint over a binary predicate pair, so two independent agents converge; no fix manufactured. Bots: CodeRabbit APPROVED · amazon-q no-blocking-defects · 7/7 checks SUCCESS. |
| 0.1.0 | 2026-07-29 | Bootstrap — forged from a real 9-repo Bitbucket-Cloud→GitHub cutover need. Named by `anima`: system-name `repo-custody-transfer`, soul-name **Translatio** (12/12; rejected `git-host-migration` — "migration" is the false promise the tool refuses). Design decisions: **carry-then-rename** (any repo-rename program runs AFTER a clean cutover — lower impact) · Blocking-Gate + Impediment Report as a first-class capability · autonomy-max with council-before-HITL. Ships the fidelity contract (T1/T2/T3/T4), the 5-phase reversible cutover, the drift-detector (SPLIT-BRAIN class), the custody ledger, and the §8 composition map. Residue scripts (extractor/archiver · pipeline translator · ledger CLI · drift CLI) deferred until a real cycle demands them (Gordian/YAGNI). **Empirical grounding**: drift-detect found bidirectional divergence in 3 of 9 repos (a `--mirror` would have destroyed 11+10 commits and 10 tags); a positive control disproved a self-fabricated `admin:org` impediment; T3 archival validated via a host API gateway with a positive control. 6/6 §10 + 8/8 anti-theater + 6/6 scope-discipline. PR `ekson73/multi-agent-os#289`. |
