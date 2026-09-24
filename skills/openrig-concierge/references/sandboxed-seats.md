# Sandboxed seats — an OS-enforced boundary for seat-executed code

> **Owned layer.** First-party OpenRig covers posture (`rig policy`, `applying-a-permission-policy`). It
> records posture; the harness enforces it (CANON C4). This page covers the one harness mechanism that a
> synthetic preflight showed can act as an **OS-enforced** boundary for code a seat runs: Claude Code's bash
> sandbox. [`trust-gates.md`](./trust-gates.md) §4 requires that boundary whenever a credential cannot be
> removed from every seat-readable source.
> **Checked against:** Claude Code 2.1.281 + `rig` 0.5.14 (cc75efdd) on macOS (Seatbelt), in a synthetic
> preflight (2026-09-24 UTC) that used sentinel files only and never read a real credential. Linux (bubblewrap)
> was not tested. Settings keys and prompt behavior change between harness releases: re-check each one with
> `/sandbox` in a live seat before relying on it.

Legend: **[T0]** read-only · **[T1]** reversible · **[T2]** disruptive · **[T3]** security gate ([`tiers.md`](./tiers.md)).

## 0. When this page applies

A seat that runs project code (package scripts, test runners, git hooks) runs it as the operator's OS user.
Permission rules gate the harness's *tools*; they do not gate what a script the seat started can read. So
when any credential stays in a file or environment channel a seat can reach, launch needs this boundary. Risk
acceptance never substitutes for it. If neither this boundary nor source removal is possible, the external-crew
recipe is not usable unattended: stop and escalate ([`trust-gates.md`](./trust-gates.md) §4).

## 1. The boundary: settings that held [T3, show the diff]

All of it lives in each desk's `.claude/settings.local.json` ([`external-crew.md`](./external-crew.md) step 5).
Render it from scratch before every launch; OpenRig then merges its own hooks and status line into the file.

| Setting | Value that held | Why |
|---|---|---|
| `sandbox.enabled` | `true` | the boundary itself |
| `sandbox.failIfUnavailable` | `true` | no silent unsandboxed run when the OS sandbox cannot start |
| `sandbox.allowUnsandboxedCommands` | `false` | removes the retry-outside-the-sandbox escape; a retry with `dangerouslyDisableSandbox` produced the same blocked results |
| `sandbox.autoAllowBashIfSandboxed` | `false` | the seat's positive allowlist still decides what runs |
| `sandbox.credentials.files` | `{path, mode: "deny"}` entries for the harness user settings and trust files, secret-manager, cloud, SSH and forge credential dirs, `~/.netrc`, shell histories, and OpenRig's own secret files | named credential files stay unreadable even if a later rule widens reads |
| `sandbox.credentials.envVars` | `{name, mode: "deny"}` for every secret-like name from the inventory ([`trust-gates.md`](./trust-gates.md) §4) **plus** well-known credential names and the per-session activity-hook token OpenRig sets in the seat's tmux env | sandboxed commands do not see these names at all |
| `sandbox.filesystem.denyRead` | `["~/"]` | a home-wide read block for sandboxed commands |
| `sandbox.filesystem.allowRead` | narrow: the desk, the repository's common `.git`, git's config includes and config dir, the global excludes file (resolved through any symlink), the node/toolchain install dirs, the package-manager cache | what git and the package manager need, found by running them and widening one path at a time |
| `sandbox.filesystem.allowWrite` | the repository's `.git/objects`, the seat's own worktree-admin and branch-ref globs, the package-manager cache | commits and installs |
| `sandbox.filesystem.denyWrite` | the repository's `.git/hooks`, `.git/config`, `refs/heads/<default>`, `packed-refs` | the seat cannot plant a hook, rewrite remotes, or move the default branch |
| `sandbox.network.allowedDomains` | the package registry only | `npm ci` / `npm test` worked through it; forge and API hosts stay unreachable |
| `permissions.additionalDirectories` | exactly `<desk>/units` | the seat's unit worktrees (§3) |
| Read / Edit deny rules | the credential paths above, plus the desk's control files (§2) | the harness tools obey these too |

Also verified: a tracked pre-commit hook ran **inside** the sandbox and could not read a sentinel; allow rules,
the sandbox filesystem lists and `credentials.envVars` hot-reload without a relaunch.

Verify in each live seat [T0]: `/sandbox` must show the sandboxed mode, strict overrides, and every deny and
allow list above. Prove the block with sentinel files that hold no secret (a child process started by a
package script must get `EPERM` on each), never by reading a real credential. That real paths are blocked is then
an inference from identical rule types, and should be stated as one.

## 2. The desk is an escape path until you close it

