#!/usr/bin/env python3
"""
work-compass-aggregate.py — cross-domain work-item AGGREGATOR + N-Tree renderer +
stale/orphan/pending detector + delegation-router for the `work-compass` agentic-tool.

Phase-1 (read-only by default). COMPOSES existing producers — it reimplements NONE of
their logic:
  - sessions / branches harvested via the existing `inventory-sessions.py` (its JSONL schema)
  - PRs via `gh pr list --json ...`           (GitHub CLI)
  - issues via `gh issue list --json ...`      (GitHub CLI)
  - Jira via `acli` IF available              (capability-detected; degrade to "unavailable")
  - worktrees via `git worktree list --porcelain`
  - branches via `git branch -vv`

Everything is normalized into ONE work-item graph (namespaced ids):
  jira:KEY · gh:owner/repo#n · session:<id> · worktree:<path> · branch:<name> · pr:<repo>#n

Output: ASCII N-Tree (default) grouped by the 7 CPT domains, OR --json (the work-item
graph), OR --format=mermaid. Deterministic: same input → same tree (CPT §9.5 consumer
contract). Compass scope verbs accepted (--scope=current|down|sideways|up|forward).

READ-ONLY: provider writes / session pause-stop-delete are NEVER executed — the
delegation-router only PRINTS a reviewable command for operator approval.

Stdlib only. AAIF cross-vendor. Capability-detected (missing producer → domain marked
"unavailable", never blocks). LF endings. No secrets in output.

Usage:
  work-compass-aggregate.py [--json | --format=ascii|mermaid]
                            [--scope current|down|sideways|up|forward] [--node ID]
                            [--stale-days N] [--repo owner/name] [--inventory PATH]
                            [--no-jira] [--no-github] [--no-sessions] [--no-git]
                            [--route ID --action ACTION] [--detect-only]
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# ── constants ──────────────────────────────────────────────────────────────────
HOME = Path.home()
DEFAULT_STALE_DAYS = 7
INVENTORY_SCRIPT = HOME / ".claude" / "scripts" / "inventory-sessions.py"

# ⛔ openclaw is a detect-only sovereign domain — NEVER enumerate/read under it
# (openclaw-detect-only-sovereign-mandatory). Every store-glob excludes this subtree.
OPENCLAW_ROOT = os.path.realpath(str(HOME / "openclaw"))

# Default local stores for the extended scanners (overridable for tests).
PLANS_DIR = HOME / ".claude" / "plans"
JOBS_DIR = HOME / ".claude" / "jobs"
CODEX_INDEX = HOME / ".codex" / "session_index.jsonl"

# The 7 CPT domains (cowork-process-topology-protocol §1). One bucket per domain.
DOMAINS = ["ticket", "worktree", "branch", "session", "thread", "process", "graph-node"]

# Status glyphs reused from statusmap house-style (statusmap/README.md "Indicadores").
GLYPH = {
    "ok": "🟢", "warn": "🟡", "fail": "🔴", "unknown": "⚪",
    "stale": "🟠", "orphan": "🔵",
}
ASCII_GLYPH = {  # no-emoji fallback (statusmap convention)
    "ok": "[OK]", "warn": "[WARN]", "fail": "[FAIL]", "unknown": "[????]",
    "stale": "[STAL]", "orphan": "[ORPH]",
}


# ── capability detection ─────────────────────────────────────────────────────────
def have(cmd: str) -> bool:
    return shutil.which(cmd) is not None


def run(argv: list[str], timeout: int = 30) -> tuple[int, str, str]:
    """Run a command read-only; never raises. Returns (rc, stdout, stderr)."""
    try:
        p = subprocess.run(
            argv, capture_output=True, text=True, timeout=timeout, check=False
        )
        return p.returncode, p.stdout, p.stderr
    except (OSError, subprocess.TimeoutExpired) as e:  # degrade gracefully
        return 1, "", f"{type(e).__name__}: {e}"


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def parse_ts(s: str | None) -> datetime | None:
    if not s:
        return None
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except (ValueError, TypeError):
        return None


def days_since(ts: str | None, ref: datetime | None = None) -> float | None:
    dt = parse_ts(ts)
    if dt is None:
        return None
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return ((ref or now_utc()) - dt).total_seconds() / 86400.0


def _is_openclaw(path) -> bool:
    """True if `path` is the openclaw sovereign tree or inside it (detect-only guard)."""
    try:
        rp = os.path.realpath(str(path))
    except OSError:
        rp = str(path)
    return rp == OPENCLAW_ROOT or rp.startswith(OPENCLAW_ROOT + os.sep)


def _mtime_iso(p: Path) -> str:
    """File/dir mtime as ISO-8601 UTC, or '' on error. Metadata only (no content)."""
    try:
        return datetime.fromtimestamp(p.stat().st_mtime, timezone.utc).isoformat()
    except OSError:
        return ""


def _tree_state(path: str) -> str:
    """Replicate gbd_tree_state (read-only): DIRTY | CLEAN | DETACHED.

    DIRTY = uncommitted TRACKED changes (porcelain line not starting with '??');
    untracked-only stays CLEAN — the exact WIP-loss class. Never raises.
    """
    rc, _, _ = run(["git", "-C", path, "symbolic-ref", "--quiet", "HEAD"])
    if rc != 0:
        return "DETACHED"
    rc, out, _ = run(["git", "-C", path, "status", "--porcelain"])
    if rc == 0 and any(ln and not ln.startswith("??") for ln in out.splitlines()):
        return "DIRTY"
    return "CLEAN"


# ── work-item model ──────────────────────────────────────────────────────────────
def item(id_: str, domain: str, title: str, **extra) -> dict:
    """A normalized work item. `id` is provider-namespaced; `domain` ∈ DOMAINS."""
    base = {
        "id": id_,
        "domain": domain,
        "title": title,
        "status": extra.pop("status", "unknown"),
        "last_ts": extra.pop("last_ts", ""),
        "refs": extra.pop("refs", {}),   # cross-domain links (branch, pr, ticket, session…)
        "flags": [],                     # detector candidates land here
        "source": extra.pop("source", ""),
    }
    base.update(extra)
    return base


# ── collectors (each COMPOSES an existing producer; none reimplemented) ──────────────
def collect_sessions(inventory_path: str | None) -> tuple[list[dict], str | None]:
    """Run the existing inventory-sessions.py and normalize its JSONL rows."""
    if not INVENTORY_SCRIPT.is_file():
        return [], "sessions: inventory-sessions.py not found"
    # The producer writes JSONL to stdout when --out omitted. We capture it.
    rc, out, err = run([sys.executable, str(INVENTORY_SCRIPT)], timeout=120)
    if rc != 0 and not out:
        return [], f"sessions: inventory failed ({err.strip()[:80]})"
    items: list[dict] = []
    for line in out.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError:
            continue
        if "error" in row:
            continue
        sid = row.get("session_id", "")
        if not sid:
            continue
        title = row.get("session_name") or row.get("last_prompt_excerpt") or "(no prompt)"
        items.append(item(
            f"session:{sid}", "session", title,
            last_ts=row.get("last_ts", ""),
            source="inventory-sessions.py",
            refs={
                "branch": row.get("git_branch", ""),
                "cwd": row.get("decoded_cwd", ""),
                "tickets": row.get("ticket_refs", []),
                "prs": row.get("pr_refs", []),
                "kind": row.get("kind", ""),
            },
        ))
    return items, None


def collect_worktrees_and_branches(repo_dir: str) -> tuple[list[dict], str | None]:
    """git worktree list --porcelain + git branch -vv (native git; nothing reimplemented)."""
    if not have("git"):
        return [], "git: not available"
    items: list[dict] = []
    # worktrees
    rc, out, _ = run(["git", "-C", repo_dir, "worktree", "list", "--porcelain"])
    if rc == 0:
        cur: dict = {}
        for ln in out.splitlines():
            if ln.startswith("worktree "):
                cur = {"path": ln[len("worktree "):]}
            elif ln.startswith("branch "):
                cur["branch"] = ln[len("branch "):].replace("refs/heads/", "")
            elif ln == "" and cur:
                p = cur.get("path", "")
                items.append(item(
                    f"worktree:{p}", "worktree", os.path.basename(p) or p,
                    source="git worktree list",
                    refs={"branch": cur.get("branch", ""), "path": p},
                ))
                cur = {}
        if cur:  # last (no trailing blank line)
            p = cur.get("path", "")
            items.append(item(
                f"worktree:{p}", "worktree", os.path.basename(p) or p,
                source="git worktree list",
                refs={"branch": cur.get("branch", ""), "path": p},
            ))
    # branches
    rc, out, _ = run(["git", "-C", repo_dir, "branch", "-vv"])
    if rc == 0:
        for ln in out.splitlines():
            name = ln[2:].split(" ", 1)[0].strip()
            if not name or name.startswith("("):
                continue
            items.append(item(
                f"branch:{name}", "branch", name,
                source="git branch -vv",
                refs={"name": name},
            ))
    # enrich each worktree with its working-tree state (blind-spot: WIP-dirty inside)
    for it in items:
        if it["domain"] == "worktree" and it["refs"].get("path"):
            it["refs"]["wip_state"] = _tree_state(it["refs"]["path"])
    return items, None


def collect_github(repo: str | None) -> tuple[list[dict], str | None]:
    """gh pr list + gh issue list (GitHub CLI). Degrade if gh missing/unauth."""
    if not have("gh"):
        return [], "github: gh CLI not available"
    items: list[dict] = []
    base = ["gh"]
    repo_args = ["--repo", repo] if repo else []
    # PRs
    rc, out, err = run(
        base + ["pr", "list", "--state", "open", "--limit", "100"] + repo_args
        + ["--json", "number,title,updatedAt,headRefName,url,isDraft"]
    )
    if rc != 0:
        return [], f"github: {err.strip()[:80] or 'unavailable'}"
    rname = repo or _infer_repo_slug()
    try:
        for pr in json.loads(out or "[]"):
            n = pr.get("number")
            items.append(item(
                f"pr:{rname}#{n}", "process", pr.get("title", ""),
                status="warn" if pr.get("isDraft") else "ok",
                last_ts=pr.get("updatedAt", ""),
                source="gh pr list",
                refs={"branch": pr.get("headRefName", ""), "url": pr.get("url", ""),
                      "number": n, "repo": rname},
            ))
    except json.JSONDecodeError:
        pass
    # Issues
    rc, out, _ = run(
        base + ["issue", "list", "--state", "open", "--limit", "100"] + repo_args
        + ["--json", "number,title,updatedAt,url"]
    )
    if rc == 0:
        try:
            for iss in json.loads(out or "[]"):
                n = iss.get("number")
                items.append(item(
                    f"gh:{rname}#{n}", "ticket", iss.get("title", ""),
                    last_ts=iss.get("updatedAt", ""),
                    source="gh issue list",
                    refs={"url": iss.get("url", ""), "number": n, "repo": rname},
                ))
        except json.JSONDecodeError:
            pass
    return items, None


def _infer_repo_slug() -> str:
    rc, out, _ = run(["gh", "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner"])
    return out.strip() if rc == 0 and out.strip() else "github"


def collect_jira() -> tuple[list[dict], str | None]:
    """Jira via `acli` IF available (capability-detected). Degrade to unavailable.

    We do NOT hardcode a JQL beyond 'assigned + open' and we never block. If acli is
    absent OR unauthenticated, the domain is reported 'unavailable' (anti-theater: no
    fabricated tickets).
    """
    if not have("acli"):
        return [], "jira: acli not available (degrade)"
    # acli surface varies by version; try a conservative JSON-emitting form, accept failure.
    rc, out, err = run(
        ["acli", "jira", "workitem", "search",
         "--jql", "assignee = currentUser() AND statusCategory != Done",
         "--json"],
        timeout=40,
    )
    if rc != 0 or not out.strip():
        return [], f"jira: acli query unavailable ({err.strip()[:60]})"
    items: list[dict] = []
    try:
        data = json.loads(out)
        rows = data if isinstance(data, list) else data.get("issues", data.get("results", []))
        for r in rows or []:
            key = r.get("key") or r.get("issueKey") or ""
            if not key:
                continue
            fields = r.get("fields", r)
            summary = fields.get("summary", r.get("summary", ""))
            updated = fields.get("updated", r.get("updated", ""))
            items.append(item(
                f"jira:{key}", "ticket", summary,
                last_ts=updated, source="acli jira",
                refs={"key": key},
            ))
    except (json.JSONDecodeError, AttributeError):
        return [], "jira: acli output unparseable (degrade)"
    return items, None


# ── extended local scanners (blind-spots — compose native git + fs; metadata-only) ──
def collect_stashes(repo_dir: str) -> tuple[list[dict], str | None]:
    """git stash list (native git). Forgotten WIP hidden in the stash stack.

    Domain graph-node. Metadata only (reflog selector · date · subject). Never raises.
    """
    if not have("git"):
        return [], "stashes: git not available"
    # %gd=selector(stash@{0}) · %cI=strict-ISO committer date · %gs=reflog subject
    rc, out, _ = run(["git", "-C", repo_dir, "stash", "list", "--format=%gd|%cI|%gs"])
    if rc != 0:
        return [], None  # not a repo / no stashes → silent (absence is not an error)
    items: list[dict] = []
    for ln in out.splitlines():
        ln = ln.strip()
        if not ln:
            continue
        parts = ln.split("|", 2)
        ref = parts[0]
        ts = parts[1] if len(parts) > 1 else ""
        subj = parts[2] if len(parts) > 2 else ""
        items.append(item(
            f"stash:{ref}", "graph-node", subj or ref,
            last_ts=ts, source="git stash list",
            refs={"stash_ref": ref},
        ))
    return items, None


def _plan_meta(p: Path) -> tuple[str, int]:
    """First heading (≤60c) + count of unchecked '- [ ]' next-steps. Metadata only."""
    title, open_steps = "", 0
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return "", 0
    for ln in text.splitlines():
        s = ln.strip()
        if not title and s.startswith("# "):
            title = s[2:].strip()[:60]
        if s.startswith("- [ ]") or s.startswith("* [ ]"):
            open_steps += 1
    return title, open_steps


def collect_plans(plans_dir: str | Path | None = None) -> tuple[list[dict], str | None]:
    """Walk ~/.claude/plans/*.md (mtime + open next-steps). Abandoned plans rot here.

    Domain graph-node. Emits path/title/mtime/open-step-count only — never file body.
    """
    base = Path(plans_dir) if plans_dir else PLANS_DIR
    if not base.is_dir():
        return [], "plans: ~/.claude/plans not present"
    items: list[dict] = []
    for p in sorted(base.glob("*.md")):
        if _is_openclaw(p):  # ⛔ never enumerate the sovereign tree
            continue
        title, open_steps = _plan_meta(p)
        items.append(item(
            f"plan:{p.name}", "graph-node", title or p.stem,
            last_ts=_mtime_iso(p), source="~/.claude/plans",
            refs={"path": str(p), "open_next_steps": open_steps},
        ))
    return items, None


def collect_bg_jobs(jobs_dir: str | Path | None = None) -> tuple[list[dict], str | None]:
    """Scan ~/.claude/jobs/<id>/ (state.json status + timeline.jsonl mtime).

    Domain process. Orphaned/stale background jobs hide here. Metadata only.
    """
    base = Path(jobs_dir) if jobs_dir else JOBS_DIR
    if not base.is_dir():
        return [], "jobs: ~/.claude/jobs not present"
    items: list[dict] = []
    for d in sorted(base.iterdir()):
        if not d.is_dir() or _is_openclaw(d):
            continue
        status = "unknown"
        state_f = d / "state.json"
        if state_f.is_file():
            try:
                status = str(json.loads(state_f.read_text(encoding="utf-8",
                                                           errors="replace")).get("status", "unknown"))
            except (OSError, json.JSONDecodeError):
                pass
        tl = d / "timeline.jsonl"
        last_ts = _mtime_iso(tl if tl.is_file() else d)
        wc_status = "ok" if status in ("completed", "done", "succeeded") else "warn"
        items.append(item(
            f"job:{d.name}", "process", f"bg-job {d.name} ({status})",
            status=wc_status, last_ts=last_ts, source="~/.claude/jobs",
            refs={"path": str(d), "job_status": status},
        ))
    return items, None


def collect_codex_sessions(index_path: str | Path | None = None) -> tuple[list[dict], str | None]:
    """Cross-vendor: read Codex's structured ~/.codex/session_index.jsonl.

    Domain session. Codex sessions are invisible to the Claude-only session producer.
    Cursor/Copilot/Gemini/Aider adapters are documented stubs (YAGNI) — not built.
    """
    idx = Path(index_path) if index_path else CODEX_INDEX
    if not idx.is_file():
        return [], "codex: ~/.codex/session_index.jsonl not present"
    if _is_openclaw(idx):
        return [], None
    try:
        text = idx.read_text(encoding="utf-8", errors="replace")
    except OSError as e:
        return [], f"codex: {type(e).__name__}"
    items: list[dict] = []
    for ln in text.splitlines():
        ln = ln.strip()
        if not ln:
            continue
        try:
            row = json.loads(ln)
        except json.JSONDecodeError:
            continue
        sid = str(row.get("id") or row.get("session_id") or "")
        if not sid:
            continue
        title = row.get("thread_name") or row.get("name") or "(codex session)"
        items.append(item(
            f"codex-session:{sid}", "session", str(title)[:60],
            last_ts=row.get("updated_at") or row.get("updatedAt") or "",
            source="~/.codex/session_index.jsonl",
            refs={"vendor": "codex"},
        ))
    return items, None


# ── detector (≤10 transparent heuristics; surfaces CANDIDATES, never auto-actions) ──
def detect(items: list[dict], stale_days: int) -> None:
    by_id = {it["id"]: it for it in items}
    branches = {it["refs"].get("name", "") for it in items if it["domain"] == "branch"}
    # branch -> has a PR?
    pr_branches = {it["refs"].get("branch", "") for it in items if it["id"].startswith("pr:")}
    # PR -> has a ticket? (ticket ref present anywhere in title/refs)
    ticket_keys = {it["refs"].get("key") or it["refs"].get("number")
                   for it in items if it["domain"] == "ticket"}
    # ticket -> has a session referencing it?
    sess_ticket_refs: set[str] = set()
    sess_branch_refs: set[str] = set()
    for it in items:
        if it["domain"] == "session":
            for t in it["refs"].get("tickets", []):
                sess_ticket_refs.add(t)
            if it["refs"].get("branch"):
                sess_branch_refs.add(it["refs"]["branch"])
    worktree_branches = {it["refs"].get("branch", "") for it in items if it["domain"] == "worktree"}

    for it in items:
        d, refs = it["domain"], it["refs"]
        # H1 branch-no-PR (a feature branch with no open PR)
        if d == "branch":
            name = refs.get("name", "")
            if name and name not in ("main", "master", "develop") and name not in pr_branches:
                it["flags"].append("branch-no-PR")
        # H2 PR-no-ticket
        if it["id"].startswith("pr:") and not (refs.get("number") in ticket_keys
                                               or _title_has_ticket(it["title"])):
            it["flags"].append("PR-no-ticket")
        # H3 ticket-no-session
        if d == "ticket":
            key = refs.get("key") or (f"#{refs.get('number')}" if refs.get("number") else "")
            if key and key not in sess_ticket_refs and str(refs.get("number")) not in {
                str(x) for x in sess_ticket_refs
            }:
                it["flags"].append("ticket-no-session")
        # H4 >Nd-no-update (any domain with a timestamp)
        ds = days_since(it.get("last_ts"))
        if ds is not None and ds > stale_days:
            it["flags"].append(f">{stale_days}d-no-update")
            if it["status"] in ("unknown", "ok"):
                it["status"] = "stale"
        # H5 worktree-no-branch (worktree pointing at detached/unknown branch)
        if d == "worktree" and not refs.get("branch"):
            it["flags"].append("worktree-no-branch")
        # H6 session-orphan (session whose branch no longer exists)
        if d == "session":
            b = refs.get("branch", "")
            if b and b not in branches and b not in worktree_branches:
                it["flags"].append("session-orphan")
        # H7 worktree-dirty-wip (uncommitted TRACKED changes hiding inside a worktree)
        if d == "worktree" and refs.get("wip_state") == "DIRTY":
            it["flags"].append("worktree-dirty-wip")
        # H8 stash-forgotten (a stash older than the staleness threshold)
        if it["id"].startswith("stash:"):
            ds = days_since(it.get("last_ts"))
            if ds is not None and ds > stale_days:
                it["flags"].append("stash-forgotten")
        # H9 plan-orphan (stale + open next-steps) / plan-stale (stale, no open steps)
        if it["id"].startswith("plan:"):
            ds = days_since(it.get("last_ts"))
            if ds is not None and ds > stale_days:
                it["flags"].append("plan-orphan" if refs.get("open_next_steps", 0) > 0
                                   else "plan-stale")
        # H10 job-orphan (claims running but untouched >Nd) / job-stale (old idle job)
        if it["id"].startswith("job:"):
            ds = days_since(it.get("last_ts"))
            if ds is not None and ds > stale_days:
                running = refs.get("job_status", "") in ("running", "active", "in_progress")
                it["flags"].append("job-orphan" if running else "job-stale")
        if it["flags"] and it["status"] in ("ok", "unknown"):
            it["status"] = "orphan" if any("orphan" in f or "-no-" in f for f in it["flags"]) else it["status"]
    return None


_TICKET_RE = re.compile(r"\b[A-Z]{2,}-\d+\b|#\d+")


def _title_has_ticket(title: str) -> bool:
    return bool(_TICKET_RE.search(title or ""))


# ── delegation-router (maps node → SUGGESTED existing-tool command; PRINT only) ──────
ROUTES = {
    # flag/domain → (tool, command-template, rationale)
    "branch-no-PR":   ("preflight",  "/preflight worktree {slug}", "branch has no PR — isolate + open one"),
    "PR-no-ticket":   ("ticket-as-prompt", "/ticket-as-prompt --link {id}", "PR lacks a tracker ticket — create/link one"),
    "ticket-no-session": ("auto-pilot", "/maos:auto-pilot \"work {id}\"", "ticket has no session — start work"),
    "session-orphan": ("postflight", "/maos:postflight  # archive/close orphan session {id}", "session branch gone — close out"),
    "worktree-no-branch": ("preflight", "/preflight detect  # inspect {id}", "worktree detached — inspect"),
    "_stale":         ("morning-briefing", "/morning-briefing --mode=recap  # review stale {id}", "stale — recap before deciding"),
    "_session":       ("auto-orchestrator", "/auto-orchestrator  # resume {id}", "resume session work"),
    "_pr":            ("quiesce", "/maos:quiesce  # converge open PR {id}", "drive PR to green"),
    "worktree-dirty-wip": ("postflight", "/maos:postflight  # commit or stash WIP in {id}", "uncommitted WIP inside worktree — commit/stash before it is lost"),
    "stash-forgotten":    ("git", "git stash show -p {id}  # review then pop/drop", "forgotten stash — review + pop or drop"),
    "plan-orphan":        ("auto-pilot", "/maos:auto-pilot \"resume plan {id}\"", "abandoned plan with open next-steps — resume or archive"),
    "plan-stale":         ("postflight", "/maos:postflight  # archive stale plan {id}", "stale plan, no open steps — archive"),
    "job-orphan":         ("postflight", "/maos:postflight  # inspect orphaned bg-job {id}", "bg-job claims running but stale — inspect/kill"),
    "job-stale":          ("postflight", "/maos:postflight  # clean stale bg-job {id}", "stale bg-job — clean up"),
}


def route(node: dict, action: str | None) -> dict:
    """Return a SUGGESTED command for operator review. NEVER executes a write."""
    flags = node.get("flags", [])
    chosen_key = None
    for f in flags:
        if f in ROUTES:
            chosen_key = f
            break
    if chosen_key is None:
        if node["id"].startswith("pr:"):
            chosen_key = "_pr"
        elif node["domain"] == "session":
            chosen_key = "_session"
        elif node["status"] == "stale":
            chosen_key = "_stale"
    if chosen_key is None:
        return {"node": node["id"], "suggestion": None,
                "note": "no routing heuristic matched — operator decides"}
    tool, tmpl, why = ROUTES[chosen_key]
    cmd = tmpl.format(id=node["id"], slug=_slug(node["title"]))
    destructive = action in {"pause", "stop", "delete"}
    return {
        "node": node["id"],
        "tool": tool,
        "suggested_command": cmd,
        "rationale": why,
        "execute": False,  # read-only contract — operator must run it manually
        "warning": ("DESTRUCTIVE: operator must confirm — tool prints only, never executes"
                    if destructive else "review-before-submit"),
    }


def _slug(title: str) -> str:
    s = re.sub(r"[^a-z0-9]+", "-", (title or "node").lower()).strip("-")
    return (s[:32] or "node")


# ── renderers ────────────────────────────────────────────────────────────────────
def _glyph(status: str, ascii_only: bool) -> str:
    table = ASCII_GLYPH if ascii_only else GLYPH
    return table.get(status, table["unknown"])


def render_ascii(graph: dict, ascii_only: bool = False) -> str:
    out: list[str] = []
    out.append("🧭 work-compass — unified work-landscape N-Tree" if not ascii_only
               else "work-compass — unified work-landscape N-Tree")
    out.append("─" * 70)
    meta = graph["meta"]
    out.append(f"items: {meta['count']}  domains: {meta['domains_present']}/{len(DOMAINS)}"
               f"  candidates: {meta['candidate_count']}  scope: {meta['scope']}")
    for diag in meta.get("unavailable", []):
        out.append(f"  ⚠ {diag}" if not ascii_only else f"  [!] {diag}")
    out.append("─" * 70)
    grouped = graph["by_domain"]
    for domain in DOMAINS:
        bucket = grouped.get(domain, [])
        if not bucket:
            continue
        out.append(f"{domain}/  ({len(bucket)})")
        for i, it in enumerate(bucket):
            last = "└─" if i == len(bucket) - 1 else "├─"
            g = _glyph(it["status"], ascii_only)
            flags = (" · " + ",".join(it["flags"])) if it["flags"] else ""
            title = it["title"][:48]
            out.append(f"  {last} {g} {it['id']}  {title}{flags}")
    out.append("─" * 70)
    if meta["candidate_count"]:
        out.append(f"stale/orphan/pending candidates: {meta['candidate_count']}"
                   " — run with --route <id> for a suggested command (review-before-submit)")
    return "\n".join(out) + "\n"


def render_mermaid(graph: dict) -> str:
    out = ["flowchart TD", "  root([work-compass])"]
    for domain in DOMAINS:
        bucket = graph["by_domain"].get(domain, [])
        if not bucket:
            continue
        dnode = f"d_{domain.replace('-', '_')}"
        out.append(f"  root --> {dnode}[{domain}]")
        for it in bucket:
            nid = "n_" + re.sub(r"[^a-zA-Z0-9]", "_", it["id"])
            label = re.sub(r'["\[\]]', "", it["title"][:32]) or it["id"]
            tag = "⚠" if it["flags"] else ""
            out.append(f'  {dnode} --> {nid}["{tag}{label}"]')
    return "\n".join(out) + "\n"


# ── compass scope filter (CPT §9.5 verbs) ───────────────────────────────────────
VALID_SCOPES = {"current", "down", "sideways", "up", "forward"}


def apply_scope(items: list[dict], scope: str, node_id: str | None) -> list[dict]:
    if scope not in VALID_SCOPES:
        sys.stderr.write(f"[--scope] invalid verb '{scope}' → fallback current\n")
        scope = "current"
    if scope == "current" or not node_id:
        return items
    sel = next((it for it in items if it["id"] == node_id), None)
    if sel is None:
        return items
    if scope == "down":   # children: items referencing this node's branch/id
        b = sel["refs"].get("branch") or sel["refs"].get("name") or ""
        return [it for it in items
                if it["refs"].get("branch") == b or _refs_point_to(it, sel["id"])]
    if scope == "sideways":  # siblings: same domain
        return [it for it in items if it["domain"] == sel["domain"]]
    if scope == "up":     # parent: the branch/worktree/ticket this node hangs off
        b = sel["refs"].get("branch", "")
        return [it for it in items
                if it["refs"].get("name") == b or it["refs"].get("branch") == b]
    if scope == "forward":  # next: flagged candidates only (the work queue)
        return [it for it in items if it["flags"]]
    return items


def _refs_point_to(it: dict, target_id: str) -> bool:
    for v in it.get("refs", {}).values():
        if isinstance(v, list) and target_id in v:
            return True
        if isinstance(v, str) and v and v in target_id:
            return True
    return False


# ── graph assembly ───────────────────────────────────────────────────────────────
def build_graph(items: list[dict], scope: str, node_id: str | None,
                unavailable: list[str]) -> dict:
    items = apply_scope(items, scope, node_id)
    by_domain: dict[str, list[dict]] = {d: [] for d in DOMAINS}
    for it in sorted(items, key=lambda x: x["id"]):  # deterministic order
        by_domain.setdefault(it["domain"], []).append(it)
    candidate_count = sum(1 for it in items if it["flags"])
    domains_present = sum(1 for d in DOMAINS if by_domain.get(d))
    return {
        "meta": {
            "count": len(items),
            "candidate_count": candidate_count,
            "domains_present": domains_present,
            "scope": scope,
            "unavailable": unavailable,
            "generated_utc": now_utc().isoformat(),
        },
        "by_domain": by_domain,
        "items": sorted(items, key=lambda x: x["id"]),
    }


# ── main ─────────────────────────────────────────────────────────────────────────
# collector registry — add a surface = ONE entry here (drives --no-<name> flags too).
COLLECTORS = ["sessions", "git", "github", "jira", "stashes", "plans", "jobs", "codex"]


def aggregate(args) -> tuple[list[dict], list[str]]:
    """Fan-out every enabled collector in fixed (deterministic) order."""
    registry = {
        "sessions": lambda: collect_sessions(args.inventory),
        "git":      lambda: collect_worktrees_and_branches(args.repo_dir),
        "github":   lambda: collect_github(args.repo),
        "jira":     lambda: collect_jira(),
        "stashes":  lambda: collect_stashes(args.repo_dir),
        "plans":    lambda: collect_plans(),
        "jobs":     lambda: collect_bg_jobs(),
        "codex":    lambda: collect_codex_sessions(),
    }
    items: list[dict] = []
    unavailable: list[str] = []
    for name in COLLECTORS:
        if getattr(args, f"no_{name}", False):
            continue
        got, diag = registry[name]()
        items += got
        if diag:
            unavailable.append(diag)
    return items, unavailable


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="work-compass cross-domain aggregator")
    ap.add_argument("--json", action="store_true", help="emit the work-item graph as JSON")
    ap.add_argument("--format", choices=["ascii", "mermaid"], default="ascii")
    ap.add_argument("--ascii-only", action="store_true", help="no-emoji ASCII glyphs")
    ap.add_argument("--scope", default="current",
                    help="Compass verb: current|down|sideways|up|forward")
    ap.add_argument("--node", default=None, help="anchor node id for scoped traversal")
    ap.add_argument("--stale-days", type=int, default=DEFAULT_STALE_DAYS)
    ap.add_argument("--repo", default=None, help="GitHub owner/name (else inferred)")
    ap.add_argument("--repo-dir", default=os.getcwd(), help="git repo dir for worktrees/branches")
    ap.add_argument("--inventory", default=None, help="reserved: pre-generated inventory path")
    for _name in COLLECTORS:  # registry-driven skip flags (--no-<collector>)
        ap.add_argument(f"--no-{_name}", action="store_true", help=f"skip the {_name} collector")
    ap.add_argument("--detect-only", action="store_true",
                    help="print only the flagged candidates")
    ap.add_argument("--route", default=None, help="node id to route (prints suggested command)")
    ap.add_argument("--action", default=None,
                    help="route action: open|recap|delegate|pause|stop|delete")
    args = ap.parse_args(argv)

    items, unavailable = aggregate(args)
    detect(items, args.stale_days)

    # delegation-router path (read-only: prints a command, never executes)
    if args.route:
        node = next((it for it in items if it["id"] == args.route), None)
        if node is None:
            print(json.dumps({"error": f"node not found: {args.route}"}), file=sys.stderr)
            return 1
        print(json.dumps(route(node, args.action), ensure_ascii=False, indent=2))
        return 0

    graph = build_graph(items, args.scope, args.node, unavailable)

    if args.detect_only:
        cands = [it for it in graph["items"] if it["flags"]]
        print(json.dumps({"candidates": cands, "count": len(cands)},
                         ensure_ascii=False, indent=2))
        return 0
    if args.json:
        print(json.dumps(graph, ensure_ascii=False, indent=2))
        return 0
    if args.format == "mermaid":
        sys.stdout.write(render_mermaid(graph))
        return 0
    sys.stdout.write(render_ascii(graph, ascii_only=args.ascii_only))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
