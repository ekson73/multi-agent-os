import assert from "node:assert/strict";
import { createHash, randomUUID } from "node:crypto";
import { spawnSync } from "node:child_process";
import fs from "node:fs";
import { cp, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

const root = fileURLToPath(new URL("../", import.meta.url));
const cli = path.join(root, "bin", "model-bundle.mjs");
const fixtures = path.join(root, "tests", "fixtures");
const activeFixture = path.join(fixtures, "neutral-active.session-model.json");
const readyFixture = path.join(fixtures, "neutral-ready.session-model.json");
const userHome = os.userInfo().homedir;
const stockArchify = [path.join(userHome, ".agents", "skills", "archify"), path.join(userHome, ".claude", "skills", "archify")]
  .find((candidate) => fs.existsSync(path.join(candidate, "bin", "archify.mjs")));
const STATES = ["planned", "started", "delegated", "deferred", "hitl", "blocked", "completed", "canceled", "superseded", "deprecated", "unknown"];
const ALLOWED = {
  planned: ["started", "delegated", "deferred", "hitl", "canceled", "superseded", "deprecated"],
  delegated: ["started", "deferred", "hitl", "canceled", "superseded"],
  started: ["completed", "blocked", "deferred", "hitl", "canceled", "superseded"],
  blocked: ["started", "deferred", "hitl", "canceled", "superseded"],
  deferred: ["planned", "hitl", "canceled", "superseded", "deprecated"],
  hitl: ["planned", "started", "deferred", "canceled"],
  completed: ["superseded", "deprecated"], canceled: [], superseded: [], deprecated: [],
  unknown: ["planned", "deferred", "hitl", "canceled"]
};

function run(args) {
  return spawnSync(process.execPath, [cli, ...args], { encoding: "utf8" });
}
function body(stream) {
  try { return JSON.parse(stream.trim()); }
  catch (error) { throw new Error(`Failed to parse JSON output: ${error.message}\n--- captured output ---\n${stream}`); }
}
function sha(bytes) { return createHash("sha256").update(bytes).digest("hex"); }
function decodeCapsule(html, id) {
  const match = html.match(new RegExp(`<script id="${id}"[^>]*>([A-Za-z0-9_-]+)<\\/script>`, "u"));
  return JSON.parse(Buffer.from(match[1], "base64url").toString("utf8"));
}
function replaceCapsule(html, id, value) {
  const bytes = Buffer.from(JSON.stringify(value));
  const pattern = new RegExp(`(<script id="${id}"[^>]*data-bytes=")\\d+(" data-sha256=")[a-f0-9]{64}(">)[A-Za-z0-9_-]+(<\\/script>)`, "u");
  return html.replace(pattern, (_whole, start, digestPrefix, openEnd, close) =>
    `${start}${bytes.length}${digestPrefix}${sha(bytes)}${openEnd}${bytes.toString("base64url")}${close}`);
}
async function temp(work) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "vasm-v2-"));
  try { return await work(directory); } finally { await rm(directory, { recursive: true, force: true }); }
}
async function copyModel(directory, source = activeFixture) {
  const file = path.join(directory, "model.session-model.json");
  await cp(source, file);
  return file;
}
async function mutateModel(directory, mutate, source = activeFixture) {
  const file = await copyModel(directory, source);
  const model = JSON.parse(await readFile(file, "utf8"));
  mutate(model);
  await writeFile(file, `${JSON.stringify(model, null, 2)}\n`);
  return file;
}
async function renderPortable(directory, source = activeFixture) {
  const model = await copyModel(directory, source);
  const out = path.join(directory, "bundle");
  const result = run(["render", model, "--profile", "portable-sidecard", "--out", out]);
  return { model, out, result, resultBody: result.stdout ? body(result.stdout) : null };
}
function lifecycle(state) {
  const base = { state, reason: null, assigned_actor_ref: null, started_at: null, ended_at: null, resume_after: null, decision_ref: null, successor_ref: null, evidence_refs: [] };
  if (state === "started") base.started_at = "2026-09-12T12:00:00Z";
  if (state === "delegated") base.assigned_actor_ref = "actor_compiler";
  if (state === "deferred") { base.reason = "Deferred for a bounded reason"; base.resume_after = "2026-09-13T12:00:00Z"; }
  if (state === "hitl") { base.reason = "A human decision is required"; base.decision_ref = "ref_policy"; }
  if (["blocked", "unknown"].includes(state)) base.reason = "State requires an explicit reason";
  if (state === "completed") { base.started_at = "2026-09-12T11:00:00Z"; base.ended_at = "2026-09-12T12:00:00Z"; base.evidence_refs = ["ref_review"]; }
  if (["canceled", "deprecated"].includes(state)) { base.reason = "Terminal disposition"; base.ended_at = "2026-09-12T12:00:00Z"; }
  if (state === "superseded") { base.reason = "A successor replaces this item"; base.ended_at = "2026-09-12T12:00:00Z"; base.successor_ref = "work_publish"; }
  return base;
}
function reconciliation() {
  return ["semantic_source", "workflow", "plan", "roadmap", "organization_model", "knowledge_base"]
    .map((surface) => ({ surface, disposition: "no_change", reason: `${surface} remains accurate`, evidence_refs: [] }));
}
function eventFor(from, to, digest) {
  return {
    event_id: `event_${from}_${to}`,
    task_ref: "work_review", from_state: from, to_state: to,
    occurred_at: "2026-09-12T14:00:00Z", base_source_sha256: digest,
    reason: "Observed lifecycle transition", evidence_refs: ["ref_review"],
    assigned_actor_ref: to === "delegated" ? "actor_compiler" : null,
    resume_after: to === "deferred" ? "2026-09-13T14:00:00Z" : null,
    decision_ref: ["deferred", "hitl"].includes(to) ? "ref_policy" : null,
    successor_ref: to === "superseded" ? "work_publish" : null,
    reconciliation: reconciliation()
  };
}
function childRequest(overrides = {}) {
  return {
    schema_version: "1.0.0", kind: "agentic_session_child_request", derivation_plan_id: randomUUID(),
    target_project_slug: "child-project", target_repository_uri: "https://example.com/public/child-project",
    subject_slug: "child-session", purpose_slug: "public-coordination", target_domain_slugs: ["delivery"],
    as_of: "2026-09-13T12:00:00Z", version: "1.0.0",
    capability_ceiling: ["read_public_evidence", "validate_model", "render_sidecard"],
    inherited_material_ids: [],
    ...overrides
  };
}

test("v2 fixtures validate and expose the exact lifecycle vocabulary", () => {
  for (const fixture of [activeFixture, readyFixture]) {
    const result = run(["validate", fixture]);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(body(result.stdout).derived.status_counts.map((item) => item.status), STATES);
  }
});

