# Dogfood — wacli Eko Almanac (verified-agentic-session-model)

**Date**: 2026-09-12
**Tool dogfooded**: `skills/verified-agentic-session-model` (PR #421)
**Feature exercised**: `wacli-concierge` / `wacli-delegate` (this PR, #418)

## What this is

A persisted, versioned copy of the "wacli Eko Almanac" — a self-governing,
portable sidecard artifact produced by `verified-agentic-session-model`'s
`bin/model-bundle.mjs render --profile portable-sidecard`. It maps this
session's own Agentic Sociotechnical Organization state, lineage, generational
capsule, and workflow for the wacli integration effort (accounts `eqm`/`eko`,
the `wacli-concierge` skill, and the `wacli-delegate` agent contract).

Three files are checked in under `agents/fixtures/wacli-eko-almanac/`, all
sharing the base name
`wacli-sidecard-agentic-artifact-ai-first-wacli-eko-almanac-verified-deli--20260912T130945Z-r44-v2.0.0--hf4e1f7fa6b6c`:

- `<base>.session-model.json` — the source session model (revision 44).
- `<base>.sidecard.html` — the deterministically rendered, CSP-hash-pinned,
  self-contained HTML artifact (open directly in a browser).
- `<base>.manifest.json` — the integrity manifest; verify with
  `node skills/verified-agentic-session-model/bin/model-bundle.mjs verify <manifest>`.

The three filenames must stay together and unrenamed: the manifest's own
subject entries reference the sibling files by their exact original names.

## Why persisted here, not left session-local

The artifact's own governance snapshot declares itself `portable=false`,
`transferable=false`, "current session-local only" — that remains true for the
*live* working copy under `~/.omp/agent/sessions/...` (an ephemeral, non-git
path). This checked-in copy is a **snapshot for delivery evidence**, not a
claim that the artifact is now a live/binding/portable authority. It exists so
the dogfood record survives past this session and is reviewable in the PR.

## Scope note (strategic placement)

The reusable **template/SSOT** (schema, renderer, tests) for
`verified-agentic-session-model` lives in `skills/verified-agentic-session-model/`
on the `verified-agentic-session-model` feature branch (PR #421) — that is the
correct home for the tool itself. This specific **Almanac instance** (the
wacli session's own data) is delivery evidence for the `wacli-concierge`/
`wacli-delegate` feature, so it lands here on this PR's branch (#418) instead
of duplicating the tool's own repo location.

> **Branch-naming note**: `CLAUDE.md`'s `{type}/{scope}-{agent-hex}` convention
> (types: `feature`/`bugfix`/`hotfix`/`docs`/`refactor`/`chore`) predates and is
> not satisfied by either PR's existing branch name (`feat/...`, no agent-hex
> suffix). Both branches were created before this doc existed; renaming a live
> branch under open review is out of proportion to a docs/fixture addition and
> risks breaking the open PRs' remote tracking. Flagged, not silently fixed by
> renaming — a branch-rename is a separate, explicit action for the PR owner.

## Verification

**Prerequisite for the full check**: `skills/verified-agentic-session-model/bin/model-bundle.mjs`
is *not* in this branch — it ships with PR #421 (branch `verified-agentic-session-model`). Run the
`model-bundle.mjs verify` line from a checkout that contains that skill (that branch, or `main`
once #421 has merged); on this branch alone it fails with a missing-file error, by design.

```bash
gitleaks dir agents/fixtures/wacli-eko-almanac --no-banner   # clean, 2026-09-12
# Full verification — requires the #421 skill (see prerequisite above):
node skills/verified-agentic-session-model/bin/model-bundle.mjs verify \
  "agents/fixtures/wacli-eko-almanac/wacli-sidecard-agentic-artifact-ai-first-wacli-eko-almanac-verified-deli--20260912T130945Z-r44-v2.0.0--hf4e1f7fa6b6c.manifest.json"
# → {"ok":true,"effective_status":"VALIDATED"}
```

**Checkout-local fallback (works on this branch, no extra tooling)** — recompute the manifest's
subject digests against the sibling files; both must print `True`:

```bash
cd agents/fixtures/wacli-eko-almanac && python3 -c '
import json, hashlib
m = json.load(open("wacli-sidecard-agentic-artifact-ai-first-wacli-eko-almanac-verified-deli--20260912T130945Z-r44-v2.0.0--hf4e1f7fa6b6c.manifest.json"))
for s in m["subjects"]:
    print(s["role"], hashlib.sha256(open(s["path"], "rb").read()).hexdigest() == s["digest"]["value"])
'
# → source True / sidecard_html True   (re-run 2026-09-12, this branch)
```

This fallback proves file integrity only (the subjects are the bytes the manifest signed); the
CSP-hash, embedded-block, and status-derivation checks need the full verifier.

---
Signed-by: Claude-Dogfood-418a-001 · 2026-09-12T13:35:00Z
