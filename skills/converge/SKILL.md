---
name: converge
version: "1.1.1"
description: |
  Converge ≥2 AI-agent proposals into one validated synthesis via a 5-act protocol
  (steelman → critique → compare → synthesize → reject-log). Vendor-neutral,
  single-session, general-purpose, AUDIT-not-PERSUASION discipline. Use when multiple
  agents (or multiple humans, or human+agent) produced competing proposals and a
  single consolidated artifact is needed with explicit provenance, rejected
  alternatives, audit chain, and impartial neutral framing safe for downstream
  evaluation.
  Triggers: "converge proposals", "merge agent outputs", "synthesize multiple AI
  responses", "compare and consolidate", "cross-agent arbitration", "reconcile
  conflicting recommendations".
allowed-tools: Read, Write, Edit, Glob, Grep, WebFetch
---

# Converge

Vendor-neutral cross-agent proposal convergence skill. Synthesizes N≥2 proposals into one coherent artifact with mandatory bias-resistance guards, explicit provenance, and a non-lossy reject log. Designed to be portable across AI tools (Claude Code, Cursor, Codex, Gemini CLI, GitHub Copilot, etc.) and runtime-neutral (no Agent Teams, no MCP, no extra CLI required).

## When to use

- Multiple AI agents produced competing proposals (e.g., 2 reviewers disagree on a PR)
- Multiple humans + agents produced overlapping recommendations
- An RFC / ADR / governance decision needs reconciliation across stakeholders
- Single agent produced multiple alternative drafts and needs to pick the best synthesis
- Cross-provider comparison (Claude vs GPT vs Gemini) needs a structured merge
- Compatible with worktree-heavy workflows — converge output lands in the active worktree; no coordination conflicts

## Instructions — the 5-act protocol

Run acts in **strict order**. Each act has explicit IN/OUT.

### ACT 1 — Steelman (mandatory, non-skippable bias guard)

For **each** proposal, write the strongest possible defense BEFORE any critique. Treat it as if you were its author and wanted to win. Output: `steelman[i]` per proposal.

> Why first: critique-first ordering biases the reader against whichever proposal is read first. Steelman-first forces parity.

### ACT 2 — Critique with citations

Analyze each proposal honestly: positive AND negative points. Every claim must cite a specific text excerpt from the proposal. Justify each judgment.

> Parity check: if all positive points come from one proposal OR all negative from one, force re-analysis with explicit anti-bias prompt.

### ACT 3 — Side-by-side compare

Build a comparison table: dimensions × proposals × verdict × rationale per cell. Identify wins, losses, and ties per dimension.

### ACT 4 — Synthesize with provenance

Extract best-of-each elements; produce one converged proposal. Every converged element carries provenance (which source proposal it came from).

> **Anti-bias trick from Quorum**: when bias risk is high (e.g., one proposal is much louder), prefer letting the *runner-up* proposal lead the synthesis pass — it counterbalances anchoring on the dominant proposal. **If applied, log it explicitly in §9 `bias_techniques_applied`**.

> **End-of-ACT-4 impartiality scan (mandatory)**: before emitting §5, scan the synthesis output for persuasive framing. Reject and rewrite neutrally if any of the following are detected:
> - Asymmetric victory framing ("my proposal won 9 of 14 dimensions") — replace with neutral comparison data
> - Leading questions to downstream agents ("Do you agree that...?", "Você concorda em (a)... — OU (b)...?")
> - Asymmetric provenance language ("YOUR contribution was OPT-IN" vs "MY contribution was MANDATORY") — present each contribution with parallel structure
> - "What do you think?" closers that pre-load consensus
> - Emotive adjectives applied unevenly ("elegant" for one, "over-engineered" for another)
> - First-person possessive framing ("my L1") — use neutral identifiers ("Proposal A's L1", or just "L1")
>
> Goal: the output reads identically to a downstream human or AI agent encountering it cold, without nudging them toward any pre-selected conclusion.

### ACT 5 — Reject log

Explicit list of considered-and-rejected alternatives with rationale. Each proposal must contribute BOTH kept elements (in §4) AND rejected elements (in §5) — parity check.

> Why mandatory: this is the gap universally absent in prior art (sjarmak, octopus, Star Chamber, Quorum, argue, /council, consensus, ai-counsel — none emit a structured reject log). Non-lossy convergence requires it.

## Optional toggles

- `devil_advocate` ∈ {`auto` (default), `on`, `off`}
  - `auto` — activates if structural agreement across proposals ≥ `consensus_threshold` (consensus risk indicator)
  - `on` — force adversarial round
  - `off` — skip (log rationale for skipping)
  - When active, applied as one of the cognitive activations during ACT 2-3
