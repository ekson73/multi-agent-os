# ADR-020: `github-app-pr-review` — one reusable reviewer workflow, one GitHub App per trust boundary, generalized only after the pilot proves it

- **Status**: Proposed (design record only; nothing is built, registered or installed by this ADR)
- **Date**: 2026-10-30
- **Deciders**: proposed by an agent session on the operator's request; the phases that create a GitHub App,
  store a secret or install anything in another repository are the repository owner's decision (see §Rollout).
- **Scope**: the design of a generic, independent agentic PR reviewer for the owner's own repositories. It does
  not change any existing skill, workflow or gate.

## Context

A private pilot repository merged an independent agentic reviewer. Measured on 2026-10-30:

| fact | value | how it was measured |
|---|---|---|
| pilot PR state | merged | `gh pr view` on the pilot PR |
| reviewer identity | a private GitHub App, only `pull_requests: write`, installed on that one repository | pilot design record §1 |
| trigger | a configured trigger-command PR comment from `OWNER`/`MEMBER`/`COLLABORATOR`, or `workflow_dispatch` on the default branch | pilot workflow `if:` |
| reviewer | an agent CLI pinned by lockfile, read-only tools only, no user/project settings and no MCP servers loaded, agent config stripped from the PR checkout | pilot workflow |
| key separation | the agent job never sees the App key; a second job validates the verdict fail-closed and publishes `APPROVE`/`REQUEST_CHANGES` on the reviewed SHA | pilot workflow, jobs `revisar` / `publicar` |
| extra layers | deterministic pre-filter (injection text, invisible unicode), grounding check (cited `path@SHA#L` must exist in the base), repository-specific "reserved to owner" class | pilot design record §8, §9, §11 |
| secrets present in the review environment | App key + App id; **the engine credential absent** | `gh api .../environments/<review-env>/secrets` (names only) |
| real reviews run so far | **0** (`issue_comment` runs = 0) | `gh api .../actions/runs -f event=issue_comment` |
| owner's repositories | private and public ones; this framework repository is public | `gh repo list` |

The operator asked for a generic reviewer for all of the owner's repositories, built from that pilot. The
obvious generalization is: one App installed on many repositories, plus one reusable workflow
(`on: workflow_call`) in a central repository, plus a thin caller per repository. This ADR tests that reading
before accepting it.

### Prior art measured (DRY / Strata)

