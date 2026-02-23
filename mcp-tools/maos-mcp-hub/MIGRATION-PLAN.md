# Migration Plan: VekOps MCP Hub → maos-mcp-hub

> **Date:** 2026-02-22
> **Source:** `~/Projects/vks-jss-sales-api/scripts/` (vekops-mcp-hub + bitbucket_pipeline)
> **Destination:** `~/Projects/multi-agent-os/mcp-tools/maos-mcp-hub/`
> **Status:** COMPLETED (Phases 1–5) — awaiting review before publish

## Target Structure

```
multi-agent-os/
├── mcp-tools/
│   └── maos-mcp-hub/
│       ├── hub.py               ← gateway (renamed from vekops-mcp-hub.py)
│       ├── cli.py               ← test CLI (renamed from mcp-cli.py)
│       ├── requirements.txt
│       ├── README.md
│       ├── MIGRATION-PLAN.md    ← this file
│       ├── servers/
│       │   └── bitbucket/
│       │       ├── __init__.py
│       │       ├── server.py
│       │       └── tools.py
│       └── lib/
│           └── bitbucket/       ← renamed from bitbucket_pipeline
│               ├── __init__.py
│               ├── client.py
│               ├── analyzer.py
│               ├── api_providers.py
│               ├── health.py
│               ├── instructions.py
│               ├── knowledge_base.py
│               ├── models.py
│               ├── patterns.py
│               └── validators.py
```

## Phases

### Phase 1: Cleanup (remove Vek-specific refs) ✅
- [x] Remove `vek_bitbucket_username/password` fallback (client.py:48,52)
- [x] Genericize docstrings `VEK_*` → `MY_*` (client.py:557-633, tools.py:2043)
- [x] Remove `VKS-1133`/`VKS-1134` refs from docstrings (tools.py, server.py)
- [x] Fix singleton inconsistency (13 tools in tools.py → all use `get_client()`)
- [x] Fix SyntaxWarning `\d` (tools.py: inside docstring → escaped)

### Phase 2: Restructure ✅
- [x] Copy files to multi-agent-os/mcp-tools/maos-mcp-hub/
- [x] Rename vekops-mcp-hub.py → hub.py
- [x] Rename mcp-cli.py → cli.py
- [x] Move bitbucket_pipeline/ → lib/bitbucket/
- [x] Move mcp-servers/bitbucket/ → servers/bitbucket/
- [x] Update all import paths (bitbucket_pipeline → lib.bitbucket)
- [x] Rename HUB_NAME to "maos-mcp-hub"
- [x] SERVERS_DIR updated to "servers/" (was "mcp-servers/")

### Phase 3: Config ✅
- [x] Create .env.example with all required env vars
- [x] requirements.txt created (fastmcp, httpx, aiolimiter, pydantic)
- [x] WARNING honored: no credentials in any files

### Phase 4: Docs ✅
- [x] README.md with generic setup instructions (architecture diagram, tool list, add-server guide, Claude Desktop config)
- [x] requirements.txt

### Phase 5: Test ✅
- [x] Validate hub discovers bitbucket server (42 tools loaded)
- [x] Validate tool listing works (`python3 cli.py list-servers`)
- [x] Validate imports resolve correctly (`from hub import discover_mcp_servers`)
- [x] venv created, dependencies installed, all tests pass

### Phase 6: Publish
- [ ] Commit + push to ekson73/multi-agent-os (awaiting manual review)
- [ ] Update vek-claude-plugins marketplace (sync multi-agent-os content)

## Cleanup Details (6 Vek refs)

| # | File | Line | Current | Replace With |
|---|------|------|---------|-------------|
| 1 | client.py | 48 | `vek_bitbucket_username` | Remove fallback |
| 2 | client.py | 52 | `vek_bitbucket_password` | Remove fallback |
| 3 | client.py | 557 | `VEK_APP_ENDPOINT` | `APP_ENDPOINT` |
| 4 | client.py | 598-599 | `VEK_REPO_ID`/`vks-jss-sales-api` | `MY_REPO_ID`/`my-repo` |
| 5 | client.py | 632-633 | `VEK_WORKSPACE_ID`/`vek-servicos` | `MY_WORKSPACE_ID`/`my-workspace` |
| 6 | tools.py | 2043 | `VEK_PREVIEW=true,SLUG=vks-1134-*` | `DEPLOY_ENV=staging,VERSION=v1.0` |

## Singleton Fix (13 tools)

Replace `client = BitbucketPipelineClient()` with `client = get_client()` in:
- get_commit_details, get_commit_build_statuses, get_builds_for_commit, compare_commit_builds
- get_pull_requests, get_pr_details, get_pr_build_statuses, create_pull_request
- list_pipeline_schedules, get_pipeline_config, get_ssh_key_info
- trigger_pipeline, list_branches

For tools with `repo_slug` param: `client = BitbucketPipelineClient(repo_slug=repo_slug) if repo_slug else get_client()`
