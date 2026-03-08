# Error Codes Registry

<!-- ═══════════════════════════════════════════════════════════════════════════
     REGISTRY: MCP-JSON-RPC Error Codes Centralizados

     Localização: ~/.claude/docs/error-codes-registry.md
     Escopo: Todos os scripts e skills do ambiente Claude
     Versão: 1.0.0
     Criado: 2026-01-23
     Autor: Claude-Code

     PROPÓSITO: Centralizar TODOS os error codes para evitar conflitos e
     garantir consistência na comunicação de erros entre agentes e scripts.
     ═══════════════════════════════════════════════════════════════════════════ -->

---

## Visão Geral

Este registry centraliza todos os error codes MCP-JSON-RPC utilizados no ambiente Claude. Seguir este registry evita conflitos de códigos e garante comportamento consistente de recovery entre agentes.

### Formato Padrão de Erro

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": <error_code>,
    "message": "<human_readable_message>",
    "data": {
      "details": "<additional_context>",
      "instructions": "<actionable_recovery_command>",
      "context": "<error_category>"
    }
  },
  "id": "<request_id>"
}
```

---

## Ranges Reservados

| Range | Owner | Propósito |
|-------|-------|-----------|
| `-32000` a `-32009` | **Core MCP** | Erros fundamentais do protocolo |
| `-32010` a `-32019` | **sync-to-git** | Sincronização Git/GitHub/Bitbucket |
| `-32020` a `-32029` | **sync-orchestrator** | Orquestração de sync operations |
| `-32030` a `-32039` | **sync-to-notebooklm** | Sincronização NotebookLM |
| `-32040` a `-32049` | **worktree-protocol** | Git Worktree operations |
| `-32050` a `-32059` | **session-management** | Sessões e locks |
| `-32060` a `-32099` | **Reservado** | Futuros core skills |
| `-32100` a `-32199` | **Project Skills** | Skills específicos de projeto |
| `-32200` a `-32299` | **User Skills** | Skills customizados do usuário |
| `-32600` a `-32699` | **JSON-RPC Standard** | Erros padrão JSON-RPC 2.0 |

---

## Core MCP (-32000 a -32009)

| Code | Nome | Descrição | Recovery |
|------|------|-----------|----------|
| `-32000` | `server_error` | Erro interno do servidor | Retry ou escalar |
| `-32001` | `requires_interaction` | Requer confirmação interativa | Adicionar `-y` flag |
| `-32002` | `branch_gate` | Operação bloqueada por gate de branch | `git checkout main` ou `--force` |
| `-32003` | `external_dependency` | Dependência externa indisponível | Informar usuário |
| `-32004` | `permission_denied` | Permissão negada para operação | Verificar credenciais |
| `-32005` | `resource_locked` | Recurso bloqueado por outro agente | Aguardar ou forçar release |
| `-32006` | `timeout` | Operação excedeu tempo limite | Retry com timeout maior |
| `-32007` | `state_conflict` | Estado inconsistente detectado | Sincronizar estado |
| `-32008` | `validation_failed` | Validação de dados falhou | Corrigir input |
| `-32009` | `operation_cancelled` | Operação cancelada pelo usuário | N/A |

---

## sync-to-git (-32010 a -32019)

| Code | Nome | Descrição | Recovery |
|------|------|-----------|----------|
| `-32010` | `git_not_initialized` | Diretório não é repositório Git | `git init` |
| `-32011` | `remote_not_configured` | Remote não configurado | `git remote add origin <url>` |
| `-32012` | `push_rejected` | Push rejeitado pelo remote | `git pull --rebase && git push` |
| `-32013` | `merge_conflict` | Conflito de merge detectado | Resolver conflitos manualmente |
| `-32014` | `branch_not_found` | Branch não existe | `git checkout -b <branch>` |
| `-32015` | `uncommitted_changes` | Alterações não commitadas | `git stash` ou `git commit` |
| `-32016` | `auth_required` | Autenticação necessária | Configurar credenciais |
| `-32017` | `hook_failed` | Git hook falhou | Verificar hook ou `--no-verify` |
| `-32018` | `lfs_error` | Erro em operação Git LFS | `git lfs install` |
| `-32019` | `submodule_error` | Erro em submodule | `git submodule update --init` |

---

## sync-orchestrator (-32020 a -32029)

| Code | Nome | Descrição | Recovery |
|------|------|-----------|----------|
| `-32020` | `orchestration_failed` | Orquestração falhou | Verificar dependências |
| `-32021` | `dependency_cycle` | Ciclo de dependência detectado | Corrigir configuração |
| `-32022` | `target_unavailable` | Target de sync indisponível | Verificar conectividade |
| `-32023` | `manifest_invalid` | Manifest de sync inválido | Regenerar manifest |
| `-32024` | `partial_sync` | Sync parcial (alguns targets falharam) | Retry targets específicos |
| `-32025` | `rate_limited` | Rate limit atingido | Aguardar e retry |
| `-32026` | `quota_exceeded` | Quota excedida | Aumentar quota ou limpar |
| `-32027` | `config_missing` | Configuração ausente | Criar config file |
| `-32028` | `version_mismatch` | Versão incompatível | Atualizar skill |
| `-32029` | `reserved` | Reservado | - |

---

## sync-to-notebooklm (-32030 a -32039)

| Code | Nome | Descrição | Recovery |
|------|------|-----------|----------|
| `-32030` | `notebooklm_auth_failed` | Autenticação NotebookLM falhou | Re-autenticar |
| `-32031` | `notebook_not_found` | Notebook não encontrado | Criar ou verificar ID |
| `-32032` | `source_limit_exceeded` | Limite de sources excedido | Remover sources antigas |
| `-32033` | `format_unsupported` | Formato de arquivo não suportado | Converter formato |
| `-32034` | `upload_failed` | Upload falhou | Retry |
| `-32035` | `api_error` | Erro na API NotebookLM | Verificar status API |
| `-32036` to `-32039` | `reserved` | Reservado | - |

---

## worktree-protocol (-32040 a -32049)

| Code | Nome | Descrição | Recovery |
|------|------|-----------|----------|
| `-32040` | `worktree_exists` | Worktree já existe | Usar existente ou remover |
| `-32041` | `worktree_not_found` | Worktree não encontrado | Criar worktree |
| `-32042` | `checkout_blocked` | Checkout bloqueado (REGRA 7) | Usar worktree |
| `-32043` | `branch_in_use` | Branch em uso por outro worktree | Escolher outra branch |
| `-32044` | `merge_blocked` | Merge hierárquico violado | Merge para branch pai |
| `-32045` | `session_conflict` | Conflito de sessão | Verificar sessions.json |
| `-32046` | `lock_held` | Lock ativo por outro agente | Aguardar ou forçar |
| `-32047` | `cleanup_failed` | Falha ao limpar worktree | Remover manualmente |
| `-32048` to `-32049` | `reserved` | Reservado | - |

---

## session-management (-32050 a -32059)

| Code | Nome | Descrição | Recovery |
|------|------|-----------|----------|
| `-32050` | `session_not_found` | Sessão não encontrada | Criar nova sessão |
| `-32051` | `session_expired` | Sessão expirada | Criar nova sessão |
| `-32052` | `session_locked` | Sessão bloqueada | Aguardar ou forçar |
| `-32053` | `heartbeat_stale` | Heartbeat stale detectado | Atualizar ou assumir |
| `-32054` | `registry_corrupt` | sessions.json corrompido | Reconstruir registry |
| `-32055` | `transition_failed` | Transição de estado falhou | Verificar guardrails |
| `-32056` to `-32059` | `reserved` | Reservado | - |

---

## JSON-RPC Standard (-32600 a -32699)

| Code | Nome | Descrição | Recovery |
|------|------|-----------|----------|
| `-32600` | `invalid_request` | Request JSON inválido | Corrigir formato |
| `-32601` | `method_not_found` | Método não existe | Verificar nome do método |
| `-32602` | `invalid_params` | Parâmetros inválidos | Verificar params ou `--init` |
| `-32603` | `internal_error` | Erro interno | Retry ou escalar |
| `-32700` | `parse_error` | Erro de parse JSON | Corrigir JSON |

---

## Como Registrar Novo Error Code

### 1. Identificar Range Apropriado

- Core functionality → `-32000` a `-32009`
- Sync skills → `-3201X` a `-3203X`
- Worktree/Session → `-3204X` a `-3205X`
- Project-specific → `-321XX`
- User custom → `-322XX`

### 2. Verificar Disponibilidade

```bash
grep -n "<code>" ~/.claude/docs/error-codes-registry.md
```

### 3. Adicionar ao Registry

Adicionar na seção apropriada com:
- Code
- Nome (snake_case)
- Descrição
- Recovery action

### 4. Atualizar Changelog

Adicionar entrada no Master Changelog deste arquivo.

---

## Implementação em Scripts

### Bash

```bash
# Função para emitir erro JSON-RPC
json_error() {
    local code="$1"
    local message="$2"
    local details="${3:-}"
    local instructions="${4:-}"
    local context="${5:-}"

    cat >&2 << EOF
{"jsonrpc":"2.0","error":{"code":${code},"message":"${message}","data":{"details":"${details}","instructions":"${instructions}","context":"${context}"}},"id":"$(uuidgen 2>/dev/null || date +%s)"}
EOF
}

