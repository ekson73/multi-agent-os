---
name: routed-pr-review
description: >
  Dispatch an independent, context-isolated PR review when the configured review
  bots are quota-blocked, absent, or past their measured latency — instead of
  waiting on them or fabricating a green. Soul-name Euthyna (εὔθυνα, the
  independent end-of-term audit of an Athenian magistrate, conducted by officials
  who were not the magistrate). Isolation is BY CONSTRUCTION: a fresh OS process
  in a different vendor family, write confinement whose strength is named per
  harness class (CLI sandbox · kernel `sandbox-exec` · perms-only, which DETECTS
  rather than PREVENTS), no delegator history, prompted to
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
| **D** isolated run | fresh OS process, write confinement per harness class (Axis 2 — never a blanket "read-only"), refute-first prompt, timeout floor 500s | `cross-harness-red-team.md` |
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

### Axis 2 — write confinement (⚠️ two rounds of review rewrote this section)

**3 of 11 harnesses expose a read-only switch; this dispatcher passes 2 of
them.** For the rest, confinement is provided from outside the CLI — and the
strength of that confinement is named honestly, because permissions alone are
**not** a boundary:

| class | when | guarantee |
|---|---|---|
| `vendor` | `codex` (`--sandbox read-only`), `claude` (`--allowedTools`) | the CLI confines itself; cwd = live repo, but only after cwd is **proven** to be `HEAD_SHA` and clean |
| `vendor+os` | vendor CLI, cwd **not** provably `HEAD_SHA` | export built anyway so the `Head reviewed:` stamp stays true |
| `os-sandboxed` | any other harness, host has `sandbox-exec` | **kernel** `file-write*` deny on the export *and* the repo root, profile **probe-verified before use**, over the disposable `chmod a-w` export |
| `os-perms-only` | any other harness, **no** kernel boundary on host | writes are **DETECTED, not PREVENTED** — see below |

⚠️ **`chmod a-w` is not an execution boundary.** A process running as the file
owner can `chmod u+w` and rewrite. Measured on this host: owner restored the
permission and wrote through it. Under `sandbox-exec` the identical attack
returned `Operation not permitted` and the content survived. So `os-perms-only`
defends against an *incidentally-writing* reviewer, never a determined one, and
the emitted evidence says exactly that instead of implying a sandbox.

**Two independent tamper checks**, because one could not see far enough:

1. **export manifest** — `sha256` before locking, recompared after; catches
   writes *inside* the tree the reviewer was given.
2. **live-repo hash** — `git status --porcelain` digest before/after; catches an
   *escape*, i.e. a write to the working tree the reviewer was never given. The
   first check was blind to this by construction.

Either check failing ⇒ exit `1` with `isolation_violated:<which>`, and
**nothing is stamped or reported as a valid review**. The enforcement class and
the tamper result ride in both the PR comment and the JSON, so a consumer audits
the isolation claim instead of believing it.

> **Three independent verifiers, three rounds, all on this artifact:**
> (1) an advisory caught the original dispatcher running unflagged harnesses in
> `$PWD` while the doc claimed read-only — the doc was ahead of the code;
> (2) dogfood cycle 1 (`codex`) caught `grok` still classified `vendor` on a
> flag the fixed code never passed;
> (3) `coderabbitai` caught that the `chmod` export was never a boundary at all,
> and that the manifest could not see an escape outside it.
> None of the three was found by the author.

## Reviewer invocation table

`evidence` is load-bearing: **proven** = executed successfully in a recorded run;
**measured** = flag confirmed present in this host's `--help` at build time
(`2026-09-03`). Never add a row without one.

| harness | invocation | enforcement class | evidence |
|---|---|---|---|
| `codex` | `codex exec --sandbox read-only --cd DIR` | `vendor` — sandbox | proven (`--cd` measured) |
| `claude` | `cd DIR && claude -p … --max-turns N --allowedTools Read Grep Glob --add-dir DIR` | `vendor` — tool allowlist **+ cwd** | proven; the `cd` is load-bearing — `--add-dir` grants access but never moves the working directory, so without it the reviewer read the caller's `$PWD` while the stamp asserted `HEAD_SHA` (found by a routed `kimi` review of this tool on #414) |
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

## Contract tests — `tests/contract.sh`

```bash
bash skills/routed-pr-review/tests/contract.sh    # -v for failing-case detail
```

