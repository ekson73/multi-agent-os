# Profile: `gauntlet-loop`

Renders a prompt in the **Gauntlet Loop** architecture (a.k.a. *Loop Engineering*): a lead agent
decomposes a goal into independently-judgeable pieces, fans out builders, and gates each piece
behind a **blind, independent critic** comparing the artifact against an **externally-named bar** —
looping until the bar is met or a stopping rule fires.

> Invoked as `--architecture=gauntlet-loop`. This is a **profile file inside this skill**, not a
> skill and not a `/command` — it does not occupy the `gauntlet-loop` skill/command namespace.

## Prior art (attribution — this profile composes, it does not claim)

| Source | Contribution |
|---|---|
| **Matt Shumer**, [`mshumer/Claude-of-Duty`](https://github.com/mshumer/Claude-of-Duty) | The originating 152-word aim-prompt; the fan-out + harsh-critic + blind-A/B pattern |
| **Addy Osmani**, [*Loop Engineering*](https://addyosmani.com/blog/loop-engineering/) (2026-06-07) | Formal name + the **5 mandatory components**, incl. stopping rules |
| [`duolahypercho/gauntlet-loop`](https://github.com/duolahypercho/gauntlet-loop) (MIT) | Proves the fill-in-the-blank aim-prompt shape works as a skill. **Cited, not vendored** — see §Divergence |
| [We0 analysis](https://we0.ai/articles/claude-opus-5-s-gauntlet-loop) · [Augment Code](https://www.augmentcode.com/guides/what-is-loop-engineering) | The verification harness (headless render, A/B contact sheets, perf assertions) |

The canonical aim-prompt, preserved verbatim as the shape's ground truth:

> *"I want you to build a first-person shooter at the level of the most recent Call of Duty games.
> It should be utterly perfect, visually beautiful, with every single thing done at AAA quality—from
> textures to physics to anything you could think of. Fan out sub-agents and have sub-agents tackle
> each one individually so that the game is utterly perfect. You should /loop on each item and have
> a separate sub-agent check it visually to ensure it looks triple A. That separate sub-agent should
> be a really harsh critic, and if it doesn't look triple A, it should keep going. Don't stop until
> each sub-agent is utterly wowed with the quality when compared with the actual Call of Duty game.
> It should literally compare them side by side blind and say which one looks better. Do this in
> ThreeJS. /loop until it's utterly perfect. Fan out sub-agents and ultracode."*

## DRAFT shape

Three load-bearing slots, then the guardrails the original leaves implicit:

```text
TASK          what to build, concretely
BUILD-METHOD  fan-out topology: lead decomposes -> N builders, each on an independently-judgeable piece
QUALITY-BAR   the EXTERNAL reference the critic compares against, named specifically
              (not "beautiful" — "at the level of <named artifact>")

CRITIC        an independent sub-agent, fresh context, no build history, prompted to REFUTE;
              blind side-by-side against the bar; forbidden from silently lowering the bar
EVIDENCE      what the critic may directly inspect (screenshots, test output, metrics, diffs)
STATE         where attempt/failure history persists OUTSIDE the conversation
STOP          cost ceiling · max attempts per piece · wall-clock · gain-stagnation delta
ESCALATION    what forces a human decision
```

## The three psychological levers (why the shape works)

| Lever | Mechanism |
|---|---|
| **Blind Critic** | A single agent reviewing its own output rationalises it — it knows the effort and accepts "looks done". A critic with **no build history** has no such attachment and judges the artifact cold. |
| **Extreme Reference** | "Make it beautiful" resolves to the model's *average* aesthetic prior and stops early. An intentionally unreachable named bar plus blind A/B surfaces the **largest** gap, giving the builder a hyper-focused correction. |
| **Destination over Route** | Specify the acceptance criterion, not the implementation. The model's own reasoning finds engineering the operator could not have specified. |

## Osmani's 5 components → this repo's primitives

The profile does not re-implement these; it wires the prompt to them.

| Component | Primitive |
|---|---|
| 1. Machine-verifiable goal | `skills/decompose-abstract-to-measurable` (D/T/J leaves; `inconclusive` is a real verdict) |
| 2. Real environment access | the executing host's tools, named explicitly in the rendered prompt |
| 3. Durable external state | scratch/journal outside the conversation (persist-first discipline) |
| 4. Inevitable verifier (hard gate) | `skills/red-team` + `bin/convergence-guard` (independence enforced deterministically) |
| 5. Clear stopping rules | the skill's Verifiability Gate + `skills/convergence-engine` economic stop |

## Lens roster (REFINE)

| Lens | Asks |
|---|---|
| **bar-nameability** | is the quality bar a *named external artifact*, or an adjective? |
| **critic-independence** | does the critic provably lack the builder's context? |
| **evidence-inspectability** | can the critic *directly observe* the thing being judged? |
| **decomposability** | is each piece independently judgeable, or do verdicts entangle? |
| **stop-rule-presence** | are cost, attempts, clock and stagnation all bounded? |
| **blast-radius** | is failure cheap and reversible at this loop length? |

## Loop budget

The Verifiability Gate typically evaluates **true** for this profile — so the profile budget
applies rather than the bare economic stop. Defaults, all overridable:

```text
max_attempts_per_piece   10
wall_clock               operator-set; no default (unbounded time is not a budget)
cost_ceiling             operator-set; REQUIRED before any long run
stagnation_delta         exit when round-over-round gain < threshold for 2 rounds
```

**The gate is not a formality.** If `bar_is_machine_verifiable` is false, this profile degrades to
the economic stop — a long loop against an unverifiable bar buys self-assessment, not quality.

## Divergence from `duolahypercho/gauntlet-loop`

Cited as prior art; deliberately **not** vendored or installed. What differs and why:

| Axis | Duola's skill | This profile |
|---|---|---|
| Stopping rule | *"you are the brake"* — none | Osmani's 5th component is **mandatory**; unbounded is refused |
| Harness | "pure prompt, no harness" | wires the prompt to measurement, red-team and independence primitives |
| Domain | games (ThreeJS, Godot) + a marketing-site example | domain-agnostic; the bar just has to be nameable and observable |
| Recovery | operator fills the blanks | `goal-recovery` + Prisma recover DoR/motivation/goal/DoD from the braindump |
| Governance | none | HUMAN_DOMAIN halt, worktree discipline, cost ceiling, escalation path |
| Install | `./install.sh` into `~/.claude/skills` | no install; profile file, no namespace claim |

Adopting the upstream skill instead would require a trust-tier gate and a pinned SHA — and would
import the one property this profile exists to fix: an unbounded loop.

## When this profile is WRONG (from the source guidance, kept)

Do **not** render a gauntlet-loop prompt when:

- a mistake is **expensive or irreversible** (prod mutation, data deletion, external disclosure);
- the agent **cannot observe the true result** (no inspectable evidence → the critic is guessing);
- the loop would expose **sensitive data or elevated permissions**;
- **one careful human pass is cheaper** than building and supervising the loop.

Any of these → fall back to `--architecture=default`, or escalate. This is the same boundary the
skill's Verifiability Gate enforces; the profile restates it because this is where it is tempting
to ignore.
