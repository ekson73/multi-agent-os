---
id: AGENTIC-SESSION-HARNESS-SPEC
title: "Agentic Session Harness (ASH) — Walkthrough Observability Spec v1.0.0"
description: "Vendor-neutral schema spec for AI agent session walkthrough observability — 17-field append-only JSONL journal captured at session close, enabling cross-session continuity for amnesic AI agents and human audit of agentic decisions. AAIF cross-vendor compatible."
type: governance
status: accepted
version: 1.0.0
created: 2026-05-19
last_updated: 2026-05-19
last_updated_by: "@operator"
authors:
  - "Operator (original pain identification + W1 authorization)"
  - "Claude Opus 4.7 (orchestration + R18 closure)"
  - "Claude Sonnet 4.6 (R16 anti-theater discipline)"
  - "Atlas (R7 sanction)"
  - "Perplexity (R16 external research grounding)"
  - "ChatGPT GPT-5.5 (R17 comparative analysis + sanction)"
owner: "@operator"
deciders: ["@operator"]
stakeholders: ["AI agent operators across vendors", "AI agents (Claude Code / Cursor / Copilot / Codex / Gemini CLI)", "future-amnesic-AI-agents (cross-session continuity)"]
ssot_level: primary
language: en-US
audience: both
ai_optimized: true
governance_level: critical
classification: internal
tags: [agentic-session-harness, walkthrough-observability, harness-engineering, ai-driven, ai-native, audit-trail, jsonl, claude-code-hooks, multi-tenant, dry, ssot, aaif-cross-vendor]
related: []
supersedes: null
superseded_by: null
refs:
  - "Harness Engineering 4-layer reference (Layer 4: Memory/Workspace)"
  - "ai-as-pwd-axiom §1 amnesia (primary motivator)"
changelog:
  - version: 1.0.0
    date: 2026-05-19
    type: bootstrap
    author: "@operator + Claude Opus 4.7"
    summary: "Layer 1 (Generic) spec bootstrap — extracted from project-scope ash-schema v1.2.1 via DRY/SSOT pointer pattern. Schema 17-field frozen since R11 + 7 honest limitations + 8 canonical jq queries + cultural loop + threat model. Cross-5-vendor unanimous closure. Vendor-neutral; organization-specific extensions documented separately."
---

# Agentic Session Harness (ASH) — Walkthrough Observability Spec v1.0.0

> **SSOT**: this file is the **canonical** Layer-1 generic spec for the ASH journal schema. Organization-specific deployments (e.g., per-tenant extensions, jurisdiction-specific compliance) should be documented in **separate Layer-2 extension files** that POINT to this spec (per DRY/SSOT discipline).
>
> **Status**: cross-vendor convergence FECHADA (17 rounds: Anthropic + xAI/Perplexity + OpenAI + Atlas unanimous).

## 1. Premise (why it exists)

AI agents operating under SpecDD / ai-driven methodologies routinely make decisions that **diverge from canonical SPECs** (BR / FR / NFR / ADR taxonomies) due to cross-session amnesia (see `ai-as-pwd-axiom` §1). Teams typically lack an audit layer to detect drift, revise specs, update CLAUDE.md, OR refine hooks/harness configuration.

**ASH** fills this gap with **DRY/KISS/YAGNI**: 1 append-only JSONL journal per day + 4 host-native hooks (SessionStart × 2 + Stop × 2) + 1 CLI auditor. Cross-vendor compatible — any host that emits session_id + Stop event can implement compatible hooks (Claude Code primary; Cursor / Copilot / Aider / Codex adaptable).

## 2. Schema — 17 canonical fields (frozen R11+)

Every entry is one JSON line in `.claude/audit/<YYYY-MM>/<DD>.jsonl`:

```json
{
  "schema_version": "1.0.0",
  "ts": "<ISO 8601 UTC, e.g. 2026-05-19T18:32:11Z>",
  "tenant": "<resolved per §3 fallback chain>",
  "project": "<repo name OR package.json name>",
  "session": "<host session_id (UUID)>",
  "agent": "<agent-id, e.g. claude-opus-4-7, cursor-composer, codex-cli>",
  "goal": "<operator intent — 1 line>",
  "task": "<executed task — 1 line>",
  "specs": ["${SPEC_PREFIX}-XXX", "${SPEC_PREFIX}-YYY"],
  "tools": ["Read", "Edit", "WebFetch", "<mcp-tool-name>"],
  "files": ["path/to/file1", "path/to/file2"],
  "decisions": [
    {
      "id": "D01",
      "decision": "<short — what was decided>",
      "rationale": "<why — evidence/reasoning>",
      "alternatives": ["<alt A considered>", "<alt B considered>"]
    }
  ],
  "compliance_flags": [
    {
      "spec_id": "${SPEC_REF}",
      "status": "cited|ignored|violated|no_spec_applicable",
      "note": "<evidence — quote/file ref/transcript line>"
    }
  ],
  "next_steps": ["<continuity hint for next session>"],
  "transcript_hash": "<sha256 of session transcript>",
  "transcript_rel": ".claude/transcripts/<session_id>.jsonl",
  "sources": [
    {"type": "file|web|mcp|transcript", "ref": "<URL OR path OR mcp-call>", "relevance": "high|medium|low"}
  ]
}
```

