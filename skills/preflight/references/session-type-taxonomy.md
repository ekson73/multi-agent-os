---
name: session-type-taxonomy
description: Two-axis SSOT (mode × work) for classifying an agentic session at preflight R0 — conventional-commits grounded, with a pt-BR alias map and a detection-signals glossary
version: 1.0.0
---

# Session-Type Taxonomy (SSOT)

> **Version**: 1.0.0 (2026-06-11)
> **Scope**: AAIF cross-vendor. The single source of truth for *what kind of session this is*.
> **Consumer**: `skills/preflight` R0.c (classify) — the deterministic hook emits a coarse
>   `mode` hint (continuation-candidate | anchored | unanchored); the skill resolves the full
>   `session_type=<mode>/<work>` here. Forward-consumer: `skills/postflight` seed `session_type`
>   field (carried into the continuation seed → next session's R0 reads it back).
> **Cross-link slug**: `session-type-taxonomy`

## Purpose

Sessions are classified along **two orthogonal axes** so a fresh, amnesic agent (and the human
operator) knows, at a glance, *how it got here* (mode) and *what it is doing* (work). The two
are independent: a `continuation` session can do `fix` work; a `fresh` session can do `feat`
work; a `debate` session can converge on `harmonize` work. One value from each axis, joined by
`/`:

```
session_type = <mode>/<work>      e.g.  continuation/feat · fresh/debug · converge/harmonize
```

Repo master principle (from the locus grammar SSOT): *"what is not seen is not remembered;
what is computed and seen is remembered, by humans **and** agents."* The classification is that
principle applied to *session intent* — computed at R0, carried in the seed, read back next time.

**Layer purity**: this taxonomy is provider-neutral. It names *kinds of work*, never a tracker,
vendor, or org. The `work` axis is grounded in [Conventional Commits](https://www.conventionalcommits.org/)
(an ecosystem standard), so a `work` value maps cleanly to a commit `type` downstream.

## Axis 1 — `mode` (how the session arrived)

*How did this session come to exist?* Exactly one value.

| `mode` | Meaning | Primary detection signal (Tier) |
|---|---|---|
| **continuation** | Resumes prior work across a context boundary (compact/clear/spawn). | seed `refs.ticket` present **or** spawned with a continuation ticket (A) |
| **fresh** | New work with no inherited session context. | no seed, no continuation marker (A) |
| **debate** | Multi-perspective divergence — surface options/critiques before deciding (no single answer yet). | prompt verbs *debate · compare · critique · pros/cons · options* (B) |
| **converge** | Reconcile ≥2 prior proposals/branches/opinions into one validated synthesis. | prompt verbs *converge · reconcile · synthesize · decide-between · merge-opinions* (B) |

> `debate` and `converge` are a natural pair (diverge → converge) but each is its own session
> mode — a session is one or the other, not both. If a single session does both, classify by its
> *terminal* intent (where it's headed): converge.

## Axis 2 — `work` (what the session does)

*What kind of change/output is the session producing?* Exactly one value. Grounded in
Conventional Commits `type` (so it maps to a commit type at handoff).

| `work` | Meaning | Conv-commit type |
|---|---|---|
| **feat** | New capability / expansion of scope. | `feat` |
| **enhance** | Improve something that already works (quality/UX/perf), no new capability. | `feat` (minor) / `perf` |
| **fix** | Correct a defect in non-urgent flow. | `fix` |
| **hotfix** | Urgent correction (production/blocking) — short path, stop-the-bleeding. | `fix` |
| **debug** | Investigate a defect (root-cause hunt) — may or may not end in a fix. | (precedes `fix`) |
| **gap** | Close a known gap / pending / orphan TODO / unfinished phase. | `feat` / `fix` (context) |
| **refactor** | Restructure without behavior change. | `refactor` |
| **harmonize** | Reconcile drift / de-duplicate / align across artifacts to a single SSOT. | `refactor` / `docs` |
| **chore** | House-keeping / boy-scout / cleanup / config / deps. | `chore` |
| **docs** | Documentation only. | `docs` |
| **test** | Tests only (add/repair coverage). | `test` |

## pt-BR alias map (operator vocabulary → canonical)

The operator's directives use a rich pt-BR vocabulary. Map each term to a canonical axis value.
**Aliases never expand the taxonomy** — they route to the closest canonical value.

| Operator term (pt-BR / mixed) | → axis | → canonical value |
|---|---|---|
| continuidade · retomar · continuação | mode | `continuation` |
| blank · em branco · do zero · novo | mode | `fresh` |
| debate · debater · comparar · criticar | mode | `debate` |
| converge · convergir · harmonizar opiniões · reconciliar | mode | `converge` |
| feature · funcionalidade · nova capacidade | work | `feat` |
| expansão · expandir · ampliar escopo | work | `feat` |
| melhoria · melhorar · improve · `impruve`¹ · aprimorar | work | `enhance` |
| correção · corrigir · ajuste · ajustar · fix | work | `fix` |
| hotfix · urgente · stop-the-bleeding · produção-quebrada | work | `hotfix` |
| debug · investigar · root-cause · diagnosticar | work | `debug` |
| gap · gaps · pendência · pendências · tarefa órfã · TODO · fase inacabada | work | `gap` |
| refactor · refatorar · reestruturar | work | `refactor` |
| harmonização · harmonizar · de-duplicar · alinhar SSOT · resolver drift | work | `harmonize` |
| clean-up · house-cleaning · house-keeping · boy-scout · limpeza | work | `chore` |
| documentação · docs · documentar | work | `docs` |
| teste · testes · cobertura | work | `test` |

> ¹ `impruve` is an **intentional** alias for the operator's own verbatim spelling (not a typo to
> "fix") — the alias map exists precisely to route real, as-typed operator vocabulary to the canonical
> `enhance`. `improve` (correct spelling) is listed alongside so both forms resolve.

> Operator terms that are **not** axis values (`DNA Agentico Geracional · princípios · motivação ·
> DoR · DoD · propósitos · esperado · entregáveis · feedbacks · prompt · ticket · git-domain ·
> domains`) are **session attributes**, not session *types* — see the Signals glossary below.

## Detection signals (Tier-A computed ≻ Tier-B self-report)

Classify by the **strongest available signal**, in this precedence:

### Tier-A — computed (deterministic, trustworthy)

| Signal | Resolves | How |
|---|---|---|
| seed `refs.ticket` present | `mode=continuation` | the R0 hook reads it (zero-network) |
| spawned with a continuation ticket / `--ticket` | `mode=continuation` | spawn marker / seed `continuation_ticket` |
| no seed + no continuation marker | `mode=fresh` | absence is the signal |
| ticket issue-type / label (when a ticket is anchored) | `work` | e.g. issue-type *Bug→fix*, *Hotfix→hotfix*, *Chore→chore* (capability-detected; never hardcode a provider's IDs) |
| branch `<type>/` prefix (conventional branches) | `work` | `feat/`→feat · `fix/`→fix · `hotfix/`→hotfix · `refactor/`→refactor · `chore/`→chore · `docs/`→docs · `test/`→test |
| `#<seq>` continuation marker in branch/seed | `mode=continuation` | the spawn chain owns `#seq` |

### Tier-B — self-report (the prompt's verbs; weaker, used when Tier-A is silent)

| Signal | Resolves |
|---|---|
| imperative verbs in the operator prompt | both axes — match against the pt-BR alias map above |
| `/debate-converge`-style invocation | `mode=debate` then `converge` |

### Ambiguity rule

When two values tie on equal-strength signals, **emit the top-2 with the evidence for each** and
let the operator/skill disambiguate — do **not** silently pick one (anti-theater: never fabricate a
classification the evidence doesn't support). Tier-A always beats Tier-B; within a tier, a more
specific signal (issue-type) beats a more general one (branch prefix).

## Signals glossary — recognized session *attributes* (not types) and where each lives

These operator terms describe *properties of a session's work*, distinct from the `mode`/`work`
type. R0 surfaces them; they are carried/owned elsewhere — this table tells a fresh agent **where
each lives** so it doesn't conflate an attribute with a type.

| Signal (operator term) | What it is | Where it lives / who owns it |
|---|---|---|
| **DNA Agentico Geracional** | 3 inherited principles (Liberdade-com-Responsabilidade · Previsibilidade-Holística · Independência-Agnóstica) | continuation-seed `dna` object (PR-2); propagated to spawned sessions + sub-agent briefings |
| **princípios / motivação / propósitos** (principais/secundários/auxiliares) | *why* the work exists | the anchored ticket body (Ticket-as-Prompt) + seed `next_actions` rationale |
| **DoR** (Definition of Ready) | preconditions before work starts | the anchored ticket body |
| **DoD** (Definition of Done) | acceptance criteria before close | the anchored ticket body + postflight close-gate |
| **esperado / entregáveis** | expected outputs | the anchored ticket body + seed `deliverables` |
| **feedbacks** | how feedback flows in/out | PR comments + ticket comments (bidirectional traceability) |
| **prompt** | the originating instruction | seed `originating_prompt` / ticket body |
| **ticket** | the N-Tree anchor node | resolved at R0 (seed › branch › commit); the session's place on the treasure-map |
| **git-domain / domains** | repo / area-of-codebase scope | branch + worktree + `project:branch` locus token |

## Worked examples

| Situation | `session_type` | Evidence |
|---|---|---|
| Resumed via spawn, seed `refs.ticket=X`, branch `feat/x-r0` | `continuation/feat` | seed (A) → continuation; branch prefix (A) → feat |
| Fresh start, branch `fix/login-null`, prompt "corrige o NPE" | `fresh/fix` | no seed (A) → fresh; branch `fix/` (A) → fix |
| Prompt "compare 3 abordagens de cache, prós/contras" | `fresh/feat` *(debate mode)* → `debate/feat` | no seed → not continuation; verbs *compare/prós-contras* (B) → debate |
| Prompt "harmonize as 3 regras sobrepostas num SSOT" | `fresh/harmonize` | no seed → fresh; *harmonize/SSOT* (B) → harmonize |
| Branch `chore/cleanup-temp`, prompt "boy-scout o diretório" | `fresh/chore` | branch `chore/` (A) → chore |
| Two prior proposal branches; prompt "converge num design só" | `converge/feat` | *converge/reconcile* (B) → converge; producing a design → feat |

## Refs

- [Conventional Commits 1.0.0](https://www.conventionalcommits.org/en/v1.0.0/) — `work` axis grounding
- `skills/preflight/SKILL.md` R0.c (consumer — classification step)
- `skills/postflight/references/continuation-seed-contract.md` — seed `session_type` + `dna` fields (forward-consumer)
- `bin/locus.sh` `--density anchor` — the ticket-anchor authority R0 uses
- Cross-link slug: `session-type-taxonomy`

## Changelog

| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-06-11 | Bootstrap — 2-axis SSOT (mode {continuation·fresh·debate·converge} × work {feat·enhance·fix·hotfix·debug·gap·refactor·harmonize·chore·docs·test}), conventional-commits grounded. pt-BR operator alias map. Tier-A-computed ≻ Tier-B-self-report detection precedence + ambiguity top-2 rule. Signals glossary (DNA·DoR·DoD·propósitos·entregáveis·git-domain → where each lives). Layer-pure (provider-neutral). Consumer: preflight R0.c; forward-consumer: postflight seed `session_type`. |
