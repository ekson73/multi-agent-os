#!/usr/bin/env python3
"""
Pass 1 — participants whitelist + phonetic-substitution check.

Strategy
--------
For each candidate proper-name token in the input (heuristic: token starting with
uppercase, length >= 3, not at sentence start unless preceded by a known attribution
marker like "@" or "Assigned to:"), do:

1. If the token is in the canonical whitelist (canonical_name or alias of any entry)
   → leave unchanged, mark verified in audit.
2. Else consult phonetic-substitutions.yaml:
   - For each entry where any ambiguous_class member matches the token (case-insensitive)
     AND the entry's canonical_short / canonical_name is present elsewhere in the
     SAME document (e.g., in an Invitees block) OR has no context-dependence, propose
     substitution with the entry's confidence (default 0.90).
3. Else compute Levenshtein-distance + difflib similarity to every whitelist entry's
   canonical_name and aliases:
   - score = difflib.SequenceMatcher ratio (0.0-1.0, equivalent to 1 - normalized
     Levenshtein for our purposes — purely stdlib, no extra deps)
   - If best score ≥ 0.85 → HIGH confidence → auto-apply
   - If 0.65 ≤ score < 0.85 → MEDIUM → flag only (not auto-applied;
     audit entry recorded with `applied: False`; no `corrections` push).
     Conservative behaviour locked per operator Q2 (PR #96, 2026-05-28).
   - If < 0.65 → LOW → leave + emit warning in audit

YAML parsing
------------
Pure stdlib: minimal YAML reader using `re`. We don't need full YAML; the catalogs
are simple key-value with lists. If the catalog grows complex, swap to PyYAML
(capability-detected import).

Audit format
------------
Appends entries to the audit-json file (which is a JSON array):
    {"pass": 1, "line": <int>, "original": "<str>", "corrected": "<str>",
     "confidence": <float>, "rule": "<whitelist-exact|phonetic-class|levenshtein>",
     "applied": <bool>}

Cross-vendor AAIF: pure Python stdlib. No external deps required.
"""
import argparse
import json
import re
import sys
from difflib import SequenceMatcher
from pathlib import Path


# ------------- minimal YAML reader (sufficient for our flat catalogs) -------------

def _try_pyyaml(path: Path):
    try:
        import yaml  # type: ignore
        with path.open("r", encoding="utf-8") as f:
            return yaml.safe_load(f)
    except Exception:
        return None


def _fallback_parse_participants(path: Path) -> list[dict]:
    """Heuristic parser for participants-canonical.yaml when PyYAML unavailable."""
    entries: list[dict] = []
    current: dict = {}
    in_aliases = False
    pat_canonical = re.compile(r'^\s*-\s+canonical_name:\s*"?([^"\n]+?)"?\s*$')
    pat_alias_inline = re.compile(r'^\s+aliases:\s*\[\]\s*$')
    pat_alias_block = re.compile(r'^\s+aliases:\s*$')
    pat_alias_item = re.compile(r'^\s+-\s+"?([^"\n]+?)"?\s*$')
    for raw in path.read_text(encoding="utf-8").splitlines():
        if pat_canonical.match(raw):
            if current:
                entries.append(current)
            current = {"canonical_name": pat_canonical.match(raw).group(1).strip(), "aliases": []}
            in_aliases = False
        elif pat_alias_inline.match(raw):
            in_aliases = False
        elif pat_alias_block.match(raw):
            in_aliases = True
        elif in_aliases:
            m = pat_alias_item.match(raw)
            if m:
                current.setdefault("aliases", []).append(m.group(1).strip())
            elif raw.strip():
                # Exit alias block on ANY non-alias-item content line — including
                # sibling keys at the same indentation (e.g., 'contexts:', 'source:',
                # 'notes:'). Previously we only exited on top-level lines, so
                # subsequent context-list items were incorrectly appended as aliases.
                in_aliases = False
    if current:
        entries.append(current)
    return entries


