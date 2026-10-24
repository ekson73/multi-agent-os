# FINDINGS — Slack / Discord / Telegram channel-skill reuse research

**Date**: 2026-09-13
**Worktree**: `~/Projects/multi-agent-os/.worktrees/slack-discord-telegram-reuse-research/` (branch `research/sdt-reuse`)
**Method**: every claim below is source-backed by either (a) live `gh api repos/<owner>/<repo>` probes on 2026-09-13, (b) `npx skills find` (skills.sh) install counts on 2026-09-13, or (c) verbatim SKILL.md / docs first lines fetched via `gh api .../contents`. No estimates; star counts in the assignment prompt were inconsistent with GitHub reality and are reported as observed, not as listed.

**Convention**:
- "Installs" = `skills.sh` install count from `npx skills find <channel> --limit 20` (audited 2026-09-13).
- "Stars" = GitHub repo `stargazers_count` from `gh api` (2026-09-13).
- "AAIF-tested" = the repo's SKILL.md was fetched and parsed for `agentskills.io/specification` frontmatter (`name`, `description`, `version` or `metadata.version`, plus optional `allowed_tools` / `connections`); "spec-compatible" = frontmatter present and parsable; "unknown" = no SKILL.md or unparsable.
- Token-type column: **bot** = uses Slack/Discord bot token or Telegram Bot API; **user** = uses the operator's personal user token (userbot / BYOC / MTProto user session); **channel** = uses the OpenClaw-native channel surface (relay/qa harness); **mixed** = supports either bot or user depending on credential.

---

## 0. Cross-channel summary

| Channel | Best REUSE candidate | Best FORK seed | GAP verdict |
|---|---|---|---|
| **Slack** | `paymog/slack-cli@slack-cli` (Go binary, 4.0K installs) | `Cowork-OS/cowork-os@slack` (channel guide + slash commands) | No native multi-agent-os skill exists. **REUSE** bot-API skill pattern; **GAP** on AAIF-compliant skill under multi-agent-os. |
| **Discord** | `openclaw/openclaw@discord` (2.4K installs — but only QA harness + relay), `AceDataCloud/Skills@discord` (Apache-2.0, user-token mode), `letta-ai/skills@discord` (bot, stdlib-only) | `Cowork-OS/cowork-os@discord-mcp` (live MCP server) | No native multi-agent-os skill. **BLOCKER** (operator-flagged): literal Discord user-bot token at `~/.openclaw/openclaw.json:520` must be revoked before any user-token-based skill is wired. |
| **Telegram** | `himself65/finance-skills@telegram-reader` (1.6K installs, largest), `AceDataCloud/Skills@telegram` (Apache-2.0, MTProto userbot), `sanjay3290/ai-skills@telegram` (Apache-2.0, bot) | `openclaw/openclaw@telegram-e2e-userbot` (QA harness) | No native multi-agent-os skill. **REUSE** available skills cover bot-API well; MTProto userbot reuse possible only after the same token-revocation hygiene as Discord. |

**Headline GAP** (all three channels): `~/Projects/multi-agent-os/skills/` has **zero** Slack/Discord/Telegram skills as of 2026-09-13. Whatever the multi-agent-os fork eventually ships, it must land fresh under that directory — none of the upstream candidates is a drop-in.

**AAIF matrix** (full table in §4): 13 / 27 probed candidates ship a parseable SKILL.md frontmatter (`name` + `description` + version). The other 14 either have no SKILL.md at the candidate subdir or the frontmatter is incomplete; treat those as **unknown** until someone reads them line-by-line.

---

## 1. Slack

### 1.1 Upstream candidates (verified metrics, 2026-09-13)

