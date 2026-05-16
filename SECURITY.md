# Security Policy

> Mirror: [VKS-1956](https://vek.atlassian.net/browse/VKS-1956) — Wave 3 supply-chain hardening for `ekson73/multi-agent-os`.

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| `>= 1.5.x` | ✅ Active support |
| `< 1.5.0`  | ❌ Out of support |

## Reporting a Vulnerability

**Do not** open public issues for security vulnerabilities. Instead:

1. Open a **private security advisory** via GitHub:
   <https://github.com/ekson73/multi-agent-os/security/advisories/new>
2. Provide:
   - Affected version(s) and commit SHA.
   - Reproduction steps (PoC if possible).
   - Impact assessment (confidentiality / integrity / availability).
3. Expect an acknowledgement within **2 business days** and a fix-or-mitigation plan within **5 business days** for HIGH/CRITICAL severity.

For coordinated disclosure with Vek (`vek-im`) cross-org partners, copy the advisory to the Jira mirror linked above.

## Hardening Controls (Wave 3)

This repo enforces the following supply-chain controls (issue #52 checklist):

| Control | Implementation |
|---------|---------------|
| Supply-chain sentinel | `.github/workflows/supply-chain-sentinel.yml` — Trivy `fs`, `pip-audit`, `gitleaks`, OpenSSF Scorecard |
| Lockfile committed | `mcp-tools/maos-mcp-hub/requirements.txt` + verification step in sentinel workflow |
| CODEOWNERS | `.github/CODEOWNERS` covers security-sensitive surfaces |
| Dependabot | `.github/dependabot.yml` — daily for pip, weekly for actions |
| Branch protection | Configured out-of-band in repo settings: require reviews + status checks before merge to `main` |
| Secrets in secret manager | No tokens or credentials are hardcoded; CI uses `${{ secrets.* }}` only; gitleaks runs on every PR |
| Tabletop exercise | `docs/security-tabletop-exercise.md` — attack scenarios + mitigations |

## Anti-Patterns Banned in CI

PRs introducing these patterns are blocked:

| Anti-pattern | Today | Planned |
|---|---|---|
| `${{ ... }}` direct interpolation inside shell `run:` bodies (CWE-78 RCE). Use `env:` blocks and reference `"$VAR"` instead. | Reviewed via CODEOWNERS auto-request on `/.github/workflows/` | Automated lint via `actionlint`/`zizmor` — tracked as P1 gap in `docs/security-tabletop-exercise.md` §B |
| Indented heredocs inside `run: \|` (silent false-negative — heredoc never closes). | Reviewed via CODEOWNERS | Same as above |
| `--no-verify` on commits/pushes without explicit operator authorization recorded in the PR body. | Reviewed manually + GaaS pre-push naming-convention check | Same as above |
| Any token, password, private key, or credential committed to git history. | **Automated**: `gitleaks` job in `supply-chain-sentinel.yml` runs on every PR + push |  |

The supply-chain sentinel workflow automates only the secret-scan and dependency/lockfile/Scorecard surfaces today. Pattern-level workflow linting is a P1 gap acknowledged in the tabletop exercise; until landed, CODEOWNERS-driven manual review is the gate for the first three rows.

## Cross-Org Coordination

Per ADR-020, this framework is a candidate input to the Vek marketplace. Security disclosures affecting marketplace integration must be cross-posted to the Vek security channel.
