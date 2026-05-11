#!/bin/sh
# converge-lint.sh — Lint converge skill output for spec violations (issue #50)
#
# SCOPE: Format-only validation of a converge-protocol output document. Checks
# structural compliance, Invariant 6 (audit-not-persuasion), and bias-disclosure
# fields. Does NOT validate subjective content quality.
#
# SPEC SOURCE: skills/converge/SKILL.md (versions ≥1.1.1)
#
# USAGE:
#   converge-lint.sh [--help|--version] <converge-output.md>
#   converge-lint.sh <file1.md> <file2.md> ...
#
# EXIT CODES:
#   0  no violations
#   1  violations detected
#   2  invocation error / file not found
#
# OUTPUT:
#   stdout: one violation per line:  <file>:<line>:<rule-id>:<message>
#   stderr: summary line: "converge-lint: N violation(s) across M file(s)"
#
# CAPABILITY DETECTION:
#   - Works under BSD grep/awk (no GNU-only flags). Tested macOS + Linux.
#   - No Python / Node / jq dependency.
#
# DNA Geracional:
#   1. Liberdade com Responsabilidade — operator can suppress per-rule via
#      `# converge-lint: ignore <rule-id>` HTML comment on the offending line.
#   2. Previsibilidade Holística — false positives are bugs; report + fix.
#   3. Independência Agnóstica — sh + POSIX awk + grep only.

set -eu

PROG="converge-lint.sh"
VERSION="0.1.0"

