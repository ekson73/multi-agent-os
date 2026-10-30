#!/usr/bin/env python3
"""Scoped PII check for skills/transcript-corrector.

Reuses skills/pii-masking/linter_pii.py for real-looking emails, CPF values
with a valid check digit, and Brazilian phone numbers. Separately fails when
a salted hash of a token window matches the removed-name denylist.

The denylist stores hashes only. This script never prints a matched name,
address, or CPF.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import sys
import unicodedata
from pathlib import Path

TOKEN_RE = re.compile(r"[^\W\d_]+", re.UNICODE)
MAX_WINDOW = 6
TEXT_SUFFIXES = {
    ".md",
    ".yaml",
    ".yml",
    ".json",
    ".py",
    ".sh",
    ".txt",
    ".toml",
}

SCRIPT_PATH = Path(__file__).resolve()
SKILL_DIR = SCRIPT_PATH.parents[1]
REPO_ROOT = SCRIPT_PATH.parents[3]
DEFAULT_DENYLIST = SKILL_DIR / "ci" / "removed-name-denylist.json"


def normalize(value: str) -> str:
    folded = unicodedata.normalize("NFKC", value).casefold()
    return re.sub(r"\s+", " ", folded).strip()


def window_forms(tokens: list[str]) -> list[str]:
    """Space-joined window plus the hyphen/apostrophe-joined forms a sealed name may use."""
    forms = [" ".join(tokens)]
    if len(tokens) > 1:
        forms.append("-".join(tokens))
        forms.append("'".join(tokens))
    return forms


def digest(salt: str, value: str) -> str:
    payload = salt + "\n" + normalize(value)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def seal(names: list[str], salt: str) -> list[str]:
    """Return sorted unique salted hashes. Callers must not log `names`."""
    return sorted({digest(salt, name) for name in names if normalize(name)})


def load_denylist(path: Path) -> tuple[str, set[str]]:
    data = json.loads(path.read_text(encoding="utf-8"))
    if data.get("algorithm") != "sha256":
        raise ValueError("denylist algorithm must be sha256")
    salt = data.get("salt")
    hashes = data.get("hashes")
    if not isinstance(salt, str) or not re.fullmatch(r"[0-9a-f]{32,128}", salt):
        raise ValueError("denylist salt must be hex")
    if not isinstance(hashes, list) or not hashes:
        raise ValueError("denylist hashes must be a non-empty list")
    cleaned: set[str] = set()
    for item in hashes:
        if not isinstance(item, str) or not re.fullmatch(r"[0-9a-f]{64}", item):
            raise ValueError("denylist entry is not a sha256 hex digest")
        cleaned.add(item)
    return salt, cleaned


def name_hit_lines(text: str, salt: str, hashes: set[str]) -> list[int]:
    """Return 1-based line numbers whose token windows match the denylist."""
    hits: list[int] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        folded = [normalize(token) for token in TOKEN_RE.findall(line)]
        folded = [token for token in folded if token]
        matched = False
        upper = min(MAX_WINDOW, len(folded))
        for size in range(1, upper + 1):
            for index in range(len(folded) - size + 1):
                window = folded[index : index + size]
                if any(digest(salt, form) in hashes for form in window_forms(window)):
                    matched = True
                    break
            if matched:
                break
        if matched:
            hits.append(lineno)
    return hits


def iter_skill_files(skill_dir: Path) -> list[Path]:
    files: list[Path] = []
    for path in sorted(skill_dir.rglob("*")):
        if not path.is_file():
            continue
        if any(part in {".git", "__pycache__"} for part in path.parts):
            continue
        if path.suffix.lower() not in TEXT_SUFFIXES:
            continue
        files.append(path)
    return files


def scan_removed_names(skill_dir: Path, denylist_path: Path) -> list[str]:
    salt, hashes = load_denylist(denylist_path)
    findings: list[str] = []
    for path in iter_skill_files(skill_dir):
        text = path.read_text(encoding="utf-8", errors="replace")
        for lineno in name_hit_lines(text, salt, hashes):
            rel = path.relative_to(skill_dir)
            findings.append(f"{rel}:{lineno}: denied-name")
    return findings


def _load_linter():
    linter_path = REPO_ROOT / "skills" / "pii-masking" / "linter_pii.py"
    spec = importlib.util.spec_from_file_location("linter_pii", linter_path)
    if spec is None or spec.loader is None:
        raise RuntimeError("cannot load linter_pii.py")
    module = importlib.util.module_from_spec(spec)
    # dataclasses reads sys.modules[cls.__module__] while the class body runs.
    sys.modules["linter_pii"] = module
    spec.loader.exec_module(module)
    return module


def scan_linter(repo_root: Path, skill_dir: Path = SKILL_DIR) -> int:
    """Run the existing PII linter over the same skill dir and suffixes. Return its exit code."""
    linter = _load_linter()
    try:
        rel = skill_dir.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError:
        sys.stderr.write("check-pii-scope: --skill-dir must be inside --repo-root\n")
        return 2
    patterns = []
    for suffix in sorted(s.lstrip(".") for s in TEXT_SUFFIXES):
        patterns.append("--paths")
        patterns.append(f"{rel}/**/*.{suffix}")
        patterns.append("--paths")
        patterns.append(f"{rel}/*.{suffix}")
    return linter.main(
        [
            *patterns,
            "--root",
            str(repo_root),
            "--fail-on-match",
        ]
    )


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--skill-dir", type=Path, default=SKILL_DIR)
    parser.add_argument("--denylist", type=Path, default=DEFAULT_DENYLIST)
    parser.add_argument("--repo-root", type=Path, default=REPO_ROOT)
    parser.add_argument(
        "--names-only",
        action="store_true",
        help="Skip the email/CPF linter (unit tests).",
    )
    args = parser.parse_args(argv)

    skill_dir = args.skill_dir.resolve()
    denylist = args.denylist.resolve()
    repo_root = args.repo_root.resolve()
    if not skill_dir.is_dir():
        sys.stderr.write("check-pii-scope: skill directory missing\n")
        return 2
    if not denylist.is_file():
        sys.stderr.write("check-pii-scope: denylist missing\n")
        return 2

    try:
        name_findings = scan_removed_names(skill_dir, denylist)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        sys.stderr.write(f"check-pii-scope: denylist error: {exc.__class__.__name__}\n")
        return 2

    if name_findings:
        sys.stdout.write("\n".join(name_findings) + "\n")
        sys.stderr.write(
            f"check-pii-scope: {len(name_findings)} removed-name hit(s); "
            "surface forms are not printed.\n"
        )
        return 1

    if args.names_only:
        return 0

    linter_code = scan_linter(repo_root, skill_dir)
    if linter_code != 0:
        return linter_code
    return 0


if __name__ == "__main__":
    sys.exit(main())
