#!/usr/bin/env python3
"""synopsis-panel — fuse the work-compass pendencies N-Tree + the HITL punch-list
into ONE view, and render it for a human (markdown-tree · mermaid-mindmap · HTML)
AND for an agent (ONE unified JSON envelope).

> Greek sún ("together") + ópsis ("a seeing") = a seeing-of-the-whole-together.

ANTI-OVER-ENG CONTRACT (the whole point of this artifact):
  This script REIMPLEMENTS NOTHING. It CALLS the two SSOT engines and fuses +
  renders their output. The engines stay the single source of truth:
    - pendencies N-Tree  <- work-compass-aggregate.py --json   (SSOT: aggregation + 7 CPT domains + 10 heuristics)
    - priority (Q1..Q4)  <- work-compass   --sort eisenhower   (SSOT: Eisenhower classification)
    - HITL ledger        <- hitl-punch-list.py (reads punch-list.md, the SSOT, 5 types)
  The ONLY net-new logic here is: (a) the fusion model that joins a pendency item
  to its HITL flag, and (b) three renderers + one JSON envelope over that model.

Usage
  synopsis-fuse.py [--compass-json F|-] [--hitl-md F] [--hitl-json F|-]
                   [--format tree|mermaid|html|json]
                   [--scope current|session|repo|vault|all]
                   [--session-id ID[,ID]]
                   [--include pending|all] [--hitl-only] [--pending-only]
                   [--title TEXT] [--self-heal]

  --compass-json  path to a pre-captured `work-compass-aggregate.py --json` payload,
                  or '-' for stdin. If omitted, the script CALLS the engine itself
                  (slower: it runs the live collectors).
  --hitl-md       path to the HITL SSOT markdown (default: discover the punch-list.md).
                  Discovery resolves the WORKING-TREE copy, which is correct for a human
                  editing the ledger on purpose. Every render therefore NAMES the file it
                  read, and WARNS when that file is modified relative to HEAD or its repo
                  is behind its upstream — an item count can match while the items differ.
  --hitl-json     path to a pre-parsed HITL JSON array, or '-' for stdin (skips the md parse).
  --format        which render to emit (default tree).
  --scope         two jobs, deliberately kept apart:
                    · pendency scope (current|session|repo|vault|all), forwarded to
                      work-compass. UNCHANGED — it means "where the pendency lives",
                      not "this conversation".
                    · in --hitl-only mode it ALSO selects the HITL ledger scope: the
                      default is SESSION (only the items whose ledger provenance names
                      this conversation) and an explicit `--scope all` widens it to the
                      whole ledger, legacy items included. Any other value narrows to
                      session, because only `all` may widen.
  --session-id    identity of the INVOKING conversation, comma-separated for a set.
                  Default: MAOS_SELF_SESSION_ID, then CLAUDE_CODE_SESSION_ID, then
                  CLAUDE_SESSION_ID, then native PI_SESSION_FILE headers. A worker
                  uses the adjacent root file; recovered roots include only ancestors
                  explicitly named by parentSession. Overrides stay exact. Cyclic or
                  conflicting native headers leave the session scope unresolved.
  --self-heal     on a renderer/parse error, print a structured repair-request
                  envelope to stderr instead of a bare traceback (hybrid self-heal M.O.).

Exit codes: 0 ok · 1 error (engine/parse) · 2 usage.
"""
from __future__ import annotations

import argparse
import datetime as dt
import html as _html
import json
import os
import re
import shutil
import subprocess
import sys
import unicodedata
from pathlib import Path

# ── engine discovery (SSOT paths; glob + fallback, self-locating) ──────────────────
HERE = Path(__file__).resolve()
# skills/synopsis-panel/bin/synopsis-fuse.py -> repo root is 3 parents up from bin/
REPO_ROOT = HERE.parents[3] if len(HERE.parents) >= 4 else HERE.parents[-1]


def _first_existing(paths: list[Path]) -> Path | None:
    for p in paths:
        if p and p.is_file():
            return p
    return None


def find_work_compass() -> Path | None:
    cands = [
        REPO_ROOT / "bin" / "work-compass-aggregate.py",
        Path.home() / "Projects" / "multi-agent-os" / "bin" / "work-compass-aggregate.py",
    ]
    hit = _first_existing(cands)
    if hit:
        return hit
    # last resort: glob under the repo root
    for g in REPO_ROOT.glob("**/work-compass-aggregate.py"):
        return g
    return None


def find_hitl_script() -> Path | None:
    cands = [
        Path.home() / "Projects" / "eko-engram" / "scripts" / "hitl-punch-list.py",
    ]
    hit = _first_existing(cands)
    if hit:
        return hit
    for base in (Path.home() / "Projects",):
        for g in base.glob("**/hitl-punch-list.py"):
            return g
    return None


def find_hitl_md() -> Path | None:
    cands = [
        Path.home() / "Projects" / "eko-engram" / "hitl" / "punch-list.md",
    ]
    hit = _first_existing(cands)
    if hit:
        return hit
    for base in (Path.home() / "Projects",):
        for g in base.glob("**/hitl/punch-list.md"):
            return g
    return None


# ── ledger PROVENANCE (say which file was read; warn when it is not the tracked one) ─
# WHY: find_hitl_md() resolves the WORKING-TREE copy of the ledger. That is the right
# default — a human editing the ledger on purpose must see their own edits, and this
# engine is read-only, so it must never substitute a different file behind their back.
# But a working-tree copy can be dirty or the repo behind its upstream, and then an
# AGENT measures a stale queue and does not know it. Measured 2026-10-26: a vault 21
# commits behind, with a dirty ledger, rendered 16 open items — the same count as the
# tracked one, with three closed items shown and three real ones hidden. The count
# matching is what hid the error. So: never swap the file, always NAME it, and WARN
# when it diverges from the tracked version.
def _git(cwd: Path, *args: str) -> str | None:
    """Run a read-only git command. Returns stripped stdout, or None if unavailable."""
    if not shutil.which("git"):
        return None
    try:
        p = subprocess.run(["git", "-C", str(cwd), *args],
                           capture_output=True, text=True, timeout=15)
    except (OSError, subprocess.SubprocessError):
        return None
    if p.returncode != 0:
        return None
    return p.stdout.strip()


