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

test("stdlib validator accepts both complete examples", () => {
  for (const [kind, name] of [
    ["operator-profile", "operator-profile.example.json"],
    ["trigger-envelope", "trigger-envelope.example.json"]
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
  const skill = await readFile(path.join(root, "SKILL.md"), "utf8");
  const profile = await json("operator-profile.schema.json");
  const stages = profile.properties.delivery.properties.candidate_stages.items.enum;
  const outputLine = skill.match(/"lifecycle_stage":"([^"]+)"/);
  assert.ok(outputLine, "SKILL output contract must expose lifecycle stages");
  assert.deepEqual(outputLine[1].split("|"), stages);
});

test("skill treats profile delivery fields as restrictive routing constraints", async () => {
  const skill = await readFile(path.join(root, "SKILL.md"), "utf8");
  assert.match(skill, /intersect it with a valid profile's[\s\S]*candidate_stages/);
  assert.match(skill, /never widen the list by inference/);
  assert.match(skill, /delivery\.deploy_mode=disabled/);
  assert.match(skill, /postflight sweep\/debrief\/handoff path[\s\S]*--no-spawn/);
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
