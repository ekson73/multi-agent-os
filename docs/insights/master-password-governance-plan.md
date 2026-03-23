# Master Secret Governance — Final Solution v4.0

> PDCA Loop #4 (final) — Converged, impact-assessed, AI-agent-optimized
> Date: 2026-03-23 12:17 BRT

---

## 1. FINAL ARCHITECTURE

```text
┌───────────────────────────────────────────────────────────┐
│               SECRET GOVERNANCE — FINAL                    │
│                                                            │
│  ┌────────────────────────────────────────────────────┐   │
│  │         AWS Secrets Manager (SSOT Backend)          │   │
│  │  MVP: ~$4-20/mo | Production: evaluate Vault       │   │
│  └────────────────────┬───────────────────────────────┘   │
│                       │                                    │
│          ┌────────────┼─────────────────┐                 │
│          │                              │                  │
│  ┌───────▼──────────┐    ┌──────────────▼─────────────┐   │
│  │   ESO v2.2.0     │    │  vek-env-resolver          │   │
│  │   (K8s Bridge)   │    │  (CI/CD + Multi-plat)      │   │
│  │                  │    │                             │   │
│  │  ClusterSecret   │    │  4-level TOML hierarchy     │   │
│  │  Store → Secret  │    │  aws://path#field provider  │   │
│  │  IRSA auth       │    │  9+ CI/CD scripts           │   │
│  │  Auto-sync 1h    │    │  Fly/Render/BB/Local        │   │
│  └──────────────────┘    └─────────────────────────────┘   │
│                                                            │
│  LAYER: SOPS + KMS (git encryption, not a manager)        │
│                                                            │
│  FUTURE: Vault evaluation when ≥100 secrets or SOC2       │
│  SWAP: Change ClusterSecretStore.spec.provider (5 min)    │
└───────────────────────────────────────────────────────────┘
```

---

## 2. vek-cli ENCAPSULATION — Análise

### Pergunta: Encapsular todas as tools de secrets em vek-cli?

| Tool Nativa | Hoje no vek-cli? | Encapsular? | Justificativa |
| ----------- | ----------------- | ----------- | ------------- |
| `kubectl get externalsecret` | ❌ | ✅ **Sim** | `secrets eso status` — UX padronizada |
| `kubectl get clustersecretstore` | ❌ | ✅ **Sim** | `secrets eso store` — health check |
| `aws secretsmanager get-secret-value` | ❌ | ✅ **Sim** | `secrets sm get` — fetch simplificado |
| `flux reconcile` | ❌ (via monitor) | 🟡 Parcial | `gitops reconcile` — já planejado |
| `sops --encrypt/--decrypt` | ❌ | ✅ **Sim** | `secrets sops encrypt/decrypt` |
| `gitleaks detect` | ❌ | ✅ **Sim** | `secrets scan` — pre-commit |
| `htpasswd -nb` | ❌ | ✅ **Sim** | `secrets generate-auth` |

### Proposta: `vek-cli secrets` Module v2.0

```text
vek-cli.py secrets
├── eso status      # kubectl get externalsecret -A + clustersecretstore
├── eso create      # Create ExternalSecret CRD from template
├── eso sync        # Force ESO refresh (annotate for immediate sync)
├── sm get          # aws secretsmanager get-secret-value (formatted)
├── sm list         # aws secretsmanager list-secrets --filter
├── sm rotate       # Trigger rotation or warn if >90d
├── sops encrypt    # sops --encrypt --in-place
├── sops decrypt    # sops --decrypt (stdout only, never write plaintext)
├── scan            # gitleaks detect --source .
├── generate-auth   # htpasswd + base64 (replace old hardcoded)
└── verify          # Full health check: SM + ESO + SOPS + scan
```

### AI Agents: vek-cli vs Tools Nativas?

| Aspecto | vek-cli | Tool Nativa (kubectl, aws, sops) |
| ------- | ------- | -------------------------------- |
| **Discovery** | `--help` lista tudo | Agent precisa saber qual tool |
| **Guard-rails** | `--dry-run` padronizado | Cada tool tem flags diferentes |
| **Output** | Formatado, JSON structured | Raw, varia por tool |
| **Context** | Já carrega cluster, region, config | Agent precisa inferir/perguntar |
| **Composability** | Um comando = pipeline completo | Agent compõe N comandos |
| **Learning curve** | 1 CLI = 1 help | N CLIs × N helps |
| **AGENTS.md** | Já documentado | Cada tool separada |

### Recomendação

> [!TIP]
> **Para AI agents: vek-cli > tools nativas**
> - Agent chama `vek-cli secrets verify --dry-run` (1 comando, contexto completo)
> - vs. `kubectl get css && kubectl get es -A && aws sm list-secrets && gitleaks detect` (4 comandos)
>
> **Para humanos experts: tools nativas são válidas** para troubleshooting ad-hoc

**Conclusão**: Encapsular em vek-cli faz sentido TANTO para AI agents quanto para padronização DevOps. Mas manter acesso direto às tools nativas para troubleshooting.

---

## 3. IMPACT-FIRST RISK ASSESSMENT

| Mudança | Impact Assessment | Mitigação |
| ------- | ----------------- | --------- |
| ESO deployed | ✅ Aditivo (novo CRD, não muda nada existente) | Rollback: delete HelmRelease |
| ClusterSecretStore | ✅ Aditivo (cria nova fonte de secrets) | Rollback: delete resource |
| ExternalSecrets | ✅ Aditivo (cria K8s Secrets automaticamente) | Rollback: delete ES |
| monitoring dependsOn | ⚠️ Mudança de comportamento (monitoring aguarda ESO) | Rollback: remove dependsOn |
| secrets.py fix | ✅ Corretivo (remove vulnerabilidade) | N/A — era bug |
| Vault (futuro) | 🟡 Seria substitutivo (troca backend) | ESO abstrai — swap provider |

---

## 4. ACTIONABLE QUEUE (Final, Prioritized)

| # | Task | Prioridade | Esforço | Status |
| - | ---- | ---------- | ------- | ------ |
| 1 | ~~ESO v2.2.0 deploy~~ | — | — | ✅ Done |
| 2 | ~~ClusterSecretStore + ExternalSecrets~~ | — | — | ✅ Syncing |
| 3 | ~~secrets.py hardcoded password fix~~ | — | — | ✅ Pushed |
| 4 | **TASK-020** Remove hardcoded props | 🔴 Q1 URGENT | 2h | Backlog |
| 5 | **TASK-022** Review 10-day changes | 🔴 Q1 | 2h | Backlog |
| 6 | **TASK-006** Remediate .env | 🔴 Q1 | 1h | Backlog |
| 7 | **TASK-007** NetworkPolicies | 🟡 Q1 | 2h | IP |
| 8 | **TASK-019** Shell→Python CLI | 🟢 Q2 | 8h | Backlog |
| 9 | **TASK-021** Rename script | 🟢 Q2 | 2h | Backlog |
| 10 | **NEW** vek-cli secrets v2.0 module | 🟢 Q2 | 4h | → TASK-023 |
| 11 | **NEW** Vault production evaluation | 🟢 Q3 | 8h | → TASK-024 |
