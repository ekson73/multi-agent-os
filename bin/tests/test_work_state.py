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
    # LF only (as the tool frames lines): splitlines() would also split on U+2028/U+0085 inside a JSON string
    return [json.loads(x) for x in p.read_text().split("\n") if x.strip()] if p.exists() else []


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


def _claimed(d, item="r1", owner="agent-a", inc="1", key=None):
    ws(d, "append", "--item", item, "--event", "enqueued", "--idempotency-key", f"e-{item}-{owner}")
    return ws(d, "claim", "--item", item, "--owner", owner, "--incarnation", inc,
              "--lease-sec", "600", "--idempotency-key", key or f"c-{item}-{owner}-{inc}")


def _expire(d, item, owner, inc, key):
    return ws(d, "append", "--item", item, "--event", "heartbeat", "--lease-sec", "-5",
              "--owner", owner, "--incarnation", inc, "--idempotency-key", key)


def _status(d, item):
    return json.loads(ws(d, "state", "--item", item).stdout)["status"]


def test_reserved_events_and_derived_status():
    with tempfile.TemporaryDirectory() as d:
        _claimed(d)
        n = len(lines(d))
        for ev in ("claimed", "dead-lettered"):
            r = ws(d, "append", "--item", "r1", "--event", ev, "--owner", "x", "--incarnation", "9",
                   "--idempotency-key", f"res-{ev}")
            check(f"append: {ev!r} is reserved to claim (exit 2)", r.returncode == 2, r.stderr)
        r = ws(d, "append", "--item", "r1", "--event", "bogus", "--owner", "x", "--incarnation", "9",
               "--lease-sec", "600", "--idempotency-key", "bogus")
        check("append: unknown event refused (cannot smuggle owner/lease fields)", r.returncode == 2, r.stderr)
        r = ws(d, "append", "--item", "r1", "--event", "heartbeat", "--status", "queued",
               "--owner", "agent-a", "--incarnation", "1", "--idempotency-key", "st")
        check("append: a --status that differs from the derived one is refused (exit 2)", r.returncode == 2, r.stderr)
        check("append: rejected events are never written", len(lines(d)) == n)
        check("state: still running/attempts=1 after the rejected attempts",
              json.loads(ws(d, "state", "--item", "r1").stdout)["attempts"] == 1 and _status(d, "r1") == "running")
        b = ws(d, "claim", "--item", "r1", "--owner", "agent-b", "--incarnation", "1",
               "--lease-sec", "600", "--idempotency-key", "cb")
        check("claim: the lease still binds after the bypass attempts (exit 5)", b.returncode == 5, b.stderr)
        r = ws(d, "append", "--item", "r1", "--event", "heartbeat", "--status", "running",
               "--owner", "agent-a", "--incarnation", "1", "--idempotency-key", "st2")
        check("append: --status that merely repeats the derived status is accepted", r.returncode == 0, r.stderr)


def test_terminal_items_cannot_be_reopened():
    with tempfile.TemporaryDirectory() as d:
        _claimed(d, "t1")
        ws(d, "append", "--item", "t1", "--event", "done", "--owner", "agent-a", "--incarnation", "1",
           "--terminal-marker", '{"kind":"completed"}', "--idempotency-key", "dn")
        n = len(lines(d))
        for ev, extra in (("enqueued", []), ("heartbeat", ["--owner", "agent-a", "--incarnation", "1"]),
                          ("released", ["--owner", "agent-a", "--incarnation", "1"])):
            r = ws(d, "append", "--item", "t1", "--event", ev, *extra, "--idempotency-key", f"re-{ev}")
            check(f"append: {ev} on a done item is refused (exit 3)", r.returncode == 3, r.stderr)
        check("append: done item log unchanged", len(lines(d)) == n)
        check("state: still done", _status(d, "t1") == "done")


