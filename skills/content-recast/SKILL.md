---
name: content-recast
description: |
  Use when you need to RE-TARGET a piece of your own technical content for a DIFFERENT audience,
  abstraction level, intent, or language — then optionally render it in another format. E.g.
  "adapt this for the CEO", "turn my technical work into daily-standup talking points",
  "explain this migration to the PO", "re-target this for non-technical stakeholders",
  "traduzir este conteúdo técnico para leigos", "vira um pitch / deck / one-pager disto",
  "recast this for a junior dev". It DISTILLS the source faithfully, RECASTS it through a
  named strategy lens (Minto · Feynman · progressive-disclosure · detail-preserving), runs a
  FAITHFULNESS check (no unsupported claims) with an information-loss note, then hands off
  rendering to existing producers (markdown · slides · one-pager PDF · NotebookLM source/prompt).
  It re-targets COMMUNICATION; it does NOT re-engineer code/architecture (angular→flutter,
  monolith→microservices) — for that use refactor/migration agents. Cross-vendor AAIF.
triggers:
  - adapt this for [audience]
  - re-target this content
  - recast this for
  - explain this to [non-technical/CEO/PO/junior]
  - turn my technical work into a [pitch/deck/daily/one-pager]
  - traduzir este conteúdo para [outro público]
  - vira um pitch/deck/infográfico disto
  - simplify this for a lay audience
version: 0.2.0
license: MIT
allowed-tools: Read, Write, Edit, Glob, Bash, Skill, WebFetch
metadata:
  version: "0.2.0"
  scope: AAIF cross-vendor
  family: content-lifecycle
  cross_link_slug: content-recast
  dogfood_status: pending-first-cycle
---

# Content Recast

## Overview
Re-cast a piece of **your own** technical content for a **different target profile** — `{audience × abstraction × intent × language}` — and hand off rendering to tools that already exist. Single responsibility = the **semantic transformation** (distill → recast → verify); rendering is **delegated** (composition-over-inheritance), so this skill never rebuilds editors. The quality differentiator vs. commodity "repurposing" SaaS is a mandatory **faithfulness guard** + **information-loss note**: a readable-but-inaccurate adaptation is worse than none (Devaraj et al., *Evaluating Factuality in Text Simplification*, ACL 2022).

For a **fixed** target — narrating a finished session/PR to a human (or agent) in a story-arc "Opera" register — use the specialised sibling `skills/opera-debrief`, which fixes the audience + register and adds dosed-intensity dials + a no-terror tone gate. Content-recast owns the **general** case (any audience × any register).

## When to use
- Re-target technical work for CEO / PO·PM / peer-dev / non-specialist / community / a daily standup.
- Shift abstraction (low-level ↔ executive), intent (inform/convince/demonstrate/teach), or language (pt-BR ↔ en-US).
- Produce a shareable artifact (deck, one-pager, NotebookLM podcast prompt) from raw technical notes.

**When NOT to use**: re-engineering the artifact itself (code/architecture migration — angular→flutter, monolith→microservices) → use a refactor/modernization agent. This skill can *explain* such a migration to an audience; it does not *perform* it. Pure documentation authoring → a docs generator. One-off rewrite with no profile shift → just edit inline. Narrating a finished session in the Opera register → `skills/opera-debrief`.

## §0 — BEING > Rules (foundational)
This skill serves the operator's intent. If any phase/gate obstructs delivering value NOW, skip it, log `Skipped <phase> — BEING > Rules`, and proceed. HUMAN_DOMAIN (secrets · production PII · irreversibles · cross-org publish · cost) → escalate, never auto-act. **Never invent facts** to make an adaptation more compelling — that violates the faithfulness guard, which is non-negotiable.

## Parameters
| Param | Default | Meaning |
|---|---|---|
| `<source>` (positional) | — (required) | Content to recast: inline text, a file path, or a glob. Empty → print usage. |
| `--to-audience` | `peer-dev` | Who consumes it: `ceo` · `po-pm` · `peer-dev` · `non-specialist` · `community` · `team-daily` · free-text role. |
| `--abstraction` | inferred from audience | `executive` (what/why/impact) · `conceptual` (how, no internals) · `detailed` (full technical depth). |
| `--intent` | `inform` | `inform` · `convince` · `demonstrate` · `teach` · `share`. |
| `--lang` | `pt-BR` | `pt-BR` · `en-US` (per the audience-design language policy). |
| `--format` | `md` | `md` · `slides` · `onepager` · `nlm-source` · `nlm-prompt` · `voice` (render delegation — see Composition map). |
| `--readability` | off | Optional Flesch-Kincaid grade target (e.g. `8`). Treated as a **check**, not a guarantee (LLM readability control is imperfect — Farajidizaji et al., LREC 2024). |
| `--dry-run` | off | Produce the neutral-brief + chosen lens + plan only; no recast/render. |