test("legacy state aliases and incomplete lifecycle conditionals fail closed", async () => {
  await temp(async (directory) => {
    const legacy = await mutateModel(directory, (model) => { model.topology.nodes[0].status = "done"; });
    assert.equal(run(["validate", legacy]).status, 1);
  });
  for (const state of STATES) {
    await temp(async (directory) => {
      const valid = await mutateModel(directory, (model) => { model.plan.work_items[0].lifecycle_state = lifecycle(state); });
      assert.equal(run(["validate", valid]).status, 0, state);
      const invalid = JSON.parse(await readFile(valid, "utf8"));
      if (state === "planned") invalid.plan.work_items[0].lifecycle_state.started_at = "2026-09-12T12:00:00Z";
      else if (state === "started") invalid.plan.work_items[0].lifecycle_state.started_at = null;
      else if (state === "delegated") invalid.plan.work_items[0].lifecycle_state.assigned_actor_ref = null;
      else if (state === "deferred") invalid.plan.work_items[0].lifecycle_state.resume_after = null;
      else if (state === "hitl") invalid.plan.work_items[0].lifecycle_state.decision_ref = null;
      else if (["blocked", "unknown"].includes(state)) invalid.plan.work_items[0].lifecycle_state.reason = null;
      else if (state === "completed") invalid.plan.work_items[0].lifecycle_state.evidence_refs = [];
      else invalid.plan.work_items[0].lifecycle_state.ended_at = null;
      await writeFile(valid, `${JSON.stringify(invalid, null, 2)}\n`);
      assert.equal(run(["validate", valid]).status, 1, `invalid ${state}`);
    });
  }
});

test("deferred requires reason AND resume_after independently - losing either rule is caught", async () => {
  for (const field of ["reason", "resume_after"]) {
    await temp(async (directory) => {
      const valid = await mutateModel(directory, (model) => { model.plan.work_items[0].lifecycle_state = lifecycle("deferred"); });
      assert.equal(run(["validate", valid]).status, 0, `deferred baseline (${field})`);
      const invalid = JSON.parse(await readFile(valid, "utf8"));
      invalid.plan.work_items[0].lifecycle_state[field] = null;
      // A decision reference must not stand in for the missing field.
      invalid.plan.work_items[0].lifecycle_state.decision_ref = "ref_policy";
      await writeFile(valid, `${JSON.stringify(invalid, null, 2)}\n`);
      const result = run(["validate", valid]);
      assert.equal(result.status, 1, `deferred with ${field}=null must fail closed`);
      assert.ok(body(result.stderr).error.details.some((item) => item.path.endsWith(`/${field}`) && item.code === "LIFECYCLE_CONDITION"), result.stderr);
    });
  }
});

test("return edges preserve feedback loops without weakening dependency-cycle rejection", async () => {
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => {
      value.topology.edges.push({ id: "edge_publish_collect_return", from: "publish", to: "collect", role: "return" });
    });
    const result = run(["validate", model]);
    assert.equal(result.status, 0, result.stderr);
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => {
      value.topology.edges.push({ id: "edge_publish_collect_main", from: "publish", to: "collect", role: "main" });
    });
    const result = run(["validate", model]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "MODEL_SEMANTIC_INVALID");
    assert.ok(body(result.stderr).error.details.some((item) => item.code === "TOPOLOGY_CYCLE"));
  });
});

test("identity, traceability, two-world organization and public-only rules are enforced", async () => {
  const mutations = [
    (model) => { model.traceability.semantic_version = "3.0.0"; },
    (model) => { model.organization.contexts.pop(); },
    (model) => { model.organization.worlds[0].kind = "agentic"; },
    (model) => { model.organization.actors[0].world_ref = "world_agentic"; },
    (model) => { model.organization.classifications.find((item) => item.class === "pii").disposition = "included"; },
    (model) => { model.references[0].distribution = "internal"; },
    (model) => { model.traceability.git.repository_uri = "https://example.com/private/repo"; },
    (model) => { model.inert_material.dna[0].source_sha256 = "0".repeat(64); }
  ];
  for (const mutate of mutations) await temp(async (directory) => {
    const file = await mutateModel(directory, mutate);
    const validate = run(["validate", file]);
    if (validate.status === 0) {
      const rendered = run(["render", file, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
      assert.equal(rendered.status, 1);
    } else assert.equal(validate.status, 1);
  });
});

test("portable render is Archify-independent and emits exactly two canonical capsules", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    assert.equal(rendered.resultBody.profile, "portable_sidecard");
    assert.equal(rendered.resultBody.trust, "CONSISTENT_UNTRUSTED");
    assert.equal(rendered.resultBody.embedded_blocks.length, 2);
    const html = await readFile(rendered.resultBody.outputs.sidecard, "utf8");
    assert.equal((html.match(/<script\b/gu) || []).length, 2);
    assert.doesNotMatch(html, /<script[^>]*type=["'](?:text|application)\/javascript/iu);
    const inspect = run(["inspect", rendered.resultBody.outputs.sidecard]);
    assert.equal(inspect.status, 0, inspect.stderr);
    assert.deepEqual(body(inspect.stdout).blocks, ["vasm-semantic-source", "vasm-render-receipt"]);
    assert.match(path.basename(rendered.resultBody.outputs.sidecard), /^agentic-session-sidecard-knowledge-release-verified-coordination--20260912T120000Z-r1-v2\.0\.0--h[a-f0-9]{12}\.sidecard\.html$/u);
    assert.ok(rendered.resultBody.embedded_blocks.every((block) => block.encoding === "base64url" && block.canonicalization === "rfc8785-jcs" && /^[a-f0-9]{64}$/u.test(block.sha256)));
    const verify = run(["verify", rendered.resultBody.manifest]);
    assert.equal(verify.status, 0, verify.stderr);
  });
});

test("portable sidecard renders an accessible directed SVG before status nodes with textual fallback", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const html = await readFile(rendered.resultBody.outputs.sidecard, "utf8");
    assert.match(html, /<svg id="dependency-graph"[^>]*role="img"[^>]*aria-labelledby="dependency-graph-title dependency-graph-desc"/u);
    assert.match(html, /<title id="dependency-graph-title">Agentic session dependency workflow<\/title>/u);
    assert.match(html, /<desc id="dependency-graph-desc">Directed dependencies grouped by lane\./u);
    assert.equal((html.match(/data-node-id=/gu) || []).length, 4);
    assert.equal((html.match(/data-edge-id=/gu) || []).length, 3);
    assert.ok(html.indexOf('aria-label="Directed edges"') < html.indexOf('aria-label="Status nodes"'));
    assert.match(html, /class="svg-item state-started" data-node-id="compose" data-state="started"/u);
    assert.match(html, /class="svg-item state-completed" data-node-id="collect" data-state="completed"/u);
    assert.match(html, /class="node state-started" data-state="started"/u);
    assert.match(html, /class="node state-completed" data-state="completed"/u);
    assert.match(html, /class="state-row state-started" data-state="started"/u);
    assert.match(html, /class="state-row state-completed" data-state="completed"/u);
    assert.match(html, /<div class="workflow-scroll" role="region" aria-label="Scrollable workflow diagram" tabindex="0">/u);
    assert.match(html, /class="edge-group edge-role-main edge-variant-emphasis"/u);
    assert.match(html, /class="svg-edge-arrow"/u);
    assert.match(html, /<h3>Diagram Key<\/h3>/u);
    assert.match(html, /Geometry is schematic; node colour, glyph, and label encode state\./u);
    assert.match(html, /<summary>Text Register · 4 Nodes · 3 Directed Edges<\/summary>/u);
    assert.match(html, /role=<code>main<\/code> · variant=<code>emphasis<\/code> · route=<code>drop<\/code>/u);
    assert.ok(html.includes("font:15px/1.55 var(--font-ui)"));
    assert.ok(html.includes("--bg:#0d1117;--panel:#161b22"));
    assert.ok(html.includes("@media screen and (max-width:1000px){.workflow-svg{min-width:900px}}"));
    assert.ok(html.includes("@media screen and (max-width:720px){main{padding:16px 14px 48px}.grid{grid-template-columns:minmax(0,1fr)}"));
    assert.ok(!/@media\s*\(max-width/u.test(html), "width breakpoints must be screen-qualified so print never inherits mobile layout");
    assert.ok(html.includes("@media print{:root{color-scheme:light"));
    assert.ok(html.includes("details:not([open])>*:not(summary){display:block!important}"));
  });
});