| candidate | what it does | covers the intent? |
|---|---|---|
| `skills/routed-pr-review` (PR #414, open) | local dispatcher: isolated, read-only, cross-vendor review when bot reviewers are quota-blocked; satisfies C3 diversity, **never** counts as a primary approval | context isolation, read-only tools, refute-first prompt. Not CI, not an identity, not a gate approval |
| `agents/code-reviewer.md` | in-harness reviewer persona | review criteria only |
| `skills/git-cycle-sentinel` | runs the git cycle (worktree, PR, merge queue) | a natural **caller**: it can post the trigger comment. Not a reviewer |
| `skills/decision-engine` | routes HITL items DIY / COMPUTE / HITL | unrelated (no PR review) |
| vendor-bound local review skills (installed, not in this repo) | local diff review through a vendor service | local, vendor-bound; no independent identity |
| a vendor's official agent action for GitHub Actions | runs a coding agent in a workflow, can use a custom GitHub App | runs the agent and the GitHub write token **in the same job**; the pilot's load-bearing property is that they never share a job |

Coverage of the intent by the best candidate (`routed-pr-review`), one leaf per capability: isolated context ✔,
read-only tools ✔, refute-first instructions ✔, server-side trigger ✘, distinct reviewer identity ✘, key in a
separate job ✘, verdict validated fail-closed ✘, approval that a gate counts ✘ → 3/8 = 0.375 < 0.5. So: a new
artifact, which **reuses** the review criteria and refute-first prompt of `routed-pr-review` /
`agents/code-reviewer.md` instead of writing new ones.

## Decision

### 1. Type: a reusable workflow plus a thin caller, not a skill

The thing is fired by GitHub on a comment, not by a model or a human `/slash`. The forge router's best-fit type
is therefore **a reusable GitHub Actions workflow** (with its scripts), not a skill. A **composite action** is
rejected: it runs inside one job, so it cannot keep the agent job and the key job apart. A skill may come later
only as an operator-facing installer/runbook (phase 3), not as the reviewer.

### 2. Names (validated with `anima`, not stamped)

Register gate: the mechanism is an *agent*-register artifact in an English, public framework repository; the
App/bot login is a *human*-register identity that people read in PR timelines. Two different objects, so two
names (dual-name doctrine, envelope-safety).

| object | name | verdict |
|---|---|---|
| generic mechanism (workflow + scripts, this repo) | **`github-app-pr-review`** | chosen: says what it is (a PR review published by a GitHub App), English like the rest of the repo, no organization prefix on a generic mechanism, honest about being GitHub-bound |
| App instance, one per trust boundary | **`<boundary>-pr-reviewer`** (bot `<boundary>-pr-reviewer[bot]`) | chosen by an `anima` run (§2.1): en-US, an agent noun for an actor, names its one job, no engine vendor and no organization in the pattern. `<boundary>` is a label the user picks for the trust boundary and keeps in local config (§5) |
| `<boundary>-agentic-reviewer` | runner-up | closest to the pilot's original wording; loses on *scope* (does not say PR) and pays the `agentic` jargon cost that the `[bot]` suffix already covers |
| a Portuguese-language instance name | rejected (first proposal of this ADR, renamed 2026-10-30) | non-English tokens in an English framework repository fail *context* and *root*; the instance pattern is en-US and named by `anima`, not stamped |
| `agentic-pr-reviewer` | rejected | as the generic slug: role collision with `agents/code-reviewer.md` and `routed-pr-review`; `agentic` is jargon that does not say "App identity" |
| `<boundary>-code-reviewer` | rejected | sibling-role collision with `agents/code-reviewer.md` (an in-harness persona, not an identity) |
| `<boundary>-reviewer` | rejected | too broad: does not say what is reviewed |

#### 2.1 Anima run for the App instance

- **Register**: human (people read `<slug>[bot]` in PR timelines), so resonance is scored too.
- **Constraints**: GitHub App slug (lowercase, hyphens, ≤34 chars, unique on GitHub); en-US; neutral to engine
  vendor and to organization, because engines are pluggable (§5) and the pattern is reused by anyone.
- **Ontology**: the App is an *actor* that posts `APPROVE` / `REQUEST_CHANGES`, so an agent noun (`reviewer`), not
  the activity (`review`). This pairs with the mechanism: `github-app-pr-review` is the review,
  `<boundary>-pr-reviewer` is who publishes it.
- **Scorecard for `<boundary>-pr-reviewer`**: 12/12 correctness PASS (semantics and scope = PR reviewer; singular
  attributive `pr`; durable; gloss-free: "the PR reviewer of this boundary"). Resonance PASS: 5 syllables after
  the label, sayable in EN and PT, no unintended meaning. 12 chars plus the label, so a label of up to 22 chars fits.
- **Sweep**: no `*-pr-reviewer` artifact in this repository; `.claude/rules/pr-reviewer-communication.md` is a rule
  about talking to review bots, a different object.
- **Availability test** for a concrete slug: `https://github.com/apps/<slug>` (404 = free). Measured 2026-10-30:
  the check discriminates (the pilot's existing private App answers 200, a random slug 404). `GET /apps/<slug>` in
  the REST API answers 404 for the pilot's App too, so the API is not the test. Run it at registration (phase 3).
- **Pilot App**: it keeps its slug (already registered); not renamed by this ADR. New Apps follow the pattern.

### 3. Topology: one reusable workflow, one App per trust boundary — not one App for everything

The operator's reading holds for the **workflow** and is refined for the **App**:

- **Workflow — central, reused.** One `workflow_call` workflow pinned by commit SHA in each caller. The review
  logic (fetch PR, strip agent config, pre-filter, run the agent, validate, publish) lives once. A PR in a caller
  repository cannot change it, which is stronger than the pilot, where the reviewer lives in the reviewed repo.
- **Secrets — still per repository.** Measured in the GitHub docs: a reusable workflow uses the **caller's**
  environment secrets when its job sets `environment:`, and the caller must pass them by name (a missing secret
  silently resolves to an empty string unless the input is `required: true`). So a central workflow does not mean
  a central key: the App key is copied into every caller's environment.
- **App — one per trust boundary.** One App key can mint an installation token for every repository the App is
  installed on. If the same key sits in N environments, the weakest of the N `main` branches becomes the
  security of all N: anyone who can merge a workflow to `main` in one repo can approve PRs in the others. So:
  - the pilot (its own trust boundary) **keeps its own App**; it is never added to the shared one;
  - the shared `<boundary>-pr-reviewer` App is installed **only** on repositories whose `main` requires a PR and
    whose review environment is restricted to `main`; a repository that fails this does not get the
    App;
  - the publish step requests the installation token **scoped to the one repository** being reviewed
    (`repositories: [<repo>]`, `pull_requests: write`), so a leaked token is one-repo even if the key is not.
- **Per-repository policy stays per repository.** Which logins a gate counts, and which paths are reserved to the
  owner, belong to each repository's own gate (the pilot's reserved class is pilot-specific). The reusable
  workflow takes an optional policy file **read from the caller's default branch**, never from the PR head, and
  publishes a plain review; it never edits any gate.

### 4. What is copied from the pilot, and what is not

Copied as-is (generic): comment/dispatch trigger and its `author_association` filter, review only open PRs whose
head is in the same repository (no forks — this matters on public repositories), concurrency per PR, the
two-job split, agent-config stripping, pinned CLI + lockfile, read-only tools, fail-closed verdict validation,
head-moved ⇒ do not publish, the pre-filter. Generic but optional: the grounding check (on by default). Not
copied: the pilot's reserved-class path list, its gate allowlist, its people and its message references — those
are specific to the pilot's trust boundary and must not land in this public repository (run the PII/secret scan before any commit
of phase 2).

