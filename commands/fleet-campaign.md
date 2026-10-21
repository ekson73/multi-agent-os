---
name: fleet-campaign
description: Converge a FLEET of provider-managed resources (N repos/accounts/clusters/projects across M credential boundaries) to ONE declared configuration state, in measured rounds — surfaces disambiguated first, every member measured at source each round, one worker per credential boundary, every worker claim re-measured before it is accepted
---

# /fleet-campaign Command

Make ONE declared configuration state true across a **fleet** — then prove it, member by member.
Thin entry point over the [`fleet-campaign` skill](../skills/fleet-campaign/SKILL.md)
(soul-name **Classis**). Use it when a single setting must become true across many resources and
the instruction names a **product** rather than a switch.

## Usage

```text
/fleet-campaign "<declared end-state>" [--round N] [--surfaces-first] [--dry-run] [--json]
```

## Parameters

| Param | Default | Effect |
|-------|---------|--------|
| `"<declared end-state>"` | *required* | the end-state in one sentence, including what must **not** be lost. Empty → print usage; STOP. |
| `--round` | `1` | which round this pass is. Every round re-derives the register from a fresh provider measurement — never from the previous round's leftovers. |
| `--surfaces-first` | off | stop after **P0 DISAMBIGUATE** and report the surface table for authorization. Correct whenever any surface may be loss-bearing. |
| `--dry-run` | off | run P0–P2 (disambiguate · recon · orient) and emit the matrix + the plan; write NOTHING. |
| `--json` | off | machine envelope (see the skill's `## Machine output`) |

## What it does

```text
P0 DISAMBIGUATE  product name -> independent surfaces, each classed by what is LOST when off
P1 RECON         measure every member AT SOURCE this round, printing the probe per column
P2 ORIENT        read for authority facts (which ref, which false negative, which tier, which floor)
P3 SHARD         one worker per credential boundary; token per process, never a global switch
P4 VERIFY        re-measure each worker claim at source before accepting it
P5 RE-DERIVE     next round's register = a fresh measurement; close on an empty re-measurement
```

## Always escalates (never waived)

Turning **off** a loss-bearing surface (detection, alerting, audit, backup) · irreversible deletion
· production · PII or a secret value · a peer's or another org's config · a cost delta · a
non-ours fork's divergence from upstream · a declared state with **no read-back probe**.
An unanswered escalation is **re-stated every round** until it is decided.

## Examples

```text
/fleet-campaign "no scheduled dependency-bump PRs in any of our repos, detection untouched"
/fleet-campaign "public access blocked on every bucket in both accounts" --surfaces-first
/fleet-campaign "MFA required for every org member" --dry-run     # P0 will find more than one surface
/fleet-campaign --round 2 --json                                  # envelope for the conductor
```

## Not this command

- Register comes from a **tracker** (sprint/backlog/issues) → `/maos:work-drain`
- Moving **one** repo between hosts → the `repo-custody-transfer` skill
- You want the loop without the fleet discipline → `/maos:ooda-loop`

## Reach it from another harness

`multi-agent-os` is the SSOT for this skill. Project it into other harness roots with the
standard mechanism rather than copying the file (a copy diverges):

```text
npx skills add ekson73/multi-agent-os --skill fleet-campaign --agent '*' -g -y
```

Loaders that ignore symlinks take `--copy` on the same command; re-run it after an upstream change
so the projection stays current.

## §Refs

- `skills/fleet-campaign/SKILL.md` (the method — nine laws, six phases, hard limits)
- `skills/fleet-campaign/references/worked-example.md` (the measured campaign behind the laws)

---
*Signed: kirocrew-worker · 2026-10-21T10:29:28-03:00*
