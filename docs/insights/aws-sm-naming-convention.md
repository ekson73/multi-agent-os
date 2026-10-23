# AWS Secrets Manager — Naming Convention Standard

> SSOT for secret naming | Updated: 2026-03-23 | Source: runtime-secrets.toml + AWS SM inventory

## Naming Pattern

```text
/{project}/{scope}/{identifier}

Where:
  project    = example-app (from runtime-secrets.toml [config] aws_prefix)
  scope      = global | env | app | aqn
  identifier = varies by scope
```

## Hierarchy (4 Levels, from runtime-secrets.toml)

| Level | Scope | Pattern | Example | Purpose |
| ----- | ----- | ------- | ------- | ------- |
| 0 | config | N/A (local only) | `aws_prefix`, `aws_region` | System configuration |
| 1 | **global** | `/{project}/global` | `/example-app/global` | Shared across ALL apps/envs |
| 2 | **env** | `/{project}/env/{env}` | `/example-app/env/hml` | Per-environment overrides |
| 3 | **app** | `/{project}/app/{app-name}` | `/example-app/app/example-sales-api` | Per-application, all envs |
| 4 | **aqn** | `/{project}/aqn/{app-env}` | `/example-app/aqn/example-sales-api-hml` | Most specific (app+env) |

## Precedence (lowest → highest)

```text
[global] → [env] → [app] → [aqn]
```

Higher levels override lower. For example:
- `APP_DB_PASSWORD` in `/example-app/global` is overridden by same key in `/example-app/env/hml`

## Reference Syntax (TOML → AWS SM)

```toml
# In runtime-secrets.toml:
APP_DB_PASSWORD = "aws:///example-app/env/hml#APP_DB_PASSWORD"
#                  ^^^   ^^^^^^^^^^^^^^^^  ^^^^^^^^^^^^^^^^
#                  proto  secret path       field name
```

## Current Inventory (21 secrets)

| Prefix | Count | Scope |
| ------ | ----- | ----- |
| `/example-app/global` | 1 | AWS keys, JFrog, Discord, etc. |
| `/example-app/env/{dev,hml,prd}` | 3 | DB, Redis, encryption per env |
| `/example-app/app/{name}` | 3 | App-specific (endpoint, username) |
| `/example-app/aqn/{name-env}` | 9 | Deploy hooks (Render) |
| `org/monitoring/{name}` | 2 | IaC monitoring (Grafana, BasicAuth) |
| `rds-db-credentials/...` | 2 | AWS-managed (RDS auto-rotation) |
| `ecr-pullthroughcache/...` | 1 | AWS ECR pull-through cache |

## Naming Rules

1. **Leading slash**: All `/example-app/*` secrets use leading `/` (set by `aws_prefix`)
2. **IaC secrets** (k8s-eks-prd-002 managed): Use `org/` prefix WITHOUT leading slash
   - Pattern: `org/{namespace}/{purpose}`
   - Example: `org/monitoring/grafana`
3. **AWS-managed**: Use AWS-generated names (`rds-db-credentials/`, `ecr-pullthroughcache/`)
4. **Never create** secrets outside these 3 prefixes
5. **Before creating**: Always `aws secretsmanager list-secrets --filters Key=name,Values={prefix}` to check existing

## Pre-Flight for Secret Creation

```yaml
before_creating_aws_sm_secret:
  - [ ] Check existing: aws secretsmanager list-secrets --filters Key=name,Values=acme
  - [ ] Identify scope: global, env, app, or aqn?
  - [ ] Follow naming pattern: /{project}/{scope}/{identifier}
  - [ ] For CI/CD (example-app): use /example-app/ prefix (with leading /)
  - [ ] For IaC (k8s manifests): use org/ prefix (without leading /)
  - [ ] Never duplicate existing secrets — merge keys instead
  - [ ] Document in runtime-secrets.toml if CI/CD scope
```
