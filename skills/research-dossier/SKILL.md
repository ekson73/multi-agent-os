---
name: research-dossier
version: "0.1.0"
description: |
  Turn finished research into a decision-ready visual dossier — html, md, json, and
  hand-offs to pdf/pptx/xlsx — routed through an intermediate representation that
  carries per-claim provenance, and gated by two deterministic oracles that fail the
  build: a provenance gate (every claim sourced, every chart citing its claims, no
  undeclared axis truncation, no empty not_checked) and a palette gate (the bundled
  dataviz validator, colorblind separation in both light and dark).
  Use when research already exists — a comparison, a market scan, a satisfaction or
  performance study — and it needs to become something a person can decide from.
  Does NOT perform the research.
  Triggers: "build a dashboard from this research", "turn this comparison into a
  report", "dossier from these findings", "compare x y z and visualize", "executive
  summary with charts", "decision-ready report".
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill
---

# research-dossier

Research emits prose. Renderers want data. Nothing bridged the two, so every
dashboard was hand-rolled — no provenance, and no reuse of the ~110 templates and
~150 design systems already installed.

This skill is that bridge, and it is deliberately thin. The lever is not the HTML;
it is the **IR**. Once research becomes JSON with provenance attached to each claim,
the existing renderers are reachable for free. Everything here composes; nothing here
duplicates.

## What makes this different from a report generator

Two **deterministic** gates can fail the build. Neither is a model judgement — same
input, same verdict, every time. A gate a model can talk its way past is decoration.

**Gate 1 — provenance.** Fails when the evidential chain is broken: a claim missing
`source` / `as_of` / `confidence`; a chart or recommendation citing a claim id that
does not exist; a recommendation with no owner or no eta; an empty `not_checked[]`;
or a **magnitude axis truncated without declaring it**. That last check is the point
of the whole gate — it carries the text-level faithfulness discipline into the
*visual* layer. A bar chart starting at 60 exaggerates a small difference into a
landslide whether or not anyone intended it. Declaring the truncation passes, and
the rationale is then printed on the face of the chart.

**Gate 2 — palette.** Runs the bundled `dataviz` skill's own `validate_palette.js`
over the resolved palette in **both** light and dark: lightness band, chroma floor,
CVD separation (ΔE OKLab per protan/deutan/tritan), normal-vision floor, surface
contrast. Colour is not reimplemented here — `dataviz` owns it, we cite it.

### What the gates check — and what they do not

An independent red-team broke the first version of gate 1, so this section is
written from evidence rather than intent. Its finding: the gate verified that
citations **resolve** and never that they **agree**. Both are now checked — a chart
point contradicting the claim it cites, a `display` string contradicting its own
`value`, stacked parts that miss their cited total, a verdict that is not the argmax
of its declared weights, a blank scorecard cell whose evidence exists but went
unused, evidence years staler than the dossier: all fail the build.

Two things remain **outside** deterministic reach, and are stated here rather than
implied away:

- **Summary vs. claims.** Prose can contradict the evidence beneath it. A numeral in
  the summary that appears in no claim raises a warning; a purely qualitative
  inversion ("the pilot succeeded") does not.
- **A recommendation citing the claims that refute it.** Citations are checked for
  existence and agreement-on-value, not for whether they *support* the sentence.

Both are semantic judgements. Do not read a green build as a claim that the argument
is sound — only that its numbers are consistent with its evidence. A weighting can
also decide an outcome on its own; when one criterion outweighs all others combined
the build warns, because arithmetic cannot refute a rigged weight, only disclosure can.

## Use it / don't

**Use when** research is finished and needs to become decidable: a tool comparison,
a market scan, a satisfaction survey, a performance review, a post-mortem.

**Don't use** to *do* the research (`/deep-research`, `last30days`, `exa` do that),
for a single chart with no argument around it (`dataviz` directly), or for prose
reformatting with no evidential claims (`content-recast`).

