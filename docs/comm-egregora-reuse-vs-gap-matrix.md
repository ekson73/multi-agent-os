---
id: comm-egregora-reuse-vs-gap-matrix-2026-09-12
version: 1.0.0
type: decision-matrix
status: draft (operator ratification pending)
owner: operator (ekson73)
last_updated: 2026-10-14
related:
  - "<private operational vault>/designs/comm-egregora-chassis.md" (v0.3.0-draft)
  - the ADR-comm-egregora-program v1.0.0 (operator-internal decision log) (v1.0.0)
  - WA-Reuse-Research FINDINGS.md (branch research/whatsapp-reuse-research, commit 987e1a9)
  - Email-Reuse-Research FINDINGS.md (branch research/email-reuse, commit 083011a)
  - SDT-Reuse-Research FINDINGS.md (branch research/sdt-reuse)
slug: comm-egregora-reuse-vs-gap-matrix
---

# Comm-Egrégoræ — REUSE-vs-GAP Decision Matrix (Consolidated)

> **Scope:** synthesize the 3 reuse-research FINDINGS.md bundles (WA / Email /
> Slack+Discord+Telegram) into one decision matrix per channel, with the
> explicit verdict (REUSE | GAP-WRAPPER | FORK | DROP | DEFER) and the evidence path
> for each. Honors D1 (reuse-first) without forcing any FORK.

**Ratification gate — NOT SATISFIED:** the `related` sources above are private,
branch-local or mutable discovery references. All verdicts below are provisional:
no actionable verdict may be ratified or adopted until its supporting evidence
is sanitized (no credentials, account identifiers or private operational data)
and published with immutable public references. Require full-commit permalinks
to source `SKILL.md` and license/permission evidence, plus a public sanitized
research snapshot with content hashes and reproducible probe details. A private
vault path, branch name or abbreviated commit alone is insufficient. Do not
ratify this matrix while its cited decision evidence remains private or
branch-local. Producing the public evidence bundle remains follow-up work (§6),
and must finish before ratification/adoption; this edit does not ratify a verdict.

## 1. Verdict per channel

