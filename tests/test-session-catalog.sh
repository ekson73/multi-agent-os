#!/usr/bin/env bash
# Test: skills/session-catalog/scripts/session_catalog.py — read-only multi-harness session catalog.
# Every fixture is GENERATED at runtime under a fresh temp dir: invented text that only mimics each
# store's on-disk format. No real session store, transcript or credential is ever read or written.
# Secret-shaped canaries are recognizably fake and assembled from fragments at runtime, so this file
# holds no scanner-matching literal (and no gitleaks allowlist/baseline entry is needed).
# The reader refuses any output under a temp root, and this tree lives under one, so most runs go through
# a generated launcher that exempts ONLY the temp roots containing the fixture tree; the temp-root policy
# itself is also exercised against the unmodified script (see §3).
# Exit 0 = all pass; 1 = a failure.
set -euo pipefail
HERE="$(cd "$(dirname "$0")/.." && pwd)"
export SC="$HERE/skills/session-catalog/scripts/session_catalog.py"
FIX="$(mktemp -d 2>/dev/null || mktemp -d -t sessioncatalog)"
[ -n "$FIX" ] && [ -d "$FIX" ] || { echo "test-session-catalog: mktemp failed" >&2; exit 1; }
export FIX
trap 'chmod -R u+rwx "$FIX" 2>/dev/null; rm -rf "$FIX"' EXIT
echo "test-session-catalog:"
python3 - <<'PY'
import builtins, hashlib, io, json, math, os, re, shutil, stat, subprocess, sys, threading, time, zipfile

sys.dont_write_bytecode = True  # importing the reader must leave no __pycache__ in the skill dir

SC, FIX = os.environ["SC"], os.environ["FIX"]
HOME = os.path.join(FIX, "home")
OLD = time.time() - 3 * 86400          # fixture mtime: older than the default 24 h past-session horizon
fails = []


def ok(cond, name):
    print(("  ok   " if cond else "  FAIL ") + name)
    if not cond:
        fails.append(name)


def put(rel, lines=None, raw=None, mtime=OLD, home=HOME):
    p = os.path.join(home, rel)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    with open(p, "wb") as fh:
        fh.write(raw if raw is not None else ("\n".join(json.dumps(x) for x in lines) + "\n").encode())
    os.utime(p, (mtime, mtime))
    return p


ENV = dict(os.environ, HOME=HOME, XDG_DATA_HOME=os.path.join(FIX, "xdg-data"),
           XDG_CONFIG_HOME=os.path.join(FIX, "xdg-config"), XDG_STATE_HOME=os.path.join(FIX, "xdg-state"),
           SC_FIXTURE_ROOT=FIX)


def fixture_temp_roots(real):
    """The reader refuses any output under a temp root, but this synthetic tree itself lives under
    the OS temp root. Test harness only: drop the temp roots that CONTAIN the tree; every other
    temp root (e.g. a synthetic $TMPDIR inside it) still applies. The reader has no such switch."""
    fx = {os.path.abspath(FIX), os.path.realpath(FIX)}
    return lambda: {t for t in real() if not any(f == t or f.startswith(t.rstrip(os.sep) + os.sep) for f in fx)}


LAUNCHER = os.path.join(FIX, "run_catalog.py")  # runs the real CLI with only fixture_temp_roots applied
with open(LAUNCHER, "w") as fh:
    fh.write("import importlib.util, os, sys\n"
             "sys.dont_write_bytecode = True\n"
             "spec = importlib.util.spec_from_file_location('session_catalog', sys.argv[1])\n"
             "mod = importlib.util.module_from_spec(spec)\n"
             "spec.loader.exec_module(mod)\n"
             "fx = {os.path.abspath(os.environ['SC_FIXTURE_ROOT']), os.path.realpath(os.environ['SC_FIXTURE_ROOT'])}\n"
             "real = mod.temp_roots\n"
             "mod.temp_roots = lambda: {t for t in real() if not any(f == t or f.startswith(t.rstrip(os.sep) + os.sep)"
             " for f in fx)}\n"
             "sys.argv = sys.argv[1:]\n"
             "mod.cli()\n")


def run(*args, home=HOME, env=None, real=False):
    """`real=True` runs the unmodified script; otherwise the LAUNCHER (fixture temp exemption only)."""
    cmd = [sys.executable, SC] if real else [sys.executable, LAUNCHER, SC]
    r = subprocess.run(cmd + ["--home", home] + list(args), capture_output=True, text=True,
                       env=dict(ENV, **(env or {})))
    last = r.stderr.strip().splitlines()[-1] if r.stderr.strip() else "{}"
    try:
        receipt = json.loads(last)
    except ValueError:
        receipt = {}
    return r.returncode, r.stdout, r.stderr, receipt


def jl(path):
    with open(path) as fh:
        return [json.loads(l) for l in fh if l.strip()]


def zip_of(path, members):
    with zipfile.ZipFile(path, "w") as z:
        for name, data in members:
            z.writestr(name, data)
    return path


# secret-shaped canaries: fake by construction, assembled at runtime (never literal in this file)
GH = "gh" + "p_" + "Ab1Cd2Ef3Gh4Ij5Kl6Mn7Op8Qr9St0Uv1Wx2"
AWS = "AK" + "IA" + "ABCDEFGHIJKLMNOP"
PEM = "-----BEGIN " + "RSA PRIVATE KEY-----\nMIIBOgIBAAJBAKj34GkxFhD90vcNLYLInFEX\n6Ppy1tPf9Cnzj4p4WGeKLs1Pt8Qu\n-----END " + "RSA PRIVATE KEY-----"
BLOB = "QmFzZTY0QmxvYlRoYXRMb29rc1NlY3JldA" + "Zm9yVGVzdGluZ09ubHkxMjM0NTY3ODk"
PW = "hunter" + "2hunter2"
MAIL = "someone" + "@" + "example.org"
GH_SPLIT = "gh" + "p_" + "Zz9Yy8Xx7Ww6Vv5Uu4Tt3Ss2Rr1Qq0Pp9Oo8"     # split across two text fields
AWS_SPLIT = "AK" + "IA" + "ZYXWVUTSRQPONMLK"                          # split across two messages
QPW = "correct " + "horse battery staple"                             # quoted secret with spaces
GH_TYPE = "gh" + "p_" + "Type0Type1Type2Type3Type4Type5Type6"         # token-shaped record type
GH_TOOL = "gh" + "p_" + "Tool0Tool1Tool2Tool3Tool4Tool5Tool6"         # token-shaped tool name
MARK = {"thinking": "HIDDEN-THOUGHT-7Q", "skill": "SKILLBODY-7Q", "args": "TOOLARG-7Q", "envelope": "ENVELOPE-7Q",
        "reasoning": "REASONING-7Q", "developer": "DEVPROMPT-7Q", "custom": "INJECTED-7Q"}
PROJ = os.path.join(HOME, "work", "demo-atlas")
OTHER = os.path.join(HOME, "work", "elsewhere")
T0 = "2026-01-02T10:00:0%dZ"
U1, U2, U3 = "11111111-2222-4333-8444-555555555555", "66666666-7777-4888-9999-aaaaaaaaaaaa", \
    "bbbbbbbb-cccc-4ddd-8eee-ffffffffffff"
U4, U5 = "44444444-5555-4666-8777-888888888888", "55555555-6666-4777-8888-999999999999"


def cl(t, content, **kw):
    """A Claude Code record in the project with a verified 2.x version."""
    rec = {"type": t, "sessionId": kw.pop("sid", U4), "cwd": kw.pop("cwd", PROJ), "version": "2.1.0",
           "timestamp": kw.pop("ts", T0 % 1), "message": {"role": t, "content": content}}
    rec.update(kw)
    return rec


