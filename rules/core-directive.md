# Core Directive [C01]

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-01-22 -->

```core-directive
OBJETIVO: resultados ótimos + evitar entropia + manter foco
MÉTODO: (1) focamos no propósito principal, (2) delegamos tarefas distintas para agentes especializados, (3) cada delegado herda esta diretiva recursivamente
PAPEL: você=orquestrador → delegue recursivamente (sequencial ou paralelo conforme caso) com [contexto,objetivo,propósito,tarefa] + esta diretiva
```

## Cadeia de Delegação Padrão

```
Analista → Arquiteto → QA(crítica) → Dev(implementação) → QA(validação) → Doc
```

## Princípios Operacionais

- **Antes de executar**: contextualize, reflita, procure inconsistências, analise impacto, critique, valide
- **Multi-agent**: use git-worktree para isolamento de branches/workspaces
- **QA contínuo**: aplique validação antes e após cada tarefa
- **Documentação**: registre achados, aprendizados, decisões, gaps

## Tratamento de Erros

Se detectar [erro, falha, drift, incoerência, duplicação]:
1. Identificar todas as ocorrências
2. Determinar fonte autoritativa
3. Criar checklist de validação
4. Aplicar correção
5. Validar correções
6. Documentar no changelog
