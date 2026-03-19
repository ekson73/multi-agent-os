# Feature Request: Claude Code Session API & Environment Variables

**Status**: Draft for submission to https://github.com/anthropics/claude-code/issues
**Date**: 2026-01-09
**Author**: Emilson de Queiroz Moraes (emilson.moraes@gmail.com)
**Context**: Multi-agent orchestration system integration

---

## Title

[Feature Request] Expose Session Metadata via Environment Variables and API

---

## Problem Description

Claude Code currently lacks programmatic access to session metadata (session ID and user-defined session names). This creates a significant integration barrier for external tooling, particularly multi-agent orchestration systems, git worktree automation, and cross-tool session tracking.

### Current Limitations

1. **No Environment Variables**: Claude Code does not expose `CLAUDE_SESSION_ID` or `CLAUDE_SESSION_NAME` to hook scripts or subprocesses
2. **Internal-Only Storage**: Session names set via `/rename` are stored internally and not accessible externally
3. **Limited Session Discovery**: The only ways to identify the current session are:
   - Parsing the status line JSON input (`session_id` field)
   - Extracting UUID from transcript file path (`~/.claude/projects/.../UUID.jsonl`)
4. **No CLI Query**: No command like `claude --current-session` to retrieve session info programmatically

### Real-World Impact

This limitation prevents:
- **Multi-agent orchestration**: External systems cannot correlate Claude Code sessions with their own session tracking
- **Git worktree integration**: Cannot automatically map session → branch → worktree without manual intervention
- **Status line customization**: Cannot display meaningful session names in custom status line implementations
- **Post-mortem analysis**: Difficult to trace session activity across multiple tools (Claude Code + Cursor + Windsurf)
- **Hook automation**: Git hooks cannot make session-aware decisions

---

## Use Cases

### 1. Multi-Agent Orchestration
**Scenario**: A framework (multi-agent-os) delegates tasks to sub-agents running in isolated Claude Code sessions.

**Current Problem**: Parent orchestrator cannot determine which session a sub-agent is using without complex file path parsing.

**With Session API**: Environment variable `CLAUDE_SESSION_ID` allows instant correlation.

### 2. Git Worktree Automation
**Scenario**: Session-based isolation using git worktrees (1 session = 1 branch = 1 worktree).

**Current Problem**: Hook scripts must parse transcript paths to determine session UUID, which is fragile.

**With Session API**: `CLAUDE_SESSION_ID` directly maps to worktree directory name.

### 3. Status Line Enhancement
**Scenario**: Custom status line showing meaningful session context (e.g., "Session: feature/login-refactor").

**Current Problem**: `/rename` names are internal-only; status line can only show UUID.

**With Session API**: `CLAUDE_SESSION_NAME` provides user-friendly display.

### 4. Cross-Tool Session Tracking
**Scenario**: Developer switches between Claude Code, Cursor, and Windsurf for the same task.

**Current Problem**: No unified session identifier across tools.

**With Session API**: External system uses `CLAUDE_SESSION_ID` to maintain consistent session records.

### 5. Audit & Debugging
**Scenario**: Post-mortem analysis of which sessions created which commits.

**Current Problem**: Must reverse-engineer session IDs from transcript file paths.

**With Session API**: Git commit metadata includes `CLAUDE_SESSION_ID` via hook injection.

---

## Proposed Solution

### Primary: Environment Variables

Expose the following environment variables to all subprocesses (hooks, scripts, CLI commands):

```bash
# UUID of the current session
CLAUDE_SESSION_ID="a1b2c3d4-e5f6-7890-abcd-ef1234567890"

# User-defined name from /rename (empty if not renamed)
CLAUDE_SESSION_NAME="feature/user-authentication"

# Timestamp when session started (ISO 8601)
CLAUDE_SESSION_STARTED="2026-01-09T10:30:00-03:00"
```

**Benefits**:
- Zero friction for hook scripts
- Standard POSIX convention
- Backward compatible (empty if not set)
- Works across all shells (bash, zsh, fish)

### Secondary: CLI Query Command

Provide a command to retrieve session metadata as JSON:

```bash
$ claude --current-session
{
  "session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "session_name": "feature/user-authentication",
  "started_at": "2026-01-09T10:30:00-03:00",
  "project_path": "/Users/emilson/Projects/VKS",
  "transcript_path": "~/.claude/projects/VKS/a1b2c3d4-e5f6-7890-abcd-ef1234567890.jsonl"
}
```

**Benefits**:
- Scriptable without environment variables
- Machine-readable JSON output
- Useful for external monitoring tools

### Tertiary: Enhanced Session Start Hook

Improve the existing session start hook to include metadata:

```json
// Passed to on-session-start hook
{
  "event": "session-start",
  "session_id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "session_name": "",
  "project_path": "/Users/emilson/Projects/VKS",
  "timestamp": "2026-01-09T10:30:00-03:00"
}
```

**Benefits**:
- External systems can register session at creation time
- Enables proactive setup (e.g., create worktree before first command)

---

## Alternatives Considered