test("portable sidecard is served with a UTF-8 BOM so file:// charset-sniffing cannot mangle it", async () => {
  // Regression test for a real incident: Chromium's local-file loader overrode an explicit
  // <meta charset="utf-8"> and rendered every state glyph as mojibake. A prior fix for this
  // was claimed in a commit message but never actually landed (a script crashed before its
  // write() call) and the 39-test suite at the time stayed green throughout - this asserts
  // the actual bytes, not a changelog claim, so that exact failure class cannot recur silently.
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const bytes = await readFile(rendered.resultBody.outputs.sidecard);
    assert.deepEqual(bytes.subarray(0, 3), Buffer.from([0xef, 0xbb, 0xbf]), "sidecard must start with a UTF-8 BOM");
    const html = bytes.toString("utf8");
    assert.ok(html.startsWith("\ufeff<!doctype html>"), "BOM must precede the doctype, not corrupt it");
  });
});

test("workflow diagram has an always-visible edge-fade cue (painted above SVG content) and honors reduced motion", async () => {
  // Regression test, round 2: a first "position-aware" attempt (paired background-
  // attachment:local/scroll gradients on .workflow-scroll) was claimed fixed twice before
  // it actually shipped, and even once it did ship, an independent council re-check proved
  // it was imperceptible in practice - opaque <rect> lane-band fills inside the child SVG
  // paint on top of a parent's background regardless of the SVG's own background being
  // transparent, so the "fix" was real in computed style but invisible on screen. Replaced
  // with a static ::before/::after overlay on the non-scrolling .workflow-figure wrapper,
  // which paints ON TOP of the SVG (pseudo-elements are the last child in local paint
  // order) - guaranteed visible, at the cost of not being scroll-position-aware. This test
  // asserts the CSS that makes it actually visible (z-index + no scroll-following
  // background-attachment), not just "a gradient exists somewhere".
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const html = await readFile(rendered.resultBody.outputs.sidecard, "utf8");
    assert.ok(html.includes(".workflow-figure::before,.workflow-figure::after"), "edge-fade must be a pseudo-element pair on the non-scrolling wrapper, not a scrolling background layer");
    assert.ok(html.includes("z-index:1"), "edge-fade must be explicitly stacked above the SVG's own paint order");
    assert.ok(html.includes("pointer-events:none"), "edge-fade must not intercept scroll/drag interaction");
    assert.equal((html.match(/linear-gradient\(-?90deg,var\(--bg\),transparent 85%\)/gu) || []).length, 2, "edge-fade requires exactly one gradient layer per side");
    assert.match(html, /@media\s*\(prefers-reduced-motion:\s*reduce\)\{[^}]*\.edge-role-main \.svg-edge,\.svg-item \.svg-node\{animation:none!important/u);
  });
});

test("inspect rejects noncanonical capsule encoding without writing", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const file = rendered.resultBody.outputs.sidecard;
    const html = await readFile(file, "utf8");
    const altered = html.replace(/(<script id="vasm-semantic-source"[^>]*>)([A-Za-z0-9_-]+)(<\/script>)/u, "$1$2=$3");
    await writeFile(file, altered);
    const inspect = run(["inspect", file]);
    assert.equal(inspect.status, 1);
    assert.ok(["CAPSULE_BLOCK_SET_INVALID", "CAPSULE_ENCODING_INVALID"].includes(body(inspect.stderr).error.code));
  });
});

test("inspect rejects visible outer-sidecard tampering even when capsules remain intact", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const file = rendered.resultBody.outputs.sidecard;
    const altered = (await readFile(file, "utf8")).replace("Nonbinding governance snapshot", "Altered governance snapshot");
    await writeFile(file, altered);
    const inspect = run(["inspect", file]);
    assert.equal(inspect.status, 1);
    assert.equal(body(inspect.stderr).error.code, "SIDECARD_OUTER_MISMATCH");
  });
});

test("inspect re-runs sensitive scanning on internally rebound capsules", async () => {
  await temp(async (directory) => {
    const raw = "capsule-owner@private-domain.dev";
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const file = rendered.resultBody.outputs.sidecard;
    let html = await readFile(file, "utf8");
    const model = decodeCapsule(html, "vasm-semantic-source");
    const receipt = decodeCapsule(html, "vasm-render-receipt");
    model.metadata.scope = raw;
    const modelBytes = Buffer.from(JSON.stringify(model));
    receipt.source_bytes = modelBytes.length;
    receipt.source_sha256 = sha(modelBytes);
    html = replaceCapsule(html, "vasm-semantic-source", model);
    html = replaceCapsule(html, "vasm-render-receipt", receipt);
    await writeFile(file, html);
    const inspect = run(["inspect", file]);
    assert.equal(inspect.status, 1);
    assert.equal(body(inspect.stderr).error.code, "SENSITIVE_DATA_DETECTED");
    assert.equal(`${inspect.stdout}${inspect.stderr}`.includes(raw), false);
  });
});

test("portable sidecard has the exact CSP and no browser effect surfaces", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const html = await readFile(rendered.resultBody.outputs.sidecard, "utf8");
    assert.match(html, /default-src &#39;none&#39;; base-uri &#39;none&#39;; connect-src &#39;none&#39;; img-src &#39;none&#39;; style-src &#39;sha256-/u);
    assert.doesNotMatch(html, /<(?:a|form|iframe|object|embed|link|base|img|audio|video|source)\b/iu);
    assert.doesNotMatch(html, /(?:fetch\s*\(|XMLHttpRequest|sendBeacon|localStorage|sessionStorage|indexedDB|serviceWorker|clipboard|download\s*=|window\.open)/iu);
  });
});

