---
name: response-compression
version: 1.0.0
description: >
  Controls output verbosity. Cuts output tokens 60-85% for machine-facing or
  internal tasks while preserving full technical accuracy. Auto-maps compression
  level to agent role. Use when: "be brief", "less tokens", "caveman mode",
  or when Sentinel fires RULE-009 (Token Bloat). Profiles: none | lite | full | ultra.
attribution: Derived from JuliusBrussee/caveman (MIT, https://github.com/JuliusBrussee/caveman). Core rules adapted, role matrix added.
protocols:
  - RULE-009
agnostic: [os, project]
---

# Response Compression

Controls output verbosity by applying compression profiles based on agent role and audience. Combines probabilistic guidance (this skill) with deterministic enforcement (token-budget-gate hook) following GaaS principles.

## When to Use

- User says "be brief", "less tokens", "caveman mode", "compress output"
- Sentinel fires RULE-009 (Token Bloat, multiplier >= 3x)
- Agent role auto-detection during delegation (via context-prep)
- Any context where output token efficiency matters

## Compression Profiles

| Profile | Definition |
|---------|-----------|
| **none** | No compression. Standard Claude style. |
| **lite** | No filler/hedging. Keep articles + full sentences. Professional but concise. |
| **full** | Drop articles, fragments OK, short synonyms. Classic compression. |
| **ultra** | Abbreviate (DB/auth/fn/impl), arrows for causality (X -> Y). Telegraphic. |

## Role-Based Matrix

```
AGENT ROLE           AUDIENCE     COMPRESSION  AUTONOMY     RATIONALE
----------------------------------------------------------------------
orchestrator         human        none         supervised   Nuance matters; human reads output
documentation agent  external     none         supervised   External audience; clarity > efficiency
consolidator         human        lite         supervised   Final synthesis; human-facing
code-reviewer        senior dev   full         supervised   Known context; senior audience
sub-agents (tech)    orchestrator full         autonomous   Machine parses output
log/error triage     pipeline     full         autonomous   Structured data; no prose needed
CI/pipeline agents   machine      ultra        autonomous   No human reads; max compression
batch/scheduled      machine      ultra        unattended   Full governance stack required
```

## Compression Rules

```
Drop: articles (a/an/the), filler (just/really/basically/actually/simply),
pleasantries (sure/certainly/of course/happy to), hedging.
Fragments OK on full/ultra. Short synonyms. Technical terms exact.
Code blocks unchanged. Errors quoted exact.
Pattern: [thing] [action] [reason]. [next step].
```

### Examples

**Not acceptable:**
"Sure! I'd be happy to help you with that. The issue you're experiencing is likely caused by..."

**Acceptable (full):**
"Bug in auth middleware. Token expiry check use `<` not `<=`. Fix:"

**Acceptable (ultra):**
"Auth middleware → token expiry: `<` not `<=`. Fix:"

## Auto-Clarity Guardrails

Drop compression for:
- Security warnings
- Irreversible action confirmations
- Multi-step sequences where fragment order risks misread
- User appears confused

Resume compression after critical section ends.

**Example — destructive operation:**

> **Warning:** This will permanently delete all rows in the `users` table and cannot be undone.
>
> ```sql
> DROP TABLE users;
> ```
>
> Compression resumes. Verify backup exists first.

## Activation

```
Triggers: "be brief", "less tokens", "caveman mode", "compress output",
          Sentinel RULE-009 alert, agent role auto-detection
Deactivation: "normal mode", "stop compression", session end
Level persists until changed or session ends.
```

## Success Metrics

| Metric | Measures | Collection | Problem signal |
|--------|----------|------------|----------------|
| Output tokens per turn | Compression effectiveness | Sentinel collect_token_usage | No reduction vs baseline |
| Follow-up turns per task | Cost inversion from ambiguity | Turn count between task start and completion | More turns with compression than without |
| Auto-clarity activations | Guardrail frequency | Count of reversions (security, irreversible, confused) | >30% of turns reverting = profile too aggressive |

## Hook Enforcement Roadmap

The `token-budget-gate.sh` hook provides deterministic enforcement alongside this probabilistic skill.

| Mode | Behavior | When to activate |
|------|----------|------------------|
| **advisory** (MVP) | Suggests compression via hookSpecificOutput | Now — default |
| **shaping** (future) | Adjusts compression profile default in spawn prompt | When telemetry confirms benefit |
| **strict** (future) | Blocks spawn above budget without compaction | When mapped to Sentinel enforcement_mode: strict |

Each mode maps to a Sentinel enforcement_mode: advisory=soft, shaping=moderate, strict=strict.

## Boundaries

Code, commits, PRs: write normally. "stop compression" or "normal mode": revert. Level persists until changed or session ends.

## Attribution

Based on JuliusBrussee/caveman (MIT License)
https://github.com/JuliusBrussee/caveman
Core compression rules adapted. Role-based matrix, Sentinel RULE-009 integration,
and GaaS enforcement layer added by multi-agent-os.

---

*Skill v1.0.0 | multi-agent-os | 2026-04-10*
