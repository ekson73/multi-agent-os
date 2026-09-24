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
| **T1 reversible** | the rig's coordination state (queue, library, one message in a pane) | an active delegation that names the rig (or you created the rig) | the T0 read surface of the thing you changed (rule 1) |
| **T2 disruptive** | live seat sessions and their un-snapshotted context, the daemon, config/posture | T1 gate **plus** a snapshot or explicit rollback path taken first | the changed surface's T0 read, plus `rig restore-check --rig <rig>` when sessions were touched |
| **T3 security gate / irreversible** | what code runs outside the sandbox, credentials, canonical state | a **recorded rationale** with the evidence behind it and the least-privilege option. Pass it as `--reason` where the installed `--help` exposes that flag; otherwise record it in the handoff or audit note. Never invent a flag. Rigs you do not own: escalate. | the changed surface's T0 read, plus the recorded rationale |

## Classification

### T0 — read-only

`rig --version` · `rig <cmd> --help` · `rig daemon status` · `rig daemon logs` · `rig doctor [--spec <path>]` ·
`rig preflight` · `rig crash-cart` · `rig ps` (all flags) · `rig capture` · `rig transcript` · `rig whoami` ·
`rig seat status` · `rig parked` · `rig health` (list and `explain`) · `rig health diagnose` (preview; without `--apply`) ·
`rig restore-check` · `rig restore status <attemptId> --rig <rigId>` · `rig snapshot list <rigId>` · `rig queue list|show|transitions|overdue|undelivered` ·
`rig view list|show` · `rig heartbeat` (without `--nudge`) · `rig spec validate|preflight|audit <file>` · `rig spec show <rig-id>` (running rigs only) · `rig agent validate` ·
`rig specs ls|show|preview` · `rig context list|show|preview|get` · `rig policy list|show|current` ·
`rig mode show|effective|cite|defaults` · `rig discover` · `rig up <src> --plan` · `rig launch <rigId> --seats <ids> --plan` ·
`rig seat handover <seat> --dry-run` · `rig config` / `rig config get <key>` · `rig tui` (viewing).

Caveats observed on 0.5.14:
- Outside a seat, `rig queue list` defaults to the *current* rig derived from `OPENRIG_SESSION_NAME`, so it
  prints `[]`. Use `rig queue list -A` or `--destination <session>`.
- Outside a seat, `rig heartbeat --rig <rig>` can fail with `cannot resolve shared-docs root`. It only
  applies to rigs that keep queue files in a shared-docs root.
- `rig health` returning nothing is **not** a health assertion (its own help says so).
- `rig attach` is **not** a viewer. It attaches the current shell into a rig node (`--self`), which is a
  T1 topology change. To watch a pane, use `rig capture` or the terminal provider's attach.
- `rig snapshot`, `rig snapshot list` and `rig launch` take the rig **ID** (`rigId` in `rig ps --json`); a rig
  name fails with "not found". `rig restore status <attemptId>` fails without `--rig <rigId>`.
- `rig launch <rigId> <node> --plan` is rejected: `--plan` applies only to a multi-seat `--seats` launch.

### T1 — reversible state

`rig send <session> <text>` (guarded; refuses a pane that sits at a prompt. Outside a seat it arrives
"without sender identity": sign the body) · `rig broadcast` ·
`rig queue create|claim|unclaim|update|block|resolve|handoff|handoff-and-complete|fallback|inbox-*|outbox-record`
(outside a seat, `queue create` needs an `OPENRIG_SESSION_NAME` label although `--source` is documented as
deprecated: set it for that one command to an honest external label, never a seat's name. `queue handoff`
without `--body` produced an empty body on 0.5.14 and `--evidence-ref` was not kept: pass `--body` with the
evidence reference inside it) ·
`rig heartbeat --nudge` · `rig up <new-rig>` (a rig name that is not running; reversible via `rig down`) ·
`rig snapshot <rigId>` · `rig archive` / `rig unarchive` · `rig specs add|remove|rename|sync` ·
`rig context add|rm|sync` · `rig launch <rigId> <seat>` (only for a seat that `rig ps --nodes` shows stopped; relaunching a live seat is T2) ·
`rig reconcile-session <session>` (adopts a live session; never launches, kills or types) ·
`rig seat clear-attention <session>` **without** `--reason` (the daemon runs its own evidence gate; only after the cause is resolved) ·
`rig health diagnose --apply` · `rig mode set <mode>` without `--confirm` (it only restates, exit 2) ·
`rig bind` / `rig adopt` · `rig attach --self`.

