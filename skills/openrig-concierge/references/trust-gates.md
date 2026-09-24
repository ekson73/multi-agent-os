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
   real control is that no secret value is ever placed where a seat can read it. That includes env the
   harness injects from the operator's user settings, which no shell-side scrub removes, and env the tmux
   server, the daemon or the login shell carries (§4, user-scope and environment check).
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
| `rig up` / `rig ps --nodes --rig <rig>` | `probe pane returned to a shell`, or `clear-attention` refused with class `pane_identity` ("foreground command '<shell>' contradicts runtime") | **not a trust gate** when the login shell runs inside a nesting terminal wrapper: the pane's foreground command reads the shell. A seat is ready only when all three hold: `startupStatus=ready`, `rig capture` shows the runtime's TUI at a prompt, and `rig ps --nodes --rig <rig>` ACTIVITY is live. Heal an empty seat as in [`external-crew.md`](./external-crew.md) step 11. |

Then read the pane (T0): `rig capture <session> --lines 40`. Classify the prompt by its text:

| Class | Prompt text (as observed) | Where it comes from |
|---|---|---|
| **A. Claude workspace trust** | the "trust the files in this folder" dialog | first launch of Claude in a cwd that is not yet trusted. Accepting it enables the project's own configuration: its hooks, permission rules, MCP servers and instructions. **OpenRig 0.5.14 auto-accepts it for managed seats.** It pre-writes `projects["<path>"].hasTrustDialogAccepted` into `~/.claude.json` for the cwd **and its git root** and drives the dialog (Runtime Config Disclosure in `~/.openrig/reference/agent-startup-guide.md`). That is trust keyed by path with no review (guardrail 4). Flag it, and do the review yourself **before** launch (section 2). The dialog itself shows up only when that write missed, for example because the daemon's HOME differs from the seat's. |
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
| A | **T3, reviewed before `rig up`.** Because OpenRig auto-accepts, launching a seat in a cwd *is* granting trust. First review that checkout and the project configuration trust would enable: `.claude/settings*.json` (hooks, permissions), `.mcp.json`, `.claude/` agents and skills, CLAUDE.md / AGENTS.md. With a desk as the cwd ([`external-crew.md`](./external-crew.md) step 5) the review is that the desk is empty apart from the crew's own settings file, plus the worktrees the seat can reach. Then run the user-scope check (§4): the seat inherits that too. Launch there only if the review passes, and record it. If the dialog appears, accept it in the pane only after the same review. | n/a. An unreviewed cwd gets no seat. |
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

- **Claude MCP approvals: scope each one to the reviewed cwd. Never approve by name at user scope.**
  Approval settings identify a server only by its *name*. An `enabledMcpjsonServers` entry in the user
  settings (`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json`) would approve that name in every repository,
  including an untrusted one that binds the same name to a different command. That is trust by name alone
  (guardrail 4). So:
  - *allow*: after reading the command of that `.mcp.json` entry, put the exact name in
    `enabledMcpjsonServers` of the **seat cwd's untracked** `.claude/settings.local.json` (the desk's, for a
    crew). It applies only to that folder, and only once the folder is trusted. Re-review whenever that
    `.mcp.json` changes. Otherwise, the operator approves interactively in the pane.
  - *deny*: `disabledMcpjsonServers` may live at user scope. A deny by name fails closed.
  - Never set `enableAllProjectMcpServers: true`. A committed `.claude/settings.json` cannot approve its own
    repo's servers ([Claude Code MCP docs, "Project server approvals and workspace trust"](https://code.claude.com/docs/en/mcp)).
  - `claude mcp list` shows a server still waiting as `⏸ Pending approval`. `claude mcp reset-project-choices`
    resets the choices.
- **Codex hooks.** Keep the per-cwd hook set small and stable. Reuse crew desks and worktrees across runs rather
  than creating new ones, because trust is keyed by path. Review once per new path through the native
  flow (guardrail 1). Organization-managed hooks (`requirements.toml`, MDM) are trusted by policy. That is an
  administrator's decision, not a seat's.
- **Unattended seats.** Use `deny` rules, not `ask` (guardrail 2). Translate the policy with
  `rig context get skills/applying-a-permission-policy`.
- **Workspace trust (class A).** Review every desk and every worktree a seat can reach before its first
  `rig up` (section 2). OpenRig auto-accepts, so the review is the only gate. It also pre-trusts the cwd's git
  root, and those entries outlive teardown ([`external-crew.md`](./external-crew.md) step 14).
