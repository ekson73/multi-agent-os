---
name: research-dossier
description: Turn finished research into a decision-ready visual dossier (html/md/json + pdf/pptx/xlsx hand-offs), routed through an IR with per-claim provenance and gated by two deterministic oracles — a provenance gate and the bundled dataviz palette validator. Does NOT perform the research.
argument-hint: "[--corpus <path> | --ir <path>] [--audience exec|engineer|team|client|public] [--formats html,md,json,pdf,pptx,xlsx] [--stakes low|high] [--out <dir>] [--strict]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, Skill
---

# /maos:research-dossier

Thin wrapper that invokes `skills/research-dossier/SKILL.md`. The skill holds all
logic (the IR contract, the extraction discipline, the two gates, the audience map,
the anti-patterns). **This file is the command surface only.**

> **Invocation**: canonical form is `/maos:research-dossier` (`plugin.json` sets
> `command_namespace.prefix_required=true`). Bare `/research-dossier` also resolves via
> `permit_unprefixed_if_no_collision`, but prefer the prefixed form in docs and scripts.

## Usage

```
/maos:research-dossier --corpus ~/.claude/plans/tool-comparison.md
/maos:research-dossier --corpus <path> --audience exec --formats html,pdf
/maos:research-dossier --ir out/dossier.json --audience engineer     # re-render, skip extraction
/maos:research-dossier --corpus <path> --stakes high                 # tighter gate, gaps expanded
```

## What it does

`corpus → IR → (scorecard, if a comparison) → render`. The intermediate representation
is the deliverable, not the HTML: once research carries per-claim provenance, the
~110 templates and ~150 design systems already installed become reachable.

Two **deterministic** gates run before anything is written — a failed dossier
produces no output at all, rather than a plausible-looking one:

1. **Provenance** — every claim sourced and dated, every chart citing claims that
   exist, every recommendation owning an owner and an eta, `not_checked[]` non-empty,
   and no magnitude axis truncated without declaring it. That last check is what
   carries the faithfulness discipline into the visual layer.
2. **Palette** — the bundled `dataviz` skill's own `validate_palette.js` in both
   light and dark: CVD ΔE OKLab per protan/deutan/tritan, lightness band, chroma
   floor, normal-vision floor, surface contrast.

## Composes, never duplicates

Chart form and colour → the bundled **`dataviz`** skill. Templates → **`open-design`**.
pdf → **`make-pdf`**. pptx/xlsx → **`document-skills`**. Prose → **`content-recast`**.
The research itself → `/deep-research`, `last30days`, `exa`.

New here: the IR contract, the scorecard primitive, the two gates, the audience map.

## Degradation

No `od` daemon → built-in fallback template. No bundled validator (its path moves on
every CLI upgrade) → runtime discovery, then a **loud WARN**, never a silent pass;
`--strict` makes it a failure. JS off → the dossier still renders completely.

## Direct renderer

```bash
node bin/research-dossier-render.mjs --ir <path> --formats html,md,json --out out
# exit 0 rendered · 1 gate failed (nothing written) · 2 usage/IO
```

Capture the exit code directly — a pipe reports the *last* command's status, so
`cmd | grep` makes a failing build read as green.

## Related

`skills/research-dossier/SKILL.md` (logic) · the bundled `dataviz` skill (form + colour
authority) · `skills/content-recast/SKILL.md` · `skills/decompose-abstract-to-measurable/SKILL.md`
(sibling discipline: abstract criterion → measurable leaves).