> **`${SPEC_PREFIX}` placeholder**: organizations using SpecDD pick a prefix taxonomy (e.g., `BR-XXX` / `FR-XXX` / `NFR-XXX` / `ADR-XXX`, OR `REQ-XXX` / `RULE-XXX`, OR custom). The spec itself is taxonomy-agnostic — only requires that spec IDs be machine-parseable strings.

### 2.1 Field reference

| Field | Type | Required | Purpose |
|---|---|---|---|
| `schema_version` | string | YES | SemVer — current `1.0.0` (community) |
| `ts` | ISO-8601 UTC | YES | When session closed |
| `tenant` | string | YES | Multi-tenant scope (see §3) |
| `project` | string | YES | Repo/package identifier |
| `session` | string | YES | Host session_id (UUID) |
| `agent` | string | YES | Agent identifier (vendor+version) |
| `goal` | string | YES | Operator intent (1 line) |
| `task` | string | YES | Executed task (1 line) |
| `specs` | string[] | sparse | SPEC IDs cited/touched |
| `tools` | string[] | sparse | Tools invoked (read/edit/MCP/etc.) |
| `files` | string[] | sparse | Files modified |
| `decisions` | object[] | sparse | Non-trivial decisions w/ rationale |
| `compliance_flags` | object[] | sparse | Per-spec compliance heuristic |
| `next_steps` | string[] | sparse | Continuity hints |
| `transcript_hash` | string | YES | SHA256 of transcript for tamper-evidence |
| `transcript_rel` | string | YES | Relative path to full transcript (symlinked via host-specific hook) |
| `sources` | object[] | sparse | Knowledge sources consulted |

Sparse = include only when applicable (DRY/KISS — empty arrays omitted).

## 3. Multi-tenant fallback chain (`tenant` field)

Order of resolution (first hit wins):

1. **`ASH_TENANT` env var** (operator-set explicit)
2. **`.claude/ash-tenant` file** (project-tracked seed — repo default)
3. **`package.json` `name` field** (Node projects)
4. **`git rev-parse --show-toplevel | basename`** (last resort)

If all 4 fail → `tenant: "unknown"` + emit warning to stderr.

## 4. Storage layout

```
<repo>/.claude/
├── audit/                       # JSONL journals (TRACKED — git committable, sanitize first)
│   └── YYYY-MM/
│       ├── DD.jsonl             # one line per session closed today
│       └── DD+1.jsonl
├── transcripts/                 # symlinks to host-native transcripts (GITIGNORED)
│   └── <session_id>.jsonl       # → <host-cache>/<encoded-cwd>/<session_id>.jsonl
└── ash-tenant                   # tenant seed string (TRACKED)
```

**Why `audit/` is tracked**: enables team review, drift detection, cross-session memory. Sanitization checklist before commit:
- gitleaks scan (no secrets)
- No PII real-name (use role-types)
- No proprietary client data

**Why `transcripts/` is gitignored**: symlinks to local machine state, may contain full conversation (PII risk).

## 5. Compliance flags heuristic (best-effort, NOT authoritative)

`compliance_flags[].status` is **agent self-assessment**, not formal audit:

| Status | Meaning |
|---|---|
| `cited` | Agent explicitly referenced spec in reasoning |
| `ignored` | Spec applicable but not cited (potential drift) |
| `violated` | Agent took action contradicting spec (alarm) |
| `no_spec_applicable` | No spec covers this domain (honest gap) |

**Stop subagent** sets these based on transcript scan (last N tool calls — `ASH_COMPLIANCE_WINDOW` env, default 50). Cultural loop (§7) is what makes these flags valuable.

## 6. 8 canonical jq queries (CLI auditor reference)

```bash
# 1. All sessions today
cat .claude/audit/$(date -u +%Y-%m)/$(date -u +%d).jsonl

# 2. Sessions that violated any spec
jq 'select(.compliance_flags[]?.status == "violated")' .claude/audit/**/*.jsonl

# 3. Decision-by-rationale grep
jq 'select(.decisions[]?.rationale | test("performance"; "i"))' .claude/audit/**/*.jsonl

# 4. Sessions touching specific file
jq --arg f "src/auth.ts" 'select(.files | index($f))' .claude/audit/**/*.jsonl

# 5. Sessions citing specific spec
jq --arg s "<SPEC-ID>" 'select(.specs | index($s))' .claude/audit/**/*.jsonl

# 6. Most-touched files (last 30 days)
find .claude/audit -name "*.jsonl" -mtime -30 -exec cat {} \; | jq -r '.files[]?' | sort | uniq -c | sort -rn | head -20

# 7. Compliance heuristic rollup
find .claude/audit -name "*.jsonl" -exec cat {} \; | jq -r '.compliance_flags[]?.status' | sort | uniq -c

# 8. Cross-session continuity trail (next_steps chain)
jq -r '"\(.ts) | \(.session) | \(.next_steps // [] | join("; "))"' .claude/audit/**/*.jsonl | sort
```

