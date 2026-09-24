# Harness adapter registry

One YAML file per AI harness (`harnesses/<id>.yaml`). This directory is **data**, not
code: the executor (`bin/harness-mcp-sync`) and the knowledge skill read it to learn where
each harness keeps its MCP configuration, what shape that configuration has, and which
CLI commands manage it. Adding a harness = adding one file. No secrets ever live here.

> **Limit:** secret-carrying detection in git-tracked files is heuristic for positional args and literal header values (flags like `--api-key`, high-entropy tokens); short or low-entropy literal secrets are undetectable — keep secrets in placeholders (`${VAR}`, `op://…`).

## Contract (schema v1)

```yaml
schema: 1                     # contract version (int, required)
id: codex                     # kebab-case, == filename stem (required)
name: OpenAI Codex CLI        # display name (required)
vendor: OpenAI                # (optional)
kind: cli                     # cli | ide | desktop-app | extension | agent-runtime
detect:                       # how to tell it is installed (any match = installed)
  commands: [codex]           # binaries looked up on PATH
  paths: ["~/.codex"]         # files/dirs whose existence proves install (~ expanded)
mcp:
  supported: true             # false => executor reports "no-mcp" and skips
  config_paths:               # candidate files, first existing wins; user scope first
    - path: "~/.codex/config.toml"
      scope: user             # user | project | workspace
  format: toml                # json | jsonc | toml | yaml
  key_path: [mcp_servers]     # path to the server MAP inside the file (list of keys)
  entry_style: codex          # which entry shape to render (see "Entry styles")
  entry_overrides:            # OPTIONAL per-harness field tweaks for the chosen style (see below)
    url_field: url            # string, or map by transport {streamable-http: httpUrl, sse: url}
    type_field: type          # key carrying the transport discriminator (e.g. `transport`)
    type_values: {stdio: null, streamable-http: http, sse: sse}   # null => omit the type key
    extra: {tools: ["*"]}     # static keys merged into every rendered entry
  transports: [stdio, streamable-http]   # subset of stdio | http | streamable-http | sse
  supports:
    headers: true             # remote server may carry static HTTP headers
    env: true                 # stdio server may carry an env map
    disable: true             # an entry-level on/off flag exists
    disable_field: enabled    # field name; semantics set by disable_semantics
    disable_semantics: enabled-bool   # enabled-bool (enabled: false) | disabled-bool (disabled: true)
  cli:                        # null when the harness has no command for it
    add: "codex mcp add <name> -- <command>"
    list: "codex mcp list"
    remove: "codex mcp remove <name>"
extensions:                   # optional: non-MCP extension surfaces
  skills: null                # command or path, or null
  plugins: null
  marketplace: null
update:
  version_cmd: "codex --version"
  update_cmd: "npm i -g @openai/codex"   # informative only; executor never runs it (T2)
docs_url: "https://..."
last_verified: "2026-09-24"   # ISO date the facts above were checked
confidence: high              # high = verified on disk + docs · medium = docs only · low = unverified
skip_reason: null             # non-null => executor never writes (reports reason instead)
notes: "free text; caveats"
```

## Entry styles

The executor maps one vendor-neutral server definition onto the harness-specific
shape named by `entry_style`. Styles are defined in ONE table (`STYLES`) in
`bin/harness-mcp-sync`. A harness whose shape does not match any existing style gets a new
style there — never an ad-hoc shape in the YAML. Small per-harness field differences inside
a family (e.g. Gemini/Qwen `httpUrl`, Antigravity `serverUrl`, Kimi `transport` instead of
`type`, Copilot's required `tools: ["*"]`) are expressed with the optional
`mcp.entry_overrides` block, which only the `mcpservers-json` / `vscode-servers` family reads
(`headers_field` is also honoured by `codex`). Styles with no safe writer (`reasonix-toml`,
`unknown`) are reported as unsupported and never written.

| style | format | notes |
|---|---|---|
| mcpservers-json | json/jsonc | `{type?, url, headers}` / `{type?, command, args, env}`; map key from `key_path` |
| vscode-servers | json/jsonc | same family, `type` always emitted (`stdio`/`http`/`sse`) |
| amp-settings | json | no `type`; literal dotted key `amp.mcpServers` |
| opencode | json | `{type: remote, url, headers}` / `{type: local, command: [cmd, ...args], environment}` |
| zed-context-servers | jsonc | `{source: custom, command, args, env}` / `{url, headers}` |
| goose-extensions | yaml | `{name, type: stdio, cmd, args, envs}` / `{name, type: streamable_http, uri, headers}` |
| codex | toml | `[mcp_servers.<n>]` + `[mcp_servers.<n>.http_headers]` / `.env` sub-tables (surgical edit) |
| grok-toml | toml | codex-like; `headers = {...}` / `env = {...}` inline tables (surgical edit) |

## Confidence rules

- `high`: config file observed on a real install AND shape confirmed against vendor docs.
- `medium`: vendor docs only, or file observed but shape inferred.
- `low`: unverified. The executor treats `low` as **plan-only** (never applies) and says so.
- Unknown harness: add a file with `confidence: low` after research — never invent paths.