def test_non_cyclic_flows_are_preserved():
    with tempfile.TemporaryDirectory() as d:
        ws(d, "append", "--item", "n1", "--event", "enqueued", "--idempotency-key", "e1")
        r = ws(d, "append", "--item", "n1", "--event", "heartbeat", "--idempotency-key", "h1")
        check("flow: heartbeat on a never-claimed item is accepted", r.returncode == 0, r.stderr)
        r = ws(d, "append", "--item", "n1", "--event", "released", "--idempotency-key", "r1")
        check("flow: released on a queued item is accepted", r.returncode == 0, r.stderr)
        r = ws(d, "append", "--item", "n1", "--event", "failed", "--idempotency-key", "f1")
        check("flow: failed without a claim is accepted", r.returncode == 0 and _status(d, "n1") == "failed", r.stderr)
        r = ws(d, "append", "--item", "n1", "--event", "enqueued", "--idempotency-key", "e2")
        check("flow: re-enqueue of a non-running, non-terminal item is accepted",
              r.returncode == 0 and _status(d, "n1") == "queued", r.stderr)
        c = ws(d, "claim", "--item", "n1", "--owner", "a", "--incarnation", "1", "--lease-sec", "600",
               "--idempotency-key", "c1")
        check("flow: claim after a failed/re-enqueued item works", c.returncode == 0, c.stderr)
        ws(d, "append", "--item", "n2", "--event", "enqueued", "--idempotency-key", "e3")
        r = ws(d, "append", "--item", "n2", "--event", "done", "--idempotency-key", "d3")
        check("flow: done WITHOUT a prior claim is accepted", r.returncode == 0 and _status(d, "n2") == "done", r.stderr)
        r = ws(d, "append", "--item", "never-enqueued", "--event", "done", "--idempotency-key", "d4")
        check("flow: `done` on an unknown item creates it directly (accepted before the contract; kept)",
              r.returncode == 0 and _status(d, "never-enqueued") == "done", r.stderr)
        r = ws(d, "append", "--item", "never-enqueued-2", "--event", "heartbeat", "--idempotency-key", "h5")
        check("flow: any append event may create an unknown item (no mandatory `enqueued` step)",
              r.returncode == 0 and _status(d, "never-enqueued-2") == "queued", r.stderr)
        r = ws(d, "claim", "--item", "never-seen", "--owner", "a", "--incarnation", "1", "--lease-sec", "60",
               "--idempotency-key", "c6")
        check("flow: `claim` still refuses an unknown item (exit 2)", r.returncode == 2, r.stderr)


def test_stale_or_foreign_owner_cannot_touch_lease():
    with tempfile.TemporaryDirectory() as d:
        _claimed(d, "o1", "agent-a", "1")
        for ev in ("heartbeat", "released", "failed", "done", "enqueued"):
            r = ws(d, "append", "--item", "o1", "--event", ev, "--owner", "agent-x", "--incarnation", "1",
                   "--idempotency-key", f"f-{ev}")
            check(f"owner: foreign {ev} while the lease is live refused (exit 5)", r.returncode == 5, r.stderr)
        r = ws(d, "append", "--item", "o1", "--event", "heartbeat", "--idempotency-key", "noid")
        check("owner: heartbeat without the claim identity refused on a running item (exit 5)",
              r.returncode == 5, r.stderr)
        _expire(d, "o1", "agent-a", "1", "x1")
        check("claim: B takes the expired lease", ws(d, "claim", "--item", "o1", "--owner", "agent-b",
              "--incarnation", "1", "--lease-sec", "600", "--idempotency-key", "cb").returncode == 0)
        n = len(lines(d))
        for ev in ("heartbeat", "released", "done"):
            extra = ["--lease-sec", "600"] if ev == "heartbeat" else []
            r = ws(d, "append", "--item", "o1", "--event", ev, "--owner", "agent-a", "--incarnation", "1",
                   *extra, "--idempotency-key", f"s-{ev}")
            check(f"owner: stale agent-a {ev} refused (exit 5)", r.returncode == 5, r.stderr)
        check("owner: nothing written by the stale incarnation", len(lines(d)) == n)
        st = json.loads(ws(d, "state", "--item", "o1").stdout)
        check("owner: record of ownership intact", st["owner"] == "agent-b" and st["status"] == "running")
        # same owner, older incarnation (own item keeps the 2-launch budget out of the picture)
        _claimed(d, "o2", "agent-a", "1")
        _expire(d, "o2", "agent-a", "1", "x2")
        check("claim: same owner, newer incarnation takes over", ws(d, "claim", "--item", "o2",
              "--owner", "agent-a", "--incarnation", "2", "--lease-sec", "600",
              "--idempotency-key", "cb2").returncode == 0)
        r = ws(d, "append", "--item", "o2", "--event", "heartbeat", "--owner", "agent-a", "--incarnation", "1",
               "--lease-sec", "600", "--idempotency-key", "oldinc")
        check("owner: older incarnation of the same owner refused (exit 5)", r.returncode == 5, r.stderr)


