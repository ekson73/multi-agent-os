#!/usr/bin/env python3
"""D3-4 trace-miner: locate failure/deviation/retry/operator-correction windows per skill.

Streams session JSONL from ~/.claude/projects and ~/.pi/agent/sessions.
Signals detected (heuristic):
  A) tool_result is_error within +/-6 lines of a skill mention
  B) user message within 8 lines AFTER an errored tool_result near a skill mention (correction)
  C) skill mentioned in >=2 assistant tool-call/read invocations in same file (re-invocation)
Output: JSON per skill -> list of {file, mtime, line, signal} + text preview to stdout (NOT persisted).
"""
import json
import os
import re
import subprocess
import sys

SKILLS = ["morning-briefing", "quiesce", "agentic-tool-forge", "directive-braindump-triage",
          "postflight", "praxis-audit", "ooda-loop", "preflight"]
ROOTS = [os.path.expanduser("~/.claude/projects"), os.path.expanduser("~/.pi/agent/sessions")]


def find_files(skill):
    files = []
    for root in ROOTS:
        try:
            out = subprocess.run(
                ["rg", "-l", "--fixed-strings", "-g", "*.jsonl", skill, root],
                capture_output=True, text=True, timeout=120).stdout
            files += [l for l in out.splitlines() if l.strip()]
        except Exception:
            pass
    return files


def line_text(obj):
    """Flatten visible text of a JSONL record."""
    try:
        m = obj.get("message", obj)
        c = m.get("content")
        if isinstance(c, str):
            return c
        if isinstance(c, list):
            parts = []
            for b in c:
                if isinstance(b, dict):
                    parts.append(str(b.get("text") or b.get("input") or b.get("content") or "")[:400])
            return " ".join(parts)
    except Exception:
        pass
    return ""


def is_error_record(obj):
    m = obj.get("message", obj)
    c = m.get("content")
    if isinstance(c, list):
        for b in c:
            if isinstance(b, dict) and (b.get("is_error") is True or b.get("type") == "tool_error"):
                return True
    t = obj.get("type", "")
    return "error" in str(t).lower()


def role_of(obj):
    m = obj.get("message", obj)
    return m.get("role") or obj.get("type", "")


def mine(skill, path):
    hits = {"A_error_near": [], "B_user_after_error": [], "C_reinvocation": 0, "mentions": 0}
    try:
        stat = os.stat(path)
    except OSError:
        return None
    mention_lines, error_lines, user_lines, invoke_lines = [], [], [], []
    with open(path, encoding="utf-8", errors="replace") as f:
        for i, raw in enumerate(f, 1):
            if skill not in raw:
                # still track errors/users for proximity even if line lacks skill
                if '"is_error":true' in raw or '"is_error": true' in raw or "tool_error" in raw:
                    error_lines.append(i)
                continue
            try:
                obj = json.loads(raw)
            except Exception:
                continue
            txt = line_text(obj)
            role = role_of(obj)
            mention_lines.append((i, role, txt[:160]))
            hits["mentions"] += 1
            if is_error_record(obj):
                error_lines.append(i)
            if role == "user":
                user_lines.append(i)
            if role in ("assistant",) and ("tool_use" in raw or "toolCall" in raw or '"name":"Skill"' in raw or "SKILL.md" in raw):
                invoke_lines.append(i)
    if not mention_lines:
        return None
    ml = {i for i, _, _ in mention_lines}
    for e in error_lines:
        if any(abs(e - m) <= 6 for m in ml):
            hits["A_error_near"].append(e)
        nxt = [u for u in user_lines if 0 < u - e <= 8]
        if nxt and any(abs(nxt[0] - m) <= 30 for m in ml):
            hits["B_user_after_error"].append((e, nxt[0]))
    hits["C_reinvocation"] = len(set(invoke_lines))
    return {
        "file": path,
        "mtime": stat.st_mtime,
        "mentions": hits["mentions"],
        "A_error_near": hits["A_error_near"][:5],
        "B_user_after_error": hits["B_user_after_error"][:5],
        "C_invocations": hits["C_reinvocation"],
        "samples": [{"line": i, "role": r, "preview": re.sub(r"\s+", " ", t)[:140]} for i, r, t in mention_lines[:3]],
    }


def main():
    out = {}
    for skill in SKILLS:
        files = find_files(skill)
        res = []
        for p in files:
            r = mine(skill, p)
            if r and (r["A_error_near"] or r["B_user_after_error"] or r["C_invocations"] >= 2):
                res.append(r)
        res.sort(key=lambda r: -(len(r["A_error_near"]) + len(r["B_user_after_error"]) * 2 + (1 if r["C_invocations"] >= 2 else 0)))
        out[skill] = {"files_with_skill": len(files), "candidates": res[:6]}
    print(json.dumps(out, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
