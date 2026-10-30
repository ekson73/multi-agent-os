# ADR-020: `github-app-pr-review` — one reusable reviewer workflow, one GitHub App per trust boundary, generalized only after the pilot proves it

- **Status**: Proposed (design record only; nothing is built, registered or installed by this ADR)
- **Date**: 2026-10-30
- **Deciders**: proposed by an agent session on the operator's request; the phases that create a GitHub App,
  store a secret or install anything in another repository are the repository owner's decision (see §Rollout).
- **Scope**: the design of a generic, independent agentic PR reviewer for the owner's own repositories. It does
  not change any existing skill, workflow or gate.

## Context

A private pilot repository merged an independent agentic reviewer (its ADR 0041). Measured on 2026-10-30:

| fact | value | how it was measured |
|---|---|---|
| pilot PR state | merged | `gh pr view` on the pilot PR |
| reviewer identity | a private GitHub App, only `pull_requests: write`, installed on that one repository | pilot ADR 0041 §1 |
| trigger | a `/revisao-agentica` PR comment from `OWNER`/`MEMBER`/`COLLABORATOR`, or `workflow_dispatch` on the default branch | pilot workflow `if:` |
| reviewer | Claude Code CLI pinned by lockfile, `--allowedTools Read,Glob,Grep`, `--setting-sources user`, `--strict-mcp-config`, agent config stripped from the PR checkout | pilot workflow |
| key separation | the agent job never sees the App key; a second job validates the verdict fail-closed and publishes `APPROVE`/`REQUEST_CHANGES` on the reviewed SHA | pilot workflow, jobs `revisar` / `publicar` |
| extra layers | deterministic pre-filter (injection text, invisible unicode), grounding check (cited `path@SHA#L` must exist in the base), repository-specific "reserved to owner" class | pilot ADR 0041 §8, §9, §11 |
| secrets present in the `revisao-agentica` environment | App key + App id; **`CLAUDE_CODE_OAUTH_TOKEN` absent** | `gh api .../environments/revisao-agentica/secrets` (names only) |
| real reviews run so far | **0** (`issue_comment` runs = 0) | `gh api .../actions/runs -f event=issue_comment` |
| owner's repositories | 20 non-archived (13 private, 7 public); this framework repository is public | `gh repo list` |

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
| `qodo-review`, `twg-code-review` (installed skills, not in this repo) | local diff review through a vendor service (Qodo) or Atlassian context | local, vendor-bound; no independent identity |
| [`anthropics/claude-code-action`](https://github.com/anthropics/claude-code-action) | official action: Claude Code in a workflow, supports a custom GitHub App and `claude_args` | runs the agent and the GitHub write token **in the same job**; the pilot's load-bearing property is that they never share a job |

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
| generic mechanism (workflow + scripts, this repo) | **`github-app-pr-review`** | chosen: says what it is (a PR review published by a GitHub App), English like the rest of the repo, no world prefix on a generic mechanism, honest about being GitHub-bound |
| App instance for the owner's own world | **`eko-revisor-agentico`** (bot `eko-revisor-agentico[bot]`) | the operator's proposal, **accepted for the instance**: world-prefixed, zero drift from the pilot's `*-revisor-agentico`, read by pt-BR people |
| `eko-revisor-agentico` as the generic slug | rejected | Portuguese token in an English repo fails *context* and *root*; a world prefix on a generic mechanism fails *scope* |
| `agentic-pr-reviewer` | rejected | role collision with `agents/code-reviewer.md` and `routed-pr-review`; `agentic` is jargon that does not say "App identity" |
| `revisor-agentico` | rejected | collides with the pilot's own instance name |

Availability of `eko-revisor-agentico` as an App slug is **not proven**: `GET /apps/<slug>` returns 404 for the
pilot's existing private App too, so a 404 says nothing. It is checked at registration (phase 2).

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
  - the pilot (client world) **keeps its own App**; it is never added to the shared one;
  - the shared `eko-revisor-agentico` App is installed **only** on repositories whose `main` requires a PR and
    whose `revisao-agentica` environment is restricted to `main`; a repository that fails this does not get the
    App;
  - the publish step requests the installation token **scoped to the one repository** being reviewed
    (`repositories: [<repo>]`, `pull_requests: write`), so a leaked token is one-repo even if the key is not.
- **Per-repository policy stays per repository.** Which logins a gate counts, and which paths are reserved to the
  owner, belong to each repository's own gate (the pilot's reserved class is pilot-specific). The reusable
  workflow takes an optional policy file **read from the caller's default branch**, never from the PR head, and
  publishes a plain review; it never edits any gate.

