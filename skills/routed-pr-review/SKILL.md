---
name: routed-pr-review
description: >
  Dispatch an independent, context-isolated PR review when the configured review
  bots are quota-blocked, absent, or past their measured latency — instead of
  waiting on them or fabricating a green. Soul-name Euthyna (εὔθυνα, the
  independent end-of-term audit of an Athenian magistrate, conducted by officials
  who were not the magistrate). Isolation is BY CONSTRUCTION: a fresh OS process
  in a different vendor family, read-only tools, no delegator history, prompted to
  REFUTE rather than approve. Reports a gate verdict that never overstates itself —
  a routed review satisfies the C3 *diversity* limb only and NEVER a configured
  primary's verdict. Use when a PR needs reviewing while blocked, when "all bots
  rate-limited" would otherwise stall a merge queue, or when a verifier
  independent of the author is required on a harness that cannot spawn one.
  Do NOT use to manufacture convergence on a PR whose primary is still pending.
---

# routed-pr-review · Euthyna

## The problem this exists for

Review bots are the independent verifier in the house merge gate. They also run
out of quota. The observed failure mode is not the outage itself — it is what an
agent does next:

- **waits** on a bot that answered at ~8h and again after 2 days
  (`pr-review-protocol.md` §4.1, empirical `multi-agent-os#386`), or
- **declares green** from a local lint pass, which
  `ai-code-review-bots-rotation.md` §5 explicitly forbids: a deterministic local
  pass is *partial evidence, NOT a review*, or
- **self-reviews**, which is the structural blind spot —
  `cross-harness-red-team.md` records a defect that survived **six** self-run
  refine rounds *including the two passes that existed to catch it*, and fell in
  cycle 1 of a fresh-process critic.

Empirical origin: `2026-09-03`, `ekson73/eko-engram#42`. CodeRabbit stalled on an
exhausted hourly quota. A delegated reviewer with isolated context found **two
real defects that had already been published** — a path fabricated by a `sed` on a
bare stem, and an `id:` field whose convention had been measured from too narrow a
sample. Neither was found by the author across several self-review passes.

## What it does

```bash
skills/routed-pr-review/bin/routed-review.sh --pr 42 --json
skills/routed-pr-review/bin/routed-review.sh --pr 42 --post          # stamp the PR
ROUTED_REVIEW_CALLER=claude skills/routed-pr-review/bin/routed-review.sh --pr 42
```

Five phases:

| phase | what | grounding |
|---|---|---|
| **A** resolve | PR, title, `headRefOid`, diff | `gh` |
| **B** primary probe | classify every reviewer that has *ever* spoken on this repo: cleared-for-head · stale/earlier-head · quota-signalled · changes-requested. Absence is proven by **positive evidence only** | `pr-review-protocol.md` §4.1(a); bot-message taxonomy from `review-bot-quota-recovery.md` |
| **C** pick reviewer | capability-detect `command -v`, skip bots expired in `~/.claude/state/ai-review-bots.json`, **exclude the caller's own family** | `ai-code-review-bots-rotation.md` §2/§3 |
| **D** isolated run | fresh OS process, read-only tools, refute-first prompt, timeout floor 500s | `cross-harness-red-team.md` |
| **E** gate verdict | emit what this *does* and *does not* satisfy; optionally post the canonical stamp | `pr-review-protocol.md` §4.1(e) |

## The gate contract — the part that matters most

⛔ **A routed review is never a configured primary's verdict.** `§4.1(e)` is
unambiguous and this tool implements it rather than arguing with it:

| limb | routed review |
|---|---|
| C3 *diversity* (independent cross-brand opinion) | **satisfies** |
| A configured primary's verdict on the current head | **never satisfies** |
| Dismissing an active `CHANGES_REQUESTED` | **never** |
| Completing convergence alone | only where **no** primary is configured (positively evidenced) **or** every primary has already cleared |

`may_complete_c3` is computed, not asserted, and the exit code carries it:
`0` = review produced and may complete C3 · `3` = review produced **but a primary
is still pending** · `2` = no reviewer available / empty output · `1` = error.

**A `Reviewed-By:` stamp is a claim, not evidence** (§4.1(e)). The comment
therefore always embeds the reviewer's *actual output* and the head SHA it
examined. A stamp with no substantive body does not satisfy the diversity limb —
treat it as absent.

## Isolation — enforced, not requested

Independence has two axes and both must hold. Only the first is about context.

### Axis 1 — context independence