| Channel | Verdict | Best upstream seed | Evidence (source research bundle) |
|---|---|---|---|
| **WhatsApp — personal/unofficial (whatsmeow/linked-device)** | **REUSE** | `openclaw/wacli` (CLI) + `extensions/whatsapp/skills/wacli/SKILL.md` | WA bundle §3.1: 4 releases/7d, 30 contributors, MIT effective; #417/#418/#419 open issues are the only acceptance-blockers |
| **WhatsApp — Business Cloud API (Meta-approved WABA)** | **REUSE** | `twilio/ai` (`skills/twilio/twilio-whatsapp-send-message` + `twilio-whatsapp-manage-senders` + 8 siblings) | WA bundle §3.2: umbrella MIT, AAIF-shaped skills, complete coverage (free-form + template + sandbox + sender lifecycle + compliance + verify OTP) |
| **WhatsApp — platform orchestration (Logs/search/debug)** | **REUSE-if-Kapso-account-else-NO-OP** | `gokapso/agent-skills` (`observe-whatsapp` + `automate-whatsapp` + `integrate-whatsapp`) | WA bundle §3.3: 3 dedicated skills, 153 stars, AAIF-shaped. Real risk: NO top-level LICENSE file (404) → operator legal sign-off required |
| **WhatsApp — vendor-neutral wrapper** | **REUSE-as-fallback** | `membranedev/application-skills` (`skills/whatsapp` + 23 vendor siblings) | WA bundle §3.4: 24-SKILL breadth is unique; maintenance signal YELLOW (last commit 2026-04-28, 1 contributor). License risk: API SPDX null but inline `license: MIT` per SKILL.md frontmatter |
| **WhatsApp — personal via `whatsapp-web.js` (idanbeck)** | **DROP** | — | WA bundle §3.5: Claude-Code-only install path, `allowed-tools: Bash, Read` AAIF-incompatible for other hosts, puppeteer `--no-sandbox`, unofficial library breaks on WA UI changes |
| **Slack-only candidate (paymog)** | **DROP (wrong surface)** | — | WA bundle §3.6: `search/code?q=whatsapp+repo:paymog/slack-cli` returned 0 hits |
| **Email — Gmail/M365/Outlook (operator's actual surface)** | **REUSE** | `openclaw/gog` (Google Workspace 17 surfaces incl. Gmail) + `himalaya +msgraph` (M365) + operator's local `spark` for personal send access | Email bundle §1: gog v0.23.0 (Apache-2.0, 17 surfaces); himalaya v2.0.0 +msgraph (Apache-2.0); spark v1.3.1 already live with Gmail personal + M365 (operator work-account, redacted) (send access) |
| **Email — IMAP/SMTP vendor-neutral (163/QQ/126/YEAH/188)** | **DEFER (license/permission missing)** | `boomsystel-code/openclaw-workspace/skills/imap-smtp-email` | Email bundle: widest provider matrix; **NO upstream LICENSE file (404)** + 7mo stale → reject reuse by default until an applicable license or written permission is recorded; operator acceptance, attribution and provenance caveats grant no reuse rights |
| **Email — outlook.com personal via Graph API** | **GAP-WRAPPER (deferred)** | — | Email bundle §3.4: himalaya msgraph is M365/Enterprise-only; outlook.com personal requires a separate path |
| **Email — multi-vendor OAuth vault in one binary** | **GAP-WRAPPER (deferred)** | — | Email bundle §3.4: cc-gmail currently Setup-needed for Vek account; cross-client threading same |
| **Slack** | **REUSE** | `AceDataCloud/Skills@slack` (bot-API, Apache-2.0, AAIF frontmatter tested) | SDT bundle §5 reuse-seed: Apache-2.0; bot-API scope (matches operator's bot use case); full frontmatter read |
| **Discord** | **REUSE-WITH-BLOCKER** | `letta-ai/skills@discord` (stdlib-only Python, bot-API, spec-compatible) | SDT bundle §5 reuse-seed — **BLOCKED**: plaintext Discord bot token at `<config-file:redacted>` must be revoked + replaced with op:// reference before any openclaw/discord reuse path is wired |
| **Telegram** | **REUSE** | `sanjay3290/ai-skills@telegram` (bash+curl+jq, Apache-2.0, AAIF frontmatter tested) | SDT bundle §5 reuse-seed: pure bash + curl + jq — no install beyond a bot token; AAIF-tested frontmatter; secondary investigation target `himself65/finance-skills@telegram-reader` (1.6K installs, highest signal) pending |

## 2. Anti-theater audit — what we did NOT claim

- **0 `tested` claims**: zero skills installed/executed on any host. Every "AAIF spec-compatible" is from reading the raw SKILL.md frontmatter, not from a runtime invoke.
- **33 candidates probed** for the SDT bundle (not just the top-3 the operator's lens mentioned); 19 SKILL.md files flagged `unknown` and listed as next-pass work, not silently treated as spec-compatible.
- **License risks** for 4 candidates (membranedev, blink-new, boomsystel-code, tiangong staging) — flagged with SPDX + raw LICENSE check, not just inferred from repo description.
- **Discord token** verified by literal `grep -nE` regex match on `<config-file:redacted>` — not an inference.
- **Operator-account / token / JID leak**: zero in any of the 3 bundles. PII gate held.

## 3. Operator ratification items (HUMAN_DOMAIN gate)

These items touch vendor trust boundaries, license unknowns, or standing-policy
changes. Public, sanitized, immutable evidence under the gate above is required
before ratifying any actionable verdict or this matrix; operator sign-off cannot
waive it. Missing reuse rights also block adoption until an applicable license
or written permission is recorded. None execute without operator sign-off:

1. **Ratify then adopt eligible REUSE seeds** above (one selection per channel-surface), only after the evidence and rights gates pass. For Slack, Discord and Telegram, forge inputs derive from this matrix's ratified rows: `AceDataCloud/Skills@slack`, `letta-ai/skills@discord` and `sanjay3290/ai-skills@telegram`, respectively. Record the matrix revision, selected repository/skill, immutable upstream revision and AAIF evidence; chassis §11 must consume those selections rather than its historical alternatives. Do not emit unresolved alternatives or rejected/deferred references (including Telegram `membranedev/application-skills@telegram` and `skillhq/telegram@telegram`). Each generated channel skeleton SSOT has exactly one explicit `npx skills add …` command for the selected, pinned package. Missing selection/evidence blocks forging; a matrix change requires re-ratification and regeneration.
2. **Mirror `sanjay3290/ai-skills/skills/gmail` as a fallback** only when `openclaw/gog` is not on PATH (per Email bundle §6.2).
3. **DEFER `boomsystel-code/openclaw-workspace/skills/imap-smtp-email`** for 163/QQ/126/YEAH/188 (Email bundle §6.3): no reuse, copying, installation or adoption while upstream permission is missing. Reconsider reuse only after an applicable license or written permission is recorded with immutable public evidence; operator acceptance, attribution or provenance caveats do not supply permission.
4. **Do NOT pursue `agentqq/agently-mail` or `membranedev/application-skills`** — they do not resolve to real GitHub repos (Email bundle §6.4).
5. **Treat `sickn33/agentic-awesome-skills/skills/outlook-automation` as a non-candidate** (Rube MCP / Composio route bypasses native himalaya for no operator benefit — Email bundle §6.5).
6. **Defer the 3 GAP items** (Outlook.com personal via Graph, cross-client threading, multi-vendor OAuth vault in one binary) to a follow-up sprint — no candidate covers them today, and forking now without a real prototype is YAGNI (Email bundle §6.6).
7. **License review before any fork lands**: BeautyFree (GPL-3.0 — copyleft, do not mix with multi-agent-os MIT/Apache), refly-ai (license null — request clarification), skillhq (license null — request clarification) — SDT bundle §6.5.
8. **Discord bot token revocation** at `<config-file:redacted>` remains an additional credential blocker after the evidence/ratification gates; replace it with an op:// reference before wiring any Discord reuse path. Until all gates pass, Discord routes stay DOWNGRADED to HITL.

## 4. Cost–benefit (honest, observed vs estimated)

| Cost / benefit | Status | Source |
|---|---|---|
| 3 research bundles delivered with real probes (gh api + LICENSE + SKILL.md bytes) | **OBSERVED** | this round |
| AAIF spec-conformance verified at the frontmatter level for 4 seeds | **OBSERVED** | raw SKILL.md reads (5 cells in AAIF matrix) |
| Forks needed | **0** | DRY-first research holds across all 5 channels |
| Gap-wrappers needed | **3 (Outlook.com personal, cross-client threading, multi-vendor OAuth vault)** | Email bundle §3.4 |
| Maintenance burden if we adopt any fork | **ESTIMATED 2–4 h/week** | operator-personal estimate from prior comm-egregoræ sessions |
| Cost to install + adopt the 6 REUSE seeds | **ESTIMATED ~30 min one-shot** (gog/himalaya/AceDataCloud/letta-ai/sanjay3290 + openclaw already installed) | inferred from `which` outputs this round |

## 5. What this matrix does NOT claim

- "Works on host X" for any skill (zero runtime installs in this research pass).
- "Openclaw is the right vendor for X" beyond the per-channel evidence cited above (the WA bundle §3.1 caveat on #417/#418/#419 stands).
- "The 19 `unknown` AAIF cells in SDT §4 are spec-compatible" — they require a second pass to read their frontmatters before any reuse decision.

## 6. Next step (operator-facing, evidence before ratification)

**Pending follow-up:** bundle the sanitized research and source/license/permission
evidence into immutable public references, replacing private/branch-local decision
citations. Until that work is complete, keep this matrix draft and block
ratification, adoption and forge commands.

After that gate passes and ratifications 1–8 are accepted:
- **install only the ratified, eligible REUSE seeds** (chassis §11 consumes this matrix),
- **revoke + regenerate the Discord token** (unblocks Discord reuse path),
- **keep the IMAP/SMTP candidate DEFERRED** until license/written permission is recorded,
- **defer the 3 GAP items** to a follow-up sprint (no fabrication under YAGNI).
- **ADR-comm-egregora-program-2026-09-12 D1** (reuse-first vs fork) closes as RESOLVED.
