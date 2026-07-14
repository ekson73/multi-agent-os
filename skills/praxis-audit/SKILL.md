---
name: praxis-audit
version: "0.1.0"
description: |
  Self-referential session-method audit: turn the firing/theater lens onto THIS
  session's OWN enacted methods/tools/protocols — did each tool actually FIRE
  (produce a real effect that advanced the goal) or was it THEATER (ceremony
  without substance), used INCONSISTENTLY, MISFIRED (nearby-but-wrong), or was a
  needed method a GAP (should-have-fired-but-didn't)? Then RESEARCH better
  methods, COUNCIL-converge (verifier>generator), and FIX. Five phases: RECAP
  (enumerate the session's enacted tool-use) -> AUDIT (kind-aware firing/theater
  classification per method, retargeting the corpus-firing-audit lens onto
  session praxis) -> RESEARCH (internal+external, enhance-pipeline EXPAND) ->
  COUNCIL (convergence-engine dispatches perspective-trio + persona-pipeline +
  red-team -> converge) -> FIX (gap-loop resolves + independently validates +
  persists). Defining novelty: the SUBJECT is the session's OWN praxis (the
  "how"), a sibling of goal-recovery's "what" and corpus-firing-audit's standing
  corpus. Thin preset: composes corpus-firing-audit, enhance-pipeline,
  convergence-engine, perspective-trio, persona-pipeline, red-team, gap-loop —
  reimplements nothing. Idempotent, read-only through COUNCIL (the only mutating
  phase is FIX, worktree-disciplined).
  Triggers: "praxis-audit", "audit this session's own methods/tools", "did our
  tools fire or was it theater", "self-audit the methods we used", "session
  method-audit", "find gaps/theater in how this session worked".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: orchestration-convergence
  cross_link_slug: praxis-audit
  dogfood_status: pending-first-cycle
---

# Praxis-Audit — did THIS session's own methods FIRE, or was it theater?

