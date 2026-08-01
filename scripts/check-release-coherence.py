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
    "CLAUDE.md",
    "README.md",
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


def git(repo: Path, *args: str, text: bool = True) -> str | bytes:
    result = subprocess.run(
        ["git", "-C", str(repo), *args],
        check=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=text,
    )
    if result.returncode != 0:
        raise PolicyError(f"git {' '.join(args[:2])} failed")
    return result.stdout


def read_blob(repo: Path, sha: str, path: str) -> str:
    output = git(repo, "show", f"{sha}:{path}")
    assert isinstance(output, str)
    return output


def version_at(repo: Path, sha: str) -> str:
    try:
        document = json.loads(read_blob(repo, sha, MANIFEST))
    except (json.JSONDecodeError, PolicyError) as exc:
        raise PolicyError(f"cannot read a valid {MANIFEST} at {sha[:12]}") from exc
    version = document.get("version")
    if not isinstance(version, str) or SEMVER_RE.fullmatch(version) is None:
        raise PolicyError("plugin version must be a single-line SemVer value")
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


def validate_release(repo: Path, base_sha: str, head_sha: str, pr_title: str) -> str:
    if SHA_RE.fullmatch(base_sha) is None or SHA_RE.fullmatch(head_sha) is None:
        raise PolicyError("base and head must be immutable 40-character commit SHAs")

    start_sha = str(git(repo, "merge-base", base_sha, head_sha)).strip()
    start_version = version_at(repo, start_sha)
    head_version = version_at(repo, head_sha)

    # A stale branch whose PR never changed the manifest must remain a no-op.
    if start_version == head_version:
        return f"plugin version untouched by this PR ({head_version})"

    base_version = version_at(repo, base_sha)
    if RELEASE_TITLE_RE.fullmatch(pr_title) is None:
        raise PolicyError("a version delta requires a separate PR titled 'chore(release): ...'")
    if not semver_greater(head_version, base_version):
        raise PolicyError(
            f"release version {head_version} must advance current base version {base_version}"
        )

    merge_commits = str(
        git(repo, "rev-list", "--merges", head_sha, f"^{start_sha}", f"^{base_sha}")
    ).splitlines()
    if merge_commits:
        raise PolicyError("release PR history must be linear; rebase instead of merging")

    paths = changed_paths(repo, start_sha, head_sha)
    unexpected = sorted(paths - ALLOWED_RELEASE_PATHS)
    if unexpected:
        raise PolicyError(
            "release PR mixes non-release paths: " + json.dumps(unexpected, ensure_ascii=True)
        )
    if MANIFEST not in paths or "CHANGELOG.md" not in paths:
        raise PolicyError("release PR must change both plugin.json and CHANGELOG.md")

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
    added_headers = [
        line[1:]
        for line in changelog_diff.splitlines()
        if line.startswith("+")
        and not line.startswith("+++")
        and header_re.match(line[1:]) is not None
    ]
    if len(added_headers) != 1:
        raise PolicyError(
            f"release PR must add exactly one CHANGELOG heading for {head_version}"
        )

    return (
        f"release coherence satisfied: {base_version} -> {head_version}; "
        "release-only paths, linear history, title and changelog verified"
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo", type=Path, default=Path.cwd())
    parser.add_argument("--base-sha", required=True)
    parser.add_argument("--head-sha", required=True)
    parser.add_argument("--pr-title", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        message = validate_release(args.repo, args.base_sha, args.head_sha, args.pr_title)
    except PolicyError as exc:
        print(f"::error::{exc}", file=sys.stderr)
        return 1
    print(f"OK: {message}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
