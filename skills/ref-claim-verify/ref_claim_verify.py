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
_SEMVER = r"\d+\.\d+(?:\.\d+)?(?:[-+][0-9A-Za-z][0-9A-Za-z.\-+]*)?(?![0-9A-Za-z_]|\.[0-9A-Za-z])"
_PATH_TOKEN = re.compile(r"`([A-Za-z0-9_./\-]+\.%s)(?::\d+)?(?:#[\w\-]+)?`" % _EXT)
_SECTION = re.compile(
    r"`([A-Za-z0-9_./\-]+\.%s)`[ \t]{0,3}(?:[,\u2014(\-][ \t]{0,3})?\u00a7[ \t]?([A-Za-z0-9][A-Za-z0-9.\-]*)" % _EXT
)
_VERSION = re.compile(
    r"(?P<anchor>`?\[[A-Za-z][A-Za-z0-9._\-]{0,23}\]`?(?!\()|`[A-Za-z0-9_./\-]+\.%s`)"
    r"[ \t]{0,3}(?:[,:][ \t]{0,3})?(?:v|version[ \t]{1,3}v?|vers\u00e3o[ \t]{1,3}v?)(?P<ver>%s)" % (_EXT, _SEMVER),
    re.IGNORECASE,
)
_DECL_HEAD = re.compile(r"^(?:>[ \t]*)?(?:\*\*)?(?:version|vers\u00e3o)(?:\*\*)?[ \t]*:", re.IGNORECASE)


def _decl_version(ln: str) -> str | None:
    """Version declared by a `Version:` / `**Versão**:` line, parsed in linear time."""
    m = _DECL_HEAD.match(ln)
    if not m:
        return None
    rest = ln[m.end():].lstrip(" \t")
    if rest.startswith("**"):
        rest = rest[2:].lstrip(" \t")
    elif rest[:1] in ("\"", "'"):
        rest = rest[1:]
    if rest[:1] in ("v", "V"):
        rest = rest[1:]
    mv = re.match(_SEMVER, rest)
    return mv.group(0) if mv else None


_FENCE = re.compile(r"^ {0,3}(```|~~~)")
_FM_VERSION = re.compile(r"(?i)^(?:version|vers\u00e3o)[ \t]*:[ \t]*(.*?)[ \t]*$")
_ATX = re.compile(r"^ {0,3}#{1,6}(?:[ \t]|$)")
MAX_LINE = 4000          # claim extraction from prose input (skipped + counted when longer)
MAX_BLOB_LINE = 1_000_000  # safety net for git blobs; every pass below is linear
_VERSION_LIKE = re.compile(r"\bv\d+\.\d+(?:\.[0-9A-Za-z]+)*(?:[-+][0-9A-Za-z.\-+]*)?", re.IGNORECASE)
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
_CREDS = (
    (re.compile(r"\b(?:AKIA|ASIA)[0-9A-Z]{12,}\b"), "[CREDENTIAL]"),
    (re.compile(r"\bgh[pousr]_[A-Za-z0-9]{20,}\b"), "[CREDENTIAL]"),
    (re.compile(r"\bxox[abprs]-[A-Za-z0-9\-]{10,}\b"), "[CREDENTIAL]"),
    (re.compile(r"\bsk-[A-Za-z0-9_\-]{16,}\b"), "[CREDENTIAL]"),
    (re.compile(r"\beyJ[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\.[A-Za-z0-9_\-]{8,}\b"), "[CREDENTIAL]"),
    (re.compile(r"(?i)\b([A-Za-z0-9_]*(?:secret|token|passw(?:or)?d|api[_-]?key|access[_-]?key[_-]?id)[A-Za-z0-9_]*)[\"']?[ \t]*[=:][ \t]*"
                r"(?:\"[^\"\n]*(?:\"|$)|'[^'\n]*(?:'|$)|\S+)"),
     r"\1=[REDACTED]"),
)
_FALLBACK = (  # degraded masking: coarser than pii-masking, but never lets these shapes through
    (re.compile(r"[\w.+\-]+@[\w\-]+\.[\w.\-]+"), "[EMAIL]"),
    (re.compile(r"\b\d{3}\.?\d{3}\.?\d{3}-?\d{2}\b"), "[CPF]"),
    (re.compile(r"(?<![\w.])\+\d[\d ().\-]{7,}\d"), "[PHONE]"),
    (re.compile(r"(?<![\w.\-])\(?\d{2,3}\)?[ .\-]\d{3,4}[ .\-]\d{4}(?![\w\-])"), "[PHONE]"),
)
MASKING_MODE = "pii-masking" if _PII is not None else "fallback"


