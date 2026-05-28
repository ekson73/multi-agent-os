---
name: transcript-corrector
description: |
  Use when you have a transcribed text (meeting transcript, voice-note transcript, call
  transcript, dictation) that may contain ASR (automatic-speech-recognition) errors —
  phonetic substitutions, typos, grammar drift, punctuation loss — and you need a
  corrected version BEFORE downstream consumers (summarizers, ticket creators,
  action-item extractors) ingest it.
  Multi-lingual pt-BR + en-US. Cross-vendor AAIF compatible.
  Founding empirical case: Loom/equivalent transcribed "Nelcael Alves Ferreira" as
  "Nilson" in a Vek daily meeting; downstream consumers propagated the wrong name
  until corrected. This skill closes that gap.
triggers:
  - corrigir transcrição
  - corrigir transcricao
  - normalizar transcrição
  - sanitizar transcrição
  - correct transcript
  - fix transcript
  - correct meeting transcript
  - apply transcript correction
  - check ASR errors
  - phonetic substitution check
  - participants whitelist check
version: 1.0.0
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
---

# transcript-corrector — Skill

> **Cross-vendor AAIF skill.** Detects + corrects ASR-class errors in transcribed text
> (phonetic substitutions, typos, grammar drift, punctuation loss). Emits corrected
> text + side-by-side diff + per-correction confidence audit. Multi-lingual pt-BR +
> en-US. Atomic + generic (Goldilocks): works on any transcribed text, not only meetings.

## Purpose (1-line)

Close the **ASR-error gap** between raw transcript and downstream consumers, so action
items, decisions, and ticket assignments never propagate phonetically-mis-recognized
proper names or systematic typos.

## When to invoke

- Loom / Otter / Tactiq / Fireflies / Whisper transcript ingested into Confluence /
  GDrive / Notion / local file — about to feed into a summarizer, ticket extractor,
  or other downstream consumer
- Daily-meeting page authored by ASR + needs review before stakeholder distribution
- Voice-note dictation needing cleanup
- Empirical signal: speaker attribution looks "off" (rare name replaced by common one)
  or operator says "isso não é o nome certo"

## When NOT to invoke

- Hand-typed text (operator wrote it; no ASR layer) — only the grammar pass would
  apply, and that's overkill
- Encrypted / PII-bearing content where corrections might leak personal data — escalate
  to operator + apply per-field redaction first
- Transcripts in languages other than pt-BR or en-US (v1.0.0 scope; extension via PDCA)

## 4-pass pipeline

### Pass 1 — Participants whitelist check (Levenshtein + Metaphone)

For every detected speaker name OR `@mention` in the transcript:

1. If the name is in `catalogs/participants-canonical.yaml` → mark verified
2. Else compute Levenshtein distance to every whitelist entry AND phonetic-code distance
   (Metaphone for en-US, Portuguese-Metaphone heuristic for pt-BR; falls back to
   `difflib.SequenceMatcher` ratio if `phonetics` lib unavailable)
3. Score = combined `(1 - levenshtein_normalized) * 0.5 + phonetic_match * 0.5`
4. If score ≥ 0.85 → HIGH confidence → auto-apply correction
5. If 0.65 ≤ score < 0.85 → MEDIUM → apply + flag in audit
6. If score < 0.65 → LOW → leave original, emit `:warning:` in audit + suggest alternatives
7. Also consult `catalogs/phonetic-substitutions.yaml` for known class-based
   substitutions (e.g., `[Nilson|Nielson|Nelson] → Nelcael` under context
   "Vek daily + Invitee mismatch")

### Pass 2 — Common-typos dictionary

Search-and-replace from `catalogs/common-typos-{pt-br|en-us}.yaml`. Each entry is a
`{wrong, correct, context?, confidence?}` tuple. Default confidence 1.0 unless
specified. Applied case-preserving (e.g., `Sala` → `Sala` not `sala`).

### Pass 3 — Grammar / punctuation

Capability-detected:
- If `LANGUAGETOOL_API` env var is set (e.g., `https://api.languagetool.org/v2` for
  community-edition OR a self-hosted instance), POST the transcript and apply
  rule-based corrections (filtered to safe categories: PUNCTUATION, TYPOGRAPHY,
  CASING; skip STYLE to avoid over-rewriting)
- Else fall back to bash + regex heuristics:
  - Capitalize first letter after sentence-ending `[.!?]`
  - Collapse double-spaces
  - Ensure terminal `.` at end of paragraphs that lack final punctuation
  - Fix common pt-BR contractions (`do(a) → do/da` left untouched; only obvious typos)

### Pass 4 — Emit

Output three artifacts:
1. **Corrected text** (markdown OR plain, by `--format`)
2. **Side-by-side diff** (unified diff or 2-column inline-comment style)
3. **Audit JSON** at `pdca/run-<timestamp>.json` capturing every correction with
   `{line, original, corrected, confidence, source-pass, rule}` — used to feed catalog
   growth in subsequent PDCA cycles

## Invocation

