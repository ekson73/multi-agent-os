# Surface: Claude bots and agents

> Load only when the intent is about Claude running outside a chat window. All four are official. Verified 2026-10-26.

| Option | What it is | Who can use it | Source |
|---|---|---|---|
| **Claude Tag** | `@Claude` in a Slack channel; replaces the old Claude in Slack. Customized with connectors, plugins, skills; per-channel memory. A workspace Owner pairs it with `@Claude connect` at `claude.ai/admin-settings/claude-tag`. | Team and Enterprise, public beta | https://claude.com/docs/claude-tag/overview.md |
| **Claude in Chrome** | Chrome extension; pairs with Claude Code via `claude --chrome`. | Direct Anthropic plan (Pro, Max, Team, Enterprise) | https://code.claude.com/docs/en/chrome.md |
| **Agent SDK** | Claude Code as a Python/TypeScript library on your own infrastructure; loads skills from `.claude/`. | Developers | https://code.claude.com/docs/en/agent-sdk/overview.md |
| **Managed Agents** | Anthropic-hosted agent harness over the API (beta header `managed-agents-2026-04-01`); defined by model, prompt, tools, MCP and skills. | API users, beta | https://platform.claude.com/docs/en/managed-agents/overview.md |

## Routes
- Slack app setup or failures → `claude-tag-troubleshoot:*`.
- Custom agents / SDK / Managed Agents code → `claude-api` (and the Agent SDK docs).
