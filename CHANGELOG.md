# Changelog

All notable changes to the Multi-Agent OS plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [Unreleased]

## [1.2.0] - 2026-01-09

### Added
- Auto-install statusline feature in session-start.sh hook
- Statusline script template (`templates/statusline-command.sh`) with:
  - Model and version display
  - Project and branch info
  - Worktree detection
  - Session state from MAOS registry
  - Cost and context usage metrics
  - Visual semaphores for context consumption

### Fixed
- BUG-001: Arithmetic increment with `set -e` in validate-plugin.sh (Critical)
  - Changed `((VAR++))` to `((VAR++)) || true` to prevent exit on 0-to-1 increment
- BUG-002: grep failure in session-end.sh when session log does not exist (High)
  - Added existence check before grep -c
- BUG-003: Missing JSON validation in statusline-command.sh (High)
  - Added validation at start, graceful exit on invalid input
  - Changed shebang from `#!/bin/bash` to `#!/usr/bin/env bash`
- BUG-004: settings.json overwrite without backup in session-start.sh (High)
  - Added `.bak` file creation before modifying user settings

## [1.1.0] - 2026-01-08

> **Note**: Plugin manifest (`plugin.json`) version should be updated to 1.1.0 to match this release.

### Added

#### MVV Generator System
- `commands/mvv.md` - `/mvv` command for Mission, Vision, Values generation
- `skills/ontological-analysis/SKILL.md` - 8-dimension philosophical analysis (v1.0.0)
- `skills/mvv-synthesis/SKILL.md` - Mission/Vision/Values synthesis (v1.0.0)

#### Documentation & Tooling
- `CLAUDE.md` - AI agent development guidance
- `CHANGELOG.md` - Version tracking (Keep a Changelog format)
- `docs/ANALYSIS_REPORT_2026-01-08.md` - Plugin analysis report
- `.worktrees/` - Multi-agent coordination infrastructure
  - `tasks.md` - Task registry
  - `sessions.json` - Session tracking
  - `protected_files.json` - File protection manifest
  - `session_lock.template.json` - Lock file template

#### README Enhancements
- Added badges (MIT License, Claude Code Plugin, Version, Sentinel)
- MVV Generator documentation

### Changed
- Skills count increased from 8 to 10 (added ontological-analysis, mvv-synthesis)
- Commands count increased from 5 to 6 (added /mvv)

### Fixed
- Standardized YAML frontmatter in audit, agent-select, and context-prep skills
- Consistent skill format across all 10 skills

## [1.0.0] - 2026-01-07

### Added

#### Plugin Structure
- `.claude-plugin/plugin.json` - Plugin manifest for Claude Code integration
- `hooks/hooks.json` - Hook configuration for lifecycle events
- `plugin-scripts/` - 4 lifecycle hook scripts
  - `session-start.sh` - Session initialization
  - `pre-delegate.sh` - Pre-delegation checks
  - `post-delegate.sh` - Post-delegation processing
  - `session-end.sh` - Session cleanup

#### Skills (8 initial)
- `audit/SKILL.md` - Sentinel Protocol auditing (v1.1.0)
- `agent-select/SKILL.md` - Agent selection algorithm (v1.0.0)
- `context-prep/SKILL.md` - Pre-delegation context preparation (v1.0.0)
- `hierarchical-merge/SKILL.md` - Branch merge hierarchy rules (v1.0.0)
- `worktree-policy/SKILL.md` - Worktree enforcement policy (v1.1.0)
- `anti-conflict/SKILL.md` - Conflict prevention protocol (v3.2.0)
- `status-map/SKILL.md` - Status visualization system (v1.0.0)
- `ttl-policy/SKILL.md` - Content freshness management (v1.0.0)

#### Commands (5 initial)
- `/sync` - Framework synchronization to consumer projects
- `/audit` - On-demand session auditing
- `/status` - Status map visualization
- `/worktree` - Git worktree management
- `/delegate` - Task delegation to sub-agents

#### Agents (4 total)
- `orchestrator.md` - Master coordinator for multi-agent sessions
- `sentinel-monitor.md` - Anomaly detection and alerting
- `qa-validator.md` - Quality assurance validation
- `consolidator.md` - Output synthesis and consolidation

#### Sentinel Protocol v1.0.0
- `sentinel/config.json` - Detection thresholds configuration
- `sentinel/detection_rules.md` - 10 detection rules:
  1. Loop Detection (auto-block)
  2. Depth Violation (max 3 levels)
  3. Error Cascade (consecutive errors)
  4. Retry Storm (5+ retries/min)
  5. Task Drift (unrelated output)
  6. Chain Break (unexpected break)
  7. Escalation Abuse (>50% escalated)
  8. Stagnation (>5 min execution)
  9. Agent Mismatch (suboptimal selection)
  10. Token Bloat (excessive usage)
- `sentinel/schema/trace_schema.json` - OpenTelemetry aligned traces
- `sentinel/schema/alert_schema.json` - Alert format specification
- `sentinel/lib/trace_writer.md` - Trace persistence patterns
- `sentinel/lib/alert_handler.md` - Alert routing logic

#### Status Map System v1.0.0
- 9 individual template types + 1 consolidated reference file (10 total):
  - PULSE (1-line, every response)
  - COMPACT (6-line, every 5 responses)
  - SESSION_START (session begin)
  - SESSION_END (session end)
  - DELEGATION_PRE (before Task tool)
  - DELEGATION_POST (after Task tool)
  - ERROR_DEBUG (error diagnosis)
  - PRE_COMMIT (commit validation)
  - FULL_REPORT (complete audit)
  - `statusmap_templates.md` (consolidated reference)
- Automatic template inference engine
- Semaphore indicators (green/yellow/red)

#### Protocols
- `protocols/hierarchical-merge-protocol.md` - HMP v1.0
  - Parent-child branch convergence
  - Child Completion Constraint
  - Exception prefixes (hotfix/, emergency/)

#### Documentation
- `README.md` - Plugin overview and installation guide
- `docs/framework-consumption.md` - Consumer project integration
- `docs/worktrees-guide.md` - Multi-agent worktree coordination
- `LICENSE` - MIT License

### Technical Details
- Hook scripts use `set -euo pipefail` for safety
- JSON output from all hook scripts
- OpenTelemetry GenAI semantic conventions for traces
- W3C Trace Context compliant span IDs

### Deprecated
- `claude-md/` directory - Use README.md instead
- `install/` directory - Use Claude Code plugin system
- `scripts/` directory - Use plugin-scripts/

## [0.9.0] - 2026-01-07

### Added
- Initial framework structure
- Core protocol documentation drafts
- Agent definitions (conceptual)

### Technical
- Repository initialization
- MIT License

---

## Version History Summary

| Version | Date | Highlights |
|---------|------|------------|
| 1.2.0 | 2026-01-09 | Statusline, bug fixes (BUG-001 to BUG-004) |
| 1.1.0 | 2026-01-08 | MVV Generator, CLAUDE.md, worktree infra |
| 1.0.0 | 2026-01-07 | Full plugin release, Sentinel, Status Map |
| 0.9.0 | 2026-01-07 | Initial framework structure |

---

*Multi-Agent OS - A Claude Code Plugin for Multi-Agent Orchestration*
*Maintained by Emilson Moraes | Powered by Claude Code*
