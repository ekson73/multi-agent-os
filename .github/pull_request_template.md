## Summary

<!-- 1–3 bullets describing what changed and why. -->

## Type

- [ ] feat (new functionality)
- [ ] fix (bug fix)
- [ ] docs
- [ ] refactor
- [ ] chore
- [ ] security
- [ ] governance
- [ ] release

## AI Involvement

<!-- Disclose honestly. See CONTRIBUTING.md § Contributor Types. -->

- [ ] Human-authored
- [ ] AI-assisted (human author used AI tools for parts of the change)
- [ ] AI-generated draft reviewed by human (named reviewer required)

If AI-assisted or AI-generated, include `Co-Authored-By:` footer(s) in the commit messages.

## Runtime / Surface Impact

<!-- Tick the surfaces this change touches. -->

- [ ] Claude Code (plugin runtime, hooks, agents, commands, skills)
- [ ] GitHub Copilot (`.github/copilot-instructions.md`)
- [ ] Generic AI agents (AGENTS.md contract)
- [ ] Plugin manifest (`.claude-plugin/plugin.json`) — requires downstream marketplace sync
- [ ] CI / GitHub Actions (`.github/workflows/`)
- [ ] Security / compliance posture

## Files requiring follow-up governance update

<!-- Tick if this PR materially changes a contract documented elsewhere. -->

- [ ] `README.md`
- [ ] `AGENTS.md`
- [ ] `CLAUDE.md`
- [ ] `CONTRIBUTING.md`
- [ ] `SECURITY.md`
- [ ] `CHANGELOG.md`
- [ ] `.github/CODEOWNERS`
- [ ] `.claude-plugin/plugin.json`
- [ ] Downstream marketplace pin (`ekson73/eko-claude-plugins`)

## Evidence

<!-- Show commands run + relevant output. Brief, paste-ready. -->

```bash
# e.g.
bash tests/validate-plugin.sh
```

## Risks

<!-- Be specific. "Low — docs only" is acceptable when accurate. -->

## Rollback

<!-- How to revert if regression detected post-merge. -->

## Checklist

- [ ] Worktree + branch used (no direct-main commits)
- [ ] Conventional Commits + `Co-Authored-By:` footer if AI involved
- [ ] gitleaks clean (pre-commit + CI workflow)
- [ ] Build / tests pass (`tests/validate-plugin.sh` or equivalent)
- [ ] No secrets, no PII, no Vek-specific content (Layer Purity per `~/.claude/rules/layer-precedence-policy.md`)
- [ ] AGENTS.md / CONTRIBUTING.md / CLAUDE.md updated if contract changed
- [ ] Version bump + CHANGELOG entry if `.claude-plugin/plugin.json` changed

<!--
🤖 If this PR was opened by an automated agent, link the plan file or skill that drove it.
-->
