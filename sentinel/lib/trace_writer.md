# Trace Writer Library

## Metadata
| Campo | Valor |
|-------|-------|
| **Version** | 1.0.0 |
| **Author** | Claude-Orch-Prime-20260106-c614 |
| **Created** | 2026-01-06 |
| **Part of** | Sentinel Protocol |
| **Language** | Python 3.8+ / Bash |

---

## Purpose

Esta biblioteca define padrões e procedimentos para escrita de eventos de trace em logs de auditoria no formato JSONL (JSON Lines). O formato JSONL foi escolhido por ser:

- **Append-friendly**: Cada linha é um JSON completo, permitindo escrita atômica
- **Streaming-friendly**: Pode ser lido linha por linha sem carregar arquivo inteiro
- **Corruption-resistant**: Se uma linha corromper, as demais permanecem válidas
- **Human-readable**: Pode ser inspecionado com ferramentas Unix padrão

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FLUXO DE ESCRITA DE TRACES                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Agent A ──┐                                                       │
│             │                                                       │
│   Agent B ──┼──► Trace Writer ──► session_{date}_{hex}.jsonl       │
│             │         │                                             │
│   Agent C ──┘         └──► session_index.json                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Write Patterns

### Atomic Append Pattern

O padrão de append atômico garante que cada trace seja escrito completamente ou não seja escrito de forma alguma, evitando corrupção parcial.

#### Python Implementation

```python
import json
import os
from datetime import datetime
from pathlib import Path

def append_trace(session_file: str, trace: dict) -> bool:
    """
    Append a single trace to a JSONL session file atomically.

    Args:
        session_file: Path to the session JSONL file
        trace: Dictionary containing the trace event

    Returns:
        bool: True if write succeeded, False otherwise
    """
    try:
        # 1. Add timestamp if not present
        if "timestamp" not in trace:
            trace["timestamp"] = datetime.now().isoformat()

        # 2. Serialize to single line (no pretty print)
        line = json.dumps(trace, ensure_ascii=False, separators=(',', ':')) + "\n"

        # 3. Open in append mode (atomic on POSIX systems)
        with open(session_file, "a", encoding="utf-8") as f:
            f.write(line)
            f.flush()  # Force write to OS buffer
            os.fsync(f.fileno())  # Force write to physical disk

        return True

    except (IOError, OSError, json.JSONEncodeError) as e:
        # Log error but don't crash
        print(f"[WARN] Failed to write trace: {e}")
        return False
```

#### Bash Implementation

```bash
#!/bin/bash
# atomic_append.sh - Append trace to JSONL file atomically

append_trace() {
    local session_file="$1"
    local trace_json="$2"

    # Ensure parent directory exists
    mkdir -p "$(dirname "$session_file")"

    # Atomic append using echo + redirect
    # Note: >> is atomic for lines < PIPE_BUF (usually 4KB)
    echo "$trace_json" >> "$session_file"

    # Force sync to disk
    sync
}

# Example usage:
# TRACE='{"event":"START","agent":"test","timestamp":"2026-01-06T19:00:00-03:00"}'
# append_trace "/path/to/session.jsonl" "$TRACE"
```

#### Princípios do Atomic Append

```
┌─────────────────────────────────────────────────────────────────────┐
│                    GARANTIAS DO ATOMIC APPEND                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  1. SERIALIZE FIRST   │  Nunca escreva parcialmente                │
│     ─────────────────│                                             │
│     trace → json_str │  Converta para string ANTES de abrir arquivo│
│                      │                                             │
│  2. SINGLE WRITE     │  Uma chamada write() por trace              │
│     ─────────────────│                                             │
│     f.write(line)    │  Não use múltiplos writes para um trace     │
│                      │                                             │
│  3. EXPLICIT SYNC    │  Garanta persistência em disco              │
│     ─────────────────│                                             │
│     flush() + fsync()│  Sem isso, dados podem ficar em buffer      │
│                      │                                             │
│  4. NEWLINE TERMINATOR │  Cada trace termina com \n               │
│     ─────────────────  │                                           │
│     line + "\n"        │  Permite leitura linha por linha          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

### Race Condition Prevention

Quando múltiplos agentes escrevem concorrentemente, é necessário prevenir condições de corrida.

#### Strategy A: Agent-Scoped Files (Recomendado)

Cada agente escreve em seu próprio arquivo de sessão, eliminando concorrência:

```python
import hashlib

def get_session_file(agent_id: str, base_dir: str = ".claude/audit") -> str:
    """
    Generate a unique session file path for an agent.

    Pattern: session_{YYYYMMDD}_{agent_hex}.jsonl

    Args:
        agent_id: Full agent identifier (e.g., "Claude-Orch-Prime-20260106-c614")
        base_dir: Base directory for audit logs

    Returns:
        str: Path to the agent's session file
    """
    from datetime import datetime

    # Extract date from agent_id or use current date
    today = datetime.now().strftime("%Y%m%d")

    # Generate short hex from agent_id
    agent_hex = hashlib.md5(agent_id.encode()).hexdigest()[:8]

    # Alternative: extract hex from agent_id if it follows pattern
    # e.g., "Claude-Orch-Prime-20260106-c614" → "c614"
    parts = agent_id.split("-")
    if len(parts) >= 4:
        agent_hex = parts[-1][:8]

    return f"{base_dir}/session_{today}_{agent_hex}.jsonl"
