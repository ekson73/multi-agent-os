# SpecDD — kirocrew-extras

Specification-Driven Development doc for `bin/kirocrew-extras`. This is the
contract; `test/test_kirocrew_extras.sh` (TestDD) verifies it.

## Purpose

Install/verify/upgrade KiroCrew optional channel dependencies into the app's
**bundled** interpreter, idempotently, in one run, with self-heal on failure.

## Functional requirements

| ID | Requirement |
|----|-------------|
| FR-1 | Resolve the bundled interpreter via glob fallback; a renamed `backend-*` dir must not break it. Exit 1 with a re-derivation hint if none found. |
| FR-2 | Read each extra's pin LIVE from `kiro_crew.extras.pip_install_command()`; never hardcode a version. |
| FR-3 | One run = ensure native prereqs → install/upgrade → verify imports → PASS/FAIL summary. |
| FR-4 | WhatsApp: detect native `libmagic`; install via Homebrew when missing (skip in `--check`). |
| FR-5 | Flags: `--check` (verify only), `--upgrade`, `--all`, `--help`; unknown flag → exit 2. |
| FR-6 | Non-zero exit if any extra FAILs (CI/cron gate). Exit 0 when all OK / nothing changed. |
| FR-7 | Self-heal: on ERR, write prompt+runlog and dispatch an AI harness. |
| FR-8 | Harness dispatch is AGNOSTIC: probe `command -v` for each of `kiro-cli claude codex opencode gemini crush amp` in order, run first available with its own headless syntax, fall back on absence/error. Order overridable via `KIROCREW_AI_HARNESS`. |
| FR-9 | Self-heal opt-out via `KIROCREW_EXTRAS_SELFHEAL=0`. |

## Non-functional / robustness

| ID | Requirement |
|----|-------------|
| NFR-1 | `mktemp` must not fail when `TMPDIR` ends in `/` (no `//`); fall back to `-t` then to a `$$` name. |
| NFR-2 | `trap self_heal ERR` only (never EXIT) to avoid double-fire. |
| NFR-3 | Healer tools are SCOPED (read/write/bash), never trust-all; human reviews the diff. |
| NFR-4 | `bash -n` clean; no unbound-variable errors under `set -u`. |
| NFR-5 | Agent authors it; a human runs it (product-path argv trips KiroCrew self-protection floors). |

## Out of scope

- Installing into any interpreter other than the KiroCrew bundle.
- Publishing `kirocrew` from an index (it is on none).
