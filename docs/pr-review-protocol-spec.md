# PR Review Protocol — Especificação Completa

<!-- ═══════════════════════════════════════════════════════════════════════════
     PROTOCOLO GLOBAL: PR Review para AI Agents

     Localização: ~/.claude/docs/pr-review-protocol-spec.md
     Escopo: Todos os repositórios do usuário
     Versão: 2.0.0
     Criado: 2026-01-22
     Autor: Claude-Code

     SOURCE OF TRUTH: Este documento é a versão global detalhada.
     Rule compacta: ~/.claude/rules/pr-review-protocol.md
     ═══════════════════════════════════════════════════════════════════════════ -->

---

## 1. Visão Geral

### 1.1 Propósito

Este protocolo define o workflow obrigatório para todos os agentes AI ao modificar código em repositórios. O objetivo é garantir:

1. **Isolamento**: Mudanças sempre em branches sandbox (via worktree)
2. **Rastreabilidade**: Todas as mudanças via Pull Request
3. **Revisão obrigatória**: Nenhum merge sem revisão (bot, humano ou IA)
4. **Análise crítica**: Agente analisa e decide sobre feedback
5. **Continuidade**: TTL e delegação garantem fluxo não-bloqueante

### 1.2 Escopo

| Aplica-se a | Não aplica-se a |
|-------------|-----------------|
| Modificações de código | Operações read-only |
| Modificações de documentação | Arquivos append-only (tasks.md, sessions.json) |
| Criação de novos arquivos | Bypass explícito do usuário |
| Refatorações | |
| Bug fixes | |

### 1.3 Integração com Outros Protocolos

```
┌─────────────────────────────────────────────────────────────────────────┐
│  HIERARQUIA DE PROTOCOLOS                                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  C01: Core Directive                                                    │
│    └── C02: Main Instructions                                           │
│          └── C04: Git Worktree Protocol   ←─┐                           │
│                └── C07: PR Review Protocol ──┘ (este documento)         │
│                      └── C06: MCP-JSON-RPC Errors                       │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Workflow Detalhado

### 2.1 Fase 1: Preparação (Worktree)

**Pré-condição**: Tarefa requer modificação de arquivos.

**Ação**:
```bash
# 1. Verificar estado do repo
git status
git fetch origin

# 2. Determinar branch pai
#    - Se em main → pai = main
#    - Se em feature branch → pai = feature branch

# 3. Criar worktree
git worktree add .worktrees/{session-id}-{feature} -b {tipo}/{feature}

# 4. Entrar no worktree
cd .worktrees/{session-id}-{feature}

# 5. Registrar sessão
# (atualizar sessions.json conforme C04)
```

**Nomenclatura**:
| Componente | Formato | Exemplo |
|------------|---------|---------|
| `session-id` | 4 chars lowercase | `a1b2` |
| `feature` | kebab-case | `mcp-errors` |
| `tipo` | feat/fix/docs/chore/refactor | `feat` |

**Resultado**: Worktree criado, pronto para modificações.

### 2.2 Fase 2: Desenvolvimento

**Pré-condição**: Dentro do worktree.

**Ação**:
```bash
# Trabalhar normalmente
# Commits frequentes

git add {arquivo}
git commit -m "{tipo}({escopo}): {descrição}

Co-Authored-By: Claude-Code (Anthropic/Claude-4-Sonnet) <noreply+claude-code@anthropic.com>"
```

**Boas práticas**:
- Commits atômicos (uma mudança lógica por commit)
- Mensagens descritivas (Conventional Commits)
- Não acumular muitas mudanças

### 2.3 Fase 3: Push e PR

**Pré-condição**: Desenvolvimento concluído ou checkpoint.

**Ação**:
```bash
# 1. Push branch
git push -u origin {branch-name}

# 2. Criar PR
gh pr create \
  --title "{tipo}({escopo}): {descrição}" \
  --body "$(cat <<'EOF'
## Summary
- [bullets com mudanças principais]

## Test plan
- [como testar]

## Checklist
- [ ] Código testado localmente
- [ ] Documentação atualizada (se aplicável)

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

**IMPORTANTE**: O PR deve apontar para a branch PAI, não necessariamente main.

```
main (root)
  └── sprint/wave-5                    ← PR aponta aqui
        └── feat/my-feature (worktree) ← trabalho aqui
```

### 2.4 Fase 4: Aguardar Revisão

**Pré-condição**: PR criado.

**Configuração**:
| Parâmetro | Default | Descrição |
|-----------|---------|-----------|
| `PR_REVIEW_TTL_MINUTES` | 30 | Timeout máximo |
| `PR_CHECK_INTERVAL_SECONDS` | 60 | Intervalo de verificação |