```

```
┌─────────────────────────────────────────────────────────────────────┐
│              AGENT-SCOPED FILES (SEM CONCORRÊNCIA)                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Agent: Claude-Orch-Prime-20260106-c614                            │
│  └──► session_20260106_c614.jsonl                                  │
│                                                                     │
│  Agent: Claude-Sub-Task1-20260106-a1b2                             │
│  └──► session_20260106_a1b2.jsonl                                  │
│                                                                     │
│  Agent: Claude-Sub-Task2-20260106-d3e4                             │
│  └──► session_20260106_d3e4.jsonl                                  │
│                                                                     │
│  ✓ Zero race conditions                                            │
│  ✓ Each agent writes independently                                 │
│  ✓ Easy to trace back to specific agent                           │
│  ✓ Parallelizable reads                                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Strategy B: File Locking (Para Arquivos Compartilhados)

Quando múltiplos agentes precisam escrever no mesmo arquivo:

```python
import fcntl
import time
from contextlib import contextmanager

@contextmanager
def locked_append(filepath: str, timeout: float = 5.0):
    """
    Context manager for exclusive file locking during append.

    Args:
        filepath: Path to file to lock
        timeout: Maximum seconds to wait for lock

    Yields:
        file: Opened file handle with exclusive lock

    Raises:
        TimeoutError: If lock cannot be acquired within timeout
    """
    start = time.time()
    f = open(filepath, "a", encoding="utf-8")

    try:
        while True:
            try:
                fcntl.flock(f.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break  # Lock acquired
            except BlockingIOError:
                if time.time() - start > timeout:
                    raise TimeoutError(f"Could not acquire lock on {filepath}")
                time.sleep(0.1)  # Wait and retry

        yield f

    finally:
        fcntl.flock(f.fileno(), fcntl.LOCK_UN)  # Release lock
        f.close()


def append_trace_locked(session_file: str, trace: dict) -> bool:
    """
    Append trace with file locking for concurrent access.
    """
    import json

    try:
        line = json.dumps(trace, ensure_ascii=False) + "\n"

        with locked_append(session_file) as f:
            f.write(line)
            f.flush()

        return True

    except (TimeoutError, IOError) as e:
        print(f"[WARN] Locked append failed: {e}")
        return False
```

#### Strategy C: Atomic Rename (Para Garantia Máxima)

Escreve em arquivo temporário e renomeia atomicamente:

```python
import tempfile
import shutil

def append_trace_atomic_rename(session_file: str, trace: dict) -> bool:
    """
    Most robust append using atomic rename.
    Slower but guarantees no corruption.
    """
    import json
    from pathlib import Path

    try:
        # 1. Read existing content (if any)
        existing = []
        if Path(session_file).exists():
            with open(session_file, "r") as f:
                existing = f.readlines()

        # 2. Write to temp file
        line = json.dumps(trace, ensure_ascii=False) + "\n"

        dir_path = Path(session_file).parent
        with tempfile.NamedTemporaryFile(
            mode="w",
            dir=dir_path,
            delete=False,
            suffix=".tmp"
        ) as tmp:
            tmp.writelines(existing)
            tmp.write(line)
            tmp_path = tmp.name

        # 3. Atomic rename (POSIX guarantees atomicity)
        shutil.move(tmp_path, session_file)

        return True

    except Exception as e:
        print(f"[WARN] Atomic rename append failed: {e}")
        # Clean up temp file if it exists
        if 'tmp_path' in locals():
            Path(tmp_path).unlink(missing_ok=True)
        return False
```

---

### Session File Naming

#### Pattern Specification

```
session_{YYYYMMDD}_{hex}.jsonl

Where:
  YYYYMMDD = Date in ISO 8601 short format (e.g., 20260106)
  hex      = 4-8 character hex identifier from agent ID
  .jsonl   = JSON Lines extension
```

#### Examples

```
session_20260106_c614.jsonl    ← Claude-Orch-Prime-20260106-c614
session_20260106_a1b2.jsonl    ← Claude-Sub-Task1-20260106-a1b2
session_20260107_f0f0.jsonl    ← Claude-Audit-Check-20260107-f0f0
```

#### Naming Function

```python
def generate_session_filename(agent_id: str) -> str:
    """
    Generate session filename from agent identifier.

    Args:
        agent_id: Agent identifier following pattern:
                  Claude-{Role}-{Date}-{Hex}

    Returns:
        str: Session filename

    Examples:
        >>> generate_session_filename("Claude-Orch-Prime-20260106-c614")
        'session_20260106_c614.jsonl'
    """
    import re
    from datetime import datetime

    # Try to extract from standard pattern
    match = re.search(r'(\d{8})-([a-f0-9]{4,8})$', agent_id, re.IGNORECASE)

    if match:
        date_str = match.group(1)
        hex_str = match.group(2).lower()
    else:
        # Fallback: use current date and hash of agent_id
        date_str = datetime.now().strftime("%Y%m%d")
        import hashlib
        hex_str = hashlib.md5(agent_id.encode()).hexdigest()[:4]

    return f"session_{date_str}_{hex_str}.jsonl"
```