def ledger_provenance(path: Path | None, kind: str = "md") -> dict:
    """Describe WHERE the HITL ledger was read from and whether it is the tracked copy.

    Pure observation: runs only read-only git queries and never rewrites, stages or
    substitutes anything. Degrades to a bare path when git, the repo or the upstream
    is unavailable — an absent signal is reported as unknown, never as "clean".
    """
    prov: dict = {"kind": kind, "path": str(path) if path else None,
                  "in_git": False, "dirty": None, "behind": None, "warning": None}
    if not path:
        prov["warning"] = "HITL ledger not found (rendering a tree with zero HITL items)"
        return prov
    d = path.parent
    top = _git(d, "rev-parse", "--show-toplevel")
    if not top:
        return prov  # not in a git repo (or no git): the absolute path is all we can say
    prov["in_git"] = True
    prov["repo"] = top
    rel = _git(d, "ls-files", "--full-name", "--error-unmatch", str(path))
    if rel is None:
        prov["dirty"] = None
        prov["warning"] = (f"ledger read from {path} is NOT TRACKED by the repo at {top} "
                           f"— nothing to compare it against")
        return prov
    prov["tracked_as"] = rel
    # dirty = the working-tree copy differs from HEAD for this path
    porcelain = _git(d, "status", "--porcelain", "--", str(path))
    prov["dirty"] = bool(porcelain)
    # behind = commits the current branch is missing from its upstream
    counts = _git(d, "rev-list", "--left-right", "--count", "@{upstream}...HEAD")
    if counts:
        parts = counts.split()
        if len(parts) == 2 and parts[0].isdigit():
            prov["behind"] = int(parts[0])
    bits = []
    if prov["dirty"]:
        bits.append("MODIFIED relative to HEAD")
    if prov["behind"]:
        bits.append(f"the repo is {prov['behind']} commit(s) BEHIND its upstream")
    if bits:
        prov["warning"] = (
            f"ledger read from the WORKING TREE and it diverges from the tracked version: "
            f"{'; '.join(bits)}. The item count can match while the items differ. "
            f"To measure the tracked version: "
            f"git -C {top} show @{{upstream}}:{rel} > /tmp/ledger.md "
            f"&& --hitl-md /tmp/ledger.md"
        )
    return prov


# ── HITL ledger parse (reuses the SSOT column contract from hitl-punch-list.py) ────
# OPEN_COLS and the markers are the hitl-punch-list.py contract (kept in sync; we READ,
# never recompute severity — that is the engine's job).
HITL_OPEN_COLS = ["ID", "Sev", "Tipo", "R", "Decidir", "Pediu", "Aberto",
                  "Idade", "Prazo", "Status", "Link"]
HITL_OPEN_MARK = ("<!-- hitl:open:start -->", "<!-- hitl:open:end -->")
HITL_TYPES = {"credencial", "gasto", "irreversivel", "envio", "negocio"}

# ── session provenance (WHICH conversation owns a ledger item) ─────────────────────
# WHY: the ledger is a single global queue — one file, every conversation's gates.
# Rendering all of it as "what needs me now" is wrong: most items belong to other
# conversations. The ledger records the owner in its own "Sessão" column (the
# writer's contract, kept in sync with hitl-punch-list.py): the id of the
# conversation that opened the item, or "-" when there is none. An item with no
# provenance is LEGACY (owner unknown) — it is never silently attributed to the
# caller; it shows only in the explicit global scope.
SESSION_ID_RE = re.compile(
    r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}")
OMP_SESSION_NAME_RE = re.compile(
    r"\d{4}-\d{2}-\d{2}T\d{2}-\d{2}-\d{2}-\d{3}Z_("
    + SESSION_ID_RE.pattern + r")")
# The header spelling is normalized (case and accent) so a ledger written as
# "Sessão" and one written as "Sessao" read the same. This is a fixed, known
# set of names — NOT a casefold applied to the opaque ids themselves.
SESSION_COL_NAMES = ("sessao", "session")
# What the writer writes when there is no provenance. Compared EXACTLY.
SESSION_MISSING = {"", "-", "--", "—", "–"}


def _norm_col(name: str) -> str:
    """Normalize a COLUMN NAME: lowercase, without accents, without separators."""
    s = (name or "").strip().lower()
    s = "".join(c for c in unicodedata.normalize("NFD", s)
                if unicodedata.category(c) != "Mn")
    return "".join(c for c in s if c.isalnum())


def _session_ids(raw) -> list[str]:
    """The owning session ids of a ledger cell: '-' (or empty) means NONE.

    The ids are kept EXACTLY as written (only surrounding whitespace stripped):
    a session id is an opaque token, so A and a are different ids and a
    casefold here would silently match the wrong conversation.
    """
    if raw is None:
        return []
    if not isinstance(raw, str):
        raw = ",".join(str(x) for x in raw)
    out = []
    for tok in raw.split(","):
        t = tok.strip()
        if not t or t in SESSION_MISSING:
            continue
        out.append(t)
    return out


def _native_session_file(path: Path) -> tuple[Path, str] | None:
    """Locate the native root file; a worker uses its adjacent root JSONL."""
    if path.suffix != ".jsonl":
        return None
    match = OMP_SESSION_NAME_RE.fullmatch(path.stem)
    if match:
        return path, match.group(1)
    match = OMP_SESSION_NAME_RE.fullmatch(path.parent.name)
    if match:
        return Path(str(path.parent) + ".jsonl"), match.group(1)
    return None


