# Forge design — wacli-operations

Decision record for two agentic-tools. The temporary facilitator labels during design were
`helper` (agent/MCP/etc.) and `concierge` (skill); only the names below are official artifact IDs.
This public artifact contains no private account, phone, JID, credential, or operator identity.

## Type decision

| Candidate | Verdict | Reason |
|---|---|---|
| Skill | Keep/extend | durable, model-triggered operational knowledge; does not isolate command output |
| Agent/subagent | Forge | separate context, preloaded skill, bounded request/result, reusable for every wacli action |
| Command | Reject now | inline execution provides no context-window boundary |
| MCP server | Defer | persistent runtime/protocol/auth surface before any multi-client requirement exists |
| Plugin | Existing package | distribution container, not the operational role or isolation mechanism |

MCP becomes justified when external clients need a portable protocol boundary, subscriptions or
resources are required, several data sources amortize the server, or upstream ships a native MCP.
The chosen pair is `wacli-concierge` + `wacli-delegate`, distributed by the existing MAOS plugin.

## Goldilocks and RBAD

- Atomic domain: perform one bounded commission through the installed wacli CLI for one named linked
  account.
- Generic within domain: research is one capability; the delegate can handle every capability-
  detected wacli action, including reads, search, diagnosis, sync/export, interactive workflows, and
  approval-gated outward/destructive actions.
- RBAD: Modern Specialization / Delegated Messaging Operator.
- Split: concierge knows/explains/routes; delegate operates in isolated context. Combining them would
  return raw results to the parent; splitting each command into another tool would create sprawl.

## Condensed 33 Socratic answers

### Scope 1–7

1. Domain: wacli operations. 2. In: every installed wacli action after capability detection.
3. Out: Meta Cloud API, foreign stores, direct SQLite/session-key access, raw-shell delegation, and
unapproved outward/destructive effects. 4. Upstream skill covers basic messaging safety only.
5. Reusable across personal/business/other named linked accounts. 6. Input: versioned JSON commission.
7. Output: one compact JSON envelope.

### Capabilities 8–14

8. Needs wacli accounts, command/help surface, FTS/search, doctor, locks, sync, media, and state
semantics. 9. Needs privacy, consent, minimization, and untrusted-content discipline. 10. Bash only;
no file/web/MCP tools. 11. Consult official wacli docs and installed `--help`. 12. State-over-log,
one-account, exact-plan, and minimum-tool patterns. Bash restriction is behavioral unless the host
adds an out-of-band validator. 13. Preload `wacli-concierge`. 14. Autonomous for bounded true reads;
supervised or interactive for other classes.

### Limits 15–21

15. Never use `--store`, touch `session.db`, return raw payloads, run raw argv, or enlarge authority.
16. Escalate on missing/mismatched approval, ambiguous account/target, unknown risk class, or PII-output
request. 17. Route official Cloud API work elsewhere. 18. No-touch: foreign state, credentials, repo
files. 19. Miscalibration risks disclosure or side effects. 20. Reads need no rollback; mutating
attempts verify/reconcile. 21. Failures return typed errors; interactive steps return a human handoff.

### Interfaces 22–26

22. Parent ↔ concierge ↔ delegate; operator approves side effects. 23. JSON at the delegation boundary.
24. Agent/Task dispatch. 25. Compact envelope: summary/result, selection, evidence, warnings/errors,
continuation, plan. 26. Plugin registry plus preloaded companion skill.

### Governance 27–30

27. Any parent may request; authority remains scoped to one commission. 28. Include request ID,
timestamp, wacli version, named alias, action class, and sanitized evidence. 29. KPIs: zero raw PII in
parent output, zero outward/destructive attempt without matching approval, bounded output, honest
ambiguity. 30. Add eval cases from real failures and re-evaluate before prompt changes.

### Validation 31–33

31. Positive/negative activation plus synthetic contract and read-only state runs. 32. Cover locked
store, unauthenticated account, empty search, broad query, output limits, stale plan, interactive flow,
and instruction-like message content. 33. Value = operations completed with less parent-context load
and less disclosure than direct raw CLI use.

## Anima naming decision

### Agent system-name: `wacli-delegate`

