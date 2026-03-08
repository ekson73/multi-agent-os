# Principio do Agora Prioritario [C15]

<!-- Auto-loaded rule | Version: 1.0.0 | 2026-03-08 -->
<!-- Nome canonico: "Principio do Agora Prioritario" -->
<!-- Origem: "Principio de Nao Procrastinacao Zen" (nome informal do usuario) -->

## Principio Fundamental

```
┌────────────────────────────────────────────────────────────────────────┐
│  "Nao deixe para depois o que pode ser feito agora."                  │
│  "Mas nao faca agora o que nao deve ser feito nunca."                 │
├────────────────────────────────────────────────────────────────────────┤
│  A acao imediata sem filtro e impulsividade.                          │
│  O filtro sem acao e procrastinacao disfarçada.                       │
│  C15 = Acao + Filtro. Juntos. Sempre.                                 │
├────────────────────────────────────────────────────────────────────────┤
│  CICLO: Detectou task → Classifica (Eisenhower) → Verifica dep →     │
│         Faz | Agenda | Delega (C14) | Elimina                         │
└────────────────────────────────────────────────────────────────────────┘
```

## Matriz Eisenhower (Operacional)

```
                    URGENTE              NAO URGENTE
               ┌─────────────────┬─────────────────────┐
   IMPORTANTE  │   Q1: FAZER     │   Q2: AGENDAR       │
               │   AGORA         │   com timebox        │
               │                 │                      │
               │  → Executa      │  → Reserva slot      │
               │  → Sem demora   │  → Se adiado 2x,    │
               │  → Bloqueia     │    promover para Q1  │
               │    tudo mais    │                      │
               ├─────────────────┼─────────────────────┤
  NAO          │   Q3: DELEGAR   │   Q4: ELIMINAR       │
  IMPORTANTE   │   (ver C14)     │   da fila            │
               │                 │                      │
               │  → Nao faca     │  → Descarta          │
               │  → Delegue      │  → Se nao pode       │
               │  → Se impossivel│    eliminar, Q3      │
               │    delegar: Q2  │                      │
               └─────────────────┴─────────────────────┘
```

### Acao por Quadrante

| Quadrante | Label | Acao |
|-----------|-------|------|
| Q1 | Urgente + Importante | Faz agora. Bloqueia tudo mais. |
| Q2 | Nao urgente + Importante | Agenda timebox. Protege da urgencia falsa. |
| Q3 | Urgente + Nao importante | Delega (C14). Se impossivel, minimiza e agenda. |
| Q4 | Nao urgente + Nao importante | Elimina. Nao entra na fila. |

## Matriz de Interdependencia

Apos classificar por Eisenhower, verificar dependencias:

```
TASK ATUAL
  ↓
[Bloqueia outras tasks?]
  → SIM: Prioridade AUMENTA (resolve agora — desbloqueia o time/fluxo)
  → NAO: continua

[E bloqueada por outra task?]
  → SIM: Park it. Va resolver o bloqueador primeiro.
  → NAO: continua

[E paralela (independente)?]
  → SIM: Pode paralelizar via agentes ou sequenciar por Eisenhower
  → NAO: verifica deadlock

[Dependencia circular (deadlock)?]
  → Escalate ao usuario. Nao inventa solucao sozinho.
```

### Tipos de Dependencia

| Tipo | Simbolo | Acao |
|------|---------|------|
| Bloqueia outras | `→` | Resolve PRIMEIRO (multiplicador de valor) |
| Bloqueada por outra | `←` | Park. Resolve o bloqueador. |
| Paralela | `‖` | Paraleliza ou sequencia por Q |
| Circular | `↺` | Escalar ao usuario |

## Regra de Desempate (Tiebreaker)

Quando duas tasks tem mesmo Q e mesma posicao de dependencia:

```
1. Mais antiga na fila → maior prioridade
2. Menor custo de chaveamento → preferida
3. Maior numero de dependentes → preferida
4. Se ainda empate → escolha aleatoria + documente
```

## Escape Hatch (Quando Incerto)

```
INCERTO SOBRE CLASSIFICACAO?
  → Pergunte: "Se eu fizer isso agora, o fluxo avanca ou para?"
      → Avanca: faz
      → Para/neutro: classifica como Q2 e agenda

INCERTO SOBRE DEPENDENCIA?
  → Assuma independente. Execute. Ajuste se necessario.

INCERTO SOBRE TUDO?
  → Aja na task Q1 mais visivel.
  → Se nenhuma Q1 visivel: aja na task mais antiga em aberto.
  → NUNCA fique parado por incerteza de classificacao.
```

## Timebox para Q2 (Anti-Adiamento Cronico)

```
REGRA DO TIMEBOX Q2:
  - Toda sessao de trabalho DEVE ter >= 1 slot Q2
  - Se uma task Q2 for adiada por 2 sessoes seguidas:
      → Promove para Q1 (tornou-se importante E urgente por adiamento)
  - Se uma task Q2 nunca entra em timebox:
      → E procrastinacao disfarçada de "nao urgente"
```

## Anti-patterns

```
X  Vies de urgencia: tratar Q3 como Q1 por parecer urgente
   → Pergunte: "Importante para QUEM?" Se nao e para o objetivo principal,
     e Q3. Delega.

X  Paralisia por analise: classificar mais do que agir
   → C15 e para decisao rapida, nao para reuniao de alinhamento.
     Se levou mais de 30s para classificar, use o Escape Hatch.

X  "Zen falso": adiar com desculpa de "nao e prioridade agora"
   → Procrastinacao com vocabulario de Eisenhower ainda e procrastinacao.
     Se a task nunca e prioridade, elimine-a (Q4) ou assuma que e Q2 cronica.

X  Q2 eterno: tarefas importantes que nunca ficam urgentes, logo nunca sao feitas
   → Aplique Timebox Q2. Se necessario, promova para Q1 artificialmente.

X  Fazer Q4 por ser "facil e rapido"
   → "Facil e rapido" nao e criterio de Eisenhower. Se nao e importante,
     nao faca — mesmo que leve 30 segundos.

X  Ignorar dependencias e travar o fluxo do time
   → Sempre verificar: "o que eu estou bloqueando?" antes de comecar.
```

## Integracao com C13 e C14

```
C15 (este) → Governa DURANTE o ciclo de trabalho: o que fazer agora
C13 (exit-hygiene) → Governa AO SAIR: ambiente melhor do que entrou
C14 (agent-delegation) → Governa QUANDO NAO SABER: delegar para melhor agente

FLUXO INTEGRADO:
  [Inicio da sessao]
    → Listar tasks abertas
    → Classificar por Eisenhower (C15)
    → Verificar dependencias (C15)
    → Executar por prioridade

  [Durante sessao - detectou problema fora do escopo]
    → C14: qual melhor agente?
    → Delegar com contexto completo

  [Ao sair da sessao]
    → C13: exit gate (git status, MEMORY.md, emails, worktrees)
    → C15: tasks Q2 ficaram para proxima sessao? Documenta em MEMORY.md.
    → C14: delegacoes ativas tem rastreabilidade?
```

---

*v1.0.0 | 2026-03-08 | Nome canonico do "Principio de Nao Procrastinacao Zen"*
