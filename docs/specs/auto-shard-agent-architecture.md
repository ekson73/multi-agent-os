# Technical Architecture: Auto-Shard Agent v1.0

---

**Document Control**

| Property | Value |
|----------|-------|
| **Project** | Auto-Shard Agent |
| **Version** | 1.0.0 |
| **Author** | Claude-Code (Solution Architect) |
| **Created** | 2026-01-25 |
| **Status** | Ready for Review |

---

## 1. Architecture Overview

O Auto-Shard Agent é um sistema híbrido que detecta arquivos Markdown grandes (>40KB) e os fragmenta automaticamente em shards menores, preservando integridade e referências.

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        AUTO-SHARD AGENT v1.0                            │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────┐      ┌───────────────────────────────────────┐   │
│  │   HOOK LAYER     │      │           SKILL LAYER                  │   │
│  │  (Detection)     │      │          (Execution)                   │   │
│  │                  │      │                                        │   │
│  │ PreToolUse:      │      │  /auto-shard                           │   │
│  │ - Edit           │─────►│    │                                   │   │
│  │ - Write          │      │    ├── ShardAnalyzer                   │   │
│  │ - MultiEdit      │      │    │   (identifica seções)             │   │
│  │                  │      │    │                                   │   │
│  │ Detects:         │      │    ├── CriticalityClassifier           │   │
│  │ - file size      │      │    │   (CRITICAL/HIGH/MEDIUM/LOW)      │   │
│  │ - file type (.md)│      │    │                                   │   │
│  │                  │      │    ├── ShardGenerator                  │   │
│  │ Outputs:         │      │    │   (cria shards)                   │   │
│  │ - JSON trigger   │      │    │                                   │   │
│  │ - BLOCK/CONTINUE │      │    ├── ReferenceUpdater                │   │
│  │                  │      │    │   (atualiza links)                │   │
│  └──────────────────┘      │    │                                   │   │
│                            │    ├── IntegrityValidator              │   │
│                            │    │   (SHA256 + link check)           │   │
│                            │    │                                   │   │
│                            │    └── RecursiveProcessor              │   │
│                            │        (max 3 níveis)                  │   │
│                            └───────────────────────────────────────┘   │
│                                                                         │
├─────────────────────────────────────────────────────────────────────────┤
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                    STATE LAYER                                    │  │
│  │  .claude/shard_state/                                             │  │
│  │    ├── config.yaml          # Configuração                        │  │
│  │    ├── manifest.json        # Mapeamento source → shards          │  │
│  │    └── hashes.json          # SHA256 para integridade             │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Execution Flow

```
┌────────┐  ┌──────────┐  ┌────────────┐  ┌────────────┐
│ Claude │  │   Hook   │  │   Skill    │  │   Files    │
│  Code  │  │ Detector │  │ Processor  │  │            │
└───┬────┘  └────┬─────┘  └─────┬──────┘  └─────┬──────┘
    │            │              │               │
    │ Write/Edit │              │               │
    │───────────►│              │               │
    │            │ Check size   │               │
    │            │──────────────┼──────────────►│
    │            │              │               │
    │ [size<=40KB: CONTINUE]    │               │
    │◄───────────│              │               │
    │            │              │               │
    │ [size>40KB: BLOCK + msg]  │               │
    │◄───────────│              │               │
    │            │              │               │
    │ /auto-shard file.md       │               │
    │──────────────────────────►│               │
    │            │              │               │
    │            │              │ 1. Analyze    │
    │            │              │───────────────►
    │            │              │ 2. Classify   │
    │            │              │ 3. Generate   │
    │            │              │ 4. Update refs│
    │            │              │ 5. Validate   │
    │            │              │◄──────────────│
    │            │              │               │
    │ Result: sharded           │               │
    │◄──────────────────────────│               │
```

---

## 3. Architecture Decision Records (ADRs)

### ADR-001: Hybrid Hook + Skill Pattern