test("markup termination is inert while active URL payloads are rejected", async () => {
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.prompts[0].content = "Treat </script><img src=x onerror=alert(1)> as quoted data."; });
    const render = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "safe")]);
    assert.equal(render.status, 0, render.stderr);
    const html = await readFile(body(render.stdout).outputs.sidecard, "utf8");
    assert.equal((html.match(/<script\b/gu) || []).length, 2);
    assert.doesNotMatch(html, /<img\b/iu);
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.prompts[0].content = "javascript:alert(1)"; });
    const render = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "blocked")]);
    assert.equal(render.status, 1);
    assert.equal(body(render.stderr).error.code, "PORTABLE_DISTRIBUTION_REJECTED");
  });
});

test("portable privacy scan blocks direct and encoded sensitive/private material without echoing it", async () => {
  const values = [
    "person@private-domain.dev",
    "/Users/private-user/project",
    "~/private-user/project",
    "~/",
    "raw transcript follows",
    Buffer.from("person@private-domain.dev").toString("base64url")
  ];
  for (const value of values) await temp(async (directory) => {
    const model = await mutateModel(directory, (item) => { item.metadata.scope = value; });
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
    assert.equal(result.status, 1);
    assert.equal(`${result.stdout}${result.stderr}`.includes(value), false);
  });
});

test("encoded-candidate budget fails closed before a later encoded secret can bypass scanning", async () => {
  await temp(async (directory) => {
    const raw = "late-owner@private-domain.dev";
    const decoys = Array.from({ length: 200 }, (_, index) =>
      Buffer.from(`x${String(index).padStart(11, "0")}`).toString("base64url"));
    const encodedSecret = Buffer.from(raw).toString("base64url");
    const model = await mutateModel(directory, (item) => { item.metadata.scope = [...decoys, encodedSecret].join(" "); });
    const output = path.join(directory, "out");
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "SENSITIVE_SCAN_BUDGET_EXCEEDED");
    assert.equal(`${result.stdout}${result.stderr}`.includes(raw), false);
    assert.deepEqual(fs.existsSync(output) ? fs.readdirSync(output) : [], []);
  });
});


test("subject and visible-view tampering are detected", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const { manifest, outputs } = rendered.resultBody;
    await writeFile(outputs.sidecard, Buffer.concat([await readFile(outputs.sidecard), Buffer.from(" ")]));
    const verify = run(["verify", manifest]);
    assert.equal(verify.status, 1);
    assert.equal(body(verify.stderr).error.code, "HASH_MISMATCH");
  });
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const manifest = JSON.parse(await readFile(rendered.resultBody.manifest, "utf8"));
    const htmlSubject = manifest.subjects.find((item) => item.role === "sidecard_html");
    const htmlFile = rendered.resultBody.outputs.sidecard;
    const altered = (await readFile(htmlFile, "utf8")).replace("Current Disposition", "Altered Disposition");
    await writeFile(htmlFile, altered);
    htmlSubject.digest.value = sha(Buffer.from(altered));
    await writeFile(rendered.resultBody.manifest, `${JSON.stringify(manifest, null, 2)}\n`);
    const verify = run(["verify", rendered.resultBody.manifest]);
    assert.equal(verify.status, 1);
    assert.equal(body(verify.stderr).error.code, "SIDECARD_OUTER_MISMATCH");
  });
});

test("fresh verify re-runs sensitive scanning before parity success", async () => {
  await temp(async (directory) => {
    const raw = "verified-owner@private-domain.dev";
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const manifest = JSON.parse(await readFile(rendered.resultBody.manifest, "utf8"));
    const sourceSubject = manifest.subjects.find((item) => item.role === "source");
    const sourceFile = path.join(rendered.out, sourceSubject.path);
    const model = JSON.parse(await readFile(sourceFile, "utf8"));
    model.metadata.scope = raw;
    const sourceBytes = Buffer.from(JSON.stringify(model));
    await writeFile(sourceFile, sourceBytes);
    sourceSubject.digest.value = sha(sourceBytes);
    await writeFile(rendered.resultBody.manifest, `${JSON.stringify(manifest, null, 2)}\n`);
    const verify = run(["verify", rendered.resultBody.manifest]);
    assert.equal(verify.status, 1);
    assert.equal(body(verify.stderr).error.code, "SENSITIVE_DATA_DETECTED");
    assert.equal(`${verify.stdout}${verify.stderr}`.includes(raw), false);
  });
});

test("almanac projection preserves title, accountability, evidence and reading order", async () => {
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => {
      value.metadata.title = "wacli Eko Almanac";
      value.metadata.scope = "Passive time-stamped operational sidecard";
      const edge = value.topology.edges.find((item) => item.id === "edge_compose_inspect");
      Object.assign(edge, { label: "review handoff", bias: 0.7, label_dx: 14, label_dy: 9 });
    });
    const first = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "first")]);
    const second = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "second")]);
    assert.equal(first.status, 0, first.stderr);
    assert.equal(second.status, 0, second.stderr);
    const html = await readFile(body(first.stdout).outputs.sidecard, "utf8");
    assert.deepEqual(await readFile(body(first.stdout).outputs.sidecard), await readFile(body(second.stdout).outputs.sidecard));
    assert.match(html, /<h1 translate="no">wacli Eko Almanac<\/h1>/u);
    assert.match(html, /<p class="subtitle">Passive time-stamped operational sidecard<\/p>/u);
    assert.match(html, /Snapshot · Not Live/u);
    assert.match(html, /Generated externally/u);
    assert.match(html, /Portable trust: CONSISTENT_UNTRUSTED/u);
    assert.match(html, /<time datetime="2026-09-12T12:00:00Z">2026-09-12T12:00:00Z<\/time>/u);
    assert.match(html, /class="artifact-id mono"/u);
    assert.match(html, /name="theme-color" media="\(prefers-color-scheme: light\)" content="#f6f8fa"/u);
    assert.match(html, /name="theme-color" media="\(prefers-color-scheme: dark\)" content="#0d1117"/u);
    for (const [term, value] of [["What", "Record the review decision"], ["Who", "Release steward"], ["When", "After semantic inspection"], ["Why", "It unblocks publication"], ["Where", "Review record"], ["How", "Attach evidence and update the criterion"]]) {
      assert.ok(html.includes(`<dt>${term}</dt><dd>${value}</dd>`));
    }
    assert.match(html, /<h2>Current Disposition<\/h2><p><strong>IN_PROGRESS<\/strong> · <span class="mono">work_review<\/span>/u);
    assert.match(html, /<summary>Work Register · 2 Items<\/summary>/u);
    assert.match(html, /Actor: Review team \(actor_reviewers\)/u);
    assert.match(html, /class="svg-edge-label"[^>]*>review handoff<\/text>/u);
    assert.match(html, /Release steward \(<code>actor_steward<\/code>\) → <code>inspect<\/code>/u);
    assert.match(html, /Approves semantic accuracy/u);
    assert.match(html, /<h2>Evidence &amp; References<\/h2>/u);
    assert.match(html, /<summary>Evidence Register · 3 Items<\/summary>/u);
    assert.match(html, /<code>ref_scope<\/code> · source/u);
    assert.match(html, /https:\/\/example\.com\/public\/scope/u);
    const order = ["<header class=\"hero\">", "id=\"next\"", "id=\"identity\"", "id=\"traceability\"", "id=\"contexts\"", "id=\"domains\"", "id=\"workflow\"", "id=\"governance\"", "id=\"criteria\"", "id=\"evidence\"", "id=\"lineage\"", "id=\"materials\""].map((token) => html.indexOf(token));
    assert.ok(order.every((position) => position >= 0));
    assert.deepEqual([...order].sort((left, right) => left - right), order);
  });
});