def _native_session_identity(raw_path: str) -> dict:
    """Read only native session headers and explicitly referenced ancestors."""
    source = "env:PI_SESSION_FILE (native headers)"

    def unresolved(reason: str) -> dict:
        return {"ids": [], "source": source, "resolved": False, "note": reason}

    current = _native_session_file(Path(raw_path).expanduser())
    if current is None:
        return unresolved("PI_SESSION_FILE has no unambiguous native session layout")
    ids: list[str] = []
    while current is not None:
        path, session_id = current
        if session_id in ids:
            return unresolved("cycle in native parentSession references")
        ids.append(session_id)
        try:
            with path.open(encoding="utf-8") as stream:
                header = json.loads(stream.readline())
                if isinstance(header, dict) and header.get("type") == "title":
                    header = json.loads(stream.readline())
        except FileNotFoundError:
            # The native filename/reference still explicitly identifies this id.
            # There is no evidence of further ancestors: do not search for any.
            break
        except (OSError, ValueError):
            return unresolved("native session header is unreadable or malformed")
        if (not isinstance(header, dict) or header.get("type") != "session"
                or header.get("id") != session_id):
            return unresolved("native session header conflicts with its filename identity")
        parent = header.get("parentSession")
        if parent is None:
            break
        if not isinstance(parent, str) or not parent.strip():
            return unresolved("ambiguous native parentSession reference")
        parent = parent.strip()
        if SESSION_ID_RE.fullmatch(parent):
            if parent in ids:
                return unresolved("cycle in native parentSession references")
            # An id-only reference proves the parent, not its own ancestors.
            ids.append(parent)
            break
        parent_path = Path(parent).expanduser()
        if not parent_path.is_absolute():
            parent_path = path.parent / parent_path
        current = _native_session_file(parent_path)
        if current is None:
            return unresolved("parentSession does not reference a native session id or file")
    return {"ids": ids, "source": source, "resolved": True, "note": None}


def resolve_session_identity(explicit: str | None, env: dict | None = None) -> dict:
    """Resolve the identity of the INVOKING conversation.

    Precedence: --session-id > MAOS_SELF_SESSION_ID > CLAUDE_CODE_SESSION_ID >
    CLAUDE_SESSION_ID > native PI_SESSION_FILE headers. Only the latter follows
    explicit parentSession references, preserving immutable item provenance when
    OMP recovers a conversation under a new id. No cwd/title/cache-key inference.
    Unreadable, conflicting or cyclic headers fail closed, never widen to all.
    """
    env = os.environ if env is None else env

    def _ids(raw: str) -> list[str]:
        # exact tokens: a session id is opaque, so only whitespace is stripped.
        # The markers the ledger uses for "no provenance" mean the same here, and
        # "unknown" is the repo's own spelling of "absent".
        return [t for t in _session_ids(raw) if t != "unknown"]

    if explicit is not None:
        ids = _ids(explicit)
        if ids:
            return {"ids": ids, "source": "--session-id", "resolved": True, "note": None}
        # An EMPTY (or marker-only) --session-id carries no identity claim: it must
        # not shadow the environment (a caller that always passes the flag would
        # otherwise get "unresolved" while the environment knows the answer).
        explicit = None
    for var in ("MAOS_SELF_SESSION_ID", "CLAUDE_CODE_SESSION_ID", "CLAUDE_SESSION_ID"):
        raw = (env.get(var) or "").strip()
        if not raw or raw == "unknown":
            continue
        ids = _ids(raw)
        # A value that is only separators (" , ") or only a marker ("-") carries no
        # identity: reporting it as RESOLVED would show an empty queue with no
        # warning, which is exactly the "unknown is not nothing" case.
        if ids:
            return {"ids": ids, "source": f"env:{var}", "resolved": True, "note": None}
    raw_path = (env.get("PI_SESSION_FILE") or "").strip()
    if raw_path:
        return _native_session_identity(raw_path)
    return {"ids": [], "source": None, "resolved": False,
            "note": ("no session identity available (--session-id, MAOS_SELF_SESSION_ID, "
                     "CLAUDE_CODE_SESSION_ID, CLAUDE_SESSION_ID, PI_SESSION_FILE)")}


def filter_by_session(items: list[dict], identity: dict) -> list[dict]:
    """Keep only the items whose ledger provenance names this conversation.

    An item with no provenance (legacy) is NOT kept: ownership is proven by the
    ledger, never inferred from the fact that the caller mentioned it. The ids
    are compared EXACTLY — a session id is an opaque token.
    """
    wanted = set(identity.get("ids", []))
    return [it for it in items if set(it.get("session") or []) & wanted]


def resolve_hitl_scope(args) -> tuple[str, str]:
    """Which HITL ledger items this render may show: 'session' or 'all'.

    The DEFAULT in --hitl-only mode is 'session': the digest answers "what needs
    me in THIS conversation". Only an explicit `--scope all` widens it to the whole
    ledger (legacy items included). Every other --scope value narrows to session,
    because widening must be asked for and never inferred. Outside --hitl-only the
    general panel keeps its historical behaviour: the whole ledger.
    """
    if not args.hitl_only:
        return "all", "general panel: whole ledger (unchanged behaviour)"
    if args.scope == "all":
        return "all", "explicit --scope all: whole ledger, legacy items included"
    if args.scope == "session":
        return "session", "--scope session: this conversation's items only"
    if args.scope is None:
        return "session", "default: this conversation's items only"
    return "session", (f"default: this conversation's items only "
                       f"(--scope {args.scope} is a pendency scope, not a widening)")


