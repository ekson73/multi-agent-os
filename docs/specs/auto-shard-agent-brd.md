# Business Requirements Document (BRD)
## Auto-Shard Agent for Claude Code

---

**Document Control**

| Property | Value |
|----------|-------|
| **Project** | Auto-Shard Agent |
| **Version** | 1.0.0 |
| **Author** | BizBridge (Business Analyst) |
| **Created** | 2026-01-25 |
| **Status** | Draft for Review |
| **Stakeholders** | AI Agents (Claude Code), Human Developers, DevOps |

---

## 1. Executive Summary

### Business Need
Claude Code agents frequently work with large documentation files (CLAUDE.md, specs, rules) that exceed optimal context window sizes. Current state requires manual intervention to split files, creating maintenance overhead and inconsistent sharding practices.

### Proposed Solution
An autonomous AI agent that automatically detects oversized files, intelligently identifies logical sharding boundaries, creates organized shard files, and maintains referential integrity through a self-executing skill system.

### Expected Benefits

| Benefit | Measurement | Target |
|---------|-------------|--------|
| **Reduced Manual Effort** | Hours saved per month | 8-12 hours |
| **Consistency** | Sharding pattern adherence | 100% |
| **Context Efficiency** | Avg file size reduction | 40-60% |
| **Maintainability** | Files requiring re-sharding | <5% |
| **Agent Performance** | Context load time improvement | 30-50% |

---

## 2. Scope

### In Scope

- Automatic file size detection (threshold-based)
- Section boundary identification (semantic analysis)
- Shard file creation with proper taxonomy
- Main file update with references
- Integrity validation (pre/post sharding)
- Recursive sharding (shards that exceed threshold)
- Rollback on failure

### Out of Scope (Phase 1)

- Code files (.py, .js, .java)
- Binary files
- Multi-file refactoring
- User-facing UI

---

## 3. Functional Requirements

### RF01: File Size Detection

**Description**: Detect when a file exceeds the configured size threshold.

**Acceptance Criteria:**
- Agent checks file size before any edit/write operation
- Threshold configurable via config (default: 40KB)
- Detection triggers within 100ms of file access
- Size calculation includes UTF-8 byte count

**Priority**: P0 (Critical)

---

### RF02: Section Boundary Identification

**Description**: Identify logical sections suitable for extraction into shards.

**Acceptance Criteria:**
- Parse Markdown using heading hierarchy (H1 = top-level section)
- Detect YAML front-matter boundaries
- Identify fenced code blocks (prevent mid-block splits)
- Calculate section sizes independently
- Exclude sections marked with `<!-- no-shard -->` tag
- Minimum shard size: 2KB

**Priority**: P0 (Critical)

---

### RF03: Section Criticality Classification

**Description**: Classify sections by importance to prioritize what stays in main file.

**Acceptance Criteria:**
- Assign criticality: CRITICAL (keep), HIGH (consider), MEDIUM (shard), LOW (shard)
- CRITICAL: Sections with `<!-- critical -->` tag or keywords (MUST, NEVER)
- HIGH: Top sections by cross-reference count, protocol refs [CXX]
- MEDIUM: Sections >5KB with low reference count
- LOW: Deprecated sections, changelogs, appendices

**Priority**: P1 (High)

---

### RF04: Shard File Creation

**Description**: Create shard files in appropriate taxonomy directories.

**Acceptance Criteria:**
- Follow taxonomy: `.claude/docs/{category}/{shard-name}.md` or `.claude/rules/`
- CRITICAL/HIGH → `.claude/rules/` (auto-load)
- MEDIUM/LOW → `.claude/docs/` (on-demand)
- Preserve original section metadata
- Add shard header with breadcrumb to parent
- Include version in front-matter

**Priority**: P0 (Critical)

---

### RF05: Main File Update with References

**Description**: Replace sharded sections with concise references.

**Acceptance Criteria:**
- Replace section content with reference block
- Preserve section heading
- Add one-line summary + link to shard
- Update table of contents if present

**Priority**: P0 (Critical)

---

### RF06: Integrity Validation

**Description**: Validate file integrity before and after sharding.

**Acceptance Criteria:**
- Pre-shard: Compute SHA256 hash of original
- Post-shard: Verify main + shards reconstruct to original
- Check: No broken internal links
- Check: All code blocks properly closed
- Check: YAML front-matter valid
- Rollback if any check fails

**Priority**: P0 (Critical)

---

### RF07: Recursive Sharding

**Description**: Apply sharding recursively if generated shards exceed threshold.

**Acceptance Criteria:**
- Check shard size after creation
- If shard >40KB, re-apply sharding logic
- Maximum recursion depth: 3 levels
- Prevent infinite loops (hash tracking)

**Priority**: P1 (High)

---

## 4. Non-Functional Requirements

### RNF01: Performance

| Metric | Target |
|--------|--------|
| Detection latency | <100ms |
| Total execution | <30s for 500KB |

### RNF02: Configurability

Configuration via `~/.claude/config.yaml`:
- threshold_kb: 40
- max_depth: 3
- exclude_patterns
- critical_sections

### RNF03: Reliability

- Automatic rollback on failure
- Backup before modification
- Lock file for concurrent access

### RNF04: Observability

- JSON-RPC logs (C06 compliant)
- Error messages with recovery instructions

### RNF05: Git Integration

- Respect git worktree protocol (C04)
- Conventional commit messages
- No direct commits to main

---

## 5. User Stories

| ID | Story | Priority | Points |
|----|-------|----------|--------|
| US1 | As an AI agent, I want to detect oversized files automatically | P0 | 3 |
| US2 | As an AI agent, I want to create logical shards | P0 | 8 |
| US3 | As a human, I want to review shard plan before execution | P1 | 5 |
| US4 | As an AI agent, I want to validate integrity | P0 | 5 |
| US5 | As an AI agent, I want to handle recursive sharding | P1 | 8 |
| US6 | As DevOps, I want structured logs | P2 | 3 |

---

## 6. Business Rules

| ID | Rule | Enforcement |
|----|------|-------------|
| BR01 | Main + shards must reconstruct original | Integrity validation |
| BR02 | No shard <2KB | Section classifier |
| BR03 | Taxonomy compliance | File creation |
| BR04 | No orphan shards | Reference + validation |
| BR05 | Git worktree mandate | Pre-execution check |

---

## 7. Risks & Mitigation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Content loss | Medium | Critical | SHA256 + rollback |
| Circular refs | Low | High | Graph validation |
| Performance >30s | High | Medium | Chunked processing |
| Breaking refs | Medium | High | Symlinks + deprecation |
| Git conflicts | High | Medium | Lock file |

---

## 8. Dependencies

| Type | Dependency | Version |
|------|------------|---------|
| Internal | Git Worktree Protocol (C04) | 2.0 |
| Internal | Session Report Standard (C05) | 1.1 |
| Internal | AI-Native Environment (C06) | 1.0 |
| External | Python | 3.9+ |
| External | python-markdown | 3.4+ |

---

## 9. Success Metrics

| Metric | Baseline | Target |
|--------|----------|--------|
| Files sharded/month | 0 | 20-30 |
| Avg file size | 55KB | 20-25KB |
| Manual interventions | 10/month | <2/month |
| Sharding failures | N/A | <5% |

---

## 10. Timeline

| Phase | Weeks | Deliverable |
|-------|-------|-------------|
| MVP | 1-4 | RF01-RF06, RNF01-05 |
| Advanced | 5-8 | RF07, JSON/YAML support |
| Production | 9-10 | CI/CD, docs |

---

*Assinatura: Claude-Code (Business Analyst) | 2026-01-25*
