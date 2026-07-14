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
The leaf now also carries `uvx_latest_producers` (the argv-free `<pkg>@latest` token(s) of any *live*
producer — secret-safe by grammar, see the collector's ATTRIBUTION block), so a re-emergent offender is
**named**, not just counted → a future agent can look up / add its dossier without re-hunting the pid.

## Round-2 falsifications (2026-07-14) — record so no future agent wrongly contains these ⛔

Round-1 contained `deploy-on-aws`. Round-2 tested the natural follow-up hypothesis — *"do its ~20 sibling
AWS/deployment plugins from the same marketplaces (`claude-plugins-official`, `aws-claude-code-plugins`,
`claude-code-plugins-plus`, `claude-code-workflows`) carry the same `awslabs …@latest` MCP servers?"* — and
**FALSIFIED it** (robust manifest sweep, Mente Tomé). Recorded here so a future amnesic agent does **not**
re-investigate *and* does **not** mistakenly mass-contain the operator's AWS plugins (that would be a
false-positive containment + governance theater — exactly the trap Skopos Gate-0 caught):

- **`aws-*` sibling family is NOT the offender class.** `deploy-on-aws` was the *unique* carrier of the
  `awslabs uvx@latest` MCP servers. The `uvx`/`awslabs` strings that exist in the sibling marketplaces are
  all **non-offenders**: docs/SKILLs teaching how to build MCP servers, `uvx black`/`uvx ruff` *formatter*
  hooks (pinned, not `@latest` MCP churn), lockfiles, and `serena`'s own `.mcp.json`. **Do NOT contain the
  `aws-*` family** — they are not `uvx …@latest` producers.
- **`deploy-on-aws` cache-orphan is EXPECTED, not a re-drain.** After uninstall, an inert cache dir lingers
  at `~/.claude/plugins/cache/claude-plugins-official/deploy-on-aws/1.3.0/` (+ a `plugin-catalog-cache.json`
  ref). This is the known Claude-Code plugin-cache-orphan pattern (`[[reference_claude_code_plugin_cache_temp_orphans_2026_07_08]]`);
  macOS-native `.orphaned_at` 7-day GC sweeps it. It holds no live MCP config and does **not** re-inflate
  the uv cache → **no action** (do not hand-`rm` plugin cache; let native GC run).
- **The live producer seen at 18:48 (pid 28935) was TRANSIENT** — gone seconds later (the `uvx @latest`
  spawn-do-exit model; each spawn still churns the cache, but it is not a sitting runaway). This is *why*
  round-2 added the `uvx_latest_producers` attribution — to name such a spawn before it vanishes.

## Changelog

| Date | Change |
|---|---|
| 2026-07-14 (r1) | Bootstrap — inaugural vetted offender `awslabs-uvx-latest` (deploy-on-aws / awslabs uvx-@latest / `awslabs/mcp#1400` not-planned). Watch-list: computer-control-mcp, iam-policy-autopilot (fixture-only). EKO-90-ext per operator `/quiesce` ADR 2026-07-14. |
| 2026-07-14 (r2) | Round-2: recorded the **sibling-falsification** (aws-* family NOT offenders — do not contain) + the `deploy-on-aws` cache-orphan expected-not-re-drain note + the transient-producer note. Collector gains `uvx_latest_producers` attribution (name an emergent producer). No new vetted offender (recon found none). |
