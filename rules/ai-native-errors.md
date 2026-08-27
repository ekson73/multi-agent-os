---
description: Protocolo de erros AI-native [C06] — JSON-RPC em stderr, exit codes 0/1/2
---

# AI-Native Error Protocol [C06]

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-01-22 -->
<!-- Full spec: ~/.claude/docs/mcp-jsonrpc-errors.md -->

## MCP-JSON-RPC Error Protocol

```
┌────────────────────────────────────────────────────────────────────────┐
│  ORDEM OBRIGATÓRIA: JSON error PRIMEIRO (stderr), human DEPOIS         │
│  CAMPO CRÍTICO: data.instructions → comando acionável para recovery   │
└────────────────────────────────────────────────────────────────────────┘
```

### Error Codes

| Código | Nome | Recovery |
|--------|------|----------|
| -32001 | Requires interaction | Adicionar `-y` flag |
| -32002 | Branch gate | `git checkout main` ou `--force` |
| -32003 | External dependency | Informar usuário |
| -32602 | Invalid params | Executar `--init` |

### Recovery Flow (AI Agent)

```
1. Agent executa: ./script.sh --cleanup
2. Script detecta não-interativo (no TTY)
3. Script output stderr: {"error":{"code":-32001,"data":{"instructions":"..."}}}
4. Agent parseia stderr, extrai instructions
5. Agent executa comando de instructions
6. Sucesso
```

### Implementation (Bash)

```bash
# JSON error SEMPRE primeiro
json_error -32001 "Requires interaction" "details" "Run: ./script.sh -y" "context"

# Human depois (se não --json)
if [ "$JSON_OUTPUT" != true ]; then
    log_error "Use -y flag"
fi
exit 1
```
