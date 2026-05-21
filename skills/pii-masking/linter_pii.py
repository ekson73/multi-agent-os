"""PII Masking Linter — Synchronous CI-time detection.

Closes Gap G1 of the OS3PD manifesto v4.13.0 (Principle 6: Respect Wildlife).
Wires the `.github/workflows/ai-governance-linter.yml` step that was declared
with a placeholder comment in v1.0.

Detectors:
    - CPF (Brazilian individual taxpayer ID) — Modulo-11 algorithmic checksum
      (NOT just regex), with anti-fraud all-same-digit rejection.
    - Email — RFC 5322 SAFE subset; catastrophic-backtracking-safe regex
      (no nested quantifiers).
    - Phone — Brazilian E.164 format (+55 + 2-digit area code + 8 or 9 digits).

Allowlist (anti-false-positive on developer artifacts):
    - localhost@127.0.0.1
    - noreply@github.com
    - test@example.com
    - *@example.com, *@example.org, *@example.net

Output guarantees:
    - Structured records: {file, line, type, masked_excerpt}.
    - Raw PII NEVER appears in stdout, stderr, or any logged output.
    - Excerpts mask the matched value before formatting.

CLI:
    python -m linter_pii --paths GLOB [--paths GLOB ...] [--fail-on-match]

Exit codes:
    0 — no PII detected (or PII detected without --fail-on-match)
    1 — PII detected AND --fail-on-match set
    2 — invocation / argument error
"""

from __future__ import annotations

import argparse
import dataclasses
import fnmatch
import json
import pathlib
import re
import sys
from collections.abc import Iterable, Iterator


# ── Allowlist ──────────────────────────────────────────────────────────────

EMAIL_ALLOWLIST_EXACT = frozenset(
    {
        "localhost@127.0.0.1",
        "noreply@github.com",
        "test@example.com",
        # AI-agent Co-Authored-By addresses (noreply bot emails, not personal data).
        "noreply@anthropic.com",
        "noreply+claude-code@anthropic.com",
        # SSH git remote URLs (shape: git@<host>:<path>). The regex captures
        # the `git@<host>` prefix and stops at the `:`, so these match as
        # "emails" but are not personal information.
        "git@github.com",
        "git@gitlab.com",
        "git@bitbucket.org",
        "git@codeberg.org",
        # README/documentation placeholder (template, not personal data).
        "your-email@company.com",
    }
)

# Wildcards stored as the suffix that must match after `@`.
EMAIL_ALLOWLIST_SUFFIX = (
    "@example.com",
    "@example.org",
    "@example.net",
)

# Files under any of these path segments are treated as fixture/sample scope:
# matches inside them still emit a record (the linter must remain honest),
# but the CI step can choose to soften severity for these paths via globs.
FIXTURE_PATH_SEGMENTS = ("/tests/", "/fixtures/", "/sample_data/", "/__pycache__/")


# ── Regexes (precompiled, catastrophic-backtracking-safe) ──────────────────

# CPF: 11 digits, optionally formatted as DDD.DDD.DDD-DD.
# Match either the formatted shape OR a bare 11-digit run that is NOT part of
# a longer digit run (negative lookarounds at both ends).
_CPF_RE = re.compile(
    r"(?<!\d)"
    r"(?P<cpf>"
    r"\d{3}\.\d{3}\.\d{3}-\d{2}"
    r"|"
    r"\d{11}"
    r")"
    r"(?!\d)"
)

# RFC 5322 SAFE subset. Local part: letters/digits/dot/underscore/percent/
# plus/hyphen (no consecutive dots; no leading/trailing dot enforced via
# bounded length classes — anti-backtracking). Domain: at least one dot;
# TLD between 2 and 24 chars (no `email@interface`-style false positives).
_EMAIL_RE = re.compile(
    r"(?<![\w.+-])"
    r"(?P<email>"
    r"[A-Za-z0-9_%+\-]+(?:\.[A-Za-z0-9_%+\-]+){0,4}"
    r"@"
    r"(?:[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?\.){1,4}"
    r"[A-Za-z]{2,24}"
    r")"
    r"(?![\w.])"
)

# Brazilian phone E.164: +55 + 2-digit area code (DD ∈ 11-99) + 8 or 9 digits.
# Allow optional separator characters (space, dot, hyphen, parens) between
# country code, area code, and number; reject sequences that are pure-digit
# 11-digit runs (those collide with CPF and are usually CPFs in disguise).
_PHONE_BR_RE = re.compile(
    r"(?<!\d)"
    r"(?P<phone>"
    r"\+55"
    r"[\s.\-]?"
    r"\(?(?P<ddd>[1-9][1-9])\)?"
    r"[\s.\-]?"
    r"(?P<num>9?\d{4}[\s.\-]?\d{4})"
    r")"
    r"(?!\d)"
)


