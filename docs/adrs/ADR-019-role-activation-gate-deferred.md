# ADR-019: role contracts stay `latent`; the activation gate is deferred until it exists as tooling

- **Status**: Accepted (scope of PR #476); the gate itself is **Proposed**, not built
- **Date**: 2026-10-07 (written while closing PR #476; the PR's changelog entries carry its opening date, 2026-10-06)
- **Deciders**: proposed by the agent session that executed PR #476; accepted only when the repository owner merges
  that PR (it edits governance text, so the merge is the owner's decision).
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
3. **It depends on host preconditions the text did not check.** A gate of this kind means something only on a host
   that stops one account from approving its own change. Where the same account can act for the agents and for the
   owner, no record proves a human, so the capability can exist only on paper.

## Decision

- A role contract admits one status, `latent`. The file's `status` never grants authority, and every decision of a
  role goes to the human.
- The gate, the digest, the A2 rule and the fields `approval_ref`, `approved_by`, `approved_at`, `trigger` and
  `authority_digest` are removed from the contract. They are listed as reserved in the template.
- `tests/governance/test-roles-latent-only.sh` checks contract **form and loaded value**, and refuses when in
  doubt. It reads the YAML template in `agents/forge.md` and, recursively, the registry `roles/`. Under `roles/` the
  only accepted file is a regular file named `*.md` (lowercase), UTF-8 without BOM and without CR, NEL, LS or PS
  characters, whose line 1 is `---`, with one frontmatter closed by `---` and a body without fences, document
  separators or `<contract key>:`. Anything else fails: symlinks, other extensions (`.yml`, `.YML`, `.Md`,
  `.gitkeep`), missing or unclosed frontmatter, a file that is not valid UTF-8 (the checker crashes, and the crash
  counts as a failure). The frontmatter is loaded with `yaml.safe_load` (PyYAML, YAML 1.1), duplicate keys refused;
  YAML that does not load fails. On the loaded value: the root is a mapping, `status` is the string `latent`,
  `tier` (if present) is null, and `role`/`status`/`tier` appear only at the root; at any depth, inside mappings and
  lists, reserved fields are null and activation keys (`active`, `enabled`, `armed`, `effective`, `activated`) are
  null or false. Without `python3` and PyYAML the test fails; it never falls back to a weaker check. Fixtures build
  a real `roles/` tree for each refused form and for a valid one. In the three guidance files the test also flags
  the word form of a transition to `active`.
- Refusing in doubt has a price: a file with CRLF or a BOM, `roles/.gitkeep`, body prose containing `role:`, and
  `active: "false"` (a string, not a boolean) fail. A legitimate case is written in the accepted form; the test is
  not loosened for it.
- What the test does **not** detect: natural-language activation ("the role goes live"); an unlisted key such as
  `is_active: true` or `Active: true`, or a non-string key that YAML 1.1 produces (`yes:` becomes a boolean);
  a different reading of the same text by a consumer that uses another YAML parser; contracts kept in a registry
  the host designates outside `roles/` (`agents/forge.md` allows one). It does not run in CI today (no workflow
  calls `tests/governance/run-all.sh`). The scope stays narrow because several `SKILL.md` files use
  `status: active` for skill lifecycle, which is unrelated to roles.

## Requirements for any future activation gate

A gate may come back only in a new PR, reviewed as a governance change, and only if it meets all of the following.

1. **Executable verifier, outside the holder.** A deterministic script (not prose, not the role's agent) decides
   whether a contract is effective. The holder cannot run, edit or override it.
2. **Identity frozen at record time.** The verifier stores who authored each ratification and each revocation, and
   whether that identity was an owner, at the moment the record was made. A later change to the owner list never
   revives a revoked ratification and never invalidates a valid revocation.
3. **Host preconditions, checked by the verifier.** The host must prevent one account from approving its own
   change: a human owner account that no agent can operate, code-owner review on the role registry, a protected
   default branch without force-push, and signed ratification records. If any precondition is missing, every contract
   stays `latent` and the verifier says which one failed.
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
   does not revive a revoked contract; A4 two records that cannot be ordered count as superseding; B3 a ratification
   on a host that fails a precondition leaves the contract `latent`.

## Consumers

No script, hook or skill in this repository reads a role contract's `status`. A consumer that wants to arm roles
depends on this ADR being implemented first.

## Limits of the evidence behind this decision

- The 11 specialists and the council verifier are from the same model family; about half started from the same prior
  report. Their agreement is an echo, not independent calibration. Cross-family independence comes only from the
  red-team (`codex`, `kimi`).
- The value of a latent-only contract was not measured. The 15-case smoke test
  (`tests/governance/test-org-roles-coverage.sh`) checks that guidance is present in the text, not that it is useful.
  Closing PR #476 and redoing it smaller remains a valid choice for the operator.
- The search for consumers covered this repository and a few related ones. A negative result does not prove that no
  consumer exists elsewhere.

## Alternatives rejected

- **Keep the gate and fix A2 in prose.** The gate would still be unexecuted text, and each review round found a new
  hole in the prose.
- **Remove the gate but keep `active` in the enum.** A value with no rule that excludes it is worse than either
  option: a contract could claim `active` with nothing to say it is wrong.
