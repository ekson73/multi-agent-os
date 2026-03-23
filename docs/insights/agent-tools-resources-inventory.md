# Agent Tools & Resources Inventory

> **Agent**: Antigravity (Google/Gemini-2.5-Pro)
> **Inventoried**: 2026-03-23T11:20 | **Environment**: macOS/arm64
> **Principle**: Always use the best resource for each task (delegation-first)

---

## 1. Cloud & Kubernetes CLIs

| Tool | Version | Status | Use Case |
| ---- | ------- | ------ | -------- |
| `aws` | 2.33.20 | ✅ Connected (AdministratorAccess) | AWS API, EKS, ECR, KMS, IAM |
| `kubectl` | (latest) | ✅ Context: `aws-eks` | K8s cluster operations |
| `flux` | 2.7.5 | ✅ Connected | FluxCD GitOps reconciliation |
| `eksctl` | (latest) | ✅ | EKS cluster management |
| `helm` | (latest) | ✅ via Rancher Desktop | Helm chart management |
| `kustomize` | (latest) | ✅ | K8s manifest overlays |
| `kubeseal` | 0.36.1 | ⚠️ No controller in cluster | Sealed secrets encryption |
| `sops` | 3.12.2 | ✅ KMS key configured | Secret encryption (SOPS) |

## 2. Platform CLIs

| Tool | Version | Status | Use Case |
| ---- | ------- | ------ | -------- |
| `gh` | 2.88.1 | ✅ | GitHub API, PRs, issues |
| `git` | 2.50.1 | ✅ | Version control |
| `docker` | 27.2.1-rd | ✅ Rancher Desktop | Container builds |
| `fly` | 0.4.24 | ✅ | Fly.io deployments |
| `render` | 2.14.0 | ✅ | Render.com deployments |

## 3. Validation & Quality CLIs

| Tool | Version | Use Case |
| ---- | ------- | -------- |
| `yamllint` | 1.38.0 | YAML syntax validation |
| `shellcheck` | (latest) | Shell script analysis |
| `jq` | 1.7 | JSON processing |
| `yq` | 4.44.3 | YAML processing |
| `htpasswd` | (system) | Basic auth generation |
| `openssl` | (system) | TLS/cert operations |
| `envsubst` | (homebrew) | Environment variable substitution |

## 4. Languages & Runtimes

| Tool | Version | Use Case |
| ---- | ------- | -------- |
| `python3` | 3.12.7 (mise) | vek-cli, automation scripts |
| `node` | 22.22.0 (volta) | Frontend builds |
| `npm` / `npx` | 11.8.0 | Package management |

## 5. Python Packages (Key)

| Package | Version | Use Case |
| ------- | ------- | -------- |
| `PyYAML` | 6.0.1 | YAML parsing |
| `ruamel.yaml` | 0.19.1 | YAML round-trip editing |
| `requests` | 2.31.0 | HTTP client |
| `cryptography` | 46.0.4 | Encryption |
| `jsonschema` | 4.25.1 | JSON Schema validation |
| `rich` | 14.3.2 | Terminal UI |
| `typer` | 0.21.1 | CLI framework |
| `click` | 8.3.1 | CLI framework (legacy) |

## 6. vek-cli.py Commands (12 modules)

```text
cluster    — EKS cluster operations
nodegroup  — Nodegroup operations
gitops     — FluxCD GitOps operations
helm       — Helm chart operations (from helm-charts.yaml)
install    — Component installers
kustomize  — Kustomize orchestration
cleanup    — Cluster cleanup operations
monitor    — Health monitoring operations
secrets    — Secret management
template   — Template operations
iam        — IAM management
alb        — ALB target group/listener operations
```

## 7. MCP Servers

| Server | Status | Use Case |
| ------ | ------ | -------- |
| `maos-mcp-hub` | ✅ Available (no resources) | Multi-agent OS hub |
| `atlassian` | ❌ Not configured | Jira/Confluence API |

## 8. System Utilities (45 total)

All verified ✅: `curl`, `wget`, `ssh`, `tar`, `zip`, `unzip`, `base64`, `sed`, `awk`, `grep`, `find`, `xargs`, `wc`, `sort`, `uniq`, `cat`, `head`, `tail`, `tee`, `diff`, `patch`

## 9. Live Connections

| Resource | Status | Details |
| -------- | ------ | ------- |
| AWS Account | ✅ | `853982059333` (AdministratorAccess SSO) |
| EKS Cluster | ✅ | `k8s-eks-prd-002` (us-east-1) |
| FluxCD | ✅ | 6 kustomizations, 15+ HelmReleases |
| kubectl | ✅ | Context: `aws-eks`, 35 namespaces |
| GitHub | ✅ | `gh` authenticated |
| Docker | ✅ | Rancher Desktop |

## 10. Delegation Matrix

| Task Type | Best Resource |
| --------- | ------------- |
| K8s manifest validation | `kustomize build` + `yamllint` |
| K8s cluster operations | `kubectl` (read) / FluxCD (write) |
| Helm chart management | `vek-cli.py helm` (SSOT: `helm-charts.yaml`) |
| Secret encryption | `sops` (KMS) — kubeseal unavailable |
| AWS API calls | `aws` CLI |
| Git operations | `git` + `gh` |
| YAML processing | `yq` (structured) / `jq` (JSON) |
| Python automation | `python3` + `vek-cli.py` |
| Monitoring/health | `vek-cli.py monitor` + `flux get` |
| Documentation | Agent (markdown) → git commit |
| Deployment | Git push → FluxCD auto-reconcile (IaC) |

## 11. Missing / Not Configured

| Tool | Impact | Action |
| ---- | ------ | ------ |
| `kubeval` | K8s schema validation | Consider installing |
| `kube-linter` | K8s best practices linting | Consider installing |
| Sealed-secrets controller | SealedSecret CRD not functional | Use SOPS/KMS instead |
| Atlassian MCP | No Jira/Confluence API from agent | Configure MCP server |
| `boto3` (Python) | AWS SDK for Python | Install if needed |