**Ação**:
```bash
# Loop de verificação
START_TIME=$(date +%s)
TTL_SECONDS=$((PR_REVIEW_TTL_MINUTES * 60))

while true; do
  # Verificar se há revisão
  REVIEWS=$(gh pr view <numero> --json reviews,comments --jq '.reviews | length + (.comments | length)')

  if [ "$REVIEWS" -gt 0 ]; then
    echo "Revisão recebida!"
    break
  fi

  # Verificar TTL
  ELAPSED=$(($(date +%s) - START_TIME))
  if [ "$ELAPSED" -ge "$TTL_SECONDS" ]; then
    echo "TTL atingido, delegando..."
    # Ir para 4a
    break
  fi

  sleep $PR_CHECK_INTERVAL_SECONDS
done
```

### 2.5 Fase 4a: Timeout (Delegação)

**Pré-condição**: TTL atingido sem revisão.

**Ação**:
```markdown
## Delegação para Agente Revisor

**Contexto**: PR #{numero} aguardando revisão há {TTL} minutos
**Objetivo**: Obter revisão técnica do PR
**Tarefa**: Analisar código e documentar feedback

Via Task tool:
- subagent_type: "code-reviewer"
- prompt: "Revise PR #{numero} no repo {repo}. Analise: qualidade do código,
           potenciais bugs, aderência a padrões, documentação.
           Poste sua análise como comentário no PR."
```

Após revisão do agente delegado, retomar fluxo na Fase 5.

### 2.6 Fase 5: Analisar Revisão

**Pré-condição**: Revisão recebida (qualquer fonte).

**Identificar fonte**:
| Fonte | Identificação | Exemplo |
|-------|---------------|---------|
| CodeRabbitAI | author: `coderabbitai` | Walkthrough, suggestions |
| GitHub Copilot | author: `copilot` | Code suggestions |
| Humano | author: username real | Review comments |
| Outro agente | author: varies | Comentário estruturado |

**Estrutura de análise**:
```markdown
## Análise da Revisão

**Revisor**: {identificação}
**Tipo de feedback**: {informativo | sugestão | issue | erro}

### Itens Recebidos

| # | Item | Classificação | Ação |
|---|------|---------------|------|
| 1 | {descrição} | {válido/falso positivo/parcial/dúvida} | {ação} |
| 2 | {descrição} | {classificação} | {ação} |

### Decisão Final
{6a | 6b | 6c | 6d}
```

### 2.7 Fase 6: Decisões

#### 6a. Merge As-Is

**Quando usar**:
- Revisão aprova sem ressalvas
- Todos os itens são informativos (walkthrough)
- Agente discorda fundamentadamente de TODOS os itens

**Requisitos para discordância**:
1. Justificativa técnica documentada
2. Referência a requisitos/specs que suportam a decisão
3. Documentação no PR antes do merge

```bash
# Se houver discordância
gh pr comment <numero> --body "## Análise da Revisão

**Itens rejeitados com justificativa**:
1. {item}: Não aplica porque {razão técnica fundamentada}

**Referências**:
- {link para spec/requisito que suporta a decisão}"

# Merge
gh pr merge <numero> --merge
```

#### 6b. Aplicar Correção (Loop)

**Quando usar**:
- Revisão aponta problemas técnicos válidos
- Agente concorda com TODAS as sugestões

```bash
# 1. Implementar correções no worktree
cd .worktrees/{session-id}-{feature}

# 2. Para cada item válido
#    - Implementar correção
#    - Commit referenciando o item

git commit -m "fix: aplica feedback da revisão

- Item 1: {descrição da correção}
- Item 2: {descrição da correção}

Ref: PR #{numero} review"

# 3. Push
git push

# 4. VOLTAR para Fase 4 (aguardar nova revisão)
```

#### 6c. Concordância Parcial (Loop)

**Quando usar**:
- Alguns itens são válidos
- Outros são falsos positivos ou não aplicáveis

```bash
# 1. Implementar APENAS itens válidos
git commit -m "fix: aplica feedback parcial da revisão

Aplicados:
- Item 1: {correção}
- Item 3: {correção}

Rejeitados (ver justificativa no PR):
- Item 2
- Item 4"

# 2. Documentar no PR
gh pr comment <numero> --body "## Resposta à Revisão

### Itens Aplicados ✅
- [x] Item 1: Implementado em commit {sha}
- [x] Item 3: Implementado em commit {sha}

### Itens Rejeitados (com justificativa) ❌
- [ ] Item 2: Não aplica porque {razão técnica}
- [ ] Item 4: Conflita com requisito {X} em {link}"

# 3. Push e aguardar nova revisão
git push
# VOLTAR para Fase 4
```