---

### Error Recovery

Quando uma escrita falha, é importante ter estratégias de recuperação.

#### Recovery Strategies

```
┌─────────────────────────────────────────────────────────────────────┐
│                    ERROR RECOVERY STRATEGIES                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ERROR TYPE          │  RECOVERY ACTION                            │
│  ────────────────────┼──────────────────────────────────────────   │
│  Disk full           │  1. Log to stderr                           │
│                      │  2. Try /tmp as fallback                    │
│                      │  3. Set degraded flag in memory             │
│                      │                                             │
│  Permission denied   │  1. Check/fix permissions                   │
│                      │  2. Try alternate directory                 │
│                      │  3. Escalate to user                        │
│                      │                                             │
│  File locked         │  1. Retry with exponential backoff          │
│                      │  2. After N retries, write to buffer        │
│                      │  3. Flush buffer when lock available        │
│                      │                                             │
│  JSON encode error   │  1. Log raw trace to error log              │
│                      │  2. Sanitize non-serializable fields        │
│                      │  3. Continue with degraded trace            │
│                      │                                             │
│  Corrupted file      │  1. Detect via validation                   │
│                      │  2. Rename to .corrupted                    │
│                      │  3. Start new session file                  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

#### Error Recovery Implementation

```python
import os
import json
from pathlib import Path
from typing import Optional, List
from dataclasses import dataclass, field

@dataclass
class TraceWriterState:
    """Maintains writer state for error recovery."""
    session_file: str
    buffer: List[dict] = field(default_factory=list)
    failed_writes: int = 0
    degraded: bool = False
    fallback_dir: str = "/tmp/sentinel_fallback"

class ResilientTraceWriter:
    """
    Trace writer with automatic error recovery.
    """

    MAX_BUFFER_SIZE = 100
    MAX_RETRIES = 3

    def __init__(self, session_file: str):
        self.state = TraceWriterState(session_file=session_file)
        self._ensure_directory()

    def _ensure_directory(self):
        """Create directory if it doesn't exist."""
        Path(self.state.session_file).parent.mkdir(parents=True, exist_ok=True)

    def write(self, trace: dict) -> bool:
        """
        Write trace with automatic recovery on failure.

        Returns:
            bool: True if write succeeded (immediately or to buffer)
        """
        # Try primary write
        for attempt in range(self.MAX_RETRIES):
            if self._try_write(self.state.session_file, trace):
                self._flush_buffer()  # Try to flush any buffered traces
                return True

            # Exponential backoff
            import time
            time.sleep(0.1 * (2 ** attempt))

        # Primary failed, try fallback
        self.state.failed_writes += 1

        if self._try_fallback(trace):
            return True

        # All failed, buffer in memory
        return self._buffer_trace(trace)

    def _try_write(self, filepath: str, trace: dict) -> bool:
        """Attempt single write to file."""
        try:
            line = json.dumps(trace, ensure_ascii=False) + "\n"
            with open(filepath, "a", encoding="utf-8") as f:
                f.write(line)
                f.flush()
                os.fsync(f.fileno())
            return True
        except Exception:
            return False

    def _try_fallback(self, trace: dict) -> bool:
        """Try writing to fallback directory."""
        try:
            Path(self.state.fallback_dir).mkdir(parents=True, exist_ok=True)
            fallback_file = Path(self.state.fallback_dir) / Path(self.state.session_file).name
            return self._try_write(str(fallback_file), trace)
        except Exception:
            return False

    def _buffer_trace(self, trace: dict) -> bool:
        """Buffer trace in memory when disk write fails."""
        if len(self.state.buffer) >= self.MAX_BUFFER_SIZE:
            # Drop oldest if buffer full
            self.state.buffer.pop(0)
            self.state.degraded = True

        self.state.buffer.append(trace)
        return True  # Buffered successfully

    def _flush_buffer(self):
        """Attempt to write buffered traces."""
        while self.state.buffer:
            trace = self.state.buffer[0]
            if self._try_write(self.state.session_file, trace):
                self.state.buffer.pop(0)
            else:
                break  # Stop on first failure

        if not self.state.buffer:
            self.state.degraded = False

    def get_status(self) -> dict:
        """Return current writer status."""
        return {
            "session_file": self.state.session_file,
            "buffered_traces": len(self.state.buffer),
            "failed_writes": self.state.failed_writes,
            "degraded": self.state.degraded
        }
```

---

## Read Patterns

### Full Session Read

Leitura completa de todos os traces de uma sessão:

```python
from typing import List, Generator
import json

def read_session(session_file: str) -> List[dict]:
    """
    Read all traces from a session file.

    Args:
        session_file: Path to JSONL session file

    Returns:
        List of trace dictionaries

    Raises:
        FileNotFoundError: If session file doesn't exist
    """
    traces = []

    with open(session_file, "r", encoding="utf-8") as f:
        for line_num, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue  # Skip empty lines

            try:
                trace = json.loads(line)
                traces.append(trace)
            except json.JSONDecodeError as e:
                # Log but don't fail - file may be partially corrupted
                print(f"[WARN] Invalid JSON at line {line_num}: {e}")
                continue

    return traces