def _fallback_mask(line: str) -> str:
    for rx, rep in _CREDS + _FALLBACK:
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
            continue  # bounded work per line (ReDoS guard); never scan a truncated claim
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
_OPEN_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})(.*)$")
_CLOSE_FENCE = re.compile(r"^ {0,3}(`{3,}|~{3,})[ \t]*$")
_QUOTE = re.compile(r"^ {0,3}(?:> ?)+")
_SETEXT = re.compile(r"^ {0,3}(?:=+|-+)[ \t]*$")
_THEMATIC = re.compile(r"^ {0,3}(?:(?:\*[ \t]*){3,}|(?:_[ \t]*){3,})$")
_COMMENT_PAIR = re.compile(r"<!--.*?-->")
_CODE_SPAN = re.compile(r"`[^`\n]*`")


class AmbiguousStructure(Exception):
    """The Markdown structure cannot be read unambiguously; callers must answer UNRESOLVED."""


_HTML_RAW = re.compile(r"^ {0,3}<(pre|script|style|textarea)(?=[\s>]|$)", re.IGNORECASE)
_HTML_BLOCK = re.compile(r"^ {0,3}</?[A-Za-z][A-Za-z0-9-]*(?=[\s/>]|$)")


def _outside_fences(content: str) -> list[str]:
    """Lines that are neither inside a fenced code block, an HTML comment/block nor a code span.

    Fences follow CommonMark (same char, closer >= opener, indent <= 3, no info string; also
    inside blockquotes). Comments are scanned sequentially and linearly: nesting, a stray closer
    or an unterminated comment/fence is AMBIGUOUS (raise) — never silently accepted. Inline-code
    mentions of `<!--` are not comments, but inside a real comment nothing is code. Multi-line
    code spans (CommonMark backtick-run matching) are dropped; a backtick run that never closes
    before the paragraph ends, or a block construct inside an open span, is AMBIGUOUS. Raw HTML
    blocks (`<pre>`/`<script>`/`<style>`/`<textarea>` until their closer; any other block tag
    until a blank line) are not Markdown metadata and are dropped. A line longer than MAX_BLOB_LINE
    is AMBIGUOUS (safety bound; every pass is linear below it).
    """
    out: list[str] = []
    fence: tuple[str, int] | None = None
    in_comment = False
    span: int | None = None  # length of the open backtick run
    html_end: re.Pattern | str | None = None  # compiled closer for raw blocks, "blank" otherwise
    for raw in content.splitlines():
        if len(raw) > MAX_BLOB_LINE:
            raise AmbiguousStructure("line longer than the safety bound")
        ln = raw
        if not ln.strip():
            if span is not None:
                raise AmbiguousStructure("backtick run never closed before the paragraph ended")
            if html_end == "blank":
                html_end = None
        if in_comment:
            if "<!--" in ln.split("-->", 1)[0]:
                raise AmbiguousStructure("nested HTML comment")
            if "-->" not in ln:
                continue
            in_comment = False
            ln = ln[ln.index("-->") + 3 :]
        scan = _CODE_SPAN.sub(lambda m: m.group().replace("<", "_").replace(">", "_"), ln)
        pieces: list[str] = []
        spieces: list[str] = []
        i = 0
        while True:  # linear: one forward pass with find(), pieces joined once
            s0 = scan.find("<!--", i)
            e0 = scan.find("-->", s0 + 4) if s0 >= 0 else -1
            if s0 < 0 or e0 < 0:
                pieces.append(ln[i:])
                spieces.append(scan[i:])
                break
            if "<!--" in scan[s0 + 4 : e0]:
                raise AmbiguousStructure("nested HTML comment")
            pieces.append(ln[i:s0])
            spieces.append(scan[i:s0])
            i = e0 + 3
        ln, scan = "".join(pieces), "".join(spieces)
        if "<!--" in scan:
            if "<!--" in scan[scan.index("<!--") + 4 :]:
                raise AmbiguousStructure("nested HTML comment")
            in_comment = True
            ln = ln[: scan.index("<!--")]
        elif "-->" in scan:
            raise AmbiguousStructure("stray HTML comment closer")
        core = _QUOTE.sub("", ln) if ln.lstrip().startswith(">") else ln
        if fence is not None:
            m = _CLOSE_FENCE.match(core)
            if m and m.group(1)[0] == fence[0] and len(m.group(1)) >= fence[1]:
                fence = None
            continue
        if html_end is not None:
            if isinstance(html_end, re.Pattern):
                if html_end.search(core):
                    html_end = None
                continue
            if core.strip():
                continue  # inside a blank-terminated HTML block
        m = _OPEN_FENCE.match(core)
        if m and not (m.group(1)[0] == "`" and "`" in m.group(2)):
            if span is not None:
                raise AmbiguousStructure("fence inside an open code span")
            fence = (m.group(1)[0], len(m.group(1)))
            continue
        if span is not None and (_ATX.match(ln) or _THEMATIC.match(ln)):
            raise AmbiguousStructure("block construct inside an open code span")
        if span is None and core.strip():
            mr = _HTML_RAW.match(core)
            if mr:
                closer = re.compile(r"</%s\s*>" % mr.group(1), re.IGNORECASE)
                if not closer.search(core[mr.end() :]):
                    html_end = closer
                continue
            if _HTML_BLOCK.match(core):
                html_end = "blank"
                continue
        starts_in_span = span is not None
        for run in re.findall(r"`+", core):
            if span is None:
                span = len(run)
            elif len(run) == span:
                span = None
        if not starts_in_span:
            out.append(ln)
    if in_comment or fence is not None or span is not None or isinstance(html_end, re.Pattern):
        raise AmbiguousStructure("unterminated comment, fence, code span or HTML block")
    return out


