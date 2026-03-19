# MCP-JSON-RPC Error Protocol (Global Standard)

<!-- Shard of ~/.claude/CLAUDE.md | Section: C06 AI-Native Environment -->
<!-- Version: 1.0.0 | Created: 2026-01-22 -->

## Purpose

Define a standardized error response format for scripts to enable **AI agents** to:
1. Parse errors programmatically from stderr
2. Understand what went wrong
3. Execute recovery actions automatically without human intervention

---

## Core Principle: JSON First, Human After

```
┌────────────────────────────────────────────────────────────────────────┐
│  ORDEM OBRIGATÓRIA para Output de Erros                                │
├────────────────────────────────────────────────────────────────────────┤
│  1. JSON-RPC error → stderr (SEMPRE, para AI parsing)                  │
│  2. Human-readable → stderr/stdout (SE não --json mode)                │
│                                                                        │
│  RAZÃO: AI agent encontra JSON imediatamente no início do stderr       │
└────────────────────────────────────────────────────────────────────────┘
```

---

## JSON-RPC 2.0 Error Format

```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32001,
    "message": "Human-readable error message",
    "data": {
      "details": "Additional context about the error",
      "instructions": "EXACT command to fix: ./script.sh --flag -y",
      "context": "error-category-identifier"
    }
  },
  "id": "unique-request-id"
}
```

### Field Requirements

| Field | Required | Description |
|-------|----------|-------------|
| `error.code` | **YES** | Standard or custom error code |
| `error.message` | **YES** | Human-readable summary |
| `error.data.details` | Optional | Additional context |
| `error.data.instructions` | **CRITICAL** | Actionable command for recovery |
| `error.data.context` | Optional | Category identifier |

---

## Error Codes

### Standard JSON-RPC Codes

| Code | Name | Description |
|------|------|-------------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid request | Not a valid request object |
| -32601 | Method not found | Method does not exist |
| -32602 | Invalid params | Invalid method parameters |
| -32603 | Internal error | Internal JSON-RPC error |

### Custom Codes (-32000 to -32099)

| Code | Name | Description | Recovery |
|------|------|-------------|----------|
| -32000 | Server error | Generic error | Check logs |
| **-32001** | **Requires interaction** | Needs user confirmation | Add `-y` flag |
| **-32002** | Branch gate | Wrong git branch | `git checkout main` or `--force` |
| **-32003** | External dependency | Service not found | Check installation |

---

## The `instructions` Field (CRITICAL)

The `instructions` field MUST contain an **actionable command** that the AI agent can execute directly:

### GOOD Instructions

```json
{"instructions": "Re-run with -y flag: ./scripts/sync.sh --cleanup -y"}
```

```json
{"instructions": "Run: ./scripts/sync.sh --init"}
```

```json
{"instructions": "Either: (1) git checkout main, or (2) use --force flag"}
```

### BAD Instructions (AVOID)

```json
{"instructions": "Check your configuration"}  // Too vague
```

```json
{"instructions": "Contact support"}  // Not actionable by AI
```

---

## Implementation Patterns

### Bash Scripts

```bash
json_error() {
    local code="${1:--32000}"
    local message="${2:-Error}"
    local details="${3:-}"
    local instructions="${4:-}"
    local context="${5:-}"

    local data_json="\"details\": \"${details}\""

    if [ -n "$instructions" ]; then
        data_json="${data_json}, \"instructions\": \"${instructions}\""
    fi

    if [ -n "$context" ]; then
        data_json="${data_json}, \"context\": \"${context}\""
    fi

    cat << EOF >&2
{
  "jsonrpc": "2.0",
  "error": {
    "code": ${code},
    "message": "${message}",
    "data": {
      ${data_json}
    }
  },
  "id": "$(uuidgen 2>/dev/null || echo "script-$$")"
}
EOF
}

# Usage - JSON FIRST, then human if not --json
handle_error() {
    # ALWAYS output JSON error first (for AI agents)
    json_error \
        -32001 \
        "Requires interaction: needs confirmation" \
        "Found 3 items to process" \
        "Re-run with -y flag: ./script.sh -y" \
        "non-interactive"

    # Then human-readable if not in JSON mode
    if [ "$JSON_OUTPUT" != true ]; then
        echo "Error: needs confirmation. Use -y flag." >&2
    fi
    exit 1
}
```

### Python Scripts

```python
import json
import sys
from uuid import uuid4

def output_json_error(
    code: int,
    message: str,
    details: str = "",
    instructions: str = "",
    context: str = ""
) -> None:
    error = {
        "jsonrpc": "2.0",
        "error": {
            "code": code,
            "message": message,
            "data": {
                "details": details,
                "instructions": instructions,
                "context": context,
            },
        },
        "id": str(uuid4()),
    }
    print(json.dumps(error), file=sys.stderr)

# Usage
def handle_error():
    # ALWAYS output JSON error first
    output_json_error(
        code=-32001,
        message="Requires interaction",
        details="Found 3 items",
        instructions="Re-run: ./script.py --cleanup -y",
        context="non-interactive"
    )

    # Then human-readable if not JSON mode
    if not json_output_mode:
        print("Error: needs confirmation. Use -y flag.", file=sys.stderr)

    sys.exit(1)
```

---

## Non-Interactive Detection

AI agents (like Claude Code) run commands non-interactively. Scripts MUST detect this:

### Bash

```bash
if [ ! -t 0 ]; then
    # Non-interactive mode - output JSON error with instructions
    json_error -32001 "Requires interaction" "..." "Use -y flag"
    exit 1
fi
```

### Python

```python
import sys
if not sys.stdin.isatty():
    output_json_error(-32001, "Requires interaction", ...)
    sys.exit(1)
```

---

## AI Agent Recovery Flow

```
1. Agent executes: ./scripts/sync.sh --cleanup
2. Script detects non-interactive mode (no TTY)
3. Script outputs to stderr:
   {
     "error": {
       "code": -32001,
       "message": "Requires interaction",
       "data": {
         "instructions": "Re-run with -y flag: ./scripts/sync.sh --cleanup -y"
       }
     }
   }
4. Agent parses stderr, extracts instructions
5. Agent executes: ./scripts/sync.sh --cleanup -y
6. Script completes successfully
```

---

## Adoption Checklist for Scripts

- [ ] JSON error outputs to **stderr** (not stdout)
- [ ] JSON error is output **FIRST** (before human messages)
- [ ] `instructions` field contains **exact command** to fix
- [ ] Non-interactive detection (`[ ! -t 0 ]`) is implemented
- [ ] Human-readable output only when `JSON_OUTPUT != true`
- [ ] Exit codes are semantic (0=success, 1=error)

---

## Scripts Using This Protocol

| Script | Location | Error Codes |
|--------|----------|-------------|
| `sync-to-drive.sh` | Project-specific | -32001, -32002, -32003, -32602 |
| `sync-to-confluence.py` | Project-specific | -32000 |
| `sync-to-notebooklm.py` | Project-specific | -32000 |

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-22 | Initial spec with JSON-first order, instructions field |

---

*Assinatura: Claude-Code | 2026-01-22T12:00:00-03:00*
