# Adapter — org-roles (role · level · tier · gate · lane · edge · tag · instance id)

> Naming conventions for an **organization modelled as agents**: roles (CEO, account manager, executor,
> verifier…), decision levels, authorization tiers, human gates, lanes, relation edges, and tags.
> Register: roles and lanes = **agent**; levels, tiers, gates, edges, tags, instance ids = **machine**.
> Pairs with `agents/forge.md` §"Organizational Roles" (the Forge decides the *contract*; Anima names it).

## Conventions
- **Roles: market-recognizable, no soul-name.** A role is agent register — apt beats pretty. A soul-name is added
  only when it maps to a **verifiable function** (a behavior a test or metric could check); an ornamental name on a
  job title changes nothing measurable, so cut it. Prefer the term a newcomer already knows (`ceo`, `verifier`,
  `account-manager`) over an invented one.
- **The name must not imply authority the role lacks.** If a market title carries a power the role does not have
  (e.g. a `ceo` that cannot approve spend), keep the title and state the limit in the role contract — do not rename
  to dodge it, and do not leave the implied power unstated. An agent holding a human-sounding title (`ceo`,
  `account-manager`) is identified as an agent wherever a person could mistake it for a human (contract field
  `holder: agent`; external-facing messages disclose that an AI is acting).
- **Specialty is an attribute, not a role.** `executor` + `specialty: dev · ops · content` — never one role per
  specialty (`developer`, `writer`…). New specialties then need no rename and no new queue.
- **Latent roles keep their final name.** Name a role now with its final name (`project-lead`, `sre`); Anima names
  it only, it never sets its status. Its contract is `latent` (no authority), and any future change of status must
  not force a re-baptism.
- **Units: `lane/<noun>` for a queue + policy scope with no head** (`lane/revenue`, `lane/delivery`). Do not name a
  "department" or "cell"/"pod"/"squad" that has no decision of its own — that is an org chart for show.
- **Entity as a graph.** Name the **edges** where the intelligence lives — `decide` · `verify` · `remember` ·
  `learn` — and relation types in snake_case (`reports_to` · `delegates_to` · `authorizes` · `approves` ·
  `executes` · `audits` · `consumes` · `produces` · `governs`). Never invent an "AI department" or a "quality team"
  to hold what an edge already expresses.
- **Search surfaces in en-US.** Tags, edge types, level/tier slugs and project slugs are retrieval surfaces → en-US,
  even when the request arrived in another language (quote the original label next to it, never as the slug).
- **Instance ids derive from the role slug:** `<role-slug>-<nn>` (`executor-01`, `ceo-01`) — the role stays the SSOT.
- **Levels and tiers: verb or noun of what they unlock** (`l0-policy` · `l3-execution`; `z0-read` ·
  `z1-local-write` · `z4-irreversible`). These are illustrative excerpts (intermediate values omitted, hence the
  `z1`→`z4` gap), not adopted series — run the sweep below before adopting any letter+digit series. A tier that
  unlocks irreversible or HUMAN_DOMAIN actions (`z4-irreversible` here) is **board/human-only**: it names a human
  gate and is never assignable as an agent role's `tier` ceiling.

## Reserved/limits — occupied short series (sweep before reuse)
Short **letter+digit series** are the most collision-prone names in a governance corpus: `G1–G8`, `T1–T4`, `A0–A4`
and similar are often already owned (merge gates, trust tiers, abstraction levels). Before naming a new series:
1. Grep the host's rules/docs/skills for the bare token and its range (`\bG[0-9]\b`, `\bT[0-9]\b`) — count real uses.
2. If occupied, **prefix it** with a disambiguating letter for the new concept (`HG0–HG3` for human gates) rather
   than overloading the old one.
3. If no free, meaningful letter exists, keep a neutral code (e.g. `Z0–Z4`) and record the reason (etymology and
   foundation aspects get a ⚠, not a silent pass).
4. Record the occupied series you found in the decision so the next sweep starts from it.

## Worked example
Subject: an operator's org model with a human owner, an orchestrator, a client-facing role, executors, an
independent verifier, two latent roles, and four human approval points.
- Human at the top → `board` (rejected `owner`: collides with "code owner" / "product owner").
- Orchestrator → `ceo` (operator's and market's word; the "cannot approve spend" limit goes in the contract).
- Executors → `executor` + `specialty` (rejected `developer`/`ops-engineer`/`writer` — three queues for one role).
- Verifier → `verifier` (rejected `reviewer`: implies cooperative review, loses "accepts evidence").
- Not-yet-needed roles (contracts kept `latent`) → `project-lead`, `sre` (rejected `ops`: collides with
  `specialty: ops`).
- Human approval points `G0–G3` → **`HG0–HG3`** (the `G` series was already owned by merge gates).
- No soul-names on any role; units = `lane/revenue`, `lane/delivery`.

## Sources
- Anthropic, *Multi-agent coordination patterns* (orchestrator–subagent, generator–verifier) —
  https://claude.com/blog/multi-agent-coordination-patterns
- Paperclip docs, *Org structure* (strict tree; the CEO is the only agent with `reportsTo: null`; the board
  approves the CEO's strategic breakdown and new-agent hires separately — oversight, not a reporting line) —
  https://mintlify.com/paperclipai/paperclip/concepts/org-structure
