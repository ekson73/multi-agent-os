# Naming Conventions & Taxonomy

> **Versão**: 1.0.0 (2026-01-22)
> **Status**: Aprovado
> **Propagado de**: `~/.claude/CLAUDE.md` [C09]

---

## Propósito

Padronizar nomenclatura de diretórios, arquivos e artefatos para facilitar navegação, busca e manutenção.

---

## Princípios

1. **Taxonomia**: Classificação hierárquica por domínio
2. **Semântica**: Nomes descrevem propósito, não implementação
3. **Contexto**: Local determina convenção aplicável
4. **Semver**: Versões onde aplicável

---

## Padrão de Diretórios

```
{NN}_{categoria}/
```

| Componente | Descrição | Exemplo |
|------------|-----------|---------|
| `NN` | Número de ordem (00-99) | `00`, `07`, `99` |
| `categoria` | Nome em snake_case | `index`, `database`, `legacy` |

**Exemplo**: `00_index/`, `07_database/`, `99_legacy/`

---

## Padrão de Arquivos

| Tipo | Padrão | Exemplo |
|------|--------|---------|
| Documentação | `{NOME_DESCRITIVO}.md` | `CATALOGO_DDL.md` |
| Configuração | `{nome}.{ext}` | `settings.json` |
| Session Report | `{YYYY-MM-DD}_{SSID}_{TYPE}.md` | `2026-01-21_ed22_completion.md` |
| Template | `TEMPLATE_{TIPO}.md` | `TEMPLATE_PRD.md` |
| Insight | `INSIGHTS_{ESCOPO}.md` | `INSIGHTS_SESSOES.md` |
| Checklist | `CHECKLIST_{CONTEXTO}_{DATA}.md` | `CHECKLIST_VALIDACAO_2026-01-22.md` |

---

## Short-name Taxonômico

Para branches, commits e identificadores curtos:

```
{tipo}/{escopo}+{categoria}/{detalhe}
```

| Componente | Valores | Exemplo |
|------------|---------|---------|
| `tipo` | fix, feat, chore, docs, refactor | `docs/` |
| `escopo` | Feature/problema principal | `session-audit` |
| `categoria` | Classificação | `+validation/` |
| `detalhe` | Especificação | `protocol-c02` |

**Exemplo**: `docs/session-audit+validation/protocol-c02`

---

## Checklist de Validação

Antes de criar arquivo/diretório:

1. ✅ Nome segue padrão da categoria?
2. ✅ Localização coerente com escopo?
3. ✅ Não duplica artefato existente?
4. ✅ Versionado se aplicável?

---

*Propagado automaticamente | v1.0.0*