| Item | Value |
|------|-------|
| **Decision** | Usar Hook para detecção leve + Skill para execução |
| **Rationale** | Hooks são síncronos (<1s). Skills podem usar Task Tool |
| **Consequences** | (+) Hook simples, (-) Dois componentes |

### ADR-002: CRITICAL/HIGH → Rules, MEDIUM/LOW → Docs

| Item | Value |
|------|-------|
| **Decision** | Direcionar por criticidade para auto-load vs on-demand |
| **Rationale** | [C08]: "Insight sem rule = arquivo morto" |
| **Consequences** | (+) Conteúdo crítico sempre presente |

### ADR-003: State em .claude/shard_state/

| Item | Value |
|------|-------|
| **Decision** | Criar diretório dedicado para estado |
| **Rationale** | Segue padrão existente (.claude/docs/, .claude/sessions/) |
| **Consequences** | (+) State isolado e rastreável |

### ADR-004: Rollback Atômico via Backup

| Item | Value |
|------|-------|
| **Decision** | Backup antes de modificação, rollback em falha |
| **Rationale** | Garante consistência |
| **Consequences** | (+) Seguro, (-) Storage temporário |

### ADR-005: Max Depth = 3

| Item | Value |
|------|-------|
| **Decision** | Hard limit de 3 níveis de recursão |
| **Rationale** | Previne loop infinito |
| **Consequences** | (+) Previne loops, (-) Arquivos depth=3 ficam grandes |

---

## 4. Directory Structure

```
~/.claude/
├── hooks/
│   └── detect-large-file.sh           # Hook detector
├── commands/
│   └── auto-shard/
│       └── SKILL.md                    # Skill principal
├── docs/
│   └── auto-shard/
│       ├── spec.md
│       └── heuristics.md
└── settings.json                       # Hook registration

{project}/.claude/
├── rules/                              # AUTO-LOAD (CRITICAL, HIGH)
│   └── {section-slug}.md
├── docs/                               # ON-DEMAND (MEDIUM, LOW)
│   ├── core/
│   ├── protocols/
│   └── reference/
└── shard_state/
    ├── config.yaml
    ├── manifest.json
    └── hashes.json
```

---

## 5. Interfaces

### 5.1 Hook Input (stdin)

```json
{
  "tool_name": "Write",
  "tool_input": {
    "file_path": "/path/to/file.md",
    "content": "..."
  }
}
```

### 5.2 Hook Output (stdout)

```json
{
  "decision": "block",
  "reason": "File exceeds 40KB threshold",
  "action": {
    "invoke_skill": "/auto-shard",
    "args": {"file_path": "/path/to/file.md"}
  }
}
```

### 5.3 Skill Output (JSON-RPC)

```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "summary": {
      "source_file": "CLAUDE.md",
      "original_size": 100000,
      "final_size": 15000,
      "shards_created": 5
    },
    "shards": [
      {"path": ".claude/rules/core-directive.md", "criticality": "CRITICAL"}
    ]
  },
  "id": "uuid"
}
```

### 5.4 Config Schema

```yaml
auto_shard:
  version: "1.0.0"
  threshold_kb: 40
  max_depth: 3
  criticality_keywords:
    critical: ["MUST", "NEVER", "CRITICAL"]
    high: ["SHOULD", "Protocol", "[C"]
  exclude_patterns:
    - "**/node_modules/**"
    - "**/_deprecated/**"
```

---

## 6. Criticality Classification

| Criticality | Heurística | Destino | Auto-Load |
|-------------|------------|---------|-----------|
| CRITICAL | MUST, NEVER, CRITICAL | `.claude/rules/` | SIM |
| HIGH | [CXX], Protocol | `.claude/rules/` | SIM |
| MEDIUM | Code blocks, templates | `.claude/docs/` | NÃO |
| LOW | Descriptive content | `.claude/docs/` | NÃO |

---

## 7. Risk Mitigation

| Risco | Mitigação |
|-------|-----------|
| Loop infinito | Hash tracking + depth limit |
| Perda de dados | SHA256 + atomic rollback |
| Links quebrados | Regex replace + validation |
| Performance >30s | Streaming + parallel I/O |
| Conflito multi-agent | Lock file + worktree |

