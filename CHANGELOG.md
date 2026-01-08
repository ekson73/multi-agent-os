# Changelog

All notable changes to the Multi-Agent OS plugin will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- CLAUDE.md file for AI agent development guidance
- CHANGELOG.md for version tracking
- Analysis report (docs/ANALYSIS_REPORT_2026-01-08.md)

### Fixed
- Standardized YAML frontmatter in audit, agent-select, and context-prep skills
- Consistent skill format across all 8 skills

## [1.0.0] - 2026-01-07

### Added

#### Plugin Structure
- `.claude-plugin/plugin.json` - Plugin manifest
- `hooks/hooks.json` - Hook configuration
- `plugin-scripts/` - 4 lifecycle hook scripts

#### Skills (8 total)
- `audit/SKILL.md` - Sentinel Protocol auditing (v1.1.0)
- `agent-select/SKILL.md` - Agent selection algorithm (v1.0.0)
- `context-prep/SKILL.md` - Pre-delegation context preparation (v1.0.0)
- `hierarchical-merge/SKILL.md` - Branch merge hierarchy (v1.0.0)
- `worktree-policy/SKILL.md` - Worktree enforcement (v1.1.0)
- `anti-conflict/SKILL.md` - Conflict prevention protocol (v3.2.0)
- `status-map/SKILL.md` - Status visualization (v1.0.0)
- `ttl-policy/SKILL.md` - Content freshness management (v1.0.0)

#### Commands (5 total)
- `/sync` - Framework synchronization
- `/audit` - Session auditing
- `/status` - Status visualization
- `/worktree` - Worktree management
- `/delegate` - Task delegation

#### Agents (4 total)
- `orchestrator.md` - Master coordinator
- `sentinel-monitor.md` - Anomaly detection
- `qa-validator.md` - Quality assurance
- `consolidator.md` - Output synthesis

#### Sentinel Protocol
- `sentinel/config.json` - Detection thresholds
- `sentinel/detection_rules.md` - 10 detection rules
- `sentinel/schema/trace_schema.json` - OpenTelemetry aligned
- `sentinel/schema/alert_schema.json` - Alert format
- `sentinel/lib/trace_writer.md` - Persistence patterns
- `sentinel/lib/alert_handler.md` - Alert routing

#### Status Map System
- 9 template types (PULSE, COMPACT, SESSION_START, etc.)
- Automatic template inference
- Semaphore indicators (green/yellow/red)

#### Documentation
- `README.md` - Plugin overview and installation
- `protocols/hierarchical-merge-protocol.md` - HMP v1.0
- `docs/framework-consumption.md` - Consumer model
- `docs/worktrees-guide.md` - Multi-agent worktree guide

### Deprecated
- `claude-md/` directory (use README.md instead)
- `install/` directory (use Claude Code plugin system)
- `scripts/` directory (use plugin-scripts/)

### Technical Details
- Hook scripts use `set -euo pipefail`
- JSON output from all hooks
- OpenTelemetry GenAI semantic conventions for traces
- W3C Trace Context compliant span IDs

## [0.x] - Pre-release

Development versions before v1.0.0 release.

---

*Multi-Agent OS - A Claude Code Plugin for Multi-Agent Orchestration*
