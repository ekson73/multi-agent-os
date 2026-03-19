# AI-Native Environment Specification

> **Versão**: 1.0.0
> **Atualizado**: 2026-01-21
> **Status**: Aprovado
> **Propagado de**: `~/.claude/CLAUDE.md` [C06]

---

## Visão Geral

Este documento especifica o ambiente **AI-Native** utilizado em todos os projetos gerenciados por agentes Claude. O ambiente é otimizado para:

- **Automação**: Outputs estruturados para parsing programático
- **Continuidade**: Session-Driven Development com handoffs documentados
- **Rastreabilidade**: Audit trails e manifests para todas operações
- **Interoperabilidade**: Padrões MCP-JSON-RPC para comunicação

---

## Definições

### Claude-Native

Ambiente otimizado para agentes **Claude Code**:

| Característica | Descrição |
|----------------|-----------|
| **CLAUDE.md** | Arquivo de contexto em cada projeto |
| **Shards** | Documentação modular em `.claude/docs/` |
| **Session Reports** | Relatórios estruturados em `.claude/sessions/` |
| **Delegação Recursiva** | Agentes especializados via Task tool |

### AI-Native

Outputs e interfaces desenhados para consumo por agentes:

| Característica | Descrição |
|----------------|-----------|
| **JSON-RPC** | Formato padrão para outputs estruturados |
| **Exit Codes** | Semânticos (0=success, 1=error, 2=warning) |
| **stderr para Erros** | Erros em JSON-RPC para parsing |
| **Idempotência** | Operações re-executáveis sem side-effects |

### AI-Driven

Decisões e processos guiados por agentes AI:

| Característica | Descrição |
|----------------|-----------|
| **Documentação para AI** | Decisões em formato parseável |
| **Automation-First** | Preferência por automação sobre manual |
| **Feedback Loops** | Validação contínua e correção |
| **Learning** | Registro de lições aprendidas |

### SDD (Session-Driven Development)

Metodologia de desenvolvimento baseada em sessões:

| Característica | Descrição |
|----------------|-----------|
| **Session Start** | Leitura de contexto anterior |
| **Tracking** | TodoWrite para progresso |
| **Documentation** | Commits assinados, changelogs |
| **Handoff** | Session report estruturado |

---

## Padrão de Output para Scripts

### Formato JSON-RPC 2.0

```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "summary": {...},
    "data": {...}
  },
  "id": "<uuid>"
}
```

### Formato de Erro (MCP-JSON-RPC)

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32000,
    "message": "Sync failed with 1 error(s)",
    "data": {
      "errors_count": 1,
      "failed_files": [
        {"file": "path/to/file.md", "error": "Failed to update"}
      ]
    }
  },
  "id": "<uuid>"
}
```

### Códigos de Erro JSON-RPC

| Código | Significado |
|--------|-------------|
| -32700 | Parse error |
| -32600 | Invalid request |
| -32601 | Method not found |
| -32602 | Invalid params |
| -32603 | Internal error |
| -32000 to -32099 | Server errors (custom) |

### Códigos de Erro Customizados

| Código | Significado |
|--------|-------------|
| -32000 | Generic server error |
| -32001 | Authentication failed |
| -32002 | Rate limit exceeded |
| -32003 | Resource not found |
| -32004 | Permission denied |

---

## Flags Obrigatórias para Scripts

Todo script CLI DEVE implementar:

| Flag | Short | Descrição | Comportamento |
|------|-------|-----------|---------------|
| `--json` | `-j` | Output JSON-RPC | Suprime output humano |
| `--dry-run` | `-n` | Preview mode | Não executa mudanças |
| `--verbose` | `-v` | Verbose output | Mais detalhes |
| `--force` | `-f` | Force execution | Bypass gates |
| `--help` | `-h` | Show help | Documentação |

### Implementação Exemplo (Python)

```python
import argparse
import json
import sys
from uuid import uuid4

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument('--json', '-j', action='store_true',
                       help='Output JSON-RPC format')
    parser.add_argument('--dry-run', '-n', action='store_true',
                       help='Preview without changes')
    parser.add_argument('--verbose', '-v', action='store_true',
                       help='Verbose output')
    parser.add_argument('--force', '-f', action='store_true',
                       help='Force execution')
    return parser.parse_args()

