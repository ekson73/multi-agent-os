# Open Design — Awareness Registry (landscape)

> Payload for `opendesign-concierge`. The Open Design surface + the external design-to-code landscape + when-to-use-which. Verified 2026-06-15.

## Open Design surface (what to orient over)
| Surface | Where | Use for |
|---|---|---|
| `od` CLI | `apps/daemon/bin/od.mjs` (build/Docker) | `plugin apply`, `skill list`, `mcp install`, code-migration |
| MCP server | `od mcp install <agent>` (stdio/local) | host agent calls Open Design as a tool |
| 152 design-systems | `design-systems/<slug>/` | brand `DESIGN.md` + tokens + components |
| 109 design-templates | `design-templates/<slug>/` | deck/dashboard/mobile-app/landing scaffolds |
| 11 craft rules | `craft/*.md` | brand-agnostic quality (a11y, typography, anti-ai-slop) |
| Desktop app | `apps/desktop` (Electron) | GUI workspace (parallel sessions) |
| AMR (optional, **paid**) | `open-design.ai/amr/` | zero-config model router — NOT required (BYOK) |

## External landscape (Open Design vs alternatives)
| Tool | What it is | How it differs from Open Design |
|---|---|---|
| **Open Design** | open-source, local-first, agent-native, CLI + plugin marketplace, code-migration scenario | the baseline here: portable, agent-agnostic, markdown `DESIGN.md` brands |
| **Figma Make + Agent** | Figma's on-canvas AI → production HTML/CSS/JS; MCP server | designer-centric, Figma-as-SSOT; OD is standalone, no Figma dependency |
| **v0** (Vercel) | AI → production React components | React-only, Vercel-bound; OD is framework-agnostic, headless |
| **Anima** | Figma→code agent | bridges Figma+agent; OD has no Figma dependency + covers existing-repo migration |
| **Banani** | generates design systems from text/images → Figma/code | asset-generator; OD is an orchestrator (agent-ready skills/plugins/projects) |
| **Google Stitch** | generative design canvas from text/image/voice | design-first canvas; OD is code-agent-native, CLI-driven, multi-agent |

## When to use Open Design
- ✅ You want a **portable, CLI-native, agent-agnostic** path (Claude Code / Cursor / Codex / Gemini), self-hostable (Docker, any cloud).
- ✅ You want to **apply a brand to an EXISTING repo** (`od-code-migration` — unique in the landscape).
- ✅ You want **markdown `DESIGN.md` brands** (versionable, diff-able) instead of Figma-token lock-in.
- ✅ You want **no local LLM** + BYOK with your existing agent.
- Prefer **Figma Make / Anima** if Figma is already your SSOT; **v0** if you're React+Vercel-only; **Banani/Stitch** if you need a generative design canvas first.

## Canonical machine facts (this environment)
- Clone: `~/.claude/plugins/marketplaces/open-design/` (don't reinstall) · wrangler 4.x ✅ · OpenSpec + Spec-Kit `specify` ✅ · node 22 / pnpm 10.28 (source-build wants 24/10.33 → prefer Docker) · POC: `~/Projects/vek-list-poc-opendesign-airbnb-design-system/`.
