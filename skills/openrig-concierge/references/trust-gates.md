# Startup trust gates — diagnose, decide, clear, pre-configure

> **Owned layer.** OpenRig covers lifecycle recovery first-party (`rig context get skills/core/rig-lifecycle`,
> `openrig-user` §`rig seat clear-attention`). It does not cover the **harness** prompts that stop a seat
> before OpenRig can see it as ready. This page covers only those prompts.
> **Checked against:** `rig` 0.5.14 (cc75efdd), Claude Code 2.1.281, Codex CLI 0.156.1, on 2026-09-23.
> Harness prompts change between harness releases. Re-check each prompt's text with `rig capture` before you act.

## Guardrails (non-negotiable — mirrored in CANON C5)

1. **Codex hooks are trusted only through Codex's native review.** Choose *Review hooks*, then read every
   hook definition **and the script each one runs**. If every hook is understood and benign, finish the
   review in Codex and let Codex record its own trust state. **Never write, synthesize or compare
   `trusted_hash` values by hand.** The hashing algorithm is undocumented and has already changed under
   OpenRig once ([mvschwarz/openrig#17](https://github.com/mvschwarz/openrig/issues/17)). If any hook is
   unclear, do one of three things: choose *Continue without trusting*, switch that seat to `claude-code`,
   or park the seat.
2. **Unattended seats use `deny` rules, not `ask` prompts.** A prompt blocks the pane. The seat can then no
   longer park its own queue item, and the rig stalls without saying why. Encode every gated operation as a
   harness `deny` (fail-closed). See [`tiers.md`](./tiers.md) rule 4 for how far a prefix deny can be trusted.
3. **Secret values never enter a seat.** A seat does not call a secret-manager CLI (for example `op`), read a
   secret store, or receive a secret by any channel: not through `rig send`, queue items, prompts, startup
   files, culture files, or seat-readable environment variables, config or files. When work needs a
   credential, the project's own just-in-time secret procedure performs the authenticated operation
   **outside the seat**, run by whoever that procedure names, and hands back only non-secret results. Back
   this with a harness `deny` on the secret CLI (for example `Bash(op:*)`). That deny is best-effort; the
   real control is that no secret value is ever placed where a seat can read it.
4. **Never trust an MCP server, hook or operation because of its name, path or owner alone.** Names are free
   to choose, and a file in `~/.codex/` or a repo's `.codex/` could have been written by anything. Read what
   it executes.
5. **Attention is diagnostic state.** Clear it only after its cause is resolved and verified (§3). Never
   clear it to make a rig look green.

## 1. Symptom → diagnosis

| Where | What you see | Meaning |
|---|---|---|
| `rig ps --nodes --rig <rig>` | LIFECYCLE `att`, REASON `Startup requires attention: …` | the harness is waiting at an interactive prompt |
| `rig ps --nodes --rig <rig>` | LIFECYCLE `att`, REASON `Readiness timeout after 30s …` | the readiness probe gave up; often a prompt it does not recognize |
| `rig restore-check --rig <rig>` | class `attention_required` | same condition, seen from the restore side |
| any `rig` error | `[object Object]` | the CLI lost the daemon's structured remediation ([#18](https://github.com/mvschwarz/openrig/issues/18), as of 0.5.14; see §5). Read `rig ps --nodes --rig <rig> --json` instead. |
| `rig up` / `rig ps --nodes --rig <rig>` | `probe pane returned to a shell`, or `clear-attention` refused with class `pane_identity` ("foreground command '<shell>' contradicts runtime") | **not a trust gate** when the login shell runs inside a nesting terminal wrapper (observed on 0.5.14). A seat is ready only when `startupStatus=ready`, `rig capture` shows the runtime's TUI at a prompt, and `rig ps --nodes --rig <rig>` ACTIVITY is live. Heal an empty seat as in [`external-crew.md`](./external-crew.md) step 11. |

Then read the pane (T0): `rig capture <session> --lines 40`. Classify the prompt by its text:

| Class | Prompt text (as observed) | Where it comes from |
|---|---|---|
| **A. Claude workspace trust** | the "trust the files in this folder" dialog | first launch of Claude in a cwd that is not yet trusted. Accepting it enables the project's own configuration: its hooks, permission rules, MCP servers and instructions. **OpenRig 0.5.14 auto-accepts it for managed seats.** It pre-writes `projects["<path>"].hasTrustDialogAccepted` into `~/.claude.json` and drives the dialog (Runtime Config Disclosure in `~/.openrig/reference/agent-startup-guide.md`). That is trust keyed by path with no review (guardrail 4). Flag it, and do the review yourself **before** launch (section 2). The dialog itself shows up only when that write missed, for example because the daemon's HOME differs from the seat's. |
| **B. Claude project MCP approval** | `New MCP server found in this project: <name>` → *Use this MCP server* / *Use this and all future MCP servers in this project* / *Continue without using this MCP server* | a `.mcp.json` in the seat's cwd. Claude asks before it uses any project-scoped server ([Claude Code MCP docs](https://code.claude.com/docs/en/mcp)). |
| **C. Codex hook review** | `Hooks need review` · `N hooks are new or changed.` · `Hooks can run outside the sandbox after you trust them.` → *Review hooks* / *Trust all and continue* / *Continue without trusting (hooks won't run)* | any non-managed hook that is new or changed. Codex records trust against each hook's current hash ([Codex hooks docs](https://developers.openai.com/codex/hooks)). |
| other | update prompts, provider login | not a trust gate. Route: `rig context get skills/core/rig-lifecycle` (failure mode "provider auth treated as impl work"). |

**Why class C comes back.** Codex stores trust in `~/.codex/config.toml` under
`[hooks.state."<source>:<event>:<i>:<j>"]`. `<source>` is the hook's source: an absolute file path such as
`<worktree>/.codex/hooks.json` or `~/.codex/config.toml`, or a plugin id. Each **new worktree path** is
therefore a new source, and so is any edit to a hook (a new hash). This path keying was seen in the config Codex 0.156.1 wrote. It is separate from #17. Project-local hooks load only once the
project's `.codex/` layer is trusted. OpenRig 0.5.14 pre-writes trust for its own activity hooks, but #17
reports that the dialog still appears on Codex 0.155.1. The maintainer has asked users to keep the trust
decision in their own hands. The key shape above describes what Codex writes. It is not a recipe: see
guardrail 1.

## 2. Decide (least privilege first)

| Class | Default choice | Choose more only when |
|---|---|---|
| A | **T3, reviewed before `rig up`.** Because OpenRig auto-accepts, launching a seat in a cwd *is* granting trust. First review that checkout and the project configuration trust would enable: `.claude/settings*.json` (hooks, permissions), `.mcp.json`, `.claude/` agents and skills, CLAUDE.md / AGENTS.md. Launch there only if the review passes, and record it. If the dialog appears, accept it in the pane only after the same review. | n/a. An unreviewed cwd gets no seat. |
| B | **Continue without using this MCP server** | the seat's role needs that exact server and you have read what its command runs (guardrail 4). Then choose *Use this MCP server*. Never choose *…all future MCP servers in this project*: that approves servers nobody has reviewed yet. |
| C | **Review hooks** → read every definition and script → finish the review in Codex only if all are understood and benign | never choose *Trust all and continue* without the review. If any hook is unclear: *Continue without trusting*, or switch the seat to `claude-code`, or park it. Codex's `--dangerously-bypass-hook-trust` flag exists but is meant for automation that already vets its hook sources, and OpenRig owns the launch flags. Do not reach for it. |

Continuing **without** trusting also skips OpenRig's own activity hooks. The ACTIVITY column and parked or
idle detection for that seat then lose fidelity. Say so in your handoff.

## 3. Act

Two paths. Pick the first one that is available:

1. **The operator answers in the pane.** Open the seat's tmux session in the terminal provider. This is the
   right path for any trust *grant* (class B *Use*, or a completed class C review).
2. **An agent drives the least-privilege option** (T3). Use
   `rig send <session> "<key>" --dangerously-interact --reason "<class>: <option> — <evidence>"`. This is the
   only override of the send guard, and it is audit-logged. It implies `--raw`. Afterwards,
   `rig capture <session>` must show the prompt gone.

**After the prompt is resolved** the seat may still show `attention_required`, because startup readiness is
checked only once ([#7](https://github.com/mvschwarz/openrig/issues/7), open as of 0.5.14; see §5):

```bash
rig seat clear-attention <session>              # T1: the daemon runs its own evidence gate
rig seat clear-attention <session> --reason "…" # T3: your attestation, only after rig capture shows a ready prompt
rig ps --nodes --rig <rig>                      # verify: LIFECYCLE run
```

**Attention is diagnostic state, not a dashboard color.** Clear it only **after** the underlying cause is
resolved and verified. For example: the native trust review is done, and `rig capture` shows the seat at an
interactive prompt again. `--reason` is an attestation of that evidence, so quote it in the reason (what you
resolved, what the capture showed). Never run `clear-attention`, with or without `--reason`, to turn a
rig green while the cause is still there. A seat that goes back to `att` means the cause was not resolved.

## 4. Pre-configure so the next launch does not block

Each item below is a reviewed, T3 configuration change. Show the diff before you write it.

- **Claude MCP approvals: scope each one to the reviewed worktree. Never approve by name at user scope.**
  Approval settings identify a server only by its *name*. An `enabledMcpjsonServers` entry in user
  `~/.claude/settings.json` would approve that name in every repository, including an untrusted one that
  binds the same name to a different command. That is trust by name alone (guardrail 4). So:
  - *allow*: after reading the command of that `.mcp.json` entry, put the exact name in
    `enabledMcpjsonServers` of the **worktree's untracked** `.claude/settings.local.json`. It applies only to
    that folder, and only once the folder is trusted. Re-review whenever that `.mcp.json` changes.
    Otherwise, the operator approves interactively in the pane.
  - *deny*: `disabledMcpjsonServers` may live at user scope. A deny by name fails closed.
  - Never set `enableAllProjectMcpServers: true`. A committed `.claude/settings.json` cannot approve its own
    repo's servers ([Claude Code MCP docs, "Project server approvals and workspace trust"](https://code.claude.com/docs/en/mcp)).
  - `claude mcp list` shows a server still waiting as `⏸ Pending approval`. `claude mcp reset-project-choices`
    resets the choices.
- **Codex hooks.** Keep the per-worktree hook set small and stable. Reuse crew worktrees across runs rather
  than creating new ones, because trust is keyed by path. Review once per new worktree through the native
  flow (guardrail 1). Organization-managed hooks (`requirements.toml`, MDM) are trusted by policy. That is an
  administrator's decision, not a seat's.
- **Unattended seats.** Use `deny` rules, not `ask` (guardrail 2). Translate the policy with
  `rig context get skills/applying-a-permission-policy`.
- **Workspace trust (class A).** Review every new worktree's checkout and project configuration before its
  first `rig up` (section 2). OpenRig auto-accepts, so the review is the only gate.
- **Secrets.** Deny the secret-manager CLI in the seat's harness config. The crew's culture file names the
  project's just-in-time procedure, which runs outside the seat and returns only non-secret results
  (guardrail 3). No secret value ever goes into that file or any other seat-readable place.

## 5. Upstream issues that affect this page (all open when checked on 2026-09-23)

Each workaround applies **only to the versions it was observed on**. It is not permanent. Before you apply
one, re-check the issue (`gh issue view <n> -R mvschwarz/openrig`) and the release notes for your installed
`rig --version` (https://github.com/mvschwarz/openrig/releases). If the issue is closed or a release says it
is fixed, drop the workaround and follow the current first-party guidance instead.

| Issue (opened) | Effect | Observed on | Workaround (for those versions only) |
|---|---|---|---|
| [#17](https://github.com/mvschwarz/openrig/issues/17) (2026-09-23) | Codex hook-trust dialog is not auto-cleared | reported on Codex 0.155.1; seen live on OpenRig 0.5.14 + Codex 0.156.1 | native review, section 2 class C |
| [#7](https://github.com/mvschwarz/openrig/issues/7) (2026-04-11) | the seat stays `attention_required` after a successful manual fix | reported 2026-04-11, still open when checked against 0.5.14; not reproduced for this page | `rig seat clear-attention` |
| [#18](https://github.com/mvschwarz/openrig/issues/18) (2026-09-23) | `[object Object]` hides the remediation | reported against 0.5.14; fix PR #22 still open when checked | `rig ps --nodes --rig <rig> --json` + `rig capture` |
| [#14](https://github.com/mvschwarz/openrig/issues/14) (2026-06-28) | `rig send` reports success while the text sits undelivered | reported 2026-06-28, still open when checked against 0.5.14; fix PR #15 still open | verify with `rig capture`, never trust the exit code |
| [#12](https://github.com/mvschwarz/openrig/issues/12) (2026-04-20) | readiness times out on tmux 3.3a | reported on tmux 3.3a; not seen on tmux 3.4+ | tmux ≥ 3.4 (`tmux -V`) |
| [#16](https://github.com/mvschwarz/openrig/pull/16) (PR, 2026-09-23) | `npm i -g @openrig/cli` fails on Node 26 | reported on Node 26.9.0; PR still open when checked | Node 20/22/24 until a release bumps better-sqlite3 |

---
Signed: Claude-RigOps-01a0-002 (sub-agent of orchestrator session `01a0`) · first authored 2026-09-23 · wrapper-readiness row: Claude-RigOps-8f02-001, 2026-09-24 (UTC) · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/trust-gates.md` · prompt texts observed live with `rig capture` on the versions above.