- **Secrets.** Deny the secret-manager CLI in the seat's harness config. The crew's culture file names the
  project's just-in-time procedure, which runs outside the seat and returns only non-secret results
  (guardrail 3). No secret value ever goes into that file or any other seat-readable place.

### User-scope and environment check (every seat inherits both) [T3]

Every seat runs as the operator, so the harness loads the operator's user scope into it: the user settings
`env` block, hooks, plugins, user MCP config and home-level agent guidance. A RigSpec cannot scope any of it,
and it has no `env` field. A seat's environment arrives through several channels, and each needs its own
scrub:

| Channel | How it reaches the seat | Scrub |
|---|---|---|
| **(a)** harness user settings `env` | the harness applies it to its tool env **after** the shell starts | desk override (step 3) |
| **(b)** the tmux server's global environment | copied from whatever process started the tmux server, then into every new pane | shell-side, at the desk (step 4) |
| **(c)** the OpenRig daemon's environment | inherited by the tmux server when the daemon starts it, so it surfaces through (b) | shell-side, at the desk (step 4) |
| **(d)** the login shell's own startup files (secret loaders, exports) | run in every pane | shell-side, placed after the loaders (step 4) |

Observed on OpenRig 0.5.14 with Claude Code 2.1.281: a shell-side scrub removed the secrets from (b) and (d),
while a secret in (a) still reached every seat's tool env.

**Launch rule: the credential leaves every seat-readable source, or seat code runs inside an OS-enforced
boundary.** An empty tool env does not protect the file the value came from. When seats execute project code
(package scripts, hooks) as the operator's OS user, the user settings file, shell startup files and credential
directories stay readable to that code whatever the probe says. Launch therefore requires **one** of:

1. every credential removed from every seat-readable source (moved out of the user settings `env`, the shell's
   default environment and seat-readable files, behind the project's just-in-time procedure; guardrail 3); or
2. an OS-enforced boundary for seat-executed code: the harness bash sandbox in strict, fail-if-unavailable
   mode, with credential file and env denies, a home-wide read block, narrow git write paths, no credential in
   any seat, and a publisher outside the crew ([`sandboxed-seats.md`](./sandboxed-seats.md)).

Risk acceptance never substitutes for either. If neither is possible, the external-crew recipe is **not usable
unattended**: stop and escalate to the operator. `Read` denies on the harness user settings file and on
credential directories belong in each desk's settings either way, but they are a speed bump that does not
close the code-execution path.

The recipe below is a **secondary control** on top of that rule. It keeps the values out of each seat's
tool env and proves it per seat, which limits accidental exposure (logs, transcripts, tool output). In a
sandboxed seat the hook may deny a shell parameter-expansion probe; run the same names-only enumeration from a
small script instead. Recipe for Claude Code seats:

1. **Inventory names, never values, from every channel [T0].** A pipeline that splits on newlines is not
   names-only if any value can contain a newline: `env | cut -d= -f1` or `tmux show-environment -g | cut -d= -f1`
   passes every continuation line of a multiline value through intact. Use only forms that never emit a
   value, and mark every secret-like name:
   - (a) keys only, from the **active** config root and any managed settings file the harness loads:
     `jq -r '.env // {} | keys[]' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"`
   - (b) and (d) together, from **inside** a pane of the same tmux server whose cwd is a desk, with the login
     shell's own names-only builtin. That lists exactly what tmux and the shell's startup files exported,
     without touching a value. Run it before you add the scrub (step 4) to build the list, and again after it
     as a check:

     ```bash
     compgen -e                                   # bash: exported names only
     print -rl -- ${(k)parameters[(R)*export*]}   # zsh: exported names only
     ```

     To find which startup file sets a name without printing its line: `grep -lw -- <NAME> <files>`.
   - (c) `rig daemon status` prints the daemon's pid. On Linux, split `/proc/<pid>/environ` on NUL inside bash
     and print only the part before the first `=`:

     ```bash
     while IFS= read -r -d '' kv; do printf '%s\n' "${kv%%=*}"; done < /proc/<pid>/environ
     ```

     On macOS no names-only read exists (`ps` prints the environment with its values), so do not read it;
     rely on (b), which the daemon's environment feeds, and on the live probe in step 5.
2. **Keep one names list** (the union of step 1), with no values. Every later step uses it.
3. **Desk override for (a) [T3, show the diff].** Render an `env` object that sets each channel-(a) name to the
   empty string, and merge it into the desk's own `.claude/settings.local.json` (mode 0600, the file that
   also carries the seat's posture) before launch. The filter below prints names only; add any secret it
   misses from the list:

   ```bash
   jq '{env: (.env // {} | keys
        | map(select(test("TOKEN|KEY|SECRET|PASSWORD|AUTH"; "i")) | {(.): ""}) | add // {})}' \
     "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json"
   ```

   It works because local settings override user settings for the same key, and OpenRig deep-merges its own
   fragment into that file and keeps `env` (observed on 0.5.14).
4. **Shell-side scrub for (b), (c) and (d) [T3, the operator's shell config].** At the **end** of the login
   shell's startup file, after every secret loader, unset the names from the list, scoped to the desk path
   so no other shell changes, and set a marker the probe can test:

   ```bash
   case "$PWD" in
     <crew-home>/desks/*) unset NAME_B NAME_C NAME_D; export CREW_DESK_SCRUB=1 ;;
   esac
   ```

   The harness is a child of that shell, so it starts without them.
5. **Verify in each LIVE seat [T1], never by reading a file.** First enumerate the exported names in the
   seat's own tool shell with the same builtin, filtered by the secret-name pattern, for anything the list
   missed. Then run a value-free test over **every** name on the list:

   ```bash
   rig send <session> '!compgen -e | grep -E "TOKEN|KEY|SECRET|PASSWORD|AUTH"' --raw     # zsh tool shell: print -rl -- ${(k)parameters[(R)*export*]} | grep -E …
   rig send <session> '![[ -z ${NAME_A:-} && -z ${NAME_B:-} && -z ${NAME_C:-} && -z ${NAME_D:-} && -n ${CREW_DESK_SCRUB:-} ]] && echo SCRUBBED || echo NOT-SCRUBBED' --raw
   rig capture <session> --lines 20
   ```

   `SCRUBBED` counts only when every inventoried name is empty and the marker is set. Use `${VAR:-}`, which
   treats set-but-empty as scrubbed. The enumeration also lists names whose values are empty: judge each name
   it prints. A new secret name goes on the list; an innocuous one (a flag, a path, an id the harness itself
   sets) is recorded as such. Neither probe prints a value, but each starts a model turn
   ([`external-crew.md`](./external-crew.md) step 6). A send to a busy pane waits until the pane idles.
6. **Stop rule.** `NOT-SCRUBBED`, or an unlisted secret name, in any seat means no work: take the rig down
   with a snapshot, fix the scrub, and relaunch under a new rig name.
7. **Re-render** the override and the unset list whenever any channel changes. Each covers only the names
   present when it was written.
8. **Reset desks after posture changes.** OpenRig's merge unions arrays, so a rule you removed from your
   template survives in a reused desk's settings file. Recreate the desk's settings file instead of merging
   again.

The override removes the value from the seat's tool env, not from its source file or from the harness process
that parsed the user settings. That residual risk is why the launch rule above requires source removal or an
OS-enforced boundary.

**User-scope MCP servers are a launch blocker, not a flow to record.** `disabledMcpjsonServers` rejects only
servers discovered from a project's `.mcp.json`; it does not disable a server configured at user scope or
provided by a plugin, and such a server runs outside any bash sandbox with the operator's credentials.
Inventory them by name only, in the operator's own terminal, never in a seat: the keys of the user-scope MCP
config (by default the `mcpServers` object in `~/.claude.json`; resolve it under the active config root when
`CLAUDE_CONFIG_DIR` is set), plus the server names `claude mcp list` shows. That command also prints each
server's command or URL, which can embed a credential, so record the names only. Any user-scope or plugin
server with filesystem, credential or network capability blocks the launch unless it is disabled at its
actual scope (removed from the user config, or its plugin disabled) or the seat runs with an isolated,
seat-scoped harness config directory (for Claude Code, `CLAUDE_CONFIG_DIR`, which needs its own login: a
human step).

Global hooks and plugins run in every seat as well. A memory-capture hook, for example, records seat sessions
into the operator's personal store: a cross-domain data flow from the target project. `rig capture` of a fresh
seat shows which session hooks fired. Isolating hooks and plugins also needs the seat-scoped config
directory. Until then, list the flow in the handoff.

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
Signed: Claude-RigOps-01a0-002 (sub-agent of orchestrator session `01a0`) · first authored 2026-09-23 · user-scope and environment check: Claude-RigOps-8f02-001, 2026-09-24 (UTC), revised 2026-09-24 (UTC) after review · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/trust-gates.md` · prompt texts observed live with `rig capture` on the versions above.
