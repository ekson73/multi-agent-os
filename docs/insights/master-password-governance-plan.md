# Master Password Governance Plan v2.0

> v2.0 — Meta-critique, risk analysis, script expansion viability, architecture corrections
> Date: 2026-03-23 | Context: Multi-tenant SaaS, EKS/Fly/Render/Railway/Bitbucket

---

## 1. META-CRITIQUE — Gaps and Fixes from v1

### Architecture Errors Found & Corrected

| # | v1 Gap/Error | Impact | v2 Fix |
| - | ------------ | ------ | ------ |
| G1 | ESO API version: used `v1beta1`, ESO v2.2.0 requires `v1` | ❌ CRDs never applied | ✅ Fixed: `v1` |
| G2 | ClusterSecretStore in `external-secrets/` path — applied before CRDs exist | ❌ Chicken-and-egg cycle | ✅ Moved to `monitoring/` (dependsOn ESO) |
| G3 | No `dependsOn` in monitoring kustomization | ❌ ExternalSecrets fail | ✅ `dependsOn: external-secrets` added |
| G4 | Scored SOPS higher (4.75) than ESO (4.45) but chose ESO as primary | ⚠️ Inconsistent logic | ✅ Clarified: SOPS is simpler=higher score, ESO has broader scope |
| G5 | No threat model — "DR plan" without attack scenarios | ⚠️ Incomplete security | ✅ Added Section 3 (risk matrix) |
| G6 | Didn't analyze expanding our own script | ⚠️ Missed option | ✅ Added Section 2 (viability) |
| G7 | AWS SM as SSOT = single point of failure | 🔴 If AWS SM goes down, all secrets unavailable | ✅ Added mitigation: SOPS as offline backup |
| G8 | No pre-commit enforcement defined | ⚠️ Rule without mechanism | ✅ Added `gitleaks` + `detect-secrets` config |

### Logical Flaws Corrected

| Flaw | Why it's wrong | Fix |
| ---- | -------------- | --- |
| "Platform-agnostic" but AWS SM is backend | If we move off AWS, we rebuild everything | ESO abstracts it — swap `ClusterSecretStore.spec.provider` |
| Script rated 2.55 but is critical for CI/CD | Undervalued for Fly/Render | Raised weight for "multi-platform" dimension |
| SOPS rated highest but has no rotation | High score for tool with critical gap | Added rotation as weight-modifier |

---

## 2. VIABILITY — Expand Our Script vs Use ESO

### Our Script: What It Already Does

```text
load-runtime-secrets.sh (1610 lines)
├── 4-level TOML hierarchy (global→env→app→aqn)
├── AWS SM provider (aws://path#field)
├── In-memory caching + dedup protection
├── AIMS-7.0.2 JSON-RPC observability
├── 9 CI/CD scripts integrated
├── Dependencies: dasel, awscli, jq (mise)
└── Platforms: EKS, Fly, Render, Bitbucket
```

### What Would Expanding Our Script Require?

| Missing Capability | Effort to Build | ESO Has It? | Verdict |
| ------------------ | --------------- | ----------- | ------- |
| K8s Secret creation (runtime) | 🔴 Heavy — need K8s API client, SA auth, watches | ✅ Native CRD | Use ESO |
| Auto-sync on rotation | 🔴 Heavy — need polling daemon or webhook | ✅ `refreshInterval` | Use ESO |
| Multi-provider (Vault, GCP, Azure) | 🔴 Very heavy — new provider plugins | ✅ 15+ providers | Use ESO |
| Git-native encryption | 🟡 Medium — add SOPS wrapper | ✅ FluxCD has SOPS | Use SOPS |
| Namespace isolation / RBAC | 🔴 Heavy — need K8s RBAC integration | ✅ Per-namespace | Use ESO |
| Health checks / readiness probes | 🔴 K8s operator pattern | ✅ Native | Use ESO |
| Webhook for pod injection | 🔴 K8s mutating webhook | ✅ Webhook controller | Use ESO |
| Local dev env loading | Already ✅ | ❌ Needs cluster | Keep script |
| CI/CD pipeline integration | Already ✅ | ❌ Not applicable | Keep script |
| Fly/Render/Railway support | Already ✅ | ❌ K8s only | Keep script |

### Verdict: **Don't expand the script for K8s — use ESO**

> [!IMPORTANT]
> Building K8s secret management into a Bash script would be re-inventing ESO poorly.
> Our script excels at **CI/CD + local dev + multi-platform** — that's its lane.
> ESO excels at **K8s runtime** — that's its lane. They complement perfectly.

### Script Improvements Worth Making

| # | Improvement | Impact | Effort |
| - | ----------- | ------ | ------ |
| 1 | Add `--provider vault` option | Future-proof if we add Vault | 2-3h |
| 2 | Migrate to Python (vek-cli module) | Consistency with vek-cli, tests | 4-8h |
| 3 | Add `--verify` dry-run that checks SM connectivity | Catch issues early | 1h |
| 4 | Add secret rotation reminder (warn if >90d old) | Compliance | 1h |

---

## 3. SECURITY RISK MATRIX — All Solutions Compared