def _md_block(text: str, marks: tuple[str, str]) -> str:
    a, b = marks
    try:
        i = text.index(a) + len(a)
        j = text.index(b)
    except ValueError:
        return ""
    return text[i:j]


def _md_rows(body: str, cols: list[str]) -> list[list[str]]:
    out = []
    for line in body.splitlines():
        if not line.startswith("|") or set(line) <= set("|- :"):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split("|")]
        if cells and cells[0] == cols[0]:  # header
            continue
        out.append(cells)
    return out


def _md_header(body: str) -> list[str]:
    """The header cells of a markdown table, or [] when there is no table."""
    for line in body.splitlines():
        if not line.startswith("|") or set(line) <= set("|- :"):
            continue
        return [c.strip() for c in line.strip().strip("|").split("|")]
    return []


def _session_col_index(header: list[str]) -> int:
    """Index of the "Sessão" column in the header, or -1 when the ledger has none.

    The column is OPTIONAL: a ledger written before the writer gained it has the
    original 11 columns, and every item in it is legacy (no provenance). The
    header is what decides, never a guess about the row width.
    """
    for i, name in enumerate(header):
        if _norm_col(name) in SESSION_COL_NAMES:
            return i
    return -1


def _base_col_index(header: list[str]) -> list[int] | None:
    """Index of each base column in the header, or None when the header is not ours.

    The base columns are the vault's fixed contract (OPEN_COLS), so the usual
    case is the header listing them in order and the mapping being positional.
    But the "Sessão" column may be written anywhere, and a positional zip would
    then shift every base value by one — a silent corruption. So: when the header
    names the base columns, they are located BY NAME; when it does not (a ledger
    we do not know), the row is read positionally as before.
    """
    if not header:
        return None
    normalized = [_norm_col(name) for name in header]
    wanted = [_norm_col(name) for name in HITL_OPEN_COLS]
    if normalized[:len(wanted)] == wanted:
        return list(range(len(wanted)))
    index = []
    for name in wanted:
        try:
            index.append(normalized.index(name))
        except ValueError:
            return None
    return index


def parse_hitl_md(path: Path) -> list[dict]:
    """Parse the OPEN table of the punch-list.md SSOT into dicts. READ-only.

    Each item also carries `session`: the id of the conversation that owns it,
    read from the ledger's own "Sessão" column. Empty means LEGACY (owner
    unknown) — never attributed to the caller.
    """
    text = path.read_text(encoding="utf-8")
    body = _md_block(text, HITL_OPEN_MARK)
    rows = _md_rows(body, HITL_OPEN_COLS)
    header = _md_header(body)
    sess_idx = _session_col_index(header)
    base_idx = _base_col_index(header)
    items = []
    for r in rows:
        if len(r) < len(HITL_OPEN_COLS):
            continue  # malformed row -> skip (the engine's `check` command flags it)
        if base_idx is None:
            d = dict(zip(HITL_OPEN_COLS, r))
        else:
            d = {name: (r[i] if i < len(r) else "")
                 for name, i in zip(HITL_OPEN_COLS, base_idx)}
        tipo = d.get("Tipo", "").split()[-1].lower() if d.get("Tipo") else ""
        # a row may carry MORE cells than the base columns (the Sessão column) or
        # exactly the base ones (a legacy ledger); both are valid
        session = _session_ids(r[sess_idx]) if 0 <= sess_idx < len(r) else []
        items.append({
            "id": d.get("ID", ""),
            "sev": d.get("Sev", ""),
            "tipo": tipo,
            "risk": d.get("R", ""),
            "decidir": d.get("Decidir", ""),
            "pediu": d.get("Pediu", ""),
            "aberto": d.get("Aberto", ""),
            "idade": d.get("Idade", ""),
            "prazo": d.get("Prazo", ""),
            "status": d.get("Status", ""),
            "link": d.get("Link", ""),
            "session": session,
        })
    return items


def _session_ids_of(item: dict) -> list[str]:
    """The owning session ids of a ledger item, from the writer's `session_id`.

    One field, one name: the writer's export contract. A missing or '-' value
    means LEGACY — no provenance.
    """
    return _session_ids(item.get("session_id"))


# ── engine callers (COMPOSE; never reimplement) ──────────────────────────────────
def call_work_compass(scope: str, include: str, extra: list[str] | None = None) -> dict:
    wc = find_work_compass()
    if not wc:
        raise RuntimeError("work-compass-aggregate.py not found (SSOT aggregation engine missing)")
    cmd = [sys.executable, str(wc), "--json",
           "--pendency-scope", scope, "--include", include,
           "--sort", "eisenhower"]
    if extra:
        cmd += extra
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
    if proc.returncode != 0 and not proc.stdout.strip():
        raise RuntimeError(f"work-compass failed (rc={proc.returncode}): {proc.stderr.strip()[:300]}")
    return json.loads(proc.stdout)


def load_compass(args) -> dict:
    if args.compass_json == "-":
        return json.load(sys.stdin)
    if args.compass_json:
        return json.loads(Path(args.compass_json).read_text(encoding="utf-8"))
    # an unspecified --scope keeps the historical pendency scope: all
    return call_work_compass(args.scope or "all", args.include)


def load_hitl(args) -> tuple[list[dict], dict]:
    """Return (items, provenance). Provenance always names the source that was read."""
    if args.hitl_json == "-":
        raw = sys.stdin.read().strip()
        items = json.loads(raw) if raw else []
        return _with_sessions(items), ledger_provenance(None, kind="json-stdin")
    if args.hitl_json:
        p = Path(args.hitl_json)
        raw = p.read_text(encoding="utf-8").strip()
        # empty file == no HITL ledger (valid)
        items = json.loads(raw) if raw else []
        return _with_sessions(items), ledger_provenance(p, kind="json")
    md = Path(args.hitl_md) if args.hitl_md else find_hitl_md()
    explicit = bool(args.hitl_md)
    if not md or not md.is_file():
        # HITL ledger absent is not fatal — a tree with zero HITL is valid
        return [], ledger_provenance(None, kind="md")
    prov = ledger_provenance(md, kind="md-explicit" if explicit else "md-discovered")
    return parse_hitl_md(md), prov


