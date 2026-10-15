#!/usr/bin/env python3
"""
test_work_state.py — stdlib-only tests for bin/work-state (durable work-item state).

Cases come from the Phase-2 impact matrix (item 1, plan section 9): idempotent re-append,
concurrent writers, lease expiry without terminal marker, and the <=2 launches budget.

Run: python3 bin/tests/test_work_state.py      (or: python3 -m pytest bin/tests/test_work_state.py)
"""
from __future__ import annotations

import json
import os
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

TOOL = Path(__file__).resolve().parent.parent / "work-state"
FAILS: list[str] = []


def check(name: str, cond: bool, detail: str = "") -> None:
    print(f"  {'PASS' if cond else 'FAIL'}  {name}" + ("" if cond else f"  {detail}"))
    if not cond:
        FAILS.append(name)


def ws(state_dir: str, *args: str) -> subprocess.CompletedProcess:
    env = {**os.environ, "WORK_STATE_DIR": state_dir}
    return subprocess.run([sys.executable, str(TOOL), *args], env=env,
                          capture_output=True, text=True, timeout=60)


def lines(state_dir: str) -> list[dict]:
    p = Path(state_dir) / "events.jsonl"
    return [json.loads(x) for x in p.read_text().splitlines()] if p.exists() else []


def test_idempotent_append():
    with tempfile.TemporaryDirectory() as d:
        a = ws(d, "append", "--item", "t1", "--event", "enqueued", "--idempotency-key", "k1")
        b = ws(d, "append", "--item", "t1", "--event", "enqueued", "--idempotency-key", "k1")
        check("append: first write exits 0", a.returncode == 0, a.stderr)
        check("append: same idempotency_key again is a no-op (exit 0)", b.returncode == 0, b.stderr)
        check("append: exactly one line for the repeated key", len(lines(d)) == 1)
        check("append: no-op is reported, not silent", "noop" in b.stdout.lower())


def test_concurrent_writers():
    with tempfile.TemporaryDirectory() as d:
        with ThreadPoolExecutor(max_workers=12) as ex:
            res = list(ex.map(lambda i: ws(d, "append", "--item", f"c{i}", "--event", "enqueued",
                                           "--idempotency-key", f"u{i}"), range(12)))
        check("concurrent: all 12 writers exit 0", all(r.returncode == 0 for r in res))
        got = lines(d)  # json.loads on every line proves no partial/torn line
        check("concurrent: 12 complete lines, none torn", len(got) == 12)
        check("concurrent: seq is unique and gap-free",
              sorted(x["seq"] for x in got) == list(range(1, 13)))
        with ThreadPoolExecutor(max_workers=6) as ex:
            list(ex.map(lambda _: ws(d, "append", "--item", "same", "--event", "enqueued",
                                     "--idempotency-key", "dup"), range(6)))
        check("concurrent: 6 racing writers with ONE key leave exactly one line",
              sum(1 for x in lines(d) if x.get("idempotency_key") == "dup") == 1)


