# Geo-Snippet — End-of-Session Recap Grammar (SSOT)

> **Version**: 1.0.0
> **Scope**: AAIF cross-vendor. A compact, glance-and-know "geo-localization" status line for agent sessions.
> **Consumer**: `skills/postflight` (P2 DEBRIEF emits it; P3 seed carries it) · `bin/spawn-continuation.sh` (D1 → session `--name`, owns `#seq`).
> **Renderer**: `bin/geo-snippet.sh`.
> **Cross-link slug**: `geo-snippet`

## Purpose — "geo-localization"

One glance answers: *which session am I in · what status · which anchor (ticket/PR/branch) · what work · is it blocked · does it need a human, and what kind?*

Master principle: **clarity > density** — *what is not seen is not remembered; what is computed and seen is remembered, by humans **and** agents.* A memory ramp for amnesic agents + a radar for the human operator. Keep it lean (KIS/YAGNI/DRY/SSOT): if it clutters, it loses its purpose.

## The grammar (the model)

```
<status> · <anchor> · <slug> [· #<seq>] [· <enrich>]
```

Separator is the middle dot `·`. Optional fields (`[...]`) collapse their token **and** their separator when absent — never leave a dangling `·`.

### Fields

| Field | What | Source tier |
|---|---|---|
| **status** | aggregate state of the **primary** goal — 4 glyphs (see below) | B (self-report) |
| **anchor** | the single most salient locator — pick exactly one | A (computed) |
| **slug** | kebab primary-goal, length-capped (≤24 chars) | B |
| **#seq** | continuation-chain position; **omit when not a chain** | A (`spawn-continuation` injects) |
| **enrich** | 0..1 trailing detail, auto-derived from status | A or B (per row) |

### status — base-3 + need-HITL (4 glyphs, aggregate projection)

| Glyph | Meaning |
|---|---|
| 🔴 | blocked |
| 🟡 | active |
| 🟠 | need-HITL (needs a human decision/authorization) |
| 🟢 | done |

This is the **aggregate projection** of the session's primary goal — deliberately ≤4 colors so it is triable pre-attentively (one glyph, instant read). It is distinct from the **per-item 5-state visual legend** (which adds 🔵 human-done) used inside checklists/N-trees: human-done + any `%`/autonomy telemetry belong in `enrich`/`pulse`, **never** in the aggregate `status` glyph. 🟠 ("needs you") is the #1 signal a geo-snippet must surface.

### anchor — salience, pick ONE (DRY)

`ticket › PR › branch › task` — the most specific available locator wins. They are **alternatives, not additive**: showing two anchors is pure clutter. (`task` is used for per-item lines in D3, not for the session line.)

### #seq — chain position, omit-when-undetected

- Continuation (a parent session spawned this one): `#<parent+1>`.
- New chain-root (a fresh goal started by `postflight`): `#1`.
- Not a tracked chain (manual / standalone): **omit** the token + its separator — never guess. The presence of `#seq` *is* the signal "this is a tracked continuity chain."

`#seq` is owned by `bin/spawn-continuation.sh` (the continuation chain). A renderer never invents an ordinal.

### enrich — auto-derived from status (removes decision-fatigue)

| status | enrich default | why |
|---|---|---|
| 🔴 blocked | `⛔<blocker>` | why it stalled |
| 🟠 need-HITL | `⛔<blocker>` ‖ `⏭<next>` | what kind of attention |
| 🟡 active | `↑N↓M` (compass) ‖ `n/m🟢` (pulse) | position / progress |
| 🟢 done | `⏭<next>` ‖ ∅ | what's left, or nothing |
| override (use-case) | `⚠R1` (default-branch + deploy-on-push) · `wt:x·peers:N` (multi-worktree) | when the scenario demands |

There is no "which enrich?" decision — status picks it. The trailing slot is extensible per use-case (`wt`+`peers` · deploy-risk · age) but stays opt-in.

## Anti-theater — metric tiers (0 theater)

Every field is classified so the renderer never fabricates:

- **Tier A — computed deterministically** (git / gh / fs / peer-detect): anchor, branch, PR, project, worktree, compass `↑N↓M`, peers, `#seq`, risk `⚠R1`. The renderer computes these.
- **Tier B — honest self-report** (the agent is the authority on its own state): status, slug, blocker, next, pulse. Passed in by the agent; never inflated.
- **Tier C — theater** (fabricated): **eliminated**. (Removed in design: invented `#seq` ordinals → chain-or-omit; a vacuous compass `•here` → real git-position `↑N↓M`.)