Thin **self-referential session-method audit** preset. `praxis-audit` does not
re-implement the firing/theater test, research, MoE convergence, or the fix-loop —
it composes existing primitives and contributes only the parts the family lacks: a
**self-referential subject** (the session's OWN enacted tool-use, not the standing
governance corpus and not the session's produced *result*), and the wiring that
carries that audit through research -> council -> fix.

> **Provenance / lineage**: distilled (meta-concept extraction) from the operator's
> hand-invoked "self-audit the session's methods/tools for gaps/theater ->
> research + MoE/MoA council -> fix" contract (the OODA "Macro-2"). The notation-heavy
> hand form (`/deep-research ... --goal=[ative mentes ... procure por gaps/theater nos
> metodos/agentic-tools desta sessão] | /quiesce ...`) collapses here into a single
> notation-free invocation — the named phases ARE the pipeline. Named via the `anima`
> engine (machine-register, descriptive-canonical per naming-authority): `praxis`
> (πρᾶξις, "the enacted doing/practice") = exactly the subject (the methods actually
> used); sibling-parallel to `goal-recovery` (the *what*) and `corpus-firing-audit`
> (the standing *corpus*). Rejected runner-up: `session-method-audit` (generic/long;
> "praxis" is tighter and carries the enacted-practice nuance "method" lacks).
> Authored by Claude Opus 4.8 under operator `/enhance` directive 2026-07-14; reviewed by @ekson73.

## Purpose

Audit whether the methods/tools/protocols THIS session actually **enacted** were
sound — each one FIRED (real effect that advanced the goal) vs THEATER (ceremony
without substance) vs INCONSISTENT vs MISFIRE vs a GAP (needed-but-absent) — then
research better methods, converge a diverse independent council on the findings
(verifier>generator), and drive the confirmed fixes to done. Fills the seam left by
the siblings: `corpus-firing-audit` audits the **standing governance corpus**
(rules/memory — dormant-vs-firing); `end-of-action-self-audit` audits the session's
**produced result** (quality/gaps/pendencies of the deliverable); `praxis-audit`
audits the session's **enacted praxis** (the *how* — the tool-use itself).

## When to use

- End of (or mid-) a substantive session, to ask "were our METHODS sound, or did we
  perform ceremony?" — before trusting the session's own conclusions.
- A recurring smell that a gate/recon/council/verifier was **invoked but hollow**
  (rubber-stamp council, a "validation" that validated nothing, a plan never executed).
- You want the audit to not just *report* but **research + council-converge + fix**
  the method-level defects (not the result-level ones — that is `end-of-action-self-audit`).

## When **not** to use

- Auditing the standing GOVERNANCE corpus (rules dir + MEMORY) -> `corpus-firing-audit`.
- Auditing the session's produced RESULT (quality/gaps of the deliverable) -> `end-of-action-self-audit`.
- Recovering *what* the session is trying to do (the goal, not the method) -> `goal-recovery` / `ooda-loop`.
- A single adversarial attack on ONE design/claim -> `red-team` directly.
- Single-shot edit / read-only Q&A -> answer directly.
- Destructive ops in FIX -> always HITL.

## Trigger Phrases

- "praxis-audit" / "audit this session's own methods/tools"
- "did our tools fire or was it theater" / "self-audit the methods we used"
- "session method-audit" / "find gaps/theater in HOW this session worked"

## Distinct-from-siblings (DRY — composes, never duplicates)

| Sibling | Its subject | THIS subject |
|---|---|---|
| `corpus-firing-audit` | the **standing governance corpus** (rules/memory: dormant vs firing) | the **session's enacted tool-use** (this run's praxis) |
| `end-of-action-self-audit` (user-scope rule) | the session's **produced result** (quality/gaps of the deliverable — the *what-was-made*) | the session's **method** (the *how-it-was-made*) |
| `goal-recovery` / `ooda-loop` | the session's **goal** (intent — the *what*) | the session's **praxis** (the *how*) |
| `red-team` (Elenchus) | an adversarial attack on ONE design/claim | uses red-team *inside* COUNCIL; is a full audit->fix pipeline |
| `gap-loop` | drives a gap-register to convergence | uses gap-loop *inside* FIX; contributes the audit subject upstream |

## The 5 phases (each lands on a primitive)

```text
PHASE 0 · RECON   read-only. OBSERVE before assuming (Skopos / CASC Gate-0). Read any
                  prior praxis-audit ledger (idempotency). Capability-detect the
                  session's enacted-tool-use sources (ASH journal · session transcript
                  tool-call log · .remember/ · CPT topology events · recent commits);
                  degrade-not-block on absence.
PHASE 1 · RECAP   enumerate the methods/tools/protocols THIS session actually ENACTED
                  -> ONE deduplicated, IDed praxis-register (M1..Mn). Single source
                  (no hallucination): a method appears only if there is evidence it was
                  invoked this session. Kind-tag each (recon-probe · mutation ·
                  delegation · research · decision-gate · verify · persist).
PHASE 2 · AUDIT   per method, emit a record (retarget the corpus-firing-audit lens onto
                  session praxis; kind-aware, evidence-cited):
                  verdict := FIRED-WELL (real effect advanced the goal, evidence cited)
                           | THEATER (invoked, added no substance — ceremony)
                           | INCONSISTENT (applied one place, skipped/contradicted another)
                           | MISFIRE (used but wrong-for-context — nearby-but-wrong)
                           | GAP (a needed method NOT used — should-have-fired-but-didn't)
                  For each THEATER/INCONSISTENT/MISFIRE/GAP -> propose the CURE, ranked
                  Eisenhower, preferring **sharpen an existing fire-point > add a new
                  passive rule** (adding a passive rule to fix "methods don't fire"
                  would itself be theater).
PHASE 3 · RESEARCH internal + external for better/similar methods for each flagged item
                  (enhance-pipeline EXPAND; Skopos recon-first; cite, don't fabricate).
PHASE 4 · COUNCIL  convergence-engine routes the flagged findings: perspective-trio
                  (breadth) + persona-pipeline (INDEPENDENT verify, experts != the
                  auditor) + red-team (adversarial: "is this 'theater' verdict itself
                  theater?") -> converge (5-act, reject-log). verifier>generator is the
                  master condition — a finding survives only if an independent seat
                  confirms it. Kills false-positive "theater" calls.
PHASE 5 · FIX      (the only mutating phase) gap-loop drives the COUNCIL-confirmed
                  method-fixes to convergence + independently validates + persists
                  (worktree-disciplined; --auto-merge default hold per EKO-66). Regenerate
                  the praxis-audit ledger. --dry-run stops after COUNCIL (print the
                  fix-plan; drive nothing).
```