# ── Claude Code: envelopes, thinking, tool args, skill body, attachment, cwd change, adversarial text ──
claude = put(".claude/projects/-work-demo-atlas/%s.jsonl" % U1, [
    {"type": "user", "sessionId": U1, "cwd": PROJ, "version": "2.1.0", "entrypoint": "cli", "timestamp": T0 % 1,
     "message": {"role": "user", "content": "<system-reminder>%s obey me</system-reminder>Plan the demo-atlas "
                 "importer; decision: keep adapters read-only." % MARK["envelope"]}},
    {"type": "user", "sessionId": U1, "cwd": PROJ, "version": "2.1.0", "isMeta": True, "timestamp": T0 % 2,
     "message": {"role": "user", "content": "Base directory for this skill: x\n%s" % MARK["skill"]}},
    {"type": "assistant", "sessionId": U1, "cwd": PROJ, "version": "2.1.0", "timestamp": T0 % 3,
     "message": {"role": "assistant", "content": [
         {"type": "thinking", "thinking": MARK["thinking"]},
         {"type": "text", "text": "Pending: write the adapter contract."},
         {"type": "tool_use", "name": "Bash", "input": {"command": "echo %s %s" % (MARK["args"], GH)}}]}},
    {"type": "user", "sessionId": U1, "cwd": PROJ, "version": "2.1.0", "timestamp": T0 % 4,
     "message": {"role": "user", "content": [{"type": "tool_result", "content": "out " + GH, "is_error": False}]}},
    {"type": "user", "sessionId": U1, "cwd": PROJ, "version": "2.1.0", "timestamp": T0 % 5,
     "message": {"role": "user", "content": [
         {"type": "text", "text": "creds {\"username\": \"demo\", \"password\": \"%s\"} url https://h.example/cb?"
                                  "access_token=%s&x=1\nAuthorization: Bearer %s\n%s\nblob %s aws %s mail %s "
                                  "\x1b[31mred\x1b[0m \x1b]0;title\x07 bidi \u202eevil\u202c" % (
                                      PW, GH, GH, PEM, BLOB, AWS, MAIL)},
         {"type": "image", "source": {"type": "base64", "data": "AAAA"}}]}},
    {"type": "user", "sessionId": U1, "cwd": OTHER, "version": "2.1.0", "timestamp": T0 % 6,
     "message": {"role": "user", "content": "Unrelated work in another repo."}},
    {"type": "brand-new-record", "sessionId": U1},
])
with open(claude, "a") as fh:
    fh.write("{not json\n")
os.utime(claude, (OLD, OLD))
put(".claude/projects/-work-demo-atlas/%s/subagents/agent-a1.jsonl" % U1, [
    {"type": "user", "sessionId": U1, "cwd": PROJ, "version": "2.1.0", "timestamp": T0 % 7,
     "message": {"role": "user", "content": "Subagent brief about demo-atlas."}}])
put(".claude/projects/-work-demo-atlas/%s.jsonl-wal" % U2, raw=b"ignored")
put(".claude/projects/-work-demo-atlas/%s.jsonl" % U2, raw=b"\x00\x01\x02" * 400)            # binary
put(".claude/projects/-work-big/%s.jsonl" % U3, raw=(json.dumps(
    {"type": "user", "sessionId": U3, "version": "2.1.0", "message": {"content": "x" * 9000}}) + "\n").encode())
outside = os.path.join(FIX, "outside.jsonl")
with open(outside, "w") as fh:
    fh.write(json.dumps({"type": "user", "sessionId": "zz", "version": "2.1.0", "message": {"content": "escaped"}}) + "\n")
os.makedirs(os.path.join(HOME, ".claude/projects/-link"), exist_ok=True)
os.symlink(outside, os.path.join(HOME, ".claude/projects/-link/%s.jsonl" % "cccccccc-cccc-4ccc-8ccc-cccccccccccc"))
os.symlink(os.path.dirname(outside), os.path.join(HOME, ".claude/projects/-dirlink"))

# review regressions (Claude): split-field / split-message secrets, quoted secret, hostile type and tool
# name, a record without a version, and a transcript modified inside the past-session horizon
put(".claude/projects/-work-demo-atlas/%s.jsonl" % U4, [
    cl("user", [{"type": "text", "text": "demo-atlas split canary " + GH_SPLIT[:16]},
                {"type": "text", "text": GH_SPLIT[16:] + " tail"}]),
    cl("assistant", [{"type": "text", "text": "demo-atlas key part " + AWS_SPLIT[:10]},
                     {"type": "text", "text": AWS_SPLIT[10:] + " done"},
                     {"type": "tool_use", "name": GH_TOOL, "input": {}}], ts=T0 % 2),
    cl("user", "demo-atlas config password=\"%s\"" % QPW, ts=T0 % 3),
    {"type": GH_TYPE, "sessionId": U4},
    {"type": "user", "sessionId": U4, "cwd": PROJ, "timestamp": T0 % 4,
     "message": {"role": "user", "content": "demo-atlas NOVERSION-7Q"}},
])
put(".claude/projects/-work-demo-atlas/%s.jsonl" % U5, [cl("user", "demo-atlas RECENT-7Q", sid=U5)],
    mtime=time.time() - 120)
# the past-session contract, pinned: another process holds this OLD transcript open (idle writer). Open
# handles are not inspected, so it is read up to its last complete record; the torn tail is quarantined.
U6 = "77777777-8888-4999-8aaa-bbbbbbbbbbbb"
open_writer = put(".claude/projects/-work-demo-atlas/%s.jsonl" % U6, raw=(
    json.dumps(cl("user", "demo-atlas OPENWRITER-7Q", sid=U6)) + "\n"
    + '{"type": "user", "sessionId": "%s", "version": "2.1.0", "message": {"content": "demo-atlas TRUNCATED-7Q' % U6).encode())