def test_expired_lease_semantics():
    with tempfile.TemporaryDirectory() as d:
        _claimed(d, "x1", "agent-a", "1")
        _expire(d, "x1", "agent-a", "1", "e")
        for ev in ("heartbeat", "done"):
            r = ws(d, "append", "--item", "x1", "--event", ev, "--owner", "agent-x", "--incarnation", "1",
                   "--idempotency-key", f"fx-{ev}")
            check(f"expired: foreign {ev} cannot move ownership without a claim (exit 5)", r.returncode == 5, r.stderr)
        r = ws(d, "append", "--item", "x1", "--event", "failed", "--owner", "supervisor", "--incarnation", "0",
               "--idempotency-key", "reap")
        check("expired: any caller may reap an expired lease with `failed`",
              r.returncode == 0 and _status(d, "x1") == "failed", r.stderr)
        c = ws(d, "claim", "--item", "x1", "--owner", "agent-b", "--incarnation", "1", "--lease-sec", "600",
               "--idempotency-key", "cb")
        check("expired: the reaped item is claimable again", c.returncode == 0, c.stderr)
        _claimed(d, "x2", "agent-a", "1")
        _expire(d, "x2", "agent-a", "1", "e2")
        r = ws(d, "append", "--item", "x2", "--event", "done", "--owner", "agent-a", "--incarnation", "1",
               "--idempotency-key", "late")
        check("expired: the owner of record may still complete late (exit 0)", r.returncode == 0, r.stderr)
        # same identity re-claiming is NOT forbidden by the contract
        _claimed(d, "x3", "agent-a", "1")
        _expire(d, "x3", "agent-a", "1", "e3")
        r = ws(d, "claim", "--item", "x3", "--owner", "agent-a", "--incarnation", "1", "--lease-sec", "600",
               "--idempotency-key", "same-id")
        check("claim: re-claim by the same identity after expiry stays allowed", r.returncode == 0, r.stderr)


def test_claim_checks_lease_before_budget():
    with tempfile.TemporaryDirectory() as d:
        _claimed(d, "b1", "agent-a", "1")
        _expire(d, "b1", "agent-a", "1", "xa")
        ws(d, "claim", "--item", "b1", "--owner", "agent-b", "--incarnation", "1", "--lease-sec", "600",
           "--idempotency-key", "cb")                      # attempt 2, live lease
        n = len(lines(d))
        r = ws(d, "claim", "--item", "b1", "--owner", "agent-c", "--incarnation", "1", "--lease-sec", "600",
               "--idempotency-key", "cc")
        check("claim: live lease + exhausted budget refuses with 5, not dead-letter", r.returncode == 5, r.stderr)
        check("claim: the live-lease refusal writes nothing", len(lines(d)) == n)
        check("claim: item stays running", _status(d, "b1") == "running")
        _expire(d, "b1", "agent-b", "1", "xb")
        r = ws(d, "claim", "--item", "b1", "--owner", "agent-c", "--incarnation", "1", "--lease-sec", "600",
               "--idempotency-key", "cc2")
        check("claim: after expiry the exhausted budget dead-letters (exit 4)", r.returncode == 4, r.stderr)
        a = ws(d, "append", "--item", "b1", "--event", "claimed", "--idempotency-key", "hand")
        check("append: cannot hand-write a claim", a.returncode == 2, a.stderr)