## Flags

| Flag | Default | Meaning |
|---|---|---|
| `--corpus <path>` | — | the finished research to read |
| `--ir <path>` | — | skip extraction, render an existing IR |
| `--audience` | `team` | `exec` · `engineer` · `team` · `client` · `public` |
| `--formats` | `html,md,json` | + `pdf` · `pptx` · `xlsx` (hand-off manifests) |
| `--design-system` | `auto` | `auto` resolves from audience |
| `--stakes` | `low` | `high` tightens the gate and expands gaps |
| `--out` | `out` | output directory |
| `--strict` | off | a missing dataviz validator FAILS instead of warning |

## Requirements

| Need | Why | If absent |
|---|---|---|
| **Node ≥ 18** | the renderer and both gates | hard requirement — nothing runs |
| **`dataviz`** (bundled) | gate 2's `validate_palette.js` | loud WARN; `--strict` makes it fail |
| **`od` daemon** (optional) | `open-design` templates | falls back to `templates/dossier.html` |
| **`python3`** (optional) | test-suite IR mutations only | those blocks self-skip |

Zero npm dependencies, by design: a decision artifact whose renderer needs a
lockfile ages badly. The only third-party code involved is `dataviz`'s validator,
which ships with the CLI and is invoked, never vendored.

## The pipeline

### 1 — Extract the IR (probabilistic; this is the judgement work)

Read the corpus and write an IR against `templates/ir.schema.json`. The schema is the
contract; read it before writing one.

The part that takes discipline is **claims[]**. Each needs `id`, `text`, `source`,
`as_of`, `confidence` — and everything downstream cites those ids. A number that
appears in a chart but in no claim is unsourced by construction, which is exactly
what gate 1 catches.

Rules worth internalising while extracting:

- **`not_checked[]` is required and non-empty.** Not a formality — the blind spots
  are what make the rest credible. If the scope genuinely was exhaustive, say so
  with a reason. An empty array is a claim of omniscience and the gate rejects it.
- **Confidence is per claim**, three bands. Uniform `high` across a large corpus
  earns a warning, because a real body of evidence has softer and harder parts.
- **A recommendation needs an owner and an eta.** Without both it is a wish, and this
  format refuses to render wishes as decisions.
- **Don't fill the scorecard grid by inference.** A missing cell renders as an
  explicit gap, which is honest; a cell invented to complete the matrix renders as
  evidence, which is not. → `references/scorecard.md`
- **Contested claims stay marked.** Averaging disagreeing sources into one number is
  a lie of omission.

### 2 — Choose the form (delegate to `dataviz`)

**Invoke the `dataviz` skill.** Do not reinvent its guidance here — it is the
authority on form and colour, and it ships with this CLI.

The two things it will tell you that are easiest to get wrong: sometimes the right
form is **not a chart** (three numbers are a KPI row, not a bar chart), and colour
comes **last**, after form, marks, and interaction. Its non-negotiables apply in
full — never a dual axis; colour follows the entity and never its rank; categorical
hues in fixed order, never cycled; a ninth series folds into "Other" rather than
generating a ninth hue.

### 3 — Resolve the theme

`--audience` selects a design system and a density; the design system supplies the
eight parameters `dataviz` consumes. → `references/audience-map.md`

Audience changes **presentation only**. It never changes the claims, the scorecard,
or `not_checked[]`. An exec dossier and an engineer dossier from one IR contain the
same evidence and pass the same gates.

### 4 — Render (deterministic; the gates run here)

```bash
node bin/research-dossier-render.mjs --ir <path> --formats html,md,json --out out
```

Exit `0` renders, `1` means a gate failed and nothing was written, `2` is usage or
I/O. Both gates run before any file is created — a failed dossier produces no
output at all, rather than a plausible-looking one.