```

### Filtered Read

Leitura com filtros por critérios específicos:

```python
from typing import Callable, Optional
from datetime import datetime

def read_filtered(
    session_file: str,
    event_type: Optional[str] = None,
    agent_pattern: Optional[str] = None,
    since: Optional[datetime] = None,
    until: Optional[datetime] = None,
    severity: Optional[str] = None,
    predicate: Optional[Callable[[dict], bool]] = None
) -> List[dict]:
    """
    Read traces matching specified criteria.

    Args:
        session_file: Path to JSONL session file
        event_type: Filter by event type (e.g., "TOOL_CALL", "BRANCH")
        agent_pattern: Filter by agent ID pattern (supports * wildcard)
        since: Only traces after this timestamp
        until: Only traces before this timestamp
        severity: Minimum severity level
        predicate: Custom filter function

    Returns:
        List of matching trace dictionaries
    """
    import fnmatch

    traces = read_session(session_file)
    filtered = []

    severity_order = {"DEBUG": 0, "INFO": 1, "WARN": 2, "ERROR": 3, "CRITICAL": 4}
    min_severity = severity_order.get(severity, 0) if severity else 0

    for trace in traces:
        # Event type filter
        if event_type and trace.get("event") != event_type:
            continue

        # Agent pattern filter
        if agent_pattern:
            agent_id = trace.get("agent_id", "")
            if not fnmatch.fnmatch(agent_id, agent_pattern):
                continue

        # Timestamp filters
        if since or until:
            ts_str = trace.get("timestamp", "")
            if ts_str:
                try:
                    ts = datetime.fromisoformat(ts_str.replace("Z", "+00:00"))
                    if since and ts < since:
                        continue
                    if until and ts > until:
                        continue
                except ValueError:
                    pass  # Invalid timestamp, include trace

        # Severity filter
        if severity:
            trace_severity = severity_order.get(trace.get("severity", "INFO"), 1)
            if trace_severity < min_severity:
                continue

        # Custom predicate
        if predicate and not predicate(trace):
            continue

        filtered.append(trace)

    return filtered


# Usage examples:
#
# # All tool calls from last hour
# read_filtered("session.jsonl",
#               event_type="TOOL_CALL",
#               since=datetime.now() - timedelta(hours=1))
#
# # All errors from orchestrator agents
# read_filtered("session.jsonl",
#               agent_pattern="Claude-Orch-*",
#               severity="ERROR")
#
# # Custom filter: traces with duration > 5000ms
# read_filtered("session.jsonl",
#               predicate=lambda t: t.get("duration_ms", 0) > 5000)
```

### Streaming Read

Leitura linha por linha para arquivos grandes:

```python
from typing import Generator, Optional

def stream_session(
    session_file: str,
    chunk_size: int = 1000
) -> Generator[dict, None, None]:
    """
    Stream traces from a session file line by line.
    Memory-efficient for large files.

    Args:
        session_file: Path to JSONL session file
        chunk_size: Hint for file buffering

    Yields:
        dict: Each trace as it's read
    """
    with open(session_file, "r", encoding="utf-8", buffering=chunk_size) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue

            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue  # Skip invalid lines


def stream_with_progress(
    session_file: str,
    progress_callback: Optional[Callable[[int, int], None]] = None
) -> Generator[dict, None, None]:
    """
    Stream traces with progress reporting.

    Args:
        session_file: Path to JSONL session file
        progress_callback: Function called with (current, total) bytes

    Yields:
        dict: Each trace as it's read
    """
    import os

    total_size = os.path.getsize(session_file)
    bytes_read = 0

    with open(session_file, "r", encoding="utf-8") as f:
        for line in f:
            bytes_read += len(line.encode("utf-8"))

            if progress_callback:
                progress_callback(bytes_read, total_size)

            line = line.strip()
            if not line:
                continue

            try:
                yield json.loads(line)
            except json.JSONDecodeError:
                continue


# Usage:
# for trace in stream_session("large_session.jsonl"):
#     process_trace(trace)
```

---

## Index Management

### session_index.json Structure

O índice de sessões permite lookup rápido sem precisar escanear todos os arquivos JSONL.

```json
{
  "version": "1.0.0",
  "schema": "sentinel/session_index/v1",
  "last_updated": "2026-01-06T21:30:00-03:00",
  "sessions": [
    {
      "session_id": "Claude-Orch-Prime-20260106-c614",
      "file": "session_20260106_c614.jsonl",
      "started_at": "2026-01-06T19:00:00-03:00",
      "ended_at": "2026-01-06T21:30:00-03:00",
      "ended_reason": "NORMAL",
      "trace_count": 145,
      "event_counts": {
        "START": 1,
        "END": 1,
        "TOOL_CALL": 89,
        "BRANCH": 12,
        "DELEGATE": 5,
        "RETURN": 5,
        "ERROR": 2,
        "CHECKPOINT": 30
      },
      "anomaly_count": 2,
      "anomalies": [
        {
          "type": "TOOL_STORM",
          "detected_at": "2026-01-06T20:15:00-03:00",
          "details": "15 tool calls in 60 seconds"
        }
      ],
      "health_score": 85,
      "metrics": {
        "duration_seconds": 9000,
        "avg_tool_duration_ms": 245,
        "max_tool_duration_ms": 12500,
        "error_rate_percent": 1.4
      }
    },
    {
      "session_id": "Claude-Sub-Analysis-20260106-a1b2",
      "file": "session_20260106_a1b2.jsonl",
      "started_at": "2026-01-06T19:05:00-03:00",
      "ended_at": "2026-01-06T19:45:00-03:00",
      "ended_reason": "NORMAL",
      "trace_count": 45,
      "event_counts": {
        "START": 1,
        "END": 1,
        "TOOL_CALL": 40,
        "CHECKPOINT": 3
      },
      "anomaly_count": 0,
      "anomalies": [],
      "health_score": 100,
      "metrics": {
        "duration_seconds": 2400,
        "avg_tool_duration_ms": 180,
        "max_tool_duration_ms": 850,
        "error_rate_percent": 0.0
      }
    }
  ],
  "summary": {
    "total_sessions": 2,
    "total_traces": 190,
    "date_range": {
      "first": "2026-01-06",
      "last": "2026-01-06"
    },
    "health_score_avg": 92.5
  }
}
```

### Index Update Pattern

O índice deve ser atualizado em momentos específicos para manter consistência:

```python
import json
from pathlib import Path
from datetime import datetime
from typing import Optional
from dataclasses import dataclass, asdict
from collections import Counter

