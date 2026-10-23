---
name: notebooklm-artifact-orchestrator
description: 'Plan, generate, and verify all 6 studio artifacts (audio, slides, video, mind_map, infographic, quiz) for a NotebookLM notebook — with explicit format/length/style/prompt choices per artifact, async-status polling, and deliverable handoff. Use when generating the full artifact set for a notebook, designing the artifact strategy for a tutorial chapter, or operationalizing the post-source phase of a NotebookLM pipeline. Triggers: generate artifacts, create podcast + slides + video, studio artifacts, notebooklm artifacts, gerar audio e slides.'
version: "0.1.0"
allowed-tools: Read, Write, Edit, Bash, Grep, Glob
---

# NotebookLM Artifact Orchestrator

The post-source phase of any NotebookLM pipeline. Given a notebook with curated sources, plans and generates the **full artifact set** (default 6 types), verifies async completion, and hands off the URLs to the caller.

## Why this skill exists

Generating artifacts naively wastes attempts on bad format choices (e.g. `slides` instead of `slide_deck`), burns time on `unknown` status, and forgets to verify `completed`. This skill:

1. Computes the **right** format/length/style for each artifact (vs guessing)
2. Submits all artifacts as a batch (with explicit per-artifact prompt when needed)
3. Polls `studio_status` and never claims completion on `unknown`
4. Persists a deliverable manifest with URLs

## Phase 0 — Inputs

Required:

- `notebook_id` — the notebook with curated sources already added
- `artifact_spec` — list of artifacts to generate. Default = full set of 6 (see below)

Optional:

- `language` — BCP-47 (default: `pt-BR`)
- `focus_prompt` — global focus for all artifacts (e.g. "leigo com curiosidade técnica")
- `per_artifact_focus` — dict of `{artifact_type: focus_prompt}` to override per artifact

## Phase 1 — Artifact planning

Default artifact set with **computed** choices (not defaults; reasoned):

| Artifact | artifact_type | format | length | style | orientation | detail | rational |
|---|---|---|---|---|---|---|---|
| Audio overview | `audio` | `deep_dive` | `long` | (n/a) | (n/a) | (n/a) | Long-form conversational podcast; pairs didactic + analogy for laypeople |
| Slide deck | `slide_deck` | `detailed_deck` | `default` | (n/a) | (n/a) | (n/a) | 1 slide per step; default length fits 15-20 slides; educational layout |
| Video summary | `video` | `explainer` | (n/a) | `whiteboard` | (n/a) | (n/a) | Whiteboard evokes classroom; 5-7 min visual recap |
| Mind map | `mind_map` | (n/a) | (n/a) | (n/a) | (n/a) | (n/a) | Hierarchical with branches per major section |
| Infographic | `infographic` | (n/a) | (n/a) | `instructional` | `landscape` | `detailed` | 1-page recap with central analogy + timeline + 5 terms |
| Quiz | `quiz` | (n/a) | (n/a) | (n/a) | (n/a) | (n/a) | 10-15 questions, difficulty `medium`; Bloom 40/40/20 |

**Adjustments by audience:**

- For **expert audience**: `audio` → `critique` or `debate`; `infographic` → `concise`; `quiz` → `hard`
- For **lay audience** (default): keep as above; emphasize `focus_prompt` to bias toward analogies
- For **quick reference**: `audio` → `brief`; `slide_deck` → `presenter_slides` + `short`; `quiz` → 5 questions

## Phase 2 — Title & prompt design

For each artifact, compute:

- `title` — should be **chapter-specific**, not generic. Use: `"<ChapterN>: <concept> — <hook for audience>"`
- `focus_prompt` — per-artifact bias:
  - `audio`: emphasize the central analogy + 1 surprising counter-intuitive fact
  - `slide_deck`: explicit "1 slide per step of the 10-section template"
  - `video`: emphasize visual analogy (since whiteboard style)
  - `mind_map`: emphasize hierarchical structure
  - `infographic`: emphasize 1-page digestibility
  - `quiz`: emphasize Bloom distribution

## Phase 3 — Batch submit

```bash
# Per artifact (CLI is the contract — these are the real subcommands):
nlm audio create <nb-id> --format deep_dive --length long --focus "<focus_prompt>" --language pt-BR --confirm
nlm slides create <nb-id> --format detailed_deck --length default --focus "..." --language pt-BR --confirm
nlm video create <nb-id> --format explainer --style whiteboard --focus "..." --language pt-BR --confirm
nlm mindmap create <nb-id> --title "<chapter-specific title>" --confirm
nlm infographic create <nb-id> --orientation landscape --detail detailed --style instructional --focus "..." --language pt-BR --confirm
nlm quiz create <nb-id> --count 12 --difficulty 3 --focus "Bloom 40/40/20: remember/understand/apply" --confirm
```

Capture each `artifact_id` returned.

**Rate-limit guard:** Wait 5s between submissions.