def _with_sessions(items: list) -> list[dict]:
    """Normalize the owning-session ids of every item to a list of exact ids.

    The case is PRESERVED: a session id is an opaque token, so `A` and `a` are
    different conversations and a casefold here would match the wrong one.
    """
    out = []
    for it in items:
        if isinstance(it, dict):
            it = dict(it)
            it["session"] = _session_ids_of(it)
        out.append(it)
    return out


# ── FUSION (the net-new model) ─────────────────────────────────────────────────────
# A HITL item is matched to a pendency node when the pendency's refs/title mention the
# HITL Link or ID; otherwise it lives under a dedicated HITL branch. Either way every
# HITL item is PRESENT and FLAGGED — the panel never drops a human-gate.
SEV_GLYPH = {"URGENTE": "\U0001F534", "ALTA": "\U0001F7E0", "NORMAL": "\U0001F7E1"}
HITL_FLAG = "\u23EB"   # ⏫ high-priority / human-gate marker (hitl-digest house-style)
HUMAN_FLAG = "\U0001F464"  # 👤 human-domain marker


def _sev_word(sev: str) -> str:
    s = (sev or "").upper()
    for w in ("URGENTE", "ALTA", "NORMAL"):
        if w in s:
            return w
    return "NORMAL"


def _hitl_links_index(hitl: list[dict]) -> dict[str, dict]:
    """Index HITL items by any token (ID, link tail) usable to attach to a pendency."""
    idx = {}
    for h in hitl:
        for key in (h.get("id", ""), h.get("link", "")):
            if key and key not in ("-", ""):
                idx[key.strip().lower()] = h
                tail = key.rstrip("/").rsplit("/", 1)[-1].lower()
                if tail:
                    idx[tail] = h
    return idx


def _item_tokens(it: dict) -> list[str]:
    toks = [str(it.get("id", "")), str(it.get("title", ""))]
    refs = it.get("refs", {}) or {}
    for v in refs.values():
        toks.append(str(v))
    return [t.lower() for t in toks if t]


def fuse(compass: dict, hitl: list[dict], *, hitl_only: bool, pending_only: bool,
         hitl_prov: dict | None = None, hitl_scope: dict | None = None) -> dict:
    meta = compass.get("meta", {}) or {}
    by_domain = compass.get("by_domain", {}) or {}
    items = compass.get("items", []) or []

    hidx = _hitl_links_index(hitl)
    attached_ids: set[str] = set()

    # attach HITL to pendency nodes where a token matches
    tree_domains: dict[str, list[dict]] = {}
    for dom, rows in by_domain.items():
        out_rows = []
        for it in rows:
            matched = []
            for tok in _item_tokens(it):
                if tok in hidx:
                    h = hidx[tok]
                    matched.append(h)
                    attached_ids.add(h.get("id", ""))
            node = {
                "id": it.get("id", ""),
                "title": it.get("title", ""),
                "domain": dom,
                "status": it.get("status", ""),
                "flags": it.get("flags", []) or [],
                "age_d": it.get("age_d", it.get("age", None)),
                "refs": it.get("refs", {}) or {},
                "hitl": [_hitl_norm(h) for h in matched],
            }
            if pending_only and not node["flags"] and not node["hitl"]:
                # pending-only keeps flagged or HITL-bearing nodes
                pass
            out_rows.append(node)
        if out_rows:
            tree_domains[dom] = out_rows

    # HITL items not attached to any pendency -> their own branch, never dropped
    orphan_hitl = [h for h in hitl if h.get("id", "") not in attached_ids]

    fused = {
        "meta": {
            "generated_utc": dt.datetime.now(dt.timezone.utc).isoformat(),
            "compass_count": meta.get("count", len(items)),
            "compass_candidates": meta.get("candidate_count", 0),
            "hitl_count": len(hitl),
            "hitl_attached": len(attached_ids),
            "hitl_orphan": len(orphan_hitl),
            "scope": meta.get("scope", ""),
            "compass_unavailable": meta.get("unavailable", []),
            # provenance of the HITL ledger: WHICH file was read, and whether it
            # diverges from the tracked version. Never omitted — an agent reading
            # this envelope must be able to tell a stale queue from a fresh one.
            "hitl_source": (hitl_prov or {}).get("path"),
            "hitl_source_kind": (hitl_prov or {}).get("kind"),
            "hitl_source_dirty": (hitl_prov or {}).get("dirty"),
            "hitl_source_behind": (hitl_prov or {}).get("behind"),
            "hitl_warning": (hitl_prov or {}).get("warning"),
            # WHICH ledger slice this render shows, and WHY. Never omitted: an agent
            # reading this envelope must be able to tell "this conversation has no
            # gates" from "the scope could not be resolved" from "the whole ledger".
            "hitl_scope": (hitl_scope or {}).get("scope", "all"),
            "hitl_scope_reason": (hitl_scope or {}).get("reason"),
            "hitl_session_ids": (hitl_scope or {}).get("session_ids", []),
            "hitl_session_resolved": (hitl_scope or {}).get("session_resolved", False),
            "hitl_session_source": (hitl_scope or {}).get("session_source"),
            "hitl_scope_unresolved": (hitl_scope or {}).get("unresolved"),
            # how many items the LEDGER holds, before the scope narrowed it: a
            # session scope showing 0 of 19 must not read as "there is nothing"
            "hitl_ledger_total": (hitl_scope or {}).get("ledger_total", len(hitl)),
            # whether this render is the HITL-only digest: it decides whether the
            # pendency scope is meaningful at all (in the pure digest there is none)
            "hitl_only": hitl_only,
            "sources": {
                "pendencies": "work-compass-aggregate.py --json (SSOT)",
                "priority": "work-compass --sort eisenhower (SSOT)",
                "hitl": "hitl-punch-list.py / punch-list.md (SSOT)",
            },
        },
        "domains": tree_domains if not hitl_only else {},
        "hitl_unattached": [_hitl_norm(h) for h in orphan_hitl],
    }
    return fused


