# ADR-019: role contracts stay `latent`; the activation gate is deferred until it exists as tooling

- **Status**: Accepted (scope of PR #476); the gate itself is **Proposed**, not built
- **Date**: 2026-10-07
- **Deciders**: root orchestrator of the session, on the record of 11 Socratic specialists, an independent red-team
  from two other model families (`codex exec`, `kimi -p`) and a council verifier. Merge of PR #476 still needs the
  operator's ratification (governance edit) and a new cross-family red-team on its final head.
- **Scope**: `agents/forge.md` §"Organizational Roles", `skills/agentic-tool-forge/SKILL.md` (step 2 and the
  `role contract (binding)` router row), `skills/anima/kb/org-roles.md`.

## Context

PR #476 teaches the Forge to answer an organizational-role request ("we need a CEO agent") with a role contract bound
to existing agents. During review the contract gained an activation gate written in prose: an owner record outside
the file, an `authority_digest` over eleven fields, and checks (a)–(e) that a holder had to cite before acting.

Three findings made that gate unfit to ship:

1. **Nothing executes it.** `agents/forge.md` admitted the gate was "detectable after the fact, not prevented
   beforehand". No script computes the digest or resolves the record.
2. **Revocation hole (A2).** Owner identities were resolved when the gate was checked, not when a record was made,
   and check (e) only counted revocations "by an owner identity". If the person who revoked later left the admin
   list, the revocation stopped counting and the older ratification became valid again. The same paragraph claimed
   the opposite, so the text contradicted itself.
3. **The gate never opens on this host.** One account operates both the agents and the owner role, and `main` has
   no branch protection, so no record could qualify. The capability existed only on paper.

## Decision

- A role contract admits one status, `latent`. The file's `status` never grants authority, and every decision of a
  role goes to the human.
- The gate, the digest, the A2 rule and the fields `approval_ref`, `approved_by`, `approved_at`, `trigger` and
  `authority_digest` are removed from the contract. They are listed as reserved in the template.
- `tests/governance/test-roles-latent-only.sh` fails if any contract surface defines, permits or describes a
  transition out of `latent`. Its scope is the three contract files above, because several `SKILL.md` files use
  `status: active` for skill lifecycle, which is unrelated to roles.

## Requirements for any future activation gate

A gate may come back only in a new PR, reviewed as a governance change, and only if it meets all of the following.

1. **Executable verifier, outside the holder.** A deterministic script (not prose, not the role's agent) decides
   whether a contract is effective. The holder cannot run, edit or override it.
2. **Identity frozen at record time.** The verifier stores who authored each ratification and each revocation, and
   whether that identity was an owner, at the moment the record was made. A later change to the owner list never
   revives a revoked ratification and never invalidates a valid revocation.
3. **Host preconditions, checked by the verifier.** A human owner account that no agent can operate; code-owner
   review on the role registry; protected default branch without force-push; signed ratification records. If any
   precondition is missing, every contract stays `latent` and the verifier says which one failed.
4. **Append-only trail with declared retention.** Ratification and revocation records are kept append-only. The
   retention period, the identities stored and the legal basis are declared before the first record exists (the trail
   holds personal identifiers, so privacy law applies).
5. **Verdicts with a reason.** The verifier returns `effective` or `latent` plus the failed check, never a bare
   boolean.
6. **Correct domain check.** The previous design compared `decide` with `reports_to`, which are different kinds of
   value (actions against a role). The check must compare like with like: `decide` against the ceiling of `tier`,
   and against the HUMAN_DOMAIN exclusion list.
7. **Fixtures shipped with the verifier.** Executable fixtures covering at least: A1 an agent-authored ratification
   is rejected; A2 a revocation still counts after its author leaves the owner list; A3 restoring old field values
   does not revive a revoked contract; A4 two records that cannot be ordered count as superseding; B3 arming a
   planned role (e.g. ombuds, values-guardian, org-designer) on a host that fails a precondition stays `latent`.

## Intended consumer

An operator planning effort outside this repository plans roles that would use this gate (its pending item is to
create and arm an ombuds, a values guardian and an org designer). No script, hook or skill reads a role contract's `status` today. Arming those
roles therefore depends on this ADR being implemented; until then they stay `latent`, as they effectively were,
because the removed gate could not open on this host.

## Limits of the evidence behind this decision

- The 11 specialists and the council verifier are from the same model family; about half started from the same prior
  report. Their agreement is an echo, not independent calibration. Cross-family independence comes only from the
  red-team (`codex`, `kimi`).
- The value of a latent-only contract was not measured. The 15-case smoke test
  (`tests/governance/test-org-roles-coverage.sh`) checks that guidance is present in the text, not that it is useful.
  Closing PR #476 and redoing it smaller remains a valid choice for the operator.
- The search for consumers covered this repository, the user's agent configuration, two plugin repositories and
  the planning vault. A negative result there does not prove that no consumer exists elsewhere.

## Alternatives rejected

- **Keep the gate and fix A2 in prose.** The gate would still be unexecuted text, and each review round found a new
  hole in the prose.
- **Remove the gate but keep `active` in the enum.** A value with no rule that excludes it is worse than either
  option: a contract could claim `active` with nothing to say it is wrong.
