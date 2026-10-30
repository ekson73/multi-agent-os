---
name: tutorial-forge
description: 'Forge a complete, multi-chapter pedagogical tutorial (analogies-first, layperson-friendly, with assessment) from any topic — outputs chapter specs, RACI plan, and pedagogical templates. Use when the user wants a structured, professional-quality tutorial or training course from scratch, expanding a syllabus, designing learning outcomes per chapter, or producing deliverables (root notebook, sub-chapter notebooks, assessment items). Triggers: tutorial, treinamento, curso para leigos, passo a passo, ensinar X do básico ao avançado, create a course.'
version: "0.1.0"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebSearch, Task
---

# Tutorial Forge

A reusable pipeline for forging a complete, multi-chapter tutorial targeted at **laypeople** (zero-technical-audience learners) progressing from basics to advanced. Reusable across any subject; not tied to a specific domain.

## What this skill produces

When invoked, this skill orchestrates an **editorial enterprise** (8 roles) and outputs:

1. **Architecture document** — RACI, workflow gates, artifact strategy
2. **Chapter map** — pedagogical spiral, learning outcomes, prerequisites, analogies
3. **Pedagogical template** — canonical 10-section structure every chapter must follow
4. **DoR / DoD** per chapter
5. **Per-chapter deliverable plan** — notebook specs, source-curation prompts, artifact specs

The downstream skills (source-curator, notebooklm-artifact-orchestrator) consume these outputs. The skill itself does NOT create notebooks — it produces the spec.

## Phase 0 — Inputs (clarify with user or infer)

Required parameters (ask if not provided):

- `topic` — subject of the tutorial (string, e.g. "AI for laypeople")
- `audience` — target learner (default: "curious layperson with no technical background")
- `language` — BCP-47 (default: `pt-BR`)
- `chapters` — number or list of chapter titles (default: 8)
- `depth` — `essential | complete | immersion` (default: `complete`)
- `output_target` — `notebooklm | markdown | html | mixed` (default: `notebooklm`)
- `project_root` — where to write deliverables (default: `./.tutorial-<slug>/`)

If the user provides a single-line intent ("tutorial X for leigos"), infer defaults and proceed; confirm only the major axes (scope, language) when ambiguity is high.

## Phase 1 — Enterprise architecture

Mirror a **professional training-publisher** org. Produce `raci/00-arquitetura-organizacional.md` containing:

1. **RACI table** for 8 roles: Director · Curator · Senior Researcher · Critical Analyst · Writer-Tutor · Multimedia Producer · Pedagogical Reviewer · QA/Release Manager
2. **Workflow gates** (≥5) with explicit entry/exit criteria
3. **Pedagogical template** (the canonical 10-section structure)
4. **Artifact strategy** with explicit format/length/layout/title/duration/prompt for each artifact type
5. **DoR / DoD** per chapter
6. **Tech stack** — which tools (NotebookLM CLI? Markdown? etc.)

## Phase 2 — Chapter map (pedagogical spiral)

Produce `raci/01-mapa-capitulos.md` with:

- **Spiral/concentric structure** — each chapter returns to prior concepts, deepening
- **Per-chapter spec**:
  - guiding question
  - 5-8 sub-topics
  - prerequisites (chapter IDs)
  - central analogy (mandatory, from the layperson's daily life)
  - learning outcomes (Bloom's: remember → understand → apply)
- **Recommended reading paths** (3 journeys: essential / complete / immersion)

## Phase 3 — Source-curation brief (handoff to source-curator)

For each chapter, produce a `capitulos/cap-N-brief.md`:

- ≥5 candidate source topics
- 3-5 mandatory authoritative sources (official docs, papers, top-vendor pages)
- Specific keywords for `web_search` and `last30days` queries
- Banned-source classes (e.g. "no YouTube transcripts", "no viral PR")
- Pre-curation: 3-5 existing assets (e.g. existing notebooks) that should be re-used as primary sources

## Phase 4 — Artifact brief (handoff to notebooklm-artifact-orchestrator)

For each chapter, produce a `capitulos/cap-N-artifacts.md` table with:

| artifact | format | length | style | title | focus_prompt | rationale |
|---|---|---|---|---|---|---|

Mandatory artifact set (default for each chapter):

- audio (deep_dive, long) — podcast-style with two voices
- slide_deck (detailed_deck, default) — 1 slide per step + analogy slide
- video (explainer, whiteboard) — visual summary
- mind_map — hierarchical with branches per major section
- infographic (landscape, instructional, detailed) — 1-page recap
- quiz (10-15 questions, medium difficulty) — Bloom distribution 40/40/20

## Phase 5 — Writer brief (handoff to writer-tutor subagent)

Per chapter: provide the chapter spec, the curated sources (passed as `notebook_id + source_ids`), the pedagogical template, and the central analogy. Subagent returns a chapter text in canonical 10-section format.

## Phase 6 — QA & release

- All chapters must satisfy DoD
- Index/cross-links between notebooks verified
- Final `relatorios/00-release-report.md` with: list of artifacts (notebook_id + URLs), file map, navigation guide

## Quality bar (Definition of Done for the whole tutorial)

- [ ] Architecture document complete (8 roles, ≥5 gates, template, artifact strategy)
- [ ] Chapter map with spiral, prerequisites, analogies, learning outcomes
- [ ] Every chapter has source-curation brief with ≥5 sources evaluated A/B/C/D
- [ ] Every chapter has artifact brief with all 6 artifacts specified
- [ ] Every chapter text follows the pedagogical 10-section template
- [ ] Glossary per chapter (5-10 terms)
- [ ] Bridge paragraph connecting each chapter to the next
- [ ] Final release report with all URLs and navigation

## Reusability (parametric, vendor-neutral)

This skill does NOT hardcode:

- A specific subject (works for AI, biology, finance, cooking, anything)
- A specific language (locale is a parameter)
- A specific output target (NotebookLM is the default but markdown-only or HTML-only are valid)
- A specific chapter count (8 is default; any 3-20 works)

To use for a different topic, change only Phase 0 inputs and Phase 1's tech stack; everything else is mechanical.

## When NOT to use this skill

- Single short article or blog post (use content-recast or a simple writing skill)
- Pure research without pedagogical goal (use research)
- One-shot NotebookLM notebook (use notebooklm + notebooklm-triage-pipeline)
- Code-only tutorial (use a code-doc generator, not this)

## Examples of invocation

```
> tutorial-forge: topic="blockchain for laypeople", language=pt-BR, chapters=6
> tutorial-forge: topic="personal finance from zero", audience="young adult", output_target=markdown
> tutorial-forge: topic="agentic AI for product managers", depth=immersion
```