**Why they exist.** Four dogfood cycles produced 19 findings and I self-caught
**zero**. The two worst were *composition* defects — every individual line
verified correct against the binary while the path through them was dead
(`exit 0` unreachable via a `.head` scope bug) or wrong (`--add-dir` granting
access without moving cwd). Line-level checking is structurally blind to both.
These run the **real script end-to-end** against a stub `PATH`, so they assert
the path.

No network, no real reviewer, no real `gh`: a temp one-commit git repo supplies
a genuine `HEAD_SHA` (the script fetches and archives it, so it must exist), and
stubs answer the four `gh` call shapes plus a fake reviewer whose output each
case controls by env. Every case is data, not another copy of the invocation.

**9 cases · 11 assertions** (cases 5 and 9 each assert an exit code *and* that
the diagnostic names its reason — a silent correct exit is not enough). The run
prints one line per assertion; that is why the count below is 11, not 9.

| # | Contract asserted | Guards against |
|---|---|---|
| 1 | `exit 0` is **reachable** when a configured primary cleared *this* head | the `.head` scope bug that made the documented success path dead code |
| 2 | an approval at an **older** sha does not clear C3 | false-green on a stale verdict |
| 3 | an active `CHANGES_REQUESTED` is never dismissed | `§4.1(e)` — the whole point of the gate |
| 4 | under-40-byte output is **not** a review | anti-theater guarantee #1 |
| 5 | explicit `--reviewer` equal to the caller is refused **+ the reason is named** | verifier ≠ generator bypass *(2 assertions)* |
| 6 | silence alone never proves "no primary configured" | `§4.1(a)` absence-from-silence misclassification |
| 7 | a trailing value-option terminates | the `shift 2` infinite loop |
| 8 | a broken `sandbox-exec` degrades to `os-perms-only`, never claims `os-sandboxed` | cycle-4 fail-open: a failure to confine reported as a successful denial |
| 9 | absent `timeout` aborts with a diagnostic **naming the remedy** | cycle-4: a hard dependency discovered late as an opaque per-harness failure *(2 assertions)* |

**They earned their keep three times, on two runs.**

- **Run 1, case 5 → defect #20.** The refusal fired and printed its reason, but
  `pick_reviewer` runs inside a command substitution, so its `die` exited only
  the subshell and the `|| { … exit 2 }` below re-labelled a usage error as
  `status:no_reviewer` — stderr right, JSON wrong. Validation hoisted into the
  main shell.
- **Run 2, case 8 → defect #21.** `build_sandbox_profile` assigned the global
  `$SANDBOX_PROFILE` *before* probing, so a failing probe returned `1` while
  leaving it set — and `arm_sandbox_prefix`, which trusts only non-emptiness,
  then wrapped every dispatch in a profile just proven not to work. Now built
  into a local and published only on success.
- **Run 2, case 8 again → defect #22, the worst of the three.** With the leak
  fixed, `SBX` is legitimately empty — and under `set -u`, **bash 3.2 (the macOS
  default) aborts when an empty array is expanded**. The entire documented
  `os-perms-only` fallback class therefore crashed on every dispatch, on every
  host without a working `sandbox-exec` — all of Linux. It never surfaced here
  because this host arms the kernel boundary. Fixed with the
  `${SBX[@]+"${SBX[@]}"}` idiom at all 4 sites.

Three defects, none found by a human or a reviewer bot, all found by running the
path. Cases 8 and 9 exist **because an advisory pointed out that the two cycle-4
boundary fixes had been proven by ad-hoc probes and never encoded** — proof
without a regression test is exactly the "verified once, shipped, forgotten"
pattern this harness exists to end.

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

Strata / DRY — the forge crossed these before creating anything.

⚠️ **Where these sources live.** The four `.md` sources below are **NOT in this
repository** — they are user-scope artifacts on the operator's machine
(`~/.claude/rules/` and an Obsidian vault). A reader of this repo alone cannot
open them, and an isolated reviewer correctly reported them as unresolvable.
They are cited as *provenance*, never as repo paths. The governance semantics
they carry are restated inline in this file precisely so this skill stands on
its own.

