# Dogfood record — ooda-loop tree cadence (2026-10-25)

**Scope**: one manual application of the tree cadence to a real multi-repo product backlog
(26 repositories, ~135 open PRs, ~287 open issues, one issue tracker). Not a run of the
`ooda-loop` ACT driver: behavioral ACT remains UNVERIFIED.

## What was run

Forward pass from the project root to a ranked filter list and a delegation plan; backward pass
reconciling findings into lessons and an updated concept note. The output of all nodes was persisted
in one draft PR at the end of the run, before the run was closed (not one PR per node).

## Evidence

| Beat | Evidence |
|---|---|
| Execute | catalog of all repositories, relation map, top-10 ranked filters |
| Feedback | each filter checked against the source (PR, ticket or file), not against session memory |
| Introspect | 6 lessons recorded, one per node that produced one |
| Persist | one draft PR in the knowledge store; one consolidated human package (6 deduplicated items) |

## Lessons that changed the skill

1. The requested concept already existed in the store: search first, then dogfood and bump.
2. The top-priority residue was almost all human-owned (credentials, production change, merges):
   the useful output was one consolidated package, not more analysis.
3. Computing every scoring dimension for every item was theater: rank all, detail only the top.
4. A helper that wrote by pushing to a protected branch could not be used; the PR was the
   durable record.

## Not verified

- Mutation-check of the two invariants (planned for cycle 2).
- Any automated enforcement; both invariants are guidance with a manual check.