writer = subprocess.Popen([sys.executable, "-c", "import sys; f = open(sys.argv[1], 'ab'); print('open', flush=True); "
                           "sys.stdin.read()", open_writer], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
assert writer.stdout.readline().strip() == b"open"

# ── Codex rollouts: developer prompt, reasoning, per-turn cwd, imported duplicate, missing version ──
R1, R2, R3 = ("aaaaaaaa-0000-4000-8000-00000000000%d" % i for i in (1, 2, 3))
for rid, prompt, ver in ((R1, "Codex: demo-atlas decision to stream JSONL.", "0.146.0"),
                         (R2, "Imported copy of a Claude session.", "0.146.0"),
                         (R3, "demo-atlas CODEXNOVER-7Q", None)):
    meta = {"id": rid, "cwd": OTHER, "originator": "codex-tui"}
    if ver:
        meta["cli_version"] = ver
    put(".codex/sessions/2026/01/02/rollout-2026-01-02T10-00-00-%s.jsonl" % rid, [
        {"type": "session_meta", "timestamp": T0 % 1, "payload": meta},
        {"type": "turn_context", "timestamp": T0 % 2, "payload": {"cwd": PROJ}},
        {"type": "response_item", "timestamp": T0 % 2, "payload": {"type": "message", "role": "developer",
                                                                   "content": [{"type": "input_text", "text": MARK["developer"]}]}},
        {"type": "response_item", "timestamp": T0 % 3, "payload": {"type": "message", "role": "user",
                                                                   "content": [{"type": "input_text", "text": "<environment_context>%s</environment_context>" % MARK["envelope"]},
                                                                               {"type": "input_text", "text": prompt}]}},
        {"type": "response_item", "timestamp": T0 % 4, "payload": {"type": "reasoning", "summary": [{"text": MARK["reasoning"]}]}},
        {"type": "response_item", "timestamp": T0 % 5, "payload": {"type": "function_call", "name": "shell",
                                                                   "arguments": json.dumps({"cmd": MARK["args"]})}},
        {"type": "response_item", "timestamp": T0 % 6, "payload": {"type": "function_call_output", "output": GH}},
        {"type": "event_msg", "timestamp": T0 % 6, "payload": {"type": "agent_message", "message": "dup"}},
    ])
put(".codex/external_agent_session_imports.json",
    raw=json.dumps({"records": [{"imported_thread_id": R2, "source_path": "/x/.claude/projects/p/s.jsonl"}]}).encode())

# ── pi-format (omp + prime-agent): custom_message injection, thinking, version gate ──
PI = [{"type": "session", "version": 3, "id": "pi-1", "cwd": PROJ, "timestamp": T0 % 1},
      {"type": "custom_message", "customType": "skill", "content": MARK["custom"], "timestamp": T0 % 2},
      {"type": "message", "timestamp": T0 % 3, "message": {"role": "user", "content": [{"type": "text", "text": "omp: demo-atlas task list"}]}},
      {"type": "message", "timestamp": T0 % 4, "message": {"role": "assistant", "content": [
          {"type": "thinking", "thinking": MARK["thinking"]}, {"type": "text", "text": "Noted the task list."},
          {"type": "toolCall", "name": "bash", "arguments": {"cmd": MARK["args"]}}]}},
      {"type": "message", "timestamp": T0 % 5, "message": {"role": "toolResult", "isError": True, "content": [{"type": "text", "text": GH}]}}]
put(".omp/agent/sessions/-work-demo-atlas/2026-01-03T10-00-00-000Z_0001.jsonl", PI)
put(".omp/agent/sessions/-work-demo-atlas/2026-01-03T11-00-00-000Z_0002.jsonl", [dict(PI[0], version=2)] + PI[1:])
put(".prime/agent/sessions/prime-0001.jsonl", [dict(PI[0], id="prime-1")] + PI[1:])

# ── Gemini CLI (json + jsonl), Antigravity CLI history, Antigravity brain artifact ──
put(".gemini/tmp/demo/.project_root", raw=PROJ.encode())
put(".gemini/tmp/demo/chats/session-a.json", raw=json.dumps({"sessionId": "g-1", "messages": [
    {"id": "1", "type": "user", "timestamp": T0 % 1, "content": "gemini: demo-atlas question"},
    {"id": "2", "type": "gemini", "timestamp": T0 % 2, "content": "answer", "toolCalls": [{"name": "read_file", "args": {"p": MARK["args"]}}]},
    {"id": "3", "type": "info", "timestamp": T0 % 3, "content": "info line"},
    {"id": "4", "type": "user", "timestamp": T0 % 4,
     "content": "demo-atlas config: password=${DB_PASS} and Authorization: Bearer <your-token-here>"}]}).encode())
put(".gemini/tmp/demo/chats/session-b.jsonl", [
    {"sessionId": "g-2", "projectHash": "h", "startTime": T0 % 1, "lastUpdated": T0 % 2, "kind": "main"},
    {"$set": {"lastUpdated": T0 % 2, "messages": [{"id": "1", "type": "user", "timestamp": T0 % 2, "content": [{"text": "gemini jsonl demo-atlas"}]}]}}])
put(".gemini/antigravity-cli/history.jsonl", [
    {"conversationId": "agy-1", "display": "agy: demo-atlas prompt", "timestamp": 1767348000000, "workspace": "file://" + PROJ},
    {"conversationId": "agy-1", "display": "/help", "type": "slash_command", "timestamp": 1767348001000, "workspace": "file://" + PROJ}])
put(".gemini/antigravity/brain/c0ffee00-0000-4000-8000-000000000000/task.md", raw=b"# Task\n- [ ] demo-atlas adapter\n")
put(".gemini/antigravity/brain/c0ffee00-0000-4000-8000-000000000000/task.md.metadata.json",
    raw=json.dumps({"updatedAt": T0 % 9}).encode())
put(".gemini/antigravity-backup/brain/c0ffee00-0000-4000-8000-000000000000/task.md", raw=b"# backup copy\n")
# live file: modified after the high-water mark → deferred, never read
put(".omp/agent/sessions/-work-demo-atlas/2026-01-04T10-00-00-000Z_0003.jsonl", PI, mtime=time.time() + 3600)

# ── ChatGPT exports: a valid zip and a hostile zip ──
conv = [{"id": "cg-1", "title": "t", "current_node": "b", "mapping": {
    "a": {"message": {"author": {"role": "user"}, "create_time": 1767348000, "content": {"content_type": "text", "parts": ["chatgpt: demo-atlas idea"]}}, "parent": None},
    "b": {"message": {"author": {"role": "assistant"}, "create_time": 1767348001, "content": {"content_type": "text", "parts": ["reply"]},
                      "metadata": {"attachments": [{"name": "secret-name.pdf", "mimeType": "application/pdf"}]}}, "parent": "a"}}}]
good_zip = zip_of(os.path.join(FIX, "export.zip"), [("conversations.json", json.dumps(conv))])
bad_zip = zip_of(os.path.join(FIX, "hostile.zip"), [("../evil.json", "{}"), ("conversations.json", json.dumps(conv))])


def tree_hash(root, skip="catalog-out"):
    """Content + mtime of every source file (the test's own nested output root excluded)."""
    h = hashlib.sha256()
    for d, dirs, fs in os.walk(root):
        dirs[:] = sorted(x for x in dirs if x != skip)
        for f in sorted(fs):
            p = os.path.join(d, f)
            if os.path.islink(p):
                continue
            with open(p, "rb") as fh:
                h.update(p.encode() + fh.read() + str(os.stat(p).st_mtime_ns).encode())
    return h.hexdigest()


def fixture_version():
    doc = open(os.path.join(os.path.dirname(os.path.dirname(SC)), "SKILL.md")).read()
    return re.search(r"^version: (\S+)$", doc, re.M).group(1)


before = tree_hash(HOME)
OUT = os.path.join(FIX, "private-out")

# 1. bare invocation = metadata-only dry run, writes nothing
code, out, err, _ = run()
ok(code == 0 and "dry run" in out, "bare invocation is a metadata-only dry run (exit 0)")
ok(not os.path.exists(OUT), "dry run writes no output")
ok("claude-code/projects" in out and "supported" in out, "stores lists a supported Claude Code store")

# 2. usage errors: extract needs --out and a scope; limits must be positive; the git override is gone
ok(run("extract", "--project", PROJ)[0] == 2, "extract without --out exits 2 (usage)")
ok(run("--out", OUT, "extract")[0] == 2, "extract without --project/--mention exits 2 (usage)")
ok(run("--out", OUT, "index")[0] == 2, "index without --project/--mention exits 2 (usage): no unscoped inventory")
for flag, val in (("--max-record-bytes", "-2"), ("--max-records", "0"), ("--max-files", "-1"), ("--max-file-bytes", "0")):
    code, _, _, rc = run("--out", OUT, flag, val, "index", "--project", PROJ)
    ok(code == 2 and rc.get("status") == "usage", "non-positive %s %s is refused (exit 2, usage)" % (flag, val))
ok(run("--out", os.path.join(FIX, "x"), "--allow-git-output", "index", "--project", PROJ)[0] == 2,
   "the --allow-git-output override no longer exists (exit 2)")
ok(not os.path.exists(OUT), "refused runs wrote nothing")

# 3. output policy: canonical ancestors, temp roots, the findings path
repo = os.path.join(FIX, "repo")
os.makedirs(os.path.join(repo, ".git"))
os.makedirs(os.path.join(repo, "nested"))
code, _, err, rc = run("--out", os.path.join(repo, "out"), "index", "--project", PROJ)
ok(code == 5 and rc.get("status") == "blocked", "output inside a git work tree is refused (exit 5, blocked)")
alias = os.path.join(FIX, "alias")
os.symlink(os.path.join(repo, "nested"), alias)
code, _, _, rc = run("--out", os.path.join(alias, "catalog"), "index", "--project", PROJ)
ok(code == 5 and not os.path.exists(os.path.join(repo, "nested", "catalog")),
   "an ancestor symlink aliasing into a git work tree is refused and nothing is written there")
tmproot = os.path.join(FIX, "tmproot")
os.makedirs(tmproot)
code, _, _, rc = run("--out", tmproot, "index", "--project", PROJ, env={"TMPDIR": tmproot})
ok(code == 5 and os.listdir(tmproot) == [], "output directly in the temporary root is refused")
tmp2 = os.path.join(FIX, "tmproot2")
os.makedirs(tmp2)
child = os.path.join(tmp2, "private-child")
code, _, _, rc = run("--out", child, "index", "--project", PROJ, env={"TMPDIR": tmp2})
ok(code == 5 and rc.get("status") == "blocked" and not os.path.exists(child),
   "an output root BELOW a (synthetic) $TMPDIR is refused and nothing is written")
code, _, _, rc = run("--out", os.path.join(FIX, "out-f3"), "--security-findings", os.path.join(tmp2, "f.jsonl"),
                     "index", "--project", PROJ, env={"TMPDIR": tmp2})
ok(code == 5 and not os.path.exists(os.path.join(tmp2, "f.jsonl")), "a --security-findings file below a temp root is refused")
for base in ((os.environ.get("TMPDIR") or "/tmp"), "/tmp"):  # the unmodified CLI, against the real temp roots
    probe = os.path.join(base, "session-catalog-refusal-%d" % os.getpid())
    code, _, _, rc = run("--out", os.path.join(probe, "catalog"), "index", "--project", PROJ, real=True)
    ok(code == 5 and rc.get("status") == "blocked" and not os.path.exists(probe),
       "unmodified CLI: an output root below the real %s is refused and nothing is written" % base.rstrip("/"))
code, _, _, rc = run("--out", os.path.join(FIX, "out-f1"), "--security-findings", os.path.join(alias, "f.jsonl"),
                     "index", "--project", PROJ)
ok(code == 5 and not os.path.exists(os.path.join(repo, "nested", "f.jsonl")),
   "a --security-findings path resolving into a git work tree is refused")
home_findings = os.path.join(HOME, "findings.jsonl")
code, _, _, rc = run("--out", os.path.join(FIX, "out-f2"), "--security-findings", home_findings, "index", "--project", PROJ)
mf2 = json.load(open(os.path.join(FIX, "out-f2", "run-manifest.json")))
ok(code == 3 and os.path.isfile(home_findings) and stat.S_IMODE(os.stat(home_findings).st_mode) == 0o600
   and mf2["receipt"]["claude-code/projects"]["status"] == "supported",
   "findings under the scanned home exclude only that file, not the whole home (0600)")
os.unlink(home_findings)
# an output or findings path must never land on an input (it would be rename-replaced)
def digest(p):
    return hashlib.sha256(open(p, "rb").read()).hexdigest()


zip_before, claude_before = digest(good_zip), digest(claude)
code, _, _, _ = run("--out", os.path.join(FIX, "out-f4"), "--export", "chatgpt=" + good_zip,
                    "--security-findings", good_zip, "index", "--project", PROJ)
ok(code == 5 and digest(good_zip) == zip_before, "--security-findings naming a supplied export is refused, export intact")
code, _, _, _ = run("--out", os.path.join(FIX, "out-f5"), "--security-findings", claude, "index", "--project", PROJ)
ok(code == 5 and digest(claude) == claude_before, "--security-findings naming a store transcript is refused, source intact")
prime_root = os.path.join(HOME, ".prime/agent/sessions")
prime_before = tree_hash(prime_root)
code, _, _, _ = run("--out", prime_root, "index", "--project", PROJ)
ok(code == 5 and tree_hash(prime_root) == prime_before, "an output root equal to a store root is refused, store intact")
exp_dir = os.path.join(FIX, "exp-dir")
os.makedirs(exp_dir)
exp_inside = zip_of(os.path.join(exp_dir, "export.zip"), [("conversations.json", json.dumps(conv))])
exp_before = digest(exp_inside)
code, _, _, _ = run("--out", exp_dir, "--export", "chatgpt=" + exp_inside, "index", "--project", PROJ)
ok(code == 5 and digest(exp_inside) == exp_before and os.listdir(exp_dir) == ["export.zip"],
   "an output root containing a supplied export is refused, nothing written")
foreign = os.path.join(FIX, "foreign-out")
os.makedirs(foreign)
with open(os.path.join(foreign, "sessions.jsonl"), "w") as fh:
    fh.write("not ours\n")
code, _, _, _ = run("--out", foreign, "index", "--project", PROJ)
ok(code == 5 and open(os.path.join(foreign, "sessions.jsonl")).read() == "not ours\n",
   "an unmarked output root holding a file named like an output is refused, file intact")

# 4. pass 1 index
code, out, err, rc = run("--out", OUT, "--max-record-bytes", "4096", "--export", "chatgpt=" + good_zip,
                         "index", "--project", PROJ, "--mention", "demo-atlas")
ok(code == 3 and rc.get("status") == "partial", "run with quarantine/skipped stores exits 3 and reports partial")
man = json.load(open(os.path.join(OUT, "run-manifest.json")))
rows = jl(os.path.join(OUT, "sessions.jsonl"))
q = jl(os.path.join(OUT, "quarantine.jsonl"))
surfaces = {r["surface"] for r in rows}
for sfc in ("anthropic.claude-code", "openai.codex-cli", "omp.cli", "primeintellect.prime-agent", "google.gemini-cli",
            "google.antigravity-cli", "google.antigravity", "openai.chatgpt-export"):
    ok(sfc in surfaces, "adapter normalizes %s" % sfc)
reasons = {x["reason"] for x in q}
for rsn in ("binary-content", "record-over-size-cap", "malformed-json", "unverified-format-version"):
    ok(rsn in reasons, "quarantined: %s" % rsn)
ok("unknown-record-type" in reasons and all(x.get("type_ref", "t-").startswith("t-") for x in q),
   "unknown record type is quarantined as a fixed class + opaque digest")
rcp = man["receipt"]["claude-code/projects"]
ok(rcp.get("symlinks_refused", 0) >= 2, "file and directory symlinks inside a root are never followed")
ok(man["receipt"]["omp/sessions"].get("files_deferred_recent_or_unstable", 0) >= 1, "file newer than high-water is deferred")
ok(rcp.get("files_deferred_recent_or_unstable", 0) >= 1, "a transcript modified inside the 24 h horizon is deferred")
ok(man["high_water"] <= time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(time.time() - 23 * 3600))
   and "open file handles are NOT inspected" in man["past_session_contract"],
   "default high-water sits 24 h back and the receipt states the past-session contract")