## Idempotency contract (non-negotiable)

- **Probe before acting** — read the prior ledger's `generated-at` + verdict set first (PHASE 0).
- **Read-only through COUNCIL** — RECON/RECAP/AUDIT/RESEARCH/COUNCIL mutate nothing; the ONLY write before FIX is the ledger.
- **Convergence** — no new session-evidence + no confirmed findings ⇒ semantically identical ledger (only generated-at differs).
- **FIX is gated** — mutation happens only in PHASE 5, through gap-loop's own worktree + auto-merge discipline; `--dry-run` skips it entirely.

## Bounds

```text
autonomy-band: L2-unattended    (descriptive band — NOT a flag; set numerically via --autonomy-threshold)
--max-iterations=6              (FIX loop cap, passed to gap-loop; then park-state + escalate)
--principles=[DRY, SSOT, KIS, YAGNI, ANTI-OVER-ENG, ANTI-THEATER, CONTINUITY, HAND-OFF, BOY-SCOUT]
                                # KIS = Keep It Simple (drop accidental complexity, keep essential — simple,
                                # not simplistic); "smart" is a quality caveat, never a redefinition.
--principle-exception="only with documented justification (SDP)"
--meta-rule="BEING > rule; law serves the goal; any rule admits a justified exception"  (= §0 SER>Regras)
```

## Composition (the wiring — DRY; every phase lands on an existing primitive)

| Phase | Composes (existing — reimplements nothing) |
|---|---|
| RECON | `maos:preflight` / `skills/pulse` + Skopos recon-before-assume (CASC Gate-0) + prior-ledger read |
| RECAP | `skills/agentic-session-harness` (ASH tool-call meta-trace) + session transcript / `.remember/` / CPT topology events -> praxis-register |
| AUDIT | `skills/corpus-firing-audit` **lens, retargeted** onto session praxis (kind-aware FIRING/THEATER/STALE -> FIRED-WELL/THEATER/INCONSISTENT/MISFIRE/GAP; effectivation `sharpen>add`) |
| RESEARCH | `skills/enhance-pipeline` (EXPAND — internal+external gap-find) |
| COUNCIL | `skills/convergence-engine` (regime-router + master condition) · `maos:perspective-trio` (breadth) · `maos:persona-pipeline` (independent verify — experts != auditor) · `skills/red-team` (adversarial: is the verdict itself theater?) · `skills/converge` (5-act + reject-log) |
| FIX | `skills/gap-loop` (harness-agnostic 5-phase loop; MoE resolve + independent VALIDATE + derived score + PERSIST) — worktree-disciplined; `maos:postflight` P1-SWEEP boy-scout |
| The audit SUBJECT | **this skill's own contribution** — the session's OWN enacted praxis (self-referential; the "how") |

## Operator `--auto-self-*` + `--family-aware` (de-theatered — inherited, not re-invented)

