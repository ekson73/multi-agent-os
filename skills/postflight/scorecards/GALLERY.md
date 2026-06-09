# Postflight Scorecard Gallery — 7 end-of-action status-card models

> Candidate **output formats** for `postflight` P3 HANDOFF (and the `end-of-action-briefing`
> §4.1 visual legend). One deterministic renderer · one param schema · 7 layout models.
> Renderer: `bin/scorecard.py`. Render any model: `bin/scorecard.py --model N --demo`.

## Design contract (all 7 share it)

- **Deterministic** — same params → same output (no clock unless passed in).
- **Self-calculating** — the script derives *every* bar, %, count, tally, sparkline,
  burndown, and (with `--auto-git`) the git/PR facts. The AI agent supplies only atoms
  it cannot compute (verdict, per-item state/label/note/confidence, what's-left).
- **AI-parameterized** — atoms arrive as a JSON params blob (`--params FILE|-`); see
  `sample-params.json`.
- **Human-glanceable** — 5-state colour legend 🔴🟡🟠🟢🔵 (icon + word + machine-token;
  never colour-alone) + the autonomy pulse (% green = the all-green compass).
- **Portable** — stdlib only · `NO_COLOR`/`--no-color` honoured · emoji carry colour so it
  renders in any terminal AND in GitHub/markdown.

## Param schema (atoms the agent supplies)

```json
{
  "session":  {"title": "...", "id": "...", "date": "2026-06-09", "time": "22:07", "duration": "~25min"},
  "verdict":  {"state": "done|warn|blocked|wip", "label": "DONE · green · merged"},
  "autonomy": {"green": 5, "blue": 1, "orange": 0, "red": 0},
  "vitals":   [{"icon": "📦", "label": "Escopo", "pct": 100, "note": "..."}],
  "checklist":[{"state": "green|blue|orange|yellow|red", "label": "...", "note": "...", "confidence": 97}],
  "whats_left":[{"state": "done|orange|red|yellow", "text": "..."}],
  "tickets":  [{"id": "PROJ-204", "status": "closed|in-progress|review|open|blocked", "title": "..."}]
}
```
`state` aliases: `done/closed/merged→green · human→blue · hitl/review→orange · doing/wip/in-progress/open→yellow · todo/blocked→red`.
**Tickets** (Jira/Linear/GH issues) are AI-supplied atoms — the agent lists which the session
touched + their status. Surfaced in M1 (TICKETS section), M2 (tickets line), M5 (kanban lanes),
M6 (telemetry + JSON-RPC), M7 (🎫 count). Cross-provider auto-detect is out of scope (per-provider
MCP/CLI) — the agent already knows the linked tickets from the session.

## The 7 models (run `--model N --demo` to see each rendered)

| # | Name | Essence | Best for |
|---|---|---|---|
| **1** | **Cockpit** | rich left-framed card: verdict band · vitals bars · checklist · pulse · what's-left · legend | substantive sessions (the full debrief) |
| **2** | **Traffic-Light Strip** | no boxes; one colour-dot line per item + pulse + next | quick sessions · inline · chat (fast clean glance) |
| **3** | **Dashboard / KPI Tiles** | a grid of boxed KPI tiles (verdict/autonomy/checklist/open) + compact list | metric-heavy sessions (status-page feel) |
| **4** | **Burndown Ledger** | done-vs-remaining bar + numbered item ledger + remaining block | multi-task sessions with a backlog |
| **5** | **Kanban Lanes** | items bucketed by state (Done/Doing/Need-you/Todo) | when "what's left" is the headline |
| **6** | **Telemetry / Machine-First** | `key=value` + git facts + sparkline + **JSON-RPC sidecar** | agent-to-agent handoff (economical register) |
| **7** | **Executive One-Liner** | Minto TL;DR in ONE line + 2-line drilldown | 1-second "bater o olho" |

## Scoring (1–100, transparent rubric — AI-recomputable)

Weights (Σ=100): **Glance-speed 25** · **AI-calculability 20** · **Density/Coverage 20** ·
**Determinism 15** · **Clean/low-noise 12** · **Portability 8**.

| Model | Glance · 25 | AICalc · 20 | Dens/Cov · 20 | Determ · 15 | Clean · 12 | Port · 8 | **TOTAL** |
|---|---|---|---|---|---|---|---|
| 2 · Traffic-Light Strip | 23 | 18 | 16 | 14 | 12 | 8 | **91** 🥇 |
| 4 · Burndown Ledger | 19 | 18 | 18 | 15 | 10 | 8 | **88** 🥈 |
| 7 · Executive One-Liner | 25 | 17 | 12 | 14 | 12 | 8 | **88** 🥈 |
| 5 · Kanban Lanes | 20 | 17 | 16 | 13 | 10 | 8 | **84** |
| 1 · Cockpit | 18 | 15 | 20 | 14 | 9 | 7 | **83** |
| 6 · Telemetry / Machine | 12 | 20 | 17 | 15 | 11 | 8 | **83** |
| 3 · Dashboard Tiles | 21 | 16 | 15 | 13 | 10 | 6 | **81** |

## Recommendation + conclusion

**Default for `postflight`: a dual-register pair (+ optional 1-line header).**

- 🥇 **Model 2 (Traffic-Light Strip, 91)** → the **human-facing default**: fastest clean
  glance that still shows the full checklist + pulse + next. Lowest noise, no box-width risk.
- 🥈 **Model 6 (Telemetry, 83)** → the **agent-facing sidecar**: its JSON-RPC block matches
  postflight's *existing* P3 seed envelope, so an agent reading the handoff parses it directly
  (dual-register per `language-policy §7`: human strip + machine sidecar).
- 🥈 **Model 7 (One-Liner, 88)** → optional **header line** prepended to M2 for the operator's
  literal 1-second "bater o olho".

**Why not a single rich card (M1/M3):** comprehensiveness costs glance-speed + portability
(box+emoji width). M1 stays the best *full debrief* (`--model 1`) for substantive sessions, but
the per-turn default should optimise glance + parse, where **M2 + M6** win. **M4** is the best
pick when a session is backlog-heavy (burndown framing). All 7 stay available via `--model N` —
the operator picks the default; the rest are on-demand.

## Usage

```bash
bin/scorecard.py --model 2 --demo                 # human strip (recommended default)
bin/scorecard.py --model 6 --demo --auto-git      # machine sidecar + self-calc git facts
bin/scorecard.py --all  --demo                     # render every model
echo "$AGENT_JSON" | bin/scorecard.py --model 2 -  # real session (agent supplies atoms via stdin)
bin/scorecard.py --model 1 --params session.json   # full Cockpit debrief from a params file
```
`NO_COLOR=1` or `--no-color` for logs/CI.
