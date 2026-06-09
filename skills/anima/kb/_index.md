# Anima KB — adapter index + routing + 33-Q + self-extend protocol

Adapters carry per-discipline naming conventions. The engine classifies the `<subject>`'s object-class, routes the
matching adapter, and applies its conventions on top of the universal 12-aspect scorecard (`../SKILL.md` §3).

## Routing table (object-class → adapter)
| If the subject is a… | Route |
|---|---|
| database · schema · instance · table · column · field · index · constraint · relationship · key | `databases.md` |
| skill · command · agent · subagent · mcp · plugin · marketplace · rule · hook | `agentic-tools.md` |
| product · brand · startup · app · service · domain · package · library (public) | `brand-product.md` |
| directory · path · file · variable · function · module · class · protocol · methodology · framework · acronym · mnemonic · alias · nickname · doc · manifesto · media · prompt · *(anything else)* | `general` (inline default below) |

**`general` default** (no dedicated file — applies the universal house-form): kebab-case · ≤6 words · role-typed ·
descriptive · no operator-personal names (universal #10) · family-aligned if `--family` given · `--lang` per
`language-policy-en-pt` (en-US technical/global; pt-BR Brazil-specific). Acronyms: expand once on first use.

## §33Q — the interrogation lens-set (SKILL §2, expanded)
11 dimensions × 3 depths (`is · should-be · must-not-be`) = 33 questions the engine answers about the subject
BEFORE generating candidates (it does not print all 33 unless explicitly asked):

| Dimension | *is?* | *should-be?* | *must-NOT-be?* |
|---|---|---|---|
| purpose | what is it for | what must the name evoke | what purpose must it not imply |
| objective | measurable goal | name must carry | must not over-claim |
| root-problem | what it solves | name should hint | must not name the symptom |
| context | where it lives | name must fit | must not clash with neighbours |
| scope | how broad | name must match | must not be too narrow/broad |
| temporality | how long it lives | durable vs dated | must not date if meant to last |
| authority | who owns naming | who may pronounce | must not usurp a reserved owner |
| authorization | is naming allowed | within rights | must not infringe (trademark/reserved) |
| right-to-name | is the token free | available/collision-free | must not collide |
| capability | does the name carry the function | yes | must not mislead |
| competence | idiomatic for the class | yes (adapter) | must not break the convention |
| resilience | survives rename pressure | yes | must not need re-baptism next week |
| gaps/pendencies/failures/anti-patterns | known risks | name must dodge | must not encode a known anti-pattern |

## Self-extend protocol (operator directive — learn-and-persist)
When a request's object-class is NOT covered by any adapter above:
1. Research the new domain's naming conventions on the web (charset · case · length · reserved · idioms · prior art).
2. Decide the name (full §3/§4 pipeline).
3. **Persist** a new `kb/<domain>.md` adapter: `## Conventions` · `## Reserved/limits` · ≥1 cited source ·
   `## Worked example`. Append a routing row above + a row to `../SKILL.md` §6 adapter table.
4. Bound: **1 new adapter per request** (Goldilocks — never pre-build 60). Idempotent (skip-if-identical).