@dataclass
class SessionSummary:
    """Summary data for a single session."""
    session_id: str
    file: str
    started_at: str
    ended_at: Optional[str] = None
    ended_reason: Optional[str] = None
    trace_count: int = 0
    event_counts: dict = None
    anomaly_count: int = 0
    anomalies: list = None
    health_score: int = 100
    metrics: dict = None

    def __post_init__(self):
        self.event_counts = self.event_counts or {}
        self.anomalies = self.anomalies or []
        self.metrics = self.metrics or {}


class SessionIndexManager:
    """
    Manages the session_index.json file.
    """

    def __init__(self, audit_dir: str = ".claude/audit"):
        self.audit_dir = Path(audit_dir)
        self.index_file = self.audit_dir / "session_index.json"
        self._index = None

    def load(self) -> dict:
        """Load index from disk or create new."""
        if self.index_file.exists():
            with open(self.index_file, "r") as f:
                self._index = json.load(f)
        else:
            self._index = {
                "version": "1.0.0",
                "schema": "sentinel/session_index/v1",
                "last_updated": datetime.now().isoformat(),
                "sessions": [],
                "summary": {
                    "total_sessions": 0,
                    "total_traces": 0,
                    "date_range": {"first": None, "last": None},
                    "health_score_avg": 100
                }
            }
        return self._index

    def save(self):
        """Persist index to disk atomically."""
        self._index["last_updated"] = datetime.now().isoformat()
        self._update_summary()

        # Atomic write via temp file
        import tempfile
        tmp = tempfile.NamedTemporaryFile(
            mode="w",
            dir=self.audit_dir,
            delete=False,
            suffix=".tmp"
        )
        try:
            json.dump(self._index, tmp, indent=2, ensure_ascii=False)
            tmp.close()
            Path(tmp.name).rename(self.index_file)
        except:
            Path(tmp.name).unlink(missing_ok=True)
            raise

    def register_session(self, session_id: str, session_file: str):
        """Register a new session when it starts."""
        if self._index is None:
            self.load()

        summary = SessionSummary(
            session_id=session_id,
            file=Path(session_file).name,
            started_at=datetime.now().isoformat()
        )

        self._index["sessions"].append(asdict(summary))
        self.save()

    def update_session(
        self,
        session_id: str,
        trace_count: int = None,
        event_counts: dict = None,
        anomalies: list = None,
        health_score: int = None,
        metrics: dict = None
    ):
        """Update session statistics during operation."""
        if self._index is None:
            self.load()

        for session in self._index["sessions"]:
            if session["session_id"] == session_id:
                if trace_count is not None:
                    session["trace_count"] = trace_count
                if event_counts is not None:
                    session["event_counts"] = event_counts
                if anomalies is not None:
                    session["anomalies"] = anomalies
                    session["anomaly_count"] = len(anomalies)
                if health_score is not None:
                    session["health_score"] = health_score
                if metrics is not None:
                    session["metrics"] = metrics
                break

        self.save()

    def close_session(self, session_id: str, reason: str = "NORMAL"):
        """Mark session as ended."""
        if self._index is None:
            self.load()

        for session in self._index["sessions"]:
            if session["session_id"] == session_id:
                session["ended_at"] = datetime.now().isoformat()
                session["ended_reason"] = reason
                break

        self.save()

    def rebuild_from_files(self):
        """
        Rebuild index by scanning all JSONL files.
        Use when index is corrupted or missing.
        """
        self._index = {
            "version": "1.0.0",
            "schema": "sentinel/session_index/v1",
            "last_updated": datetime.now().isoformat(),
            "sessions": [],
            "summary": {}
        }

        for jsonl_file in self.audit_dir.glob("session_*.jsonl"):
            summary = self._analyze_session_file(jsonl_file)
            if summary:
                self._index["sessions"].append(asdict(summary))

        self.save()

    def _analyze_session_file(self, filepath: Path) -> Optional[SessionSummary]:
        """Analyze a JSONL file to extract session summary."""
        traces = []

        with open(filepath, "r") as f:
            for line in f:
                try:
                    traces.append(json.loads(line))
                except:
                    continue

        if not traces:
            return None

        # Extract session ID from first START event or filename
        session_id = None
        for t in traces:
            if t.get("event") == "START":
                session_id = t.get("agent_id")
                break

        if not session_id:
            # Extract from filename: session_20260106_c614.jsonl
            parts = filepath.stem.split("_")
            if len(parts) >= 3:
                session_id = f"Unknown-{parts[1]}-{parts[2]}"

        # Count events
        event_counts = Counter(t.get("event", "UNKNOWN") for t in traces)

        # Find time range
        timestamps = []
        for t in traces:
            ts = t.get("timestamp")
            if ts:
                timestamps.append(ts)

        started_at = min(timestamps) if timestamps else None
        ended_at = max(timestamps) if timestamps else None

        # Check for END event
        ended_reason = None
        for t in traces:
            if t.get("event") == "END":
                ended_reason = t.get("reason", "NORMAL")

        return SessionSummary(
            session_id=session_id,
            file=filepath.name,
            started_at=started_at,
            ended_at=ended_at,
            ended_reason=ended_reason,
            trace_count=len(traces),
            event_counts=dict(event_counts)
        )

    def _update_summary(self):
        """Update aggregate summary statistics."""
        sessions = self._index.get("sessions", [])

        if not sessions:
            self._index["summary"] = {
                "total_sessions": 0,
                "total_traces": 0,
                "date_range": {"first": None, "last": None},
                "health_score_avg": 100
            }
            return

        total_traces = sum(s.get("trace_count", 0) for s in sessions)
        health_scores = [s.get("health_score", 100) for s in sessions]

        dates = []
        for s in sessions:
            if s.get("started_at"):
                dates.append(s["started_at"][:10])

        self._index["summary"] = {
            "total_sessions": len(sessions),
            "total_traces": total_traces,
            "date_range": {
                "first": min(dates) if dates else None,
                "last": max(dates) if dates else None
            },
            "health_score_avg": sum(health_scores) / len(health_scores) if health_scores else 100
        }
