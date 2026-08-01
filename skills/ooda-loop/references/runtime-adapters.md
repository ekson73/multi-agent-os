# Runtime Adapter Contract

`ooda-loop` is portable content, not a claim that every host has the same command,
webhook, identity, worktree or deployment API. Its portable core is:

- `SKILL.md` in the Agent Skills directory format;
- a vendor-neutral Markdown loop contract;
- strict JSON profile, trigger and outward-run contracts;
- capability detection and fail-closed authority intersection.

The [Agent Skills specification](https://agentskills.io/specification) defines the portable
directory and `SKILL.md` frontmatter format. A runtime that can load that format can consume the
core; a runtime that cannot must use a thin, local adapter that loads the same files without
changing their security semantics.

| Runtime | Format discovery (official documentation, checked 2026-08-01) | Route from this checkout | Command surface | MAOS ACT mapping/status |
|---|---|---|---|---|
| Claude Code | Native plugin Skills | Load the repository with `claude --plugin-dir <checkout>` or install the published `maos` plugin | Supplied wrapper: `/maos:ooda-loop` | Adapter mapping exists in the plugin but behavioral v0.3 dogfood is **UNVERIFIED**; live host gates still apply. |
| Codex | Native open-standard Skills support ([official](https://help.openai.com/en/articles/20001066)) | Package/install `skills/ooda-loop` through the installed Codex Skill surface; a clone alone is not discovery | No MAOS slash-command claim; invoke by Skill intent/name | Adapter-required and **UNVERIFIED**: map workspace, approvals, tools, child-result capture and promotion. |
| Gemini CLI | Native workspace/user Agent Skills ([official](https://geminicli.com/docs/cli/using-agent-skills/)) | `gemini skills link ./skills/ooda-loop --scope workspace` from this checkout, then verify `/skills list` | Native Skill activation; no MAOS command wrapper | Adapter-required and **UNVERIFIED**; activation consent and host policy remain in force. |
| OpenCode | Native `.agents/skills` discovery and permissioned loading ([official](https://opencode.ai/docs/skills)) | Copy/link `skills/ooda-loop` to the consumer's `.agents/skills/ooda-loop` or configure an explicit Skill source | Native `skill` tool; no MAOS command wrapper | Adapter-required and **UNVERIFIED**; configure Skill/tool permissions and child-result capture. |
| Antigravity | Native Agent Skills with product-specific paths ([official codelab](https://codelabs.developers.google.com/antigravity/how-to-create-agent-skills-for-antigravity-cli)) | Copy/link into the installed product's documented workspace Skill path; re-check singular/plural path for that product/version | Native semantic Skill activation; no MAOS command wrapper | Adapter-required and **UNVERIFIED**; discovery does not imply unattended ACT. |
| JCode | Native `~/.jcode/skills` and Claude-plugin Skill loading documented on a site marked under construction ([official](https://jcode.sh/docs)) | Audited copy/link to `~/.jcode/skills/ooda-loop`; the checked page documents no project-local Skill path | `/ooda-loop` after installation is documented generically for skill names, not behavior-tested here | Adapter-required and **UNVERIFIED**; global installation expands scope and needs an explicit sovereignty review. |

## Adapter minimum

An adapter must provide all of the following before it may run ACT:

1. A way to read repository policy and the full Skill.
2. A trusted-root path boundary plus a way to validate all three JSON contracts and keep trigger data separate from control-plane configuration.
3. A current identity/capability check for any mutation.
4. An isolated change mechanism or an explicit reason it cannot mutate.
5. A deterministic evidence channel for checks and promotion gates.
6. A fail-closed mapping for missing capability, secrets, external integrations and hard boundaries.
7. Project/tenant binding, connector-authentication evidence, replay storage, cancellation, lease and global budget enforcement.
8. Child-driver result capture and normalization so exactly one outer marker is emitted.

An adapter may receive Discord, Slack, Jira, Linear, chat or webhook data, but it must label it
as signal-only unless an independent repository policy and live integration grant authority.

Compatibility labels describe documentation evidence, not perpetual vendor guarantees. Native discovery
means only that the host can find/load the Skill format. It does not prove this Skill's end-to-end behavior;
every runtime remains **UNVERIFIED for MAOS ACT** until a sanitized capability-mapped dogfood is recorded.
