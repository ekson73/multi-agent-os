# GaaS: Governance-as-a-Service — Manifesto Arquitetural

> O pilar que garante todos os outros pilares.
> Version: 1.0.0 | Created: 2026-03-19

---

## O Problema: Governance by Hope

Na engenharia tradicional, governanca significa escrever um PDF ou um longo `CONTRIBUTING.md` e torcer para que o desenvolvedor leia e cumpra.

No mundo da Inteligencia Artificial GenAI — onde o agente pode sofrer transbordamento de contexto (*context overflow*), alucinar regras, ou simplesmente ignorar o Prompt de Sistema para focar no codigo — depender apenas da leitura e fazer **Gestao Baseada na Esperanca (Governance by Hope)**.

```
┌────────────────────────────────────────────────────────────────────────┐
│  GOVERNANCE BY HOPE (anti-pattern)                                     │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  1. Humano escreve regras em Markdown                                 │
│  2. LLM recebe regras no system prompt                                │
│  3. LLM "interpreta" regras como sugestoes probabilisticas            │
│  4. LLM alucina, ignora, ou reinterpreta criativamente                │
│  5. Humano descobre violacao dias depois no code review               │
│                                                                        │
│  RESULTADO: Compliance confessional, nao algoritmico                  │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

## A Solucao: Desacoplar a Regra do Ator

O GaaS resolve isso **desacoplando a regra do ator**. Nao importa se quem codificou a feature foi um engenheiro senior, o Claude, o Copilot, o Codex, o Gemini, ou qualquer outro agente. A governanca se torna uma entidade fisica, inviolavel e onipresente na esteira.

```
┌────────────────────────────────────────────────────────────────────────┐
│  GaaS: GOVERNANCE-AS-A-SERVICE (the pattern)                           │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  A IA nao "interpreta" um exit code 1 — ela OBEDECE.                 │
│  Um stderr de hook e um FATO DETERMINISTICO,                          │
│  nao uma SUGESTAO PROBABILISTICA.                                     │
│                                                                        │
│  Instrucoes Markdown = sugestoes (o LLM pode ignorar)                 │
│  Exit code + stderr  = fatos (o LLM nao pode contornar)               │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Os 3 Motores do GaaS

### Motor 1: Linha de Defesa Local (Git Hooks Implacaveis)

O GaaS comeca no terminal local (*Pre-commit* / *Pre-push* hooks). Se um Agente IA tentar dar um `git commit` no branch raiz (`main`) quebrando a regra C04 do Worktree, o Hook intercepta o comando, dropa a acao e retorna um Error Code.

**A Magica:** A IA le o `stderr` do terminal (ex: *"Commit Bloqueado pelo Policy Hook: Voce esta na raiz. Use Worktrees."*), percebe que errou, e se autocorrige em loop. A IA aprende com o erro da infraestrutura sem intervencao humana.

```bash
# Exemplo real: .githooks/pre-commit
if echo "$BRANCH_NAME" | grep -Eq '^(main|master|develop)$'; then
    echo "🛑 [GAAS: ACTION REJECTED] POLICY VIOLATION"
    echo "Agente/User tentou commitar na branch restrita: '$BRANCH_NAME'"
    exit 1  # ← FATO DETERMINISTICO. A IA nao pode "reinterpretar" isso.
fi
```

**Implementacao no multi-agent-os:**
- `.githooks/pre-commit` — bloqueia commits em main/master/develop (C04)
- `.githooks/pre-push` — valida nomenclatura de branch
- `hooks/hooks.json` — lifecycle hooks do plugin (SessionStart, PreToolUse, PostToolUse, Stop)

### Motor 2: Linha de Defesa Remota (Esteira CI/CD)

E se a IA enganar o Hook local (`git commit --no-verify`)? O GaaS possui os **AI-Bots Reviewers** na nuvem (GitHub Actions / Bitbucket Pipelines).

Quando a IA X abre o Pull Request, a Pipeline engatilha o GaaS:
1. Linters de Seguranca (SRE) catam chaves vazadas (PII)
2. Analisa nomenclatura de branch
3. Obriga assinatura SOTA (`Co-Authored-By: <Agent>`)
4. Chama CodeRabbit, Copilot, Qodo para code review automatizado

A branch fica tecnicamente impossivel de ser fundida (*Merged*) se os criterios sintaticos nao retornarem verde. O compliance e algoritmico, nao confessional.

**Implementacao no multi-agent-os:**
- `rules/pr-governance-unified.md` — lifecycle de 12 steps com review obrigatorio
- `docs/pr-review-protocol-spec.md` — spec completa de review
- `docs/pr-reviewer-communication.md` — protocolo de comunicacao com bots
- `sentinel/` — 10 regras de deteccao de anomalias

### Motor 3: Policy-as-Code (Rego / OPA)

A evolucao maxima do GaaS. Em vez de escrevermos regras num Markdown de texto livre (que os LLMs interpretam como querem dependendo do seu "humor" criativo), as politicas sao transformadas em **codigo logico** ou *JSON schemas*.

A governanca nao diz *"Por favor, nao coloque portas abertas no YAML de Kubernetes"*. Ela aplica uma funcao booleana rodando em background avaliando a topologia do codigo.

**Status no multi-agent-os:**
- `sentinel/config.json` — thresholds de deteccao em JSON (parcialmente implementado)
- `sentinel/schema/` — JSON schemas para traces e alerts
- OPA/Rego — **planejado** (gap identificado, nao implementado)

