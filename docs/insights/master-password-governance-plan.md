# Master Password Governance Plan v1.0

> **Context**: Multi-tenant SaaS, IaC GitOps (FluxCD), multi-platform (EKS/Fly/Render/Railway/Bitbucket)
> **Date**: 2026-03-23 | **Agent**: Antigravity (Google/Gemini-2.5-Pro)

---

## 1. Expanded Comparison Matrix — 20 Solutions × 15 Dimensions

### Category A: Secret Managers

| Dim | ESO | SOPS | Sealed Secrets | Vault | AWS SM | Infisical | Doppler | Our Script |
| --- | --- | ---- | -------------- | ----- | ------ | --------- | ------- | ---------- |
| **Resources** | CRD+operator (1 pod) | CLI only | CRD+controller | HA cluster | Managed | Self-hosted/SaaS | SaaS | Shell (1610 lines) |
| **Functionality** | Bridge external→K8s | Encrypt files in git | Encrypt for git | Full PKI+dynamic secrets | Store+rotate | Store+share+rotate | Store+share+sync | 4-level TOML+AWS SM |
| **Integrations** | AWS/GCP/Azure/Vault/15+ | KMS/PGP/age | K8s only | 300+ plugins | AWS ecosystem | K8s/Docker/CI | 15+ CI/CD | Bitbucket/Fly/Render |
| **Security** | RBAC+namespace isolation | KMS encryption | Asymmetric crypto | Zero-trust+audit | IAM+KMS+rotation | RBAC+E2E encryption | SOC2+RBAC | AWS IAM |
| **Governance** | Policy via Kyverno/OPA | Git audit trail | Git audit trail | Sentinel policies | CloudTrail | Audit logs | Audit+RBAC | AIMS protocol |
| **Practicality** | 🟢 Low complexity | 🟢 Trivial | 🟢 Trivial | 🔴 High (HA ops) | 🟢 Managed | 🟡 Medium | 🟢 SaaS | 🟡 Custom |
| **AI-native** | ❌ | ❌ | ❌ | ❌ | ❌ | ⚠️ API | ⚠️ API | ✅ AIMS-7.0.2 |
| **AI-ready** | ✅ YAML CRDs | ✅ Simple CLI | ✅ YAML | ✅ API+CLI | ✅ SDK+CLI | ✅ SDK+CLI | ✅ SDK+CLI | ✅ JSON-RPC |
| **AI-friendly** | ✅ Declarative | ✅ Declarative | ✅ Declarative | ⚠️ Complex config | ✅ Simple API | ✅ Simple API | ✅ Simple API | ✅ Structured output |
| **AWS SM** | ✅ Native provider | ⚠️ KMS only | ❌ | ✅ Backend | ✅ IS the store | ✅ Integration | ✅ Import | ✅ `aws://` provider |
| **Replicability** | ✅ CRDs in git | ✅ Files in git | ✅ Files in git | ⚠️ Config+policies | ⚠️ External | ⚠️ Export/import | ⚠️ Export/import | ✅ TOML in git |
| **DR** | ✅ Redeploy from git | ✅ Decrypt from git | ⚠️ Need controller key | ⚠️ Backup/restore | ✅ Multi-region | ⚠️ Backup | ✅ SaaS (managed) | ✅ TOML+AWS SM |
| **Recreate from zero** | ✅ `git push` → FluxCD | ✅ `sops -d` | ⚠️ Need cert backup | 🔴 Complex rebuild | ✅ Secrets survive | ⚠️ Re-import | ✅ SaaS persists | ✅ TOML+AWS SDK |
| **Cost** | Free | Free | Free | Free/$$HCP | $0.40/s/mo | Free/$$SaaS | $$SaaS | Free |

### Category B: IaC + GitOps + Platforms

