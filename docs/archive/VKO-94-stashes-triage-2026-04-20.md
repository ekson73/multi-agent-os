# VKO-94 — Pre-Existing Stashes Triage & Archive

- **Date of execution:** 2026-04-20
- **Repository:** `github.com/ekson73/multi-agent-os`
- **Main HEAD during triage:** `1f2f160` (post PR #38 VKO-88 Jira search migration + PR #39 GaaS/GaaC Agentic Delegation Framework v1.0)
- **Tracking ticket:** Linear [VKO-94](https://linear.app/ekson73/issue/VKO-94)
- **Related policy memory:** `feedback_multi_agent_environment_respect.md` (user-scope)
- **DoD reference:** forensic read-only investigation + per-item human authorization + execution record

## 🎯 Why this document exists

`git stash drop` is destructive. Before dropping WIP that might contain architectural context, we preserve the full diff here so the history is searchable forever in git log + Markdown. This is the per-item authorization record requested in VKO-94 DoD.

## 🗂 Executive summary

| Stash | Created | Classification | Decision | Destination |
|-------|---------|----------------|----------|-------------|
| `@{0}` | 2026-03-28 | SUPERSEDED | **DROP** | this archive (diff below) |
| `@{1}` | 2026-03-19 | NEEDS_OWNER_CONSULT → RECOVERY | **APPLY to new branch** | branch `feat/vko-94-recover-v1.6.0-pillars` |
| `@{2}` | 2026-01-23 | SUPERSEDED | **DROP** | this archive (diff below) |

Drop order executed: `@{2}` → `@{1}` → `@{0}` (highest index first to avoid renumbering).

---

## stash@{0} — Co-Author format standardization

### Metadata

- **Parent commit:** `1e74d5cebaafc7852274bdfbb9b7f0b287e356e1`
- **Parent subject:** `fix(docs): resolve CodeRabbit review round 2 — version headers + worktree detection`
- **Author:** Emilson Moraes
- **Created:** 2026-03-28 20:39:52 -0300
- **Base branch:** `feature/agent-bootstrap-coauthor-standard` (deleted — orphan stash)
- **Size:** 5 files, 7 insertions / 7 deletions

### Classification: SUPERSEDED

**Rationale:**
- Base branch `feature/agent-bootstrap-coauthor-standard` no longer exists (already merged or abandoned).
- Commit `ecdbaa0 fix(governance): address coderabbit review — worktree detection, version alignment, co-author format` exists in main and addresses the same three concerns from the parent commit subject.
- Content purpose: update Co-Author string from `Claude Opus 4.5 / 4.6 <noreply@anthropic.com>` to `Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>` across 5 files, and tighten the regex validator to require a TLD (`\.[a-zA-Z]{2,}`).
- Co-Author model identifiers have since evolved further in main; preserving this intermediate form has no forward value.

### Files touched

| File | Change |
|------|--------|
| `docs/co-author-standard.md` | regex validator hardened (require TLD) |
| `docs/pr-review-protocol-spec.md` | example co-author updated |
| `docs/specs/sync-to-git-spec.md` | env var + git config example updated |
| `rules/agent-scm.md` | default co-author updated |
| `skills/sync-to-git/SKILL.md` | commit + PR body co-author updated |

### Decision: **DROP** (authorized 2026-04-20)

### Full diff (preserved evidence)

```diff
diff --git a/docs/co-author-standard.md b/docs/co-author-standard.md
index aaf3afd..924e075 100644
--- a/docs/co-author-standard.md
+++ b/docs/co-author-standard.md
@@ -144,7 +144,7 @@ Agents SHOULD validate their Co-Author format before committing:
 ```bash
 # Regex validation: Name (Provider/Model) <email>
 # Uses grep -E for POSIX/macOS portability (not grep -P which is GNU-only)
-echo "$CO_AUTHOR" | grep -qE '^[^()<>]+ \([A-Za-z0-9.-]+/[A-Za-z0-9._-]+\) <[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+>$' \
+echo "$CO_AUTHOR" | grep -qE '^[^()<>]+ \([A-Za-z0-9.-]+/[A-Za-z0-9._-]+\) <[a-zA-Z0-9.+_-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}>$' \
   && echo "VALID" || echo "INVALID"
 ```
 
diff --git a/docs/pr-review-protocol-spec.md b/docs/pr-review-protocol-spec.md
index c5ec5ea..f86a060 100644
--- a/docs/pr-review-protocol-spec.md
+++ b/docs/pr-review-protocol-spec.md
@@ -102,7 +102,7 @@ cd .worktrees/{session-id}-{feature}
 git add {arquivo}
 git commit -m "{tipo}({escopo}): {descrição}
 
-Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
+Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>"
 ```
 
 **Boas práticas**:
diff --git a/docs/specs/sync-to-git-spec.md b/docs/specs/sync-to-git-spec.md
index f39db07..e2b5c23 100644
--- a/docs/specs/sync-to-git-spec.md
+++ b/docs/specs/sync-to-git-spec.md
@@ -195,7 +195,7 @@ SYNC_GIT_AUTO_DELEGATE_REVIEWER=true
 SYNC_GIT_REVIEWER_AGENT=code-reviewer
 
 # Commit Configuration
-SYNC_GIT_CO_AUTHOR="Claude Opus 4.5 <noreply@anthropic.com>"
+SYNC_GIT_CO_AUTHOR="Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>"
 SYNC_GIT_CONVENTIONAL_COMMITS=true
 
 # Worktree Integration (C04)
@@ -217,7 +217,7 @@ SYNC_GIT_MANIFEST_ENABLED=true
 ```bash
 git config --local sync.git.remote origin
 git config --local sync.git.protected-branches "main,master"
-git config --global sync.git.co-author "Claude Opus 4.5 <noreply@anthropic.com>"
+git config --global sync.git.co-author "Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>"
 ```
 
 ## Gates de Segurança
diff --git a/rules/agent-scm.md b/rules/agent-scm.md
index 37fb57e..0cdcf25 100644
--- a/rules/agent-scm.md
+++ b/rules/agent-scm.md
@@ -104,7 +104,7 @@ INPUT (obrigatorio):
   - description: string (o que mudou e POR QUE)
 
 INPUT (opcional):
-  - co_author: string (default: Claude Opus 4.6 <noreply@anthropic.com>)
+  - co_author: string (default: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>)
   - breaking: boolean (BREAKING CHANGE)
 
 CHECKLIST PRE-COMMIT (R01):
diff --git a/skills/sync-to-git/SKILL.md b/skills/sync-to-git/SKILL.md
index a1ff987..7a4253e 100644
--- a/skills/sync-to-git/SKILL.md
+++ b/skills/sync-to-git/SKILL.md
@@ -157,7 +157,7 @@ fi
 ```bash
 # Usage: sync-commit "type(scope): description"
 MESSAGE="$1"
-CO_AUTHOR="Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>"
+CO_AUTHOR="Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>"
 
 # Validate conventional commits
 if ! echo "$MESSAGE" | grep -qE "^(feat|fix|docs|chore|refactor|test|style|perf|ci|build)(\(.+\))?:"; then
@@ -199,7 +199,7 @@ gh pr create --title "$TITLE" --body "$(cat <<EOF
 - [ ] Manual testing done
 
 ---
-Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
+Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>
 EOF
 )" --base "$BASE"
 
```

---

## stash@{1} — v1.6.0 "Native by Design" architecture pillars draft

### Metadata

- **Parent commit:** `e0d5dd181936f8346c4bbd368cda87b13aec3489`
- **Parent subject:** `fix(agnostic): final sweep - purge vekdbadmin, br.com.vek, jeevek, VKS- refs`
- **Author:** Emilson Moraes
- **Created:** 2026-03-19 18:06:22 -0300
- **Base branch:** `main` (generic label "pre-worktree: unstaged changes from previous sessions")
- **Size:** 3 files, **144 insertions / 7 deletions** — largest of the three

### Classification: NEEDS_OWNER_CONSULT → RECOVERY

**Rationale:**
- Content proposes a complete architectural reframing of MAOS from "Claude Code plugin" to "open-source, AI-agnostic framework" built on 9 pillars: AGENTS.md, MCP-HUB, A2A, ACP, GaaS, Direct-Raw-URLs, Multi-Agent, AI-Agnostic, Org-Agnostic.
- Parent commit context shows this draft was part of the broader agnosticism sweep (`fix(agnostic): final sweep`).
- Partial overlap with main: GaaS framework is now in `[Unreleased]` via PR #39 GaaS/GaaC Agentic Delegation Framework v1.0, but the **9-pillar formalization, AAIF alignment narrative, README rewrite with badges, and consumption-method diagram are not yet in main**.
- Value is **complementary, not duplicated**. Drop would lose the narrative rewrite; merging directly to main would require owner review.

### Files touched

| File | Change scope |
|------|--------------|
| `CHANGELOG.md` | New `[1.6.0] - 2026-03-19` section with 25 lines describing 9 pillars + AAIF alignment |
| `CLAUDE.md` | New "Architecture Pillars (Native by Design)" table + footer version bump |
| `README.md` | Major rewrite: new badges (AI Agnostic, AAIF Aligned, MCP Native), full "Architecture Pillars" section with pillar table, GaaS guarantor narrative, agnosticism detail, AAIF alignment table, 5 consumption methods diagram |

### Decision: **RECOVERY** (authorized 2026-04-20)

- Destination branch: `feat/vko-94-recover-v1.6.0-pillars`
- Branch base: main @ `1f2f160`
- Mechanism: `git stash apply stash@{1}` on new branch, then commit
- Owner may cherry-pick, merge, or discard at leisure. Not opening a PR automatically.

### Full diff (preserved evidence)

The diff is ~194 lines and is the source for the recovery branch. It is preserved in git history in two places:

1. The recovery commit on branch `feat/vko-94-recover-v1.6.0-pillars`
2. The original stash contents, already captured in `/tmp/vko94-stash-1.diff` during triage (verify with `git show` on the recovery commit)

For audit trail, the full diff text is also inlined in this archive below:

```diff
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 8f09f4a..2139cb0 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -8,6 +8,31 @@ and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0
 
 ## [Unreleased]
 
+## [1.6.0] - 2026-03-19
+
+### Changed
+
+#### Architecture (Native by Design)
+- Formalized 9 architectural pillars that define Multi-Agent OS identity:
+  1. **AGENTS.md** — universal project instructions standard (AAIF), 24+ AI tools read natively
+  2. **MCP-HUB** (Model Context Protocol) — AAIF/Linux Foundation aligned
+  3. **A2A Protocol** (Agent-to-Agent) — aligned with Google A2A patterns
+  4. **ACP** (Agent Communication Protocol) — compatible with JetBrains/Zed standard
+  5. **GaaS** (Governance-as-a-Service) — enforcement via CI/CD hooks, not advisory docs
+  6. **Direct-Raw-URLs Ready** — zero-install context injection for any AI provider
+  7. **Multi-Agent** — N concurrent agents via worktree isolation + hierarchical merge
+  8. **AI-Agnostic** — provider, LLM, and agent CLI agnostic (Markdown/JSON protocols)
+  9. **Company/Org-Agnostic** — no corporate assumptions, consumer adaptation model
+- Documented alignment with AAIF (Agentic AI Foundation) cornerstone projects: MCP, AGENTS.md, goose
+- Documented 5 consumption methods: Raw URL injection, Claude Code plugin, AGENTS.md reference, submodule, MCP server
+- Updated project description from "Claude Code plugin" to "open-source, AI-agnostic framework"
+
+#### Documentation
+- `docs/gaas-architecture-manifesto.md` — **NEW**: GaaS Architecture Manifesto — "Governance by Hope" vs physical enforcement, 3 motors (hooks, CI/CD, Policy-as-Code), Zero-Trust enforcement chain
+- `README.md` — Complete rewrite of header, badges, and identity section with pillar table, consumption model, and GaaS guarantor section
+- `CLAUDE.md` — Added Architecture Pillars section to Repository Overview
+- Version bump to 1.6.0
+
 ## [1.4.0] - 2026-03-08
 
 ### Added
diff --git a/CLAUDE.md b/CLAUDE.md
index f2116ea..3dfe60b 100644
--- a/CLAUDE.md
+++ b/CLAUDE.md
@@ -9,7 +9,23 @@ This file provides guidance to Claude Code (claude.ai/code) when working with th
 
 ## Repository Overview
 
-**Multi-Agent OS** is a Claude Code plugin for orchestrating AI agents in software development workflows. It provides:
+**Multi-Agent OS** is an open-source, AI-agnostic framework for orchestrating multi-agent software development workflows. While it currently operates primarily as a Claude Code plugin, it is **Native by Design** on 8 architectural pillars that ensure cross-provider compatibility:
+
+### Architecture Pillars (Native by Design)
+
+| Pillar | What | How |
+|--------|------|-----|
+| **AGENTS.md** | Universal project instructions (AAIF standard) | All protocols Markdown-native, 24+ AI tools read natively |
+| **MCP-HUB** | Tool/data connectivity (AAIF standard) | `mcp-tools/maos-mcp-hub/` |
+| **A2A Protocol** | Agent-to-agent communication | `protocols/agent-delegation.md`, `protocols/rbad.md` |
+| **ACP** | IDE-agent interaction | `commands/`, `skills/`, `hooks/` |
+| **GaaS** | Governance via CI/CD + git hooks | `.githooks/`, `sentinel/`, `rules/` |
+| **Direct-Raw-URLs** | Zero-install context injection | `docs/RAW_URL_INJECTION.md` |
+| **Multi-Agent** | N concurrent agents in parallel | Worktree protocol + hierarchical merge |
+| **AI-Agnostic** | Provider/LLM/CLI agnostic | All protocols are Markdown/JSON |
+| **Org-Agnostic** | No corporate assumptions | Consumer model (`docs/framework-consumption.md`) |
+
+### Key Capabilities
 
 - **Sentinel Protocol**: Anomaly detection and observability for multi-agent orchestration
 - **Status Map System**: Human-readable ASCII status visualizations
@@ -303,5 +319,5 @@ See `docs/framework-consumption.md` for full guidance.
 
 ---
 
-*Multi-Agent OS v1.5.0 | Plugin for Claude Code*
-*Analysis by: Claude-Analyst-c614-plugin | 2026-01-08T21:30:00-03:00*
+*Multi-Agent OS v1.6.0 | Native by Design: AI-Agnostic, Multi-Agent, Protocol-First*
+*Architecture pillars formalized: 2026-03-19*
diff --git a/README.md b/README.md
index c699b03..b056dce 100644
--- a/README.md
+++ b/README.md
@@ -1,11 +1,107 @@
 # Multi-Agent OS
 
 [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
-[![Claude Code](https://img.shields.io/badge/Claude%20Code-Plugin-blueviolet)](https://claude.ai/code)
-[![Version](https://img.shields.io/badge/Version-1.5.0-blue)](https://github.com/ekson73/multi-agent-os)
+[![AI Agnostic](https://img.shields.io/badge/AI-Agnostic-purple)](https://github.com/ekson73/multi-agent-os)
+[![Version](https://img.shields.io/badge/Version-1.6.0-blue)](https://github.com/ekson73/multi-agent-os)
+[![AAIF Aligned](https://img.shields.io/badge/AAIF-Aligned-orange)](https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation)
+[![MCP Native](https://img.shields.io/badge/MCP-Native-green)](https://modelcontextprotocol.io)
 [![Sentinel](https://img.shields.io/badge/Sentinel-Protocol-green)](https://github.com/ekson73/multi-agent-os/tree/main/sentinel)
 
-A comprehensive Claude Code plugin for orchestrating AI agents in software development workflows.
+An open-source, AI-agnostic framework for orchestrating multi-agent software development workflows with formalized governance, observability, and conflict prevention.
+
+> **Native by Design**: Built from inception on the pillars of provider-agnosticism, protocol-first governance, and open interoperability — not retrofitted from a single-vendor tool.
+
+---
+
+## Architecture Pillars
+
+Multi-Agent OS is founded on 9 architectural pillars that ensure it works across any AI provider, any organization, and any project:
+
+| # | Pillar | Description | Implementation |
+|---|--------|-------------|----------------|
+| 1 | **AGENTS.md** | Universal project instructions standard (AAIF) | All protocols are Markdown-native, `AGENTS.md`-compatible — 24+ AI tools read natively |
+| 2 | **MCP-HUB** (Model Context Protocol) | Tool and data connectivity layer for AI agents | `mcp-tools/maos-mcp-hub/` — AAIF/Linux Foundation standard (donated by Anthropic) |
+| 3 | **A2A Protocol** (Agent-to-Agent) | Inter-agent communication and coordination | `protocols/agent-delegation.md`, `protocols/rbad.md` — aligned with Google A2A patterns |
+| 4 | **ACP** (Agent Communication Protocol) | IDE-agent interaction standard | `commands/`, `skills/`, `hooks/` — compatible with JetBrains/Zed ACP standard |
+| 5 | **GaaS** (Governance-as-a-Service) | **The guarantor pillar** — physical enforcement via hooks + CI/CD + Policy-as-Code | `.githooks/`, `sentinel/`, `rules/` — the only pillar agents cannot ignore ([manifesto](docs/gaas-architecture-manifesto.md)) |
+| 6 | **Direct-Raw-URLs Ready** | Zero-install context injection via GitHub Raw URLs | `docs/RAW_URL_INJECTION.md` — any AI agent fetches governance on-demand |
+| 7 | **Multi-Agent** | Native support for N concurrent agents in parallel | `docs/git-worktree-protocol.md`, `protocols/hierarchical-merge-protocol.md` |
+| 8 | **AI-Agnostic** | Provider, LLM, and agent CLI agnostic | All protocols are Markdown/JSON — consumable by any LLM or agentic tool |
+| 9 | **Company/Org-Agnostic** | No corporate assumptions baked in | Framework adapts to any org via consumer model (`docs/framework-consumption.md`) |
+
+### GaaS: The Guarantor Pillar
+
+> All other 8 pillars are *advisory* — the agent can ignore them. GaaS is the only pillar that is **physical enforcement**. An `exit code 1` from a git hook is a deterministic fact, not a probabilistic suggestion.
+
+```
+Markdown instructions = suggestions (the LLM may ignore)
+exit code + stderr    = facts (the LLM cannot circumvent)
+```
+
+**3 Enforcement Motors:**
+
+| Motor | Layer | What it blocks | Bypassable? |
+|-------|-------|----------------|-------------|
+| **Git Hooks** | Local terminal | Commits on main, bad branch names | Only via `--no-verify` |
+| **CI/CD Pipeline** | Cloud (PR) | PII leaks, missing co-author, failed review | No (branch protection) |
+| **Policy-as-Code** | Cloud (OPA/Rego) | Schema violations, security misconfigs | No (boolean evaluation) |
+
+The AI reads `stderr`, recognizes the error, and self-corrects in a loop — **learning from infrastructure without human intervention**. This is Zero-Trust for hybrid teams (Humans + AIs).
+
+Full manifesto: [`docs/gaas-architecture-manifesto.md`](docs/gaas-architecture-manifesto.md)
+
+### Agnosticism in Detail
+
+```
+AI-Agnostic means:
+├── AI-Provider-Agnostic    → Works with OpenAI, Anthropic, Google, Meta, Mistral, etc.
+├── LLM-Agnostic            → Works with any model: GPT-4o, Claude, Gemini, Llama, DeepSeek, Qwen, etc.
+├── AI-Agent-CLI-Agnostic   → Works with: Claude Code, Codex CLI, Cursor, Windsurf, Copilot,
+│                              Gemini CLI, Aider, OpenHands, Zed, Goose, RooCode/Cline, Warp, etc.
+└── Company/Org-Agnostic    → No Vek, no Acme — adapts to ANY organization via consumer model
+```
+
+### Alignment with Industry Standards (AAIF / Linux Foundation)
+
+In December 2025, the Linux Foundation established the **Agentic AI Foundation (AAIF)** with three cornerstone projects. Multi-Agent OS aligns natively with all three:
+
+| AAIF Project | Origin | Multi-Agent OS Integration |
+|--------------|--------|---------------------------|
+| **MCP** | Anthropic | `mcp-tools/maos-mcp-hub/` — native MCP server hub |
+| **AGENTS.md** | OpenAI | All protocols are Markdown-native, AGENTS.md-compatible |
+| **goose** | Block | Compatible runtime via StdIO/SSE MCP transport |
+
+### How Agents Consume This Framework
+
+```
+┌──────────────────────────────────────────────────────────────────┐
+│  CONSUMPTION METHODS (pick one or combine)                       │
+├──────────────────────────────────────────────────────────────────┤
+│                                                                  │
+│  1. RAW URL INJECTION (zero-install, any AI provider)           │
+│     Agent fetches governance on-demand from GitHub Raw URLs      │
+│     → Works with ANY tool that can fetch URLs                    │
+│                                                                  │
+│  2. CLAUDE CODE PLUGIN (native hooks + commands)                │
+│     claude plugins install /path/to/multi-agent-os               │
+│     → Deepest integration: hooks, commands, skills, agents       │
+│                                                                  │
+│  3. AGENTS.md REFERENCE (emerging standard)                     │
+│     Include Raw URLs in your project's AGENTS.md                │
+│     → 24+ AI tools read AGENTS.md natively                      │
+│                                                                  │
+│  4. SUBMODULE / CLONE (full local access)                       │
+│     git submodule add ... .multi-agent-os                        │
+│     → Version-locked, offline-capable                            │
+│                                                                  │
+│  5. MCP SERVER (tool connectivity)                              │
+│     Register maos-mcp-hub as MCP server in any MCP-aware tool  │
+│     → Works with Claude, ChatGPT, Copilot, Gemini, VS Code     │
+│                                                                  │
+└──────────────────────────────────────────────────────────────────┘
+```
+
+---
 
 ## Features
 
@@ -207,4 +303,4 @@ MIT License - See LICENSE file for details.
 
 ---
 
-*Multi-Agent OS v1.5.0 | Created by Emilson Moraes | Powered by Claude Code*
+*Multi-Agent OS v1.6.0 | Created by Emilson Moraes | Native by Design: AI-Agnostic, Multi-Agent, Protocol-First*
```

---

## stash@{2} — plugin.json version bump 1.2.0 → 1.2.1

### Metadata

- **Parent commit:** `1851e23f552f0eb16b5b0e08245cffd5c65cc966`
- **Parent subject:** `feat(docs): adicionar orientações sobre worktrees e intercomunicação entre agentes`
- **Author:** Emilson Moraes
- **Created:** 2026-01-23 13:55:51 -0300
- **Base branch:** `main`
- **Size:** 2 files, 9 insertions / 3 deletions (smallest, oldest)

### Classification: SUPERSEDED

**Rationale:**
- Current `plugin.json` in main is at `"version": "1.5.0"` — three minor versions beyond the `1.2.1` this stash proposes.
- The `1.2.1` CHANGELOG entry was never merged because the project leapfrogged directly to `1.3.x` / `1.4.0` / `1.5.0`.
- The change to remove `"hooks": "./hooks/hooks.json"` no longer applies — current plugin.json no longer declares that field in the same shape (keyword list and overall structure have evolved significantly).
- Content purpose: a routine version-sync fix with no surviving architectural value.

### Files touched

| File | Change |
|------|--------|
| `.claude-plugin/plugin.json` | version `1.2.0` → `1.2.1`, removed `hooks` field |
| `CHANGELOG.md` | added `[1.2.1] - 2026-01-10` entry + history table row |

### Decision: **DROP** (authorized 2026-04-20)

### Full diff (preserved evidence)

```diff
diff --git a/.claude-plugin/plugin.json b/.claude-plugin/plugin.json
index ec67d99..5412a5c 100644
--- a/.claude-plugin/plugin.json
+++ b/.claude-plugin/plugin.json
@@ -1,6 +1,6 @@
 {
   "name": "maos",
-  "version": "1.2.0",
+  "version": "1.2.1",
   "description": "MAOS (Multi-Agent OS) - Coordination Framework for AI Agents with Orchestration, Sentinel Protocol, Worktree Policy, Status Maps",
   "author": {
     "name": "Vek - Desenvolvimento de Software",
@@ -17,6 +17,5 @@
     "sentinel",
     "observability",
     "git-worktrees"
-  ],
-  "hooks": "./hooks/hooks.json"
+  ]
 }
diff --git a/CHANGELOG.md b/CHANGELOG.md
index 70ed7c6..a07650f 100644
--- a/CHANGELOG.md
+++ b/CHANGELOG.md
@@ -8,6 +8,12 @@ and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0
 
 ## [Unreleased]
 
+## [1.2.1] - 2026-01-10
+
+### Fixed
+- Version sync: plugin.json now matches CHANGELOG (was 1.2.1 vs 1.2.0)
+- Note: No code changes, only version metadata alignment
+
 ## [1.2.0] - 2026-01-09
 
 ### Added
@@ -173,6 +179,7 @@ and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0
 
 | Version | Date | Highlights |
 |---------|------|------------|
+| 1.2.1 | 2026-01-10 | Version sync fix |
 | 1.2.0 | 2026-01-09 | Statusline, bug fixes (BUG-001 to BUG-004) |
 | 1.1.0 | 2026-01-08 | MVV Generator, CLAUDE.md, worktree infra |
 | 1.0.0 | 2026-01-07 | Full plugin release, Sentinel, Status Map |
```

---

## Recovery destinations

| Stash | Destination |
|-------|-------------|
| `@{0}` | **dropped** — diff preserved in this file |
| `@{1}` | **applied** on branch [`feat/vko-94-recover-v1.6.0-pillars`](https://github.com/ekson73/multi-agent-os/tree/feat/vko-94-recover-v1.6.0-pillars) |
| `@{2}` | **dropped** — diff preserved in this file |

## Verification commands

```bash
# Anyone auditing this decision later can reconstruct the stashes from the diffs above:
awk '/^## stash@\{0\} —/,/^---$/' docs/archive/VKO-94-stashes-triage-2026-04-20.md \
  | awk '/^```diff/,/^```$/' | sed '1d;$d' > /tmp/reconstructed-stash-0.diff

# Confirm stash list is empty:
git stash list    # expect no output

# Inspect recovery branch:
git show feat/vko-94-recover-v1.6.0-pillars
```

## Cross-references

- Linear: [VKO-94](https://linear.app/ekson73/issue/VKO-94) (this ticket), [VKO-97](https://linear.app/ekson73/issue/VKO-97) (session handoff), [VKO-91](https://linear.app/ekson73/issue/VKO-91) (context origin)
- Memory policy: `feedback_multi_agent_environment_respect.md` (user-scope)
- DoD: forensic read-only investigation + per-item authorization + execution record — all satisfied here
