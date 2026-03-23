# Secret Management — Comprehensive Comparison Matrix

> **Context**: IaC GitOps (FluxCD), EKS, multi-tenant SaaS, multi-platform (EKS/Fly/Render/Bitbucket)
> **Date**: 2026-03-23 | **Agent**: Antigravity

## All Solutions Evaluated

| # | Solution | Category |
| - | -------- | -------- |
| 1 | HashiCorp Vault | Centralized secret manager |
| 2 | External Secrets Operator (ESO) | K8s operator (bridge) |
| 3 | Mozilla SOPS | Git-native encryption |
| 4 | AWS Secrets Manager | Cloud-native managed |
| 5 | Sealed Secrets (Bitnami) | K8s controller |
| 6 | AWS SSM Parameter Store | Cloud-native key-value |
| 7 | Doppler | SaaS secret manager |
| 8 | Infisical | OSS secret manager |
| 9 | `load-runtime-secrets.sh` (ours) | Custom CI/CD script |
| 10 | K8s native Secrets | Built-in (base64) |
| 11 | CSI Secrets Store Driver | K8s CSI volume |

---

## 10-Dimension Comparison

| Dimension | Vault | ESO | SOPS | AWS SM | Sealed Secrets | SSM PS | Doppler | Infisical | Our Script | K8s Native | CSI Driver |
| --------- | ----- | --- | ---- | ------ | -------------- | ------ | ------- | --------- | ---------- | ---------- | ---------- |
| **Purpose** | Centralized secrets + PKI + dynamic | Bridge external→K8s | Encrypt files in git | Managed secret store | Encrypt secrets for git | Key-value store | SaaS secret hub | OSS secret hub | CI/CD env loading | Built-in K8s | Mount secrets as volumes |
| **Context** | Enterprise multi-cloud | K8s GitOps | Git-centric IaC | AWS ecosystem | K8s-only | AWS ecosystem | Any platform | Self-hosted/SaaS | Bitbucket pipelines | Any K8s | Any K8s |
| **Scope** | All platforms | K8s namespaces | Git repos | AWS accounts | K8s clusters | AWS accounts | Projects/envs | Projects/envs | Apps × envs | Namespace | Pod-level |
| **Cloud-Agnostic** | ✅ Yes | ✅ Yes (multi-provider) | ✅ Yes (KMS/PGP/age) | ❌ AWS-only | ⚠️ K8s-only | ❌ AWS-only | ✅ Yes | ✅ Yes | ⚠️ AWS SM dep | ✅ Yes | ⚠️ Provider dep |
| **GitOps-Native** | ⚠️ External | ✅ CRD in git | ✅ Encrypted in git | ❌ External | ✅ SealedSecret in git | ❌ External | ❌ External | ⚠️ API-based | ❌ Shell | ⚠️ Plaintext risk | ❌ External |
| **Dynamic Rotation** | ✅ Dynamic secrets | ✅ Auto-sync | ❌ Manual | ✅ Native rotation | ❌ No | ⚠️ Via Lambda | ✅ Yes | ✅ Yes | ❌ Manual | ❌ Manual | ✅ Via provider |
| **Complexity** | 🔴 High (HA, unsealing) | 🟢 Low | 🟢 Low | 🟢 Low (managed) | 🟢 Low | 🟢 Low | 🟢 Low (SaaS) | 🟡 Medium | 🟡 Medium (1610 lines) | 🟢 Trivial | 🟡 Medium |
| **Cost** | Free (OSS) or $$ (HCP) | Free | Free | $0.40/secret/mo | Free | Free (<10k) | $$ (SaaS) | Free (OSS) | Free | Free | Free |
| **Resources** | Pod + storage + HA | 1 pod (operator) | CLI only (no runtime) | Managed | 1 pod (controller) | Managed | SaaS | Pod(s) | Shell only | Built-in | DaemonSet |
| **Maturity** | ✅ 10+ years | ✅ GA v2.2.0 | ✅ 7+ years | ✅ 5+ years | ⚠️ Maintenance mode | ✅ 7+ years | ✅ 3+ years | 🟡 2+ years | ✅ 1+ year (custom) | ✅ 10+ years | ✅ 3+ years |

---

## Scoring (1-5, higher = better for our context)

| Dimension | Weight | Vault | ESO | SOPS | AWS SM | Our Script |
| --------- | ------ | ----- | --- | ---- | ------ | ---------- |
| Cloud-Agnostic | 20% | 5 | 5 | 5 | 1 | 2 |
| GitOps-Native | 20% | 2 | 5 | 5 | 1 | 1 |
| Rotation | 15% | 5 | 4 | 1 | 5 | 1 |
| Complexity (inverse) | 15% | 1 | 4 | 5 | 4 | 3 |
| Cost | 10% | 3 | 5 | 5 | 3 | 5 |
| Multi-platform | 10% | 4 | 2 | 4 | 2 | 5 |
| Maturity | 5% | 5 | 4 | 5 | 5 | 3 |
| DX (local dev) | 5% | 2 | 1 | 4 | 2 | 5 |
| **Weighted Score** | | **3.15** | **4.15** | **4.10** | **2.45** | **2.55** |