def _heading_tokens(content: str) -> tuple[set[str], bool]:
    toks: set[str] = set()
    for ln in _outside_fences(content):
        if _ATX.match(ln):
            for t in re.findall(r"(?:\u00a7[ \t]?)?([A-Za-z]?\d+(?:\.\d+)*[A-Za-z]?)", ln):
                toks.add(t.strip())
    return toks, bool(toks)


def declared_versions(content: str) -> list[str]:
    """Versions a file (or section) declares for itself, ignoring code and comments.

    YAML frontmatter, when present, is the authoritative declaration."""
    lines = content.splitlines()
    if lines and lines[0].strip() == "---":
        end = next((j for j in range(1, min(len(lines), 200)) if lines[j].strip() == "---"), None)
        if end is None:
            return []  # unterminated frontmatter: nothing is authoritative -> UNRESOLVED upstream
        vals: list[str] = []
        for fl in lines[1:end]:
            mf = _FM_VERSION.match(fl)
            if not mf:
                continue
            v = re.sub(r"[ \t]+#.*$", "", mf.group(1)).strip()
            if len(v) >= 2 and v[0] == v[-1] and v[0] in "\"'":
                v = v[1:-1].strip()
            v = v[1:] if v[:1] in "vV" else v
            if not re.fullmatch(_SEMVER, v):  # whole value must be the version, not just a prefix
                raise AmbiguousStructure("frontmatter version is not a clean version string")
            vals.append(v)
        if vals:
            return sorted(set(vals))
        content = "\n".join(lines[end + 1 :])
    found_set: set[str] = set()
    for ln in _outside_fences(content):
        if "|" in ln:
            continue  # a table row is not authoritative metadata
        v = _decl_version(ln)
        if v:
            found_set.add(v)
    return sorted(found_set)


def _heading_windows(content: str, anchor: str) -> list[str]:
    """Text after EVERY heading that carries the anchor, each ending at the next boundary.

    Boundaries: another ATX heading, a Setext underline (the line above it is that
    heading's title and is dropped), a thematic break. A bare mention of the anchor in
    prose is ignored. Every matching heading is returned so duplicates can conflict.
    """
    lines = _outside_fences(content)
    wins: list[str] = []
    for i, ln in enumerate(lines):
        if _ATX.match(ln) and anchor in ln:
            win: list[str] = []
            for nxt in lines[i + 1 :]:
                if _ATX.match(nxt) or _THEMATIC.match(nxt):
                    break
                if _SETEXT.match(nxt):
                    if win:
                        win.pop()  # that line was the title of the next (setext) heading
                    break
                win.append(nxt)
            wins.append("\n".join(win))
    return wins


ANCHOR_FILE_CAP = 50


def _anchor_files(repo: str, refs: list[str], anchor: str) -> tuple[list[tuple[str, str]], bool]:
    """(ref, path) of tracked .md files whose heading carries [ID]; second item = cap exceeded."""
    hits: list[tuple[str, str]] = []
    overflow = False
    for r in refs:
        esc = "".join("\\" + ch if ch in "[]().*+?^$|{}\\" else ch for ch in anchor)
        pat = r"^ {0,3}#{1,6}[ \t].*" + esc  # only files whose HEADING carries the anchor
        rc, out = _git(repo, "grep", "-l", "-E", "-e", pat, r, "--", "*.md")
        if rc != 0:
            continue
        rows = out.splitlines()
        overflow = overflow or len(rows) > ANCHOR_FILE_CAP
        for ln in rows[:ANCHOR_FILE_CAP]:
            ref, _, path = ln.partition(":")
            hits.append((ref, path))
    return hits, overflow


