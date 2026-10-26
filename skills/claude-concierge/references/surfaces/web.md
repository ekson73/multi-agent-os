# Surface: claude.ai (web)

> Load only when the intent is about the claude.ai chat app in the browser. Verified 2026-10-26; re-check the URLs before any "how".

- **What it is:** the Claude chat app in the browser.
- **Customization:** Projects (see `projects.md`), Skills, connectors.
- **Skills (verified):** available on Free, Pro, Max, Team and Enterprise, with code execution turned on. Enable on Free/Pro/Max under Settings > Capabilities; on Team/Enterprise an admin sets Organization settings > Plugins & skills > Policy. Upload a custom skill as a ZIP via Customize > Skills > "+" > Create skill > Upload a skill. The support article does not say which apps (web, desktop, mobile) show this; treat other surfaces as not verified.
- **Skills and Claude Code:** from Claude Code v2.1.273, enabled claude.ai skills are downloaded to `~/.claude/skills/synced/` when you sign in to Claude Code with a claude.ai account (`/login`). No sync with an API key, `ANTHROPIC_AUTH_TOKEN`, `CLAUDE_CODE_OAUTH_TOKEN`, `apiKeyHelper`, Bedrock, `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC`, bare mode, `--safe-mode`, or when managed settings lock skills to plugin sources. Turn off with `syncClaudeAiSkills: false`. API skills stay separate.
- **NOT VERIFIED:** the "styles" feature — no official page found (https://claude.com/blog/styles returns 404, and the personalization support article does not mention it). Do not describe how styles work or where they appear.

## Routes
- API code that calls Claude → `claude-api`.
- Turning instructions into a reusable skill → `agentic-tool-forge`.

## Sources
- https://support.claude.com/en/articles/12512180-use-skills-in-claude
- https://code.claude.com/docs/en/skills
- https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview
- https://support.claude.com/en/articles/10185728-understanding-claude-s-personalization-features (checked; no mention of styles)