def _fallback_parse_phonetic(path: Path) -> list[dict]:
    """Heuristic parser for phonetic-substitutions.yaml when PyYAML unavailable."""
    entries: list[dict] = []
    current: dict = {}
    in_ambiguous = False
    pat_canon = re.compile(r'^\s*-\s+canonical:\s*"?([^"\n]+?)"?\s*$')
    pat_canon_short = re.compile(r'^\s+canonical_short:\s*"?([^"\n]+?)"?\s*$')
    pat_amb_block = re.compile(r'^\s+ambiguous_class:\s*$')
    pat_amb_item = re.compile(r'^\s+-\s+"?([^"\n]+?)"?\s*$')
    pat_confidence = re.compile(r'^\s+confidence:\s*([0-9.]+)\s*$')
    pat_context = re.compile(r'^\s+context:\s*"?([^"\n]+?)"?\s*$')
    for raw in path.read_text(encoding="utf-8").splitlines():
        if pat_canon.match(raw):
            if current:
                entries.append(current)
            current = {"canonical": pat_canon.match(raw).group(1).strip(),
                       "ambiguous_class": [], "confidence": 0.90}
            in_ambiguous = False
        elif pat_canon_short.match(raw):
            current["canonical_short"] = pat_canon_short.match(raw).group(1).strip()
        elif pat_amb_block.match(raw):
            in_ambiguous = True
        elif pat_amb_item.match(raw) and in_ambiguous:
            current.setdefault("ambiguous_class", []).append(pat_amb_item.match(raw).group(1).strip())
        elif pat_confidence.match(raw):
            current["confidence"] = float(pat_confidence.match(raw).group(1))
            in_ambiguous = False
        elif pat_context.match(raw):
            current["context"] = pat_context.match(raw).group(1).strip()
            in_ambiguous = False
    if current:
        entries.append(current)
    return entries


def load_participants(path: Path) -> list[dict]:
    parsed = _try_pyyaml(path)
    if parsed and isinstance(parsed, dict) and "participants" in parsed:
        return parsed["participants"]
    return _fallback_parse_participants(path)


def load_phonetic(path: Path) -> list[dict]:
    parsed = _try_pyyaml(path)
    if parsed and isinstance(parsed, dict) and "substitutions" in parsed:
        return parsed["substitutions"]
    return _fallback_parse_phonetic(path)


# ------------- correction logic -------------

def build_whitelist(participants: list[dict]) -> set[str]:
    names: set[str] = set()
    for p in participants:
        if "canonical_name" in p:
            names.add(p["canonical_name"])
            for tok in p["canonical_name"].split():
                if len(tok) >= 3:
                    names.add(tok)
        for a in p.get("aliases", []) or []:
            names.add(a)
    return names


def find_candidate_names(text: str) -> list[tuple[int, str]]:
    """Return list of (line_number, token) for proper-name candidates."""
    candidates: list[tuple[int, str]] = []
    # Capitalized token of length >= 3 that isn't at the very start of a sentence
    # OR is preceded by attribution markers ("@", "Assigned to:", "designou", "para",
    # "com", or a bullet "- ").
    name_re = re.compile(r"(?:(?<=\s)|(?<=@)|(?<=:)|(?<=-\s))([A-ZÁÉÍÓÚÂÊÔÃÕÇ][a-zãõçáéíóúâêîôûà]{2,})")
    for i, line in enumerate(text.splitlines(), start=1):
        for m in name_re.finditer(line):
            candidates.append((i, m.group(1)))
    return candidates


def best_similarity(token: str, candidates: list[str]) -> tuple[float, str]:
    best_score = 0.0
    best_match = ""
    for c in candidates:
        s = SequenceMatcher(None, token.lower(), c.lower()).ratio()
        if s > best_score:
            best_score = s
            best_match = c
    return best_score, best_match


