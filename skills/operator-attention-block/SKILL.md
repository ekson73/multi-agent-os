---
name: operator-attention-block
version: 1.0.0
description: >
  Pharos — the fixed end-of-message block that surfaces EVERY item a human must act on
  (approval/GO, decision, answer, security alert, manual step) so it is never buried in
  prose. Use on every agent response to a human that asks for anything, and as a one-line
  "nothing needs you" status at the end of substantive work. Enforced by the
  attention-block-gate Stop hook + bin/attention-block-lint.
soul-name: Pharos
agnostic: [os, project, llm, harness]
---

# Operator Attention Block (soul-name *Pharos*)

> *Pharos* — the lighthouse of Alexandria: one fixed light, always in the same place, that
> tells you where to look. Display-only name; the machine slug is `operator-attention-block`.

## The problem it solves

A human reading a long agent answer misses the one line where the agent asked for a GO, an
opinion, or a manual step. The ask was there — but in paragraph six, phrased as a subordinate
clause. The operator's words: *"como uma agulha no palheiro"*. Every fix that relies on the
human reading more carefully fails; the fix has to be on the writer's side, and it has to be
checked, because an amnesic agent forgets conventions.

## The contract (binding for any agent writing to a human)

1. **Where** — the block is the **last thing in the message**. The terminal auto-scrolls to the
   bottom; that is where the reader's eye lands. Nothing after it.
2. **When** — present whenever the message asks the human for anything. On a substantive
   end-of-work message with nothing pending, emit the one-line **clear** status instead, so
   "nothing needs you" is a positive statement, not an absence the human has to infer.
   Trivial conversational replies need neither.
3. **Shape** — only terminal-safe markdown (bold, single-level blockquote, numbered list, code
   spans). No `##` headings (render as plain bold), no GFM `[!IMPORTANT]` (prints literally),
   no nested quotes.
4. **Every item** = severity icon **+** verb word (never color alone) · one line · an exact
   reply token the human can type.
5. **Cap: 3 items.** More than 3 ⇒ persist the rest (ticket/backlog) and say so in the block.
   Alarm fatigue is real: a block that is always long stops being read.
6. **Self-answer first** (`harmonic` L10 / council-before-HITL): only the irreducible residue
   goes in the block. The block is not a license to ask more.

### Template — items pending

```
(linha em branco)
> **🔔 PRECISA DE VOCÊ (2)**
> 1. **🛑 AUTORIZAR** — encerrar 7 processos órfãos (reversível) · responda `1 sim` / `1 não`
> 2. **🔶 DECIDIR** — região do deploy · `2A` sa-east-1 (recomendado) · `2B` us-east-1
> ➕ +2 registrados no backlog (não precisam de você agora)
```

No `---` above the block: a rule right under a prose line turns that line into a setext
heading. The blockquote already separates the block. The `➕` line appears only past the cap.

### Template — nothing pending

```
> **✅ NADA PRECISA DE VOCÊ**
```

Always the same short line — details belong in the prose above. A line that varies gets
read; a line that is always identical gets *recognized*, which is the point.

Labels follow the operator's language (en: `🔔 NEEDS YOU (N)` / `✅ NOTHING NEEDS YOU`). The
linter keys on the emoji markers, so any language works.

### Severity and verbs

| Icon | Meaning | Verbs (pt-BR · en) |
|---|---|---|
| 🛑 | Blocking: I cannot proceed, or security/irreversible | AUTORIZAR · APPROVE / SEGURANÇA · SECURITY |
| 🔶 | A decision that changes what I do next | DECIDIR · DECIDE / RESPONDER · ANSWER / OPINAR · REVIEW |
| ✋ | Manual step for the human, when convenient | AÇÃO MANUAL · MANUAL STEP |

Shapes differ, not only colors: red/orange/yellow circles collapse into one another for
red-green color-blind readers (WCAG 1.4.1). Order items by severity (🛑 first). Reply tokens
carry the item number (`1 sim`, `2A`) so a bare "go" is never ambiguous, and use the
operator's language (`sim`/`não`, not `go`/`no`). The linter still accepts the legacy
🔴🟠🟡 circles.

## Enforcement (why this is a mechanism, not a wish)

| Piece | Path | Role |
|---|---|---|
| Linter | `bin/attention-block-lint` | Deterministic: ask-shaped text vs. block presence/position/cap. `--json`, exit 2 on warning. |
| Stop hook | `plugin-scripts/governance/attention-block-gate.sh` | Every turn: bad verdict ⇒ injects a one-shot reminder so the agent fixes the message before stopping; good block with items ⇒ macOS desktop notification. |
| Tests | `bin/tests/attention-block-lint.test.sh · tests/governance/test-attention-block-gate.sh` | 20 cases (buried asks pt/en, fences, quotes, trailing prose, cap, path-safety, kill-switch). |

Hook safety: never blocks (exit 0), one-shot per `prompt_id` (atomic mkdir), fail-safe on any
missing dependency, untrusted ids path-allowlisted, every invocation ledgered at
`~/.claude/state/attention-block-gate/ledger.jsonl`. Kill-switches: `MAOS_ATTENTION_GATE=0`,
`MAOS_ATTENTION_NOTIFY=0`.

Wiring (Claude Code settings, `hooks.Stop`):

```json
{ "type": "command", "command": "<maos>/plugin-scripts/governance/attention-block-gate.sh" }
```

Other harnesses (Codex, Cursor, Gemini…) have no Stop hook: the contract above is
behavioral-binding there, and `attention-block-lint` can run in any CI or review step.

## Limits (stated, not hidden)

- Detection is heuristic (question marks + a pt/en ask-phrase list). False positives cost one
  extra turn at most; false negatives are asks phrased without either signal.
- The model cannot color terminal text; icons + bold + position are the whole visual budget.
- A desktop notification tells an absent human *that* something waits, not *what* — the block
  is the source of truth.

## Anti-patterns

1. ❌ Asking mid-message and not repeating it in the block ("it's in there somewhere").
2. ❌ Prose after the block (breaks "last thing on screen").
3. ❌ A block every turn with filler items (alarm fatigue kills the channel).
4. ❌ Color alone (circles of different colors) without distinct shapes + the verb word.
5. ❌ `✅ NADA PRECISA DE VOCÊ` while a question sits above it (the linter flags this).

## Relations

`question-batch-gate` (sibling: counts questions, pushes toward ≤1 per turn) ·
`end-of-action-briefing-protocol` (the block is its Handoff/Status closing line) ·
`council-gate` (items only after the council could not resolve them).