| Dim | FluxCD | ArgoCD | Terraform | OpenTofu | Pulumi | Crossplane | Rancher | EKS | K8s native |
| --- | ------ | ------ | --------- | -------- | ------ | ---------- | ------- | --- | ---------- |
| **Resources** | 4 controllers | UI+server+repo | CLI+state | CLI+state | CLI+SaaS | K8s CRDs | UI+server | Managed | Built-in |
| **Functionality** | GitOps reconcile | GitOps+UI+SSO | IaC provisioning | IaC (TF fork OSS) | IaC (code-first) | K8s-native IaC | Multi-cluster mgmt | Managed K8s | Container orch |
| **Secret mgmt** | SOPS decrypt | Vault plugin | Vault/env vars | OPA+env vars | Native encryption | K8s secrets | Rancher secrets | IAM+IRSA | base64 (insecure) |
| **Security** | RBAC+SOPS+mTLS | RBAC+SSO+OIDC | State encryption | OPA policies | Native encryption | K8s RBAC | RBAC+PSP | IAM+KMS+IRSA | RBAC only |
| **AI-native** | ❌ | ❌ | ⚠️ AI providers | ⚠️ AI providers | ✅ Pulumi AI | ❌ | ❌ | ❌ | ❌ |
| **AI-ready** | ✅ YAML CRDs | ✅ YAML | ✅ HCL | ✅ HCL | ✅ Code (Python/TS) | ✅ YAML CRDs | ⚠️ UI-heavy | ✅ CLI+API | ✅ YAML |
| **AI-friendly** | ✅ Declarative | ✅ Declarative | ✅ Declarative | ✅ Declarative | ✅ Imperative+types | ✅ Declarative | ⚠️ UI clicks | ✅ CLI flags | ✅ Simple API |
| **DR** | ✅ Git IS the state | ✅ Git IS the state | ⚠️ State file critical | ⚠️ State file | ⚠️ State file | ✅ K8s etcd | ⚠️ Backup DB | ✅ AWS managed | ⚠️ etcd backup |
| **Recreate zero** | ✅ `flux bootstrap` | ✅ `argocd install` | ✅ `terraform apply` | ✅ `tofu apply` | ✅ `pulumi up` | ✅ Helm install | ⚠️ Complex | ✅ `eksctl create` | ✅ `kubeadm init` |
| **Cloud-agnostic** | ✅ Any K8s | ✅ Any K8s | ✅ Multi-cloud | ✅ Multi-cloud | ✅ Multi-cloud | ✅ Multi-cloud | ✅ Multi-cloud | ❌ AWS only | ✅ Any |
| **Cost** | Free | Free | Free/$$Cloud | Free | Free/$$SaaS | Free | Free/$$Enterprise | $$AWS | Free |

---

## 2. Weighted Scoring — Our Context

| Solution | Cloud-Agnostic (20%) | GitOps (20%) | DR/Recreate (15%) | AI-Ready (10%) | Security (15%) | Complexity⁻¹ (10%) | Cost (10%) | **Total** |
| -------- | -------------------- | ------------ | ------------------ | -------------- | -------------- | ------------------- | ---------- | --------- |
| **ESO** | 5 | 5 | 4 | 4 | 4 | 4 | 5 | **4.45** |
| **SOPS** | 5 | 5 | 5 | 4 | 4 | 5 | 5 | **4.75** |
| **AWS SM** | 1 | 1 | 5 | 4 | 5 | 5 | 3 | **3.20** |
| **Our Script** | 2 | 1 | 4 | 5 | 3 | 3 | 5 | **2.85** |
| **Vault** | 5 | 2 | 3 | 3 | 5 | 1 | 3 | **3.10** |
| **Infisical** | 4 | 3 | 3 | 4 | 4 | 3 | 3 | **3.40** |
| **FluxCD** | 5 | 5 | 5 | 4 | 4 | 4 | 5 | **4.65** |
| **Crossplane** | 5 | 4 | 4 | 4 | 4 | 3 | 5 | **4.15** |
| **OpenTofu** | 5 | 3 | 3 | 4 | 4 | 4 | 5 | **3.85** |

---

## 3. Master Architecture — Password Governance

```text
┌──────────────────────────────────────────────────────────────────┐
│                    MASTER PASSWORD GOVERNANCE                     │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  LAYER 1: Single Source of Truth (SSOT)                          │
│  ┌─────────────────────────────────────┐                         │
│  │ AWS Secrets Manager (us-east-1)     │ ← All secrets live here │
│  │ ├── vek/database/{env}#password     │                         │
│  │ ├── vek/monitoring/grafana#admin    │                         │
│  │ ├── vek/redis/{env}#url             │                         │
│  │ └── vek/{app}/{env}#*               │                         │
│  └──────────────┬──────────────────────┘                         │
│                 │                                                 │
│  LAYER 2: Platform Bridges (consumers)                           │
│  ┌──────────────┼──────────────────────────────────────┐         │
│  │              │                                       │         │
│  │  ┌───────────▼───┐  ┌──────────────┐  ┌───────────┐ │         │
│  │  │ ESO (K8s)     │  │ SOPS (git)   │  │ Script    │ │         │
│  │  │ ExternalSecret│  │ sops encrypt │  │ aws://    │ │         │
│  │  │ → K8s Secret  │  │ → FluxCD     │  │ → env var│ │         │
│  │  └───────┬───────┘  └──────┬───────┘  └─────┬─────┘ │         │
│  │          │                 │                │       │         │
│  │     EKS pods        Helm values       CI/CD +     │         │
│  │     (runtime)       (git-native)      Fly/Render   │         │
│  └─────────────────────────────────────────────────────┘         │
│                                                                   │
│  LAYER 3: Governance Rules                                       │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │ R1: ZERO plaintext secrets in git (enforced by pre-commit)│   │
│  │ R2: All secrets in AWS SM with vek/ prefix convention     │   │
│  │ R3: ESO for K8s, Script for CI/CD, SOPS for git values   │   │
│  │ R4: Rotation policy: 90 days (automated via AWS SM)       │   │
│  │ R5: Audit: CloudTrail + ESO sync logs + Git history       │   │
│  │ R6: DR: AWS SM survives, ESO/SOPS recreate from git       │   │
│  │ R7: Access: IRSA (K8s), Pipeline vars (CI/CD), IAM (CLI) │   │
│  └───────────────────────────────────────────────────────────┘   │
│                                                                   │
│  LAYER 4: DR / Recreate from Zero                                │
│  ┌───────────────────────────────────────────────────────────┐   │
│  │ 1. eksctl create cluster (from .eks/ config)              │   │
│  │ 2. flux bootstrap (GitRepo → auto-reconciles everything)  │   │
│  │ 3. ESO installs → ClusterSecretStore connects to AWS SM   │   │
│  │ 4. ExternalSecrets fetch → K8s Secrets auto-created       │   │
│  │ 5. Apps start with secrets from AWS SM (zero manual work) │   │
│  │ 6. SOPS secrets decrypted by FluxCD (KMS key survives)    │   │
│  │ 7. CI/CD: Script reads from AWS SM (no cluster needed)    │   │
│  │                                                            │   │
│  │ Total DR time: ~30 min (cluster) + ~5 min (FluxCD sync)   │   │
│  │ Zero secret re-creation needed (AWS SM is external SSOT)  │   │
│  └───────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
```

