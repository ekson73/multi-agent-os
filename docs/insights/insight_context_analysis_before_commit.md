# Insight: Análise de Contexto ANTES de Commit

> **Data**: 2026-01-25
> **Categoria**: #git #session #docs
> **Sessão**: ef47

---

## Problema

Arquivo foi commitado em localização incorreta porque a decisão de "onde commitar" foi baseada em **conveniência operacional** (repo com git funcional) em vez de **análise de conteúdo** (contexto semântico do arquivo).

## Evidência

| Ação | Resultado |
|------|-----------|
| Arquivo `prompt-aux-1.md` criado em `~/Projects/` | Sem git tracking |
| Procurei repo com git funcional | VKS disponível |
| Commitei em VKS `07_prompts/` | Commit `889f0ab` |
| Analisei conteúdo posteriormente | Arquivo é GLOBAL (refs a `~/.claude/`) |
| **Erro detectado** | Arquivo em local incorreto |

## Solução

1. Analisar **CONTEÚDO** do arquivo ANTES de decidir localização
2. Identificar referências internas (paths, imports, contexto)
3. Determinar escopo: GLOBAL (`~/.claude/`) vs PROJETO (`./`)
4. Só então escolher onde commitar

## Regra

```
┌────────────────────────────────────────────────────────────────────────┐
│  REGRA: ANALISAR CONTEÚDO → DETERMINAR CONTEXTO → ESCOLHER LOCAL       │
│                                                                        │
│  ERRADO: "Onde tem git?" → Commitar                                    │
│  CERTO:  "Onde pertence?" → Garantir git → Commitar                    │
│                                                                        │
│  Indicadores de escopo GLOBAL:                                         │
│  - Referências a ~/.claude/                                            │
│  - Padrões aplicáveis a múltiplos projetos                             │
│  - Skills, Rules, Specs genéricos                                      │
│                                                                        │
│  Indicadores de escopo PROJETO:                                        │
│  - Referências a paths relativos do projeto                            │
│  - Dados específicos do domínio                                        │
│  - Configurações project-specific                                      │
└────────────────────────────────────────────────────────────────────────┘
```

## Checklist de Compliance (Nomenclatura)

Antes de criar/mover arquivo:

- [ ] Nome segue snake_case?
- [ ] Versão incluída se aplicável (_vN)?
- [ ] Semântica clara (descreve propósito)?
- [ ] Localização coerente com escopo?
- [ ] Não duplica artefato existente?

## Exemplo Corretivo

| Antes | Depois |
|-------|--------|
| `VKS/07_prompts/prompt-aux-1.md` | `~/.claude/docs/prompts/prompt_sync_harmonization_v5.md` |
| Commit `889f0ab` (VKS) | Commit `fc51347` (~/.claude) + `c81135e` (remove VKS) |

---

*Criado por: Claude-Code | 2026-01-25T11:20:00-03:00*
