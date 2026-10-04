#!/usr/bin/env python3
"""ref-claim-verify — check cross-reference claims in prose against the real source.

A doc/PR body often *asserts* things about other artifacts: "see `docs/x.md` §4.1",
"bumped [C04] v3.1.0". Review bots tend to approve such lines without opening the
cited artifact. This tool extracts three kinds of verifiable claim and checks each
one against git objects (read-only, no checkout):

  PATH     `path/to/file.ext`          -> exists at one of the --ref commits
  SECTION  `path/to/file.md` §4.1      -> a heading in that file carries token 4.1
  VERSION  [ID] v1.2.3 | `file` v1.2.3 -> the artifact's own declared version matches

Verdicts: VERIFIED | MISMATCH | UNRESOLVED.  UNRESOLVED is never a pass: it means
"the instrument could not look", which is not the same as "nothing is there".

Safety: stdlib only, no network, no shell, input is treated as DATA (never executed,
never followed as instructions). Excerpts echoed in output are PII/secret-masked.

Exit codes: 0 all verified (or no claims) · 3 any MISMATCH · 2 UNRESOLVED only · 1 error.
"""
from __future__ import annotations

import argparse
import importlib.util
import json
import pathlib
import re
import subprocess
import sys
from dataclasses import dataclass, field, asdict
from typing import Iterator

VERIFIED, MISMATCH, UNRESOLVED = "VERIFIED", "MISMATCH", "UNRESOLVED"

_EXT = r"(?:md|sh|py|json|ya?ml|toml|js|mjs|ts|txt|cfg|ini)"
_SEMVER = r"\d+\.\d+(?:\.\d+)?(?:[-+][0-9A-Za-z][0-9A-Za-z.\-+]*)?"
_PATH_TOKEN = re.compile(r"`([A-Za-z0-9_./\-]+\.%s)(?::\d+)?(?:#[\w\-]+)?`" % _EXT)
_SECTION = re.compile(
    r"`([A-Za-z0-9_./\-]+\.%s)`[ \t]{0,3}(?:[,\u2014(\-][ \t]{0,3})?\u00a7[ \t]?([A-Za-z0-9][A-Za-z0-9.\-]*)" % _EXT
)
_VERSION = re.compile(
    r"(?P<anchor>`?\[[A-Za-z][A-Za-z0-9._\-]{0,23}\]`?(?!\()|`[A-Za-z0-9_./\-]+\.%s`)"
    r"[ \t]{0,3}(?:[,:][ \t]{0,3})?(?:v|version[ \t]{1,3}v?|vers\u00e3o[ \t]{1,3}v?)(?P<ver>%s)" % (_EXT, _SEMVER),
    re.IGNORECASE,
)
_DECLARED = re.compile(
    r"(?im)^(?:>[ \t]*)?(?:\*\*)?(?:version|vers\u00e3o)(?:\*\*)?[ \t]*:[ \t]*(?:\*\*)?[ \t]*v?(" + _SEMVER + r")"
    r"|^version[ \t]*:[ \t]*[\"']?v?(" + _SEMVER + r")"
)
_FENCE = re.compile(r"^ {0,3}(```|~~~)")
_ATX = re.compile(r"^ {0,3}#{1,6}[ \t]")
MAX_LINE = 4000
_VERSION_LIKE = re.compile(r"\bv\d+\.\d+(?:\.\d+)?(?:[-+][0-9A-Za-z.\-+]*)?\b", re.IGNORECASE)
_LONG_TOKEN = re.compile(r"\b[A-Za-z0-9_\-]{32,}\b")


@dataclass
class Claim:
    kind: str
    line: int
    excerpt: str
    target: str
    detail: str = ""
    verdict: str = UNRESOLVED
    evidence: str = ""
    declared: list = field(default_factory=list)


