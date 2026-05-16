# VKS-1694 — Audit de Resíduo Flat-Tools em maos-mcp-hub

**Data**: 2026-04-17
**Sessão**: typed-peacock
**Auditor**: Claude-Opus-4.7 (plan mode + auto mode)
**Status**: FASE 0 concluída, aguardando aprovação humana para FASE 1

> **Snapshot note**: Os inventários e contagens em §1 representam o estado **pré-VKS-1853** (commits anteriores a `4161b01`). VKS-1853 adicionou 3 operações novas em `pull_request` (`add_pr_comment`, `reply_to_pr_comment`, `update_pr_description`), elevando Bitbucket de **52 → 55 tools flat** e o total de ações acessíveis via gateway de **96 → 99**. Tabelas e contagens preservam o snapshot original para fins de auditoria histórica; valores pós-VKS-1853 estão anotados inline quando relevante.

---

## 1. Inventário de Flat-Tools Registradas

### 1.1. Ponto de registro duplicado em `hub.py`

```python
# hub.py:268-294 — FLAT TOOL REGISTRATION (resíduo a remover)
for server_name, server_data in discovered_servers.items():
    for tool_name, tool_func in tools.items():
        namespaced_name = f"{server_name}_{tool_name}"
        mcp.tool(name=namespaced_name)(tool_func)
        total_tools_registered += 1

# hub.py:297-383 — GATEWAY META-TOOL REGISTRATION (mantém)
for gw_name in ["discover", "jira", "confluence", "bitbucket", "compass", "common"]:
    # registra atlassian_* meta-tools
```

### 1.2. Servers flat existentes

| Server | Arquivo | `TOOLS` dict | Count |
|---|---|---:|---:|
| bitbucket | `servers/bitbucket/tools.py:2992` | `TOOLS = {52 entradas}` | **52** |
| jira | `servers/jira/tools.py:512` | `TOOLS = {8 entradas}` | **8** |
| confluence | — | (não existe) | 0 |
| compass | — | (não existe) | 0 |
| common | — | (não existe) | 0 |

**Total flat expostos hoje**: **60 tools** (52 BB + 8 Jira)
**Total meta expostos**: 6 (atlassian_*)
**Total MCP registrado**: **66 tools**
**Objetivo VKS-1694**: 6 tools

### 1.3. Lista exata — Jira (8 tools flat)

| Flat tool | Handler | Gateway equivalente |
|---|---|---|
| `jira_get_issue` | `get_issue()` | `atlassian_jira(resource="issue", operation="get")` |
| `jira_list_attachments` | `list_attachments()` | `atlassian_jira(resource="attachment", operation="list")` |
| `jira_download_attachment` | `download_attachment()` | `atlassian_jira(resource="attachment", operation="download")` |
| `jira_upload_attachment` | `upload_attachment()` | `atlassian_jira(resource="attachment", operation="upload")` |
| `jira_delete_attachment` | `delete_attachment()` | `atlassian_jira(resource="attachment", operation="delete")` |
| `jira_get_boards` | `get_boards()` | `atlassian_jira(resource="board", operation="list")` |
| `jira_get_estimation` | `get_estimation()` | `atlassian_jira(resource="estimation", operation="get")` |
| `jira_set_estimation` | `set_estimation()` | `atlassian_jira(resource="estimation", operation="set")` |

**Cobertura gateway**: 100% (+ 14 ops novas: transition, search.jql, comment.add, worklog.add, link.*, project.*, user.search, estimation.calculate)

### 1.4. Lista exata — Bitbucket (52 tools flat — pré-VKS-1853; 55 pós-VKS-1853)

Extraído de `servers/bitbucket/tools.py:2992-3050+`:

```text
Core: get_recent_builds, get_build_details, get_build_steps, get_step_logs
Analysis: analyze_failures, auto_diagnose, compare_builds, diagnose_pipeline_failure
Health: check_pipeline_health, check_alerts, get_executive_summary
Test Reports: get_test_reports, get_test_cases, get_test_case_reasons
Deployments: get_recent_deployments, get_deployment_details, get_environments,
             get_environment_variables, get_repository_variables, get_workspace_variables
Cache: list_caches, get_cache_details, clear_cache, analyze_cache_efficiency
Commits: get_commit_details, get_commit_build_statuses, get_builds_for_commit, compare_commit_builds
PRs: get_pull_requests, get_pr_details, get_pr_build_statuses, create_pull_request,
     get_pr_comments, merge_pull_request, approve_pull_request, unapprove_pull_request
Pipelines: list_pipeline_schedules, get_pipeline_config, get_ssh_key_info
Auto-Learning: save_successful_fix, search_learned_fixes, get_knowledge_base_stats
Control: trigger_pipeline, stop_pipeline
Branches: list_branches, get_branch, create_branch, delete_branch, set_default_branch,
          get_branch_restrictions, set_branch_restriction, delete_branch_restriction
```

