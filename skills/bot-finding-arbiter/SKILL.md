---
name: bot-finding-arbiter
version: "1.3.0"
description: |
  Soul-name **Praetor**. Adjudicates a code-reviewer bot's finding when a build / CI /
  pipeline / PR fails or is blocked on it — and, like the Roman praetor who both judged
  cases AND published the edict that refined the law going forward, it can correct the
  bot's OWN repo-committed config file to teach the bot our governance for future reviews.
  Runs an OODA loop per finding: OBSERVE (intake the finding) → ORIENT (classify
  {valid-actionable | bot-wrong | ambiguous} with an INDEPENDENT verify — verifier >
  generator) → DECIDE one of 7 dispositions [accept-total · accept-partial+adapt · fix ·
  improve · expand · reject-total · comment/justify] → ACT (fix the code, OR reply-justify,
  OR — only when the bot is VERIFIABLY wrong — write a teaching edit to the bot's config
  file per the bot-config registry). HARD GUARDRAIL: NEVER suppress a valid security /
  logic finding; a config edit that would silence a real finding → HITL, always. Composes
  existing primitives (gh-CLI / bb-pipeline-watch intake · convergence-engine / cascade-resolver /
  perspective-trio for the verify · pr-governance disposition menu · auto-merge gate) —
  builds no new convergence machinery.
  Use when a bot flags a PR/build and you must decide what to do about the finding,
  when a reviewer bot keeps emitting the same false-positive, or when a bot's config
  should be taught your standards.
  Triggers: "the bot flagged X, what do we do", "coderabbit/qodo/copilot/amazon-q/gitleaks
  is wrong here", "teach the bot", "fix the recurring false positive", "arbitrate this
  finding", "praetor", "bot-finding-arbiter", "resolve the bot complaint on this PR",
  "o bot reclamou, o que fazemos", "ensina o bot".
allowed-tools: Task, Read, Write, Edit, Bash, Grep, Glob
---

# bot-finding-arbiter · *Praetor*

> **Praetor** — the Roman magistrate who *adjudicated disputes* AND *issued the edictum praetoris*,
> an annually-refined statement of the rules he would apply. This skill is the software praetor:
> it **judges** a reviewer-bot's finding (route to one of 7 dispositions) and, when the bot is
> verifiably wrong, **issues an edict** — a teaching edit to the bot's own repo config so the bot
> works to our governance from now on. It **composes** existing convergence primitives; it does not
> re-implement judging, verifying, commenting, or merging.

## The one non-negotiable (read first)

> ⛔ **A config edit MUST NEVER suppress a valid security or logic finding.** Editing a bot's config
> to make it stop complaining is *only* legitimate for a **verifiably-wrong** finding
> (false-positive / governance-misalignment / style-only). If the finding is a real
> secret · injection · auth flaw · CVE · correctness bug → the answer is **fix or HITL**, never
> "teach the bot to be quiet." Silencing a real finding = gaming the scanner (Goodhart) = forbidden.
> The "bot is wrong" verdict is the gate to a config edit, and that verdict is **independently
> verified** (verifier > generator) before any file is touched.

## When to use / not use
- **Use**: a build/CI/pipeline/PR is failing or blocked on a bot-code-reviewer finding and you must
  decide what to do; OR a reviewer bot emits a recurring false-positive worth teaching away.
- **Not use**: driving a whole session to green (→ `quiesce`); merely watching PR state
  (→ `gh pr checks` / `bin/bb-pipeline-watch.sh`); a finding you will simply fix inline with no arbitration needed
  (just fix it, per `pr-governance-unified` Step 4).

## Inputs
`<pr>` (number/url) · optional `<finding-selector>` (bot name / check context / comment id).
If omitted → ingest ALL open findings on the PR and arbitrate each.

## The OODA loop (per finding)

