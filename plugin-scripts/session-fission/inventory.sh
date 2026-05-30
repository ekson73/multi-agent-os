#!/usr/bin/env bash
# /**
#  * session-fission · inventory.sh
#  * @context MAOS plugin script — READ-ONLY transcript analysis for the session-fission skill.
#  * @reason Parse a Claude Code session transcript (.jsonl) into a proposed N-Tree of atomic
#  *         contexts (keyed by project/branch/cwd + time-gap) so a tangled session can be split.
#  * @impact Emits JSON only. Never writes to, mutates, or deletes the source transcript.
#  * @version 0.1.0
#  */

set -euo pipefail

# JSON-escape a string for safe interpolation into the bash-emitted error envelopes.
# (The python3 analysis block below emits JSON via json.dumps, which is already safe;
# this helper only guards the pre-python3 error paths where a path is interpolated.)
json_escape() {
  local s="$1"
  s=${s//\\/\\\\}; s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}; s=${s//$'\r'/\\r}; s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

# =============================================================================
# RESOLVE TRANSCRIPT (read-only)
# =============================================================================
CONFIG_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
TRANSCRIPT="${1:-}"
TARGET_CWD="${SF_CWD:-$PWD}"
GAP_SECONDS="${SF_GAP_SECONDS:-1800}"   # time-gap (s) that suggests a topic boundary within a branch
# Validate before it reaches the embedded python int() — a bad SF_GAP_SECONDS would
# otherwise crash with a non-JSON ValueError traceback, breaking the JSON contract.
if ! printf '%s' "$GAP_SECONDS" | grep -qE '^[0-9]+$'; then
  printf '{"status":"error","error":"SF_GAP_SECONDS must be a non-negative integer (got: %s)"}\n' "$(json_escape "$GAP_SECONDS")"
  exit 1
fi

if [ -z "$TRANSCRIPT" ]; then
  # Claude Code encodes the cwd into the project dir name by replacing '/' and '.' with '-'.
  enc="$(printf '%s' "$TARGET_CWD" | tr '/.' '--')"
  proj="$CONFIG_DIR/projects/$enc"
  if [ -d "$proj" ]; then
    TRANSCRIPT="$(ls -t "$proj"/*.jsonl 2>/dev/null | head -1 || true)"
  fi
fi

if [ -z "$TRANSCRIPT" ] || [ ! -f "$TRANSCRIPT" ]; then
  printf '{"status":"error","error":"transcript not found","hint":"pass a path arg, or run inside a project dir that has sessions under %s/projects/<encoded-cwd>/"}\n' "$(json_escape "$CONFIG_DIR")"
  exit 1
fi

# =============================================================================
# ANALYZE (python3 — robust JSONL parse; emits JSON; no message bodies, labels only)
# =============================================================================
if ! command -v python3 >/dev/null 2>&1; then
  printf '{"status":"error","error":"python3 not found","hint":"inventory.sh requires python3 for robust JSONL parsing; install python3 and retry"}\n'
  exit 1
fi
python3 - "$TRANSCRIPT" "$GAP_SECONDS" <<'PY'
import sys, json, datetime

path, gap = sys.argv[1], int(sys.argv[2])

def parse_ts(s):
    if not s:
        return None
    try:
        return datetime.datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp()
    except Exception:
        return None

events = []
total = 0
with open(path, "r", encoding="utf-8", errors="replace") as fh:
    for line in fh:
        line = line.strip()
        if not line:
            continue
        total += 1
        try:
            d = json.loads(line)
        except Exception:
            continue
        if d.get("type") not in ("user", "assistant"):
            continue
        events.append({
            "ts": parse_ts(d.get("timestamp")),
            "branch": d.get("gitBranch") or "no-branch",
            "cwd": d.get("cwd") or "",
            "slug": d.get("slug") or "",
            "sidechain": bool(d.get("isSidechain")),
            "role": d.get("type"),
        })

# order by timestamp when available (stable otherwise)
events.sort(key=lambda e: (e["ts"] is None, e["ts"] or 0))

clusters = []
def label_from(seg, branch, idx):
    # SAFETY CONTRACT: labels must NOT embed raw message text — that would leak
    # transcript content (potentially secrets) into stdout/logs, contradicting the
    # "no message bodies, labels only" guarantee. Use the explicit `slug` (operator-set,
    # already safe) when present; otherwise a content-free branch+segment label.
    for e in seg:
        if e["slug"]:
            return e["slug"][:80]
    return f"{branch} · segment {idx}"

# Cluster by branch, then split on time-gaps inside the same branch.
by_branch = {}
for e in events:
    by_branch.setdefault(e["branch"], []).append(e)

cid = 0
for branch, seg in by_branch.items():
    seg.sort(key=lambda e: (e["ts"] is None, e["ts"] or 0))
    cur = []
    prev = None
    sub = []
    for e in seg:
        if prev is not None and e["ts"] is not None and (e["ts"] - prev) > gap:
            sub.append(cur); cur = []
        cur.append(e); prev = e["ts"] if e["ts"] is not None else prev
    if cur:
        sub.append(cur)
    seg_idx = 0
    for s in sub:
        cid += 1
        seg_idx += 1
        ts_vals = [e["ts"] for e in s if e["ts"]]
        clusters.append({
            "id": f"c{cid:02d}",
            "label": label_from(s, branch, seg_idx),
            "branch": branch,
            "cwd": (s[0]["cwd"] if s else ""),
            "msg_count": len(s),
            "has_sidechain": any(e["sidechain"] for e in s),
            "first_ts": (datetime.datetime.fromtimestamp(min(ts_vals), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")) if ts_vals else None,
            "last_ts": (datetime.datetime.fromtimestamp(max(ts_vals), datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")) if ts_vals else None,
        })

# Relation hints are time-ordered, NOT branch-grouped order: clusters were appended
# grouped by branch, so we must re-sort by first_ts before deriving sequential/independent
# hints — otherwise interleaved-branch work yields misleading relations.
def _cluster_start(c):
    return c["first_ts"] or "9999"  # ISO strings sort lexicographically; None last
ordered = sorted(clusters, key=_cluster_start)
relations = []
for i in range(1, len(ordered)):
    a, b = ordered[i-1], ordered[i]
    rel = "sequential" if a["branch"] == b["branch"] else "independent"
    relations.append({"from": a["id"], "to": b["id"], "rel": rel})

out = {
    "status": "ok",
    "schema": "session-fission/inventory/0.1.0",
    "source": path,
    "read_only": True,
    "total_lines": total,
    "cluster_count": len(clusters),
    "gap_seconds": gap,
    "clusters": clusters,
    "relations": relations,
    "note": "Heuristic proposal — confirm/adjust with the operator before snapshot/reseed. Auto-detected transcript = most-recent (no CLAUDE_SESSION_ID env var exists).",
}
print(json.dumps(out, indent=2))
PY