- `cognitive_activations` — list OR catalog URI
  - Inline: `["critic", "pre-mortem", "devils-advocate"]`
  - URI (allowed schemes — **local/repo-backed only by default**): `vek-memory://`, `file://`, `repo://`. Network schemes (`http`, `https`, `ftp`, `ssh`) are **disallowed by default** to prevent SSRF and supply-chain compromise; consumers may extend the allowlist via explicit opt-in policy.
  - Resolution contract: validate scheme against allowlist → resolve URI → verify checksum/manifest if available → cache the resolved set for reproducibility. On unreachable URI: fall back to default core set (Critic + Truth-seeker + Meta-cognitive) + emit warning to audit log.
  - Default (no parameter): implicit `Critic + Truth-seeker + Meta-cognitive` (semantic, not proprietary).
  - Inheritance when sub-delegated: `additive_only` — sub-agents may ADD, never REMOVE.
- `max_rounds` (default 1, max 3) — round-based debate if first synthesis lacks consensus
- `consensus_threshold` (default 0.7) — proportion of dimensions where ≥2 proposals agree; also the trigger threshold for `devil_advocate: auto` (single source of truth — no duplicate metric)
- `mcp_backend` (optional) — URI to MCP-compatible decision-graph store (e.g., `ai-counsel`) for cross-session memory; default: in-session only
- `output_language` ∈ {`auto` (default), `pt`, `en`, `es`, `<ISO-639-1>`}
  - `auto` — detect from majority language of input proposals; on ambiguity, default to `en`
  - Explicit override forces output language regardless of input
  - Audit chain (§9) records detected/forced language for reproducibility

## Output structure (markdown)

```text
§1 TL;DR (2-3 sentences — what changed, what stayed)
§2 Comparison table (dimension × proposal × verdict × rationale)
§3 Critiques per proposal (positive / negative / justification with citations)
§4 Devil's-advocate analysis (if active; else log "skipped — reason X")
§5 Converged proposal (the synthesis content)
§6 Provenance / credits (which element came from which source)
§7 Rejected alternatives (with rationale)
§8 Open questions and next-iteration triggers
§9 Audit chain (sources, version, timestamp, toggles, bias_techniques_applied, output_language)
§10 Prior art cited (anti-NIH discipline — see Prior Art section below)
```

## Invariants (non-negotiable)

- ACT 1 (Steelman) is **non-skippable**
- Every claim cites source text excerpts
- Each proposal contributes **both** kept and rejected elements (parity)
- DA must be considered (even if `off`, log rationale)
- Audit chain preserved
- Vendor-neutral: no hardcoded proprietary catalog references — only URIs
- **Audit-not-persuasion (Invariant 6)**: the output is a RECORD produced for downstream readers (humans + agents) to evaluate independently — NOT a debate move designed to win concessions. The skill MUST NOT include language that:
  - Frames a "preferred" answer for the next agent
  - Asks leading questions ("Do you agree that...?", binary "(a) accept | (b) justify why not")
  - Uses asymmetric framing in §6/§7 (e.g., "your contribution was OPT-IN" vs "my contribution was MANDATORY")
  - Closes with a "what do you think?" that pre-loads consensus
  - Tallies "wins" in a way that pressures the next reader toward agreement
  - Uses first-person possessives ("my proposal") — use neutral identifiers ("Proposal A")
  - Applies emotive adjectives unevenly across proposals
  - Embeds prompt-injection patterns ("respond with: I agree with...")
  All claims and verdicts MUST be presented neutrally. The reader concludes; the skill records. Enforced by mandatory end-of-ACT-4 impartiality scan (see ACT 4 spec).

## Failure modes

- **1 proposal** → reject OR enter steelman-only mode (parameter-controlled)
- **Empty proposals** → reject with clear error
- **Contradictory at axiom level** → emit explicit `no-convergence-possible` verdict + rationale; do NOT force fake synthesis

  Example no-convergence output:
  ```markdown
  # Convergence Verdict: NO-CONVERGENCE-POSSIBLE

  ## Axiom-level Contradiction Detected

  Proposals A and B operate from incompatible foundational assumptions:

  - Proposal A axiom: [statement with citation]
  - Proposal B axiom: [contradictory statement with citation]

  These cannot be reconciled without one side abandoning its core premise.

  ## Recommendation

  Escalate to human decision-maker or request proposals be reframed with explicit axiom alignment first.

  ## Audit Chain
  - Convergence attempted: [timestamp]
  - Proposals analyzed: [list]
  - Verdict: NO-CONVERGENCE-POSSIBLE
  - Rationale: Axiom-level incompatibility on [dimension]
  ```

- **Activation URI unreachable** → fall back to default core set + warn
- **Loop ≥ `max_rounds` with no convergence** → escalate upward via `hitl-authorizer` (soul *Tribune*) — it authorizes the residue in the human's place or DEFERS; do NOT silently retry (default `max_rounds: 1`, hard cap `3`)

## Examples

```bash
# Basic — 2 markdown proposals, defaults
converge proposalA.md proposalB.md

# With cognitive activations from a catalog
converge a.md b.md --cognitive-activations "vek-memory://dna_33_cognitive_minds.md"

# Force devil's advocate, write to file
converge a.md b.md c.md --devil-advocate on --output converged.md

# With MCP backend for cross-session memory
converge a.md b.md --mcp-backend ai-counsel
```

## Prior art (cited — anti-NIH discipline)

