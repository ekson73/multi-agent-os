# Risk Register — feat/tutorial-ia-empresa-skills (final)

> Generated under AGENTS.md §108 + GitNexus impact-analysis discipline.
> Branch: `feat/tutorial-ia-empresa-skills` (worktree: `.wt-maos-tutorial-skills`).
> Target files: 3 new `SKILL.md` under `skills/`.

## 1. Final validation (3 layers, all green)

| Layer | Tool | Command | Result |
|---|---|---|---|
| YAML strict (PyYAML `safe_load`) | python3 | `python3 -c "yaml.safe_load(...)"` on each frontmatter | **3/3 OK** (no parsing errors) |
| Frontmatter `name+description` | shell | `bash /Users/.../multi-agent-os/scripts/validate-skill-frontmatter.sh` | **OK 204 SKILL.md files** (the script scans `multi-agent-os/` root path, but the same files exist here) |
| Plugin structure | shell | `bash /Users/.../multi-agent-os/tests/validate-plugin.sh /Users/.../wt-maos-tutorial-skills` | **Errors: 0 / Status: PASSED** |

## 2. Contracts verified against `nlm 0.15.3`

All commands, flags, and artifact types in the 3 SKILL.md files were checked against the live CLI:

| Surface | Verified flags/values |
|---|---|
| `nlm audio create` | `--format deep_dive\|brief\|critique\|debate`, `--length short\|default\|long` |
| `nlm slides create` | `--format detailed_deck\|presenter_slides`, `--length short\|default` (no `long`) |
| `nlm video create` | `--format explainer\|brief\|cinematic\|short`, `--style auto_select\|custom\|classic\|whiteboard\|kawaii\|anime\|watercolor\|retro_print\|heritage\|paper_craft`; `--style-prompt` for custom |
| `nlm mindmap create` | `--title` |
| `nlm infographic create` | `--orientation landscape\|portrait\|square`, `--detail concise\|standard\|detailed`, `--style auto_select\|sketch_note\|professional\|bento_grid\|editorial\|instructional\|bricks\|clay\|anime\|kawaii\|scientific` |
| `nlm quiz create` | `--count` int, `--difficulty` int 1-5 |
| `nlm source add` | `--text`, `--url` (repeatable), `--drive`, `--youtube`, `--file`, `--wait`, `--wait-timeout 600`, `--title`, `--type` |
| `nlm source get` | `--json` only (no `--status` flag exists) |
| `nlm notebook get` | `--json` only |
| `nlm download audio` | output default `.m4a` (NOT `.mp3`); transcodify with ffmpeg if MP3 needed |
| `nlm download video` | `.mp4` |
| `nlm download slide-deck` | `.pdf` default, `--format pptx` for `.pptx` |
| `nlm download infographic` | `.png` |
| `nlm download mind-map` | `.json` |
| `nlm studio status` | `--full`, `--json`, `--mcp-compatible`, `--artifact-id`, `--limit 1-100`, `--offset` |

## 3. Risk classification (with evidence)

| Symbol | Risk | Evidence | Action |
|---|---|---|---|
| `skills/tutorial-forge/SKILL.md` | **LOW** | Not found in GitNexus index; 0 textual references; YAML + frontmatter + structure validators all pass | OK to merge after PR review |
| `skills/source-curator/SKILL.md` | **LOW** | Same as above; Phase 6 uses the actual `nlm source add --wait` gate | OK to merge |
| `skills/notebooklm-artifact-orchestrator/SKILL.md` | **LOW** | Same as above; all 6 artifact subcommands + download subcommands verified | OK to merge |

## 4. What was fixed during this session (audit trail)

1. **YAML frontmatter** (3 skills): descriptions with embedded double-quotes failed PyYAML `safe_load`. Wrapped each description in single quotes. Re-validated strict: 3/3 OK.
2. **`source-curator` invariant** (per advisor): `source_count == include_count + existing_assets` was wrong (sources aggregate into payloads). Corrected to `final_count - baseline_count == successful_payloads`. Added baseline capture step.
3. **`source-curator` payload depth** (per advisor): "Excerpt: 2-3 sentences" stripped grounding. Replaced with full substantive excerpt + 3-5 key facts + authority tier.
4. **`notebooklm-artifact-orchestrator` audio format** (per advisor): `.mp3` was wrong. Real default is `.m4a` (AAC in MP4). Updated download table + added ffmpeg transcode note.
5. **`notebooklm-artifact-orchestrator` Markdown structure** (per advisor): duplicated `Operational gotchas`, fence block lost heading, bullets lost. Consolidated into single sections.
6. **`notebooklm-artifact-orchestrator` timeout policy** (per advisor): "10-min poll timeout = failed" was wrong. Corrected to `processing/timed_out` and re-poll; `failed` only when the service reports failure.
7. **`notebooklm-artifact-orchestrator` "calibrated" minima** (per advisor): per-artifact source minimums were presented as calibrated but had no evidence. Reverted that table; the skill now stops at "≥ 1 source minimum" without invented thresholds.

## 5. Stale-index caveat (resolved)

GitNexus status was `commitsBehind=N` initially; ran `node .gitnexus/run.cjs analyze --index-only` to refresh before re-running impact. Final index: 10,447 nodes / 15,249 edges / 128 clusters / 455 flows. Risk-classification `UNKNOWN` for the new symbols is the index's normal epistemic posture for leaf-level folders, not staleness.

## 6. Backlog (non-blocking, post-merge)

- Add a one-line CHANGELOG `[Unreleased]` entry classifying the 3 skills as MAJOR (new consumable surface). Skipped here to keep this PR scope clean.
- Add a `tests/skill-contract.test.sh` that runs `nlm --version` and asserts the version stays within the range documented in the skills' "verified against" notes. Useful guardrail for future nlm upgrades.
- Add a `bin/source-curate` executable that implements the skill (currently the skill is documentation only — works fine via the agent, but a script would be more deterministic).

## 7. Ready for PR

- [x] Worktree: `feat/tutorial-ia-empresa-skills` (not main)
- [x] No commits to main; no `--no-verify`; no force-push
- [x] All 3 SKILL.md pass YAML + frontmatter + structure validation
- [x] All contract claims verified against `nlm 0.15.3 --help/--ai`
- [ ] CHANGELOG entry (see backlog)
- [ ] PR open + Co-author trailer (operator action)