---

## 8. Implementation Priority

| Fase | Componente | Estimativa |
|------|------------|------------|
| P1 | Hook detector | 2h |
| P1 | SKILL.md base | 2h |
| P2 | ShardAnalyzer | 4h |
| P2 | CriticalityClassifier | 2h |
| P3 | ShardGenerator | 4h |
| P3 | ReferenceUpdater | 3h |
| P4 | IntegrityValidator | 2h |
| P4 | RecursiveProcessor | 4h |
| P5 | Tests | 8h |

**Total**: ~31h (AI-agent pode ser 50% menos)

---

## 9. Compliance Matrix

| Requisito | Status | Implementação |
|-----------|--------|---------------|
| RF01: Detectar >40KB | ✓ | Hook PreToolUse |
| RF02: Identificar seções | ✓ | ShardAnalyzer |
| RF03: Classificar | ✓ | CriticalityClassifier |
| RF04: Criar shards | ✓ | ShardGenerator |
| RF05: Atualizar refs | ✓ | ReferenceUpdater |
| RF06: Validar SHA256 | ✓ | IntegrityValidator |
| RF07: Recursão max 3 | ✓ | RecursiveProcessor |

---

## 10. Worktree Integration (C04)

O Auto-Shard Agent DEVE respeitar o Git Worktree Protocol (C04).

### Regras de Integração

| Contexto | Comportamento |
|----------|---------------|
| **Main branch** | Hook BLOQUEIA operação. Mensagem: "Use worktree for sharding" |
| **Worktree ativo** | Skill executa normalmente |
| **--force flag** | Bypass worktree check (com warning) |

### Fluxo com Worktree

```
1. Hook detecta arquivo >40KB
2. Hook verifica: `git worktree list` + branch atual
3. Se main/master → BLOCK com instrução
4. Se worktree → CONTINUE, invoke skill
5. Skill executa sharding no worktree
6. Após sharding: sugerir commit + PR
```

### Hook Integration

```bash
# No detect-large-file.sh
current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
    echo '{"decision":"block","reason":"Sharding requires worktree (C04)"}'
    exit 2
fi
```

---

## 11. Exit Codes (C06)

Conformidade com AI-Native Environment (C06).

| Code | Significado | Quando |
|------|-------------|--------|
| **0** | Success | Sharding completado com sucesso |
| **1** | Error | Falha irrecuperável (validação, I/O) |
| **2** | Warning/Block | Hook bloqueou (worktree, threshold) |
| **3** | Partial | Sharding parcial (alguns shards falharam) |

### Uso

```bash
/auto-shard full ~/.claude/CLAUDE.md
echo $?  # 0 = success, 1 = error, 2 = blocked, 3 = partial
```

---

## 12. CLI Interface

### Flags Obrigatórias (C06)

| Flag | Descrição | Default |
|------|-----------|---------|
| `--json` | Output em JSON-RPC (stdout) | false |
| `--dry-run` | Preview sem modificar | false |
| `--force` | Bypass worktree check | false |
| `--verbose` | Output detalhado | false |
| `--threshold` | Override threshold (KB) | 40 |

### Exemplos

```bash
# Análise com output JSON
/auto-shard analyze ~/.claude/CLAUDE.md --json

# Dry-run com verbose
/auto-shard full ~/.claude/CLAUDE.md --dry-run --verbose

# Force sharding em main (não recomendado)
/auto-shard full ~/.claude/CLAUDE.md --force
```

### Output --json

```json
{
  "jsonrpc": "2.0",
  "result": {
    "success": true,
    "exit_code": 0,
    "operation": "full",
    "summary": {...}
  },
  "id": "auto-shard-2026-01-25T12:00:00Z"
}
```

---

*Assinatura: Claude-Code (Solution Architect) | 2026-01-25*
*Versão: 1.1.0 (corrigido issues C04-1, C06-1, C06-2)*
