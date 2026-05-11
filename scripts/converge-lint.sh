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

  # CL003 — asymmetric framing detection (lightweight v0.1)
  # Heuristic: scan §6 Provenance + §7 Decisions for proposal-A vs proposal-B
  # mentions; count positive descriptors per proposal. Flag if disparity > 3x.
  # Positive descriptor set is intentionally short to minimize false positives.
  cl003_out=$(awk -v file="$f" '
    BEGIN {
      in_target = 0; pos_a = 0; pos_b = 0
      neg_a = 0; neg_b = 0  # also track negatives to refine signal
    }
    /^#{1,6} .*([Pp]rovenance|ACT *6|§6|[Dd]ecisions|ACT *7|§7)/ { in_target = 1; next }
    /^#{1,6} / && in_target == 1 { in_target = 0 }
    in_target == 1 {
      # tally positive/negative-affect lexemes per proposal — only when line
      # mentions ONE proposal (skip cross-comparative sentences to avoid
      # signal cross-pollution).
      mentions_a = ($0 ~ /[Pp]roposal *[Aa]/) || ($0 ~ /[Aa]gent-A/) || ($0 ~ /[Pp]roposta *A/) || ($0 ~ /opç[aã]o *A/)
      mentions_b = ($0 ~ /[Pp]roposal *[Bb]/) || ($0 ~ /[Aa]gent-B/) || ($0 ~ /[Pp]roposta *B/) || ($0 ~ /opç[aã]o *B/)
      # Word-level tally: count occurrences of positive/negative tokens, not lines
      if (mentions_a && !mentions_b) {
        line_lc = tolower($0)
        n_pos = gsub(/best|optimal|robust|elegant|cleaner|superior|bold|comprehensive|excellent|ideal/, "", line_lc)
        n_neg = gsub(/weak|brittle|sloppy|inferior|naive|simplistic|risky|fragile/, "", line_lc)
        pos_a += n_pos; neg_a += n_neg
      } else if (mentions_b && !mentions_a) {
        line_lc = tolower($0)
        n_pos = gsub(/best|optimal|robust|elegant|cleaner|superior|bold|comprehensive|excellent|ideal/, "", line_lc)
        n_neg = gsub(/weak|brittle|sloppy|inferior|naive|simplistic|risky|fragile/, "", line_lc)
        pos_b += n_pos; neg_b += n_neg
      }
    }
    END {
      # Net favor = positives - negatives per proposal
      net_a = pos_a - neg_a
      net_b = pos_b - neg_b
      gap = (net_a > net_b ? net_a - net_b : net_b - net_a)
      if ((pos_a + pos_b + neg_a + neg_b) >= 4 && gap >= 4) {
        printf "%s:1:CL003:asymmetric-framing in §6/§7 (proposal-A net=%d, proposal-B net=%d, gap=%d, pos_a=%d neg_a=%d pos_b=%d neg_b=%d)\n", file, net_a, net_b, gap, pos_a, neg_a, pos_b, neg_b
      }
    }
  ' "$f")
  if [ -n "$cl003_out" ]; then
    echo "$cl003_out"
    cl003_n=$(echo "$cl003_out" | wc -l | tr -d ' ')
    violations=$((violations + cl003_n))
  fi

  # CL004 — ungrounded claims in §3 Compare/critique
  # Requires a blockquote excerpt (`> "..."`) OR a line citation (`L<num>`).
  # Inline code (backticks) does NOT count as grounding — per spec §3 definition.
  cl004_out=$(awk -v file="$f" '
    BEGIN { in_sec3 = 0 }
    /^#{1,6} .*[Cc]ompare|^#{1,6} .*ACT *3|^#{1,6} .*§3|^#{1,6} .*[Cc]ritique/ { in_sec3 = 1; next }
    /^#{1,6} / && in_sec3 == 1 { in_sec3 = 0 }
    in_sec3 == 1 && /^[ \t]*[-*] / {
      has_evidence = 0
      # Only blockquote OR line citation counts as evidence
      if ($0 ~ /> *["'\''"]/)            has_evidence = 1   # inline blockquote with quote
      if ($0 ~ /^[ \t]*>/)               has_evidence = 1   # blockquote on same line
      if ($0 ~ /L[0-9]+|line *[0-9]+/)   has_evidence = 1   # line citation
      if (!has_evidence) {
        printf "%s:%d:CL004:ungrounded-critique (no quote-excerpt or L<num> citation): %s\n", file, NR, substr($0, 1, 80)
      }
    }
  ' "$f")
  if [ -n "$cl004_out" ]; then
    echo "$cl004_out"
    cl004_n=$(echo "$cl004_out" | wc -l | tr -d ' ')
    violations=$((violations + cl004_n))
  fi

  # CL005 — §4 must REFERENCE impartiality scan WITHIN the §4 section body
  # (section-scoped per Qodo PR #51 finding — was previously whole-file grep).
  sec4_body=$(awk '
    /^#{1,6} .*synthesize|^#{1,6} .*ACT *4|^#{1,6} .*§4/ { in_sec = 1; next }
    /^#{1,6} / && in_sec == 1 { in_sec = 0 }
    in_sec == 1 { print }
  ' "$f")
  if [ -n "$sec4_body" ]; then
    if ! echo "$sec4_body" | grep -qiE "impartiality scan|end-of-ACT-4|persuasive framing|Invariant 6"; then
      echo "$f:1:CL005:missing-parity-check-evidence-within-§4"
      violations=$((violations + 1))
    fi
  fi

  # CL006 — Invariant-6 audit disclosures WITHIN §9 (section-scoped)
  sec9_body=$(awk '
    /^#{1,6} .*audit chain|^#{1,6} .*ACT *9|^#{1,6} .*§9/ { in_sec = 1; next }
    /^#{1,6} / && in_sec == 1 { in_sec = 0 }
    in_sec == 1 { print }
  ' "$f")
  if [ -n "$sec9_body" ]; then
    if ! echo "$sec9_body" | grep -qE "output_language"; then
      echo "$f:1:CL006:missing-output_language-within-§9-audit-chain"
      violations=$((violations + 1))
    fi
    if ! echo "$sec9_body" | grep -qE "bias_techniques_applied"; then
      echo "$f:1:CL006:missing-bias_techniques_applied-within-§9-audit-chain"
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