**Cobertura gateway**: 100% — todas as 52 tools mapeadas via `gateways/bitbucket/actions.py:RESOURCE_MAP` em 11 resources (pipeline=16 ops, pull_request=8, branch=8, deployment=4, commit=4, test=3, cache=4, variable=2, learning=3).

> **Atualização pós-VKS-1853**: `pull_request` passou de **8 → 11 ops** com a adição de `add_pr_comment`, `reply_to_pr_comment` e `update_pr_description`. Bitbucket total: **52 → 55 tools flat**. Demais resources inalterados.

---

## 2. Consumers Externos Descobertos

### 2.1. Consumers ATIVOS (precisam migração)

| Arquivo | Linhas | Tool referenciada | Ação |
|---|---|---|---|
| `~/.claude/agents/ops-strategist.md` | 53, 64, 68 | `jira_get_issue`, `bitbucket_get_recent_builds`, `bitbucket_check_pipeline_health`, `bitbucket_get_pull_requests` | **MIGRAR** — atualizar para gateway |
| `multi-agent-os/plugin-scripts/governance/lib/json-rpc.sh` | 116-117 | (string descritiva) | **ATUALIZAR** texto para referenciar gateway |

### 2.2. Consumers HISTÓRICOS (read-only artifacts — NÃO migrar)

| Arquivo | Tipo | Decisão |
|---|---|---|
| `~/.claude/plans/hazy-scribbling-simon.md` | plano antigo | Ignorar — artefato histórico |
| `~/.claude/plans/do-leia-o-moonlit-lemur.md` | plano antigo | Ignorar |
| `vek-docs-trellis/.planning/osppe/34-convergence-10-meta-critique.md` | análise histórica | Ignorar |
| `~/.claude/plans/vamos-continuar-com-vks-1694-typed-peacock.md` | este plano | Self-reference, ok |

### 2.3. Consumers em infraestrutura executável

- **Tests**: ZERO referências em `tests/`, `test_*.py`
- **CI/Pipelines**: ZERO referências em `.yml`, `.yaml`
- **Python/JS/TS runtime**: ZERO
- **Shell executáveis**: ZERO (json-rpc.sh só exibe texto, não invoca)

**Risco de regressão em runtime**: **MUITO BAIXO** — apenas 1 agente prompt precisa atualização.

---

## 3. Classificação & Decisão

| Item | Classificação | Decisão |
|---|---|---|
| 52 Bitbucket flat tools | Safe to deprecate | Hide via flag → delete |
| 8 Jira flat tools | Safe to deprecate | Hide via flag → delete |
| `ops-strategist.md` | Needs migration | Atualizar refs para gateway (FASE 1) |
| `json-rpc.sh:116-117` | Nit (apenas texto) | Atualizar texto informativo (FASE 1) |
| Planos antigos + meta-critique | Ignore (histórico) | — |

---

## 4. Safety Assessment

| Critério | Status | Evidência |
|---|---|---|
| Gateway cobre 100% das flat-tools? | ✅ SIM | Bitbucket 52/52, Jira 8/8 |
| Handlers preservados? | ✅ SIM | Gateway importa `from servers.X.tools import TOOLS` |
| E2E validation rodou? | ✅ SIM | VKS-1718 — Done |
| Consumers runtime externos? | ✅ ZERO | Apenas 1 prompt + 1 texto descritivo |
| Feature flag possível? | ✅ SIM | `MAOS_EXPOSE_FLAT_TOOLS` (default=false) |
| Rollback rápido? | ✅ SIM | env var flip ou `git revert` |

**Veredicto final**: **SAFE TO DEPRECATE** via processo faseado (flag → validation → hard delete).

---

## 5. Recommended Next Steps (FASE 1+)

1. Abrir PR em `multi-agent-os` contendo:
   - `hub.py` — envolver loop flat em `if os.getenv("MAOS_EXPOSE_FLAT_TOOLS", "false").lower() == "true":`
   - `.env.example` — documentar variável
   - `README.md` — seção Migration guide + remover "Flat Namespace (Legacy)"
   - `~/.claude/agents/ops-strategist.md` — migrar 3 refs para gateway pattern
   - `plugin-scripts/governance/lib/json-rpc.sh:116-117` — atualizar strings descritivas
   - `CHANGELOG.md` — entrada `### Changed` (não `### Removed` ainda — isso é FASE 3)

2. Rodar `pytest tests/` + smoke test do hub.

3. Validation window (FASE 2): 1 dia observando.

4. FASE 3 hard-delete após validation.

---

## 6. Métricas Previstas

| Métrica | Antes | Depois (FASE 3) | Redução |
|---|---:|---:|---:|
| Total MCP tools registradas | 66 | 6 | -91% |
| Token footprint (schemas) | baseline | 1/10 | ~90% menor |
| Tools reais disponíveis | 66+6=72 | 6 meta × 99 ações = 6 tools → 99 ações acessíveis (pós-VKS-1853; era 96 no snapshot original) | mesma capacidade |

---

**Relatório gerado por**: Claude-Opus-4.7 | sessão typed-peacock | 2026-04-17
**Próximo passo**: Apresentar via AskUserQuestion e aguardar aprovação.
