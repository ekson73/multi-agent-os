# Tasks — maos-hub-console

> One worktree per task (GitHub Flow, ADR-004). DoD-gate (cascade rule): no task closes on a
> prose-judged `THEN` — logged field or golden fixture only. Depends on the registry SSOT.

## WAVE 5 — Registry + Console (operator control-plane)

- [x] **T1 `feature/<id>-registry-ssot`** — implement the registry SSOT per
  `openspec/specs/maos-hub-registry/spec.md`: auto-derive records from skill/agent frontmatter +
  promote the Phase-2 N-Tree (incompatibilities + recipes) into structured data; add `activation`,
  `license`/SPDX, `provenance`, `ttl`, `rollback`, `conflicts_with`. *Acceptance: registry validates
  against the spec; `conflicts_with` graph round-trips the Phase-2 incompatibilities.*
- [x] **T2 `feature/<id>-profile-as-gating-input`** — persist an enablement **profile SSOT**; wire the
  MAOS Hub gating to honor it (route/expose only enabled + compatible). *Acceptance: a disabled/
  conflicting tool is not routed; the decision is logged.*
- [x] **T3 `feature/<id>-console-modes`** — `maos-concierge` `setup`/`config` modes: views `preset ·
  category · use-case · context-aware · prose-intent · safe-mode`; `--help`, `--safe-mode`. ASCII
  first-class; optional HTML artifact. *Acceptance: each view renders from the registry; selection is
  conflict-checked + HITL-confirmed before it writes the profile.*
- [x] **T4 `feature/<id>-context-aware-v1`** — deterministic ranking by `work-compass` project signals,
  **reasoning shown**. *Acceptance: same input → same ranking (byte-stable); the "why" is emitted.*
- [x] **T5 `feature/<id>-prose-intent`** — prose need → bounded interview (≤3 Qs) → custom profile
  DRAFT (HITL). *Acceptance: the prose→profile mapping is shown; never auto-applies.*
- [x] **T6 `feature/<id>-activation-karpathy`** — apply the `activation` taxonomy; internalize the
  karpathy *principles* natively (credit the inspiration), repo as `opt-in`/`default-on-for-context`.

## WAVE 6 — Community integration (the front-door, ADR-007)

- [ ] **T7 `feature/<id>-slot-adapter`** — first-class slot-adapter: vendored upstream (pinned +
  provenance/SBOM) + owned shim + isolation (single-conductor) + rollback. *Acceptance: an integrated
  tool lives in its slot; upstream is update-trackable; rollback recipe present.*
- [ ] **T8 `feature/<id>-contribution-gatekeeper`** — agent reviewing inbound community PRs: advisory
  triage ON the deterministic floor (`supply-chain-sentinel` + `ai-governance-linter` + gitleaks +
  sandbox) + **mandatory HITL**; reject-by-default; never as-is; emits impact-analysis + ADR +
  changelog (adopt/adapt/reject + justification) + credit/license (`co-author-standard` +
  `THIRD_PARTY_NOTICES`) + the fallback commit. *Acceptance: a planted-malicious fixture is
  blocked by the floor; the agent never auto-accepts; all artifacts generated.*
- [ ] **T9 `feature/<id>-ttl-freshness`** — every integration carries a TTL + re-validation cadence;
  stale/abandoned/compromised upstream auto-flag + eject. *Acceptance: a stale fixture is flagged + the
  registry marks it for ejection.*
- [ ] **T10 `feature/<id>-hardened-distributor`** — MAOS-as-distributor hardening: signed releases +
  SBOM + provenance. *Acceptance: release carries signature + SBOM.*

> **WAVE 5 delivered 2026-07-02** — T1 #209(+fix #211) · T2 #210(+fix #212) · T3 #214 · T4 #215 · T5 #216 · T6 #217. Status SSOT: chapter README §"Status do hands-on".
>
> Sequencing: WAVE 5 (T1→T2 first — registry then teeth) before WAVE 6. WAVE 6's gatekeeper (T8)
> requires the deterministic floor already green (the WAVE-0 AgentShield/CI of ADR-006).
