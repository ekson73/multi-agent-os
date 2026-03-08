# Context Analysis Before Commit [R01]

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-01-25 -->
<!-- Source: insight_context_analysis_before_commit.md -->

## Regra Obrigatória

```
┌────────────────────────────────────────────────────────────────────────┐
│  ANTES DE COMMITAR: Analisar CONTEÚDO → Determinar CONTEXTO → LOCAL   │
├────────────────────────────────────────────────────────────────────────┤
│  ERRADO: "Onde tem git funcional?" → Commitar                          │
│  CERTO:  "Onde o arquivo PERTENCE?" → Garantir git → Commitar          │
└────────────────────────────────────────────────────────────────────────┘
```

## Indicadores de Escopo

| Escopo | Indicadores | Destino |
|--------|-------------|---------|
| **GLOBAL** | Refs a `~/.claude/`, padrões multi-projeto, Skills/Rules genéricos | `~/.claude/` |
| **PROJETO** | Refs a paths relativos, dados de domínio, configs específicas | `./` (projeto) |

## Checklist Pré-Commit

Antes de `git add` em qualquer arquivo novo:

1. [ ] Li o conteúdo do arquivo?
2. [ ] Identifiquei referências internas (paths, imports)?
3. [ ] Determinei escopo: GLOBAL ou PROJETO?
4. [ ] Local escolhido é coerente com escopo?
5. [ ] Nome segue taxonomia (snake_case, semver, semântica)?

## Anti-Pattern

```
# ERRADO (conveniência operacional)
~/Projects/arquivo.md → "VKS tem git" → commit em VKS

# CERTO (análise de contexto)
~/Projects/arquivo.md → "Conteúdo refs ~/.claude/" → GLOBAL → commit em ~/.claude/
```

---
*Origem: Sessão ef47 (2026-01-25) | Erro corrigido: commit 889f0ab*
