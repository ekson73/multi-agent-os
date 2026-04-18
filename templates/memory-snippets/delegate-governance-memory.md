# Memory Snippets — delegate-governance (paste-able)

> Copy these blocks into your user-scope memory directory (Claude Code default: `~/.claude/projects/<slug>/memory/`). They're versioned here instead of written directly because remote sessions have ephemeral `~`.
>
> **Canonical repo paths** referenced by the snippets — do NOT rewrite, reference:
> - `protocols/delegation/delegation-init-prompt.md`
> - `protocols/delegation/delegation-dna-prompt.md`
> - `protocols/delegation/delegation-finalize-prompt.md`
> - `protocols/delegation/provider-matrix.md`
> - `skills/delegate-governance/SKILL.md`
> - `plugin-scripts/gaac/delegate.sh`

---

## Snippet 1 — Append to `dna_agentic_delegation_33_minds.md`

Add under a new section `## Delegation Prompts (canonical)`:

```markdown
## Delegation Prompts (canonical)

The 33-Mind taxonomy feeds into three invariant meta-prompts. Each session that spawns sub-agents must emit the appropriate prompt from `protocols/delegation/` via `plugin-scripts/gaac/delegate.sh <phase>`:

- **init** → sub-agent starts work (minds activated: 29 Autônoma, 03 Crítica, 30 Agnóstica, 07 Tomé + task-specific)
- **dna** → mid-flight refresh (guardrails: token watchdog, TTL, Sentinel rules 1/2/9, escalation)
- **finalize** → close-out (minds: 31 Reflexiva, 33 Legatária; cleanup per axial principle #5)

CLI: `plugin-scripts/gaac/delegate.sh init --ticket=$TICKET` (VCS auto-detected from `git remote -v`; ticket provider auto-detected from key prefix).

KPI target: next delegation consumes ≤ 2 files to initialize (down from ≥ 7 pre-framework).
```

---

## Snippet 2 — Append to `governance_priority_eisenhower.md`

Insert between "Passo 0" and "Passo 1":

```markdown
### Passo 0.5 — Invoke `delegate.sh init` before any sub-agent spawn

If the task requires delegation (Task tool, `/delegate`, `/parallel`), run:

\`\`\`bash
: "${CLAUDE_PLUGIN_ROOT:?CLAUDE_PLUGIN_ROOT must point to the multi-agent-os plugin root}"
bash "${CLAUDE_PLUGIN_ROOT}/plugin-scripts/gaac/delegate.sh" init --ticket="${TICKET:-}"
\`\`\`

Paste the stdout as the prefix of the sub-agent prompt. The dynamic header (TICKET_PROVIDER, VCS_PROVIDER, AGENT_HEX) is authoritative — do not override.

Skip Passo 0.5 if:
- No sub-agent spawn planned (solo execution).
- Read-only delegation with < 3 tool calls (overhead > value).
```

---

## Snippet 3 — Append to `feedback_multi_agent_harmony.md`

Replace the "Pre-flight checklist (Phase 1)" bullet that says "run the 7-phase protocol manually" with:

```markdown
**Pre-flight checklist (Phase 1)**: the Anti-Conflict v3.2 checklist is now embedded in the init prompt (`protocols/delegation/delegation-init-prompt.md` §Phase 1). Use `plugin-scripts/gaac/delegate.sh init` to emit it + the 4 cognitive lenses + provider detection in one shot. Do NOT re-implement the checklist inline.
```

---

## Snippet 4 — Create new file `dna_meta_prompts_delegation.md`

Full content:

```markdown
---
name: Meta-Prompts Delegation — When to use which
description: Phase routing guide for the GaaS/GaaC delegation framework. Maps situation → phase → prompt file → CLI flag.
type: project
---

## Decision Table

| Situation | Phase | Prompt | CLI |
|---|---|---|---|
| About to `Task(...)` a sub-agent | init | `delegation-init-prompt.md` | `delegate.sh init [--ticket K]` |
| Long chain (≥ 5 tool calls) drifting | dna | `delegation-dna-prompt.md` | `delegate.sh dna` |
| Sub-agent finished, before reporting back | finalize | `delegation-finalize-prompt.md` | `delegate.sh finalize` |
| Recursive sub-sub-agent | dna (as DNA Heritage Block) | `delegation-dna-prompt.md` §"DNA Heritage Block" | — (paste inline) |
| Ad-hoc task, no ticket | init with no --ticket | same | `delegate.sh init` |
| Cross-provider (Jira ticket + GitHub repo) | — | `provider-matrix.md` §Cross-pairs | — |

## When NOT to use the framework

- Single-agent task, no Task tool call.
- Read-only analysis.
- Simple rename / typo fix.
- User explicitly asks for direct action, no ceremony.

## Upgrade notes

If an external API migrates (ex: Jira CHANGE-2046 → `/search/jql`), update `provider-matrix.md` first, then the call-sites. Meta-prompts are stable — only the matrix moves with external change.
```

---

## Snippet 5 — Update `MEMORY.md` index

Add these lines under the existing list:

```markdown
- [Meta-Prompts Delegation](dna_meta_prompts_delegation.md) — When to emit init/dna/finalize; cross-reference to canonical repo paths
- (framework itself lives in `multi-agent-os/protocols/delegation/` — this memory file is the **router** only)
```

---

## How to apply all snippets

From a local shell (not a remote/CI session):

```bash
MEMORY_DIR="$HOME/.claude/projects/-Users-<user>-Projects-multi-agent-os/memory"  # adjust path
# Snippets 1-3: edit existing files manually or with sed
# Snippet 4: create new file
cat > "$MEMORY_DIR/dna_meta_prompts_delegation.md" <<'EOF'
# (paste Snippet 4 content here)
EOF
# Snippet 5: edit MEMORY.md index
```

Verify by running the CLI and noticing it runs without re-reading 7 memory files for context — that's the KPI of adoption.
