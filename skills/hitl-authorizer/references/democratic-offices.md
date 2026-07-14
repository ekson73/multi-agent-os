# The Democratic Authorization Republic — office catalogue

> **What this is.** The `hitl-authorizer` (soul **Tribune**) broker is not a single authority — it enacts a **democratic separation-of-powers ladder** of authorization offices. This file is the **per-office SSOT**: for each office it computes, individually, its **context · scope · rights · authorization · breadth (abrangência) · authority**, the primitive that realizes it, and whether it runs by default. It also records the offices **rejected** by the democratic filter (with rationale) and the **constitutional invariants** no office may violate.
>
> **Design law (Gordian / `agentic-first §4.7.7`):** an office earns its existence only if it maps to a **distinct** existing primitive OR adds **genuinely-new** authority. The bounded offices are therefore **named SEATS over existing primitives** (no re-wrapped engines); only the operator-gated **Prime-Minister** is a genuinely-new mode. Naming = Anima's call (`[C-naming]` / `naming-authority`) — the office soul-names ARE the sourced democratic civic archetypes.

## §1 — The democratic filter (the admission criterion)

> **Operator directive (2026-07-14, verbatim pt-BR):** *"somente considere os que tiverem caracter democrático, ignora todos os que possuam caracter ditatorial/monarquia/poder-absoluto/herança-de-autoridade-por-parentesco; os que tiverem super-powers tipo [regent, prime-minister] não deixar default, somente se invocado/acionado/command pelo usuário/operador hitl."*

An office is **admitted** iff its archetype is **democratic** — ALL of:
- **Elected / appointed-and-accountable** (not by inheritance/kinship).
- **Bounded + checked** (subject to veto, no-confidence, term, or collegial mutual-veto).
- **Term-limited / revocable** (no perpetual or absolute authority).

