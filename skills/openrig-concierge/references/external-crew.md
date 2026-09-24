# External crews on another repository — STOP, and what is known

> **Owned layer.** First-party `openrig-architect` teaches how to design pods, seats, edges and AgentSpecs
> (`rig context get skills/core/openrig-architect`); the schema lives in `~/.openrig/reference/rig-spec.md` and
> `agent-spec.md`. This page records only whether this skill supports running a crew on someone else's git
> repository (it does not, yet) and the OpenRig facts verified while finding that out.
> **Checked against:** `rig` 0.5.14 (cc75efdd). The facts below were observed on that version, in a throwaway
> crew (§2, §5) and in the first real external-crew run (2026-09-24 UTC).

Legend: **[T0]** read-only · **[T1]** reversible · **[T2]** disruptive · **[T3]** security gate ([`tiers.md`](./tiers.md)).

## 0. STOP: external crews are not supported

**Do not launch an OpenRig crew on a target repository with this skill**: any seat, any role (writing,
reviewing or research), attended or unattended. This stays in force until the isolation design in
[#453](https://github.com/ekson73/multi-agent-os/issues/453) is validated.

Why, briefly (details in #453):

- every seat runs as the operator's OS user, so code a seat executes (tests, package scripts, hooks) is not
  contained by harness permission rules, and anything the operator can read or write is in reach;
- the harness loads the operator's user scope (settings env, hooks, plugins, MCP servers) into every seat;
- pointing a seat's cwd away from the repository drops the project's own config and gates, and pointing it at
  the repository modifies tracked files (§3);
- no tested procedure yet keeps a crew's access to the target read-only or isolated, and review found gaps in
  each candidate (desks, snapshot copies, before/after checks).

Everything below is **information**, not a recipe.

## 1. Builtin starters (information; STOP for external targets)

`rig specs ls --kind rig`; inspect one with `rig specs preview <name> --kind rig` (`--kind` is required when a
rig and a workflow share the name, as `conveyor` does on 0.5.14).

| Starter | Seats (runtime) | Good for |
|---|---|---|
| `first-project` | dev.owner (codex), dev.check (codex) | one bounded change with an independent checker |
| `implementation-pair` | dev.impl (claude-code), dev.qa (codex) | build plus cross-runtime QA |
| `adversarial-review` | orch.lead (claude-code), review.r1 (claude-code), review.r2 (codex) | independent review of existing work |
| `conveyor` | intake.lead, plan.planner, build.builder, review.reviewer (mixed) | a staged pipeline |
| `research-team` | orch.lead, research.analyst, research.synthesizer (mixed) | investigation, no code changes |
| `product-team` (preview) | 7 seats across orch1 / dev1 / rev1 | a full product loop; expensive |

Runtimes were read from the shipped `rig.yaml` files of 0.5.14; starter contents change between releases. On an
external target repository every starter is under the §0 STOP.

## 2. Reusing builtin agents from outside the install tree

`agent_ref` accepts only `local:` (relative to the rig spec's directory) or `path:` (absolute), apart from
`builtin:terminal` (rig-spec.md, validation rule 8). No scheme resolves a builtin agent by bare name, so
registering a directory in the library does **not** turn its agents into name references. The options: copy
the install's `specs/agents/<group>/` subtree beside your `rig.yaml` and refer to it as
`local:agents/<group>/<name>` (record `rig --version`; it drifts on upgrade); use `path:<install>/specs/agents/...`
(breaks on upgrade or another machine); or register the crew directory with `rig specs add <crew-dir>` [T1]
(reversible with `rig specs remove`). `rig specs ls --kind rig` prints each builtin `rig.yaml` path, and the
`agents/` tree sits under the same `specs/` parent. Validate every copied agent with `rig agent validate`.

## 3. Never point a seat's cwd at a repository checkout

On 0.5.14 OpenRig unconditionally `guidance_merge`s a managed block (the default culture plus the start
overlay) into `<cwd>/CLAUDE.md` at launch, whatever the spec says. In a repository that tracks `CLAUDE.md`, a
seat whose cwd is a checkout or worktree therefore modifies a tracked file the moment it launches (observed as
` M CLAUDE.md`). An earlier revision of this page said to point each member's `cwd` at its worktree; that is
retracted. `rig up --cwd` overrides the working directory "for all members for this run" (`rig up --help`).

## 4. Culture delivery: `startup.files` with `send_text`

On 0.5.14 `culture_file` (hint `auto`, a `.md` file) also resolves to `guidance_merge`, so it writes a managed
block into `<cwd>/CLAUDE.md` like the default culture does. To deliver a culture without writing into the cwd,
put it in the rig-level startup block; it arrives as each seat's first message once the harness is ready:

```yaml
startup:
  files:
    - path: CULTURE.md          # safe relative path (rig-spec rules 14, 21)
      delivery_hint: send_text
      required: true
  actions: []
```

`rig spec audit` then reports that no `culture_file` is set; that advisory is expected. Confirm delivery with
`rig transcript <session> --grep "<culture title>"` [T0].

## 5. Validating a spec [T0]

```bash
rig spec validate rig.yaml
rig spec preflight rig.yaml --rig-root .
rig spec audit rig.yaml                     # advisory: startup context, culture
rig agent validate agents/<group>/<name>/agent.yaml
rig up rig.yaml --plan                      # preview only; launches nothing
```

## 6. Launch, relaunch and rig identity

A rig name that is already running is refused with a `409 rig_name_running` guard (since 0.5.4). Note the rig
ID (`rigId` in `rig ps --json`): several verbs take only the ID (§8). Bringing a stopped rig back is unreliable
on 0.5.14:

- `rig up <name> --existing` can fail with "restore snapshots name an older occupant" once any seat of that
  rig was fresh-launched, even though `rig down` prints "To restore: rig up <name>".
- `rig up <spec>` with the name of a **stopped** rig creates a **second** rig with the same name. Both project
  the same tmux session names, so seat state read by name is ambiguous.

So relaunch under a **new rig name**, address rigs by ID wherever a verb takes one, and never infer seat state
from a name that two rigs share. Removing the old record with `rig down --delete` is T3 (operator).

## 7. Readiness under a nesting terminal wrapper

Where the operator's login shell runs inside a terminal wrapper that nests it, tmux's `pane_current_command`
reads the shell, not the runtime. Observed on 0.5.14: the readiness probe can fail with "the probe pane returned
to a shell" (a launch race that leaves an empty seat), and `rig seat clear-attention` stays blocked (class
`pane_identity`), so LIFECYCLE stays `att` for a healthy seat. There, a seat is ready only when all three hold:
`startupStatus=ready`, `rig capture` shows the runtime's TUI at a prompt, and `rig ps --nodes --rig <rig>`
ACTIVITY is live. An empty seat is healed with `rig snapshot <rigId>` first, then
`rig seat launch <session> --fresh --stop --reason "<capture evidence>"` [T2].

## 8. Command shapes outside a seat (0.5.14)

With `OPENRIG_SESSION_NAME` unset, pass `--rig <rig>`, `-A` or full session names (CANON C11).

- `rig snapshot`, `rig snapshot list` and `rig launch` take the rig **ID**; a name fails with "not found".
  `rig restore <snapshotId> --rig <rigId>` and `rig restore status <attemptId> --rig <rigId>` need the ID too.
- `rig launch <rigId> <node> --plan` is rejected; `--plan` applies only to a multi-seat `--seats` launch.
- `rig queue create` fails with "--source is required when OPENRIG_SESSION_NAME is not set", although its help
  calls `--source` deprecated. Set the variable for that one command to an honest external label
  (`OPENRIG_SESSION_NAME=<your-agent-id>@<rig> rig queue create …`); never borrow a seat's name.
- `rig queue handoff` without `--body` produced an empty body, and `--evidence-ref` was not kept. Pass `--body`
  with the evidence reference written inside it, and check it with `rig queue show <id>` (CANON C7).
- Outside-seat `rig send` is delivered "without sender identity": sign the body with your agent ID.
- `rig send --wait-for-idle <s> --verify` is not a turn boundary: a send during a turn can come back
  `rendered-unconfirmed` with the text staged in the input box. Judge delivery by the queue or
  `rig transcript`, not by the send result.

## 9. Teardown commands

```bash
rig snapshot <rigId>                        # T1: crash-insurance floor (the name fails: §8)
rig down <rig> --snapshot                   # T2: stops sessions, keeps records
rig archive <rig>                           # T1: hides it; `rig unarchive` reverses
```

Never pass `--delete` by default (T3).

---
Signed: Claude-RigOps-01a0-002 (sub-agent of orchestrator session `01a0`) · first authored 2026-09-23 · reduced to the STOP plus verified facts: Claude-RigOps-8f02-001, 2026-09-24 (UTC) · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/external-crew.md` · checked against `rig` 0.5.14 (cc75efdd).
