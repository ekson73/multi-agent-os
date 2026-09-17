# Kiro co-habitation & compatibility

> How MAOS installs on the Kiro family (`kiro-cli`, Kiro IDE, Kiro Crew) **alongside**
> Claude Code on the same machine, and an honest account of what ports and what does not.
> Verified on `kiro-cli 2.22.0`, 2026-09-17.

## TL;DR

- MAOS's skills install on Kiro with **`npx skills add ekson73/multi-agent-os -g -a kiro-cli`**, plus **one** extra config line for Kiro Crew (which the skills CLI cannot reach). See [Installation → Kiro](../README.md#kiro-cli--kiro-ide--kiro-crew).
- Every change for Kiro is **ADDITIVE**. Nothing under `~/.claude/**` or any other harness path is removed, renamed, reordered or degraded. You can run Kiro and Claude Code simultaneously on the same host.
- Skills, commands and agents port as-is (skills are the Agent Skills open standard; Kiro reads them). Invocation changes; capability does not.
- Governance hooks: **6 of the 8 MAOS hook classes port** to Kiro's hook system. The **only** genuine loss is context-compaction governance (`PreCompact`/`PostCompact`) — Kiro 2.22.0 has no compaction hook event. Kiro's `permissions.yaml` is a **stronger** deterministic deny layer than Claude Code's and covers a different axis.
- No `KIRO.md`. `AGENTS.md` is the vendor-neutral SSOT and Kiro reads it. Kiro is wired through the skill loaders + `AGENTS.md`, not a second context file.

## 1. Kiro has TWO independent skill loaders

This is the single fact that makes the Kiro install two steps instead of one.

| Loader root | Read by | Notes |
|---|---|---|
| `~/.kiro/skills` | **kiro-cli AND the Kiro IDE default agent** | entries automatically become `/slash` commands |
| `~/.kiro/crew/skills` + `skills.extra_paths` | **Kiro Crew ONLY** | the `skills` CLI has no agent id that writes here |

`npx skills add … -a kiro-cli` writes real **copies** (not symlinks) into `~/.kiro/skills/<name>/SKILL.md` and reaches the first loader — **never** the second. Kiro Crew is a separate loader; you point it at what step 1 already wrote with `kirocrew config set skills.extra_paths '["~/.kiro/skills"]'`. That is one copy on disk, two loaders, no clone and no `~/Projects` path — a fleet user has no checkout of this repo.

`extra_paths` is watched, so step 2 applies with no restart. Verify with `kirocrew config get skills.extra_paths`.

## 2. The agent id is `kiro-cli` — nothing else

The `npx skills` id for the Kiro family is **`kiro-cli`**. `kiro`, `kiro-ide` and `kiro-crew` are **NOT** valid ids: `-a kiro` returns `Invalid agents: kiro`, `"status": "failed"`, and writes **zero files** — a silent no-op. Publish only `kiro-cli`.

## 3. What ports

### 3.1 Skills → auto `/slash` commands

