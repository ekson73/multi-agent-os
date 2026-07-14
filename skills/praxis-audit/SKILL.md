---
name: praxis-audit
version: "0.1.0"
description: >-
  Self-referential session-method audit — turn the firing/theater lens onto THIS
  session's OWN enacted methods/tools (not the standing governance corpus, not the
  produced result). Per method: FIRED-WELL / THEATER / INCONSISTENT / MISFIRE / GAP,
  then RESEARCH better methods, COUNCIL-converge (verifier>generator; red-team the
  verdict), and FIX (gap-loop, worktree-disciplined). Composes existing primitives
  (corpus-firing-audit lens, enhance-pipeline, convergence-engine + its council seats,
  gap-loop) — reimplements nothing; read-only through COUNCIL. Use when ending or mid
  a substantive session, to ask "were our METHODS sound or did we perform ceremony?"
  before trusting its conclusions; or on a recurring smell that a gate/recon/council/
  verifier was invoked but hollow. Triggers: "praxis-audit", "audit this session's own
  methods/tools", "did our tools fire or was it theater", "self-audit the methods we
  used", "find gaps/theater in how this session worked".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
metadata:
  version: "0.1.0"
  scope: AAIF cross-vendor
  family: orchestration-convergence
  cross_link_slug: praxis-audit
  dogfood_status: dry-run-cycle-1-recorded-2026-07-14  # see reference.md Dogfood log; promote post-effectivation
---

# Praxis-Audit — did THIS session's own methods FIRE, or was it theater?

Thin **self-referential session-method audit** preset. It re-implements nothing — it
composes existing primitives and contributes only what the family lacks: a
**self-referential subject** (the session's OWN enacted tool-use — not the standing
governance corpus, not the produced *result*) plus the wiring that carries that audit
through research → council → fix.

> `praxis` (πρᾶξις, "the enacted doing") = exactly the subject; named via the `anima`
> engine (naming-authority). Full provenance, sibling-distinctions, `--auto-self-*`
> mapping, self-validity proofs, external grounding, §DUED and the dogfood log →
> **`reference.md`** ([C07b] inline-vs-spec: this SKILL.md is the lean operational
> entry). Authored by Claude Opus 4.8 under operator `/enhance` directive 2026-07-14; reviewed by @ekson73.

## Purpose

Audit whether the methods/tools THIS session actually **enacted** were sound — each
FIRED-WELL (real effect that advanced the goal) vs THEATER (ceremony) vs INCONSISTENT
vs MISFIRE (nearby-but-wrong) vs GAP (needed-but-absent) — then research better methods,
converge a diverse INDEPENDENT council (verifier>generator), and drive confirmed fixes
to done. It fills the seam its siblings leave: `corpus-firing-audit` → the standing
**corpus** (dormant vs firing); `end-of-action-self-audit` → the produced **result**;
`praxis-audit` → the enacted **praxis** (the *how*).

## When to use

- End of / mid a substantive session — "were our METHODS sound, or ceremony?" — before trusting its conclusions.
- A recurring smell that a gate/recon/council/verifier was **invoked but hollow** (rubber-stamp council, a "validation" that validated nothing, a plan never executed).
- You want not just a *report* but **research + council-converge + fix** of the method-level defects.

## When **not** to use

- Standing GOVERNANCE corpus (rules + MEMORY) → `corpus-firing-audit`. Produced RESULT quality → `end-of-action-self-audit`.
- Recovering *what* the session is doing (goal, not method) → `goal-recovery` / `ooda-loop`. One adversarial attack on ONE claim → `red-team`.
- Single-shot edit / read-only Q&A → answer directly. Destructive ops in FIX → always HITL.

## The phases — a RECON pre-step (phase 0) + the core RECAP → FIX sequence