# ── Data model ─────────────────────────────────────────────────────────────


@dataclasses.dataclass(frozen=True)
class Finding:
    """One PII detection event.

    The `masked_excerpt` field is constructed so that the raw PII never
    appears verbatim; consumers (CI logs, JSON exports) only see the
    masked form.
    """

    file: str
    line: int
    pii_type: str
    masked_excerpt: str

    def as_dict(self) -> dict[str, object]:
        return dataclasses.asdict(self)


# ── Masking helpers ────────────────────────────────────────────────────────


def _mask_cpf(value: str) -> str:
    """Reduce a CPF to its first 3 and last 2 digits — the rest is `*`."""
    digits = re.sub(r"\D", "", value)
    if len(digits) != 11:
        return "[CPF]"
    return f"{digits[:3]}.***.***-{digits[-2:]}"


def _mask_email(value: str) -> str:
    """Show the first letter of the local part and the full domain."""
    if "@" not in value:
        return "[EMAIL]"
    local, _, domain = value.partition("@")
    if not local:
        return f"@{domain}"
    return f"{local[0]}***@{domain}"


def _mask_phone(value: str) -> str:
    """Show only country code + area code, mask the rest."""
    digits = re.sub(r"\D", "", value)
    if digits.startswith("55") and len(digits) >= 4:
        return f"+55 {digits[2:4]} ****-****"
    return "[PHONE]"


def _trim_excerpt(masked_line: str, max_len: int = 200) -> str:
    """Trim a fully-masked line to a manageable length for CI logs.

    Centers the window around any masking marker (`***` or `[`) so the reader
    sees the relevant context. Adds ellipses on either side when truncated.
    """
    stripped = masked_line.strip()
    if len(stripped) <= max_len:
        return stripped
    marker_idx = stripped.find("***")
    if marker_idx < 0:
        marker_idx = stripped.find("[")
    if marker_idx < 0:
        return stripped[:max_len] + "…"
    half = max_len // 2
    start = max(0, marker_idx - half + 20)
    end = min(len(stripped), marker_idx + half + 20)
    prefix = "…" if start > 0 else ""
    suffix = "…" if end < len(stripped) else ""
    return f"{prefix}{stripped[start:end].strip()}{suffix}"


def _fully_mask_line(line: str, replacements: list[tuple[str, str]]) -> str:
    """Apply every (raw → masked) replacement on the line.

    Replacements are sorted by raw length descending so longer overlaps win.
    Idempotent under repeated application: once a raw token is replaced, the
    masked form does not match any subsequent raw pattern.
    """
    out = line
    for raw, masked in sorted(replacements, key=lambda pair: -len(pair[0])):
        if raw and raw in out:
            out = out.replace(raw, masked)
    return out


# ── CPF Modulo-11 validation ───────────────────────────────────────────────


def is_valid_cpf(value: str) -> bool:
    """Return True iff `value` is a structurally valid Brazilian CPF.

    Implements the Brazilian Receita Federal Modulo-11 checksum AND rejects
    the well-known anti-fraud sentinels (all-same-digit runs).
    """
    digits = re.sub(r"\D", "", value)
    if len(digits) != 11:
        return False
    # Anti-fraud: Receita Federal rejects all-same-digit CPFs.
    if len(set(digits)) == 1:
        return False

    def _checksum(digit_count: int) -> int:
        total = sum(
            int(digits[i]) * (digit_count + 1 - i) for i in range(digit_count)
        )
        remainder = total % 11
        return 0 if remainder < 2 else 11 - remainder

    d1 = _checksum(9)
    d2 = _checksum(10)
    return d1 == int(digits[9]) and d2 == int(digits[10])


# ── Email allowlist ────────────────────────────────────────────────────────


def is_allowlisted_email(value: str) -> bool:
    lowered = value.lower()
    if lowered in EMAIL_ALLOWLIST_EXACT:
        return True
    return any(lowered.endswith(suffix) for suffix in EMAIL_ALLOWLIST_SUFFIX)


# ── Core scanner ───────────────────────────────────────────────────────────


def _iter_cpf_matches(line: str) -> Iterator[tuple[str, str]]:
    """Yield (raw_match, masked) for each VALID CPF on the line."""
    for m in _CPF_RE.finditer(line):
        raw = m.group("cpf")
        if is_valid_cpf(raw):
            yield raw, _mask_cpf(raw)


def _iter_email_matches(line: str) -> Iterator[tuple[str, str]]:
    """Yield (raw_match, masked) for each email that is NOT allowlisted."""
    for m in _EMAIL_RE.finditer(line):
        raw = m.group("email")
        if not is_allowlisted_email(raw):
            yield raw, _mask_email(raw)


