---
name: tip
description: Show a MAOS discoverability tip on demand (which agentic-tool to use, when) — or generate paste-ready startup announcements.
---

# /maos:tip Command

Surface a **MAOS Tip** — a one-line nudge about a maos agentic-tool (what it does, when to use it,
how to invoke it) so you get the most out of the ~116 tools in this plugin. This is the on-demand
twin of the session-start tip that fires once per new session.

## Usage

```
/maos:tip                              # one random tip now (non-mutating — never burns the session rotation)
/maos:tip --family <family>            # a tip scoped to a family (worktree-lifecycle, orchestration-convergence, …)
/maos:tip --emit-announcements [N]     # print N (default 10) paste-ready startup-announcement strings
```

## What to do

Run the tips hook in the requested mode and show its output verbatim:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/plugin-scripts/session-tip.sh" --print ${ARGUMENTS:-}
```

- Default → one random tip (`💡 MAOS Tip · <tool>: <when-to-use>. Try: /maos:<tool> · more: /maos:maos-concierge`).
- `--family <f>` → filter to that family; if none match, say so.
- `--emit-announcements [N]` → run the hook with `--emit-announcements` instead of `--print`; print the JSON array
  and the paste instructions verbatim. **Do NOT write `settings.json` / `companyAnnouncements` yourself** — that
  channel is server-side / org-managed (HUMAN_DOMAIN); the operator pastes the array.

If the operator's current work matches the surfaced tool, offer to route them to it (or to `/maos:maos-concierge`
for a guided pick). Depth lives in the concierge — a tip only points the way (DRY).

## Silencing

Session-start tips are opt-out via `MAOS_TIPS=off`, `MAOS_NO_TIPS=1`, or `~/.claude/.maos-no-tips`;
`MAOS_TIPS_EVERY=Nd` throttles them to at most one per N days. `/maos:tip` itself is always on-demand.

## Related

- `skills/maos-concierge/SKILL.md` — deep onboarding + intent→tool routing (where tips route to).
- `plugin-scripts/session-tip.sh` — the hook that powers this command.
- `tips/inference.md` — selection logic. `docs/adrs/ADR-008-*.md` — design decision + rationale.
