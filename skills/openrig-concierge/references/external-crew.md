# External crew recipe — an OpenRig crew on someone else's git repository

> **Owned layer.** First-party `openrig-architect` teaches how to design pods, seats, edges and AgentSpecs.
> Load it for any authoring detail: `rig context get skills/core/openrig-architect`. The schema lives in
> `~/.openrig/reference/rig-spec.md` and `agent-spec.md` (the installed reference docs; default
> `OPENRIG_HOME`). This page covers only what those sources leave to the operator: reusing builtin agents
> from outside the install tree, per-seat desks and worktrees, taking in the host project's governance,
> checkout hygiene, the user scope every seat inherits, and the conduct loop run from outside the rig.
> **Checked against:** `rig` 0.5.14 (cc75efdd). Steps 4 and 8 were validated on that version with a
> throwaway crew outside the install dir (`rig spec validate`, `rig spec preflight --rig-root .`,
> `rig agent validate`, `rig up --plan`; all passed). Steps 1, 5, 6, 9, 10, 11, 12 and 14 carry field
> corrections from the first real external-crew run on the same version (2026-09-24 UTC): three Claude
> seats on a private target repo, launched, verified, conducted and torn down from outside the rig.

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

**Boot cost is per seat and per launch.** A fresh Claude Code seat boots with the operator's whole user scope
(home-level guidance, rules, skill and plugin listings; see step 9). In the field run that was several
hundred thousand tokens of context per seat before any work, and every fresh launch or relaunch pays it
again. Prefer fewer seats, relaunch sparingly, and budget `seats × launches` of boot cost.

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

> **Runtime scope.** The desk recipe below (steps 5, 6 and 9) and [`sandboxed-seats.md`](./sandboxed-seats.md)
> are validated **only for Claude Code seats**. For Codex or any other runtime, projecting its project config
> and hooks (for Codex, `.codex/`) into a desk, and granting writable roots outside the desk (for Codex,
> `--add-dir`), are **not covered**. Do not use this recipe for those seats until it is validated for that
> runtime: stop and escalate, or run those seats' work another way.

- Keep the crew directory (`rig.yaml`, `agents/`, `CULTURE.md`) **outside** the target repo, on a "shelf".
  First-party guidance: "the spec root controls file resolution; the runtime cwd controls trust, project
  guidance, permissions, and repo context" (`openrig-architect`).
- **Retracted: do not point a member's `cwd` at a repo worktree.** An earlier revision of this page said to.
  On 0.5.14 OpenRig unconditionally `guidance_merge`s a managed block (the default culture plus the start
  overlay) into `<cwd>/CLAUDE.md` at launch, whatever the spec says. In a repo that tracks `CLAUDE.md`, a
  seat whose cwd is a worktree therefore modifies a tracked file the moment it launches (observed as
  ` M CLAUDE.md`, a block of about 200 lines).
- **Each seat's `cwd` is a desk:** an empty per-seat directory outside every git repository, mode 0700
  (`mkdir -m 0700 <crew-home>/desks/<seat>`; `git -C <desk> rev-parse --git-dir` must fail). The managed
  block, projected skills and settings fragments then land in the desk. Absolute paths and paths relative
  to the rig root both validate on 0.5.14.
- **The seat reaches its worktrees through the harness's additional-directories permission**, never through
  its cwd, and **only its own**. For Claude Code that is `permissions.additionalDirectories` in the desk's own
  `.claude/settings.local.json`. OpenRig deep-merges its own fragment into that file and keeps your keys.
  Never grant the shared parent of all the project's worktrees: that gives every seat write reach into its
  siblings' and into any ambient worktrees, and a `deny` rule there is only a speed bump (step 6).
- **One per-seat parent, one unit worktree per writer.** Before launch, create an empty parent per writing
  seat inside the location the target project's worktree policy names (MAOS default:
  [`worktree-policy`](../../worktree-policy/SKILL.md)), for example `<repo>/.worktrees/<crew>-<seat>/`, and
  grant each seat only its own parent. The seat then creates each unit worktree under that parent
  (`<repo>/.worktrees/<crew>-<seat>/<unit>`), the way the project's policy says. Two writers never share a
  worktree or a parent. A reviewer gets only the worktree checked out at the commit it reviews, read-only:
  grant that one directory and deny `Edit` and `Write` on it. **Sandboxed seats differ:** under the bash
  sandbox's home-wide read block, git fails in an additional directory, so their unit worktrees must live
  under the desk (`<desk>/units/<seat>-<unit>`). Where the project's worktree location is binding, the operator
  decides; the crew cannot ([`sandboxed-seats.md`](./sandboxed-seats.md) §3).
