---
name: agentic-session-harness
description: Generic, vendor-neutral session-observability engine (ASH — Agentic Session Harness). Per-session journals capturing goal · tasks · decisions[] · sources · transcript_hash, plus a decision-audit (why the agent decided X, spec_alignment drift). Ships CLIs (agentic-walkthrough timeline · agentic-decisions audit report · agentic-decide capture · agentic-reindex backfill) + SessionStart/Stop hooks. Use when you need an auditable record of what an agent did and WHY across sessions. Promoted from a host product 2026-06-02 (Layer-1 community engine).
version: 1.0.0
---

# Agentic Session Harness (ASH) — engine

## Purpose
A session-end observability harness: one journal entry per session (`.claude/audit/<YYYY-MM>/<DD>.jsonl`) with the 17-field FROZEN schema (goal · tasks · decisions[] · sources · transcript_hash · spec_alignment · …). The **walkthrough** reads the timeline; the **decision-audit** answers *why the agent decided X instead of following the SPEC*. Vendor-neutral (AAIF) — Bash 3.2 + jq only, no org-specific content (Layer-Purity clean).

## When to Use
- Audit what happened in a session (timeline) → `agentic-walkthrough <sid>`
- Audit the agent's DECISIONS + why → `agentic-decisions` (`--filter spec_alignment=divergent` = the drift signal)
- Capture a high-stakes decision mid-session → `agentic-decide --decision … --rationale … --spec-ref …`
- Backfill/migrate old journals → `agentic-reindex`

## Trigger Phrases
"session timeline", "why did the agent diverge from the spec", "decision audit", "capture this decision", "walkthrough of session X", "session journal".

## Components
| Kind | Path | Role |
|---|---|---|
| CLI | `bin/agentic-walkthrough` | session timeline (markdown; `--raw`, `--today`, `--violations`) |
| CLI | `bin/agentic-decisions` | decision-audit report (table/list/json; `--filter`/`--sort`) |
| CLI | `bin/agentic-decide` | in-session explicit capture (`DEC-` ids) |
| CLI | `bin/agentic-reindex` | backfill/migrate/enrich journals |
| CLI | `bin/agentic-fix-dangling-symlinks.sh` | repair transcript symlinks |
| hook | `hooks/link.sh`, `hooks/resume.sh` | SessionStart: symlink transcript + inject last-5 context |
| hook | `hooks/stop-fallback.sh` | Stop: reliably-firing entry writer + structural `XDEC-` extraction |
| hook | `hooks/decide-merge.sh` | Stop: fold staged `DEC-`/`XDEC-` into `decisions[]`, deduped |
| lib | `hooks/lib.sh` | shared helpers (sourced by hooks + reindex) |
| spec | `SPEC.md` | the FROZEN-17 generic schema SSOT |

The CLIs source `hooks/lib.sh` relatively (`../hooks/lib.sh`); the bundle is self-contained.

## Activation (opt-in) — wire the hooks
ASH ships as an **opt-in** capability (not auto-wired, so it never forces journaling on consumers). To activate, register the hooks in your project's `.claude/settings.json` (SessionStart → `link.sh`, `resume.sh`; Stop → `stop-fallback.sh` then `decide-merge.sh`), or via the plugin's `hooks/hooks.json` referencing `${CLAUDE_PLUGIN_ROOT}/skills/agentic-session-harness/hooks/*.sh`. Orientation + per-intent routing: see the `walkthrough-concierge` skill.

## Sentinel coexistence (multi-agent-os)
ASH and the **Sentinel Protocol** both observe into `.claude/audit/`, but **do not collide** and are complementary:
- **ASH journals** → `.claude/audit/<YYYY-MM>/<DD>.jsonl` (month-dir + day-file): per-session goal/decisions/timeline + decision-audit (the *what & why*).
- **Sentinel traces** → `.claude/audit/session_{YYYYMMDD}_{hex}.jsonl` + `session_index.json` (flat): anomaly/health detection (the *is-this-going-wrong*).
Distinct filename namespaces → both run in the same sink. ASH = post-hoc decision audit; Sentinel = live anomaly guard.

## Companions
- `walkthrough-concierge` — teaches/routes/anchors over this engine (start here if unsure which tool).
- `decision-capture` — WHEN to call `agentic-decide`.

## Changelog
- 2026-06-02 — v1.0.0 — Promoted to multi-agent-os (Layer-1 community engine) from a host product. Renamed CLIs `ash-*` → `agentic-*`; hooks dropped the `ash-` prefix (dir name covers); self-contained bundle (`bin/` + `hooks/` co-located, relative lib sourcing). Vendor-neutral / Layer-Purity clean. Corporate overlays (taxonomy/compliance) live separately in the consuming org's private toolkit.
