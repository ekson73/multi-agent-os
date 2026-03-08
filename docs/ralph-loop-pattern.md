# Ralph Loop Pattern

> **Versão**: 1.0.0 (2026-01-20)
> **Status**: Aprovado
> **Propagado de**: `~/.claude/CLAUDE.md` [C03]

---

## Propósito

Para tarefas de longa duração ou que requerem múltiplas iterações, use o padrão **Ralph Loop**.

---

## Estrutura do Loop

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Ralph Loop                                                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐       │
│   │ ANALYZE  │────►│ EXECUTE  │────►│ VALIDATE │────►│ DECIDE   │       │
│   └──────────┘     └──────────┘     └──────────┘     └──────────┘       │
│        ▲                                                  │             │
│        │                    ┌─────────────────────────────┘             │
│        │                    ▼                                           │
│        │           ┌────────────────┐                                   │
│        │           │ EXIT_CONDITION │                                   │
│        │           │     MET?       │                                   │
│        │           └───────┬────────┘                                   │
│        │                   │                                            │
│        │         NO        │        YES                                 │
│        └───────────────────┴──────────────► EXIT                        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Uso

```markdown
## Ralph Loop: [Nome da Tarefa]

**Objetivo**: [O que queremos alcançar]
**Max Iterações**: [número] (default: 10)
**Condição de Saída**: [critério mensurável]

### Parâmetros
- `max_iterations`: Limite de ciclos (prevenir loops infinitos)
- `exit_condition`: Critério de sucesso (ex: "score >= 90%", "zero_errors")
- `checkpoint_interval`: A cada N iterações, salvar estado

### Exemplo
Objetivo: "Corrigir todos os erros de formatação nos documentos T3"
Max Iterações: 10
Condição de Saída: "zero_errors AND qa_approved"
```

---

## Fallback Strategy

Se o loop falhar, atingir timeout ou max_iterations:

1. **Salvar estado**: checkpoint com progresso atual
2. **Documentar**: registrar o que foi feito e o que falta
3. **Notificar**: sinalizar interrupção ao humano
4. **Planejar**: criar tasks para continuação

---

## Retry Strategy

```
max_retries: 3
backoff: exponential (1s, 2s, 4s)
on_final_failure: escalate_to_human
```

---

*Propagado automaticamente | v1.0.0*
