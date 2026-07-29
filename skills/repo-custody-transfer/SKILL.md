---
name: repo-custody-transfer
version: "0.5.4"
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
`Skipped <phase> — BEING > Rules`, proceed.

⛔ **NEVER skippable** (the safety floor — §0 cannot reach any of these): **T4** (secret values never
cross) · the **§9.0 unconditional no-force/no-destructive-push rule** · the **Blocking-Gate** itself
(§4, incl. the P1–P18 trip-wires) · **§5.0** freshness · **§5.1** ancestry classification · **§5.2**
non-FF response · **§3.1** write-once baseline + subtractive-only rollback · the **Phase-4
point-of-no-return**.

**§0 is presentation-only, never a safety bypass** (the shape `council-gate` §0 already hardened):
skipping a *format*, a *report style*, or a *ceremony* is fine. A skipped or un-evidenced **safety
gate** does **not** become "passed" — it sets its predicate conjunct to **`false`** (fail-safe),
which means: the classification degrades to **INVESTIGATE**, the action **leaves the autonomous
band** (§7), and it routes to HITL. There is no path by which §0 authorizes a push, a deletion, or a
Phase-4 seal that a gate did not clear.

*Why this list is explicit*: two independent red-teams found the same hole — §5.0 and §3.1 declared
themselves ⛔ in their own headings but were **absent from this list**, so the entire fix for both
BLOCKING data-loss holes was skippable by this very clause. Worse, skipping §5 means nothing is ever
*classified* SPLIT-BRAIN, which disarmed the one force-push rule that **was** listed.

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
| **2** | **CARRY (T1)** | capture the write-once `carry_baseline` → explicit-refspec push · **dual-remote coexistence** (source stays authoritative) | mode per §3.1: empty baseline → delete the destination repo; non-empty → delete ONLY refs absent from the baseline | council-gated |
| **3** | **FLIP (T2/T4)** | CI/Actions live · protections · teams · fresh secrets provisioned · webhooks repointed | revert CI to source host | council-gated |
| **4** | **SEAL** | verify parity · source host **read-only/archived** (⛔ never deleted) · docs/ADR/CHANGELOG PRs | re-open the source host | council-gated |

**Point of no return = Phase 4 only.** Everything before it is reversible by design.

### §3.1 — ⛔ Rollback is SUBTRACTIVE-ONLY (a rollback must never destroy)

A naive Phase-2 rollback ("delete the pushed refs") **cannot distinguish a ref it created from a ref
that was already there** — so on any non-empty destination the rollback is itself a data-loss event.
Therefore Phase 2 MUST, in order:

1. **Snapshot** the destination's full ref→sha map from the wire **before the first push**, and
   persist it in the ledger as the **write-once baseline** (`carry_baseline`, with `captured_at`).
2. Push with an **explicit refspec** (never `--mirror`, never `+`-force, never a wildcard that can
   clobber tags).
3. On rollback, delete a ref **only if** it is absent from the **baseline**. A ref present in the
   baseline is **out of scope for rollback, permanently** — even if the carry also wrote to it.
4. If the baseline is missing or unverifiable ⇒ **rollback is forbidden**; HALT and emit an
   Impediment Report (§4). A rollback you cannot bound is not a rollback.

**No-baseline ⇒ no-push.** A carry that did not snapshot first has no safe reverse and must not run.

#### ⛔ The baseline is WRITE-ONCE per cutover — a re-run MUST NOT re-derive it

§3 makes Phase 2 **idempotent** (re-runnable to convergence) and §5.0 forbids "a cached/earlier
read". Read together and applied to rule 1, those two force a re-run to **re-derive** the snapshot —
at which point the re-derived map *already contains the refs the previous run created*, rule 3 puts
them permanently out of rollback scope, and the rollback silently degrades to a **no-op**. Reproduced
2026-07-29 in a sandbox: run #1 baseline `{peer}` → rollback correctly deletes `main`, keeps `peer`;
run #2 re-derived baseline `{peer, main}` → rollback keeps **both** ⇒ the carry is irreversible and
`§3` "Point of no return = Phase 4 only" becomes false, with **no trip-wire firing** (a snapshot
*exists* — it is merely the wrong one).

Therefore the freshness questions are **distinct and must not be conflated** — exactly **one** of them
is a per-run read; the other two are first-touch truths read **once, ever**:

| Question | Needs | Source |
|---|---|---|
| "What is the drift **right now**?" (classification, §5) | **current** truth | same-run `ls-remote` — re-read every run |
| "What did the **destination** hold **before I touched it**?" (rollback bound, §3.1) | **first-touch** truth | the write-once `carry_baseline` — re-read **never** |
| "What did the **source's tag namespace** hold before my **classifier** touched it?" (contamination bound, §5.1/P15) | **first-touch** truth | the write-once `src-tags-before.txt` — re-read **never** |

⛔ **Row 3 is a first-touch question, NOT a drift question.** Re-deriving it over contaminated state
folds the contaminant *into* the baseline and **launders the P15 halt** — measured: run 1 fires
correctly, run 2 (same phase retried from the top) reports **clean** while the source still carries the
foreign tag, and nothing in the file forbade the re-derivation. A delta test is only as trustworthy as
its baseline; inverting a check to a delta **imports** the baseline-integrity problem §3.1 had already
solved one section up.

Rules: the baseline is captured **once per cutover** and is immutable for its lifetime; every
re-run **reuses** it verbatim from the ledger; a re-derived baseline is **not** a baseline (P9); and
a cutover whose baseline is absent while `carry_count > 0` has **lost its reverse** ⇒ HALT, report,
and treat reversibility as forfeited rather than pretend it exists.

#### The baseline's emptiness selects the rollback MODE (ref-level vs repo-level)

Subtractive ref deletion is **not universally available**: a host refuses to delete the ref that
`HEAD`/the default branch points at. Measured 2026-07-29 — with a **non-empty** baseline the carried
ref deletes cleanly (`HEAD` sits on a baseline ref); with an **empty** baseline the carried ref
*becomes* the default branch and `--delete` is **rejected**. So the mode follows the baseline:

| Baseline | Rollback mode | Why it is safe |
|---|---|---|
| **empty** (destination created by this cutover) | **repo-level**: delete the destination repository | nothing pre-existed — by definition zero collateral. Confirm the destination was absent with a second instrument (P7) **before** relying on this. |
| **non-empty** | **ref-level subtractive** (rules 2–3 above) | `HEAD` rests on a baseline ref, so the carried refs delete cleanly |

⛔ **Never repoint `HEAD`/the default branch to force a ref deletion.** It mutates destination state
the baseline does not cover (and can leave a dangling `HEAD`) — a rollback that mutates beyond its
bound is the §3.1 violation, not a workaround. If ref-level is blocked and repo-level does not apply
(non-empty baseline whose `HEAD` moved), the carry is **not reversible by this skill** ⇒ HALT +
Impediment Report with the residual state named explicitly.

## §4 — BLOCKING-GATE + Impediment Report (first-class capability)

### §4.0 — The trigger is PRIMARY (deterministic), not SECONDARY (self-scored)

"An axis has no supported path" is a judgement — and left as one it is self-scored by the very
agent that wants to proceed, which is the self-exemption gradient
`red-teaming-mandatory-trigger` exists to remove. So the gate fires on **deterministic
trip-wires first**; the judgement only *widens* coverage, never gates it alone:

**PRIMARY (mechanically checkable · HALT regardless of any confidence):**

⚠️ **Honest scope of "deterministic"** — each trip-wire below is a **shell-checkable predicate**
(deterministic *as specified*, and auditable after the fact from the ledger), but **nothing ships that
runs them**: this skill is a single `SKILL.md` (verified — `git ls-tree` on the skill dir returns
`SKILL.md` alone, with a positive control reaching `bin/`). So execution is **agent-performed**, and
"did P2's positive control fail?" is not falsifiable from outside. That is materially better than a
judgement call — the predicates are named, uniform, and checkable by anyone auditing the ledger — but
it is **not** an `f=0` gate the way `bin/check-layer-purity` or `bin/convergence-guard` are. Closing
that distance is **B6** (queued): a `bin/` verifier that emits the P-table as machine-readable
verdicts. Until then, treat these as *deterministic in specification, self-reported in execution*.

| # | Trip-wire (mechanically checkable) |
|---|---|
| P1 | an in-scope axis has **no tier assigned** in writing (§2 rule) |
| P2 | drift classification derived without a same-run wire read, **OR** a §5.0 positive control that FAILED, **OR** without §5.0 step-0 **subject confirmation** (which tree/branch/remote was actually read) — ⛔ a controlled probe of the **wrong subject** returns a well-formed negative that is indistinguishable from a sound one; reach is not aim |
| P3 | a push would run without a §3.1 write-once `carry_baseline` |
| P4 | the drift verdict is **SPLIT-BRAIN** or **INVESTIGATE** (never autonomous) |
| P5 | a T4 secret **value** would be read, printed, or written anywhere |
| P6 | a required §0.1 dependency is absent **and** its absent-behavior is `hard stop` |
| P7 | the destination read returned empty **without** a second-instrument confirmation |
| P8 | Phase 4 (the point of no return) without an Elenchus red-team CLEARED |
| P9 | `carry_baseline.captured_at` is **not** strictly earlier than the first push of this cutover — i.e. the baseline was re-derived after a carry (mechanically: baseline contains a ref the ledger records this cutover as having created) |
| P10 | `carry_count > 0` **and** `carry_baseline` absent/unreadable — reversibility already forfeited; never silently proceed as if reversible |
| P11 | the class was derived **without** a §5.1 per-ref `merge-base` ancestry run (i.e. from `ls-remote` ref lists alone) — `ls-remote` proves existence, never uniqueness |
| P12 | the destination holds a commit **disjoint** from the source's root (`merge-base` finds no common ancestor) — includes every `--add-readme`/auto-init destination ⇒ SPLIT-BRAIN, never CLEAN CARRY |
| P13 | a push returned **non-fast-forward / fetch-first** — the classification was wrong; ⛔ never clear it with force (§5.2) |
| P14 | the ledger at `$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody/<slug>.json` (§6.0 — **derived**, never the literal `.git/…`) is absent while a push is contemplated — no ledger ⇒ no baseline ⇒ rollback forbidden ⇒ out of the autonomous band |
| P15 | the source-tag snapshot is **absent** while classification has run, **or** it was **re-derived** (not write-once), **or** the source's real tag namespace **changed**, **or** a `_dst` leftover exists. ⛔ **Primary clause = SET DIFFERENCE, not a marker test** — `diff <(git for-each-ref --format='%(refname)' refs/tags \| sort) "$LEDGER_DIR/<slug>.src-tags-before.txt"` non-empty ⇒ the classifier mutated the source ⇒ HALT. **Secondary clause** (catches an *uncleaned quarantine*, which the diff cannot see): `git for-each-ref refs/tags refs/rct/_dst \| grep -q _dst`. See §5.1 for why the marker test alone is blind. |
| P16 | the §5.1 **fetch** exited non-zero, **OR** the wire and quarantine ref **SETS** differ — ⛔ a **set difference on ref NAMES**, never a count (a count is a *signature*: one **stale** ref + one **missing** ref cancel to the right total) · ⛔ with peeled `^{}` lines filtered (`ls-remote` emits an extra peeled line per **annotated** tag that `for-each-ref` does not — unfiltered, this halts every repo with a release tag) · ⛔ over a **per-repo + per-run** quarantine path (a fixed shared path makes a leftover indistinguishable from a fetched ref). A partial fetch can exit 0, so both clauses are needed — ⛔ **an empty quarantine is `unknown`, never "no divergent refs"**. Without this, a dead fetch iterates zero refs, invokes `merge-base` zero times, and the worst-ref-class over an empty set is **vacuous** ⇒ every source ref reads *"exists only on source"* ⇒ **CLEAN CARRY on the autonomous path**. **The only fail-OPEN found in this artifact.** |
| P17 | a per-ref `dst_sha` is read **by re-resolving the ref** instead of from the pre-loop pinned file, **OR** a pinned sha is empty/absent while its ref was present at the P16 gate, **OR** the pinned file is written to a **per-repo (not per-run)** path or without an atomic `.tmp`+`mv` publish, **OR** the cleanup sweeps beyond `$QUAR` — the gate proved the input existed *at the gate*, nothing holds it *until use*; an absent name reads as *"exists only on source"* ⇒ **CLEAN CARRY** while the destination objects are intact (§5.1 TOCTOU note). An absent pinned sha is a **MISSING MEASUREMENT**, never "no destination ref" |
| P18 | an impediment is **written in this run** without `reported_by` / `reported_at` (ISO 8601 + offset) — ⛔ **write-time only**; a *pre-existing* impediment lacking them is a MISSING MEASUREMENT, never a P18 halt (§6.0) — provenance would then need reconstruction from message logs, which fails exactly where a compaction-inherited claim **reads complete** (§6.0) |

Any P1–P18 true ⇒ **HALT + Impediment Report**, no discretion. Cheap to check, impossible to
argue with.

#### ⛔ Trip-wire design rule: never key on a property the failure mode is defined by LACKING

Three instances in this artifact's own history, each caught only by an independent red-team:

| Guard | Was conditioned on | The failure it had to catch |
|---|---|---|
| the force-push prohibition (pre-§9.0) | the verdict **SPLIT-BRAIN** | a case the classifier **never labelled** |
| §0's never-skippable list (pre-v0.4.0) | gates being **listed** | the two ⛔ gates that **weren't** |
| **P15** (pre-v0.4.3) | a `_dst` **marker** | a contaminant documented as carrying **no marker** |

