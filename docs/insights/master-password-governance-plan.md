# Master Password Governance — PDCA Convergence v3.0

> PDCA Loop #3 — Incorporating vek-cli inventory findings
> Date: 2026-03-23 12:04 BRT

---

## PDCA Loop Summary

### Plan (v1): 11 solutions evaluated → hybrid ESO + SOPS + AWS SM + Script
### Do (v2): Deployed ESO, created IRSA, synced secrets, fixed CRD ordering
### Check (v3): New insights from vek-cli inventory

| # | New Finding | Impact on v2 |
| - | ----------- | ------------ |
| F1 | `secrets.py` has **hardcoded password** (`admin:prom-password`) | 🔴 vek-cli itself is a vulnerability |
| F2 | vek-cli has **zero ESO commands** | 🟡 No way to manage ESO via CLI |
| F3 | Script is a **config resolver**, not just secret loader | 🟡 Rename needed, role clarified |
| F4 | TASK-019 exists: migrate shell→Python | 🟢 Script will become vek-cli module |
| F5 | 4-level TOML hierarchy is the **unique differentiator** | 🟢 No solution replicates this |
| F6 | SOPS is a **supporting tool**, not a standalone solution | 🟡 Demote from "solution" to "layer" |

### Act (v3): Converge to 3 solutions + 1 layer

---

## CONVERGED: 3 Solutions + 1 Encryption Layer

```text
┌──────────────────────────────────────────────────────────────┐
│              FINAL ARCHITECTURE (3 solutions)                 │
│                                                               │
│  ┌────────────────────────────────────────────────────┐      │
│  │ SOLUTION 1: AWS Secrets Manager (SSOT Backend)     │      │
│  │ Role: Single source of truth for ALL secrets       │      │
│  │ Scope: All platforms, all environments             │      │
│  │ Score: 3.35 (low because AWS-only, but REQUIRED)   │      │
│  └────────────────────┬───────────────────────────────┘      │
│                       │                                       │
│          ┌────────────┼────────────────┐                     │
│          │                             │                      │
│  ┌───────▼──────────┐   ┌─────────────▼──────────────┐      │
│  │ SOLUTION 2: ESO  │   │ SOLUTION 3: vek-env-resolver│      │
│  │ (K8s Bridge)     │   │ (CI/CD + Multi-plat Bridge) │      │
│  │                  │   │                              │      │
│  │ Scope:           │   │ Scope:                       │      │
│  │  • EKS runtime   │   │  • Bitbucket pipelines       │      │
│  │  • K8s Secrets    │   │  • Fly.io deploys            │      │
│  │  • Auto-sync      │   │  • Render deploys            │      │
│  │  • IRSA auth      │   │  • Local development         │      │
│  │                  │   │  • 4-level TOML hierarchy     │      │
│  │ Score: 4.00      │   │  Score: 3.20 → 3.65*          │      │
│  └──────────────────┘   └──────────────────────────────┘      │
│                                                               │
│  LAYER (not solution): SOPS + KMS                            │
│  Role: Encrypt files at rest in git (FluxCD decrypts)        │
│  NOT a secret manager — it's an encryption mechanism         │
│                                                               │
│  * Score corrected: multi-platform weight increased           │
└──────────────────────────────────────────────────────────────┘
```

---

## Why 3, Not 1?

| Claim | Reality |
| ----- | ------- |
| "Use one tool for everything" | **Impossible** — K8s needs CRDs, Fly/Render need env vars |
| "Our script can do EKS too" | **Not viable** — reinventing ESO (10 missing capabilities) |
| "ESO can do CI/CD too" | **Not applicable** — ESO requires K8s cluster |
| "AWS SM directly everywhere" | **Partially true** — but each platform needs a bridge |

> **The 3 solutions are not alternatives — they're complementary layers consuming the same backend.**

---

## Corrected Risk Matrix (after PDCA)

| Threat | Mitigation | Residual Risk |
| ------ | ---------- | ------------- |
| 🔴 Hardcoded passwords in properties | TASK-020 (remove + rotate) | **Blocked on dev team** |
| 🔴 Hardcoded password in vek-cli secrets.py | Fix immediately (line 22) | **Can fix now** |
| 🟡 No pre-commit secret detection | TASK-020 (add gitleaks) | Medium |
| 🟡 AWS SM = single cloud dependency | ESO abstracts provider swap | Low |
| 🟡 Script rename pending | TASK-021 (Q2) | Low |
| 🟢 ESO not in vek-cli | Add after TASK-019 (shell→Python) | Low |

---

## Actionable Queue (Priority Order)

| # | Action | Severity | Effort | Status |
| - | ------ | -------- | ------ | ------ |
| 1 | ~~Deploy ESO v2.2.0~~ | — | — | ✅ Done |
| 2 | ~~ClusterSecretStore + ExternalSecrets~~ | — | — | ✅ Syncing |
| 3 | **Fix secrets.py hardcoded password** | 🔴 CRITICAL | 5min | **Now** |
| 4 | **TASK-020**: Remove property defaults | 🔴 CRITICAL | 2h | Backlog |
| 5 | **TASK-006**: Remediate .env | 🔴 HIGH | 1h | Backlog |
| 6 | **TASK-007**: NetworkPolicies | 🟡 HIGH | 2h | Backlog |
| 7 | **TASK-019**: Shell→Python migration | 🟢 Q2 | 8h | Backlog |
| 8 | **TASK-021**: Rename script | 🟢 Q2 | 2h | Backlog |

---

## Convergence Confirmed

After 3 PDCA iterations (Plan→v1, Do→v2, Check→v3), the architecture is **converged**:

- ✅ No new solutions needed
- ✅ No existing solution should be removed
- ✅ Roles are clearly scoped (backend / K8s bridge / CI/CD bridge)
- ✅ Gaps are identified and backlogged
- 🔴 One immediate fix: `secrets.py` hardcoded password

> [!IMPORTANT]
> **Core Swap Criterion**: If a solution/provider/architecture proves significantly better than AWS SM
> in relevant dimensions AND at comparable cost (~$0.40/secret/mo), we CAN reconsider replacement.
> ESO abstracts the backend — swap = change `ClusterSecretStore.spec.provider` only.