| tier | mechanism | independence |
|---|---|---|
| **weak** | in-harness blank subagent | starts with no conversation history, but the parent authors its prompt (bias channel) and it shares the model family → **correlated verifier** |
| **strong** (this tool's default) | fresh OS process, different vendor family, no delegator history | independent by construction — different blind spots |

`cross-harness-red-team.md` §Must-not forbids counting a self-run critique as the
independent cycle. Tier-weak is documented here so a future agent does not
mistake it for tier-strong; it is not what this dispatcher does.

### Axis 2 — read-only enforcement (⚠️ the defect this section exists to close)

**3 of 11 harnesses expose a read-only switch; this dispatcher actually passes
2 of them.** Asking the other 9 nicely is not enforcement, and a doc that says
"read-only tools" while running an unflagged CLI in the live worktree is a false
claim — exactly the class this tool's own reviewer prompt rates *at least major*.
So enforcement is split by capability, and the classification is allowed to
depend ONLY on a flag the code genuinely passes:

| class | harnesses | mechanism |
|---|---|---|
| `vendor` (2) | `codex` (`--sandbox read-only`), `claude` (`--allowedTools`) | the CLI guarantees it; cwd = live repo |
| `os` (9) | everything else, **including `grok`** | cwd = a **disposable `git archive` export** of the head tree: every path `chmod a-w`, and **no `.git` at all**, so a git mutation is not even expressible |

`grok` exposes `--allow-rule` (alias `--allowedTools`) and is nevertheless `os`:
**this dispatcher does not pass that flag**, and classifying on an unpassed flag
is the same false-claim class the tool exists to catch. Promotion to `vendor`
requires the flag to be passed *and* proven in a recorded run — not merely to
exist in `--help`.

The `os` class is then **proven**, not trusted: a `sha256` manifest is taken
before locking and recompared after the run. A single byte of drift ⇒ the run
exits `1` with `isolation_violated`, and **nothing is stamped or reported as a
valid review**. The enforcement class and the tamper-check result ride in both
the PR comment and the JSON, so a consumer can audit the isolation claim instead
of believing it.

> **Two defects were caught before this shipped, by two independent verifiers.**
> (1) An advisory caught the original dispatcher running all unflagged harnesses
> in `$PWD` while the doc claimed read-only — the doc was ahead of the code.
> (2) Dogfood cycle 1 (`codex`, isolated) then caught that `grok` was still
> classified `vendor` on a flag the fixed code never passed — the same defect
> surviving for one harness, now *asserted* as enforced. Neither was found by
> the author.

## Reviewer invocation table

`evidence` is load-bearing: **proven** = executed successfully in a recorded run;
**measured** = flag confirmed present in this host's `--help` at build time
(`2026-09-03`). Never add a row without one.

| harness | invocation | enforcement class | evidence |
|---|---|---|---|
| `codex` | `codex exec --sandbox read-only --cd DIR` | `vendor` — sandbox | proven (`--cd` measured) |
| `claude` | `claude -p … --max-turns N --allowedTools Read Grep Glob --add-dir DIR` | `vendor` — tool allowlist | proven |
| `grok` | `grok -p` (cwd-scoped) | `os` — locked export (`--allow-rule` exists but is **not passed**) | measured |
| `gemini` | `gemini -p` (cwd-scoped) | `os` — locked export | measured |
| `qwen` | `qwen -p` (also native `qwen review run`) | `os` — locked export | measured |
| `kimi` | `kimi -p --output-format text\|json` | `os` — locked export | measured |
| `copilot` | `copilot -p` | `os` — locked export (`--allow-all-tools` exists and is **never** passed) | measured |
| `pi` | `pi --print` | `os` — locked export | measured |
| `jcode` | `jcode run` | `os` — locked export | measured |
| `opencode` | `opencode run` (also native `opencode pr <N>`) | `os` — locked export | measured |
| `kiro` | `kiro chat` | `os` — locked export | measured |

`os` = the disposable `chmod a-w` export from Axis 2, with a post-run manifest
tamper check. No row may claim read-only without one of the two mechanisms.

Two native review paths were found during the probe and are **not** wrapped by
this tool: `qwen review run` and `opencode pr <N>`. They are recorded as
candidates for a later cycle rather than silently duplicated.

## Anti-theater guarantees

1. **Empty output is NOT a review.** Under 40 bytes ⇒ exit `2`, the bot is
   recorded as limited in the rotation state file, and nothing is stamped.
2. **Truncation is declared.** A diff over the cap is cut and `diff_truncated:
   yes` rides in the comment and the JSON.
3. **Secrets are absolute.** `gitleaks` scans the comment body *before* posting;
   any hit aborts the post.
4. **Timeout floor 500s.** A 280s cap once burned `$4.7` for zero output
   (`cross-harness-red-team.md`).
5. **The prompt rewards refutation**, requires `file:line` citations, mandates
   "could not verify" over guessing, and classifies a PR-body claim unsupported
   by the diff as at least *major*.
6. **The isolation claim is audited, not asserted.** For every `os`-class
   reviewer the export manifest is recompared after the run; drift ⇒ exit `1`
   `isolation_violated` and no stamp. The enforcement class and tamper result
   are emitted, so a consumer never has to take "read-only" on faith.

## What was reused rather than built

Strata / DRY — the forge crossed these before creating anything:

| capability | source | disposition |
|---|---|---|
| review criteria, severity taxonomy | `code-review-excellence`, `code-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` + 5 more already installed | **reused** — no new criteria authored |
| bot-message taxonomy (rate-limit vs plan vs informational) | `review-bot-quota-recovery.md` | **reused** in phase B |
| rotation + state file + never-hot-retry | `ai-code-review-bots-rotation.md` | **reused** in phase C |
| gate semantics | `pr-review-protocol.md` §4.1 | **implemented**, not amended |
| isolation shape | `cross-harness-red-team.md` | **reused** in phase D |
| in-harness stub | `agents/code-reviewer.md` (17 lines, no isolation) | **left intact**, now points here |

Net-new is exactly one thing: **an executable dispatcher that makes isolation and
gate-honesty mechanical instead of remembered.**

## Governance note — no rule amendment was needed

The forge order flagged a possible tension in `§4.1(e)` requiring either
(i) positioning as the verifier limb, or (ii) an H6-gated amendment with
independent red-team and HITL ratification. **Path (i) is fully specified by
§4.1(e) as written** — it already states what a routed review counts for, where
it is recorded, and the two conditions under which it may complete convergence.
No amendment, no red-team gate, no HITL cycle. The rule was right; it only
lacked an implementation.

## Non-goals

- Not a replacement for configured bots — it is the rung *below* them.
- Not a merge authority. It never sets `--auto-merge` and never clears C2.
- Not a security scanner. Route `snyk`/`gitleaks` separately.
- Not a fixer. It reviews; the caller fixes.