test("next selection is dependency-aware and uses stable blocking, priority, critical-domain, sequence and ID ordering", async () => {
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => {
      value.analysis.gaps[0].status = "completed"; value.analysis.gaps[0].reason = null; value.analysis.gaps[0].evidence_refs = ["ref_review"];
      value.plan.work_items[0].lifecycle_state = lifecycle("completed");
      value.plan.work_items[1].blocker_refs = [];
      value.plan.work_items.push({ ...value.plan.work_items[1], id: "work_urgent", title: "Urgent work", priority: "q1", sequence: 9, blocking: true, dependencies: [] });
    });
    const result = run(["next", model]);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(body(result.stdout).next, { disposition: "TASK", task_ref: "work_urgent" });
  });
  assert.deepEqual(body(run(["next", activeFixture]).stdout).next, { disposition: "IN_PROGRESS", task_ref: "work_review" });
  assert.deepEqual(body(run(["next", readyFixture]).stdout).next, { disposition: "QUIESCENT", task_ref: null });
  await temp(async (directory) => {
    const delegated = await mutateModel(directory, (value) => { value.plan.work_items[0].lifecycle_state = lifecycle("delegated"); });
    assert.deepEqual(body(run(["next", delegated]).stdout).next, { disposition: "DELEGATED", task_ref: "work_review" });
  });
  await temp(async (directory) => {
    const item = (overrides) => ({
      id: overrides.id, title: overrides.id, description: null, task_kind: "delivery",
      priority: "q1", sequence: overrides.sequence, blocking: true, critical_path_ref: overrides.critical_path_ref,
      dependencies: [], blocker_refs: [], domain_refs: ["domain_release"], world_refs: ["world_human"],
      deliverables: ["Outcome"], lifecycle_state: lifecycle("planned")
    });
    const model = await mutateModel(directory, (value) => {
      value.plan.work_items = [
        item({ id: "work_alpha", sequence: 5, critical_path_ref: "publish" }),
        item({ id: "work_beta", sequence: 5, critical_path_ref: "compose" }),
        item({ id: "work_gamma", sequence: 2, critical_path_ref: "compose" }),
        item({ id: "work_aaa_first", sequence: 2, critical_path_ref: "compose" })
      ];
    });
    const result = run(["next", model]);
    assert.equal(result.status, 0, result.stderr);
    assert.deepEqual(body(result.stdout).next, { disposition: "TASK", task_ref: "work_aaa_first" });
  });
});

test("transition matrix, expected digest, atomic output and six reconciliations are enforced", async () => {
  for (const from of STATES) for (const to of STATES) await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.plan.work_items[0].lifecycle_state = lifecycle(from); });
    const bytes = await readFile(model);
    const digest = sha(bytes);
    const eventFile = path.join(directory, "event.json");
    await writeFile(eventFile, `${JSON.stringify(eventFor(from, to, digest), null, 2)}\n`);
    const output = path.join(directory, "transitioned.json");
    const result = run(["transition", model, "--event", eventFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status === 0, ALLOWED[from].includes(to), `${from} -> ${to}: ${result.stderr}`);
    if (!ALLOWED[from].includes(to)) assert.equal(body(result.stderr).error.code, "TRANSITION_DENIED", `${from} -> ${to}: ${result.stderr}`);
    assert.equal(fs.existsSync(output), ALLOWED[from].includes(to));
    if (result.status === 0) {
      const changed = JSON.parse(await readFile(output, "utf8"));
      assert.equal(changed.lifecycle.events.at(-1).reconciliation.length, 6);
      assert.equal(changed.traceability.updated_at, "2026-09-12T14:00:00Z");
    }
  });
  await temp(async (directory) => {
    const model = await copyModel(directory);
    const digest = sha(await readFile(model));
    const event = eventFor("started", "completed", digest);
    event.reconciliation.pop();
    const eventFile = path.join(directory, "event.json");
    await writeFile(eventFile, JSON.stringify(event));
    const output = path.join(directory, "out.json");
    const result = run(["transition", model, "--event", eventFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(fs.existsSync(output), false);
  });
  await temp(async (directory) => {
    const model = await copyModel(directory);
    const digest = sha(await readFile(model));
    const eventFile = path.join(directory, "event.json");
    await writeFile(eventFile, JSON.stringify(eventFor("started", "completed", digest)));
    const output = path.join(directory, "out.json");
    const result = run(["transition", model, "--event", eventFile, "--expected-digest", "0".repeat(64), "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "BASE_DIGEST_MISMATCH");
    assert.equal(fs.existsSync(output), false);
  });
});

test("returning to planned after a start clears started_at so the allowed transition passes its own gate", async () => {
  for (const via of ["deferred", "hitl"]) await temp(async (directory) => {
    let model = await copyModel(directory);
    assert.equal(JSON.parse(await readFile(model, "utf8")).plan.work_items.find((item) => item.id === "work_review").lifecycle_state.state, "started");
    for (const [index, [from, to]] of [["started", via], [via, "planned"]].entries()) {
      const digest = sha(await readFile(model));
      const event = { ...eventFor(from, to, digest), event_id: `event_${index}_${from}_${to}`, occurred_at: `2026-09-12T14:0${index}:00Z` };
      const eventFile = path.join(directory, `event-${index}.json`);
      await writeFile(eventFile, JSON.stringify(event));
      const output = path.join(directory, `step-${index}.json`);
      const result = run(["transition", model, "--event", eventFile, "--expected-digest", digest, "--out", output]);
      assert.equal(result.status, 0, `${from} -> ${to} via ${via}: ${result.stderr}`);
      model = output;
    }
    const state = JSON.parse(await readFile(model, "utf8")).plan.work_items.find((item) => item.id === "work_review").lifecycle_state;
    assert.equal(state.state, "planned");
    assert.equal(state.started_at, null);
  });
});

test("lifecycle history rejects discontinuity, replay, time regression, stale latest pointer and final-state mismatch", async () => {
  const cases = [
    ["HISTORY_STATE_DISCONTINUITY", (model) => { model.lifecycle.events[1].from_state = "planned"; }],
    ["DUPLICATE_EVENT_ID", (model) => { model.lifecycle.events[1].event_id = model.lifecycle.events[0].event_id; }],
    ["HISTORY_TIME_ORDER", (model) => { model.lifecycle.events[1].occurred_at = "2026-09-12T11:00:00Z"; }],
    ["LATEST_EVENT_INVALID", (model) => { model.lifecycle.latest_event_ref = model.lifecycle.events[0].event_id; }],
    ["HISTORY_FINAL_STATE_MISMATCH", (model) => { model.plan.work_items[0].lifecycle_state = lifecycle("blocked"); }],
    ["LATEST_EVENT_INVALID", (model) => { model.lifecycle.events = []; model.lifecycle.latest_event_ref = "history_first"; }]
  ];
  for (const [expectedCode, mutate] of cases) await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => {
      const first = eventFor("planned", "delegated", "a".repeat(64));
      first.event_id = "history_first";
      first.occurred_at = "2026-09-12T12:00:00Z";
      const second = eventFor("delegated", "started", "b".repeat(64));
      second.event_id = "history_second";
      second.occurred_at = "2026-09-12T13:00:00Z";
      value.lifecycle.events = [first, second];
      value.lifecycle.latest_event_ref = second.event_id;
      value.plan.work_items[0].lifecycle_state = lifecycle("started");
      mutate(value);
    });
    const result = run(["validate", model]);
    assert.equal(result.status, 1);
    assert.ok(body(result.stderr).error.details.some((item) => item.code === expectedCode), `${expectedCode}: ${result.stderr}`);
  });
});