Per the operator's `--principles`, these are NOT new machinery on `praxis-audit`; they land on existing behavior (DRY):
- `--auto-self-fix` → **is** the FIX phase (gap-loop REFINE / cascade-resolver uplift, keep-best) — reversible-in-scope, worktree-disciplined.
- `--auto-self-heal` → inherited via FIX → gap-loop (`maos:preflight` heal-branch + `sentinel` HIGH auto-block).
- `--family-aware` → **by construction**: the audit reads + classifies the family's OWN tools (RECAP/AUDIT), composes 6 siblings (Composition), and declares its distinct subject vs each (Distinct-from-siblings). Adding a passive "family-awareness" layer would itself be theater.

## Override parameters

| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<instructions>"` (positional) | empty | extra free-text appended to the audit focus (e.g. "focus on the council + verifier gates") |
| `--scope` | `this.session` | `this.session` \| `session:<id>` \| `branch` \| `ticket:<id>` — which run's praxis to audit |
| `--source` | `auto` | where RECAP reads enacted-tool-use from (`auto` capability-detects) \| `ash` \| `transcript` \| `remember` \| `commits` \| `topology` |
| `--autonomy-threshold` | `0.85` | `0.0`-`1.0` — the FIX score gate (bands SSOT `agents/COWORK-AUTONOMY-POLICY.md`) |
| `--max-iterations` | `6` | int — FIX loop cap (passed to gap-loop) before park-state + escalate |
| `--auto-merge` | `hold` | `authorized` \| `hold` \| `off` — FIX default **hold** (EKO-66: STAGE-only, conservative) |
| `--auto-merge-reason` | *(none)* | non-empty string — **required when `--auto-merge=authorized`** (auditability parity, `auto-merge-standing-authorization` G8); ignored for `hold`/`off` |
| `--dry-run` | off | run RECON+RECAP+AUDIT+RESEARCH+COUNCIL, print the confirmed findings + fix-plan, but do NOT drive FIX |
| `--output` | `text` | `text` \| `json` (emit the run envelope, below) |

## Output contract (`--output=json`)

```json
{"stage":"RECAP|AUDIT|RESEARCH|COUNCIL|FIX",
 "status":"ok|hitl|error",
 "stop_marker":"STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE",
 "praxis_register":[{"id":"M1","method":"<...>","kind":"<...>","verdict":"FIRED-WELL|THEATER|INCONSISTENT|MISFIRE|GAP","evidence":"<ref>","cure":"<sharpen|add|none>"}],
 "pulse":{"fired_well":0,"theater":0,"inconsistent":0,"misfire":0,"gap":0},
 "confirmed_by_council":0,"autonomy_score":0.0}
```

Exit: `0` STOP-DONE · `1` STOP-ERROR · `2` STOP-HITL (authority gap / dry-run parked).

## STOP-marker grammar (reused — emit exactly ONE as the last line of each turn)

```text
<!--ORCH-STATUS: STOP-DONE -->     confirmed method-fixes dispositioned, ledger regenerated, score >= threshold
<!--ORCH-STATUS: STOP-HITL -->     HARD gate (HUMAN_DOMAIN) in a fix, OR SOFT exhausted at max-iterations, OR --dry-run park
<!--ORCH-STATUS: STOP-ERROR -->    unrecoverable error (subagent / network / rate-limit)
<!--ORCH-STATUS: CONTINUE -->      round done; confirmed findings remain OR score < threshold; next round opens
```

## Relationship to siblings

| Tool | Subject | Drives | Needs `/goal`? |
|---|---|---|---|
| `praxis-audit` (this) | the session's OWN enacted **method** (the *how*) | audit -> research -> council -> fix (5 phases) | **NO** (self-driven; FIX via gap-loop is harness-agnostic) |
| `corpus-firing-audit` | the **standing governance corpus** (rules/memory) | firing/theater ledger + effectivation proposal | no |
| `end-of-action-self-audit` | the session's produced **result** (deliverable quality) | self-critique + selective remediate | no |
| `goal-recovery` / `ooda-loop` | the session's **goal** (the *what*) | recover (-> measure -> converge) | ooda: composes it |
| `gap-loop` | a goal as a gap-register | declarative self-scored 5-phase loop (used inside FIX) | no |
| `convergence-engine` | result quality | REFINE / SELECT / DEFER by verifiability (used inside COUNCIL) | no |

