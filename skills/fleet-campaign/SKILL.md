---
name: fleet-campaign
version: "0.1.0"
description: |
  Converge a FLEET of provider-managed resources (N repos across M owners/orgs, N cloud accounts,
  N clusters, N projects) to ONE declared configuration state, in measured rounds. Soul-name
  Classis — the fleet brought under one command, hull by hull, each inspected before it is signed
  off. Six phases: DISAMBIGUATE the named target into independent surfaces (what is LOST when each
  one is off) → RECON the whole fleet at source THIS round → ORIENT on authority facts (which ref
  the provider reads, which read is a false negative, which absence is a plan tier, which host
  floor outranks the target's own policy) → SHARD one worker per credential boundary → VERIFY every
  worker claim at source before accepting it → RE-DERIVE the register each round until the
  re-measurement is empty. Thin conductor: composes work-drain's level-triggered invariant,
  ooda-loop's round structure, agentic-delegation's briefing contract and worktree-policy's
  isolation — reimplements no loop, no tracker access and no provider client.
  Use when ONE setting must become true across MANY resources you do not control one-by-one, and
  the product name you were given ("turn Dependabot off", "enable MFA everywhere", "drop public
  access on all buckets") hides more than one switch.
  Triggers: "fleet-campaign", "across all repos", "every repo in the org", "turn X off everywhere",
  "fleet-wide", "all accounts", "bulk config change", "em todos os repos", "na organização toda",
  "desligar X em tudo", "campanha de configuração".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob, AskUserQuestion
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

This skill serves the operator's intent. If a phase obstructs delivering value NOW, skip it, log
`Skipped <phase> — BEING > Rules`, and proceed. Gates are for correctness, never ritual. The one
thing §0 never waives is `## Hard limits` — a surface whose absence loses detection, an
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
P2 ORIENT        read the measurement for AUTHORITY facts, not just values (the nine laws below)
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

Record the classification (`decision-capture`) before the first probe. A campaign that skipped P0
is the one that blinds a resource nobody meant to blind.

### P1 — RECON at source

Build a **measurement matrix**: one row per fleet member, one column per surface, and — this is
the contract — **the exact probe that produced each column**, printed with the matrix.

```text
| member | surface-A | surface-B | … | measured_at |
| probe  | <command> | <command> | … | <timestamp>  |
```

A column without its probe is not a measurement, it is a belief. A matrix without `measured_at`
cannot be aged by the next reader.

### P2 — ORIENT

Read the matrix for the facts that decide **whether your plan is even relevant**, not just for
values. The nine laws below are exactly that reading. Two of them (L5 host-floor, L2 authority-ref)
have invalidated whole plans *after* they were written.

### P3 — SHARD

Partition the fleet by **credential boundary** — one worker per token/login/account/profile, token
passed into that worker's process. Never a mutable global selector that two workers can race
(`gh auth switch` and friends). Brief each worker with: its slice, the declared end-state, the
read-back probe that proves it, and the hard limits. Delegation depth ≤ 2, parallel ≤ 3.

### P4 — VERIFY before accept

A worker's `done` is a **claim**. Re-run the read-back probe yourself, on the member, before the
claim enters the register as fact. Budget for this to change the plan: in the campaign that
produced this skill it did, twice.

### P5 — RE-DERIVE

The next round's register is a **fresh measurement of the fleet**, not the leftovers of the last
one. A round closes when the re-measurement of the declared state is empty — which also makes a
re-run after a partial round a no-op, and an interrupted campaign resumable without state files.

## The nine laws (generalized from measurement, not from assumption)

| # | Law | What it says | Measured instance |
|---|---|---|---|
| **L1** | **SURFACE-DECOMPOSITION** | A product name is a bundle, not a switch. Enumerate the independent surfaces and classify each by what is lost when it is off. Never act on the bundle name. | One vendor name covered three surfaces: CVE **detection**, automatic **fix PRs**, and scheduled **version-bump PRs**. Only the third was the noise. Turning the first off would have blinded a private client repo that hosts a payment app's secret-sync manifest. |
| **L2** | **AUTHORITY-REF** | A provider reads ONE ref (usually the default branch). Changing the config on the ref *you* work on does not change behaviour. Find which ref the provider reads before editing. | On a Gitflow repo (default `main`, work on `develop`), removing the config file on `develop` left generation fully alive. A backport to the default branch was required; it cost an entire round. |
| **L3** | **FALSE-NEGATIVE-READ** | A `404`/empty from a legacy endpoint is not "absent" — the state may live in a successor surface. Probe the successor before concluding absence. | A `404` from the classic branch-protection endpoint read as "unprotected"; the real gate lived in an org-level **ruleset**, invisible to that endpoint. |
| **L4** | **TIER-NOT-CONFIG** | A `null`/absent field can mean "your plan does not populate this" — which is neither *disabled* nor *you lack permission*. Prove which by reading permission separately. | Private resources without the paid security tier returned a `null` config block while the same API reported `admin=true`. Absence of data, not absence of configuration. |
| **L5** | **HOST-FLOOR-OUTRANKS-POLICY** | The **executing host's** own guardrails bound you independently of the target's policy. Measure the floor first. | A host floor blocked every direct push to a default branch regardless of the repo's own rules. The carefully built map of which targets *permitted* a direct push became irrelevant: everything went by PR anyway. |
| **L6** | **FORK-INHERITS** | On a fork, removing an inherited file is **divergence from upstream**, not a fix. Decide it explicitly and record it. | One fleet member was a fork; its config came from upstream. Removing it was recorded as a deliberate, reversible divergence — not reported as a cleanup. |
| **L7** | **INVENTORY-DECAYS** | Every measured number has a drift rate. Re-measure anything mutable before each round and print the number next to its measurement time. | An inventory 8 days old said 18 open bot PRs; at action time there were 25 (~1/day). Acting on the snapshot would have left 7 untouched and reported done. |
| **L8** | **CLAIM-IS-NOT-EVIDENCE** | A worker/subagent `done` is a claim. Re-run the probe yourself. | Two of the re-measurements disagreed with the claim and changed the plan. |
| **L9** | **ONE-WORKER-PER-CREDENTIAL** | Shard by credential boundary; pass the token per process. A shared mutable credential selector is a race, not a convenience. | One worker per owner, distinct tokens, zero collisions across three rounds; the global credential switcher was never used. |

> The laws are **provider-agnostic on purpose**. `references/worked-example.md` carries the concrete
> probe set from the campaign that produced them, as a worked instance — not as the method.

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
{"declared_state":"<…>","round":1,"fleet":{"members":48,"credential_boundaries":2},
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
| the bounded round | `ooda-loop` | P0/P1 fleet-specific ORIENT inputs (the nine laws) |
| worker briefing | `agentic-delegation` | the shard key is the **credential boundary** |
| isolation | `worktree-policy` · `anti-conflict` | one worktree per worker, never the repo root |
| decision record | `decision-capture` | the surface classification is the record |
| PR mechanics | `hierarchical-merge` · `CONTRIBUTING.md` | unchanged |

Does NOT: author a provider client · drain tickets (`work-drain`) · migrate hosts
(`repo-custody-transfer`) · score tools (`agentic-tool-evaluator`) · decide adoption
(`agentic-tool-intake`).

## §Quality Tests

**6/6 self-validity:**
1. Frontmatter parses as YAML; `name` + `description` present.
2. Command wrapper exists and its filename = the `/entry` (`commands/fleet-campaign.md`).
3. Every law is stated generally AND carries a measured instance — no law without evidence.
4. The report contract prints a **probe** per column; a column without one fails the gate.
5. Level-triggered: a re-run after a partial round is a no-op on already-converged members.
6. `bash tests/validate-plugin.sh` passes (0 new errors).

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
- `skills/fleet-campaign/references/worked-example.md` (the measured campaign behind the nine laws)

## DNA Geracional (inherited by every spawned agent)

- **Measure, never assume** — a column without a probe is a belief; print the probe.
- **A claim is not evidence** — re-measure a subordinate's `done` at source before accepting it.
- **Re-derive, never replay** — the provider is the write-ahead log; store no queue.
- **Decompose before acting** — a product name is a bundle; classify each surface by what is lost.
- **Never trade detection for quiet** — noise is removable, blindness is not.
- **Shard by credential, one worker per boundary** — no shared mutable credential selector.
- **Unverified is a third state** — distinct from pass and from fail; report it as itself.
- **Boy-Scout** — leave the fleet and the tree cleaner than found; no half-converged member unnamed.

## Examples

```text
/fleet-campaign "no scheduled dependency-bump PRs in any of our repos"
/fleet-campaign "public access blocked on every bucket in both accounts" --surfaces-first
/fleet-campaign --round 2 --json          # machine envelope for the conductor
/fleet-campaign "MFA required for every member of the org"   # P0 will find >1 surface
```

## §Changelog

| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-10-21 | **Bootstrap.** Forged through `agentic-tool-pipeline` (Stage-0 routed the source-object **bare INTENT** → `agentic-tool-forge`; Stage-1 internal DRY probe over the 89-skill corpus found **no** member deriving a register from a live provider measurement of N resources — `work-drain` derives from trackers, `repo-custody-transfer` is N=1 host→host, `ooda-loop` is the generic round — so the gap is real and this is an addition, not a sister of an existing SSOT). Carries the M.O. that survived a real **48-member / 2-credential-boundary / 3-round** campaign plus the **nine laws** generalized beyond the provider that produced them, each stated generally AND evidenced by its measured instance. Named via the `anima` methodology: system-name **`fleet-campaign`**, soul-name **Classis** (a fleet under single command, inspected hull by hull); rejected **`fleet-convergence`** (collides semantically with `converge`/`convergence-engine`, which are proposal-synthesis, so it would misroute) and **`census`** (names only the measuring half, not the convergence). Composes `work-drain`'s level-triggered invariant, `ooda-loop`'s round, `agentic-delegation`'s briefing, `worktree-policy`/`anti-conflict` isolation and `decision-capture` — reimplements none. Hybrid: cognitive surface-classification + deterministic probe/read-back matrix; a probe that cannot run is reported `unverified`, a third state. Hard limits (loss-bearing surface off · irreversible · prod/PII/secret · peer config · cost · non-ours fork divergence · no read-back) always escalate and are **re-stated every round** until answered. Provider-agnostic by construction; the concrete probe set lives in `references/worked-example.md`. `latent` until two dogfood cycles per the promotion gate. |

## License

MIT (matches multi-agent-os repo `LICENSE`).