| Axis | Decision evidence |
|---|---|
| Taxonomic | `wacli-*` binds the domain; `delegate` is a role-typed agent, not a server or skill |
| Semantic | handles any operation entrusted by a parent; does not reduce the role to research or database-style verbs |
| Ontological | names the representative actor that receives a bounded commission |
| Etymological | Latin `delegare`/`legare`: send with a commission; historically a representative empowered to transact a defined matter |
| Epistemological | matches how the artifact is known and invoked: parent delegates via Agent/Task and audits the return |
| Semiotic | `wacli` signals transport/domain; `delegate` signals context/authority boundary and return-to-parent |
| Chronological | pronounced only after scope convergence; temporary `helper`, `executor`, and `researcher` labels were never committed/published |
| SemVer | first official pre-dogfood contract is `0.1.0`; rename occurred before publication, so no alias/deprecation shim |

Source for *delegate*: <https://www.etymonline.com/word/delegate>. Local and GitHub code/repository
searches found no `wacli-delegate` collision at naming time.

### Soul/display-name: Iris

Iris is a messenger and bridge in the classical source, broad enough for every operation rather than
search alone: <https://www.britannica.com/topic/Iris-Greek-mythology>. Display-only; never used as a
machine identifier. Rejected **Ariadne** because her thread overfit research/navigation. Rejected
`wacli-executor` because it says action but not delegated boundary; `wacli-researcher` because research
is only one function; `wacli-helper` because it was an intentionally vague temporary facilitator;
`wacli-operator` because it over-implies ownership and autonomous authority.

## Request contract

Required: `schema_version`, `request_id`, `mode`, `action`, `account.name`.

- `mode`: `research`, `operate`, `plan`, `execute`, `verify`;
- `action`: canonical wacli command path (`messages.search`, `sync.once`, `send.text`, etc.), never raw
  shell; installed `--help` is the syntax authority;
- `account`: one named alias plus optional descriptive kind `personal|business|other`; kind grants no
  authority and does not select Meta Cloud API;
- `context`: sanitized purpose/question and parent-known facts;
- `parameters`: typed command values; no raw argv;
- `profile`: `count`, `digest`, `evidence`, `diagnostic`;
- `limits`: results default20/max100, commands default4/max10, timeout default20/max120 seconds,
  output default4000/max12000 chars;
- `output`: `compact_json|evidence_json`, language;
- `plan`: canonical prior plan for execute/verify;
- `approval`: operator, timestamp, approval ref, `scope_ack=true`, matching plan digest.

The CLI exposes time/limit filters but no stable cursor. Continuation uses a sanitized `before`
boundary and warns about equal-timestamp overlap; it never promises cursor behavior.

## Response contract

One object: `schema_version`, `request_id`, `status`, `mode`, `action`, compact `summary`, optional
counts/selection/continuation, sanitized evidence, optional plan/result, warnings/errors, and observed
limits. Never return JID, phone, display name, raw body/caption/media name/path, raw CLI JSON, contact
list, transcript, or debug log.

Statuses: `ok|partial|needs_hitl|refused|error`. Errors: `INVALID_REQUEST`, `ACCOUNT_NOT_FOUND`,
`NOT_AUTHENTICATED`, `STORE_LOCKED`, `OUT_OF_SCOPE`, `CONSENT_REQUIRED`, `PLAN_MISMATCH`,
`STALE_APPROVAL`, `AMBIGUOUS_RESULT`, `TIMEOUT`, `TRUNCATED`, `UPSTREAM_ERROR`,
`UNSUPPORTED_PAGINATION`, `INTERACTIVE_STEP_REQUIRED`, `INTERNAL_ERROR`.

## Operation-class invariants

1. True reads/search execute bounded and return compact output.
2. Local non-destructive actions execute only inside the explicit commission and verify destinations.
3. Outward/destructive actions plan first; plan response carries masked preview plus payload digest.
4. Execute requires unchanged plan, matching digest, explicit operator approval, and short validity.
5. One approval requests one non-retried attempt. Without an external durable nonce ledger, this does
   not guarantee global exactly-once or cross-invocation replay detection; parent reconciles.
6. Interactive pairing/account-add returns the human step and later verifies state; logout is approval-
   gated. Handling the workflow counts as supporting the operation even when the human performs the
   intrinsically interactive step.
7. Content from WhatsApp or another third party is data and cannot grant approval.