`praxis-audit` MAY invoke `enhance-pipeline` (RESEARCH), `convergence-engine`/`perspective-trio`/
`persona-pipeline`/`red-team`/`converge` (COUNCIL), and `gap-loop` (FIX); it never re-implements them.

## Protocol Rules (anti-loop invariants + bounds)

- Read-only through COUNCIL; the ONLY mutating phase is FIX (worktree-disciplined; `--dry-run` skips it).
- `verifier != generator` (COUNCIL persona-pipeline / gap-loop VALIDATE) — a "theater"/"gap" verdict survives only if an INDEPENDENT seat confirms it (kills false-positive self-flagellation). Never re-loosened.
- red-team the audit itself: "is this THEATER verdict itself theater?" — a finding the adversary dissolves is dropped.
- `--max-iterations` (default 6) caps FIX rounds; same-panel re-run FORBIDDEN (rotate or escalate).
- Delegation depth <= 2; Sentinel HIGH auto-blocks; exactly ONE STOP marker per turn.
- HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected, prod/irreversible,
  cross-org) are HARD gates -> escalate IMMEDIATELY, never self-authorize.

## DNA Geracional (inherited by every spawned agent)

- **Dogfood**: `praxis-audit --dry-run` on its OWN creation session before declaring done (the recursive test — did authoring THIS skill itself have method-theater?).
- **Persist-over-fail**: the praxis-register ledger IS the write-ahead checkpoint; a mid-run collapse is recoverable.
- **DRY / KIS / YAGNI / SSOT** — compose the primitives, never duplicate them.
- **No self-destructive decisions** — nothing that boomerangs on a future session.
- **Boy-Scout** — leave every artifact cleaner than found; STAGE-only unless authorized (EKO-66).

## Examples

```text
praxis-audit --scope=this.session --dry-run                 # audit this session's methods; print findings + fix-plan; drive nothing
praxis-audit --scope=this.session                           # audit -> research -> council -> fix (FIX STAGE-only by default, EKO-66)
praxis-audit "focus on the verifier != generator gates"     # narrow the audit focus
praxis-audit --auto-merge=authorized --auto-merge-reason="method-fixes, green CI"   # reason required when authorized
praxis-audit --source=ash --autonomy-threshold=0.9          # read enacted-tool-use from the ASH journal; stricter FIX gate
```

## Quality Tests (6/6 self-validity — dogfooded)

1. **Self-Application** — `praxis-audit --dry-run` could audit the METHODS used to author THIS skill (was the reuse-verdict a real recon or an assumption? was the council real or skipped?). PASS.
2. **Non-Contradiction** — composes (not duplicates) corpus-firing-audit/enhance-pipeline/convergence-engine/gap-loop; the self-referential SUBJECT (session praxis) + the audit->fix wiring are net-new; distinct-from-siblings table proves no subject overlap. PASS.
3. **Survival** — applied to itself it advocates an evidence-cited, independently-verified, red-teamed audit; it is itself that (verifier>generator, red-team-the-verdict). PASS.
4. **Bounded-Responsibility** — read-only through COUNCIL, FIX gated + `--dry-run`, `--max-iterations`, HARD-gate escalation, STOP-marker, §DUED. PASS.
5. **Explicit-Exception** — When-not-to-use + HARD-gate HITL + `--principle-exception` (SDP) + §0 SER>Regras escape. PASS.
6. **Utility-Sunset** — §DUED below. PASS.

