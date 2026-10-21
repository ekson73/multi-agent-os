# Worked example — the campaign that produced the nine laws

> This is a **worked instance**, not the method. The method is provider-agnostic and lives in
> `../SKILL.md`. Read this one for the shape of a real measurement matrix and for the probes that
> made each law observable rather than plausible.
>
> **Redaction boundary.** This repository is open source. Members in a client organization are
> referred to only as *a private client repo* (`C1…C6`). No host, account id, resource ARN, secret
> name, person or client content appears here. Only our own public repos are named.

## The declared end-state

> "No scheduled dependency-bump pull requests generated in any of our repositories, **without**
> losing vulnerability detection anywhere."

The second clause is the whole campaign. It was not in the original instruction — P0 produced it.

## P0 — DISAMBIGUATE: one product name, three surfaces

The instruction was *"turn the dependency bot off"*. Enumerating what the vendor actually exposes
gave three independent switches:

| Surface | What it does | What is LOST when off | Class |
|---|---|---|---|
| **alerts** | detects a known vulnerability in a declared dependency | **detection** — the repo goes blind | **loss-bearing** |
| **security updates** | opens a fix PR for an alert automatically | automation only; the alert still fires | loss-bearing (weak) |
| **version updates** | opens scheduled bump PRs from a checked-in config file | nothing a human would miss | **noise-only** |

Only **version updates** was the noise the operator meant. The authorized action was therefore:
remove the config file from the ref the provider reads, close the already-open bump PRs, and
**never call the alerts-off endpoint**. One member had the weak loss-bearing surface explicitly
authorized off; the detection surface was left on in all 48.

Had P0 been skipped, the obvious one-liner (disable the product) would have blinded a private
client repo that stores a payment application's secret-sync manifest. That near miss is **L1**.

## P1 — RECON: the measurement matrix

48 members across two credential boundaries: our personal account (20) and a client organization
(28). A third candidate account measured **0 repos** and was dropped from the fleet — recorded, not
silently omitted.

Probe per column (the contract: the command is printed *with* the matrix):

| Column | Probe | Reading |
|---|---|---|
| `alerts` | `gh api -i repos/{o}/{r}/vulnerability-alerts \| head -1` | `204` = on · `404` = off |
| `sec-upd` | `gh api repos/{o}/{r} --jq '.security_and_analysis.dependabot_security_updates.status'` | `enabled`/`disabled` · **`null` = not populated at this plan tier** |
| `config file` | `gh api repos/{o}/{r}/contents/.github/dependabot.yml` (fallback `.yaml`) | `200` = present · `404` = absent |
| `open bot PRs` | `gh pr list --repo {o}/{r} --author app/dependabot --state open --json number --jq 'length'` | count |
| `branch gate` | `gh api -i repos/{o}/{r}/branches/{default}/protection \| head -1` **and** `gh api repos/{o}/{r}/rulesets` | `200` = classic gate · `404` **does not mean unprotected** (see L3) |

Measured totals, `measured_at` round 1:

| | personal account | client org | fleet |
|---|---|---|---|
| members | 20 | 28 | 48 |
| detection on | 0 | 7 | 7 |
| auto-fix on | 0 | 1 | 1 |
| config file present | 3 | 6 | **9** |
| open bump PRs | 3 | 15 | **18** |

## P2 — ORIENT: what the matrix said that the values alone did not

**L4 — `null` is a plan tier, not a setting.** 13 private members returned
`security_and_analysis = null`. A second, separate read settled what that meant:

```
gh api repos/{o}/{r} --jq '{perm:.permissions, sec:.security_and_analysis}'
→ perm.admin = true, sec = null
```

Admin held; the block was simply not populated without the paid security tier. Absence of data,
not absence of configuration and not absence of permission. Reading permission *separately* is
what made the difference legible.

**L3 — the `404` that was not an absence.** Five members returned `404` from the classic
branch-protection endpoint. That endpoint does not see organization **rulesets**; on at least one
member the real approval gate lived there. A plan that read `404` as *"direct commit is fine here"*
would have been built on a false negative.

