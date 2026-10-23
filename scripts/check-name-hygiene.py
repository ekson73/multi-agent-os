#!/usr/bin/env python3
"""check-name-hygiene — keep the framework free of org- and person-specific identifiers.

Why hashes: a plain-text denylist would republish exactly the names this check
exists to keep out of the tree. Each denylist entry is sha256(salt + token), so
the list can be reviewed and versioned without spelling the names. This is
obfuscation against casual reading and grep, not secrecy: short names are
dictionary-guessable, and the check does not try to hide that.

Detectors (stdlib only, no network):
  1. Denylisted tokens. Text is split on [^A-Za-z0-9] (regex escapes such as
     a word-boundary escape are dropped first; camelCase parts are checked too)
     and lower-cased. Entry
     mode "x" matches the whole token; mode "p" matches any token that starts
     with the denylisted value (min. 3 chars), e.g. a handle followed by digits.
  2. Real-looking e-mail addresses (example/test/noreply domains are ignored).
  3. CPF / CNPJ with valid check digits (Modulo 11).
  4. Local home paths (/Users/NAME/, /home/NAME/) with a non-generic NAME.
  5. Host-alias SSH remotes (git@github.com-ALIAS:) with a non-generic ALIAS.

Allowlist (.github/name-hygiene/allow.json): every entry needs a "reason".
Fields: "paths" (fnmatch globs), optional "detectors" (ids such as "d3",
"email", "home-path"), optional "context" (regex; "{T}" stands for the
matched token, so allow rules never spell the name either).

Exit codes: 0 clean (or --report-only), 1 findings, 2 usage/config error.
Output masks every finding to its first character.
"""
from __future__ import annotations

import argparse
import fnmatch
import hashlib
import json
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.dirname(HERE)
DEFAULT_DENY = ".github/name-hygiene/denylist.txt"
DEFAULT_ALLOW = ".github/name-hygiene/allow.json"

TOKEN_RE = re.compile(r"[A-Za-z0-9]+")
CAMEL_RE = re.compile(r"[A-Z]?[a-z]+|[A-Z]+(?![a-z])|[0-9]+")
ESCAPE_RE = re.compile(r"\\[bBwWdDsSntr]")
EMAIL_RE = re.compile(r"(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]{1,64}@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)*\.[A-Za-z]{2,}")
CPF_RE = re.compile(r"(?<!\d)\d{3}\.?\d{3}\.?\d{3}-?\d{2}(?!\d)")
CNPJ_RE = re.compile(r"(?<!\d)\d{2}\.?\d{3}\.?\d{3}/?\d{4}-?\d{2}(?!\d)")
DIGITS_RE = re.compile(r"\d{2}")
HOME_RE = re.compile(r"/(?:Users|home)/([A-Za-z][A-Za-z0-9._-]*)/")
SSH_ALIAS_RE = re.compile(r"git@github\.com-([A-Za-z0-9_.-]+):")

GENERIC_HOME = {"user", "username", "you", "me", "name", "example", "runner", "shared",
                "alice", "bob", "charlie", "x", "foo",
                "jane.doe", "john.doe", "dev", "ubuntu", "node", "app", "linuxbrew", "vscode", "codespace"}
GENERIC_ALIAS = {"personal", "work", "alias", "example", "account"}
IGNORED_EMAIL_DOMAINS = re.compile(
    r"(^|\.)(example\.(com|org|net)|example|test|invalid|localhost|"
    r"company\.com|provider\.com|email\.com|domain\.com)$", re.I)
TEXT_LIMIT = 2_000_000


def sha(salt: str, token: str) -> str:
    return hashlib.sha256((salt + token).encode("utf-8")).hexdigest()


def load_denylist(path: str):
    salt, entries = None, []
    with open(path, encoding="utf-8") as fh:
        for raw in fh:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            if line.startswith("salt "):
                salt = line.split(None, 1)[1]
                continue
            parts = line.split()
            if len(parts) != 3 or parts[1] not in ("x", "p") or not re.fullmatch(r"[0-9a-f]{64}", parts[2]):
                raise ValueError(f"bad denylist line: {line[:40]}")
            entries.append({"id": parts[0], "mode": parts[1], "hash": parts[2]})
    if not salt:
        raise ValueError("denylist has no 'salt' line")
    return salt, entries


def load_allow(path: str):
    if not os.path.exists(path):
        return []
    with open(path, encoding="utf-8") as fh:
        data = json.load(fh)
    rules = data.get("allow", [])
    for r in rules:
        if not r.get("reason") or not r.get("paths"):
            raise ValueError(f"allow rule without reason/paths: {r.get('id', '?')}")
    return rules


def cpf_ok(d: str) -> bool:
    if len(d) != 11 or len(set(d)) == 1:
        return False
    for n in (9, 10):
        s = sum(int(d[i]) * (n + 1 - i) for i in range(n))
        if (s * 10 % 11) % 10 != int(d[n]):
            return False
    return True


def cnpj_ok(d: str) -> bool:
    if len(d) != 14 or len(set(d)) == 1:
        return False
    w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    w2 = [6] + w1
    for w, n in ((w1, 12), (w2, 13)):
        r = sum(int(d[i]) * w[i] for i in range(n)) % 11
        if (0 if r < 2 else 11 - r) != int(d[n]):
            return False
    return True


