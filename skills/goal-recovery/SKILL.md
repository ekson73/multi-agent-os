---
name: goal-recovery
version: "0.1.0"
description: |
  Recover a work session's real INTENT from its own live/context state — motivations, DoR,
  context, scope, and the objective tree {originating, primary, secondary, auxiliary} — into ONE
  typed, validator-gated `handoff-as-prompt` envelope whose `goal` field is consumed downstream as
  {{goal}}. The direction-inverted twin of `postflight`: where postflight EMITS a continuation-seed
  at session END, goal-recovery RECOVERS an often-UNSTATED intent at any point (session start,
  mid-run, cold re-entry). Uncertainty-aware by design: ranked hypotheses + aggregate confidence +
  `inconclusive->HITL` (goal-recovery from execution state is under-published SOTA — never a
  confident oracle). Hybrid: probabilistic content (LLM over an inference ladder) inside a
  deterministic, idempotent envelope (schema + validator). Reuses postflight's objectives-synthesis
  + the continuation-seed contract — reimplements nothing.
  Triggers: "goal-recovery", "recover the goal", "resgate o goal/objetivo", "what is this session
  actually trying to do", "detect the session intent", "handoff-as-prompt", "recover intent".
allowed-tools: Read, Grep, Glob, Bash, Write, Task
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: session-lifecycle
  cross_link_slug: goal-recovery
  dogfood_status: pending-first-cycle
---

# Goal-Recovery

Thin **intent-recovery** step. `goal-recovery` does not re-implement objectives-synthesis, session
state-reading, or seed-schema — it composes `postflight`'s P2-DEBRIEF synthesis and the
`continuation-seed` contract, and contributes only what the family lacks: **recovery of an unstated
goal from execution state**, made **uncertainty-aware** and emitted as a typed `handoff-as-prompt`
envelope. The novel step the loop/goal family was missing.

