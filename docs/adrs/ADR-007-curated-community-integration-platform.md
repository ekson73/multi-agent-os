# ADR-007: MAOS as the curated community-integration platform (the trusted front-door)

- **Status**: **Exploratory / DRAFT (FROZEN)** — demoted from "North Star" on 2026-06-28 by the goal-loop (critical-analysis + solutions-debate + cascade confidence gate **0.75 < 0.85 → escalate**). **DRAFT = frozen: no implementation until re-ratified** (gated on a real demand signal + the first integration proving the gate). The atomic core ships via **ADR-006**; this platform identity is **earned, not declared**.
- **Date**: 2026-06-28
- **Deciders**: Operator (Emilson de Queiroz Moraes / ekson73) + Claude (Cowork), via HITL co-design (~5-turn dialogue)
- **Scope**: Strategic identity of the `maos` framework. Extends **ADR-006** (MAOS Hub). The operator-facing console + the community-integration motion are the two human/inbound faces of the same MAOS Hub gating network.
- **SSOT**: `docs/vision/maos-integration-platform.md` (narrative) · `openspec/changes/maos-hub-console/` (console contract) · `openspec/specs/maos-hub-registry/spec.md` (registry contract). · Closure: `research/agentic-moe-2026/20260628-goal-loop-closure.md`.

```bash
# /**
#  * Rebaixar ADR-007 de "North Star ratificável" para "Draft exploratória (frozen)".
#  * @context goal-loop 2026-06-28: 9 experts em 2 turnos (forge+persona-pipeline; Jeff-Dean/Sam-Altman/
#  *          Steve-Jobs; cascade 4 lentes) convergiram; gate de confiança agregada = 0.75 < 0.85 → escalar.
#  * @reason Anti-theater + honestidade: "front-door confiável do commons" é promessa a se GANHAR (pull +
#  *          1a integracao provando o gate), nao a declarar com <1K stars e demanda N=1. Self-fix reversivel-in-scope.
#  * @impact Identidade-plataforma congela; nucleo atomico (ADR-006) segue ratificavel; foco no MVP/wedge.
#  */
```

## Context

ADR-006 made MAOS a native MoE gating network (the MAOS Hub). This ADR names what the Hub is *for*
the wider world. The agentic ecosystem is exploding: an infinity of humans + agents ship good tools,
fragmented across GitHub / marketplaces / harnesses, with **no trusted curator** that is
security-aware, use-case-aware, freshness-aware and harmony-aware. The operator is **lost**: they
don't know what is good, good-for-what, when to use it — they often don't know a solution *exists*.
Our own `agentic-moe-2026` research is the proof: it took a full deep-research project, with a
supply-chain gate, just to map what is good. If *we* needed that, the operator is adrift.

So MAOS becomes **more than a producer of solutions** — it becomes the producer of the
**meta-solution**: the **all-in-one trusted front-door** to the *vetted best* of the commons. We keep
building our own tools **and** we curate/integrate the community's best.

```bash
# /**
#  * Adotar a identidade "plataforma curadora-integradora confiável" como North Star do MAOS.
#  * @context Gap real e vivido (a própria pesquisa ATH é a prova); nenhum curador confiável ocupa o lugar.
#  * @reason O valor não é criar mais um tool — é o front-door que resolve discovery+confiança+contexto.
#  * @impact MAOS = índice+gate+adapter+guia do melhor do commons; curadoria AGÊNTICA, ratificação HUMANA.
#  */
```

## Decision

**MAOS is the curated, security-gated, agentically-maintained front-door to the best of the agentic
commons** — an *index + gate + adapter + guide*, not a re-host. Three faces of one MAOS Hub:

1. **Integrator (inbound)** — discover → vet → adapt → register the community's best.
2. **Registry (SSOT)** — the vetted knowledge: per tool, *what · good-for-what · when · which
   phase · conflicts · risks · mitigations · guardrails · activation · license · provenance · ttl ·
   rollback* (`openspec/specs/maos-hub-registry/spec.md`).
3. **Console (operator-facing)** — projects the registry for the human: views by preset / category /
   use-case / **context-aware** / **prose-intent (guided interview)** / **safe-mode**; the operator's
   **profile is a first-class INPUT to the gating** (teeth in *our* hub layer, not the harness).

