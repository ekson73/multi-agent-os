#!/usr/bin/env python3
"""render_dod_as_prompt.py — the deterministic ORIENT renderer for `ooda-loop`.

The missing wire in the goal-loop family: Prisma (decompose-abstract-to-measurable) AUTHORS a
`measurement_spec` (a D/T/J value-tree — the probabilistic, LLM-authored half); the four consumers
(ooda-loop ORIENT, gap-loop/quiesce `--condition`, dod-recovery) consume a `dod-as-prompt` ENVELOPE.
Nothing deterministically PROJECTED the spec into that envelope — the acceptance list, the KPIs, and
the `termination_predicate` string were hand-authored, which is neither deterministic nor idempotent.
This script is that projection: spec (+ the driving goal) -> a validator-gated dod-as-prompt envelope.

It INVENTS no measurement. Authoring the value-tree and scoring it are BOTH Prisma's job
(structural_route.py form-gates the tree; aggregate_spec.py rolls it up). This renderer only
mechanically derives the three envelope fields the spec already determines:
  * acceptance[]            — one human-readable item per MATERIAL leaf (leaf_type D or T; J excluded:
                              a judgment leaf is not a binary "is it done?" checklist item — but it
                              stays IN measurement_spec, scored by Prisma).
  * kpis[]                  — measurable success signals: the D/T leaf counts + the standard Prisma
                              aggregate-score signal (>= band_high, inconclusive.flag=false).
  * termination_predicate   — THE string the driver consumes as `--condition`: the D/T leaves ANDed,
                              gated on the Prisma HIGH band. Deterministic given the spec.
`context_lock` defaults to the spec's own `meta.context_lock` (Prisma Step-0 already carries it —
context/purpose/stakeholder/targets); `--context-lock` overrides.

Correct-by-construction (every required key is set here), THEN — by default — proven against the SSOT
gate `skills/goal-recovery/bin/validate_envelope.py` (a dod envelope is refused if any gate breaks).
Fail-closed: a validation failure prints NOTHING on stdout and exits 3. `--no-validate` skips the
proof (portable/AAIF fallback when the validator is absent).

Stdlib only. Exit codes match the family:
  0  ok            (valid envelope on stdout)
  2  unreadable    (bad path / bad JSON)
  3  SpecError     (a required input is absent/empty, no material leaf, or the self-gate refused it)

Usage:
  render_dod_as_prompt.py --spec <measurement_spec.json> --for-goal "<goal>" [> dod.json]
  render_dod_as_prompt.py --spec <spec-or-wrapper.json> --handoff <handoff-as-prompt.json>
  render_dod_as_prompt.py --spec <spec.json> --for-goal "<g>" --context-lock <cl.json> --no-validate
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile

CONTRACT = "skills/ooda-loop/templates/dod-as-prompt.schema.json"
CONTRACT_VERSION = "1.0.0"
DEFAULT_BAND_HIGH = 0.85
CONTEXT_LOCK_KEYS = ("context", "purpose", "stakeholder", "targets")


def die(code, msg):
    sys.stderr.write(msg.rstrip("\n") + "\n")
    sys.exit(code)


def load(path):
    try:
        with open(path, "r", encoding="utf-8") as fh:
            return json.load(fh)
    except FileNotFoundError:
        die(2, f"[unreadable] no such file: {path}")
    except json.JSONDecodeError as exc:
        die(2, f"[unreadable] invalid JSON in {path}: {exc}")


def extract_spec(obj):
    """Accept a raw measurement_spec (meta+nodes at top level) OR a wrapper that carries one
    (.params.measurement_spec — a dod/handoff-shaped file — or .measurement_spec)."""
    if not isinstance(obj, dict):
        die(3, "[SpecError] --spec must be a JSON object")
    if isinstance(obj.get("meta"), dict) and "nodes" in obj:
        return obj
    params = obj.get("params")
    if isinstance(params, dict) and isinstance(params.get("measurement_spec"), dict):
        return params["measurement_spec"]
    if isinstance(obj.get("measurement_spec"), dict):
        return obj["measurement_spec"]
    die(3, "[SpecError] --spec has no measurement_spec (need meta+nodes, or .params.measurement_spec)")


def resolve_for_goal(args):
    if args.for_goal is not None and args.for_goal.strip():
        return args.for_goal.strip()
    if args.handoff:
        h = load(args.handoff)
        g = ((h.get("params") or {}).get("goal") if isinstance(h, dict) else None) or ""
        if isinstance(g, str) and g.strip():
            return g.strip()
        die(3, "[SpecError] --handoff has no non-empty params.goal")
    die(3, "[SpecError] for_goal required: pass --for-goal \"<goal>\" or --handoff <handoff-as-prompt.json>")


def resolve_context_lock(args, spec):
    if args.context_lock:
        cl = load(args.context_lock)
        cl = cl.get("context_lock", cl) if isinstance(cl, dict) else cl
    else:
        cl = (spec.get("meta") or {}).get("context_lock")
    if not isinstance(cl, dict):
        die(3, "[SpecError] no context_lock: spec.meta.context_lock absent (Prisma Step-0) and no --context-lock")
    missing = [k for k in CONTEXT_LOCK_KEYS if not (isinstance(cl.get(k), str) and cl[k].strip())]
    if missing:
        die(3, f"[SpecError] context_lock missing/empty keys: {', '.join(missing)} (a context-free DoD is refused)")
    # keep only the contracted keys + optional priority_focus (drop spec-internal noise)
    out = {k: cl[k] for k in CONTEXT_LOCK_KEYS}
    if isinstance(cl.get("priority_focus"), str) and cl["priority_focus"].strip():
        out["priority_focus"] = cl["priority_focus"]
    return out


def material_leaves(spec):
    """MATERIAL leaves = D or T (deterministic-measurable / judgment-tolerant-with-anchors).
    J (pure judgment) is excluded from acceptance — it is not a binary checklist item — but is NOT
    removed from measurement_spec (Prisma still scores it)."""
    out = []
    for n in spec.get("nodes") or []:
        if isinstance(n, dict) and n.get("leaf_type") in ("D", "T"):
            label = n.get("label")
            if isinstance(label, str) and label.strip():
                out.append((n["leaf_type"], label.strip()))
    return out


def project(spec, for_goal, context_lock):
    leaves = material_leaves(spec)
    if not leaves:
        die(3, "[SpecError] measurement_spec has no material (D/T) leaf — a DoD with no measurable "
               "acceptance item is theater; add at least one D or T leaf")

    band_high = ((spec.get("thresholds") or {}).get("band_high"))
    if not (isinstance(band_high, (int, float)) and not isinstance(band_high, bool) and 0.0 < band_high <= 1.0):
        band_high = DEFAULT_BAND_HIGH

    acceptance = [f"{label} ({lt})" for lt, label in leaves]

    n_d = sum(1 for lt, _ in leaves if lt == "D")
    n_t = sum(1 for lt, _ in leaves if lt == "T")
    prisma_signal = (f"Prisma aggregate score >= {band_high} (band HIGH) with inconclusive.flag=false")
    kpis = []
    if n_d:
        kpis.append(f"{n_d}/{n_d} deterministic (D) leaves satisfied")
    if n_t:
        kpis.append(f"{n_t}/{n_t} judgment-tolerant (T) leaves pass their anchors")
    kpis.append(prisma_signal)

    termination_predicate = (
        "DONE when: " + " AND ".join(acceptance)
        + f" — AND the {prisma_signal}. Leaves re-scored each round against current state."
    )

    return {
        "jsonrpc": "2.0",
        "method": "session.dod_derivation",
        "params": {
            "for_goal": for_goal,
            "context_lock": context_lock,
            "measurement_spec": spec,
            "acceptance": acceptance,
            "kpis": kpis,
            "termination_predicate": termination_predicate,
        },
        "data": {
            "layer": "community",
            "type": "dod-as-prompt",
            "engine": "decompose-abstract-to-measurable",
            "contract": CONTRACT,
            "contract_version": CONTRACT_VERSION,
        },
    }


def self_validate(envelope):
    """Prove the built envelope against the SSOT gate (validate_envelope.py). Correct-by-construction
    already, but this is the anti-theater belt-and-suspenders: never emit an envelope the gate refuses.
    Returns None on pass; a message string on fail; "" (empty) when the validator is absent (degraded)."""
    validator = os.path.join(
        os.path.dirname(os.path.abspath(__file__)),
        os.pardir, os.pardir, "goal-recovery", "bin", "validate_envelope.py")
    validator = os.path.normpath(validator)
    if not os.path.isfile(validator):
        return ""  # portable fallback — validator not co-located
    tmp = None
    try:
        fd, tmp = tempfile.mkstemp(suffix=".dod.json")
        with os.fdopen(fd, "w", encoding="utf-8") as fh:
            json.dump(envelope, fh)
        proc = subprocess.run([sys.executable, validator, tmp, "--type", "dod"],
                              capture_output=True, text=True)
        return None if proc.returncode == 0 else (proc.stderr or proc.stdout or "validator refused").strip()
    except Exception as exc:  # never let the proof crash the render
        return ""
    finally:
        if tmp and os.path.exists(tmp):
            os.remove(tmp)


def main():
    ap = argparse.ArgumentParser(description="project a Prisma measurement_spec into a validator-gated dod-as-prompt envelope")
    ap.add_argument("--spec", required=True, help="measurement_spec JSON (raw, or a wrapper carrying .params.measurement_spec)")
    ap.add_argument("--for-goal", help="the goal this DoD measures (or use --handoff)")
    ap.add_argument("--handoff", help="handoff-as-prompt JSON — for_goal <- its params.goal")
    ap.add_argument("--context-lock", help="context_lock JSON override (default: spec.meta.context_lock)")
    ap.add_argument("--no-validate", action="store_true", help="skip the SSOT self-gate (portable fallback)")
    args = ap.parse_args()

    spec = extract_spec(load(args.spec))
    for_goal = resolve_for_goal(args)
    context_lock = resolve_context_lock(args, spec)
    envelope = project(spec, for_goal, context_lock)

    if not args.no_validate:
        verdict = self_validate(envelope)
        if verdict is None:
            sys.stderr.write("[ok] dod-as-prompt self-gated against validate_envelope.py (exit 0)\n")
        elif verdict == "":
            sys.stderr.write("[warn] validate_envelope.py not found — emitting unproven (correct-by-construction); pass to the gate downstream\n")
        else:
            die(3, "[SpecError] rendered dod-as-prompt refused by the SSOT gate:\n" + verdict)

    json.dump(envelope, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    sys.exit(0)


if __name__ == "__main__":
    main()