### T2 — disruptive (snapshot or rollback first)

`rig down <rig>` (always `--snapshot`) · `rig release <rig>` · `rig unclaim <session>` · `rig seat stop` ·
`rig seat launch <seat> --fresh` (a blank occupant with no continuity source; `--stop` replaces a live one. Snapshot first, as for `rig seat stop`) ·
`rig seat clean` · `rig remove <rig> <node>` · `rig shrink <rig> <pod>` · `rig up --fresh <seats>` ·
`rig launch --seats …` with holds · `rig seat handover <seat>` (run `--dry-run` first) ·
`rig restore <snapshotId> --rig <rigId>` · `rig start` (restores rigs) · `rig daemon start|stop` ·
`rig compact <session>` · `rig seat set-model` · `rig policy apply` · `rig mode set --confirm` ·
`rig config set|reset` · upgrading OpenRig (route: `rig context get skills/core/openrig-upgrade`).

### T3 — security gate or irreversible

| Command / action | Why T3 |
|---|---|
| `rig send <session> <keys> --dangerously-interact --reason "<why>"` | drives another agent's prompt. It is the only override of the prompt guard and it is audit-logged. |
| trusting Codex hooks, approving a Claude MCP server, pre-trusting a workspace | changes what runs outside the sandbox. Procedure: [`trust-gates.md`](./trust-gates.md). |
| `rig seat clear-attention <session> --reason "<attestation>"` | skips the daemon's evidence gate on your word. Use it only **after** the cause is resolved and verified with `rig capture`, and quote that evidence in the reason. Attention is diagnostic state: never clear it to turn a rig green. |
| `rig auth save|switch` · `rig provider` account switching · `rig seat set-resume-token` | credentials and identity |
| `rig down --delete` · `rig release --delete` · `rig destroy` | delete canonical records. `rig destroy` requires `--confirm destroy-openrig-state`. **Operator only.** |
| public push, PR, merge, publish, release | the boundary OpenRig itself keeps (`openrig-user`, §Coordination trust boundary), and the one the project's own governance owns |

## Rules that apply across tiers

1. **Verify each mutation through its own T0 read surface, never through an exit code.** Session and
   topology effects: `rig ps --nodes --rig <rig>` and `rig capture <session>`. `rig send` can report success
   while the text sits undelivered in the pane (upstream [#14](https://github.com/mvschwarz/openrig/issues/14),
   open as of 0.5.14; re-check it). Queue items: `rig queue show <id>`. Library: `rig specs show <name> --kind <kind>`.
   Config: `rig config get <key>`. Archive state: `rig ps --include-archived`. Snapshots: `rig snapshot list <rigId>`.
   Recorded policy: `rig policy current --spec <path>`. Mode: `rig mode effective`. A healthy pane does not
   prove that some other mutation landed.
2. **Ownership.** Rigs you did not create get T0 only, unless the delegation names them (CANON C8).
3. **OpenRig records posture; the harness enforces it** (CANON C4). A tier is a decision discipline for the
   operating agent. It is not a sandbox.
4. **Unattended seats get `deny`, not `ask`.** An `ask` rule freezes a headless seat at a prompt: first-party
   `applying-a-permission-policy` says so for `rig up`/`rig down` ("an `ask` here FREEZES an autonomous
   seat"). A frozen pane cannot even park its own queue item. For unattended rigs, encode each gated
   operation as a harness `deny` rule (fail-closed). The same first-party skill warns that prefix rules are
   best-effort: a `deny` on `Bash(rm -rf:*)` misses `rm <target> -rf`. A deny is therefore a speed bump,
   not proof of prevention. Where the stakes are real, do not give the seat the capability at all: no
   push credentials, Codex `workspace-write` sandbox, no secret access. External crews with code-writing seats
   are not supported by this skill at all for now ([`external-crew.md`](./external-crew.md), STOP).

---
Signed: Claude-RigOps-01a0-002 (sub-agent of orchestrator session `01a0`) · first authored 2026-09-23 · command-shape corrections: Claude-RigOps-8f02-001, 2026-09-24 (UTC) · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/tiers.md` · verified against `rig` 0.5.14 (cc75efdd).
