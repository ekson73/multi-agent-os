# AWARENESS-REGISTRY.md — MAOS framework landscape (the concierge payload)

> **Companion to** `SKILL.md` (maos-concierge). This is the `--mode=explain` + `--mode=guide` lookup table.
> **Vendor-neutral** (MIT / AAIF cross-vendor). **Last verified**: 2026-05-28 against MAOS v1.5.2.
> **Convention**: this registry is *referenced*, not duplicated, by callers (per the framework-consumption "reference, don't copy" rule). Counts are point-in-time — `--mode=audit` re-derives from `ls` and flags drift.

---

## Tier ladder (how to think about the framework)

```
Tier 0  Orchestration spine   → orchestrator agent · /delegate · /parallel · auto-pilot
Tier 1  Creation              → The Forge (forge agent) + 33Q + RBAD + Goldilocks
Tier 2  Safety governances    → Anti-Conflict · Hierarchical-Merge · Worktree-Policy · TTL-Policy
Tier 3  Observability         → Sentinel Protocol (audit · sentinel-monitor) · Status Maps
Tier 4  Delegation governance → GaaS/GaaC (delegate-governance + init/dna/finalize + provider-matrix)
Tier 5  Domain advisories     → founder-playbook + founder-stage-* · MVV (ontological-analysis)
Tier 6  External reach        → maos-mcp-hub (6 typed Atlassian gateways)
```

## Agents (`agents/*.md`)

| Agent | One-line role |
|---|---|
| `orchestrator` | Master coordinator — decomposes goals, spawns + sequences sub-agents |
| `forge` | The Forge — meta-agent creator (33Q + RBAD + Goldilocks); creates agents, doesn't solve domains |
| `sentinel-monitor` | Anomaly detection / observability over orchestration traces |
| `qa-validator` | Quality assurance gate before session end |
| `consolidator` | Synthesizes outputs from multiple sub-agents |
| `code-reviewer` | Code review specialist |
| `debugger` | Root-cause analysis |
| `data-analyst` · `data-validator` | Data analysis · validation/evidence capture |
| `governance-auditor` | Standards/compliance/pattern enforcement |
| `legacy-archaeologist` | Reverse-engineer old codebases → target-agnostic specs |
| `memory-curator` | Knowledge/memory hygiene |
| `naming-organizer` | Taxonomy + naming conventions |
| `validation-auditor` | Second-line auditor (verifies validations) |
| `founder-coach` | AI-native startup lifecycle coach |
| `gitops-engineer` | K8s/GitOps declarative infra |
| `consultants/*` | Thinking-archetype consultants (persona lenses) |

## Skills (`skills/*/SKILL.md`) — ~31

| Cluster | Skills |
|---|---|
| Orchestration/delegation | `agent-select` · `agentic-delegation` · `delegate-governance` · `context-prep` · `auto-pilot` |
| Conflict/merge/worktree | `anti-conflict` · `hierarchical-merge` · `worktree-policy` |
| Observability | `audit` · `status-map` |
| Lifecycle/freshness | `ttl-policy` · `morning-briefing` · `pulse` · `quiesce` |
| Synthesis/convergence | `converge` · `consolidator` (agent) |
| Governance hygiene | `rule-quality-tests` · `operator-quote-capture` · `response-compression` · `slm-routing` · `pii-masking` |
| Creation/authoring | `skill-writer` · (forge agent) |
| Knowledge/MVV | `mvv-synthesis` · `ontological-analysis` · `notebooklm` · `find-docs` |
| Founder | `founder-playbook` · `founder-stage-idea` · `founder-stage-mvp` · `founder-stage-launch` · `founder-stage-scale` |

## Commands (`commands/*.md`) — ~14

`/sync` (framework sync) · `/audit` · `/agentic-status` · `/worktree` · `/delegate` · `/auto-pilot` · `/auto-shard` · `/mvv` · `/quiesce` · `/founder-playbook` · `/analyze` · `/code` · …

## Protocols & governances

| Governance | What it does | Source |
|---|---|---|
| **Sentinel Protocol** | 10 detection rules, health score 0-100, auto-block on HIGH (loops/depth), trace logging `.claude/audit/session_*.jsonl` | `sentinel/detection_rules.md` · `sentinel/config.json` |
| **Anti-Conflict Protocol v3.2** | 7-phase workflow, mandatory git worktree, lock-file coordination for protected files, mandatory QA before session end | `skills/anti-conflict` |
| **Hierarchical Merge Protocol** | Branches merge to **parent**, not directly to main; Child Completion Constraint; exception prefixes `bugfix/ hotfix/ emergency/` | `protocols/hierarchical-merge-protocol.md` |
| **Worktree Policy** | Mandatory worktree for any file modification; dir `.worktrees/{agent-short}-{feature}/` | `skills/worktree-policy` |
| **TTL Policy** | Content freshness by type (14-180 days); PROV tags; states FRESH→EXPIRING→EXPIRED | `skills/ttl-policy` |
| **GaaS/GaaC Delegation** | Spawn governance: init/dna/finalize prompts + provider-matrix (Ticket×VCS×Secrets×Observability) | `protocols/delegation/` · `plugin-scripts/gaac/delegate.sh` · `skills/delegate-governance` |
| **The Forge** | Agent-creation discipline: 33 Socratic Questions + RBAD taxonomy (6 categories) + Goldilocks Principle (atomic ∧ generic) | `agents/forge.md` |
| **Status Maps** | 9 ASCII template types for human-readable status; human-observability value | `statusmap/templates/` · `skills/status-map` |
| **maos-mcp-hub** | Universal MCP gateway — 6 typed Atlassian meta-tools (discover/jira/confluence/bitbucket/compass/common), 4-level progressive discovery, `_agent_feedback` hints | `mcp-tools/maos-mcp-hub/` |

## Core concepts (vocabulary the concierge teaches)

- **GaaS** (Governance-as-a-Service) / **GaaC** (Governance-as-Code) — delegation governance surfaced as discoverable skill + CLI.
- **RBAD taxonomy** — 6 categories for sourcing the best resource: IT roles · C-suite · traditional professions · modern specializations · real personas · fictional archetypes.
- **Goldilocks Principle** — an agent/skill must be *atomic* (one clear scope) AND *generic* (solves ANY task in that scope).
- **Reference, don't duplicate** — MAOS is the source-of-truth framework; consumers reference (PROV tags), never copy.
- **Human observability** — automation always emits human-readable visibility (Status Maps), not just machine logs.
- **Hierarchical convergence** — parallel work converges through controlled hierarchies, not direct merges.

## What to SKIP (anti-bloat — concierge tells you what NOT to reach for)

- Don't reach for `auto-pilot` for a single trivial edit — use a worktree + direct work.
- Don't forge a new agent when an existing one covers the scope (Forge Q4 checks this first).
- Don't wire Sentinel for a one-shot solo task — it's for multi-agent orchestration.
- Don't duplicate a protocol into a consumer repo — reference it.

## Refs

- `CLAUDE.md` (repo) · `AGENTS.md` · `README.md` · `docs/framework-consumption.md` · `docs/worktrees-guide.md`
- The Forge 33Q: `agents/forge.md` §"33 Socratic Questions"
- Companion: `CANON.md` (canonical decisions) · `references/socratic-33q.md` (this concierge's own spec)
