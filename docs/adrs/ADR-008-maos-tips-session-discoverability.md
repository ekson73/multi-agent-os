# ADR-008: MAOS-Tips — Session-Start Discoverability Nudges

- **Status**: Accepted
- **Date**: 2026-07-10
- **Deciders**: Operator + orchestrator (council: recon 3/3 + debate/converge 3-lens + Anima naming)
- **Scope**: multi-agent-os (Layer-1 community, MIT, en-US)

## Context

MAOS ships ~116 agentic-tools (63 skills + 25 commands + 28 agents). Discovery is poor: unless a user
already knows a tool's name they won't find it, and the value of the plugin stays locked. The operator
saw the Claude Code **native `companyAnnouncements`** feature render a "Message from vek-im: VSAF…"
orange-bar banner at session start (delivered server-side by the org's Anthropic Console enterprise
policy) and asked for a MAOS-owned equivalent that teaches *which tool to use, when*.

**Recon finding**: `companyAnnouncements` is org-server-side (same channel as `organizationInstructions`),
absent from any local settings, and **not writable by a plugin** — server-side, org-only, and Layer-impure
for a community artifact. So a plugin cannot reuse that channel; the portable substitute is the
**SessionStart hook** channel (stderr human line + stdout `additionalContext`).

## Decision

Ship **MAOS-Tips**: a SessionStart hook that surfaces **one curated tip** about a maos tool per new
session, plus an on-demand command and a print-only announcements generator.

1. **Target = multi-agent-os only.** vek-ai-toolkit is out (empty `hooks.json`; Layer Purity — no
   corporate content here). A Vek overlay is a separate roadmap item.
2. **Placement = session-start (v1).** End-of-action is v2 — a context-mismatched tip mid-work is a
   credibility-killer; startup is low-risk.
3. **Frequency = 1 per session** (operator directive) — fires only on `.source ∈ {startup, clear}`
   (skip `resume`/`compact`), with `session_id` idempotency + a no-repeat seen-ledger. `MAOS_TIPS_EVERY=Nd`
   throttles further. Silenceable via `MAOS_TIPS=off` / `MAOS_NO_TIPS=1` / `~/.claude/.maos-no-tips`.
4. **Source = hybrid (curated + CI-validated).** The catalog is hand-curated (the when-to-use clause is
   UX craft) but its *integrity* is a CI gate: `tips/validate-tips.sh` fails the build if any `tool_path`
   is orphaned or a tip's family drifts from the tool's declared `metadata.family`. This kills catalog rot
   (the concierge's AWARENESS-REGISTRY drifted to "~31 skills" for 63 real — the failure mode we refuse).
5. **DRY route, not duplicate.** A tip is a 1-line PUSH nudge + a route to `maos-concierge`; depth (PULL)
   stays in the concierge. Not a skill (avoids the SKILL.md ceremony); no hardcoded version.
6. **Announcements generator = opt-in, print-only.** `--emit-announcements [N]` prints paste-ready strings
   so an operator can replicate the native banner in their *own* `settings.json` or org console. The plugin
   **never writes settings** (HUMAN_DOMAIN).
7. **Language.** en-US in the community artifact; `MAOS_TIPS_LANG=pt-br` reserved as an operator-side opt-in.

### Artifacts

| Artifact | Role |
|----------|------|
| `plugin-scripts/session-tip.sh` | SessionStart hook (5th entry) + `--print` / `--emit-announcements` / `--family` modes |
| `tips/catalog.json` | curated corpus (16 seed tips) + `families{family→{route,blurb}}` |
| `tips/inference.md` | selection logic (trigger gate · rotation+no-repeat · render · fallback) |
| `tips/validate-tips.sh` | anti-orphan CI gate (tool_path exists · family-sync · route resolves · smoke-run) |
| `commands/tip.md` | `/maos:tip` on-demand |
| `tests/governance/test-session-tip.sh` | behavior fixtures (opt-out · skip · no-repeat · idempotency · announce) |

Seen-ledger lives user-scope at `~/.claude/maos/tips-state.json` (JSON; atomic-mv + symlink-guard,
cloned from `auto-name-session.sh`), **never committed**.

## Alternatives rejected

- **Write `companyAnnouncements` from the plugin** — impossible/inappropriate (server-side, org-only,
  HUMAN_DOMAIN, Layer-impure). → print-only generator instead.
- **Hand-written catalog with no validation** — rots (proven by the concierge registry drift). → CI gate.
- **End-of-action placement in v1** — context-mismatch risk. → deferred to v2.
- **Make it a skill** — adds SKILL.md ceremony for a hook-driven nudge. → command + hook, no skill.
- **1 per day (recommended default)** — operator chose 1 per session; honored (`MAOS_TIPS_EVERY` available
  for those who want less).
- **Auto-derive tips from SKILL.md frontmatter** — the *when-to-use* phrasing is craft, not derivable
  cleanly today. → v2 (curated now; validated for integrity).

## Consequences

- **Positive**: discoverability nudge with near-zero risk (advisory, silenceable, degrades to no-op);
  catalog rot is now a build failure, not a slow drift; the announcements generator gives operators the
  native banner without the plugin touching settings.
- **Negative / cost**: the curated catalog needs occasional hand-editing as tools evolve (mitigated —
  `validate-tips.sh` makes a stale entry fail CI, so drift is caught, not shipped).
- **Security**: catalog = static strings + boolean/count signals only; never file contents/ticket
  bodies/PII; announcements are print-only.

## TTL / revisit

Revisit when: (a) tool count materially grows and hand-curation strains → build the v2 frontmatter
auto-derivation; (b) end-of-action demand emerges → v2 placement; (c) a Vek overlay is scoped →
separate corporate artifact honoring Layer Purity.

## References

- `tips/inference.md` · `tips/catalog.json` · `plugin-scripts/session-tip.sh` · `commands/tip.md`
- Native feature: Claude Code `companyAnnouncements` (org-server-side; not plugin-writable)
- Pattern precedents: `plugin-scripts/governance/single-conductor-scan.sh` (SessionStart emit),
  `plugin-scripts/governance/auto-name-session.sh` (atomic state), `statusmap/inference.md` (data+inference)
- Sibling: `skills/maos-concierge/SKILL.md` (deep onboarding — where tips route to)
