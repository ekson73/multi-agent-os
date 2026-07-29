# Audience → design system → the parameters `dataviz` consumes

`--audience` used to stop at lens selection: it changed how prose was written and
nothing else. Every dossier then rendered with the same density, the same chart
count, and the same palette regardless of who opened it. This file is the missing
half of that flag.

The chain is: **audience → design system → the eight parameters the `dataviz`
method consumes.** `dataviz` is design-system-agnostic by construction — it takes
those parameters and leaves the method untouched — so pointing a different system
at it is a substitution, never a fork.

## The eight parameters

Straight from `dataviz`'s own plug-in contract. A design system supplies these; the
procedure, the form heuristic, the six checks, and the mark specs do not change.

| # | Parameter | What it supplies |
|---|---|---|
| 1 | **Ramps** | the hue scales the palette draws from |
| 2 | **Categorical theme** | the fixed hue order (never cycled) |
| 3 | **Sequential hue** | the default single hue for magnitude |
| 4 | **Diverging pair** | two warm/cool poles + a neutral midpoint |
| 5 | **Status palette** | good / warning / serious / critical, distinct from categorical |
| 6 | **Texture fill** | one directional fill at 45°/135°, for CVD / print / forced-colors |
| 7 | **Surfaces** | light and dark chart-surface colors — the validator needs both |
| 8 | **Filter controls** | date-range and dimension controls |

## The map

`design_system` names an `open-design` system when the `od` daemon is available.
When it is not, the built-in fallback template applies the same *density* and
*emphasis* decisions with the reference palette — so the audience still changes the
output, just with fewer typographic options.

| Audience | Design system | Density | Charts | Emphasis |
|---|---|---|---|---|
| `exec` | `publication` | low — one idea per screen | ≤3, each answering one question | hero figure + verdict; evidence collapsed |
| `engineer` | `mission-control` | high — comfortable with detail | as many as the data earns | tables expanded, full evidence visible |
| `team` | `dashboard` | medium | ≤5 | recommendations with owner + eta foregrounded |
| `client` | `publication` | low, generous whitespace | ≤3, heavily labelled | verdict and methodology; `not_checked[]` prominent |
| `public` | `publication` | low | ≤2, self-explanatory | no jargon; every abbreviation expanded on first use |

### Density is a real parameter, not a mood

Two things are **implemented in the renderer** today (`DENSITY` in
`bin/research-dossier-render.mjs`, covered by `bin/tests/research-dossier.test.sh`):

| Effect | Behaviour |
|---|---|
| **Chart cap** | charts beyond the audience's cap are not rendered — and the omission is **disclosed** on the page ("N further charts omitted at … density"). An omission the reader cannot see is an edit, not a summary. |
| **Evidence table default** | `<details open>` for `engineer`, collapsed elsewhere. Collapsed is still reachable with JS off — `<details>` is a native element, so the evidence is never script-gated. |

`stakes: high` overrides the collapse: evidence re-expands at every audience.

**Not yet implemented:** demoting a chart under ~4 data points to a stat tile.
That one comes straight from `dataviz`'s "is it even a chart?" table — three
numbers are a KPI row, not a bar chart, and an exec dossier is exactly where that
mistake gets made. It is listed here as a gap rather than described as behaviour,
because a documented-but-inert parameter is the theater the gates exist to prevent.

## What audience does NOT change

This is the important half.

**The claims. The scorecard cells. The `not_checked[]` list. The gates.**

An exec dossier and an engineer dossier built from the same IR contain the same
evidence and pass the same two gates. Audience selects **presentation** — how much
is on screen at once, which design system's parameters are loaded, what is
collapsed by default. It never selects **content**.

The failure this rules out: quietly dropping `not_checked[]` or the contested-claim
markers for an executive audience because they "clutter the story." That is the
strongest reason to keep an audience map explicit rather than leaving it to per-render
judgement — the temptation is real, it always argues from good taste, and the person
with the least context gets the least-qualified version of the truth.

`stakes: high` overrides density downward everywhere: gaps and `not_checked[]` are
expanded regardless of audience.

## Palette resolution

1. `ir.theme.palette` if the author set it explicitly.
2. Otherwise the design system's categorical order for the audience.
3. Otherwise the `dataviz` reference palette (blue → orange → aqua).

Whichever path resolves, **gate 2 validates the result in both modes** before
anything renders. There is no path to output that skips it.

Two constraints inherited from `dataviz` and worth restating because they bite here:

- **Three slots for all-pairs forms.** The reference palette's first three slots
  validate under `--pairs all` (scatter, bubble, choropleth, small multiples). The
  fourth puts yellow next to orange, which fails the all-pairs floors. Past three,
  fold into "Other" or facet — never generate a ninth hue.
- **The relief rule.** Three light-mode slots sit below 3:1 against the light
  surface. That is a WARN, not a failure, and it is discharged by visible direct
  labels or a table view. The fallback template ships both, so the warning is
  answered by construction rather than dismissed.

## Refs

- Parameter contract + the non-negotiables: the bundled `dataviz` skill
  (`SKILL.md`, `references/palette.md`, `references/choosing-a-form.md`)
- Validation: `bin/research-dossier-render.mjs` gate 2 → `validate_palette.js`
- Systems: the `open-design` marketplace (~150 design systems, ~110 templates)