test("one-child derivation assigns new identity, immutable lineage, bounded depth and capability subset", async () => {
  await temp(async (directory) => {
    const sentinel = "parent-only-sentinel-7f4c";
    const model = await mutateModel(directory, (value) => {
      value.topology.nodes[0].label = sentinel;
      value.intent.goal = sentinel;
      value.references.find((item) => item.id === "ref_scope").uri = `https://example.com/public/${sentinel}`;
      value.inert_material.prompts[0].content = sentinel;
    });
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_dna", "material_template", "material_governance"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, `${JSON.stringify(request, null, 2)}\n`);
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 0, result.stderr);
    const child = JSON.parse(await readFile(output, "utf8"));
    assert.notEqual(body(run(["validate", model]).stdout).artifact_id, body(result.stdout).artifact_id);
    assert.equal(child.child_derivation.generation_depth, 1);
    assert.match(child.child_derivation.parent_lineage.parent_source_sha256, /^[a-f0-9]{64}$/u);
    assert.match(digest, /^[a-f0-9]{64}$/u);
    assert.equal(child.child_derivation.parent_lineage.parent_source_sha256, digest);
    assert.deepEqual(child.child_derivation.capability_ceiling, request.capability_ceiling);
    assert.equal(body(result.stdout).automatic_recursive_spawn, false);
    assert.equal(JSON.stringify(child).includes(sentinel), false);
    assert.deepEqual(child.topology.nodes.map((item) => item.id), ["child_intake"]);
    assert.deepEqual(child.plan.work_items.map((item) => item.id), ["child_task"]);
    assert.equal(child.intent.goal, "Prepare one minimal governed child workflow for external validation.");
    assert.deepEqual(child.traceability.ai_llm, { provider: "none", model: "deterministic-template", revision: null });
    const childReferences = new Map(child.references.map((item) => [item.id, item]));
    for (const collection of ["seeds", "dna", "templates", "instructions", "prompts", "directives", "governance"]) {
      assert.ok(child.inert_material[collection].length > 0, `${collection} must be self-contained`);
      assert.ok(child.inert_material[collection].every((item) =>
        item.trust_class === "untrusted_data"
        && item.binding === false
        && item.effect_class === "none"
        && item.distribution === "public"
        && item.source_sha256 === childReferences.get(item.source_ref)?.digest.value
        && !item.content.includes(sentinel)));
    }
    assert.equal(child.inert_material.seeds[0].id, "default_seed");
    assert.equal(child.inert_material.instructions[0].id, "default_instruction");
    assert.equal(child.inert_material.prompts[0].id, "default_prompt");
    assert.equal(child.inert_material.directives[0].id, "default_directive");
    assert.ok(child.topology.nodes.every((item) => item.status === "planned"));
    assert.ok(child.plan.work_items.every((item) => item.lifecycle_state.state === "planned"));
    assert.deepEqual(child.lifecycle.events, []);
    assert.deepEqual(child.analysis, { root_causes: [], gaps: [], failures: [], risks: [] });
    assert.equal(child.inert_material.dna.length, 1);
    assert.equal(child.inert_material.templates.length, 1);
    assert.equal(child.inert_material.governance.length, 1);
    assert.ok(child.references.every((item) => ["ref_parent_lineage", "ref_generated_defaults"].includes(item.id) || item.id.startsWith("inherited_ref_")));
    const defaultsReference = childReferences.get("ref_generated_defaults");
    for (const collection of ["seeds", "instructions", "prompts", "directives"]) {
      assert.equal(child.inert_material[collection][0].source_ref, defaultsReference.id);
      assert.equal(child.inert_material[collection][0].source_sha256, defaultsReference.digest.value);
    }
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => {
      value.child_derivation.generation_depth = 2;
      value.child_derivation.capability_ceiling = ["read_public_evidence"];
      value.child_derivation.parent_lineage = { parent_artifact_id: `vasm:${"a".repeat(64)}`, parent_source_sha256: "b".repeat(64), derivation_plan_id: randomUUID() };
    });
    const digest = sha(await readFile(model));
    const request = childRequest({
      target_project_slug: "third-project", target_repository_uri: "https://example.com/public/third-project",
      subject_slug: "third-session", as_of: "2026-09-14T12:00:00Z", capability_ceiling: ["read_public_evidence"]
    });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "CHILD_DEPTH_EXCEEDED");
    assert.equal(fs.existsSync(output), false);
  });
});

test("child derivation scans allowlisted inherited material before any write", async () => {
  await temp(async (directory) => {
    const raw = "sensitive-owner@private-domain.dev";
    const model = await mutateModel(directory, (value) => { value.inert_material.dna[0].content = raw; });
    const digest = sha(await readFile(model));
    const request = childRequest({
      target_project_slug: "safe-child", target_repository_uri: "https://example.com/public/safe-child",
      subject_slug: "safe-child-session", as_of: "2026-09-14T12:00:00Z",
      capability_ceiling: ["read_public_evidence", "validate_model"],
      inherited_material_ids: ["material_dna"]
    });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "SENSITIVE_DATA_DETECTED");
    assert.equal(`${result.stdout}${result.stderr}`.includes(raw), false);
    assert.equal(fs.existsSync(output), false);
  });
});

