# Adapter — agentic-tools (skill · command · agent · subagent · mcp · plugin · marketplace · rule · hook)

> This adapter carries the **agentic-tools** naming conventions (agent register). `agentic-tool-forge` Phase 4
> delegates to the **`anima`** skill, which routes here for skill/command/agent/etc. names (`../SKILL.md` §3 + §6.5).

## Conventions
- **Case/length**: `kebab-case`, ≤6 words, lowercase. One artifact = one name; the `/command` mirrors its skill's name.
- **Role-typed + semantic**: the name says what it *does* or the *role* it plays (`pr-diff-digest`, `transcript-corrector`), not a vague label (`helper`, `util`).
- **Family-aligned**: align to an existing namespace when one exists — lifecycle family `agentic-tool-{forge,evaluator,trainer}` · concierge family `*-concierge` · gstack `plan-*`/`design-*` · maos `*` peers. Honor `--family`.
- **No operator-personal names** (universal #10) — role-types only, never `alice-*`/`bob-*`.
- **No host-vendor lock** in the name (AAIF cross-vendor): avoid `claude-`/`cursor-` prefixes unless the tool is genuinely host-specific.
- **Collision check (§5)**: `Grep` `~/.claude/{skills,commands,agents,rules,hooks}/` + the plugin skill-list for an existing same-name artifact before pronouncing.

## Type-word hints (helps semantics + ontology aspects)
- workflow/engine → noun or verb-noun (`session-fission`, `convergence-engine`) · router/concierge → `*-concierge`/`*-router` · detector/auditor → `*-detector`/`*-auditor` · corrector/normalizer → `*-corrector`.

## Worked example (self-baptism — see SKILL §7)
Subject: *this very naming tool* (an agent-register skill) → candidates `anima` · `nomira`(taken) · `namer`(taken+generic) · `onoma`(flat) · `nomenclator`(religion-coded persona + sprawl).
**Decision: `anima`** — Latin "soul/breath" (Aristotle/Jung); atomic single-word kebab, role-typed via the descriptor
"the namer", secular global-universal (no vendor/culture lock), synergic with `agentic-tool-forge` (body↔soul). System-name `anima`; no soul-name needed (the tool IS the namer).

## Sources
- `agentic-tool-forge` §5-axis naming engine · `[C09]` Naming Conventions · `root-cause-first-prevention-priority §10` (5-axis rigor) · MS patent US12487817 (artifact-name collision-against-autocomplete pattern).