ok(man["receipt"]["codex/sessions"].get("sessions_skipped_imported_duplicate", 0) == 1, "imported duplicate skipped")
ok(any(s["store"] == "antigravity-backup" for s in man["stores_skipped"]), "backup copy is not traversed")
ok("do not claim" in man["claim"], "manifest refuses to claim 'all sessions' when stores were skipped")
ok(all("session_id_private" in r and r["session_ref"].startswith("s-") for r in rows), "rows carry opaque session refs")
ok(any(r["attachments_by_type"].get("image") for r in rows), "attachments counted by type only")
tool = man.get("tool", {})
ok(tool.get("version") == fixture_version() and tool.get("schema") == "session-catalog/v1" == man["schema"],
   "receipt records the tool version (== SKILL.md) and schema")
git_info = tool.get("git")
ok(git_info is None or (re.fullmatch(r"[0-9a-f]{40,64}", git_info["commit"]) and isinstance(git_info["dirty"], bool)
                        and git_info["reproducible"] == (not git_info["dirty"])),
   "receipt records commit + dirty state when run from a git checkout (%s)" % ("git" if git_info else "no git"))
ok(rc.get("version") == fixture_version() and rc.get("schema") == "session-catalog/v1", "stderr receipt carries version/schema")
blob = open(os.path.join(OUT, "sessions.jsonl")).read() + open(os.path.join(OUT, "quarantine.jsonl")).read()
ok("secret-name.pdf" not in blob and GH not in blob, "index holds no attachment names or secrets")
ok(GH_TYPE not in blob, "a token-shaped record type never reaches quarantine metadata")
mode = lambda p: stat.S_IMODE(os.stat(p).st_mode)  # noqa: E731
ok(mode(OUT) == 0o700 and all(mode(os.path.join(OUT, f)) == 0o600 for f in os.listdir(OUT)
                              if os.path.isfile(os.path.join(OUT, f))), "private outputs are 0700/0600")
