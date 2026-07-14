# praxis-audit — reference (rationale, proofs, dogfood log)

> On-demand companion to `SKILL.md` ([C07b] inline-vs-spec). SKILL.md is the lean
> operational entry (what an agent loads to run the skill); this file carries the
> provenance, sibling-distinctions, self-validity proofs, external grounding, §DUED
> sunset, and the dogfood log. Nothing here is required to *invoke* the skill.

## Provenance / lineage

Distilled (meta-concept extraction) from the operator's hand-invoked "self-audit the
session's methods/tools for gaps/theater → research + MoE/MoA council → fix" contract
(the OODA "Macro-2"). The notation-heavy hand form
(`/deep-research ... --goal=[ative mentes ... procure por gaps/theater nos metodos/agentic-tools desta sessão] | /quiesce ...`)
collapses into a single notation-free invocation — the named phases ARE the pipeline.
Named via the `anima` engine (machine-register, descriptive-canonical per
naming-authority): `praxis` (πρᾶξις, "the enacted doing/practice") = exactly the subject
(the methods actually used); sibling-parallel to `goal-recovery` (the *what*) and
`corpus-firing-audit` (the standing *corpus*). Rejected runner-up: `session-method-audit`
(generic/long; "praxis" is tighter and carries the enacted-practice nuance "method" lacks).

## Distinct-from-siblings (DRY — composes, never duplicates)

| Sibling | Its subject | THIS subject |
|---|---|---|
| `corpus-firing-audit` | the **standing governance corpus** (rules/memory: dormant vs firing) | the **session's enacted tool-use** (this run's praxis) |
| `end-of-action-self-audit` (user-scope rule) | the session's **produced result** (deliverable quality/gaps — the *what-was-made*) | the session's **method** (the *how-it-was-made*) |
| `goal-recovery` / `ooda-loop` | the session's **goal** (intent — the *what*) | the session's **praxis** (the *how*) |
| `red-team` (Elenchus) | an adversarial attack on ONE design/claim | uses red-team *inside* COUNCIL; is a full audit→fix pipeline |
| `gap-loop` | drives a gap-register to convergence | uses gap-loop *inside* FIX; contributes the audit subject upstream |
| `convergence-engine` | result quality (REFINE/SELECT/DEFER by verifiability) | uses it *inside* COUNCIL |

## Operator `--auto-self-*` + `--family-aware` (de-theatered — inherited, not re-invented)

Per the operator's `--principles`, these are NOT new machinery on `praxis-audit`; they land on existing behavior (DRY):

- `--auto-self-fix` → **is** the FIX phase (gap-loop REFINE / cascade-resolver uplift, keep-best) — reversible-in-scope, worktree-disciplined.
- `--auto-self-heal` → inherited via FIX → gap-loop (`maos:preflight` heal-branch + `sentinel` HIGH auto-block).
- `--family-aware` → **by construction**: the audit reads + classifies the family's OWN tools (RECAP/AUDIT), composes its siblings (Composition), and declares its distinct subject vs each (Distinct-from-siblings). Adding a passive "family-awareness" layer would itself be theater.
- `(calcule defaults fixed, calcule dinamicamente at runtime)` → satisfied: the flag defaults are **fixed** (SKILL.md Override table) AND `--source=auto` capability-detects the enacted-tool sources + the COUNCIL seat-roster rotates via the convergence-engine at **runtime**.

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: `praxis-audit --dry-run` on its OWN creation session before declaring done (the recursive test — did authoring THIS skill itself have method-theater?). See the dogfood log below.
- **Persist-over-fail**: the praxis-register ledger IS the write-ahead checkpoint; a mid-run collapse is recoverable.
- **DRY / KIS / YAGNI / SSOT** — compose the primitives, never duplicate them.
- **No self-destructive decisions** — nothing that boomerangs on a future session.
- **Boy-Scout** — leave every artifact cleaner than found; STAGE-only unless authorized (EKO-66).

