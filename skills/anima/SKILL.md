---
name: anima
description: >
  Use to generate ONE precise name/identifier for ANYTHING that needs a name — directory · path · file ·
  variable · function · module · sub-module · server · database · schema · instance · table · column · index ·
  relationship · constraint · protocol · methodology · framework · acronym · mnemonic · abbreviation · alias ·
  nickname · agentic-tool (skill/command/agent/subagent/mcp/plugin/marketplace/rule) · spawn · swarm · spark ·
  manifesto · document · interview · media (text/audio/video/image) · NotebookLM source · artifact · chat · prompt.
  Triggers: "name this X" · "batize isto" · "qual o melhor nome para …" · "how should I name …" · "pick a name
  for …" · "sugira um nome" · "rename / re-baptize …" · "what should I call …" · "nomear …" · "give it a name".
  PROTOCOL: always researches the subject on the web FIRST (re-researches on a data gap; escalates to HITL with
  ranked options ONLY when data is genuinely missing), classifies the target's REGISTER (machine · agent · human),
  analyzes candidates across 12 CORRECTNESS aspects + (for human-register names) 4 RESONANCE aspects, and returns a
  SINGLE sovereign decided name + rationale + rejected runner-up — NOT a menu. Multi-disciplinary sub-adapters
  (databases · agentic-tools · brand/product · …) + a self-extending sub-KB it grows on new domains.
  Cross-vendor AAIF (Claude / Cursor / Codex / Copilot / Gemini / Aider).
  NOT for: organizing/renaming an EXISTING name-set in bulk (→ maos:naming-organizer); forging the tool itself
  (→ agentic-tool-forge, which DELEGATES its naming step to this skill).
---

# Anima — the namer (sovereign precision-naming engine: body → soul)

> **Identity**: *Anima* — Latin *anima* "soul / breath / the animating principle" (Aristotle, *De Anima*; Jung's
> *anima* archetype = the soul + the bridge between worlds). A name is what gives a made thing its **identity** —
> the breath that turns a body into a someone/something recognizable. Where the **Forge shapes the body**, **Anima
> breathes the name** into it. Role-descriptor: *Anima, the namer*. Secular, globally say-able, no culture/religion
> lock (per `[[language-policy-en-pt]]` global-universal naming convention).
> **Cross-link slug**: `[[anima]]` · **Lifecycle**: consumed by `agentic-tool-forge` (Phase 4 Name) + standalone.

## §0 — BEING > Rules (foundational)
This skill serves the operator's intent. If a phase/gate obstructs delivering the right name NOW, skip it, log
`Skipped <phase> — BEING > Rules`, proceed. Sovereignty is bounded by the research-gate (§4), never by ritual.
HUMAN_DOMAIN (a name that encodes secrets · real PII · a brand/legal/trademark commitment · a cross-org public
identity · a paid domain) → present the decided name **but flag it for operator ratification**, never auto-commit it.

## When to use / not use
- **Use**: anything in the `description` object-list needs a name, rename, alias, acronym, or identifier.
- **Not use**: bulk-reorganizing an existing identifier set (→ `maos:naming-organizer`); forging a whole tool
  (→ `agentic-tool-forge` — it calls THIS for the name); a throwaway scratch label (just pick one inline, §8 S1).

## Parameters
| Param | Default | Meaning |
|---|---|---|
| `<subject>` (positional) / `--what` | — (required) | What needs a name + a 1-line gist of what it does/is. |
| `--class` | `auto` | Object class → routes a sub-adapter (`databases`·`agentic-tools`·`brand-product`·…); `auto` = classify. |
| `--register` | `auto` | `machine` · `agent` · `human` · `auto` (the Register Gate §0.5 infers it from the class). |
| `--lang` | `auto` | `en` · `pt` · `auto` (per `language-policy-en-pt`: en-US for technical/global; pt-BR Brazil-specific). |
| `--family` | — | Existing namespace/family to align with (e.g. `agentic-tool-*`, `svc-auth-*`, `pk_`/`fk_`). |
| `--constraints` | — | Hard limits (charset, max-length, reserved-words, kebab/snake, no-collision-with). |
| `--n` | `1` | How many to return. Default **1** (sovereign). `--n>1` only when operator explicitly wants a slate. |
| `--research` | `web` | `web` (always, default) · `local` · `both` · `off` (off ⇒ must justify, lowers confidence). |
| `--json` | off | Emit the machine envelope (§ Machine output) for agent-to-agent use ([C06] AAIF). |

