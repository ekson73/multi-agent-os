# Glossário de Termos Globais

> **Versão**: 1.0.0 (2026-01-22)
> **Status**: Aprovado
> **Propagado de**: `~/.claude/CLAUDE.md`

---

## Tiers de Documentação (T0-T4)

| Tier | Nome | Definição | Permissão |
|------|------|-----------|-----------|
| **T0** | Raw Sources | Fontes externas brutas (APIs, dumps, exports) | Read-only |
| **T1** | Incoming | Documentos fonte recebidos | Read-only |
| **T2** | Internal | Documentos processados para uso interno | Read-write |
| **T3** | Outgoing | Documentos para distribuição a stakeholders | Read-write |
| **T4** | Deliverables | Entregáveis finais aprovados | Append-only |

---

## Fluxo de Dados

```
T0 (Raw) → T1 (Incoming) → T2 (Internal) → T3 (Outgoing) → T4 (Deliverables)
   │            │               │               │               │
   └── dump ────┴── ingest ─────┴── process ────┴── review ─────┴── approve
```

---

## Papéis Padrão

| Sigla | Papel | Responsabilidade |
|-------|-------|------------------|
| **BA** | Business Analyst | Requisitos, gaps, regras de negócio |
| **SA** | Solution Architect | Arquitetura, viabilidade técnica |
| **QA** | Quality Assurance | Validação, testes, consistência |
| **Dev** | Developer | Implementação, correções |
| **PM** | Project Manager | Coordenação, escopo, prazos |
| **Doc** | Documentation | Registros, changelogs, guias |

---

## Matriz RACI Padrão

| Atividade | Orquestrador | Analista | Arquiteto | QA | Dev | Humano |
|-----------|:------------:|:--------:|:---------:|:--:|:---:|:------:|
| Delegação de tasks | **R** | I | I | I | I | A |
| Análise de requisitos | C | **R** | C | I | I | A |
| Validação técnica | I | C | **R** | C | C | A |
| QA/Revisão | I | I | C | **R** | I | A |
| Implementação | I | I | C | C | **R** | A |
| Decisões de escopo | C | C | C | C | C | **R/A** |

**Legenda**: R=Responsável, A=Aprova, C=Consultado, I=Informado

---

## Estrutura de Projetos Recomendada

```
projeto/
├── CLAUDE.md              # Contexto específico do projeto
├── README.md              # Documentação do projeto
├── .claude/
│   ├── docs/              # Shards de documentação detalhada
│   └── commands/          # Comandos customizados do projeto
├── .worktrees/            # Git worktrees para multi-agent (ver C04)
│   ├── sessions.json      # Registro de sessões
│   ├── tasks.md           # Log de tarefas
│   └── {agent}-{feature}/ # Worktrees ativos
├── src/                   # Código fonte (se aplicável)
├── docs/                  # Documentação adicional
└── archive/               # Arquivos históricos/deprecated
```

---

*Propagado automaticamente | v1.0.0*
