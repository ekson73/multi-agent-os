# References — transcript-corrector skill

External libraries, datasets, and standards consulted during design.
None are vendored in this repo; all are capability-detected at runtime
(skill must function without them via pure Bash + jq + stdlib Python fallback).

## Algorithms

### Levenshtein distance
- Original paper: Vladimir I. Levenshtein (1966) "Binary codes capable of correcting
  deletions, insertions, and reversals", *Soviet Physics Doklady*, 10(8):707-710
- Python stdlib fallback: `difflib.SequenceMatcher(None, a, b).ratio()` — produces a
  normalized 0.0-1.0 similarity score similar to (1 - normalized Levenshtein)
- Optional fast-path: PyPI package `python-Levenshtein` (C-optimized) — install if
  available, fall back otherwise

### Metaphone / phonetic encoding
- Original Metaphone: Lawrence Philips (1990) "Hanging on the Metaphone",
  *Computer Language*, 7(12)
- Double Metaphone: Lawrence Philips (2000) "The Double Metaphone Search Algorithm",
  *C/C++ Users Journal*, 18(6)
- Portuguese-specific phonetic encoding (BR adaptation): heuristic implementation
  inspired by `metaphone-ptbr` (community Python lib) — for v1.0.0 we fall back to
  Levenshtein + `difflib` if no phonetics lib available
- Optional libs: `phonetics`, `jellyfish`, `metaphone` (Python)

## Grammar / style checking

### LanguageTool
- Open-source proofreading library (https://languagetool.org/)
- REST API endpoint for community edition:
  `https://api.languagetool.org/v2/check` (rate-limited)
- Self-hosted: `docker run -p 8010:8010 erikvl87/languagetool`
- Categories we apply (safe-only): `PUNCTUATION`, `TYPOGRAPHY`, `CASING`
- Categories we EXCLUDE (over-rewriting risk): `STYLE`, `REDUNDANCY`, `PLAIN_ENGLISH`

### Alternative — pure Bash regex fallback
- Capitalize after `[.!?]\s+` (sentence start)
- Collapse `\s{2,}` → single space
- Ensure terminal `.` on paragraphs lacking final punctuation

## ASR error patterns — research notes

The empirical Nilson→Nelcael case (founding example for this skill) belongs to a
well-documented ASR error class: **rare proper name substitution by common
phonetic neighbor**. Mainstream literature:

- Goel & Byrne (2000), "Minimum Bayes-risk automatic speech recognition" — describes
  the bias toward high-prior-probability words in ASR output
- Stolcke et al. (2002), "SRILM — An extensible language modeling toolkit" — confirms
  rare-word out-of-vocabulary substitution as a primary error class
- Modern ASR (Whisper, Loom, Otter): same pattern persists; proper-name correction
  requires either fine-tuned vocabulary OR post-processing whitelist (this skill's
  Pass-1 approach)

## Datasets (for future PDCA enrichment)

- LanguageTool community-curated rule sets: https://community.languagetool.org/rule/list
- OpenSubtitles parallel corpus (for typo mining): https://opus.nlpl.eu/OpenSubtitles
- Whisper error analysis: https://github.com/openai/whisper (see issues + community
  notes on rare proper name handling)

## Sister skills (in this repo) consulted

- `multi-agent-os/skills/operator-quote-capture/SKILL.md` — 2-step filter pattern
  (Analyze → Validate) — adapted for Pass-1 "Detect → Confirm correction"
- `multi-agent-os/skills/converge/SKILL.md` — 5-Act cross-agent debate — used in
  PDCA when LOW-confidence correction needs adjudication
- `multi-agent-os/skills/skill-writer/SKILL.md` — used to validate this skill's
  frontmatter + structure
- `multi-agent-os/skills/find-docs/SKILL.md` — used to research ASR-error literature

## Refs in operator's user-scope

- `~/.claude/rules/auto-self-harness.md` `[C17]` — autonomy framework (cited
  throughout SKILL.md)
- `~/.claude/rules/pr-review-protocol.md` v2.0.0 — PR workflow used to land this
  skill (PDCA + bot convergence)
- `~/.claude/CLAUDE.md` `[C04]` Worktree Protocol, `[C07]` v2.1.0 HITL Authorization
- `~/.claude/plans/fuzzy-fluttering-crayon.md` — full design plan for this skill
