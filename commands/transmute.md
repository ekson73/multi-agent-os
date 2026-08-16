---
name: transmute
description: Transmute ONE source of any kind (text · prompt · draft · braindump · doc · code · agentic-tool) through a transformation menu (analyze · critique · meta-critique · red-team · validate · fix · enhance · refine · sanitize · harmonize · compliance) and CAST it into a target type (same-as-source default · prompt · agentic-tool · audience-recast · artifact · ledger · ticket) emitted to one-or-more sinks (stdout · clipboard · vault/obsidian · path · git-repo · jira · linear · atlassian · bitbucket · github · confluence · gamma · canva · agentic-tool). Thin router composing existing primitives. Safe default dry-run.
---

# /transmute Command

Thin wrapper that invokes `skills/transmute/SKILL.md`. The skill holds all logic
(pipeline predicate, cast router, composition map, sink axis, STOP-marker grammar,
bounds). This file is the command surface only. Soul-name: *Proteus*.

## Usage

```text
/transmute "<source>" [--transforms=…] [--to-type=…] [--output-target=…]
                     [--mode=…] [--principles=auto] [--user-lang=pt-BR]
                     [--agentic-lang=en-US] [--output=…] [--max-rounds=12]
```

## Flags

| Flag | Default | Allowed values |
|---|---|---|
| `"<source>"` (positional) | *required* | path · glob · inline text · `-` (stdin). Empty/unfilled placeholder → STOP-ERROR |
| `--transforms` | `analyze,refine` | ordered comma list (analyze, critique, meta-critique, red-team, validate, fix, enhance, refine, sanitize, harmonize, dogfood); `auto` = infer |
| `--to-type` | `same-as-source` | `prompt` · `agentic-tool:{skill\|command\|agent\|subagent\|rule\|memory\|hook\|webhook\|event\|trigger\|mcp\|plugin\|marketplace}` · `audience-recast` · `artifact:{md\|html\|pdf\|slides\|diagram\|confluence\|gamma\|canva}` · `ledger` · `ticket`/`ticket:{jira\|linear}` |
| `--output-target` | *(report inline)* | comma sinks: `stdout` · `clipboard` · `vault[:path]`/`obsidian[:path]` · `path:P` · `git-repo:P` · `agentic-tool:kind:path` · `jira[:key]` · `linear[:key]` · `confluence[:space]` · `gamma[:deck]` · `canva[:design]` · `bitbucket:P` · `github:P` · `atlassian:P` |
| `--mode` | `dry-run` | `dry-run` · `run` · `dogfood` (aliases: `--dry-run`/`--run`/`--dogfood`) |
| `--principles` | `auto` | inherit host governance corpus by reference (`auto`=full 40+ list; csv validated) |
| `--user-lang` | `pt-BR` | operator-facing prose |
| `--agentic-lang` | `en-US` | rendered-artifact language |
| `--agentic-format` | `json-rpc` | alias of `--output=json-rpc` (`method`+`params` per [C06]) |
| `--output` | `table` | `table` · `json` · `json-rpc` |
| `--max-rounds` | `12` | hard cap for looped verbs |

## Examples

```text
/transmute ~/dumps/round-n1.braindump.md --to-type=prompt --output-target=clipboard
/transmute "src/**" --transforms=sanitize,analyze,fix --mode=run --output-target=git-repo:./
/transmute docs/spec.md --to-type=audience-recast --dry-run
/transmute README.md --to-type=agentic-tool:skill --mode=dogfood
/transmute report.md --to-type=artifact:pdf --output-target=path:./out/report.pdf
```

## Related

- `skills/transmute/SKILL.md` — full logic + cast router + composition map
- Siblings: `refine-braindump-to-prompt` · `agentic-tool-forge` · `content-recast` ·
  `enhance-pipeline` · `directive-braindump-triage`