### Operating model — agentic curation, human ratification ("two of us" is enough)
The lifecycle family does the legwork; the human is the HITL ratifier:
`agentic-tool-intake/pipeline` (discover + decide) → deterministic security floor
(`.github/workflows/supply-chain-sentinel.yml` + `ai-governance-linter.yml` + gitleaks + sandbox) →
**contribution-gatekeeper** agent (triage, never sole decision) → `agentic-tool-evaluator` →
`dogfood-ledger` (promotion gate) → `ttl-policy` (freshness/auto-deprecate). **The integrator is
built BY the agents it integrates.**

### The 7 guardrails (non-negotiable — the survival conditions of a trusted hub)
1. **Reject-by-default.** The gate's default verdict is DEFER/REJECT; integration is the rare
   exception that EARNS its way. "Best vetted few, contextualized" — never "everything trending".
2. **No agent alone on security.** The gatekeeper is advisory triage ON deterministic floors + HITL;
   the reviewer-agent is itself an injection target. Never auto-accept untrusted external code.
3. **Real license classification.** Classify SPDX + compatibility (copyleft AGPL/GPL × permissive ×
   NONE/all-rights-reserved × custom); record in `THIRD_PARTY_NOTICES`/SBOM. Never assume MIT
   (the research found NOASSERTION / AGPL / NONE among top tools).
4. **Adapt the adapter, not the tool.** Vendor upstream pinned + provenance; put our changes in a
   thin **slot-adapter** we own; keep upstream pristine + update-trackable + isolated (single-conductor).
5. **Honor the creator (for real).** Enforce `docs/co-author-standard.md` in commits + attribution in
   the registry + `THIRD_PARTY_NOTICES` + thanks. Ethos (os3pd respect / AAIF) and strategy (goodwill → contributions).
6. **Rollback as DoD.** No integration merges without a documented fallback/rollback path — for
   every item, including MAOS's own forged tools (symmetric, boy-scout).
7. **TTL + hardened distributor.** Every integration carries a TTL + re-validation cadence;
   stale/abandoned/compromised upstreams auto-flag + eject (the GSD/MemPalace lesson). MAOS-as-trusted
   -distributor is itself a target → signed releases + SBOM + provenance.

### `activation` taxonomy (per tool, in the registry)
`always-on` (substrate/floor — MAOS-owned OR license-clean + conflict-free + low-attack-surface) ·
`default-on-for-context` (conditional) · `opt-in` (operator-selected) · `excluded`.
Third-party reaches `always-on` only past the license + conflict + attack-surface gates.
*Worked example — `andrej-karpathy-skills`*: NOT a blind always-on (license=NONE; L0 collision with
MAOS's own guardrail; coding-context fit). Resolution: **internalize the principles natively + credit
the inspiration** (ideas aren't copyrightable; honor the source); treat the repo as `opt-in` /
`default-on-for-context` (coding), reconciled by precedence.

## Consequences

- **Positive**: a defensible, differentiated identity (the trusted front-door no marketplace/awesome-
  list occupies); discovery + education as the wedge; ~80% reuses the lifecycle family + os3pd +
  co-author-standard + ttl-policy + the supply-chain CI (DRY, not a new empire).
- **Negative (named honestly)**: this is a **curation-trust-freshness** product — a perpetual
  editorial + security operation. The moat is judgment + freshness + trust, and **one bad integration
  that slips the gate destroys the trust that is the whole value**. The 7 guardrails are the price.
- **Roadmap**: realized as new waves in the Claude-Code handoff (registry SSOT → console/control-plane
  → integrator + contribution-gatekeeper), after the WAVE-0 safety foundation of ADR-006.
- **Status discipline**: Proposed; ratify via PR (squash-merge, human gate, ADR-004). MVV/Vision edits
  to `CLAUDE.md` are HITL-escalated to the ratifying PR.

## References
- Companion: `docs/adrs/ADR-006-ath-moe-hub-adoption.md` (MAOS Hub) · ADR-004 (GitHub Flow) · ADR-005 (dogfood ledger).
- Vision: `docs/vision/maos-integration-platform.md`. Contracts: `openspec/changes/maos-hub-console/` + `openspec/specs/maos-hub-registry/spec.md`.
- Evidence: `research/agentic-moe-2026/` (the landscape + the supply-chain lesson). Family: `skills/agentic-tool-{intake,forge,evaluator,trainer,pipeline}` + `dogfood-ledger` + `ttl-policy` + `os3pd-manifesto` + `co-author-standard`.

---
*ADR-007 · co-designed by operator + Claude (Cowork) over a ~5-turn HITL dialogue · 2026-06-28 · ratify via PR.*
