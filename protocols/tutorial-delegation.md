---
name: tutorial-delegation
description: Three-role delegation contract that governs handoffs in the tutorial-specialist workflow: Pesquisador-Crítico → Redator-Tutor → Revisor Pedagógico. Each handoff returns a strict JSON artifact; downstream rejects malformed inputs.
version: "0.1.0"
---

# Tutorial Delegation Contract

The `tutorial-specialist` agent cycles through 8 roles, but only 3
require strict handoffs because they produce structured JSON
artifacts that downstream consumers (the agent's own later phases)
must parse and validate.

## The 3 strict handoffs

### Handoff 1: Pesquisador-Crítico → Redator-Tutor

- **Producer:** Pesquisador-Crítico (role 3+4 combined)
- **Output:** `ledger.json` per chapter
- **Schema (required fields):**
  ```json
  {
    "capitulo": <int>,
    "titulo": "<str>",
    "notebook_id": "<uuid|null>",
    "analogy_central": "<str>",
    "sources": [
      {
        "id": "<str>",
        "title": "<str>",
        "url": "<str>",
        "authority_tier": "A|B",
        "why": "<str>",
        "key_facts": ["<str>", "<str>", "<str>"],
        "excerpt_pt": "<5+ sentences pt-BR>"
      }
    ],
    "rejected": [{ "url": "<str>", "reason": "<str>" }]
  }
  ```
- **Validation gates:**
  - `len(sources) ∈ [5, 7]`
  - all `authority_tier ∈ {A, B}` (no C, no D as included)
  - 0 occurrences of `wikipedia.org` in `sources[].url` (Wikipedia allowed only in `rejected[]` with reason)
  - each `excerpt_pt` has ≥ 5 sentences (rough: ≥ 80 words)
- **Downstream rejection:** if validation fails, Redator-Tutor refuses
  to start and asks Pesquisador-Crítico to re-emit the ledger.

### Handoff 2: Redator-Tutor → Revisor Pedagógico

- **Producer:** Redator-Tutor (role 5)
- **Output:** `tutorial.md` per chapter
- **Validation gates:**
  - `wc -w` ∈ [1000, 1500]
  - 10 H2 sections, in this exact order:
    1. Contexto
    2. Analogia do Mundo Real
    3. Definição Simples
    4. Como Funciona (passo-a-passo)
    5. Conceitos-Chave
    6. Comparações & Armadilhas
    7. Ferramentas & Onde Tocar
    8. Exercício Prático
    9. Checkpoint de Auto-Avaliação
    10. Conexão com o Próximo Capítulo
  - central analogy mentioned at least 3 times
  - 0 fabricated URLs (every URL must come from the ledger)
- **Downstream rejection:** if word count is out of range OR a
  section is missing, Revisor returns the tutorial to Redator for
  revision before QA.

### Handoff 3: Revisor Pedagógico → QA Final

- **Producer:** Revisor Pedagógico (role 7)
- **Output:** `revision.json`
  ```json
  {
    "capitulo": <int>,
    "approved": <bool>,
    "issues": [{ "section": "<int>", "kind": "<clarity|fact|analogy>", "note": "<str>" }],
    "tutorial_word_count": <int>
  }
  ```
- **If `approved = false`:** tutorial returns to Redator (Handoff 2)
- **If `approved = true`:** tutorial advances to QA Final (role 8)

## Handoff timing

The 3 handoffs happen **per chapter**. Total fan-out:
- 1 root + N chapters
- N × 3 handoffs per chapter
- All chapters can be processed in parallel (each Redator-Tutor
  is an independent sub-task)

## Failure modes

- **Pesquisador-Crítico hangs (planning-only output):** the parent
  agent detects via `len(sources) < 5` and re-dispatches with a
  stricter prompt: "response = JSON only, no plan".
- **Redator-Tutor returns planning-only:** detected by word count
  fail; re-dispatch with the ledger passed inline.
- **NotebookLM CLI rate-limit on audio/slides/video:** queue them
  with `--confirm` and `sleep 8` between calls; accept partial
  artifact completion; document the gap honestly.

## Versioning

- v0.1.0 (2026-10-08): initial 3-handoff contract.