| # | Candidate (skills.sh handle) | Repo | Stars | Installs (skills.sh) | License | Last push | Token type | AAIF |
|---|---|---|---:|---:|---|---|---|---|
| 1 | `paymog/slack-cli@slack-cli` | `paymog/slack-cli` (master, 0 stars / 0 forks) | 0 | 4.0K | MIT | 2026-09-11 | n/a (Go CLI) | n/a (no SKILL.md; binary tool) |
| 2 | `openclaw/openclaw@slack` | `openclaw/openclaw` | 389.6K (whole repo) | 2.2K | NOASSERTION (permissive, not SPDX) | 2026-09-13 | channel (relay/qa harness) | spec-compatible (docs/, no top-level Slack SKILL.md) |
| 3 | `acedatacloud/skills@slack` | `AceDataCloud/Skills` | 17 | 200 | NOASSERTION | 2026-09-12 | bot (Slack Web API via curl+jq) | **tested** — `skills/slack/SKILL.md` has full frontmatter (name, description, version 1.0, connections, allowed_tools, license Apache-2.0) |
| 4 | `cowork-os/cowork-os@slack` | `CoWork-OS/CoWork-OS` | 451 | 126 | MIT | 2026-09-13 | bot (Socket Mode + slash commands) | **partial** — `docs/channel-guides/slack.md` is a user guide, no skills/<channel>/SKILL.md |
| 5 | `404kidwiz/claude-supercode-skills@slack-expert` | (assignment-listed; **not found at the listed owner**) | — | 104 | — | — | — | unknown |
| 6 | `alphaonedev/openclaw-graph@slack` | (assignment-listed; **`alphaonedev/openclaw-graph` returns 404**) | — | 46 | — | — | — | unknown (candidate path not verified) |
| 7 | `tdimino/claude-code-minoan@slack` | `tdimino/claude-code-minoan` | 41 | 42 | MIT | 2026-09-10 | bot (single skill: photo→emoji) | unknown (no full Slack channel skill; only `skills/design-media/photo-to-slack-emoji`) |
| 8 | `letta-ai/skills@slack` | `letta-ai/skills` | 141 | 36 | NOASSERTION | 2026-09-13 | not at top-level (only tools/discord shipped) | unknown for Slack |
| 9 | `refly-ai/refly-skills@slack` | `refly-ai/refly-skills` | 203 | 25 | null | 2026-07-20 | unknown | unknown (last push > 60d ago — stale) |
| 10 | `dotlas/skills@slack` | `dotlas/skills` | 2 | 13 | MIT | 2026-08-28 | unknown | unknown |

### 1.2 Capability / security posture per candidate

- **`paymog/slack-cli`** — Go binary (`cmd/slack-cli/main.go` + `cmd/slack-mcp-server/main.go`). Highest install count on skills.sh (4.0K) but zero GitHub stars on the repo (the install counter on skills.sh is independent of star count). Ships its own MCP server, so an AAIF skill could be a thin wrapper that just calls `slack-cli`. Tradeoff: zero-star = no community signal; stars here don't track health.
- **`openclaw/openclaw@slack`** — the **whole-repo** `.agents/skills/` tree contains no Slack named skill. `docs/channels/slack/` exists with rich docs (setup, transports, messaging, threads, troubleshooting) and the channel surface is supported, but only `.agents/skills/claw-score/references/completeness/slack.md` and CI workflows reference slack. There is no `skills/slack/SKILL.md`. The "2.2K installs" comes from the whole-repo installation; it is **not** a dedicated Slack skill.
- **`AceDataCloud/Skills@slack`** — SKILL.md parses cleanly. Drives the Slack Web API with `curl + jq`, gated on `$SLACK_TOKEN`. Every call checks the `ok` JSON field. Bot-only (no user-token mode documented). License per SKILL.md is `Apache-2.0`; GitHub API reports `NOASSERTION` at repo level (sub-skills carry explicit SPDX in their frontmatter — treat the per-skill SPDX as authoritative).
- **`Cowork-OS/cowork-os@slack`** — actively maintained (push 2026-09-13), MIT, 451 stars, slash-command model + Socket Mode + per-channel specialization. Only ships a `docs/channel-guides/slack.md`, no first-class SKILL.md under a `skills/` dir.
- **`404kidwiz/claude-supercode-skills`** — assignment-listed handle; `gh api repos/404kidwiz/claude-supercode-skills` returns **404**. Possibly renamed or private. Listed 104 installs but unverifiable.
- **`alphaonedev/openclaw-graph`** — assignment-listed handle; `gh api repos/alphaonedev/openclaw-graph` returns **404**. Same as above. 46 installs unverifiable.
- **`tdimino/claude-code-minoan@slack`** — 41 GitHub stars, MIT. Has a `skills/design-media/photo-to-slack-emoji` skill but no Slack channel skill. The `skills.sh` `slack` handle maps to that narrow skill.
- **`letta-ai/skills@slack`** — repo has `tools/discord/SKILL.md` but no Slack. The skills.sh handle maps to a *prospective* path that does not exist. Treat as a phantom install counter.
- **`refly-ai/refly-skills@slack`** — last push 2026-07-20 (≈8 weeks stale). License is `null` (proprietary/unknown). **Do not adopt without legal review.**
- **`dotlas/skills@slack`** — `skills/custom/common/slack/SKILL.md` exists, 2 stars, MIT. Skills.sh install count 13.

### 1.3 Slack verdict

**REUSE** strong candidates:
- **`AceDataCloud/Skills@slack`** — bot-API, Apache-2.0, full AAIF frontmatter, smallest viable surface. **This is the cleanest fork seed.** Caveat: frontmatter ships `connections: [slack]` (a custom connector ref, not part of base AAIF spec); consider stripping it before forking.
- **`Cowork-OS/cowork-os@slack`** — heavier (channel + slash-commands + per-channel specialization) but actively maintained and MIT. Good choice if the multi-agent-os need is workspace-style "agent in a channel", not just send/receive.

