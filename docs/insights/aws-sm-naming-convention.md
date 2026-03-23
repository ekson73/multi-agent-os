# AWS Secrets Manager — Naming Convention Standard

> SSOT for secret naming | Updated: 2026-03-23 | Source: runtime-secrets.toml + AWS SM inventory

## Naming Pattern

```text
/{project}/{scope}/{identifier}

Where:
  project    = vek-sales (from runtime-secrets.toml [config] aws_prefix)
  scope      = global | env | app | aqn
  identifier = varies by scope
```

## Hierarchy (4 Levels, from runtime-secrets.toml)

| Level | Scope | Pattern | Example | Purpose |
| ----- | ----- | ------- | ------- | ------- |
| 0 | config | N/A (local only) | `aws_prefix`, `aws_region` | System configuration |
| 1 | **global** | `/{project}/global` | `/vek-sales/global` | Shared across ALL apps/envs |
| 2 | **env** | `/{project}/env/{env}` | `/vek-sales/env/hml` | Per-environment overrides |
| 3 | **app** | `/{project}/app/{app-name}` | `/vek-sales/app/vks-jss-sales-api` | Per-application, all envs |
| 4 | **aqn** | `/{project}/aqn/{app-env}` | `/vek-sales/aqn/vks-jss-sales-api-hml` | Most specific (app+env) |

## Precedence (lowest → highest)

```text
[global] → [env] → [app] → [aqn]
```

Higher levels override lower. For example:
- `VEK_DB_PASSWORD` in `/vek-sales/global` is overridden by same key in `/vek-sales/env/hml`

## Reference Syntax (TOML → AWS SM)

```toml
# In runtime-secrets.toml:
VEK_DB_PASSWORD = "aws:///vek-sales/env/hml#VEK_DB_PASSWORD"
#                  ^^^   ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^
#                  proto  secret path       field name
```

## Current Inventory (21 secrets)

| Prefix | Count | Scope |
| ------ | ----- | ----- |
| `/vek-sales/global` | 1 | AWS keys, JFrog, Discord, etc. |
| `/vek-sales/env/{dev,hml,prd}` | 3 | DB, Redis, encryption per env |
| `/vek-sales/app/{name}` | 3 | App-specific (endpoint, username) |
| `/vek-sales/aqn/{name-env}` | 9 | Deploy hooks (Render) |
| `vek/monitoring/{name}` | 2 | IaC monitoring (Grafana, BasicAuth) |
| `rds-db-credentials/...` | 2 | AWS-managed (RDS auto-rotation) |
| `ecr-pullthroughcache/...` | 1 | AWS ECR pull-through cache |

## Naming Rules

1. **Leading slash**: All `/vek-sales/*` secrets use leading `/` (set by `aws_prefix`)
2. **IaC secrets** (k8s-eks-prd-002 managed): Use `vek/` prefix WITHOUT leading slash
   - Pattern: `vek/{namespace}/{purpose}`
   - Example: `vek/monitoring/grafana`
3. **AWS-managed**: Use AWS-generated names (`rds-db-credentials/`, `ecr-pullthroughcache/`)
4. **Never create** secrets outside these 3 prefixes
5. **Before creating**: Always `aws secretsmanager list-secrets --filters Key=name,Values={prefix}` to check existing

## Pre-Flight for Secret Creation

```yaml
before_creating_aws_sm_secret:
  - [ ] Check existing: aws secretsmanager list-secrets --filters Key=name,Values=vek
  - [ ] Identify scope: global, env, app, or aqn?
  - [ ] Follow naming pattern: /{project}/{scope}/{identifier}
  - [ ] For CI/CD (vek-sales): use /vek-sales/ prefix (with leading /)
  - [ ] For IaC (k8s manifests): use vek/ prefix (without leading /)
  - [ ] Never duplicate existing secrets — merge keys instead
  - [ ] Document in runtime-secrets.toml if CI/CD scope
```