def _hitl_norm(h: dict) -> dict:
    sev = _sev_word(h.get("sev", ""))
    return {
        "id": h.get("id", ""),
        "sev": sev,
        "tipo": h.get("tipo", ""),
        "risk": h.get("risk", ""),
        "decidir": h.get("decidir", ""),
        "pediu": h.get("pediu", ""),
        "prazo": h.get("prazo", ""),
        "status": h.get("status", ""),
        "link": h.get("link", ""),
        "glyph": SEV_GLYPH.get(sev, SEV_GLYPH["NORMAL"]),
        "flag": HITL_FLAG,
        "human": HUMAN_FLAG,
    }


# ── RENDERERS ──────────────────────────────────────────────────────────────────────
def _flag_suffix(node: dict) -> str:
    parts = []
    if node.get("hitl"):
        worst = max((h["sev"] for h in node["hitl"]), key=lambda s: ["NORMAL", "ALTA", "URGENTE"].index(s) if s in ("NORMAL", "ALTA", "URGENTE") else 0)
        parts.append(f"{HITL_FLAG}{SEV_GLYPH.get(worst, '')}")
    if node.get("flags"):
        parts.append("\u00b7 " + ",".join(node["flags"]))
    return ("  " + " ".join(parts)) if parts else ""


def render_tree(fused: dict, title: str) -> str:
    m = fused["meta"]
    out = [f"# {title}", ""]
    # the pendency scope is meaningless in the pure digest (there is no pendency
    # tree there), so it is not printed — the HITL scope line below says what applies
    scope_txt = "" if m.get("hitl_only") else f" · pendency scope={m['scope'] or 'all'}"
    out.append(f"> {m['compass_count']} pendencies "
               f"({m['compass_candidates']} flagged) · {m['hitl_count']} HITL "
               f"({m['hitl_attached']} attached, {m['hitl_orphan']} standalone)"
               f"{scope_txt}")
    if m["compass_unavailable"]:
        out.append(f"> unavailable: {', '.join(m['compass_unavailable'])}")
    if m.get("hitl_source"):
        out.append(f"> HITL ledger: `{m['hitl_source']}`")
    if m.get("hitl_scope") and m.get("hitl_scope") != "all":
        ids = ", ".join(m.get("hitl_session_ids") or []) or "unresolved"
        out.append(f"> HITL scope: {m['hitl_scope']} ({ids}) — {m.get('hitl_scope_reason')}")
        total = m.get("hitl_ledger_total")
        # The ownership split is only claimable when the identity RESOLVED. With an
        # unresolved identity "this conversation" is unknown, so counting what is not
        # ours would assert a fact we do not have — the warning below says it instead.
        if (m.get("hitl_session_resolved")
                and isinstance(total, int) and total > m.get("hitl_count", 0)):
            out.append(f"> {m.get('hitl_count', 0)} of {total} ledger items are this "
                       f"conversation's — the other {total - m.get('hitl_count', 0)} belong "
                       f"to other conversations or carry no provenance. `--scope all` shows "
                       f"the whole ledger.")
    if m.get("hitl_scope_unresolved"):
        out.append(f">")
        out.append(f"> ⚠ session scope unresolved: {m['hitl_scope_unresolved']}. "
                   f"No HITL item is shown because the calling conversation could not be "
                   f"identified — this is NOT an empty queue. Pass --session-id, or ask "
                   f"for the whole ledger with --scope all.")
    if m.get("hitl_warning"):
        out.append(f">")
        out.append(f"> ⚠ {m['hitl_warning']}")
    out.append("")
    for dom, rows in fused["domains"].items():
        out.append(f"- **{dom}** ({len(rows)})")
        for n in rows:
            age = f"[{n['age_d']:.0f}d]" if isinstance(n.get("age_d"), (int, float)) and n["age_d"] >= 0 else ""
            out.append(f"  - {n['id']}  {n['title']}{_flag_suffix(n)}  {age}".rstrip())
            for h in n.get("hitl", []):
                out.append(f"    - {h['flag']}{h['glyph']} HITL {h['id']} "
                           f"[{h['tipo']}/{h['risk']}] {h['decidir']}")
    orphan = fused.get("hitl_unattached", [])
    if orphan:
        out.append(f"- **HITL (human-domain {HUMAN_FLAG})** ({len(orphan)})")
        for h in orphan:
            out.append(f"  - {h['flag']}{h['glyph']} {h['id']} "
                       f"[{h['tipo']}/{h['risk']}] {h['decidir']}  "
                       f"(pediu {h['pediu'] or '?'} · prazo {h['prazo'] or '-'})")
    return "\n".join(out) + "\n"