def correct_pass1(text: str, participants: list[dict], phonetic: list[dict],
                  audit: list[dict]) -> str:
    """Apply Pass-1 corrections (HIGH-confidence only); record everything in audit."""
    whitelist = build_whitelist(participants)

    # Detect which canonicals from the phonetic catalog are present elsewhere in the
    # document (in the Invitees block OR anywhere). If present, that authorizes the
    # high-confidence substitution.
    # Word-boundary matching (\b) prevents false positives where a canonical's letters
    # appear as a substring inside an unrelated word (e.g., "Alves" matching "valves",
    # "salves"). Empirical case raised by amazon-q-developer 2026-05-28.
    text_lower = text.lower()
    active_phonetic: list[dict] = []
    for entry in phonetic:
        canonical = entry.get("canonical_short") or entry.get("canonical", "")
        canonical_full = entry.get("canonical", "")
        if not canonical:
            continue
        canonical_pat = r"\b" + re.escape(canonical.lower()) + r"\b"
        canonical_full_pat = r"\b" + re.escape(canonical_full.lower()) + r"\b" if canonical_full else canonical_pat
        if (re.search(canonical_pat, text_lower) or
                re.search(canonical_full_pat, text_lower)):
            active_phonetic.append(entry)

    candidates = find_candidate_names(text)
    corrections: list[tuple[str, str]] = []  # (original, corrected)
    seen: set[str] = set()

    for line_no, token in candidates:
        if token in seen:
            continue
        seen.add(token)

        # 1. Direct whitelist hit
        if token in whitelist:
            audit.append({
                "pass": 1, "line": line_no, "original": token, "corrected": token,
                "confidence": 1.0, "rule": "whitelist-exact", "applied": False
            })
            continue

        # 2. Phonetic substitution class
        phonetic_hit = None
        for entry in active_phonetic:
            ambiguous = [a.lower() for a in entry.get("ambiguous_class", [])]
            if token.lower() in ambiguous:
                phonetic_hit = entry
                break
        if phonetic_hit:
            correct = phonetic_hit.get("canonical_short") or phonetic_hit.get("canonical")
            conf = phonetic_hit.get("confidence", 0.90)
            applied = conf >= 0.85
            audit.append({
                "pass": 1, "line": line_no, "original": token, "corrected": correct,
                "confidence": conf, "rule": "phonetic-class", "applied": applied
            })
            if applied:
                corrections.append((token, correct))
            continue

        # 3. Levenshtein / SequenceMatcher fallback
        score, match = best_similarity(token, sorted(whitelist))
        if score >= 0.85:
            audit.append({
                "pass": 1, "line": line_no, "original": token, "corrected": match,
                "confidence": score, "rule": "levenshtein-high", "applied": True
            })
            corrections.append((token, match))
        elif score >= 0.65:
            audit.append({
                "pass": 1, "line": line_no, "original": token, "corrected": match,
                "confidence": score, "rule": "levenshtein-medium", "applied": False,
                "note": ":warning: MEDIUM-confidence — review before apply"
            })
        else:
            audit.append({
                "pass": 1, "line": line_no, "original": token, "corrected": "",
                "confidence": score, "rule": "no-match", "applied": False,
                "note": ":warning: Token not in whitelist; no high-confidence correction"
            })

    # Apply HIGH-confidence corrections (regex with word boundaries).
    # Case-insensitive detection so "nilson" / "NILSON" / "Nilson" all match;
    # replacement uses the canonical (correctly-cased) form.
    out = text
    for original, correct in corrections:
        out = re.sub(rf"\b{re.escape(original)}\b", correct, out, flags=re.IGNORECASE)
    return out


# ------------- CLI -------------

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", required=True)
    ap.add_argument("--output", required=True)
    ap.add_argument("--participants", required=True)
    ap.add_argument("--phonetic", required=True)
    ap.add_argument("--audit-append", required=True)
    ap.add_argument("--language", default="auto")
    args = ap.parse_args()

    text = Path(args.input).read_text(encoding="utf-8")
    participants = load_participants(Path(args.participants))
    phonetic = load_phonetic(Path(args.phonetic))

    audit_path = Path(args.audit_append)
    # Defensive: handle missing file AND empty-file (json.loads('') would raise).
    if audit_path.exists():
        content = audit_path.read_text(encoding="utf-8")
        audit = json.loads(content) if content.strip() else []
    else:
        audit = []
    out = correct_pass1(text, participants, phonetic, audit)
    audit_path.write_text(json.dumps(audit, ensure_ascii=False, indent=2), encoding="utf-8")
    Path(args.output).write_text(out, encoding="utf-8")
    return 0


if __name__ == "__main__":
    sys.exit(main())