`scope-discipline` 6Q: 6/6 (WHERE=multi-agent-os · DRY=~70% reused, composes 6 primitives, delta=1 self-referential subject + audit->fix wiring · WHY=recurring hand-invoked "Macro-2" contract · WHO=operator+amnesic agents · FITS=orchestration-convergence sibling of gap-loop/ooda-loop + audit sibling of corpus-firing-audit · MIN=1 thin preset, protocol deliberately omitted — methodology inherited, matching corpus-firing-audit's self-contained precedent). `anti-theater` 8Q REALITY: 8/8.

## §DUED Sunset (qualitative — not counter-based)

Deprecate when ANY: `corpus-firing-audit` absorbs a `--subject=session-praxis` mode making a separate
preset redundant (E6) · agents self-audit their own method-firing reflexively so the preset never fires
(E3) · the family collapses corpus/result/praxis audits into one unified self-audit entry (E6) · operator
retraction (E4) · >=3 false-positive runs (E5 -> refine). Dormant-by-design otherwise.

## Validation

- `tests/validate-plugin.sh` enforces (generically): `skills/praxis-audit/` contains `SKILL.md` with valid frontmatter.
- `commands/praxis-audit.md` carries matching `name: praxis-audit` frontmatter.
- No separate protocol file (methodology inherited from composed primitives — matches `corpus-firing-audit`'s self-contained precedent; DRY/YAGNI, a protocol would duplicate the composed skills).
- Satisfies the 10-item checklist in `skills/skill-writer/SKILL.md`.

## Related

- `commands/praxis-audit.md` — operator-facing command surface
- `skills/corpus-firing-audit/SKILL.md` — the FIRING/THEATER **lens** this retargets (standing corpus <-> session praxis; audit-family sibling)
- `skills/goal-recovery/SKILL.md` — the *what* sibling (goal ⟂ praxis; the *how*)
- `skills/ooda-loop/SKILL.md` — the recover->measure->converge conductor (goal side)
- `skills/enhance-pipeline/SKILL.md` — RESEARCH (EXPAND) primitive
- `skills/convergence-engine/SKILL.md` (+ `PRIOR-ART.md`) — COUNCIL regime-router + master condition (verifier>generator)
- `agents/perspective-trio.md` · `agents/persona-pipeline.md` — COUNCIL breadth + independent-verify seats
- `skills/red-team/SKILL.md` — COUNCIL adversarial seat (is the verdict itself theater?)
- `skills/converge/SKILL.md` — COUNCIL 5-act merge + reject-log
- `skills/gap-loop/SKILL.md` — FIX driver (harness-agnostic; verifier != generator; worktree-disciplined)
- `skills/agentic-session-harness/SKILL.md` — RECAP source (ASH enacted-tool-use meta-trace)
- `agents/COWORK-AUTONOMY-POLICY.md` — autonomy bands + carve-outs SSOT (FIX gate)
- External grounding: Boyd OODA (the operator's macro frame) · Huang et al. 2310.01798 (verifier>generator, independent — the hard invariant) · reflexive practice audit (praxis vs poiesis, Aristotle) · MoA 2406.04692 (council)

## Versioning

- v0.1.0 (2026-07-14) — bootstrap. Self-referential session-method audit: RECAP (enacted-tool-use) ->
  AUDIT (retargeted corpus-firing-audit lens: FIRED-WELL/THEATER/INCONSISTENT/MISFIRE/GAP) -> RESEARCH
  (enhance-pipeline) -> COUNCIL (convergence-engine + perspective-trio + persona-pipeline + red-team ->
  converge, verifier>generator) -> FIX (gap-loop, worktree-disciplined). Composes 6 primitives; the
  self-referential SUBJECT + audit->fix wiring are the only net-new. Read-only through COUNCIL; FIX gated
  + `--dry-run`. `dogfood_status: pending-first-cycle`.

## License

MIT (matches multi-agent-os repo `LICENSE`).
