---
name: fleet-campaign
version: "0.1.0"
description: |
  Converge a FLEET of provider-managed resources (N repos across M owners/orgs, N accounts,
  N clusters, N projects) to ONE declared configuration state, in measured rounds. Soul-name
  Classis. Six phases: DISAMBIGUATE the named target into independent surfaces (what is LOST
  when each is off) → RECON the fleet at source THIS round → ORIENT on authority facts (which
  ref the provider reads, which read is a false negative, which absence is a plan tier) → SHARD
  one worker per credential boundary → VERIFY every worker claim at source before accepting it
  → RE-DERIVE each round until the re-measurement is empty.
  Use when ONE setting must become true across MANY resources and the product name you were
  given ("turn Dependabot off", "enable MFA everywhere") hides more than one switch.
  Triggers: "fleet-campaign", "across all repos", "every repo in the org", "turn X off
  everywhere", "fleet-wide", "bulk config change", "em todos os repos", "na organização toda",
  "desligar X em tudo".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, Skill, AskUserQuestion
---

# fleet-campaign

> Make ONE declared configuration state true across a FLEET — then prove it, hull by hull.
> **Soul-name Classis** (Lat. *classis*, a fleet under single command): the commander never trusts
> a hull's own report; each is inspected before it is signed off, and the roster is re-counted
> before every sortie because ships move.
> **Composes** `work-drain` (the level-triggered invariant: re-derive the register from the source
> of truth each pass, never replay a stored queue), `ooda-loop` (the bounded round), `agentic-
> delegation` (the worker briefing contract), `worktree-policy` + `anti-conflict` (isolation),
> `decision-capture` (why each surface was classified as it was). It reimplements none of them.
> Distinct from its siblings: `work-drain` derives its register from **trackers** and drains
> *tickets*; `repo-custody-transfer` moves **one** repo between hosts; this one derives its
> register from a **live provider measurement of N resources** and converges *configuration*.
> **Cross-link slug**: `[[fleet-campaign]]`

## §0 — BEING > Rules (Foundational Compliance)

This skill serves the operator's intent. If a **narrative** step obstructs delivering value NOW —
a prose walkthrough, a rationale section, a formatted table a machine will not read — skip it, log
`Skipped <step> — BEING > Rules`, and proceed. Gates are for correctness, never ritual.

**The output contracts are not narrative.** When `--json` is requested, the envelope is mandatory
and must be valid and complete (every required field, one stop marker): a caller in machine mode
parses the reply, so degrading to prose there is a broken contract, not a saved step. The
`## Report format` columns are likewise mandatory in their own mode — what §0 licenses dropping is
the explanation around them, never the measured rows.

**Two phases are never skippable, and §0 does not reach them:** **P4 VERIFY** (re-measure each
worker claim at source) and **P5 RE-DERIVE** (the fresh measurement that closes a round). Skipping
either turns the campaign into an unverified claim, which is the one failure this skill exists to
prevent — a member could be reported converged while the resource is untouched. Owning a read-back
probe is not the same as running it: the hard limits require the probe to **exist**, P4 requires it
to have **run**, and convergence may not be reported without both.

`## Hard limits` is likewise never waived — a surface whose absence loses detection, an
irreversible deletion, production, PII/secret, a peer's config or cost always escalates.

## Purpose

A fleet campaign is not N independent tasks. It is one declared end-state plus N measurements, and
almost everything that goes wrong goes wrong *before* the first mutation: the target was a bundle
of switches, the measurement was stale, the provider reads a different ref than the one you edited,
or a worker's "done" was a claim nobody re-measured. This skill is the method that survived a real
48-resource, 3-round campaign, generalized so the next one does not relearn it.

## When to use

