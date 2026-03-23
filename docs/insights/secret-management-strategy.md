# Secret Management Strategy — 3-Agent Analysis

> **Delegated to**: 3 specialist agents per governance protocol P2 (delegation-first)
> **Date**: 2026-03-23 | **Context**: TASK-005 Grafana secret + general IaC security

---

## Agent 1: Cloud Security Architect — Market Best Practices

### Recommendation Matrix

| Solution | Cloud-Agnostic | GitOps-Native | Dynamic Rotation | Complexity | Cost |
| -------- | -------------- | ------------- | ---------------- | ---------- | ---- |
| **ESO** (External Secrets Operator) | ✅ Yes | ✅ ExternalSecret CRD in git | ✅ Via provider | Medium | Free |
| **SOPS** (Mozilla) | ✅ Yes (KMS, PGP, age) | ✅ Encrypted in git | ❌ Manual | Low | Free |
| **HashiCorp Vault** | ✅ Yes | ⚠️ External | ✅ Dynamic secrets | High | OSS or $$ |
| **AWS Secrets Manager** | ❌ AWS-only | ❌ External | ✅ Native rotation | Low | $0.40/secret/mo |
| **Sealed Secrets** | ⚠️ K8s-only | ✅ SealedSecret in git | ❌ No | Low | Free |

### Verdict: **ESO + SOPS hybrid** (best of both worlds)

```text
SOPS  → For secrets that MUST live in git (FluxCD HelmRelease values, configs)
ESO   → For runtime secrets fetched from AWS Secrets Manager at pod startup
```

---

## Agent 2: IaC/GitOps Specialist — Our Current State

### Secret Management Landscape

| Layer | Tool | Status | Issue |
| ----- | ---- | ------ | ----- |
| **IaC (k8s-eks-prd-002)** | SOPS | ✅ Configured (.sops.yaml, dual-region KMS) | Only 1 encrypted file exists |
| **IaC** | Sealed Secrets | ❌ Chart="off", no controller | Dead end — not deployed |
| **IaC** | ESO | ❌ Chart="off", SecretStore manifest exists | **Ready to activate** |
| **App (sales-api)** | `load-runtime-secrets.sh` | ✅ Sophisticated (4-level TOML, AWS SM provider) | Shell script, not K8s-native |
| **App (sales-api)** | `application-hml.properties` | 🚨 **CRITICAL** | **Hardcoded passwords in plaintext in git** |
| **Cluster** | kubectl secrets | ⚠️ Created manually | Not GitOps (e.g., grafana-admin-credentials) |

### 🚨 Critical Security Findings in vks-jss-sales-api

```properties
# application-hml.properties — PLAINTEXT CREDENTIALS IN GIT:
quarkus.datasource.password=${VEK_DB_PASSWORD:dJOCBLn06GapAmuzHveS8w}
quarkus.redis.hosts=rediss://...:hl0vM6hlm31HDu2c@...amazonaws.com:6379
vek.db.encryption.secret.key=${VEK_DB_ENCRYPTION_SECRET_KEY:b571d5ca8981b6d5c9f8783ebc122261}
```

> [!CAUTION]
> DB password, Redis password, and encryption key are **hardcoded as default values** in properties files committed to git. Even though env vars can override them, the defaults are the real credentials exposed in version control.

---

## Agent 3: Compliance/Governance Expert — Recommendation

### Decision: ESO + AWS Secrets Manager + SOPS

```text
┌─────────────────────────────────────────────────────────┐
│                   SECRET MANAGEMENT ARCHITECTURE         │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Git (SSOT)                                             │
│  ├── ExternalSecret CRD (reference only, no values)     │
│  ├── SOPS-encrypted secrets (for helm values)           │
│  └── NO plaintext secrets (enforced by pre-commit)      │
│                                                          │
│  AWS Secrets Manager (actual secrets)                    │
│  ├── vek/database/{env}#password                        │
│  ├── vek/redis/{env}#url                                │
│  ├── vek/grafana#admin-password                         │
│  └── vek/nginx-basic-auth#auth                          │
│                                                          │
│  ESO Controller (in-cluster)                            │
│  ├── Watches ExternalSecret CRDs                        │
│  ├── Fetches from AWS Secrets Manager                   │
│  ├── Creates K8s Secrets                                │
│  └── Auto-syncs on rotation                             │
│                                                          │
│  SOPS (git-native encryption)                           │
│  ├── HelmRelease inline values needing secrets          │
│  ├── ConfigMaps with sensitive data                     │
│  └── Encrypted with dual-region KMS (already configured)│
│                                                          │
└─────────────────────────────────────────────────────────┘
```

### Why This Architecture?