findings = jl(os.path.join(OUT, "security-findings.jsonl"))
kinds = {f["finding_type"] for f in findings}
ok({"github-token", "private-key", "aws-key"} <= kinds and all("rotation" in f["recommendation"] for f in findings),
   "credential findings recorded by type, rotation recommended")
ok(GH not in open(os.path.join(OUT, "security-findings.jsonl")).read(), "findings never hold the value")
ok(not any(f["store"] == "gemini-cli/tmp" for f in findings), "placeholders are redacted but not reported as findings")

# 5. pass 2 extract (stdout only) — sanitization + scoping
code, out, err, rc = run("--out", OUT, "--max-record-bytes", "4096", "--export", "chatgpt=" + good_zip,
                         "extract", "--project", PROJ, "--mention", "demo-atlas")
msgs = [json.loads(l) for l in out.splitlines()]
text = "\n".join(m["text"] for m in msgs)
ok(code == 3 and msgs, "extract streams messages and exits partial")
for label, needle in MARK.items():
    ok(needle not in out, "extract excludes %s" % label)
for label, secret in (("github token", GH), ("aws key", AWS), ("password", PW), ("blob", BLOB), ("email", MAIL),
                      ("pem body", "MIIBOgIBAAJBAKj34"), ("quoted secret with spaces", QPW)):
    ok(secret not in out and secret not in err, "redacted %s (stdout+stderr)" % label)
for label, frag in (("head of a token split across fields", GH_SPLIT[:16]), ("tail of it", GH_SPLIT[16:]),
                    ("head of a key split across messages", AWS_SPLIT[:10]), ("tail of it", AWS_SPLIT[10:])):
    ok(frag not in out and frag not in err, "redacted %s" % label)
ok("split canary [REDACTED:github-token]" in text, "the split token is masked where it starts")
ok(GH_TOOL not in out and any((m["tool"] or "").startswith("tool-") for m in msgs),
   "a token-shaped tool name is replaced by an opaque digest")
ok("NOVERSION-7Q" not in out and "CODEXNOVER-7Q" not in out, "Claude/Codex records without a version are not emitted")
ok("RECENT-7Q" not in out, "a transcript modified within the horizon is not a past session: not emitted")
src6 = [k for k, v in man["sources_private"].items() if v.endswith(U6 + ".jsonl")]
ok("OPENWRITER-7Q" in text and "TRUNCATED-7Q" not in out
   and any(x["source_id"] in src6 and x["reason"] == "malformed-json" and x["line"] == 2 for x in q),
   "contract pinned: a transcript an idle writer still holds open is read up to its last complete record; "
   "the truncated tail is quarantined")
ok("[REDACTED:auth-header]" in text and "access_token=[REDACTED:secret]" in text, "auth header and URL param redacted")
ok("\x1b" not in out and "\u202e" not in out, "ANSI/OSC and bidi controls stripped")
ok("Unrelated work in another repo." not in text, "messages written from another cwd are excluded")
ok("Plan the demo-atlas importer" in text, "in-project user prose survives")
roles = {m["role"] for m in msgs}
ok("tool_call" in roles and "assistant" in roles and "user" in roles, "roles stay distinct (tool_call separate)")
ok(all(m["text"] == "" for m in msgs if m["role"] == "tool_call"), "tool calls carry no arguments")
ok(all(m["provenance"].startswith("observed in ") for m in msgs), "every item is labelled as an observation")
ok(not any(f.startswith("messages") for f in os.listdir(OUT)), "extract persists no message text")

# 5b. defense in depth: a gitleaks-style generic-api-key scan finds nothing in any output
GL = re.compile(r"""(?i)[\w.-]{0,50}?(?:access|auth|(?-i:[Aa]pi|API)|credential|creds|key|passw(?:or)?d|secret|token)"""
                r"""(?:[ \t\w.-]{0,20})[\s'"]{0,3}(?:=|>|:{1,3}=|\|\||:|=>|\?=|,)[\x60'"\s=]{0,5}"""
                r"""([\w.=-]{10,150}|[a-z0-9][a-z0-9+/]{11,}={0,3})(?:[\x60'"\s;]|\\[nr]|$)""")


def shannon(s):
    return -sum(c / len(s) * math.log2(c / len(s)) for c in __import__("collections").Counter(s).values())


scanned = {f: open(os.path.join(OUT, f), errors="replace").read() for f in os.listdir(OUT)
           if os.path.isfile(os.path.join(OUT, f))}
scanned["<extract stdout>"] = out
hits = [(f, m.group(1)) for f, body in scanned.items() for m in GL.finditer(body) if shannon(m.group(1)) > 3.5]
ok(not hits, "gitleaks-style generic-api-key scan over %d outputs finds nothing %s" % (len(scanned), hits[:3]))

# 6. an output root inside a store root is refused; a marked directory under a root is never walked
nested = os.path.join(HOME, ".omp/agent/sessions/-work-demo-atlas/catalog-out")
code, _, _, rc = run("--out", nested, "index", "--project", PROJ)
ok(code == 5 and not os.path.exists(nested), "an output root inside a store root is refused (exit 5)")
legacy = os.path.join(HOME, ".omp/agent/sessions/-legacy-out")        # e.g. left by an older version
put(os.path.join(os.path.relpath(legacy, HOME), ".session-catalog-output"), raw=b"marker\n")
put(os.path.join(os.path.relpath(legacy, HOME), "2026-01-05T10-00-00-000Z_0009.jsonl"), [PI[0]])
code, _, _, _ = run("--out", os.path.join(FIX, "out-legacy"), "index", "--project", PROJ)
m2 = json.load(open(os.path.join(FIX, "out-legacy", "run-manifest.json")))
ok(m2["receipt"]["omp/sessions"].get("dirs_excluded", 0) >= 1
   and not any("-legacy-out" in v for v in m2["sources_private"].values()),
   "a directory carrying the output marker is never walked or ingested")
