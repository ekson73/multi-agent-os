#!/usr/bin/env python3
"""Fail-closed release-PR coherence policy for the MAOS plugin version."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from pathlib import Path


MANIFEST = ".claude-plugin/plugin.json"
ALLOWED_RELEASE_PATHS = {
    MANIFEST,
    "CHANGELOG.md",
}
RELEASE_TITLE_RE = re.compile(r"^chore\(release\)(!)?:\s+.+$")
SEMVER_RE = re.compile(
    r"^(0|[1-9][0-9]*)\."
    r"(0|[1-9][0-9]*)\."
    r"(0|[1-9][0-9]*)"
    r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
    r"(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
)
SHA_RE = re.compile(r"^[0-9a-f]{40}$")


class PolicyError(RuntimeError):
    """A deterministic release-coherence violation."""


def strict_json_object(pairs: list[tuple[str, object]]) -> dict[str, object]:
    document: dict[str, object] = {}
    for key, value in pairs:
        if key in document:
            raise PolicyError(f"duplicate JSON key is not allowed: {key}")
        document[key] = value
    return document


def git(repo: Path, *args: str, text: bool = True) -> str | bytes:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args],
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=text,
            encoding="utf-8" if text else None,
            errors="strict" if text else None,
        )
    except UnicodeDecodeError as exc:
        raise PolicyError(f"git {' '.join(args[:2])} returned non-UTF-8 output") from exc
    if result.returncode != 0:
        raise PolicyError(f"git {' '.join(args[:2])} failed")
    return result.stdout


def read_blob(repo: Path, sha: str, path: str) -> str:
    output = git(repo, "show", f"{sha}:{path}")
    assert isinstance(output, str)
    return output


def manifest_at(repo: Path, sha: str) -> dict[str, object]:
    try:
        document = json.loads(
            read_blob(repo, sha, MANIFEST), object_pairs_hook=strict_json_object
        )
    except (json.JSONDecodeError, PolicyError) as exc:
        raise PolicyError(f"cannot read a valid {MANIFEST} at {sha[:12]}") from exc
    if not isinstance(document, dict):
        raise PolicyError(f"{MANIFEST} must contain a JSON object")
    return document


def version_at(repo: Path, sha: str) -> str:
    document = manifest_at(repo, sha)
    version = document.get("version")
    if not isinstance(version, str) or SEMVER_RE.fullmatch(version) is None:
        raise PolicyError("plugin version must be a single-line SemVer value")
    semver_key(version)
    return version


def semver_key(version: str) -> tuple[int, int, int, tuple[tuple[int, int | str], ...] | None]:
    match = SEMVER_RE.fullmatch(version)
    if match is None:
        raise PolicyError("plugin version must be a single-line SemVer value")
    prerelease = match.group(4)
    if prerelease is None:
        prerelease_key = None
    else:
        identifiers: list[tuple[int, int | str]] = []
        for identifier in prerelease.split("."):
            if identifier.isdigit():
                if len(identifier) > 1 and identifier.startswith("0"):
                    raise PolicyError("numeric SemVer prerelease identifiers cannot have leading zeroes")
                identifiers.append((0, int(identifier)))
            else:
                identifiers.append((1, identifier))
        prerelease_key = tuple(identifiers)
    return int(match.group(1)), int(match.group(2)), int(match.group(3)), prerelease_key


def semver_greater(candidate: str, baseline: str) -> bool:
    candidate_key = semver_key(candidate)
    baseline_key = semver_key(baseline)
    if candidate_key[:3] != baseline_key[:3]:
        return candidate_key[:3] > baseline_key[:3]
    candidate_pre = candidate_key[3]
    baseline_pre = baseline_key[3]
    if candidate_pre is None:
        return baseline_pre is not None
    if baseline_pre is None:
        return False
    return candidate_pre > baseline_pre


def changed_paths(repo: Path, start_sha: str, head_sha: str) -> set[str]:
    output = git(
        repo,
        "diff",
        "--name-only",
        "--diff-filter=ACDMRTUXB",
        "-z",
        start_sha,
        head_sha,
        "--",
        text=False,
    )
    assert isinstance(output, bytes)
    return {
        item.decode("utf-8", errors="surrogateescape")
        for item in output.split(b"\0")
        if item
    }


def validate_release(repo: Path, base_sha: str, head_sha: str) -> str:
    if SHA_RE.fullmatch(base_sha) is None or SHA_RE.fullmatch(head_sha) is None:
        raise PolicyError("base and head must be immutable 40-character commit SHAs")

    start_sha = str(git(repo, "merge-base", base_sha, head_sha)).strip()
    start_version = version_at(repo, start_sha)
    head_version = version_at(repo, head_sha)

    # A stale branch whose PR never changed the manifest must remain a no-op.
    if start_version == head_version:
        return f"plugin version untouched by this PR ({head_version})"

    base_version = version_at(repo, base_sha)
    if start_sha != base_sha:
        raise PolicyError("release PR must be rebased onto the current base before validation")
    if not semver_greater(head_version, base_version):
        raise PolicyError(
            f"release version {head_version} must advance current base version {base_version}"
        )

    merge_commits = str(
        git(repo, "rev-list", "--merges", head_sha, f"^{start_sha}", f"^{base_sha}")
    ).splitlines()
    if merge_commits:
        raise PolicyError("release PR history must be linear; rebase instead of merging")

    release_commits = str(git(repo, "rev-list", "--reverse", f"{base_sha}..{head_sha}")).splitlines()
    if release_commits != [head_sha]:
        raise PolicyError("a version delta requires exactly one release commit")
    release_subject = str(git(repo, "log", "-1", "--format=%s", head_sha)).strip()
    if RELEASE_TITLE_RE.fullmatch(release_subject) is None:
        raise PolicyError("the release commit subject must match 'chore(release): ...'")

    paths = changed_paths(repo, start_sha, head_sha)
    unexpected = sorted(paths - ALLOWED_RELEASE_PATHS)
    if unexpected:
        raise PolicyError(
            "release PR mixes non-release paths: " + json.dumps(unexpected, ensure_ascii=True)
        )
    if MANIFEST not in paths or "CHANGELOG.md" not in paths:
        raise PolicyError("release PR must change both plugin.json and CHANGELOG.md")

    start_manifest = manifest_at(repo, start_sha)
    head_manifest = manifest_at(repo, head_sha)
    start_manifest.pop("version", None)
    head_manifest.pop("version", None)
    start_canonical = json.dumps(start_manifest, sort_keys=True, separators=(",", ":"))
    head_canonical = json.dumps(head_manifest, sort_keys=True, separators=(",", ":"))
    if start_canonical != head_canonical:
        raise PolicyError("release PR may change only the version field inside plugin.json")

    base_changelog = read_blob(repo, base_sha, "CHANGELOG.md")
    header_re = re.compile(rf"^## \[{re.escape(head_version)}\](?:\s|$)", re.MULTILINE)
    if header_re.search(base_changelog):
        raise PolicyError(f"release version {head_version} already exists in base CHANGELOG.md")

    tags = str(git(repo, "tag", "--list", head_version, f"v{head_version}")).splitlines()
    if tags:
        raise PolicyError(f"release version {head_version} already exists as a Git tag")

    changelog_diff = str(
        git(repo, "diff", "--unified=0", "--no-color", start_sha, head_sha, "--", "CHANGELOG.md")
    )
    removed_lines: list[str] = []
    added_lines: list[str] = []
    hunk_count = 0
    in_hunk = False
    for line in changelog_diff.splitlines():
        if line.startswith("@@"):
            hunk_count += 1
            in_hunk = True
        elif in_hunk and line.startswith("-"):
            removed_lines.append(line[1:])
        elif in_hunk and line.startswith("+"):
            added_lines.append(line[1:])
    if removed_lines or hunk_count != 1:
        raise PolicyError("CHANGELOG delta must be one additive release-section hunk")
    first_meaningful = next((line for line in added_lines if line.strip()), None)
    if first_meaningful is None or header_re.match(first_meaningful) is None:
        raise PolicyError("the new CHANGELOG hunk must begin with the release heading")
    added_headers = [
        line for line in added_lines if header_re.match(line) is not None
    ]
    added_sections = [line for line in added_lines if line.startswith("## ")]
    if len(added_headers) != 1 or added_sections != added_headers:
        raise PolicyError(
            f"release PR must add exactly one CHANGELOG heading for {head_version}"
        )

    return (
        f"release coherence satisfied: {base_version} -> {head_version}; "
        "one release commit, release-only content and changelog verified"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        message = validate_release(args.repo, args.base_sha, args.head_sha)
    except PolicyError as exc:
        print(f"::error::{exc}", file=sys.stderr)
        return 1
    print(f"OK: {message}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
