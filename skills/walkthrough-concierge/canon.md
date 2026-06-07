# CANON — walkthrough-concierge anchor SSOT

> Canonical ASH decisions a fresh agent/human re-finds here instead of re-deriving (anchor-mode source). Each = the decision + why + the corrective pointer when drift is detected. Schema SSOT remains the docs; this is the **decision index**, not a copy.

| # | Canonical decision | Why | Drift to flag |
|---|---|---|---|
| C1 | **Journals stamp `schema_version: 1.0.0`** (the frozen Layer-1 row contract, SPEC.md §2) | the §17 decision-audit fields are an ADDITIVE extension inside `decisions[]`, not a row-version bump | any journal stamping ≠ 1.0.0 for current entries |
| C2 | **`decisions[]` is auto-captured STRUCTURALLY at Stop by `stop-fallback.sh`** (v1.6.2) | the Stop `type:agent` hook empirically never wrote (0/17) — the fallback is the reliably-firing extraction path | treating type:agent step-10 as the live extraction path (it's a no-op) |
| C3 | **`XDEC-<n>` = eXtracted (structural floor); `DEC-<n>` = explicit `agentic-decide` (high-fidelity "why" ceiling)** | distinct id namespaces never collide; `decide-merge.sh` keeps both, deduped by id | reusing `DEC-`/`XDEC-` across the wrong source; id collision |
| C4 | **Anti-hallucination: no transcript/`agentic-decide` evidence ⇒ decision omitted** (never fabricated) | a fabricated audit is worse than an empty one (anti-theater Layer-5 R3/R4) | inventing decisions with no git/gh/transcript signal |
| C5 | **`spec_alignment ∈ {aligned, divergent, unverified}` is THE drift signal**; structural extraction sets `unverified` | the operator's core pain = "why did the agent diverge from the SPEC"; `divergent` is the filterable answer; `unverified` = structural couldn't assert | claiming `aligned`/`divergent` without evidence |
| C6 | **Layer-1 (`SPEC.md`, the agentic-session-harness spec) is FROZEN-17** (generic, vendor-neutral) | cross-vendor portability; org-specific extensions live in Layer-2 only | adding org/corporate content to Layer-1 (purity violation) |
| C7 | **`decide-merge.sh` runs LAST in the Stop chain**; staged `DEC-` win on id-collision | self-declared-at-decision-time > post-hoc reconstruction | re-ordering the Stop chain so merge runs before the entry exists |
| C8 | **Cross-repo promotion is a governance/PR action** (Layer-1 promoted to multi-agent-os 2026-06-02 via operator override of the dogfood gate; recorded in the promotion ledger) | promotion is deliberate + audit-trailed, never silent | re-promoting or forking without a governance PR + ledger record |

## Anchor-mode usage
`--mode=anchor` → surface the relevant C# + the contradiction observed + the corrective pointer (the schema § OR the SKILL Phase-0 probe). Never silently pass a contradiction; never mutate to "fix" — propose.