## Relationship to siblings

| Tool | Subject | Drives | Needs `/goal`? |
|---|---|---|---|
| `praxis-audit` (this) | the session's OWN enacted **method** (the *how*) | audit → research → council → fix | **NO** (self-driven; FIX via gap-loop is harness-agnostic) |
| `corpus-firing-audit` | the **standing governance corpus** (rules/memory) | firing/theater ledger + effectivation proposal | no |
| `end-of-action-self-audit` | the session's produced **result** (deliverable quality) | self-critique + selective remediate | no |
| `goal-recovery` / `ooda-loop` | the session's **goal** (the *what*) | recover (→ measure → converge) | ooda: composes it |
| `gap-loop` | a goal as a gap-register | declarative self-scored loop (used inside FIX) | no |
| `convergence-engine` | result quality | REFINE / SELECT / DEFER by verifiability (used inside COUNCIL) | no |

## Quality Tests (6 self-validity)

1. **Self-Application** — the first `--dry-run` cycle (dogfood log below) audited the METHODS used to author + PDCA-harden THIS skill, and independently converged with the external bot council on the one real misfire. PASS (evidence-backed, not asserted).
2. **Non-Contradiction** — composes (not duplicates) corpus-firing-audit/enhance-pipeline/convergence-engine/gap-loop; the self-referential SUBJECT (session praxis) + the audit→fix wiring are net-new; the Distinct-from-siblings table proves no subject overlap. PASS.
3. **Survival** — applied to itself it advocates an evidence-cited, independently-verified, red-teamed audit; it is itself that (verifier>generator, red-team-the-verdict). PASS.
4. **Bounded-Responsibility** — read-only through COUNCIL, FIX gated + `--dry-run`, `--max-iterations`, HARD-gate escalation, STOP-marker, §DUED. PASS.
5. **Explicit-Exception** — When-not-to-use + HARD-gate HITL + `--principle-exception` (SDP) + §0 SER>Regras escape. PASS.
6. **Utility-Sunset** — §DUED below. PASS.

