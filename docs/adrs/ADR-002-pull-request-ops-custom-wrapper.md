# ADR-002: Pull Request Operations — Custom Wrapper over Rovo Dev API

## Status

**Accepted** (2026-04-23)

## Context

### Problem Statement

The `maos-mcp-hub` `atlassian_bitbucket.pull_request` resource is missing three critical operations required for the full autonomous PR review loop (Step 8 of the AI-Native Protocol, "7 Mentes"):

- `add_comment` — responding to AI bot findings (Qodo, CodeRabbit, Copilot, RovoDev)
- `update_description` — updating Bot Scorecard in the PR body after review cycles
- `reply_to_comment` — threaded replies to specific bot comments

Additionally, parameter naming is inconsistent across operations on the same resource:

- `create` accepts `account` (multi-persona auth) — correct
- `get` and `get_comments` accept only `pr_id` and NOT `account` — inconsistent
- Agents must memorize operation-specific contracts, violating DNA Geracional item 3 (Independência Agnóstica — padronizar)

Finally, `createJiraIssue` rejects the `priority` field when issue type is `Intervenção Técnica - I.A.` (id 10407), forcing 2 round-trips (create + edit) to set priority. This was empirically reproduced in VKS-1851 and VKS-1853 creation sessions.

Tracking ticket: **[VKS-1853](https://vek.atlassian.net/browse/VKS-1853)**.

### Decision Space

Three routes were considered (per ticket guidance — "Mente Agnóstica — pesquisa antes de implementar"):

**Route A — Rovo Dev MCP / atlassian-rovo as primary**
Delegate the gateway to proxy calls into the `atlassian-rovo` MCP server (which has native Atlassian auth).

**Route B — Bitbucket Cloud REST API v2.0 (custom wrapper in `maos-mcp-hub`)**
Implement new tools in `servers/bitbucket/tools.py` and new client methods in `lib/bitbucket/client.py`, using endpoints:
- `POST /2.0/repositories/{workspace}/{repo_slug}/pullrequests/{pr_id}/comments`
- `PUT /2.0/repositories/{workspace}/{repo_slug}/pullrequests/{pr_id}`

**Route C — Hybrid**
Use Rovo where available, fall back to custom for gaps.

### Prior Art / Constraints

- **PR #40** (commit `c8db272`, 2026-04-20): `chore(delegation): deprecate atlassian-rovo to Tier-3 fallback [VKS-1706]`. The repository already made the architectural decision that `atlassian-rovo` is a **fallback only**, not a primary dependency. The `maos-mcp-hub` is the primary Tier-1 tool. Expanding coverage by delegating *back* into `atlassian-rovo` would reverse this architectural direction.
- **PR #36** (VKS-1694 v1.7): `atlassian_bitbucket` gateway already wraps 52 local actions directly — zero external MCP dependencies for core flows.
- **VKO-88** (PR #38): last primary-tier gap on Jira was closed by fixing JQL search *inside* the hub, confirming the hub-first architecture.
- **Bitbucket Cloud REST API v2.0** natively supports the required endpoints (PR comments, PR update) with the same auth layer already used by the existing 52 actions (`get_client` / `get_client_for_account`).
- **atlassian-rovo MCP** does not expose `add_comment` / `update_description` for Bitbucket PRs at the time of this ADR (confirmed empirically and via PR #40 rationale — Rovo's Bitbucket coverage is read-heavy, and VKS operates on Bitbucket Cloud via the workspace-level token pool).

## Decision

Adopt **Route B — Custom Wrapper in `maos-mcp-hub`**.

### Rationale

1. **Architectural alignment**: PR #40 explicitly demoted `atlassian-rovo` to Tier-3 fallback. Delegating new functionality back into Rovo (Route A) would contradict the documented ecosystem direction.
2. **Coverage**: Rovo Dev does not natively expose the required PR comment / description endpoints for Bitbucket Cloud in a multi-persona / multi-account shape. Route A is not feasible end-to-end.
3. **Consistency**: The 52 existing BB actions already flow through `lib/bitbucket/client.py` with the same auth, rate limiting, retry semantics, account pool, and governance hooks. Adding 3 more PR methods there preserves the architecture and returns identical error shapes.
4. **Testability**: `tests/test_bitbucket_client.py` and `tests/test_gateway_bitbucket.py` already mock the same `request_json` infrastructure via `respx`. Extending the test matrix is straightforward.
5. **Zero new dependencies**: No new Python packages, no new MCP servers, no new env vars.

Hybrid (Route C) is unnecessary given that Route A has zero reusable surface for these three specific operations.

### Scope

This ADR covers the three DoD items of VKS-1853:

**Gap 6 — `pull_request` missing ops**
Add three new tools in `servers/bitbucket/tools.py`:
- `add_pr_comment(content, pr_id=None, pull_request_id=None, parent_id=None, account="", workspace="", repo_slug="")` — `content` first positional; `pr_id` keyword-only with `pull_request_id` as forward-compat alias (Gap 7).
- `update_pr_description(description, pr_id=None, pull_request_id=None, account="", workspace="", repo_slug="")` — `description` first positional; `pr_id` keyword-only aliased.
- `reply_to_pr_comment(parent_id, content, pr_id=None, pull_request_id=None, account="", workspace="", repo_slug="")` — `parent_id` first positional (required); thin wrapper over `add_pr_comment`.

Registered in `RESOURCE_MAP["pull_request"]` as operations `add_comment`, `update_description`, `reply_to_comment`.

**Gap 7 — Params standardization**
- All `pull_request.*` operations will accept **both** `pr_id` (canonical, existing) **and** `pull_request_id` (alias, forward-compat alternative) to support agents that prefer resource-name-matched params.
- All `pull_request.*` operations will accept `account` (currently some do, some do not). Where it was implicit, it becomes explicit and documented.
- Backwards compatibility: `pr_id` remains the canonical parameter name. No breaking change.

**Gap 8 — Jira `priority` rejected for issue type 10407**
- Root cause hypothesis (to confirm via `getIssueTypeMetaWithFields`): the `priority` field is not in the Jira screen scheme for issue type 10407 in project VKS.
- Fix in wrapper: `create_issue` gateway action will accept `priority` as an optional parameter, serialize it as `{"name": priority}` (Jira-standard) when the issue type allows, and surface a descriptive error message ("priority not available for this issue type / screen scheme") when the server rejects it, rather than a generic 400.
- Ideal long-term fix is at the Jira screen-scheme config level (not in wrapper scope), but the wrapper change unblocks agents with a graceful-degrade path and clear hint for humans.

### Consequences

**Positive**:
- Full autonomous PR loop (Step 8 of AI-Native Protocol) unblocked. Agents can respond to bot reviews and update Bot Scorecards programmatically.
- Consistent params contract (`account + pr_id + payload`) across all `pull_request.*` operations.
- Hub-first architecture preserved; `atlassian-rovo` remains Tier-3 fallback.

**Negative**:
- Three new HTTP endpoints to maintain against Bitbucket API evolution. Mitigated by reusing the same `request_json` / `ApiError` infrastructure as 52 existing actions.
- If Bitbucket ever introduces a breaking change to PR comment API (unlikely, v2.0 is stable), we pay maintenance cost — but so would Rovo, so the cost is architecture-independent.

**Neutral**:
- `pull_request_id` alias adds minor schema complexity; kept internal to the wrapper, agents see a cleaner contract.

## References

- VKS-1853 (primary ticket)
- PR #40 / VKS-1706 (atlassian-rovo demotion to Tier-3)
- PR #36 / VKS-1694 v1.7 (52-action gateway)
- PR #38 / VKO-88 (Jira JQL hub migration)
- Memory: `~/.claude/projects/-Users-emilson-moraes-Projects-vek-docs-trellis/memory/feedback_maos_mcp_hub_gaps.md`
- Bitbucket Cloud REST API v2.0 — Pullrequests endpoints
- ADR-001 (session identity) — same ADR format template