- **Unit worktrees come only from a reviewed, pinned commit.** Under a desk cwd the harness loads no project
  config from a worktree, so a unit worktree needs no review gate of its own as long as the seat creates it
  from the **exact commit SHA** that was reviewed (record it before launch; a moving branch name is not
  enough, because its tip can advance after the review) or from the seat's own branch. Advancing the pin
  means reviewing the new commit first. What still runs is code the seat executes (package scripts and the
  like), which the credential launch rule (step 9) covers. Seats never create a worktree from any other ref (a
  contributor's branch, a PR head, a tag); that needs a review first.
- `additionalDirectories` scopes the harness's file tools. Shell commands are bounded only by the seat's
  allowlist, so keep path-taking allow rules exact (and remember that `git` in any worktree writes the shared
  repository metadata).
- **Never use `rig up --cwd` for a crew.** It overrides the working directory "for all members for this
  run" (`rig up --help`), so every seat would share one cwd.
- The project's root checkout stays on its default branch.
- **Verify after launch [T0]:** `git -C <path> status --porcelain` (untracked files included) prints the same
  lines as the pre-launch baseline for the root checkout and for every worktree a seat can reach. Also check
  the projected paths directly: no new `CLAUDE.md`, `AGENTS.md`, `.claude/`, `.agents/`, `.mcp.json` or
  `.openrig/` in any of them. A ` M CLAUDE.md` line, or a new untracked `CLAUDE.md` in a repo that does not
  track one, means a seat's cwd is inside the repo.
- Each desk path is a new trust key: OpenRig pre-trusts it (step 9, step 14). Plan for step 9.

## 6. Culture file and posture: the crew adds orchestration, never authority

- **Deliver the culture as a startup file, not through `culture_file`.** On 0.5.14 `culture_file` (hint
  `auto`, a `.md` file) also resolves to `guidance_merge`, so it writes a managed block into
  `<cwd>/CLAUDE.md` like the default culture does (step 5). Put it in the rig-level startup block instead.
  It arrives as each seat's first message once the harness is ready:

  ```yaml
  startup:
    files:
      - path: CULTURE.md          # safe relative path (rig-spec rules 14, 21)
        delivery_hint: send_text
        required: true
    actions: []
  ```

  `rig spec audit` then reports that no `culture_file` is set. That advisory is expected and deliberate.
  Confirm delivery per seat with `rig transcript <session> --grep "<culture title>"` [T0].
- **Project-scoped config does not follow a desk seat (mandatory pre-launch step).** With the cwd outside the
  repo, the harness does not load the target's project-scoped config: **both** `.claude/settings.json` and
  `.claude/settings.local.json` (hooks, permissions, enabled plugins), `.mcp.json`, and `.claude/` rules,
  skills, commands and agents. Before launch, inventory all of it in the reviewed checkout, then give every
  item a disposition (show each diff):
  1. **Hooks, permission rules, plugin enables:** project the reviewed entries from both settings layers into
     each desk's `.claude/settings.local.json`.
  2. **MCP servers:** project them, do not only approve them. Copy the reviewed server definitions from the
     project's `.mcp.json` into the desk's `.mcp.json` (the desk is the seat's cwd, so that is the file the
     harness reads), and approve each server by exact name in the desk's `enabledMcpjsonServers`
     ([`trust-gates.md`](./trust-gates.md) §4). A server the seat's role does not need is left out.
  3. **Rules:** copy the reviewed `.claude/rules/` into the desk's `.claude/rules/`, or declare them
     unavailable in the culture and tell seats to read them from their worktree before any work.
  4. **Skills:** make them reachable, either by telling seats to read them from their worktree (for example
     the project's canonical `.agents/skills/<name>/SKILL.md`) or by copying reviewed skill directories into
     the desk.
  5. **Commands and agents:** copy the reviewed `.claude/commands/` and `.claude/agents/` directories into
     the desk's `.claude/`, or state in the culture that they are unavailable as commands and agents in that
     seat, and that the seat reads their content from its worktree when a runbook names one.
  6. **A deterministic gate that cannot be projected** (for example a hook that resolves paths relative to
     the project root) is not a risk anyone may accept: the project's gates outrank the crew (CANON C9). This
     recipe is then unusable for that repo. Stop and escalate to the operator.
- The culture's content:
  1. "The target project's AGENTS.md, runbooks and human gates outrank this file." A desk is outside the
     repo, so no seat loads the project's AGENTS.md / CLAUDE.md on its own. Tell each seat to read them
     from its worktree before any work.
  2. The project's human gates, listed **by reference** (push, PR, merge, publish, production, secrets).
     Seats stop at them and escalate.
  3. The **name** of the project's just-in-time secret procedure. It runs outside the seats and returns only
     non-secret results. No secret value ever goes into this file, a prompt or the queue
     ([`trust-gates.md`](./trust-gates.md) guardrail 3).
  4. What evidence the crew must produce, and where it goes (the queue, or files).
  5. "Issue single simple commands." See the unattended posture below.
- Examples to read: the shipped `first-project/CULTURE.md` ("Keep local edits and commits within the
  assigned change. Publishing, pushes… need their own authorization") and `factory-rsi/CULTURE.md`.
- **Permission posture.** `rig spec preflight` warns `permission_policy absent; launch_posture=floor` when
  none is set. Record one with `rig policy apply <name>` [T2]. Translating it into live harness config goes
  through `rig context get skills/applying-a-permission-policy`. OpenRig records posture and the harness
  enforces it (CANON C4). Unattended seats get `deny`, not `ask` ([`tiers.md`](./tiers.md) rule 4).
- **Unattended posture, as run in the field on Claude Code seats.** Where a credential stays seat-readable,
  seats that run project code also need the OS-enforced sandbox boundary in
  [`sandboxed-seats.md`](./sandboxed-seats.md); the items below are not a boundary on their own:
  - A positive allowlist per seat, plus a `PermissionRequest` hook in the desk settings that answers every
    remaining permission prompt `deny`, with a message telling the seat to park the item. No `ask` rule
    survives, so no pane freezes.
  - Prefix and wildcard `deny` rules are a speed bump, not a boundary. They fail open for `git -C <dir> …`,
    for flag-last forms and for chained commands. The structural controls are the desk (step 5), one
    worktree per writer, the target repo's branch protection, and no credentials in any seat (step 9).
  - Compound shell commands are checked sub-command by sub-command, so one unlisted piece (`printf`, a
    pipe, a `cd`) denies the whole line. Teach seats to issue single simple commands.
  - Commit signing that goes through an interactive agent (a desktop password manager, a hardware key)
    fails unattended. Use `git commit --no-gpg-sign` **only** where the target branch does not require
    signatures, verified read-only first. Encode the branch as one path segment: a raw `release/1.0`
    changes the API path and the rules call can come back empty, which would read as "no requirement".
    For GitHub:

    ```bash
    ENC=$(jq -rn --arg b "$BRANCH" '$b|@uri')
    gh api "repos/<owner>/<repo>/branches/$ENC" -q .name        # must print the branch name
    gh api "repos/<owner>/<repo>/rules/branches/$ENC" --paginate --slurp \
      | jq '[add[]? | select(.type=="required_signatures")] | length'   # must print 0
    gh api "repos/<owner>/<repo>/branches/$ENC/protection" -q '.required_signatures.enabled'   # must print false
    ```

    Only "Branch not protected" (HTTP 404) on the last call counts as no classic protection. Any other
    failure, an empty response, or a missing branch is **INCONCLUSIVE**: signing stays required and
    `--no-gpg-sign` is not allowed.
  - `rig send <session> '!<cmd>' --raw` [T1] runs a permission-free shell probe in the seat's real tool env,
    which you read back with `rig capture`. The runtime then answers the output with a model turn. Keep
    probes to names or flags, never values, and prefer disposable seats. List names with the shell's
    names-only builtin (`compgen -e`, or zsh `${(k)parameters[(R)*export*]}`), never with a newline-splitting
    pipeline such as `env | cut -d= -f1`, which leaks multiline values ([`trust-gates.md`](./trust-gates.md) §4).

## 7. Checkout hygiene

Launching projects runtime files into each seat's cwd (Runtime Config Disclosure in `agent-startup-guide.md`;
delivery hints in `agent-spec.md`). With desks (step 5) they land in the desk, not in a worktree. The rules
below still hold, because a seat can copy or recreate them inside a worktree:

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

Before the first launch, follow [`trust-gates.md`](./trust-gates.md) §2 and §4. OpenRig auto-accepts Claude
workspace trust for each seat's cwd, so review every desk (empty, apart from the crew's own settings file)
and every worktree a seat can reach before it gets a seat. Then: exact MCP approvals scoped to where they
apply, native Codex hook review, deny rules, no secret values anywhere a seat can read.

**User scope and environment.** Every seat also inherits the operator's harness user scope (the user settings
`env` block, hooks, plugins, user MCP config, home-level agent guidance) and the environment of the tmux
server, the OpenRig daemon and the login shell. A seat runs code as the operator user, so any credential
stored in a file it can read is reachable however empty its env is. Launch therefore requires either every
credential removed from every seat-readable source, or an OS-enforced boundary for seat-executed code
([`sandboxed-seats.md`](./sandboxed-seats.md)). Risk acceptance never substitutes; if neither is possible,
the recipe is not usable unattended: stop and escalate. Run the check in [`trust-gates.md`](./trust-gates.md)
§4, whose per-channel scrubs and live `SCRUBBED` probe are a secondary control on top of that. `NOT-SCRUBBED`
in any seat is a stop rule: take the rig down (snapshot first) and fix it before any work.