### 5. Engines are pluggable adapters; real config stays with the user

- **Engine adapter.** The reusable workflow calls the review agent through one adapter interface: input = the
  stripped PR checkout + the review prompt, output = a verdict file the publish job validates. Each engine is
  one adapter (its CLI, its read-only flags, its credential name). Phase 2 ships here only the interface, a neutral
  example adapter and its tests; it sets no engine as the default.
- **Real config is local.** Which engine, the fallback order, which App, which secret names and which
  subscription per trust boundary live in the caller repository (a config file on its default branch) or on the
  user's machine. This repository documents only the schema. Neutral example:

```yaml
# .github/pr-review.yml in the caller repository (example; values are placeholders)
boundary: example            # trust-boundary label; App slug = example-pr-reviewer
engines: [engine-a, engine-b] # adapter ids, tried in order
app_id_secret: PR_REVIEW_APP_ID
app_key_secret: PR_REVIEW_APP_KEY
engine_credential_secret: PR_REVIEW_ENGINE_TOKEN
environment: pr-review
```

- **No names in this repository.** No organization, account, e-mail, client, private repository or subscription
  is named here; trust boundaries are described as trust boundaries.

## Rejected alternatives

| alternative | why rejected |
|---|---|
| N copies of the pilot workflow, one per repo | N places to patch every fix; drift is certain |
| one App + one key for all repositories, pilot included | blast radius = the weakest `main`; crosses trust boundaries |
| hub repository that runs every review and posts cross-repo (key in one place only) | the App then needs `contents: read` on every repo, and the target must dispatch to the hub with a cross-repo token it does not have; more moving parts than the problem. Revisit only if per-repo key copies become the real pain |
| a vendor's official agent action as the reviewer core | the agent runs in the step that holds the GitHub token, and its README lists GitHub API access among the agent's default tools |
| composite action | cannot hold the two-job key separation |
| build it now | the pilot has run **zero** real reviews and lacks its agent token; generalizing an unproven mechanism is over-engineering |

## Rollout (phased, each phase gated)

| phase | what | gate to start it | who |
|---|---|---|---|
| 0 | this design record | — | agent |
| 1 | pilot proves itself: owner provides the agent token; run the trigger command on real PRs | owner provides the engine credential (credential = owner) | owner + agents |
| 2 | extract the reusable workflow + scripts into this repo (no App, no secret), behind tests; the pilot switches to calling it, keeping its own App | **≥2 real reviews in the pilot that published a verdict on the reviewed SHA and were correct on audit** (green), and 0 key/agent leaks | agent (PR) |
| 3 | register `<boundary>-pr-reviewer`, enable it on **one** owner repository with protected `main` | phase 2 merged and the pilot green again on the reusable workflow; owner registers the App and stores the key (credential = owner) | owner |
| 4 | widen to further owner repositories one at a time, each checked for protected `main` + restricted environment | ≥2 real green reviews on the phase-3 repository; subscription quota observed (below) | owner installs, agent prepares callers |

**Subscription quota.** One engine credential (for example one subscription) would serve every
repository. The trigger stays manual (comment), concurrency stays per PR, and phase 4 widens only after the
observed usage of phases 1–3 is known. No automatic `pull_request` trigger in this design.

## Risks accepted

- Same vendor family as the authoring agents: independence is of context and identity, not of model (as in the
  pilot). `routed-pr-review` remains the cross-vendor diversity rung.
- Copies of the shared App key in several environments; bounded by the "protected `main` only" install rule and
  the one-repo token scope, not removed.
- `github.job_workflow_sha` (or an equivalent) is needed so the reusable workflow checks out its own scripts at
  the pinned SHA; this is to be verified in phase 2, not assumed.

## Reversal

Phase 0: revert this file. Later phases: remove the caller workflow from a repository, uninstall the App from
it (or delete the App, which kills the key), delete that repository's review environment, and
re-run the repository's gate on open PRs so a review by the App stops counting.

## Refs

- Pilot: private repository, design record of its reviewer — not linked, private.
- [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) — environment
  secrets in called workflows.
- [Access to components in a private repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
  — a reusable workflow in a private repository is callable only from private repositories of the same owner,
  and only when that access is enabled. This framework repository is public, so a caller of a workflow here
  needs no access setting; that is why the central workflow carries no secret and no repository-specific policy.
- `skills/routed-pr-review` (lands with PR #414), `agents/code-reviewer.md`, `skills/git-cycle-sentinel`, `skills/agentic-tool-forge`,
  `skills/anima`.