### 4. What is copied from the pilot, and what is not

Copied as-is (generic): comment/dispatch trigger and its `author_association` filter, concurrency per PR, the
two-job split, agent-config stripping, pinned CLI + lockfile, read-only tools, fail-closed verdict validation,
head-moved ⇒ do not publish, the pre-filter. Generic but optional: the grounding check (on by default). Not
copied: the pilot's reserved-class path list, its gate allowlist, its people and its message references — those
are client-world content and must not land in this public repository (run the PII/secret scan before any commit
of phase 2).

## Rejected alternatives

| alternative | why rejected |
|---|---|
| N copies of the pilot workflow, one per repo | N places to patch every fix; drift is certain |
| one App + one key for all 20 repositories, pilot included | blast radius = the weakest `main`; crosses the client/owner world boundary |
| hub repository that runs every review and posts cross-repo (key in one place only) | the App then needs `contents: read` on every repo, and the target must dispatch to the hub with a cross-repo token it does not have; more moving parts than the problem. Revisit only if per-repo key copies become the real pain |
| `anthropics/claude-code-action` as the reviewer core | same job holds the agent and the write token; its default toolset includes GitHub write operations |
| composite action | cannot hold the two-job key separation |
| build it now | the pilot has run **zero** real reviews and lacks its agent token; generalizing an unproven mechanism is over-engineering |

## Rollout (phased, each phase gated)

| phase | what | gate to start it | who |
|---|---|---|---|
| 0 | this design record | — | agent |
| 1 | pilot proves itself: owner provides the agent token; run `/revisao-agentica` on real PRs | owner provides `CLAUDE_CODE_OAUTH_TOKEN` (credential = owner) | owner + agents |
| 2 | extract the reusable workflow + scripts into this repo (no App, no secret), behind tests; the pilot switches to calling it, keeping its own App | **≥2 real reviews in the pilot that published a verdict on the reviewed SHA and were correct on audit** (green), and 0 key/agent leaks | agent (PR) |
| 3 | register `eko-revisor-agentico`, enable it on **one** owner repository with protected `main` | phase 2 merged and the pilot green again on the reusable workflow; owner registers the App and stores the key (credential = owner) | owner |
| 4 | widen to further owner repositories one at a time, each checked for protected `main` + restricted environment | ≥2 real green reviews on the phase-3 repository; subscription quota observed (below) | owner installs, agent prepares callers |

**Subscription quota.** One `CLAUDE_CODE_OAUTH_TOKEN` (the owner's Claude subscription) would serve every
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
it (or delete the App, which kills the key), delete that repository's `revisao-agentica` environment, and
re-run the repository's gate on open PRs so a review by the App stops counting.

## Refs

- Pilot: private repository, ADR 0041 (revisor agêntico por GitHub App) — not linked, private.
- [Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows) — environment
  secrets in called workflows.
- [Access to components in a private repository](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository)
  — a public repository's reusable workflow is callable by any repository; a private one only by private
  repositories of the same owner, when access is enabled.
- `skills/routed-pr-review` (lands with PR #414), `agents/code-reviewer.md`, `skills/git-cycle-sentinel`, `skills/agentic-tool-forge`,
  `skills/anima`.
