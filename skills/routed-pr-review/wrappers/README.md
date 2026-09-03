# Per-harness wrappers — caller side

The dispatcher (`../bin/routed-review.sh`) is already harness-agnostic on the
**reviewer** side (it capability-detects and picks one). These wrappers are the
**caller** side: how each host invokes the skill, and the one variable that must
be set for the independence invariant to hold.

## The single non-negotiable

```bash
ROUTED_REVIEW_CALLER=<the harness you are running in>
```

Without it the dispatcher cannot exclude the caller's own vendor family and may
route the review back to the same model that wrote the code — a **correlated
verifier**, which is the exact failure `cross-harness-red-team.md` §Must-not
forbids. Unset is tolerated (no exclusion) but it silently weakens the gate, so
every wrapper below sets it.

## Design decision — one table, not eleven near-identical files

`# /** [decision] · @context 11 harnesses named in the forge order · @reason the
invocation differs by ONE token per host; eleven files would be eleven copies of
one line, violating PHASE III SSOT/DRY of agentic-bootloader-v2 · @impact a
single table is the SSOT; only harnesses with a real *discovery* convention get a
file of their own */`

Files that exist beyond this table do so because the harness has a discovery
mechanism a table cannot satisfy:

- `invoke.sh` — generic POSIX entry point for any harness that can shell out.

## Invocation per harness

| harness | how to call | notes |
|---|---|---|
| **claude** (Claude Code) | `ROUTED_REVIEW_CALLER=claude skills/routed-pr-review/bin/routed-review.sh --pr N --post` | or via the `Bash` tool; skill auto-discovers under `skills/` |
| **codex** | `ROUTED_REVIEW_CALLER=codex ./…/routed-review.sh --pr N --json` | codex will not be chosen as its own reviewer |
| **gemini / antigravity** | `ROUTED_REVIEW_CALLER=gemini ./…/routed-review.sh --pr N` | |
| **opencode** | `ROUTED_REVIEW_CALLER=opencode ./…/routed-review.sh --pr N` | native `opencode pr <N>` is a *separate* path, not wrapped |
| **aws-kiro / crew** | `ROUTED_REVIEW_CALLER=kiro ./…/routed-review.sh --pr N` | |
| **pi** | `ROUTED_REVIEW_CALLER=pi ./…/routed-review.sh --pr N` | pi has no spawn tool — this is exactly its use case |
| **oh-my-pi** | `ROUTED_REVIEW_CALLER=pi ./…/routed-review.sh --pr N` | same family as `pi`; shares its exclusion |
| **prime-agent** | `ROUTED_REVIEW_CALLER=prime-agent ./…/routed-review.sh --pr N` | unknown family ⇒ no exclusion applied; pass an explicit `--reviewer` if the host shares a vendor with one in the pool |
| **copilot** | `ROUTED_REVIEW_CALLER=copilot ./…/routed-review.sh --pr N` | |
| **kimi / qwen / grok / jcode** | `ROUTED_REVIEW_CALLER=<name> ./…/routed-review.sh --pr N` | |
| **any other** | `ROUTED_REVIEW_CALLER=<binary-name> ./…/routed-review.sh --pr N` | the name only needs to match the pool entry to be excluded |

## Contract for every wrapper

1. Set `ROUTED_REVIEW_CALLER`.
2. Do not pass `--post` unless the caller is authorised to write to the PR.
3. Treat exit `3` as **"reviewed but still blocked"** — never as a merge signal.
4. Treat exit `2` as **"no review exists"** — never stamp, never claim green.
5. Never wrap the script in a retry loop against the *same* reviewer; rotation
   already fall-throughs (`ai-code-review-bots-rotation.md` §3.5: a hot retry on
   the same bot is not a different strategy).

---

*Signed: `Claude-Dev-pr414` (Claude Opus 5, branch `feat/routed-pr-review` @ `342165e`) | 2026-09-03T15:33:49-03:00 — per `CLAUDE.md` §Sign documents with agent ID and timestamp*