def render_mermaid(fused: dict, title: str) -> str:
    def _mm(s: str) -> str:
        return (s or "").replace("(", "[").replace(")", "]").replace('"', "'")

    m = fused["meta"]
    out = []
    # provenance goes OUTSIDE the fence: a mindmap node cannot carry a sentence safely
    if m.get("hitl_source"):
        out.append(f"> HITL ledger: `{m['hitl_source']}`")
    if m.get("hitl_scope") and m.get("hitl_scope") != "all":
        ids = ", ".join(m.get("hitl_session_ids") or []) or "unresolved"
        out.append(f"> HITL scope: {m['hitl_scope']} ({ids}) — {m.get('hitl_scope_reason')}")
    if m.get("hitl_scope_unresolved"):
        out.append(f"> ⚠ session scope unresolved: {m['hitl_scope_unresolved']}. "
                   f"No HITL item is shown because the calling conversation could not be "
                   f"identified — this is NOT an empty queue.")
    if m.get("hitl_warning"):
        out.append(f"> ⚠ {m['hitl_warning']}")
    if out:
        out.append("")
    out += ["```mermaid", "mindmap", f"  root(({_mm(title)}))"]
    for dom, rows in fused["domains"].items():
        out.append(f"    {_mm(dom)}")
        for n in rows:
            cls = ":::hitl" if n.get("hitl") else (":::flag" if n.get("flags") else "")
            out.append(f"      {_mm(n['id'])} {_mm(n['title'][:40])}{cls}")
            for h in n.get("hitl", []):
                out.append(f"        {h['flag']} {_mm(h['id'])} {_mm(h['decidir'][:30])}:::hitl")
    orphan = fused.get("hitl_unattached", [])
    if orphan:
        out.append("    HITL")
        for h in orphan:
            out.append(f"      {h['flag']} {_mm(h['id'])} {_mm(h['decidir'][:30])}:::hitl")
    out.append("```")
    # mermaid is experimental for mindmap icons/classes (per DDR lesson): degrade-safe.
    return "\n".join(out) + "\n"


def render_html(fused: dict, title: str) -> str:
    m = fused["meta"]
    e = _html.escape

    def node_li(n: dict) -> str:
        badge = ""
        if n.get("hitl"):
            worst = n["hitl"][0]["sev"]
            badge = f'<span class="b hitl">{HITL_FLAG} HITL</span>'
        elif n.get("flags"):
            badge = f'<span class="b flag">{e(",".join(n["flags"]))}</span>'
        inner = f'<span class="id">{e(n["id"])}</span> {e(n["title"])} {badge}'
        kids = ""
        if n.get("hitl"):
            kids = "<ul>" + "".join(
                f'<li class="hl {h["sev"].lower()}">{h["glyph"]} {e(h["id"])} '
                f'<em>[{e(h["tipo"])}/{e(h["risk"])}]</em> {e(h["decidir"])}</li>'
                for h in n["hitl"]) + "</ul>"
        return f"<li>{inner}{kids}</li>"

    domains_html = ""
    for dom, rows in fused["domains"].items():
        lis = "".join(node_li(n) for n in rows)
        domains_html += f'<details open><summary>{e(dom)} <small>({len(rows)})</small></summary><ul>{lis}</ul></details>'
    orphan = fused.get("hitl_unattached", [])
    if orphan:
        lis = "".join(
            f'<li class="hl {h["sev"].lower()}">{h["glyph"]} {e(h["id"])} '
            f'<em>[{e(h["tipo"])}/{e(h["risk"])}]</em> {e(h["decidir"])} '
            f'<small>pediu {e(h["pediu"] or "?")} · prazo {e(h["prazo"] or "-")}</small></li>'
            for h in orphan)
        domains_html += f'<details open><summary>{HUMAN_FLAG} HITL human-domain <small>({len(orphan)})</small></summary><ul>{lis}</ul></details>'

    source_html = ""
    # the pendency scope is meaningless in the pure digest (no pendency tree there)
    scope_html = "" if m.get("hitl_only") else f" &middot; scope={e(m['scope'] or 'all')}"
    if m.get("hitl_source"):
        source_html += f'<p class="sub">HITL ledger: <code>{e(str(m["hitl_source"]))}</code></p>'
    if m.get("hitl_scope") and m.get("hitl_scope") != "all":
        ids = ", ".join(m.get("hitl_session_ids") or []) or "unresolved"
        source_html += (f'<p class="sub">HITL scope: <code>{e(str(m["hitl_scope"]))}</code> '
                        f'({e(ids)}) — {e(str(m.get("hitl_scope_reason") or ""))}</p>')
    if m.get("hitl_scope_unresolved"):
        source_html += (f'<p class="warn">&#9888; session scope unresolved: '
                        f'{e(str(m["hitl_scope_unresolved"]))}. No HITL item is shown because '
                        f'the calling conversation could not be identified — this is NOT an '
                        f'empty queue.</p>')
    if m.get("hitl_warning"):
        source_html += f'<p class="warn">&#9888; {e(str(m["hitl_warning"]))}</p>'

    return f"""<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{e(title)}</title>
<style>
 :root{{--bg:#0d1117;--fg:#e6edf3;--mut:#8b949e;--line:#21262d;--hitl:#f85149;--alta:#d29922;--flag:#58a6ff}}
 @media(prefers-color-scheme:light){{:root{{--bg:#fff;--fg:#1f2328;--mut:#656d76;--line:#d0d7de}}}}
 body{{background:var(--bg);color:var(--fg);font:14px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace;margin:0;padding:2rem}}
 h1{{font-size:1.2rem;margin:0 0 .25rem}} .sub{{color:var(--mut);margin:0 0 1.5rem;font-size:.85rem}}
 details{{border:1px solid var(--line);border-radius:8px;margin:.5rem 0;padding:.5rem .75rem}}
 summary{{cursor:pointer;font-weight:600}} ul{{list-style:none;margin:.4rem 0;padding-left:1.1rem}}
 li{{margin:.2rem 0}} .id{{color:var(--flag);font-weight:600}}
 .b{{font-size:.72rem;padding:.05rem .4rem;border-radius:999px;margin-left:.3rem}}
 .b.hitl{{background:var(--hitl);color:#fff}} .b.flag{{background:var(--flag);color:#fff}}
 .hl{{color:var(--mut)}} .hl.urgente{{color:var(--hitl)}} .hl.alta{{color:var(--alta)}}
 em{{color:var(--mut);font-style:normal}} small{{color:var(--mut)}}
 .warn{{border:1px solid var(--alta);border-left:4px solid var(--alta);border-radius:6px;
   padding:.5rem .75rem;margin:0 0 1rem;color:var(--fg);font-size:.85rem}}
 code{{color:var(--flag)}}
</style></head><body>
<h1>{e(title)}</h1>
<p class="sub">{m['compass_count']} pend&ecirc;ncias ({m['compass_candidates']} flagged) &middot;
{m['hitl_count']} HITL ({m['hitl_attached']} attached / {m['hitl_orphan']} standalone){scope_html} &middot;
gerado {e(m['generated_utc'][:19])}Z</p>
{source_html}
{domains_html}
<p class="sub">Fontes (SSOT, n&atilde;o reimplementadas): work-compass &middot; eisenhower &middot; hitl punch-list.</p>
</body></html>
"""


