# MAOS-Tips — Selection Inference

> How `plugin-scripts/session-tip.sh` decides **whether** to surface a tip, **which** tip,
> and **how** it renders. Mirrors `statusmap/inference.md` (data-file + inference doc pattern).
> Design SSOT: `docs/adrs/ADR-008-maos-tips-session-discoverability.md`.

## When to surface (trigger gate — ALL must hold)

| # | Gate | Rule |
|---|------|------|
| 1 | **Not opted out** | none of `MAOS_TIPS=off` · `MAOS_NO_TIPS=1` · `~/.claude/.maos-no-tips` |
| 2 | **Ready** | `jq` present AND `tips/catalog.json` exists AND is valid JSON (else silent no-op) |
| 3 | **Fresh session** | SessionStart `.source ∈ {startup, clear}` — **skip `resume` and `compact`** (context already warm ⇒ a tip there is noise) |
| 4 | **Not CI** | `CI != true` |
| 5 | **Not already tipped this session** | `.session_id != state.last_session_id` (idempotency for double-fire) |
| 6 | **Throttle (optional)** | if `MAOS_TIPS_EVERY=Nd`, at least `N` days since `state.last_shown_ts` |

Fail any gate → `exit 0`, emit nothing. The hook **never** blocks or errors the session.

## Which tip (selection = rotation + no-repeat)

```
eligible = [ every tip id ] − state.seen          # set difference (jq: [..] - $seen)
if eligible is empty:  recycle → pick tips[0], reset seen = [picked]      # corpus exhausted
else:                  pick first eligible (stable id order) → seen += [picked]
```

- **Frequency = 1 per session** (operator directive) — gate 5 guarantees at most one per `session_id`;
  gate 3 restricts to startup/clear. `MAOS_TIPS_EVERY=Nd` reduces further to ≤1 per N days.
- **No-repeat**: the seen-ledger cycles the whole corpus before repeating → variety without randomness.
- **On-demand (`--print`)** ignores gates 3–6 and the ledger (random pick, non-mutating) so `/maos:tip`
  never "burns" the session's rotation.

## Context variables

| Var | Source | Use |
|-----|--------|-----|
| `.source` | SessionStart stdin JSON | gate 3 (startup/clear vs resume/compact) |
| `.session_id` | SessionStart stdin JSON | gate 5 idempotency + written to state |
| `MAOS_TIPS` / `MAOS_NO_TIPS` / `~/.claude/.maos-no-tips` | env / file | gate 1 opt-out |
| `MAOS_TIPS_EVERY` | env (`Nd`) | gate 6 daily throttle |
| `MAOS_TIPS_LANG` | env (`pt-br`) | reserved: operator-side language opt-in (v1 catalog is en-US) |
| `CI` | env | gate 4 |
| `CLAUDE_PLUGIN_ROOT` | env | locate `tips/catalog.json` |
| `HOME` | env | seen-ledger state at `~/.claude/maos/tips-state.json` |

## Output format (1 line + leading blank line)

```
💡 MAOS Tip · <tool>: <when-to-use>. Try: /maos:<tool>  ·  more: /maos:<family-route>
```

- **stderr** = the human line above (glyph 💡, distinct from 🧭 status-map / 🛡️ conductor-scan).
- **stdout** = `{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"<router-hint>"}}`
  so the agent can proactively route the operator's *actual* work to the surfaced tool.
- `<family-route>` resolves via `families[tip.family].route` (all → `maos-concierge`; DRY — the tip
  routes to depth, it does not restate the concierge).

## Print-only announcements discipline

`--emit-announcements [N]` prints up to N tip strings as a JSON array (companyAnnouncements shape) +
paste instructions to stderr. **The plugin never writes `settings.json` / `companyAnnouncements`** —
that channel is server-side / org-managed (HUMAN_DOMAIN); the operator applies the paste. This is the
community-portable echo of the native "Message from <org>:" banner, not a replacement for it.

## Fallback strategy (degrade, never fail)

| Missing | Behavior |
|---------|----------|
| `tips/` or `catalog.json` | silent no-op (exit 0) — the plugin works without tips |
| `jq` | silent no-op |
| `HOME` unset | tips still render; state degrades to `/tmp` (no persistence) |
| `governance/lib/common.sh` | inline `json_escape` fallback + `log_audit` no-op |
| corpus exhausted | recycle (reset seen) — never runs dry |

## v2 / roadmap (YAGNI now)

`weight`/weighted-random · context-gates (min_tools, repo-signal) · `tags` · end-of-action placement ·
auto-derivation of tips from SKILL.md frontmatter · surfacing analytics · `MAOS_TIPS_LANG=pt-br` catalog.