def _iter_phone_matches(line: str) -> Iterator[tuple[str, str]]:
    """Yield (raw_match, masked) for each E.164-BR phone on the line."""
    seen_spans: list[tuple[int, int]] = []
    for m in _PHONE_BR_RE.finditer(line):
        span = m.span()
        if any(start <= span[0] and span[1] <= end for start, end in seen_spans):
            continue
        seen_spans.append(span)
        raw = m.group("phone")
        yield raw, _mask_phone(raw)


def scan_text(file_path: str, text: str) -> list[Finding]:
    """Scan a single text blob for all three PII categories.

    Excerpts use a single fully-masked version of the source line so that
    a finding for one PII type cannot leak a different PII type on the same
    line into the output.
    """
    findings: list[Finding] = []
    for line_no, line in enumerate(text.splitlines(), start=1):
        cpfs = list(_iter_cpf_matches(line))
        emails = list(_iter_email_matches(line))
        phones = list(_iter_phone_matches(line))

        if not (cpfs or emails or phones):
            continue

        masked_line = _fully_mask_line(line, cpfs + emails + phones)
        excerpt = _trim_excerpt(masked_line)

        for _ in cpfs:
            findings.append(
                Finding(file=file_path, line=line_no, pii_type="cpf", masked_excerpt=excerpt)
            )
        for _ in emails:
            findings.append(
                Finding(file=file_path, line=line_no, pii_type="email", masked_excerpt=excerpt)
            )
        for _ in phones:
            findings.append(
                Finding(file=file_path, line=line_no, pii_type="phone_br", masked_excerpt=excerpt)
            )
    return findings


def scan_file(path: pathlib.Path) -> list[Finding]:
    """Read a file safely and scan its text."""
    try:
        text = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return []
    return scan_text(str(path), text)


# ── Glob expansion ─────────────────────────────────────────────────────────


def _expand_globs(
    globs: Iterable[str],
    root: pathlib.Path,
    excludes: Iterable[str] = (),
) -> Iterator[pathlib.Path]:
    """Expand each glob relative to root, yielding regular files only.

    Supports `**` for recursive matching via pathlib.Path.glob.
    Skips paths under `.git/`, `.worktrees/`, `node_modules/`, and
    `__pycache__/`. Any path matching one of the `excludes` glob patterns
    (relative to `root`) is also skipped.
    """
    skip_segments = (".git", ".worktrees", "node_modules", "__pycache__")
    exclude_patterns = tuple(excludes)
    seen: set[pathlib.Path] = set()
    for pattern in globs:
        # Reject absolute patterns by design — scope linter to the repo.
        normalized = pattern.lstrip("./")
        for match in root.glob(normalized):
            if not match.is_file():
                continue
            if any(seg in match.parts for seg in skip_segments):
                continue
            rel_path = match.relative_to(root).as_posix()
            if any(fnmatch.fnmatch(rel_path, exc) for exc in exclude_patterns):
                continue
            resolved = match.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            yield match


# ── CLI ────────────────────────────────────────────────────────────────────


def _format_text(findings: list[Finding]) -> str:
    lines = []
    for f in findings:
        lines.append(f"{f.file}:{f.line}: [{f.pii_type}] {f.masked_excerpt}")
    return "\n".join(lines)


def _format_json(findings: list[Finding]) -> str:
    return json.dumps([f.as_dict() for f in findings], indent=2, ensure_ascii=False)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="linter_pii",
        description="Synchronous PII detector (CPF / email / phone-BR).",
    )
    parser.add_argument(
        "--paths",
        action="append",
        required=True,
        help="Glob pattern(s) relative to --root. Use --paths multiple times.",
    )
    parser.add_argument(
        "--root",
        default=".",
        help="Repository root the glob patterns are resolved against (default: cwd).",
    )
    parser.add_argument(
        "--format",
        choices=("text", "json"),
        default="text",
        help="Output format (default: text).",
    )
    parser.add_argument(
        "--exclude",
        action="append",
        default=[],
        help=(
            "Glob pattern (relative to --root) to skip during scanning. "
            "Repeatable. Example: --exclude 'docs/**' --exclude '**/tests/**'."
        ),
    )
    parser.add_argument(
        "--fail-on-match",
        action="store_true",
        help="Exit 1 when any PII is detected (default: exit 0).",
    )

    args = parser.parse_args(argv)

    root = pathlib.Path(args.root).resolve()
    if not root.is_dir():
        sys.stderr.write(f"linter_pii: --root is not a directory: {root}\n")
        return 2

    all_findings: list[Finding] = []
    for path in _expand_globs(args.paths, root, args.exclude):
        all_findings.extend(scan_file(path))

    if all_findings:
        output = _format_json(all_findings) if args.format == "json" else _format_text(all_findings)
        # findings already masked — safe to print
        print(output)

    if args.fail_on_match and all_findings:
        sys.stderr.write(
            f"linter_pii: {len(all_findings)} PII finding(s) detected; "
            "see output above (excerpts are masked).\n"
        )
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
