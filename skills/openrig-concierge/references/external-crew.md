# External crew recipe — an OpenRig crew on someone else's git repository

> **Owned layer.** First-party `openrig-architect` teaches how to design pods, seats, edges and AgentSpecs.
> Load it for any authoring detail: `rig context get skills/core/openrig-architect`. The schema lives in
> `~/.openrig/reference/rig-spec.md` and `agent-spec.md` (the installed reference docs; default
> `OPENRIG_HOME`). This page covers only what those sources leave to the operator: reusing builtin agents
> from outside the install tree, per-seat desks and worktrees, taking in the host project's governance,
> checkout hygiene, and the conduct loop run from outside the rig.
> **Checked against:** `rig` 0.5.14 (cc75efdd). Steps 4 and 8 were validated on that version with a
> throwaway crew outside the install dir (`rig spec validate`, `rig spec preflight --rig-root .`,
> `rig agent validate`, `rig up --plan`; all passed). Steps 5, 6 and 10–14 carry field corrections from the
> first real external-crew run on the same version (2026-09-24 UTC).

> **STOP: unattended crews that execute project code are not supported.** An unattended crew whose seats
> run project code (tests, package scripts, hooks) as the operator's OS user is **not supported** by this
> skill until the isolation design in [#453](https://github.com/ekson73/multi-agent-os/issues/453) is
> validated. Do not launch one. This recipe is for **attended** (human-in-the-loop) use only, with no
> credential readable by seat-executed code.

Legend: **[T0]** read-only · **[T1]** reversible · **[T2]** disruptive · **[T3]** security gate ([`tiers.md`](./tiers.md)).

## 0. Ready (DoR)

- Phase 0 of the skill passed (`rig` on PATH, daemon running, the runtimes you plan to use are installed).
- The target repo path is known, **and you have read its governance**: AGENTS.md / CLAUDE.md, its worktree
  and branch policy, its PR/merge/publish rules, its human gates, and its secret procedure.
- The delegation names the rig you are about to create. Rigs you did not create stay T0 (CANON C8).

## 1. Frame the goal

Write one bounded outcome with its acceptance evidence (a test, a PR, a report), a stop condition, the
human gates it touches, and a budget. Start with the smallest crew that can produce the evidence. Token cost
is the most common complaint about large fleets, so two seats are a better start than seven.

## 2. Choose a starter [T0]

Builtin starters (`rig specs ls --kind rig`; inspect one with `rig specs preview <name> --kind rig`. `--kind` is required when a rig and a workflow share the name, as `conveyor` does on 0.5.14):

| Starter | Seats (runtime) | Good for |
|---|---|---|
| `first-project` | dev.owner (codex), dev.check (codex) | one bounded change with an independent checker |
| `implementation-pair` | dev.impl (claude-code), dev.qa (codex) | build plus cross-runtime QA |
| `adversarial-review` | orch.lead (claude-code), review.r1 (claude-code), review.r2 (codex) | independent review of existing work |
| `conveyor` | intake.lead, plan.planner, build.builder, review.reviewer (mixed) | a staged pipeline |
| `research-team` | orch.lead, research.analyst, research.synthesizer (mixed) | investigation, no code changes |
| `product-team` (preview) | 7 seats across orch1 / dev1 / rev1 | a full product loop; expensive |

Runtimes were read from the shipped `rig.yaml` files of 0.5.14. Starter contents change between releases,
so always `rig specs preview <name> --kind rig` before you rely on one.

## 3. Shape the topology

Pods, seats, runtimes and edges (`delegates_to`, `spawned_by`, `can_observe`, `collaborates_with`,
`escalates_to`) follow `openrig-architect`. Two points it does not settle:

- **Reviewer independence:** put the reviewer in a different pod and, where possible, on a different
  runtime from the builder (CANON C6).
- **Human gate seat:** name who answers human-gate questions. Route with
  `rig context get skills/core/human-in-the-loop`. The crew never answers *as* the human.

## 4. Reuse builtin agents from outside the install tree

`agent_ref` accepts only `local:` (relative to the rig spec's directory) or `path:` (absolute), apart from
`builtin:terminal` (rig-spec.md, validation rule 8). No scheme resolves a builtin agent by bare name. So
registering a directory in the library does **not** turn its agents into name references. Three options:

| Option | How | Cost | Use when |
|---|---|---|---|
| **Copy the tree (recommended)** | copy the install's `specs/agents/<group>/` subtree beside your `rig.yaml`; refer to it as `local:agents/<group>/<name>` | a snapshot that drifts from later CLI upgrades. Record the source version (`rig --version`) in the crew README and diff it on upgrade. | any crew you keep |
| `path:` absolute | `path:<install>/specs/agents/<group>/<name>` | hardcodes the install path, which includes the version manager's directories. Breaks on upgrade or on another machine. | a throwaway probe |
| Register the crew dir [T1] | `rig specs add <crew-dir>` (a directory holding `rig.yaml` plus its `agents/`) | a library mutation, reversible with `rig specs remove` | you want `rig up <crew-name>` by name. Confirm with `rig specs preview <name>` and `rig up <name> --plan`. |

To find the install's `specs/agents/` directory, run `rig specs ls --kind rig`. Each row prints the absolute
path of a builtin `rig.yaml`, and the `agents/` tree sits under the same `specs/` parent. Validate every
agent you copy: `rig agent validate agents/<group>/<name>/agent.yaml`.

## 5. Desks, worktrees and `cwd` — one writing seat, one worktree

- Keep the crew directory (`rig.yaml`, `agents/`, `CULTURE.md`) **outside** the target repo, on a "shelf".
  First-party guidance: "the spec root controls file resolution; the runtime cwd controls trust, project
  guidance, permissions, and repo context" (`openrig-architect`).
- **Retracted: do not point a member's `cwd` at a repo worktree.** An earlier revision of this page said to.
  On 0.5.14 OpenRig unconditionally `guidance_merge`s a managed block (the default culture plus the start
  overlay) into `<cwd>/CLAUDE.md` at launch, whatever the spec says. In a repo that tracks `CLAUDE.md`, a seat
  whose cwd is a worktree therefore modifies a tracked file the moment it launches (observed as ` M CLAUDE.md`).
- **Replacement, for attended use only (see the STOP above): each seat's `cwd` is a desk,** an empty per-seat
  directory outside every git repository (`mkdir -m 0700 <crew-home>/desks/<seat>`). The managed block and
  projected files then land in the desk. The seat reaches its own worktree through the harness's
  additional-directories permission (for Claude Code, `permissions.additionalDirectories` in the desk's
  `.claude/settings.local.json`); never grant the shared parent of all worktrees. That grant scopes the
  harness's file tools only. It is not isolation: code the seat runs executes as the operator.
- Because the desk is outside the repo, the harness does not load the target's project-scoped config: its
  `.claude/` settings and permissions, hooks, MCP servers, rules (including path-scoped ones, whose `paths:`
  would resolve against the desk) and skills. Seats read the project's AGENTS.md / CLAUDE.md from their
  worktree (step 6). **Launch stop:** if the target relies on **any** mandatory project-scoped config of that
  kind, do not use the desk layout. Projecting it into a desk is not covered by this skill yet
  ([#452](https://github.com/ekson73/multi-agent-os/issues/452),
  [#453](https://github.com/ekson73/multi-agent-os/issues/453)).
- **Required before launch [T0]: inventory the target's project-scoped config.** In the reviewed checkout,
  list names and paths only, never values: in `.claude/settings.json` and `.claude/settings.local.json`, the
  hook events, permission rules and `enabledPlugins` entries (for example
  `jq -r '(.hooks // {} | keys[]), (.permissions // {} | keys[]), (.enabledPlugins // {} | keys[])' <file>`);
  the server names in `.mcp.json` (`jq -r '.mcpServers // {} | keys[]' .mcp.json`); every file under
  `.claude/rules/`, flagging each one whose frontmatter has `paths:` (`grep -l '^paths:' -r .claude/rules`);
  the entries under `.claude/skills/`, `.claude/commands/` and `.claude/agents/`; and the equivalent `.codex/`
  and `.agents/` directories. Classify each item as mandatory or optional from the project's own governance
  docs (AGENTS.md, CLAUDE.md, CONTRIBUTING, runbooks). Any item that is mandatory, or whose status is unknown
  or cannot be inspected, is a stop for the desk layout. Record the inventory and its classification in the
  handoff.
- Give **every writing seat its own git worktree** of the target repo, made the way the target project's own
  worktree policy says (MAOS default: [`worktree-policy`](../../worktree-policy/SKILL.md)).
- **Never use `rig up --cwd` for a crew.** It overrides the working directory "for all members for this
  run" (`rig up --help`), so every seat would share one cwd.
- The project's root checkout stays on its default branch. Reviewers read a worktree checked out at the
  commit they review.
- **Verify after launch [T0]:** `git -C <path> status --porcelain` (untracked files included) prints the same
  lines as before launch for the root checkout and every worktree a seat can reach. A ` M CLAUDE.md` line, or
  a new untracked `CLAUDE.md`, means a seat's cwd is inside the repo.
- Every new desk path is a new trust key for Claude and for Codex. Plan for step 9.

## 6. Culture file and posture: the crew adds orchestration, never authority

- **Deliver the culture as a startup file, not through `culture_file`.** On 0.5.14 `culture_file` (hint
  `auto`, a `.md` file) also resolves to `guidance_merge`, so it writes a managed block into `<cwd>/CLAUDE.md`
  like the default culture does. Put it in the rig-level startup block instead; it arrives as each seat's
  first message once the harness is ready:

  ```yaml
  startup:
    files:
      - path: CULTURE.md          # safe relative path (rig-spec rules 14, 21)
        delivery_hint: send_text
        required: true
    actions: []
  ```

  `rig spec audit` then reports that no `culture_file` is set. That advisory is expected and deliberate.
  Confirm delivery per seat with `rig transcript <session> --grep "<culture title>"` [T0]. Its content:
  1. "The target project's AGENTS.md, runbooks and human gates outrank this file." A desk is outside the
     repo, so no seat loads the project's AGENTS.md / CLAUDE.md on its own: tell each seat to read them from
     its worktree before any work.
  2. The project's human gates, listed **by reference** (push, PR, merge, publish, production, secrets).
     Seats stop at them and escalate.
  3. The **name** of the project's just-in-time secret procedure. It runs outside the seats and returns only
     non-secret results. No secret value ever goes into this file, a prompt or the queue
     ([`trust-gates.md`](./trust-gates.md) guardrail 3).
  4. What evidence the crew must produce, and where it goes (the queue, or files).
- Examples to read: the shipped `first-project/CULTURE.md` ("Keep local edits and commits within the
  assigned change. Publishing, pushes… need their own authorization") and `factory-rsi/CULTURE.md`.
- **Permission posture.** `rig spec preflight` warns `permission_policy absent; launch_posture=floor` when
  none is set. Record one with `rig policy apply <name>` [T2]. Translating it into live harness config goes
  through `rig context get skills/applying-a-permission-policy`. OpenRig records posture and the harness
  enforces it (CANON C4). Unattended seats get `deny`, not `ask` ([`tiers.md`](./tiers.md) rule 4).

## 7. Checkout hygiene

Launching projects runtime files into each seat's cwd (Runtime Config Disclosure in `agent-startup-guide.md`;
delivery hints in `agent-spec.md`):

- `.claude/skills/<skill>/`, `.agents/skills/<skill>/`, `.claude/settings.local.json`, `.mcp.json`, `.openrig/`
- managed blocks inside `CLAUDE.md` / `AGENTS.md`, delimited by
  `<!-- BEGIN OpenRig MANAGED BLOCK: <name> -->` … `<!-- END OpenRig MANAGED BLOCK: <name> -->`

Rules:

1. **Never commit projected files or managed blocks.** Stage explicit paths only (no `git add -A`). Before each
   commit, check `git status --porcelain` and `git diff -- CLAUDE.md AGENTS.md`.
2. **Never blanket-ignore** `.claude/`, `.agents/` or `.codex/`: the project may commit its own files there.
   If you need exclusions, add exact paths to the repo-local `.git/info/exclude`, which is never committed.
   Do not change the project's `.gitignore` unless its governance asks for that.
3. **Clean only crew-owned worktrees**, and only after harvest (step 13).

## 8. Validate [T0]

```bash
rig spec validate rig.yaml
rig spec preflight rig.yaml --rig-root .
rig spec audit rig.yaml                     # advisory: startup context, culture
rig agent validate agents/<group>/<name>/agent.yaml
rig up rig.yaml --plan                      # preview only; launches nothing
```

## 9. Pre-clear trust gates [T3]

Before the first launch, follow [`trust-gates.md`](./trust-gates.md) §2 and §4, keyed to each seat's
**actual cwd, the desk**. OpenRig auto-accepts Claude workspace trust for the desk, so review the desk (empty,
apart from the settings the crew placed there) before it gets a seat. MCP approvals, settings and native Codex
hook review also apply to the desk, because that is where the harness reads them. Review each **worktree**
separately, before it is granted to a seat through additional directories: its checkout, and that it holds
nothing a seat should not reach. Then: deny rules, and no secret values anywhere a seat can read.

## 10. Launch [T1]

`rig up rig.yaml`. A name that is already running is refused with a `409 rig_name_running` guard (since
0.5.4). Note the rig ID from the output or from `rig ps --json` (`rigId`): several verbs take only the ID
(step 12).

**Bringing a stopped rig back is unreliable on 0.5.14.** Observed in the field run:

- `rig up <name> --existing` can fail with "restore snapshots name an older occupant" once any seat of that
  rig was fresh-launched, even though `rig down` prints "To restore: rig up <name>".
- `rig up <spec>` with the name of a **stopped** rig creates a **second** rig with the same name. Both
  project the same tmux session names, so seat state read by name is ambiguous.

So relaunch under a **new rig name**, address rigs by ID wherever a verb takes one, and never infer seat
state from a name that two rigs share. Removing the old record with `rig down --delete` is T3 (operator).

## 11. Verify [T0]

```bash
rig ps --nodes --rig <rig>                  # every seat LIFECYCLE run, none att (see the wrapper caveat)
rig ps --nodes -A --json                    # per seat: rigId, startupStatus, agentActivity
rig capture --rig <rig> --lines 30          # panes at a ready prompt, no trust dialog
rig restore-check --rig <rig>               # restorable before any real work starts
```

Any seat at `att` → [`trust-gates.md`](./trust-gates.md), after this caveat.

**Nesting terminal wrappers.** Where the operator's login shell runs inside a terminal wrapper that nests
it, tmux's `pane_current_command` reads the shell, not the runtime. Observed on 0.5.14: the readiness probe
can fail with "the probe pane returned to a shell" (a launch race that leaves an empty seat), and
`rig seat clear-attention` stays blocked (class `pane_identity`), so LIFECYCLE stays `att` for a healthy seat.
There, a seat is ready only when all three hold: `startupStatus=ready`, `rig capture` shows the runtime's TUI
at a prompt, and `rig ps --nodes --rig <rig>` ACTIVITY is live. Heal an empty seat with `rig snapshot <rigId>`
first, then `rig seat launch <session> --fresh --stop --reason "<capture evidence>"` [T2].

## 12. Conduct from outside the rig [T0 loop]

You are not a seat: `OPENRIG_SESSION_NAME` is unset, so any verb that defaults to "my rig" needs an explicit
scope. One tick:

```bash
rig ps --nodes --rig <rig>                  # lifecycle + activity per seat
rig capture --rig <rig> --lines 30          # what the panes say
rig queue list -A                           # outside a seat plain `queue list` is empty; or --destination <session>
rig parked --rig <rig>                      # stopped seats that still owe work
rig view show escalations --rig <rig>       # what needs a human
rig health --rig <rig>                      # an empty result is not a health claim
rig heartbeat --rig <rig>                   # only for rigs with a shared-docs queue root; otherwise it errors
```

- **Cadence:** tight while seats boot and while a seat waits at a gate. Relax it while the queue moves.
- **Intervene** by the smallest step that works: a `rig send` nudge [T1] → refocus → escalate. The ladder is
  first-party: `rig context get skills/pods/oversight-team` and `rig context get skills/core/watchdog`.
- **Human-gate questions** from a seat go to the operator. The crew never answers as the human.
- **Command shapes outside a seat (0.5.14):**
  - `rig snapshot`, `rig snapshot list` and `rig launch` take the rig **ID**; a name fails with "not found".
    `rig restore <snapshotId> --rig <rigId>` and `rig restore status <attemptId> --rig <rigId>` need the ID too.
  - `rig launch <rigId> <node> --plan` is rejected; `--plan` applies only to a multi-seat `--seats` launch.
  - `rig queue create` fails with "--source is required when OPENRIG_SESSION_NAME is not set", although its
    help calls `--source` deprecated. Set the variable for that one command to an honest external label
    (`OPENRIG_SESSION_NAME=<your-agent-id>@<rig> rig queue create …`). Never borrow a seat's name.
  - `rig queue handoff` without `--body` produced an empty body, and `--evidence-ref` was not kept. Pass
    `--body` with the evidence reference written inside it, and check it with `rig queue show <id>`.
  - Outside-seat `rig send` is delivered "without sender identity": sign the body with your agent ID.
  - `rig send --wait-for-idle <s> --verify` is not a turn boundary: a send during a turn can come back
    `rendered-unconfirmed` with the text staged in the input box. Judge delivery by the queue or
    `rig transcript`, not by the send result.

## 13. Harvest

Findings reach the target project **only through its own channels** (its PR flow, its tracker), with
evidence refs. Use `rig transcript <session> --grep "<pattern>"` [T0] to recover decisions. Feed lessons back
into the crew's `CULTURE.md` or into this skill.

## 14. Teardown

```bash
rig snapshot <rigId>                        # T1: crash-insurance floor (the name fails: step 12)
rig down <rig> --snapshot                   # T2: stops sessions, keeps records
rig archive <rig>                           # T1: hides it; `rig unarchive` reverses
```

Never pass `--delete` by default (T3). Afterwards, restore any managed-block hunks in the worktrees and
remove the crew-owned worktrees through the project's worktree procedure, only once each one is clean and its
work is merged or recorded.

---
Signed: Claude-RigOps-01a0-002 (sub-agent of orchestrator session `01a0`) · first authored 2026-09-23 · field corrections: Claude-RigOps-8f02-001, 2026-09-24 (UTC) · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/external-crew.md` · validated on `rig` 0.5.14 (cc75efdd).
