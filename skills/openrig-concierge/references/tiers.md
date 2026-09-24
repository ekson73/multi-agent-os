# Mutation tiers T0–T3 — `rig` command classification

> **Owned layer.** OpenRig ships the raw material (the `openrig-user` trust-boundary section, policy
> modes, `applying-a-permission-policy`) but no canonical tier table. This page is a
> citation-backed digest of that material. It is not new policy.
> **Checked against:** `rig` **0.5.14 (cc75efdd)**. Every command below appears in its `--help`.
> Re-check with `rig <cmd> --help` after an upgrade (fact ladder, [`sources.md`](./sources.md)).

## Why tiers, and why these ones

OpenRig's own doctrine warns against arbitrary boundaries: "Do not add or defend a restriction
without naming the protected asset, the actual adversary, the blocked attack path, and the concrete
consequence" (`rig context get openrig-user`, §Coordination trust boundary). Each tier below therefore
names **the asset it protects**. A tier that cannot name its asset should be deleted.

| Tier | Protected asset | Gate before acting | Verify after acting |
|---|---|---|---|
| **T0 read-only** | none (observation only) | none. Runs freely, including on rigs you do not own. | n/a |
| **T1 reversible** | the rig's coordination state (queue, library, one message in a pane) | an active delegation that names the rig (or you created the rig) | a T0 read that shows the effect |
| **T2 disruptive** | live seat sessions and their un-snapshotted context, the daemon, config/posture | T1 gate **plus** a snapshot or explicit rollback path taken first | a T0 read, plus `rig restore-check --rig <rig>` when sessions were touched |
| **T3 security gate / irreversible** | what code runs outside the sandbox, credentials, canonical state | recorded `--reason`, the evidence behind it, the least-privilege option. Rigs you do not own: escalate. | a T0 read plus an audit line naming the decision |

## Classification

### T0 — read-only

`rig --version` · `rig <cmd> --help` · `rig daemon status` · `rig daemon logs` · `rig doctor [--spec <path>]` ·
`rig preflight` · `rig crash-cart` · `rig ps` (all flags) · `rig capture` · `rig transcript` · `rig whoami` ·
`rig seat status` · `rig parked` · `rig health` (list and `explain`) · `rig health diagnose` (preview; without `--apply`) ·
`rig restore-check` · `rig restore status <attemptId>` · `rig snapshot list <rig>` · `rig queue list|show|transitions|overdue|undelivered` ·
`rig view list|show` · `rig heartbeat` (without `--nudge`) · `rig spec validate|preflight|audit|show` · `rig agent validate` ·
`rig specs ls|show|preview` · `rig context list|show|preview|get` · `rig policy list|show|current` ·
`rig mode show|effective|cite|defaults` · `rig discover` · `rig up <src> --plan` · `rig launch <rig> --plan` ·
`rig seat handover <seat> --dry-run` · `rig config` / `rig config get <key>` · `rig tui` (viewing).

Caveats observed on 0.5.14:
- Outside a seat, `rig queue list` defaults to the *current* rig derived from `OPENRIG_SESSION_NAME`, so it
  prints `[]`. Use `rig queue list -A` or `--destination <session>`.
- Outside a seat, `rig heartbeat --rig <rig>` can fail with `cannot resolve shared-docs root`. It only
  applies to rigs that keep queue files in a shared-docs root.
- `rig health` returning nothing is **not** a health assertion (its own help says so).
- `rig attach` is **not** a viewer. It attaches the current shell into a rig node (`--self`), which is a
  T1 topology change. To watch a pane, use `rig capture` or the terminal provider's attach.

### T1 — reversible state