`pdf`, `pptx`, and `xlsx` emit **hand-off manifests** rather than files: those
formats belong to `make-pdf` and `document-skills`, and reimplementing them here
would be exactly the duplication this skill exists to avoid.

## Composition — what this delegates

| Concern | Owner |
|---|---|
| chart form, colour, marks, palette validation | the bundled **`dataviz`** skill |
| html templates + design systems | **`open-design`** (~110 / ~150) |
| pdf | **`make-pdf`**, or print-CSS from the rendered html |
| pptx / xlsx | **`document-skills`** (fallbacks: `marp-cli`, csv) |
| prose recasting | **`content-recast`** |
| the research itself | `/deep-research`, `last30days`, `exa` |

What is genuinely new here is only the IR contract, the scorecard primitive, the two
gates, and the audience map. Everything else is routing.

## Degradation

Each of these is a tested path, not an aspiration:

- **No `od` daemon** → the built-in `templates/dossier.html` fallback.
- **No bundled `dataviz` validator** (it lives in a version-and-hash-keyed temp dir
  that moves on every CLI upgrade) → the path is discovered at runtime; when absent
  the gate degrades to a **loud WARN**, never a silent pass. `--strict` makes it a
  failure for CI. `DATAVIZ_VALIDATOR` overrides the path.
- **JavaScript off** → the dossier still renders completely. The body is written
  server-side; JS only reveals the theme toggle. An archival decision artifact that
  needs a script to show its evidence is not archival.

## The output

Single file, opens over `file://`, no network. Inline SVG charts — nothing to bundle
and no canvas to hide from a screen reader. Every chart carries `role="img"`, an
`aria-label` describing the actual values, and a real `<table>` of the same numbers
(per `dataviz`, that table *is* the accessible rendering, not a courtesy). Dark mode
is selected rather than flipped: its own validated steps under both the OS query and
the `data-theme` toggle, toggle winning either way. `@media print` and
`prefers-reduced-motion` present. Citations are anchors into the evidence table.

## Verify

```bash
node bin/research-dossier-render.mjs --ir skills/research-dossier/examples/ir-valid.json --gates-only   # 0
for f in missing-source truncated-axis dangling-refs bad-palette wish-not-decision; do
  node bin/research-dossier-render.mjs --ir "skills/research-dossier/examples/ir-$f.json" --gates-only >/dev/null 2>&1
  echo "$f -> $?"   # each must be 1
done
DATAVIZ_VALIDATOR=/nonexistent node bin/research-dossier-render.mjs --ir skills/research-dossier/examples/ir-valid.json --gates-only 2>&1 | grep WARN
```

Capture exit codes directly. A pipe returns the exit of the *last* command in it, so
`cmd | grep` silently reports the grep's status and a failing build reads as green.

## Anti-patterns

- **Rendering before gating.** The gates exist to stop output, not to annotate it.
- **Filling `not_checked[]` with boilerplate** to satisfy the gate. It is load-bearing.
- **Truncating an axis and declaring it reflexively.** The declaration is a cost, not
  a bypass — if there is no real rationale, don't truncate.
- **Copying `dataviz` guidance into this skill.** Cite it; it ships with the CLI and
  it will be updated without us.
- **Adding a format renderer** instead of a hand-off manifest.
- **Softening a dossier for an executive audience** by dropping gaps or contested
  markers. Audience changes density, never evidence.
- **Inventing scorecard cells** so the grid looks complete.

## Files

| Path | What |
|---|---|
| `templates/ir.schema.json` | the IR contract |
| `templates/dossier.html` | fallback template (server-rendered shell) |
| `references/scorecard.md` | the comparison primitive's discipline |
| `references/audience-map.md` | audience → design system → the 8 dataviz parameters |
| `examples/ir-valid.json` | working fixture (dogfood: the chart-library comparison) |
| `examples/ir-*.json` (5) | negative fixtures — each must fail the gate |
| `bin/research-dossier-render.mjs` | renderer + both gates |
