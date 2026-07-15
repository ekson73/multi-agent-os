# Democratic-Governance Models — Reference for Composing Councils (Prisma-filtered)

> **Type**: on-demand reference doc (cited, **not** auto-loaded — on-demand reference knowledge belongs in a doc, not a rule/skill).
> **Version**: 1.0.0 (2026-07-14)
> **Naming**: machine-register descriptive slug (a file identifier is machine-register ⇒ precise descriptive slug, no soul-name).
> **Consumed by**: the pre-HITL council-authorization gate — `council-gate` / *Boule*, proposed in **companion PR #255** (⚠️ **not present in this repo state**; every mention below is a forward-reference to that PR, never an in-repo path) — at its council-composition step, plus the loop family (goal/gap/ooda-loop · quiesce · auto-orchestrator · auto-pilot).
> **Provenance**: distils + Prisma-filters an **operator-curated scholarly consolidation of democratic organizational models** (academic typologies · real institutional forms · administrative machinery · fictional archetypes). That consolidation is a machine-local research **input**, deliberately not a repo artifact.
> **Auditability** (how to check this doc without the input): every verdict in §2 is re-derivable from (a) the five leaves in §1 and (b) the archetype's **public** definition — see the verifiable anchors in §7 (Lijphart · Athenian sortition · Roman consulship · Ombudsman 1809 · GDPR Art.22/LGPD Art.20). The private consolidation supplied the *candidate list*, not the *audit basis*.

## §0 — What this is / is NOT (DRY boundary)