**Failure handling:** If a submission fails, log the error and continue with the remaining artifacts (don't block the batch).

## Phase 4 — Async verification

Artifacts are async. Status values (per `nlm studio status --full`):

- `in_progress` — actively generating
- `completed` — has URL (audio_url / video_url / slide deck PDF or PPTX / infographic PNG / mind map JSON / quiz JSON)
- `failed` — won't complete; mark and skip

```bash
# Poll until all artifacts complete (max 10 min per artifact)
nlm studio status <nb-id>
nlm studio status <nb-id> --full   # shows custom_instructions too
```

Persist: `artifact-status.json` with `{artifact_id, type, status, url, focus_prompt, submitted_at, completed_at}`.

## Phase 5 — Deliverable handoff

When ALL artifacts have `completed` (or are marked `failed` with rationale), produce:

- `deliverable-manifest.md` — table of artifacts with title, type, status, URL, focus_prompt
- `deliverable-manifest.json` — machine-readable version

Download each artifact using the **real subcommand** from `nlm download`:

| Artifact | Subcommand | Default ext | Notes |
|---|---|---|---|
| Audio | `nlm download audio <nb-id> --output <path>.m4a` | **`.m4a`** (AAC in MP4) | NotebookLM audio is AAC/M4A; `.mp3` is NOT what the service produces. If the consumer requires MP3 (e.g. legacy player), transcode explicitly: `ffmpeg -i in.m4a -codec:a libmp3lame -qscale:a 2 out.mp3` |
| Video | `nlm download video <nb-id> --output <path>.mp4` | `.mp4` | |
| Slide deck | `nlm download slide-deck <nb-id> --output <path>.pdf` | `.pdf` | Or `--format pptx` for `.pptx` |
| Quiz | `nlm download quiz <nb-id> --output <path>.json --format json` | `.json` | |
| Infographic | `nlm download infographic <nb-id> --output <path>.png` | `.png` | |
| Mind map | `nlm download mind-map <nb-id> --output <path>.json` | `.json` | Render to image separately if needed |
| Report | `nlm download report <nb-id> --output <path>.md` | `.md` | |

Bulk alternative: `nlm download all <nb-id> --output-dir <dir>` downloads every completed artifact into per-notebook subdirs (each in its real format).
## Quality bar

- [ ] All 6 artifacts (or specified subset) submitted with explicit format/length/style choices
- [ ] No artifact claimed "done" on `unknown` status
- [ ] Each `completed` artifact has a URL captured
- [ ] Each `failed` artifact has a documented reason
- [ ] Deliverable manifest persisted (md + json)
- [ ] Local copies of artifacts downloaded

## Reusability

- Works for any `notebook_id`
- `artifact_spec` is parametric — generate only audio+slides, or only the full 6
- `focus_prompt` is parametric — bias for layperson, expert, exam-prep, etc.
- `language` is parametric

## When NOT to use this skill

- Notebook has no sources yet (run `source-curator` first)
- Need only ONE artifact (call the CLI directly)
- Operator has not authorized generation (requires `--confirm` / `confirm: true`)

## Operational gotchas (verified against `nlm 0.15.3 --help` / `--ai`)

- **CLI subcommand is `nlm slides create`**. The MCP `studio_create` tool accepts `artifact_type: "slide_deck"`. Both are valid in their respective surfaces; do not mix them.
- **Audio length**: only `short | default | long`. `extra-long` is NOT valid.
- **Audio format**: only `deep_dive | brief | critique | debate`.
- **Slide format**: only `detailed_deck | presenter_slides`. Length only `short | default` (no `long`).
- **Video format**: `explainer | brief | cinematic | short`. Style: `auto_select | custom | classic | whiteboard | kawaii | anime | watercolor | retro_print | heritage | paper_craft`. Use `--style-prompt` for custom.
- **Infographic orientation**: `landscape | portrait | square`. Detail: `concise | standard | detailed`. Style: `auto_select | sketch_note | professional | bento_grid | editorial | instructional | bricks | clay | anime | kawaii | scientific`.
- **Quiz difficulty**: integer `1-5` (1=easy, 5=hard); NOT strings.
- **Bulk `source add`**: `--url` is repeatable (`nlm source add <nb> --url X --url Y`). Use `--wait` to block until source is processed.
- **All artifact commands require `--confirm` (CLI) / `confirm: true` (MCP)**. Operator's explicit instruction in conversation counts as authorization.
- **Rate-limit guards**: 2s between `source` ops, 5s between content-generation ops.
- **Async status values (from `nlm studio status` CLI)**: `in_progress | completed | failed`. The literal string `unknown` does not appear in CLI output — that term comes from the MCP server notes and means "still processing". A 10-min poll timeout does NOT convert to `failed`; record as `processing/timed_out` and re-poll. Only treat as `failed` when the service explicitly reports failure.

## Examples of invocation

```
> artifact-orchestrator: notebook_id=abc, full 6
> artifact-orchestrator: notebook_id=abc, only audio + slides
> artifact-orchestrator: notebook_id=abc, full 6, language=en, audience=expert
```
