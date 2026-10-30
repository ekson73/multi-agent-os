# Worked example — the campaign that produced the laws

> This is a **worked instance**, not the method. The method is provider-agnostic and lives in
> `../SKILL.md`. Read this one for the shape of a real measurement matrix and for the probes that
> made each law observable rather than plausible.
>
> **Redaction boundary.** This repository is open source. Members in a client organization are
> referred to only as *a private client repo* (`C1…C6`). No host, account id, repository owner,
> resource ARN, secret name, person or client content appears here — see `## Identifiers in this
> document`.

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
remove the config file from the ref the provider reads, review the already-open bot PRs
**individually** (see P4 — the author does not tell a scheduled bump from a security fix, so they
are never closed in bulk), and **never call the alerts-off endpoint**. One member had the weak loss-bearing surface explicitly
authorized off; the detection surface was left on in all 48.

Had P0 been skipped, the obvious one-liner (disable the product) would have blinded a private
client repo that stores a payment application's secret-sync manifest. That near miss is **L1**.

## P1 — RECON: the measurement matrix

48 members across two credential boundaries: our personal account (20) and a client organization
(28). A third candidate account measured **0 repos** and was dropped from the fleet — recorded, not
silently omitted. A zero is only trusted after a **positive control**: the same credential first
reads its own identity (`gh api user --jq .login`) and one repository known to belong to that
boundary. A credential that fails the control (expired, wrong host, fine-grained or App token
scoped to selected repos) makes the zero `unverified`, never "empty", and the boundary stays in
the fleet as an open escalation.

Probe per column (the contract: the command is printed *with* the matrix):

| Column | Probe | Reading |
|---|---|---|
| `alerts` | `gh api -i repos/{o}/{r}/vulnerability-alerts \| head -1` | `204` = on · `404` = off **only when** the same credential reads the repo with Administration-read (positive control: `gh api repos/{o}/{r} --jq .permissions.admin` is `true`); otherwise `404` is `unverified` (GitHub also answers `404` for an under-permissioned or unauthenticated private repo) |
| `sec-upd` | `gh api repos/{o}/{r} --jq '.security_and_analysis.dependabot_security_updates.status'` | `enabled`/`disabled` · **`null` = not populated at this plan tier** |
| `config file` | `gh api -i repos/{o}/{r}/contents/.github/dependabot.yml \| head -1` (then `.yaml`) | `200` = present · `404` = absent. **Status only** — the bare call returns the file *body*, which the report contract would then print |
| `open bot PRs` | `gh pr list --repo {o}/{r} --author app/dependabot --state open --json number --jq 'length'` | count. An **ORIENT signal only** — how loud the noise is. It mixes scheduled bumps with security fixes under one author and is deliberately **not** the acceptance gate (see P4) |
| `branch gate` | `gh api -i repos/{o}/{r}/branches/{default}/protection \| head -1` **and** `gh api repos/{o}/{r}/rulesets --jq 'length'` | `200` = classic gate · `404` **does not mean unprotected** (see L3). Count only, for the same reason |

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
instead of the keyring — and it can drive a mutation under the wrong identity. The global switcher
(`gh auth switch`) was likewise **never** used. Zero collisions across three rounds. That is **L9**.

**What command-scoping does NOT buy you: trace safety.** Scoping keeps the credential out of the
shared environment; it does **not** keep it out of a shell trace. Under `set -x` (or a CI runner
that traces by default) Bash logs the *expanded* assignment, so the token lands in the transcript
exactly as it would from an `export`. Trace safety is a separate measure and it must be taken
separately: keep tracing **off** across token acquisition and the invocation that consumes it
(`set +x` around the block, restoring the previous state afterwards), or hand the credential over
by a path that never materializes it in a traced command. A campaign that prints its probes
verbatim — which the report contract requires — is precisely the environment where this matters.

## L2 in the field — the Gitflow round it cost

One member is Gitflow: default branch `main`, all work on `develop`. The config file was removed on
`develop` — correct by the repo's own convention, and **generation continued**, because the provider
reads the **default branch**. Converging it needed a second PR backporting the removal to `main`.

That is one full round spent on a ref assumption. The general form (**L2**): find which ref the
provider reads *before* editing, not after the read-back disagrees with you.

## P4 — VERIFY: the read-back that closed each member

Per member, after the merge, on the **default** ref explicitly:

```
# 1. GENERATION SOURCE gone — BOTH supported filenames, the same pair P1 discovered with
gh api -i repos/{o}/{r}/contents/.github/dependabot.yml  | head -1   # expect 404
gh api -i repos/{o}/{r}/contents/.github/dependabot.yaml | head -1   # expect 404

# 2. DETECTION unchanged (204 where it was 204) — the clause that proves nothing was traded away
gh api -i repos/{o}/{r}/vulnerability-alerts | head -1

# 3. the one member whose auto-fix surface was authorized off — read it back too
gh api repos/{o}/{r} --jq '.security_and_analysis.dependabot_security_updates.status'  # disabled

# 4. remaining bot PRs — LISTED for individual review, never bulk-counted or bulk-closed
gh pr list --repo {o}/{r} --author app/dependabot --state open --json number,title
```

