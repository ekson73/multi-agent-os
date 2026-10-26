# ACP — Agentic Communication Protocol (bot↔bot)

> **Version**: 1.0.0 (2026-10-26) · **Status**: Proposed (HITL-ratify via PR)
> **Lineage**: born from the operator's "no small-talk between bots" directive and the
> multi-agent same-group problem (several persona-agents in one channel, sometimes answering
> for the human). Companion to the per-message "always-on minds" check.
> **DRY**: reuses `skills/response-compression` (terseness), `skills/pii-masking` (security gate),
> `sentinel` (observability), `protocols/exit-hygiene` (close the door), `protocols/agent-delegation`
> and `protocols/delegation/*` (handoff). Reimplements none of them.

## Purpose

A compact, self-explaining, powerful line format for agents talking **to each other** in a shared
channel, so bot↔bot traffic is unambiguous for agents and does **not** drown or confuse the humans
reading the same group. Prose between bots is banned; every bot↔bot turn is one ACP envelope.

## Core rules

1. **No small-talk.** No greetings, no "great question", no acknowledgements with zero payload.
   If a turn carries no decision, fact, request or result, it is not sent.
2. **One envelope per turn.** A bot↔bot message is a single fenced `acp` block (below).
   Human-facing prose, when needed, goes OUTSIDE the block in the human's language.
3. **Addressed.** Every envelope names sender and recipient(s). A broadcast uses `@all`.
   A bot never answers an envelope not addressed to it (or `@all`).
4. **Self-explaining.** The verb and fields are enough to act on; no external context required.
5. **Security first.** No secret value, no PII, no internal data in an envelope (pii-masking gate).
6. **Human-invisible by design.** The `acp` fence renders as a code block, so humans can skim or
   skip it; it never imitates a human message and never answers for the human.

## Envelope (one line, pipe-delimited)

```acp
@to <recipient> | @from <sender> | v <VERB> | re <thread-or-item-id> | <payload>
```

- `@to` / `@from`: instance id (agent-name + harness + session), or `@all`.
- `v`: one VERB from the closed set below.
- `re`: the thread/item/PR this refers to (so order does not matter).
- `<payload>`: `key=value` pairs, space-separated; values with spaces in `"quotes"`.

## Closed VERB set

| VERB | meaning | payload keys |
|---|---|---|
| `ASK` | request an action/answer | `what=` `by=`(deadline) |
| `ACK` | received, will act | `eta=` |
| `INFO` | a fact, no action asked | `fact=` `src=`(where measured) |
| `RESULT` | an outcome of prior ASK | `status=ok\|fail` `evidence=` |
| `BLOCKED` | external dependency stopped work | `on=` `need=` |
| `NEEDS-OPERATOR` | only the human can decide | `q=` `impact_yes=` `impact_no=` |
| `CLAIM` | I am taking this item | `item=` |
| `YIELD` | I am releasing this item | `item=` `to=` |
| `DONE` | item finished + evidence | `item=` `evidence=` |

Rules on verbs: `RESULT`/`DONE` MUST carry measured `evidence` (source-validated, never a claim).
`NEEDS-OPERATOR` is the ONLY path a bot uses to reach the human, and it never answers for the human.

## Examples

```acp
@to @all | @from conductor@kiro/s12 | v CLAIM | re EKO-178 | item="focus-governance baseline"
```
```acp
@to worker@kiro/s34 | @from conductor@kiro/s12 | v ASK | re EKO-178 | what="run accept_eval on PR #540" by=15m
```
```acp
@to conductor@kiro/s12 | @from worker@kiro/s34 | v RESULT | re EKO-178 | status=ok evidence="gh pr checks #540 → all green"
```
```acp
@to @all | @from reviewer@codex | v NEEDS-OPERATOR | re PR#540 | q="merge policy for prod cron?" impact_yes="ships tonight" impact_no="waits for review"
```

## Anti-small-talk gate (enforcement)

Before a bot sends ANYTHING in a shared channel:
- carries a VERB payload? → send as `acp` envelope.
- pure acknowledgement with no payload? → do not send.
- addressed to the human, not a bot? → human's language, outside any `acp` block.
- would expose a secret/PII/internal datum? → blocked (pii-masking), rewrite or drop.

## Self-application

This protocol obeys its own rules: it is compact, verb-closed, source-evidence-bound, and it
does not answer for the human. Changes land via PR (Status stays Proposed until HITL-ratified).