```

#### When to Update Index

```
┌─────────────────────────────────────────────────────────────────────┐
│                    INDEX UPDATE TRIGGERS                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  EVENT                │  ACTION                                     │
│  ────────────────────┼──────────────────────────────────────────   │
│  Session starts       │  register_session()                        │
│                      │  Create entry with started_at                │
│                      │                                             │
│  Every N traces      │  update_session()                           │
│  (N=50 recommended)  │  Update trace_count, event_counts           │
│                      │                                             │
│  Anomaly detected    │  update_session()                           │
│                      │  Append to anomalies list                   │
│                      │                                             │
│  Session ends        │  close_session()                            │
│                      │  Set ended_at, final counts                 │
│                      │                                             │
│  /audit command      │  Trigger rebuild_from_files() if stale      │
│                      │                                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Rotation Policy

### Active vs Archive

Política de rotação para gerenciar espaço em disco e performance de leitura:

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FILE LIFECYCLE                                   │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  .claude/audit/                                                     │
│  ├── session_index.json          ← Always in root                  │
│  ├── session_20260106_c614.jsonl ← Active (today)                  │
│  ├── session_20260105_a1b2.jsonl ← Active (yesterday)              │
│  ├── session_20260104_d3e4.jsonl ← Active (2 days ago)             │
│  └── archive/                                                       │
│      ├── session_20251230_e5f6.jsonl ← Archived (7+ days)          │
│      └── session_20251229_g7h8.jsonl ← Archived (8+ days)          │
│                                                                     │
│  TIMELINE:                                                          │
│  ──────────────────────────────────────────────────────────────    │
│  Day 0-7    │  Active    │  .claude/audit/                         │
│  Day 7-30   │  Archive   │  .claude/audit/archive/                 │
│  Day 30+    │  Delete    │  Automatic cleanup                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Rotation Implementation

