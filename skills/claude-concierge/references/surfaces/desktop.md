# Surface: Claude Desktop

> Load only when the intent is about the macOS/Windows desktop app. Verified 2026-10-26.

- **What it is:** desktop app for macOS and Windows (beta on Ubuntu/Debian). Its **Code** tab embeds Claude Code (then `code.md` applies).
- **Local MCP:** desktop extensions (`.mcpb`) install local MCP servers in one click, from the directory or a file. Credentials marked `sensitive` go to the OS keychain / Credential Manager. Admins can allow/block extensions.
- **NOT VERIFIED:** whether custom Agent Skills load in the desktop chat. The skills support article (https://support.claude.com/en/articles/12512180-use-skills-in-claude) covers plans, settings and upload but names no app; do not claim desktop support until a source does.

## Routes
- Same MCP must serve non-Claude hosts too → `harness-concierge`.
- Desktop Code tab questions → `code.md` / `claude-code-guide`.

## Sources
- https://support.claude.com/en/articles/10949351-getting-started-with-local-mcp-servers-on-claude-desktop
- https://code.claude.com/docs/en/overview.md
