---
name: repo-custody-transfer
version: "0.4.2"
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
(§4, incl. the P1–P15 trip-wires) · **§5.0** freshness · **§5.1** ancestry classification · **§5.2**
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

Therefore the two freshness questions are **distinct and must not be conflated**:

| Question | Needs | Source |
|---|---|---|
| "What is the drift **right now**?" (classification, §5) | **current** truth | same-run `ls-remote` — re-read every run |
| "What did the destination hold **before I touched it**?" (rollback bound, §3.1) | **first-touch** truth | the write-once `carry_baseline` — re-read **never** |

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
| P2 | drift classification derived without a same-run wire read, or a §5.0 positive control that FAILED |
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
| P15 | a ref matching `refs/tags/*_dst*`, `refs/tags/_dst/**` or any `refs/rct/_dst/**` leftover exists at classification time or push time — the classifier contaminated a real namespace, or its quarantine was never cleaned (§5.1). Mechanically: `git for-each-ref refs/tags refs/rct/_dst \| grep -q _dst` |

Any P1–P15 true ⇒ **HALT + Impediment Report**, no discretion. Cheap to check, impossible to
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

1. **Same instrument, same tree.** Re-run the *same* `ls-remote` against a ref you **know** exists
   (a control repo you can reach). If the control **also** returns empty, the instrument is lying —
   ⛔ do **not** classify; re-probe with a reaching instrument. *A control that switches instruments
   is not a control*: it sidesteps the suspect condition and passes while the real query still lies.
2. **Only then**, if the control passed and the destination is still empty, escalate to a **second
   instrument** (a repo-exists API call) to distinguish *absent* from a `[C19]` 404-masquerade.

An empty result is `unknown`, **never** `no refs`. Both steps are required before any classification.

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
# ⛔ --no-tags is load-bearing, and the quarantine MUST be outside refs/tags/ and refs/remotes/
git fetch --no-tags <destination> \
  '+refs/heads/*:refs/rct/_dst/heads/*' \
  '+refs/tags/*:refs/rct/_dst/tags/*'
# then, PER REF:
git merge-base --is-ancestor <dst_sha> <src_sha>   # dst reachable from src? → fast-forwardable
git merge-base --is-ancestor <src_sha> <dst_sha>   # src reachable from dst? → destination is ahead
git merge-base <src_sha> <dst_sha>                 # non-zero ⇒ DISJOINT ROOTS
# and ALWAYS, once classified:
git for-each-ref --format='%(refname)' refs/rct/_dst | xargs -r -n1 git update-ref -d
```

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

"$LEDGER_DIR/<repo-slug>.json"            # the ledger (states · tiers · verdict · impediments)
"$LEDGER_DIR/<repo-slug>.refs-before.txt" # the write-once carry_baseline (ref<TAB>sha), §3.1
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
  "drift_verdict": "CLEAN_CARRY|SPLIT_BRAIN|INVESTIGATE|ALREADY_DONE",
  "tiers": {"commits":"T1","pipelines":"T2","prs":"T3","secrets":"T4"},
  "carry_baseline_path": "<LEDGER_DIR>/<slug>.refs-before.txt",
  "carry_baseline_captured_at": "<iso8601|null>", "carry_count": 0,
  "impediments": [{"trip_wire":"P5","report":"<path>"}],
  "resume": "<one concrete next step>" }
```

**Phase-0 rule (makes resume real)**: **first** action is to read the ledger path above.
- **Exists** ⇒ **load it and resume** from `phase_states` — never re-derive from recall.
- **Absent** ⇒ you are **NOT resuming**: re-run Phase 0 read-only, and ⛔ **do not push** — an absent
  ledger means an absent `carry_baseline`, which per §3.1 means **rollback is forbidden**, which
  means the push is out of the autonomous band (§7).