An office is **rejected** iff it has **dictatorial · monarchy · absolute-power · hereditary-by-kinship** character (§4).
A super-power office (elevated authority) is admitted **only as operator-gated, non-default** (§3, invariant #2).

Sources: [Roman Republic structure (Lumen)](https://courses.lumenlearning.com/atd-herkimer-westerncivilization/chapter/structure-of-the-republic/) · [Motion of no confidence (Wikipedia)](https://en.wikipedia.org/wiki/Motion_of_no_confidence) · [Regent (Wikipedia)](https://en.wikipedia.org/wiki/Regent) · [Roman dictator (Wikipedia)](https://en.wikipedia.org/wiki/Roman_dictator) · [Sortition & citizens' assemblies (Sortition Foundation)](https://www.sortitionfoundation.org/what). Substrate prior-art: [AgentCity — Constitutional Governance via Separation of Power (arXiv)](https://arxiv.org/pdf/2604.07007) · [Tiered AgentRunner Framework (arXiv)](https://arxiv.org/pdf/2605.10223).

## §2 — The office ladder (admitted — each individually scoped)

| Office (soul) | Democratic basis (sourced) | Context — when convened | Scope — what it decides | Rights / Authority | Breadth (abrangência) | Default? | Realized by (reuse — no new engine) |
|---|---|---|---|---|---|---|---|
| **Tribune** | *tribunus plebis* — elected popular check; veto/*intercessio* on behalf of the people; sacrosanct-but-bounded | EVERY escalation (the front-door) | intercept → `bin/classify.sh` → authorize the residue OR refer up the ladder | MAY authorize residue @ **≥0.90**; veto/refer; **NEVER a carve-out** | one escalation at a time | **DEFAULT (always-on)** | the skill itself + `bin/classify.sh` (built) |
| **Parliament** | parliamentary assembly — elected reps debate + **vote**; majority rules, minority-report preserved | Tribune can't authorize alone (MEDIUM / genuine uncertainty) | deliberate → converge → **vote** on the authorization | majority authorizes; dissent recorded | the pending decision | DEFAULT (the council tier) | `maos:perspective-trio` · `maos:persona-pipeline` · `skills/converge` · `skills/convergence-engine` |
| **Ombudsman** | independent accountability officer — investigates + checks power on citizens' behalf | any AUTHORIZE candidate needs an independent check | audit the proposed authorization; represent the affected party | **independent** verify (verifier > generator); **veto** power | one verdict | DEFAULT (the verify seat) | `maos:persona-pipeline` verify-stage · `skills/red-team` (Elenchus) on hard-triggers · `bin/convergence-guard` |
| **Consul** | Roman consul — elected, one-year term, **collegial with mutual veto to prevent tyranny** | high-stakes-but-reversible, broad-scope residue (opt-in) | a **paired** decision; **either consul vetoes** | mutual-veto pair (each can block the other) | one high-stakes decision | **OPTIONAL** — operator `--consul` | two INDEPENDENT council runs + mutual-veto |
| **Prime-Minister** | head of government — accountable to parliament, **removable by no-confidence**, non-hereditary | **ONLY** when the operator invokes `--prime-minister` | form a stronger "government" (max-diversity council + `consultants`) + decide harder cases the bounded tier deferred | **elevated** authority — **STILL bounded by the carve-outs** (invariant #1) | one operator-commanded decision | **OPERATOR-GATED (non-default)** | stronger council + `maos:consultants:*` |
| **Referendum** | direct democracy — the sovereign **people** decide directly | the ladder cannot resolve (a carve-out OR the residue) | = escalate to the operator | the operator decides | — | the **FALLBACK** (the whole point of HITL) | HITL (`AskUserQuestion`, `end-of-action-briefing §7.1` — ranked recommendation, never a blank ask) |

**Note — Jury / sortition** is *not* a separate seat: the random, diverse panel is already **how** Parliament/Ombudsman diversify (multi-axis diversity, `agentic-first §4.7.5`). Adding a separate "Jury" office would re-wrap the same diversity primitive → rejected as over-engineering (Gordian), while its democratic principle (diverse random deliberation) is honored inside the council.

## §3 — Per-office detail (the "calcule individualmente para cada" computation)

### Tribune — the elected popular check (DEFAULT)
- **Context**: fires on *every* escalation that would otherwise fall back to a human (a loop's `STOP-HITL`, an `AskUserQuestion`, an autonomy-band pause).
- **Scope**: intercept → run the deterministic gate → authorize the **uncertainty-residue** OR refer up. NEVER decides a carve-out.
- **Rights**: the *intercessio* — interpose between a decision and its execution, or refer it up. **Right of veto** (defer). NO right over the human-owned classes.
- **Authorization**: MAY substitute the human's *yes* on residue at **score ≥ 0.90 ∧ convergence ∧ independent-verify ∧ ¬carve-out ∧ anti-theater 8/8 ∧ CASC-green**.
- **Breadth**: one escalation; the caller retains accountability (`agentic-delegation`).
- **Authority**: bounded + revocable (like the historical tribune) — never a ruler.

### Parliament — the deliberative assembly (DEFAULT council tier)
- **Context**: the Tribune cannot authorize alone (MEDIUM band / genuine uncertainty).
- **Scope**: debate the residue across diverse lenses → converge → **vote**; majority carries, minority-report is preserved.
- **Rights**: collective deliberation; a majority authorizes, dissent is recorded (protected).
- **Authorization**: produces the convergence signal + `autonomy_score` the Tribune's ≥0.90 gate consumes. Does NOT itself substitute the human — it advises the Tribune's verdict.
- **Breadth**: the single pending decision; economic-stop `n*≤3-4` (term limit — invariant #4).
- **Authority**: representative + bounded; realized by `perspective-trio`/`persona-pipeline`/`converge` (no new engine).

### Ombudsman — the independent accountability officer (DEFAULT verify seat)
- **Context**: any AUTHORIZE candidate needs an **independent** check before the Tribune emits it.
- **Scope**: audit the proposed authorization; represent the "affected party"; on a hard-trigger, the audit **IS** the red-team (Elenchus, rewarded for breaking the artifact).
- **Rights**: independent **veto** — its refutation blocks the authorization.
- **Authorization**: satisfies the **verifier > generator** master condition (`agentic-first §4.7.2`); it never *grants*, it only *checks*.
- **Breadth**: one verdict; **must be independent of Parliament** (invariant #3 — separation of powers).
- **Authority**: accountability-only; realized by `persona-pipeline` verify-stage / `red-team` / `bin/convergence-guard`.

### Consul — the collegial mutual-veto pair (OPTIONAL, operator `--consul`)
- **Context**: a high-stakes but reversible, broad-scope residue where the operator wants a stronger check than the single Ombudsman without full Prime-Minister elevation.
- **Scope**: a **paired** decision — two independent council runs; either "consul" can veto the other.
- **Rights**: mutual veto (collegiality prevents unilateral tyranny — the historical consular check).
- **Authorization**: authorizes only if **both** runs converge AND neither vetoes; else DEFER.
- **Breadth**: one high-stakes decision; opt-in only (non-default).
- **Authority**: elevated-but-collegial; a lighter super-power than Prime-Minister.

### Prime-Minister — the accountable elevated executive (OPERATOR-GATED, non-default)
- **Context**: **ONLY** when the operator explicitly invokes `--prime-minister` (an agent routing an escalation can NEVER self-elevate — invariant #2).
- **Scope**: "form a government" — assemble a max-diversity council + `maos:consultants:*` archetypes + decide the harder cases the bounded tier deferred.
- **Rights**: elevated deliberative + decision authority — **but STILL bounded by the carve-outs** (invariant #1: even the Prime-Minister cannot authorize secrets/HUMAN_DOMAIN/merge-prod).
- **Authorization**: same ≥0.90 + independent-verify gate, over a stronger council; accountable (no-confidence-removable analogue = the operator can revoke at any word).
- **Breadth**: one operator-commanded decision.
- **Authority**: the strongest *admitted* office — democratically constituted (accountable, non-hereditary), never absolute. It is the **democratic replacement** for the rejected Regent/Dictator super-power.

### Referendum — the sovereign people (the FALLBACK = HITL)
- **Context**: the ladder cannot resolve — either a carve-out (invariant #1) or an irreducible residue after Score-Uplift.
- **Scope**: escalate to the operator.
- **Rights / Authorization / Authority**: the operator is sovereign; this is the deliberate ~10–15% residue that reaches a human, never faked-to-zero.
- **Breadth**: carries a ranked recommendation + justification (`end-of-action-briefing §7.1`).

## §4 — REJECTED offices (the democratic filter, made auditable)

| Office | Why REJECTED (fails the filter) | Its role is served *democratically* by… |
|---|---|---|
| **Regent** ❌ | "A regent is a temporary ruler who governs **on behalf of a [hereditary] monarch**… an interim arrangement until formal **succession**" → **monarchy + hereditary-by-kinship**. | the operator-gated **Prime-Minister** (elevated interim authority, but accountable + non-hereditary). |
| **Dictator** (Roman) ❌ | "endowed with **full authority / full powers of the state**, **subordinating the other magistrates**" → **absolute-power** (even though term-limited + Senate/tribune-checked). The filter excludes *poder-absoluto* explicitly. | Prime-Minister (checked elevated authority) + ultimately the **Referendum** (the operator). |
| **Monarch / King / Emperor** ❌ | hereditary, absolute — the archetype the filter names first. | — (no analogue; sovereignty stays with the operator/Referendum). |

**Why the rejections matter:** the operator listed *regent* and *prime-minister* together as "super-power" candidates. The filter resolves the tension: **Prime-Minister passes** (accountable, removable, non-hereditary) and is admitted as an operator-gated super-power; **Regent fails** (monarchical/hereditary) and is *not built* — its useful role (elevated interim authority) is re-homed onto the democratic Prime-Minister. This is documented so the filter is **auditable**, not asserted.

## §5 — Constitutional invariants (the checks-and-balances = the safety spine)

No office — not even Prime-Minister — may violate these. They are the democratic re-framing of the ⛔ carve-outs + the ECE guarantees:

1. **Inalienable rights (carve-outs).** The ⛔ classes — **secrets [un-liftable even by operator authorization], HUMAN_DOMAIN (`[C17] §2`), merge→main/prod** — are constitutional limits **NO office can override**. Enforced FIRST by the deterministic `bin/classify.sh` (a carve-out ⇒ `office=none`, `never_authorize=true`), **before any office convenes**. Proven by fixture `case-10` (an operator-invoked Prime-Minister on a secret still yields `office=none`).
2. **Anti-dictatorship (super-powers off by default).** Prime-Minister + Consul are **non-default**; only an explicit operator invoke (`.operator_invoke == true` / `--prime-minister` / `--consul`) unlocks them. The `fail_safe_default` = the bounded tier. Proven by fixture `case-08` (super-power requested without invoke ⇒ `office=bounded superpower_gated=true`).
3. **Separation of powers.** The Ombudsman (verifier) is **independent** of Parliament (generator) — verifier > generator (`agentic-first §4.7.2`), gated by `bin/convergence-guard`.
4. **Term limits.** Deliberation is economic-stopped at `n*≤3-4` (`agentic-first §4.7.6`) — no perpetual authority.
5. **Protected dissent.** Parliament's minority-report is preserved in the verdict/audit object.
6. **Accountability + transparency.** Every verdict (AUTHORIZE *and* DEFER) writes an ASH `decision-capture`; the **calling agent acts and retains accountability** (`agentic-delegation` — an AUTHORIZE substitutes the *yes*, never the responsibility chain).

## §6 — How the deterministic gate enforces the offices

`bin/classify.sh` emits two office-tier fields alongside the carve-out verdict:
- **`office`** — `none` (a carve-out — invariant #1) · `bounded` (default: Tribune→Parliament→Ombudsman) · `prime-minister` / `consul` (only when `operator_invoke=true` — invariant #2).
- **`superpower_gated`** — `true` iff an elevated office was *requested* but *refused* for lack of an operator invoke (the fail-safe fired).

The office-tier gate is **orthogonal to** the carve-out gate: the carve-out gate decides *whether a council may spawn at all* (safety-critical); the office-tier gate decides *which office convenes for the already-safe residue* (proportionality + anti-dictatorship). Elevation can **never** defeat a carve-out — it only changes which council convenes on residue the ≥0.90 gate already bounds. Fixtures `case-08`/`case-09`/`case-10` prove all three behaviors.

## §Refs
- Policy SSOT: `agents/COWORK-AUTONOMY-POLICY.md` (≥0.90 bar · carve-outs · Council-before-HITL ladder).
- Skill: `../SKILL.md` §Democratic Offices · gate: `../bin/classify.sh` · fixtures: `../tests/case-08..10`.
- Governance (user-scope, cited): `~/.claude/rules/hitl-authorizer.md` · `auto-merge-standing-authorization §1.1.1` · `[C17] §2` · `harmonic §0.5.1` CASC · `anti-theater-grounding-protocol §4`.
- Cross-link: `[[hitl-authorizer]]`.