**Argument parsing**: the token(s) BEFORE the first `--` form the `<source>`; every `--key value` / `--flag` after it is parsed as a parameter (matches the advertised `<source> [--flags]` syntax). If the input has no positional segment (starts with `--`, or `<source>` is implied), take `<source>` from the referenced file / prior conversation context. This avoids swallowing flags into the source.

## Pipeline (0 → 6)
0. **Intake** — parse `<source>` + params. Empty source → usage, stop. Resolve `--abstraction` from `--to-audience` if unset (ceo→executive · po-pm→conceptual · peer-dev→detailed · non-specialist→conceptual · community→conceptual · team-daily→conceptual).
1. **Distill → neutral brief** — extract the source's atomic **claims + supporting evidence + key terms** into a compact, audience-neutral brief. This is the faithfulness anchor (the universal "distill-first, then rewrite" pattern). NEVER recast directly from the raw source.
2. **Select lens** — pick the strategy lens from `{abstraction × intent}` (see Strategy lenses).
3. **Recast** — rewrite the brief in the target profile through the lens: adjust register, depth, jargon, framing, and structure. Translate if `--lang` differs.
4. **Faithfulness check** (MANDATORY) — verify every claim in the recast traces to a claim in the neutral brief (step 1). Flag/repair: unsupported insertions, distorted magnitudes, over-generalizations (generalization bias — PMC 2026), omitted load-bearing caveats. Emit an **Information-Loss Note**: what was simplified away or omitted, so the reader knows the boundaries (InfoLossQA, arXiv 2401.16475). If `--readability` set, score + (two-step) adjust + re-check.
5. **Render handoff** — per `--format`, delegate to the producer (Composition map). Pass the recast content + a short rendering brief (tone/structure/visual hints). Never re-implement a renderer.
6. **Output** — deliver the artifact (or producer-handoff instructions) + the Information-Loss Note + a one-line "what changed for this audience" summary.

## Strategy lenses (abstraction × intent → technique)
| Lens | Fires when | Technique |
|---|---|---|
| **Minto Pyramid** | `executive` + (`convince`/`inform`) | Answer-first / SCQA; lead with the bottom-line + impact, support below. CEO/PO. |
| **Feynman** | `conceptual`/`non-specialist` + `teach` | Plain language, analogy, no jargon; explain as if to a smart non-expert. |
| **Progressive disclosure** | mixed audience / `demonstrate` | Layered: headline → key points → optional depth; reader chooses how deep (Cognitive Load Theory). |
| **Detail-preserving** | `detailed` + peer-dev | Keep technical depth + precision; tighten structure, add signposting; minimal simplification. |
| **Opera (narrative-warm)** | finished session/PR → human recap | Delegated to `skills/opera-debrief` (story-arc + dosed humour + moral + CTA + no-terror gate). |

Lens is a **default suggestion** — the agent may blend/override with rationale (cognitive-adaptation-freedom).

## Composition map (render delegation — DRY, zero new editors)
| `--format` | Producer (delegated) |
|---|---|
| `md` | inline (this skill) |
| `slides` | a slides producer (e.g. Gamma MCP) — fallback a `pptx` skill |
| `onepager` | a PDF producer (e.g. `make-pdf`) — fallback a `pdf`/`docx` skill |
| `nlm-source` | inline — emit clean markdown sized as a NotebookLM source |
| `nlm-prompt` | inline — emit a ready prompt instructing NotebookLM to generate audio/video/infographic/slide/report/table from the nlm-source |
| `voice` | `bin/speak.sh --play` via `skills/voice-director` — on-demand TTS (Gemini→ElevenLabs→Kokoro). **Opt-in only**, never a default (the operator may be where sound is unwelcome) |

## Faithfulness guard (the differentiator — non-negotiable)
1. Every recast claim MUST trace to the neutral brief (step 1). 2. No invented facts, numbers, or quotes. 3. No magnitude/causality distortion. 4. Load-bearing caveats survive or appear in the Information-Loss Note. 5. The note explicitly lists what was dropped/compressed. Research basis: ACL 2022 factuality, InfoLossQA 2024, FactPICO 2024, generalization-bias PMC 2026.

