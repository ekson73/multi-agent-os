#!/usr/bin/env python3
"""Fail-closed stdlib validator for ooda-loop intake contracts.

The repository intentionally does not require a JSON Schema package at runtime. This validator
implements the exact Draft 2020-12 keyword subset used by the intake/output schemas and refuses a
schema containing an unsupported assertion keyword. It validates shape only; freshness, replay
storage and effective authority still require live host evidence.

Exit codes: 0 valid; 2 unreadable JSON/path; 3 schema or instance refused.
"""

import argparse
import datetime as dt
import json
import re
import sys
from pathlib import Path


HERE = Path(__file__).resolve().parent.parent
MAX_INPUT_BYTES = 1024 * 1024
SCHEMAS = {
    "operator-profile": HERE / "templates" / "operator-profile.schema.json",
    "trigger-envelope": HERE / "templates" / "trigger-envelope.schema.json",
    "run-envelope": HERE / "templates" / "run-envelope.schema.json",
}
ANNOTATIONS = {"$schema", "$id", "title", "description"}
ASSERTIONS = {
    "type", "additionalProperties", "required", "properties", "const", "enum", "items",
    "minLength", "maxLength", "pattern", "format", "minItems", "maxItems", "uniqueItems",
    "minimum", "maximum", "allOf", "if", "then",
}


def die(code, message):
    sys.stderr.write(message.rstrip() + "\n")
    raise SystemExit(code)


def resolve_input(path, trusted_root=None):
    resolved = Path(path).resolve(strict=True)
    if trusted_root is not None:
        root = Path(trusted_root).resolve(strict=True)
        try:
            resolved.relative_to(root)
        except ValueError:
            die(3, f"[path-error] {resolved} escapes trusted root {root}")
    if resolved.stat().st_size > MAX_INPUT_BYTES:
        die(3, f"[path-error] {resolved} exceeds {MAX_INPUT_BYTES} bytes")
    return resolved


def load(path, trusted_root=None):
    try:
        resolved = resolve_input(path, trusted_root)
        with resolved.open("r", encoding="utf-8") as handle:
            return json.load(handle)
    except OSError as exc:
        die(2, f"[unreadable] {path}: {exc}")
    except json.JSONDecodeError as exc:
        die(2, f"[unreadable] invalid JSON in {path}: {exc}")


def audit_schema(schema, where="$"):
    if not isinstance(schema, dict):
        die(3, f"[schema-error] {where}: schema node must be an object")
    unknown = set(schema) - ANNOTATIONS - ASSERTIONS
    if unknown:
        die(3, f"[schema-error] {where}: unsupported keywords: {', '.join(sorted(unknown))}")
    for name, child in (schema.get("properties") or {}).items():
        audit_schema(child, f"{where}.properties.{name}")
    if isinstance(schema.get("items"), dict):
        audit_schema(schema["items"], f"{where}.items")
    for index, child in enumerate(schema.get("allOf") or []):
        audit_schema(child, f"{where}.allOf[{index}]")
    for keyword in ("if", "then"):
        if isinstance(schema.get(keyword), dict):
            audit_schema(schema[keyword], f"{where}.{keyword}")


def type_matches(value, expected):
    return {
        "object": isinstance(value, dict),
        "array": isinstance(value, list),
        "string": isinstance(value, str),
        "integer": isinstance(value, int) and not isinstance(value, bool),
        "number": isinstance(value, (int, float)) and not isinstance(value, bool),
        "boolean": isinstance(value, bool),
        "null": value is None,
    }.get(expected, False)


def valid_datetime(value):
    if not isinstance(value, str):
        return False
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
        return "T" in value and parsed.tzinfo is not None and parsed.utcoffset() is not None
    except ValueError:
        return False


def validate(value, schema, where="$", errors=None):
    errors = [] if errors is None else errors
    expected = schema.get("type")
    if expected and not type_matches(value, expected):
        errors.append(f"{where}: expected {expected}, got {type(value).__name__}")
        return errors
    if "const" in schema and value != schema["const"]:
        errors.append(f"{where}: must equal {schema['const']!r}")
    if "enum" in schema and value not in schema["enum"]:
        errors.append(f"{where}: value {value!r} is not in the allowed enum")

    for child in schema.get("allOf") or []:
        validate(value, child, where, errors)
    if isinstance(schema.get("if"), dict):
        condition_errors = []
        validate(value, schema["if"], where, condition_errors)
        if not condition_errors and isinstance(schema.get("then"), dict):
            validate(value, schema["then"], where, errors)

    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for key in schema.get("required", []):
            if key not in value:
                errors.append(f"{where}: missing required property {key!r}")
        if schema.get("additionalProperties") is False:
            for key in value.keys() - properties.keys():
                errors.append(f"{where}: additional property {key!r} is not allowed")
        for key, child in properties.items():
            if key in value:
                validate(value[key], child, f"{where}.{key}", errors)

    if isinstance(value, list):
        if len(value) < schema.get("minItems", 0):
            errors.append(f"{where}: needs at least {schema['minItems']} items")
        if "maxItems" in schema and len(value) > schema["maxItems"]:
            errors.append(f"{where}: allows at most {schema['maxItems']} items")
        if schema.get("uniqueItems"):
            canonical = [json.dumps(item, sort_keys=True, separators=(",", ":")) for item in value]
            if len(canonical) != len(set(canonical)):
                errors.append(f"{where}: items must be unique")
        if isinstance(schema.get("items"), dict):
            for index, item in enumerate(value):
                validate(item, schema["items"], f"{where}[{index}]", errors)

    if isinstance(value, str):
        if len(value) < schema.get("minLength", 0):
            errors.append(f"{where}: string shorter than {schema['minLength']}")
        if "maxLength" in schema and len(value) > schema["maxLength"]:
            errors.append(f"{where}: string longer than {schema['maxLength']}")
        if "pattern" in schema and re.fullmatch(schema["pattern"], value) is None:
            errors.append(f"{where}: does not match {schema['pattern']!r}")
        if schema.get("format") == "date-time" and not valid_datetime(value):
            errors.append(f"{where}: must be an ISO 8601 date-time")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{where}: must be >= {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{where}: must be <= {schema['maximum']}")
    return errors


def main():
    parser = argparse.ArgumentParser(description="validate an ooda-loop intake JSON contract")
    parser.add_argument("kind", choices=sorted(SCHEMAS))
    parser.add_argument("input")
    parser.add_argument("--schema", help="override schema path for contract development")
    parser.add_argument("--trusted-root", help="canonical root that must contain the input (blocks symlink/path escape)")
    args = parser.parse_args()

    schema = load(args.schema or SCHEMAS[args.kind])
    audit_schema(schema)
    errors = validate(load(args.input, args.trusted_root), schema)
    if errors:
        die(3, "[SpecError] intake contract refused:\n- " + "\n- ".join(errors))
    print(f"[ok] {args.kind} validates")


if __name__ == "__main__":
    main()