Four things in that block were learned the hard way, and each is this document's own rules biting
its own example:

**Both filenames, not one.** P1 discovered the config with a `.yml` → `.yaml` fallback. A read-back
that probes only `.yml` accepts a member that still carries `.yaml`: it returns the expected `404`,
reports converged, and leaves scheduled updates fully configured. Within the declared-state set the
read-back must be as wide as discovery was — anything narrower is a false completion.

**The generation source gone is the convergence proof — not a PR count of zero.** The declared state
is *no scheduled bumps generated*. Once the config file is absent from the authority ref, no new
scheduled bump can be produced; that is the durable fact. An open-PR count is a **side effect**,
and it is the wrong acceptance gate here because the vendor opens **both** scheduled bumps and
**security fixes** under the same author, and there is no reliable label-based way to tell them
apart: the `dependencies` label is applied to both by default, and a repository that sets the
config's own `labels` option **replaces** those defaults for security updates as well, so neither
the presence of `dependencies` nor the absence of a `security` label proves anything. A predicate
built on those labels therefore misclassifies in **both** directions — it can count a security fix
as a bump (and the obvious way to make the gate pass is to close it, delaying remediation) and it
can omit a real bump under custom labels (false convergence). So the remaining PRs are **listed**
for individual review, never bulk-counted and never bulk-closed; closing a security fix is a
separate, explicitly authorized decision. That is the **L1** trap (acting on the bundle instead of
the surface) trying to reappear inside the acceptance check, and L4's shape too: a signal that is
not guaranteed to be populated cannot carry a verdict.

**The authorized-off surface is read back as well.** One member had the weak loss-bearing surface
(auto-fix PRs) explicitly authorized off. It is part of the declared state for that member, so it
gets its own read-back — `disabled`, measured, not assumed. The ORIENT-only columns (`branch gate`,
and the plan tier on members where nothing was declared about it) carry no read-back by design:
they told us whether the plan was relevant, and no campaign action changed them.

**Detection unchanged is the clause that matters.** All 7 members that had detection on still
returned `204` after the campaign; the alerts-off endpoint was never called.

Every worker `done` was re-run this way by the conductor before entering the register. Two
re-measurements disagreed with the claim and changed the plan — **L8**. The lesson is not that the
workers were careless; it is that a claim and a measurement are different kinds of object.

## P5 — RE-DERIVE: why the 8-day-old inventory was not reusable

The round-1 inventory reported **18** open bot PRs. At action time the fresh measurement returned
**25** — the bots had kept working, ~1 new PR/day. Acting on the snapshot would have handled 18,
left 7 unseen, and reported done. Re-deriving the register from the provider each round is what
makes that impossible, and it is the same invariant `work-drain` uses on trackers. That is **L7**.

(The count is the decay evidence, nothing more. It is an ORIENT signal, not the gate, and those 25
are reviewed one by one — a bulk action on a population that mixes a noise surface with a
loss-bearing one is the mistake P4 exists to refuse.)

## L6 — the fork, and the escalation it requires

One member is **our** public fork of an upstream project **we do not own**, and it carried the
config file **from upstream**. Removing it there is divergence from upstream, not a cleanup.

By this skill's own `## Hard limits` that fires an escalation — "a fork's divergence from an
upstream that is not ours" — and an escalation has a required shape that "we did it deliberately"
does not satisfy. The record must carry four things before the mutation:

| Field | Value for this member |
|---|---|
| what fires the limit | removing an upstream-inherited file diverges our fork from an upstream we do not own |
| the measurement behind it | the file is present on the fork's authority ref and originates upstream, not from us |
| reversibility | restoring the file restores parity — reversible, no data loss |
| decision + authority | **the operator's**, recorded as a named decision before the change; the campaign may not self-authorize it |

In this campaign the divergence was measured, recorded as reversible, and reported as a divergence
rather than as a fix. What the record should also have carried explicitly, and what any future run
must capture before touching a fork, is the fourth row: the operator's decision, named, with the
limit it waives. Absent that row the correct state is **pending escalation**, not done — and the
member is reported as such rather than counted as converged.

## Outcome

| Declared clause | Result | Proof |
|---|---|---|
| no scheduled bump PRs generated | 9/9 config files absent on the default ref | `404` per member, both filenames |
| already-open bot PRs disposed | each reviewed individually; none closed in bulk | per-PR disposition |
| detection not degraded | 7/7 still on | `204` per member, alerts endpoint never mutated |
| members named, none silently skipped | 2 archived members documented as read-only with nothing to change | repo flag |

Three rounds: measure → act per boundary → verify and converge the Gitflow remainder.

## Identifiers in this document

No account or repository owner is named. This repository appears only as "this repository"; the
fork member appears as *our fork of an upstream we do not own*; every member in the client
organization is `C1…C6`. Placeholders in probes (`{o}`, `{r}`, `<login-A>`, `<login-B>`) are
exactly that — the reader substitutes their own.

---
*Signed: kirocrew-worker · 2026-10-21T10:29:28-03:00*
