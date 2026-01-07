# Template: DELEGATION_POST

**Proposito**: Resultado apos sub-agente completar
**Tempo de absorcao**: 8-12 segundos
**Trigger**: Automatico (apos Task tool retornar)

---

## Formato

```
┌─ DELEGATION RESULT ─────────────────────────────────────────────────────┐
│                                                                          │
│  Agent: {agent_id} │ Status: {status} │ Duration: {duration}             │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  TASK OUTCOME                                                            │
│  ─────────────────────────────────────────────────────────────────────── │
│  {outcome_summary}                                                       │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  METRICS                                                                 │
│  ─────────────────────────────────────────────────────────────────────── │
│  Output size: {output_tokens} tokens │ Quality: {quality_score}/10       │
│  Anomalies: {anomalies_detected}                                         │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  SENTINEL ANALYSIS                                                       │
│  ─────────────────────────────────────────────────────────────────────── │
│  {sentinel_status}                                                       │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  → {next_action}                                                         │
└──────────────────────────────────────────────────────────────────────────┘
```

## Exemplo Preenchido (Sucesso)

```
┌─ DELEGATION RESULT ─────────────────────────────────────────────────────┐
│                                                                          │
│  Agent: Claude-Analyst-c614-003 │ Status: ✓ SUCCESS │ Duration: 45s      │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  TASK OUTCOME                                                            │
│  ─────────────────────────────────────────────────────────────────────── │
│  Identified 4 critical gaps in VKS-554 dependencies:                     │
│  - VKS-554 → VKS-533: 1 day gap (HIGH risk)                              │
│  - VKS-533 → VKS-553: 1 day gap (HIGH risk)                              │
│  - VKS-545 → VKS-534: 3 day gap (MEDIUM risk)                            │
│  Recommended: Add 5-day buffer to Wave 4                                 │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  METRICS                                                                 │
│  ─────────────────────────────────────────────────────────────────────── │
│  Output size: 487 tokens │ Quality: 8/10                                 │
│  Anomalies: 0                                                            │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  SENTINEL ANALYSIS                                                       │
│  ─────────────────────────────────────────────────────────────────────── │
│  ✓ All 10 detection rules passed                                         │
│  ✓ No anomalies detected                                                 │
│  ✓ Output aligned with task scope                                        │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  → Consolidating output into main context                                │
└──────────────────────────────────────────────────────────────────────────┘
```

## Exemplo Preenchido (Falha)

```
┌─ DELEGATION RESULT ─────────────────────────────────────────────────────┐
│                                                                          │
│  Agent: Claude-Dev-c614-004 │ Status: ✗ FAILED │ Duration: 2m15s         │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  TASK OUTCOME                                                            │
│  ─────────────────────────────────────────────────────────────────────── │
│  Error: File not found - 02_processed_data/missing_file.csv              │
│  Agent attempted to read non-existent dependency mapping                 │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  METRICS                                                                 │
│  ─────────────────────────────────────────────────────────────────────── │
│  Output size: 0 tokens │ Quality: N/A                                    │
│  Anomalies: 1 (ERROR_CASCADE potential)                                  │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  SENTINEL ANALYSIS                                                       │
│  ─────────────────────────────────────────────────────────────────────── │
│  ⚠ RULE-004 (Error Cascade): Watching for consecutive errors            │
│  ⚠ Recommendation: Verify file paths before retry                        │
│                                                                          │
├──────────────────────────────────────────────────────────────────────────┤
│  → Escalating to orchestrator for decision                               │
└──────────────────────────────────────────────────────────────────────────┘
```

## Campos

| Campo | Obrigatorio | Descricao |
|-------|-------------|-----------|
| `agent_id` | Sim | ID do agente que executou |
| `status` | Sim | ✓ SUCCESS / ✗ FAILED / ⚠ PARTIAL |
| `duration` | Sim | Tempo de execucao |
| `outcome_summary` | Sim | Resumo do resultado (3-5 linhas) |
| `output_tokens` | Nao | Tamanho do output em tokens |
| `quality_score` | Nao | Score de qualidade 0-10 |
| `anomalies_detected` | Sim | Numero de anomalias |
| `sentinel_status` | Sim | Resultado da analise Sentinel |
| `next_action` | Sim | Proxima acao do orchestrator |

## Status Indicators

| Status | Significado | Acao Subsequente |
|--------|-------------|------------------|
| ✓ SUCCESS | Tarefa completada com sucesso | Consolidar output |
| ✗ FAILED | Tarefa falhou | Retry ou escalate |
| ⚠ PARTIAL | Resultado parcial | Avaliar se suficiente |
| ⏳ TIMEOUT | Tempo excedido | Verificar stagnation |

---

**Versao**: 1.0