test("standard profile still renders through trusted stock Archify", async (context) => {
  if (!stockArchify) { context.skip("stock Archify unavailable"); return; }
  await temp(async (directory) => {
    const model = await copyModel(directory, readyFixture);
    const render = run(["render", model, "--profile", "standard", "--out", path.join(directory, "bundle"), "--archify-dir", stockArchify]);
    assert.equal(render.status, 0, render.stderr);
    assert.equal(body(render.stdout).profile, "standard");
    const verify = run(["verify", body(render.stdout).manifest, "--archify-dir", stockArchify]);
    assert.equal(verify.status, 0, verify.stderr);
  });
});

test("transition scans for sensitive data both before and after applying the event", async () => {
  await temp(async (directory) => {
    const raw = "transition-base-owner@private-domain.dev";
    const model = await mutateModel(directory, (value) => { value.metadata.scope = raw; });
    const digest = sha(await readFile(model));
    const eventFile = path.join(directory, "event.json");
    await writeFile(eventFile, JSON.stringify(eventFor("started", "completed", digest)));
    const output = path.join(directory, "out.json");
    const result = run(["transition", model, "--event", eventFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "SENSITIVE_DATA_DETECTED");
    assert.equal(`${result.stdout}${result.stderr}`.includes(raw), false);
    assert.equal(fs.existsSync(output), false);
  });
  await temp(async (directory) => {
    const raw = "transition-event-owner@private-domain.dev";
    const model = await copyModel(directory);
    const digest = sha(await readFile(model));
    const event = eventFor("started", "completed", digest);
    event.reason = raw;
    const eventFile = path.join(directory, "event.json");
    await writeFile(eventFile, JSON.stringify(event));
    const output = path.join(directory, "out.json");
    const result = run(["transition", model, "--event", eventFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "SENSITIVE_DATA_DETECTED");
    assert.equal(`${result.stdout}${result.stderr}`.includes(raw), false);
    assert.equal(fs.existsSync(output), false);
  });
});

test("portable distribution rejects private-network and credentialed reference URIs", async () => {
  const badUris = [
    "https://10.0.0.5/status",
    "https://127.0.0.1/status",
    "https://192.168.1.5/status",
    "https://internal-host/status",
    "https://user:pass@example.com/status",
    "https://[::ffff:127.0.0.1]/status",
    "https://[::ffff:169.254.169.254]/latest/meta-data/",
    "https://[::ffff:10.0.0.5]/status",
    "https://[64:ff9b::a9fe:a9fe]/latest/meta-data/",
    "https://[fe80::1]/status",
    "https://[fe90::1]/status",
    "https://[febf::1]/status",
    "https://100.64.0.1/internal",
    "https://100.127.255.254/internal",
    "https://[::ffff:100.64.0.1]/internal",
    "https://192.0.0.8/status",
    "https://198.18.0.1/status",
    "https://198.51.100.7/status",
    "https://203.0.113.9/status",
    "https://224.0.0.1/status",
    "https://240.0.0.1/status"
  ];
  for (const uri of badUris) await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.references.find((item) => item.id === "ref_scope").uri = uri; });
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
    assert.equal(result.status, 1, uri);
    assert.equal(body(result.stderr).error.code, "PORTABLE_DISTRIBUTION_REJECTED", uri);
  });
  const publicGit = { repository_visibility: "public", tracking_state: "tracked_clean", ref_name: "main", commit_sha: "a".repeat(40), tree_sha: "b".repeat(40) };
  for (const uri of ["https://localhost/private.git", "https://10.0.0.5/private.git", "https://100.64.0.1/private.git"]) await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.traceability.git = { ...value.traceability.git, ...publicGit, repository_uri: uri }; });
    assert.equal(run(["validate", model]).status, 0, `validate accepts public visibility with ${uri}`);
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
    assert.equal(result.status, 1, uri);
    assert.ok(body(result.stderr).error.details.some((item) => item.path === "/traceability/git/repository_uri" && item.code === "PRIVATE_REPOSITORY_URI"), result.stderr);
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.traceability.git = { ...value.traceability.git, ...publicGit, repository_uri: "https://example.com/public/project.git" }; });
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
    assert.equal(result.status, 0, result.stderr);
  });
  await temp(async (directory) => {
    const model = await copyModel(directory);
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
    assert.equal(result.status, 0, result.stderr);
  });
});

test("portable distribution accepts a public urn:embedded-snapshot: reference", async () => {
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.references.find((item) => item.id === "ref_scope").uri = "urn:embedded-snapshot:test-subject:v1"; });
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
    assert.equal(result.status, 0, result.stderr);
  });
});

test("derive-child rejects a private-network target repository URI", async () => {
  await temp(async (directory) => {
    const model = await copyModel(directory);
    const digest = sha(await readFile(model));
    const request = childRequest({ target_repository_uri: "https://10.0.0.5/child-project" });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "CHILD_REQUEST_INVALID");
    assert.equal(fs.existsSync(output), false);
  });
});

test("derive-child only inherits dna, template, and governance material explicitly named in the request", async () => {
  const marker = "parent-only-project-prose-marker-9f2e";
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.dna[0].content = marker; });
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_template", "material_governance"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 0, result.stderr);
    const child = JSON.parse(await readFile(output, "utf8"));
    assert.equal(JSON.stringify(child).includes(marker), false);
    assert.equal(child.inert_material.dna[0].id, "default_dna");
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.dna[0].content = marker; });
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_dna", "material_template", "material_governance"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 0, result.stderr);
    const child = JSON.parse(await readFile(output, "utf8"));
    assert.equal(child.inert_material.dna[0].content, marker);
  });
  await temp(async (directory) => {
    const model = await copyModel(directory);
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_missing"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "INHERITED_MATERIAL_NOT_FOUND");
    assert.equal(fs.existsSync(output), false);
  });
});

test("derive-child only inherits template material explicitly named in the request", async () => {
  const marker = "parent-only-template-prose-marker-6b1a";
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.templates[0].content = marker; });
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_dna", "material_governance"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 0, result.stderr);
    const child = JSON.parse(await readFile(output, "utf8"));
    assert.equal(JSON.stringify(child).includes(marker), false);
    assert.equal(child.inert_material.templates[0].id, "default_template");
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.templates[0].content = marker; });
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_dna", "material_template", "material_governance"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 0, result.stderr);
    const child = JSON.parse(await readFile(output, "utf8"));
    assert.equal(child.inert_material.templates[0].content, marker);
  });
});

test("derive-child only inherits governance material explicitly named in the request", async () => {
  const marker = "parent-only-governance-prose-marker-4f7d";
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.governance[0].content = marker; });
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_dna", "material_template"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 0, result.stderr);
    const child = JSON.parse(await readFile(output, "utf8"));
    assert.equal(JSON.stringify(child).includes(marker), false);
    assert.equal(child.inert_material.governance[0].id, "default_governance");
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.inert_material.governance[0].content = marker; });
    const digest = sha(await readFile(model));
    const request = childRequest({ inherited_material_ids: ["material_dna", "material_template", "material_governance"] });
    const requestFile = path.join(directory, "request.json");
    await writeFile(requestFile, JSON.stringify(request));
    const output = path.join(directory, "child.json");
    const result = run(["derive-child", model, "--request", requestFile, "--expected-digest", digest, "--out", output]);
    assert.equal(result.status, 0, result.stderr);
    const child = JSON.parse(await readFile(output, "utf8"));
    assert.equal(child.inert_material.governance[0].content, marker);
  });
});

