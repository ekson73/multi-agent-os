# Dogfood — the fixture is real research, not a synthetic sample

`ir-valid.json` is not invented demo data. It is the chart-library comparison this
skill's own recon produced while deciding what the fallback template should embed
— dist bytes read off each library's distributed build, accessibility read off each
vendor's published documentation, on 2026-07-29.

That matters for one reason: **a fixture written to make the gates pass proves
nothing.** This one was written to answer a real question, and the gates were built
afterward. If the two ever disagree, the research is right and the gate is wrong.

## The test the dogfood has to survive

> Run the artifact over the corpus and check that the resulting dossier reproduces
> the same decision the recon reached.

It does. Verified 2026-07-29:

| Check | Result |
|---|---|
| Decision preserved | Chart.js — the recon's pick, unchanged |
| Runner-up named + why it lost | Apache ECharts, "~5x the bytes for a benefit the table view already delivers" |
| Every chart datapoint traceable to a claim id | 0 untraceable |
| Magnitude axis honest | `y_min: 0`, not truncated |
| Missing scorecard cells | render `— not measured`, never as a zero |
| Renders with JavaScript off | verdict, scorecard, chart values, data table, evidence, `not_checked[]` all present |
| Remote subresources | 0 (source citation URLs remain — those are provenance, not dependencies) |

Reproduce:

```bash
node bin/research-dossier-render.mjs --ir skills/research-dossier/examples/ir-valid.json \
  --formats html,md,json --out out
echo $?    # 0 — capture directly; a pipe would report the pipe's last command
```

## What the dogfood found

Two things worth recording, because a dogfood that finds nothing usually means
nobody looked.

1. **Claim text containing a literal `<table>` renders as a raw tag in the markdown
   output.** The HTML path escapes it correctly (`&lt;table&gt;`, verified — and
   verified *not* double-escaped), so this is a fidelity nit on one output format,
   not an injection surface. Left unfixed deliberately: markdown is not an execution
   sink, and blanket-escaping prose would mangle legitimate text for a cosmetic gain.

2. **The scorecard is deliberately sparse.** Four of nine cells are unmeasured, and
   the grid says so. Filling them would have made the comparison *look* more
   complete and *be* less true — which is the exact failure `references/scorecard.md`
   exists to prevent.

## What this fixture is NOT

It is three libraries, not an exhaustive survey, and the decision is cheap to
reverse. Its own `not_checked[]` says so. It is a working example of the discipline,
not a claim about the charting ecosystem.
