# Anima ∘ Prisma — Dogfood Round 2 (2026-08-10)

## Setup
- Prisma: `multi-agent-os/skills/decompose-abstract-to-measurable` + `scripts/aggregate_spec.py`
- Specs: `examples/naming-*.json`
- Command: `python3 …/aggregate_spec.py --spec <spec.json>` (use JSON out; `--md` is markdown)

## Cycle 1 — Hub rename (distribution catalog)

| Candidate | score | band | conf | inconclusive |
|---|---:|---|---:|---|
| **eko-plugin-marketplace** | **0.875** | **HIGH** | 0.873 | no |
| eko-pack-index | 0.445 | LOW | 0.878 | **yes** (`conflict:root`) |

**Decision corroborated:** keep `eko-plugin-marketplace`. Opaque interim fails measurable gloss+continuity.

## Cycle 2 — Agentic-tool skill name (control + negative)

| Candidate | score | band | conf | inconclusive |
|---|---:|---|---:|---|
| **bitbucket-pipeline-watch** | **0.942** | **HIGH** | 0.944 | no |
| bb-helper | 0.478 | LOW | 0.919 | **yes** (`conflict:root`) |

**Decision corroborated:** role-typed vendor+object+verb beats vague helper. Prisma applies cleanly to **agentic-tool** class, not only hub renames.

## Review / fixes from dogfood
1. **Template** `templates/naming-fitness.measurement-spec.json` — reusable across classes.  
2. **Class routing table** in Anima §4.5 (hub · skill · db · path · server).  
3. **Rule:** band LOW or `inconclusive.flag` ⇒ cannot be sole winner (HITL or next candidate).  
4. **Skip still stands** for pure machine conventional names (`user_id`) — no tree.  
5. Do not use `--md` when expecting JSON machine out.

## Dogfood ledger
- anima-prisma-compose cycle 001 complete (hub rename pair)
- anima-prisma-compose cycle 002 complete (skill name pair)