---

## Por Que GaaS e o Pilar Garantidor

Os outros 8 pilares do Multi-Agent OS sao todos *advisory* — o agente pode ignora-los:

| Pilar | Natureza | O agente pode ignorar? |
|-------|----------|------------------------|
| AGENTS.md | Instrucoes em Markdown | Sim (sugestao probabilistica) |
| MCP | Conectividade de ferramentas | Sim (pode nao usar) |
| A2A | Comunicacao agente-agente | Sim (pode nao comunicar) |
| ACP | Interacao IDE-agente | Sim (pode bypassar) |
| Raw URLs | Distribuicao de governanca | Sim (pode nao ler) |
| Multi-Agent | Capacidade arquitetural | Sim (pode operar sozinho) |
| AI-Agnostic | Principio de design | Sim (pode usar vendor-specific) |
| Org-Agnostic | Principio de design | Sim (pode hardcodar org) |
| **GaaS** | **Enforcement fisico** | **NAO (exit code 1 e incontornavel)** |

**GaaS e o unico pilar que nao depende de cooperacao do agente.** Ele garante que os outros 8 sejam respeitados mesmo quando o agente alucina, ignora contexto, ou age de forma autonoma sem supervisao.

---

## Beneficio Zero-Trust e AI-Agnostic

Implementar o GaaS e o unico modo de atingir o nirvana do **Zero-Trust** em times hibridos (Humanos + IAs). O repositorio passa a "nao confiar em ninguem".

```
┌────────────────────────────────────────────────────────────────────────┐
│  ZERO-TRUST ENFORCEMENT CHAIN                                          │
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  Agente (qualquer)                                                    │
│    │                                                                   │
│    ├── git commit → [MOTOR 1: Hook Local]                             │
│    │                  ├── PASS → continua                              │
│    │                  └── FAIL → exit 1 (IA autocorrige)              │
│    │                                                                   │
│    ├── git push → [MOTOR 1: Hook Pre-push]                            │
│    │                ├── PASS → continua                                │
│    │                └── FAIL → exit 1 (IA renomeia branch)            │
│    │                                                                   │
│    ├── PR Create → [MOTOR 2: CI/CD Pipeline]                          │
│    │                 ├── Linter PII → PASS/FAIL                       │
│    │                 ├── Branch naming → PASS/FAIL                    │
│    │                 ├── Co-Author check → PASS/FAIL                  │
│    │                 └── Bot Review → approve/request-changes          │
│    │                                                                   │
│    └── PR Merge → [MOTOR 2: Branch Protection]                        │
│                     ├── N approvals required → PASS/FAIL              │
│                     ├── CI checks passed → PASS/FAIL                  │
│                     └── [MOTOR 3: OPA Policy] → PASS/FAIL            │
│                                                                        │
│  RESULTADO: Nenhuma mudanca entra sem passar por TODOS os motores     │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
```

---

## Referencia de Implementacao

| Motor | Artefato no multi-agent-os | Status |
|-------|---------------------------|--------|
| Hook pre-commit | `.githooks/pre-commit` | Implementado |
| Hook pre-push | `.githooks/pre-push` | Implementado |
| Plugin hooks | `hooks/hooks.json` | Implementado |
| PR governance | `rules/pr-governance-unified.md` | Implementado |
| PR review spec | `docs/pr-review-protocol-spec.md` | Implementado |
| Sentinel detection | `sentinel/detection_rules.md` | Implementado |
| Sentinel schemas | `sentinel/schema/*.json` | Implementado |
| Bot communication | `docs/pr-reviewer-communication.md` | Implementado |
| Installation guide | `docs/GaaS_INSTALLATION_GUIDE.md` | Implementado |
| Raw URL injection | `docs/RAW_URL_INJECTION.md` | Implementado |
| OPA/Rego policies | — | Planejado |
| PII linter | — | Planejado |

---

## Anti-Patterns

### Symlinks for Governance File Sharing

Using symbolic links (symlinks) to share AI context files (CLAUDE.md, .cursorrules, AGENTS.md) across repositories is a **known anti-pattern** that violates GaaS principles. Symlinks with absolute paths:

- **Break Motor 2 (CI/CD):** CI runners cannot resolve local filesystem paths, causing pipeline failures that bypass all remote governance checks
- **Bypass Motor 1 (Local Hooks):** Dangling symlinks produce silent failures where hooks may not find the governance files they need to enforce
- **Undermine Zero-Trust:** Symlinks expose local filesystem structure (usernames, directory layouts) in git history, violating the information disclosure principle

A real-world incident demonstrated that 47 committed symlinks blocked an entire team's CI pipeline for 10 days across all branches.

**Use instead:** Raw URL Injection (C15 Protocol) or layered composition via sync scripts. See [`why-not-symlinks.md`](./why-not-symlinks.md) for the full analysis, decision matrix, and recommended alternatives.

---

## Leitura Complementar

- `docs/GaaS_INSTALLATION_GUIDE.md` — Como instalar os 3 motores em qualquer repo
- `docs/RAW_URL_INJECTION.md` — Context injection via Raw URLs
- `rules/pr-governance-unified.md` — PR lifecycle de 12 steps
- `sentinel/detection_rules.md` — 10 regras de deteccao de anomalias
- `protocols/hierarchical-merge-protocol.md` — Merge hierarquico
