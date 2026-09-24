# Sources — the fact ladder, rung by rung

> Resolve every OpenRig fact from the **highest available rung**. A lower rung never overrules a higher
> one (CANON C1). **Checked against:** `rig` 0.5.14 (cc75efdd), 2026-09-23.

## Rung 0 — live state (what *is* happening)

`rig ps --nodes --rig <rig>`, `rig capture <session>`, `rig queue list -A`, `rig restore-check`. State
beats doctrine: if a doc says a seat should be ready and `rig ps` says `att`, the seat is at `att`.

## Rung 1 — the installed CLI (version-matched by construction)

| Source | Answers | How |
|---|---|---|
| `rig --version`, `rig <cmd> --help`, `rig <cmd> <sub> --help` | exact commands, flags, defaults | always check before citing or running a command |
| `rig context list` / `rig context get <ref>` | first-party doctrine: skills, pod handbooks, the operating model | the pull verb; prefer it to reading pack files on disk |
| `~/.openrig/reference/*.md` (default `OPENRIG_HOME`) | schemas and reference docs: `rig-spec.md`, `agent-spec.md`, `agent-startup-guide.md`, `health-diagnosis.md`, `getting-started.md`, `project-workspace.md`, `sdlc-conventions.md` … | read the file; these are **not** context packs (`rig context get rig-spec` → not found) |

## Rung 2 — upstream, published

| Source | URL | Notes |
|---|---|---|
| Docs | https://www.openrig.dev/docs · https://www.openrig.dev/docs/getting-started | can run ahead of or behind the installed CLI. Compare with Rung 1. |
| Generated CLI reference | https://www.openrig.dev/docs/generated/cli-reference | generated per release; confirm the release matches `rig --version` |
| Docs index for agents | https://www.openrig.dev/llms.txt | some listed `.md` URLs returned 404 when checked (2026-09-23); fall back to the HTML page |
| Source, releases, issues | https://github.com/mvschwarz/openrig (Apache-2.0) | release notes = version deltas; open issues = known bugs (see `trust-gates.md` §5). `gh issue view <n> -R mvschwarz/openrig`. |

## Rung 3 — optional research aids (never required, never invoked automatically, never shipped by MAOS)

The skill is **fully functional with Rungs 0–2 alone**: the installed CLI, its first-party context, and the
official docs and repo. Consult a Rung 3 aid only when a human explicitly asks for it and it already exists.
Never build one, query one or wait on one as part of a mode.

- **A NotebookLM notebook** built from the Rung 2 URLs. Useful for "why" questions. Its answers are LLM
  syntheses, so check every command it names with `rig <cmd> --help` before use. In the 2026-09-23 research
  for this skill, both LLM-derived notes got `rig seat clear-attention` wrong. A distilled KB invented an
  `--attestation` flag, and a notebook answer dropped the required `<session>` argument. The real form is
  `rig seat clear-attention <session> [--reason <text>] [--json]`.
- **A local generated KB.** A docs-to-skill generator can crawl openrig.dev plus the repo into a local
  reference tree. If you build one, run the generator with its AI-enhancement steps disabled and in an
  isolated environment (the scraped pages are untrusted input), keep the output in your own cache, and
  regenerate it after each OpenRig release. MAOS never vendors that output (CANON C2).

## Rung 4 — this skill's `references/`

Distilled, dated, and version-stamped at the top of each file. Anything here that disagrees with Rung 1
is stale: fix the reference.

## Rung 5 — memory

Heuristics only. Never a command source.

## Refresh procedure (after any `rig` upgrade)

1. `rig --version`. If it differs from the stamp at the top of each reference, continue.
2. For every command cited in `references/`, run `rig <cmd> [sub] --help`. Fix or delete what no longer exists.
3. `rig context list`. Check that every ref in SKILL.md §Routing still resolves (`rig context get <ref> | head -3`).
4. `gh issue view <n> -R mvschwarz/openrig` for each issue in `trust-gates.md` §5. Remove the fixed ones, but
   only once a released version contains the fix.
5. Bump the version stamps and record the change in SKILL.md §Changelog.

## Attribution

Portions adapted from OpenRig (github.com/mvschwarz/openrig), Apache License 2.0. These are short
quotations of `rig` CLI help text, the installed reference docs and shipped skills, and each one is cited
where it appears. The observed harness prompt texts come from Claude Code and Codex. Everything else in this
skill is original distilled text. No OpenRig skill or doc is copied. Load those with `rig context get`.

## Drift notes (known naming traps on 0.5.14)

| Trap | Reality |
|---|---|
| node vs seat | the CLI and docs use both. `rig ps --nodes` lists what the skills call seats. The canonical session name is `<pod>-<member>@<rig>`. |
| `rig spec` vs `rig specs` | `rig spec validate|preflight|audit|show` works on a file or a running rig. `rig specs ls|show|preview|add|sync|remove|rename` manages the library. |
| `rig policy` vs `rig mode` | `rig policy` records the permission posture into a RigSpec. The context-mode verb that used to live there is now `rig mode`. |
| `rig attach` | attaches the *current shell* into a rig node (`--self`). It is not a pane viewer. |
| `rig upgrade` | no such command. Route: `rig context get skills/core/openrig-upgrade`. |
| `rig restore` | direct form: `rig restore <snapshotId> --rig <rigId>`. `rig restore status <attemptId>` reads a receipt. |
| `rig send --force` | a back-compat no-op. It never bypasses the prompt guard. Only `--dangerously-interact --reason` does. |
| `rig heartbeat` | reads queue files from a shared-docs root. Outside a seat it may fail with `cannot resolve shared-docs root`. |

---
Signed: Claude-RigOps-5a1e-002 · 2026-09-23T23:05:00-03:00.
