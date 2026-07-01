# bot-finding-arbiter (Praetor) — deterministic ORIENT fixtures

These fixtures **prove** the deterministic classification gates of `../bin/classify.sh` —
the code-enforced part of Praetor's ORIENT step. They are the executable evidence behind
the SKILL's ⛔never-suppress-valid-security claim (which was prose-only until this suite).

## Run

```sh
./skills/bot-finding-arbiter/tests/run.sh   # exit 0 = all pass
```

## What each case proves

| Case | Input | Asserts |
|---|---|---|
| `case-01-synthetic-false-positive` | qodo "missing Jira key" (content) | `content · defer-to-verify` — the classifier does NOT deterministically rubber-stamp "bot-wrong"; it hands the finding to the probabilistic verify (verifier > generator). |
| `case-02-real-secret-gitleaks` | gitleaks hardcoded secret | `security-class · never_suppress=true` — the ⛔ gate: a real secret is NEVER deterministically suppressed. |
| `case-03-snyk-account-quota` | Snyk `state=error` "test limit reached" | `account-error · repo_fixable=no` — the account-vs-code split: a platform failure is not fixable by any committed file → HITL, no config edit. |
| `case-04-trivy-cve` | Trivy CVE finding | `security-class · never_suppress=true` — CVEs are security-class; default is fix/upgrade, never auto-suppress. |
| `case-05-coderabbit-style-nit` | CodeRabbit style suggestion (content) | `content · defer-to-verify` — style/content findings defer to the verify, never auto-suppress. |
| `case-06-nonquota-limit-not-account` | `state=error` build error "failed to limit concurrent connections" | `content · defer-to-verify` — proves the tightened `platform_re` (per amazon-q review on #192): a NON-quota "limit" in error-state is NOT dismissed as account-side (defense-in-depth even if the state guard were removed). |

## Contract

`classify.sh` reads a finding envelope `{bot, context, state, description}` and emits one
canonical line: `bucket=… disposition=… repo_fixable=… never_suppress=…`. The probabilistic
disposition (which of the 7 dispositions; the actual teach-the-bot edit) stays in the LLM-driven
`SKILL.md` OODA loop — this suite only pins the deterministic skeleton (ECE `agentic-first §4.7`).
