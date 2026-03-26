# Why Symlinks Should NEVER Be Used for Sharing AI Context Files

> **TL;DR:** Symlinks look like a clever shortcut for sharing CLAUDE.md, .cursorrules, and other AI context files across repositories. In practice, they silently break CI/CD, corrupt cross-platform builds, leak filesystem structure, and create maintenance nightmares that are far worse than the duplication they aimed to prevent.

---

## 1. The Problem: Why Teams Are Tempted

When managing AI governance files (CLAUDE.md, .cursorrules, .windsurfrules, AGENTS.md) across multiple repositories, developers naturally reach for two principles:

- **SSOT (Single Source of Truth):** "I want one canonical file. Changes propagate everywhere automatically."
- **DRY (Don't Repeat Yourself):** "I refuse to copy the same 500-line governance file into 12 repos."

Both principles are sound in application code. But AI context files live at the intersection of git, CI/CD runners, multiple operating systems, and LLM tooling — a combination where symlinks become a liability, not an asset.

---

## 2. Why Symlinks Fail

### 2.1 Absolute Paths Break in CI/CD

CI/CD runners (GitHub Actions, Bitbucket Pipelines, GitLab CI, Jenkins) execute builds in ephemeral containers or VMs. The filesystem layout is:

```
/home/runner/work/repo-name/repo-name/
/opt/atlassian/pipelines/agent/build/
/builds/group/project/
```

A symlink pointing to `/Users/john.doe/Projects/shared-governance/CLAUDE.md` will **never** resolve on any CI runner. The build fails with a cryptic "file not found" or — worse — silently uses an empty/missing file, producing a green build with zero governance applied.

### 2.2 Absolute Paths Break on Other Developers' Machines

Even within the same team, developer machines have different usernames, directory structures, and mount points:

```
# Developer A (macOS)
/Users/alice/Projects/multi-agent-os/

# Developer B (Linux)
/home/bob/code/multi-agent-os/

# Developer C (Windows WSL)
/mnt/c/Users/charlie/repos/multi-agent-os/
```

A symlink committed with Developer A's absolute path is a **dangling symlink** on every other machine. `git clone` succeeds, but the file content is unreachable.

### 2.3 Dangling Symlinks Crash Build Tools

Angular compiler, TypeScript (`tsc`), webpack, Vite, esbuild, and other build tools follow symlinks to read file contents. When a symlink target does not exist:

- **Angular/webpack:** `ENOENT: no such file or directory` — build fails immediately
- **TypeScript:** Cannot find module or type declaration — compilation error
- **esbuild/Vite:** Silent resolution failure or missing chunk in output bundle
- **Prettier/ESLint:** May skip the file entirely, giving false "all clean" results

These failures are often non-obvious because the error message references the symlink path, not the missing target.

### 2.4 `.gitignore` Does NOT Affect Already-Tracked Files

A common misconception:

> "I'll just add the symlinks to `.gitignore` later to fix it."

**Wrong.** `.gitignore` only prevents **untracked** files from being staged. Once a symlink is committed and tracked by git, adding it to `.gitignore` has **zero effect**. The symlink remains in the repository, in every branch, in every clone. Removing it requires explicit `git rm --cached` followed by a commit — across every branch where it was merged.

### 2.5 Git Tracks Symlinks as Target Path Strings

Git does not store the content of the symlink target. It stores the **literal path string** that the symlink points to. This means:

```bash
$ git cat-file -p <blob-hash-of-symlink>
/Users/john.doe/Projects/shared-governance/CLAUDE.md
```

Your local filesystem structure is now permanently recorded in git history. Even if you delete the symlink later, `git log --all --diff-filter=A -- '*.md'` will reveal the original absolute path forever.

### 2.6 Windows Has Limited Symlink Support

On Windows (without WSL):

- Creating symlinks requires **Administrator privileges** or Developer Mode enabled
- `git config core.symlinks` defaults to `false` on many Windows git installations
- When `core.symlinks` is false, git creates **plain text files** containing the target path instead of actual symlinks
- This means the same repo behaves differently on Windows vs. macOS/Linux — a portability nightmare

### 2.7 Information Disclosure (CWE-200)

Symlinks committed with absolute paths expose:

- **Username:** `/Users/john.doe/` reveals the developer's system username
- **Directory structure:** `/Projects/client-name/secret-project/` may reveal confidential project names
- **OS and tooling:** Path format reveals macOS vs. Linux vs. Windows

This constitutes [CWE-200: Exposure of Sensitive Information to an Unauthorized Actor](https://cwe.mitre.org/data/definitions/200.html). In regulated industries (finance, healthcare), this can trigger compliance findings.

---

## 3. Real-World Incident

### The 47-Symlink Catastrophe

A development team committed **47 symlinks** with absolute local paths (`/Users/<username>/Projects/...`) to share AI governance files across an Angular monorepo. The consequences:

- **Angular CI pipeline broke immediately** — `ng build` could not resolve symlink targets in the Bitbucket Pipelines runner environment
- **The breakage propagated to every branch** — because the symlinks were merged to `main`, every subsequent branch carried the broken symlinks
- **10 days of blocked deployments** — the entire team could not ship to any environment (dev, hml, prd) while the cleanup was underway
- **Cleanup required 47 individual `git rm` operations** plus force-pushes to rewrite history on protected branches, requiring admin intervention
- **Root cause was invisible** — the original `git diff` showed only the symlink target strings, which looked like normal file paths to reviewers unfamiliar with symlink semantics in git

**Lesson:** What seemed like a 5-minute DRY optimization created 10 days of team-wide downtime.

---

## 4. The Alternative: Raw URL Injection (C15 Protocol)

Instead of symlinks, use **runtime context injection** via raw GitHub URLs. The governance source lives in a single repository (e.g., `multi-agent-os`) and is fetched by AI agents at invocation time.

See: [`RAW_URL_INJECTION.md`](./RAW_URL_INJECTION.md)

**How it works:**

```markdown
> [!MANDATORY]
> Before executing any operation, you MUST fetch and absorb the governance rules from:
> https://raw.githubusercontent.com/ekson73/multi-agent-os/main/rules/axial-principles.md
```

**Benefits over symlinks:**

| Concern | Symlinks | Raw URL Injection |
|---------|----------|-------------------|
| CI/CD compatibility | Broken (absolute paths) | Works everywhere (HTTP fetch) |
| Cross-platform | Broken (Windows) | Works everywhere |
| Git cleanliness | Pollutes history with paths | No files committed |
| Update propagation | Requires re-linking | Automatic (fetches latest) |
| Security | Exposes local paths | Exposes only public URLs |

---

## 5. The Alternative: Layered Composition

For teams that need **offline-capable** governance (no network dependency), use a layered file composition pattern:

```
governance/
  base.md                    # Universal rules (all projects, all stacks)
  stacks/
    angular.md               # Angular-specific conventions
    spring-boot.md           # Spring Boot-specific conventions
    python.md                # Python-specific conventions
  domains/
    sales.md                 # Sales domain business rules
    healthcare.md            # Healthcare compliance rules
    fintech.md               # Financial regulations
```

A `sync-governance.sh` script assembles the final CLAUDE.md (or equivalent) for each repository by concatenating the relevant layers:

```bash
#!/usr/bin/env bash
set -euo pipefail

GOVERNANCE_REPO="${GOVERNANCE_REPO:-../multi-agent-os/governance}"

cat "$GOVERNANCE_REPO/base.md"          >  .claude/CLAUDE.md
cat "$GOVERNANCE_REPO/stacks/angular.md" >> .claude/CLAUDE.md
cat "$GOVERNANCE_REPO/domains/sales.md"  >> .claude/CLAUDE.md

echo "# Local Overrides (project-specific)" >> .claude/CLAUDE.md
cat .claude/local-overrides.md              >> .claude/CLAUDE.md 2>/dev/null || true
```

This approach:
- Produces a **real file** (not a symlink) that works everywhere
- Supports **local overrides** without modifying shared layers
- Can run in CI/CD with the governance repo checked out as a submodule or fetched via script
- Enables **drift detection** (compare generated output vs. committed file)

---

## 6. Decision Matrix

| Approach | Best For | Tradeoffs |
|----------|----------|-----------|
| **Raw URL Injection (C15)** | Teams using AI agents with web access; maximum SSOT | Requires network at agent invocation; no offline support |
| **sync-governance.sh (Layered Composition)** | Teams needing offline support; CI/CD-first workflows | Requires running sync script after governance changes; possible drift |
| **Git Submodule** | Monorepo-adjacent setups; pinned governance versions | Submodule update friction; developers forget `--recurse-submodules` |
| **Copy + Drift Detection** | Small teams; few repos; simplicity over automation | Manual copy step; drift detection script needed to catch staleness |
| **Symlinks** | **NEVER** | Breaks CI/CD, breaks cross-platform, breaks build tools, leaks paths |

### Choosing the Right Approach

```
Do your AI agents have web access?
  ├── YES → Use Raw URL Injection (C15)
  └── NO
       ├── Do you need pinned governance versions?
       │    ├── YES → Use Git Submodule
       │    └── NO → Use sync-governance.sh
       └── Is this a single small project?
            └── YES → Copy + Drift Detection is acceptable
```

---

## See Also

- [`RAW_URL_INJECTION.md`](./RAW_URL_INJECTION.md) — The C15 protocol for runtime context injection
- [`gaas-architecture-manifesto.md`](./gaas-architecture-manifesto.md) — The 3-motor enforcement architecture
- [`framework-consumption.md`](./framework-consumption.md) — How consumers should reference the framework
- [CWE-200: Exposure of Sensitive Information](https://cwe.mitre.org/data/definitions/200.html) — The security classification for path disclosure