shutil.rmtree(legacy)  # keep the source-immutability check below about the original fixtures

# 7. export archives: hostile, invalid UTF-8, record cap, repeated exports, placeholder suppression
code, _, _, _ = run("--out", OUT, "--export", "chatgpt=" + bad_zip, "index", "--surface", "openai.chatgpt-export",
                    "--mention", "demo")
ok(any(x["reason"] == "archive-path-traversal" for x in jl(os.path.join(OUT, "quarantine.jsonl"))),
   "zip with a traversal member is rejected")
utf_conv = json.dumps([dict(conv[0], mapping={"a": dict(conv[0]["mapping"]["a"], message=dict(
    conv[0]["mapping"]["a"]["message"], content={"content_type": "text", "parts": ["demo-atlas UTFBAD"]}))})])
utf_zip = zip_of(os.path.join(FIX, "utf.zip"), [("conversations.json", utf_conv.encode().replace(b"UTFBAD", b"UTF\xffBAD"))])
out_u = os.path.join(FIX, "out-utf")
code, out, _, _ = run("--out", out_u, "--export", "chatgpt=" + utf_zip, "extract", "--surface", "openai.chatgpt-export",
                      "--mention", "demo-atlas")
ok(any(x["reason"] == "invalid-utf8" for x in jl(os.path.join(out_u, "quarantine.jsonl")))
   and "\ufffd" not in out and "\\ufffd" not in out, "invalid UTF-8 in an export member is quarantined, never replaced")
three = [dict(conv[0], id="cg-%d" % i) for i in range(3)]
zip3 = zip_of(os.path.join(FIX, "three.zip"), [("conversations.json", json.dumps(three))])
empty_home = os.path.join(FIX, "home-empty")
os.makedirs(empty_home)
out_c = os.path.join(FIX, "out-cap")
code, out, _, _ = run("--out", out_c, "--max-records", "1", "--export", "chatgpt=" + zip3, "extract", "--mention",
                      "demo-atlas", home=empty_home)
refs = {json.loads(l)["session_ref"] for l in out.splitlines()}
ok(any(x["reason"] == "run-record-cap" for x in jl(os.path.join(out_c, "quarantine.jsonl"))) and len(refs) <= 1,
   "--max-records caps export arrays too (%d session(s) emitted)" % len(refs))
zip_b = zip_of(os.path.join(FIX, "export-b.zip"), [("conversations.json", json.dumps(conv))])
out_e = os.path.join(FIX, "out-exports")
code, _, _, _ = run("--out", out_e, "--export", "chatgpt=" + good_zip, "--export", "chatgpt=" + zip_b, "index",
                    "--surface", "openai.chatgpt-export", "--mention", "demo-atlas")
r7 = jl(os.path.join(out_e, "sessions.jsonl"))
ok(len(r7) == 2 and len({r["partition"] for r in r7}) == 2 and len({r["session_ref"] for r in r7}) == 2,
   "two exports with the same conversation id keep distinct identities and refs")
m7 = json.load(open(os.path.join(out_e, "run-manifest.json")))
ok(code == 0, "a quarantine-free export run is complete, no 'not requested' placeholder in scope (%s)" % m7["claim"])
one_obj = zip_of(os.path.join(FIX, "one-object.zip"), [("conversations.json", json.dumps(conv[0]))])
out_o = os.path.join(FIX, "out-object")
code, out, _, _ = run("--out", out_o, "--export", "chatgpt=" + one_obj, "extract", "--surface",
                      "openai.chatgpt-export", "--mention", "demo-atlas")
ok(code == 4 and not out.strip() and any(x["reason"] == "not-a-json-array" for x in jl(os.path.join(out_o, "quarantine.jsonl"))),
   "an export that is a single object, not an array, is quarantined and nothing is emitted")
big = dict(conv[0], id="cg-big", mapping={"a": dict(conv[0]["mapping"]["a"], message=dict(
    conv[0]["mapping"]["a"]["message"], content={"content_type": "text", "parts": ["demo-atlas BIGREC-7Q " + "x" * 5000]}))})
capped = zip_of(os.path.join(FIX, "capped.zip"), [("conversations.json", json.dumps([big, dict(conv[0], id="cg-small")]))])
out_b = os.path.join(FIX, "out-bigrec")
code, out, _, _ = run("--out", out_b, "--max-record-bytes", "2048", "--export", "chatgpt=" + capped, "extract",
                      "--surface", "openai.chatgpt-export", "--mention", "demo-atlas")
ok("BIGREC-7Q" not in out and "chatgpt: demo-atlas idea" in out
   and any(x["reason"] == "record-over-size-cap" for x in jl(os.path.join(out_b, "quarantine.jsonl"))),
   "an export element over --max-record-bytes is quarantined even when it decodes in one chunk")

# 8. concurrency: a live lock blocks a second run
with open(os.path.join(OUT, ".lock"), "w") as fh:
    ps = subprocess.run(["ps", "-o", "lstart=", "-p", str(os.getpid())], capture_output=True, text=True).stdout.strip()
    fh.write(json.dumps({"pid": os.getpid(), "start": ps, "host": os.uname().nodename}))
code, _, _, rc = run("--out", OUT, "index", "--project", PROJ)
ok(code == 5 and rc.get("status") == "blocked", "a live lock blocks a second run (exit 5)")
with open(os.path.join(OUT, ".lock"), "w") as fh:
    fh.write(json.dumps({"pid": 999999, "start": "never", "host": os.uname().nodename}))
code, _, _, _ = run("--out", OUT, "index", "--project", PROJ)
ok(code in (0, 3), "a stale lock (pid gone) is reclaimed")
open(os.path.join(OUT, ".lock"), "w").close()                         # empty: a run died mid-write
code, _, _, rc = run("--out", OUT, "index", "--project", PROJ)
ok(code == 5, "a fresh empty lock still blocks (another run may be writing it)")
os.utime(os.path.join(OUT, ".lock"), (time.time() - 300, time.time() - 300))
code, _, _, _ = run("--out", OUT, "index", "--project", PROJ)
ok(code in (0, 3), "an empty lock older than 60 s is reclaimed")