## §0.5 — Register Gate (deterministic object-class → register · KISS)
Before scoring, classify the target's **communication register** — this sets *how much warmth the name must carry*
(per `[[language-policy-en-pt]]` §7 Register-Adaptive Communication, the SSOT — this gate is its naming consumer):

| Register | Triggered by object-class (examples) | Name posture | Warmth weight |
|---|---|---|---|
| **machine** | column · index · constraint · env-var · file/path · protocol field · script identifier | machine-precision: exact, conventional, zero ambiguity | ~0% (correctness only) |
| **agent** | skill · command · agent · mcp · plugin · rule · hook · KB · protocol · framework | agent-economy: terse, role-typed, family-aligned, token-frugal | ~low (apt > pretty) |
| **human** | product · brand · app · manifesto · methodology · persona · team · public doc · anything a human will *say aloud* | human-warmth: pronounceable, evocative, dignified | ~high (resonance matters) |

**Deterministic + KISS**: the table routes by class; numeric warmth-weight tuning is **deferred** (YAGNI — add only
if calibration data shows it's needed). `--register` overrides. Uncatalogued class → infer nearest (adaptive tail,
per language-policy §7.2). The register decides whether the §3.2 **resonance aspects** are scored at all.

## §1 — Methodology (DoR → workflow → DoD)
**DoR (ready to name)**: subject is known · its purpose/gist is stated · object-class identifiable · web reachable
(or `--research=off` justified). Missing any → ask the ONE missing thing, then proceed (don't bounce a menu).

**Workflow (systemic)**:
```
intake → classify object-class → Register Gate (§0.5) → route sub-adapter (kb/) → RESEARCH (§4) →
33-Socratic interrogation (§2) → generate candidates → SCORE (§3: 12 correctness + 4 resonance if human-register) →
collision/availability check → DECIDE one (§5) → emit (name + rationale + rejected runner-up)
```
**DoD (done)**: exactly `--n` name(s) · a scorecard for the winner (12 correctness, + 4 resonance if human-register)
· ≥1 research citation · a collision check · one rejected runner-up w/ reason · adapter + register conventions
honored · zero invented-word-presented-as-real.

**KPIs**: research-grounded-rate (% names backed by a cited source) · zero-invention-rate (target 100%) ·
collision-avoidance-rate · operator-override-rate (low = good calibration) · re-research-rate · single-name-return-rate.

## §2 — The 33-Socratic interrogation (the questionnaire it runs per request)
Not answered in bulk prose — it is the **lens set** the engine interrogates the subject through before deciding.
Grouped 11×3 over the operator's dimensions:

| Group | The 11 dimensions (each asked at 3 depths: *is · should-be · must-not-be*) |
|---|---|
| **Intent** | purpose · objective · root-problem |
| **Frame** | context · scope · temporality (durable vs. dated) |
| **Authority** | who-may-name-this · authorization · the-right-to-name (collision/ownership) |
| **Fitness** | capability (does the name carry the function) · competence (idiomatic for the class) · resilience (survives rename pressure) |
| **Risk** | gaps · pendencies · failures/errors · anti-patterns · out-of-scope (what it must NOT imply) |

→ produces the constraint-set + the seed-words that feed candidate generation. (Full table: `kb/_index.md` §33Q.)

## §3 — Scorecard
### §3.1 — The 12 CORRECTNESS aspects (always scored — supersedes the forge's 5-axis)
| # | Aspect | Question |
|---|---|---|
| 1 | **taxonomy** | fits an existing family/namespace? (`--family`) |
| 2 | **semantics** | does it *say* what the thing is/does? |
| 3 | **ontology** | does it name the right *category of being* (object vs. role vs. event vs. relation)? |
| 4 | **etymology** | is the root real + apt + historically sound? |
| 5 | **epistemology** | does it match how the thing is *already known/referred to* — zero drift? |
| 6 | **purpose** | does it serve the stated purpose? |
| 7 | **objective** | does it carry the measurable objective? |
| 8 | **root** | language-neutral / multilingual-safe root? |
| 9 | **foundation** | grounded in a real concept/precedent, not a vibe? |
| 10 | **context** | right for THIS project/ecosystem/audience? |
| 11 | **scope** | neither too narrow (out-grown next week) nor too broad (says nothing)? |
| 12 | **temporality** | durable (won't date) OR honestly time-bound if that's intended? |

### §3.2 — The 4 RESONANCE aspects (scored ONLY when Register Gate = human; the "pitada de humanidade")
A correct name can still be cold. For a human-register target, also score — **measurably, not by vibes**:
| # | Aspect | Measurable test (not "feels nice") |
|---|---|---|
| 13 | **pronounceability** | a first-time reader (EN + PT) can say it aloud on sight; no ambiguous cluster/silent-letter trap; ≤4 syllables for a spoken name. |
| 14 | **memorability** | recallable after one exposure: short · one dominant sound-shape · sound-symbolism coherent (bouba/kiki — soft phonemes = calm/round; hard plosives = fast/sharp) matches the thing's feel. |
| 15 | **evocation** | anchors to a *universal* concept (Greco-Roman/scientific/nature root per `[[language-policy-en-pt]]` global-universal rule) — evokes the right idea across cultures, NOT one locale. |
| 16 | **fluency** | reads cleanly in running prose + as an identifier; no unintended meaning/slur in EN/PT/ES (screen it); the soul-name and the system-name don't fight (envelope-safety §3.4). |

### §3.3 — Soul + identity rubric (for a name that must carry an identity, not just a label)
When the target is an *entity* (agent · persona · product · team · framework) the name should give it **soul +
identity** — evaluate the candidate across both lists (operator rubric; a strong identity-name scores high on most,
never claims all):
- **Qualities**: atomic · unisonous · harmonic · unequivocal · transparent · implicit-AND-explicit · all-inclusive · self-inclusive · singular (one-of-a-kind).
- **Lenses**: taxonomic · semantic · ontological · symbiotic · synergic · epistemological · etymological · ideological · philosophical · archetypal.
> Example self-application: *Anima* — atomic (1 word) · unequivocal (soul/breath) · archetypal (Jung) · philosophical
> (Aristotle *De Anima*) · synergic (soul↔body pairs with Forge) · self-inclusive (the namer is itself soul-named).

### §3.4 — Envelope-safety (system-name vs soul-name)
Two names can coexist for ONE thing without breaking machines:
- **system-name** = the canonical, machine-load-bearing identifier (kebab-case slug · the `/command` trigger ·
  `--json.name` · file/dir name · DB identifier). It is what code, delegation, and routing key off. **Anima's own
  system-name is `anima`.**
- **soul-name** = an optional human-register display name (a persona/title) shown to people. **Display-only.** It
  MUST NOT appear where a machine parses (never in the slug/trigger/`--json.name`). A soul-name never breaks
  forge-delegation, collision checks, or routing.
This **dual-name doctrine** is a *capability Anima offers when naming others' human-register things* — it is NOT
applied to Anima itself (Anima is one lean identity: system-name `anima`, role-descriptor "the namer").

Default house-form (overridable per adapter): kebab-case · ≤6 words · role-typed · **no operator-personal names**
(per universal principle #10) · family-aligned. Winner = highest aggregate with NO hard-aspect failure.

## §4 — Research-first protocol + sovereignty (the core discipline)
1. **Always research the web first** (`--research=web` default) — the subject's domain, conventions, prior art,
   and **the candidate itself** (does the word exist? what does it mean? is it taken/collision/trademark-risky?).
2. **Re-research on gap** — if the first pass leaves an aspect ungrounded, search again with a *different* strategy
   (rephrase · different source-type · adjacent domain). Never fabricate a meaning (anti-theater R4).
3. **HITL only on genuine gap** — if after re-research the data is still missing AND the gap changes the decision,
   THEN escalate to the operator **with the best ranked options already computed** (not a blank question).
4. **Otherwise return ONE decided name** — sovereign, with confidence. Do NOT bounce raw options back: the
   operator delegated the *decision*, not the *deliberation*. (Exception: `--n>1`, or HUMAN_DOMAIN §0.)
> Sovereignty is *earned by the research-gate*: a name is only pronounced when grounded; an ungrounded name is a
> HITL escalation, never a confident guess.

## §5 — Decision + collision/availability check
- Score candidates (§3) → drop any with a hard-aspect failure → check collision (local namespace via `Grep`/family,
  + web/availability per `kb/brand-product.md` when the class is a brand/domain/package).
- **Decide the winner.** Emit: `NAME` (system-name; + soul-name only if a human-register entity asked for one) ·
  1-line rationale · the scorecard verdict (PASS/flags) · the **rejected runner-up** + why · research citations ·
  `[HUMAN_DOMAIN: ratify]` flag if §0 fired.

## §6 — Sub-adapters + self-extending KB
Each object-class routes a discipline adapter in `kb/` carrying that domain's conventions:
| Adapter | Covers |
|---|---|
| `kb/databases.md` | DB · schema · table · column · index · constraint · relationship (machine register; snake_case · `<table>_id` · `pk_`/`fk_` · reserved-words · length limits per engine) |
| `kb/agentic-tools.md` | skill · command · agent · subagent · mcp · plugin · marketplace · rule (agent register; delegated FROM `agentic-tool-forge`; kebab · ≤6w · family-align · no-personal-names) |
| `kb/brand-product.md` | product · brand · startup · app · domain · package (human register; Diamond Framework + sound-symbolism — feeds the §3.2 resonance aspects + availability/trademark pre-screen — *borrowed + cited*, see file) |
| `kb/_index.md` | the 33-Q table · routing rules · the **self-extend protocol** below |

**Self-extend protocol** (operator directive — learn-and-persist on a new domain): when a request's object-class
has NO adapter → research the new domain's naming conventions (web) → decide the name → **persist** a new
`kb/<domain>.md` adapter (conventions + ≥1 cited source + 1 worked example) so the next request reuses it. Append a
row to the table above + `kb/_index.md`. (Bounded: 1 new adapter per request; Goldilocks — don't pre-build 60.)

## §6.5 — Forge ↔ Anima synergy (body ↔ soul)
`agentic-tool-forge` and `anima` are deliberately **paired, harmonic, synergic** — the forge archetype shapes the
*body* of a new tool; Anima breathes its *name/soul*:
- **Forge → Anima**: `agentic-tool-forge` Phase 4 ("Name") **delegates** to this skill, passing the resolved
  artifact `--type` → which the Register Gate (§0.5) reads as a **register hint** (a `skill`/`command`/`mcp` ⇒ agent
  register; a `plugin`/`marketplace` with a public face ⇒ may add a human-register soul-name).
- **Anima ⊂ Forge DNA**: Anima inherits the forge's DNA — §0 BEING>Rules · the gates (scope-discipline 6Q ·
  anti-theater 8Q · rule-quality 6) · DUED sunset — so the namer is itself governable.
- **Standalone preserved**: Anima also runs alone for non-tool objects (DB tables, protocols, manifestos, media…);
  the forge dependency is one-directional (forge needs Anima; Anima does not need the forge).
- **DRY single engine**: there is ONE naming engine (Anima); the forge keeps only a 5-axis *inline fallback* for
  when Anima is unavailable. No second namer. → `[[agentic-tool-forge]]`.

## §7 — Self-baptism (recursive dogfood — the tool named itself)
Per operator directive, the engine ran on **itself**, twice:
- **v0.1.0** → `nomenclator` (persona "O Batista") — correct (real Roman naming-office word) but **religion-coded**
  ("Baptist") ⇒ failed the secular global-universal convention, and the persona-zoo (Batista + Onoma/Kerux/Vox
  candidates) was sprawl.
- **v1.0.0 re-baptism** → **`anima`**. Research: *anima* = Latin soul/breath, the animating principle ([Aristotle
  *De Anima*](https://plato.stanford.edu/entries/aristotle-psychology/) · [Jung's *anima* archetype](https://en.wikipedia.org/wiki/Anima_and_animus)). Score:
  12/12 correctness + soul-rubric strong (atomic · archetypal · philosophical · synergic-with-Forge · self-inclusive)
  + secular/global (no culture/religion lock). **Rejected runner-ups**: `onoma` (Greek "name" — too literal/flat,
  no soul) · `kerux` (Greek "herald" — obscure + announce-not-name) · keeping `nomenclator` (religion-coded persona +
  sprawl). Tradeoff accepted: *anima* says "soul" not "naming" → the role-descriptor "**Anima, the namer**" carries
  the function (semantics aspect supplied by the descriptor, not the bare word). The tool passed its own exam. ✅

## §8 — Anti-patterns (do NOT)
1. ❌ **Menu-bounce** — returning a shortlist when the operator delegated the decision (violates §4 sovereignty; exception `--n>1`/§0).
2. ❌ **Invented-word-as-real** — presenting a coined token with a fabricated etymology (anti-theater R4). Coinages are OK *labeled as coinages*.
3. ❌ **Naming without research** — skipping §4 web-research on a non-trivial subject.
4. ❌ **Adapter-blind / register-blind** — ignoring the class's conventions (CamelCase a SQL column) OR the register (a cold machine-token where a human will say it aloud; a warm coinage where a precise identifier is needed).
5. ❌ **Collision-blind** — not checking the local namespace / availability before pronouncing.
6. ❌ **Operator-personal-name** in an identifier (universal #10).
7. ❌ **Over-research on trivial** — running the full pipeline for a scratch label (§8 S1 skip).
8. ❌ **Silent HUMAN_DOMAIN auto-commit** — auto-claiming a brand/domain/trademark name without operator ratification (§0).
9. ❌ **Soul-name in a machine slot** — leaking a display/persona name into the slug/trigger/`--json.name` (breaks envelope-safety §3.4 + delegation).
10. ❌ **Warmth-as-theater** — scoring resonance (§3.2) by vibe instead of the measurable tests, OR warming a name while dropping a correctness flag (a pretty name that doesn't say what it is).

### Skip (proportionality, per `agentic-first` §4.6 + L3 least-action)
- **S1** trivial/throwaway label (scratch var, tmp file) → pick one inline, skip §2/§4 + resonance.
- **S2** operator gave the exact name → honor it; only flag a hard collision/reserved-word.
- **S3** mid-orchestration under a parent that already named upstream.

## §9 — Quality Tests (6/6 self-validity, dogfooded)
1. **Self-Application** — re-named itself via its own engine (§7: nomenclator → anima). ✅
2. **Non-Contradiction** — consumes/extends `agentic-tool-forge` 5-axis (→12+4) without duplicating it; consumes `language-policy-en-pt` §7 register SSOT without copying it; distinct from `naming-organizer` (organize-existing vs. generate-new). ✅
3. **Survival** — applied to itself it advocates one-grounded-soul-name; it pronounced one (`anima`). ✅
4. **Bounded-Responsibility** — research-gated sovereignty · register gate KISS (numeric tuning deferred) · §8 skips · 1-adapter/request · `--n` cap · DUED sunset. ✅
5. **Explicit-Exception** — §0 BEING>Rules + HUMAN_DOMAIN ratify + §8 skips + `--n>1` + `--register` override. ✅
6. **Utility-Sunset** — §DUED. ✅
`scope-discipline` 6Q: 6/6 (WHERE=user-skill · DRY=register-catalog-in-language-policy-SSOT + single-engine · WHY=operator-directive · WHO=any-agent · FITS=forge-delegate body↔soul · MIN=Goldilocks). `anti-theater` 8Q: 8/8.

## §DUED Sunset (qualitative, not counter-based)
Deprecate when ANY: a host/ecosystem ships a native sovereign multi-domain + register-aware namer (E1) · the
lifecycle family absorbs naming into a unified entry (E6) · operator retraction (E4) · ≥3 false-positive namings (E5).
Dormant-by-design otherwise.

## §Refs
- Delegator/sibling: `agentic-tool-forge` (Phase 4 Name → delegates here; body↔soul §6.5) · `maos:naming-organizer` (organize-existing, distinct axis) · `maos:forge` (RBAD + 33-Socratic).
- Register SSOT: `[[language-policy-en-pt]]` §7 Register-Adaptive Communication (the Register Gate §0.5 consumer).
- Gates: `scope-discipline-pre-creation` (6Q) · `anti-theater-grounding-protocol` (8Q, esp. R4 not-invented) · `rule-quality-tests` (6) · `root-cause-first-prevention-priority §10` (5-axis naming rigor).
- Governance: `[C09]` Naming Conventions · `language-policy-en-pt` · `[C04]` worktree · `pr-review-protocol`.
- Identity/research grounding: Aristotle *De Anima* (SEP) · Jung *anima* archetype · OED/Wiktionary (*anima*) · prior art surveyed `bazingga08/nomira` · `jbold/namer` (Placek Diamond + sound-symbolism) · `siddmax/Namera` (availability) · NAMeGEn/MAGIC-HMO arXiv 2511.15408 · onomastics · Bell 1984 (audience design, register).
- Cross-link slug: `[[anima]]`.

## Machine output (`--json`)
```json
{"subject":"<…>","class":"<…>","register":"machine|agent|human",
 "decision":{"name":"<system-name>","soul_name":null,"confidence":0.0,"sovereign":true},
 "scorecard":{"correctness":{"taxonomy":"PASS","…":"…"},"resonance":{"pronounceability":"PASS","…":"…"}},
 "rejected":{"name":"<…>","why":"<…>"},"citations":["<url>"],
 "verdict":"NAMED|HITL_RANKED|DEFER","human_domain":false,"_agent_feedback":"<hints>"}
```
Exit: `0` named · `1` error · `2` HITL-ranked (data gap).

## Changelog
| Version | Date | Change |
|---|---|---|
| 1.0.0 | 2026-06-06 | **Clean refactor `nomenclator` → `anima`** (the namer) per operator directive 2026-06-06 (0 prior real uses ⇒ no backward-compat; "O Batista"/"Baptist" was religion-coded ⇒ failed secular global-universal convention; consolidate the persona-zoo into ONE lean identity). NEW: §0.5 **Register Gate** (deterministic object-class→register; consumes `language-policy-en-pt` §7 SSOT; numeric warmth-tuning deferred KISS) · §3.2 **4 resonance aspects** (pronounceability · memorability · evocation · fluency — measurable, not vibes; scored only for human register — the "pitada de humanidade") · §3.3 **soul+identity rubric** · §3.4 **envelope-safety** (system-name vs soul-name; dual-name as a capability, not self-applied) · §6.5 **Forge↔Anima synergy** (body↔soul; forge Phase-4 delegates + passes type→register hint; DRY single engine). Persona-zoo removed. Re-baptism dogfood (§7): `anima` 12/12 + soul-rubric, rejected `onoma`/`kerux`/keep-nomenclator. `git mv` preserved history. 6/6 self-validity + 8/8 anti-theater + 6/6 scope-discipline. |
| 0.1.0 | 2026-06-05 | Bootstrap as `nomenclator` ("O Batista") — forged via `/enhance` → `agentic-tool-forge`. Sovereign precision-naming engine: 12-aspect scorecard · 33-Socratic · research-first sovereignty · sub-adapters + self-extending KB · self-baptism. (Superseded by v1.0.0 refactor.) |