## 7. Cultural loop (operational guidance — non-optional)

> **Operational note**: ASH generates auditable data; the **improvement loop** (review journals → adjust specs / CLAUDE.md / hooks) is a **human** responsibility. Without this loop, ASH degrades to passive logging.

**Recommended cadence**:
- **Daily**: developer reviews own journals before commit
- **Weekly**: tech-lead reviews `compliance_flags[violated|ignored]` rollup
- **Per-PR**: PR body includes auditor-CLI excerpt
- **Quarterly**: retrospective → update SPECs / CLAUDE.md / hooks based on drift patterns

## 7.5 Threat model (security boundary — explicit)

**ASH hooks + CLI run LOCALLY on the operator's machine** under their UID, invoked by the host's hook system OR by the operator from a terminal. They are **NOT a server**, **NOT exposed to network input**, and **NOT shared between multiple untrusted principals**.

| Boundary | Trust level | Defense applied |
|---|---|---|
| **Stdin JSON `session_id`** | UNTRUSTED (could carry path-traversal payloads in adversarial host build) | Format validation (alnum+hyphens only); `grep -F`; `jq --arg` |
| **CLI argv (session prefix)** | UNTRUSTED (operator types) | Format validation (alnum+hyphens only) |
| **Journal `transcript_rel` field** | UNTRUSTED (an attacker who can write to journals could inject) | `case` pattern + resolved-path containment check |
| **`CLAUDE_PROJECT_DIR` env var** | TRUSTED (set by host; operator-controlled environment) | Entry-point sanity check: must be absolute path that exists |
| **`git rev-parse --show-toplevel` output** | TRUSTED (operator's own repo) | Sanity check inherited via PROJECT_DIR |
| **`HOME` env var** | TRUSTED (operating system) | None (foundational trust) |

**Out of scope** for ASH v1.0.0 threat model:
- Adversaries with shell access on operator's machine (already game over)
- Adversaries who manipulate OS env vars (already arbitrary code execution)
- Adversaries who control git itself (already deeper compromise)
- Multi-tenant shared journals (deploy ASH per-user, not shared)

Promotion to network-exposed OR multi-tenant-server context would require expanded threat model + additional defenses (auth, sandbox, sandbox-escape protection). NOT in scope for community MVP.

## 8. Honest limitations (7 technical)

1. **Chain-of-thought NOT captured** — host transcripts typically don't include internal reasoning; only tool calls + final outputs
2. **No formal compliance audit** — `compliance_flags` is heuristic self-assessment, not enforced
3. **Drift detection is best-effort** — if agent doesn't cite spec, can't auto-detect ignored vs no-applicable
4. **No multi-agent orchestration tracking** — single session = single agent; recursive subagent spawns are flattened
5. **`type: agent` Stop hook EXPERIMENTAL** — per Claude Code docs; behavior may change cross-version; co-equal fallback (see §"co-equal degradation") mitigates
6. **Compliance window finite** — `ASH_COMPLIANCE_WINDOW=50` last tool calls only; long sessions may truncate
7. **Auditor drift** — CLI auditor output is generated; reviewers must verify against raw transcript

## 9. Co-equal graceful degradation (L1 mitigation)

The primary Stop entry-writer is a `type: agent` subagent that reads the transcript and synthesizes a rich entry. Because this hook type is EXPERIMENTAL (L5 above), ASH ships a **co-equal fallback** Stop hook (`*-stop-fallback`) that:

1. Runs AFTER the subagent (chained in `settings.json` Stop array)
2. Checks via jq if the subagent already wrote an entry for this session_id → skip if yes
3. Otherwise writes a minimal entry (sparse fields: `goal: "(fallback...)"`, `task: "(fallback...)"`, but `tenant + project + session + agent + ts + transcript_*` always populated)
4. Idempotent via mkdir-based atomic lock (POSIX-portable)

This guarantees **at-least-once journal entry per session**, even if the experimental subagent breaks on a host upgrade.

## 10. AAIF cross-vendor portability

| Host | Status |
|---|---|
| **Claude Code** | Primary; hooks shipped (SessionStart × 2 + Stop × 2 + settings.json subagent prompt) |
| **Cursor** | Adaptable; needs SessionStart equivalent + Stop equivalent in Cursor's config schema |
| **Copilot CLI** | Adaptable; uses tool-call hooks instead of SessionStart |
| **Aider** | Adaptable; uses Aider's `--restore-chat-history` mode + Stop equivalent |
| **Codex (CLI)** | Adaptable; uses Codex's `session-end` event |
| **Gemini CLI** | Adaptable via session lifecycle equivalents |

Spec contract: any host that emits (a) `session_id` UUID at session-start AND (b) Stop/session-end event with stdin payload containing `session_id` can implement ASH-compatible hooks.

## 11. Refs

- Harness Engineering 4-layer canonical definition — ASH is **Layer 4 (Memory/Workspace)** of the harness 4-layer
- `ai-as-pwd-axiom` §1 amnesia — primary motivator
- Cross-vendor convergence trail: 17 rounds, ~135KB clipboard archive