#### 6d. Falha/Inconclusivo (Escalar)

**Quando usar**:
- Não consegue decidir se correção é válida
- Problema técnico complexo demais
- Requer conhecimento de domínio específico
- Múltiplas tentativas falharam

```bash
gh pr comment <numero> --body "## ⚠️ Status: Requer Assistência Humana

### O que foi tentado
1. {tentativa 1}
2. {tentativa 2}

### Descobertas técnicas
- {insight 1}
- {insight 2}

### Dúvidas pendentes
1. {pergunta específica 1}
2. {pergunta específica 2}

### Recomendação
{próximos passos sugeridos}

---
*Agente: {nome} | {timestamp}*
*Status: AGUARDANDO_HUMANO*"
```

**IMPORTANTE**: NÃO fazer merge. Aguardar decisão humana.

### 2.8 Fase 7: Merge Final

**Pré-condição**: Decisão 6a tomada.

**Checklist obrigatório**:
- [ ] Revisão recebida (bot/humano/IA)
- [ ] Análise documentada no PR
- [ ] Itens válidos corrigidos OU discordâncias justificadas
- [ ] CI/CD checks passando (se configurado)

```bash
gh pr merge <numero> --merge

# Cleanup
cd /path/to/repo
rm -rf .worktrees/{session-id}-{feature}
git worktree prune
```

---

## 3. Árvore de Decisão

```
Revisão recebida
      │
      ├── Nenhum item/apenas informativo?
      │     └── SIM → 6a. Merge
      │
      ├── Todos os itens são válidos?
      │     └── SIM → 6b. Aplicar correção → Loop
      │
      ├── Mix de válidos e inválidos?
      │     └── SIM → 6c. Parcial → Loop
      │
      ├── Todos os itens são falsos positivos?
      │     └── SIM → 6a. Merge (documentar discordância)
      │
      └── Não consigo decidir?
            └── SIM → 6d. Escalar para humano
```

---

## 4. Cenários e Exemplos

### 4.1 Cenário: CodeRabbitAI Walkthrough Only

**Situação**: CodeRabbitAI comenta apenas com walkthrough/summary.

**Análise**:
```markdown
## Análise da Revisão

**Revisor**: coderabbitai (bot)
**Tipo de feedback**: Informativo

### Itens Recebidos
| # | Item | Classificação | Ação |
|---|------|---------------|------|
| 1 | Walkthrough summary | Informativo | Nenhuma |
| 2 | Changes table | Informativo | Nenhuma |

### Decisão Final
6a. Merge As-Is (review informativo)
```

### 4.2 Cenário: Humano Pede Correção

**Situação**: Revisor humano solicita mudança de nome de variável.

**Análise**:
```markdown
## Análise da Revisão

**Revisor**: @joao-dev (humano)
**Tipo de feedback**: Sugestão

### Itens Recebidos
| # | Item | Classificação | Ação |
|---|------|---------------|------|
| 1 | "Renomear `data` para `userData`" | Válido | Implementar |

### Decisão Final
6b. Aplicar correção → novo commit → aguardar nova revisão
```

### 4.3 Cenário: Discordância Fundamentada

**Situação**: Bot sugere adicionar testes, mas PR é apenas documentação.

**Análise**:
```markdown
## Análise da Revisão

**Revisor**: coderabbitai (bot)
**Tipo de feedback**: Sugestão

### Itens Recebidos
| # | Item | Classificação | Ação |
|---|------|---------------|------|
| 1 | "Considerar adicionar testes" | Falso positivo | Documentar |

### Justificativa da Discordância
Este PR modifica apenas arquivos .md (documentação).
Não há código testável. A sugestão não se aplica ao contexto.

### Decisão Final
6a. Merge As-Is (falso positivo documentado)
```

### 4.4 Cenário: Mix de Feedback

**Situação**: 3 sugestões - 2 válidas, 1 falso positivo.

**Análise**:
```markdown
## Análise da Revisão

### Itens Recebidos
| # | Item | Classificação | Ação |
|---|------|---------------|------|
| 1 | "Adicionar try/catch na linha 45" | Válido | Implementar |
| 2 | "Usar const ao invés de let" | Válido | Implementar |
| 3 | "Remover console.log" | Falso positivo | Documentar |

### Justificativa para Item 3
O console.log é intencional para debug em ambiente de desenvolvimento.
Está dentro de bloco `if (process.env.DEBUG)`.

### Decisão Final
6c. Concordância parcial → implementar 1,2 → documentar 3 → nova revisão
```

### 4.5 Cenário: Timeout (TTL)

