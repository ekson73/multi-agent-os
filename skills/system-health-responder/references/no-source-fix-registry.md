# No-Source-Fix Offender Registry — `offender-containment.sh` evidence gate

> The **evidence gate** for the operator ADR (2026-07-14, verbatim pt-BR): *"Até que o agentic-tool/
> plugin nao tem fix resolvido na fonte, pode desativar e/ou remover o agentic-tool e/ou plugin."*
>
> `offender-containment.sh` disables/removes a plugin **only** if it appears in the `offenders` block
> below (a machine-parsed, human-auditable list) carrying a **confirmed upstream wontfix/closed/
> not-planned + verified-date**. This makes "no source fix" *real*, not hand-waved (anti-theater · Mente
> Tomé): a tool is never contained on suspicion — only on recorded evidence. An un-vetted producer →
> the responder PROPOSES + seeds a HITL delegation to investigate (`/quiesce`'s "pesquise do que se trata"),
> never auto-contains. Adding an entry = an operator/agent judgment act (research the upstream, confirm
> no fix, record the URL + status + date). **Protected tools (`1password openclaw omniroute claude`) can
> never be entered** — the script refuses them regardless.

## Vetted offenders (ACTIONABLE — `disable` by default, `remove` only when uninstall is separately armed)

Format (one per line, `|`-delimited): `offender-id | plugin@marketplace | disable|remove | evidence`

```offenders
awslabs-uvx-latest | deploy-on-aws@claude-plugins-official | disable | awslabs/mcp#1400 "uv cache grows indefinitely" CLOSED not-planned; uvx <pkg>@latest re-resolves + writes fresh ~130MB env per new transitive dep, uv has NO auto-GC; verified 2026-07-14
```

### Evidence dossier — `awslabs-uvx-latest` (inaugural entry, 2026-07-14)

- **Producer**: `uvx awslabs.aws-iac-mcp-server@latest`, `awslabs.aws-pricing-mcp-server@latest`,
  `awslabs.aurora-dsql-mcp-server@latest` — 3 AWS Labs MCP servers shipped by the
  `deploy-on-aws@claude-plugins-official` plugin (v1.3.0), each spawned via `uvx …@latest`.
- **Mechanism**: `uvx <pkg>@latest` re-resolves from PyPI every spawn; any new transitive dependency →
  a fresh ~130 MB environment written to `~/.cache/uv/archive-v0/`. `uv` has **no automatic garbage
  collection** (`uv cache prune` is manual). N concurrent Claude sessions × repeated spawns re-inflated
  the archive faster than the disk-guardian's Tier-1 could prune the symptom → disk 926 GB → ~2.5 GB free.
- **No source fix**: `awslabs/mcp#1400` ("uv cache grows indefinitely") was **CLOSED "not planned"** —
  upstream will not fix. Same pattern independently reported at `acryldata/mcp-server-datahub#125`
  (~150 GB) and `astral-sh/uv#11432 / #9790 / #5731`. → satisfies the ADR "no fix resolved at the source".
- **Action taken (2026-07-14, operator-authorized)**: 12 producer procs killed → plugin **disabled**
  (reversible config-fix) → then **uninstalled** per the ADR. Disk 2.5 GB → 100+ GB, churn recurrence 0.
- **Durable prevention**: `uv cache prune` (this skill's `--prune`); avoid `@latest` (pin a version or
  `uv tool install`); the `system-health-guardian` collector now emits a `cache_producer` leading-indicator.
- **Registry action = `disable`** (reversible-first default). The plugin is currently *uninstalled*, so
  `plugin_present` → false → the script reports "already contained". The entry stays as the durable
  evidence trail + re-arms detection if the plugin is ever reinstalled.

## Watch-list (NOT vetted — the script does NOT act on these; propose/investigate only)

These `uvx …@latest` MCP names surfaced during the 2026-07-14 investigation but were **NOT in active
config** (only in plugin-cache docs / an episodic-memory test fixture) → **not a live producer**, not
entered above. If either becomes an *active* config source AND is confirmed no-source-fix, promote it to
the `offenders` block with its own dossier:

- `computer-control-mcp@latest` — fixture-only 2026-07-14; not active config.
- `iam-policy-autopilot@latest` — fixture-only 2026-07-14; not active config.

General watch: any `uvx …@latest` MCP server (the whole class shares the uv-no-auto-GC churn risk). The
collector's `cache_producer` leaf (`uvx_latest_procs > 0` while disk pressured) is the standing tripwire.

## Changelog

| Date | Change |
|---|---|
| 2026-07-14 | Bootstrap — inaugural vetted offender `awslabs-uvx-latest` (deploy-on-aws / awslabs uvx-@latest / `awslabs/mcp#1400` not-planned). Watch-list: computer-control-mcp, iam-policy-autopilot (fixture-only). EKO-90-ext per operator `/quiesce` ADR 2026-07-14. |
