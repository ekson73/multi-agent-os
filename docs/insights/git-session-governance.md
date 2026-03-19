# Insights de Sessoes - Acme Solution

> **Versao**: 1.0.0
> **Data**: 2026-01-22
> **Proposito**: Documentar aprendizados para sessoes futuras

---

## Insight 1: Drifts de Working Directory Persistem Entre Checkouts

### Problema
Ao fazer `git checkout` entre branches, mudancas **unstaged** (nao adicionadas com `git add`) persistem no working directory. Isso causa:
- Estado inconsistente entre branches
- Confusao sobre qual conteudo pertence a qual branch
- Auditorias com resultados incorretos

### Evidencia
```bash
# Situacao encontrada
$ git checkout main
# Arquivo RELATORIO_MIGRACAO.md aparece como "deleted" mesmo no main
# Porque a delecao foi feita antes do checkout e nao foi staged
```

### Solucao
**ANTES de fazer checkout:**
```bash
git stash          # Guarda mudancas locais
# ou
git checkout -- .  # Descarta mudancas locais
# ou
git add . && git commit  # Commita mudancas
```

### Regra
```
┌────────────────────────────────────────────────────────────────────────┐
│  REGRA: Verificar `git status` ANTES e DEPOIS de checkout             │
│  ACAO: Working directory DEVE estar limpo antes de trocar de branch   │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Insight 2: Sessoes Podem Criar Artefatos Sem Session Report

### Problema
Commits podem criar artefatos (documentos, codigo) sem um session report associado. Quando outra sessao faz auditoria, pode:
- Atribuir credito incorreto (para sessao errada)
- Inflar/deflar status de sessoes
- Perder rastreabilidade de quem fez o que

### Evidencia
- Sessao `ed22` criou catalogos (commits 6ae6ea0, 2040e27)
- Auditoria atribuiu esses artefatos a sessao `reng`
- Status de `reng` foi inflado de 60% para 85% incorretamente

### Solucao
**Verificar ANTES de atribuir progresso:**
```bash
# Quem criou este arquivo?
git log --oneline -- docs/07_database/legado/CATALOGO_DDL.md

# Qual sessao estava ativa nesse commit?
# Verificar timestamp do commit vs timestamps dos session reports
```

### Regra
```
┌────────────────────────────────────────────────────────────────────────┐
│  REGRA: Rastrear artefatos via `git log` antes de atribuir credito    │
│  ACAO: Vincular commits a session reports pelo timestamp              │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Insight 3: Session Reports Podem Nao Ser Descobertos

### Problema
Session reports existentes podem nao ser descobertos em auditorias se:
- Estao em branches nao merged
- Foram criados apos o ultimo `git pull`
- Estao com nomenclatura diferente do esperado

### Evidencia
- Sessao `ed22` nao foi incluida na auditoria inicial
- Apenas `svgm` e `reng` foram analisados
- `ed22` e a sessao que realmente fez o trabalho dos catalogos

### Solucao
**Listar TODAS as sessoes antes de auditar:**
```bash
# Todas as sessoes locais
ls -la .claude/sessions/*.md

# Todas as sessoes em todas as branches
git ls-tree -r --name-only HEAD .claude/sessions/
git ls-tree -r --name-only origin/main .claude/sessions/
```

### Regra
```
┌────────────────────────────────────────────────────────────────────────┐
│  REGRA: Fazer inventario COMPLETO de sessoes antes de auditar         │
│  ACAO: Verificar .claude/sessions/ em TODAS as branches               │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Insight 4: Interdependencias Reais vs Declaradas

### Problema
Session reports podem declarar dependencias que nao existem ou omitir dependencias reais. O fluxo real de execucao pode ser diferente do documentado.

### Evidencia
- `reng` documentou tarefas que foram feitas por `ed22`
- A sessao `ed22` e continuacao logica de `reng`
- Mas isso nao estava documentado em nenhum lugar

### Solucao
**Criar grafo de dependencias:**
```markdown
## Grafo de Sessoes
svgm (migracao)
  └── reng (estrutura inicial docs)
        └── ed22 (catalogos e ER)
              └── [proxima sessao]
```

### Regra
```
┌────────────────────────────────────────────────────────────────────────┐
│  REGRA: Documentar sessao-pai no header do session report             │
│  FORMATO: > **Parent Session**: {SSID} ou "none" se raiz              │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Insight 5: 100% Completo Requer Auditoria

### Problema
Sessoes auto-declaradas como 100% frequentemente tem:
- Claims nao verificados
- Mudancas nao commitadas
- Artefatos faltando

### Evidencia
- `svgm` declarou 100%, auditoria encontrou 98%
- `reng` declarou 60%, foi corrigido para 85% (erro oposto)
- `ed22` declara 100%, ainda nao auditado

### Solucao
**Nenhuma sessao e 100% ate ser auditada:**
```
STATUS PERMITIDOS (auto-declarado):
- pending (0-25%)
- in_progress (25-75%)
- review_pending (75-99%)
- [NAO PERMITIDO] 100% complete

STATUS APOS AUDITORIA:
- verified_complete (100%)
- verified_partial (N%)
```

### Regra
```
┌────────────────────────────────────────────────────────────────────────┐
│  REGRA: Status "100% SUCESSO" requer auditoria externa                │
│  ACAO: Usar "REVIEW_PENDING" ate ser auditado                         │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Matriz de Erros Comuns

| Erro | Sintoma | Causa | Prevencao |
|------|---------|-------|-----------|
| Drift WD | Arquivo aparece em branch errada | Checkout sem limpar | `git status` antes/depois |
| Credito errado | Status inflado/deflado | Nao rastrear origem | `git log` por arquivo |
| Sessao invisivel | Auditoria incompleta | Nao listar todas | Inventario completo |
| Dependencia oculta | Fluxo confuso | Nao documentar pai | Campo "Parent Session" |
| 100% falso | Auditoria falha | Auto-declaracao | Proibir 100% sem auditoria |

---

## Aplicacao

Estes insights DEVEM ser:
1. Propagados para `~/.claude/CLAUDE.md` como regras globais
2. Verificados em toda auditoria futura
3. Usados como checklist pre-commit

---

*Documentado: Claude-Code | 2026-01-22T10:00:00-03:00*
