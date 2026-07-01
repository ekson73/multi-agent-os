# Bot-Config Registry — the teach-the-bot SSOT

> Consumed by `bot-finding-arbiter` (*Praetor*) §4. Maps each reviewer/scanner bot to the
> **repo-committed config file** that teaches it, WHAT that file controls, and — critically —
> whether the bot's misbehavior is **repo-fixable at all** (some errors are account/dashboard-side
> and no committed file can fix them).
>
> ⛔ **Every edit below is subject to the one non-negotiable**: teach-the-bot edits are ONLY for a
> **verifiably-wrong** finding, NEVER to suppress a valid security/logic finding. Prefer the
> *narrowest* teaching form (a path-scoped instruction / documented-convention note) over a broad ignore.

## Registry

| Bot | Config file (repo-committed) | What it teaches / controls | Repo-fixable? | Preferred teaching form |
|---|---|---|---|---|
| **Qodo / PR-Agent** | `.pr_agent.toml` (root) — `extra_instructions`; optional `best_practices.md` | review priorities, DO-NOT-FLAG list, project truths (e.g. tracker, branch regex) | ✅ | append a scoped line to `extra_instructions` naming the convention the bot missed |
| **CodeRabbit** | `.coderabbit.yaml` (root) — `reviews.path_instructions`, `knowledge_base.learnings`, `path_filters` | per-path natural-language review guidance; "living document" | ✅ | add a `path_instructions` entry for the file/pattern with the rule; NOT a blanket disable |
| **GitHub Copilot review** | `.github/copilot-instructions.md` (repo-wide) · `.github/instructions/**/*.instructions.md` (path-scoped, `applyTo` frontmatter) | repo-wide + path-scoped review instructions | ✅ | add a path-scoped `*.instructions.md` with the convention |
| **Amazon Q Developer** | `.amazonq/rules/*.md` (priority-tagged Markdown) — ⚠️ **documented, but frequently NOT the observed convention** | coding-standards / review rules *if* Q code-review is actually configured | ⚠️ **confirm-first** | the `.amazonq/` dir is commonly an **OpenSpec / prompt host**, not a reviewer-config dir → verify a real Q *code-review* config exists before treating `.amazonq/rules/` as a teaching surface; **default HITL when absent** (never invent the file) |
| **gitleaks** | `.gitleaks.toml` `[allowlist]` · `.gitleaksignore` | secret-scan allowlist / fingerprint ignore | ✅ (⚠️ security) | allowlist ONLY a proven false-positive fingerprint/path; **never** a real secret — HITL if in doubt |
| **Trivy** | `trivy.yaml` · `.trivyignore` | CVE / misconfig suppression | ✅ (⚠️ security) | ignore a specific CVE ID ONLY with a documented rationale + expiry; else fix/upgrade |
| **Semgrep** | **often no committed rule file** — commonly CI-registry-driven (`semgrep --config p/ci`); a local `.semgrep.yml` / `.semgrep.yaml` is frequently absent | SAST findings | ⚠️ CI-tuning (not a committed rule file when registry-driven) | narrowest = inline `# nosemgrep: <rule-id>` + rationale at the flagged line; else tune the CI invocation (`--config`, severity, block-vs-warn `\|\| true`); ⚠️ security-class → verify-gated, never blanket-disable |
| **OpenSSF Scorecard** | workflow YAML only (no rule file) | informational scoring | ⚠️ workflow-only | tune the job in `.github/workflows/*`; findings are informational (rarely a "teach" case) |
| **pip-audit** | none (CLI flags + `requirements*.txt`) | dependency advisories | ⚠️ workflow-only | suppress via `--ignore-vuln` in the workflow with rationale, or upgrade the dep (preferred) |
| **Snyk** | `.snyk` (ignore/policy) — scan-time only | ignore specific vuln IDs/paths | ❌ for **account** issues (quota/import/entitlement/enablement = **dashboard-only**) | **do NOT edit a file to fix an account error** — HITL playbook (re-import / plan / visibility) |

## Grounding discipline (recon-before-assume — anti-theater)
The config files above are **candidate** teaching surfaces, not guarantees. Several bots' *documented* config files are, in practice, **frequently NOT adopted** in a given repo — notably **Qodo's `best_practices.md`** (the real teaching surface is almost always `extra_instructions` in `.pr_agent.toml`) and **Amazon-Q's `.amazonq/rules/`** (the `.amazonq/` dir is often an OpenSpec / prompt host instead). Therefore, before any teach-the-bot edit, Praetor's OBSERVE step MUST **verify the target file actually exists in the repo** (`ls` / glob) — never assume it from this table. If the expected teaching surface is **absent** → **HITL** (propose creating it), never fabricate a config path: a written-but-wrong path is a **silent no-op** that lets the false-positive recur (anti-theater — the edict must land on a file the bot actually reads).

## Classification cues (how Praetor decides `repo-fixable?`)
- **Content finding** ("this line/dep/secret is a problem") → repo-fixable via the bot's config (if verified-wrong) OR fix the code (if valid).
- **Platform/account error** — the check `state=error` with a description about **quota, rate-limit, auth, import, entitlement, timeout, "test limit reached"** → the bot's *platform* failed, not the code → **NOT repo-fixable** → HITL playbook, no config edit. (Empirical anchor: a Snyk `security/snyk` status ERROR = *"used your limit of private tests"* = account quota — a `.snyk` file cannot fix it.)
- **Security class** (secret/injection/auth/CVE) verified-wrong → allowlist is possible but ⚠️ HITL-gated; the default is *fix/upgrade*, not suppress.

## Notes
- The gitleaks/Trivy allowlists are the "the scanner is wrong here" mechanism, but they are the *highest-risk* edits (a mis-allowlist hides a real secret/CVE) → strongest verify + HITL when uncertain.
- CodeRabbit currently reads `CLAUDE.md` via the CLI `--config` flag in this repo; a committed `.coderabbit.yaml` is the more durable teaching surface when one is warranted.
- Update this registry when a new reviewer bot is adopted OR a config-file convention changes.