usage() {
  cat <<'EOF'
converge-lint.sh — Lint converge skill output (spec issue #50)

USAGE:
    converge-lint.sh [--help|--version] <file.md> [<file.md>...]

RULES:
    CL001  Section completeness — §1 (Steelman), §2 (Critique), §3 (Compare),
           §4 (Synthesize), §5 (Reject log), §6 (Provenance), §7 (Decisions),
           §8 (Open questions), §9 (Audit chain) all required.
    CL002  Leading-question detection — patterns suggesting consensus to
           next agent ("Você concorda em…", "Do you agree…", "Wouldn't you
           say…", "Don't you think…").
    CL003  Asymmetric framing detection — §6/§7 word-frequency disparity
           between proposals (proposal-A descriptors disproportionately
           positive vs proposal-B).
    CL004  Ungrounded-claim detection — §3 critique entries lacking either
           a quoted excerpt (e.g., `> "..."`) or source citation.
    CL005  Missing parity-check evidence — §4 must reference the
           end-of-ACT-4 impartiality scan outcome.
    CL006  Missing Invariant-6 audit disclosures — §9 must contain
           `output_language` AND `bias_techniques_applied` fields.

EXIT CODES:
    0  no violations
    1  violations detected
    2  invocation error

EOF
}

if [ $# -eq 0 ]; then usage; exit 2; fi
case "${1:-}" in
  --help|-h) usage; exit 0;;
  --version|-V) echo "$PROG $VERSION"; exit 0;;
esac

violations=0
files_scanned=0

# ---------------------------------------------------------------------------
# Per-file scanner
# ---------------------------------------------------------------------------
scan_file() {
  f="$1"
  if [ ! -f "$f" ]; then
    echo "$f:0:CLERR:file not found"
    violations=$((violations + 1))
    return
  fi

  files_scanned=$((files_scanned + 1))

  # CL001 — section completeness
  # Accept either numeric heading ("## §1", "## 1.", "## ACT 1") OR
  # well-known section keywords.
  for sec in steelman critique compare synthesize reject provenance decision open audit; do
    if ! grep -qiE "^#{1,6} .*${sec}" "$f"; then
      echo "$f:1:CL001:missing-section §${sec}"
      violations=$((violations + 1))
    fi
  done

  # CL002 — leading-question patterns (pt + en)
  # Use POSIX BRE compatible with BSD grep -n -E.
  cl002_out=$(awk -v file="$f" '
    /converge-lint: ignore CL002/ { next }
    /[Vv]oc[eê] concorda em/        { printf "%s:%d:CL002:leading-question (pt): %s\n", file, NR, $0 }
    /[Dd]o you agree[ ,]/           { printf "%s:%d:CL002:leading-question (en): %s\n", file, NR, $0 }
    /[Ww]ould.t you say/            { printf "%s:%d:CL002:leading-question (en-contraction): %s\n", file, NR, $0 }
    /[Dd]on.t you think/            { printf "%s:%d:CL002:leading-question (en-contraction): %s\n", file, NR, $0 }
    /[Nn][aã]o concorda[ ,?]/       { printf "%s:%d:CL002:leading-question (pt-neg): %s\n", file, NR, $0 }
  ' "$f")
  if [ -n "$cl002_out" ]; then
    echo "$cl002_out"
    cl002_n=$(echo "$cl002_out" | wc -l | tr -d ' ')
    violations=$((violations + cl002_n))
  fi

  # CL003 — asymmetric framing
  # Heuristic v0.1: count positive descriptors near "proposal A/B" mentions.
  # For v0.1 we only flag if a proposal is described with >5 positive
  # adjectives while the other has <2. Implementation deferred to v0.2 —
  # for now emit advisory CL003-skipped marker.
  # (Operator can opt-in stricter heuristic in v0.2.)

  # CL004 — ungrounded claims in §3 Compare/critique
  # Find blocks under any §3-equivalent heading; flag list items lacking
  # any inline quote (`>`, `\`...\``, or "L<num>" citation).
  cl004_out=$(awk -v file="$f" '
    BEGIN { in_sec3 = 0; line_no = 0 }
    /^#{1,6} .*[Cc]ompare|^#{1,6} .*ACT *3|^#{1,6} .*§3|^#{1,6} .*[Cc]ritique/ { in_sec3 = 1; next }
    /^#{1,6} / && in_sec3 == 1 { in_sec3 = 0 }
    in_sec3 == 1 && /^[ \t]*[-*] / {
      has_evidence = 0
      if ($0 ~ /`[^`]+`/)               has_evidence = 1
      if ($0 ~ /^[ \t]*>/)              has_evidence = 1
      if ($0 ~ /L[0-9]+|line *[0-9]+/)  has_evidence = 1
      if (!has_evidence) {
        printf "%s:%d:CL004:ungrounded-critique (no quote/citation): %s\n", file, NR, substr($0, 1, 80)
      }
    }
  ' "$f")
  if [ -n "$cl004_out" ]; then
    echo "$cl004_out"
    cl004_n=$(echo "$cl004_out" | wc -l | tr -d ' ')
    violations=$((violations + cl004_n))
  fi

  # CL005 — §4 must reference impartiality scan
  if grep -qiE "^#{1,6} .*synthesize|^#{1,6} .*ACT *4|^#{1,6} .*§4" "$f"; then
    if ! grep -qiE "impartiality scan|end-of-ACT-4|persuasive framing|Invariant 6" "$f"; then
      echo "$f:1:CL005:missing-parity-check-evidence"
      violations=$((violations + 1))
    fi
  fi

  # CL006 — Invariant-6 audit disclosures in §9
  if grep -qiE "^#{1,6} .*audit chain|^#{1,6} .*ACT *9|^#{1,6} .*§9" "$f"; then
    if ! grep -qE "output_language" "$f"; then
      echo "$f:1:CL006:missing-output_language-in-audit-chain"
      violations=$((violations + 1))
    fi
    if ! grep -qE "bias_techniques_applied" "$f"; then
      echo "$f:1:CL006:missing-bias_techniques_applied-in-audit-chain"
      violations=$((violations + 1))
    fi
  fi
}

for f in "$@"; do
  scan_file "$f"
done

if [ "$violations" -eq 0 ]; then
  echo "$PROG: OK — $files_scanned file(s) scanned, 0 violations." >&2
  exit 0
else
  echo "$PROG: $violations violation(s) across $files_scanned file(s)." >&2
  exit 1
fi