- ONE setting must become true across MANY resources (repos, accounts, clusters, projects, tenants).
- The instruction names a **product**, not a switch ("turn Dependabot off", "enable branch protection
  everywhere", "block public buckets") — i.e. the surfaces behind the name are not yet enumerated.
- The fleet spans **more than one credential boundary** (two logins, an org plus a user, two accounts).
- An inventory exists but was taken earlier, and acting on it would be acting on a snapshot.

## When **not** to use

- ONE resource → do the change directly; this conductor's overhead buys nothing.
- The register comes from a **tracker** (sprint, backlog, issues) → `work-drain` (Antlia).
- The work is moving a repo between **hosts** → `repo-custody-transfer` (Translatio).
- You need the *loop* but not the fleet discipline → `ooda-loop` / `gap-loop`.
- The declared state cannot be **read back** from the provider. Without a read-back there is no
  acceptance, only a claim — stop and say so rather than running a campaign you cannot close.

## The M.O. — six phases

```text
P0 DISAMBIGUATE  the named target -> independent SURFACES, each classified by what is LOST when off
P1 RECON         measure every fleet member AT SOURCE, this round, with the probe named per column
P2 ORIENT        read the measurement for AUTHORITY facts, not just values (the laws below)
P3 SHARD         one worker per credential boundary; token passed per process, never switched
P4 VERIFY        re-measure each worker's claim at source BEFORE accepting it
P5 RE-DERIVE     next round's register comes from a fresh measurement; close only when it is empty
```

### P0 — DISAMBIGUATE

Enumerate the independent surfaces the product name bundles. For each, answer one question:
**what is lost when this is off?** Then split the set in two.

| Class | Meaning | Authority |
|---|---|---|
| **noise-only** | turning it off loses nothing a human would miss | the campaign may act |
| **loss-bearing** | turning it off loses detection, alerting, audit or recovery | HITL, per surface |

Record the classification (`decision-capture`) before the first probe. Under `--dry-run` the
record is kept in the report only and nothing durable is written; the durable capture happens on
the first executing round. A campaign that skipped P0 is the one that blinds a resource nobody
meant to blind.

### P1 — RECON at source

Build a **measurement matrix**: one row per fleet member, one column per surface, and — this is
the contract — **the exact probe that produced each column**, printed with the matrix.

```text
| member | surface-A | surface-B | … | measured_at |
| probe  | <command> | <command> | … | <timestamp>  |
```

A column without its probe is not a measurement, it is a belief. A matrix without `measured_at`
cannot be aged by the next reader.

**Probes are metadata-only.** A presence check reads status, not content (`-i | head -1`, a count,
a status field) — never a body the probe then prints. The report contract requires the probe's
output to be shown, so a probe that returns file content or a full configuration object puts that
content into the report, which `## Hard limits` and anti-theater rule 7 forbid. Ask the provider
whether the thing exists, not what it says.

**The read-back must probe exactly the set discovery probed, for every surface the campaign
declared or mutated.** Two different sets are in play and conflating them is the error: the ORIENT
columns (a branch gate, a plan tier) exist to tell you whether your plan is relevant and need no
read-back; every surface named in the declared end-state, plus every surface the campaign actually
changed, needs one. Within that set the read-back must be as wide as discovery was: if P1 found the
state under either of two filenames, two field names or two API surfaces, a P4 read-back that
checks only one accepts a member that still carries the other. And
when a counted population is **shared** between a noise surface and a loss-bearing one — the same
author, label or namespace emitting both — the read-back must filter down to the noise surface.
Otherwise acceptance is satisfiable by destroying the thing P0 protected, which is **L1** returning
through the back door.

### P2 — ORIENT

Read the matrix for the facts that decide **whether your plan is even relevant**, not just for
values. The laws below are exactly that reading. Two of them (L5 host-floor, L2 authority-ref)
have invalidated whole plans *after* they were written.

### P3 — SHARD

Partition the fleet by **credential boundary** — one worker per token/login/account/profile, the
credential bound to that single worker invocation (command-scoped). Never a mutable global
selector two workers can race (`gh auth switch` and friends), and never an `export` into the
conductor's own shell: an exported credential is the same race through the environment, and it
puts the raw value where a traced transcript can capture it.

**Every spawn goes through `delegate-governance`** — this repository's canonical delegation entry
point (`AGENTS.md` §Delegation) — which carries the ticket, provider, DNA-inheritance and cleanup
checks a fleet campaign must not skip. Its three phases run at three different times, not all
before the spawn:

| Phase | When | What it does for a fleet campaign |
|---|---|---|
| `init` | **before** the worker is spawned | ticket + provider + authority resolved for that shard |
| `dna` | **during** the run, as needed | inheritance payload the worker passes to anything it spawns |
| `finalize` | **after** the worker returns | cleanup and reconciliation for that shard |

Reach it as the **skill** (`delegate-governance`), which is why `Skill` is in this skill's
`allowed-tools`. The script form is a source-checkout convenience, and it is **not** at a
source-relative path when this ships as an installed plugin — resolve it from the plugin root, the
same way `person-agent-creator` does, and fall back to the skill when the host sets no root:

```bash
GOV="${CLAUDE_PLUGIN_ROOT:+$CLAUDE_PLUGIN_ROOT/plugin-scripts/gaac/delegate.sh}"
[ -x "${GOV:-}" ] || GOV=""      # no plugin root (Pi / npx installs) -> use the skill
```

The brief is the **fleet-specific payload** layered on top of that governance prompt, never a
replacement for it: each worker receives its slice, the declared end-state, the read-back probe
that proves it, and the hard limits. Delegation depth ≤ 2, parallel ≤ 3.

Sharding by credential is an **isolation** measure, never a review measure. That two shards carry
different identities does not make one a valid reviewer of the other: an approval gate exists to
get an independent responsible reviewer, and satisfying it with a second credential the same
operator controls is a bypass — explicitly inside `## Hard limits` whenever the resource is a
peer's or another org's.

### P4 — VERIFY before accept

A worker's `done` is a **claim**. Re-run the read-back probe yourself, on the member, before the
claim enters the register as fact. Budget for this to change the plan: in the campaign that
produced this skill it did, twice.

### P5 — RE-DERIVE

The next round's register is a **fresh measurement of the fleet**, not the leftovers of the last
one. A round closes when the re-measurement of the declared state is empty — which also makes a
re-run after a partial round a no-op, and an interrupted campaign resumable without state files.

## The laws (generalized from measurement, not from assumption)

| # | Law | What it says | Measured instance |
|---|---|---|---|
| **L1** | **SURFACE-DECOMPOSITION** | A product name is a bundle, not a switch. Enumerate the independent surfaces and classify each by what is lost when it is off. Never act on the bundle name. | One vendor name covered three surfaces: CVE **detection**, automatic **fix PRs**, and scheduled **version-bump PRs**. Only the third was the noise. Turning the first off would have blinded a private client repo that hosts a payment app's secret-sync manifest. |
| **L2** | **AUTHORITY-REF** | A provider reads ONE ref (usually the default branch), and **which ref that is varies between members of the same family** — two repos on the same branching convention can have different defaults. Measure the default per member; never infer it from the convention. The mirror case matters as much: a config file left on a **non-default** branch is inert today and a **silent landmine** — it reactivates the moment someone flips the default. | Both directions were measured. One Gitflow member (default `main`, work on `develop`): removing the file on `develop` left generation fully alive, and a backport to `main` cost an entire round. Two other members of the *same* family (default `develop`): the file was already absent on `develop` — generation dead — but still present on `main`, inert and waiting. |
| **L3** | **FALSE-NEGATIVE-READ** | A `404`/empty from a legacy endpoint is not "absent" — the state may live in a successor surface. Probe the successor before concluding absence. | A `404` from the classic branch-protection endpoint read as "unprotected"; the real gate lived in an org-level **ruleset**, invisible to that endpoint. |
| **L4** | **TIER-NOT-CONFIG** | A `null`/absent field can mean "your plan does not populate this" — which is neither *disabled* nor *you lack permission*. Prove which by reading permission separately. | Private resources without the paid security tier returned a `null` config block while the same API reported `admin=true`. Absence of data, not absence of configuration. |
| **L5** | **HOST-FLOOR-OUTRANKS-POLICY** | The **executing host's** own guardrails bound you independently of the target's policy. Measure the floor first. | A host floor blocked every direct push to a default branch regardless of the repo's own rules. The carefully built map of which targets *permitted* a direct push became irrelevant: everything went by PR anyway. |
| **L6** | **FORK-INHERITS** | On a fork, removing an inherited file is **divergence from upstream**, not a fix. Decide it explicitly and record it. | One fleet member was a fork; its config came from upstream. Removing it was recorded as a deliberate, reversible divergence — not reported as a cleanup. |
| **L7** | **INVENTORY-DECAYS** | Every measured number has a drift rate. Re-measure anything mutable before each round and print the number next to its measurement time. | An inventory 8 days old said 18 open bot PRs; at action time there were 25 (~1/day). Acting on the snapshot would have left 7 untouched and reported done. |
| **L8** | **CLAIM-IS-NOT-EVIDENCE** | A worker/subagent `done` is a claim. Re-run the probe yourself. | Two of the re-measurements disagreed with the claim and changed the plan. |
| **L9** | **ONE-WORKER-PER-CREDENTIAL** | Shard by credential boundary and bind the credential to **one worker invocation** (command-scoped). Any shared mutable credential — a global switcher *or* an exported environment variable the conductor's shell holds — is a race, not a convenience: whatever ran last is what the next worker inherits, and a mutation can land under the wrong identity. Command-scoping is not trace safety: a shell trace logs the expanded assignment, so tracing is disabled separately. | One worker per owner, command-scoped tokens, zero collisions across three rounds; the global switcher was never used and the token was never exported into the conductor shell. |
| **L10** | **OWN-BY-RESOURCE-BOUNDARY** | Partition ownership by **resource and credential boundary**, never by task type. "One agent measures, another writes" does not remove contention: two agents holding write permission on the same resource collide even on unrelated tasks. One owner per resource, for the whole round, start to finish. | Round 2 sharded by token/owner; the round after sharded by **repo**, one worker each. Both held. The only cross-worker surprise came from a PR touched before a boundary message landed — a boundary gap, not a task-type gap. |
| **L11** | **ROLLUP-IS-NOT-THE-GATE** | A pull-request check rollup in a repo with third-party review apps **never goes clean**, so a "rollup green" acceptance condition chases a target that does not exist. The gate is the **required set** plus the merge state. Measure `gh pr checks <n> --required` (and the merge state), not the rollup. | Measured on this skill's own PR: `gh pr checks <n>` exits **1**; `gh pr checks <n> --required` exits **0**. The exit-1 contributors were **non-required apps out of quota** — one code-scanner reporting `Code test limit reached`, one reviewer reporting `Review rate limited` — plus jobs in `skipping` (a merge queue, a bug-finder, a scorecard). No unconcluded check run was present. |
| **L12** | **BLOCKED-IS-NOT-MISSING-APPROVAL** | A `BLOCKED` merge state does not mean an approving review is missing. Find which gate is actually pending before proposing a reviewer. | `required_approving_review_count = 0` on **11 of 11** branches across the fleet. The real gates were a pending review **request** and required checks — and two PRs carrying a request for a team landed on auto-merge anyway, so the request was advisory. |
| **L13** | **GATE-MAY-LIVE-IN-CODE** | Look for the gate in **workflows and scripts** before concluding none exists. An empty ruleset list and a `404 Branch not protected` each prove nothing: a provider has several places a gate can live, and one of them is the repository's own code. | One member returned `[]` for rulesets while its reviewer allowlist lived in code — a workflow plus the library it calls, with parity tested between them. Four fleet members returned the classic `404` while another member carried **7** active rulesets. |
| **L14** | **EXTERNAL-LOOPS-DO-NOT-CONVERGE** | A loop driven by an **external agent that re-executes on every change** has no fixed point — a new head re-triggers every reviewer and each finds more. The exit is the conductor's to define, never the loop's. Symptom: the finding count **rising** between rounds. Cure: an explicit exit criterion = an objective bar (the required set) + the class you fix (correction-defects: wrong fact, wrong command, security risk, or an instruction that would misdirect another agent) + everything else **declined in-thread with a reason**. Declining with a reason is a review answer, not debt. | Five review bots across four heads produced **4 → 9 → 16** findings. 15 were fixed and 1 refuted with evidence; the rising count, not the quality, was the signal. Same error as hand-rebasing a live branch (cure there: per-PR auto-merge on your own PRs), in a different disguise. |

> The laws are **provider-agnostic on purpose**. `references/worked-example.md` carries the concrete
> probe set from the campaign that produced them, as a worked instance — not as the method.

## How a law enters this table (the rule above the laws)

**A law enters only with a cause that was measured.** A cause *inferred* from tool output is a
hypothesis: it is marked as a hypothesis, or it stays out. Nothing else in this skill matters as
much, because a reader does not re-measure what the asset already claims to know — so an asset
that teaches a wrong cause is worse than no asset at all, and it is worse for longer.

This table has already been corrected by its own rule. **L11** first shipped, in a conductor's
report, with the cause "a check run that registers and never concludes", inferred from truncated
check names in a terminal. A worker measured it and refuted it: the real contributors were
non-required apps out of quota plus skipped jobs, and no unconcluded run existed at all. The
*effect* survived the correction, the *cause* did not — and only the measured cause yields the
actionable form (`--required`, exit 0) instead of the vague one ("the rollup is unreliable").

Three consequences for anyone extending this table:

1. **Name the probe that produced the cause**, in the law's own evidence column. A law whose
   evidence is a narrative, not a probe, is a hypothesis wearing a law's clothes.
2. **An effect you can reproduce does not validate a cause you did not measure.** The two are
   separate claims and they fail separately.
3. **When a law is corrected, correct it where it lives** — not only in the report that carried it.
   A stale copy in an index, a changelog or a memory becomes the next drift source.

## Hybrid execution & forward-compatibility

**Cognitive half (the agent):** enumerating the surfaces behind a product name, judging
*loss-bearing vs noise-only*, deciding a fork's divergence, reading which ref carries authority.
None of these are lookups.

**Deterministic half (the probes):** the measurement matrix, the read-back per surface, the
emptiness check that closes a round. These must be commands with printed output, never prose.

**Forward-compatible:** a surface the provider has not exposed to you yet is **detected, reported
and routed** (DEFER-HITL) — never assumed, and never fabricated as measured. A probe that cannot
run is recorded as *unverified*, which is a third state, distinct from both pass and fail.

## Hard limits (always escalate — §0 never waives these)

- Turning **off** any loss-bearing surface (detection, alerting, audit, backup, recovery).
- **Irreversible** or non-restorable deletion, anywhere in the fleet.
- Anything touching **production**, **PII** or a **secret value**.
- Config owned by a **peer or another org** you were not asked to change.
- Anything with a **cost** delta.
- A **fork's** divergence from an upstream that is not ours.
- A declared state with **no read-back probe** — unprovable, therefore not a campaign.

Escalate as *recommended options with the measurement behind them*, never as an open question.
While an escalation is unanswered, **re-state it every round** until it is decided.

## Report format (verbatim contract)

```text
## Round <n> — <declared end-state>
measured_at: <timestamp>   fleet: <N members> / <M credential boundaries>

### Surfaces
| surface | class (noise-only|loss-bearing) | authorized? | action |

### Matrix
| member | <surface…> | measured_at |     (+ the probe row)

### Accepted this round (re-measured at source)
| member | claim | read-back probe | result |

### Not done
| member | why | who must act |
```

## Machine output (`--json`) — family envelope

```json
{"declared_state":"<…>","round":1,"measured_at":"<ISO-8601>",
 "fleet":{"members":48,"measured_this_round":48,"credential_boundaries":2},
 "surfaces":[{"name":"<…>","class":"noise-only|loss-bearing","authorized":true}],
 "accepted":[{"member":"<…>","probe":"<…>","result":"<…>"}],
 "pending":[{"member":"<…>","why":"<…>","owner":"agent|human"}],
 "verdict":"CONVERGED|ROUND-OPEN|DEFER-HITL","stop_marker":"STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE"}
```

Exit codes: `0` converged or round reported · `1` error · `2` HITL/defer.

## Composition (what it delegates — and what it does NOT)

| Concern | Delegated to | This skill's delta |
|---|---|---|
| level-triggered re-derivation | `work-drain` (Antlia) | register derived from a **provider measurement**, not a tracker |
| the bounded round | `ooda-loop` | P0/P1 fleet-specific ORIENT inputs (the laws) |
| spawning a worker | `delegate-governance` (`AGENTS.md` canonical entry point) | the fleet brief is the payload on top of that prompt, never a bypass |
| worker briefing content | `agentic-delegation` | the shard key is the **credential boundary** |
| isolation | `worktree-policy` · `anti-conflict` | one worktree per worker, never the repo root |
| decision record | `decision-capture` | the surface classification is the record |
| PR mechanics | `hierarchical-merge` · `CONTRIBUTING.md` | unchanged |

Does NOT: author a provider client · drain tickets (`work-drain`) · migrate hosts
(`repo-custody-transfer`) · score tools (`agentic-tool-evaluator`) · decide adoption
(`agentic-tool-intake`).

## §Quality Tests

**8/8 self-validity:**
1. Frontmatter parses as YAML; `name` + `description` present.
2. Command wrapper exists and its filename = the `/entry` (`commands/fleet-campaign.md`).
3. Every law is stated generally AND carries a measured instance — no law without evidence.
4. The report contract prints a **probe** per column; a column without one fails the gate.
5. The P4 read-back probes **exactly the set** P1 discovered with (every filename / field / API
   surface), and any population shared with a loss-bearing surface is filtered down to the noise
   surface — a read-back narrower than discovery, or satisfiable by destroying what P0 protected,
   fails the gate.
6. P4 and P5 are outside the `§0` skip escape; convergence cannot be reported without both having
   run.
7. Level-triggered: a re-run after a partial round is a no-op on already-converged members.
8. `bash tests/validate-plugin.sh` passes (0 new errors).

**Scope-discipline 6Q:** (1) Is the register derived from a live provider read, not a snapshot?
(2) Is discovery/looping composed, not reimplemented? (3) Is every loss-bearing surface gated?
(4) Is the shard key the credential boundary? (5) Is each worker claim re-measured before accept?
(6) Does a round close on an empty re-measurement rather than on a worker's report?

**Anti-theater 8Q:** (1) No fabricated member, surface or probe result. (2) No hardcoded provider.
(3) No claimed capability that was not detected. (4) No silent omission — every unconverged member
is named with a reason and an owner. (5) No loss-bearing surface turned off without authorization.
(6) No worker claim accepted unverified. (7) No secret, PII, host, ARN, client resource name or
client content in any output. (8) An unrunnable probe is reported `unverified`, never as a pass.

## §DUED Sunset (qualitative, not counter-based)

Deprecate when: the provider ships fleet-wide declarative config with read-back that makes rounds
unnecessary (E1) · `work-drain` grows a provider-measurement register, absorbing this (E6) ·
operator retraction (E4) · ≥3 campaigns where P0 found exactly one surface and the laws never
fired (E5 → narrow the trigger, not auto-deprecate).

## §Refs

- `skills/work-drain/SKILL.md` (level-triggered invariant — **inherited**, not rebuilt)
- `skills/ooda-loop/SKILL.md` · `skills/gap-loop/SKILL.md` (the round / condition loop)
- `skills/agentic-delegation/SKILL.md` (worker briefing contract)
- `skills/worktree-policy/SKILL.md` · `skills/anti-conflict/SKILL.md` (isolation)
- `skills/decision-capture/SKILL.md` (surface classification as a durable decision)
- `skills/repo-custody-transfer/SKILL.md` (sibling — ONE repo, host→host; honest-fidelity precedent)
- `skills/anima/SKILL.md` (named this skill — see `§Changelog` for the rejected runners-up)
- `commands/fleet-campaign.md` (the `/entry` wrapper)
- `skills/fleet-campaign/references/worked-example.md` (the measured campaign behind the laws)

**The local-facts half.** This skill is the SSOT for the **mechanics** — provider-agnostic method,
laws, limits. The host-specific facts a campaign needs (which accounts exist, which gate lives in
which workflow, which third-party app is out of quota on which repo) belong to a **host steering
document**, not here: they are not portable and they decay on a different clock. On the machine
that produced this skill that document is `~/.kiro/steering/github-fleet-campaign-facts.md`, and
it points back here as the SSOT for the method — the two halves cite each other and neither
duplicates the other. Keep that split when you port this: mechanics travel, facts do not.

## DNA Geracional (inherited by every spawned agent)

- **Measure, never assume** — a column without a probe is a belief; print the probe.
- **A claim is not evidence** — re-measure a subordinate's `done` at source before accepting it.
- **Re-derive, never replay** — the provider is the write-ahead log; store no queue.
- **Decompose before acting** — a product name is a bundle; classify each surface by what is lost.
- **Never trade detection for quiet** — noise is removable, blindness is not.
- **Shard by credential, one worker per boundary** — no shared mutable credential selector.
- **Unverified is a third state** — distinct from pass and from fail; report it as itself.
- **A cause inferred from tool output is a hypothesis** — mark it as one or leave it out.
- **One owner per resource** — partition by resource and credential, never by task type.
- **The conductor owns the exit** — an externally driven loop has no fixed point of its own.
- **Boy-Scout** — leave the fleet and the tree cleaner than found; no half-converged member unnamed.

## Examples

```text
/fleet-campaign "no scheduled dependency-bump PRs in any of our repos"
/fleet-campaign "public access blocked on every bucket in both accounts" --surfaces-first
/fleet-campaign "public access blocked on every bucket in both accounts" --round 2 --json
/fleet-campaign "MFA required for every member of the org"   # P0 will find >1 surface
```

## §Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-10-21 | **Bootstrap.** Forged through `agentic-tool-pipeline` (Stage-0 routed the source-object **bare INTENT** → `agentic-tool-forge`; Stage-1 internal DRY probe over the 89-skill corpus found **no** member deriving a register from a live provider measurement of N resources — `work-drain` derives from trackers, `repo-custody-transfer` is N=1 host→host, `ooda-loop` is the generic round — so the gap is real and this is an addition, not a sister of an existing SSOT). Carries the M.O. that survived a real **48-member / 2-credential-boundary / 3-round** campaign plus the **laws** generalized beyond the provider that produced them, each stated generally AND evidenced by its measured instance. Named via the `anima` methodology: system-name **`fleet-campaign`**, soul-name **Classis** (a fleet under single command, inspected hull by hull); rejected **`fleet-convergence`** (collides semantically with `converge`/`convergence-engine`, which are proposal-synthesis, so it would misroute) and **`census`** (names only the measuring half, not the convergence). Composes `work-drain`'s level-triggered invariant, `ooda-loop`'s round, `agentic-delegation`'s briefing, `worktree-policy`/`anti-conflict` isolation and `decision-capture` — reimplements none. Hybrid: cognitive surface-classification + deterministic probe/read-back matrix; a probe that cannot run is reported `unverified`, a third state. Hard limits (loss-bearing surface off · irreversible · prod/PII/secret · peer config · cost · non-ours fork divergence · no read-back) always escalate and are **re-stated every round** until answered. Provider-agnostic by construction; the concrete probe set lives in `references/worked-example.md`. `latent` until two dogfood cycles per the promotion gate. |

## License

MIT (matches multi-agent-os repo `LICENSE`).

---
*Signed: kirocrew-worker · 2026-10-21T10:29:28-03:00*