# Uso
json_error -32002 "Branch checkout blocked" "Attempted checkout in main repo" "Use worktree" "git-worktree"
```

### Python

```python
import json
import sys
import uuid

def json_error(code: int, message: str, details: str = "", instructions: str = "", context: str = ""):
    error = {
        "jsonrpc": "2.0",
        "error": {
            "code": code,
            "message": message,
            "data": {
                "details": details,
                "instructions": instructions,
                "context": context
            }
        },
        "id": str(uuid.uuid4())
    }
    print(json.dumps(error), file=sys.stderr)

# Uso
json_error(-32002, "Branch checkout blocked", "Attempted checkout", "Use worktree", "git-worktree")
```

---

## Referências

- [JSON-RPC 2.0 Specification](https://www.jsonrpc.org/specification)
- [MCP-JSON-RPC Error Protocol](~/.claude/docs/mcp-jsonrpc-errors.md)
- [AI-Native Error Protocol](~/.claude/rules/ai-native-errors.md)

---

## Master Changelog

| Versão | Data | Autor | Descrição |
|--------|------|-------|-----------|
| 1.0.0 | 2026-01-23 | Claude-Code | Versão inicial - consolidação de error codes |

---

*Versão: 1.0.0 | Atualizado: 2026-01-23 | Autor: Claude-Code*
