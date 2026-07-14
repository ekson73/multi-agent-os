---
name: council-gate
description: Pre-HITL democratic council-authorization gate (Boule). Runs everything destined for HITL fallback through a democratic council FIRST; authorizes safe/reversible/non-HUMAN_DOMAIN actions in place of the human on convergence at score>=0.90 under an operator-ratified arming lease, else falls back to HITL with ranked contestable recommendations. Ships UNARMED (consultative until ratification).
---

# /council-gate Command

Invokes the `council-gate` skill (soul-name *Boule*) — a **pre-HITL democratic council-authorization gate**.

## Usage

```
/council-gate "<the decision that would otherwise fall back to HITL>" [--armed] [--stakes trivial|low|medium|high] [--seats <a,b,c>] [--json]
```

## What it does

Everything destined for HITL fallback passes through this gate **first**. It runs a **two-layer** evaluation:

1. **Layer 1 — deterministic deny-set** (out-of-band, evaluated FIRST, independent of confidence): secrets · production PII · irreversible/prod · merge→main/prod · push-force · `--no-verify` · cross-org · $$$ · critical-infra/CI · `[C17]` §2 HUMAN_DOMAIN. Match → **HARD BLOCK → HITL**. The council can never open this.
2. **Layer 2 — democratic council** (only within the cleared band): role-advisors (dev-fe/dev-be/dba/devsecops/dpo + more by stakes) converge (verifier > generator, independent). On convergence + `autonomy_score ≥ 0.90` + reversible + **armed**, the gate **authorizes in place of the human** (executes + `decision-capture` audit).

Otherwise → **HITL fallback with ranked, contestable recommendations + confidence + audit trail** (never a blank ask).

## Default posture: UNARMED

Ships **consultative**. `--armed` is honored ONLY under an operator-ratified standing grant OR an explicit per-invocation operator authorization — there is **no self-arm**. Unarmed, it emits the `AUTHORIZE` verdict + a 1-touch confirm rather than executing.

## Governance SSOT

`~/.claude/rules/council-gate.md` (the constitutional rule) + `skills/council-gate/SKILL.md` (the executable protocol). Composes `maos:{persona-pipeline,perspective-trio,cascade-resolver,convergence-engine,decision-capture}` + `bin/convergence-guard`. Cross-link: `[[council-gate]]`.