def output_result(success, data, errors=None, args=None):
    """Output result in appropriate format"""
    if args and args.json:
        # JSON-RPC format
        response = {
            "jsonrpc": "2.0",
            "result": {"success": success, "data": data},
            "id": str(uuid4())
        }
        print(json.dumps(response, indent=2))
    else:
        # Human-readable format
        print(f"Success: {success}")
        print(f"Data: {data}")

    # Always output errors to stderr in JSON-RPC
    if errors and not success:
        error_response = {
            "jsonrpc": "2.0",
            "error": {
                "code": -32000,
                "message": f"Failed with {len(errors)} error(s)",
                "data": {"errors": errors}
            },
            "id": str(uuid4())
        }
        print(json.dumps(error_response), file=sys.stderr)

    return 0 if success else 1
```

---

## Session-Driven Development (SDD)

### Ciclo de Vida de uma Sessão

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    SESSION LIFECYCLE                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. INITIALIZE                                                          │
│     ├── Ler CLAUDE.md (global + local)                                  │
│     ├── Ler session reports anteriores                                  │
│     └── Verificar propagação de standards                               │
│                                                                         │
│  2. EXECUTE                                                             │
│     ├── Criar TodoWrite com tarefas                                     │
│     ├── Executar tarefas sequencialmente                                │
│     ├── Atualizar status conforme progresso                             │
│     └── Commitar mudanças com Co-Author                                 │
│                                                                         │
│  3. VALIDATE                                                            │
│     ├── Verificar se todas tarefas completadas                          │
│     ├── Executar testes/validações                                      │
│     └── Resolver pendências                                             │
│                                                                         │
│  4. HANDOFF                                                             │
│     ├── Gerar session report estruturado                                │
│     ├── Commitar session report                                         │
│     └── Documentar próximos passos                                      │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Session Report Format

Ver `~/.claude/CLAUDE.md` [C05] para formato completo.

Quick reference:
- **Local**: `.claude/sessions/{YYYY-MM-DD}_{SSID}_{TYPE}.md`
- **SSID**: 4 caracteres únicos do agente
- **TYPE**: catchup, completion, handoff, incident, decision

### Handoff Protocol

Ao encerrar sessão:

1. **Atualizar TodoWrite** - Marcar todas tarefas como completed ou documentar pendências
2. **Criar Session Report** - Com 10 seções obrigatórias
3. **Commitar** - Session report vai para `.claude/sessions/`
4. **Próximos Passos** - Documentar claramente a próxima ação lógica

---

## Propagação para Repositórios

### Trigger de Propagação

O agente DEVE verificar propagação quando:
- Inicia sessão em novo repositório
- Detecta versão desatualizada no repo local
- Primeira escrita no repo

### Checklist de Verificação

```markdown
## AI-Native Propagation Checklist

- [ ] `.claude/docs/ai-native-environment.md` existe
- [ ] Versão >= 1.0.0
- [ ] `CLAUDE.md` tem seção "AI-Native Environment"
- [ ] Scripts seguem padrão JSON-RPC (--json flag)
- [ ] `.claude/sessions/` existe
```

### Comando de Verificação

```bash
# Verificar se repo está AI-Native compliant
ls -la .claude/docs/ai-native-environment.md 2>/dev/null || echo "MISSING: ai-native-environment.md"
grep -q "AI-Native Environment" CLAUDE.md 2>/dev/null || echo "MISSING: AI-Native section in CLAUDE.md"
ls -d .claude/sessions 2>/dev/null || echo "MISSING: .claude/sessions/"
```

---

## Audit Trail

### Manifest Files

Todo script que modifica estado DEVE gerar manifest:

```json
{
  "operation_id": "<uuid>",
  "timestamp": "<ISO-8601>",
  "script": "sync-to-confluence.py",
  "version": "1.3.0",
  "git_commit": "abc1234",
  "operations": [
    {"file": "...", "action": "CREATE", "result": "success"},
    {"file": "...", "action": "UPDATE", "result": "success"}
  ],
  "summary": {
    "success": 10,
    "errors": 0
  }
}
```

### Localização de Manifests

| Tipo | Localização |
|------|-------------|
| Confluence sync | `00_metadata/audit/confluence_sync_*.json` |
| NotebookLM sync | `00_metadata/audit/notebooklm_sync_*.json` |
| GDrive sync | `00_metadata/audit/gdrive_sync_*.json` |

---

## Versioning

| Versão | Data | Mudanças |
|--------|------|----------|
| 1.0.0 | 2026-01-21 | Versão inicial |

---

*Propagado automaticamente | v1.0.0*
