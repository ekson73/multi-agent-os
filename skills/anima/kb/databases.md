# Adapter — databases (DB · schema · table · column · index · constraint · relationship)

## Conventions
- **Case**: `snake_case`, all-lowercase, words separated by `_` (`start_date`, not `StartingDate`). Be consistent across the whole DB.
- **Tables**: noun; pick singular OR plural and hold it project-wide (`customer`/`customers` — don't mix). No vendor prefixes (`tbl_`) unless the family mandates it.
- **Columns**: singular noun naming one attribute. No cryptic abbreviations (`fn`/`ln`/`od` → `first_name`/`last_name`/`order_date`). Don't repeat the table name redundantly when context is clear.
- **Primary key**: `<table>_id` (e.g. `customer_id`). **Foreign key**: the referenced `<table>_id` (`customer_id`) — same name signals the link + the target.
- **Index naming**: prefix by purpose — `pk_<table>` · `fk_<child>_<parent>` (e.g. `fk_order_customer`) · `ix_<table>_<cols>` · `uq_<table>_<cols>`.
- **Booleans**: `is_`/`has_` prefix (`is_active`). **Timestamps**: `_at` (`created_at`). **Counts**: `_count`.

## Reserved words / limits (collision check — §5)
- **Avoid reserved keywords** as identifiers (`SELECT`, `ORDER`, `USER`, `BIGINT`, …). If unavoidable, the engine
  flags it + notes the per-engine escape: PostgreSQL `"name"` · MySQL `` `name` `` · SQL Server `[name]`.
- **Length limits** (truncate-risk check): MySQL 64 · SQL Server 128 · Oracle <12.2 = 30, ≥12.2 = 128 · PostgreSQL 63. Keep names well under the *target* engine's limit.

## Worked example
Subject: *"table holding per-tenant audit events; multi-tenant Postgres"* · `--family svc-auth-*`
→ candidates `audit_event` (singular noun, snake_case) · reject `AuditEvents` (CamelCase breaks convention),
`audit` (reserved-ish, too broad), `tenant_audit_event_log` (`_log`+`event` redundant, length).
**Decision: `audit_event`** (PK `audit_event_id`, FK to tenant `tenant_id`, index `ix_audit_event_tenant_id`).

## Sources
- Baeldung — DB/Table/Column naming conventions · MS Learn — Reserved Keywords (T-SQL) · MySQL 8.0 Identifier Length Limits.
