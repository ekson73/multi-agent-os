import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

const here = new URL("../templates/", import.meta.url);

async function json(name) {
  return JSON.parse(await readFile(new URL(name, here), "utf8"));
}

function validateProfile(profile) {
  assert.equal(profile.contract_version, "1.0");
  assert.match(profile.operator?.language ?? "", /^[a-z]{2,3}(-[A-Z]{2}|-[0-9]{3})?$/);
  assert.ok(["limited", "working", "advanced"].includes(profile.operator?.technical_literacy));
  assert.ok(["none", "bounded", "delegated"].includes(profile.authority?.technical_delegation));
  assert.ok(Array.isArray(profile.authority?.human_decision_domains));
  assert.deepEqual(new Set(profile.authority?.hard_stop_domains), new Set([
    "secret", "personal-data", "identity-or-access", "money-or-cost",
    "legal-or-regulated-effect", "external-communication", "cross-organization",
    "destructive-or-irreversible"
  ]));
  assert.ok(Array.isArray(profile.sources?.authoritative));
  assert.deepEqual(new Set(["discord-message", "slack-message", "jira-issue", "linear-issue"]),
    new Set(profile.sources?.signal_only.filter((source) =>
      ["discord-message", "slack-message", "jira-issue", "linear-issue"].includes(source))));
  assert.ok(Array.isArray(profile.delivery?.permitted_stages));
  assert.ok(["disabled", "gated"].includes(profile.delivery?.deploy_mode));
}

test("operator-profile example is valid JSON and satisfies the portable contract", async () => {
  const [schema, example] = await Promise.all([
    json("operator-profile.schema.json"),
    json("operator-profile.example.json")
  ]);

  assert.equal(schema.$schema, "https://json-schema.org/draft/2020-12/schema");
  assert.equal(schema.$id, "urn:multi-agent-os:operator-profile:1.0");
  assert.equal(schema.additionalProperties, false);
  assert.equal(schema.properties.contract_version.const, "1.0");
  assert.equal(schema.properties.authority.properties.hard_stop_domains.minItems, 8);
  assert.equal(schema.properties.authority.properties.hard_stop_domains.maxItems, 8);
  validateProfile(example);
});

test("profile rejects an invented deployment authorization", async () => {
  const profile = await json("operator-profile.example.json");
  profile.delivery.deploy_mode = "authorized";
  assert.throws(() => validateProfile(profile));
});

test("profile rejects an attempt to waive a hard boundary", async () => {
  const profile = await json("operator-profile.example.json");
  profile.authority.hard_stop_domains.pop();
  assert.throws(() => validateProfile(profile));
});
