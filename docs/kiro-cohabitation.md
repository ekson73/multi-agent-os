# Kiro co-habitation & compatibility

> How MAOS installs on the Kiro family (`kiro-cli`, Kiro IDE, Kiro Crew) **alongside**
> Claude Code on the same machine, and an honest account of what ports and what does not.
> Verified on `kiro-cli 2.22.0`, 2026-09-17.

## TL;DR

- MAOS installs on Kiro in **two steps**: `npx skills add ekson73/multi-agent-os -g -a kiro-cli`, then one config line for Kiro Crew (which the skills CLI cannot reach). See [Installation](#1-installation-two-steps).
- Every change for Kiro is **ADDITIVE**. Nothing under `~/.claude/**` or any other harness path is removed, renamed, reordered or degraded. You can run Kiro and Claude Code simultaneously on the same host.
- Governance hooks: **6 of the 8 MAOS hook classes port** to Kiro's hook system. The **only** genuine loss is context-compaction governance (`PreCompact`/`PostCompact`) — Kiro 2.22.0 has no compaction hook event. Kiro's `permissions.yaml` is a **stronger** deterministic deny layer than Claude Code's, on a different axis.
- No `KIRO.md`. [`AGENTS.md`](../AGENTS.md) is the vendor-neutral SSOT and Kiro reads it.

## 1. Installation (two steps)

The Kiro install is two steps because [Kiro has two independent skill loaders](#2-kiro-has-two-independent-skill-loaders) and the `skills` CLI reaches only one of them.

```bash
# 1 — kiro-cli + the Kiro IDE default agent (skills become /slash commands automatically)
npx skills add ekson73/multi-agent-os -g -a kiro-cli

# 2 — Kiro Crew: a SEPARATE loader. Point it at what step 1 already wrote.
kirocrew config set skills.extra_paths '["~/.kiro/skills"]'
```

Verify step 2:

```bash
kirocrew config get skills.extra_paths
```

`extra_paths` is watched, so step 2 applies with **no restart**. Step 2 needs no clone and no repo path — it reuses step 1's copy, so there is **one copy on disk, two loaders**. A fleet user has no checkout of this repo.

`-a kiro-cli` writes real **copies** (`"mode": "copy"`, not symlinks) into `~/.kiro/skills/<name>/SKILL.md`. Why copies and not symlinks is a loader-behaviour decision covered in [`why-not-symlinks.md`](./why-not-symlinks.md).

### The agent id is `kiro-cli` — nothing else

The `npx skills` id for the Kiro family is **`kiro-cli`**. `kiro`, `kiro-ide` and `kiro-crew` are **NOT** valid ids: `-a kiro` returns `Invalid agents: kiro`, `"status": "failed"`, and writes **zero files** — a silent no-op. Publish only `kiro-cli`.

A **private** repo install needs working git auth: the CLI tries the git credential helper, then `gh repo clone`, then SSH.

## 2. Kiro has TWO independent skill loaders

This is the single fact that makes the Kiro install two steps instead of one. Do not assume one loader covers the other — it does not.

| Loader root | Read by | Notes |
|---|---|---|
| `~/.kiro/skills` | **kiro-cli AND the Kiro IDE default agent** | entries automatically become `/slash` commands |
| `~/.kiro/crew/skills` + `skills.extra_paths` | **Kiro Crew ONLY** | the `skills` CLI has no agent id that writes here |

`npx skills add … -a kiro-cli` reaches the **first** loader and **never** the second. Kiro Crew is reached only by step 2 (`skills.extra_paths`), which is why the install is two steps.

## 3. Governance hooks — 6 of 8 classes port

MAOS ships governance via [`hooks/hooks.json`](../hooks/hooks.json) (Claude Code hook classes). This was probed on `kiro-cli 2.22.0` with `kiro-cli agent validate` — the validator **rejects unknown keys**, so acceptance is meaningful.

**Kiro 2.22.0 ACCEPTS** (lowercase camelCase): `preToolUse`, `postToolUse`, `userPromptSubmit`, `agentSpawn`, `stop`. `matcher` takes a regex alternation (e.g. `execute_bash|fs_write`). **`preToolUse` genuinely BLOCKS** — a non-zero exit vetoes the tool call.

**Kiro 2.22.0 REJECTS**: the 3.0-capitalised `PreToolUse` etc., plus `preCompact`, `postCompact`, `preTaskExec`, `postTaskExec`, `postFileCreate|Save|Delete`, `sessionStart`, `sessionEnd`, `manual`.

Tool names must be translated: `Bash` → `execute_bash`; `Edit|Write|MultiEdit` → `fs_write`.

| MAOS hook class | Kiro 2.22.0 mapping | Verdict |
|---|---|---|
| `SessionStart` | `agentSpawn` | **ports** |
| `PreToolUse[Bash]` (worktree-gate, agentshield) | `preToolUse` matcher `execute_bash` | **ports — truly blocks** |
| `PreToolUse[Task]` (token-budget-gate, agentshield, pre-delegate) | `preToolUse` on the spawn tool | **ports** |
| `PreToolUse[Edit\|Write\|MultiEdit]` (preflight-edit-gate) | `preToolUse` matcher `fs_write` | **ports** |
| `PostToolUse[Task]` (post-delegate) | `postToolUse` | **ports** |
| `Stop` (session-end) | `stop` | **ports** |
| `PreCompact` (postflight-precompact) | — no compaction event | **LOST** |
| `PostCompact` (postflight-postcompact) | — no compaction event | **LOST** |

**The honest loss, stated plainly:** only **context-compaction governance** (`PreCompact` / `PostCompact`) is genuinely unavailable on Kiro 2.22.0, because Kiro exposes no compaction hook event. This is a real gap, not a rename — do not expect compaction-time governance on Kiro until Kiro adds such an event.

## 4. `permissions.yaml` — a stronger deny layer Kiro adds

Independently of hooks, Kiro has `permissions.yaml`: **capability + match/exclude globs + effect**, with **deny-overrides across all scopes**, compound commands split on `;` `&&` `||` `|`, and — in headless turns — **every `ask` becomes `deny`**. This is a **stronger deterministic deny layer** than Claude Code's, on a different axis from the hook classes above. A fleet operator hardening MAOS on Kiro should express blunt deny rules here rather than only in hooks.

## 5. Co-habitation: the install is ADDITIVE, but watch name masking

**Additive by construction.** Installing MAOS on Kiro writes only to `~/.kiro/**` and, via step 2, a Kiro Crew config entry. It removes, renames or alters **nothing** under `~/.claude/**` or any other harness path. Kiro and Claude Code run side by side on the same machine, at the same time, off their own roots.

**First-writer-wins name masking — the hazard to know about.** Skill loaders resolve roots in order and **mask duplicate skill names first-writer-wins**. A drifted **older** copy of a skill sitting in an earlier-resolved root silently shadows a newer one, so a "successful" publish can have **zero effect**. Claude logs `Skill "<name>" is masked by <path>`; some resolvers (e.g. Amp resolving `~/.agents/skills` before `~/.claude/skills`) skip the later duplicate silently.

What this means for a Kiro + Claude Code co-habitant: if the same skill name exists under both a Kiro root and a Claude root that a given harness resolves, the earlier-resolved one wins **for that harness**. Keep one authoritative copy per name, and when a publish appears to have no effect, check for a masking log line and a stale earlier-root copy before re-publishing.

## 6. What we did NOT verify (reported honestly)

- **Kiro Powers as a Vek distribution surface.** `~/.kiro/powers/registry.json` supports a `repoSources` slot (a Power = git repo + path), but it is currently **empty** on the reference host and the exact user-facing action that ADDS a `repoSources` entry (dashboard vs CLI vs hand-edit) was **not verified**. `registry.json`/`installed.json` are machine-owned and must never be hand-edited. Treat a Vek Powers repo as a **target** capability, not a shipped one. Agent Skills (§1–2) is the verified install path.
- A pre-built, ready-to-load Kiro `hooks` config for MAOS is **not shipped** here; §3 is the porting guide, not a drop-in artifact.

## References

- Multi-host install matrix (incl. the two-step Kiro block): [`multi-host-packaging.md`](./multi-host-packaging.md)
- Vendor-neutral agent contract: [`AGENTS.md`](../AGENTS.md)
- Why copies not symlinks (loader behaviour): [`why-not-symlinks.md`](./why-not-symlinks.md)
- MAOS hook config: [`hooks/hooks.json`](../hooks/hooks.json)