def test_claim_lease_and_attempts():
    with tempfile.TemporaryDirectory() as d:
        ws(d, "append", "--item", "w1", "--event", "enqueued", "--idempotency-key", "e1")
        c1 = ws(d, "claim", "--item", "w1", "--owner", "agent-a", "--incarnation", "1",
                "--lease-sec", "600", "--idempotency-key", "c1")
        check("claim: first launch granted", c1.returncode == 0, c1.stderr)
        busy = ws(d, "claim", "--item", "w1", "--owner", "agent-b", "--incarnation", "1",
                  "--lease-sec", "600", "--idempotency-key", "c1b")
        check("claim: live lease refuses a second claim (exit 5)", busy.returncode == 5, busy.stderr)
        st = json.loads(ws(d, "state", "--item", "w1").stdout)
        check("state: owner/incarnation/lease recorded", st["owner"] == "agent-a"
              and st["incarnation"] == 1 and st["lease_until"] and st["attempts"] == 1)

        # lease expires without a terminal marker -> eligible again, attempts preserved
        ws(d, "append", "--item", "w1", "--event", "heartbeat", "--lease-sec", "-5",
           "--owner", "agent-a", "--incarnation", "1", "--idempotency-key", "expire")
        c2 = ws(d, "claim", "--item", "w1", "--owner", "agent-b", "--incarnation", "1",
                "--lease-sec", "600", "--idempotency-key", "c2")
        check("claim: expired lease without terminal marker is re-claimable", c2.returncode == 0, c2.stderr)
        check("claim: attempts preserved and incremented (=2)",
              json.loads(ws(d, "state", "--item", "w1").stdout)["attempts"] == 2)

        # 3rd launch refused -> dead-letter
        ws(d, "append", "--item", "w1", "--event", "heartbeat", "--lease-sec", "-5",
           "--owner", "agent-b", "--incarnation", "1", "--idempotency-key", "expire2")
        c3 = ws(d, "claim", "--item", "w1", "--owner", "agent-c", "--incarnation", "1",
                "--lease-sec", "600", "--idempotency-key", "c3")
        check("claim: 3rd launch is refused (exit 4)", c3.returncode == 4, c3.stderr)
        check("claim: item moves to dead-letter",
              json.loads(ws(d, "state", "--item", "w1").stdout)["status"] == "dead-letter")
        again = ws(d, "claim", "--item", "w1", "--owner", "agent-d", "--incarnation", "1",
                   "--lease-sec", "600", "--idempotency-key", "c4")
        check("claim: dead-letter is terminal (still refused)", again.returncode == 4, again.stderr)


def test_terminal_marker_blocks_claim():
    with tempfile.TemporaryDirectory() as d:
        ws(d, "append", "--item", "x1", "--event", "enqueued", "--idempotency-key", "e")
        ws(d, "claim", "--item", "x1", "--owner", "a", "--incarnation", "1", "--lease-sec", "600",
           "--idempotency-key", "c")
        ws(d, "append", "--item", "x1", "--event", "done", "--status", "done", "--owner", "a",
           "--incarnation", "1", "--terminal-marker", '{"kind":"completed"}', "--idempotency-key", "d")
        r = ws(d, "claim", "--item", "x1", "--owner", "b", "--incarnation", "1", "--lease-sec", "600",
               "--idempotency-key", "c2")
        check("terminal: a completed item cannot be re-claimed (exit 3)", r.returncode == 3, r.stderr)


def test_manifest_is_sanitized():
    with tempfile.TemporaryDirectory() as d:
        ws(d, "append", "--item", "m1", "--event", "enqueued", "--idempotency-key", "e",
           "--owner", "/Users/alice/secret-run", "--note", "token ghp_" + "B" * 30)
        raw = (Path(d) / "events.jsonl").read_text()
        man = ws(d, "manifest").stdout
        check("manifest: valid JSON", bool(json.loads(man)))
        check("manifest: absolute user path collapsed", "alice" not in man)
        check("manifest: secret-shaped token masked", "B" * 30 not in man and "[redacted]" in man)
        check("manifest: raw log stays raw/local (not rewritten)", "alice" in raw)


def test_default_dir_is_outside_any_git_checkout():
    env = {k: v for k, v in os.environ.items() if k != "WORK_STATE_DIR"}
    r = subprocess.run([sys.executable, str(TOOL), "path"], env=env, capture_output=True,
                       text=True, timeout=60)
    path = Path(r.stdout.strip() or "/nonexistent").resolve() if r.returncode == 0 else None
    check("path: default location resolves", path is not None, r.stderr)
    if path is not None:
        g = subprocess.run(["git", "-C", str(path.parent if not path.exists() else path),
                            "rev-parse", "--is-inside-work-tree"], capture_output=True, text=True)
        check("path: default log dir is not inside a git work tree (raw log stays local)",
              g.returncode != 0 or g.stdout.strip() != "true")


def test_all():  # pytest-visible: a failing check must fail the run (unlike the legacy runner)
    for fn in (test_idempotent_append, test_concurrent_writers, test_claim_lease_and_attempts,
               test_terminal_marker_blocks_claim, test_manifest_is_sanitized,
               test_default_dir_is_outside_any_git_checkout):
        print(f"\n[{fn.__name__}]")
        fn()
    assert not FAILS, f"failed checks: {FAILS}"


if __name__ == "__main__":
    try:
        test_all()
    except AssertionError as e:
        print(f"\nRESULT: FAILED — {e}")
        raise SystemExit(1)
    print("\nRESULT: all checks passed")