# ── envelope (ONE unified JSON for agents) ─────────────────────────────────────────
def render_json(fused: dict, title: str) -> str:
    env = {
        "artifact": "synopsis-panel",
        "title": title,
        "schema": "synopsis-panel/v1",
        "meta": fused["meta"],
        "tree": {"domains": fused["domains"], "hitl_unattached": fused["hitl_unattached"]},
    }
    return json.dumps(env, ensure_ascii=False, indent=2)


RENDERERS = {
    "tree": render_tree,
    "mermaid": render_mermaid,
    "html": render_html,
    "json": render_json,
}


# ── self-heal (hybrid M.O.: on failure emit a repair-request, not a bare trace) ────
def self_heal_envelope(exc: Exception, ctx: dict) -> str:
    return json.dumps({
        "synopsis_panel_error": True,
        "error_type": type(exc).__name__,
        "error": str(exc),
        "context": ctx,
        "repair_request": (
            "synopsis-panel failed. Likely causes: (1) work-compass-aggregate.py or "
            "hitl-punch-list.py / punch-list.md not found or moved (re-run with explicit "
            "--compass-json / --hitl-md); (2) a changed JSON/column contract in an SSOT "
            "engine (re-align the parse keys). Diagnose at the named source, then re-run."
        ),
    }, ensure_ascii=False, indent=2)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description="synopsis-panel — fuse pendencies N-Tree + HITL into one view")
    ap.add_argument("--compass-json", default=None, help="work-compass --json path, '-' for stdin, or omit to call the engine")
    ap.add_argument("--hitl-md", default=None, help="punch-list.md path (default: discover)")
    ap.add_argument("--hitl-json", default=None, help="pre-parsed HITL JSON array path or '-'")
    ap.add_argument("--format", choices=list(RENDERERS), default="tree")
    ap.add_argument("--scope", choices=["current", "session", "repo", "vault", "all"], default=None,
                    help="pendency scope forwarded to work-compass (default: all). In "
                         "--hitl-only mode it ALSO selects the HITL ledger scope: unspecified "
                         "means THIS conversation's items; an explicit 'all' widens to the "
                         "whole ledger, legacy items included")
    ap.add_argument("--session-id", default=None,
                    help="identity of the invoking conversation (comma-separated for a set, "
                         "compared exactly); default: MAOS_SELF_SESSION_ID, "
                         "CLAUDE_CODE_SESSION_ID, CLAUDE_SESSION_ID, then native "
                         "PI_SESSION_FILE headers and explicit parentSession ancestors")
    ap.add_argument("--include", choices=["pending", "all"], default="pending")
    ap.add_argument("--hitl-only", action="store_true", help="render only the HITL branch")
    ap.add_argument("--pending-only", action="store_true", help="keep flagged/HITL-bearing pendency nodes")
    ap.add_argument("--title", default="Synopsis — pend\u00eancias + HITL (N-Tree)")
    ap.add_argument("--self-heal", action="store_true", help="emit a repair-request envelope on error instead of a traceback")
    args = ap.parse_args(argv)

    ctx = {"format": args.format, "scope": args.scope or "all", "include": args.include}
    try:
        compass = load_compass(args)
        hitl, hitl_prov = load_hitl(args)

        # ── the HITL scope, applied BEFORE counting, prioritising and rendering ──
        # The ledger is one global queue; a digest that shows all of it answers a
        # question nobody asked. The default in --hitl-only mode is THIS
        # conversation's items, and the filter runs before the counts, so every
        # number in the output describes the slice that was actually shown.
        scope, scope_reason = resolve_hitl_scope(args)
        identity = resolve_session_identity(args.session_id)
        scope_info = {
            "scope": scope,
            "reason": scope_reason,
            "session_ids": identity["ids"],
            "session_resolved": identity["resolved"],
            "session_source": identity["source"],
            "unresolved": None,
            "ledger_total": len(hitl),
        }
        if scope == "session":
            if not identity["resolved"]:
                # FAIL CLOSED: an unresolved identity is not an empty queue and not a
                # full one. Show nothing, and say the scope could not be resolved.
                scope_info["unresolved"] = identity["note"]
                hitl = []
            else:
                hitl = filter_by_session(hitl, identity)

        fused = fuse(compass, hitl, hitl_only=args.hitl_only,
                     pending_only=args.pending_only, hitl_prov=hitl_prov,
                     hitl_scope=scope_info)
        sys.stdout.write(RENDERERS[args.format](fused, args.title))
        return 0
    except Exception as exc:  # noqa: BLE001 — hybrid self-heal boundary
        if args.self_heal:
            sys.stderr.write(self_heal_envelope(exc, ctx) + "\n")
        else:
            sys.stderr.write(f"synopsis-panel error: {type(exc).__name__}: {exc}\n")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
