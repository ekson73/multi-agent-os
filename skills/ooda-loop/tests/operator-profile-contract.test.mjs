import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { spawnSync } from "node:child_process";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const templates = path.join(root, "templates");
const validator = path.join(root, "bin", "validate_intake_contract.py");

async function json(name) {
  return JSON.parse(await readFile(path.join(templates, name), "utf8"));
}

function validate(kind, file) {
  return spawnSync("python3", [validator, kind, file], { encoding: "utf8" });
}

async function withMutation(sourceName, mutate, check) {
  const directory = await mkdtemp(path.join(tmpdir(), "ooda-intake-"));
  try {
    const value = await json(sourceName);
    mutate(value);
    const file = path.join(directory, "case.json");
    await writeFile(file, `${JSON.stringify(value, null, 2)}\n`);
    check(file);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

test("stdlib validator accepts all complete contract examples", () => {
  for (const [kind, name] of [
    ["operator-profile", "operator-profile.example.json"],
    ["trigger-envelope", "trigger-envelope.example.json"],
    ["run-envelope", "run-envelope.example.json"]
  ]) {
    const result = validate(kind, path.join(templates, name));
    assert.equal(result.status, 0, result.stderr);
  }
});

test("operator profile refuses invented authority, waived baseline and extra fields", async () => {
  const cases = [
    (value) => { value.authority.technical_delegation_claim = "authorized"; },
    (value) => { value.authority.baseline_acknowledgements.pop(); },
    (value) => { value.authority.human_decision_domains.push("business-rule"); },
    (value) => { value.authority.grant = "deploy"; },
    (value) => { delete value.provenance.expires_at; },
    (value) => { delete value.operator.role; },
    (value) => { value.delivery.candidate_stages = ["not-a-stage"]; }
  ];
  for (const mutate of cases) {
    await withMutation("operator-profile.example.json", mutate, (file) => {
      const result = validate("operator-profile", file);
      assert.equal(result.status, 3, result.stdout + result.stderr);
    });
  }
});

test("trigger envelope refuses control-plane injection and unsafe raw payload metadata", async () => {
  const cases = [
    (value) => { value.security.raw_payload_retained = true; },
    (value) => { value.security.authority_claim = "authorized"; },
    (value) => { value.request.auto_merge = "authorized"; },
    (value) => { value.request.summary = ""; },
    (value) => { value.idempotency.replay_key = "not-a-digest"; },
    (value) => { value.freshness.max_age_seconds = 0; },
    (value) => { value.event.observed_at = "2026-08-01T12:00:00"; },
    (value) => { value.event.observed_at = "2026-99-99T99:99:99Z"; },
    (value) => { delete value.connector.authentication_state; },
    (value) => { value.binding.project_slug = "../escape"; }
  ];
  for (const mutate of cases) {
    await withMutation("trigger-envelope.example.json", mutate, (file) => {
      const result = validate("trigger-envelope", file);
      assert.equal(result.status, 3, result.stdout + result.stderr);
    });
  }
});

test("validator fails closed if a future schema adds an unsupported assertion", async () => {
  const directory = await mkdtemp(path.join(tmpdir(), "ooda-schema-"));
  try {
    const schema = await json("operator-profile.schema.json");
    schema.oneOf = [{ required: ["operator"] }];
    const schemaFile = path.join(directory, "schema.json");
    await writeFile(schemaFile, `${JSON.stringify(schema)}\n`);
    const result = spawnSync("python3", [
      validator,
      "operator-profile",
      path.join(templates, "operator-profile.example.json"),
      "--schema",
      schemaFile
    ], { encoding: "utf8" });
    assert.equal(result.status, 3, result.stdout + result.stderr);
    assert.match(result.stderr, /unsupported keywords/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});

test("skill output lifecycle stages match the intake contract", async () => {
  const profile = await json("operator-profile.schema.json");
  const run = await json("run-envelope.schema.json");
  assert.deepEqual(
    run.properties.intake.properties.lifecycle_stage.enum,
    profile.properties.delivery.properties.candidate_stages.items.enum
  );
});

test("run envelope refuses vocabulary drift and unstructured authority", async () => {
  const cases = [
    (value) => { value.result.outcome = "PARTIAL"; },
    (value) => { value.result.stop_marker = "STOP-HITL-TECHNICAL"; },
    (value) => { value.intake.lifecycle_stage = "reveng"; },
    (value) => { value.intake.execution_authority = "proven"; },
    (value) => { value.result = { outcome: "DELIVERY_DONE", status: "error", stop_marker: "STOP-HITL", route: "act" }; },
    (value) => { value.result = { outcome: "PARKED_PARTIAL", status: "ok", stop_marker: "STOP-DONE", route: "park" }; },
    (value) => { value.result = { outcome: "BLOCKED_HITL", status: "hitl", stop_marker: "STOP-ERROR", route: "act" }; },
    (value) => { value.result = { outcome: "ERROR", status: "partial", stop_marker: "CONTINUE", route: "consult" }; },
    (value) => {
      value.result = { outcome: "CONTINUE", status: "partial", stop_marker: "CONTINUE", route: "act" };
      value.intake.execution_authority.state = "denied";
      value.intake.access = "ACCESS_FORBIDDEN";
    },
    (value) => { value.unexpected = true; }
  ];
  for (const mutate of cases) {
    await withMutation("run-envelope.example.json", mutate, (file) => {
      const result = validate("run-envelope", file);
      assert.equal(result.status, 3, result.stdout + result.stderr);
    });
  }
});

test("run envelope permits ACT only with proven authority and ready access", async () => {
  await withMutation("run-envelope.example.json", (value) => {
    value.result = { outcome: "DELIVERY_DONE", status: "ok", stop_marker: "STOP-DONE", route: "act" };
    value.intake.execution_authority.state = "proven";
    value.intake.execution_authority.evidence_refs = ["repository-policy:accepted-decision-42"];
    value.intake.access = "ACCESS_READY";
  }, (file) => {
    const result = validate("run-envelope", file);
    assert.equal(result.status, 0, result.stdout + result.stderr);
  });
});

test("skill treats profile delivery fields as restrictive routing constraints", async () => {
  const skill = await readFile(path.join(root, "SKILL.md"), "utf8");
  assert.match(skill, /intersect it with a valid profile's[\s\S]*candidate_stages/);
  assert.match(skill, /never widen the list by inference/);
  assert.match(skill, /delivery\.deploy_mode=disabled/);
  assert.match(skill, /postflight sweep\/debrief\/handoff path[\s\S]*--no-spawn/);
});

test("skill separates unresolved operator intent from ordinary technical uncertainty", async () => {
  const skill = await readFile(path.join(root, "SKILL.md"), "utf8");
  assert.doesNotMatch(skill, /RESOLVE-INCONCLUSIVE/);
  assert.match(skill, /unresolved operator goal or acceptance intent reported inconclusive/);
  assert.match(skill, /inconclusive\.flag=true[\s\S]*STOP-HITL/);
  assert.match(skill, /unresolved technical residue becomes `STOP-PARKED`/);
  assert.doesNotMatch(skill, /any red\s*->\s*HITL/);
  assert.match(skill, /autonomy_score below threshold[\s\S]*still below threshold -> STOP-PARKED/);
  assert.match(skill, /STOP-DONE[\s\S]*DELIVERY_DONE only[\s\S]*no applicable gap\/open SPEC\/failed check\/pending promotion/);
  assert.doesNotMatch(skill, /CONTINUE[^\n]*score < threshold/);
});

test("trusted-root mode rejects a canonical path escape", async () => {
  const directory = await mkdtemp(path.join(tmpdir(), "ooda-root-escape-"));
  try {
    const outside = path.join(directory, "profile.json");
    await writeFile(outside, await readFile(path.join(templates, "operator-profile.example.json")));
    const result = spawnSync("python3", [
      validator,
      "operator-profile",
      outside,
      "--trusted-root",
      templates
    ], { encoding: "utf8" });
    assert.equal(result.status, 3, result.stdout + result.stderr);
    assert.match(result.stderr, /escapes trusted root/);
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
});
