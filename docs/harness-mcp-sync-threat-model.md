# harness-mcp-sync — failure-class threat model (PDCA round 11)

Scope: `bin/harness-mcp-sync`. This round fixes **classes of failure**, not single findings.
Each class lists every instance found by auditing the executor, with the regression
test that pins it (`bin/tests/harness-mcp-sync.test.sh`, block "PDCA round 11").
Negative control: the new block fails 22 assertions against `8bd0c74` and passes on
this head.

## C-A — git environment trust

**Threat.** The git-safety gate decides whether a secret may be written to a config
file (a tracked or untracked file inside a git work tree is refused). The executor runs
`git` as a subprocess, so every inherited `GIT_*` variable and every global/system config
file can move the probe to another repository, another index or another work tree. The
gate then answers "not in a repo" for a file that *is* tracked, and a secret lands in
version control. Source: CodeRabbit Major 4107215664.

| Instance | Fix | Test |
|---|---|---|
| `_git()` (ls-files / check-ignore probes used by build_plan, doctor, verify) | `env=_git_env()`: drop every `GIT_*` variable, set `GIT_CONFIG_NOSYSTEM=1`, `GIT_CONFIG_GLOBAL=/dev/null` | C-A unit, 9 variables |
| `rev-parse --is-inside-work-tree` | same env | C-A unit |
| end-to-end apply of a secret server under `GIT_DIR=<bogus>` | refused, file untouched, non-zero exit | C-A e2e |

Covered variables: `GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_OBJECT_DIRECTORY`,
`GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_COMMON_DIR`, `GIT_CEILING_DIRECTORIES`,
`GIT_CONFIG_COUNT/KEY_n/VALUE_n`, `GIT_CONFIG_GLOBAL`. The scrub is by prefix, so a
variable git adds later is also dropped. `core.fsmonitor=false`, `core.hooksPath=/dev/null`
and `stdin=DEVNULL` (earlier rounds) remain.

**Stated trade-off.** Ignoring the global config also ignores a global
`core.excludesFile`. A file ignored only by the operator's global excludes is therefore
classified `untracked`, and a secret write to it is refused. This is stricter, not looser
(fail-closed). Any git error still maps to `unknown`, which also refuses secrets.

## C-B — multi-harness atomicity

**Threat.** `apply` and `restore` loop over harnesses. If the manifest is persisted only
once after the loop, a failure in the middle leaves configs already written (or restored)
while the manifest still describes the old state. The next run then either adopts
foreign entries or deletes owned ones. Source: Codex P1 4107275318; apply audited for
the same shape.

| Instance | Fix | Test |
|---|---|---|
| restore: manifest reconciled after the loop | reconcile and `save_manifest` per restored harness | C-B restore (later payload missing) |
| restore: exception from one harness aborts the rest | per-harness try; failure is reported as `refused … file left unchanged`, exit non-zero | C-B restore |
| apply: `save_manifest` fails after the config write | the write is rolled back from the backup, the manifest entry is reverted, the error re-raised | C-B apply (fault-injected) |

## C-C — config shape strictness

**Threat.** A managed path (`key_path`) whose value is an explicit `null`, a list or a
scalar was treated as "absent" and overwritten with a fresh mapping. That silently
destroys user data of an unexpected shape. Source: Codex P2 4107275343.

| Instance | Fix | Test |
|---|---|---|
| JSON `"mcpServers": null` | `map_shape_error` flags any non-mapping at any level → malformed, untouched | C-C hnj |
| YAML `extensions: null` | same | C-C hny |
| nested path, first level `null` | same (checked per level) | C-C hn2 |
| verify | reuses `map_shape_error` | covered by the same helper |

## C-D — transport alias normalization

**Threat.** The SSOT may spell a remote transport `http` while an adapter declares only
`streamable-http` (or the reverse). The adapter lookup then misses and renders a spelling
the harness does not accept, or apply and verify disagree. Source: Codex P2 4107275325.

| Instance | Fix | Test |
|---|---|---|
| `render_entry` (all styles; used by apply and verify) | `canonical_transport()`: if the transport is `http`/`streamable-http` and not declared, use the declared alias | C-D htsh, hthp |
| both declared | unchanged | C-D htbo ×2 |
| verify agrees with apply | same function | C-D verify assertions |

## Out of scope (not changed this round)

Registry authorship (trusted, reviewed data), the operator's own shell, and a local
attacker with write access to `$HOME` are outside this model, as in earlier rounds.