This is the **knowledge base of democratic-governance MODELS** — a catalogue of *how democratic bodies organize authority*, filtered to the genuinely-useful, with a deterministic filter methodology and a model→agent mapping. It is **not** the authorization gate: the *decision* mechanism (should an action be auto-authorized in place of the human, or go to HITL?) is `council-gate` / *Boule* (**companion PR #255**), which this doc **cites, never duplicates**. Relationship: *Boule is the gate; this is the models KB its council-composition draws on.*

Its durable value: for each future council-roster expansion, filter the candidates **here, deterministically** (§1) instead of re-researching — closing the re-research/re-duplication loop that has recurred across sessions.

## §1 — The Prisma filter (decompose "useful · beneficial · non-toxic" → measurable)

Each candidate archetype is scored against **five measurable leaves** (per the in-repo skill `decompose-abstract-to-measurable` / *Prisma* — decompose an abstract criterion into checkable leaves rather than eyeball a verdict).

| # | Leaf | Checkable test |
|---|---|---|
| L1 | **distinct-contribution** | Contributes something the gate lacks. Two passing forms, which the verdict rule (below) distinguishes: **(a) mechanism** — a new authorization mechanism; **(b) framing** — names/organizes an existing-but-unnamed cluster, adding **no** new machinery. A re-wrap of a tier/seat the gate already has in both mechanism *and* name fails L1. |
| L2 | **democratic-eligible** | Deliberative / dispersed-power / accountable. Rejects dictatorial · monarchy · absolute-power · hereditary-authority (the operator's exclusion; and personas are behavior-lenses, never appeals-to-authority). |
| L3 | **non-toxic** | Does NOT concentrate power, enable capture/collusion, or weaken a guardrail (⛔ deny-set / Layer-1). |
| L4 | **implementable-on-existing** | Composes existing maos agents/skills, or a genuinely-thin new mechanism (native-over-custom). |
| L5 | **autonomy-positive** | Raises the safe auto-authorization band **OR** strengthens the fail-safe, without eroding the boundary (measurable via the observability protocol: safe-auto-authorize-rate ↑ while authorize-then-regret held at 0). |

### Verdict rule (deterministic — every verdict below is derivable from the marks, no judgment call)

Evaluate L1→L5 **in order**; the **first ✗ short-circuits** (remaining leaves are then not evaluated).

| Verdict | Rule |
|---|---|
| **ADOPT (mechanism)** | L1 ✓ *via form (a)* ∧ L2 ✓ ∧ L3 ✓ ∧ L4 ✓ ∧ L5 ✓ |
| **ADOPT (framing)** | L1 ✓ *via form (b)* ∧ L2 ✓ ∧ L3 ✓ ∧ L4 ✓ ∧ L5 ✓ — adopted as taxonomy only; ships no machinery |
| **ALREADY-EMBODIED** | L1 ✗ *because the gate already implements it under its own name* ⇒ no new work (a confirmation, not an adoption) |
| **REJECT** | any of L2..L5 ✗ ⇒ rejected, naming the first failing leaf |

**Mark legend** (the only marks used — no undefined states): `✓` leaf passes · `✗` leaf fails · `n/e` **not evaluated** (an earlier leaf already failed and short-circuited).

## §2 — Prisma-filtered archetype catalogue

Applying §1 to the model space (families drawn from the academic-typology, real-institutional, and fictional-archetype axes):

| Archetype (family) | L1 | L2 | L3 | L4 | L5 | Verdict (per the §1 rule) |
|---|:--:|:--:|:--:|:--:|:--:|---|
| Consensual democracy (dispersed power · veto-players · coalitions; Lijphart) | ✗ | n/e | n/e | n/e | n/e | **ALREADY-EMBODIED** — this *is* the gate's convergence; no new work |
| Ministries / portfolios (Finance · Foreign · Defense · Justice · Interior · Economy …) | ✗ | n/e | n/e | n/e | n/e | **ALREADY-EMBODIED** — this *is* the gate's seat roster; expand seats selectively (§4) |
| **Cross-veto / dual-executive** (Roman *consul* — paired, mutual-veto, term-limited) | ✓ (a) | ✓ | ✓ | ✓ | ✓ | ✅ **ADOPT (mechanism)** — a 2nd independent verifier with veto on the highest-stakes cleared actions (§5.1) |
| **Sortition / rotation** (Athenian assembly — sortition + rotativity) | ✓ (a) | ✓ | ✓ | ✓ | ✓ | ✅ **ADOPT (mechanism)** — rotate seats to defeat a pre-jailbroken/colluding council (§5.2) |
| **Independent oversight authorities** (Ombudsman [SE 1809] · audit · rights-protection · intelligence-*under-democratic-oversight*) | ✓ (b) | ✓ | ✓ | ✓ | ✓ | ✅ **ADOPT (framing)** — names the gate's existing verifier + red-team + observability + DPO as one cluster; no new machinery (§5.3) |
| **Diplomatic / multilateral** (embassies · foreign-relations · UN-style assembly with executive council) | ✓ (b) | ✓ | ✓ | ✓ | ✓ | ✅ **ADOPT (framing)** — inter-body relations = the gate's family-wiring (§5.4) |
| Weighted / reputation voting ("algorithmic citizenship" — votes weighted by reputation/contribution/expertise) | ✓ (a) | ✓ | ✗ | n/e | n/e | ❌ **REJECT (L3)** — weighting concentrates power + is Goodhart-gameable; flat convergence + stakes-scaled selection is safer |
| Hive / ecosystem / network democracy (emergent-signal, habitat/node seats) | ✓ (a) | ✓ | ✓ | ✗ | n/e | ❌ **REJECT (L4)** — its L1-passing mechanism is genuinely distinct (**emergent-signal aggregation** over node/habitat seats, with *no* deliberation step — which the gate does not implement), but it would need new machinery, while the gate's *deliberative* convergence already serves the same decision purpose more auditably (YAGNI) |
| Delegative · illiberal · strong-executive-majoritarian | ✓ (a) | ✗ | n/e | n/e | n/e | ❌ **REJECT (L2)** — concentrates power / erodes horizontal controls |
| Regent (regency / hereditary) · Dictator (absolute, even if time-boxed) | ✓ (a) | ✗ | n/e | n/e | n/e | ❌ **REJECT (L2)** — monarchy/hereditary · absolute-power (the operator's explicit filter) |

**Result: 4 genuinely-additive enrichments** (§5 — 2 mechanism + 2 framing) + 2 confirmations that the gate's convergence and seat-roster already embody the consensual/ministerial cores. Not 30 bodies — the anti-theater outcome.

## §3 — The 7 modeling dimensions (describe any democratic body)

For composing/classifying a seat or body (from the consolidation's practical modeling taxonomy):

1. **Legitimacy source** — plebiscitary · parliamentary · mixed · corporate · segmentary.
2. **Representation unit** — individual · territory · party · identity-group · guild · **domain-expertise** (the agentic analog) · network-node · ecosystem.
3. **Executive structure** — monocephalic · **dual (cross-veto)** · collegiate · distributed.
4. **Centralization** — unitary · federal · confederal · multilevel · polycentric.
5. **Administrative apparatus** — ministries · secretariats · departments · agencies · **independent authorities** · public enterprises.
6. **Decision mechanism** — simple-majority · qualified-majority · **consensus/convergence** · **cross-veto** · **sortition** · deliberation · algorithm (deterministic guard) · emergent-signal.
7. **Citizenship scope** — human · interspecies · corporate · ecological · **machinic** · **hybrid** (the cowork-team: humans + agents).

Bolded values are the ones relevant to an agentic pre-HITL council.

## §4 — Portfolio → seat mapping

The gate composes seats from **existing** maos agents (forge only a genuinely-distinct gap). The authoritative role→agent SSOT is [`agents/README.md`](../agents/README.md) "Role Coverage Map"; this doc adds the broader **portfolio → seat** view.

The **Existing agent seat(s)** column contains **only literal agents** (SSOT names). Anything that is *not* an agent — framing, a protocol, a process, or a gap — is kept in the separate **Non-agent element** column, so the role→agent mapping stays mechanically usable.

| Portfolio / body | Seat function | Existing agent seat(s) | Non-agent element |
|---|---|---|---|
| Finance · Economy · Accounting | cost / budget / resource lens | — | **gap** (documented, not forged; nearest agent `agile-product-lead` covers value/priority, *not* cost) |
| Foreign relations · Diplomacy | inter-body / cross-org / family relations | — | **framing** (§5.4) — the family-wiring, not a seat |
| Defense · Interior / Security | security / threat lens | `governance-auditor` · `architecture:security-reviewer` | — |
| Justice | compliance / rights adjudication | `data-privacy-officer` (LGPD/GDPR) · `governance-auditor` | — |
| Intelligence / oversight (Ombudsman · audit) | independent verify + red-team + observability | `governance-auditor` · `data-privacy-officer` | **process**: red-team · **protocol**: the observability protocol (*Metron*, external — §7) — agents + these together = the oversight cluster (§5.3) |
| Science / Tech · Industry | build / architecture lens | `architecture:architect` · `quarkus-backend-engineer` · `react-frontend-engineer` · `supabase-engineer` | — |

Genuine gaps (documented, **not forged** — forge only if the nearest seat proves insufficient in dogfooding): a dedicated Finance/Economy lens; a generic-Postgres / Neon / Aurora DBA seat (the agent roster in this repository state is Supabase-bound).

## §5 — The 4 genuinely-additive enrichments (for the pre-HITL gate)

Offered to `council-gate` / *Boule* (**companion PR #255**) for incorporation — each maps to a section of that PR's proposal. Framing/safeguards, not competing mechanisms.

1. **Cross-veto / dual-executive safeguard** *(mechanism)* — on the *highest-stakes cleared* actions, require a **second, independent** verifier that can **veto** (Roman dual-consul mutual-veto). *Strengthens the fail-safe* (a 2nd independent gate on the residual risk within the already-cleared band). → the gate's triple-check / council sections.
2. **Sortition / rotation anti-capture** *(mechanism)* — select/rotate council seats **deterministically** (by index/hash, not model-judged) so no *fixed* set can be pre-jailbroken or collude (Athenian sortition). *Directly defends the gate's confused-deputy thesis* (a converging council is jailbreakable as a unit — a rotating one is a moving target). → the gate's seat-selection section.
3. **Oversight-authority taxonomy** *(framing)* — name the existing independent-verifier + red-team + observability + DPO as one **"democratic oversight authority"** cluster (Ombudsman + intelligence-*under-democratic-oversight*). **Framing, no new machinery.** → the gate's independent-verifier / red-team / observability sections.
4. **Diplomatic / family-integration framing** *(framing)* — model the gate's family-wiring (its deferred loop integration) as **"diplomatic relations between authorization bodies"** (multilateral/UN assembly + executive council). → the gate's integration section + the loop family.

**The L5 leaf (`autonomy-positive`), per contribution kind** — all four pass L5, but the *strength* of the claim differs by kind, and saying so is the honest part:

- **Mechanism (#1 · #2) — measurable**: they *strengthen the fail-safe*, which is precisely what lets the gate safely widen its auto-authorization band while holding **authorize-then-regret at 0** (an observability SLI, §7) — an honest autonomy gain, not theatre.
- **Framing (#3 · #4) — enabling, not measurable**: **#3** makes the fail-safe's *completeness* auditable — a scattered, unnamed oversight set cannot be checked for holes *before* the band widens, so naming the cluster is a precondition for widening it responsibly. **#4** lets one authorization decision be *handed across* the loop family instead of each loop escalating to HITL independently — fewer independent HITL escalations for the same work. Neither carries an SLI of its own; both are recorded here as **enabling** claims so that their `L5 ✓` is *derivable from a stated rationale* rather than asserted.

## §6 — Rejected patterns (logged, per §1)

- **Weighted / reputation voting** — fails L3 (non-toxic): vote-weighting concentrates power and is Goodhart-gameable; the gate's flat convergence + stakes-scaled seat-selection is the safer equivalent.
- **Hive / ecosystem / network democracy** — passes L1 on a genuinely distinct mechanism (**emergent-signal aggregation** over node/habitat seats, with no deliberation step — the gate implements no such thing), then fails L4 (implementable-on-existing / YAGNI): that mechanism would need new machinery, while the gate's *deliberative* convergence already serves the same decision purpose more auditably. *(Not `ALREADY-EMBODIED`: the gate's convergence is deliberative, so it does not embody emergent-signal aggregation — the L1 test is about the mechanism, and this one is absent.)*
- **Delegative / illiberal / strong-executive-majoritarian** — fails L2: erodes horizontal controls (the opposite of what a pre-HITL fail-safe needs).
- **Regent · Dictator** — fails L2: hereditary/monarchy · absolute-power (the operator's explicit exclusion).

## §7 — Refs

**In-repo** (verifiable here):
- **Filter**: the `decompose-abstract-to-measurable` skill (*Prisma*) — abstract criterion → measurable leaves.
- **Agent SSOT**: [`agents/README.md`](../agents/README.md) "Role Coverage Map" (the §4 seat names).

**Companion PR** (not in this repo state):
- **The gate this doc serves**: `council-gate` / *Boule* — **PR #255**. This doc informs its council-composition; it is NOT a second gate.

**External — operator user-scope governance rules** (cited by slug as provenance/discipline; they live in the operator's user-scope rule corpus, **outside this repository**, so they are named rather than linked): `anti-theater-grounding-protocol` (abstract-criterion → measurable; the reality bar) · `scope-discipline` (doc-vs-skill placement) · `layer-precedence-policy` (cite, don't duplicate) · `over-engineering-circuit-breaker` (thin-over-elaborate) · `reuse-and-elevate-protocol` (extend, don't reinvent) · `naming-authority` (the naming register-gate) · `agentic-observability-protocol` (*Metron* — the §5 autonomy SLIs).

**Anchors (public + verifiable — the §2 audit basis)**: Lijphart *Patterns of Democracy* (majoritarian/consensual) · Athenian sortition + rotation · Roman consulship (paired mutual-veto) · Swedish *Justitieombudsman* (1809) · GDPR Art.22 / LGPD Art.20 (solely-automated-decision oversight; SCHUFA CJEU C-634/21) · OECD "machinery of government".