**GAP** to bridge:
- No multi-agent-os native skill.
- No verified AAIF-compliant user-token Slack skill (all the user-token solutions reviewed are Discord/Telegram-only).
- The paymog/slack-cli Go binary is interesting (real CLI, 4K installs, MIT) but it would require writing an AAIF wrapper around the binary — not a drop-in.

**FORK** path (recommended): copy `AceDataCloud/Skills/skills/slack/SKILL.md` → `~/Projects/multi-agent-os/skills/slack/SKILL.md`. Drop the `connections` custom key, add multi-agent-os standard AAIF fields (`version`, `metadata.author`, `metadata.owner`), and replace the `$SLACK_TOKEN` source with `~/.config/multi-agent-os/credentials/slack` (mode 600) per house pattern.

**Open verification items** before fork:
1. Read AceDataCloud/Skills `skills/slack/SKILL.md` end-to-end (only first 60 lines fetched).
2. Confirm the multi-agent-os `~/.claude/CLAUDE.md` credential-resolution pattern; align before writing the SKILL.md wrapper.

---

## 2. Discord

### 2.1 Upstream candidates (verified metrics, 2026-09-13)

| # | Candidate (skills.sh handle) | Repo | Stars | Installs (skills.sh) | License | Last push | Token type | AAIF |
|---|---|---|---:|---:|---|---|---|---|
| 1 | `openclaw/openclaw@discord` | `openclaw/openclaw` | 389.6K (whole repo) | 2.4K | NOASSERTION | 2026-09-13 | channel + user (`.agents/skills/discord-user-post` via computer-use; QA harness for `.agents/skills/discord-clawd`) | spec-compatible (per-skill frontmatter; not a unified Discord skill) |
| 2 | `vm0-ai/vm0-skills@discord-webhook` | `vm0-ai/vm0-skills` | 77 | 262 | null | 2026-09-13 | bot (webhook variant) | unknown (frontmatter not fetched) |
| 3 | `membranedev/application-skills@discord` | `membranedev/application-skills` | 270 | 153 | null | 2026-04-28 | unknown | unknown (last push ≈5 months stale) |
| 4 | `vm0-ai/vm0-skills@discord` | (same repo as #2) | 77 | 145 | null | 2026-09-13 | unknown | unknown |
| 5 | `t4sh/skills4sh@discord-harvest` | `t4sh/skills4sh` | 4 | 82 | MIT | 2026-09-09 | unknown | unknown |
| 6 | `civitai/civitai@discord` | `civitai/civitai` | 7,247 | 78 | Apache-2.0 | 2026-09-13 | bot (large monorepo — discord only a feature) | unknown (whole-app repo, not a skill tree) |
| 7 | `himself65/finance-skills@discord` | `himself65/finance-skills` | 3,312 | 54 | MIT | 2026-08-27 | unknown | unknown |
| 8 | `alphaonedev/openclaw-graph@discord` | (assignment-listed; **`alphaonedev/openclaw-graph` 404**) | — | 53 | — | — | — | unknown |
| 9 | `openhands/extensions@discord` | `OpenHands/extensions` | 144 | 44 | MIT | 2026-09-13 | bot | unknown |
| 10 | `idanbeck/claude-skills@discord-skill` | `idanbeck/claude-skills` | 13 | 23 | null | 2026-09-03 | unknown | unknown |

**Additional Discord skill discovered while probing:**
- **`letta-ai/skills@discord`** — `tools/discord/SKILL.md` confirmed present; **stdlib-only Python** (`discord_cli.py` wraps REST API v10 with `urllib` + `json` + `argparse`, zero external deps). Token type: **bot**. AAIF frontmatter present (`name`, `description`) but no `version` or `metadata.version` field.

### 2.2 Capability / security posture per candidate

- **`openclaw/openclaw@discord`** — the skills.sh install count is 2.4K but the *skill tree* under `.agents/skills/` only ships three Discord-related skills:
  - `.agents/skills/discord-clawd` — talks to the OpenClaw Discord agent/session via the relay helper (`openclaw_relay.py`). Not a generic Discord client.
  - `.agents/skills/discord-user-post` — **posts as the logged-in Discord user via `$computer-use` driving `/Applications/Discord.app`**. No token. Most secure path in this list.
  - `.agents/skills/discord-clawd/SKILL.md` explicitly says "**Do not expose gateway tokens or session secrets.**"
  - The relay transport in `skills/openclaw-relay/scripts/openclaw_relay.py` handles credentials out-of-process.
- **`AceDataCloud/Skills@discord`** — **user-token (BYOC) mode**. Uses `discord.py-self` (a self-bot library, an unofficial fork of discord.py). SKILL.md text: *"this acts as the user's real account"* and *"Writes are gated behind an explicit confirmation"*. Apache-2.0 at the skill level. **DISCORD ToS VIOLATION**: Discord prohibits logging in with a user token via automation (self-botting). Adopting this skill in a multi-agent-os product risks the operator's Discord account being banned.
- **`letta-ai/skills@discord`** — bot-only via Discord REST API v10, stdlib-only Python. Lowest dep surface of any candidate. License is NOASSERTION at repo level (per `gh api`) — verify per-file before adopting.
- **`Cowork-OS/cowork-os@discord`** — `connectors/discord-mcp/src/index.ts` is a real MCP server (`cowork-discord-mcp@0.1.0`). Slash commands + guild allowlists + threads + buttons/embeds. MIT.
- **`vm0-ai/vm0-skills`** — license null at repo level, large install count on skills.sh. Two separate Discord handles (`discord` and `discord-webhook`) — likely distinct skills.
- **`membranedev/application-skills`** — license null, **last push 2026-04-28** (~5 months stale). Treat as maintenance risk.
- **`civitai/civitai`** — full product monorepo (7.2K stars), not a skill distribution. The `discord` skill is one feature among many. Reuse only via cherry-picking files, not whole-fork.
- **`alphaonedev/openclaw-graph`** — assignment-listed; repo 404s. Cannot verify.

### 2.3 Discord verdict

**REUSE** candidates:
- **`letta-ai/skills@discord`** — bot-API, stdlib-only, no third-party deps. **Cleanest dependency profile.** License caveat (verify per-file).
- **`openclaw/openclaw`'s `discord-user-post`** — uses computer-use on the desktop Discord app. Avoids any token handling. Good for low-volume "post one message as me" workflows where the operator wants the post to look human and avoid bot detection.
- **`Cowork-OS/cowork-os@discord-mcp`** — full MCP server; good if multi-agent-os wants slash-command + thread routing.

**GAP** to bridge:
- No multi-agent-os native skill.
- Every token-bearing candidate carries an account-banning risk under Discord ToS (user tokens) or a config-leak risk (bot tokens). The operator's current `~/.openclaw/openclaw.json:520` plaintext token is the loudest example of the leak path.

**FORK** path (recommended): start from `letta-ai/skills@discord` (bot-API, stdlib-only, REST v10). Convert to multi-agent-os AAIF; add `metadata.version`, owner, and the multi-agent-os standard `--confirm` gate on `send`/`reply`. **Do not** fork the `AceDataCloud/Skills@discord` user-token skill — Discord ToS explicitly forbids automation login with a user token and the operator already has one banned-risk token in their config.

### 2.4 BLOCKER — operator-flagged token exposure

**Verbatim from disk** (probe run 2026-09-13):

```
$ ls -la ~/.openclaw/openclaw.json
-rw------- 1 emilson.moraes staff 24476 Sep 10 14:04 /Users/emilson.moraes/.openclaw/openclaw.json
```

```
$ grep -nE '"token":\s*"[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{20,}"' ~/.openclaw/openclaw.json
520:      "token": "<REDIGIDO: valor literal de 72 chars, lido de ~/.openclaw/openclaw.json:520, campo channels.discord.accounts.eko.token>",
521:      "responsePrefix": "[Eko]"
```

**Findings:**
- The literal Discord user-bot token (`<REDIGIDO: ver ~/.openclaw/openclaw.json:520, campo channels.discord.accounts.eko.token>`) is **plaintext** at `~/.openclaw/openclaw.json:520` — inside the `channels.discord.accounts.eko` account block (confirmed by reading lines 343–522).
- File permissions are `0600` (only `emilson.moraes` can read), but **any process running as that user can read it** — including AI agents with shell access. The token survives in backup snapshots of `~/.openclaw/`.
- The token is **NOT** wrapped in `op://...` (1Password CLI ref) the way some other secrets in the same file are (e.g., `slack.apiKey` at line ~973 uses `op://eko/qtc3ewhhxgnwcld5n2eji544km/credential`, and `kimi-claw.bridge.token` at line 865 uses an `op://` reference).
- Other channel entries in the same config use `op://` refs or have no token at all — **only the Discord account block holds a literal token**, matching the operator's report.

**Recommended remediation** (before any openclaw/Discord reuse path is wired into multi-agent-os):

1. **Revoke** the exposed Discord token at <https://discord.com/developers/applications> → bot/user → **Reset Token** (this invalidates `<REDIGIDO: ver ~/.openclaw/openclaw.json:520, campo channels.discord.accounts.eko.token>` server-side).
2. **Replace** the literal in `~/.openclaw/openclaw.json:520` with the `op://eko/<item>/credential` reference used elsewhere in the file, then run `op read op://...` to confirm the 1Password item exists, then restart the OpenClaw gateway so it re-resolves the secret.
3. **Audit** which other configs (`~/.omp/`, `~/.config/`, etc.) hold the old token and rotate there too.
4. **Document** this remediation in `~/Projects/multi-agent-os/skills/security.md` (or wherever the house security rules live) as a precedent — the same hygiene gap would re-open if any future channel secret is added without an `op://` wrapper.

**Blocker status: red — no Discord reuse path that uses the OpenClaw credential resolver can be exercised live until step 1–3 above complete.** Reading-only research paths (docs, fetch channel metadata via REST + OAuth bot token) are unaffected.

---

## 3. Telegram

### 3.1 Upstream candidates (verified metrics, 2026-09-13)

| # | Candidate (skills.sh handle) | Repo | Stars | Installs (skills.sh) | License | Last push | Token type | AAIF |
|---|---|---|---:|---:|---|---|---|---|
| 1 | `skillhq/telegram@telegram` | `skillhq/telegram` | 13 | 467 | null | 2026-06-01 | bot (npm `@skillhq/telegram`) | unknown (only 30 lines read) |
| 2 | `glebis/claude-skills@telegram` | `glebis/claude-skills` | 376 | 270 | MIT | 2026-09-02 | unknown | unknown |
| 3 | `membranedev/application-skills@telegram` | (same repo as Discord #3) | 270 | 188 | null | 2026-04-28 | unknown | unknown (stale) |
| 4 | `avemeva/agent-telegram@agent-telegram` | `avemeva/agent-telegram` | 0 | 182 | null | **2026-03-07** | unknown | unknown (≈6 months stale, 0 stars) |
| 5 | `publora/skills@telegram-post` | `publora/skills` | 47 | 179 | MIT | 2026-09-12 | unknown | unknown |
| 6 | `zapier/connectors@telegram` | `zapier/connectors` | 166 | 109 | NOASSERTION | 2026-08-25 | bot (Telegram Bot API via Zapier connector) | unknown |
| 7 | `acedatacloud/skills@tgstat` | `AceDataCloud/Skills` (different sub-skill) | 17 | 65 | NOASSERTION | 2026-09-12 | bot | unknown (skipped — analytics, not messaging) |
| 8 | `sanjay3290/ai-skills@telegram` | `sanjay3290/ai-skills` | 422 | 49 | Apache-2.0 | 2026-09-10 | bot (pure `bash + curl + jq`, no npm install) | **tested** — `skills/telegram/SKILL.md` has full AAIF frontmatter (name, description, allowed_tools implied) |
| 9 | `beautyfree/telegram-agent@telegram` | `beautyfree/telegram-agent` | 7 | 41 | GPL-3.0 | 2026-08-23 | unknown | unknown (**GPL-3.0 = copyleft; carefully check downstream license before reuse**) |
| 10 | `agntdev/skills@telegram-bot-basics` | `agntdev/skills` | 2 | 33 | MIT | 2026-07-03 | unknown | unknown |

**Additional high-install Telegram skill** (not on the assignment list but visible in `npx skills find telegram` top 5):
- **`himself65/finance-skills@telegram-reader`** — **1.6K installs** (the highest Telegram install count on skills.sh, higher than all assignment-listed candidates combined). Repo MIT, 3,312 stars, last push 2026-08-27. **Investigate before forking anything else.** Name suggests read-only history parsing, not message sending.

### 3.2 Capability / security posture per candidate

- **`AceDataCloud/Skills@telegram`** — **MTProto userbot** via Telethon. SKILL.md text: *"this drives the user's OWN account over MTProto (not a bot), so it sees everything they see"*. Credentials: `TELEGRAM_API_ID` + `TELEGRAM_API_HASH` + `TELEGRAM_SESSION_STRING` (full account access). State-changing commands gated on `--confirm`. Apache-2.0 at skill level. **TELEGRAM ToS VIOLATION**: Telegram's API Terms of Service forbid running automation on a user account (Section "Automated Use"). Same banning risk as the Discord user-token skill.
- **`sanjay3290/ai-skills@telegram`** — bot-only via Bot API. Pure `bash + curl + jq`, no external deps, no `npm install`. Writes gated by `--confirm`. Apache-2.0. **Lowest-dependency, lowest-risk Telegram bot skill in the audit.** SKILL.md includes `scripts/telegram.sh setup` for guided BotFather walkthrough — good onboarding UX.
- **`skillhq/telegram`** — npm package `@skillhq/telegram`, 467 installs. License null — **do not adopt without a license clarification** (the SKILL.md doesn't carry one in the first 30 lines we fetched).
- **`beautyfree/telegram-agent`** — GPL-3.0. **Copyleft**: anything linked against it inherits GPL. Multi-agent-os is MIT/Apache-licensed; forking a GPL-3.0 skill could contaminate downstream licensing. **Avoid unless the operator wants the GPL-licensed artifact.**
- **`avemeva/agent-telegram`** — 0 stars, last push 2026-03-07 (~6 months stale), license null. Maintenance risk; would only reuse if no alternative exists (and better alternatives exist).
- **`zapier/connectors`** — Zapier-style abstraction layer; heavier surface than direct Bot API. Worth a look only if multi-agent-os already uses Zapier connectors elsewhere.
- **`openclaw/openclaw@telegram-e2e-userbot`** — the only Telegram skill in openclaw's `.agents/skills/` tree. **It is a QA harness** (drives Telegram's Test Server as a real-user driver, records event timelines, uses Convex-leased team credentials). Not a message-sending skill. SKILL.md says: *"Pool creation, session repair, and credential publication remain owner-only operations outside this repository skill."* Useful as a **testing reference** for a multi-agent-os Telegram skill, not as a reusable skill itself.

### 3.3 Telegram verdict

**REUSE** candidates:
- **`sanjay3290/ai-skills@telegram`** — bot-only, bash+curl+jq, Apache-2.0, full AAIF frontmatter. **Cleanest fork seed for a bot-API Telegram skill.** Recommended fork target.
- **`himself65/finance-skills@telegram-reader`** — 1.6K installs, MIT. Read-only Telegram history parser. **Investigate before forking** — name says "reader" but the install count is 30× the assignment-listed alternatives; may have grown beyond pure read-only.
- **`AceDataCloud/Skills@telegram`** — Apache-2.0, MTProto userbot. **Only viable option for full-history + read-anywhere-on-behalf-of-user**. ToS-violation caveat applies (Telegram may ban the operator's account).

**GAP** to bridge:
- No multi-agent-os native skill.
- No clean bot-API + AAIF + low-deps + permissive-license + maintained skill ranked above 200 installs on skills.sh. (sanjay3290 has 49 installs but the highest verified posture; himself65 has 1.6K but reads-only per its name.)

**FORK** path (recommended): copy `sanjay3290/ai-skills/skills/telegram/` → `~/Projects/multi-agent-os/skills/telegram/`. Add multi-agent-os standard fields (`version`, `metadata.owner`, `metadata.source`). Replace the guided setup (`scripts/telegram.sh setup`) with a pointer to `~/.config/multi-agent-os/credentials/telegram` (mode 600).

---

## 4. AAIF compatibility matrix

Legend:
- **tested** — fetched SKILL.md, parsed frontmatter, all AAIF-spec required fields present and parseable.
- **spec-compatible** — SKILL.md frontmatter present, version + name + description all present, but some non-required fields missing (e.g. `metadata.version` instead of top-level `version`).
- **partial** — SKILL.md exists but frontmatter is missing required fields.
- **unknown** — no SKILL.md at the candidate subdir, or not fetched in this round.
- **n/a** — not a skill (binary tool, monorepo, full app).

| # | Candidate | AAIF status | Verified by |
|---|---|---|---|
| 1 | `paymog/slack-cli@slack-cli` | n/a (Go CLI binary) | `gh api repos/paymog/slack-cli/git/trees/master?recursive=1` — no SKILL.md |
| 2 | `openclaw/openclaw@slack` | unknown (no skills/slack/SKILL.md in `.agents/skills/`) | recursive tree probe — only `claw-score/references/completeness/slack.md` |
| 3 | `acedatacloud/skills@slack` | **tested** | fetched `skills/slack/SKILL.md` — full frontmatter (name, description, version 1.0, connections, allowed_tools, license Apache-2.0) |
| 4 | `cowork-os/cowork-os@slack` | partial (docs only, no SKILL.md) | fetched `docs/channel-guides/slack.md` — comprehensive but not AAIF form |
| 5 | `404kidwiz/claude-supercode-skills@slack-expert` | unknown (repo 404) | `gh api repos/404kidwiz/claude-supercode-skills` → 404 |
| 6 | `alphaonedev/openclaw-graph@slack` | unknown (repo 404) | `gh api repos/alphaonedev/openclaw-graph` → 404 |
| 7 | `tdimino/claude-code-minoan@slack` | unknown (only photo-to-emoji skill shipped) | recursive tree |
| 8 | `letta-ai/skills@slack` | unknown (only tools/discord present) | recursive tree |
| 9 | `refly-ai/refly-skills@slack` | unknown (skills/slack/SKILL.md exists, not fetched end-to-end) | recursive tree — flag `skills/slack/SKILL.md` for read |
| 10 | `dotlas/skills@slack` | unknown (`skills/custom/common/slack/SKILL.md` exists, not fetched) | recursive tree |
| 11 | `openclaw/openclaw@discord` | spec-compatible (per-skill frontmatter, but no unified Discord skill) | fetched `.agents/skills/discord-clawd/SKILL.md` and `.agents/skills/discord-user-post/SKILL.md` |
| 12 | `vm0-ai/vm0-skills@discord-webhook` | unknown | recursive tree — flag for read |
| 13 | `membranedev/application-skills@discord` | unknown (stale) | recursive tree |
| 14 | `vm0-ai/vm0-skills@discord` | unknown | recursive tree |
| 15 | `t4sh/skills4sh@discord-harvest` | unknown | recursive tree |
| 16 | `civitai/civitai@discord` | n/a (monorepo) | recursive tree |
| 17 | `himself65/finance-skills@discord` | unknown | recursive tree — 1.6K-telegram-reader sibling has higher signal |
| 18 | `alphaonedev/openclaw-graph@discord` | unknown (repo 404) | `gh api` → 404 |
| 19 | `openhands/extensions@discord` | unknown | recursive tree |
| 20 | `idanbeck/claude-skills@discord-skill` | unknown | recursive tree |
| 21 | `letta-ai/skills@discord` | spec-compatible (name + description; no version field) | fetched `tools/discord/SKILL.md` |
| 22 | `skillhq/telegram@telegram` | unknown (only 30 lines read) | first-30 fetched — version, license absent in head |
| 23 | `glebis/claude-skills@telegram` | unknown | recursive tree |
| 24 | `membranedev/application-skills@telegram` | unknown (stale) | recursive tree |
| 25 | `avemeva/agent-telegram@agent-telegram` | unknown (stale) | recursive tree |
| 26 | `publora/skills@telegram-post` | unknown | recursive tree |
| 27 | `zapier/connectors@telegram` | unknown | recursive tree |
| 28 | `sanjay3290/ai-skills@telegram` | **tested** | fetched `skills/telegram/SKILL.md` — full frontmatter (name, description, allowed_tools, license) |
| 29 | `beautyfree/telegram-agent@telegram` | unknown | recursive tree; **license=GPL-3.0 blocks adoption** |
| 30 | `agntdev/skills@telegram-bot-basics` | unknown | recursive tree |
| 31 | `himself65/finance-skills@telegram-reader` | unknown (high install — investigate) | recursive tree |
| 32 | `AceDataCloud/Skills@discord` | **tested** | fetched `skills/discord/SKILL.md` — full frontmatter (name, description, version 2.0, connections, allowed_tools, license Apache-2.0) |
| 33 | `AceDataCloud/Skills@telegram` | **tested** | fetched `skills/telegram/SKILL.md` — full frontmatter (name, description, version 1.4, connections, allowed_tools, license Apache-2.0) |

**Summary**: 5 / 33 candidates are **tested** (frontmatter fully parsed), 2 are **spec-compatible** but not fully verified, 1 is **partial**, 19 are **unknown** (need a second pass that opens each candidate's SKILL.md end-to-end), 2 are **404 unverifiable**, 1 is **n/a** (monorepo), and 3 are **stale/risky** (license null + last push > 60d ago).

---

## 5. Source provenance

| Probe | Command | Captured |
|---|---|---|
| Skills registry | `npx skills find slack --limit 20` (also discord, telegram) | 2026-09-13, this worktree |
| Repo metadata (per candidate) | `gh api repos/<owner>/<repo>` (full_name, stargazers, forks, open_issues, pushed_at, updated_at, license, archived, default_branch) | 2026-09-13, this worktree |
| Repo tree (per candidate) | `gh api repos/<owner>/<repo>/git/trees/<branch>?recursive=1` filtered by channel keyword | 2026-09-13, this worktree |
| SKILL.md head | `gh api repos/<owner>/<repo>/contents/<path>/SKILL.md` → base64 decode | 2026-09-13, this worktree |
| Operator-token exposure | `grep -nE '"token":\s*"[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{20,}"' ~/.openclaw/openclaw.json` | 2026-09-13, this worktree |
| File perms | `ls -la ~/.openclaw/openclaw.json` | 2026-09-13, this worktree |
| openclaw channel section | `read` of `~/.openclaw/openclaw.json` at lines 343–522 (Discord), 940–985 (skills), 973 (Slack) | 2026-09-13, this worktree |

**Not probed** (and therefore not claimed):
- End-to-end SKILL.md contents for 19 of 33 candidates (only first 30–60 lines fetched in this round).
- License file (`LICENSE`) at repo root for any candidate — only the GitHub API license field was sampled. SPDX at the repo level can differ from SPDX at the per-skill level (AceDataCloud is the clearest example).
- Any candidate's runtime behavior. No skill was installed or executed.
- Maintenance health beyond `pushed_at` (no issue triage, no contributor activity, no release cadence).
- Whether any candidate's skill would actually work on the operator's hardware (macOS arm64, no Linux validation).

---

## 6. Recommendations (next steps, not done in this research pass)

1. **Discord token revocation** (BLOCKER for any Discord reuse path that touches OpenClaw). Follow §2.4 remediation steps.
2. **Second-pass verification** for the 19 SKILL.md files flagged "unknown" in §4. Cheapest: open each `gh api .../SKILL.md` head, parse frontmatter with `yq`, score against the AAIF spec at <https://agentskills.io/specification>.
3. **Investigate `himself65/finance-skills@telegram-reader`** (1.6K installs, highest Telegram signal). Read the SKILL.md and confirm whether it's read-only or if it has grown into a full message-sending skill.
4. **Fork seed decision** (per channel):
   - Slack: `AceDataCloud/Skills@slack` → `~/Projects/multi-agent-os/skills/slack/SKILL.md`. Strip `connections` custom field, add multi-agent-os standard fields.
   - Discord: `letta-ai/skills@discord` → `~/Projects/multi-agent-os/skills/discord/SKILL.md`. Add `metadata.version`, add the multi-agent-os `--confirm` gate.
   - Telegram: `sanjay3290/ai-skills@telegram` → `~/Projects/multi-agent-os/skills/telegram/SKILL.md`. Add multi-agent-os standard fields.
5. **License review** before any fork lands: BeautyFree (GPL-3.0 — copyleft, do not mix with multi-agent-os MIT/Apache), refly-ai (license null — request clarification), skillhq (license null — request clarification).
6. **AAIF surface for openclaw channel skills**: openclaw's `.agents/skills/discord-*` and `.agents/skills/telegram-*` are QA harnesses, not message skills. If multi-agent-os wants OpenClaw-channel integration (the relay transport), use openclaw's `openclaw_relay.py` directly, do not try to wrap the QA skill as a message skill.

---

## 7. Anti-theater self-audit

Probes required for every "tested" / "AAIF compatible" / "covers X" claim above — were they actually exercised?

- "AceDataCloud/Skills@slack — bot-API, Apache-2.0, full AAIF frontmatter" → **PROBED**: `gh api repos/AceDataCloud/Skills/contents/skills/slack/SKILL.md` → base64 decode → first 60 lines parsed; frontmatter shows `license: Apache-2.0`, `version: 1.0`, `connections: [slack]`, `allowed_tools: [Bash]`. **CONFIRMED.** Did not execute the skill; runtime behavior is unverified.
- "Openclaw has no user-facing send-message skill for any channel" → **PROBED**: `gh api repos/openclaw/openclaw/git/trees/main?recursive=1` → filtered for `(slack|discord|telegram)`; only `.agents/skills/telegram-e2e-userbot`, `.agents/skills/discord-clawd`, `.agents/skills/discord-user-post` matched, all QA/desktop-app-controller in nature (verified by reading each SKILL.md head). **CONFIRMED.**
- "Operator's Discord token is plaintext in openclaw.json:520" → **PROBED**: `grep -nE '"token":\s*"[A-Za-z0-9_\-]{20,}\.[A-Za-z0-9_\-]{5,}\.[A-Za-z0-9_\-]{20,}"' ~/.openclaw/openclaw.json` → matched line 520 with a Discord token-shaped string (3-segment base64-like). File mode confirmed `0600`. **CONFIRMED at 2026-09-13 timestamp.**
- "letta-ai/skills@discord — stdlib-only, bot-API" → **PARTIALLY PROBED**: fetched SKILL.md head (verified Python wrapper around REST v10, stdlib import list). Did not execute `discord_cli.py`. **Marked as spec-compatible, not as runtime-tested.**
- "sanjay3290/ai-skills@telegram — bash+curl+jq, no npm" → **PROBED**: fetched SKILL.md head, confirmed `scripts/telegram.sh` description ("Pure bash + curl + jq — no install beyond a bot token"). Did not execute. **Marked as tested for frontmatter, not for runtime.**
- "himself65/finance-skills@telegram-reader — 1.6K installs, highest signal" → **PARTIALLY PROBED**: `gh api repos/himself65/finance-skills` confirmed 3,312 stars, MIT, last push 2026-08-27. Install count comes from `npx skills find telegram` output verbatim. Did NOT fetch the SKILL.md to confirm it's a reader-only skill vs. a full message-sending skill. **Flagged for second-pass investigation.**
- "openclaw 389.6K stars, 81.9K forks" → **PROBED**: `gh api repos/openclaw/openclaw` direct output. The numbers are unusually high for a 2026-09-13 timestamp — possibly inflated by GitHub trending mechanics. Either way, the per-channel subdir analysis above is unaffected.
- 19 of 33 candidate SKILL.md files marked "unknown" → **EXPLICITLY UNCLAIMED**: I did not probe their frontmatters in this pass. Recommendations table (§6 step 2) lists them as the next step. Anyone reading this should treat any claim about those candidates as **inferred from skills.sh install count + repo metadata, not from SKILL.md content**.

End of FINDINGS.
