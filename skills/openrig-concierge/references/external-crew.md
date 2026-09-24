# External crew recipe — an OpenRig crew on someone else's git repository

> **Owned layer.** First-party `openrig-architect` teaches how to design pods, seats, edges and AgentSpecs.
> Load it for any authoring detail: `rig context get skills/core/openrig-architect`. The schema lives in
> `~/.openrig/reference/rig-spec.md` and `agent-spec.md` (the installed reference docs; default
> `OPENRIG_HOME`). This page covers only what those sources leave to the operator: reusing builtin agents
> from outside the install tree, per-seat worktrees, taking in the host project's governance, checkout
> hygiene, and the conduct loop run from outside the rig.
> **Checked against:** `rig` 0.5.14 (cc75efdd). Steps 4 and 8 were validated on that version with a
> throwaway crew outside the install dir (`rig spec validate`, `rig spec preflight --rig-root .`,
> `rig agent validate`, `rig up --plan`; all passed).

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

Builtin starters (`rig specs ls --kind rig`; inspect one with `rig specs preview <name>`):

| Starter | Seats (runtime) | Good for |
|---|---|---|
| `first-project` | dev.owner (codex), dev.check (codex) | one bounded change with an independent checker |
| `implementation-pair` | dev.impl (claude-code), dev.qa (codex) | build plus cross-runtime QA |
| `adversarial-review` | orch.lead (claude-code), review.r1 (claude-code), review.r2 (codex) | independent review of existing work |
| `conveyor` | intake.lead, plan.planner, build.builder, review.reviewer (mixed) | a staged pipeline |
| `research-team` | orch.lead, research.analyst, research.synthesizer (mixed) | investigation, no code changes |
| `product-team` (preview) | 7 seats across orch1 / dev1 / rev1 | a full product loop; expensive |

Runtimes were read from the shipped `rig.yaml` files of 0.5.14. Starter contents change between releases,
so always `rig specs preview` before you rely on one.

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

## 5. Worktrees and `cwd` — one writing seat, one worktree

- Keep the crew directory (`rig.yaml`, `agents/`, `CULTURE.md`) **outside** the target repo, on a "shelf".
  First-party guidance: "the spec root controls file resolution; the runtime cwd controls trust, project
  guidance, permissions, and repo context" (`openrig-architect`).
- Give **every writing seat its own git worktree** of the target repo, made the way the target project's own
  worktree policy says (MAOS default: [`worktree-policy`](../../worktree-policy/SKILL.md)). Point the
  member's `cwd` at that worktree. Absolute paths and paths relative to the rig root both validate on 0.5.14.
- **Never use `rig up --cwd` for a crew with several worktrees.** It overrides the working directory "for
  all members for this run" (`rig up --help`), so every seat would land in the same tree.
- The project's root checkout stays on its default branch. Reviewers read a worktree checked out at the
  commit they review.
- Every new worktree path is a new trust key for Claude and for Codex. Plan for step 9.

## 6. Culture file and posture: the crew adds orchestration, never authority

- `culture_file` must be a safe relative path (rule 14), so it lives in the crew directory. Its content:
  1. "The target project's AGENTS.md, runbooks and human gates outrank this file." Each seat's runtime
     already loads the project's AGENTS.md / CLAUDE.md from its cwd.
  2. The project's human gates, listed **by reference** (push, PR, merge, publish, production, secrets).
     Seats stop at them and escalate.
  3. The project's just-in-time secret procedure. Seats never call a secret manager themselves
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

Before the first launch in any new worktree, follow [`trust-gates.md`](./trust-gates.md) §4: exact MCP
approvals, native Codex hook review, deny rules, no secrets.

## 10. Launch [T1]

`rig up rig.yaml`. A name that is already running is refused with a `409 rig_name_running` guard (since
0.5.4): pick a new name. To bring a stopped rig back by name, use `rig up <name> --existing`.

## 11. Verify [T0]

```bash
rig ps --nodes --rig <rig>                  # every seat LIFECYCLE run, none att
rig capture --rig <rig> --lines 30          # panes at a ready prompt, no trust dialog
rig restore-check --rig <rig>               # restorable before any real work starts
```

Any seat at `att` → [`trust-gates.md`](./trust-gates.md).

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

## 13. Harvest

Findings reach the target project **only through its own channels** (its PR flow, its tracker), with
evidence refs. Use `rig transcript <session> --grep "<pattern>"` [T0] to recover decisions. Feed lessons back
into the crew's `CULTURE.md` or into this skill.

## 14. Teardown

```bash
rig snapshot <rig>                          # T1: crash-insurance floor
rig down <rig> --snapshot                   # T2: stops sessions, keeps records
rig archive <rig>                           # T1: hides it; `rig unarchive` reverses
```

Never pass `--delete` by default (T3). Afterwards, restore any managed-block hunks in the worktrees and
remove the crew-owned worktrees through the project's worktree procedure, only once each one is clean and its
work is merged or recorded.

---
Signed: Claude-RigOps-01a0-002 (sub-agent of orchestrator session `01a0`) · first authored 2026-09-23 · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/external-crew.md` · validated on `rig` 0.5.14 (cc75efdd).