**L5 — the host floor outranked all of it.** The executing host refuses any direct push to a
default branch, independent of what the target repo permits. So the carefully assembled map of
*which members allow a direct commit* became irrelevant: **all 9 went by pull request**. The floor
is a property of where you run, not of what you are changing — measure it first, and the map you
need shrinks.

## P3 — SHARD: one worker per credential boundary

Two workers, one per account. The credential is bound to **one worker invocation**, as a
command-scoped variable — never `export`ed into the conductor's shell:

```
# worker A — personal account, 20 members
GH_TOKEN=$(gh auth token --user <login-A>) <worker-A-command>
# worker B — client org, 28 members
GH_TOKEN=$(gh auth token --user <login-B>) <worker-B-command>
```

**Why command-scoped and not `export`ed.** An exported `GH_TOKEN` is shared mutable state in the
conductor shell: every worker spawned afterwards inherits whichever assignment ran last. That is
the same cross-worker credential race L9 forbids for the global switcher — via the environment
instead of the keyring — and it can drive a mutation under the wrong identity. It also puts the
raw token where any traced transcript of the campaign can capture it, which the anti-theater rule
on secret leakage forbids. The global switcher (`gh auth switch`) was likewise **never** used.
Zero collisions across three rounds. That is **L9**.

## L2 in the field — the Gitflow round it cost

One member is Gitflow: default branch `main`, all work on `develop`. The config file was removed on
`develop` — correct by the repo's own convention, and **generation continued**, because the provider
reads the **default branch**. Converging it needed a second PR backporting the removal to `main`.

That is one full round spent on a ref assumption. The general form (**L2**): find which ref the
provider reads *before* editing, not after the read-back disagrees with you.

## P4 — VERIFY: the read-back that closed each member

Per member, after the merge, on the **default** ref explicitly:

```
gh api -i repos/{o}/{r}/contents/.github/dependabot.yml | head -1   # expect 404
gh pr list --repo {o}/{r} --author app/dependabot --state open --json number --jq 'length'   # expect 0
gh api -i repos/{o}/{r}/vulnerability-alerts | head -1              # expect UNCHANGED (204 where it was 204)
```

The third line is the one that matters: it proves the campaign removed noise **without** trading
away detection. All 7 members that had detection on still returned `204` after the campaign; the
alerts-off endpoint was never called.

Every worker `done` was re-run this way by the conductor before entering the register. Two
re-measurements disagreed with the claim and changed the plan — **L8**. The lesson is not that the
workers were careless; it is that a claim and a measurement are different kinds of object.

## P5 — RE-DERIVE: why the 8-day-old inventory was not reusable

The round-1 inventory reported **18** open bump PRs. At action time the fresh measurement returned
**25** — the bots had kept working, ~1 new PR/day. Acting on the snapshot would have closed 18,
left 7 standing, and reported done. Re-deriving the register from the provider each round is what
makes that impossible, and it is the same invariant `work-drain` uses on trackers. That is **L7**.

## L6 — the fork decision

One member (`ekson73/ekora`, a public fork of an upstream project we do not own) carried the config
file **from upstream**. Removing it there is divergence from upstream, not a cleanup. It was done
deliberately, recorded as reversible (restoring the file restores parity), and reported as a
divergence rather than as a fix.

## Outcome

| Declared clause | Result | Proof |
|---|---|---|
| no scheduled bump PRs generated | 9/9 config files absent on the default ref | `404` per member |
| no open bump PRs left | 0 across all 48 | count per member |
| detection not degraded | 7/7 still on | `204` per member, alerts endpoint never mutated |
| members named, none silently skipped | 2 archived members documented as read-only with nothing to change | repo flag |

Three rounds: measure → act per boundary → verify and converge the Gitflow remainder.

## Our own repos named here

`ekson73/multi-agent-os` (this repository) and `ekson73/ekora` only. Everything in the client
organization is `C1…C6`, deliberately.