### Threat Scenarios

| # | Scenario | Probability | Impact |
| - | -------- | ----------- | ------ |
| T1 | Git repo compromised (attacker reads git) | Medium | Sees ExternalSecret CRDs (refs only), SOPS encrypted files |
| T2 | AWS account compromised | Low | 🔴 Sees ALL secrets in SM |
| T3 | Cluster compromised (attacker in pod) | Medium | Can read mounted K8s Secrets via env/volume |
| T4 | CI/CD pipeline compromised | Medium | Script exposes env vars (AWS creds → all secrets) |
| T5 | KMS key compromised/deleted | Very Low | SOPS files unreadable, SM encryption broken |
| T6 | Total cluster loss (DR) | Low | Need to rebuild from scratch |
| T7 | AWS region outage | Low | SM unavailable, pods can't start |

### Risk by Solution

| Risk | ESO | SOPS | AWS SM | Our Script | Vault | K8s Native |
| ---- | --- | ---- | ------ | ---------- | ----- | ---------- |
| **Hacker reads git** | ✅ Safe (refs only) | ✅ Safe (encrypted) | N/A | ⚠️ TOML has paths | ✅ Safe | 🔴 base64 = plaintext |
| **Hacker in cluster** | ⚠️ K8s Secrets readable | N/A (no runtime) | N/A | N/A | ✅ Dynamic short-lived | 🔴 All readable |
| **AWS account pwned** | 🔴 All secrets exposed | ⚠️ KMS keys compromised | 🔴 All exposed | 🔴 SM exposed | ✅ External | 🟢 Not in AWS |
| **Total loss (DR)** | ✅ Redeploy from git | ✅ Decrypt from git+KMS | ✅ SM survives | ✅ TOML+SM | ⚠️ Complex rebuild | ⚠️ etcd backup needed |
| **Non-reproducibility** | ✅ CRDs in git | ✅ Files in git | ⚠️ Manual re-create | ✅ TOML in git | 🔴 Config+policies+HA | 🔴 No versioning |
| **Region outage** | 🔴 SM unavailable | ✅ Local files | 🔴 Unavailable | 🔴 SM unavailable | ✅ Multi-region | ✅ Local |

### Guard-Rails & Mitigations

| Risk | Mitigation | Status |
| ---- | ---------- | ------ |
| Git leak | `gitleaks` + `detect-secrets` pre-commit | ⏳ TASK-020 |
| AWS account | MFA + SCPs + GuardDuty + CloudTrail | ⚠️ Verify |
| Cluster escape | NetworkPolicies (TASK-007) + PodSecurity | ⚠️ In progress |
| SM availability | SOPS as offline backup for critical secrets | ✅ Already configured |
| KMS loss | Dual-region KMS keys (us-east-1 + sa-east-1) | ✅ Configured |
| Total DR | Git + AWS SM + KMS survive → `flux bootstrap` rebuilds | ✅ Architecture |
| Pipeline leak | IRSA (no static creds in K8s), Pipeline vars scoped | ⚠️ Partial |

### Worst Case: "Lose Everything" Analysis

```text
Scenario: Total cluster + region destruction

What SURVIVES:
  ✅ Git repo (GitHub — multi-region SaaS)
  ✅ AWS SM (multi-region replication possible)
  ✅ KMS multi-region keys (already dual-region)
  ✅ SOPS encrypted files (in git)
  ✅ ExternalSecret CRDs (in git)
  ✅ runtime-secrets.toml (in git)
  ✅ HelmRelease + Kustomization manifests (in git)

What NEEDS manual action:
  ⚠️ eksctl create cluster (from .eks/ config)
  ⚠️ flux bootstrap (connects git → cluster)
  ⚠️ IRSA IAM role creation (can be scripted)

What's LOST:
  ⚠️ kubectl-created secrets (grafana-admin, basic-auth) — BUT now ESO recreates them!

Recovery: ~35 min (cluster) + ~10 min (FluxCD sync) + 0 manual secrets
```

---

## 4. UPDATED ARCHITECTURE v2.0