def email_ignored(addr: str) -> bool:
    local, dom = addr.rsplit("@", 1)
    if "noreply" in local.lower() or "noreply" in dom.lower() or local.lower() == "git":
        return True
    if IGNORED_EMAIL_DOMAINS.search(dom):
        return True
    return bool(re.match(r"^v?\d", dom.split(".")[0]))  # package@1.2.3 etc.


def mask(s: str) -> str:
    return s[:1] + "*" * min(max(len(s) - 1, 2), 6)


def list_files(root: str, paths: list[str] | None):
    if paths:
        return [p for p in paths if os.path.isfile(os.path.join(root, p))]
    out = subprocess.run(["git", "ls-files", "-z"], cwd=root, capture_output=True, check=True).stdout
    return [p for p in out.decode("utf-8", "replace").split("\0") if p]


def allowed(rules, path, detector, line, token):
    for r in rules:
        if not any(fnmatch.fnmatch(path, g) for g in r["paths"]):
            continue
        if r.get("detectors") and detector not in r["detectors"]:
            continue
        ctx = r.get("context")
        if ctx:
            rx = ctx.replace("{T}", re.escape(token) if token else "")
            if not re.search(rx, line, re.I):
                continue
        return True
    return False


def scan(root, files, salt, deny, rules, self_paths):
    exact = {e["hash"]: e for e in deny if e["mode"] == "x"}
    prefix = {e["hash"]: e for e in deny if e["mode"] == "p"}
    findings = []
    cache: dict = {}

    def lookup(low: str):
        if low in cache:
            return cache[low]
        e = exact.get(sha(salt, low))
        if not e and prefix:
            for k in range(3, min(len(low), 40) + 1):
                e = prefix.get(sha(salt, low[:k]))
                if e:
                    break
        cache[low] = e
        return e
    for path in files:
        if path in self_paths:
            continue
        full = os.path.join(root, path)
        if os.path.islink(full):
            continue
        try:
            with open(full, "rb") as fh:
                blob = fh.read(TEXT_LIMIT)
        except OSError:
            continue
        if b"\0" in blob[:8000] or blob.startswith(b"%PDF"):
            continue
        name_text = path  # file names leak too
        lines = [name_text] + blob.decode("utf-8", "replace").split("\n")
        for lineno, line in enumerate(lines):
            hits = []
            # regex escapes such as \bname\b would glue a letter to the name
            tok_line = ESCAPE_RE.sub(" ", line)
            for m in TOKEN_RE.finditer(tok_line):
                tok = m.group(0)
                parts = [tok]
                camel = CAMEL_RE.findall(tok)
                if len(camel) > 1:
                    parts += camel
                for part in parts:
                    e = lookup(part.lower())
                    if e:
                        hits.append((e["id"], part))
                        break
            for m in (EMAIL_RE.finditer(line) if "@" in line else ()):
                if not email_ignored(m.group(0)):
                    hits.append(("email", m.group(0)))
            has_digits = DIGITS_RE.search(line) is not None
            for m in (CPF_RE.finditer(line) if has_digits else ()):
                if cpf_ok(re.sub(r"\D", "", m.group(0))):
                    hits.append(("cpf", m.group(0)))
            for m in (CNPJ_RE.finditer(line) if has_digits else ()):
                if cnpj_ok(re.sub(r"\D", "", m.group(0))):
                    hits.append(("cnpj", m.group(0)))
            for m in (HOME_RE.finditer(line) if ("/Users/" in line or "/home/" in line) else ()):
                if m.group(1).lower() not in GENERIC_HOME and not m.group(1).startswith(("$", "{")):
                    hits.append(("home-path", m.group(1)))
            for m in (SSH_ALIAS_RE.finditer(line) if "git@github.com-" in line else ()):
                if m.group(1).lower() not in GENERIC_ALIAS:
                    hits.append(("ssh-alias", m.group(1)))
            for det, tok in hits:
                if allowed(rules, path, det, line, tok):
                    continue
                findings.append({"file": path, "line": lineno, "detector": det, "token": mask(tok)})
    return findings


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--root", default=DEFAULT_ROOT)
    ap.add_argument("--denylist", default=None)
    ap.add_argument("--allow", default=None)
    ap.add_argument("--paths", nargs="*", help="limit to these repo-relative files (e.g. the PR diff)")
    ap.add_argument("--report-only", action="store_true", help="always exit 0 (advisory mode)")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    root = os.path.abspath(a.root)
    deny_path = a.denylist or os.path.join(root, DEFAULT_DENY)
    allow_path = a.allow or os.path.join(root, DEFAULT_ALLOW)
    try:
        salt, deny = load_denylist(deny_path)
        rules = load_allow(allow_path)
        files = list_files(root, a.paths)
    except (OSError, ValueError, subprocess.CalledProcessError, json.JSONDecodeError) as exc:
        print(f"check-name-hygiene: config error: {exc}", file=sys.stderr)
        return 2
    self_paths = {os.path.relpath(p, root) for p in (deny_path, allow_path)}
    findings = scan(root, files, salt, deny, rules, self_paths)
    if a.json:
        print(json.dumps({"findings": findings, "count": len(findings)}, indent=2))
    else:
        for f in findings:
            where = f"{f['file']} (file name)" if f["line"] == 0 else f"{f['file']}:{f['line']}"
            print(f"{where}: [{f['detector']}] {f['token']}")
        print(f"check-name-hygiene: {len(findings)} finding(s) in {len({f['file'] for f in findings})} file(s)"
              f" across {len(files)} scanned file(s){' (report-only)' if a.report_only else ''}")
    if findings and not a.report_only:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
