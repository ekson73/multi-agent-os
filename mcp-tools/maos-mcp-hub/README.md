# MAOS MCP Hub

**Universal MCP Gateway — Auto-discovers and exposes all your MCP servers through a single entry point.**

Part of the [Multi-Agent OS (MAOS)](https://github.com/your-org/multi-agent-os) ecosystem.

---

## What It Does

MAOS MCP Hub is a **universal gateway** for the [Model Context Protocol (MCP)](https://modelcontextprotocol.io/). Instead of configuring each AI tool individually in Claude Desktop (or any MCP client), you configure MAOS MCP Hub once — and it auto-discovers all your MCP servers and exposes their tools with clean namespaced names.

**Key features:**
- 🔍 **Auto-discovery** — Drop a new server into `servers/` and it's instantly available
- 🏷️ **Namespaced tools** — `bitbucket_get_recent_builds`, `github_get_workflow_status`, etc.
- ⚡ **Single config** — One Claude Desktop entry, unlimited servers
- 🔌 **Zero-config for new servers** — No hub code changes needed
- 📊 **Dynamic registration** — Tools registered at startup

---

## Architecture

```
hub.py                          ← Universal MCP gateway (STDIO transport)
│
├── servers/                    ← MCP server modules (auto-discovered)
│   └── bitbucket/
│       ├── server.py           ← Server metadata (SERVER_INFO)
│       └── tools.py            ← Tool implementations (TOOLS dict)
│
├── lib/                        ← Shared client libraries
│   ├── common/
│   │   ├── errors.py           ← Typed API errors (Auth/NotFound/RateLimit/etc.)
│   │   └── http.py             ← Shared HTTP layer (retry/backoff/rate-limit/redaction)
│   └── bitbucket/
│       ├── client.py           ← Bitbucket Cloud API client (async httpx)
│       ├── analyzer.py         ← AI-powered failure analysis
│       ├── health.py           ← Health monitoring
│       ├── models.py           ← Pydantic data models
│       ├── patterns.py         ← Error pattern matching
│       ├── knowledge_base.py   ← Auto-learning fix KB
│       ├── instructions.py     ← Contextual diagnostic instructions
│       ├── validators.py       ← Input validation helpers
│       └── api_providers.py    ← Multi-provider AI integration
│
├── cli.py                      ← Development/testing CLI
├── requirements.txt
├── requirements-dev.txt
├── tests/
├── .env.example
└── README.md
```

**Request flow:**
```
Claude Desktop
    ↓ MCP (STDIO)
hub.py
    ↓ discovers + registers
servers/bitbucket/tools.py
    ↓ calls
lib/bitbucket/client.py
    ↓ HTTP
Bitbucket Cloud API
```

---

## Setup

### 1. Clone

```bash
git clone https://github.com/your-org/multi-agent-os.git
cd multi-agent-os/mcp-tools/maos-mcp-hub
```

### 2. Install dependencies

```bash
python3 -m venv .venv
source .venv/bin/activate      # Linux/macOS
# .venv\Scripts\activate       # Windows

pip install -r requirements.txt
pip install -r requirements-dev.txt
```

### 3. Configure environment

```bash
cp .env.example .env
```

Edit `.env` with your credentials:

```env
BITBUCKET_EMAIL=your-email@company.com
BITBUCKET_USERNAME=your_username
BITBUCKET_API_TOKEN=your_bitbucket_api_token
BITBUCKET_WORKSPACE=your_workspace
# Optional default repo (recommended empty for multi-repo)
BITBUCKET_REPO_SLUG=
JIRA_EMAIL=your-email@company.com
JIRA_API_TOKEN=your_jira_token
# Optional fallback shared token for Jira/Confluence:
ATLASSIAN_API_TOKEN=
JIRA_CLOUD_ID=your-cloud-id
```

### Token Policy (Operational)

Use app-scoped env vars by default. Reusing the same secret across vars is allowed when desired.

- Bitbucket: `BITBUCKET_API_TOKEN` (primary) -> `BITBUCKET_APP_PASSWORD` (legacy fallback).
- Jira: `JIRA_API_TOKEN` (primary) -> `ATLASSIAN_API_TOKEN` (fallback).
- Confluence (future tools): `CONFLUENCE_API_TOKEN` (primary) -> `ATLASSIAN_API_TOKEN` (fallback).

Multi-repo recommendation:
- Keep `BITBUCKET_REPO_SLUG` empty.
- Pass `repo_slug` in each Bitbucket tool call.

### 4. Test the CLI

```bash
# List available servers
python3 cli.py list-servers

# List tools from the bitbucket server
python3 cli.py bitbucket list-tools

# Call a tool directly
python3 cli.py bitbucket get_recent_builds '{"count": 5, "repo_slug": "your_workspace/your_repo"}'
```

### 5. Configure Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json` (macOS):

```json
{
  "mcpServers": {
    "maos-mcp-hub": {
      "command": "/path/to/.venv/bin/python3",
      "args": ["/path/to/maos-mcp-hub/hub.py"],
      "env": {
        "BITBUCKET_EMAIL": "your-email@company.com",
        "BITBUCKET_USERNAME": "your_username",
        "BITBUCKET_API_TOKEN": "your_bitbucket_api_token",
        "BITBUCKET_WORKSPACE": "your_workspace"
      }
    }
  }
}
```

Restart Claude Desktop. You'll see the **6 `atlassian_*` gateway tools** (discover, jira, confluence, bitbucket, compass, common) covering 104 actions total (v2.3.0, VKS-2080).

### 6. Run tests (pilot D65)

```bash
pytest -q tests/test_bitbucket_client.py tests/test_jira_client.py
```

---

## Meta-Tools Gateway (Atlassian)

### Problem

AI providers impose tool-count limits that break flat namespaces at scale:

| Provider | Tool Limit |
|----------|-----------|
| Gemini   | 100       |
| Windsurf | 100       |
| ChatGPT  | ~30       |

With 55 Bitbucket tools and Jira/Confluence/Compass on the roadmap, the flat namespace (`bitbucket_get_recent_builds`, `jira_get_issue`, ...) would hit limits immediately.

### Solution: 6 Typed Gateways

The Meta-Tools Gateway collapses **104 actions** (v2.3.0) into **6 MCP tools**. Five domain gateways accept a uniform `{resource?, operation?, params?}` input; `atlassian_discover` is parameterless:

| Gateway | Tool Name | Actions | Purpose |
|---------|-----------|---------|---------|
| **Discover** | `atlassian_discover` | -- | Catalog of all domains and action counts |
| **Jira** | `atlassian_jira` | 27 | Issues, boards, sprints (list/create/update), versions (create/release), estimation, comments, worklogs, links, search |
| **Confluence** | `atlassian_confluence` | 12 | Pages, comments, spaces, search (CQL) |
| **Bitbucket** | `atlassian_bitbucket` | 55 | Pipelines, PRs (incl. add/reply comment, update description — VKS-1853), branches, deployments, tests, caches |
| **Compass** | `atlassian_compass` | 6 | Service registry, components, relationships, custom fields |
| **Common** | `atlassian_common` | 4 | User info, accessible resources, server info |

### 4-Level Progressive Discovery

Every gateway supports progressive discovery. An AI agent can navigate from zero knowledge to full execution in 4 calls (levels 0–2 are discovery; level 3 is execution):

```text
# Level 0 — List resources (call with no params)
atlassian_jira({})
→ { "resources": ["issue", "search", "comment", "worklog", "link", "attachment", "board", "estimation", "project", "user"] }

# Level 1 — List operations for a resource
atlassian_jira({"resource": "issue"})
→ { "resource": "issue", "operations": ["get", "create", "edit", "transition", "get_transitions"] }

# Level 2 — Show param schema for a resource+operation
atlassian_jira({"resource": "issue", "operation": "create"})
→ { "resource": "issue", "operation": "create", "required": ["project_key", "summary", "issue_type"], "optional": {...} }

# Level 3 — Execute
atlassian_jira({"resource": "issue", "operation": "get", "params": {"issue_key": "VKS-1715"}})
→ { "key": "VKS-1715", "summary": "...", "_agent_feedback": {...} }
```

### `_agent_feedback` in Every Response

Every response (discovery or execution) includes an `_agent_feedback` block with governance hints, contextual tips, and suggested next steps:

```json
{
  "_agent_feedback": {
    "tool": "atlassian_jira",
    "resource": "issue",
    "operation": "create",
    "governance": ["governance_level obrigatorio", "DARCI roles recomendados"],
    "next_steps": ["Estimar story points", "Adicionar DARCI roles"]
  }
}
```

Error responses also include enriched feedback (e.g., "Check credentials" for 401, "Rate limit -- retry with backoff" for 429).

### `estimate_story_points` Formula

The Jira gateway includes a deterministic story point estimation formula that calculates complexity from observable issue data:

```text
raw = (base(1) + subtask_w + attachment_w + comment_w + link_w + desc_w + label_bonus)
      × type_multiplier
→ Fibonacci snap {1, 2, 3, 5, 8, 13}
```

Type multipliers: Epic=1.5, Story=1.0, Task=1.0, Bug=0.8, Sub-task=0.6.
Label bonus: +1 for `complex`, `security`, or `migration` labels.

Call with `dry_run=True` (default) to preview, `dry_run=False` to apply.

### Architecture

```text
gateways/                          ← Meta-tool gateway layer
├── discover/
│   ├── gateway.py                 ← GATEWAY_INFO metadata
│   └── actions.py                 ← Domain catalog builder
├── jira/
│   ├── gateway.py
│   └── actions.py                 ← 27 actions across 12 resources
├── confluence/
│   ├── gateway.py
│   └── actions.py                 ← 12 actions across 4 resources
├── bitbucket/
│   ├── gateway.py
│   └── actions.py                 ← 55 actions across 9 resources (VKS-1853)
├── compass/
│   ├── gateway.py
│   └── actions.py                 ← 6 actions across 3 resources
└── common/
    ├── gateway.py
    └── actions.py                 ← 4 actions across 3 resources

lib/gateway/                       ← Gateway framework (reusable)
├── router.py                      ← MetaToolRouter: dispatch + discovery
├── schema_registry.py             ← Auto-gen typed schemas from signatures
├── feedback.py                    ← @with_feedback decorator
├── discovery.py                   ← 3-level discovery response builder
└── types.py                       ← GatewayRequest, ActionSchema, AgentFeedback
```

**Request flow (gateway path):**

```text
AI Agent
    ↓ MCP tool call (e.g., atlassian_jira)
hub.py
    ↓ GatewayRequest(resource=resource, operation=operation, params=params)
gateways/jira/actions.py
    ↓ MetaToolRouter.dispatch()
    ├── level 0-2: discovery response
    └── level 3: handler(**params) wrapped with @with_feedback
            ↓
        lib/jira/client.py → Jira Cloud API
```

### Adding a New Gateway

1. Create `gateways/<domain>/gateway.py` with `GATEWAY_INFO` dict.
2. Create `gateways/<domain>/actions.py` with handler functions and a `build_router()` that returns a `MetaToolRouter`.
3. Register in `gateways/discover/actions.py` `_DOMAIN_REGISTRY`.
4. Register the gateway in `hub.py` by adding it to the `_GATEWAY_MODULES` and `_GATEWAY_INFOS` dicts. Gateways are not auto-discovered; they require explicit registration.

---

## Migration: Flat → Gateway

**Context** (VKS-1694): The legacy flat namespace (`bitbucket_*` + `jira_*` =
60 tools) was replaced by 6 typed meta-tool gateways. Flat tools are fully
**removed** since v1.7 — the handlers in `servers/{bitbucket,jira}/tools.py`
still exist as Python modules and are imported directly by the gateways, but
they are no longer exposed as individual MCP tools.

### Default behavior (since v1.7)

Running `python hub.py` emits a multi-line startup summary to stderr. The
hub is considered ready when these lines appear:

```text
======================================================================
✅ MAOS MCP Hub Ready!
   Gateways: 6 (104 actions)
   Total MCP tools: 6
======================================================================
```

Any other outcome (fewer gateways, a RuntimeError, or a startup trace)
indicates a fail-closed registration — v1.7 has no flat-tool fallback.

### History

- **v2.2 (VKS-1853, 2026-04-23)** added 3 new `pull_request` ops
  (`add_comment`, `update_description`, `reply_to_comment`) and
  standardized params across all `pull_request.*` operations
  (`pr_id`/`pull_request_id` alias, `account` on every op). Also made
  `createJiraIssue` surface a helpful `screen_scheme_hint` when
  `priority` is rejected by a screen scheme (e.g., issue type 10407
  "Intervenção Técnica - I.A." in project VKS). Total actions: 99.
- **v1.6** introduced `MAOS_EXPOSE_FLAT_TOOLS` env flag (default `false`).
  The var and rollback path were **removed in v1.7**.
- If you are on v1.6 and need to set the flag temporarily, upgrade to v1.7
  and migrate any remaining consumer to the `atlassian_*` gateway pattern
  via the mapping table below.

### Mapping table

| Old flat tool | New gateway call |
|---|---|
| `bitbucket_get_recent_builds` | `atlassian_bitbucket({resource:"pipeline", operation:"list"})` |
| `bitbucket_get_build_details` | `atlassian_bitbucket({resource:"pipeline", operation:"get"})` |
| `bitbucket_get_build_steps` | `atlassian_bitbucket({resource:"pipeline", operation:"get_steps"})` |
| `bitbucket_get_step_logs` | `atlassian_bitbucket({resource:"pipeline", operation:"get_logs"})` |
| `bitbucket_trigger_pipeline` | `atlassian_bitbucket({resource:"pipeline", operation:"trigger"})` |
| `bitbucket_stop_pipeline` | `atlassian_bitbucket({resource:"pipeline", operation:"stop"})` |
| `bitbucket_check_pipeline_health` | `atlassian_bitbucket({resource:"pipeline", operation:"get_health"})` |
| `bitbucket_check_alerts` | `atlassian_bitbucket({resource:"pipeline", operation:"get_alerts"})` |
| `bitbucket_auto_diagnose` | `atlassian_bitbucket({resource:"pipeline", operation:"auto_diagnose"})` |
| `bitbucket_get_pull_requests` | `atlassian_bitbucket({resource:"pull_request", operation:"list"})` |
| `bitbucket_get_pr_details` | `atlassian_bitbucket({resource:"pull_request", operation:"get"})` |
| `bitbucket_create_pull_request` | `atlassian_bitbucket({resource:"pull_request", operation:"create"})` |
| `bitbucket_merge_pull_request` | `atlassian_bitbucket({resource:"pull_request", operation:"merge"})` |
| `bitbucket_approve_pull_request` | `atlassian_bitbucket({resource:"pull_request", operation:"approve"})` |
| `bitbucket_list_branches` | `atlassian_bitbucket({resource:"branch", operation:"list"})` |
| `bitbucket_create_branch` | `atlassian_bitbucket({resource:"branch", operation:"create"})` |
| `bitbucket_delete_branch` | `atlassian_bitbucket({resource:"branch", operation:"delete"})` |
| `bitbucket_set_default_branch` | `atlassian_bitbucket({resource:"branch", operation:"set_default"})` |
| `bitbucket_get_recent_deployments` | `atlassian_bitbucket({resource:"deployment", operation:"list"})` |
| `bitbucket_get_test_reports` | `atlassian_bitbucket({resource:"test", operation:"get_reports"})` |
| `bitbucket_list_caches` | `atlassian_bitbucket({resource:"cache", operation:"list"})` |
| `bitbucket_clear_cache` | `atlassian_bitbucket({resource:"cache", operation:"clear"})` |
| `jira_get_issue` | `atlassian_jira({resource:"issue", operation:"get"})` |
| `jira_list_attachments` | `atlassian_jira({resource:"attachment", operation:"list"})` |
| `jira_upload_attachment` | `atlassian_jira({resource:"attachment", operation:"upload"})` |
| `jira_download_attachment` | `atlassian_jira({resource:"attachment", operation:"download"})` |
| `jira_delete_attachment` | `atlassian_jira({resource:"attachment", operation:"delete"})` |
| `jira_get_boards` | `atlassian_jira({resource:"board", operation:"list"})` |
| `jira_get_estimation` | `atlassian_jira({resource:"estimation", operation:"get"})` |
| `jira_set_estimation` | `atlassian_jira({resource:"estimation", operation:"set"})` |

(Full 60-tool mapping available via `atlassian_discover` — call with no params
to list resources, or see `gateways/<domain>/actions.py:RESOURCE_MAP`.)

### Why the change

| Metric | Before (v1.5) | After (v1.7) | Δ |
|---|---:|---:|---:|
| Tools registered by hub | 66 | 6 | **-91%** |
| Schema token footprint | baseline | ~1/10 | **-90%** |
| Functional capability | 60 operations | 96 operations (via 6 gateways) | **+60%** |

Gateways **add** 36 new operations (Jira transition, search.jql, comments,
worklogs, links, etc.) that were never exposed via flat tools.

### Timeline

- ✅ v1.6 — feature flag `MAOS_EXPOSE_FLAT_TOOLS` (hide by default)
- ✅ v1.7 — removed flat-tool registration loop + `servers/{bitbucket,jira}/server.py`
  (handlers in `servers/{bitbucket,jira}/tools.py` remain — gateways depend on them)

---

## Adding a New Server

1. Create a directory under `servers/`:
   ```
   servers/
   └── myservice/
       ├── __init__.py    (empty)
       ├── server.py      (SERVER_INFO dict)
       └── tools.py       (TOOLS dict with async functions)
   ```

2. Define `SERVER_INFO` in `server.py`:
   ```python
   SERVER_INFO = {
       "name": "myservice",
       "display_name": "My Service",
       "version": "1.0.0",
       "description": "Does awesome things",
       "env_vars": {
           "MYSERVICE_API_KEY": "API key for My Service"
       },
       "tools": ["get_status", "list_items"]
   }
   ```

3. Define `TOOLS` in `tools.py`:
   ```python
   async def get_status() -> dict:
       """Get service status"""
       return {"status": "ok"}

   TOOLS = {
       "get_status": get_status,
   }
   ```

4. Restart the hub after adding an explicit gateway registration in `gateways/<your-domain>/` and wiring it into `hub.py` (`_GATEWAY_MODULES`/`_GATEWAY_INFOS`). Legacy flat auto-registration (`myservice_get_status` style) was removed in v1.7 — non-Atlassian servers are welcome as gateways but are no longer picked up automatically via `servers/<name>/server.py`.

---

## Development & Testing

### Test via CLI

```bash
# All servers
python3 cli.py list-servers

# Server tools
python3 cli.py bitbucket list-tools

# Direct tool call
python3 cli.py bitbucket get_recent_builds '{"count": 3}'
python3 cli.py bitbucket check_pipeline_health '{}'
```

### Test import

```bash
python3 -c "from hub import discover_mcp_servers; print(discover_mcp_servers())"
```

### Run in debug mode

```bash
python3 hub.py --help
```

---

## Environment Variables Reference

| Variable | Required | Description |
|----------|----------|-------------|
| `BITBUCKET_EMAIL` | Recommended | Atlassian account email (preferred for Basic auth with API token) |
| `JIRA_EMAIL` | Optional fallback | Shared principal fallback for Bitbucket Basic auth |
| `BITBUCKET_USERNAME` | Legacy fallback | Bitbucket username (fallback for Basic auth) |
| `BITBUCKET_API_TOKEN` | Yes | Bitbucket API token (primary variable) |
| `BITBUCKET_APP_PASSWORD` | Legacy | Deprecated alias (fallback only) |
| `BITBUCKET_WORKSPACE` | Optional | Workspace slug (fallback/context) |
| `BITBUCKET_REPO_SLUG` | Optional | Default repo (`workspace/repo`) — prefer empty in multi-repo mode |
| `BITBUCKET_AUTH_TYPE` | Optional | Force `bearer` or `basic` auth |
| `JIRA_EMAIL` | Yes (jira tools) | Atlassian account email for Jira Basic auth |
| `JIRA_API_TOKEN` | Preferred (jira tools) | Jira token (first lookup for Jira client) |
| `ATLASSIAN_API_TOKEN` | Optional | Shared fallback token for Jira/Confluence |
| `CONFLUENCE_API_TOKEN` | Optional | Reserved for Confluence tooling |
| `JIRA_CLOUD_ID` | Yes (jira tools) | Jira Cloud ID (tenant UUID) |
| `DEEPSEEK_API_KEY` | Optional | AI diagnosis (DeepSeek) |
| `GOOGLE_API_KEY` | Optional | AI diagnosis (Gemini) |
| `MISTRAL_API_KEY` | Optional | AI diagnosis (Mistral) |

**Auth detection:** If `BITBUCKET_AUTH_TYPE` is not set, auth auto-detects bearer format (`ATCTT3x...`) and otherwise uses Basic auth (`email + token`) following Bitbucket API token docs. Basic principal resolution order: `BITBUCKET_EMAIL` -> `JIRA_EMAIL` -> `BITBUCKET_USERNAME`.

**Multi-repo recommendation:** Leave `BITBUCKET_REPO_SLUG` empty and pass `repo_slug` in each Bitbucket tool call.

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Contributing

Contributions welcome! To add a new MCP server integration, see [Adding a New Server](#adding-a-new-server) above.

Issues and PRs: [github.com/your-org/multi-agent-os](https://github.com/your-org/multi-agent-os)

---

Agent Signature: `codex-cli` | Timestamp: `2026-03-04T08:52:33-03:00`
