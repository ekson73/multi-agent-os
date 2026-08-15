---
name: proofread
version: "1.0.0"
description: |
  Use when FINALIZING any text artifact — a doc / ADR / README / ticket body /
  PR description / commit message / release note — to check GRAMMAR (pt-BR + en-US),
  TYPOS, and MIS-FORMATTING before it ships. For the THOROUGH tier, run cspell
  (the workhorse — it flags novel typos like "Aurona" that grep and codespell miss) +
  LanguageTool (grammar/concordância/acentos/spelling, LOCAL — never a public API)
  + markdownlint-cli2 (structure), and offer an optional Grammar-Genie rewrite for tone.
  Compose the deterministic linters with the probabilistic rewrite (ECE pattern);
  do not build a new engine. Report issues with file:line + fix suggestions; apply
  fixes only with confirmation.
  SKIP for trivial/throwaway text. Triggers: "proofread this", "revise / check grammar",
  "revisar gramática / ortografia", "find typos", "antes de commitar revise o texto",
  "is this text clean", "lint this doc", "check spelling pt-BR", "/proofread".
allowed-tools: Read, Edit, Bash, Grep, Glob
---

# proofread — text-quality pass (gramática pt-BR+en · typos · mis-formatting)

> **Soul-name**: *Aristarchus* (Aristarchus of Samothrace, ~150 BCE — head of the Library of
> Alexandria, the founding textual critic who invented the editorial marks; display-only).
> **System-name** (canonical slug/trigger) = `proofread`. Named via the `anima` envelope.
> **Pattern**: Eko Convergence Engine — deterministic linters bound + verify a probabilistic
> rewrite (`agentic-first §4.7`). **Reference catalog**: a host repo's `docs/text-quality-tooling.md`
> (if present) holds the install matrix + the cspell≠codespell split + the privacy guardrail.

## When to fire (self-describing trigger)
At the moment you are **about to ship text a human will read**: a doc/ADR/README, a tracker
ticket body, a PR description, a commit message, a release note. Fire on judgment — no gate.
**Skip** trivial/throwaway text (a one-line ack, scratch notes), per anti-over-engineering.

## The stack (4 axes — install once, then this skill orchestrates)
| Axis | Tool | Role |
|---|---|---|
| Typos (THOROUGH) | **cspell** + `@cspell/dict-pt-br` | catch-anything — flags novel typos (`Aurona`) |
| Typos (low-noise) | **codespell** | curated common-misspell pairs (backstop; misses novel) |
| Grammar pt-BR+en | **LanguageTool** (LOCAL) | concordância · ortografia · acentos · spelling |
| Mis-formatting | **markdownlint-cli2** | markdown structure |
| Rewrite/tone | **Grammar-Genie** (this agent) | optional human rewrite over the suggestions |

**Install** (if the CLIs are absent): use the host repo's install script when present
(`scripts/install-text-quality-tooling.sh`), else: `brew install languagetool markdownlint-cli2`
· `npm i -g cspell @cspell/dict-pt-br` · `pip install codespell`. Verify: `command -v cspell languagetool`.

## How to run
```bash
# 1) typos (THOROUGH — uses repo cspell.json if present; pt-BR dict active)
cspell <files-or-glob>                 # the workhorse: catches what grep can't enumerate
# 2) grammar — LOCAL ONLY (see Privacy)
languagetool -l pt-BR <file.md>        # or  -l en-US
languagetool --http --port 8081        # local server → POST /v2/check for programmatic use
# 3) formatting
markdownlint-cli2 <files-or-glob>
```
Scope to the **changed/target files** (don't lint the whole repo). Read the output, then:
- present a concise issue list (file:line · what · suggestion);
- for high-confidence corrections (clear typos/accents), apply via Edit **after confirming** the
  word is a genuine error — never blind `replace_all` (a real-word token may be intentional);
- optionally offer a Grammar-Genie rewrite for tone/clarity over the mechanical suggestions.

## ⛔ Privacy guardrail (non-negotiable)
LanguageTool has a PUBLIC API that **uploads your text**. For any sensitive / proprietary
content run it **LOCAL** (`languagetool` CLI / `--http` / Docker) — NEVER `api.languagetool.org`.
Same discipline for any cloud grammar service. (Secrets/PII/LGPD.)

## cspell ≠ codespell (the split — don't confuse them)
- **cspell** = full-dictionary spell-check → flags any unknown token (catches novel typos like
  `Aurona`); multi-language (pt-BR + en); the **workhorse** of this skill.
- **codespell** = curated common-misspell pairs (English-biased, low-noise) → a fast CI/pre-commit
  **backstop** that does NOT catch novel typos. Use both; they complement, not compete.

## Output discipline (anti-theater)
Report only REAL issues with evidence (file:line). Distinguish a genuine typo from a
flagged-but-legitimate token (proper noun / coined term → add to the repo's cspell allowlist,
e.g. `.cspell-akasha-words.txt`, not "fix" it). Verify before replacing (Mente Tomé).

## Skip / bounds
Skip trivial text · scope to changed files · time-box (don't lint a 200-file repo on a 1-file
change) · never block a workflow (this is advisory — the on-demand THOROUGH pass; a repo may
also wire a fast warn-only pre-commit backstop separately).

## Cross-links
- Apply the ECE pattern from `agentic-first-decision-protocol §4.7` (deterministic harness × probabilistic cognition).
- Consult `docs/text-quality-tooling.md` in a consuming repo for the install/when/how catalog.
- Lineage: named via `skills/anima`; forged via the `agentic-tool-forge` discipline.

## Changelog
| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-06-24 | Bootstrap — forged from the akasha text-quality roadmap (`plans/compressed-enchanting-shamir.md`). ECE composition (cspell + LanguageTool-local + markdownlint × Grammar-Genie), pt-BR+en, privacy-local, self-describing WHEN. Soul-name *Aristarchus*. Empirically grounded: cspell catches `Aurona`, codespell doesn't, LanguageTool flags pt-BR concordância/acentos local. |