```python
from pathlib import Path
from datetime import datetime, timedelta
import shutil

class TraceRotator:
    """
    Handles rotation and cleanup of session files.
    """

    ACTIVE_DAYS = 7      # Files stay active for 7 days
    ARCHIVE_DAYS = 30    # Files archived for 30 days total, then deleted

    def __init__(self, audit_dir: str = ".claude/audit"):
        self.audit_dir = Path(audit_dir)
        self.archive_dir = self.audit_dir / "archive"

    def rotate(self):
        """
        Perform rotation: move old files to archive, delete expired files.
        """
        now = datetime.now()
        active_cutoff = now - timedelta(days=self.ACTIVE_DAYS)
        delete_cutoff = now - timedelta(days=self.ARCHIVE_DAYS)

        self.archive_dir.mkdir(parents=True, exist_ok=True)

        # Process active files
        for f in self.audit_dir.glob("session_*.jsonl"):
            file_date = self._extract_date(f)
            if file_date is None:
                continue

            if file_date < delete_cutoff:
                # Too old even for archive - delete
                f.unlink()
                print(f"[INFO] Deleted expired: {f.name}")

            elif file_date < active_cutoff:
                # Move to archive
                dest = self.archive_dir / f.name
                shutil.move(str(f), str(dest))
                print(f"[INFO] Archived: {f.name}")

        # Process archive files for deletion
        for f in self.archive_dir.glob("session_*.jsonl"):
            file_date = self._extract_date(f)
            if file_date is None:
                continue

            if file_date < delete_cutoff:
                f.unlink()
                print(f"[INFO] Deleted from archive: {f.name}")

    def _extract_date(self, filepath: Path) -> Optional[datetime]:
        """
        Extract date from session filename.
        Format: session_YYYYMMDD_xxxx.jsonl
        """
        import re

        match = re.search(r'session_(\d{8})_', filepath.name)
        if match:
            try:
                return datetime.strptime(match.group(1), "%Y%m%d")
            except ValueError:
                pass
        return None

    def get_stats(self) -> dict:
        """Get rotation statistics."""
        active_count = len(list(self.audit_dir.glob("session_*.jsonl")))
        archive_count = len(list(self.archive_dir.glob("session_*.jsonl"))) if self.archive_dir.exists() else 0

        active_size = sum(f.stat().st_size for f in self.audit_dir.glob("session_*.jsonl"))
        archive_size = sum(f.stat().st_size for f in self.archive_dir.glob("session_*.jsonl")) if self.archive_dir.exists() else 0

        return {
            "active_files": active_count,
            "active_size_mb": active_size / (1024 * 1024),
            "archive_files": archive_count,
            "archive_size_mb": archive_size / (1024 * 1024),
            "total_files": active_count + archive_count,
            "total_size_mb": (active_size + archive_size) / (1024 * 1024)
        }
```

### Retention Configuration

```python
# retention_config.py

RETENTION_CONFIG = {
    # How long files stay in active directory
    "active_retention_days": 7,

    # How long files stay in archive before deletion
    "archive_retention_days": 30,

    # Maximum total size for active directory (MB)
    "active_max_size_mb": 100,

    # Maximum total size for archive directory (MB)
    "archive_max_size_mb": 500,

    # Whether to compress archived files
    "compress_archive": True,

    # Rotation schedule (cron-like)
    "rotation_schedule": "daily",  # or "weekly", "on_startup"
}
```

---

## Integration

### With Detection Engine

O Trace Writer integra com o Detection Engine para análise em tempo real:

```python
from typing import Protocol, Callable, List
from dataclasses import dataclass

class DetectionEngineProtocol(Protocol):
    """Protocol for detection engine integration."""

    def analyze(self, trace: dict) -> List[dict]:
        """Analyze a trace and return any detected anomalies."""
        ...


@dataclass
class IntegratedTraceWriter:
    """
    Trace writer with real-time detection integration.
    """
    session_file: str
    detection_engine: DetectionEngineProtocol = None
    on_anomaly: Callable[[dict], None] = None

    def write(self, trace: dict) -> bool:
        """
        Write trace and run detection analysis.

        Flow:
        1. Persist trace to JSONL
        2. Pass trace to detection engine
        3. If anomalies found, trigger callback
        """
        # 1. Persist first (even if detection fails)
        success = self._persist(trace)

        if not success:
            return False

        # 2. Run detection (if configured)
        if self.detection_engine:
            anomalies = self.detection_engine.analyze(trace)

            # 3. Handle anomalies
            for anomaly in anomalies:
                # Persist anomaly as separate trace
                anomaly_trace = {
                    "event": "ANOMALY_DETECTED",
                    "timestamp": trace.get("timestamp"),
                    "original_event": trace.get("event"),
                    "anomaly": anomaly
                }
                self._persist(anomaly_trace)

                # Trigger callback
                if self.on_anomaly:
                    self.on_anomaly(anomaly)

        return True

    def _persist(self, trace: dict) -> bool:
        """Internal persistence implementation."""
        try:
            import json
            import os

            line = json.dumps(trace, ensure_ascii=False) + "\n"
            with open(self.session_file, "a") as f:
                f.write(line)
                f.flush()
                os.fsync(f.fileno())
            return True
        except Exception:
            return False


# Usage with detection engine:
#
# from detection_engine import AnomalyDetector
#
# detector = AnomalyDetector()
# writer = IntegratedTraceWriter(
#     session_file="session.jsonl",
#     detection_engine=detector,
#     on_anomaly=lambda a: print(f"ALERT: {a}")
# )
#
# writer.write({"event": "TOOL_CALL", "tool": "bash", ...})
```

```
┌─────────────────────────────────────────────────────────────────────┐
│              TRACE WRITER ↔ DETECTION ENGINE FLOW                  │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│   Trace Event ──► Trace Writer ──► JSONL File                      │
│                        │                                            │
│                        ▼                                            │
│                   Detection Engine                                  │
│                        │                                            │
│               ┌────────┴────────┐                                   │
│               ▼                 ▼                                   │
│         [No Anomaly]      [Anomaly Found]                          │
│               │                 │                                   │
│               ▼                 ▼                                   │
│           Continue         Write ANOMALY_DETECTED trace            │
│                                 │                                   │
│                                 ▼                                   │
│                         Trigger Callback                           │
│                                 │                                   │
│                                 ▼                                   │
│                     Alert User / Update Index                      │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### With /audit Skill

A skill `/audit` lê traces para exibir ao usuário:

```python
# Exemplo de como /audit skill usa o trace_writer