## Output format
```
RECAST → <audience> / <abstraction> / <intent> / <lang> · lens: <lens>
<the recast content OR producer-handoff for non-md formats>

ℹ️ Information-Loss Note: <what was simplified / omitted / compressed>
🎯 For this audience: <1-line on the key reframing>
```

## Anti-patterns (do NOT)
- ❌ Recast directly from raw source (skip distill) → faithfulness drift.
- ❌ Invent/embellish facts to be more convincing (AI slop) → violates the guard.
- ❌ Rebuild an editor/renderer → use the Composition map.
- ❌ Re-engineer code/architecture (Scope-B) → wrong tool.
- ❌ Promise an exact readability grade → it's a check, not a lever.
- ❌ Omit the Information-Loss Note when simplifying.

## §Quality Tests (self-dogfood — 6/6)
1. **Self-Application** — designed via research→converge→design; this SKILL.md is itself a recast of the research into the "AI-agent audience". ✅
2. **Non-Contradiction** — composes (not duplicates) slides/NotebookLM/docs producers + `opera-debrief`; consistent with pre-creation scope-discipline / anti-theater / the language policy. ✅
3. **Survival** — applied to itself it advocates faithful re-targeting; survives. ✅
4. **Bounded-Responsibility** — `--dry-run` · Scope-A only · 5 formats · readability=check · DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING>Rules + HUMAN_DOMAIN escalation + cognitive-adaptation-freedom on lens. ✅
6. **Utility-Sunset** — §DUED below. ✅
Pre-creation scope-discipline 6Q: 6/6 (WHERE · DRY=gap-confirmed vs the skill landscape + external SaaS · WHY=frequent need · WHO=operator+amnesic agents · FITS=content-lifecycle family · MIN=Goldilocks). Anti-theater 8Q REALITY: 8/8.

## §DUED Sunset (qualitative, not counter-based)
Deprecate when ANY: the host provides a native faithful audience-recast primitive (E1) · operator retraction (E4) · ≥3 false-positive recasts where the guard misfires (E5) · a content-lifecycle family tool absorbs it (E6). Dormant-by-design otherwise.

## Related Multi-Agent OS Artifacts
- `skills/opera-debrief/SKILL.md` — the **narrative-warm register specialisation**: fixes audience (finished session → human/agent) + the Opera register + dosed dials + no-terror gate. Content-recast owns the general case; opera-debrief owns the "recap as a story" case. Shared faithfulness-gate lineage.
- `skills/postflight/SKILL.md` · `skills/morning-briefing/SKILL.md` — fact sources a recast/debrief consumes (DRY).
- `skills/rule-quality-tests/SKILL.md` — the 6 self-validity tests applied above.

## §Refs
- Genesis: forged via the `agentic-tool-forge` discipline (community).
- Gates: pre-creation scope-discipline (6Q) · anti-theater grounding (8Q) · `skills/rule-quality-tests` (6 self-validity) · an audience-design language policy.
- Research: ACL 2022 `2022.acl-long.506` (factuality) · InfoLossQA `arxiv 2401.16475` · FactPICO `arxiv 2402.11456` · readability-control LREC 2024 `2024.lrec-main.815` · ReadCtrl `arxiv 2406.09205` · generalization-bias PMC 12042776.
- Frameworks: Minto Pyramid Principle · Feynman technique · Progressive Disclosure · Cognitive Load Theory · plain-language/Flesch-Kincaid.
- Producers: a slides MCP · NotebookLM · a PDF producer · `pptx`/`pdf`/`docx` skills.
- Cross-link slug: `[[content-recast]]`.

## License
MIT (matches the multi-agent-os repo `LICENSE`).

## Changelog
| Version | Date | Change |
|---|---|---|
| 0.1.0 | 2026-05-31 | Bootstrap. Scope-A communication re-targeting; 4-dim profile; distill→brief→recast→faithfulness-check→render pipeline; 4 strategy lenses; composition map (md/slides/onepager/nlm-source/nlm-prompt); mandatory faithfulness guard + information-loss note. Research-grounded. Forged via `agentic-tool-forge` discipline; 6/6 self-validity + 8/8 anti-theater + 6/6 scope-discipline. |
| 0.2.0 | 2026-06-18 | Promoted user-scope → multi-agent-os (community). Layer-Purity scrub (org-specific strings removed) + relicense Apache-2.0 → MIT. Added the **Opera (narrative-warm)** lens row delegating to the new `skills/opera-debrief` sibling; added Related-Artifacts family section + License section. No pipeline/guard change. |