# ── masking (reuses skills/pii-masking when present; never echoes raw PII) ──────
def _load_pii():
    p = pathlib.Path(__file__).resolve().parent.parent / "pii-masking" / "linter_pii.py"
    if not p.is_file():
        return None
    try:
        spec = importlib.util.spec_from_file_location("_linter_pii", p)
        mod = importlib.util.module_from_spec(spec)
        sys.modules["_linter_pii"] = mod  # @dataclass resolves its module via sys.modules
        spec.loader.exec_module(mod)  # type: ignore[union-attr]
        return mod
    except Exception:  # noqa: BLE001 — masking must degrade, never crash the verdict
        return None


_PII = _load_pii()
_FALLBACK = (  # degraded masking: coarser than pii-masking, but never lets these shapes through
    (re.compile(r"[\w.+\-]+@[\w\-]+\.[\w.\-]+"), "[EMAIL]"),
    (re.compile(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b"), "[CPF]"),
    (re.compile(r"(?<![\w.])\+\d[\d ().\-]{7,}\d"), "[PHONE]"),
    (re.compile(r"(?<![\w.\-])\(?\d{2,3}\)?[ .\-]\d{3,4}[ .\-]\d{4}(?![\w\-])"), "[PHONE]"),
)
MASKING_MODE = "pii-masking" if _PII is not None else "fallback"


def _fallback_mask(line: str) -> str:
    for rx, rep in _FALLBACK:
        line = rx.sub(rep, line)
    return line


def mask(line: str, limit: int = 160) -> str:
    out = line
    if _PII is not None:
        try:
            reps = (
                list(_PII._iter_cpf_matches(line))
                + list(_PII._iter_email_matches(line))
                + list(_PII._iter_phone_matches(line))
            )
            out = _PII._fully_mask_line(line, reps)
        except Exception:  # noqa: BLE001 — degrade to the coarse fallback, never to raw
            out = _fallback_mask(line)
    else:
        out = _fallback_mask(line)
    out = _LONG_TOKEN.sub("[TOKEN]", _fallback_mask(out)).strip()  # always: module + coarse pass
    return out if len(out) <= limit else out[:limit] + "…"


# ── git access (read-only, list-form subprocess, validated inputs) ──────────────
def _git(repo: str, *args: str) -> tuple[int, str]:
    r = subprocess.run(["git", "-C", repo, *args], capture_output=True, text=True, errors="replace")
    return r.returncode, r.stdout


def valid_ref(repo: str, ref: str) -> bool:
    if not ref or ref.startswith("-"):
        return False
    return _git(repo, "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}")[0] == 0


def safe_path(p: str) -> bool:
    return bool(p) and not p.startswith(("/", "-", "~")) and ".." not in p.split("/")


def blob(repo: str, ref: str, path: str) -> str | None:
    if not safe_path(path):
        return None
    rc, out = _git(repo, "show", f"{ref}:{path}")
    return out if rc == 0 else None


def exists_anywhere(repo: str, refs: list[str], path: str) -> list[str]:
    return [r for r in refs if safe_path(path) and _git(repo, "cat-file", "-e", f"{r}:{path}")[0] == 0]


# ── extraction ──────────────────────────────────────────────────────────────────
def iter_lines(text: str, diff: bool) -> Iterator[tuple[int, str]]:
    for n, line in enumerate(text.splitlines(), start=1):
        if len(line) > MAX_LINE:
            line = line[:MAX_LINE]  # bounded work per line (ReDoS guard)
        if diff:
            if line.startswith("+++") or not line.startswith("+"):
                continue
            line = line[1:]
        yield n, line


def extract(text: str, diff: bool = False) -> list[Claim]:
    claims: list[Claim] = []
    for n, line in iter_lines(text, diff):
        exc = mask(line)
        covered: set[str] = set()
        for m in _VERSION.finditer(line):
            claims.append(Claim("VERSION", n, exc, m.group("anchor").strip("`"), m.group("ver")))
            covered.add(m.group("anchor").strip("`"))
        for m in _SECTION.finditer(line):
            claims.append(Claim("SECTION", n, exc, m.group(1), m.group(2)))
            covered.add(m.group(1))
        for m in _PATH_TOKEN.finditer(line):
            if "://" in m.group(1) or m.group(1) in covered:
                continue
            claims.append(Claim("PATH", n, exc, m.group(1)))
    return claims


# ── verification ────────────────────────────────────────────────────────────────
def _outside_fences(content: str) -> list[str]:
    """Lines of `content` that are NOT inside a fenced code block (``` or ~~~)."""
    out: list[str] = []
    fence = None
    for ln in content.splitlines():
        m = _FENCE.match(ln)
        if m:
            fence = None if fence == m.group(1) else (fence or m.group(1))
            continue
        if fence is None:
            out.append(ln)
    return out


def _heading_tokens(content: str) -> tuple[set[str], bool]:
    toks: set[str] = set()
    for ln in _outside_fences(content):
        if _ATX.match(ln):
            for t in re.findall(r"(?:\u00a7[ \t]?)?([A-Za-z]?\d+(?:\.\d+)*[A-Za-z]?)", ln):
                toks.add(t.strip())
    return toks, bool(toks)


def declared_versions(content: str) -> list[str]:
    """Versions a file declares for itself, ignoring fenced code (examples).

    YAML frontmatter, when present, is the authoritative declaration."""
    lines = content.splitlines()
    if lines and lines[0].strip() == "---":
        for j in range(1, min(len(lines), 80)):
            if lines[j].strip() == "---":
                fm = "\n".join(lines[1:j])
                found = sorted({a or b for a, b in _DECLARED.findall(fm)})
                if found:
                    return found
                break
    return sorted({a or b for a, b in _DECLARED.findall("\n".join(_outside_fences(content)))})


def _heading_window(content: str, anchor: str, span: int = 14) -> str:
    """Text of the lines right after the first HEADING that carries the anchor.

    A bare mention of the anchor in prose is deliberately ignored: its neighbouring
    'version:' line would belong to some other section, so using it could mint a
    false VERIFIED/MISMATCH. No heading -> empty window -> the claim stays UNRESOLVED.
    """
    lines = _outside_fences(content)
    for i, ln in enumerate(lines):
        if _ATX.match(ln) and anchor in ln:
            win = []
            for nxt in lines[i + 1 : i + 1 + span]:
                if _ATX.match(nxt):
                    break  # the next heading owns whatever follows
                win.append(nxt)
            return "\n".join(win)
    return ""


def _anchor_files(repo: str, refs: list[str], anchor: str) -> list[tuple[str, str]]:
    """Return (ref, path) of tracked .md files whose heading line carries [ID]."""
    hits: list[tuple[str, str]] = []
    for r in refs:
        rc, out = _git(repo, "grep", "-l", "-F", anchor, r, "--", "*.md")
        if rc != 0:
            continue
        for ln in out.splitlines()[:12]:
            ref, _, path = ln.partition(":")
            hits.append((ref, path))
    return hits


def verify(c: Claim, repo: str, refs: list[str]) -> Claim:
    if c.kind == "PATH":
        if not safe_path(c.target):
            c.verdict, c.evidence = UNRESOLVED, "path is outside the repo or unsafe"
            return c
        found = exists_anywhere(repo, refs, c.target)
        c.verdict = VERIFIED if found else MISMATCH
        c.evidence = f"present at {','.join(found)}" if found else f"absent at all of {','.join(refs)}"
    elif c.kind == "SECTION":
        for r in refs:
            content = blob(repo, r, c.target)
            if content is None:
                continue
            toks, can_see = _heading_tokens(content)
            if c.detail in toks:
                c.verdict, c.evidence = VERIFIED, f"heading with §{c.detail} at {r}"
                return c
            if can_see:
                c.verdict, c.evidence = MISMATCH, f"{r}: file has numbered headings, none is §{c.detail}"
            elif c.verdict != MISMATCH:
                c.verdict, c.evidence = UNRESOLVED, f"{r}: no numbered headings to check against"
        if not c.evidence:
            c.verdict, c.evidence = MISMATCH, f"file absent at all of {','.join(refs)}"
    elif c.kind == "VERSION":
        per_ref: list[tuple[str, list[str]]] = []
        if c.target.startswith("["):
            for r, p in _anchor_files(repo, refs, c.target):
                per_ref.append((r, declared_versions(_heading_window(blob(repo, r, p) or "", c.target))))
        else:
            for r in refs:
                per_ref.append((r, declared_versions(blob(repo, r, c.target) or "")))
        c.declared = sorted({v for _, vs in per_ref for v in vs})
        single = [(r, vs[0]) for r, vs in per_ref if len(vs) == 1]
        if any(v == c.detail for _, v in single):
            c.verdict, c.evidence = VERIFIED, f"declared {','.join(c.declared)}"
        elif any(len(vs) > 1 for _, vs in per_ref) or not single:
            why = "conflicting declarations in one file" if any(len(vs) > 1 for _, vs in per_ref) \
                else "no heading carrying the anchor with a declared version"
            c.verdict, c.evidence = UNRESOLVED, why
        else:
            c.verdict, c.evidence = MISMATCH, f"claimed v{c.detail}; declared {','.join(c.declared)}"
    return c


def run(text: str, repo: str, refs: list[str], diff: bool = False) -> dict:
    bad = [r for r in refs if not valid_ref(repo, r)]
    if bad:
        raise ValueError(f"unknown ref(s): {', '.join(bad)}")
    claims = [verify(c, repo, refs) for c in extract(text, diff)]
    counts = {v: sum(1 for c in claims if c.verdict == v) for v in (VERIFIED, MISMATCH, UNRESOLVED)}
    seen = sum(len(_VERSION_LIKE.findall(ln)) for _, ln in iter_lines(text, diff))
    unparsed = max(0, seen - sum(1 for c in claims if c.kind == "VERSION"))
    code = 3 if counts[MISMATCH] else 2 if counts[UNRESOLVED] else 0
    shown = []
    for c in claims:
        d = asdict(c)
        for k in ("target", "detail", "evidence"):
            d[k] = mask(d[k], 200)  # raw lookup values stay internal; every displayed string is masked
        shown.append(d)
    return {"refs": refs, "claims": shown, "counts": counts,
            "exit": code, "masking": MASKING_MODE, "unparsed_version_mentions": unparsed,
            "note": ("no verifiable claims found — this is NOT a pass of anything" if not claims else "")
                    + (f" {unparsed} version-like mention(s) not tied to an anchor — review manually"
                       if unparsed else "")}


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("file", nargs="?", default="-", help="text file, or - for stdin")
    ap.add_argument("--repo", default=".")
    ap.add_argument("--ref", action="append", help="commit-ish to check against (repeatable; default HEAD). "
                    "For a PR pass base AND head: a path the PR adds exists only at head.")
    ap.add_argument("--diff", action="store_true", help="input is a unified diff: only added lines are scanned")
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    try:
        text = sys.stdin.read() if a.file == "-" else pathlib.Path(a.file).read_text(errors="replace")
        rep = run(text, a.repo, a.ref or ["HEAD"], a.diff)
    except (OSError, ValueError) as e:
        print(f"ref-claim-verify: {e}", file=sys.stderr)
        return 1
    if a.json:
        print(json.dumps(rep, ensure_ascii=False, indent=2))
    else:
        for c in rep["claims"]:
            print(f"{c['verdict']:<10} {c['kind']:<7} L{c['line']:<4} {c['target']} {c['detail']}  — {c['evidence']}")
        print(f"\n{rep['counts']}  masking={rep['masking']}  {rep['note']}".rstrip())
    return rep["exit"]


if __name__ == "__main__":
    sys.exit(main())