test("portable render fails closed when reusing a stem whose existing manifest is malformed", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const manifestFile = rendered.resultBody.manifest;
    const manifest = JSON.parse(await readFile(manifestFile, "utf8"));
    manifest.subjects = [];
    await writeFile(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
    const secondModel = await copyModel(directory);
    const secondResult = run(["render", secondModel, "--profile", "portable-sidecard", "--out", rendered.out]);
    assert.equal(secondResult.status, 1);
    assert.equal(body(secondResult.stderr).error.code, "STALE_MANIFEST_UNTRUSTED");
  });
});

test("verify rejects a VALIDATED manifest whose embedded_blocks count violates its profile's schema contract", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const manifestFile = rendered.resultBody.manifest;
    const manifest = JSON.parse(await readFile(manifestFile, "utf8"));
    assert.equal(manifest.status, "VALIDATED");
    assert.equal(manifest.embedded_blocks.length, 2);
    manifest.embedded_blocks = manifest.embedded_blocks.slice(0, 1);
    await writeFile(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
    const verify = run(["verify", manifestFile]);
    assert.equal(verify.status, 1);
    const error = body(verify.stderr).error;
    assert.equal(error.code, "MANIFEST_SCHEMA_INVALID");
    assert.ok(error.details.some((item) => item.path === "/embedded_blocks"), JSON.stringify(error.details));
  });
});

test("canonicalization rejects an unpaired UTF-16 surrogate instead of silently accepting it", async () => {
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.metadata.scope = "lone surrogate \uD800 marker"; });
    const output = path.join(directory, "out");
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "CANONICALIZATION_LONE_SURROGATE");
    assert.deepEqual(fs.existsSync(output) ? fs.readdirSync(output) : [], []);
  });
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.metadata.scope = "valid emoji \uD83D\uDE00 marker"; });
    const result = run(["render", model, "--profile", "portable-sidecard", "--out", path.join(directory, "out")]);
    assert.equal(result.status, 0, result.stderr);
  });
});

test("string length limits count Unicode code points, not UTF-16 units", async () => {
  for (const [count, expected] of [[4096, 0], [4097, 1]]) await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.metadata.scope = "\u{1F600}".repeat(count); });
    const result = run(["validate", model]);
    assert.equal(result.status, expected, `${count} astral characters: ${result.stderr}`);
    if (expected) assert.ok(body(result.stderr).error.details.some((item) => item.path === "/metadata/scope" && item.keyword === "maxLength"), result.stderr);
  });
});

test("timestamps are UTC Z-terminated in both the public schema contract and the CLI", async () => {
  const schema = JSON.parse(await readFile(path.join(root, "schemas", "session-model.schema.json"), "utf8"));
  const manifestSchema = JSON.parse(await readFile(path.join(root, "schemas", "integrity-manifest.schema.json"), "utf8"));
  for (const definition of [schema.$defs.dateTime, schema.$defs.nullableDateTime, manifestSchema.$defs.dateTime]) {
    const pattern = new RegExp(definition.pattern, "u");
    assert.ok(pattern.test("2026-09-12T14:00:00Z") && pattern.test("2026-09-12T14:00:00.250Z"));
    assert.ok(!pattern.test("2026-09-12T14:00:00+02:00") && !pattern.test("2026-09-12T14:00:00-03:00") && !pattern.test("2026-09-12T14:00:00"));
  }
  for (const [value, expected] of [["2026-09-12T14:00:00Z", 0], ["2026-09-12T14:00:00+02:00", 1], ["2026-09-12T14:00:00-03:00", 1], ["2026-02-30T14:00:00Z", 1]]) await temp(async (directory) => {
    const model = await mutateModel(directory, (item) => { item.traceability.updated_at = value; });
    const result = run(["validate", model]);
    assert.equal(result.status, expected, `${value}: ${result.stderr}`);
  });
});

test("verify scans the manifest's own bytes for sensitive data before accepting a bundle", async () => {
  await temp(async (directory) => {
    const rendered = await renderPortable(directory);
    assert.equal(rendered.result.status, 0, rendered.result.stderr);
    const manifestFile = rendered.resultBody.manifest;
    const manifest = JSON.parse(await readFile(manifestFile, "utf8"));
    manifest.checks[0].details = "password=abcdefghijklmnop";
    await writeFile(manifestFile, `${JSON.stringify(manifest, null, 2)}\n`);
    const verify = run(["verify", manifestFile]);
    assert.equal(verify.status, 1);
    assert.equal(body(verify.stderr).error.code, "SENSITIVE_DATA_DETECTED");
    assert.ok(!verify.stderr.includes("abcdefghijklmnop"), "verify must not echo the detected value");
  });
});

test("standard render scans the exact persisted source bytes, so a duplicate-member smuggle fails closed", async () => {
  await temp(async (directory) => {
    const raw = "duplicate-key-owner@private-domain.dev";
    const model = await copyModel(directory, readyFixture);
    const text = await readFile(model, "utf8");
    const smuggled = text.replace(/^(\s*)"scope": /mu, `$1"scope": ${JSON.stringify(raw)},\n$1"scope": `);
    assert.notEqual(smuggled, text);
    assert.ok(!JSON.stringify(JSON.parse(smuggled)).includes(raw), "JSON.parse must have discarded the first occurrence");
    await writeFile(model, smuggled);
    const output = path.join(directory, "bundle");
    const result = run(["render", model, "--profile", "standard", "--out", output]);
    assert.equal(result.status, 1);
    assert.equal(body(result.stderr).error.code, "SENSITIVE_DATA_DETECTED");
    assert.ok(!result.stderr.includes(raw));
    assert.ok(!fs.existsSync(path.join(output, path.basename(model))));
  });
});

test("a schema-valid SemVer with build metadata renders, verifies, and yields a filename-safe stem", async () => {
  await temp(async (directory) => {
    const model = await mutateModel(directory, (value) => { value.identity.version = "2.0.0+build.7"; value.traceability.semantic_version = "2.0.0+build.7"; });
    assert.equal(run(["validate", model]).status, 0);
    const out = path.join(directory, "bundle");
    const render = run(["render", model, "--profile", "portable-sidecard", "--out", out]);
    assert.equal(render.status, 0, render.stderr);
    const manifest = body(render.stdout).manifest;
    assert.match(path.basename(manifest), /-v2\.0\.0_build\.7--h[a-f0-9]{12}\.manifest\.json$/u);
    assert.ok(!path.basename(manifest).includes("+"));
    assert.equal(run(["verify", manifest]).status, 0);
  });
});