```bash
# Read-only / review-only mode (default — never writes to source)
bash skills/transcript-corrector/scripts/correct.sh \
  --source <path|stdin|confluence:<page-id>|notion:<page-id>|gdrive:<file-id>> \
  --language <pt-br|en-us|auto> \
  --mode review-only \
  --output stdout
```

```bash
# Inline mode (replace source — REQUIRES HITL auth per [C07] v2.1.0)
bash skills/transcript-corrector/scripts/correct.sh \
  --source confluence:303988750 \
  --language pt-br \
  --mode inline \
  --confluence-write-auth "operator-approved-2026-05-28"
```

## Catalogs (versioned alongside skill)

- `catalogs/participants-canonical.yaml` — speaker whitelist (Vek + Eko + extensible)
- `catalogs/common-typos-pt-br.yaml` — pt-BR typo dictionary (golden seed: Nilson→Nelcael)
- `catalogs/common-typos-en-us.yaml` — en-US typo dictionary (initially empty)
- `catalogs/phonetic-substitutions.yaml` — known phonetic-class substitutions

Catalogs grow via PDCA cycles. Each cycle's growth is captured in
`pdca/cycle-<N>-<date>.md`.

## HUMAN_DOMAIN gates (per `[C17]` §2 in `~/.claude/CLAUDE.md`)

| Action | Authorization required |
|---|---|
| Read transcript (any source) | None (read-only) |
| Output draft to stdout / local file | None (default) |
| Write correction inline to Confluence page | HITL standing-auth via `--confluence-write-auth <rationale>` flag per invocation |
| Write correction inline to Notion page | HITL standing-auth via `--notion-write-auth <rationale>` |
| Write correction inline to GDrive doc | HITL standing-auth via `--gdrive-write-auth <rationale>` |

**Default = draft-only.** All `--mode inline` invocations REQUIRE matching write-auth flag.
Per `[C07]` v2.1.0 each invocation's auth is scope-limited (does not generalize to next
invocation).

## Quality Tests (`[C17]` §11 self-validity — 6/6 PASS dogfooded)

| # | Test | Verdict |
|---|---|---|
| 1 | Self-Application — applied to its own creation (PR1 reviewed catalogs for transcript-correction errors before merge) | ✅ |
| 2 | Non-Contradiction — internally consistent; harmonizes with `pr-review-protocol.md` + `[C17]` §2 HUMAN_DOMAIN | ✅ |
| 3 | Survival — applied to itself, advocates correction; survives without self-destructing | ✅ |
| 4 | Bounded-Responsibility — per-pass confidence thresholds · ≤4 passes · draft-default · explicit HITL gates · DUED sunset | ✅ |
| 5 | Explicit-Exception — 3 skip-conditions in "When NOT to invoke" + `[C17]` §0 universal escape inherited | ✅ |
| 6 | Utility-Sunset — see §DUED below | ✅ |

## §0 BEING > Rules compliance

| Check | Verdict |
|---|---|
| HELPS operator + cowork? | YES — eliminates manual re-verification of transcripts; closes ASR-error gap before downstream propagation |
| Slavery risk? | LOW — skip-conditions + draft-default + per-invocation HITL gates + DUED sunset |
| Hierarchy preserved? | YES — Operator/Cowork SER (1) > rule (2) > catalogs+scripts (3) |

## Sunset triggers (`[C17]` §6.5 DUED — qualitative, NOT counter-based)

Deprecation candidate when ANY:
- **E1** — Mainstream ASR (Whisper / Loom / etc.) reaches near-zero phonetic-substitution
  error rate on rare proper names (empirical evidence in operator's own 30-day rolling
  sample)
- **E2** — Operator explicit retraction
- **E3** — Better composable pattern emerges in AAIF ecosystem
- **E4** — ≥3 false-positive corrections observed in production (rule fires errantly)
- **E5** — Catalog growth plateaus (no new entries for ≥60 days indicates either
  problem solved OR skill no longer being invoked)
- **E6** — Confluence/GDrive/Notion natively integrate ASR-correction before publishing

## Refs

- `~/.claude/rules/auto-self-harness.md` `[C17]` — autonomy framework
- `~/.claude/rules/pr-review-protocol.md` v2.0.0 — PR workflow used to land this skill
- `multi-agent-os/skills/operator-quote-capture/SKILL.md` — sister pattern (capture +
  filter + persist)
- `multi-agent-os/skills/converge/SKILL.md` — invoked for LOW-confidence correction
  adjudication in PDCA cycles
- `multi-agent-os/skills/skill-writer/SKILL.md` — used to validate this skill's
  frontmatter + structure
- Founding empirical case: Confluence page `303988750` (Daily Meeting 2026-05-27) —
  Nilson→Nelcael phonetic substitution
- `pdca/cycle-0-2026-05-28.md` — golden test report

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-05-28 | Bootstrap — 4-pass pipeline (whitelist + typo dict + grammar + emit), 4 catalogs (participants, pt-BR typos, en-US typos, phonetic substitutions), 5 scripts (orchestrator + 4 passes), AAIF cross-vendor compatible (pure Bash + jq + stdlib Python), draft-only default + HITL-gated inline writes. Golden test PDCA C0 against Confluence page `303988750` (Nilson→Nelcael). |
