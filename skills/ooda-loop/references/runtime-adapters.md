# Runtime Adapter Contract

`ooda-loop` is portable content, not a claim that every host has the same command,
webhook, identity, worktree or deployment API. Its portable core is:

- `SKILL.md` in the Agent Skills directory format;
- a vendor-neutral Markdown loop contract;
- a strict JSON `operator-profile` input;
- capability detection and fail-closed authority intersection.

The [Agent Skills specification](https://agentskills.io/specification) defines the portable
directory and `SKILL.md` frontmatter format. A runtime that can load that format can consume the
core; a runtime that cannot must use a thin, local adapter that loads the same files without
changing their security semantics.

| Runtime | Consumption route | Adapter rule |
|---|---|---|
| Claude Code | `commands/ooda-loop.md` plus `skills/ooda-loop/SKILL.md` | The command wrapper is supplied; host tools and hooks remain subject to project policy. |
| Codex | Load `SKILL.md` through the host skill mechanism when available | Bind workspace, worktree, tool and approval behavior to the Codex host; do not assume a Claude slash command. |
| Gemini | Load `SKILL.md` through the host skill mechanism when available | Bind only documented Gemini tools and promotion gates; unknown capability means no execution. |
| OpenCode | Load `SKILL.md` through the host skill/instruction mechanism when available | Keep inbound integrations as untrusted signals and map tool permissions explicitly. |
| Antigravity | Load the Markdown contract and JSON schema through its documented extension surface | Do not claim native discovery until that runtime proves it; use a local adapter otherwise. |
| JCode | Load the Markdown contract and JSON schema through its documented extension surface | Do not claim native discovery until that runtime proves it; use a local adapter otherwise. |

## Adapter minimum

An adapter must provide all of the following before it may run ACT:

1. A way to read repository policy and the full Skill.
2. A way to validate `operator-profile` and keep it separate from untrusted trigger text.
3. A current identity/capability check for any mutation.
4. An isolated change mechanism or an explicit reason it cannot mutate.
5. A deterministic evidence channel for checks and promotion gates.
6. A fail-closed mapping for missing capability, secrets, external integrations and hard boundaries.

An adapter may receive Discord, Slack, Jira, Linear, chat or webhook data, but it must label it
as signal-only unless an independent repository policy and live integration grant authority.