We evaluated **7 synchronization scenarios** using a multi-agent analysis framework. Here are the key findings:

| Scenario | Description | Score | Status |
|----------|-------------|-------|--------|
| **Scenario 3** | **Environment Variable Injection** (this request) | **8.3-8.6/10** | **BLOCKED** (requires vendor) |
| Scenario 5 | Git Branch-Based Identity (workaround) | 7.0-7.3/10 | **CURRENT** (best available) |
| Scenario 1 | Transcript Path Parsing | 5.3-5.7/10 | Fragile |
| Scenario 2 | Session Registry File | 5.7-6.0/10 | Complex |
| Scenario 4 | Status Line Bidirectional Sync | 6.0-7.0/10 | High complexity |
| Scenario 6 | Hook-Based Synchronization | 6.0-6.3/10 | Race conditions |
| Scenario 7 | External Session Manager | 4.7-5.0/10 | Heavyweight |

**Unanimous Recommendation**: All 3 independent agents identified **Scenario 3 (Environment Variables)** as the ideal long-term solution, but it is currently **BLOCKED** on vendor implementation.

**Current Workaround**: We are using **Scenario 5 (Git Branch-Based Identity)** where the git branch name serves as the session identifier. This works but has limitations:
- Requires discipline (1 branch = 1 session)
- Breaks if user switches branches mid-session
- Doesn't help with session name visibility

---

## Implementation Notes

### Backward Compatibility
- All new environment variables should default to empty strings if not set
- Existing hook scripts continue to work unchanged
- CLI command returns error if called outside a session

### Security Considerations
- Session IDs are UUIDs (already safe to expose)
- Session names are user-defined (no sensitive data)
- Environment variables only visible to child processes (standard OS behavior)

### Performance Impact
- Negligible: Environment variables are set once at session start
- CLI command reads from in-memory session state (no file I/O)

---

## Expected Impact

If implemented, this feature would:

1. **Enable Multi-Agent Ecosystems**: External orchestrators (multi-agent-os, CrewAI, AutoGen) can integrate seamlessly with Claude Code
2. **Improve Git Workflows**: Automated worktree management tied to session lifecycle
3. **Enhance Observability**: Better session tracking for debugging and auditing
4. **Reduce Integration Friction**: Developers no longer need fragile file path parsing
5. **Support Cross-Tool Workflows**: Unified session identity across Claude Code, Cursor, Windsurf, etc.

### Metrics of Success
- **Adoption**: 50%+ of advanced users enable session-based automation within 6 months
- **Ecosystem Growth**: 3+ third-party tools integrate with Claude Code session API within 12 months
- **Support Reduction**: 20% fewer issues related to session identification and hook debugging

---

## References

### Related Issues
- (None found - this appears to be a new request)

### Community Discussion
- Multi-agent orchestration is a growing use case (see multi-agent-os, AutoGen, CrewAI)
- Git worktree workflows are increasingly common for AI-assisted development

### Prior Art
- **VS Code**: Exposes `VSCODE_PID` and workspace metadata via environment variables
- **Cursor**: Provides session context through internal APIs
- **GitHub Copilot**: Exposes session metadata for telemetry and debugging

---

## Appendix: Multi-Agent Analysis Summary

We conducted a formal evaluation using 3 independent AI agents (Architect, Integration Specialist, DevOps Engineer) to assess 7 synchronization scenarios.

### Agent Consensus
- **All 3 agents** ranked Scenario 3 (Environment Variables) as the top long-term solution
- **All 3 agents** identified vendor dependency as the primary blocker
- **All 3 agents** recommended Scenario 5 (Git Branch-Based Identity) as the best available workaround

### Key Quotes
> "Scenario 3 would score **8-9/10** if implemented by the vendor. It's the cleanest architectural solution." - Architect Agent

> "Environment variables are the **gold standard** for process-level metadata injection. This is how every mature CLI tool works." - Integration Specialist Agent

> "Without vendor support, we're stuck with workarounds that are **70% as good** but require 3x the maintenance." - DevOps Engineer Agent

### Full Analysis
See `.claude/docs/multi-agent-collaboration.md` for complete evaluation matrix.

---

## Conclusion

This feature request represents a **critical missing capability** for advanced Claude Code integrations. While workarounds exist, they are fragile and require significant maintenance overhead.

**Request Priority**: High
**Estimated Implementation Effort**: Low (environment variables) to Medium (full CLI API)
**Community Benefit**: Enables an entire ecosystem of third-party integrations

We are willing to beta test this feature and provide feedback if Anthropic is interested in pursuing this.

---

**Contact**:
Emilson de Queiroz Moraes
Email: emilson.moraes@gmail.com
Role: DevOps Engineer & AI Evangelist @ Vek
Location: Florianópolis, SC, Brazil

---

*Document prepared using multi-agent analysis framework*
*Analysis Date: 2026-01-09*
*Agents: Architect, Integration Specialist, DevOps Engineer*
*Consensus Score: 100% agreement on Scenario 3 as ideal solution*