from trace_writer import (
    read_session,
    read_filtered,
    stream_session,
    SessionIndexManager
)
from datetime import datetime, timedelta

def audit_skill_handler(args: dict) -> str:
    """
    Handler for /audit skill.

    Commands:
      /audit                   - Summary of current session
      /audit --last 1h         - Traces from last hour
      /audit --errors          - Only error traces
      /audit --session <id>    - Specific session
      /audit --anomalies       - Only anomalies
    """
    audit_dir = ".claude/audit"
    index_mgr = SessionIndexManager(audit_dir)
    index = index_mgr.load()

    # Parse arguments
    if args.get("summary") or not args:
        return _generate_summary(index)

    if args.get("last"):
        duration = _parse_duration(args["last"])
        since = datetime.now() - duration
        return _generate_recent_report(audit_dir, since)

    if args.get("errors"):
        return _generate_error_report(audit_dir)

    if args.get("anomalies"):
        return _generate_anomaly_report(index)

    if args.get("session"):
        session_id = args["session"]
        return _generate_session_report(audit_dir, index, session_id)

    return "Unknown audit command. Use /audit --help for options."


def _generate_summary(index: dict) -> str:
    """Generate summary view."""
    summary = index.get("summary", {})
    sessions = index.get("sessions", [])

    # Get current/recent session
    active = [s for s in sessions if not s.get("ended_at")]
    recent = sorted(sessions, key=lambda s: s.get("started_at", ""), reverse=True)[:5]

    output = []
    output.append("## Audit Summary\n")
    output.append(f"Total Sessions: {summary.get('total_sessions', 0)}")
    output.append(f"Total Traces: {summary.get('total_traces', 0)}")
    output.append(f"Health Score (avg): {summary.get('health_score_avg', 100):.1f}%\n")

    if active:
        output.append("### Active Sessions")
        for s in active:
            output.append(f"- {s['session_id']}: {s.get('trace_count', 0)} traces")

    output.append("\n### Recent Sessions")
    for s in recent:
        status = "ACTIVE" if not s.get("ended_at") else s.get("ended_reason", "ENDED")
        output.append(f"- [{status}] {s['session_id']}: {s.get('trace_count', 0)} traces, health={s.get('health_score', 100)}%")

    return "\n".join(output)


def _generate_recent_report(audit_dir: str, since: datetime) -> str:
    """Generate report of recent traces."""
    from pathlib import Path

    output = []
    output.append(f"## Traces since {since.isoformat()}\n")

    for f in Path(audit_dir).glob("session_*.jsonl"):
        traces = read_filtered(str(f), since=since)
        if traces:
            output.append(f"### {f.name}")
            for t in traces[-10:]:  # Last 10 from each file
                output.append(f"  [{t.get('timestamp', '?')}] {t.get('event', '?')}: {t.get('description', '')[:50]}")

    return "\n".join(output) if len(output) > 1 else "No traces found in the specified period."


def _parse_duration(duration_str: str) -> timedelta:
    """Parse duration string like '1h', '30m', '2d'."""
    import re

    match = re.match(r'^(\d+)([hmsd])$', duration_str.lower())
    if not match:
        return timedelta(hours=1)  # Default

    value = int(match.group(1))
    unit = match.group(2)

    if unit == 'h':
        return timedelta(hours=value)
    elif unit == 'm':
        return timedelta(minutes=value)
    elif unit == 'd':
        return timedelta(days=value)
    elif unit == 's':
        return timedelta(seconds=value)

    return timedelta(hours=1)
```

---

## Appendix: Quick Reference

### File Locations

```
.claude/audit/
├── session_index.json           # Session lookup index
├── session_YYYYMMDD_xxxx.jsonl  # Active session files (0-7 days)
└── archive/
    └── session_YYYYMMDD_xxxx.jsonl  # Archived files (7-30 days)
```

### JSONL Line Format

```json
{"event":"TOOL_CALL","timestamp":"2026-01-06T19:00:00-03:00","agent_id":"Claude-X","tool":"bash","args":{"command":"ls"},"duration_ms":150}
```

### Key Functions

| Function | Purpose |
|----------|---------|
| `append_trace(file, trace)` | Write single trace atomically |
| `read_session(file)` | Read all traces from file |
| `read_filtered(file, **criteria)` | Read matching traces |
| `stream_session(file)` | Memory-efficient streaming read |
| `SessionIndexManager.register_session()` | Register new session |
| `SessionIndexManager.close_session()` | Mark session as ended |
| `TraceRotator.rotate()` | Archive/delete old files |

### Common Patterns

```python
# Write a trace
append_trace("session.jsonl", {
    "event": "TOOL_CALL",
    "timestamp": datetime.now().isoformat(),
    "tool": "bash",
    "args": {"command": "ls -la"}
})

# Read all errors
errors = read_filtered("session.jsonl", severity="ERROR")

# Stream large file
for trace in stream_session("large_session.jsonl"):
    process(trace)

# Rotate old files
TraceRotator().rotate()
```

---

*Sentinel Protocol v1.0 - Trace Writer Library*
*Last updated: 2026-01-06*
