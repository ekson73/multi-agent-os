# Migration Plan: OrgOps MCP Hub → maos-mcp-hub

> **Date:** 2026-02-22
> **Source:** `my-example-api/scripts/` (orgops-mcp-hub + bitbucket_pipeline)
> **Destination:** `ekson73/multi-agent-os/mcp-tools/maos-mcp-hub/`
> **Status:** ✅ COMPLETED — All 6 phases done

## Target Structure

```
multi-agent-os/
├── mcp-tools/
│   └── maos-mcp-hub/
│       ├── hub.py               ← gateway (renamed from orgops-mcp-hub.py)
│       ├── cli.py               ← test CLI (renamed from mcp-cli.py)
│       ├── requirements.txt
│       ├── .env.example
│       ├── .gitignore
│       ├── LICENSE              ← MIT
│       ├── README.md
│       ├── MIGRATION-PLAN.md   ← this file
│       ├── servers/
│       │   ├── __init__.py
│       │   └── bitbucket/
│       │       ├── __init__.py
│       │       ├── server.py
│       │       └── tools.py    ← 42 tools
│       └── lib/
│           ├── __init__.py
│           └── bitbucket/      ← renamed from bitbucket_pipeline
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

### Phase 1: Cleanup (remove Org-specific refs) ✅
- [x] Remove `org_bitbucket_username/password` fallback (client.py:48,52)
- [x] Genericize docstrings `ORG_*` → `MY_*` (client.py:557-633, tools.py:2043)
- [x] Remove `VKS-1133`/`VKS-1134` refs from docstrings (tools.py, server.py)
- [x] Fix singleton inconsistency (13 tools in tools.py → all use `get_client()`)
- [x] Fix SyntaxWarning `\d` (tools.py: inside docstring → escaped)

### Phase 2: Restructure ✅
- [x] Copy files to multi-agent-os/mcp-tools/maos-mcp-hub/
- [x] Rename orgops-mcp-hub.py → hub.py
- [x] Rename mcp-cli.py → cli.py
- [x] Move bitbucket_pipeline/ → lib/bitbucket/
- [x] Move mcp-servers/bitbucket/ → servers/bitbucket/
- [x] Update all import paths (bitbucket_pipeline → lib.bitbucket)
- [x] Rename HUB_NAME to "maos-mcp-hub"
- [x] SERVERS_DIR updated to "servers/"

### Phase 3: Config ✅
- [x] Create .env.example with all required env vars
- [x] requirements.txt (fastmcp, httpx, aiolimiter, pydantic, python-dotenv)
- [x] Zero credentials in any files

### Phase 4: Docs ✅
- [x] README.md (architecture, setup, 42-tool table, add-server guide, Claude config)
- [x] LICENSE (MIT)
- [x] .gitignore

### Phase 5: Test ✅
- [x] Hub discovers bitbucket server (42 tools loaded, zero warnings)
- [x] CLI works (`python3 cli.py list-servers`)
- [x] Imports resolve correctly
- [x] venv created, dependencies installed

### Phase 6: Publish ✅
- [x] Commit + push to `ekson73/multi-agent-os` — commit `20df6d9`
- [x] Commit + push removal from `my-example-api` — commit `fe021f1a`
- [x] Sync `org-claude-plugins` marketplace — commit `6a54211`
- [x] Remove old `orgops-mcp-hub` MCP server from `~/.claude.json`
- [x] Add new `maos-mcp-hub` MCP server pointing to multi-agent-os

## QA Report

**Agent:** maos-mcp-hub-qa (Sonnet 4.6, 4min)
**Veredito:** ✅ APROVADO

### Corrections made during QA:
1. `lib/bitbucket/__init__.py` — removed `__author__ = "Acme Corp"` (company leak)
2. `hub.py` — replaced `ghp_your_token` placeholder (triggered credential scan)
3. Removed all `__pycache__/` directories
4. Created `.gitignore`
5. Created `LICENSE` (MIT)
6. Added `python-dotenv` to requirements.txt + `load_dotenv()` in hub.py/cli.py

### Completeness Check:
- **Agent:** maos-migration-completeness (Sonnet 4.6, 2min)
- **Result:** 16/16 files migrated, zero external dependencies, source files cleaned

## Cleanup Details (6 company refs — all removed)

| # | File | Original | Replaced With |
|---|------|----------|--------------|
| 1 | client.py:48 | `org_bitbucket_username` | Removed (fallback eliminated) |
| 2 | client.py:52 | `org_bitbucket_password` | Removed (fallback eliminated) |
| 3 | client.py:557 | `ORG_APP_ENDPOINT` | `APP_ENDPOINT` |
| 4 | client.py:598-599 | `ORG_REPO_ID`/`my-example-api` | `MY_REPO_ID`/`my-repo` |
| 5 | client.py:632-633 | `ORG_WORKSPACE_ID`/`acme-org` | `MY_WORKSPACE_ID`/`my-workspace` |
| 6 | tools.py:2043 | `ORG_PREVIEW=true,SLUG=vks-1134-*` | `DEPLOY_ENV=staging,VERSION=v1.0` |

## Singleton Fix (13 tools — all fixed)

All `client = BitbucketPipelineClient()` replaced with `client = get_client()`.
Tools with `repo_slug` param use: `client = BitbucketPipelineClient(repo_slug=repo_slug) if repo_slug else get_client()`