| capability | source | where it lives | disposition |
|---|---|---|---|
| review criteria (what to look for) | `code-review-excellence`, `code-reviewer`, `silent-failure-hunter`, `pr-test-analyzer` + 5 more | installed skills (host) | **reused** — no new criteria authored |
| severity ladder `[blocking\|major\|minor\|nit]` in the reviewer prompt | extends `pr-review-protocol.md` (which uses `blocking` + `major`) | `~/.claude/rules/`, external | ⚠️ **partly authored** — `minor`/`nit` are mine. Measured 2026-09-03: the cited rule contains `nit` **zero** times. An earlier revision of this table claimed "no new criteria authored" across both rows; that was a false claim of the same class this tool's own prompt rates *at least major*, self-caught by Socratic Q13 |
| finding classes `[correctness\|security\|silent-failure\|governance\|test-gap]` | named after the installed skills above | installed skills (host) | **derived** — one class per source skill, not independently invented |
| bot-message taxonomy (rate-limit vs plan vs informational) | `review-bot-quota-recovery.md` | vault, external | **reused** in phase B |
| rotation + state file + never-hot-retry | `ai-code-review-bots-rotation.md` | `~/.claude/rules/`, external | **reused** in phase C |
| gate semantics | `pr-review-protocol.md` §4.1 | `~/.claude/rules/`, external | **implemented**, not amended; restated inline above |
| isolation shape | `cross-harness-red-team.md` | vault, external | **reused** in phase D |
| in-harness stub | `agents/code-reviewer.md` | **this repo** | **behaviour unchanged**; +18 lines appended declaring its correlated-verifier boundary and routing here (17 → 34 lines) |

Net-new is exactly one thing: **an executable dispatcher that makes isolation and
gate-honesty mechanical instead of remembered.**

## Q20/Q21 — revert and fallback

**Revert.** The only external side effect is one PR comment (`--post`); without
that flag nothing leaves the process. To revert: `gh pr comment --delete-last`
(or delete by id). The dispatcher never pushes, never merges, never edits code,
and never writes outside `$WORK`/the disposable export — so there is no
repository state to roll back.

**Fallback ladder** — exit codes read off the code, not intended (an earlier
draft of this very section mis-stated two of them; corrected before commit):

| # | condition | exit | behaviour |
|---|---|---|---|
| 1 | no harness left after family exclusion | `2` | JSON `status:no_reviewer`, `may_complete_c3:false`. **Never** falls back to the caller (verifier ≠ generator) |
| 2 | reviewer produced <40 bytes | `2` | treated as **no review**; the bot **is** recorded in `~/.claude/state/ai-review-bots.json` so rotation *skips* it next cycle (§3 never-hot-retry) |
| 3 | isolation violated (either tamper check) | `1` | no stamp, no comment, `status:isolation_violated` |
| 4 | `gitleaks` absent while `--post` given | `1` | refuses to post rather than posting an unscanned body |
| 5 | review ran, gate does not clear C3 | `3` | the review **is** emitted; `3` means *reviewed-but-blocked*, not failure |
| 6 | review ran, C3 cleared | `0` | — |

Below the ladder, `ai-code-review-bots-rotation` §5 still licenses the
deterministic local path (`gitleaks`/lint/typecheck/build) as **labelled partial
evidence** — never as a "review".

## Q29/Q33 — KPIs and cost, measured not projected

| KPI | Definition | First-cycle measurement (2026-09-03, PR #414) |
|---|---|---|
| finding precision | findings that survived independent verification ÷ findings raised | **14/14 = 100%** across 3 reviewers |
| author blind-spot rate | defects found by the routed reviewer that the author's own passes missed | **14/14** — author self-caught **0** after 6 self-review rounds |
| gate honesty | routed runs that overstated their limb | **0** — `may_complete_c3` never certified a pending primary |
| cost per cycle | wall-clock + calls | ~4-6 min, 1 dispatch + 1 verification read |
| false-green risk | reviews stamped without substantive body | **0** — the <40-byte guard fired as designed |

**ROI framing.** The comparison is not "routed review vs. a real bot" — it is
"routed review vs. **waiting**". Cycle 1 ran while CodeRabbit was quota-blocked
for 40 minutes and returned two real defects in that window. Re-measure these
numbers per cycle; a precision figure that drifts below ~70% means the reviewer
prompt is generating noise and should be tightened, not trusted.

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

---

*Signed: `Claude-Dev-pr414` (Claude Opus 5, branch `feat/routed-pr-review`, cycle-4 regressions encoded) | 2026-09-03T22:07:45-03:00 — per `CLAUDE.md` §Sign documents with agent ID and timestamp*