| Requirement | How It's Met |
| ----------- | ------------ |
| **Cloud-agnostic** | ESO supports AWS, GCP, Azure, Vault — swap provider, keep CRDs |
| **GitOps** | ExternalSecret CRDs + SOPS files versioned in git |
| **IaC** | FluxCD reconciles ESO CRDs automatically |
| **Dynamic rotation** | AWS SM rotates → ESO syncs → pod gets new secret |
| **Compliance** | No plaintext in git, audit trail in AWS SM |
| **Multi-platform** | Works with K8s, EKS, Fly, Render (via env injection) |
| **Existing investment** | SOPS+KMS already configured, ESO SecretStore manifest exists |

### Implementation Priority (Eisenhower)

| # | Action | Priority | Effort |
| - | ------ | -------- | ------ |
| 1 | **Remove hardcoded passwords** from `application-*.properties` | Q1 URGENT | 2h |
| 2 | **Install ESO** via helm-charts.yaml (`status: "on"`) | Q1 URGENT | 1h |
| 3 | **Create ExternalSecret CRDs** for grafana, basic-auth, app secrets | Q1 | 2h |
| 4 | **Migrate sales-api secrets** to AWS SM ExternalSecrets | Q1 | 4h |
| 5 | **Add pre-commit hook** to detect plaintext secrets | Q2 | 1h |
| 6 | **Remove Sealed Secrets** (chart + files, superseded by ESO) | Q2 | 30min |
| 7 | **Add secret rotation** policy in AWS SM | Q3 | 2h |

---

## Inventory: Our `load-runtime-secrets.sh` (vks-jss-sales-api)

> Source: `scripts/load-runtime-secrets.sh` (1610 lines, AIMS-7.0.2 JSON-RPC)

### Architecture

```text
set-pre-build-env.sh
├── load-runtime-secrets.sh (1610 lines)
│   ├── runtime-secrets.toml (4-level hierarchy)
│   │   ├── [global]              — Always loaded
│   │   ├── [env.<env>]           — Per environment (dev/hml/prd)
│   │   ├── [app.<app>]           — Per application
│   │   └── [aqn.<app>-<env>]     — Per app+env combo
│   ├── AWS Secrets Manager provider (aws://path#field)
│   ├── In-memory cache (multi-field per secret)
│   ├── AIMS-7.0.2 JSON-RPC (ai_progress, ai_metric, ai_context)
│   └── Duplicate execution protection (VEK_RUNTIME_SECRETS_LOADED)
├── 20+ functions (resolve_aws_secret, cache, etc.)
└── Dependencies: dasel 2.8.1, awscli 2.15.0, jq 1.7 (mise)
```

### 9 Integrated CI/CD Scripts

`ecr-deploy.sh`, `fly-deploy.sh`, `render-deploy.sh`, `maven-build.sh`, `maven-deploy.sh`, `maven-reports.sh`, `maven-unit-tests.sh`, `discord-send.sh`, `security-scan.sh`

### Comparison: Runtime Secrets vs ESO

| Feature | `load-runtime-secrets.sh` | ESO | Verdict |
| ------- | ----------------------------- | --- | ------- |
| Provider | AWS SM only | AWS SM, Vault, GCP, Azure | ESO wins (multi-provider) |
| K8s-native | ❌ Shell script | ✅ CRD | ESO wins |
| GitOps | ❌ Manual | ✅ Declarative | ESO wins |
| Hierarchy | ✅ 4-level TOML (global→env→app→aqn) | ⚠️ Per-secret flat | Ours wins |
| CI/CD (Bitbucket) | ✅ 9 scripts integrated | ⚠️ Cluster-only | Ours wins (CI/CD) |
| Local dev | ✅ `source script` | ⚠️ Needs cluster | Ours wins (DX) |
| Caching | ✅ In-memory + duplicate guard | ✅ RefreshInterval | Tie |
| AI observability | ✅ AIMS-7.0.2 JSON-RPC | ❌ | Ours wins |
| Multi-platform | ✅ EKS, Fly, Render | ⚠️ K8s only | Ours wins |
| Rotation | ❌ Manual | ✅ Auto-sync | ESO wins |

**Conclusion**: They **complement**, not compete:
- `load-runtime-secrets.sh` → Local dev, CI/CD pipelines, non-K8s platforms (Fly, Render)
- ESO → K8s runtime secrets (pods, HelmReleases, ConfigMaps)

---

## Governance SSOT Updates Needed

| Document | Update |
| -------- | ------ |
| `k8s-eks-prd-002/AGENTS.md` | Add ESO as secret management standard |
| `helm-charts.yaml` | Change `external-secrets.status` from `"off"` to `"on"` |
| `multi-agent-os/governance-v2` | Add secret management architecture diagram |
| `vek-devops-backlog` | Create TASK for application-*.properties cleanup |