## 10. Launch [T1]

`rig up rig.yaml`. A name that is already running is refused with a `409 rig_name_running` guard (since
0.5.4). Note the rig ID from the output or from `rig ps --json` (`rigId`): several verbs take only the ID
(step 12).

**Bringing a stopped rig back is unreliable on 0.5.14.** Observed in the field run:

- `rig up <name> --existing` can fail with "restore snapshots name an older occupant" once any seat of that
  rig was fresh-launched (`rig seat launch --fresh`), even though `rig down` prints "To restore: rig up <name>".
- `rig up <spec>` with the name of a **stopped** rig creates a **second** rig with the same name. Both
  project the same tmux session names, so the stopped rig's seat can show `activity: running` from the new
  rig's pane, and any seat state read by name is ambiguous.

So: relaunch under a **new rig name**. Address rigs by ID wherever a verb takes one, and for `rig ps`, which
filters by name, read `rig ps --nodes -A --json` and select by `rigId`. Never infer seat state from a name
that two rigs share. Removing the old record with `rig down --delete` is T3 (operator).

## 11. Verify [T0]

```bash
rig ps --nodes --rig <rig>                  # every seat LIFECYCLE run, none att (see the wrapper caveat)
rig ps --nodes -A --json                    # per seat: rigId, startupStatus, agentActivity
rig capture --rig <rig> --lines 30          # panes at a ready prompt, no trust dialog
rig restore-check --rig <rig>               # restorable before any real work starts
```

