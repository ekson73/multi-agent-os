# Template: PRE_COMMIT

**Proposito**: Validacao antes de commit
**Tempo de absorcao**: 8-10 segundos
**Trigger**: Automatico (pre-commit) ou `/status pre`

---

## Formato

```
┌─ PRE-COMMIT CHECK ──────────────────────────────────────────────────────┐
│                                                                          │
│  Branch: {branch} │ Target: {commit_target}                              │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  STAGED FILES ({staged_count})                                           │
│  ─────────────────────────────────────────────────────────────────────── │
│  {staged_files_list}                                                     │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  VALIDATION CHECKS                                                       │
│  ─────────────────────────────────────────────────────────────────────── │
│  {check_icon} Protected files: {protected_status}                        │
│  {check_icon} Lock conflicts:  {lock_status}                             │
│  {check_icon} Naming convention: {naming_status}                         │
│  {check_icon} ISO dates: {dates_status}                                  │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  → {commit_recommendation}                                               │
│  [commit] [git status] [abort]                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

## Exemplo Preenchido

```
┌─ PRE-COMMIT CHECK ──────────────────────────────────────────────────────┐
│                                                                          │
│  Branch: main │ Target: direct commit to main                            │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  STAGED FILES (3)                                                        │
│  ─────────────────────────────────────────────────────────────────────── │
│  M  .claude/statusmap/README.md                                          │
│  A  .claude/statusmap/templates/COMPACT.md                               │
│  A  .claude/statusmap/inference.md                                       │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  VALIDATION CHECKS                                                       │
│  ─────────────────────────────────────────────────────────────────────── │
│  ✓ Protected files: CLAUDE.md not in staging                             │
│  ✓ Lock conflicts:  No active locks on staged files                      │
│  ✓ Naming convention: All files follow snake_case                        │
│  ✓ ISO dates: All dates in YYYY-MM-DD format                             │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  → Ready to commit                                                       │
│  [commit] [git status] [abort]                                           │
└──────────────────────────────────────────────────────────────────────────┘
```

## Campos

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `branch` | Sim | Branch atual |
| `commit_target` | Sim | Destino do commit |
| `staged_count` | Sim | Numero de arquivos staged |
| `staged_files_list` | Sim | Lista de arquivos com status (M/A/D) |
| `protected_status` | Sim | Status de arquivos protegidos |
| `lock_status` | Sim | Status de conflitos de lock |
| `naming_status` | Sim | Status de convencao de nomes |
| `dates_status` | Sim | Status de formatos de data |
| `commit_recommendation` | Sim | Recomendacao final |

## Indicadores de Check

| Indicador | Significado |
|-----------|-------------|
| ✓ | Check passou |
| ⚠ | Warning (pode prosseguir com cautela) |
| ✗ | Check falhou (requer correcao) |

---

**Versao**: 1.0