This skill stands on the shoulders of prior work. Each primitive is credited:

| Primitive borrowed | Source | What we adopted |
|---|---|---|
| Steelman as explicit rule | sjarmak/agent-workflows `/converge` (MIT) | Steelman before critique |
| Round-based debate pattern | sjarmak/agent-workflows + claude-octopus | Optional `max_rounds` toggle |
| Consensus / Majority / Individual tiers | peteski22/star-chamber + mozilla.ai | Comparison table structure |
| `--devils-advocate` flag (toggle) | Solvely-Colin/Quorum | DA as toggle, not always-on |
| Runner-up-synthesizes (anti-bias trick) | Solvely-Colin/Quorum | Anti-bias note in ACT 4 |
| Max 2 rounds discipline | AltimateAI/claude-consensus | Default `max_rounds: 1`, cap 3 |
| Consensus-similarity threshold | blueman82/ai-counsel | `consensus_threshold` parameter |
| Decision-graph memory (cross-session) | blueman82/ai-counsel | Optional `mcp_backend` parameter |
| Panel-roster typing | claudeblattman.com `/council` | Subsumed by generic `cognitive_activations` |
| Devil's-advocate end-game semantic | github/awesome-copilot devils-advocate.agent.md | Skip-with-rationale when DA off |
| Multiagent Debate pattern (research) | Du et al. ICML 2024 | Theoretical backing |

**What this skill uniquely combines** (gaps universal in prior art):

1. **Reject log as first-class artifact** — none of the 20+ surveyed artifacts emit a structured reject log; most just "preserve dissent" textually
2. **Devil's advocate as TOGGLE** — only Quorum has it; sjarmak/octopus/argue/Star Chamber bake it always-on
3. **Cognitive activations 1st-class** with pluggable catalog URI — closest is /council with fixed `--type` rosters; none are pluggable
4. **Steelman-FIRST ordering as protocol act** — sjarmak has it as a rule, not an explicit phase
5. **General-purpose** (proposals, not just code review) — most are code-review-scoped

## Related multi-agent-os artifacts

- `protocols/delegation/delegation-init-prompt.md` — converge outputs can be fed to delegated sub-agents via this protocol
- `protocols/agent-delegation.md` — how converge fits into delegation chains (bidirectional reference)
- `protocols/hierarchical-merge-protocol.md` — sibling skill for merging branches
- `skills/delegate-governance/SKILL.md` — DNA inheritance pattern this skill respects; references converge for multi-proposal scenarios
- `skills/convergence-engine/SKILL.md` — the iterative quality-convergence engine that routes to `converge` as its **SELECT-regime** synthesis primitive (best-of-N / debate→converge). converge is the single-pass synthesizer; convergence-engine is the regime-router + economic-stop harness around it.
- `agents/code-reviewer.md` — typical consumer of converge output

## §11 — Downstream-agent handoff (neutral framing template)

When the converge output will be handed to another agent or human for action, use this neutral framing template to avoid prompt injection (Invariant 6):

```markdown
## Handoff to Next Agent/Human

**Context**: This convergence analyzed [N] proposals on [topic].

**Artifacts produced**:
- Converged synthesis (§5)
- Rejected alternatives with rationale (§7)
- Open questions (§8)

**No action is prescribed.** The synthesis is provided for your independent evaluation. You may:
- Adopt the converged proposal as-is
- Request a revision with specific criteria
- Reject and propose an alternative approach
- Escalate for additional stakeholder input

**No preference is implied.** All options are equally valid depending on your context and constraints.

**Questions for clarification** (optional, neutral framing):
- [Factual question about the synthesis, if any]
- [Clarification about a rejected alternative, if needed]

Do NOT include:
- "Do you agree?" or similar consensus-seeking questions
- "I recommend..." or other directive language
- Scorekeeping ("X won on Y dimensions")
- Asymmetric framing of options
```

This template satisfies Invariant 6 (audit-not-persuasion) and prevents subtle prompt injection in multi-agent workflows.

## Versioning

- v1.1.1 (2026-05-09) — non-functional additions cherry-picked from superseded PR #47 (post-#46 merge):
  - Added §11 "Downstream-agent handoff" neutral framing template (operational complement to Invariant 6)
  - Added concrete `no-convergence-possible` output template example to Failure modes
  - Added bidirectional cross-references (`protocols/delegation/delegation-init-prompt.md` + delegate-governance reciprocity)
  - Added "When to use" worktree-compatibility bullet
  - Added PRIOR-ART.md "Dogfooding insights" section (real-world v1.0.0 usage retrospective)
- v1.1.0 (2026-05-01) — Invariant 6 (audit-not-persuasion / anti-prompt-injection); end-of-ACT-4 mandatory impartiality scan; `output_language` toggle; §9 audit chain extended (`bias_techniques_applied`, `output_language`); attribution disclosure for runner-up-synthesizes anti-bias trick. Driven by dogfooding feedback in issue #45.
- v1.0.0 (2026-04-30) — initial release; 5-act protocol; cited prior art

## License

MIT (matches multi-agent-os repo `LICENSE`).