---

## 4. Why This Stack (Meta-Critique)

### What we chose vs alternatives

| Our Choice | Why NOT the alternative |
| ---------- | ---------------------- |
| AWS SM (backend) | Vault is overkill for MVP; Doppler is SaaS $$ |
| ESO (K8s bridge) | Sealed Secrets dead; CSI limited; native K8s insecure |
| SOPS (git encryption) | Already configured (KMS); zero runtime cost |
| Our Script (CI/CD) | Works on Fly/Render/Railway; AIMS-7.0.2 observability |
| FluxCD (GitOps) | Already deployed; ArgoCD adds UI complexity |

### Self-critique: what's NOT ideal

| Gap | Impact | Mitigation |
| --- | ------ | ---------- |
| AWS SM = not cloud-agnostic | Vendor lock-in | ESO abstracts it; swap provider = change ClusterSecretStore |
| No automated rotation | Stale passwords | AWS SM Lambda rotation (TASK backlog) |
| Hardcoded defaults in properties | Bypass entire system | **Priority #1: remove defaults** |
| Script is Bash (not Python) | Maintenance risk | Works well; refactor when needed |

---

## 5. Implementation Roadmap

| # | Action | Priority | Effort | Owner |
| - | ------ | -------- | ------ | ----- |
| 1 | ✅ ESO deployed + IRSA | Done | — | Antigravity |
| 2 | ⏳ Enable ClusterSecretStore + ExternalSecrets | Waiting ESO CRDs | 5min | Antigravity |
| 3 | 🔴 Remove hardcoded passwords from `application-*.properties` | Q1 URGENT | 2h | Dev team |
| 4 | 🟡 Add pre-commit hook to detect plaintext secrets | Q1 | 1h | DevOps |
| 5 | 🟡 Migrate all app secrets to AWS SM ExternalSecrets | Q1 | 4h | DevOps |
| 6 | 🟢 Remove Sealed Secrets (chart + files) | Q2 | 30min | DevOps |
| 7 | 🟢 AWS SM rotation policy (90d) | Q3 | 2h | DevOps |
| 8 | 🟢 Migrate to SOPS for HelmRelease inline values | Q3 | 2h | DevOps |

---

## 6. Governance SSOT References

| Document | Path |
| -------- | ---- |
| This plan | `multi-agent-os/docs/insights/master-password-governance-plan.md` |
| Comparison matrix | `multi-agent-os/docs/insights/secret-management-comparison-matrix.md` |
| Tools inventory | `multi-agent-os/docs/insights/agent-tools-resources-inventory.md` |
| ESO HelmRelease | `k8s-eks-prd-002/flux-v2/.../external-secrets/flux-helmrelease--external-secrets.yaml` |
| ClusterSecretStore | `k8s-eks-prd-002/flux-v2/.../external-secrets/k8s--clustersecretstore--aws-sm.yaml.disabled` |
| ExternalSecrets | `k8s-eks-prd-002/flux-v2/.../monitoring/k8s--externalsecrets--monitoring.yaml.disabled` |
| Runtime-secrets docs | `vks-jss-sales-api/scripts/docs/vekops-kb/.../runtime-secrets-*.md` |