The desk is the seat's cwd, so the sandbox makes it writable by default. It also holds files that run
**outside** the sandbox: OpenRig's hook scripts and status-line collector under `<desk>/.openrig/`, and
guidance files the harness loads (`CLAUDE.md`, `CLAUDE.local.md`). In the preflight, seat code could rewrite them:
a real sandbox escape. Add Edit denies (which also become sandbox write denies) on `<desk>/.openrig/**`,
`<desk>/*.md`, `<desk>/.claude/**`, `<desk>/.mcp.json` and any other directory the harness or its plugins load
from the desk. This list is an enumeration: re-check it whenever OpenRig, the harness or a plugin adds a file to
the desk.

## 3. What did not work, and what it costs

| # | Observed | Consequence |
|---|---|---|
| 1 | `permissions.blockReadsOutsideWorkingDirectories: true` made the sandbox drop `allowRead`, `allowWrite` and `additionalDirectories` (the `/sandbox` config listed none of them), so git and the package manager failed. Removing it was not live either: it needed a fresh occupant. | Leave it unset. Use `denyRead ["~/"]` plus the narrow `allowRead` instead. |
| 2 | Under `denyRead`, git in an **additional** directory failed with `unable to get current working directory: Operation not permitted`; inside the cwd tree it worked. | Unit worktrees live **under the desk** (`<desk>/units/<seat>-<unit>`, with a seeded `<seat>-home` worktree as the git context), not in the project's worktree directory. Where the project's worktree-location convention is binding, the crew cannot authorize this deviation: the operator decides. |
| 3 | A sandbox **network** prompt ("request outside of sandbox") bypasses `PermissionRequest` hooks and freezes the pane, and a relayed keystroke arriving while it is up could approve it. A Notification hook that sends Escape denied it, but only as a timing workaround. `sandbox.network.strictAllowlist` closes it, but it is honored only at user, managed or `--settings` scope, and OpenRig 0.5.14 cannot pass `--settings`. | Unattended use needs the operator to set `strictAllowlist` at user or managed scope (it takes effect only where the sandbox is enabled), or a seat-scoped harness config dir with its own login. Until then this is a stop, not a residual risk. |
| 4 | When the Bash cwd is a linked worktree, the harness grants the whole shared `.git` (minus `hooks` and `config`). Per-seat write globs do not hold: another worktree's admin `HEAD` and `index`, other branches and remote refs stayed writable, and loose objects can be overwritten. | Per-seat git-metadata isolation between worktrees of one repository is **not** achievable this way. It is a blocker wherever the project must preserve other worktrees' work in progress. Otherwise mitigate on the publishing side (§4). |
| 5 | Sandboxed seats cannot reach the OpenRig daemon (`rig queue` fails to connect). Opening its local port would hand seat code the whole control plane, including launching an unsandboxed seat. | Keep the port closed. Seats report in their pane or a desk outbox file; a clerk **outside** the crew mirrors results into `rig queue`. |
| 6 | Seat code could write to the unsandboxed desk files. | Fixed by §2; it was an escape before the fix. |
| 7 | OpenRig 0.5.14 launches Claude Code with `--permission-mode acceptEdits`, which overrides `permissions.defaultMode` in the file. | Edits inside allowed paths are auto-accepted; the Edit denies and the sandbox are what bound them. |

Residual risks that stay after all of the above: the allowed registry host is a narrow exfiltration channel
(domain fronting, no TLS inspection); the harness injects a few names of its own (sandbox proxy and git
plumbing) that are visible to seat code; the harness process itself still holds its parsed user settings; and
hooks run outside the sandbox with the harness environment. Record each one in the handoff.

## 4. Trusted publisher: how sandboxed work leaves the crew

Seats hold no push credential. A publisher **outside** the crew moves reviewed work to the forge without ever
running crew-authored code outside a sandbox:

1. A publisher-owned clean clone at the default branch, with its own trusted hooks from that branch.
2. `git -c fetch.fsckObjects=true fetch <seat-repo> refs/heads/<exact-branch>`. The candidate is never checked out.
3. A path gate: a candidate that changes hook, CI, git-attribute, submodule or LFS config files, or any file the
   trusted hooks or CI execute, is **parked** for a human instead of pushed.
4. Push by exact SHA: `git push origin <sha>:refs/heads/<branch>`. The trusted clone's own hooks run.
   Never `core.hooksPath=/dev/null` and never `--no-verify`.
5. Verification of record after merge is the forge's CI on the merge commit plus an ancestry check
   (`git merge-base --is-ancestor <merge> origin/<default>`), not a local build of candidate code.

In the preflight a seat-authored candidate that changed a tracked hook was parked, its hook never ran, and
origin received only the clean candidate.

---
Signed: Claude-RigOps-8f02-001 (sub-agent of the orchestrating session) · first authored 2026-09-24 (UTC) from a synthetic sandboxed-seat preflight (sentinel files only) · last revised: `git log -1 --format=%cI -- skills/openrig-concierge/references/sandboxed-seats.md` · checked against Claude Code 2.1.281 + `rig` 0.5.14 (cc75efdd) on macOS.