**Situação**: 30 minutos sem revisão.

**Ação**:
```markdown
## Delegação: Code Review PR #152

**Contexto**: PR criado há 30 minutos sem revisão
**Objetivo**: Obter análise técnica
**Tarefa**: Revisar código e postar feedback

**Delegado para**: Task(subagent_type="code-reviewer")
```

---

## 5. Configuração

### 5.1 Variáveis de Ambiente

| Variável | Tipo | Default | Descrição |
|----------|------|---------|-----------|
| `PR_REVIEW_TTL_MINUTES` | int | 30 | Tempo máximo de espera por revisão |
| `PR_CHECK_INTERVAL_SECONDS` | int | 60 | Intervalo entre verificações |
| `PR_AUTO_DELEGATE_REVIEWER` | bool | true | Delegar automaticamente após TTL |
| `PR_REQUIRE_HUMAN_APPROVAL` | bool | false | Sempre exigir humano |
| `PR_AUTO_MERGE_ON_APPROVAL` | bool | true | Merge automático se aprovado |

### 5.2 Arquivo de Configuração

Criar `.claude/config/pr-review.json` no repositório:

```json
{
  "version": "1.0",
  "ttl_minutes": 30,
  "check_interval_seconds": 60,
  "auto_delegate": true,
  "require_human": false,
  "reviewer_agents": ["code-reviewer", "security-sentinel"],
  "bypass_patterns": ["docs/**/*.md", "*.txt"],
  "protected_branches": ["main", "production"]
}
```

---

## 6. Exceções

### 6.1 Bypass Autorizado

O usuário pode autorizar bypass explicitamente:

```
Usuário: "merge sem esperar revisão, é urgente"
```

**Ação**:
```bash
# Documentar exceção
gh pr comment <numero> --body "## ⚠️ Bypass de Revisão Autorizado

**Razão**: Solicitação explícita do usuário
**Timestamp**: {ISO timestamp}
**Risco assumido**: Sim"

# Merge imediato
gh pr merge <numero> --merge
```

### 6.2 Hotfix Crítico

Produção down, correção urgente.

**Requisitos**:
1. Documentar urgência no PR
2. Notificar stakeholders
3. Agendar revisão post-mortem

```bash
gh pr create --title "HOTFIX: {descrição}" --body "
## 🚨 HOTFIX CRÍTICO

**Problema**: {descrição do incidente}
**Impacto**: {sistemas afetados}
**Urgência**: CRÍTICA - Produção impactada

⚠️ Este PR segue bypass de emergência.
Revisão post-mortem agendada para {data}.
"

gh pr merge <numero> --merge
```

---

## 7. Métricas e Observabilidade

### 7.1 Eventos a Registrar

| Evento | Dados | Destino |
|--------|-------|---------|
| PR_CREATED | pr_number, branch, timestamp | sessions.json |
| REVIEW_RECEIVED | pr_number, reviewer, type, timestamp | sessions.json |
| REVIEW_ANALYZED | pr_number, decision, items_count | sessions.json |
| PR_MERGED | pr_number, commits_count, timestamp | sessions.json |
| TTL_TIMEOUT | pr_number, waited_minutes | sessions.json |
| DELEGATION | pr_number, delegated_to, timestamp | sessions.json |

### 7.2 Session Report

Incluir na seção 5 (status) do session report:

```markdown
### PRs da Sessão

| PR | Status | Revisão | Decisão | Tempo |
|----|--------|---------|---------|-------|
| #152 | MERGED | CodeRabbitAI | 6a (approved) | 5min |
| #153 | PENDING | - | Aguardando | 12min |
```

---

## 8. Troubleshooting

### 8.1 "PR não recebe revisão do CodeRabbitAI"

**Diagnóstico**:
```bash
# Verificar se bot está instalado
gh api repos/{owner}/{repo}/installation

# Verificar configuração
cat .github/coderabbit.yaml
```

**Solução**: Instalar app em https://github.com/apps/coderabbitai

### 8.2 "TTL muito curto"

**Sintoma**: Delegação frequente antes de revisão humana.

**Solução**: Aumentar `PR_REVIEW_TTL_MINUTES` ou `PR_REQUIRE_HUMAN_APPROVAL=true`.

### 8.3 "Merge bloqueado por CI"

**Diagnóstico**:
```bash
gh pr checks <numero>
```

**Solução**: Corrigir falhas de CI antes do merge.

---

## 9. Changelog

| Versão | Data | Mudanças |
|--------|------|----------|
| 2.0.0 | 2026-01-22 | Versão inicial generalizada (substitui github-workflow.md) |

---

*Assinatura: Claude-Code | 2026-01-22T11:50:00-03:00*