| Metric | Tier · source | Relevance |
|---|---|---|
| status 🔴🟡🟠🟢 | B · self-report | HIGH (core "needs attention?") |
| slug | B · self-report / branch | HIGH ("what work") |
| ticket | A* · parse branch/commit (else omit) | HIGH (1 anchor) |
| PR#N | A · `gh pr list --head <b>` | HIGH (1 anchor) |
| branch | A · `git rev-parse --abbrev-ref HEAD` | HIGH (1 anchor) |
| project | A · `basename $(git rev-parse --show-toplevel)` | MED (redundant w/ branch) |
| worktree | A · `git worktree list` | MED (multi-wt only) |
| #seq | A (`spawn-continuation` injects) / omit | MED |
| compass ↑N↓M | A · `git rev-list --left-right --count <base>...HEAD` | MED (distance from base) |
| pulse n/m🟢 | B · progress (never inflated) | MED (telemetry — clutter in the name) |
| blocker ⛔ | B · observed state | HIGH-when-🟠 |
| next ⏭ | B · plan | MED |
| peers:N | A · peer-session-detect | LOW (niche, multi-session) |
| risk ⚠R1 | A · default-branch + deploy-on-push probe | HIGH-when-on-default-branch |

## The 4 densities (one grammar, progressive disclosure)

Same grammar, same field semantics, four densities. Density goes in the tree, not in the name.

**D1 `name`** — minimal · primary goal only · glance-and-know:
```
🟡 · PROJ-142 · payment-retry-logic
```

**D2 `status`** — N0 · one rich line · the whole session:
```
🟡 acme-api:main · payment-retry-logic · ↑5↓0 · 3/4🟢 · peers:0
```

**D3 `ntree`** — N lines · one status-line per item · **main goal pinned at top ("never forget")** · goals[primary/secondary/auxiliary] + tasks + pendings:
```
🟡 PROJ-142 · payment-retry-logic · #4 · ↑5↓0          ← main goal (always first)
├─ 🟢 retry-backoff ............. merged PR#88
├─ 🟠 idempotency-key .......... ⛔ needs-operator (key format)
├─ 🔴 dlq-replay ............... blocked-by upstream
└─ 🟡 metrics-wiring ........... in-progress
```

**D4 `conv`** — optional · one line · the conventions/terms in play (visibility → memory):
```
conv: base-3+🟠 · anchor=ticket›PR›branch›task · #seq=chain/omit · enrich-auto · Tier A/B/C
```

## 7 use-cases (recap — visibility → memory)

1. **Handoff before `/clear`** — D2 + D3.
2. **Amnesic agent re-hydrates** — D3 with the main goal pinned at top.
3. **Continuation seed** — `postflight` seeds the next session + `#seq` (D1 + D3).
4. **Cross-session triage** "which one needs me (🟠/🔴)?" — D1.
5. **Main-goal anchoring** in a long session — D3 top line.
6. **Pendings audit** — D3.
7. **Convention surfacing** — D4.

## Renderer contract (`bin/geo-snippet.sh`)

```
geo-snippet --density name|status|ntree|conv [--status GLYPH] [--slug SLUG]
            [--seq N] [--enrich STR] [--pulse n/m] [--base REF]
```

- **Tier-A fields are computed by the tool** (anchor, project, compass, peers, `⚠R1`). **Tier-B fields are passed in** (`--status`, `--slug`, `--seq`, `--enrich`, `--pulse`) — the agent is the authority on its own state.
- **enrich placement**: D1 `name` carries enrich only when explicitly supplied (`--enrich`) — the name stays clean (clarity > density). D2/D3 surface compass / pulse / peers as their own computed fields, so the name never duplicates them. A 🔴/🟠 blocker reason is self-report (`--enrich '⛔<reason>'`).
- **D3 `ntree`**: the header line is rendered like D2; item lines are read from **stdin** (one per line: `<glyph> <slug> [· <enrich>]`) and formatted into the tree — the objectives tree is agent-supplied (Tier B), never auto-generated.
- **Always read-only, capability-detected, graceful-degrade, exit 0** (no `gh` → branch anchor; no peer-detect lib → omit `peers`; detached HEAD / no upstream → omit compass). Never blocks a session end.

## Composition / reuse (Strata — don't rebuild)

- `skills/postflight` **P2 DEBRIEF** already produces the recap (composes `morning-briefing` + N-tree + Eisenhower) — it emits D2 + D3 + D4 via this renderer; it does not reinvent the recap.
- `bin/spawn-continuation.sh` owns naming + the `#seq` chain — D1 feeds `--name`.
- `plugin-scripts/governance/lib/peer-session-detect.sh` (`psd_peer_sessions <repo>`) — the `peers:N` field.
- `skills/morning-briefing` — the 7-section state DEBRIEF already composes.
- `skills/status-map` — **prior-art**, a different (ASCII-box PULSE/COMPACT) shape; left as-is, not merged.

## License

MIT (matches the multi-agent-os repo `LICENSE`).