```text
RECON    (phase 0, read-only) OBSERVE before assuming (Skopos / CASC Gate-0). Read any prior
         praxis-audit ledger (idempotency). Capability-detect the enacted-tool-use sources
         (ASH journal · transcript tool-call log · .remember/ · CPT topology · commits); degrade-not-block.
RECAP    enumerate the methods/tools THIS session actually ENACTED → ONE deduplicated, IDed
         praxis-register (M1..Mn). No hallucination: a method appears only with evidence it was
         invoked. Kind-tag (recon-probe · mutation · delegation · research · decision-gate · verify · persist).
AUDIT    per method (retarget the corpus-firing-audit lens onto session praxis; kind-aware, evidence-cited):
         verdict := FIRED-WELL | THEATER | INCONSISTENT | MISFIRE | GAP
         For each THEATER/INCONSISTENT/MISFIRE/GAP → propose the CURE, ranked Eisenhower, preferring
         **sharpen an existing fire-point > add a new passive rule** (a passive rule to fix "methods
         don't fire" would itself be theater).
RESEARCH internal + external for better methods per flagged item (enhance-pipeline EXPAND, run as a
         Task sub-skill carrying its own web allowlist; Skopos recon-first; cite, don't fabricate).
COUNCIL  convergence-engine routes the findings: perspective-trio (breadth) + persona-pipeline
         (INDEPENDENT verify, experts != the auditor) + red-team ("is this 'theater' verdict itself
         theater?") → converge (5-act, reject-log). verifier>generator is the master condition — a
         finding survives only if an independent seat confirms it. Kills false-positive "theater" calls.
FIX      (the only mutating phase) gap-loop drives COUNCIL-confirmed fixes to convergence +
         independently validates + persists (worktree-disciplined; --auto-merge default hold, EKO-66).
         Regenerate the ledger. --dry-run stops after COUNCIL (print the fix-plan; drive nothing).
```

## Idempotency contract

- **Probe before acting** — read the prior ledger's `generated-at` + verdict set first (RECON).
- **Read-only through COUNCIL** — only write before FIX is the ledger.
- **Convergence** — no new evidence + no confirmed findings ⇒ semantically identical ledger.
- **FIX is gated** — mutation only in FIX, via gap-loop's worktree + auto-merge discipline; `--dry-run` skips it.

## Bounds

```text
--max-iterations=6          (FIX loop cap → gap-loop; then park-state + escalate)   depth <= 2   Sentinel HIGH auto-blocks
--principles=[DRY, SSOT, KIS (Keep It Simple; not simplistic), YAGNI, ANTI-OVER-ENG, ANTI-THEATER, CONTINUITY, HAND-OFF, BOY-SCOUT]
--principle-exception="only with documented justification (SDP)"   --meta-rule="BEING > rule" (§0 SER>Regras)
```

## Composition (the wiring — DRY; every phase lands on an existing primitive)

| Phase | Composes (reimplements nothing) |
|---|---|
| RECON | `maos:preflight` / `skills/pulse` + Skopos recon (CASC Gate-0) + prior-ledger read |
| RECAP | `skills/agentic-session-harness` (ASH tool-call meta-trace) + transcript / `.remember/` / CPT topology → praxis-register |
| AUDIT | `skills/corpus-firing-audit` **lens, retargeted** onto session praxis (FIRING/THEATER/STALE → FIRED-WELL/THEATER/INCONSISTENT/MISFIRE/GAP; `sharpen>add`) |
| RESEARCH | `skills/enhance-pipeline` (EXPAND — internal+external; Task sub-skill with its own web allowlist) |
| COUNCIL | `skills/convergence-engine` (regime-router + master condition) · `maos:perspective-trio` (breadth) · `maos:persona-pipeline` (independent verify) · `skills/red-team` (adversarial) · `skills/converge` (5-act + reject-log) |
| FIX | `skills/gap-loop` (5-phase: MoE resolve + independent VALIDATE + derived score + PERSIST; worktree-disciplined) · `maos:postflight` P1-SWEEP |
| SUBJECT | **this skill's own contribution** — the session's OWN enacted praxis (self-referential; the *how*) |