def test_lease_out_of_range_is_a_clean_rejection():
    with tempfile.TemporaryDirectory() as d:
        ws(d, "append", "--item", "v1", "--event", "enqueued", "--idempotency-key", "e")
        n = len(lines(d))
        r = ws(d, "claim", "--item", "v1", "--owner", "a", "--incarnation", "1",
               "--lease-sec", "999999999999999", "--idempotency-key", "big")
        check("claim: absurd --lease-sec is rejected with exit 2 (no traceback)",
              r.returncode == 2 and "Traceback" not in r.stderr, r.stderr)
        r = ws(d, "append", "--item", "v1", "--event", "heartbeat", "--lease-sec", "-999999999999999",
               "--idempotency-key", "bigneg")
        check("append: absurd negative --lease-sec is rejected with exit 2",
              r.returncode == 2 and "Traceback" not in r.stderr, r.stderr)
        check("lease range: nothing written", len(lines(d)) == n)


def test_structurally_invalid_log_is_refused_before_any_append():
    bad_logs = {
        "only-seq": b'{"seq":1}\n',
        "non-object": b'[1,2]\n',
        "missing-event": b'{"v":1,"seq":1,"t":"2026-01-01T00:00:00+00:00","item":"i"}\n',
        "seq-not-increasing": (b'{"v":1,"seq":2,"t":"2026-01-01T00:00:00+00:00","item":"i","event":"enqueued"}\n'
                               b'{"v":1,"seq":2,"t":"2026-01-01T00:00:01+00:00","item":"i","event":"heartbeat"}\n'),
        "unparseable-lease": (b'{"v":1,"seq":1,"t":"2026-01-01T00:00:00+00:00","item":"i","event":"claimed",'
                              b'"owner":"a","incarnation":1,"lease_until":"never"}\n'),
        "torn-line": b'{"v":1,"seq":1,"t":"2026-01-01T00:00:00+00:00","item":"i","ev',
    }
    for name, content in bad_logs.items():
        with tempfile.TemporaryDirectory() as d:
            log = Path(d) / "events.jsonl"
            log.write_bytes(content)
            for cmd in (["append", "--item", "i", "--event", "enqueued", "--idempotency-key", "k"],
                        ["claim", "--item", "i", "--owner", "a", "--incarnation", "1", "--lease-sec", "60",
                         "--idempotency-key", "kc"],
                        ["state"]):
                r = ws(d, *cmd)
                check(f"invalid log [{name}]: `{cmd[0]}` fails closed (non-zero, no traceback)",
                      r.returncode != 0 and "Traceback" not in r.stderr, r.stderr)
                check(f"invalid log [{name}]: `{cmd[0]}` leaves the log byte-identical",
                      log.read_bytes() == content)


def _load_tool():
    import importlib.machinery
    import importlib.util
    loader = importlib.machinery.SourceFileLoader("work_state_mod", str(TOOL))
    spec = importlib.util.spec_from_loader("work_state_mod", loader)
    mod = importlib.util.module_from_spec(spec)
    loader.exec_module(mod)
    return mod