`rig send <session> <text>` (guarded; refuses a pane that sits at a prompt) · `rig broadcast` ·
`rig queue create|claim|unclaim|update|block|resolve|handoff|handoff-and-complete|fallback|inbox-*|outbox-record` ·
`rig heartbeat --nudge` · `rig up <new-rig>` (a rig name that is not running; reversible via `rig down`) ·
`rig snapshot <rig>` · `rig archive` / `rig unarchive` · `rig specs add|remove|rename|sync` ·
`rig context add|rm|sync` · `rig launch <rig> <seat>` (relaunch a stopped seat) · `rig seat launch` ·
`rig reconcile-session <session>` (adopts a live session; never launches, kills or types) ·
`rig seat clear-attention <session>` **without** `--reason` (the daemon runs its own evidence gate) ·
`rig health diagnose --apply` · `rig mode set <mode>` without `--confirm` (it only restates, exit 2) ·
`rig bind` / `rig adopt` · `rig attach --self`.

### T2 — disruptive (snapshot or rollback first)

`rig down <rig>` (always `--snapshot`) · `rig release <rig>` · `rig unclaim <session>` · `rig seat stop` ·
`rig seat clean` · `rig remove <rig> <node>` · `rig shrink <rig> <pod>` · `rig up --fresh <seats>` ·
`rig launch --seats …` with holds · `rig seat handover <seat>` (run `--dry-run` first) ·
`rig restore <snapshotId> --rig <rig>` · `rig start` (restores rigs) · `rig daemon start|stop` ·
`rig compact <session>` · `rig seat set-model` · `rig policy apply` · `rig mode set --confirm` ·
`rig config set|reset` · upgrading OpenRig (route: `rig context get skills/core/openrig-upgrade`).

### T3 — security gate or irreversible

| Command / action | Why T3 |
|---|---|
| `rig send <session> <keys> --dangerously-interact --reason "<why>"` | drives another agent's prompt. It is the only override of the prompt guard and it is audit-logged. |
| trusting Codex hooks, approving a Claude MCP server, pre-trusting a workspace | changes what runs outside the sandbox. Procedure: [`trust-gates.md`](./trust-gates.md). |
| `rig seat clear-attention <session> --reason "<attestation>"` | skips the daemon's evidence gate on your word. Attest only what you verified yourself with `rig capture`. |
| `rig auth save|switch` · `rig provider` account switching · `rig seat set-resume-token` | credentials and identity |
| `rig down --delete` · `rig release --delete` · `rig destroy` | delete canonical records. `rig destroy` requires `--confirm destroy-openrig-state`. **Operator only.** |
| public push, PR, merge, publish, release | the boundary OpenRig itself keeps (`openrig-user`, §Coordination trust boundary), and the one the project's own governance owns |

## Rules that apply across tiers

1. **Verify with a T0 read, never with an exit code.** `rig send` can report success while the text sits
   undelivered in the pane (upstream [#14](https://github.com/mvschwarz/openrig/issues/14)). Confirm with
   `rig capture <session>`.
2. **Ownership.** Rigs you did not create get T0 only, unless the delegation names them (CANON C8).
3. **OpenRig records posture; the harness enforces it** (CANON C4). A tier is a decision discipline for the
   operating agent. It is not a sandbox.
4. **Unattended seats get `deny`, not `ask`.** An `ask` rule freezes a headless seat at a prompt: first-party
   `applying-a-permission-policy` says so for `rig up`/`rig down` ("an `ask` here FREEZES an autonomous
   seat"). A frozen pane cannot even park its own queue item. For unattended rigs, encode each gated
   operation as a harness `deny` rule (fail-closed). The same first-party skill warns that prefix rules are
   best-effort: a `deny` on `Bash(rm -rf:*)` misses `rm <target> -rf`. A deny is therefore a speed bump,
   not proof of prevention. Where the stakes are real, do not give the seat the capability at all: no
   push credentials, Codex `workspace-write` sandbox, no secret access.

---
Signed: Claude-RigOps-5a1e-002 · 2026-09-23T22:50:00-03:00 · verified against `rig` 0.5.14 (cc75efdd).