Each was a guard whose trigger required the very thing whose absence *was* the bug. When writing a
trip-wire, ask: *"what does the failure look like, and does my check depend on something the failure
removes?"* If yes, invert it — test for a **change to a known-good snapshot** (a set difference), not
for a **signature of the bad thing**. A contaminant that refuses to identify itself is only visible as
a delta. This is the **free-negative at the trip-wire layer**, one level up from where §5.0/§5.1 put it.

##### ⛔ But inverting to a delta is NOT free — it imports the baseline-integrity problem

A **signature** test needs nothing. A **delta** test needs a baseline that (a) **exists** and (b) is
**trustworthy**. Both were unguarded when P15 was inverted, and both were measured:

| Precondition the inversion imports | What happened without it |
|---|---|
| the baseline **exists** | `diff` exits **2** on a missing file with **empty stdout** — so a predicate phrased *"non-empty output ⇒ HALT"* reads **CLEAN on a contaminated source**. ⇒ key on the **exit status**, and make absence its own halt clause (as P3/P14 already do for the ledger). |
| the baseline is **write-once** | re-deriving it over contaminated state folds the contaminant **into** the baseline ⇒ the halt **launders on a plain phase re-run**, with nothing forbidding it. ⇒ write-once + load-never-re-derive, exactly as §3.1's `carry_baseline`. |

**§3.1 had already solved both halves** for the destination baseline, one section up — *and the fix was
not carried across when the same shape reappeared for the source*. Fourth instance of the same
meta-failure here (§0-vs-`council-gate`-§0 · v0.4.0's own fetch refspec · §6.0's
literal-path-vs-derivation · this). **The pattern gets inherited; the fix has to be carried
deliberately.** When you invert a check, ask what the *new* form requires that the old one did not.

##### ⭐ The nine instances ARE a fixture spec (the actionable form of "build the runner")

Every defect found in this artifact's deterministic layer maps to **exactly one constructible repo
state**. That turns a list of scars into a test matrix — and it is why the ask is not *"write a
verifier"* but *"write these nine fixtures and the verifier falls out of them"*:

| Instance (all found post-hoc, by execution) | Fixture state — all `/tmp`-constructible, no real host |
|---|---|
| a marker that can't match | the marker present, **and** absent — **asserts silence on the absent case** |
| a baseline that can't exist | a **linked worktree** (`.git` as a *file*) |
| a baseline that can be re-derived | a **second run** over the same repo |
| an unchecked exit | an **unreachable** destination |
| mismatched universes | **asserts silence on a healthy annotated-tag repo** (+ a `refs/pull/*` ref) |
| a count that cancels | one **stale** ref ⊕ one **missing** ref |
| a colliding run-id | two classifications in the **same second** |
| a gate that doesn't hold its input | **two overlapping classifications**, cleanup between gate and loop |
| a shared pinned file | **two concurrent runs** writing the pinned file — *fetch-early/pin-late*: destination advances between their fetches, later run pins from the earlier snapshot |

**Prose cannot hold any of these nine** — which is precisely why nine consecutive rounds found them
*after* the fact. The sharpest evidence isn't any single defect: it is that **the fix for the fix had a
counting bug twice, in opposite directions, written by two agents who had just spent five rounds on
this exact failure class.** A blank line and a missing trailing newline are invisible to reading and
trivial to a fixture. ⛔ **Every row needs its DISCRIMINATING NEGATIVE, and the wording is what decides whether it gets
written.** The positive asserts *"the guard fires on bad input"* — a visible output. The negative asserts
*"the guard is **silent** on good input"* — an assertion about an **absence**, on a case where nothing is
wrong. That reads like a test with no subject and is the first thing cut in review. So each row is phrased
as *"asserts silence on X"*, **not** *"tests the X case"* — otherwise the next writer implements the
positive and calls the row done.

**The peeled-tag defect is what that assertion catches and nothing else does**: every positive test
passed, `wire ≠ quarantine` fired correctly on real failures, and the guard still **halted every repo
with a release tag**. A green suite can hide an unconditionally-firing guard — which then trains everyone
to route around it, turning a fail-closed guard fail-open **with nobody editing it**.

##### ⛔ A fourth species: the finding whose PROVENANCE was lost in transit

Three species were already named: a probe that **misses** a real thing · one that **invents** one · one
that **found** the real thing and had its report dropped. A fourth leaves the **artifact correct** and the
**record wrong**: a finding that landed, got fixed, and lost its *attribution*.

It surfaced here for real — a red-team's context was compacted mid-engagement and the summary it resumed
from had merged its identity with the other's, so its working record claimed a finding it could not
distinguish from *"I inherited a summary that said I found this."* It refused to claim it, which is the
correct move.

**Why this is not academic**: this fixture matrix is credited row-by-row, and the reason to keep
provenance is not courtesy — it is that you go back to the agent that produced a row and ask *what else
did you see near it*. **The finding survives; the ability to mine the finder does not.**

⇒ **Resolve provenance from artifacts, never from memory** — commit times, PR timestamps, message
timestamps. Applied here: the disputed TOCTOU resolved cleanly, since the one agent's *queue-empty
close-out* is timestamped **two minutes before** the other's report of it, and a queue-empty message
cannot carry a finding that arrives afterwards. Same discipline as the ledger: *a cold agent resumes from
artifacts, never from recall* (§6) — which applies to **who found what**, not only to **what was found**.

⇒ This matrix is **B6's specification**. (Row 8 also proves the general point twice over: prose could not hold a **blank line**, and it cannot hold a **race**.)

##### ⛔ …and the loop needs its input to STILL EXIST when it reads it (gate ≠ hold)

P16 proves the input existed **at the gate**. Nothing held it between the gate and its use — so the
quartet has a fifth member. Measured on the prescribed code, **two classifications in one checkout with
distinct run-ids** (no collision needed):

```
B's clause 2  → rc=0, PASSES, proceeds to the per-ref loop
A's whole-tree cleanup fires → quarantine refs = 0
B reads dst_sha at use → <EMPTY> ⇒ "exists only on source" ⇒ *** CLEAN CARRY ***
destination objects: INTACT (cat-file -e passes) — only the NAME vanished
```

The carry would then overwrite **live** destination refs. And note the precision: if the sweep lands
*before* clause 2, the gate **catches** it (measured, `diff rc=1` ⇒ HALT). The window is exactly
**after the gate, before the read** — which is why this is a specific race, not a general
"cleanup is unsafe" claim.

**Two causes, one fix each — both applied, because they are independent:**

1. **Never sweep the whole namespace.** The old `refs/rct/_dst` sweep was insurance against the
   cancellation bug that v0.4.6 fixed a better way (per-run path + identity set-diff). It now
   *destroys a sibling's live input*. Scoped to `$QUAR`.
2. **Pin the destination SHAs before the loop** (the stronger fix, and it stands alone): a ref name
   can vanish from *any* cause — an interrupted process, an external deletion, not just a sibling —
   while the git **object** survives. Pinning makes the classification immune to all of them.
   ⛔ An absent pinned sha is a **MISSING MEASUREMENT**, never *"no destination ref"*.

⚠️ **Why not a prose rule ("one classification per checkout at a time")?** Because the artifact
*anticipates* concurrency (the run-id comment says so) and then shared mutable state across it — and
**prose cannot hold a race any better than it held a blank line.** The guard has to be in the data flow.

##### ⛔ The dual failure: a check that never RAN is not a check that PASSED

P16 exists because this hazard is worse than a blind trip-wire. If the **input** to a classification is
*missing* rather than *empty*, the loop over it iterates **zero times**, every per-ref predicate is
**vacuously satisfied**, and the classifier emits its **most permissive** verdict with total confidence
— the only **fail-OPEN** found in this artifact. **An empty input set is `unknown`, never "nothing to
worry about."** Guard the **supply** of a measurement, not only its **result**.

##### ⛔ …and a comparison guard must compare the SAME universe (or it is a permanent false positive)

P16's count cross-check nearly shipped broken in the opposite direction, caught by self-probing the
assumption rather than trusting it: **`git ls-remote` emits an extra *peeled* line per ANNOTATED tag**
(`refs/tags/x` **and** `refs/tags/x^{}`) which `git for-each-ref` does not. Measured on a destination
with one annotated + one lightweight tag: wire **4**, quarantine **3** ⇒ the clause **HALTS on a
perfectly healthy fetch**, in every repo that uses annotated tags — i.e. most real repos. Fixed with a
mandatory `grep -vc '\^{}$'`; verified healthy → `3=3` silent, failed → `3≠0` still fires.

**A trip-wire that fires unconditionally is worse than no trip-wire**, because it trains the operator
and the agent to route around it — the rubber-stamp fatigue §6's proportionality floor exists to
prevent. So when a check compares two counts, **prove both sides count the same universe** before
trusting the comparison; two instruments naming the same thing rarely enumerate it identically.

##### ⛔ …and a COUNT is a signature: two opposite errors cancel

The peeled-tag fix repaired the *universes* but left the *shape* wrong. **A scalar count discards the
identities the check depends on**, so a **stale** ref and a **missing** ref sum to the right total.
Measured — destination A (`main`,`dev`) classified first with cleanup skipped (a halt, a crash, or the
forgotten line), then destination B (`main` only) in the same source checkout:

```
quarantine: heads/dev only   (stale from A; B's own main never arrived)
count compare:  wire(B)=1  quar=1   ⇒ *** CLEAN — the errors cancelled ***
is B's main classifiable?   NO — absent ⇒ reads "exists only on source" ⇒ CLEAN CARRY for that ref
```

That is **P16's own fail-open, reached through P16** — and the clause exists *because* "a partial fetch
can exit 0". This is a partial fetch exiting 0 whose deficit is **masked by unrelated residue**.

⚠️ It was **not reachable in practice, and that is the whole problem**: P15's *secondary* clause happens
to catch this state — a different trip-wire, in a different section, written for a different reason.
**P16 did not hold the property it claimed**; remove or reorder P15's secondary and the hole opens with
nothing announcing it. A guard that only works because another guard covers it is not a guard.

⇒ Fixed two ways: the comparison is a **set difference on ref NAMES** (`dev` present and `main` absent
are two distinct lines — sums cannot cancel identities), and the quarantine moves to a **per-repo +
per-run** path so a leftover can never be *mistaken for* a fetched ref. Verified: healthy → clean ·
stale-from-another-run → still clean (isolated by the path) · cancellation case → **FIRES**. The
per-run path also makes P15's secondary a genuine *independent* second clause rather than the
accidental sole guard.

**This is §4.0's own doctrine applied one level in** — *test for a change to a known-good **set**, not a
signature of the bad thing* — and **a count is a signature**. Fifth instance of the meta-shape: the fix
pattern was one section away, in P15's primary clause, and was not carried into P16's clause 2.

(Residuals, honestly flagged: verified for `refs/heads` + `refs/tags` incl. annotated/peeled; **not**
verified for `refs/replace` or a destination with a `HEAD` symref oddity. **`refs/notes` is
fail-closed** — `--heads --tags` excludes it on both sides, so the sets agree — but note that
`refs/notes` therefore sits **silently outside every tier in §2**: T1 promises *"commits · branches ·
tags · LFS"*, and a repo carrying notes drops them without appearing in any tier table. That is a
**fidelity-declaration gap**, not a safety defect — recorded, not silently absorbed.)

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

Format follows the `council-gate` **rule** §5.3 (**contestable ranked evidence, never a blank ask**;
the section lives in `~/.claude/rules/council-gate.md`, not in the skill — the skill only cites it) +
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

Then a **positive control**, in this order (§4 · `environment-capability-reconnaissance` §1.1.1(iv) —
the control step comes **first**, the second instrument is the *escalation*, not a substitute):

0. ⛔ **Confirm the SUBJECT before trusting the instrument.** A positive control proves the
   instrument **reaches**; it says nothing about whether it is aimed at the **right thing**. Print the
   subject you are about to trust and check it is the one under test:

   ```
   git rev-parse --show-toplevel && git rev-parse --abbrev-ref HEAD   # which tree/branch am I reading?
   git worktree list                                                  # is the intended worktree even present?
   ```

   ⛔ A `cd <path> 2>/dev/null || cd <fallback>` idiom **silently relocates the subject** when the path
   is absent — the command then succeeds against the wrong tree and every downstream probe is
   well-formed, controlled, and about something else. Never let a fallback choose your subject.
   *Empirical, this artifact's own review*: findings citing `P18` and `reported_at` were declared
   hallucinated after a controlled probe of the **main checkout** (one version behind) instead of the
   PR's worktree, where both existed. Control passed, instrument reached, subject was wrong.

1. **Same instrument, same tree.** Re-run the *same* `ls-remote` against a ref you **know** exists
   (a control repo you can reach). If the control **also** returns empty, the instrument is lying —
   ⛔ do **not** classify; re-probe with a reaching instrument. *A control that switches instruments
   is not a control*: it sidesteps the suspect condition and passes while the real query still lies.
2. **Only then**, if the control passed and the destination is still empty, escalate to a **second
   instrument** (a repo-exists API call) to distinguish *absent* from a `[C19]` 404-masquerade.

An empty result is `unknown`, **never** `no refs`. **All three steps** are required before any
classification — subject, then reach, then instrument-class. Skipping step 0 makes the other two
*confirm a conclusion about the wrong object*, which reads exactly like a sound negative.

