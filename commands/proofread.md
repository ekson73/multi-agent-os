---
name: proofread
description: Proofread a text artifact (doc/ADR/ticket/PR-body/commit-msg) for grammar (pt-BR+en), typos, and mis-formatting before it ships — THOROUGH tier (cspell + LanguageTool-local + markdownlint + optional Grammar-Genie rewrite).
---

# /proofread Command

Thin wrapper that invokes `skills/proofread/SKILL.md`. The skill holds all logic
(the stack, when/how, the privacy guardrail, the cspell≠codespell split, output
discipline); this file is the command surface only.

## Usage

```
/proofread [<files-or-glob>]
```

- No argument → proofread the **changed / staged** text files (git diff scope).
- `<files-or-glob>` → proofread those files (e.g. `/proofread docs/**/*.md`).

## What it does

1. **Typos** — `cspell` (catch-anything, pt-BR dict) → flags novel typos like `Aurona`.
2. **Grammar** — `languagetool -l pt-BR|en-US` **LOCAL only** (never the public API).
3. **Formatting** — `markdownlint-cli2`.
4. **Rewrite (optional)** — a Grammar-Genie pass for tone/clarity over the suggestions.

Reports issues with `file:line` + suggestion; applies high-confidence fixes only after
confirming (never blind `replace_all`). Skip for trivial/throwaway text.

See `skills/proofread/SKILL.md` for the full stack, install, and bounds.
