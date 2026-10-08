---
name: source-curator
description: 'Research, critically evaluate, and import sources for a NotebookLM notebook — with adversarial grading (A/B/C/D), dedup, and reliable text-source ingestion. Use when adding sources to a notebook, curating a research dump, vetting external URLs before adding to a knowledge base, or building a topic-bounded corpus for downstream artifact generation. Triggers: curate sources, import to notebook, find sources for X, vet this URL, build a notebook on Y, curadoria de fontes.'
version: "0.1.0"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, WebSearch
---

# Source Curator

A reusable pipeline for **researching, critically evaluating, and importing** sources into a NotebookLM notebook. Output: a notebook with vetted text-sources (one per theme/department) that downstream artifact-generation can consume.

## Why this skill exists

Naive `source_add --url` frequently fails ("Could not add url source" — fetch / rate-limit errors) and offers no quality control. This skill:

1. Treats external URLs as **untrusted** until vetted
2. Aggregates approved sources into **text payloads** (per theme), the only reliable `source_add` path
3. Applies an **adversarial grade** (A/B/C/D) to each candidate
4. Documents the rationale for every include/exclude decision (audit trail)

## Phase 0 — Inputs

Required:

- `notebook_id` — target NotebookLM notebook
- `topic` — what we're looking for
- `curation_brief` — output of `tutorial-forge` (preferred) or manual: 5-10 keywords, banned-source classes, mandatory-source list

Optional:

- `existing_assets` — list of pre-mapped artifacts (notebooks, files) to ingest as primary sources
- `depth` — `quick (≥3 sources) | standard (≥5) | deep (≥10)` (default: `standard`)

## Phase 1 — Research

For each keyword in `curation_brief`:

1. `web_search` with site: filter for authoritative domains (e.g. `site:arxiv.org`, `site:openai.com`, `site:anthropic.com`, `site:docs.*`)
2. Optionally invoke `last30days` skill for recency when topic is moving fast
3. Capture: URL + title + 1-line rationale

Aim for `≥ 2 * depth` candidates (over-fetch; the critic will prune).

## Phase 2 — Adversarial grading

For each candidate, score:

| Criterion | Question | Weight |
|---|---|---|
| Authority | Is the source from a primary/authoritative voice? | 30% |
| Recency | Is it current enough for the topic? | 20% |
| Coverage | Does it cover the chapter's sub-topics? | 25% |
| Bias | Is it free of obvious commercial/PR bias? | 15% |
| Accessibility | Will a layperson understand it (or is it for experts)? | 10% |

Grades:

- **A** (≥0.85) — must include
- **B** (0.70-0.84) — include if not duplicate
- **C** (0.50-0.69) — include only if a gap; otherwise skip
- **D** (<0.50) — exclude with rationale

Output: a `catalog.json` with every candidate's URL, title, grade, 1-line rationale, and decision (include/skip).

## Phase 3 — Dedup

Two passes:

1. **Exact** — same title → keep first
2. **Semantic** — same event/paper across platforms → subagent with schema; keep canonical

Track in `dedup-log.json`.

## Phase 4 — Aggregate into text payloads

For each `theme/department`, group included sources into a **complete** text payload (not just a 2-3-sentence excerpt — those strip the grounding NotebookLM needs to actually use the source in artifact generation):

```
# Theme: <name>

## Source 1: <title>
URL: <url>
Why: <1-line rationale>
Key facts (3-5 bullets): each one a complete sentence
Full text or substantive excerpt: the section(s) most relevant to the chapter — quotes, definitions, step-by-step procedures. Aim for the passage the chapter will cite verbatim. If the source is a long page, paste the section that grounds the chapter's central analogy or the most counterintuitive claim.
Date accessed: YYYY-MM-DD
Authority tier: official-docs | peer-reviewed | industry-report | blog-expert | news | forum

## Source 2: ...
```

**Payload sizing rules (verified against `nlm source add --text` limits):**

- **≤25 entries per theme payload** (matches the bulk-delete chunk cap; keep payloads parallel so a re-aggregation round stays simple).
- **Per-payload size**: aim 20-40 KB. Above ~50 KB the `nlm source add --text` call slows and can time out. Above 100 KB it is rejected; chunk into 2 payloads of the same theme.
- **If a theme would exceed 25 entries**: split into `Theme A — Part 1` and `Theme A — Part 2` payloads; the chapter briefly references both.
- **Minimum per source inside a payload**: title + URL + 1-line why + 3+ complete sentences of substantive content. Anything thinner does not give NotebookLM enough to generate from.

Add each chunked payload via `nlm source add <nb-id> --text "<payload>" --title "Theme: <name>"`. NotebookLM auto-titles, but supplying a title makes the source list navigable.

**Why text and not URL?** Per the operational playbook (`notebooklm-mcp-ops`): URL `source_add` frequently fails with "Could not add url source" (fetch / rate-limit). Text is reliable. If a URL must be preserved (citation), keep it as a line inside the text payload, not as the source type.

## Phase 5 — Add existing assets (optional)