---

## Recommendation: Hybrid Stack

```text
┌──────────────────────────────────────────────────────┐
│              OUR SECRET MANAGEMENT STACK              │
├──────────────────────────────────────────────────────┤
│                                                       │
│  1. ESO (score: 4.15) ──── K8s runtime secrets        │
│     └── Bridge: AWS SM → K8s Secrets (auto-sync)      │
│                                                       │
│  2. SOPS (score: 4.10) ── Git-native encrypted values │
│     └── HelmRelease inline values, ConfigMaps         │
│                                                       │
│  3. AWS SM (score: 2.45) ─ Backend store              │
│     └── Actual secrets live here (centralized)        │
│                                                       │
│  4. Our Script (score: 2.55) ─ CI/CD + local dev     │
│     └── load-runtime-secrets.sh (Fly, Render, BB)     │
│                                                       │
│  Flow:                                                │
│  AWS SM ──→ ESO ──→ K8s Secret ──→ Pod                │
│  AWS SM ──→ Script ──→ env vars ──→ CI/CD             │
│  SOPS+KMS ──→ git ──→ FluxCD ──→ K8s                 │
│                                                       │
│  NOT using: Vault (overkill), SealedSecrets (dead),   │
│  Doppler ($$), K8s native (insecure), CSI (limited)   │
└──────────────────────────────────────────────────────┘
```

## Meta-Critique: Can ONE Solution Cover All Platforms?

> User requirement: preferably ONE solution for AWS, K8s, EKS, Fly, Render, Railway

### Analysis

| Platform | Runs containers? | Native secret injection | ESO works? | Our script works? |
| -------- | --------------- | ---------------------- | ---------- | ---------------- |
| EKS (K8s) | ✅ Pods | K8s Secrets, env vars | ✅ | ⚠️ CI/CD only |
| Fly.io | ✅ Machines | `fly secrets set` | ❌ No K8s | ✅ `fly-deploy.sh` |
| Render | ✅ Services | Env groups | ❌ No K8s | ✅ `render-deploy.sh` |
| Railway | ✅ Services | Env vars | ❌ No K8s | ✅ (adaptable) |
| Bitbucket | ✅ Pipelines | Pipeline vars | ❌ No K8s | ✅ `set-pre-build-env.sh` |

### Verdict: **AWS Secrets Manager IS already the single source of truth**

```text
              ┌─────────────────────────────┐
              │   AWS Secrets Manager (SSOT) │  ← ONE source
              │   vek/database/{env}#...     │
              │   vek/monitoring/grafana#... │
              └──────────┬──────────────────┘
                         │
         ┌───────────────┼───────────────────┐
         │               │                   │
    ┌────▼────┐   ┌──────▼──────┐   ┌───────▼──────┐
    │   ESO   │   │  Our Script │   │  AWS SDK     │
    │ (K8s)   │   │  (CI/CD)   │   │  (App code)  │
    └────┬────┘   └──────┬──────┘   └───────┬──────┘
         │               │                  │
    K8s Secrets     Env vars          Runtime fetch
    (EKS pods)   (Fly/Render/BB)   (Java/Quarkus)
```

**There IS no single tool that works everywhere** — that's a fundamental constraint:
- K8s needs CRDs/operators (ESO)
- Fly/Render need CLI/env vars (our script)
- App code needs SDK (already using `aws-java-sdk-secretsmanager`)

**But AWS SM IS the single unified backend.** ESO and our script are just **platform-specific bridges** to the same store. This is the correct architecture.

### Self-Critique: What changes?

| Current State | Problem | Fix |
| ------------- | ------- | --- |
| ✅ AWS SM as SSOT | — | Already correct |
| ✅ Script for CI/CD | Works for Fly/Render/BB | Keep |
| ✅ ESO for K8s | Being deployed now | Deploying |
| 🚨 Hardcoded defaults in properties | Bypass SM entirely | **Remove defaults** (priority #1) |
| ⚠️ Script is AWS-coupled | Not agnostic | Acceptable — SM is our backend |

> [!IMPORTANT]
> The architecture is sound. The gap is NOT tooling — it's **discipline**: someone bypassed the system by hardcoding passwords as defaults in `application-*.properties`.

## Why NOT the others?

| Excluded | Reason |
| -------- | ------ |
| **Vault** | Overkill for MVP phase — needs HA, unsealing, operator overhead |
| **Sealed Secrets** | Controller not installed, project in maintenance mode, ESO supersedes |
| **Doppler** | SaaS cost, vendor lock-in |
| **Infisical** | Too new, adds another system to maintain |
| **CSI Driver** | Volume-mount only, no K8s Secret object creation |
| **K8s Native** | Base64 ≠ encryption, plaintext in etcd |
| **SSM PS** | AWS-only, no rotation policy, ESO can bridge if needed later |