`scope-discipline` 6Q: WHERE=multi-agent-os · DRY=heavily reused (composes existing primitives; delta = 1 self-referential subject + audit→fix wiring) · WHY=recurring hand-invoked "Macro-2" contract · WHO=operator + amnesic agents · FITS=orchestration-convergence sibling of gap-loop/ooda-loop + audit sibling of corpus-firing-audit · MIN=1 thin preset, protocol deliberately omitted (methodology inherited, corpus-firing-audit's self-contained precedent). `anti-theater` 8Q REALITY: 8/8 (real · not-theater · not-hallucinated · not-invented · viable · applicable · implementable · useful).

## §DUED Sunset (qualitative — not counter-based)

Deprecate when ANY: `corpus-firing-audit` absorbs a `--subject=session-praxis` mode making a separate preset redundant (E6) · agents self-audit their own method-firing reflexively so the preset never fires (E3) · the family collapses corpus/result/praxis audits into one unified self-audit entry (E6) · operator retraction (E4) · ≥3 false-positive runs (E5 → refine). Dormant-by-design otherwise.

## External grounding

Boyd OODA (the operator's macro frame) · Huang et al. 2310.01798 "LLMs cannot self-correct reasoning yet" (verifier>generator, independent — the hard invariant) · reflexive practice audit (praxis vs poiesis, Aristotle) · MoA 2406.04692 (council).

## Dogfood log

### Cycle 1 — `praxis-audit --dry-run --scope=this.session` — 2026-07-14 (manual enactment)

> **Honest scope note**: enacted by hand (the skill is not yet runtime-invocable — the
> `maos:` registry lags repo HEAD; refreshing it routes through the corporate marketplace
> = operator-domain / effectivation-pending). This is a real read-only enactment of the
> RECON→COUNCIL phases on THIS forge session; FIX not driven (`--dry-run`). It converges
> with the **external** bot council on PR #248 (Amazon Q · CodeRabbit · Qodo · Copilot),
> which served as the independent verifier panel (verifier>generator satisfied).

**RECAP** (methods THIS session enacted, evidence-cited):

| id | method | kind | evidence |
|---|---|---|---|
| M1 | Explore subagent — reuse-inventory recon for the PS question | recon-probe/delegation | returned schema-file-grounded verdict on the 4 candidate tools |
| M2 | Skopos recon-before-assume (read-only `gh`/`wc` probes) | recon-probe | probed PR #248 status + review bodies + byte-sizes BEFORE asserting |
| M3 | PS reuse-decision via DRY/YAGNI evidence-table (Strata) | decision-gate | declined 4 tools, each with producer/consumer evidence |
| M4 | plan-mode discipline (plan file → ExitPlanMode) | decision-gate | operator approved the plan |
| M5 | PDCA on PR #248 bot findings (pr-review-protocol) | verify/mutation | read + categorized findings → fix-vs-reply → applied F1-F7 |
| M6 | anti-theater / honesty (F5 validation, F6 dogfood-status) | verify | the F5/F6 fixes correct real overclaims |
| M7 | Anima naming (`praxis-audit`, runner-up recorded) | decision-gate | naming-authority; single sovereign call |
| M8 | Gordian anti-over-eng (thin preset; declined dod-recovery) | decision-gate | kept 0 new machinery |
| M9 | COUNCIL / MoE-MoA convergence on the forge | verify | external bots = independent verifier panel; solo+Explore on the low-stakes reuse-decision |

**AUDIT** (verdicts):

- M1–M8 → **FIRED-WELL** (each produced a real effect that advanced the goal; evidence cited above).
- M9 → **FIRED-WELL (proportionate-council note)** — the external bot panel (Amazon Q/CodeRabbit/Qodo/Copilot) genuinely served as the independent verifier on the *artifact* (found real drift → verifier>generator holds). The PS reuse-*decision* was solo + 1 Explore, which is proportionate for a schema-file-verifiable, low-stakes DRY call (a full 3-seat council there would be the over-engineering the `--principles` forbid). Not a theater-gap.
- **M-forge-doc → MISFIRE (independently confirmed)** — the forge's first SKILL.md asserted "6/6 self-validity — dogfooded" and "composes 6 primitives" / "5 phases" **before** the first dogfood cycle and while the composition actually lists 7+ primitives + a phase-0 pre-step. Claiming dogfooded/PASS before dogfooding is the exact anti-theater the tool exists to catch — applied to itself. **Independently confirmed** by the external council: CodeRabbit (Major: "do not report dogfooding as passed while pending"; SSOT count) + Qodo (description>1024, validation overclaim) + Copilot (×8 phase/primitive-count drift).

**pulse**: `{fired_well: 8, theater: 0, inconsistent: 0, misfire: 1, gap: 0}` · `confirmed_by_council: 1` · `autonomy_score ≈ 0.9`.

**CURE** (ranked; sharpen > add): **sharpen** the fire-points — (a) run the actual first dogfood cycle = THIS log; (b) fix the overclaims (F1 trim <12KB, F2 desc<1024, F3 drop brittle counts, F5 validation honesty, F6 dogfood-status honest). No passive rule added (adding one to fix "claimed-before-dogfooding" would itself be theater). All cures are the F1-F7 changes shipped in PR #248.

**Convergence**: the internal self-audit and the external bot council **agree** on the single real finding (the strongest signal — verifier>generator, independent). `--dry-run` parks here (FIX = the PR's own edits, driven under normal PDCA, not by an auto-FIX loop).

`dogfood_status`: first `--dry-run` cycle recorded 2026-07-14; promote past provisional once the runtime skill is registered and a fresh cycle re-runs post-effectivation.
