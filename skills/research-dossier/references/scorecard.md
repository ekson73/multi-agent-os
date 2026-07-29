# The scorecard — comparison with evidence per cell

The shape lives in `templates/ir.schema.json` (`$defs.scorecard`). This file is the
discipline: how to build one that survives a reader who disagrees with its verdict.

A scorecard is **N options × M criteria**, where every cell carries its own value,
evidence, confidence and date. That per-cell provenance is the whole point. A
comparison table where the numbers float free of their sources is a conclusion
wearing the costume of an analysis.

## The unit is the cell, not the row

Most comparison tables are authored row-by-row — "let me describe tool A" — which
produces cells written to be consistent with each other rather than with the evidence.
Author **cell-by-cell instead**: pick a criterion, gather what each option actually
measured on it, and let the row be whatever falls out.

Each cell needs five things (all required by the schema):

| Field | Why it's mandatory |
|---|---|
| `option` + `criterion` | the coordinate |
| `value` | number, string, or boolean — whatever the evidence supports |
| `source_claims` | resolves to real `claims[]` ids; the gate fails on a dangling one |
| `confidence` | `high` / `medium` / `low` — how much you'd bet on THIS cell |

`display` is optional and worth using whenever the raw value reads badly (`208` →
`"208 KB"`). `as_of` per cell matters when the options were measured at different
times — a bundle size from 2024 next to one from 2026 is not a comparison.

## Sparse is honest; complete is often fabricated

The schema does not require a cell for every (option, criterion) pair, and you should
not force one. A missing cell renders as an explicit gap. A cell invented to fill the
grid renders as evidence.

The pressure to complete the matrix is real and worth naming: a table with holes
*looks* like sloppy work, so authors fill them by inference, and inference in a cell
is indistinguishable from measurement once it's in the grid. Leave the hole. If the
hole matters, it belongs in `not_checked[]` with a reason.

## Weights are declared or they are smuggled

`criteria[].weight` is optional; omitted means equal. Whichever you choose, the reader
sees it.

This is the load-bearing rule of the whole primitive. An unweighted scorecard where
one criterion has eight sub-criteria and another has one is weighted — just
invisibly, by row count. If bundle size matters three times as much as star count for
this decision, say `weight: 3`, and let someone argue with the 3 instead of trying to
reverse-engineer it from the verdict.

**Set weights before filling cells.** Weighting after you've seen the numbers is how a
scorecard gets tuned until it agrees with the conclusion you already had.

## Direction, so you don't pre-invert

`direction` (`higher-better` / `lower-better` / `neutral`) lives on the criterion and
on `claim.metric`. Declare it and store the raw number. Do not helpfully flip a
lower-is-better metric so the aggregation works — the raw value is what the source
said, and a reader checking your work needs to find that number, not its complement.

`neutral` is for criteria where more is not better in any direction (license type,
rendering technology) — these are compared, not ranked.

## The verdict states itself

`verdict.winner` + `rationale` + `runner_up` + `rejected_because`.

Naming the runner-up and *why it lost* is what distinguishes a decision from an
endorsement. It's also the field that ages best: six months later, when the winner
disappoints, the runner-up entry is the first thing anyone will want.

If the scorecard does not support a clean winner, say that in `rationale` rather than
manufacturing one. "Two options are within noise on the criteria that matter; the
tiebreaker is outside this comparison" is a legitimate verdict.

## Rendering

The renderer emits a scorecard as a **table plus, optionally, a heatmap**. Both, not
either — per the `dataviz` form guidance, more than ~7 classes that all carry meaning
belong in a table, and a comparison grid is exactly that case.

Cell **confidence is encoded separately from value** — never by fading the value's
color. Muting a low-confidence number makes it look like a small number. Use the
confidence column, a marker, or a second heatmap layer.

Color follows the **entity**, not the rank (a `dataviz` non-negotiable). If a filter
drops an option, the survivors keep their colors.

## Anti-patterns

- **Filling the grid by inference** — the failure this format is built against.
- **Weighting after seeing the numbers** — tuning to a predetermined answer.
- **Pre-inverting `lower-better` values** — destroys the reader's ability to verify.
- **Confidence-as-opacity** — reads as magnitude, not certainty.
- **A verdict with no runner-up** — an endorsement, not a decision.
- **Uniform `high` confidence across every cell** — near-certainly unexamined; the
  provenance gate warns on it, because a real comparison has softer and harder cells.
- **Options that aren't comparable** — three libraries and a managed service on one
  grid produces cells that don't mean the same thing across a row.

## Worked shape

```jsonc
{
  "options": ["chartjs", "echarts", "frappe"],
  "criteria": [
    {"id": "size",  "label": "Bundle (raw)", "unit": "KB", "direction": "lower-better", "weight": 3},
    {"id": "a11y",  "label": "Native a11y",  "direction": "higher-better", "weight": 2},
    {"id": "print", "label": "Print/export", "direction": "higher-better"}
  ],
  "cells": [
    {
      "option": "chartjs", "criterion": "size", "value": 208, "display": "208 KB",
      "source_claims": ["chartjs-bundle-size"], "confidence": "high", "as_of": "2026-07-29"
    },
    {
      "option": "chartjs", "criterion": "a11y", "value": false, "display": "none (docs-confirmed)",
      "source_claims": ["chartjs-no-native-a11y"], "confidence": "high"
    }
    // 'print' for chartjs deliberately absent — not measured; see not_checked[]
  ],
  "verdict": {
    "winner": "chartjs",
    "rationale": "Smallest that still covers every required form; the a11y hole is closed by the mandatory table view.",
    "runner_up": "echarts",
    "rejected_because": "Generated ARIA descriptions are better, but the bundle cost is not justified when the table view already delivers accessibility."
  }
}
```

Note what that fragment does: it leaves a cell out rather than guessing, it stores
`208` with `lower-better` rather than inverting it, it says why the runner-up lost,
and the verdict's rationale is checkable against the cells above it.

## Refs

- Shape: `templates/ir.schema.json` `$defs.scorecard`
- Form/color authority: the bundled `dataviz` skill —
  `references/choosing-a-form.md` (table vs chart), `references/color-formula.md`
- Gate: `bin/research-dossier-render.mjs` (provenance) — dangling `source_claims`,
  weight/direction sanity, uniform-confidence warning