### 1 — OBSERVE (intake — reuse, don't rebuild)
- Pull the finding(s) via the existing intake, per host:
  **GitHub** → `gh pr view <pr> --json statusCheckRollup,reviews,comments` +
  `gh api repos/<owner>/<repo>/commits/<sha>/statuses` (reviews + checks + commit-statuses);
  **Bitbucket** → `bin/bb-pipeline-watch.sh` (emits each bot's verdict + comment as a parseable envelope).
- **GitHub WATCH parity (native — resolved, no wrapper built)**: to *wait* on a red/running check the way
  `bb-pipeline-watch.sh` does on Bitbucket, use the native primitive:
  `gh pr checks <pr> --watch --fail-fast --json name,bucket,description,link` (the `bucket` field is a
  parseable {pass|fail|pending|skipping|cancel} envelope; exit code 8 = still pending) + on failure
  `gh run view <run-id> --log-failed` for the error-relevant log tail — the `<run-id>` comes from the
  failing check's `link` field in the same `gh pr checks --json` output (`…/actions/runs/<run-id>/job/…`),
  or from `gh run list --branch <branch> --status failure --json databaseId`. A custom `bin/gh-checks-watch.sh`
  is intentionally NOT built — the native flags already return a structured failure diagnosis (Gordian:
  native-primitive-over-custom-machinery).
- For each finding capture: `bot` · `context` (check name) · `state` (error/failure/pending) ·
  `description` · `target_url` · the code hunk it points at.
- **Recon-before-assume (Skopos)**: read the actual finding + the code it cites before forming any verdict.

### 2 — ORIENT (classify + INDEPENDENTLY verify)
Classify the finding into exactly one bucket — and the "bot-wrong" verdict is **verified by an
independent lens** (not the same reasoning that proposed it):

| Bucket | Meaning | Verify gate (verifier > generator) |
|---|---|---|
| **valid-actionable** | the bot is right; the code should change | a deterministic oracle where one exists (test / compile / re-run the scanner on the hunk) OR a 2nd-lens read |
| **bot-wrong** | false-positive · governance-misalignment · style-only · **infra/account error** (e.g. quota, not code) | **MANDATORY** independent verify via `perspective-trio` / `cascade-resolver` / `convergence-engine` (REFINE/SELECT) OR a deterministic proof (the pattern is in our governance / the flagged file is our documented convention) |
| **ambiguous** | can't ground either way after recon | → DEFER + comment (never guess a config edit) |

- ⛔ **Security class** (secret/injection/auth/CVE/data-loss): a "bot-wrong" verdict here requires a
  deterministic proof AND is **HITL-gated** before any suppression-style config edit — no autonomous silence.
- **Account/infra error** (the bot's *platform* failed, not the code — e.g. Snyk "test limit reached",
  a scanner timeout): classify **bot-wrong → but NOT repo-fixable** (see registry `repo-fixable?` column)
  → HITL playbook, **no config edit** (a repo file cannot fix an account-side quota).
- **Deterministic pre-filter (run FIRST — the ECE deterministic skeleton):** `bin/classify.sh` (requires `jq`)
  reads the finding envelope `{bot, context, state, description}` and code-enforces the two *safety* cues before the
  probabilistic verify runs — (a) `state=error` + platform keywords → `account-error · NOT-repo-fixable · HITL`;
  (b) security substance (secret/injection/auth/CVE/data-loss) → `security-class · HITL-gated · never-suppress`;
  (c) everything else → `content · defer-to-verify` (hand to the probabilistic ORIENT above). It **only gates,
  never suppresses** — a `content` verdict always defers to the verifier. The gates are proven by
  `tests/run.sh` (7/7 fixtures, incl. gitleaks-secret → never-suppress + Snyk-quota → not-repo-fixable).

### 3 — DECIDE (the 7 dispositions)
Route the finding to exactly ONE (elevates the 5-path `pr-governance-unified` Step-8 menu to per-finding + 7-way):

| # | Disposition | When |
|---|---|---|
| 1 | **accept-total** | valid; adopt the bot's suggestion as-is |
| 2 | **accept-partial+adapt** | valid core, but adapt the suggestion to our context |
| 3 | **fix** | valid; correct the code (may differ from the bot's exact suggestion) |
| 4 | **improve** | valid + opportunity to go beyond the minimal fix |
| 5 | **expand** | valid + the finding reveals a broader gap worth addressing |
| 6 | **reject-total** | bot-wrong; the finding does not apply |
| 7 | **comment/justify** | **ALWAYS** — every disposition posts a rationale comment on the PR (reuse `pr-reviewer-communication` / `vek-pr-commentator`) |
Plus (only on a verified **bot-wrong** that IS repo-fixable): **teach-the-bot** (§4) — an edict.

### 4 — ACT
- **Code dispositions (1-5)**: apply in the worktree; converge + merge via existing gates
  (`pr-governance-unified` Steps 4/9 · `auto-merge-standing-authorization`). Do NOT rebuild convergence.
- **reject-total (6)**: post a rationale comment; if the bot supports thread-resolve, resolve it.
- **teach-the-bot (edict)**: write the minimal teaching edit to the bot's config file **per the
  registry** (`bot-config-registry.md`), as a **reviewed PR** (worktree → review → merge), NEVER a
  silent commit. Prefer a *narrow* rule (path-scoped instruction / documented-convention note) over a
  broad ignore. Record it on the Bot Scorecard (`vek-pr-commentator`) as a `config-taught` disposition
  so accuracy is tracked (the compounding win: each edict permanently shrinks future false-positives).
  - **Best-practices grounding (MANDATORY, before authoring the edict)**: consult BOTH
    (a) the bot's **official, current config documentation** (the `find-docs` skill, a docs-research
    MCP such as `mcp__ref-tools-mcp__*` when available in the host, or WebSearch —
    config surfaces drift between releases; a stale/wrong key is a silent no-op that lets the
    false-positive recur, per the registry's recon-before-assume discipline) AND
    (b) the **governance anchor** the edict encodes (`pr-governance-unified` § Bot-Config Correction
    Discipline / the repo's documented convention). The edict PR body MUST cite both — the official
    doc proves the key/syntax is *real*; the governance anchor proves the teaching is *our standard*,
    not self-serving convenience.
- **ALWAYS (7)**: the rationale comment names the disposition + the evidence (the audit trail).

## Teach-the-bot registry
The bot → config-file → what-it-teaches → **repo-fixable?** map is the SSOT in
[`bot-config-registry.md`](./bot-config-registry.md). Snyk quota / account entitlements = **NOT
repo-fixable** (dashboard) → HITL, no edit.

## Composition (reuse map — build nothing new here)
| Need | Reused primitive |
|---|---|
| intake findings | `gh` (GitHub: `pr view --json` + `api …/commits/<sha>/statuses`) · `bin/bb-pipeline-watch.sh` (Bitbucket) |
| deterministic ORIENT pre-filter (account-error / security-class gate) | `bin/classify.sh` + `tests/` fixtures (the only net-new code — a thin gate, not new convergence) |
| independent verify (verifier > generator) | `skills/convergence-engine` · `agents/perspective-trio` · `agents/cascade-resolver` · `agents/persona-pipeline` · `bin/convergence-guard` |
| disposition menu (elevated 5→7) | `rules/pr-governance-unified.md` Step 8 |
| post comment / scorecard | `.claude/rules/pr-reviewer-communication.md` · `vek-ai-toolkit:vek-pr-commentator` (Bot Scorecard) |
| merge gate | `auto-merge-standing-authorization` · `bin/convergence-guard` |
| loop discipline / OODA / no-silent-drop | `loose-end-triage-queue` (Taxis) |

## Bounds · Skip · Guardrails
- **Bounds**: ≤ the existing PDCA cap (6 iterations/PR) · verify time-boxed · one config-edit PR per bot
  per convergence · never touch `.github/workflows/` (critical-infra) autonomously → HITL.
- **Skip**: trivial single fix (just fix it inline) · read-only inspection · a finding already resolved ·
  mid-orchestration under a parent already arbitrating.
- **Guardrails**: ⛔ never suppress a valid security/logic finding · config-edit = reviewed PR never silent ·
  account/infra errors are not repo-fixable · shared-repo edits go in a worktree (concurrency).

## Anti-patterns (do NOT)
1. ❌ **Teach-the-bot to be quiet about a REAL finding** (the central forbidden move — Goodhart/security).
2. ❌ **Config edit without independent verify** (self-declared "false positive" → self-serving edit).
3. ❌ **Silent config commit** (must be a reviewed PR).
4. ❌ **Broad ignore when a narrow path-instruction suffices** (over-suppression).
5. ❌ **Treat an account/infra error as repo-fixable** (Snyk quota ≠ `.snyk` edit).
6. ❌ **Rebuild convergence / commenting / merging** (compose the existing primitives).
7. ❌ **Skip the always-comment (7)** — every disposition leaves an audit-trail rationale.

## Quality Tests (6/6 §11 self-validity + 7/7 fixtures) + grounding
1 Self-Application ✅ (built under worktree→PR→converge→merge, the very loop it arbitrates) · 2 Non-Contradiction ✅ (composes `pr-governance-unified`/`convergence-engine`/`auto-merge-standing`; zero duplication) · 3 Survival ✅ · 4 Bounded ✅ (PDCA cap · skips · one-edit-PR · never-critical-infra) · 5 Explicit-Exception ✅ (skips + HITL gates + §0 SER) · 6 Utility-Sunset ✅ (DUED below). Anti-theater 8/8 (the teach-the-bot lever is real config-as-code, empirically grounded in `.pr_agent.toml` precedent; the ⛔never-suppress-valid-security gate is now **code-proven** by `tests/run.sh` (7/7), not prose-only).

## DUED Sunset (qualitative)
Deprecate when ANY: a host ships native "arbitrate + teach reviewer bot" (E1) · absorbed into `convergence-engine`/`pr-governance-unified` as one entry (E6) · operator retraction (E4) · ≥3 false-positive suppressions slip through (E5 → tighten the verify gate, not deprecate).

## Refs
`rules/pr-governance-unified.md` (§ Bot-Config Correction Discipline — the governance this skill executes) · `bot-config-registry.md` (the SSOT map) · `skills/convergence-engine` · `agents/{perspective-trio,cascade-resolver,persona-pipeline}` · `bin/classify.sh` (deterministic ORIENT pre-filter) + `tests/run.sh` · `bin/{convergence-guard,bb-pipeline-watch.sh}` · `gh` CLI · `vek-ai-toolkit:vek-pr-commentator` (Bot Scorecard) · akasha `pr-review-protocol.md` / `auto-merge-standing-authorization.md` / `loose-end-triage-queue.md`. Named by `anima` (soul-name *Praetor*, per `[[naming-authority]]` `[C-naming]`).

## Changelog
| Version | Date | Change |
|---|---|---|
| 1.3.0 | 2026-07-01 | Residual `/enhance` Round #(N+1) — directive-triage verified the operator directive ~85-90% already satisfied by v1.2.x; this MINOR closes the 3 verified residual gaps (docs-only; `classify.sh` + `tests/` untouched, still 7/7). (a) **G-bp — explicit best-practices grounding**: the teach-the-bot edict now MANDATES consulting the bot's official current config docs (`find-docs` skill / a docs-research MCP e.g. `mcp__ref-tools-mcp__*` / WebSearch) AND the governance anchor before authoring, and citing BOTH in the edict PR (was implicit in narrowest-form; directive asks "best practices + our governance" explicitly). (b) **G-gh — GitHub watch parity resolved native**: documented `gh pr checks <pr> --watch --fail-fast --json name,bucket,…` (bucket envelope, exit 8 = pending) + `gh run view --log-failed` as the GitHub sibling of `bb-pipeline-watch.sh`; probe confirmed the native flags return a structured failure diagnosis → NO custom wrapper built (Gordian). (c) **G-fire — fire-point effectivation (cross-file)**: `skills/quiesce` v0.2.0 + `pr-governance-unified` v1.2.1 now ROUTE bot-blocked PRs / per-finding review analysis to this skill as the default handler — "toda vez que" now has an active trigger instead of a passive skill (Skopos PHASE-2 lesson: sharpen a fire-point > add passive prose). |
| 1.2.1 | 2026-07-01 | PDCA (self-dogfood — **Praetor arbitrated qodo's review of its own v1.2.0 PR #193**; 3 valid findings → all `accept-partial+adapt`, docs-only, `classify.sh` + `tests/` still 7/7). (1) **Semgrep `\|\| true`**: reframed from a neutral "teaching form" to an explicit **suppression anti-pattern** (HITL-only + alerting + expiry, never silent) — a security-class row must not read as endorsing gate-disabling (aligns with the row's own `never blanket-disable` + ⛔never-suppress). (2) **nosemgrep syntax**: `# nosemgrep` is a no-op in `//`-comment languages (JS/TS/Java) → generalized to "a comment in the flagged file's own language syntax containing `nosemgrep`" + JS/TS + Python examples (correctness). (3) **consistency**: `rules/pr-governance-unified.md` bot→config map reframed as **candidate surfaces (recon-before-assume)** so it no longer lists `.amazonq/rules/` plainly as SSOT without the confirm-first caveat the registry now carries. qodo's recurring "missing Jira key" sub-claim = known FP (repo uses Linear; already taught in `.pr_agent.toml`) → rejected, no edit. |
| 1.2.0 | 2026-07-01 | Registry `/enhance` (docs-only — `classify.sh` + `tests/` untouched, still 7/7). (a) **corrija** (anti-theater R4): the Amazon-Q row claimed `.amazonq/rules/*.md` as a teaching surface, but that is **not the observed convention** — `.amazonq/` dirs are commonly OpenSpec/prompt hosts, not reviewer-config → row marked ⚠️ confirm-first, default HITL when absent (never invent the file). (b) **melhore**: added a **Grounding discipline (recon-before-assume)** subsection — the registry entries are *candidate* surfaces; several documented config files are frequently NOT adopted (Qodo `best_practices.md` → real surface is `extra_instructions`; Amazon-Q `.amazonq/rules/`), so OBSERVE must `ls`-verify the file exists before an edict (a written-but-wrong path is a silent no-op that lets the FP recur). (c) **expande**: added a **Semgrep** row — commonly CI-registry-driven (`--config p/ci`) with no committed rule file; teach = inline `# nosemgrep: <rule-id>` + rationale (narrowest) or tune the CI invocation; ⚠️ security-class, verify-gated. Vendor-neutral (Layer-Purity clean — no repo-specific inventory hardcoded into the community skill; the per-repo map stays operator-side). |
| 1.1.0 | 2026-07-01 | Harden — (a) **corrija**: fixed the dangling `bin/pr-review-watch` GitHub-intake reference (cited 5× but the file never existed) → repointed to the real `gh` CLI (`pr view --json` + `api …/statuses`), Bitbucket stays `bb-pipeline-watch.sh`; a symmetric `bin/pr-review-watch` wrapper is a deferred nicety (gh already does it). (b) **melhore**: added `bin/classify.sh` — a deterministic ORIENT pre-filter (ECE skeleton) that code-enforces the two safety cues (account/platform-error → NOT-repo-fixable · security-class → HITL-gated never-suppress; content → defer-to-verify) + `tests/` (7 fixtures + `run.sh`, converge-style) that **prove** the ⛔never-suppress-valid-security gate (7/7 pass). The gate was prose-only in v1.0.0. **PDCA (self-dogfood — Praetor arbitrated its own PR #192)**: (i) amazon-q `:stop_sign:` → tightened bare `limit` to quota-specific phrases (accept-partial+adapt; their `test.?limit` suggestion would have broken the real "used your limit of private tests" variant → case-06); (ii) qodo → removed the ambiguous `import` cue (a code import-error is repo-fixable → defer, not dismiss → case-07), word-boundaried HTTP codes, surfaced classifier stderr on test failure, documented the `jq` dependency. `jq` required by `classify.sh`. |
| 1.0.0 | 2026-07-01 | Bootstrap — per-finding 7-way OODA disposition arbiter + teach-the-bot config-as-code edict (the greenfield capability: no prior tool wrote back to a bot's config; elevates the manual `.pr_agent.toml` + `pr-governance-unified` Known-FP precedent into a governed, multi-bot, verified loop). ⛔ never-suppress-valid-security hard gate + verifier>generator verify before any edit. Composes existing convergence/intake/comment/merge primitives (zero duplication). Soul-name *Praetor* via `anima`. |