- **Never enter a phase without writing its entry first** (persist-first, `harmonic` L9).

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
    P1–P15 trip-wires; a gate the proceeding agent scores itself is a gate it can talk past.
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
| 0.4.2 | 2026-07-29 | **The ledger address was unwritable in the very environment `[C04]` mandates — a DEADLOCK, and the second time the amnesic contract was un-fixed by a different mechanism** (`redteam-translatio` re-attacking `d6fbc4b`). §6.0 fixed the address as the literal `.git/maos/custody/<slug>.json`. In a **linked worktree** `.git` is a **file**, not a directory — verified in this very worktree: `file .git` → `ASCII text`, contents `gitdir: …/.git/worktrees/rct-ancestry`, and `mkdir -p .git/maos/custody` → **`Not a directory`**. Since `[C04]` *mandates* a worktree for modifications, the ledger was unwritable exactly where the corpus requires the work to happen; **P14** ("ledger absent while a push is contemplated ⇒ HALT") then fires **unconditionally, forever**. Fail-closed, so no data loss — a **deadlock**: worktree required ⇒ ledger required to push ⇒ ledger unwritable in a worktree. ⇒ **Fix: DERIVE, never hardcode** — `LEDGER_DIR="$(git rev-parse --path-format=absolute --git-common-dir)/maos/custody"`, verified executing verbatim from inside this linked worktree (resolves to the common-dir, `mkdir` succeeds, write succeeds, P14 no longer deadlocks). **⛔ `--git-common-dir`, NOT `--absolute-git-dir`** — and this distinction is the finding's real teeth: the **per-worktree** git-dir is **deleted when the worktree is removed**, and `maos:postflight` removes worktrees, so a ledger there **dies at exactly the session boundary it exists to survive**. Measured both: after `git worktree remove`, per-worktree ledger **DESTROYED**, common-dir ledger **SURVIVED**. Common-dir is also where the cited precedent actually lives (verified: `maos/` under the common-dir holds `continuation-seed.latest.json`; the per-worktree dir has no `maos/` at all). **Root-cause note**: `plugin-scripts/governance/preflight-session.sh` **already documents this exact trap** (*"the hardcoded `$REPO/.git/maos/...` never resolves"*) and solves it by probing `rev-parse` — §6.0 cited that script as precedent while copying its **literal path** instead of its **derivation**. Third instance this artifact of the same meta-failure: *the pattern was inherited, the fix was not* (cf. §0's escape clause vs `council-gate` §0, and v0.4.0's own fetch refspec). **+ Honesty edit to §4.0**: the header claimed the PRIMARY trip-wires are *"deterministic · `f=0`"*. Verified overstated — `git ls-tree -r HEAD -- skills/repo-custody-transfer/` returns **`SKILL.md` alone** (positive control: the same instrument reaches `bin/artifact-registry`, `bin/check-layer-purity`), so **nothing ships that runs them**: execution is agent-performed and "did P2's positive control fail?" is unfalsifiable from outside. Re-scoped to *"mechanically checkable · deterministic in **specification**, self-reported in **execution**"*, with the gap named as **B6** (a `bin/` verifier emitting machine-readable P-table verdicts) rather than papered over. Materially better than a judgement call — named, uniform, ledger-auditable predicates — but **not** an `f=0` gate the way `check-layer-purity`/`convergence-guard` are, and the file now says so. **What survived this pass**: `redteam-translatio` ran §5.1's commands against a real auto-init destination and confirmed **P11–P14 cover it** — `is-ancestor` both ways exit 1, `merge-base` exit 1 ⇒ DISJOINT ⇒ P12 ⇒ SPLIT-BRAIN — **with a discriminating control** (a genuinely fast-forwardable pair → both exit 0 ⇒ CLEAN CARRY), so the classifier is not trivially returning SPLIT-BRAIN for everything. That was the part it could not break. **Attribution, corrected at the red-team's own insistence**: I had called its report "the highest-value input this artifact received"; it pushed back that `elenchus-2` found the root defect and it had missed one reachable from what it read. Its generalization is worth keeping as doctrine: **reading an artifact finds contradictions in what it says; running it finds contradictions between what it says and what the tools do.** Different defect classes — this artifact needed both passes, and every fix from v0.4.0 onward came from one or the other. |
| 0.4.1 | 2026-07-29 | **§5.1's own fetch refspec was contaminating the SOURCE — a defect introduced BY the v0.4.0 fix** (`elenchus-2`, re-attacking `d6fbc4b`; the one line nobody had probed). v0.4.0 prescribed `'+refs/tags/*:refs/tags/_dst/*'`. The branch half was fine (`refs/remotes/_dst/*` = quarantine); **the tag half wrote into `refs/tags/`, which is not a scratch space** — anything there is a **real local tag**. Reproduced verbatim: source `v1`, destination holding its own `rel-9`; the fetch printed **both** `rel-9 -> _dst/rel-9` *and* `rel-9 -> rel-9`, leaving the source's tags as `_dst/rel-9 · rel-9 · v1`. Two measured harms: **(a)** git's default **tag-following** created the bare `rel-9` with **no marker at all** that it came from the destination ⇒ a later T1 fidelity check compares a tag set **the classifier itself contaminated** (`--no-tags` suppresses this; the refspec alone does **not**); **(b)** the residue is **pushable back** — `git push --dry-run <dst> 'refs/tags/*:refs/tags/*'` exported `_dst/rel-9` + `_dst/v1` as **permanent real tags** on the destination. **Why it slipped every existing guard**: §9.0's property is about a destination ref *losing* a reachable commit, and all of P1–P14 are framed around *loss* or *mis-classification* — this is **additive contamination of the source**, then exported. Neither the property nor a single trip-wire could see it. ⇒ **Fix** (verified on four axes): `git fetch --no-tags` + quarantine under `refs/rct/_dst/**` (outside both `refs/tags/` and `refs/remotes/`) + a **mandatory cleanup** (`for-each-ref … | xargs -r -n1 git update-ref -d`) once classified — measured after the fix: source `refs/tags` stays exactly `v1`, zero bare `rel-9`, zero `_dst` inside `refs/tags`, wildcard tag push exports **0** `_dst` refs, ancestry classification unaffected. **New doctrine** (stated alongside EXISTENCE-vs-UNIQUENESS, because it is the same error one level down): **a read-only classification must not WRITE into either side's real ref namespace.** **+ §9.0 gains an ADDITIVE prohibition table** (kept separate rather than bending the loss-property to fit): ⛔ wildcard tag push `refs/tags/*:refs/tags/*` (an **explicit-list** tag push is fine — the *wildcard* is what carries the residue) · ⛔ any classification writing into `refs/tags/**`/`refs/remotes/**`. **+ P15** (a `_dst` leftover in a real namespace or an uncleaned quarantine, at classification **or** push time). Also from the same pass: **§5.0's positive control is now explicitly same-instrument-same-tree FIRST**, with the second instrument as the *escalation* — plus the note that *a control which switches instruments is not a control* (it sidesteps the suspect condition and passes while the real query still lies), per `environment-capability-reconnaissance` §1.1.1(iv) · **§5.2 now records that it makes the classify→push TOCTOU survivable, explicitly NOT a licence to skip a freeze** (a peer's push gets *rejected*, not force-overwritten — which is why `elenchus-2` downgraded that finding from BLOCKING to MINOR; the per-class freeze/expected-SHA lease is still owed) · **citation corrected**: `council-gate` §5.3 lives in the **rule** (`~/.claude/rules/council-gate.md:170`), not the skill — verified, the skill merely cites it. **Attribution corrected**: v0.4.0 credited `elenchus-2` alone for the "a prohibition conditioned on a classification cannot protect the case where classification failed" reasoning; `redteam-translatio` reached it **independently** (its B2). Joint attribution — two independent arrivals is stronger evidence than one, and the record should say so. **Method note worth keeping**: `elenchus-2`'s first probe of this revision landed in the **wrong tree** (a `cd … \|\| cd main-repo` fallback silently put it on `main`, where all 8 markers read absent) and its **same-instrument positive control caught it** — the third time this engagement that the §4 rule caught a red-teamer's own false negative. Evidence *for* the rule, from the people attacking the artifact that contains it. |
| 0.4.0 | 2026-07-29 | **TWO INDEPENDENT RED-TEAMS delivered; 5 fixes, 3 of them closing a live data-loss path.** ⚠️ **Retraction first**: v0.3.0's method-note said the red-team "did not deliver" and that P8 stood unmet. **Both reported** (`redteam-translatio`: CLEAR-WITH-FINDINGS, 8 blockers; `elenchus-2`: probe-1 REFUTED, 3 defects). That note was wrong at the time of writing and is corrected here — the independent pass exists, and it found what self-red-teaming had not. **(1) §5.1 ancestry classification (the root defect, `elenchus-2`)** — §5 classified on *"both sides have **unique** commits"*, which is an **ancestry** question, while §5.0 prescribed `git ls-remote`, which returns **ref→sha only**. `grep` confirmed **zero** hits for `merge-base`/`is-ancestor`/`git fetch` in the whole artifact ⇒ the agent was told to derive a verdict its prescribed instrument **cannot produce**, and the failure is *silent* (differing SHAs are equally consistent with fast-forwardable and with disjoint roots). Now: fetch objects, classify **per-ref** with `merge-base --is-ancestor`, repo-class = **worst** ref-class (a clean branch cannot launder a divergent one — this is what makes `--branches '[*]'` safe). **`ls-remote` establishes EXISTENCE, never UNIQUENESS.** **(2) The auto-init destination is SPLIT-BRAIN, not "empty"** — `gh repo create --add-readme` leaves **one unrelated root commit**. Reproduced end-to-end: dest `main=d8e5e15`, source `main=c412f39`+`v1`; `ls-remote` shows only *"both have main, SHAs differ"*, from which one agent reads halt and another reads *"just a README, effectively empty"* ⇒ CLEAN-CARRY ⇒ **unattended push**. Same file, opposite bands, one autonomous. Then the §3.1-compliant explicit-refspec push was **rejected** (git's non-FF backstop — the strongest real safety property in the flow) and `--force` **destroyed the destination commit without violating any rule in this file**, because the case was never labelled SPLIT-BRAIN. **(3) §9.0 the unconditional rule, restated as a PROPERTY** (both red-teams) — *no operation may cause a destination ref to stop pointing at a commit still reachable from that destination, in **any** class **including unclassified***. The old ban was predicated on the *verdict*, and **a prohibition conditioned on a classification cannot protect the case where classification failed** — which is precisely the case that loses data. The spelling table now includes what the old one missed: `--delete`, `:<ref>`, `--prune`, `--force-with-lease` (lossy under a stale lease) — including the deletion the skill itself **mandates** on rollback, now permitted only inside §3.1's baseline bound. **(4) §0 can no longer route around the safety floor** (both red-teams, independently) — §5.0/§3.1 declared themselves ⛔ in their own headings yet were **absent from the never-skippable list**, so the entire fix for both v0.2.0 BLOCKING holes was skippable by §0; worse, skipping §5 meant nothing was ever *classified* SPLIT-BRAIN, disarming the one force rule that **was** listed. §0 is now **presentation-only**: a skipped safety gate does not become "passed", it sets its conjunct **`false`** ⇒ class degrades to INVESTIGATE ⇒ leaves the autonomous band ⇒ HITL (the shape `council-gate` §0 already hardened — pattern inherited, fix had not been). **(5) §6.0 the ledger has an ADDRESS** (both red-teams; the one gating production for both) — §7 granted **unattended push** authority partly on "ledger-bounded state" while the ledger had **no path and no schema**; the resume instructions lived inside an artifact the cold agent could not locate (circular), and §9 forbids the recall fallback ⇒ §3.1's *exceptional* "no snapshot ⇒ rollback forbidden" was the **default** state of every cold resume. Now `.git/maos/custody/<slug>.json` + `.refs-before.txt`, reusing the **existing** convention (`.git/maos/continuation-seed.latest.json`, verified: 24 refs, written by `preflight-session.sh`) — not a new one — plus a minimum schema and a Phase-0 load-or-restart rule. **+ §5.2**: a non-FF rejection is a **positive SPLIT-BRAIN signal** ⇒ HALT, ⛔ never cleared with force. **+ P11–P14** deterministic trip-wires (class-without-ancestry · disjoint-root/auto-init · non-FF-returned · ledger-absent-while-pushing); P1–P10 → **P1–P14**. Verified: the exploit that destroyed a commit at v0.3.0 now classifies **SPLIT_BRAIN** and leaves the autonomous band. **Honest residue**: `elenchus-2` examined only vectors 1+5 (2/3/4/6/7 NOT_EXAMINED by it); `redteam-translatio` covered 1–7 but read the file rather than running a cutover, and its 4 unverified items are excluded from these fixes. Its B3 (T3 extraction needs a fail-closed gitleaks scrub), B4 (protections arrive one phase after history — `[C18]` explicitly does **not** supply ref protection), B5 (no freeze for CLEAN CARRY ⇒ coexistence manufactures divergence), B6 (no deterministic PRIMARY layer beyond P1–P14) and B7 (`council-gate` ships UNARMED ⇒ "council-gated" means consultative-with-human-confirm, not autonomous authorization) are **queued, not silently patched** — they gate anything beyond a pilot. Also honored: both red-teams' free-negative discipline caught their own false negatives mid-review, which is evidence **for** the §4 rule, not against it. |
| 0.3.0 | 2026-07-29 | **§3.1 write-once `carry_baseline` + rollback-mode selection (BLOCKING, self-red-teamed).** Two more data-loss holes in the UNATTENDED band, both found by *executing* the artifact's own rules in a sandbox rather than re-reading them. **(1) The idempotence × freshness contradiction (P9/P10, anti-pattern #15)** — §3 promises Phase 2 is "re-runnable to convergence" and §5.0 forbids "a cached/earlier read"; applied together to the v0.2.0 snapshot rule they *force* a re-run to re-derive the snapshot, which then already contains the refs the previous run created ⇒ rule-3 puts them permanently out of rollback scope ⇒ **rollback silently degrades to a no-op** and "point of no return = Phase 4 only" becomes false — with **no trip-wire firing**, because a snapshot *does* exist, it is merely the wrong one. Reproduced: run #1 baseline `{peer}` → `DELETE main / KEEP peer` (correct); run #2 re-derived `{peer,main}` → `KEEP` both. Fixed by splitting the two freshness questions that were conflated under one word: *"what is the drift now?"* (classification — re-read **every** run) vs *"what did the destination hold before I touched it?"* (rollback bound — read **once, ever**). The baseline is now write-once + immutable, `captured_at`-stamped, ledger-persisted, reused verbatim on replay; P9 catches a re-derived baseline mechanically, P10 catches `carry_count > 0` with the baseline gone (reversibility already forfeited — halt, never proceed as if reversible). **(2) Ref deletion is not universally available** — the fix's own verification run then failed on the *real* rollback: a host refuses to delete the ref `HEAD`/the default branch points at. Measured both cases: **non-empty** baseline → `HEAD` rests on a baseline ref, carried refs delete cleanly; **empty** baseline → the carried ref *becomes* the default branch and `--delete` is **rejected** (exactly the pilot's shape). So the baseline's emptiness now *selects the mode*: empty ⇒ repo-level (delete the destination — zero collateral by definition, P7 second-instrument confirmation required first); non-empty ⇒ ref-level subtractive. ⛔ **Never repoint `HEAD` to force a deletion** — it mutates state outside the baseline (and can leave a dangling `HEAD`), which is the §3.1 violation rather than a workaround; if neither mode applies, the carry is **not reversible by this skill** ⇒ HALT + Impediment Report naming the residual state. Also: `carry_baseline`/`carry_count` added to the §6 ledger contract; Phase-2 rollback cell now states both modes; P1–P8 → **P1–P10**. Method note: **all four BLOCKING fixes so far (v0.2.0's two and v0.3.0's two) were found by the author, not by an independent party** — each by *executing* the rules in a sandbox rather than re-reading them, since a rule that reads coherent can still be incoherent when run, and a sandbox is the only honest verifier of a reversibility claim. An independent red-team (Elenchus) was dispatched and did **not** deliver; vectors 2/3/4/6/7 therefore remain **without independent review**. That gap is recorded rather than papered over: self-red-teaming found real defects but it shares the author's blind spots by construction, so it does **not** satisfy the §7 `verifier > generator` independence requirement for Phase 4 (P8 still stands, unmet). |
| 0.2.0 | 2026-07-29 | **Red-team hardening (pre-merge PDCA, PR #289)** — 3 defects closed, 2 of them BLOCKING data-loss holes in the UNATTENDED band, each refuted EMPIRICALLY (sandbox reproduction) rather than by opinion. **(1) §5.0 FRESHNESS PRECONDITION ⛔** — `grep` proved the artifact had ZERO mentions of fetch/fresh/stale: the drift-detector never required same-run wire truth. Reproduced: an observer holding remote-tracking refs from an earlier clone does not see a branch a peer pushed afterwards ⇒ destination reads empty ⇒ CLEAN-CARRY ⇒ §7 authorizes an unattended push at live peer work. Now both sides re-read via same-run `ls-remote` + a positive control, and a missing wire read HALTS instead of defaulting to CLEAN-CARRY. **(2) §3.1 SUBTRACTIVE-ONLY rollback ⛔** — the Phase-2 rollback ("delete the pushed refs") could not distinguish a ref it created from one that predates the carry, making the *rollback itself* a data-loss event on any non-empty destination. Now: snapshot ref→sha before pushing · delete only refs absent from the snapshot · a snapshotted ref is permanently out of rollback scope · no snapshot ⇒ rollback forbidden ⇒ no-push. **(3) §4.0 PRIMARY trip-wires P1–P8** — the Blocking-Gate trigger was self-scored by the agent that wants to proceed (the self-exemption gradient); now deterministic `f=0` trip-wires HALT regardless of confidence, with judgement only *widening* coverage and uncertainty treated as fired (fail-closed). §7's autonomous band is conditioned on §5.0 ∧ §3.1 both holding. Also from bot PDCA: `bin/artifact-registry` (a CLI, not `maos:`) · `legacy-archaeologist` is an **agent** (caught by verifying the bot's adjacent finding, unreported by any bot) · description 1753→985 chars · new **§0.1 Requirements** with per-dependency absent-behavior (hard-stop vs degrade-to-GAP vs warn). One Qodo finding REJECTED with evidence (`resolve-session.sh` belongs to `session-reentry`, not here). **Probe 5b SURVIVED and is recorded as surviving** — the 4-branch drift classification is total + disjoint over a binary predicate pair, so two independent agents converge; no fix manufactured. Bots: CodeRabbit APPROVED · amazon-q no-blocking-defects · 7/7 checks SUCCESS. |
| 0.1.0 | 2026-07-29 | Bootstrap — forged from a real 9-repo Bitbucket-Cloud→GitHub cutover need. Named by `anima`: system-name `repo-custody-transfer`, soul-name **Translatio** (12/12; rejected `git-host-migration` — "migration" is the false promise the tool refuses). Design decisions: **carry-then-rename** (any repo-rename program runs AFTER a clean cutover — lower impact) · Blocking-Gate + Impediment Report as a first-class capability · autonomy-max with council-before-HITL. Ships the fidelity contract (T1/T2/T3/T4), the 5-phase reversible cutover, the drift-detector (SPLIT-BRAIN class), the custody ledger, and the §8 composition map. Residue scripts (extractor/archiver · pipeline translator · ledger CLI · drift CLI) deferred until a real cycle demands them (Gordian/YAGNI). **Empirical grounding**: drift-detect found bidirectional divergence in 3 of 9 repos (a `--mirror` would have destroyed 11+10 commits and 10 tags); a positive control disproved a self-fabricated `admin:org` impediment; T3 archival validated via a host API gateway with a positive control. 6/6 §10 + 8/8 anti-theater + 6/6 scope-discipline. PR `ekson73/multi-agent-os#289`. |