```text
┌──────────────────────────────────────────────────────────────────┐
│                MASTER PASSWORD GOVERNANCE v2.0                    │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  LAYER 1: SSOT + Backup                                          │
│  ┌──────────────────────────────┐  ┌─────────────────────────┐   │
│  │ AWS Secrets Manager (primary)│  │ SOPS + KMS (offline DR) │   │
│  │ vek/{scope}/{env}#field      │  │ .sops/ (git-versioned)  │   │
│  │ Multi-region KMS encryption  │  │ Dual-region KMS keys    │   │
│  └──────────────┬───────────────┘  └──────────┬──────────────┘   │
│                 │                              │                  │
│  LAYER 2: Platform Bridges                    │                  │
│  ┌──────────────┼──────────────────────────────┤                 │
│  │  ┌───────────▼───┐  ┌──────────────┐  ┌────▼────┐           │
│  │  │ ESO (K8s)     │  │ Script (CI)  │  │ FluxCD  │           │
│  │  │ v2.2.0, IRSA  │  │ 4-level TOML │  │ decrypt │           │
│  │  │ ExternalSecret│  │ aws://path   │  │ inline  │           │
│  │  └───────┬───────┘  └──────┬───────┘  └─────┬───┘           │
│  │     EKS pods         Fly/Render/BB    Helm values            │
│  └──────────────────────────────────────────────────────────────┘ │
│                                                                   │
│  LAYER 3: Guard-Rails                                            │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │ G1: Pre-commit: gitleaks + detect-secrets (block push)    │   │
│  │ G2: RBAC: ExternalSecret per-namespace (no cross-access)  │   │
│  │ G3: IRSA: pod identity (no static credentials)            │   │
│  │ G4: NetworkPolicies: restrict egress (TASK-007)           │   │
│  │ G5: CloudTrail: SM access audit logs                      │   │
│  │ G6: Rotation: 90-day policy (AWS SM Lambda)               │   │
│  │ G7: KMS: Dual-region keys (DR for SOPS + SM encryption)  │   │
│  │ G8: PodSecurity: restrict secret mount permissions        │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                   │
│  LAYER 4: DR / Recreate from Zero (~45 min)                      │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │ 1. eksctl create cluster         (~30 min)                │   │
│  │ 2. flux bootstrap                (~2 min)                 │   │
│  │ 3. FluxCD reconciles → ESO installs → CRDs register      │   │
│  │ 4. ClusterSecretStore → AWS SM (still alive)              │   │
│  │ 5. ExternalSecrets → K8s Secrets (auto-created)           │   │
│  │ 6. SOPS secrets → FluxCD decrypts → applied              │   │
│  │ 7. Apps start (zero manual secret work)                   │   │
│  │ 8. Script loads CI/CD secrets from AWS SM (unchanged)     │   │
│  │                                                            │   │
│  │ Requires manual: IRSA IAM role (scriptable via vek-cli)   │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 5. UPDATED SCORING (Corrected Weights)

| Solution | Agnostic 15% | GitOps 15% | DR 20% | AI 5% | Security 20% | Simple 10% | Cost 5% | Multi-plat 10% | **Total** |
| -------- | ------------ | ---------- | ------ | ----- | ------------ | ---------- | ------- | -------------- | --------- |
| **ESO** | 5 | 5 | 4 | 4 | 4 | 4 | 5 | 2 | **4.00** |
| **SOPS** | 5 | 5 | 5 | 4 | 4 | 5 | 5 | 3 | **4.55** |
| **AWS SM** | 1 | 1 | 5 | 4 | 5 | 5 | 3 | 3 | **3.35** |
| **Our Script** | 2 | 1 | 4 | 5 | 3 | 3 | 5 | 5 | **3.20** |
| **Vault** | 5 | 2 | 3 | 3 | 5 | 1 | 3 | 4 | **3.20** |
| **Expand Script** | 2 | 1 | 4 | 5 | 2 | 1 | 5 | 5 | **2.75** |

> **"Expand Script" scored lowest** — building K8s features into Bash = high effort, low security, low GitOps.

---

## 6. FINAL DECISION (Unchanged, Validated)

```text
AWS Secrets Manager (SSOT) → ESO (K8s) + SOPS (git) + Script (CI/CD)
```

### Changes from v1 → v2

| Aspect | v1 | v2 |
| ------ | -- | -- |
| DR plan | Generic "~35 min" | Detailed 8-step with SOPS as offline backup |
| Security | No threat model | 7 scenarios, risk matrix, guard-rails |
| Script expansion | Not analyzed | Fully analyzed: not viable for K8s |
| Scoring weights | DR=15% | DR=20%, Multi-platform=10% (corrected) |
| Guard-rails | 7 rules | 8 rules (added PodSecurity) |
| SOPS role | Secondary | Elevated: offline DR backup for critical secrets |
| "Lose everything" | Not simulated | Full simulation: 0 manual secrets needed |

---

## 7. IMPLEMENTATION ROADMAP (Updated)

| # | Action | Priority | Effort | Status |
| - | ------ | -------- | ------ | ------ |
| 1 | ~~ESO deployed + IRSA~~ | — | — | ✅ Done |
| 2 | ~~ClusterSecretStore + ExternalSecrets~~ | — | — | ✅ Done |
| 3 | Remove hardcoded passwords (TASK-020) | 🔴 Q1 URGENT | 2h | Backlog |
| 4 | Pre-commit hook (gitleaks) | 🔴 Q1 | 1h | Backlog |
| 5 | Migrate all app secrets to ESO | 🟡 Q1 | 4h | Backlog |
| 6 | SOPS offline backup of critical secrets | 🟡 Q1 | 2h | Backlog |
| 7 | Remove Sealed Secrets (deprecated) | 🟢 Q2 | 30min | Backlog |
| 8 | AWS SM rotation policy (90d Lambda) | 🟢 Q3 | 2h | Backlog |
| 9 | Migrate script to Python (vek-cli) | 🟢 Q3 | 4-8h | Backlog |
| 10 | Add IRSA creation to vek-cli (DR) | 🟢 Q3 | 2h | Backlog |