Operator `--auto-self-fix/-heal` = the FIX phase (gap-loop); `--family-aware` = by construction (reads/classifies the family's own tools). NOT new machinery — de-theatered mapping in `reference.md`.

## Override parameters

| Flag | Default | Allowed / Notes |
|---|---|---|
| `"<instructions>"` (positional) | empty | extra free-text narrowing the audit focus |
| `--scope` | `this.session` | `this.session` \| `session:<id>` \| `branch` \| `ticket:<id>` |
| `--source` | `auto` | `auto` (capability-detect) \| `ash` \| `transcript` \| `remember` \| `commits` \| `topology` |
| `--autonomy-threshold` | `0.85` | `0.0`-`1.0` — FIX score gate (bands SSOT `agents/COWORK-AUTONOMY-POLICY.md`) |
| `--max-iterations` | `6` | int — FIX loop cap → gap-loop |
| `--auto-merge` | `hold` | `authorized` \| `hold` \| `off` — default **hold** (EKO-66: STAGE-only) |
| `--auto-merge-reason` | *(none)* | non-empty — **required when `--auto-merge=authorized`** (`auto-merge-standing` G8) |
| `--dry-run` | off | RECON→COUNCIL only; print confirmed findings + fix-plan; drive NO FIX |
| `--output` | `text` | `text` \| `json` (run envelope below) |

Defaults are **fixed**; `--source=auto` and the COUNCIL seat-roster are computed **dynamically at runtime** (capability-detect + convergence-engine rotation).

## Output contract (`--output=json`)

```json
{"stage":"RECAP|AUDIT|RESEARCH|COUNCIL|FIX","status":"ok|hitl|error",
 "stop_marker":"STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE",
 "praxis_register":[{"id":"M1","method":"<...>","kind":"<...>","verdict":"FIRED-WELL|THEATER|INCONSISTENT|MISFIRE|GAP","evidence":"<ref>","cure":"<sharpen|add|none>"}],
 "pulse":{"fired_well":0,"theater":0,"inconsistent":0,"misfire":0,"gap":0},"confirmed_by_council":0,"autonomy_score":0.0}
```

Exit: `0` STOP-DONE · `1` STOP-ERROR · `2` STOP-HITL (authority gap / dry-run parked). Emit exactly ONE `<!--ORCH-STATUS: STOP-DONE|STOP-HITL|STOP-ERROR|CONTINUE -->` as the last line of each turn.

## Protocol Rules (anti-loop invariants)

- Read-only through COUNCIL; the ONLY mutating phase is FIX (worktree-disciplined; `--dry-run` skips it). `allowed-tools` (`Task, Read, Write, Edit, Bash, Grep, Glob`) matches sibling conductors `gap-loop`/`ooda-loop`; Write/Edit/Bash are exercised **only** in FIX — the restriction is a protocol contract (per-phase frontmatter tool-gating is not a Claude Code primitive).
- `verifier != generator` (persona-pipeline / gap-loop VALIDATE) — a verdict survives only if an INDEPENDENT seat confirms it. Never re-loosened. red-team the audit itself: a finding the adversary dissolves is dropped.
- RECAP/AUDIT read the session's OWN enacted-tool log (ASH/transcript/`.remember`/CPT) + public composition manifests — NOT peer skills' prompt-bodies or secrets.
- `--max-iterations` (6) caps FIX; same-panel re-run FORBIDDEN. HUMAN_DOMAIN + non-negotiable guardrails (secrets/PII, force-push protected, prod/irreversible, cross-org) are HARD gates → escalate, never self-authorize.

## Examples

```text
praxis-audit --scope=this.session --dry-run                 # audit this session's methods; print findings + fix-plan; drive nothing
praxis-audit --scope=this.session                           # audit → research → council → fix (FIX STAGE-only by default, EKO-66)
praxis-audit "focus on the verifier != generator gates"     # narrow the focus
praxis-audit --auto-merge=authorized --auto-merge-reason="method-fixes, green CI"   # reason required when authorized
```

## Validation

`tests/validate-plugin.sh` checks (generically) that `skills/praxis-audit/` contains a `SKILL.md` and that `commands/praxis-audit.md` begins with `---`. It does **not** parse YAML or assert a `name:` match — deeper frontmatter/name validation is by review + the `skills/skill-writer/SKILL.md` 10-item checklist, not the CI script. No separate protocol file (methodology inherited from the composed primitives — `corpus-firing-audit`'s self-contained precedent).

## Related

`commands/praxis-audit.md` · `skills/corpus-firing-audit` (the retargeted lens) · `skills/{goal-recovery,ooda-loop}` (the *what*) · `skills/enhance-pipeline` (RESEARCH) · `skills/convergence-engine` + `agents/{perspective-trio,persona-pipeline}.md` + `skills/{red-team,converge}` (COUNCIL) · `skills/gap-loop` (FIX) · `skills/agentic-session-harness` (RECAP) · `agents/COWORK-AUTONOMY-POLICY.md`. Extended rationale, proofs, external grounding, §DUED, dogfood log → **`reference.md`**.

## License

MIT (matches multi-agent-os repo `LICENSE`).