The 40+ MAOS skills are the [Agent Skills open standard](https://agentskills.io); Kiro reads them directly. Once in `~/.kiro/skills`, each is **automatically a `/slash` command** in kiro-cli and the Kiro IDE default agent. No wrapper files are needed.

### 3.2 The 13 MAOS commands need no porting mechanism

MAOS's `commands/*.md` slash commands are a Claude-Code plugin surface. On Kiro the equivalent capability is delivered by the skills themselves: a skill in `~/.kiro/skills` **is** a `/slash` command. So the command capability arrives with step 1 of the install. **Invocation changes, capability does not** — e.g. Claude Code's `/maos:auto-pilot` is reached on Kiro as the `auto-pilot` skill's own slash command. We deliberately do **not** ship 13 command wrapper files for Kiro; that would be duplicated surface with no added capability.

### 3.3 Agents

Agent persona definitions in `agents/` are **repository-only source** — the skills CLI installs skills, not agents, so **step 1 installs none of them** and there is no `agents/` install step to run. They stay readable/usable as source (markdown + YAML frontmatter) and delegation guidance is unchanged.

Kiro's own custom-agent surface is a **different format in a different place**: JSON files under `~/.kiro/agents/` (project-scoped: `.kiro/agents/`), where an agent grants itself skills via `"resources": ["skill://.kiro/skills/**/SKILL.md"]`. So porting a MAOS persona to a first-class Kiro agent means **authoring a Kiro agent JSON that points at the installed skills** — a deliberate conversion, not a copy. Until someone does that, the personas are consumed as source/context by whichever agent reads them, which is why step 1 alone already delivers the delegation capability.

## 4. Governance hooks — 6 of 8 classes port

MAOS ships governance via `hooks/hooks.json` (Claude Code hook classes). Probed on `kiro-cli 2.22.0` with `kiro-cli agent validate` — the validator **rejects unknown keys**, so acceptance is meaningful.

**Kiro 2.22.0 ACCEPTS** (lowercase camelCase): `preToolUse`, `postToolUse`, `userPromptSubmit`, `agentSpawn`, `stop`. `matcher` takes a regex alternation (e.g. `execute_bash|fs_write`). **`preToolUse` genuinely BLOCKS** — a non-zero exit vetoes the tool call.

**Kiro 2.22.0 REJECTS**: the 3.0-capitalised `PreToolUse` etc., plus `preCompact`, `postCompact`, `preTaskExec`, `postTaskExec`, `postFileCreate|Save|Delete`, `sessionStart`, `sessionEnd`, `manual`.

Tool names translate: `Bash` → `execute_bash`; `Edit|Write|MultiEdit` → `fs_write`; `Task` → `use_subagent`. Verify the current set against your own build (`kiro-cli` reports its callable tool identifiers) rather than assuming — the identifier is `use_subagent`, not `invoke_subagent`/`spawn_subagent`.

| MAOS hook class | Kiro 2.22.0 mapping | Verdict |
|---|---|---|
| `SessionStart` (session-start, auto-name, preflight, reload, single-conductor-scan, session-tip) | `agentSpawn` | **ports** |
| `PreToolUse[Bash]` (worktree-gate, agentshield) | `preToolUse` matcher `execute_bash` | **ports — truly blocks** |
| `PreToolUse[Task]` (pre-delegate, token-budget-gate, agentshield) | `preToolUse` matcher `use_subagent` | **ports** |
| `PreToolUse[Edit\|Write\|MultiEdit]` (preflight-edit-gate) | `preToolUse` matcher `fs_write` | **ports** |
| `PostToolUse[Task]` (post-delegate) | `postToolUse` | **ports** |
| `Stop` (session-end) | `stop` | **ports** |
| `PreCompact` (postflight-precompact) | — no compaction event | **LOST** |
| `PostCompact` (postflight-postcompact) | — no compaction event | **LOST** |

**The honest loss, stated plainly:** only **context-compaction governance** (`PreCompact` / `PostCompact`) is genuinely unavailable on Kiro 2.22.0, because Kiro exposes no compaction hook event. The two MAOS scripts behind them (`postflight-precompact.sh`, `postflight-postcompact.sh`) have no Kiro trigger. This is a real gap, not a rename — do not expect compaction-time governance on Kiro until Kiro adds such an event.

> Note: this repo does not ship a pre-built Kiro `hooks` config; the mapping above is the **porting guide** for a user who wants MAOS governance under Kiro. The verified-accepted event set is the authoritative surface to target.

## 5. `permissions.yaml` — a stronger deny layer Kiro adds (IDE + CLI surfaces only)

Independently of hooks, Kiro has `permissions.yaml`: **capability + match/exclude globs + effect**, with **deny-overrides across all scopes**, compound commands split on `;` `&&` `||` `|`, and — in headless turns — **every `ask` becomes `deny`**. This is a **stronger deterministic deny layer** than Claude Code's, on a different axis from the hook classes above. A fleet operator hardening MAOS on Kiro should express blunt deny rules here rather than only in hooks.

**Scope this precisely — it is not one deny layer across all of Kiro.** `permissions.yaml` governs the **Kiro IDE and `kiro-cli` surfaces**. **Kiro Crew (the gateway) does not read it**: Crew is governed by its own trust root — `security_policy.json`, `profiles/`, `admission_policy.json` and `denied_commands.json` under Crew's data home, plus a self-protection floor — which is deliberately unreachable from inside a tool call (that unreachability is what makes it un-disableable, not a misconfiguration). Consequence for a fleet operator: hardening `permissions.yaml` **does not harden Crew**, and the two must be configured separately. Writing a deny rule in one and assuming coverage of the other is the mistake to avoid.

## 6. Co-habitation hazard: name masking (first-writer-wins)

Skill loaders resolve roots in order and **mask duplicate skill names first-writer-wins**. A drifted **older** copy of a skill sitting in an earlier-resolved root silently shadows a newer one, so a "successful" publish can have **zero effect**. Claude logs `Skill "<name>" is masked by <path>`; some resolvers (e.g. Amp resolving `~/.agents/skills` before `~/.claude/skills`) skip the later duplicate silently.

**What this means for a Kiro + Claude Code co-habitant:** if the same skill name exists under both a Kiro root and a Claude root that a given harness resolves, the earlier-resolved one wins for that harness. Keep one authoritative copy per name, and when a publish appears to have no effect, check for a masking log line and a stale earlier-root copy before re-publishing.

## 7. What we did NOT verify (report honestly)

- **Kiro Powers as a Vek distribution surface.** `~/.kiro/powers/registry.json` supports a `repoSources` slot (a Power = git repo + path), but it is currently empty on the reference host and the exact user-facing action that ADDS a `repoSources` entry (dashboard vs CLI vs hand-edit) was **not verified**. `registry.json`/`installed.json` are machine-owned and must never be hand-edited. Treat a Vek Powers repo as a **target** capability, not a shipped one. Agent Skills (§1–2) is the verified install path.
- A pre-built, ready-to-load Kiro `hooks` JSON for MAOS is **not shipped** here; §4 is the porting guide, not a drop-in artifact.

## References

- Install steps: [README → Installation → Kiro](../README.md#kiro-cli--kiro-ide--kiro-crew)
- Vendor-neutral agent contract: [`AGENTS.md`](../AGENTS.md)
- Why copies not symlinks (loader behaviour): [`docs/why-not-symlinks.md`](./why-not-symlinks.md)
- MAOS hook config: [`hooks/hooks.json`](../hooks/hooks.json)