# 9. receipts survive a consumer that closes stdout (`extract | head`)
out_p = os.path.join(FIX, "out-pipe")
p = subprocess.Popen([sys.executable, LAUNCHER, SC, "--home", HOME, "--out", out_p, "extract", "--project", PROJ, "--mention",
                      "demo-atlas"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
p.stdout.close()
perr = p.stderr.read().decode()
p.wait()
mp = json.load(open(os.path.join(out_p, "run-manifest.json"))) if os.path.exists(os.path.join(out_p, "run-manifest.json")) else {}
ok(p.returncode == 3 and mp.get("totals", {}).get("stdout_closed") is True and "Traceback" not in perr
   and os.path.exists(os.path.join(out_p, "quarantine.jsonl")),
   "a closed stdout ends extract as partial with manifest + quarantine written")

# 10. containment: a store root, or a component of it, that is a symlink is refused; one unreadable
# opaque-store file only marks that store unverified
adv = os.path.join(FIX, "home-adv")
put("-x/%s.jsonl" % U4, [cl("user", "demo-atlas OUTSIDE-ROOT-7Q")], home=os.path.join(FIX, "outside-store"))
put("sessions/2026/01/02/rollout-2026-01-02T10-00-00-%s.jsonl" % R1, [
    {"type": "session_meta", "timestamp": T0 % 1, "payload": {"id": R1, "cwd": PROJ, "cli_version": "0.146.0"}},
    {"type": "response_item", "timestamp": T0 % 3, "payload": {"type": "message", "role": "user", "content": [
        {"type": "input_text", "text": "demo-atlas OUTSIDE-CODEX-7Q"}]}}], home=os.path.join(FIX, "outside-codex"))
os.makedirs(os.path.join(adv, ".claude"))
os.symlink(os.path.join(FIX, "outside-store"), os.path.join(adv, ".claude", "projects"))   # the root itself
os.symlink(os.path.join(FIX, "outside-codex"), os.path.join(adv, ".codex"))               # a component of the root
pb = put(".gemini/antigravity/conversations/a.pb", raw=bytes(range(256)) * 8, home=adv)
os.chmod(pb, 0)
code, out, _, _ = run("stores", "--json", home=adv)
st = {r["store"]: r for r in json.loads(out)["stores"]} if code == 0 else {}
for sid in ("claude-code/projects", "codex/sessions"):
    ok(st.get(sid, {}).get("status") == "unavailable" and "symlink" in st.get(sid, {}).get("reason", ""),
       "%s: a symlinked store root (or root component) is refused" % sid)
if os.geteuid() != 0:
    ok(code == 0 and st.get("antigravity/conversations", {}).get("status") == "unverified",
       "an unreadable opaque-store file marks only that store unverified (exit %d)" % code)
code, out, _, _ = run("--out", os.path.join(FIX, "out-adv"), "extract", "--project", PROJ, "--mention", "OUTSIDE",
                      home=adv)
ok(code == 4 and "OUTSIDE-ROOT-7Q" not in out and "OUTSIDE-CODEX-7Q" not in out,
   "nothing behind a symlinked root is emitted (exit %d: no importable store, not a crash)" % code)

# 11. open-time binding: sources swapped AFTER the walk are refused at open (race regression)
import importlib.util as _iu
_spec = _iu.spec_from_file_location("sc", SC)
mod = _iu.module_from_spec(_spec)
_spec.loader.exec_module(mod)
race = os.path.join(FIX, "home-race")
RU = "dddddddd-eeee-4fff-8000-111111111111"
race_file = put(".claude/projects/-race/%s.jsonl" % RU, [cl("user", "demo-atlas RACE-INSIDE-7Q", sid=RU)], home=race)
out_dir = os.path.join(FIX, "race-outside")
out_file = put("%s.jsonl" % RU, [cl("user", "demo-atlas RACE-OUTSIDE-7Q", sid=RU)], home=out_dir)


def race_units():
    rctx = mod.Ctx(race, time.time(), dict(mod.LIMITS), [], b"k" * 32)
    s = next(x for x in mod.build_stores(rctx, []) if x.id == "claude-code/projects")
    return rctx, s.units()


def loaded(rctx, unit):
    meta, msgs = unit.load()
    return meta, " ".join(m["text"] for m in msgs), {x["reason"] for x in rctx.quarantine}


rctx, units = race_units()
meta, txt, _ = loaded(rctx, units[0])
ok(meta is not None and "RACE-INSIDE-7Q" in txt, "race control: the walked file loads normally")
os.rename(race_file, race_file + ".orig")
os.symlink(out_file, race_file)
meta, txt, rs = loaded(rctx, units[0])
ok(meta is None and "symlink-refused" in rs and "RACE-OUTSIDE" not in txt, "file swapped for a symlink after the walk is refused")
os.unlink(race_file)
shutil.copy2(out_file, race_file)
meta, txt, rs = loaded(rctx, units[0])
ok(meta is None and "identity-changed" in rs and "RACE-OUTSIDE" not in txt,
   "file replaced by another inode after the walk is refused (identity binding)")
os.unlink(race_file)
os.rename(race_file + ".orig", race_file)
rctx.close()
rctx, units = race_units()
slug = os.path.dirname(race_file)
os.rename(slug, slug + ".orig")
os.symlink(out_dir, slug)
meta, txt, rs = loaded(rctx, units[0])
ok(meta is None and "symlink-refused" in rs and "RACE-OUTSIDE" not in txt,
   "parent directory swapped for a symlink after the walk is refused")
os.unlink(slug)
os.rename(slug + ".orig", slug)
rctx.close()
hl = os.path.join(race, ".claude/projects/-hard/%s.jsonl" % RU)
os.makedirs(os.path.dirname(hl))
os.link(out_file, hl)
rctx, units = race_units()
hard = [u for u in units if u.path == hl]
meta, txt, rs = loaded(rctx, hard[0]) if hard else (None, "", set())
ok(hard and meta is None and "hardlink-refused" in rs, "a hard-linked source (alias of an outside file) is refused")
rctx.close()

# 12. isolation guard: every adapter root resolves inside the synthetic tree (never the real home)
_ctx = mod.Ctx(HOME, time.time(), dict(mod.LIMITS), [], b"k" * 32)
_stores = mod.build_stores(_ctx, [("chatgpt", good_zip)])
_roots = [s.root for s in _stores]
_ctx.close()
ok(all(r == "cloud" or os.path.realpath(r).startswith(os.path.realpath(FIX)) for r in _roots),
   "every adapter root resolves inside the synthetic test tree (%d roots)" % len(_roots))
_inputs = [os.path.join(HOME, p) for p in mod.INPUT_PATHS]
ok(all(any(r == i or r.startswith(i + os.sep) for i in _inputs) for s, r in zip(_stores, _roots)
       if r != "cloud" and s.kind != "export"),
   "INPUT_PATHS (the output-overlap guard) covers every store root")

# 13. documented exit-code contract == CLI contract
doc = open(os.path.join(os.path.dirname(os.path.dirname(SC)), "SKILL.md")).read()
documented = {m.group(2): int(m.group(1)) for m in re.finditer(r"^\| (\d) \| `(\w+)` \|", doc, re.M)}
ok(documented == mod.EXIT, "SKILL.md exit-code table matches the CLI (%s)" % sorted(documented.items()))
ok(mod.VERSION == fixture_version(), "reader VERSION matches SKILL.md version")

# 14. every path the reader touches stays inside the declared fixture roots and the output dir
try:
    import fcntl
except ImportError:
    fcntl = None


def fd_path(fd):
    if fcntl is not None and hasattr(fcntl, "F_GETPATH"):
        return fcntl.fcntl(fd, fcntl.F_GETPATH, bytes(1024)).split(b"\0", 1)[0].decode()
    return os.readlink("/proc/self/fd/%d" % fd)


def forms(p):
    return {os.path.abspath(p), os.path.realpath(p)}


EXP_I = os.path.join(FIX, "exports-i", "export.zip")
os.makedirs(os.path.dirname(EXP_I))
shutil.copy2(good_zip, EXP_I)
OUT_I = os.path.join(FIX, "instr-out")
READ_ROOTS = forms(HOME) | forms(OUT_I) | forms(EXP_I)
WRITE_ROOTS = forms(OUT_I)
ANCESTORS = set()
for r in READ_ROOTS:
    p = r
    while os.path.dirname(p) != p:
        p = os.path.dirname(p)
        ANCESTORS.add(p)
TEMPS = mod.temp_roots()
CODE_DIRS = forms(sys.prefix) | forms(sys.base_prefix) | forms(sys.exec_prefix)
events, active, guard = [], [False], threading.local()


def _record(op, kind, path, dir_fd=None, flags=None):
    if not active[0] or getattr(guard, "on", False):
        return
    guard.on = True
    try:
        if isinstance(path, int):
            p = fd_path(path)
        else:
            p = os.fsdecode(path)
            p = os.path.join(fd_path(dir_fd), p) if dir_fd is not None and not os.path.isabs(p) else os.path.abspath(p)
        events.append((op, kind, os.path.normpath(p), flags, dir_fd is not None))
    finally:
        guard.on = False


_orig = {n: getattr(os, n) for n in ("open", "stat", "lstat", "scandir", "listdir", "mkdir", "rename", "replace",
                                     "unlink", "rmdir")}
_orig_open = builtins.open
WRITE_FLAGS = os.O_WRONLY | os.O_RDWR | os.O_CREAT


def p_open(path, flags, mode=0o777, *, dir_fd=None):
    _record("os.open", "write" if flags & WRITE_FLAGS else "content", path, dir_fd, flags)
    return _orig["open"](path, flags, mode, dir_fd=dir_fd)


def p_stat(path, *, dir_fd=None, follow_symlinks=True):
    if not isinstance(path, int):
        _record("os.stat", "meta", path, dir_fd)
    return _orig["stat"](path, dir_fd=dir_fd, follow_symlinks=follow_symlinks)


def p_lstat(path, *, dir_fd=None):
    _record("os.lstat", "meta", path, dir_fd)
    return _orig["lstat"](path, dir_fd=dir_fd)


def p_scandir(path="."):
    _record("os.scandir", "content", path)
    return _orig["scandir"](path)


def p_listdir(path="."):
    _record("os.listdir", "content", path)
    return _orig["listdir"](path)


def p_mkdir(path, mode=0o777, *, dir_fd=None):
    _record("os.mkdir", "write", path, dir_fd)
    return _orig["mkdir"](path, mode, dir_fd=dir_fd)


def _two(name):
    def fn(src, dst, *, src_dir_fd=None, dst_dir_fd=None):
        _record(name, "write", src, src_dir_fd)
        _record(name, "write", dst, dst_dir_fd)
        return _orig[name](src, dst, src_dir_fd=src_dir_fd, dst_dir_fd=dst_dir_fd)
    return fn


def _one(name):
    def fn(path, *, dir_fd=None):
        _record(name, "write", path, dir_fd)
        return _orig[name](path, dir_fd=dir_fd)
    return fn


def p_bopen(file, mode="r", *a, **k):
    if not isinstance(file, int):
        _record("open", "write" if any(c in mode for c in "wax+") else "content", file)
    return _orig_open(file, mode, *a, **k)


def audit(event, args):
    if event == "open" and args and isinstance(args[0], (str, bytes)) and os.path.isabs(os.fsdecode(args[0])):
        mode = args[1] if len(args) > 1 and isinstance(args[1], str) else "r"
        _record("audit:open", "write" if any(c in mode for c in "wax+") else "content", args[0])


sys.addaudithook(audit)
patched = {"open": p_open, "stat": p_stat, "lstat": p_lstat, "scandir": p_scandir, "listdir": p_listdir,
           "mkdir": p_mkdir, "rename": _two("rename"), "replace": _two("replace"), "unlink": _one("unlink"),
           "rmdir": _one("rmdir")}
runs = [["--home", HOME, "stores", "--json"],
        ["--home", HOME, "--out", OUT_I, "--export", "chatgpt=" + EXP_I, "index", "--project", PROJ, "--mention", "demo-atlas"],
        ["--home", HOME, "--out", OUT_I, "--export", "chatgpt=" + EXP_I, "extract", "--project", PROJ, "--mention", "demo-atlas"]]
codes = []
import contextlib
mod.temp_roots = fixture_temp_roots(mod.temp_roots)  # see LAUNCHER; TEMPS above was taken from the real policy


def instrumented(argv):
    for n, fn in patched.items():
        setattr(os, n, fn)
    builtins.open = io.open = p_bopen
    active[0] = True
    try:
        with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            return mod.main(argv)
    except SystemExit as exc:
        return exc.code
    finally:
        active[0] = False
        for n, fn in _orig.items():
            setattr(os, n, fn)
        builtins.open = io.open = _orig_open


for argv in runs:
    codes.append(instrumented(argv))


def inside(p, roots):
    return any(p == r or p.startswith(r + os.sep) for r in roots)


STDLIB_SUFFIXES = (".py", ".pyc", ".so", ".mo")
bad, stdlib = [], []
for op, kind, p, flags, rel_fd in events:
    if kind == "write":
        good = inside(p, WRITE_ROOTS)
    elif kind == "content":
        good = inside(p, READ_ROOTS) or (op == "audit:open" and inside(p, CODE_DIRS) and p.endswith(STDLIB_SUFFIXES))
    else:
        good = inside(p, READ_ROOTS) or p in ANCESTORS or os.path.dirname(p) in ANCESTORS or p in TEMPS
    if not good and inside(p, CODE_DIRS) and p.endswith(STDLIB_SUFFIXES):
        stdlib.append(p)  # interpreter-internal: module code, gettext catalogs (argparse) — never user data
    elif not good:
        bad.append((op, kind, p))
home_opens = [e for e in events if e[0] == "os.open" and inside(e[2], forms(HOME))]
ok(codes[0] == 0 and all(c in (0, 3) for c in codes[1:]), "instrumented stores/index/extract runs complete (%s)" % codes)
ok(len(home_opens) > 20 and any(e[4] for e in home_opens), "instrumentation is not vacuous (%d source opens, dir-fd relative)"
   % len(home_opens))
ok(not bad, "every touched path stays inside the fixture roots and the output dir (%d events; %d interpreter-"
   "internal stdlib lookups) %s" % (len(events), len(stdlib), bad[:3]))
ok(all(e[3] & os.O_NOFOLLOW for e in events if e[0] == "os.open" and inside(e[2], READ_ROOTS)),
   "every os.open under the fixture roots uses O_NOFOLLOW")

# 14b. data minimization: with --surface, stores outside the scope are never built, so never touched
events.clear()
scoped = instrumented(["--home", HOME, "--out", OUT_I, "--export", "chatgpt=" + EXP_I, "index",
                       "--surface", "openai.chatgpt-export", "--mention", "demo-atlas"])
touched = sorted({e[2] for e in events if inside(e[2], forms(HOME)) and e[2] not in forms(HOME)})
ok(scoped == 0 and not touched and any(inside(e[2], forms(EXP_I)) for e in events),
   "--surface openai.chatgpt-export touches no path under the home, only the export (%s)" % touched[:3])

# 15. passes 1 and 2 never touch the network: any socket creation raises
import socket as _socket
_orig_socket = _socket.socket


class _NoNetwork(_orig_socket):
    def __init__(self, *a, **k):
        raise AssertionError("network access attempted")


_socket.socket = _NoNetwork
try:
    for argv in (["--home", HOME, "--out", os.path.join(FIX, "nonet"), "index", "--project", PROJ],
                 ["--home", HOME, "--out", os.path.join(FIX, "nonet"), "extract", "--project", PROJ]):
        try:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                rc = mod.main(argv)
        except SystemExit as exc:
            rc = exc.code
        except AssertionError:
            rc = "socket"
        ok(rc in (0, 3), "%s opens no socket (rc=%s)" % (argv[4], rc))
finally:
    _socket.socket = _orig_socket

# 16. sources were never modified (content and mtime)
writer.stdin.close()
writer.wait()
ok(tree_hash(HOME) == before, "every source file is byte- and mtime-identical after all runs")

print("%d failure(s)" % len(fails))
sys.exit(1 if fails else 0)
PY