def verify(c: Claim, repo: str, refs: list[str]) -> Claim:
    try:
        return _verify(c, repo, refs)
    except AmbiguousStructure as e:
        c.verdict, c.evidence = UNRESOLVED, f"ambiguous markdown structure ({e})"
        return c


def _verify(c: Claim, repo: str, refs: list[str]) -> Claim:
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
        by_ref: dict[str, set[str]] = {}
        overflow = False
        if c.target.startswith("["):
            hits, overflow = _anchor_files(repo, refs, c.target)
            for r, pth in hits:
                for w in _heading_windows(blob(repo, r, pth) or "", c.target):
                    by_ref.setdefault(r, set()).update(declared_versions(w))
        else:
            for r in refs:
                by_ref.setdefault(r, set()).update(declared_versions(blob(repo, r, c.target) or ""))
        c.declared = sorted({v for vs in by_ref.values() for v in vs})
        resolved = {r: next(iter(vs)) for r, vs in by_ref.items() if len(vs) == 1}
        conflicted = [r for r, vs in by_ref.items() if len(vs) > 1]
        if any(v == c.detail for v in resolved.values()) and not overflow:
            c.verdict, c.evidence = VERIFIED, f"declared {','.join(c.declared)}"
        elif overflow:
            c.verdict, c.evidence = UNRESOLVED, f"more than {ANCHOR_FILE_CAP} files mention the anchor"
        elif conflicted:
            c.verdict, c.evidence = UNRESOLVED, f"conflicting declarations at {','.join(conflicted)}"
        elif not resolved:
            c.verdict, c.evidence = UNRESOLVED, "no heading carrying the anchor with a declared version"
        else:
            c.verdict, c.evidence = MISMATCH, f"claimed v{c.detail}; declared {','.join(c.declared)}"
    return c


def _mask_obj(o, key: str = ""):
    if isinstance(o, str):
        if key == "refs" and re.fullmatch(r"[0-9a-fA-F]{7,64}", o):
            return o
        return mask(o, 200)
    if isinstance(o, list):
        return [_mask_obj(x, key) for x in o]
    if isinstance(o, dict):
        return {k: (v if k == "masking" else _mask_obj(v, k)) for k, v in o.items()}
    return o


def run(text: str, repo: str, refs: list[str], diff: bool = False) -> dict:
    bad = [r for r in refs if not valid_ref(repo, r)]
    if bad:
        raise ValueError(f"unknown ref(s): {', '.join(bad)}")
    claims = [verify(c, repo, refs) for c in extract(text, diff)]
    counts = {v: sum(1 for c in claims if c.verdict == v) for v in (VERIFIED, MISMATCH, UNRESOLVED)}
    seen = sum(len(_VERSION_LIKE.findall(ln)) for _, ln in iter_lines(text, diff))
    unparsed = max(0, seen - sum(1 for c in claims if c.kind == "VERSION"))
    code = 3 if counts[MISMATCH] else 2 if counts[UNRESOLVED] else 0
    skipped = sum(1 for ln in text.splitlines() if len(ln) > MAX_LINE)
    rep = {"refs": refs, "claims": [asdict(c) for c in claims], "counts": counts,
           "exit": code, "masking": MASKING_MODE, "unparsed_version_mentions": unparsed,
           "skipped_long_lines": skipped,
           "note": ("no verifiable claims found — this is NOT a pass of anything" if not claims else "")
                   + (f" {unparsed} version-like mention(s) not tied to an anchor — review manually" if unparsed else "")
                   + (f" {skipped} line(s) over {MAX_LINE} chars were skipped, not verified" if skipped else "")}
    return _mask_obj(rep)  # raw lookup values stay internal; EVERY serialized string is masked


class _MaskedParser(argparse.ArgumentParser):
    def error(self, message):  # argparse echoes raw argv in diagnostics; never let it leak PII
        print(f"ref-claim-verify: {mask(message)}", file=sys.stderr)
        raise SystemExit(1)


def main(argv: list[str] | None = None) -> int:
    ap = _MaskedParser(description=__doc__.split("\n\n")[0])
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
        print(f"ref-claim-verify: {mask(str(e))}", file=sys.stderr)
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