If `existing_assets` is provided, each existing asset is **converted to a text-source** and grouped into a theme payload (it does NOT count as a separate `source_add` call). For each asset:

- For each existing notebook in the list: run `nlm notebook query <existing_nb> "<chapter-relevant question>" --conversation-id <id>` to extract a 1-page summary, then include that summary as a Source entry inside the relevant theme payload (with the original notebook title and a citation link to the existing notebook's `notebook_id`).
- For each local file: `read` the file, distill a 1-page summary (or paste the most chapter-relevant section verbatim if the file is short), include as a Source entry inside the relevant theme payload.
- For URLs in the existing_assets list: same as Phase 4 — paste the section that grounds the chapter, with the URL inside the payload.
For each asset (existing notebook summary, local file excerpt, or URL excerpt), include it as a Source entry inside the relevant theme payload — it does not become a separate `source_add` call on its own.

## Phase 6 — Verification (REAL source_ids, baseline-aware)

What `nlm 0.15.3` actually exposes (verified via `nlm source get --help` / `nlm notebook get --help`):

- `nlm source get <source_id> --json` returns source metadata (title, type, status where the API surfaces it). The CLI has **no `--status` / `--wait` / polling flag** on `source get`. Use `nlm source add --wait --wait-timeout 600` at ingestion time to block until that single source is processed; that is the CLI's READY gate.
- `nlm notebook get <notebook_id> --json` returns the notebook envelope including a `source_count`.

Per-source READY gate (do not advance past this gate while pending):

```bash
# Add a payload, capture source_id, block until it is processed
add_out=$(nlm source add <nb-id> --text "<payload>" --title "Theme: X" --wait --wait-timeout 600 --json)
source_id=$(echo "$add_out" | jq -r '.id // .source_id // empty')
[ -n "$source_id" ] || { echo "source_add returned no id; abort"; exit 1; }
```

The `--wait` flag on `nlm source add` is the **only documented CLI gate** for source readiness. Without it, an unprocessed source can sit pending while the rest of the pipeline runs and produce thin artifacts.

**Final count invariant (corrected, baseline-aware):**

```
baseline_count      = nlm notebook get <id> --json | jq .source_count   # captured BEFORE this run
final_count         = nlm notebook get <id> --json | jq .source_count   # captured AFTER all sources are READY
successful_payloads = count of source_add calls that returned a source_id AND reached terminal state

# Required:
final_count - baseline_count == successful_payloads
```

`include_count` (candidates graded A/B/C that were kept) is NOT the right invariant: many candidates are aggregated into one theme payload, so `successful_payloads` ≤ `include_count` always. The check the skill must perform is `delta == successful_payloads`, NOT `final_count == include_count`.

Failure handling:

- If `delta < successful_payloads`: at least one `source_add` failed silently; list which `source_id`s are missing from the final `source list` and re-add them.
- If `delta > successful_payloads`: another process added sources concurrently; investigate before declaring done.

Persist:

- `catalog.json` — full grading log (per-candidate: URL, title, grade, rationale, decision `include|skip`)
- `curation-report.md` — human-readable summary, decisions, theme grouping, payload sizes
- `dedup-log.json` — dedup decisions (per duplicate cluster: kept source_id, dropped URLs)
- `themes/<n>.md` — the actual text payloads added (one file per `source_add` call)
- `ingestion-manifest.json` — `{source_id, title, theme, candidate_count, payload_bytes, added_at, ready_at, source_get_response}` for every successful `source_add`. This is the audit trail the rest of the pipeline (notebooklm-artifact-orchestrator) reads.

## Quality bar

- [ ] Every candidate has a grade and a rationale in `catalog.json`
- [ ] `include_count + skip_count = candidate_count` (candidate-side invariant; this stays correct)
- [ ] Only A/B grades included; C included only with documented gap-rationale
- [ ] Every source in a payload has title + URL + 1-line why + 3+ complete sentences of substantive content
- [ ] Every `source_add` call was issued with `--wait --wait-timeout 600` AND returned a non-empty `source_id`
- [ ] `final_count - baseline_count == successful_payloads` (baseline captured BEFORE this run)
- [ ] `ingestion-manifest.json` persisted with one row per `source_id`

## Reusability

- Works with any `notebook_id` (does not assume a particular project)
- `curation_brief` is a parameter — the same skill curates AI sources, finance sources, biology sources
- `existing_assets` is optional — first-run projects skip it

## Failure modes & recovery

| Error | Cause | Recovery |
|---|---|---|
| `source_add --url` fails | Fetch / rate-limit | Convert to text-payload with URL in body |
| `source_add --text` slow | Large payload (>50KB) | Chunk into themes |
| `notebook_get` shows wrong count | Race / dedup error | Re-poll; never trust `submitted` as `added` |
| Auth cookie expired | >20min idle | `nlm login` and resume |

## When NOT to use this skill

- Need a single quick source (use `web_search` + manual read)
- Already have a clean source list (skip Phase 1-3; just do Phase 4-6)
- Bulk-import Drive docs only (use `source_add --drive` directly)