Any seat at `att` → [`trust-gates.md`](./trust-gates.md), after this caveat.

**Nesting terminal wrappers.** Where the operator's login shell runs inside a terminal wrapper that nests
it, tmux's `pane_current_command` reads the shell, not the runtime. Observed on 0.5.14:

- the readiness probe fails fast with "the probe pane returned to a shell" when the launch keystrokes race
  the wrapper, so `rig up` reports `Status: partial` and the pane shows the launch command echoed above a bare
  prompt (an empty seat);
- `rig seat clear-attention` stays blocked (class `pane_identity`: "foreground command '<shell>' contradicts
  runtime"), with or without `--reason`, so LIFECYCLE stays `att` for a healthy seat.

There, a seat is ready only when all three hold: `startupStatus=ready`, `rig capture` shows the runtime's TUI
at a prompt, and `rig ps --nodes --rig <rig>` ACTIVITY is live. Heal an empty seat with `rig snapshot <rigId>` first, then
`rig seat launch <session> --fresh --stop --reason "<capture evidence>"` [T2], and re-check `startupStatus`
after about a minute: the CLI can report the same pane-identity warning while the seat comes up ready.

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
    `rig down` accepts either. `rig restore status <attemptId>` needs `--rig <rigId>`.
  - `rig launch <rigId> <node> --plan` is rejected for a single node; `--plan` applies only to a multi-seat
    `--seats` launch.
  - `rig queue create` fails with "--source is required when OPENRIG_SESSION_NAME is not set", although its
    help calls `--source` deprecated and ignored, and passing it does not help. Set the variable for that one
    command to an honest external label, for example `OPENRIG_SESSION_NAME=<your-agent-id>@<rig> rig queue create …`.
    Never borrow a seat's name.
  - `rig queue handoff` without `--body` produced a new item with an empty body, and its `--evidence-ref` was
    not kept, although its help says the source body is kept. Always pass `--body` (or `--body-file`) and
    write the evidence reference **inside the body** (for example a final line `evidence: <path or URL>`).
    Before treating the handoff as durable, check with `rig queue show <id>` that the new item's body
    carries that reference.
  - Every outside-seat `rig send` is delivered "without sender identity". Sign the message body with your
    agent ID.
  - `rig send --wait-for-idle <s> --verify` is not a turn-boundary guarantee. A send that lands during a turn
    can come back `rendered-unconfirmed` with the text still staged in the seat's input box. Judge delivery by
    what the seat did (the queue item's transitions with `rig queue show <id>`, or
    `rig transcript <session> --grep "<phrase>"`), never by the send result.

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
work is merged or recorded. Desks are crew-owned: remove them once the rig is down.

**Residue outside the crew's reach** (T3, the operator's cleanup): OpenRig pre-trusts each seat's cwd **and**
its git root in the harness's user trust store (for Claude Code, the `projects` map in `~/.claude.json`), and
those entries stay after teardown, pointing at deleted desks. The runtimes' own session transcripts, and
anything a user-scope hook recorded (step 9), stay too. List them in the handoff; do not edit global stores
from a crew.

---
Signed: Claude-RigOps-01a0-002 (sub-agent of orchestrator session `01a0`) · first authored 2026-09-23 · field corrections: Claude-RigOps-8f02-001, 2026-09-24 (UTC) · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/external-crew.md` · validated on `rig` 0.5.14 (cc75efdd).