def test_short_and_failed_writes_stay_append_only_and_honest():
    import errno
    import io
    from contextlib import redirect_stdout
    mod = _load_tool()
    real_write, real_fsync = os.write, os.fsync
    prev = os.environ.get("WORK_STATE_DIR")

    def attempt(item, key):
        try:
            with redirect_stdout(io.StringIO()):
                mod.main(["append", "--item", item, "--event", "enqueued", "--idempotency-key", key])
            return 0, ""
        except SystemExit as e:
            return (e.code if e.code else 0), str(e.code)

    with tempfile.TemporaryDirectory() as d:
        os.environ["WORK_STATE_DIR"] = d
        log = Path(d) / "events.jsonl"
        try:
            check("write: baseline append ok", attempt("w", "k0")[0] == 0)

            os.write = lambda fd, data: real_write(fd, bytes(data)[:7])  # short writes: 7 bytes at a time
            try:
                rc, _ = attempt("w2", "k1")
            finally:
                os.write = real_write
            got = lines(d)
            check("write: short writes are completed (full valid line recorded)",
                  rc == 0 and got[-1]["item"] == "w2" and len(got) == 2)

            before = log.read_bytes()
            calls = {"n": 0}

            def partial_then_fail(fd, data):
                calls["n"] += 1
                if calls["n"] == 1:
                    return real_write(fd, bytes(data)[:5])
                raise OSError(errno.ENOSPC, "no space left")
            os.write = partial_then_fail
            try:
                rc, msg = attempt("w3", "k2")
            finally:
                os.write = real_write
            after = log.read_bytes()
            check("write: an error after a partial write is a non-zero failure", rc not in (0, None), msg)
            check("write: NO truncation — the 5 partial bytes stay as evidence (append-only)",
                  len(after) == len(before) + 5 and after.startswith(before))
            check("write: the message admits a partial line and does not claim 'not recorded'",
                  "PARTIAL" in msg and "not recorded" not in msg.lower().replace("is not in the log", ""), msg)
            r = ws(d, "append", "--item", "w4", "--event", "enqueued", "--idempotency-key", "k3")
            check("write: the next command refuses the torn log (fail-closed)", r.returncode != 0, r.stderr)
            check("write: ...and leaves the evidence byte-identical", log.read_bytes() == after)

            log.write_bytes(before)  # restore a clean log for the remaining cases
            os.write = lambda fd, data: 0                       # accepts nothing: must not loop forever
            try:
                rc, msg = attempt("w5", "k4")
            finally:
                os.write = real_write
            check("write: a 0-byte write fails closed (non-zero)", rc not in (0, None), msg)
            check("write: zero bytes written -> log byte-identical and the message says so",
                  log.read_bytes() == before and "no bytes were written" in msg, msg)

            def bad_fsync(fd):
                raise OSError(errno.EIO, "fsync failed")
            os.fsync = bad_fsync
            try:
                rc, msg = attempt("w6", "k5")
            finally:
                os.fsync = real_fsync
            check("write: fsync failure is an error, and does not claim the event is absent",
                  rc not in (0, None) and "may be recorded" in msg and len(lines(d)) == 3, msg)
        finally:
            os.write, os.fsync = real_write, real_fsync
            if prev is None:
                os.environ.pop("WORK_STATE_DIR", None)
            else:
                os.environ["WORK_STATE_DIR"] = prev


def test_log_without_final_newline_is_refused():
    import errno
    import io
    from contextlib import redirect_stdout
    mod = _load_tool()
    real_write = os.write
    prev = os.environ.get("WORK_STATE_DIR")

    with tempfile.TemporaryDirectory() as d:
        os.environ["WORK_STATE_DIR"] = d
        log = Path(d) / "events.jsonl"
        try:
            with redirect_stdout(io.StringIO()):
                mod.main(["append", "--item", "a", "--event", "enqueued", "--idempotency-key", "k0"])
            good = log.read_bytes()
            calls = {"n": 0}

            def fail_exactly_before_lf(fd, data):  # every byte but the final LF, then ENOSPC
                calls["n"] += 1
                if calls["n"] == 1:
                    return real_write(fd, bytes(data)[:-1])
                raise OSError(errno.ENOSPC, "no space left")
            os.write = fail_exactly_before_lf
            try:
                try:
                    with redirect_stdout(io.StringIO()):
                        mod.main(["append", "--item", "b", "--event", "enqueued", "--idempotency-key", "k1"])
                    rc, msg = 0, ""
                except SystemExit as e:
                    rc, msg = (e.code if e.code else 0), str(e.code)
            finally:
                os.write = real_write
            torn = log.read_bytes()
            check("LF: the write that died just before the LF fails honestly (non-zero, PARTIAL)",
                  rc not in (0, None) and "PARTIAL" in msg, msg)
            check("LF: the file now holds a COMPLETE json object with no final LF (the dangerous shape)",
                  torn.startswith(good) and not torn.endswith(b"\n") and json.loads(torn[len(good):])["item"] == "b")
        finally:
            os.write = real_write
            if prev is None:
                os.environ.pop("WORK_STATE_DIR", None)
            else:
                os.environ["WORK_STATE_DIR"] = prev

        # same torn log, and a hand-written complete line without LF: every command refuses, bytes untouched
        shapes = {"died-before-LF": torn,
                  "hand-written-no-LF": good + good.rstrip(b"\n").replace(b'"seq":1', b'"seq":2')}
        for name, content in shapes.items():
            log.write_bytes(content)
            for cmd in (["append", "--item", "c", "--event", "enqueued", "--idempotency-key", "k9"],
                        ["append", "--item", "b", "--event", "enqueued", "--idempotency-key", "k1"],  # key already in the torn line
                        ["claim", "--item", "a", "--owner", "x", "--incarnation", "1", "--lease-sec", "60",
                         "--idempotency-key", "kc"],
                        ["state"], ["manifest"]):
                r = ws(d, *cmd)
                check(f"LF [{name}]: `{cmd[0]}` fails closed (non-zero, no traceback, no 'noop')",
                      r.returncode != 0 and "Traceback" not in r.stderr and "noop" not in r.stdout, r.stderr)
                check(f"LF [{name}]: `{cmd[0]}` leaves the log byte-identical", log.read_bytes() == content)
        log.write_bytes(good)
        r = ws(d, "append", "--item", "c", "--event", "enqueued", "--idempotency-key", "k9")
        check("LF: with the LF restored the log is usable again", r.returncode == 0 and len(lines(d)) == 2, r.stderr)

    with tempfile.TemporaryDirectory() as d:  # LF-only framing: U+2028/U+0085 inside a note must not split a line
        note = "a\u2028b\x85c"
        r = ws(d, "append", "--item", "u", "--event", "enqueued", "--note", note, "--idempotency-key", "n1")
        check("LF: a note with U+2028/U+0085 is accepted", r.returncode == 0, r.stderr)
        r = ws(d, "append", "--item", "u", "--event", "heartbeat", "--idempotency-key", "n2")
        check("LF: ...and the log stays readable by the next command (one event per LF line)",
              r.returncode == 0 and len(lines(d)) == 2 and json.loads(ws(d, "state", "--item", "u").stdout)["note"] == note,
              r.stderr)