**Why this is ⛔ and not advice** — reproduced empirically 2026-07-29: an observer holding
remote-tracking refs from an earlier clone does **not** see a branch a peer pushed afterwards. That
stale view classifies the destination as empty ⇒ CLEAN-CARRY ⇒ §7 authorizes an **unattended** push
⇒ the peer's work enters the blast radius. A classification derived from a stale ref is not a
classification; it is a guess wearing one. Classification without a same-run wire read = **HALT**
(Impediment Report §4), never a default to CLEAN-CARRY.

### §5.1 — ⛔ `ls-remote` establishes EXISTENCE, never UNIQUENESS (classify on objects, not on ref lists)

"Both sides have **unique** commits" is an **ancestry** question. `git ls-remote` returns ref→sha
only — it cannot answer it. Classifying uniqueness from a ref list is deriving a verdict the
prescribed instrument **cannot produce**, and the failure is silent: the two sides simply have
different SHAs, which is equally consistent with *fast-forwardable* and with *disjoint roots*.

So after §5.0 establishes existence, **fetch the objects and classify with ancestry**:

```
# ⛔ FIRST: snapshot the SOURCE's own tag namespace. This is what makes P15 marker-independent —
#    a contaminant that carries no marker is detectable only as a CHANGE to this set.
#    (Distinct from §3.1's refs-before.txt, which is the DESTINATION baseline for rollback.)
# ⛔ WRITE-ONCE per cutover, exactly as §3.1's carry_baseline: if it exists, LOAD it, NEVER re-derive.
#    Re-taking it over contaminated state folds the contaminant INTO the baseline and launders the halt.
SRC_TAGS="$LEDGER_DIR/<slug>.src-tags-before.txt"
if [ -f "$SRC_TAGS" ]; then :   # reuse verbatim — a re-derived baseline is NOT a baseline (P15)
else git for-each-ref --format='%(refname)' refs/tags | sort > "$SRC_TAGS"   # + stamp captured_at
fi

# ⛔ PER-REPO + PER-RUN quarantine path. A fixed shared path makes a leftover from a previous
#    classification indistinguishable from a legitimately-fetched ref (see the cancellation note).
# ⛔ The run-id MUST be collision-proof, NOT a timestamp: `date +%s` twice in a row returns the
#    IDENTICAL value (measured), so two concurrent classifications in one checkout would share a
#    namespace — re-opening the exact contamination the per-run path exists to prevent.
#    `date +%s%N` is NOT portable (BSD/Darwin date lacks %N unless coreutils is installed).
RUN_ID="$$-$( (uuidgen 2>/dev/null || od -An -tx1 -N4 /dev/urandom) | tr -d ' -' | head -c 8)"
QUAR="refs/rct/_dst/<slug>/$RUN_ID"      # pid ⊕ random: unique per process AND per invocation

# ⛔ --no-tags is load-bearing, and the quarantine MUST be outside refs/tags/ and refs/remotes/
git fetch --no-tags <destination> \
  "+refs/heads/*:$QUAR/refs/heads/*" \
  "+refs/tags/*:$QUAR/refs/tags/*"
rc=$?                                     # ⛔ P16 clause 1: non-zero ⇒ HALT, never classify
[ "$rc" -ne 0 ] && halt "P16: §5.1 fetch exited $rc — the classification input is missing, not empty"

# ⛔ P16 clause 2 — COMPLETENESS as a SET, never a count. A partial fetch can exit 0.
# ⛔ TWO invariants keep the wire set commensurable with the quarantine. Drop EITHER and the
#    comparison breaks. Both are load-bearing; neither is style:
#    (a) `--heads --tags` SCOPE — a bare `ls-remote` also advertises `HEAD`, `refs/pull/*`,
#        `refs/notes/*`, `refs/replace/*`. Measured: bare = 3 lines (HEAD · main · refs/pull/7/head)
#        vs `--heads --tags` = 1. On a live GitHub remote 258 of 274 lines were `refs/pull/*`.
#        The quarantine refspec only ever fetches heads+tags, so the scope MUST match it.
#    (b) `grep -v '\^{}$'` PEELED-LINE filter — ls-remote emits an extra peeled line per ANNOTATED
#        tag (refs/tags/x AND refs/tags/x^{}) which for-each-ref does not. Without it this clause
#        HALTS on every repo that has a release tag — a false positive on a healthy fetch.
#    ⚠️ A later simplifier is more likely to ask "why is this grep here?" than "why these flags?" —
#       so (a) is named explicitly even though it looks like ordinary argument choice.
# ⛔ A COUNT cancels: one stale ref + one missing ref sum to the right total (see below).
# ⛔ GUARD THE WIRE READ'S OWN SUPPLY FIRST. Inside a pipeline (or a process substitution) the
#    exit status is the LAST command's — grep/awk/sort — so `ls-remote`'s 128 is DISCARDED and a
#    failed read is indistinguishable from an empty destination. Assign, CHECK, then compare.
wire=$(git ls-remote --heads --tags <destination> 2>/dev/null); rc_ls=$?
[ "$rc_ls" -ne 0 ] && halt "P16: ls-remote exited $rc_ls — the wire set is MISSING, not empty"
# ⛔ the -z guard is load-bearing: printf '%s\n' "" emits ONE BLANK LINE, which survives
#    grep -v '\^{}$' and makes a genuinely-empty destination read as 1 ref instead of 0.
if [ -z "$wire" ]; then wire_set=""
else wire_set=$(printf '%s\n' "$wire" | grep -v '\^{}$' | awk '{print $2}' | sort); fi

# ⛔ printf '%s' (no \n) DROPS the trailing newline, so the left side loses its line terminator and
#    diverges from the right on an otherwise-identical set. Emit nothing when empty, else one line
#    per ref — measured: '%s' alone false-positives on a perfectly healthy fetch.
diff <(if [ -n "$wire_set" ]; then printf '%s\n' "$wire_set"; fi) \
     <(git for-each-ref --format='%(refname)' "$QUAR" | sed "s|^$QUAR/||" | sort) \
  >/dev/null 2>&1 || halt "P16: fetch under-delivered — wire/quarantine ref SETS differ"

# ⛔ PIN the destination SHAs into the ledger BEFORE the loop. The gate above proved the input
#    existed *at the gate*; nothing holds it between the gate and its use. A ref name can vanish
#    mid-loop (a sibling run's cleanup, an interrupted process, any external deletion) while the
#    OBJECT survives — and an absent name reads as "exists only on source" ⇒ CLEAN CARRY.
#    Pinning makes the classification immune to ANY cause of ref disappearance, not just cleanup.
# ⛔ PER-RUN path + ATOMIC publish. A per-repo path is shared mutable state — exactly what pinning
#    exists to remove: a concurrent run truncates it with `>` and the loop then reads an EMPTY
#    pinned sha ⇒ the P17 misclassification returns. Measured. The quarantine is per-run; the
#    pinned FILE must inherit that isolation. `>` also truncates-then-writes, so an interruption
#    leaves a partial file — hence write-to-.tmp-then-mv (rename is atomic on one filesystem).
DST_PINNED="$LEDGER_DIR/<slug>.dst-pinned.$RUN_ID.txt"
git for-each-ref --format='%(refname) %(objectname)' "$QUAR" \
  | sed "s|^$QUAR/||" > "$DST_PINNED.tmp" && mv "$DST_PINNED.tmp" "$DST_PINNED"
# ⚠️ Do NOT "unify" this with §3.1's carry_baseline: that one is per-CUTOVER and write-once (a
#    rollback bound that must survive re-runs); this one is per-RUN (a classification input that
#    must NOT survive into another run). Different lifetimes, deliberately.

# then, PER REF, reading dst_sha from the PINNED file — never re-resolving the ref:
#   (valid ONLY once P16 passed — see the vacuous-CLEAN-CARRY note below)
git merge-base --is-ancestor <pinned_dst_sha> <src_sha>   # dst reachable from src? → fast-forwardable
git merge-base --is-ancestor <src_sha> <pinned_dst_sha>   # src reachable from dst? → destination ahead
git merge-base <src_sha> <pinned_dst_sha>                 # non-zero ⇒ DISJOINT ROOTS
# ⛔ An empty/absent pinned sha is NOT "no destination ref" — it is a MISSING MEASUREMENT (P17).

# and ALWAYS, once classified — clean ONLY THIS RUN's slice. ⛔ Never sweep the whole namespace:
# a concurrent classification's quarantine lives there and is its live input (see the TOCTOU note).
# A per-run path already makes a foreign leftover harmless, and clause 2's set-diff now SEES one.
git for-each-ref --format='%(refname)' "$QUAR" | xargs -r -n1 git update-ref -d
# then P15 — SET DIFFERENCE first (the only form that sees an unmarked contaminant).
# ⛔ Key on the EXIT STATUS, never on stdout emptiness: diff exits 1 = differences,
#    but 2 = TROUBLE (e.g. missing baseline) and on 2 stdout is EMPTY.
[ -f "$LEDGER_DIR/<slug>.src-tags-before.txt" ] \
  || halt "P15: source-tag snapshot ABSENT while classification has run — cannot verify"
diff <(git for-each-ref --format='%(refname)' refs/tags | sort) \
     "$LEDGER_DIR/<slug>.src-tags-before.txt" >/dev/null 2>&1
rc=$?; [ "$rc" -ne 0 ] && halt "P15: source tag namespace changed (diff rc=$rc)"
git for-each-ref refs/tags refs/rct/_dst | grep -q _dst   # secondary: uncleaned quarantine
```

#### ⛔ Why P15's primary clause is a SET DIFFERENCE and not a marker test

A deterministic check **must not key on a property the failure mode is defined by lacking.** Harm (1)
above is documented as *"the bare tag carries **no marker whatsoever** that it came from the
destination"* — so a trip-wire that greps for `_dst` **cannot see it**. Measured with the quarantine
path **correct** and only `--no-tags` omitted (destination genuinely ahead, so tag-following has
objects to pull):

```
* [new tag]  rel-9 -> refs/rct/_dst/tags/rel-9
* [new tag]  rel-9 -> rel-9                    ← tag-following, unprefixed
-- prescribed cleanup runs, rc=0, quarantine empty --
source refs/tags after cleanup:  rel-9  v1
marker test (grep _dst):  *** CLEAN — proceeds ***      ⛔ blind
set difference:           FIRES  (> refs/tags/rel-9)    ✅
```

The cleanup deletes `refs/rct/_dst/**` faithfully; `rel-9` was never in there. **The trip-wire written
to catch this contamination reported clean on the half documented as the more dangerous one.** This is
the same shape as the §9.0 defect one layer up — *a guard conditioned on the very thing whose absence
is the failure mode* (there: a prohibition conditioned on a classification that never happened; here: a
trip-wire conditioned on a marker the failure never produces). It is the **free-negative at the
trip-wire layer**.

The marker clause is **kept as secondary** because it catches something the diff cannot: an
**uncleaned quarantine** (`refs/rct/_dst/**` still present), which is outside `refs/tags` and so never
appears in the tag set-difference. Two clauses, two distinct failure modes; neither subsumes the other.

#### ⛔ A read-only classification must not WRITE into either side's real ref namespace

`refs/tags/<anything>` is **not** a scratch space — anything under it is a **real local tag**, not a
remote-tracking ref. Two measured harms when the quarantine is placed there (or when tag-following
is left on):

1. **Git's default tag-following creates the tag *unprefixed*.** Reproduced 2026-07-29: source with
   `v1`, destination holding its own `rel-9` (a prior partial cutover, or a peer). The fetch printed
   **both** `rel-9 -> _dst/rel-9` *and* `rel-9 -> rel-9`, leaving the source's tag list as
   `_dst/rel-9 · rel-9 · v1`. The bare `rel-9` carries **no marker whatsoever** that it came from the
   destination — so a later T1 fidelity check compares a tag set **the classifier itself
   contaminated**. `--no-tags` is what suppresses this; the refspec alone does not.
2. **The residue is pushable back.** `git push --dry-run <dst> 'refs/tags/*:refs/tags/*'` exported
   `_dst/rel-9` and `_dst/v1` as **permanent real tags** on the destination. This is not data *loss*,
   so **§9.0's property does not catch it**, and **no P1–P14 trip-wire sees it** — every one of them
   is framed around *losing* a destination commit or *mis-classifying*. This is **additive
   contamination of the source**, then exported: the classifier's own instrument damaging the thing
   it was invoked to measure, and leaving residue in a repo the cutover just took custody of.

⇒ Quarantine under `refs/rct/_dst/**` (verified: source `refs/tags` stays exactly `v1`, nothing
`_dst` inside `refs/tags`, wildcard tag push exports **0** `_dst` refs, ancestry classification
unaffected), and **delete the quarantine once classified** — the cleanup line above is not optional
hygiene, it is what keeps a re-run's classification honest.

| Per-ref ancestry result | Class |
|---|---|
| equal SHA | **ALREADY DONE** → verify only |
| destination is an ancestor of source | **CLEAN CARRY** (fast-forwardable) → standard T1 |
| source is an ancestor of destination | **INVESTIGATE** — the destination is *ahead*; never assume ownership |
| neither, **or `merge-base` finds no common ancestor** | ⛔ **SPLIT-BRAIN** → reconciliation protocol |
| ref exists only on source | **CLEAN CARRY** for that ref |
| ref exists only on destination | **INVESTIGATE** — prior partial cutover |

The repo's class is the **worst** class across all its refs (one SPLIT-BRAIN ref ⇒ the repo is
SPLIT-BRAIN). A ref-by-ref verdict is what makes `--branches '[*]'` safe: a clean branch does not
launder a divergent one.

#### ⛔ The auto-init destination is SPLIT-BRAIN, not "empty"

`gh repo create --add-readme` (and every "initialize with a README" equivalent) leaves the
destination holding **one unrelated root commit**. It is **not empty** and **not** CLEAN CARRY:
its root is **disjoint** from the source's, so by the table above it is SPLIT-BRAIN and leaves the
§7 autonomous band.

Reproduced 2026-07-29: dest `main=d8e5e15` (auto-init), source `main=c412f39` + tag `v1`.
`ls-remote` shows only *"both have `refs/heads/main`, SHAs differ, not identical"* — from which one
agent reads SPLIT-BRAIN/halt and another reads *"it's just a README, effectively empty"* ⇒ CLEAN
CARRY ⇒ **unattended push**. Same repo, same file, opposite bands, one of them autonomous. Ancestry
resolves it deterministically: neither is an ancestor, `merge-base` finds nothing ⇒ disjoint roots.

⇒ **Create the destination EMPTY** (no `--add-readme`, no license/gitignore template) when a carry
is planned. An auto-init destination is a self-inflicted SPLIT-BRAIN.

### §5.2 — ⛔ A non-fast-forward rejection is a POSITIVE SPLIT-BRAIN signal (never clear it with force)

The git push rejection (`! [rejected] ... (non-fast-forward)` / `(fetch first)`) is the **only**
safety signal that fires without any prose being obeyed — it is the strongest real safety property
in this whole flow, and the skill owns its response:

This is also what makes the **TOCTOU window** (classify → push) survivable rather than fatal: a peer
pushing between the §5.0/§5.1 read and the carry gets its work **rejected**, not force-overwritten.
That is a backstop, **not** a licence to skip a freeze — a freeze/expected-SHA lease for every class
(not just SPLIT-BRAIN) is still owed (queued).

**A rejection means the classification was wrong.** Correct response: **HALT + Impediment Report**
(§4), re-run §5.1 ancestry classification, and treat the repo as SPLIT-BRAIN until proven otherwise.
⛔ **NEVER** clear a rejection with `--force`, `-f`, `+<refspec>`, `--force-with-lease`, or
`--mirror`. The rejection is git protecting a commit that the destination would otherwise lose;
escalating past it converts a caught error into data loss.

SPLIT-BRAIN is a **distinct class**, not a harder migration: it demands per-branch merge/rebase
decisions, a dedicated red-team pass, and an explicit freeze point. It never runs on cycle 1.

## §6 — Custody ledger (amnesic re-activation)

### §6.0 — ⛔ THE LEDGER HAS AN ADDRESS (a checkpoint with no address is a promise, not a checkpoint)

⛔ **DERIVE the path — never hardcode `.git/`.** In a **linked worktree** (`[C04]` *mandates* one for
modifications) `.git` is a **file**, not a directory, so a literal `.git/maos/...` is unwritable:

```bash
# ⛔ --git-common-dir, NOT --absolute-git-dir (see below)
LEDGER_DIR="$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody"
mkdir -p "$LEDGER_DIR"

"$LEDGER_DIR/<repo-slug>.json"              # the ledger (states · tiers · verdict · impediments)
"$LEDGER_DIR/<repo-slug>.refs-before.txt"   # write-once carry_baseline — DESTINATION, rollback (§3.1)
"$LEDGER_DIR/<repo-slug>.src-tags-before.txt" # SOURCE tag snapshot — P15 set-difference (§5.1)
"$LEDGER_DIR/<repo-slug>.dst-pinned.$RUN_ID.txt" # DESTINATION ref→sha pinned pre-loop, PER-RUN + atomic — P17 (§5.1)
```

**Why `--git-common-dir` and not `--absolute-git-dir`** — measured 2026-07-29, and this is the whole
point: the **per-worktree** git-dir is **deleted when the worktree is removed**, and `maos:postflight`
removes worktrees. A ledger written there **dies at exactly the session boundary it exists to
survive** — which un-fixes the amnesic contract a second time, by a different mechanism. Proof:

| Location | After `git worktree remove` |
|---|---|
| `$(git rev-parse --absolute-git-dir)/maos/custody/…` | ⛔ **DESTROYED** |
| `$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody/…` | ✅ **SURVIVED** |

Common-dir is also where the existing convention actually lives — verified: `maos/` under the
common-dir contains `continuation-seed.latest.json`; the per-worktree dir has no `maos/` at all.

**Reuse the derivation, not the literal.** `plugin-scripts/governance/preflight-session.sh` already
documents this exact trap (*"the hardcoded `$REPO/.git/maos/...` never resolves"*) and solves it by
probing `rev-parse` — this section originally cited that script as precedent while copying its
**path** instead of its **derivation**. Same shape as the §0 hole: *the pattern was inherited, the fix
was not.* Registered via `bin/artifact-registry` when the cutover completes.

**Minimum schema** (extend freely; these keys are load-bearing):

```json
{ "repo": "<slug>", "source": "<url>", "destination": "<url>",
  "phase": 0, "phase_states": {"0":"done","1":"dispensed","2":"halted:P5"},
  "drift_verdict": "CLEAN_CARRY|SPLIT_BRAIN|INVESTIGATE|ALREADY_DONE"   // ⛔ SERIALIZED form is UNDERSCORED; the prose spells it SPLIT-BRAIN. Same verdict, two registers: hyphen in prose, underscore on the wire. Ledger consumers MUST accept only the underscored set.,
  "tiers": {"commits":"T1","pipelines":"T2","prs":"T3","secrets":"T4"},
  "carry_baseline_path": "<LEDGER_DIR>/<slug>.refs-before.txt",
  "src_tags_before_path": "<LEDGER_DIR>/<slug>.src-tags-before.txt",
  "src_tags_before_captured_at": "<iso8601+offset|null>",
  "dst_pinned_path": "<LEDGER_DIR>/<slug>.dst-pinned.<run-id>.txt",   // per-RUN, atomic-published
  "carry_baseline_captured_at": "<iso8601+offset|null>", "carry_count": 0,
  "impediments": [{"trip_wire":"P5","report":"<path>",
                   "reported_by":"<agent-id>","reported_at":"<iso8601+offset>",
                   "verified_by":"<agent-id|null>"}],
  "resume": "<one concrete next step>" }
```

#### ⛔ Provenance is a FIELD, not a reconstruction

Each impediment records **who reported it, when (ISO 8601 + offset), and who verified it**. Without
those, provenance has to be reconstructed from message logs — and reconstruction fails in the one case
that matters, because a claim inherited from a **context compaction** arrives as a **first-person
measurement** and *reads complete*.

Observed for real in this artifact's own review: a red-team's context was compacted mid-engagement and
the resumed summary had merged its identity with another agent's, so its record asserted a finding it
could not distinguish from *"I inherited a summary that said I found this"* — **carrying a sandbox path
and a target sha**, i.e. the full texture of a real measurement. That texture is precisely why such a
claim passes unchallenged.

**The distinguishing property**: the other three free-negative species surface as either a visible **gap**
or a visible **false claim**. This one **reads complete** — which is why it needs an **artifact check**,
never a suspicion. *A first-person claim inherited from a summary is a report ABOUT the past, not a
measurement OF it.*

⇒ Same move as pinning `dst_sha` before the loop instead of re-resolving it: **record the attribution at
the moment of observation** rather than deriving it later from state that may have been rewritten.
`run_id` already makes rows attributable to a *run*; these fields make them attributable to an *agent*.

**Phase-0 rule (makes resume real)**: **first** action is to read the ledger path above.
- **Exists** ⇒ **load it and resume** from `phase_states` — never re-derive from recall.
- **Absent** ⇒ you are **NOT resuming**: re-run Phase 0 read-only, and ⛔ **do not push** — an absent
  ledger means an absent `carry_baseline`, which per §3.1 means **rollback is forbidden**, which
  means the push is out of the autonomous band (§7).
- **Never enter a phase without writing its entry first** (persist-first, `harmonic` L9).

⛔ **Legacy impediments (written before provenance was a field) do NOT halt a resume.** P18 is a
**write-time** gate. An impediment already on disk with only `trip_wire` + `report` is a **MISSING
MEASUREMENT** — the same class as an absent pinned sha (§5.1), not a violation. On load:

- Treat its provenance as **`unknown`**, and ⛔ **never cite it as verified** — an unattributed
  impediment cannot carry the weight of an attributed one.
- ⛔ **Never back-fill `reported_by` / `reported_at` from recall or from message logs.** A
  reconstructed provenance **reads complete** while being invented — precisely the fourth
  free-negative species P18 exists to prevent. Absent stays absent; `unknown` is the honest value.
- **Continue the resume.** Halting here would deadlock every ledger predating the field — the same
  failure shape as v0.4.2's unwritable ledger address: a guard that forbids the operation it was
  written to protect.

Every impediment written **from this run onward** carries provenance, so the unknown set is
closed and shrinking, never growing.

*Why this is ⛔*: both red-teams landed on the same hole — §7 granted **unattended push** authority
partly on the strength of "ledger-bounded state", while the ledger had **no path and no schema**. The
resume instructions lived inside an artifact the cold agent could not locate (circular), and §9
forbids the fallback ("trust recall over the ledger"). So §3.1's *exceptional* "snapshot missing ⇒
rollback forbidden" was in fact the **default** state of every cold resume. An address fixes it;
without one, the amnesic contract is unhonorable by construction.

---

A durable per-repo record: phase states · tier assignments · drift verdict · **the write-once
`carry_baseline` (ref→sha + `captured_at`) and `carry_count`** (§3.1 — the rollback bound; a re-run
reads it, never rewrites it) · impediments raised · artifacts produced · resume instructions. It is the SSOT for "where is this cutover?" so a
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

## §9.0 — ⛔ THE UNCONDITIONAL RULE (stated as a PROPERTY, not as a list of spellings)

> **No operation may cause a destination ref to stop pointing at a commit that is still reachable
> from that destination — in ANY class, including UNCLASSIFIED.**

This is deliberately **unconditional**. The previous formulation predicated the prohibition on the
verdict *"SPLIT-BRAIN"* / *"a destination with unique refs"* — i.e. on the classification. **A
prohibition conditioned on a classification cannot protect the case where the classification
failed**, which is exactly the case that loses data. Measured 2026-07-29: an auto-init destination
was never labelled SPLIT-BRAIN, so `git push --force` destroyed its commit **without violating any
rule in this file**.

Non-exhaustive spellings of the forbidden property — the property governs, this list only helps you
recognize it (and it now includes the ones the skill itself *mandates* elsewhere, which the old
spelling-based ban missed):

| Forbidden | Note |
|---|---|
| `--mirror` | deletes every destination ref absent from the source |
| `--force` · `-f` | the canonical case |
| `+<refspec>` (leading `+`) | force, spelled differently — easy to miss in review |
| `--force-with-lease` | **still lossy under a wrong/stale lease** — not a safe alternative here |
| `--delete` · `push <remote> :<ref>` | ⚠️ the skill *requires* ref deletion on rollback ⇒ permitted **only** inside §3.1's baseline bound |
| `--prune` | deletes by omission — the silent form |
| `git filter-repo` / history rewrite | changes every hash (anti-pattern #11) |
| repointing `HEAD`/default branch to enable a deletion | §3.1 — mutates outside the baseline |

**Plus one ADDITIVE prohibition** — the property above is about *loss*, so it does not reach this;
stated separately rather than bent to fit:

| ⛔ Also forbidden | Why |
|---|---|
| `git push <dst> 'refs/tags/*:refs/tags/*'` (wildcard tag push) | exports §5.1 classifier **scratch refs** into the destination as permanent real tags — measured. Violates T1 *"byte-identical"* by adding refs present in **neither** side's true history. An **explicit-list** tag push is fine; the **wildcard** is what carries the residue. |
| a classification that writes into `refs/tags/**` or `refs/remotes/**` of either side | §5.1 — a read-only measurement must not mutate what it measures |

**The two carve-outs, and nothing else**: (a) §3.1 rollback deleting a ref **absent from the
write-once baseline**; (b) §3.1 **repo-level** rollback on an **empty** baseline. Both are
subtractive within a proven bound. Everything else ⇒ **HALT + Impediment Report**.

## §9 — Anti-patterns (do NOT)

1. ❌ **Any operation violating §9.0** — force/mirror/prune/`+refspec`/rewrite, in **any** class
   including unclassified. Conditioning this on SPLIT-BRAIN is what made it bypassable (§9.0).
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
    P1–P18 trip-wires; a gate the proceeding agent scores itself is a gate it can talk past.
14. ❌ **Unbounded rollback** — deleting destination refs without a pre-carry baseline, or deleting a
    ref that predates the carry (§3.1). The rollback then destroys what the cutover promised to protect.
15. ❌ **Re-derive the rollback baseline on a re-run** — reading it "fresh" per §5.0 on an idempotent
    replay folds the refs the previous run created into the baseline, silently degrading rollback to a
    **no-op** with no trip-wire firing (§3.1 write-once, P9). Classification is re-read every run; the
    rollback bound is read **once, ever**. Two different questions, two different freshness rules.

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

## §Vocabulary — say "probe" or "attack-path" for adversarial review

`bin/check-layer-purity` reserves one word here: the corporate name in its `\bv…r(inf)?\b` pattern
(run the checker to see it — this section deliberately does not spell it). That word is also the
most natural English term for a red-team attack-path, so the collision is structural, not
accidental: it fired **three times** while authoring this skill, each time caught only by the gate.

**Use `probe` / `attack-path` / `finding` instead.** The gate is deterministic and correct; the
vocabulary was the bug — never request an exception for it.

*(Recursive proof: the first draft of this very section tripped the gate **four times**, because it
quoted the forbidden token in order to explain it. A rule about a word must not contain the word.)*

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
| 0.5.4 | 2026-07-29 | **P18 would have deadlocked every ledger written before it** (`qodo-code-review`, PR #295 — severity-high, and correct). P18 read *"an impediment is recorded without `reported_by`/`reported_at` ⇒ HALT"* with no write-time/read-time distinction, while §6.0 orders an amnesic to **load and resume** any ledger it finds. A pre-0.5.2 ledger holds impediments with only `trip_wire` + `report` ⇒ the conservative reading halts the resume ⇒ the artifact's own continuity contract is unreachable. **The same failure shape as v0.4.2** (the ledger address unwritable in the very environment `[C04]` mandates): a guard that forbids the operation it was written to protect. **Fix**: P18 scoped ⛔ **write-time only**; §6.0 gains the read-time rule — a pre-existing impediment lacking provenance is a **MISSING MEASUREMENT** (§5.1's vocabulary, not a new one), loads as `provenance: unknown`, is ⛔ never cited as verified, is ⛔ **never back-filled from recall** (a reconstructed provenance *reads complete* while invented — the fourth species P18 exists to prevent), and does **not** halt. The unknown set is closed and shrinking, since every impediment from this run onward carries provenance. Also **rejected with evidence**: the same review flagged `T21:29-03:00` as a date-less timestamp — the date is present (`2026-07-29T21:27-03:00`); the matcher caught a substring. |
| 0.5.3 | 2026-07-29 | **A controlled probe of the WRONG SUBJECT — the free-negative committed by this artifact's own author, against its own reviewer, mid-review** (Copilot, PR #295). Two findings (trip-wire rows out of numeric order; the ledger schema mixing `<iso8601+offset>` with an undefined `<iso8601|null>` while P18 mandates the offset) were **declared hallucinated** — after a probe that ran a positive control, passed it, and was pointed at the **main checkout (v0.5.1)** instead of this PR's worktree (v0.5.2), where both existed. The control proved the instrument **reached**; nothing proved it was **aimed** at the subject under test, and a `cd <path> 2>/dev/null || cd <fallback>` idiom had silently relocated that subject when the worktree path was absent. **Both findings were real and are fixed**; the diagnostic error is the durable lesson. §5.0 gains a ⛔ **step 0 — confirm the SUBJECT before trusting the instrument** (`--show-toplevel` + `--abbrev-ref HEAD` + `worktree list`), ahead of the existing reach-control and second-instrument steps, with the fallback-idiom anti-pattern named; the closing rule becomes **all three steps** (subject → reach → instrument-class), because steps 1-2 without step 0 merely *confirm a conclusion about the wrong object*. **P2 widened** to fire on a missing subject confirmation, so the trip-wire watches all three steps rather than one. Adds `wrong-tree` to the probe checklist beside `wrong-string`, `wrong-place` and `wrong-instrument` — the fourth way a negative lies, and the only one that survives a passing control. |
| 0.5.2 | 2026-07-29 | **Provenance becomes a FIELD instead of a reconstruction** — `redteam-translatio`'s closing observation, and it was one field short of making the fourth free-negative species *impossible* rather than merely *documented*. §6.0's `impediments` recorded `trip_wire` + `report` and **nothing about who reported it**, so attribution had to be rebuilt from message logs — which fails in exactly the case that matters. ⇒ each impediment now carries **`reported_by` · `reported_at` (ISO 8601 + offset) · `verified_by`**, plus **P18** firing when they are absent. **The reasoning, which is the durable half**: a claim inherited from a **context compaction** arrives as a **first-person measurement** and *reads complete* — its own record carried a sandbox path and a target sha, the full texture of a real probe, and *that texture is precisely why it passes unchallenged*. So the fourth species has a distinguishing property the other three lack: a probe that **misses** a real thing leaves a visible gap; one that **invents** one leaves a visible false claim; one whose **report is dropped** leaves silence — but a claim whose **provenance** was corrupted **reads complete**, which is why it needs an **artifact check**, never a suspicion. *A first-person claim inherited from a summary is a report ABOUT the past, not a measurement OF it.* **Same move as pinning `dst_sha`**: record the attribution **at the moment of observation** rather than deriving it later from state that may have been rewritten — `run_id` already made rows attributable to a *run*, these fields make them attributable to an *agent*. **It also closed the corrupted SOURCE, not just my record** — it persisted the correction as a durable memory rather than letting an uncorrected working record re-assert the false claim on its next resume, noting that fixing the *consumer* leaves the *supply* defective. **That is the same asymmetry as the invitation pattern and as `n_wire`** — guard the supply — now observed a third time, on provenance. Attribution itself resolved from artifacts: the queue-empty close-out at **2026-07-29T21:27-03:00** precedes the report at **T21:29-03:00**, so the TOCTOU credit is `elenchus-2`'s and rests on timestamps rather than anyone's recall. |
| 0.5.1 | 2026-07-29 | **Two close-out refinements about the METHOD, both cheaper than the findings they arrived with.** **(1) The discriminating negative gets omitted because of how it READS**, not because anyone forgets it is needed. The positive asserts *"the guard fires on bad input"* — a visible output. The negative asserts *"the guard is **silent** on good input"* — an assertion about an **absence**, on a case where nothing is wrong, which looks like a test with no subject and is the first thing cut in review. ⇒ fixture rows now read **"asserts silence on X"**, never *"tests the X case"*, or the next writer implements the positive and calls the row done. The **peeled-tag** defect is exactly what that assertion catches and nothing else does: every positive test passed, `wire ≠ quarantine` fired correctly on real failures, and the guard still **halted every repo with a release tag** — *a green suite can hide an unconditionally-firing guard*, which then trains everyone to route around it, turning a fail-closed guard **fail-open with nobody editing it**. **(2) A FOURTH free-negative species: the finding whose PROVENANCE was lost in transit** — artifact correct, **record wrong**. It happened here: a red-team's context was compacted mid-engagement and the summary it resumed from had merged its identity with the other's, so its working record claimed a finding it *could not distinguish* from "I inherited a summary that said I found this." **It refused to claim it** — the correct move, and the same refusal-to-inflate the whole engagement ran on. Not academic: this matrix is credited **row-by-row** precisely so one can go back to the agent that produced a row and ask *what else did you see near it*. **The finding survives; the ability to mine the finder does not.** ⇒ **Resolve provenance from artifacts, never memory.** Applied: the disputed TOCTOU settles on timestamps — one agent's **queue-empty close-out (2026-07-29T21:27-03:00)** precedes the other's **report (2026-07-29T21:29-03:00)**, and a queue-empty message cannot carry a finding that arrives two minutes later ⇒ the existing credit stands. Same discipline as §6's ledger (*a cold agent resumes from artifacts, never from recall*), applied to **who found what** rather than only **what was found**. **Also verified**: `elenchus-2`'s per-slug pin-clobber report targeted `5d55a59` and was **already fixed in `0d38bef`** (same PR, later commit), live in `main` — pin path carries `$RUN_ID` (the `DST_PINNED=` assignment in §5.1), the §6.0 ledger file list, and the `dst_pinned_path` schema key. Mechanism confirmed by replay: **PER_SLUG** → A reads **B's** pin (clobber); **PER_RUN** → A reads **its own**. Its framing kept as the standing argument: every fix has been correct *about the thing it was told about* while inheriting the previous layer's unexamined assumption about **ownership of state** — invisible in a code sample, obvious in a two-process fixture. **Nine rounds of expert reading missed what a ~15-line `/tmp` fixture catches immediately.** |
| 0.5.0 | 2026-07-29 | **TOCTOU fail-open in `main`: the gate proved the input existed, nothing held it until use** (`elenchus-2`, against merged code — not a branch under review). **MINOR bump, not patch**: the per-ref loop's data source changes (pinned file, not live refs) and the cleanup's scope narrows — a behavioural contract change for any consumer. **Reproduced on the prescribed code**, two classifications in one checkout with **distinct** run-ids (no collision needed): B's clause 2 → `rc=0`, PASSES → A's **whole-tree** cleanup fires → quarantine = 0 refs → B reads `dst_sha` *at use* → `<EMPTY>` ⇒ *"exists only on source"* ⇒ ***CLEAN CARRY*** — while `cat-file -e` confirms the **destination objects are intact**. Only the *name* vanished, and the name was the input; the carry would then overwrite **live** destination refs. **Precision matters**: if the sweep lands *before* clause 2 the gate **catches** it (measured, `diff rc=1` ⇒ HALT). The window is exactly **after the gate, before the read** — a specific race, not a general "cleanup is unsafe" claim. **Two independent causes, one fix each, both applied**: **(1)** the `refs/rct/_dst` **whole-tree** sweep was insurance against the cancellation bug v0.4.6 already fixed better (per-run path ⊕ identity set-diff) and now *destroys a sibling's live input* ⇒ scoped to `$QUAR`. **(2)** *(the stronger fix, standing alone)* **pin the destination ref→sha into the ledger BEFORE the loop** (`<slug>.dst-pinned.<run-id>.txt`, `dst_pinned_path` in the schema) and read `dst_sha` from it, never by re-resolving — a ref name can vanish from **any** cause (interrupted process, external deletion, not just a sibling) while the git **object** survives. Verified: FIX A → B's quarantine survives A's cleanup, `dst_sha` readable · FIX B → pinned shas survive a **hostile whole-tree sweep**, `is-ancestor` still classifies, objects present. ⛔ **An absent pinned sha is a MISSING MEASUREMENT, never "no destination ref"** (**P17**). **Why not a prose rule** ("one classification per checkout at a time")? The artifact *anticipates* concurrency — the v0.4.7 run-id comment says so — and then shared mutable state across it. **Prose cannot hold a race any better than it held a blank line**, so the guard is in the data flow. ⇒ **P17** added; live P-range refs synced to **P1–P17**; the fixture matrix gains its **eighth** row (*two overlapping classifications, cleanup between gate and loop*). **The red-team's framing, kept**: eight rounds, eight defects, **every one found by execution and none by reading** — and this one proves the general claim twice over, since prose held neither the blank line nor the race. **HELD this round** (attacked, survived): the `<run-id>` surface I had flagged to it — it built the collision (`date +%Y%m%dT%H%M%S` twice → identical, reproducing my `date +%s` measurement) and confirmed it **fails closed** via v0.4.6's identity set-diff, then moot entirely under v0.4.7's `$$`-based id (3/3 distinct) · clause 2 correct on all four states at v0.4.9 · both P16 invariants greppable · the `n_wire` supply guard. ⚠️ **A red-team's process warning, adopted**: `elenchus-2` went idle on a **transport error** earlier, and `redteam-translatio` sharpened how that must be recorded — an agent lost mid-flight may hold **found-but-unsent** findings, which leave *no gap in the coverage table at all*. So the record says **`last pass status UNKNOWN — may hold unsent findings`**, never *incomplete*: "incomplete" implies the gap is where the silence is, and it may not be. That is the free-negative one turn further — a probe that **found** the real thing and had its report dropped in transit. `redteam-translatio` also stated its own queue **empty** to make the request symmetric. **Pre-merge PDCA on this PR added three fixes, all verified before accepting.** **(a) qodo — a RACE in the pinned file I had just added** (`Action required · Bug · Reliability`): I made the *quarantine* per-run and left the *pinned file* on a **per-repo** path — the very shared mutable state pinning exists to remove. Measured: run B pins 2 refs → run A truncates the same path with `>` → A cleans its slice and re-pins → **the file is 0 lines** → B reads `pinned_dst_sha=<EMPTY>` ⇒ **the P17 misclassification returns**. Its second point is equally right: `>` truncates-then-writes, so an interruption leaves a *partial* file. ⇒ per-run path `<slug>.dst-pinned.$RUN_ID.txt` + **atomic publish** (`.tmp` then `mv`), schema and P17 synced. ⚠️ Noted inline that this must **not** be unified with §3.1's `carry_baseline`: that is per-**cutover** and **write-once** (a rollback bound that must survive re-runs); this is per-**run** (a classification input that must **not** survive into another run). Different lifetimes, deliberately. **(b)+(c) copilot — two of my own sync errors when adding P17**: the pinned-sha note cited **P16** where P17 is meant (the table and changelog said P17; only the inline comment was stale — a wrong cross-reference makes the spec harder to implement *and* audit), and the fixture narrative still said *"nine fixtures"* while the heading, table and closing line said eight. Both fixed. **Deliberate non-change**: the v0.4.9 row also says "seven" — merged history (verified on `origin/main`), accurate when written, kept verbatim per `[C07b]`; rewriting it would falsify what was known when. **Ninth fixture row**: *two concurrent runs writing the pinned file*. |
| 0.4.9 | 2026-07-29 | **Close-out. Doc-only, and it crosses my own stop line — stated plainly.** I said *"a reachable fail-open gets fixed; another paragraph does not"*, and this **is** another paragraph. Justification, narrower than v0.4.6-8: both items are **correctness-preservation for a fix already shipped**, not new hardening, and both come from the red-teams' close-out rather than a new probe. If that reads as rationalisation, the honest summary is: I judged two specific decay risks worth one final commit, and there is no third. **(1) P16's wire set has TWO invariants, and only one was named** (`redteam-translatio`, flagged as *unverified* by it — I verified it). The peeled-line `grep` was documented; the **`--heads --tags` SCOPE was not**. Measured: a **bare** `ls-remote` also advertises `HEAD`, `refs/pull/*`, `refs/notes/*`, `refs/replace/*` — 3 lines (HEAD · main · refs/pull/7/head) vs **1** under `--heads --tags`; on a live GitHub remote **258 of 274** lines were `refs/pull/*`. Drop *either* invariant and the comparison breaks (explodes, or cancels). Its reasoning for why this needed naming is the load-bearing part: **a later simplifier is far likelier to ask "why is this `grep` here?" than "why these flags?"** — so the flags read as ordinary argument choice and get "cleaned up". Both invariants are now named inline as load-bearing, with the measurement. **(2) The seven instances are a FIXTURE SPEC, not a list of scars** — its close-out contribution, and the most actionable thing produced this engagement. Each defect maps to **exactly one constructible repo state**: marker present/absent · a **linked worktree** (`.git` as a file) · a **second run** · an **unreachable** destination · an **annotated** tag · one **stale** ⊕ one **missing** ref · two classifications in the **same second**. All seven `/tmp`-constructible, none needing a real host. ⇒ **B6's ask is not "write a verifier" but "write these seven fixtures and the verifier falls out of them."** **A red-team disclosed its own process gap** (worse, in its judgement, than the redundancy it was reporting): it attacked `5887a86` because that was the sha in my invitation and **never checked whether HEAD had moved past it** — it asked *"is the working copy this sha?"* but not *"is this sha still current?"*, half of the two-freshness-questions shape §3.1 already states. Its fix — `git log --oneline <sha>..HEAD -- <path>` before reading — and its reason for recording it: **the next red-team on this artifact inherits the same invitation pattern.** ⚠️ **Coverage, stated so the record cannot be misread**: both red-teams' CLEAR-WITH-FINDINGS verdicts cover **probes 1 and 5 only**. Probes **2/3/4/6/7 are NOT_EXAMINED by either**, and §7/§8/§9.0/§10 were never re-read past `8a0ed09`. **Do not read the verdicts as coverage.** Standing guidance unchanged: §9.0's ⛔ literal spellings **are the oracle** — if that table is ever rewritten they move to a fenced block or a data file the trip-wires read, **never into paraphrase**. PR #291 stays blocked on the operator's YARA ruling; CodeRabbit's review stays **unread** — both red-teams independently declined to route around it, on the grounds that doing so is the same escalate-past-a-rejection §5.2 forbids one layer down. |
| 0.4.8 | 2026-07-29 | **P16 guarded ONE operand of its own comparison and not the other — a reachable fail-open that SURVIVED the v0.4.6 set-diff rewrite** (`elenchus-2`). Its report targeted `7444d33` where clause 2 was still a count; I had rewritten it to a set difference in v0.4.6, so I tested whether the substance survived rather than assuming it didn't. **It did**: inside a pipeline (or a process substitution) the exit status is the **LAST** command's — `grep`/`awk`/`sort` — so **`ls-remote`'s 128 is discarded** and the stream is simply empty. Measured: unreachable destination → pipeline `rc=0`, 0 bytes ⇒ the set-diff compares **empty against empty** ⇒ ***CLEAN***. `n_quar`'s supply was protected by clause 1; **`n_wire`'s was not** — my own *guard-the-supply* doctrine applied to one operand and not the other. Exploitable path (not theoretical, and the red-team was right to insist): a partial fetch delivering **zero** refs at `rc=0` **plus** a failed wire read ⇒ empty-vs-empty ⇒ silent ⇒ vacuous loop ⇒ **CLEAN CARRY**. Those are **one root cause**, not two coincidences — a flaky or half-authenticated remote produces both. ⇒ **Fix: assign, CHECK, then compare** (`wire=$(...)`; `rc_ls=$?`; non-zero ⇒ HALT). **Two counting traps inside a three-line fix, both caught only by RUNNING it**: (a) the red-team disclosed that its *own* first version was wrong — `printf '%s\n' ""` emits **one blank line** that survives `grep -v`, so a genuinely-empty destination counted **1** instead of 0 ⇒ hence the `-z` guard; (b) my first version then inverted it — `printf '%s'` **drops the trailing newline**, so the left side lost its terminator and **false-positived on a perfectly healthy fetch** (measured: sets byte-identical, diff empty, yet my harness reported FIRES). I isolated it as a harness bug before touching the skill, then found the skill had inherited the same `printf`. Verified 5/5: unreachable → HALT · empty → silent · healthy w/ annotated tag → silent · fetch-skipped → FIRES · cancellation → FIRES. **The residual from v0.4.5 is CLOSED** — the red-team built a destination carrying `refs/notes/commits` + `refs/replace/<sha>` + a symref branch + a dangling `HEAD` + both tag kinds **at once**: `--heads --tags` excludes notes/replace from **both** sides so the universes match (`n_wire=5 = n_quar`), and `HEAD` is never counted. Notes/replace/peeled/symref/dangling-HEAD: **none** break clause 2. ⭐ **The strongest argument for B6 is not the finding — it is that the fix for the fix had a counting bug, twice, written by two agents who had just spent five rounds on precisely this failure class. Prose cannot catch a blank line.** Seven consecutive rounds in the deterministic layer's *specification*; `n_wire`'s guard belongs in **B6's spec** alongside marker-independence, baseline-integrity and supply-guard. The red-team **endorsed the Gordian stop** and asked that this be the last prose finding. |
| 0.4.7 | 2026-07-29 | **The `<run-id>` I introduced in v0.4.6 was collision-prone — self-caught immediately, while naming it as the untested surface to a red-team.** v0.4.6 fixed P16 by moving the quarantine to a per-repo+per-run path, but left `<run-id>` a placeholder with no stated provenance. Probed the obvious choice: **`date +%s` twice in a row returns the IDENTICAL value** (measured), so two concurrent classifications in one checkout would share a namespace — **re-opening the exact stale-vs-fetched contamination the per-run path exists to prevent**. `date +%s%N` is **not portable** (BSD/Darwin `date` lacks `%N`). ⇒ Fixed: `RUN_ID="$$-<8 hex from uuidgen or /dev/urandom>"` — pid ⊕ random, unique per process **and** per invocation, with a `/dev/urandom` fallback when `uuidgen` is absent. Verified **6/6 distinct within one second**. Same lesson as v0.4.5: **the defect was found in the act of writing down what I had not verified** — twice now, naming an unverified assumption to a red-team is what made it checkable. A placeholder in a safety path is an unverified assumption wearing a variable name. |
| 0.4.6 | 2026-07-29 | **P16's own fail-open: a COUNT is a signature, so two opposite errors cancel** (`elenchus-2`). ⚠️ **I declared a stop at v0.4.5 and then shipped this — stated plainly rather than quietly.** The justification, and it is narrow: v0.4.5 was *more prose about a check nothing runs* (correctly stopped), whereas this is a **reachable fail-open** in the guard added two versions ago. A fail-open outranks a self-imposed process stop; a *prose-hardening* round does not. **The defect**: P16 clause 2 compared `n_wire` to `n_quar` as **counts**, over a **fixed shared** quarantine path. A scalar discards the identities the check depends on, so a **stale** ref and a **missing** ref sum to the right total. Measured — destination A (`main`,`dev`) classified with cleanup skipped (halt/crash/forgotten line), then destination B (`main` only) in the same source checkout: quarantine holds `heads/dev` only (A's leftover; B's own `main` never arrived) ⇒ `wire(B)=1 quar=1` ⇒ ***CLEAN*** ⇒ B's `main` is absent ⇒ reads *"exists only on source"* ⇒ **CLEAN CARRY for that ref**. P16's *own* fail-open, reached through P16 — and the clause exists precisely because *"a partial fetch can exit 0"*; this **is** a partial fetch exiting 0 whose deficit is masked by unrelated residue. ⚠️ **It was not reachable in practice, and that is the whole problem**: P15's *secondary* clause happens to catch this state — a different trip-wire, in a different section, written for a different reason. **P16 did not hold the property it claimed**; remove or reorder P15's secondary and the hole opens with nothing announcing it. *A guard that only works because another guard covers it is not a guard.* ⇒ **Fixed two ways**: the comparison is now a **set difference on ref NAMES** (`dev` present and `main` absent are two distinct lines — sums cancel, identities do not), and the quarantine moved to a **per-repo + per-run** path (`refs/rct/_dst/<slug>/<run-id>`) so a leftover can never be *mistaken for* a fetched ref; cleanup still sweeps the **whole** `refs/rct/_dst` tree so a crashed earlier run's residue cannot survive. Verified 3 cases: healthy → clean · stale-from-another-run → still clean (isolated by the path) · cancellation → **FIRES**. The per-run path also promotes P15's secondary from *accidental sole guard* to genuine independent clause. **Doctrine — §4.0's own rule applied one level in**: *test for a change to a known-good **set**, not a signature of the bad thing* — **and a count IS a signature.** Sixth instance of the meta-shape: the fix pattern sat one section away in P15's primary clause and was not carried into P16's clause 2. **Method note (`redteam-translatio`, correcting my framing)**: I had written that correcting a finding downward "was the method". Narrower and right — *"enumerate the space instead of reasoning about the case"* is the method; the downgrade was a **consequence** of enumerating honestly. Same move produced an **escalation** this round: enumerating what `ls-remote` actually emits, rather than trusting two counts were comparable. **B-C closed**: its peeled-tag finding against `5887a86` was already fixed in v0.4.5 (`grep -vc '\^{}$'`) — independently found by me while writing down an unverified assumption, and independently confirmed by both red-teams. **New fidelity-declaration gap recorded** (not a safety defect): `refs/notes` is **fail-closed** in P16 (`--heads --tags` excludes it on both sides, sets agree) but sits **silently outside every tier in §2** — T1 promises *"commits · branches · tags · LFS"*, so a repo carrying notes drops them without appearing in any tier table. Also still unverified: `refs/replace`, and a destination with a `HEAD` symref oddity. |
| 0.4.5 | 2026-07-29 | **P16's count cross-check was a PERMANENT false positive on any repo with an annotated tag — self-caught by probing my own assumption instead of trusting it.** While telling a red-team that P16 was the newest unattacked surface, I flagged that its clause 2 *assumes* `ls-remote` and `for-each-ref` count the same universe, and that I had verified it only for heads+tags. Probing that assumption disproved it: **`git ls-remote` emits an extra *peeled* line per ANNOTATED tag** (`refs/tags/x` **and** `refs/tags/x^{}`) which `for-each-ref` does not. Measured on a destination with one annotated + one lightweight tag: wire **4**, quarantine **3** ⇒ P16 **HALTS on a perfectly healthy fetch**, in every repo that uses annotated tags — i.e. most real repos. ⇒ **Fix: mandatory `grep -vc '\^{}$'`** on the wire count; verified healthy → `3=3` **silent**, failed fetch → `3≠0` **still fires** (the fail-open fix is intact). **New doctrine — a comparison guard must compare the SAME universe, or it is a permanent false positive**: *a trip-wire that fires unconditionally is worse than no trip-wire*, because it trains the operator **and the agent** to route around it — the rubber-stamp fatigue §6's proportionality floor exists to prevent. When a check compares two counts, **prove both sides enumerate the same universe before trusting the comparison**; two instruments naming the same thing rarely enumerate it identically. This is the free-negative's mirror image: not a probe that misses a real thing, but a probe that **invents** one. **Honest residual, flagged rather than glossed**: verified for `refs/heads` + `refs/tags` (incl. annotated/peeled); **not** verified for `refs/notes`, `refs/replace`, or a destination with a `HEAD` symref oddity. Method note worth keeping: this defect was found in the act of **writing down what I had not verified**. Naming the unverified assumption out loud — in a message to a red-team, as a courtesy — was what made it checkable. |
| 0.4.4 | 2026-07-29 | **The only FAIL-OPEN found in this artifact, plus the two preconditions the P15 inversion silently imported.** Three BLOCKING from two independent red-teams, all reproduced before acceptance. **(1) P16 — a FAILED §5.1 fetch was indistinguishable from a CLEAN CARRY** (`redteam-translatio`; found by *enumerating* the exit space rather than reasoning about it). §5.1 checked `merge-base`'s exit but **nothing checked the `fetch`'s** — the operation that supplies every SHA `merge-base` compares. Measured against a **non-empty** destination so no existing guard fires: `ls-remote` → 1 ref (P7 silent, the read was genuinely fine) · fetch → **exit 128** (wrong path / auth expiry / `[C19]` 404) · quarantine → **0 refs** · per-ref loop iterates **0** · `merge-base` invoked **0** times · worst-ref-class over an empty set is **vacuous** ⇒ every source ref matches *"exists only on source"* ⇒ **CLEAN CARRY on the autonomous path**. P7 is scoped to §5.0's read; P11 cannot distinguish *"ran over the refs and found none divergent"* from *"had no refs to run over"*; P12 never executes. ⇒ **P16, two clauses** (both needed — a partial fetch can exit 0): fetch exit non-zero ⇒ HALT · quarantine ref count ≠ §5.0 wire count ⇒ HALT. Verified discriminating: failure → `wire=1 quar=0` **fires**; success → `1=1` **silent**. **New doctrine — guard the SUPPLY of a measurement, not only its RESULT**: *a check that never RAN is not a check that PASSED*; **an empty input set is `unknown`, never "nothing to worry about"** — when the input is *missing* rather than *empty*, every per-ref predicate is **vacuously satisfied** and the classifier emits its **most permissive** verdict with total confidence. **(2)+(3) The P15 inversion was not free** (`elenchus-2`) — §4.0's new rule (*test for a delta, not a signature*) is right, but **a signature test needs nothing while a delta test needs a baseline that EXISTS and is TRUSTWORTHY**, and both were unguarded: **(2)** `diff` exits **2** on a missing baseline with **empty stdout**, so the clause phrased *"non-empty ⇒ HALT"* read ***CLEAN on a contaminated source*** (measured: tags `rel-9 v1`, `rc=2`, 0 bytes out) — and the secondary `_dst` clause could not help, because the quarantine **had** been cleaned faithfully. This is conditional-compliance one turn further: **P15 is the layer for when §5.1's prose isn't obeyed, yet its primary clause required that §5.1's snapshot line WAS obeyed** — partial compliance is exactly the state it exists to catch. ⇒ key on the **exit status**, and make **absence its own halt clause**, mirroring what P3/P14 already do for the ledger. **(3)** the source snapshot was **re-derivable**, so the halt **launders on a plain phase re-run**: measured — run 1 fires correctly; run 2 re-takes the snapshot over contaminated state, folding `rel-9` **into** the baseline, and reports ***CLEAN*** while the source still carries it, **without the agent doing anything the file forbade**. ⇒ **write-once + load-never-re-derive**, exactly as §3.1's `carry_baseline`; `src_tags_before_captured_at` added to the schema. Verified: run 2 now reuses the baseline and **still fires**. **+ The two-freshness-questions table gains a THIRD row** — *"what did the **source's** tag namespace hold before my **classifier** touched it?"* → **first-touch truth, re-read never**. That table is where the file declares which reads are per-run and which are once-ever, so omitting the row is what let the re-derivation look legal. **⭐ The meta-lesson, now on its FOURTH instance**: §3.1 had **already solved both halves** of baseline-integrity for the destination, one section up — *and the fix was not carried across when the same shape reappeared for the source*. Same as §0-vs-`council-gate`-§0, v0.4.0's own fetch refspec, and §6.0's literal-path-vs-derivation. **The pattern gets inherited; the fix has to be carried deliberately.** When you invert a check, ask what the **new** form requires that the old one did not. **A red-team DOWNGRADED its own prior finding**: P12's exit-128 ambiguity (issue #292) — it enumerated the space (`merge-base`: 0/1/128, `129` on one arg; `--is-ancestor`: 0/1/128) and confirmed 128/129 collapse into DISJOINT ⇒ **over-halts** ⇒ fail-**closed**, the direction §4 already prescribes; *no input yields CLEAN CARRY from a broken `merge-base`*. So **BLOCKING → MINOR**: the ambiguity is real but the consequence is safe — it degrades an Impediment Report's *"root cause with PROBED evidence"* into an **assumption wearing probed clothing** (reporting "disjoint roots" when the truth was a bad object). #292 re-labelled diagnosis-quality, not safety. It corrected a finding *downward* unprompted; recorded because that calibration is what makes the rest of its report load-bearing. **Also HELD, reported as non-findings** (each attacked, none inflated): §3.1 write-once baseline is independent of the quarantine, so the tag contamination cannot reach it · the `xargs -r` cleanup is correct as written · rollback-mode-by-emptiness unchanged · the B6 honesty edit matches what ships (independently re-verified: `ls-tree` returns `SKILL.md` alone, control reaches `bin/`) · P11–P14 vs auto-init survived a second discriminating-control run · P15's two clauses confirmed **non-subsuming in both directions**. **Standing**: B3/B4/B5/B7 + MINOR-1/-3 — *no new evidence produced this pass and not re-asserted as if there were*. Both red-teams also **declined to route around the YARA block** to read PR #291, unprompted, on the grounds that reading a blocked artifact through a side channel is the same escalate-past-a-rejection §5.2 forbids one layer down. |
| 0.4.3 | 2026-07-29 | **P15 — the trip-wire written to catch the v0.4.1 contamination was BLIND to the half documented as more dangerous** (`elenchus-2` re-attacking `29e951d`). P15 was specified mechanically as `git for-each-ref refs/tags refs/rct/_dst \| grep -q _dst` — **a marker test**. But §5.1's own prose says of harm (1): *"the bare tag carries **no marker whatsoever** that it came from the destination."* So P15 could not see it. Reproduced with the quarantine path **correct** and only `--no-tags` omitted (destination genuinely ahead, so tag-following has objects to pull): the fetch printed `rel-9 -> refs/rct/_dst/tags/rel-9` **and** `rel-9 -> rel-9`; the prescribed cleanup ran `rc=0` and emptied the quarantine faithfully — `rel-9` was never in it — leaving source tags as `rel-9 · v1`, and **P15 reported *CLEAN, proceeds***. The source then carries a destination-origin tag into the §2 T1 comparison (*"byte-identical, verifiable"*). **Why BLOCKING and not minor**: `--no-tags` is prescribed and load-bearing, so an agent obeying §5.1 verbatim is safe — **P15 is the layer that exists for when it is not obeyed**, and §4's whole claim is a layer that fires *without any prose being obeyed*. A trip-wire that only fires when the prose **was** obeyed fails its own layer's contract. ⇒ **Fix: P15's primary clause is now a SET DIFFERENCE**, not a pattern match — snapshot the source's tag namespace **before** the §5.1 fetch (`$LEDGER_DIR/<slug>.src-tags-before.txt`, a **source**-side snapshot, distinct from §3.1's **destination** `refs-before.txt`), then `diff` after cleanup; any delta ⇒ HALT. The `_dst` grep is **kept as secondary** because it catches what the diff cannot see: an **uncleaned quarantine** under `refs/rct/_dst/**`, which lives outside `refs/tags` and so never appears in the tag delta. Two clauses, two failure modes, neither subsuming the other. Verified discriminating: `--no-tags` omitted → set-diff **FIRES** (marker clean); `--no-tags` present → **both clean** (not a trip-wire that shouts unconditionally). **+ New §4.0 design rule, because this is the THIRD instance of one shape** — *never key a deterministic check on a property the failure mode is defined by LACKING*: the force-push ban was conditioned on the verdict **SPLIT-BRAIN** (a case the classifier never labelled) · §0's never-skippable list was conditioned on gates being **listed** (the two ⛔ gates that weren't) · P15 was conditioned on a **marker** the failure never produces. Each guard's trigger required the very thing whose absence *was* the bug. Remedy stated as doctrine: test for a **change to a known-good snapshot**, not for a **signature of the bad thing** — *a contaminant that refuses to identify itself is only visible as a delta*. This is the **free-negative at the trip-wire layer**, one level above where §5.0/§5.1 put it. **Also probed and HELD** (the red-team went looking and reported the non-finding): BSD `xargs -r` on Darwin is undocumented (`xargs --version` → unrecognized) but works — `printf '' \| xargs -r -n1 git update-ref -d` → `rc=0`, zero invocations. The §5.1 cleanup line is portable here. **Guidance recorded for the pending §9.0/YARA rewrite**: ⛔ do **not** replace the literal spellings with descriptions — `refs/tags/*:refs/tags/*` and P13/P15's greppable strings **are the oracle**; describe-don't-spell would convert mechanically-checkable predicates into prose requiring interpretation, which is the salience gap §4 exists to escape. If the pattern must leave §9.0's table it should move to a fenced non-executable block or a data file the trip-wires read — never evaporate into paraphrase. |
| 0.4.2 | 2026-07-29 | **The ledger address was unwritable in the very environment `[C04]` mandates — a DEADLOCK, and the second time the amnesic contract was un-fixed by a different mechanism** (`redteam-translatio` re-attacking `d6fbc4b`). §6.0 fixed the address as the literal `.git/maos/custody/<slug>.json`. In a **linked worktree** `.git` is a **file**, not a directory — verified in this very worktree: `file .git` → `ASCII text`, contents `gitdir: …/.git/worktrees/rct-ancestry`, and `mkdir -p .git/maos/custody` → **`Not a directory`**. Since `[C04]` *mandates* a worktree for modifications, the ledger was unwritable exactly where the corpus requires the work to happen; **P14** ("ledger absent while a push is contemplated ⇒ HALT") then fires **unconditionally, forever**. Fail-closed, so no data loss — a **deadlock**: worktree required ⇒ ledger required to push ⇒ ledger unwritable in a worktree. ⇒ **Fix: DERIVE, never hardcode** — `LEDGER_DIR="$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody"`, verified executing verbatim from inside this linked worktree (resolves to the common-dir, `mkdir` succeeds, write succeeds, P14 no longer deadlocks). **⛔ `--git-common-dir`, NOT `--absolute-git-dir`** — and this distinction is the finding's real teeth: the **per-worktree** git-dir is **deleted when the worktree is removed**, and `maos:postflight` removes worktrees, so a ledger there **dies at exactly the session boundary it exists to survive**. Measured both: after `git worktree remove`, per-worktree ledger **DESTROYED**, common-dir ledger **SURVIVED**. Common-dir is also where the cited precedent actually lives (verified: `maos/` under the common-dir holds `continuation-seed.latest.json`; the per-worktree dir has no `maos/` at all). **Root-cause note**: `plugin-scripts/governance/preflight-session.sh` **already documents this exact trap** (*"the hardcoded `$REPO/.git/maos/...` never resolves"*) and solves it by probing `rev-parse` — §6.0 cited that script as precedent while copying its **literal path** instead of its **derivation**. Third instance this artifact of the same meta-failure: *the pattern was inherited, the fix was not* (cf. §0's escape clause vs `council-gate` §0, and v0.4.0's own fetch refspec). **+ Honesty edit to §4.0**: the header claimed the PRIMARY trip-wires are *"deterministic · `f=0`"*. Verified overstated — `git ls-tree -r HEAD -- skills/repo-custody-transfer/` returns **`SKILL.md` alone** (positive control: the same instrument reaches `bin/artifact-registry`, `bin/check-layer-purity`), so **nothing ships that runs them**: execution is agent-performed and "did P2's positive control fail?" is unfalsifiable from outside. Re-scoped to *"mechanically checkable · deterministic in **specification**, self-reported in **execution**"*, with the gap named as **B6** (a `bin/` verifier emitting machine-readable P-table verdicts) rather than papered over. Materially better than a judgement call — named, uniform, ledger-auditable predicates — but **not** an `f=0` gate the way `check-layer-purity`/`convergence-guard` are, and the file now says so. **What survived this pass**: `redteam-translatio` ran §5.1's commands against a real auto-init destination and confirmed **P11–P14 cover it** — `is-ancestor` both ways exit 1, `merge-base` exit 1 ⇒ DISJOINT ⇒ P12 ⇒ SPLIT-BRAIN — **with a discriminating control** (a genuinely fast-forwardable pair → both exit 0 ⇒ CLEAN CARRY), so the classifier is not trivially returning SPLIT-BRAIN for everything. That was the part it could not break. **Attribution, corrected at the red-team's own insistence**: I had called its report "the highest-value input this artifact received"; it pushed back that `elenchus-2` found the root defect and it had missed one reachable from what it read. Its generalization is worth keeping as doctrine: **reading an artifact finds contradictions in what it says; running it finds contradictions between what it says and what the tools do.** Different defect classes — this artifact needed both passes, and every fix from v0.4.0 onward came from one or the other. |
| 0.4.1 | 2026-07-29 | **§5.1's own fetch refspec was contaminating the SOURCE — a defect introduced BY the v0.4.0 fix** (`elenchus-2`, re-attacking `d6fbc4b`; the one line nobody had probed). v0.4.0 prescribed `'+refs/tags/*:refs/tags/_dst/*'`. The branch half was fine (`refs/remotes/_dst/*` = quarantine); **the tag half wrote into `refs/tags/`, which is not a scratch space** — anything there is a **real local tag**. Reproduced verbatim: source `v1`, destination holding its own `rel-9`; the fetch printed **both** `rel-9 -> _dst/rel-9` *and* `rel-9 -> rel-9`, leaving the source's tags as `_dst/rel-9 · rel-9 · v1`. Two measured harms: **(a)** git's default **tag-following** created the bare `rel-9` with **no marker at all** that it came from the destination ⇒ a later T1 fidelity check compares a tag set **the classifier itself contaminated** (`--no-tags` suppresses this; the refspec alone does **not**); **(b)** the residue is **pushable back** — `git push --dry-run <dst> 'refs/tags/*:refs/tags/*'` exported `_dst/rel-9` + `_dst/v1` as **permanent real tags** on the destination. **Why it slipped every existing guard**: §9.0's property is about a destination ref *losing* a reachable commit, and all of P1–P14 are framed around *loss* or *mis-classification* — this is **additive contamination of the source**, then exported. Neither the property nor a single trip-wire could see it. ⇒ **Fix** (verified on four axes): `git fetch --no-tags` + quarantine under `refs/rct/_dst/**` (outside both `refs/tags/` and `refs/remotes/`) + a **mandatory cleanup** (`for-each-ref … | xargs -r -n1 git update-ref -d`) once classified — measured after the fix: source `refs/tags` stays exactly `v1`, zero bare `rel-9`, zero `_dst` inside `refs/tags`, wildcard tag push exports **0** `_dst` refs, ancestry classification unaffected. **New doctrine** (stated alongside EXISTENCE-vs-UNIQUENESS, because it is the same error one level down): **a read-only classification must not WRITE into either side's real ref namespace.** **+ §9.0 gains an ADDITIVE prohibition table** (kept separate rather than bending the loss-property to fit): ⛔ wildcard tag push `refs/tags/*:refs/tags/*` (an **explicit-list** tag push is fine — the *wildcard* is what carries the residue) · ⛔ any classification writing into `refs/tags/**`/`refs/remotes/**`. **+ P15** (a `_dst` leftover in a real namespace or an uncleaned quarantine, at classification **or** push time). Also from the same pass: **§5.0's positive control is now explicitly same-instrument-same-tree FIRST**, with the second instrument as the *escalation* — plus the note that *a control which switches instruments is not a control* (it sidesteps the suspect condition and passes while the real query still lies), per `environment-capability-reconnaissance` §1.1.1(iv) · **§5.2 now records that it makes the classify→push TOCTOU survivable, explicitly NOT a licence to skip a freeze** (a peer's push gets *rejected*, not force-overwritten — which is why `elenchus-2` downgraded that finding from BLOCKING to MINOR; the per-class freeze/expected-SHA lease is still owed) · **citation corrected**: `council-gate` §5.3 lives in the **rule** (`~/.claude/rules/council-gate.md:170`), not the skill — verified, the skill merely cites it. **Attribution corrected**: v0.4.0 credited `elenchus-2` alone for the "a prohibition conditioned on a classification cannot protect the case where classification failed" reasoning; `redteam-translatio` reached it **independently** (its B2). Joint attribution — two independent arrivals is stronger evidence than one, and the record should say so. **Method note worth keeping**: `elenchus-2`'s first probe of this revision landed in the **wrong tree** (a `cd … \|\| cd main-repo` fallback silently put it on `main`, where all 8 markers read absent) and its **same-instrument positive control caught it** — the third time this engagement that the §4 rule caught a red-teamer's own false negative. Evidence *for* the rule, from the people attacking the artifact that contains it. |
| 0.4.0 | 2026-07-29 | **TWO INDEPENDENT RED-TEAMS delivered; 5 fixes, 3 of them closing a live data-loss path.** ⚠️ **Retraction first**: v0.3.0's method-note said the red-team "did not deliver" and that P8 stood unmet. **Both reported** (`redteam-translatio`: CLEAR-WITH-FINDINGS, 8 blockers; `elenchus-2`: probe-1 REFUTED, 3 defects). That note was wrong at the time of writing and is corrected here — the independent pass exists, and it found what self-red-teaming had not. **(1) §5.1 ancestry classification (the root defect, `elenchus-2`)** — §5 classified on *"both sides have **unique** commits"*, which is an **ancestry** question, while §5.0 prescribed `git ls-remote`, which returns **ref→sha only**. `grep` confirmed **zero** hits for `merge-base`/`is-ancestor`/`git fetch` in the whole artifact ⇒ the agent was told to derive a verdict its prescribed instrument **cannot produce**, and the failure is *silent* (differing SHAs are equally consistent with fast-forwardable and with disjoint roots). Now: fetch objects, classify **per-ref** with `merge-base --is-ancestor`, repo-class = **worst** ref-class (a clean branch cannot launder a divergent one — this is what makes `--branches '[*]'` safe). **`ls-remote` establishes EXISTENCE, never UNIQUENESS.** **(2) The auto-init destination is SPLIT-BRAIN, not "empty"** — `gh repo create --add-readme` leaves **one unrelated root commit**. Reproduced end-to-end: dest `main=d8e5e15`, source `main=c412f39`+`v1`; `ls-remote` shows only *"both have main, SHAs differ"*, from which one agent reads halt and another reads *"just a README, effectively empty"* ⇒ CLEAN-CARRY ⇒ **unattended push**. Same file, opposite bands, one autonomous. Then the §3.1-compliant explicit-refspec push was **rejected** (git's non-FF backstop — the strongest real safety property in the flow) and `--force` **destroyed the destination commit without violating any rule in this file**, because the case was never labelled SPLIT-BRAIN. **(3) §9.0 the unconditional rule, restated as a PROPERTY** (both red-teams) — *no operation may cause a destination ref to stop pointing at a commit still reachable from that destination, in **any** class **including unclassified***. The old ban was predicated on the *verdict*, and **a prohibition conditioned on a classification cannot protect the case where classification failed** — which is precisely the case that loses data. The spelling table now includes what the old one missed: `--delete`, `:<ref>`, `--prune`, `--force-with-lease` (lossy under a stale lease) — including the deletion the skill itself **mandates** on rollback, now permitted only inside §3.1's baseline bound. **(4) §0 can no longer route around the safety floor** (both red-teams, independently) — §5.0/§3.1 declared themselves ⛔ in their own headings yet were **absent from the never-skippable list**, so the entire fix for both v0.2.0 BLOCKING holes was skippable by §0; worse, skipping §5 meant nothing was ever *classified* SPLIT-BRAIN, disarming the one force rule that **was** listed. §0 is now **presentation-only**: a skipped safety gate does not become "passed", it sets its conjunct **`false`** ⇒ class degrades to INVESTIGATE ⇒ leaves the autonomous band ⇒ HITL (the shape `council-gate` §0 already hardened — pattern inherited, fix had not been). **(5) §6.0 the ledger has an ADDRESS** (both red-teams; the one gating production for both) — §7 granted **unattended push** authority partly on "ledger-bounded state" while the ledger had **no path and no schema**; the resume instructions lived inside an artifact the cold agent could not locate (circular), and §9 forbids the recall fallback ⇒ §3.1's *exceptional* "no snapshot ⇒ rollback forbidden" was the **default** state of every cold resume. Now `.git/maos/custody/<slug>.json` + `.refs-before.txt`, reusing the **existing** convention (`.git/maos/continuation-seed.latest.json`, verified present and written by `preflight-session.sh`) — not a new one — plus a minimum schema and a Phase-0 load-or-restart rule. **+ §5.2**: a non-FF rejection is a **positive SPLIT-BRAIN signal** ⇒ HALT, ⛔ never cleared with force. **+ P11–P14** deterministic trip-wires (class-without-ancestry · disjoint-root/auto-init · non-FF-returned · ledger-absent-while-pushing); P1–P10 → **P1–P14**. Verified: the exploit that destroyed a commit at v0.3.0 now classifies **SPLIT_BRAIN** and leaves the autonomous band. **Honest residue**: `elenchus-2` examined only vectors 1+5 (2/3/4/6/7 NOT_EXAMINED by it); `redteam-translatio` covered 1–7 but read the file rather than running a cutover, and its 4 unverified items are excluded from these fixes. Its B3 (T3 extraction needs a fail-closed gitleaks scrub), B4 (protections arrive one phase after history — `[C18]` explicitly does **not** supply ref protection), B5 (no freeze for CLEAN CARRY ⇒ coexistence manufactures divergence), B6 (no deterministic PRIMARY layer beyond P1–P14) and B7 (`council-gate` ships UNARMED ⇒ "council-gated" means consultative-with-human-confirm, not autonomous authorization) are **queued, not silently patched** — they gate anything beyond a pilot. Also honored: both red-teams' free-negative discipline caught their own false negatives mid-review, which is evidence **for** the §4 rule, not against it. |
| 0.3.0 | 2026-07-29 | **§3.1 write-once `carry_baseline` + rollback-mode selection (BLOCKING, self-red-teamed).** Two more data-loss holes in the UNATTENDED band, both found by *executing* the artifact's own rules in a sandbox rather than re-reading them. **(1) The idempotence × freshness contradiction (P9/P10, anti-pattern #15)** — §3 promises Phase 2 is "re-runnable to convergence" and §5.0 forbids "a cached/earlier read"; applied together to the v0.2.0 snapshot rule they *force* a re-run to re-derive the snapshot, which then already contains the refs the previous run created ⇒ rule-3 puts them permanently out of rollback scope ⇒ **rollback silently degrades to a no-op** and "point of no return = Phase 4 only" becomes false — with **no trip-wire firing**, because a snapshot *does* exist, it is merely the wrong one. Reproduced: run #1 baseline `{peer}` → `DELETE main / KEEP peer` (correct); run #2 re-derived `{peer,main}` → `KEEP` both. Fixed by splitting the two freshness questions that were conflated under one word: *"what is the drift now?"* (classification — re-read **every** run) vs *"what did the destination hold before I touched it?"* (rollback bound — read **once, ever**). The baseline is now write-once + immutable, `captured_at`-stamped, ledger-persisted, reused verbatim on replay; P9 catches a re-derived baseline mechanically, P10 catches `carry_count > 0` with the baseline gone (reversibility already forfeited — halt, never proceed as if reversible). **(2) Ref deletion is not universally available** — the fix's own verification run then failed on the *real* rollback: a host refuses to delete the ref `HEAD`/the default branch points at. Measured both cases: **non-empty** baseline → `HEAD` rests on a baseline ref, carried refs delete cleanly; **empty** baseline → the carried ref *becomes* the default branch and `--delete` is **rejected** (exactly the pilot's shape). So the baseline's emptiness now *selects the mode*: empty ⇒ repo-level (delete the destination — zero collateral by definition, P7 second-instrument confirmation required first); non-empty ⇒ ref-level subtractive. ⛔ **Never repoint `HEAD` to force a deletion** — it mutates state outside the baseline (and can leave a dangling `HEAD`), which is the §3.1 violation rather than a workaround; if neither mode applies, the carry is **not reversible by this skill** ⇒ HALT + Impediment Report naming the residual state. Also: `carry_baseline`/`carry_count` added to the §6 ledger contract; Phase-2 rollback cell now states both modes; P1–P8 → **P1–P10**. Method note: **all four BLOCKING fixes so far (v0.2.0's two and v0.3.0's two) were found by the author, not by an independent party** — each by *executing* the rules in a sandbox rather than re-reading them, since a rule that reads coherent can still be incoherent when run, and a sandbox is the only honest verifier of a reversibility claim. An independent red-team (Elenchus) was dispatched and did **not** deliver; vectors 2/3/4/6/7 therefore remain **without independent review**. That gap is recorded rather than papered over: self-red-teaming found real defects but it shares the author's blind spots by construction, so it does **not** satisfy the §7 `verifier > generator` independence requirement for Phase 4 (P8 still stands, unmet). |
| 0.2.0 | 2026-07-29 | **Red-team hardening (pre-merge PDCA, PR #289)** — 3 defects closed, 2 of them BLOCKING data-loss holes in the UNATTENDED band, each refuted EMPIRICALLY (sandbox reproduction) rather than by opinion. **(1) §5.0 FRESHNESS PRECONDITION ⛔** — `grep` proved the artifact had ZERO mentions of fetch/fresh/stale: the drift-detector never required same-run wire truth. Reproduced: an observer holding remote-tracking refs from an earlier clone does not see a branch a peer pushed afterwards ⇒ destination reads empty ⇒ CLEAN-CARRY ⇒ §7 authorizes an unattended push at live peer work. Now both sides re-read via same-run `ls-remote` + a positive control, and a missing wire read HALTS instead of defaulting to CLEAN-CARRY. **(2) §3.1 SUBTRACTIVE-ONLY rollback ⛔** — the Phase-2 rollback ("delete the pushed refs") could not distinguish a ref it created from one that predates the carry, making the *rollback itself* a data-loss event on any non-empty destination. Now: snapshot ref→sha before pushing · delete only refs absent from the snapshot · a snapshotted ref is permanently out of rollback scope · no snapshot ⇒ rollback forbidden ⇒ no-push. **(3) §4.0 PRIMARY trip-wires P1–P8** — the Blocking-Gate trigger was self-scored by the agent that wants to proceed (the self-exemption gradient); now deterministic `f=0` trip-wires HALT regardless of confidence, with judgement only *widening* coverage and uncertainty treated as fired (fail-closed). §7's autonomous band is conditioned on §5.0 ∧ §3.1 both holding. Also from bot PDCA: `bin/artifact-registry` (a CLI, not `maos:`) · `legacy-archaeologist` is an **agent** (caught by verifying the bot's adjacent finding, unreported by any bot) · description 1753→985 chars · new **§0.1 Requirements** with per-dependency absent-behavior (hard-stop vs degrade-to-GAP vs warn). One Qodo finding REJECTED with evidence (`resolve-session.sh` belongs to `session-reentry`, not here). **Probe 5b SURVIVED and is recorded as surviving** — the 4-branch drift classification is total + disjoint over a binary predicate pair, so two independent agents converge; no fix manufactured. Bots: CodeRabbit APPROVED · amazon-q no-blocking-defects · 7/7 checks SUCCESS. |
| 0.1.0 | 2026-07-29 | Bootstrap — forged from a real 9-repo Bitbucket-Cloud→GitHub cutover need. Named by `anima`: system-name `repo-custody-transfer`, soul-name **Translatio** (12/12; rejected `git-host-migration` — "migration" is the false promise the tool refuses). Design decisions: **carry-then-rename** (any repo-rename program runs AFTER a clean cutover — lower impact) · Blocking-Gate + Impediment Report as a first-class capability · autonomy-max with council-before-HITL. Ships the fidelity contract (T1/T2/T3/T4), the 5-phase reversible cutover, the drift-detector (SPLIT-BRAIN class), the custody ledger, and the §8 composition map. Residue scripts (extractor/archiver · pipeline translator · ledger CLI · drift CLI) deferred until a real cycle demands them (Gordian/YAGNI). **Empirical grounding**: drift-detect found bidirectional divergence in 3 of 9 repos (a `--mirror` would have destroyed 11+10 commits and 10 tags); a positive control disproved a self-fabricated `admin:org` impediment; T3 archival validated via a host API gateway with a positive control. 6/6 §10 + 8/8 anti-theater + 6/6 scope-discipline. PR `ekson73/multi-agent-os#289`. |