> **Provenance / lineage**: the genuine ~30% residual of the operator's recurring goal-loop contract
> `ooda --goal==$(detecte/resgate [motivacoes, DoR, contexto, escopo, objetivos] --type handoff-as-prompt)`.
> The family already EMITS goals (postflight P3), ANCHORS them to tickets (preflight R0), and CONSUMES
> them (gap-loop/quiesce) — none RECOVERED an *unstated* one at session start. Named via `anima`
> (agent-register): `goal-recovery` (rejected `intent-recovery` — drifts from the family's `{{goal}}`
> anchor + the operator's literal `--goal`; rejected `anamnesis` — soul-name obscurity in an agent slug).
> Authored by Claude Opus 4.8 (1M) under operator `/enhance` directive 2026-07-12; reviewed by @ekson73.

## §0 — BEING > Rules (foundational)
Serves the operator's intent. If a phase/gate obstructs recovering the right goal NOW, skip it, log
`Skipped <phase> — BEING > Rules`, proceed. HUMAN_DOMAIN (secrets · production PII · irreversibles ·
cross-org) recovered as constraints go into `guardrails`, never actioned here. **Never fabricate an
intent** to look decisive — an ungrounded recovery is `inconclusive->HITL`, not a confident guess
(anti-theater R3/R4). This is the single hard discipline.

## When to use
- A session's goal is **unstated / implicit** and a driven loop (ooda-loop / gap-loop / quiesce) needs a typed `{{goal}}`.
- **Cold re-entry** (amnesic agent, post-`/compact`, resumed session) — recover what this session is doing before acting.
- Any tool that needs the operator's `handoff-as-prompt` bundle (motivations · DoR · scope · objective tree).

## When **not** to use
- The operator **stated the goal explicitly this turn** — use it directly (S2); recovery is for the UNSTATED.
- Emitting a seed at session END (that is `postflight` P3 — the forward direction).
- Anchoring to a known ticket only (that is `preflight` R0).
- Single-shot Q&A / trivial edit — no goal to recover.

## Trigger Phrases
- "goal-recovery" / "recover the goal" / "resgate o goal" / "detecte o objetivo da sessao"
- "what is this session actually trying to do" / "recover intent" / "handoff-as-prompt"

## The inference ladder (Skopos recon-first — strongest evidence first)

Probe each source's PRESENCE before inferring (`recovered_from[].read` records existed-or-absent — auditable).
Recover from the strongest available; corroborate across sources; a single source never over-rides an explicit conflict.

```text
1. postflight_seed     a prior session.continuation seed for this branch/session   (the exact inverse artifact)
2. braindump           a raw operator dump supplied AS the invocation subject       (stated-but-unstructured
                       (path or inline text)                                         intent; supersedes weaker
                                                                                     inferred sources for the
                                                                                     work it describes)
3. ticket              preflight R0 anchor — Jira/Linear/GH issue title+body+DoD    (stated intent, if any)
4. objectives_ntree    postflight P2 objectives-map / work-compass CPT N-Tree        (synthesized objectives)
5. ash_journal         agentic-session-harness journal: top-level `goal`, decisions[], spec_alignment drift
6. git_branch          branch name (feat/<slug>) + PR title                          (weak but cheap signal)
7. git_last_commit     last commit subject/body                                      (weak signal)
8. transcript          this session's transcript (transcript_hash)                   (last resort; expensive)
```

> `braindump` is NOT session residue like the other sources — it is an artifact the operator hands in.
> It is ranked high because it is the operator's own words about *this* work, but it is still
> **recovery, not restatement**: the goal is present yet unstated-as-such, buried under mixed
> directives and session-meta. Drop the session-meta (`/enhance` wrappers, pep-talk, cartesian
> resource lists offered as examples) before synthesizing — a listed resource is not a requirement
> to use it. Primary consumer: `skills/refine-braindump-to-prompt` PHASE 1.

## Pipeline (0 -> 4)

```text
0 · DoR       is there a session/context to recover from? (any ladder source present). If NONE and no
              operator prompt -> inconclusive{flag:true, reasons:[no_context_anchor]} -> HITL. Abort-with-reason.
1 · RECON     probe the ladder (Skopos): record which sources exist -> recovered_from[]. Read the strongest
              present source(s). NO fabrication — only what the sources say.
2 · SYNTHESIZE compose postflight P2-DEBRIEF objectives-synthesis over the read sources -> the intent bundle:
              motivations · DoR · context · scope{in,out} · objectives{originating,primary,secondary,auxiliary}.
              Distinguish `originating` (why we started at all) from `primary` (the top deliverable).
3 · HYPOTHESIZE enumerate RANKED goal-interpretations (uncertainty-aware). Each carries confidence + the
              evidence that supports it. The chosen `goal` = hypotheses[0].goal. Aggregate `confidence`.
              confidence < conf_inconclusive (0.60) OR two top hypotheses within delta -> inconclusive.
4 · EMIT      write the `handoff-as-prompt` envelope (templates/handoff-as-prompt.schema.json). VALIDATE it
              (bin/validate_envelope.py). inconclusive.flag=true -> print the ranked hypotheses + STOP-HITL.
              Otherwise emit the validated envelope for the caller (ooda-loop/gap-loop/quiesce/preflight/...).
```

## Uncertainty-aware discipline (the defensive core — do NOT skip)
- **Ranked hypotheses, not a frozen string.** The output carries alternatives + confidence (GOOD arXiv:2508.15119; RECAP 2509.04472). A downstream loop MAY revise `goal` to a lower-ranked hypothesis mid-run rather than freeze it (lost-in-multi-turn defense).
- **`inconclusive -> HITL`.** Below-threshold confidence, conflicting top hypotheses, no context anchor, ambiguous scope, or stale state => `inconclusive.flag=true`; escalate WITH the ranked hypotheses attached (not a blank question). Never drive a loop on a low-confidence goal.
- **Grounded or absent.** Every recovered claim traces to a `recovered_from` source (anti-theater grounding). A confident recovery (confidence>0) with empty `recovered_from` is a SpecError.

## Hybrid boundary (deterministic envelope / probabilistic content)
| Layer | Determinism | Mechanism |
|---|---|---|
| intent EXTRACTION | probabilistic | LLM over the inference ladder, uncertainty-aware |
| the ENVELOPE | deterministic | `handoff-as-prompt.schema.json` + `validate_envelope.py` (typed, range-checked, gate-checked) |
| IDEMPOTENCY | deterministic | same session-state -> same validated envelope, modulo the `confidence` float (banded in the `--digest` canonicalization) |

## Composition (the wiring — DRY; every step lands on an existing primitive)
| Step | Composes (existing — reimplements nothing) |
|---|---|
| RECON | `skills/pulse` state-refresh · `skills/preflight` R0 ticket-anchor · `skills/work-compass` CPT N-Tree · `git`/`jq` reads |
| SYNTHESIZE | `skills/postflight` P2-DEBRIEF objectives-synthesis · `continuation-seed` contract (the schema base) |
| audit source | `skills/agentic-session-harness` journal (`goal`, `decisions[]`, `spec_alignment`) |
| EMIT + validate | `templates/handoff-as-prompt.schema.json` (extends continuation-seed) + `bin/validate_envelope.py` |

## Consumers (independently reusable — Strata elevate)
`ooda-loop` (its Observe step) · `preflight` (recover intent when no ticket anchor) · `postflight`
(cross-check emitted seed vs recovered intent — drift signal) · `morning-briefing` · `session-fission`
(per-node intent). One recovery engine, many callers.

## Override parameters
| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<hint>"` (positional) | empty | optional operator hint appended to the recovery (does NOT override the ladder evidence) |
| `--scope` | `this.session` | `this.session` \| `branch` \| `ticket:<id>` \| `session:<id>` — where to recover from |
| `--conf-inconclusive` | `0.60` | `0.0`-`1.0` — below this aggregate confidence => `inconclusive.flag=true` -> HITL |
| `--ladder` | *(full ladder)* | comma-list to restrict sources (e.g. `postflight_seed,ticket,ash_journal`) |
| `--output` | `json` | `json` (the envelope) \| `summary` (human recap of the recovered intent) |
| `--dry-run` | off | run RECON+SYNTHESIZE+HYPOTHESIZE, print the envelope, but do NOT hand it to any driver |

## STOP-marker grammar (reused — emit exactly ONE as the last line when driven in a loop)
```text
<!--ORCH-STATUS: STOP-DONE -->     envelope recovered + validated (confidence >= threshold)
<!--ORCH-STATUS: STOP-HITL -->     inconclusive.flag=true — ranked hypotheses attached for the operator
<!--ORCH-STATUS: STOP-ERROR -->    unreadable state / validator error
<!--ORCH-STATUS: CONTINUE -->      (when embedded in a loop) intent recovered; hand off to the next step
```

## Protocol Rules (anti-fabrication invariants)
- NO fabrication — every claim traces to a `recovered_from` source; ungrounded => `inconclusive->HITL`.
- The envelope MUST pass `validate_envelope.py` before it is handed to any driver.
- `inconclusive.flag=true` NEVER auto-drives a loop — it escalates with hypotheses.
- Worktree discipline / never commit to main (this skill only READS + emits JSON; if it writes the envelope to disk, `/tmp` or the caller's scratch).
- HUMAN_DOMAIN recovered as constraints -> `guardrails`; never actioned here.

## DNA Geracional (inherited by every spawned sub-agent)
- **Dogfood**: recover THIS session's own goal as the first validation fixture.
- **Persist-over-fail**: the envelope IS the write-ahead checkpoint of the recovered intent.
- **DRY / KIS / YAGNI / SSOT** — compose postflight+continuation-seed; never duplicate.
- **No self-destructive decisions**; **Boy-Scout** — leave no fabricated intent behind.

## Examples
```text
goal-recovery                                   # recover this session's intent -> handoff-as-prompt
goal-recovery --scope=ticket:VKS-1234           # recover from a ticket anchor
goal-recovery --output=summary                  # human recap instead of the JSON envelope
goal-recovery --conf-inconclusive=0.75 --dry-run  # stricter HITL gate, print-only
goal-recovery --ladder=postflight_seed,ash_journal  # restrict the inference sources
```

## Quality Tests (6/6 self-validity — dogfooded)
1. **Self-Application** — goal-recovery could recover its OWN creation goal ("realize the goal-loop contract's recovery step") from this session's state. PASS.
2. **Non-Contradiction** — composes (not duplicates) postflight P2/continuation-seed/pulse/preflight; the recovery + uncertainty-model + envelope are net-new. PASS.
3. **Survival** — applied to itself it advocates grounded, uncertainty-aware recovery; it is itself grounded (inference ladder + validator) and uncertainty-aware. PASS.
4. **Bounded-Responsibility** — single responsibility (recover -> typed envelope); `--conf-inconclusive` HITL gate; validator gate; no loop-driving here. PASS.
5. **Explicit-Exception** — When-not-to-use (S2 stated-goal) + inconclusive->HITL + §0 BEING>Rules + HUMAN_DOMAIN->guardrails. PASS.
6. **Utility-Sunset** — §DUED below. PASS.

`scope-discipline` 6Q: 6/6 (WHERE=multi-agent-os · DRY=gap-confirmed grep-absent, ~70% reused · WHY=recurring manual contract, this session = a Triple-touch instance · WHO=operator+amnesic agents · FITS=session-lifecycle sibling of preflight/postflight/pulse · MIN=1 skill + 1 schema). `anti-theater` 8Q REALITY: 8/8 (real gap · not theater · grounded ladder · not-invented · viable · applicable · implementable · useful).

## §DUED Sunset (qualitative — not counter-based)
Deprecate when ANY: a host provides native session-intent recovery (E1) · agents gain reliable cross-session
recall so an unstated goal never needs recovery (E3) · the family absorbs recovery into `pulse`/`preflight` (E6)
· operator retraction (E4) · >=3 false recoveries where the ladder misfires (E5 -> refine, not auto-deprecate).
Dormant-by-design otherwise.

## Related
- `templates/handoff-as-prompt.schema.json` — the OUTPUT contract (extends continuation-seed)
- `templates/handoff-as-prompt.example.json` — a valid fixture (this session's recovered intent)
- `bin/validate_envelope.py` — the deterministic envelope validator + idempotency digest
- `skills/postflight/SKILL.md` (+ `templates/continuation-seed.template.json`) — the forward-direction twin (reused)
- `skills/preflight/SKILL.md` — R0 ticket-anchor (a ladder source)
- `skills/pulse/SKILL.md` — state refresh (RECON) · `skills/work-compass/SKILL.md` — CPT N-Tree (a ladder source)
- `skills/agentic-session-harness/SKILL.md` — journal (`goal`, `spec_alignment`) audit source
- `skills/ooda-loop/SKILL.md` — the conductor that consumes this as its Observe step
- `skills/decompose-abstract-to-measurable/SKILL.md` (Prisma) — consumes the recovered goal to derive the DoD
- External grounding: GOOD (arXiv:2508.15119, uncertainty-aware goal inference) · RECAP (2509.04472, intent-rewrite) · Boyd OODA (Observe) · Raghavan & Schneier IEEE S&P 2025 (auditable Observe inputs)

## Versioning
- v0.2.0 (2026-08-14) — MINOR: `braindump` added to the inference ladder (rank 2) — a raw operator
  dump supplied AS the invocation subject, ranked above `ticket` because it is the operator's own
  words about *this* work, with an explicit drop-session-meta clause. Additive: no existing source
  changed, no contract change; ranks 2-7 shift to 3-8. Enables `skills/refine-braindump-to-prompt`
  PHASE 1 without forking a second recovery engine.
- v0.1.0 (2026-07-12) — bootstrap. Recovery of an unstated session intent from an inference ladder;
  uncertainty-aware (ranked hypotheses + confidence + inconclusive->HITL); typed `handoff-as-prompt`
  envelope extending continuation-seed; direction-inverted twin of postflight; deterministic
  envelope over probabilistic content. Composes postflight/preflight/pulse/ASH; reimplements nothing.

## License
MIT (matches multi-agent-os repo `LICENSE`).