def test_outgoing_event_is_validated_before_the_log_is_opened():
    with tempfile.TemporaryDirectory() as d:
        log = Path(d) / "events.jsonl"
        r = ws(d, "append", "--item", "", "--event", "enqueued", "--idempotency-key", "e0")
        check("outgoing: an empty --item is rejected with exit 2 (no traceback)",
              r.returncode == 2 and "Traceback" not in r.stderr and "schema" in r.stderr, r.stderr)
        check("outgoing: on a fresh dir the rejected event does not even create the log", not log.exists())
        ws(d, "append", "--item", "ok", "--event", "enqueued", "--idempotency-key", "e1")
        before = log.read_bytes()
        for args in (["--item", "", "--event", "enqueued"], ["--item", "", "--event", "done"],
                     ["--item", "", "--event", "heartbeat", "--lease-sec", "60"]):
            r = ws(d, "append", *args, "--idempotency-key", "e2")
            check(f"outgoing: {args[3]} with an empty item is rejected (exit 2)", r.returncode == 2, r.stderr)
        check("outgoing: the existing log is byte-identical after the rejections", log.read_bytes() == before)
        r = ws(d, "state")
        check("outgoing: ...and still readable (the rejected event was never written)",
              r.returncode == 0 and list(json.loads(r.stdout)) == ["ok"], r.stderr)


def test_all():  # pytest-visible: a failing check must fail the run (unlike the legacy runner)
    for fn in (test_idempotent_append, test_concurrent_writers, test_claim_lease_and_attempts,
               test_terminal_marker_blocks_claim, test_manifest_is_sanitized,
               test_default_dir_is_outside_any_git_checkout,
               test_reserved_events_and_derived_status, test_terminal_items_cannot_be_reopened,
               test_non_cyclic_flows_are_preserved, test_stale_or_foreign_owner_cannot_touch_lease,
               test_expired_lease_semantics, test_claim_checks_lease_before_budget,
               test_lease_out_of_range_is_a_clean_rejection,
               test_structurally_invalid_log_is_refused_before_any_append,
               test_short_and_failed_writes_stay_append_only_and_honest,
               test_log_without_final_newline_is_refused,
               test_outgoing_event_is_validated_before_the_log_is_opened):
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
