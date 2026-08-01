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

| Runtime | Format discovery (official documentation, checked 2026-08-01) | MAOS ACT status | Adapter rule |
|---|---|---|---|
| Claude Code | Native Skill plus repository command wrapper | **UNVERIFIED** | `commands/ooda-loop.md` is supplied, but installed-host hooks, identity, policy and promotion gates still require mapping. |
| Codex | Native open-standard Skills support ([official](https://help.openai.com/en/articles/20001066)) | **UNVERIFIED** | Map workspace, approvals and tools; never assume Claude slash-command semantics. |
| Gemini CLI | Native workspace/user Agent Skills ([official](https://geminicli.com/docs/cli/using-agent-skills/)) | **UNVERIFIED** | Activation consent and host policy still apply; map only documented tools and promotion gates. |
| OpenCode | Native `.agents/skills` discovery and permissioned loading ([official](https://opencode.ai/docs/skills)) | **UNVERIFIED** | Re-verify the installed version and configure skill/tool permissions explicitly. |
| Antigravity | Native Agent Skills with product-specific paths ([official codelab](https://codelabs.developers.google.com/antigravity/how-to-create-agent-skills-for-antigravity-cli)) | **UNVERIFIED** | Adapt the repository Skill into the documented workspace path; do not infer unattended ACT from discovery. |
| JCode | Native `~/.jcode/skills` and Claude-plugin skill loading documented on a site marked under construction ([official](https://jcode.sh/docs)) | **UNVERIFIED** | Re-verify the installed build and establish project-scoped installation plus every ACT gate before mutation. |

## Adapter minimum

An adapter must provide all of the following before it may run ACT:

1. A way to read repository policy and the full Skill.
2. A trusted-root path boundary plus a way to validate both intake contracts and keep them separate from raw trigger text.
3. A current identity/capability check for any mutation.
4. An isolated change mechanism or an explicit reason it cannot mutate.
5. A deterministic evidence channel for checks and promotion gates.
6. A fail-closed mapping for missing capability, secrets, external integrations and hard boundaries.
7. Project/tenant binding, connector-authentication evidence, replay storage, cancellation, lease and global budget enforcement.

An adapter may receive Discord, Slack, Jira, Linear, chat or webhook data, but it must label it
as signal-only unless an independent repository policy and live integration grant authority.

Compatibility labels describe documentation evidence, not perpetual vendor guarantees. Native discovery
means only that the host can find/load the Skill format. It does not prove this Skill's end-to-end behavior;
every runtime remains **UNVERIFIED for MAOS ACT** until a sanitized capability-mapped dogfood is recorded.
