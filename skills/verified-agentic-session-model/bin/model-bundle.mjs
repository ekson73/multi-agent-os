#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import { createHash, randomUUID } from "node:crypto";
import fs from "node:fs";
import {
  lstat,
  mkdir,
  mkdtemp,
  open,
  readFile,
  realpath,
  rename,
  rm,
  unlink,
  writeFile
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

const TOOL = "verified-agentic-session-model";
const VERSION = "2.0.0";
const STATUS_VALUES = ["planned", "started", "delegated", "deferred", "hitl", "blocked", "completed", "canceled", "superseded", "deprecated", "unknown"];
const REASON_REQUIRED = new Set(["deferred", "hitl", "blocked", "canceled", "superseded", "deprecated", "unknown"]);
const TERMINAL_STATES = new Set(["completed", "canceled", "superseded", "deprecated"]);
const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const MODEL_SCHEMA = path.join(ROOT, "schemas", "session-model.schema.json");
const MANIFEST_SCHEMA = path.join(ROOT, "schemas", "integrity-manifest.schema.json");
const JSON_INDENT = 2;
const MAX_BYTES = 2 * 1024 * 1024;
const ARCHIFY_TIMEOUT_MS = 30_000;
const CHECKS_BY_PROFILE = {
  standard: ["model_schema_and_references", "sensitive_data_and_distribution", "archify_workflow_validation", "archify_render_check", "cross_view_parity", "exact_byte_digests"],
  portable_sidecard: ["model_schema_and_references", "sensitive_data_and_distribution", "sidecard_csp_and_passivity", "embedded_capsule_integrity", "cross_view_parity", "exact_byte_digests"]
};
const ROLE_MEDIA = {
  source: "application/json",
  workflow: "application/json",
  diagram_html: "text/html",
  markdown: "text/markdown",
  sidecard_html: "text/html"
};
const TRANSITIONS = {
  planned: ["started", "delegated", "deferred", "hitl", "canceled", "superseded", "deprecated"],
  delegated: ["started", "deferred", "hitl", "canceled", "superseded"],
  started: ["completed", "blocked", "deferred", "hitl", "canceled", "superseded"],
  blocked: ["started", "deferred", "hitl", "canceled", "superseded"],
  deferred: ["planned", "hitl", "canceled", "superseded", "deprecated"],
  hitl: ["planned", "started", "deferred", "canceled"],
  completed: ["superseded", "deprecated"],
  canceled: [],
  superseded: [],
  deprecated: [],
  unknown: ["planned", "deferred", "hitl", "canceled"]
};
const EMAIL_ALLOWLIST_EXACT = new Set([
  "localhost@127.0.0.1",
  "noreply@github.com",
  "test@example.com",
  "noreply@anthropic.com",
  "noreply+claude-code@anthropic.com",
  "git@github.com",
  "git@gitlab.com",
  "git@bitbucket.org",
  "git@codeberg.org",
  "your-email@company.com"
]);
const EMAIL_ALLOWLIST_SUFFIX = ["example.com", "example.org", "example.net"];

class AppError extends Error {
  constructor(code, message, exitCode = 1, details = undefined) {
    super(message);
    this.code = code;
    this.exitCode = exitCode;
    this.details = details;
  }
}

function usage() {
  const cli = `node ${path.relative(process.cwd(), fileURLToPath(import.meta.url))}`;
  return [
    `${cli} validate <model>`,
    `${cli} render <model> --profile <standard|portable-sidecard> --out <dir> [--archify-dir <path>]`,
    `${cli} verify <manifest> [--archify-dir <path>]`,
    `${cli} inspect <sidecard.html>`,
    `${cli} next <model>`,
    `${cli} transition <model> --event <event.json> --expected-digest <sha256> --out <model.json>`,
    `${cli} derive-child <model> --request <request.json> --expected-digest <sha256> --out <child.json>`
  ];
}

function emitSuccess(operation, result = {}) {
  process.stdout.write(`${JSON.stringify({ ok: true, operation, ...result })}\n`);
}

function emitError(operation, error) {
  const envelope = {
    ok: false,
    operation,
    effective_status: error.exitCode === 1 ? "STALE" : undefined,
    error: {
      code: error.code || "INTERNAL_ERROR",
      message: error.message,
      ...(error.details === undefined ? {} : { details: error.details })
    }
  };
  if (envelope.effective_status === undefined) delete envelope.effective_status;
  process.stderr.write(`${JSON.stringify(envelope)}\n`);
}

function pointerEscape(value) {
  return String(value).replaceAll("~", "~0").replaceAll("/", "~1");
}

function deepEqual(left, right) {
  return JSON.stringify(left) === JSON.stringify(right);
}

function jsonText(value) {
  return `${JSON.stringify(value, null, JSON_INDENT)}\n`;
}

function canonicalize(value) {
  if (Array.isArray(value)) return value.map(canonicalize);
  if (value && typeof value === "object") {
    return Object.fromEntries(Object.keys(value).sort().map((key) => [key, canonicalize(value[key])]));
  }
  return value;
}

const LONE_SURROGATE = /[\uD800-\uDBFF](?![\uDC00-\uDFFF])|(?<![\uD800-\uDBFF])[\uDC00-\uDFFF]/;
function assertNoLoneSurrogates(value) {
  if (typeof value === "string") {
    if (LONE_SURROGATE.test(value)) throw new AppError("CANONICALIZATION_LONE_SURROGATE", "Canonicalization rejected an unpaired UTF-16 surrogate (masked)");
  } else if (Array.isArray(value)) {
    for (const item of value) assertNoLoneSurrogates(item);
  } else if (value && typeof value === "object") {
    for (const key of Object.keys(value)) { assertNoLoneSurrogates(key); assertNoLoneSurrogates(value[key]); }
  }
}
function canonicalBytes(value) {
  assertNoLoneSurrogates(value);
  return Buffer.from(JSON.stringify(canonicalize(value)));
}

function identityDigest(model) {
  return sha256(canonicalBytes(model.identity));
}

function artifactId(model) {
  return `vasm:${identityDigest(model)}`;
}

function sha256(value) {
  return createHash("sha256").update(value).digest("hex");
}

function digest(value) {
  return { algorithm: "sha256", value: sha256(value) };
}

async function readBounded(file, label) {
  let handle;
  try {
    const before = await lstat(file);
    if (!before.isFile() || before.isSymbolicLink()) throw new AppError("FILE_TYPE_REJECTED", `${label} must be a regular non-symlink file`);
    if (before.size > MAX_BYTES) throw new AppError("FILE_TOO_LARGE", `${label} exceeds the 2 MiB limit`);
    const flags = fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0);
    handle = await open(file, flags);
    const opened = await handle.stat();
    if (!opened.isFile()) throw new AppError("FILE_TYPE_REJECTED", `${label} must be a regular file`);
    if (opened.size > MAX_BYTES) throw new AppError("FILE_TOO_LARGE", `${label} exceeds the 2 MiB limit`);
    const bytes = await handle.readFile();
    if (bytes.length > MAX_BYTES) throw new AppError("FILE_TOO_LARGE", `${label} exceeds the 2 MiB limit`);
    return bytes;
  } catch (error) {
    if (error instanceof AppError) throw error;
    throw new AppError("FILE_READ_FAILED", `Cannot read ${label} at ${file}: ${error.code || "unreadable"}`);
  } finally {
    if (handle) await handle.close().catch(() => {});
  }
}

async function readJson(file, label) {
  const bytes = await readBounded(file, label);
  try {
    return { value: JSON.parse(bytes.toString("utf8")), bytes };
  } catch (error) {
    throw new AppError("JSON_INVALID", `${label} is not valid JSON: ${error.message}`);
  }
}
function validRfc3339(value) {
  const match = value.match(/^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?Z$/u);
  if (!match) return false;
  const parsed = new Date(value);
  return Number.isFinite(parsed.valueOf())
    && parsed.getUTCFullYear() === Number(match[1])
    && parsed.getUTCMonth() + 1 === Number(match[2])
    && parsed.getUTCDate() === Number(match[3])
    && parsed.getUTCHours() === Number(match[4])
    && parsed.getUTCMinutes() === Number(match[5])
    && parsed.getUTCSeconds() === Number(match[6]);
}

function validCpf(value) {
  const digits = value.replace(/\D/gu, "");
  if (digits.length !== 11 || new Set(digits).size === 1) return false;
  const checksum = (count) => {
    let total = 0;
    for (let index = 0; index < count; index += 1) total += Number(digits[index]) * (count + 1 - index);
    const remainder = total % 11;
    return remainder < 2 ? 0 : 11 - remainder;
  };
  return checksum(9) === Number(digits[9]) && checksum(10) === Number(digits[10]);
}

function scanSensitive(bytes) {
  const text = bytes.toString("utf8");
  const findings = [];
  const record = (type, masked) => findings.push({ type, masked });
  for (const match of text.matchAll(/(?<!\d)(\d{3}\.\d{3}\.\d{3}-\d{2}|\d{11})(?!\d)/gu)) {
    if (validCpf(match[1])) {
      const digits = match[1].replace(/\D/gu, "");
      record("cpf", `${digits.slice(0, 3)}.***.***-${digits.slice(-2)}`);
    }
  }
  for (const match of text.matchAll(/(?<![\w.+-])([A-Za-z0-9_%+\-]+(?:\.[A-Za-z0-9_%+\-]+){0,4}@(?:[A-Za-z0-9](?:[A-Za-z0-9\-]{0,61}[A-Za-z0-9])?\.){1,4}[A-Za-z]{2,24})(?![\w.])/gu)) {
    const value = match[1];
    const lowered = value.toLowerCase();
    const domain = lowered.split("@")[1];
    const allowlisted = EMAIL_ALLOWLIST_EXACT.has(lowered)
      || EMAIL_ALLOWLIST_SUFFIX.some((suffix) => domain === suffix || domain.endsWith(`.${suffix}`));
    if (!allowlisted) record("email", `${value[0]}***@${domain}`);
  }
  for (const match of text.matchAll(/(?<!\d)(\+55[\s.\-]?\(?([1-9][1-9])\)?[\s.\-]?9?\d{4}[\s.\-]?\d{4})(?!\d)/gu)) {
    record("phone_br", `+55 ${match[2]} ****-****`);
  }
  const secrets = [
    [/(-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----)/gu, "private_key", "-----BEGIN *** PRIVATE KEY-----"],
    [/\b(AKIA[0-9A-Z]{16})\b/gu, "aws_access_key", "AKIA…REDACTED"],
    [/\b((?:ghp|github_pat)_[A-Za-z0-9_]{20,})\b/gu, "access_token", "token…REDACTED"],
    [/\b(sk-[A-Za-z0-9_-]{20,})\b/gu, "api_key", "sk-…REDACTED"],
    [/\b(?:api[_-]?key|secret|token|password)\b\s*[:=]\s*["']?([A-Za-z0-9_./+=-]{16,})/giu, "named_secret", "value…REDACTED"]
  ];
  for (const [pattern, type, masked] of secrets) {
    for (const _match of text.matchAll(pattern)) record(type, masked);
  }
  return findings;
}

function decodedPayloads(text) {
  const decoded = [];
  for (const match of text.matchAll(/[A-Za-z0-9+/_-]{16,4096}={0,2}/gu)) {
    try {
      const bytes = Buffer.from(match[0], match[0].includes("+") || match[0].includes("/") ? "base64" : "base64url");
      const value = bytes.toString("utf8");
      if (value.length && !value.includes("\uFFFD")) {
        if (decoded.length >= 200) throw new AppError("SENSITIVE_SCAN_BUDGET_EXCEEDED", "Sensitive-data scan exceeded its bounded encoded-candidate budget");
        decoded.push(value);
      }
    } catch (error) {
      if (error instanceof AppError) throw error;
      // Invalid candidate is ordinary text, not an encoded payload.
    }
  }
  return decoded;
}

function enforceSensitivePreflight(bytes) {
  const text = bytes.toString("utf8");
  const findings = [
    ...scanSensitive(bytes),
    ...decodedPayloads(text).flatMap((value) => scanSensitive(Buffer.from(value)).map((item) => ({ ...item, type: `encoded_${item.type}` })))
  ];
  if (findings.length) throw new AppError(
    "SENSITIVE_DATA_DETECTED",
    "Source contains data blocked by the bounded pre-persistence detector",
    1,
    { detector_scope: ["cpf_modulo_11", "email_safe_subset", "phone_e164_br", "high_signal_secrets", "single_layer_base64"], findings }
  );
}

const schemaCache = new Map();
function loadSchema(file) {
  const absolute = path.resolve(file);
  if (!schemaCache.has(absolute)) {
    schemaCache.set(absolute, JSON.parse(fs.readFileSync(absolute, "utf8")));
  }
  return schemaCache.get(absolute);
}

function typeMatches(value, expected) {
  switch (expected) {
    case "null": return value === null;
    case "array": return Array.isArray(value);
    case "object": return value !== null && typeof value === "object" && !Array.isArray(value);
    case "integer": return Number.isInteger(value);
    case "number": return typeof value === "number" && Number.isFinite(value);
    default: return typeof value === expected;
  }
}

function resolveSchemaRef(ref, documentFile) {
  const [relativeFile, fragment = ""] = ref.split("#", 2);
  const targetFile = relativeFile ? path.resolve(path.dirname(documentFile), relativeFile) : documentFile;
  let schema = loadSchema(targetFile);
  if (fragment) {
    for (const segment of fragment.replace(/^\//, "").split("/")) {
      const key = segment.replaceAll("~1", "/").replaceAll("~0", "~");
      schema = schema?.[key];
    }
  }
  if (!schema) throw new AppError("SCHEMA_UNSUPPORTED", `Unresolvable schema reference: ${ref}`);
  return { schema, documentFile: targetFile };
}

function schemaErrors(instance, schemaFile) {
  const errors = [];
  const rootFile = path.resolve(schemaFile);

  function add(at, keyword, message) {
    errors.push({ path: at || "/", keyword, message });
  }

  function check(value, schema, at, documentFile) {
    if (schema === true) return;
    if (schema === false) {
      add(at, "falseSchema", "value is not allowed");
      return;
    }
    if (schema.$ref) {
      const resolved = resolveSchemaRef(schema.$ref, documentFile);
      check(value, resolved.schema, at, resolved.documentFile);
      return;
    }
    if (Object.hasOwn(schema, "const") && !deepEqual(value, schema.const)) {
      add(at, "const", `must equal ${JSON.stringify(schema.const)}`);
    }
    if (schema.enum && !schema.enum.some((candidate) => deepEqual(value, candidate))) {
      add(at, "enum", `must be one of ${schema.enum.map((item) => JSON.stringify(item)).join(", ")}`);
    }
    if (schema.type) {
      const types = Array.isArray(schema.type) ? schema.type : [schema.type];
      if (!types.some((type) => typeMatches(value, type))) {
        add(at, "type", `must be ${types.join(" or ")}`);
        return;
      }
    }
    if (value === null) return;

    if (typeof value === "string") {
      if (schema.minLength !== undefined && value.length < schema.minLength) add(at, "minLength", `must contain at least ${schema.minLength} character(s)`);
      if (schema.maxLength !== undefined && value.length > schema.maxLength) add(at, "maxLength", `must contain no more than ${schema.maxLength} character(s)`);
      if (schema.pattern && !(new RegExp(schema.pattern, "u")).test(value)) add(at, "pattern", `must match ${schema.pattern}`);
      if (schema.format === "date-time" && !validRfc3339(value)) add(at, "format", "must be a real RFC 3339 UTC date-time");
    }

    if (typeof value === "number") {
      if (schema.minimum !== undefined && value < schema.minimum) add(at, "minimum", `must be >= ${schema.minimum}`);
      if (schema.maximum !== undefined && value > schema.maximum) add(at, "maximum", `must be <= ${schema.maximum}`);
    }

    if (Array.isArray(value)) {
      if (schema.minItems !== undefined && value.length < schema.minItems) add(at, "minItems", `must contain at least ${schema.minItems} item(s)`);
      if (schema.maxItems !== undefined && value.length > schema.maxItems) add(at, "maxItems", `must contain no more than ${schema.maxItems} item(s)`);
      if (schema.uniqueItems) {
        const seen = new Set();
        value.forEach((item, index) => {
          const encoded = JSON.stringify(item);
          if (seen.has(encoded)) add(`${at}/${index}`, "uniqueItems", "must not duplicate another item");
          seen.add(encoded);
        });
      }
      if (schema.prefixItems) {
        schema.prefixItems.forEach((itemSchema, index) => {
          if (index < value.length) check(value[index], itemSchema, `${at}/${index}`, documentFile);
        });
      }
      if (schema.items === false && schema.prefixItems && value.length > schema.prefixItems.length) {
        add(at, "items", "contains an item beyond the allowed tuple length");
      } else if (schema.items && schema.items !== true) {
        value.forEach((item, index) => check(item, schema.items, `${at}/${index}`, documentFile));
      }
    }

    if (value && typeof value === "object" && !Array.isArray(value)) {
      for (const required of schema.required || []) {
        if (!Object.hasOwn(value, required)) add(at, "required", `must contain property ${required}`);
      }
      const properties = schema.properties || {};
      for (const [key, child] of Object.entries(value)) {
        if (Object.hasOwn(properties, key)) check(child, properties[key], `${at}/${pointerEscape(key)}`, documentFile);
        else if (schema.additionalProperties === false) add(`${at}/${pointerEscape(key)}`, "additionalProperties", "property is not allowed");
        else if (schema.additionalProperties && typeof schema.additionalProperties === "object") check(child, schema.additionalProperties, `${at}/${pointerEscape(key)}`, documentFile);
      }
    }
  }

  check(instance, loadSchema(rootFile), "", rootFile);
  return errors;
}

function walk(value, at, visit) {
  if (!value || typeof value !== "object") return;
  visit(value, at);
  if (Array.isArray(value)) {
    value.forEach((item, index) => walk(item, `${at}/${index}`, visit));
  } else {
    for (const [key, child] of Object.entries(value)) walk(child, `${at}/${pointerEscape(key)}`, visit);
  }
}

function semanticErrors(model) {
  const errors = [];
  const ids = new Map();
  const referenceIds = new Set(model.references.map((item) => item.id));
  const referenceById = new Map(model.references.map((item) => [item.id, item]));
  const nodeIds = new Set(model.topology.nodes.map((item) => item.id));
  const laneIds = new Set(model.topology.lanes.map((item) => item.id));
  const actorIds = new Set(model.organization.actors.map((item) => item.id));
  const worldIds = new Set(model.organization.worlds.map((item) => item.id));
  const domainIds = new Set(model.organization.domains.map((item) => item.id));
  const responsibilityIds = new Set(model.governance.responsibilities.map((item) => item.id));
  const work = [...model.plan.waves, ...model.plan.work_items];
  const workIds = new Set(work.map((item) => item.id));
  const itemIds = new Set(model.plan.work_items.map((item) => item.id));
  const gapRiskIds = new Set([...model.analysis.gaps, ...model.analysis.risks].map((item) => item.id));
  const edgePairs = new Set(model.topology.edges.map((edge) => `${edge.from}\u0000${edge.to}`));
  const add = (at, code, message) => errors.push({ path: at || "/", code, message });
  const requireRef = (set, value, at, code) => { if (!set.has(value)) add(at, code, "unknown reference (masked)"); };

  walk(model, "", (value, at) => {
    if (!Array.isArray(value) && typeof value.id === "string") {
      if (ids.has(value.id)) add(`${at}/id`, "DUPLICATE_ID", `duplicates ${ids.get(value.id)}`);
      else ids.set(value.id, `${at}/id`);
    }
    if (!Array.isArray(value) && Array.isArray(value.evidence_refs)) {
      value.evidence_refs.forEach((ref, index) => requireRef(referenceIds, ref, `${at}/evidence_refs/${index}`, "DANGLING_EVIDENCE_REF"));
    }
    if (!Array.isArray(value) && STATUS_VALUES.includes(value.status)) {
      if (value.status === "completed" && value.evidence_refs.length === 0) add(`${at}/evidence_refs`, "COMPLETED_WITHOUT_EVIDENCE", "completed requires evidence");
      if (REASON_REQUIRED.has(value.status) && !(typeof value.reason === "string" && value.reason.trim())) add(`${at}/reason`, "STATUS_REASON_REQUIRED", `${value.status} requires a reason`);
      if (!REASON_REQUIRED.has(value.status) && value.reason !== null) add(`${at}/reason`, "STATUS_REASON_FORBIDDEN", `${value.status} requires a null reason`);
    }
  });

  function checkLifecycle(state, at, ownerId) {
    const requireField = (field, condition, message) => { if (!condition) add(`${at}/${field}`, "LIFECYCLE_CONDITION", message); };
    if (state.state === "planned") {
      for (const field of ["reason", "assigned_actor_ref", "started_at", "ended_at", "resume_after", "decision_ref", "successor_ref"]) requireField(field, state[field] === null, `planned requires ${field}=null`);
      requireField("evidence_refs", state.evidence_refs.length === 0, "planned requires no evidence");
    }
    if (state.state === "started") requireField("started_at", state.started_at !== null, "started requires started_at");
    if (state.state === "delegated") requireField("assigned_actor_ref", state.assigned_actor_ref !== null, "delegated requires assigned_actor_ref");
    if (state.state === "deferred") {
      requireField("reason", typeof state.reason === "string" && state.reason.trim(), "deferred requires reason");
      requireField("resume_after", state.resume_after !== null || state.decision_ref !== null, "deferred requires resume_after or decision_ref");
    }
    if (state.state === "hitl") {
      requireField("reason", typeof state.reason === "string" && state.reason.trim(), "hitl requires reason");
      requireField("decision_ref", state.decision_ref !== null, "hitl requires decision_ref");
    }
    if (["blocked", "unknown"].includes(state.state)) requireField("reason", typeof state.reason === "string" && state.reason.trim(), `${state.state} requires reason`);
    if (state.state === "completed") {
      requireField("ended_at", state.ended_at !== null, "completed requires ended_at");
      requireField("evidence_refs", state.evidence_refs.length > 0, "completed requires evidence");
    }
    if (["canceled", "deprecated"].includes(state.state)) {
      requireField("reason", typeof state.reason === "string" && state.reason.trim(), `${state.state} requires reason`);
      requireField("ended_at", state.ended_at !== null, `${state.state} requires ended_at`);
    }
    if (state.state === "superseded") {
      requireField("reason", typeof state.reason === "string" && state.reason.trim(), "superseded requires reason");
      requireField("ended_at", state.ended_at !== null, "superseded requires ended_at");
      requireField("successor_ref", state.successor_ref !== null, "superseded requires successor_ref");
    }
    if (state.assigned_actor_ref !== null) requireRef(actorIds, state.assigned_actor_ref, `${at}/assigned_actor_ref`, "DANGLING_ACTOR_REF");
    if (state.decision_ref !== null) requireRef(referenceIds, state.decision_ref, `${at}/decision_ref`, "DANGLING_DECISION_REF");
    if (state.successor_ref !== null) {
      requireRef(itemIds, state.successor_ref, `${at}/successor_ref`, "DANGLING_SUCCESSOR_REF");
      if (state.successor_ref === ownerId) add(`${at}/successor_ref`, "SELF_SUCCESSOR", "work item cannot supersede itself");
    }
    if (state.started_at && state.ended_at && new Date(state.started_at) > new Date(state.ended_at)) add(at, "LIFECYCLE_TIME_ORDER", "started_at must not exceed ended_at");
  }
  work.forEach((item, index) => checkLifecycle(item.lifecycle_state, `/plan/${model.plan.waves.includes(item) ? "waves" : "work_items"}/${index}`, item.id));

  if (model.traceability.semantic_version !== model.identity.version) add("/traceability/semantic_version", "VERSION_MISMATCH", "semantic_version must equal identity.version");
  if (new Date(model.traceability.updated_at) < new Date(model.traceability.created_at)) add("/traceability/updated_at", "TIME_ORDER", "updated_at must not precede created_at");
  const git = model.traceability.git;
  if (git.repository_visibility === "public") {
    if (!git.repository_uri?.startsWith("https://") || !git.ref_name || !git.commit_sha || !git.tree_sha) add("/traceability/git", "PUBLIC_GIT_INCOMPLETE", "public Git traceability requires https URI, ref, commit, and tree");
  } else if ([git.repository_uri, git.ref_name, git.commit_sha, git.tree_sha].some((item) => item !== null)) add("/traceability/git", "PRIVATE_GIT_DISCLOSURE", "undisclosed/not_applicable Git fields must be null");

  const contexts = model.organization.contexts.map((item) => item.kind).sort();
  if (!deepEqual(contexts, ["artifact_world", "target_project_world"])) add("/organization/contexts", "CONTEXT_SET_INVALID", "requires one artifact and one target-project context");
  const worlds = model.organization.worlds.map((item) => item.kind).sort();
  if (!deepEqual(worlds, ["agentic", "human"])) add("/organization/worlds", "WORLD_SET_INVALID", "requires one human and one agentic world");
  const classes = model.organization.classifications.map((item) => item.class).sort();
  const expectedClasses = ["community", "gdpr", "gov", "lgpd", "opensource", "org", "personal", "pii", "private", "secrets", "work"];
  if (!deepEqual(classes, expectedClasses)) add("/organization/classifications", "CLASSIFICATION_SET_INVALID", "requires each canonical classification exactly once");
  const worldById = new Map(model.organization.worlds.map((item) => [item.id, item]));
  model.organization.worlds.forEach((world, index) => {
    world.actor_refs.forEach((ref, refIndex) => requireRef(actorIds, ref, `/organization/worlds/${index}/actor_refs/${refIndex}`, "DANGLING_ACTOR_REF"));
    world.domain_refs.forEach((ref, refIndex) => requireRef(domainIds, ref, `/organization/worlds/${index}/domain_refs/${refIndex}`, "DANGLING_DOMAIN_REF"));
  });
  model.organization.actors.forEach((actor, index) => {
    requireRef(worldIds, actor.world_ref, `/organization/actors/${index}/world_ref`, "DANGLING_WORLD_REF");
    actor.responsibility_refs.forEach((ref, refIndex) => requireRef(responsibilityIds, ref, `/organization/actors/${index}/responsibility_refs/${refIndex}`, "DANGLING_RESPONSIBILITY_REF"));
    const expectedKind = ["human", "human_team"].includes(actor.kind) ? "human" : "agentic";
    if (worldById.get(actor.world_ref)?.kind !== expectedKind) add(`/organization/actors/${index}/world_ref`, "ACTOR_WORLD_MISMATCH", `${actor.kind} requires ${expectedKind} world`);
  });
  model.organization.domains.forEach((domain, index) => {
    domain.world_refs.forEach((ref, refIndex) => requireRef(worldIds, ref, `/organization/domains/${index}/world_refs/${refIndex}`, "DANGLING_WORLD_REF"));
    domain.component_refs.forEach((ref, refIndex) => requireRef(nodeIds, ref, `/organization/domains/${index}/component_refs/${refIndex}`, "DANGLING_COMPONENT_REF"));
    requireRef(actorIds, domain.owner_actor_ref, `/organization/domains/${index}/owner_actor_ref`, "DANGLING_ACTOR_REF");
  });

  const occupied = new Set();
  model.topology.nodes.forEach((node, index) => {
    requireRef(laneIds, node.lane, `/topology/nodes/${index}/lane`, "DANGLING_LANE_REF");
    requireRef(worldIds, node.world_ref, `/topology/nodes/${index}/world_ref`, "DANGLING_WORLD_REF");
    requireRef(actorIds, node.owner_actor_ref, `/topology/nodes/${index}/owner_actor_ref`, "DANGLING_ACTOR_REF");
    node.domain_refs.forEach((ref, refIndex) => requireRef(domainIds, ref, `/topology/nodes/${index}/domain_refs/${refIndex}`, "DANGLING_DOMAIN_REF"));
    const cell = `${node.lane}\u0000${node.column}`;
    if (occupied.has(cell)) add(`/topology/nodes/${index}/column`, "LAYOUT_CELL_COLLISION", "lane/column already occupied");
    occupied.add(cell);
  });
  model.topology.groups.forEach((group, index) => {
    requireRef(laneIds, group.lane, `/topology/groups/${index}/lane`, "DANGLING_LANE_REF");
    if (group.from_column > group.to_column) add(`/topology/groups/${index}`, "INVALID_COLUMN_RANGE", "from_column must not exceed to_column");
  });
  model.topology.phases.forEach((phase, index) => { if (phase.from_column > phase.to_column) add(`/topology/phases/${index}`, "INVALID_COLUMN_RANGE", "from_column must not exceed to_column"); });
  model.topology.edges.forEach((edge, index) => {
    requireRef(nodeIds, edge.from, `/topology/edges/${index}/from`, "DANGLING_EDGE_REF");
    requireRef(nodeIds, edge.to, `/topology/edges/${index}/to`, "DANGLING_EDGE_REF");
  });
  model.topology.critical_path.forEach((node, index, list) => {
    requireRef(nodeIds, node, `/topology/critical_path/${index}`, "DANGLING_CRITICAL_PATH_REF");
    if (index > 0 && !edgePairs.has(`${list[index - 1]}\u0000${node}`)) add(`/topology/critical_path/${index}`, "CRITICAL_PATH_EDGE_MISSING", "consecutive critical nodes require a directed edge");
  });
  const adjacency = new Map(model.topology.nodes.map((node) => [node.id, []]));
  model.topology.edges.filter((edge) => ["main", "branch"].includes(edge.role ?? "main")).forEach((edge) => adjacency.get(edge.from)?.push(edge.to));
  const topologyVisiting = new Set();
  const topologyVisited = new Set();
  function visitNode(id) {
    if (topologyVisiting.has(id)) { add("/topology/edges", "TOPOLOGY_CYCLE", `topology cycle at ${id}`); return; }
    if (topologyVisited.has(id)) return;
    topologyVisiting.add(id);
    for (const target of adjacency.get(id) || []) visitNode(target);
    topologyVisiting.delete(id);
    topologyVisited.add(id);
  }
  model.topology.nodes.forEach((node) => visitNode(node.id));
  model.governance.responsibilities.forEach((item, index) => {
    if (!ids.has(item.subject_ref)) add(`/governance/responsibilities/${index}/subject_ref`, "DANGLING_SUBJECT_REF", "unknown subject");
    requireRef(actorIds, item.actor_ref, `/governance/responsibilities/${index}/actor_ref`, "DANGLING_ACTOR_REF");
  });
  const materialById = new Map(Object.values(model.inert_material).flat().map((item) => [item.id, item]));
  const expectedMaterialKinds = { seeds: "seed", dna: "dna", templates: "template", instructions: "instruction", prompts: "prompt", directives: "directive", governance: "governance" };
  for (const [collection, expected] of Object.entries(expectedMaterialKinds)) {
    model.inert_material[collection].forEach((item, index) => {
      if (item.kind !== expected) add(`/inert_material/${collection}/${index}/kind`, "MATERIAL_KIND_MISMATCH", `expected ${expected}`);
      requireRef(referenceIds, item.source_ref, `/inert_material/${collection}/${index}/source_ref`, "DANGLING_SOURCE_REF");
      const source = referenceById.get(item.source_ref);
      if (source && item.source_sha256 !== source.digest.value) add(`/inert_material/${collection}/${index}/source_sha256`, "MATERIAL_SOURCE_DIGEST_MISMATCH", "material source_sha256 must equal its source reference digest");
    });
  }
  model.governance.policy_snapshots.forEach((ref, index) => {
    if (materialById.get(ref)?.kind !== "governance") add(`/governance/policy_snapshots/${index}`, "POLICY_SNAPSHOT_INVALID", "must reference inert governance material");
  });
  model.metadata.created_from.forEach((ref, index) => requireRef(referenceIds, ref, `/metadata/created_from/${index}`, "DANGLING_SOURCE_REF"));
  work.forEach((item, index) => {
    item.dependencies.forEach((ref, refIndex) => requireRef(workIds, ref, `/plan/work/${index}/dependencies/${refIndex}`, "DANGLING_DEPENDENCY_REF"));
    item.blocker_refs.forEach((ref, refIndex) => { if (!workIds.has(ref) && !gapRiskIds.has(ref)) add(`/plan/work/${index}/blocker_refs/${refIndex}`, "DANGLING_BLOCKER_REF", "unknown blocker"); });
    item.domain_refs.forEach((ref, refIndex) => requireRef(domainIds, ref, `/plan/work/${index}/domain_refs/${refIndex}`, "DANGLING_DOMAIN_REF"));
    item.world_refs.forEach((ref, refIndex) => requireRef(worldIds, ref, `/plan/work/${index}/world_refs/${refIndex}`, "DANGLING_WORLD_REF"));
    if (item.critical_path_ref !== null) requireRef(nodeIds, item.critical_path_ref, `/plan/work/${index}/critical_path_ref`, "DANGLING_CRITICAL_PATH_REF");
  });
  const visiting = new Set();
  const visited = new Set();
  const dependencyMap = new Map(work.map((item) => [item.id, item.dependencies]));
  function visitDependency(id) {
    if (visiting.has(id)) { add("/plan", "DEPENDENCY_CYCLE", `dependency cycle at ${id}`); return; }
    if (visited.has(id)) return;
    visiting.add(id);
    for (const dependency of dependencyMap.get(id) || []) visitDependency(dependency);
    visiting.delete(id);
    visited.add(id);
  }
  work.forEach((item) => visitDependency(item.id));

  const eventIds = new Set();
  const lastStateByTask = new Map();
  let priorOccurredAt = null;
  model.lifecycle.events.forEach((event, index) => {
    if (eventIds.has(event.event_id)) add(`/lifecycle/events/${index}/event_id`, "DUPLICATE_EVENT_ID", "event_id must be unique");
    eventIds.add(event.event_id);
    requireRef(itemIds, event.task_ref, `/lifecycle/events/${index}/task_ref`, "DANGLING_TASK_REF");
    if (!TRANSITIONS[event.from_state].includes(event.to_state)) add(`/lifecycle/events/${index}/to_state`, "TRANSITION_DENIED", "transition is not allowed");
    if (priorOccurredAt !== null && new Date(event.occurred_at) < new Date(priorOccurredAt)) add(`/lifecycle/events/${index}/occurred_at`, "HISTORY_TIME_ORDER", "lifecycle events must be globally nondecreasing");
    priorOccurredAt = event.occurred_at;
    if (lastStateByTask.has(event.task_ref) && event.from_state !== lastStateByTask.get(event.task_ref)) add(`/lifecycle/events/${index}/from_state`, "HISTORY_STATE_DISCONTINUITY", "per-task event history is discontinuous");
    lastStateByTask.set(event.task_ref, event.to_state);
    const surfaces = event.reconciliation.map((item) => item.surface).sort();
    const expected = ["knowledge_base", "organization_model", "plan", "roadmap", "semantic_source", "workflow"];
    if (!deepEqual(surfaces, expected)) add(`/lifecycle/events/${index}/reconciliation`, "RECONCILIATION_INCOMPLETE", "requires each of six surfaces exactly once");
  });
  const lastEventId = model.lifecycle.events.at(-1)?.event_id ?? null;
  if (model.lifecycle.latest_event_ref !== lastEventId) add("/lifecycle/latest_event_ref", "LATEST_EVENT_INVALID", "latest_event_ref must be null exactly for empty history, otherwise the final event id");
  for (const [taskRef, finalState] of lastStateByTask) {
    const current = model.plan.work_items.find((item) => item.id === taskRef);
    if (current && current.lifecycle_state.state !== finalState) add("/plan/work_items", "HISTORY_FINAL_STATE_MISMATCH", `task ${taskRef} state differs from its final event`);
  }
  const lineage = model.child_derivation.parent_lineage;
  const lineageValues = [lineage.parent_artifact_id, lineage.parent_source_sha256, lineage.derivation_plan_id];
  if (model.child_derivation.generation_depth === 0 && lineageValues.some((item) => item !== null)) add("/child_derivation/parent_lineage", "ROOT_LINEAGE_INVALID", "depth zero requires null lineage");
  if (model.child_derivation.generation_depth > 0 && lineageValues.some((item) => item === null)) add("/child_derivation/parent_lineage", "CHILD_LINEAGE_INCOMPLETE", "child depth requires complete lineage");
  if (model.child_derivation.generation_depth === 2 && model.child_derivation.capability_ceiling.includes("sync_parent_model")) add("/child_derivation/capability_ceiling", "DEPTH_CAPABILITY_INVALID", "depth two cannot sync a parent model");
  for (const item of model.plan.work_items) {
    const seen = new Set();
    let current = item;
    while (current?.lifecycle_state.state === "superseded" && current.lifecycle_state.successor_ref) {
      if (seen.has(current.id)) { add("/plan/work_items", "SUCCESSOR_CYCLE", `successor cycle at ${current.id}`); break; }
      seen.add(current.id);
      current = model.plan.work_items.find((candidate) => candidate.id === current.lifecycle_state.successor_ref);
    }
  }
  return errors;
}

function validateModel(model) {
  const schema = schemaErrors(model, MODEL_SCHEMA);
  if (schema.length) throw new AppError("MODEL_SCHEMA_INVALID", "Session model failed schema validation", 1, schema);
  const semantic = semanticErrors(model);
  if (semantic.length) throw new AppError("MODEL_SEMANTIC_INVALID", "Session model failed semantic validation", 1, semantic);
}

function lifecycleState(item) {
  return item.lifecycle_state?.state ?? item.status;
}

function dependencySucceeded(id, items, seen = new Set()) {
  if (seen.has(id)) return false;
  const item = items.get(id);
  if (!item) return false;
  if (item.lifecycle_state.state === "completed") return true;
  if (item.lifecycle_state.state !== "superseded" || !item.lifecycle_state.successor_ref) return false;
  return dependencySucceeded(item.lifecycle_state.successor_ref, items, new Set([...seen, id]));
}

function nextTask(model) {
  const items = new Map(model.plan.work_items.map((item) => [item.id, item]));
  const blockers = new Map([...model.analysis.gaps, ...model.analysis.risks].map((item) => [item.id, item]));
  const criticalIndex = new Map(model.topology.critical_path.map((id, index) => [id, index]));
  const criticalRank = (item) => item.critical_path_ref === null ? Number.MAX_SAFE_INTEGER : (criticalIndex.get(item.critical_path_ref) ?? Number.MAX_SAFE_INTEGER);
  const eligible = model.plan.work_items.filter((item) => {
    if (item.lifecycle_state.state !== "planned") return false;
    if (!item.dependencies.every((id) => dependencySucceeded(id, items))) return false;
    return item.blocker_refs.every((id) => {
      if (items.has(id)) return dependencySucceeded(id, items);
      const blocker = blockers.get(id);
      return blocker && (!blocker.blocking || blocker.status === "completed");
    });
  });
  const priority = { q1: 0, q2: 1, q3: 2, q4: 3 };
  const compare = (left, right) =>
    Number(right.blocking) - Number(left.blocking)
    || priority[left.priority] - priority[right.priority]
    || criticalRank(left) - criticalRank(right)
    || left.sequence - right.sequence
    || Buffer.compare(Buffer.from(left.id), Buffer.from(right.id));
  const started = model.plan.work_items.filter((item) => item.lifecycle_state.state === "started").sort(compare);
  if (started.length) return { disposition: "IN_PROGRESS", task_ref: started[0].id };
  const delegated = model.plan.work_items.filter((item) => item.lifecycle_state.state === "delegated").sort(compare);
  if (delegated.length) return { disposition: "DELEGATED", task_ref: delegated[0].id };
  eligible.sort(compare);
  if (eligible.length) return { disposition: "TASK", task_ref: eligible[0].id };
  if (model.plan.work_items.some((item) => item.lifecycle_state.state === "hitl")) return { disposition: "HITL", task_ref: null };
  if (model.plan.work_items.some((item) => !TERMINAL_STATES.has(item.lifecycle_state.state))) return { disposition: "BLOCKED", task_ref: null };
  return { disposition: "QUIESCENT", task_ref: null };
}

function deriveFacts(model) {
  const counts = Object.fromEntries(STATUS_VALUES.map((status) => [status, 0]));
  walk(model, "", (value) => {
    if (Array.isArray(value)) return;
    const state = value.lifecycle_state?.state ?? value.status;
    if (STATUS_VALUES.includes(state)) counts[state] += 1;
  });
  const pathNodes = model.topology.critical_path.map((id) => model.topology.nodes.find((node) => node.id === id));
  const criticalPathHead = pathNodes.find((node) => node.status !== "completed")?.id ?? null;
  const criteria = [...model.intent.definition_of_done, ...model.governance.acceptance_criteria];
  const blockingDomain = [...model.analysis.gaps, ...model.analysis.risks]
    .some((item) => item.blocking && !["completed", "superseded"].includes(item.status));
  const blockingWork = model.plan.work_items.some((item) => item.blocking && !dependencySucceeded(item.id, new Map(model.plan.work_items.map((work) => [work.id, work]))));
  const criticalBad = pathNodes.some((node) => ["unknown", "hitl", "blocked"].includes(node.status));
  const readiness = criteria.every((item) => item.status === "completed") && !blockingDomain && !blockingWork && !criticalBad ? "READY" : "NOT_READY";
  return { status_counts: STATUS_VALUES.map((status) => ({ status, count: counts[status] })), readiness, critical_path_head: criticalPathHead, next: nextTask(model) };
}

const PUBLIC_URN_PREFIXES = ["urn:vasm:", "urn:public:", "urn:example:", "urn:embedded-snapshot:"];
function embeddedIPv4FromMappedHost(inner) {
  const hexPair = /^(?:::ffff:|64:ff9b::)([0-9a-f]{1,4}):([0-9a-f]{1,4})$/u.exec(inner);
  if (!hexPair) return null;
  const high = Number.parseInt(hexPair[1], 16);
  const low = Number.parseInt(hexPair[2], 16);
  if (!Number.isInteger(high) || !Number.isInteger(low) || high > 0xffff || low > 0xffff) return null;
  return [(high >> 8) & 0xff, high & 0xff, (low >> 8) & 0xff, low & 0xff];
}
function isPrivateIPv4Quad(a, b) {
  return a === 127 || a === 10 || a === 0 || (a === 172 && b >= 16 && b <= 31) || (a === 192 && b === 168) || (a === 169 && b === 254);
}
function isPrivateOrLoopbackHost(hostname) {
  const host = hostname.toLowerCase();
  if (host === "localhost" || host === "0.0.0.0") return true;
  if (host.endsWith(".local")) return true;
  if (host.startsWith("[") && host.endsWith("]")) {
    const inner = host.slice(1, -1);
    if (inner === "::1" || inner === "::") return true;
    // fe80::/10 spans first-hextet 0xfe80-0xfebf (10 fixed bits, not nibble-aligned) —
    // a literal "fe80:" string-prefix match misses fe81::..febf:: entirely.
    const leadingHextetText = inner.split(":")[0];
    const leadingHextet = /^[0-9a-f]{1,4}$/u.test(leadingHextetText) ? Number.parseInt(leadingHextetText, 16) : null;
    if (leadingHextet !== null && leadingHextet >= 0xfe80 && leadingHextet <= 0xfebf) return true;
    if (/^f[cd][0-9a-f]{2}:/u.test(inner)) return true;
    // SEC-002 follow-up: an IPv4-mapped (::ffff:0:0/96, RFC 4291 §2.5.5.2) or NAT64
    // (64:ff9b::/96, RFC 6052) IPv6 literal embeds a real IPv4 address in its last 32
    // bits; re-run the same dotted-quad private-range check against the embedded bytes
    // instead of letting WHATWG URL's hex-compressed serialization slip past unchecked.
    const mapped = embeddedIPv4FromMappedHost(inner);
    if (mapped) return isPrivateIPv4Quad(mapped[0], mapped[1]);
    return false;
  }
  const ipv4 = host.match(/^(\d{1,3})\.(\d{1,3})\.(\d{1,3})\.(\d{1,3})$/u);
  if (ipv4) return isPrivateIPv4Quad(Number(ipv4[1]), Number(ipv4[2]));
  return !host.includes(".");
}
function isPublicHttpsUri(uri) {
  if (typeof uri !== "string" || !uri.startsWith("https://")) return false;
  let parsed;
  try { parsed = new URL(uri); } catch { return false; }
  if (parsed.protocol !== "https:" || parsed.username || parsed.password) return false;
  return !isPrivateOrLoopbackHost(parsed.hostname);
}
function isPublicReferenceUri(uri) {
  return isPublicHttpsUri(uri) || (typeof uri === "string" && PUBLIC_URN_PREFIXES.some((prefix) => uri.startsWith(prefix)));
}

function validatePortableDistribution(model) {
  const problems = [];
  const add = (pathValue, code, message) => problems.push({ path: pathValue, code, message });
  const distribution = model.metadata.distribution;
  if (distribution.classification !== "portable_sanitized"
      || distribution.references_policy !== "public_only"
      || distribution.content_policy !== "sanitized_public_only") {
    add("/metadata/distribution", "PORTABLE_POLICY_REQUIRED", "portable sidecards require sanitized public-only distribution");
  }
  model.references.forEach((reference, index) => {
    if (reference.distribution !== "public" || !isPublicReferenceUri(reference.uri)) add(`/references/${index}`, "PRIVATE_REFERENCE", "portable references must be public https or urn values");
  });
  const git = model.traceability.git;
  if (git.repository_visibility !== "public" && [git.repository_uri, git.ref_name, git.commit_sha, git.tree_sha].some((value) => value !== null)) add("/traceability/git", "PRIVATE_GIT_DISCLOSURE", "undisclosed Git metadata must remain null");
  model.organization.contexts.forEach((context, index) => {
    if (context.repository_uri !== null && !isPublicHttpsUri(context.repository_uri)) add(`/organization/contexts/${index}/repository_uri`, "PRIVATE_REPOSITORY_URI", "portable repository URI must be public https or null");
  });
  for (const classification of model.organization.classifications) {
    if (["private", "secrets", "pii", "lgpd", "gdpr"].includes(classification.class) && classification.disposition !== "excluded") add("/organization/classifications", "PRIVATE_CLASSIFICATION_INCLUDED", `${classification.class} must be excluded`);
  }
  const canonical = canonicalBytes(model).toString("utf8");
  const texts = [canonical, ...decodedPayloads(canonical)];
  for (const [code, pattern] of [
    ["PRIVATE_PATH", /(?:\/Users\/|\/home\/|[A-Za-z]:\\Users\\)/u],
    ["LOCAL_IDENTIFIER", /(?:account|store)[_-]?id\s*[:=]/iu],
    ["RAW_TRANSCRIPT", /(?:raw|full|verbatim)[ _-]?transcript/iu],
    ["HIDDEN_PROMPT", /(?:system|developer)[ _-]?prompt/iu],
    ["ACTIVE_URL_PAYLOAD", /(?:javascript|data|blob):/iu],
    ["INSECURE_URL", /http:\/\//iu]
  ]) if (texts.some((text) => pattern.test(text))) add("/", code, "portable content contains a blocked private or active-content pattern");
  if (problems.length) throw new AppError("PORTABLE_DISTRIBUTION_REJECTED", "Portable distribution checks failed", 1, problems);
}

function deterministicUuid(hex) {
  const chars = hex.slice(0, 32).split("");
  chars[12] = "4";
  chars[16] = ["8", "9", "a", "b"][Number.parseInt(chars[16], 16) % 4];
  const value = chars.join("");
  return `${value.slice(0, 8)}-${value.slice(8, 12)}-${value.slice(12, 16)}-${value.slice(16, 20)}-${value.slice(20)}`;
}

function portableStem(model, digestLength = 12) {
  const identity = model.identity;
  const date = identity.chronological.as_of.replace(/[-:]/gu, "").replace(/\.\d+Z$/u, "Z");
  const prefix = [
    identity.taxonomic.family,
    identity.taxonomic.artifact_class,
    identity.semantic.subject,
    identity.semantic.purpose
  ].join("-").slice(0, 72).replace(/-+$/u, "");
  return `${prefix}--${date}-r${identity.chronological.revision}-v${identity.version}--h${identityDigest(model).slice(0, digestLength)}`;
}

function portableStemMatches(model, stem) {
  return [12, 16, 24, 32, 64].some((length) => portableStem(model, length) === stem);
}

async function selectPortableStem(model, outDir) {
  for (const length of [12, 16, 24, 32, 64]) {
    const stem = portableStem(model, length);
    const manifest = path.join(outDir, `${stem}.manifest.json`);
    const occupied = [`${stem}.session-model.json`, `${stem}.sidecard.html`, `${stem}.manifest.json`]
      .some((name) => fs.existsSync(path.join(outDir, name)));
    if (!occupied) return stem;
    if (fs.existsSync(manifest)) {
      const existing = await readJson(manifest, "existing portable manifest");
      if (existing.value.identity_sha256 === identityDigest(model)) return stem;
    }
  }
  throw new AppError("IDENTITY_HASH_COLLISION", "All collision-safe identity digest suffixes are occupied");
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/gu, (character) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "\"": "&quot;", "'": "&#39;" })[character]);
}

const STATUS_PRESENTATION = {
  planned: ["○", "Planned"], started: ["▶", "Started"], delegated: ["↗", "Delegated"],
  deferred: ["◷", "Deferred"], hitl: ["◇", "HITL"], blocked: ["!", "Blocked"],
  completed: ["✓", "Completed"], canceled: ["×", "Canceled"], superseded: ["⇢", "Superseded"],
  deprecated: ["⌁", "Deprecated"], unknown: ["?", "Unknown"]
};

const PORTABLE_STYLE = `:root{color-scheme:light dark;--bg:#f8fafc;--panel:#fff;--text:#172033;--muted:#526079;--line:#cbd5e1;--accent:#1d4ed8}*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:14px/1.5 ui-monospace,SFMono-Regular,Menlo,monospace}main{max-width:1180px;margin:auto;padding:28px}.hero,.panel{border:1px solid var(--line);background:var(--panel);border-radius:12px;padding:18px;margin:0 0 16px}.hero h1{margin:4px 0}.eyebrow{color:var(--accent);font-weight:700}.muted{color:var(--muted)}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(280px,1fr));gap:14px}.wide{grid-column:1/-1}h2,h3{margin:0 0 10px}dl{display:grid;grid-template-columns:minmax(110px,.45fr) 1fr;gap:6px 12px;margin:0}dt{color:var(--muted)}dd{margin:0;overflow-wrap:anywhere}ul{margin:0;padding-left:20px}.status{display:inline-flex;gap:7px;align-items:center;border-radius:999px;padding:2px 9px;font-weight:700;border:1px solid currentColor}.status[data-state=planned],.status[data-state=canceled],.status[data-state=deprecated],.status[data-state=unknown]{color:#334155;background:#f1f5f9}.status[data-state=started]{color:#1e40af;background:#dbeafe}.status[data-state=delegated],.status[data-state=superseded]{color:#5b21b6;background:#ede9fe}.status[data-state=deferred]{color:#78350f;background:#fef3c7}.status[data-state=hitl]{color:#9a3412;background:#ffedd5}.status[data-state=blocked]{color:#991b1b;background:#fee2e2}.status[data-state=completed]{color:#166534;background:#dcfce7}.node{border-left:4px solid var(--accent);padding:9px 11px;margin:8px 0;background:color-mix(in srgb,var(--panel) 90%,var(--accent))}.edge{padding:4px 0}.warning{border-color:#b45309}.mono{overflow-wrap:anywhere}@media(prefers-color-scheme:dark){:root{--bg:#0f172a;--panel:#172033;--text:#e5edf8;--muted:#aab7ca;--line:#475569;--accent:#93c5fd}.status[data-state=planned],.status[data-state=canceled],.status[data-state=deprecated],.status[data-state=unknown]{color:#e2e8f0;background:#1e293b}.status[data-state=started]{color:#bfdbfe;background:#1e3a8a}.status[data-state=delegated],.status[data-state=superseded]{color:#ddd6fe;background:#4c1d95}.status[data-state=deferred]{color:#fde68a;background:#78350f}.status[data-state=hitl]{color:#fed7aa;background:#7c2d12}.status[data-state=blocked]{color:#fecaca;background:#7f1d1d}.status[data-state=completed]{color:#bbf7d0;background:#14532d}}@media(prefers-reduced-motion:reduce){*{scroll-behavior:auto!important}}@media print{body{background:#fff;color:#111}.panel,.hero{break-inside:avoid}}`;
const PORTABLE_GRAPH_STYLE = `.workflow-svg{display:block;width:100%;height:auto;margin:12px 0 18px;border:1px solid var(--line);border-radius:10px;background:var(--bg)}.lane-band{fill:var(--panel);stroke:var(--line)}.lane-title,.svg-edge-label{fill:var(--muted);font-size:11px}.svg-edge{stroke:var(--muted);stroke-width:1.6;fill:none}.svg-node{stroke-width:2}.svg-node-label{fill:var(--text);font-size:12px;font-weight:700}.svg-node-state{font-size:10px;font-weight:700}.state-planned{--state-fg:#334155;--state-bg:#f1f5f9}.state-started{--state-fg:#1e40af;--state-bg:#dbeafe}.state-delegated,.state-superseded{--state-fg:#5b21b6;--state-bg:#ede9fe}.state-deferred{--state-fg:#78350f;--state-bg:#fef3c7}.state-hitl{--state-fg:#9a3412;--state-bg:#ffedd5}.state-blocked{--state-fg:#991b1b;--state-bg:#fee2e2}.state-completed{--state-fg:#166534;--state-bg:#dcfce7}.state-canceled,.state-deprecated,.state-unknown{--state-fg:#334155;--state-bg:#e2e8f0}.svg-item .svg-node{fill:var(--state-bg);stroke:var(--state-fg)}.svg-item .svg-node-state{fill:var(--state-fg)}.node[data-state]{border-left-color:var(--state-fg);background:var(--state-bg);color:var(--state-fg)}@media(prefers-color-scheme:dark){.state-planned,.state-canceled,.state-deprecated,.state-unknown{--state-fg:#e2e8f0;--state-bg:#1e293b}.state-started{--state-fg:#bfdbfe;--state-bg:#1e3a8a}.state-delegated,.state-superseded{--state-fg:#ddd6fe;--state-bg:#4c1d95}.state-deferred{--state-fg:#fde68a;--state-bg:#78350f}.state-hitl{--state-fg:#fed7aa;--state-bg:#7c2d12}.state-blocked{--state-fg:#fecaca;--state-bg:#7f1d1d}.state-completed{--state-fg:#bbf7d0;--state-bg:#14532d}}`;
const PORTABLE_ROW_STYLE = `.state-row{border-left:4px solid var(--state-fg);background:var(--state-bg);color:var(--state-fg);padding:6px 9px;margin:5px 0;border-radius:5px}.state-row strong{color:inherit}`;
const PORTABLE_LAYOUT_STYLE = `main{max-width:980px}.grid{grid-template-columns:repeat(2,minmax(0,1fr))}.panel{min-width:0}dl{grid-template-columns:minmax(150px,.55fr) minmax(0,1fr)}dt{min-width:0}dd{min-width:0;overflow-wrap:break-word;word-break:normal}.mono,code{max-width:100%;overflow-wrap:anywhere;word-break:break-word}@media(max-width:720px){main{padding:14px}.grid{grid-template-columns:minmax(0,1fr)}dl{grid-template-columns:minmax(0,1fr);gap:2px}dt{margin-top:8px}dd{margin-bottom:4px}}`;
const PORTABLE_ALMANAC_STYLE = `:root{color-scheme:light dark;--bg:#f6f8fa;--panel:#ffffff;--panel-subtle:#f0f3f6;--text:#172033;--muted:#475569;--line:#cbd5e1;--line-strong:#64748b;--accent:#1e40af;--danger:#b42318;--focus:#1d4ed8;--font-ui:ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;--font-data:ui-monospace,SFMono-Regular,Menlo,Consolas,monospace}body{font:15px/1.55 var(--font-ui);font-synthesis:none;text-rendering:optimizeLegibility}main{max-width:1120px;padding:32px 20px 64px}.hero,.panel{min-width:0;border:1px solid var(--line);padding:20px 22px;margin:0 0 16px}h1,h2,h3{text-wrap:balance}h1{font-size:32px;line-height:1.2;letter-spacing:-.02em;margin:0 0 8px}h2{font-size:18px;line-height:1.3;margin:0 0 16px}h3{font-size:15px;line-height:1.35;margin:24px 0 8px}.subtitle{max-width:72ch;margin:0 0 16px;color:var(--muted);font-size:16px;line-height:1.6}.goal{max-width:75ch;margin:16px 0}.meta{margin:12px 0 0;color:var(--muted);font-size:13px;font-variant-numeric:tabular-nums}.artifact-id,.hero .meta{min-width:0;overflow-wrap:anywhere;word-break:break-word}.snapshot-strip{display:flex;flex-wrap:wrap;gap:8px 16px;align-items:center;padding:10px 0;border-block:1px solid var(--line);font-size:13px}.trust{font-weight:700}.grid{grid-template-columns:repeat(2,minmax(0,1fr));gap:16px;align-items:start}.wide{grid-column:1/-1}.priority{border-color:var(--line-strong)}dl{grid-template-columns:minmax(124px,.38fr) minmax(0,1fr);gap:8px 16px}dt{min-width:0;color:var(--muted);font-size:13px;font-weight:650}dd{min-width:0;overflow-wrap:anywhere;word-break:normal}.mono,code,.artifact-id{font-family:var(--font-data);font-variant-numeric:tabular-nums;max-width:100%;overflow-wrap:anywhere;word-break:break-word}.node,.state-row{border:1px solid var(--state-fg);border-radius:8px;padding:10px 12px;margin:8px 0;background:var(--state-bg);color:var(--state-fg)}.node[data-state] .muted{color:inherit;font-size:13px;margin-top:4px}.workflow-figure{margin:12px 0 20px}.workflow-scroll{max-width:100%;overflow-x:auto;overscroll-behavior-x:contain;scrollbar-color:var(--line-strong) var(--panel-subtle)}.workflow-scroll:focus-visible,summary:focus-visible{outline:3px solid var(--focus);outline-offset:3px}.workflow-svg{width:100%;margin:0;border-color:var(--line-strong)}.lane-title,.svg-edge-label{fill:var(--muted);font:12px var(--font-ui)}.svg-node-label{fill:var(--text);font:700 15px var(--font-ui)}.svg-node-state{font:700 11px var(--font-ui)}.svg-edge-label{paint-order:stroke;stroke:var(--bg);stroke-width:5px;stroke-linejoin:round}.edge-group{--edge-color:var(--muted)}.edge-group .svg-edge{stroke:var(--edge-color);stroke-width:1.6;fill:none}.edge-group .svg-edge-arrow{fill:var(--edge-color)}.edge-variant-emphasis{--edge-color:var(--accent)}.edge-variant-emphasis .svg-edge,.edge-variant-security .svg-edge{stroke-width:2.4}.edge-variant-security{--edge-color:var(--danger)}.edge-role-branch .svg-edge,.edge-variant-dashed .svg-edge{stroke-dasharray:8 5}.edge-role-return .svg-edge{stroke-dasharray:2 4}.diagram-key,.legend-list{display:flex;flex-wrap:wrap;gap:8px 12px;align-items:center}.legend-list{list-style:none;padding:0}.register{margin-top:20px}.register summary{cursor:pointer;color:var(--text);font-weight:700;padding:8px 0}.workflow-figure figcaption{margin-top:8px;color:var(--muted);font-size:13px}.evidence-row{margin:8px 0;padding:8px 0;border-bottom:1px solid var(--line);overflow-wrap:anywhere}@media(prefers-color-scheme:dark){:root{--bg:#0d1117;--panel:#161b22;--panel-subtle:#21262d;--text:#e6edf3;--muted:#9da7b3;--line:#30363d;--line-strong:#6e7681;--accent:#79c0ff;--danger:#f85149;--focus:#79c0ff}}@media(max-width:1000px){.workflow-svg{min-width:900px}}@media(max-width:720px){main{padding:16px 14px 48px}.grid{grid-template-columns:minmax(0,1fr)}.hero,.panel{padding:16px 14px}h1{font-size:28px}dl{grid-template-columns:minmax(0,1fr);gap:2px}dt{margin-top:10px}dd{margin-bottom:4px}}@media print{:root{color-scheme:light;--bg:#fff;--panel:#fff;--panel-subtle:#fff;--text:#111827;--muted:#334155;--line:#94a3b8;--line-strong:#64748b;--accent:#1e40af;--danger:#991b1b;--focus:#1e40af}body{font-size:10pt;background:#fff;color:var(--text);print-color-adjust:exact;-webkit-print-color-adjust:exact}main{max-width:none;padding:0}.grid{display:block}.hero,.panel{padding:12pt;margin:0 0 10pt;background:#fff;break-inside:auto}.hero,#identity,#traceability,#contexts,#domains,#lineage,#materials{break-inside:avoid}h2,h3,summary{break-after:avoid}.node,.state-row,li{break-inside:avoid}.workflow-scroll{overflow:visible}.workflow-svg{min-width:0}details:not([open])>*:not(summary){display:block!important}.state-planned,.state-started,.state-delegated,.state-deferred,.state-hitl,.state-blocked,.state-completed,.state-canceled,.state-superseded,.state-deprecated,.state-unknown{--state-fg:#111827;--state-bg:#fff}}`;
const PORTABLE_CSS = `${PORTABLE_STYLE}${PORTABLE_GRAPH_STYLE}${PORTABLE_ROW_STYLE}${PORTABLE_LAYOUT_STYLE}${PORTABLE_ALMANAC_STYLE}`;

function statusBadge(state) {
  const [glyph, label] = STATUS_PRESENTATION[state];
  return `<span class=\"status state-${state}\" data-state=\"${state}\"><span aria-hidden=\"true\">${glyph}</span>${label}</span>`;
}

function portableWorkflowSvg(model) {
  if (model.topology.lanes.length > 48 || model.topology.nodes.length > 288) throw new AppError("SIDECARD_VISUAL_LIMIT", "Portable workflow exceeds 48 lanes or 288 nodes");
  const width = 1120;
  const laneHeight = 90;
  const height = Math.max(170, 58 + model.topology.lanes.length * laneHeight);
  const laneIndex = new Map(model.topology.lanes.map((lane, index) => [lane.id, index]));
  const positioned = new Map(model.topology.nodes.map((node) => [node.id, {
    ...node,
    x: 70 + node.column * 175,
    y: 36 + laneIndex.get(node.lane) * laneHeight,
    width: 145,
    height: 58
  }]));
  const lanes = model.topology.lanes.map((lane, index) => {
    const y = 18 + index * laneHeight;
    return `<g data-lane-id=\"${escapeHtml(lane.id)}\"><rect class=\"lane-band\" x=\"12\" y=\"${y}\" width=\"1096\" height=\"78\" rx=\"8\"/><text class=\"lane-title\" x=\"24\" y=\"${y + 18}\">${escapeHtml(truncateToUnits(lane.label, 32))}</text></g>`;
  }).join("");
  const edges = model.topology.edges.map((edge) => {
    const from = positioned.get(edge.from);
    const to = positioned.get(edge.to);
    const x1 = from.x + from.width / 2;
    const y1 = from.y + from.height / 2;
    const x2 = to.x + to.width / 2;
    const y2 = to.y + to.height / 2;
    const dx = x2 - x1;
    const dy = y2 - y1;
    const length = Math.hypot(dx, dy) || 1;
    const ux = dx / length;
    const uy = dy / length;
    const targetOffset = Math.abs(dx) >= Math.abs(dy) ? to.width / 2 + 3 : to.height / 2 + 3;
    const tipX = x2 - ux * targetOffset;
    const tipY = y2 - uy * targetOffset;
    const baseX = tipX - ux * 10;
    const baseY = tipY - uy * 10;
    const arrow = `${tipX},${tipY} ${baseX - uy * 5},${baseY + ux * 5} ${baseX + uy * 5},${baseY - ux * 5}`;
    const labelT = edge.bias ?? 0.5;
    const labelX = x1 + (tipX - x1) * labelT + (edge.label_dx ?? 0);
    const labelY = y1 + (tipY - y1) * labelT + (edge.label_dy ?? -8);
    const role = edge.role ?? "main";
    const variant = edge.variant ?? "default";
    const label = edge.label ? `<text class=\"svg-edge-label\" x=\"${labelX}\" y=\"${labelY}\" text-anchor=\"middle\">${escapeHtml(truncateToUnits(edge.label, 22))}</text>` : "";
    return `<g class=\"edge-group edge-role-${role} edge-variant-${variant}\" data-edge-id=\"${escapeHtml(edge.id)}\" data-from=\"${escapeHtml(edge.from)}\" data-to=\"${escapeHtml(edge.to)}\"><line class=\"svg-edge\" x1=\"${x1}\" y1=\"${y1}\" x2=\"${tipX}\" y2=\"${tipY}\"/><polygon class=\"svg-edge-arrow\" points=\"${arrow}\"/>${label}</g>`;
  }).join("");
  const nodes = [...positioned.values()].map((node) => {
    const [glyph, stateLabel] = STATUS_PRESENTATION[node.status];
    const cx = node.x + node.width / 2;
    return `<g class=\"svg-item state-${node.status}\" data-node-id=\"${escapeHtml(node.id)}\" data-state=\"${node.status}\"><title>${escapeHtml(node.label)} — ${escapeHtml(stateLabel)}</title><rect class=\"svg-node\" x=\"${node.x}\" y=\"${node.y}\" width=\"${node.width}\" height=\"${node.height}\" rx=\"8\"/><text class=\"svg-node-label\" x=\"${cx}\" y=\"${node.y + 24}\" text-anchor=\"middle\">${escapeHtml(truncateToUnits(node.label, 18))}</text><text class=\"svg-node-state\" x=\"${cx}\" y=\"${node.y + 43}\" text-anchor=\"middle\">${glyph} ${escapeHtml(stateLabel)}</text></g>`;
  }).join("");
  return `<svg id=\"dependency-graph\" class=\"workflow-svg\" viewBox=\"0 0 ${width} ${height}\" role=\"img\" aria-labelledby=\"dependency-graph-title dependency-graph-desc\"><title id=\"dependency-graph-title\">Agentic session dependency workflow</title><desc id=\"dependency-graph-desc\">Directed dependencies grouped by lane. Node fill, outline, glyph, and text encode delivery state.</desc>${lanes}<g aria-label=\"Directed edges\">${edges}</g><g aria-label=\"Status nodes\">${nodes}</g></svg>`;
}

function inertBlock(id, type, role, bytes) {
  return {
    descriptor: { id, role, encoding: "base64url", media_type: "application/json", canonicalization: "rfc8785-jcs", decoded_bytes: bytes.length, sha256: sha256(bytes) },
    html: `<script id=\"${id}\" type=\"${type}\" data-encoding=\"base64url\" data-media-type=\"application/json\" data-canonicalization=\"rfc8785-jcs\" data-bytes=\"${bytes.length}\" data-sha256=\"${sha256(bytes)}\">${bytes.toString("base64url")}</script>`
  };
}

function renderPortableSidecard(model, stemOverride = undefined) {
  validatePortableDistribution(model);
  model = JSON.parse(canonicalBytes(model).toString("utf8"));
  const derived = deriveFacts(model);
  const source = canonicalBytes(model);
  const identitySha = identityDigest(model);
  const stem = stemOverride ?? portableStem(model);
  const receipt = {
    schema_version: "1.0.0", kind: "agentic_session_render_receipt",
    source_sha256: sha256(source), source_bytes: source.length, identity_sha256: identitySha,
    identity_stem: stem, schema_sha256: sha256(fs.readFileSync(MODEL_SCHEMA)),
    template_sha256: sha256(Buffer.from(`portable-sidecard-template-v2\\n${PORTABLE_CSS}`)),
    generator: generatorIdentity(), run_id: deterministicUuid(sha256(Buffer.concat([source, Buffer.from(PORTABLE_CSS)]))),
    generated_at: model.identity.chronological.as_of,
    capability_profile: { mode: "passive_snapshot", browser_effects: "none", external_tool_required: true }
  };
  const semanticBlock = inertBlock("vasm-semantic-source", "application/vnd.maos.agentic-session+base64url", "semantic_source", source);
  const receiptBlock = inertBlock("vasm-render-receipt", "application/vnd.maos.render-receipt+base64url", "render_receipt", canonicalBytes(receipt));
  const csp = `default-src 'none'; base-uri 'none'; connect-src 'none'; img-src data:; style-src 'sha256-${createHash("sha256").update(PORTABLE_CSS).digest("base64")}'; font-src 'none'; media-src 'none'; object-src 'none'; frame-src 'none'; worker-src 'none'; manifest-src 'none'; form-action 'none'`;
  const identity = model.identity;
  const trace = model.traceability;
  const classifications = model.organization.classifications.map((item) => `<li>${escapeHtml(item.class)} — ${escapeHtml(item.disposition)}</li>`).join("");
  const contexts = model.organization.contexts.map((item) => `<li><strong>${escapeHtml(item.kind)}</strong> — ${escapeHtml(item.label)}${item.project_slug ? ` · ${escapeHtml(item.project_slug)}` : ""}${item.repository_uri ? ` · <span class=\"mono\">${escapeHtml(item.repository_uri)}</span>` : ""}</li>`).join("");
  const worlds = model.organization.worlds.map((item) => `<li><strong>${escapeHtml(item.kind)}</strong> — ${escapeHtml(item.label)}</li>`).join("");
  const domains = model.organization.domains.map((item) => `<li><strong>${escapeHtml(item.label)}</strong> — ${escapeHtml(item.purpose)}</li>`).join("");
  const actorLabels = new Map(model.organization.actors.map((actor) => [actor.id, actor.label]));
  const nodes = model.topology.nodes.map((node) => `<div class=\"node state-${node.status}\" data-state=\"${node.status}\">${statusBadge(node.status)} <strong>${escapeHtml(node.label)}</strong><div class=\"muted\"><span class=\"mono\">${escapeHtml(node.id)}</span> · ${escapeHtml(node.component_kind)} · owner ${escapeHtml(actorLabels.get(node.owner_actor_ref) || "Unknown")} (<span class=\"mono\">${escapeHtml(node.owner_actor_ref)}</span>) · ${escapeHtml(node.world_ref)} · ${escapeHtml(node.domain_refs.join(", "))}${node.reason ? ` · ${escapeHtml(node.reason)}` : ""}</div></div>`).join("");
  const edges = model.topology.edges.map((edge) => `<li class=\"edge\"><code>${escapeHtml(edge.from)}</code> → <code>${escapeHtml(edge.to)}</code>${edge.label ? ` · ${escapeHtml(edge.label)}` : ""} · role=<code>${escapeHtml(edge.role ?? "main")}</code> · variant=<code>${escapeHtml(edge.variant ?? "default")}</code> · route=<code>${escapeHtml(edge.route ?? "schematic")}</code></li>`).join("");
  const workflowSvg = portableWorkflowSvg(model);
  const responsibilities = model.governance.responsibilities.map((item) => `<li><strong>${escapeHtml(item.role)}</strong> · ${escapeHtml(actorLabels.get(item.actor_ref) || "Unknown actor")} (<code>${escapeHtml(item.actor_ref)}</code>) → <code>${escapeHtml(item.subject_ref)}</code>${item.detail ? `<div class=\"muted\">${escapeHtml(item.detail)}</div>` : ""}</li>`).join("");
  const constraints = model.governance.authority_constraints.map((item) => `<li class=\"state-row state-${item.status}\" data-state=\"${item.status}\">${statusBadge(item.status)} ${escapeHtml(item.title)}${item.reason ? `<div>${escapeHtml(item.reason)}</div>` : ""}</li>`).join("");
  const criteriaItems = [...model.intent.definition_of_done, ...model.governance.acceptance_criteria];
  const criteria = criteriaItems.map((item) => `<li class=\"state-row state-${item.status}\" data-state=\"${item.status}\">${statusBadge(item.status)} ${escapeHtml(item.text)}${item.reason ? `<div>${escapeHtml(item.reason)}</div>` : ""}</li>`).join("");
  const risks = model.analysis.risks.map((item) => `<li class=\"state-row state-${item.status}\" data-state=\"${item.status}\">${statusBadge(item.status)} ${escapeHtml(item.title)} · ${escapeHtml(item.likelihood)}/${escapeHtml(item.impact)} · blocking=${item.blocking}${item.reason ? `<div>${escapeHtml(item.reason)}</div>` : ""}</li>`).join("");
  const work = model.plan.work_items.map((item) => {
    const criticalOwner = model.topology.nodes.find((node) => node.id === item.critical_path_ref)?.owner_actor_ref;
    const actorId = item.lifecycle_state.assigned_actor_ref ?? criticalOwner;
    const actor = actorId ? `${actorLabels.get(actorId) || "Unknown actor"} (${actorId})` : "Unassigned (none)";
    return `<li class=\"state-row state-${item.lifecycle_state.state}\" data-state=\"${item.lifecycle_state.state}\">${statusBadge(item.lifecycle_state.state)} <strong class=\"mono\">${escapeHtml(item.id)}</strong> — ${escapeHtml(item.title)}<div>Actor: ${escapeHtml(actor)} · Dependencies: ${escapeHtml(item.dependencies.join(", ") || "none")}${item.lifecycle_state.reason ? ` · Reason: ${escapeHtml(item.lifecycle_state.reason)}` : ""}</div></li>`;
  }).join("");
  const stateSet = new Set([...model.topology.nodes.map((item) => item.status), ...model.governance.authority_constraints.map((item) => item.status), ...criteriaItems.map((item) => item.status), ...model.analysis.risks.map((item) => item.status), ...model.plan.work_items.map((item) => item.lifecycle_state.state)]);
  const statusKey = STATUS_VALUES.filter((state) => stateSet.has(state)).map((state) => `<li>${statusBadge(state)}</li>`).join("");
  const edgeKey = [...new Set(model.topology.edges.map((edge) => `${edge.role ?? "main"} / ${edge.variant ?? "default"}`))].map((item) => `<li><code>${escapeHtml(item)}</code></li>`).join("");
  const materials = Object.values(model.inert_material).flat().map((item) => `<li>${escapeHtml(item.kind)} · ${escapeHtml(item.purpose)} · untrusted_data · binding=false · effect=none</li>`).join("");
  const evidence = model.references.map((reference) => `<div class=\"evidence-row\"><code>${escapeHtml(reference.id)}</code> · ${escapeHtml(reference.role)}<br><span class=\"mono\">${escapeHtml(reference.uri)}</span><br><span class=\"mono\">${escapeHtml(reference.digest.algorithm)}:${escapeHtml(reference.digest.value)}</span></div>`).join("");
  const nextAction = model.plan.next_action;
  const html = `<!doctype html>
<html lang=\"${escapeHtml(model.metadata.language)}\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width,initial-scale=1\"><meta http-equiv=\"Content-Security-Policy\" content=\"${escapeHtml(csp)}\"><meta name=\"theme-color\" media=\"(prefers-color-scheme: light)\" content=\"#f6f8fa\"><meta name=\"theme-color\" media=\"(prefers-color-scheme: dark)\" content=\"#0d1117\"><title>${escapeHtml(model.metadata.title)} — portable sidecard</title><style>${PORTABLE_CSS}</style></head><body><main>
<header class=\"hero\"><h1 translate=\"no\">${escapeHtml(model.metadata.title)}</h1><p class=\"subtitle\">${escapeHtml(model.metadata.scope)}</p><div class=\"snapshot-strip\"><span class=\"status state-planned\"><span aria-hidden=\"true\">○</span>Snapshot · Not Live</span><span>Generated externally</span><span class=\"trust\">Portable trust: CONSISTENT_UNTRUSTED</span></div><p class=\"goal\"><strong>Current goal:</strong> ${escapeHtml(model.intent.goal)}</p><p class=\"meta\">As of <time datetime=\"${escapeHtml(identity.chronological.as_of)}\">${escapeHtml(identity.chronological.as_of)}</time> · <span class=\"artifact-id mono\" translate=\"no\">${escapeHtml(artifactId(model))}</span></p></header>
<div class=\"grid\">
<section class=\"panel wide priority\" id=\"next\"><h2>Current Disposition</h2><p><strong>${escapeHtml(derived.next.disposition)}</strong>${derived.next.task_ref ? ` · <span class=\"mono\">${escapeHtml(derived.next.task_ref)}</span>` : ""}</p><dl class=\"next-action\"><dt>What</dt><dd>${escapeHtml(nextAction.what)}</dd><dt>Who</dt><dd>${escapeHtml(nextAction.who)}</dd><dt>When</dt><dd>${escapeHtml(nextAction.when)}</dd><dt>Why</dt><dd>${escapeHtml(nextAction.why)}</dd><dt>Where</dt><dd>${escapeHtml(nextAction.where)}</dd><dt>How</dt><dd>${escapeHtml(nextAction.how)}</dd></dl><details class=\"register\"><summary>Work Register · ${model.plan.work_items.length} Items</summary><ul>${work || "<li>None</li>"}</ul></details></section>
<section class=\"panel\" id=\"identity\"><h2>Identity — eight facets</h2><dl><dt>Taxonomic</dt><dd>${escapeHtml(Object.values(identity.taxonomic).join(" · "))}</dd><dt>Semantic</dt><dd>${escapeHtml(Object.values(identity.semantic).join(" · "))}</dd><dt>Ontological</dt><dd>${escapeHtml(Object.values(identity.ontological).join(" · "))}</dd><dt>Epistemological</dt><dd>${escapeHtml(Object.values(identity.epistemological).join(" · "))}</dd><dt>Etymological</dt><dd>${escapeHtml(Object.values(identity.etymological).join(" · "))}</dd><dt>Semiotic</dt><dd>${escapeHtml(Object.values(identity.semiotic).join(" · "))}</dd><dt>Chronological</dt><dd>${escapeHtml(identity.chronological.as_of)} · revision ${identity.chronological.revision}</dd><dt>SemVer</dt><dd>${escapeHtml(identity.version)}</dd></dl></section>
<section class=\"panel\" id=\"traceability\"><h2>Traceability</h2><dl><dt>Author</dt><dd>${escapeHtml(trace.author.public_id)} · ${escapeHtml(trace.author.attribution)}</dd><dt>Harness</dt><dd>${escapeHtml(trace.ai_harness.name)} ${escapeHtml(trace.ai_harness.version)}</dd><dt>Model</dt><dd>${escapeHtml(trace.ai_llm.provider)} · ${escapeHtml(trace.ai_llm.model)}${trace.ai_llm.revision ? ` · ${escapeHtml(trace.ai_llm.revision)}` : ""}</dd><dt>Created</dt><dd>${escapeHtml(trace.created_at)}</dd><dt>Updated</dt><dd>${escapeHtml(trace.updated_at)}</dd><dt>SemVer</dt><dd>${escapeHtml(trace.semantic_version)}</dd><dt>Git client</dt><dd>${escapeHtml(trace.git.client_version)}</dd><dt>Git tracking</dt><dd>${escapeHtml(trace.git.tracking_state)} · ${escapeHtml(trace.git.repository_visibility)}</dd><dt>Repository</dt><dd class=\"mono\">${escapeHtml(trace.git.repository_uri || "undisclosed")}</dd><dt>Ref</dt><dd class=\"mono\">${escapeHtml(trace.git.ref_name || "undisclosed")}</dd><dt>Commit</dt><dd class=\"mono\">${escapeHtml(trace.git.commit_sha || "undisclosed")}</dd><dt>Tree</dt><dd class=\"mono\">${escapeHtml(trace.git.tree_sha || "undisclosed")}</dd></dl></section>
<section class=\"panel\" id=\"contexts\"><h2>Artifact world and target-project world</h2><ul>${contexts}</ul><h3>Human and agentic worlds</h3><ul>${worlds}</ul></section>
<section class=\"panel\" id=\"domains\"><h2>Domains and classifications</h2><ul>${domains}</ul><h3>Distribution classes</h3><ul>${classifications}</ul></section>
<section class=\"panel wide\" id=\"workflow\"><h2>Workflow and interdependencies</h2><figure class=\"workflow-figure\"><div class=\"workflow-scroll\" role=\"region\" aria-label=\"Scrollable workflow diagram\" tabindex=\"0\">${workflowSvg}</div><figcaption>Source-to-target relationships are authoritative. Geometry is schematic; node colour, glyph, and label encode state. Edge appearance mirrors model role and variant. Use the text register for exact metadata.</figcaption></figure><div class=\"diagram-key\"><h3>Diagram Key</h3><ul class=\"legend-list\">${statusKey || "<li>No states</li>"}${edgeKey || "<li>No edges</li>"}</ul></div><details class=\"register\"><summary>Text Register · ${model.topology.nodes.length} Nodes · ${model.topology.edges.length} Directed Edges</summary><h3>Nodes</h3>${nodes}<h3>Directed edges</h3><ul>${edges || "<li>None</li>"}</ul></details></section>
<section class=\"panel\" id=\"governance\"><h2>Nonbinding governance snapshot</h2><p>binding=false · portable=false · transferable=false · descriptive_only</p><p>${escapeHtml(model.governance.authority_snapshot.sanitized_scope)}</p><h3>Responsibilities</h3><ul>${responsibilities || "<li>None</li>"}</ul><h3>Constraints</h3><ul>${constraints || "<li>None</li>"}</ul></section>
<section class=\"panel\" id=\"criteria\"><h2>Criteria and risks</h2><h3>Criteria</h3><ul>${criteria}</ul><h3>Risks</h3><ul>${risks || "<li>None</li>"}</ul></section>
<section class=\"panel wide\" id=\"evidence\"><h2>Evidence &amp; References</h2><p>${model.references.length} sanitized public/URN references</p><details class=\"register\"><summary>Evidence Register · ${model.references.length} Items</summary>${evidence}</details></section>
<section class=\"panel\" id=\"lineage\"><h2>Child blueprint and lineage</h2><p>Generation depth ${model.child_derivation.generation_depth}/${model.child_derivation.max_generation_depth} · no authority transfer · automatic recursive spawn denied.</p><p>Capabilities: <span class=\"mono\">${escapeHtml(model.child_derivation.capability_ceiling.join(", ") || "none")}</span></p><p>Parent: <span class=\"mono\">${escapeHtml(model.child_derivation.parent_lineage.parent_artifact_id || "root")}</span></p></section>
<section class=\"panel\" id=\"materials\"><h2>Inert seed, DNA, template, instruction, prompt, directive, governance material</h2><ul>${materials || "<li>None recorded</li>"}</ul><details><summary>Machine capsule contract</summary><p>Exactly two base64url canonical-JSON blocks follow. They are inert data for an external reader; artifact content is nonbinding and has no browser effects.</p></details></section>
</div>${semanticBlock.html}${receiptBlock.html}</main></body></html>`;
  const htmlBytes = Buffer.from(html);
  if (htmlBytes.length > MAX_BYTES) throw new AppError("FILE_TOO_LARGE", "Portable sidecard exceeds the 2 MiB limit");
  return { htmlBytes, source, receipt, blocks: [semanticBlock.descriptor, receiptBlock.descriptor], derived, stem, csp };
}

function inspectSidecardBytes(bytes) {
  const html = bytes.toString("utf8");
  const style = html.match(/<style>([\s\S]*?)<\/style>/u)?.[1];
  if (style !== PORTABLE_CSS) throw new AppError("SIDECARD_PASSIVITY_FAILED", "Sidecard fixed style is missing or changed");
  const expectedCsp = `default-src 'none'; base-uri 'none'; connect-src 'none'; img-src data:; style-src 'sha256-${createHash("sha256").update(PORTABLE_CSS).digest("base64")}'; font-src 'none'; media-src 'none'; object-src 'none'; frame-src 'none'; worker-src 'none'; manifest-src 'none'; form-action 'none'`;
  const csp = html.match(/<meta http-equiv="Content-Security-Policy" content="([^"]+)">/u)?.[1]?.replaceAll("&amp;", "&").replaceAll("&#39;", "'");
  if (csp !== expectedCsp) throw new AppError("SIDECARD_CSP_INVALID", "Sidecard CSP is missing or changed");
  if (/<(?:a|form|iframe|object|embed|link|base|img|audio|video|source)\b/iu.test(html)
      || /\son[a-z]+\s*=/iu.test(html)
      || /(?:fetch\s*\(|XMLHttpRequest|sendBeacon|localStorage|sessionStorage|indexedDB|caches\.|serviceWorker|navigator\.clipboard|showOpenFilePicker|showSaveFilePicker|window\.open|document\.write|innerHTML|outerHTML|insertAdjacentHTML|eval\s*\(|new Function|url\s*\()/iu.test(html)) {
    throw new AppError("SIDECARD_PASSIVITY_FAILED", "Sidecard contains a forbidden active surface");
  }
  const blocks = [...html.matchAll(/<script id="([^"]+)" type="([^"]+)" data-encoding="base64url" data-media-type="application\/json" data-canonicalization="rfc8785-jcs" data-bytes="([0-9]+)" data-sha256="([a-f0-9]{64})">([A-Za-z0-9_-]+)<\/script>/gu)];
  if (blocks.length !== 2 || (html.match(/<script\b/gu) || []).length !== 2) throw new AppError("CAPSULE_BLOCK_SET_INVALID", "Sidecard requires exactly two inert capsule blocks");
  const expected = [["vasm-semantic-source", "application/vnd.maos.agentic-session+base64url"], ["vasm-render-receipt", "application/vnd.maos.render-receipt+base64url"]];
  const decoded = {};
  blocks.forEach((match, index) => {
    if (match[1] !== expected[index][0] || match[2] !== expected[index][1]) throw new AppError("CAPSULE_BLOCK_SET_INVALID", "Capsule identity or media type differs");
    if (match[5].includes("=") || !/^[A-Za-z0-9_-]+$/u.test(match[5])) throw new AppError("CAPSULE_ENCODING_INVALID", "Capsule is not unpadded base64url");
    const value = Buffer.from(match[5], "base64url");
    if (value.length > MAX_BYTES || value.toString("base64url") !== match[5] || value.length !== Number(match[3]) || sha256(value) !== match[4]) throw new AppError("CAPSULE_DIGEST_MISMATCH", "Capsule encoding, size, or digest differs");
    let parsed;
    try { parsed = JSON.parse(value.toString("utf8")); } catch { throw new AppError("CAPSULE_JSON_INVALID", "Capsule JSON is invalid"); }
    if (!value.equals(canonicalBytes(parsed))) throw new AppError("CAPSULE_CANONICALIZATION_INVALID", "Capsule JSON is not canonical");
    decoded[match[1]] = { value: parsed, bytes: value, sha256: match[4] };
  });
  validateModel(decoded["vasm-semantic-source"].value);
  enforceSensitivePreflight(canonicalBytes(decoded["vasm-semantic-source"].value));
  validatePortableDistribution(decoded["vasm-semantic-source"].value);
  const receipt = decoded["vasm-render-receipt"].value;
  const receiptKeys = ["capability_profile", "generated_at", "generator", "identity_sha256", "identity_stem", "kind", "run_id", "schema_sha256", "schema_version", "source_bytes", "source_sha256", "template_sha256"];
  const receiptShapeValid = deepEqual(Object.keys(receipt).sort(), receiptKeys)
    && receipt.schema_version === "1.0.0"
    && receipt.kind === "agentic_session_render_receipt"
    && deepEqual(Object.keys(receipt.generator || {}).sort(), ["name", "runtime", "version"])
    && receipt.generator.name === TOOL
    && receipt.generator.version === VERSION
    && /^node v[0-9]+\.[0-9]+\.[0-9]+/u.test(receipt.generator.runtime)
    && deepEqual(Object.keys(receipt.capability_profile || {}).sort(), ["browser_effects", "external_tool_required", "mode"])
    && receipt.capability_profile.mode === "passive_snapshot"
    && receipt.capability_profile.browser_effects === "none"
    && receipt.capability_profile.external_tool_required === true
    && validRfc3339(receipt.generated_at)
    && /^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/u.test(receipt.run_id);
  if (!receiptShapeValid
      || receipt.source_sha256 !== decoded["vasm-semantic-source"].sha256
      || receipt.source_bytes !== decoded["vasm-semantic-source"].bytes.length
      || receipt.identity_sha256 !== identityDigest(decoded["vasm-semantic-source"].value)
      || !portableStemMatches(decoded["vasm-semantic-source"].value, receipt.identity_stem)
      || receipt.schema_sha256 !== sha256(fs.readFileSync(MODEL_SCHEMA))
      || receipt.template_sha256 !== sha256(Buffer.from(`portable-sidecard-template-v2\\n${PORTABLE_CSS}`))) {
    throw new AppError("CAPSULE_RECEIPT_MISMATCH", "Render receipt shape or binding differs");
  }
  const reconstructed = renderPortableSidecard(decoded["vasm-semantic-source"].value, receipt.identity_stem);
  if (!bytes.equals(reconstructed.htmlBytes)) throw new AppError("SIDECARD_OUTER_MISMATCH", "Outer sidecard bytes differ from the deterministic semantic projection");
  return { model: decoded["vasm-semantic-source"].value, receipt, blocks: blocks.map((match) => match[1]), trust: "CONSISTENT_UNTRUSTED" };
}

function compact(value, max = 44) {
  const text = String(value).replace(/\s+/gu, " ").trim();
  return text.length <= max ? text : `${text.slice(0, Math.max(1, max - 1))}…`;
}

const WORKFLOW_COLUMN_CENTERS = [88, 220, 300, 430, 500, 625];
const FULLWIDTH = /[\u1100-\u115f\u2e80-\ua4cf\uac00-\ud7a3\uf900-\ufaff\ufe10-\ufe6f\uff00-\uff60\uffe0-\uffe6\u{1F000}-\u{1FAFF}\u{20000}-\u{3FFFD}]/u;

function displayUnits(value) {
  let units = 0;
  for (const character of String(value)) units += FULLWIDTH.test(character) ? 2 : 1;
  return units;
}

function truncateToUnits(value, maximum) {
  const text = String(value).replace(/\s+/gu, " ").trim();
  if (displayUnits(text) <= maximum) return text;
  let output = "";
  let used = 0;
  for (const character of text) {
    const width = FULLWIDTH.test(character) ? 2 : 1;
    if (used + width + 1 > maximum) break;
    output += character;
    used += width;
  }
  return `${output}…`;
}

function projectNode(node, nodes, edges) {
  const sublabel = node.owner_actor_ref ?? node.description ?? node.id;
  const center = WORKFLOW_COLUMN_CENTERS[node.column];
  const spacingCap = Math.min(...nodes
    .filter((candidate) => candidate !== node && candidate.lane === node.lane)
    .map((candidate) => {
      const connected = edges.some((edge) =>
        (edge.from === node.id && edge.to === candidate.id)
        || (edge.from === candidate.id && edge.to === node.id));
      const distance = Math.abs(center - WORKFLOW_COLUMN_CENTERS[candidate.column]);
      return Math.max(62, Math.min(120, distance - (connected ? 28 : 8)));
    }));
  const effectiveSpacingCap = Number.isFinite(spacingCap) ? spacingCap : 120;
  const boundaryCap = node.column === 0 ? 92 : node.column === 5 ? 90 : 120;
  const desired = Math.max(62, Math.min(120, Math.ceil(Math.max(
    displayUnits(node.label) * 6.8,
    displayUnits(sublabel) * 4.8
  ) + 12)));
  const width = Math.min(desired, effectiveSpacingCap, boundaryCap);
  const labelUnits = Math.max(1, Math.floor((width - 6) / 6.8));
  const sublabelUnits = Math.max(1, Math.floor((width - 8) / 4.8));
  return {
    id: node.id,
    lane: node.lane,
    col: node.column,
    type: node.component_kind,
    label: truncateToUnits(node.label, labelUnits),
    sublabel: truncateToUnits(sublabel, sublabelUnits),
    tag: node.status,
    width
  };
}

function splitWorkflowCards(cards) {
  return cards.flatMap((card) => {
    if (card.items.length <= 12) return [card];
    const total = Math.ceil(card.items.length / 12);
    return Array.from({ length: total }, (_, index) => ({
      ...card,
      title: `${card.title} · ${index + 1}/${total}`,
      items: card.items.slice(index * 12, (index + 1) * 12)
    }));
  });
}

function itemText(item) {
  return item.text ?? item.title ?? item.label;
}

function statusLine(item) {
  const state = lifecycleState(item);
  const reason = item.lifecycle_state?.reason ?? item.reason;
  return `${item.id}: ${itemText(item)} [${state}]${reason ? ` — ${reason}` : ""}`;
}

function listOrNone(items) {
  return items.length ? items : ["None recorded"];
}

function workflowCards(model, derived) {
  const dependencyItems = [
    ...model.topology.edges.map((edge) => `${edge.from} -> ${edge.to}${edge.label ? ` (${edge.label})` : ""}`),
    ...[...model.plan.waves, ...model.plan.work_items].flatMap((item) => item.dependencies.map((dependency) => `${dependency} -> ${item.id}`))
  ];
  return splitWorkflowCards([
    { dot: "cyan", title: "Derived Facts", items: [
      `Readiness: ${derived.readiness}`,
      `Critical path head: ${derived.critical_path_head ?? "none"}`,
      ...derived.status_counts.map(({ status, count }) => `${status}: ${count}`)
    ] },
    { dot: "emerald", title: "Intent Status", items: [
      ...model.intent.definition_of_ready.map((item) => `ready/${statusLine(item)}`),
      ...model.intent.definition_of_done.map((item) => `dod/${statusLine(item)}`),
      ...Object.entries(model.intent.objectives).flatMap(([tier, items]) => items.map((item) => `${tier}/${statusLine(item)}`))
    ] },
    { dot: "violet", title: "Topology Nodes", items: model.topology.nodes.map(statusLine) },
    { dot: "slate", title: "Dependencies", items: listOrNone(dependencyItems) },
    { dot: "amber", title: "Authority Constraints", items: listOrNone(model.governance.authority_constraints.map(statusLine)) },
    { dot: "cyan", title: "Responsibilities", items: listOrNone(model.governance.responsibilities.map((item) => `${item.subject_ref}: ${item.role} — ${item.actor_ref}${item.detail ? ` (${item.detail})` : ""}`)) },
    { dot: "emerald", title: "Acceptance Criteria", items: model.governance.acceptance_criteria.map(statusLine) },
    { dot: "orange", title: "Gaps and Failures", items: listOrNone([...model.analysis.gaps, ...model.analysis.failures].map(statusLine)) },
    { dot: "rose", title: "Risks", items: listOrNone(model.analysis.risks.map((item) => `${statusLine(item)}; likelihood=${item.likelihood}; impact=${item.impact}; blocking=${item.blocking}`)) },
    { dot: "cyan", title: "Plan", items: listOrNone([
      `Next: ${model.plan.next_action.what} — ${model.plan.next_action.who}`,
      ...model.plan.waves.map(statusLine),
      ...model.plan.work_items.map(statusLine)
    ]) }
  ]);
}

function projectWorkflow(model, derived, outputName) {
  const nodeById = new Map(model.topology.nodes.map((node) => [node.id, node]));
  const criticalPath = model.topology.critical_path || [];
  const renderableMainPath = criticalPath.length >= 2
    && criticalPath.every((id, index) => index === 0
      || nodeById.get(id).column >= nodeById.get(criticalPath[index - 1]).column);
  const workflow = {
    schema_version: 1,
    diagram_type: "workflow",
    meta: {
      title: model.metadata.title,
      subtitle: `${model.metadata.scope} · ${derived.readiness}`,
      output: outputName,
      animation: "none"
    },
    lanes: model.topology.lanes.map((lane) => ({
      id: lane.id,
      label: lane.label,
      ...(lane.variant ? { variant: lane.variant } : {})
    })),
    ...(model.topology.phases ? { phases: model.topology.phases.map((phase) => ({
      id: phase.id,
      label: phase.label,
      fromCol: phase.from_column,
      toCol: phase.to_column,
      ...(phase.variant ? { variant: phase.variant } : {})
    })) } : {}),
    ...(model.topology.groups ? { groups: model.topology.groups.map((group) => {
      const leftBoundaryOccupied = model.topology.nodes.some((node) =>
        node.lane === group.lane && node.column === group.from_column);
      return {
        id: group.id,
        label: group.label,
        lane: group.lane,
        fromCol: leftBoundaryOccupied && group.from_column > 0 ? group.from_column - 1 : group.from_column,
        toCol: group.to_column,
        ...(group.variant ? { variant: group.variant } : {})
      };
    }) } : {}),
    ...(renderableMainPath ? { mainPath: criticalPath } : {}),
    nodes: model.topology.nodes.map((node) => projectNode(node, model.topology.nodes, model.topology.edges)),
    edges: model.topology.edges.map((edge) => {
      const crossLane = nodeById.get(edge.from)?.lane !== nodeById.get(edge.to)?.lane;
      const routing = edge.role === "return"
        ? { fromSide: "top", toSide: "top", route: "up-channel" }
        : crossLane
          ? { fromSide: "bottom", toSide: "top", route: "drop" }
          : {};
      return {
        from: edge.from,
        to: edge.to,
        ...(edge.label ? { label: edge.label } : {}),
        ...(edge.variant ? { variant: edge.variant } : {}),
        ...(edge.role ? { role: edge.role } : {}),
        ...routing,
        ...(edge.route ? { route: edge.route } : {}),
        ...(edge.from_side ? { fromSide: edge.from_side } : {}),
        ...(edge.to_side ? { toSide: edge.to_side } : {}),
        ...(edge.channel_y !== undefined ? { channelY: edge.channel_y } : {}),
        ...(edge.label_dx !== undefined ? { labelDx: edge.label_dx } : {}),
        ...(edge.label_dy !== undefined ? { labelDy: edge.label_dy } : {}),
        ...(edge.label_segment !== undefined ? { labelSegment: edge.label_segment } : {}),
        ...(edge.bias !== undefined ? { bias: edge.bias } : {})
      };
    }),
    cards: workflowCards(model, derived)
  };
  return workflow;
}

function mdInline(value) {
  const specials = new Set(["\\", "`", "*", "_", "[", "]", "{", "}", "<", ">", "#", "+", ".", "!", "|", "(", ")", "-"]);
  return [...String(value)].map((character) => specials.has(character) ? `\\${character}` : character).join("");
}

function statusTable(items, name = "Item") {
  const rows = [`| ID | ${name} | Status | Reason | Evidence |`, "|---|---|---|---|---|"];
  if (!items.length) rows.push("| — | None recorded | — | — | — |");
  else items.forEach((item) => {
    const state = lifecycleState(item);
    const reason = item.lifecycle_state?.reason ?? item.reason;
    const evidence = item.lifecycle_state?.evidence_refs ?? item.evidence_refs;
    rows.push(`| ${mdInline(item.id)} | ${mdInline(itemText(item))} | ${mdInline(state)} | ${mdInline(reason ?? "—")} | ${mdInline(evidence.join(", ") || "—")} |`);
  });
  return rows.join("\n");
}

function renderMarkdown(model, derived) {
  const lines = [];
  const add = (...items) => lines.push(...items);
  const objectives = Object.entries(model.intent.objectives)
    .flatMap(([tier, items]) => items.map((item) => ({ ...item, title: `${tier}: ${item.title}` })));
  const dependencyLines = [
    ...model.topology.edges.map((edge) => `- \`${edge.from}\` → \`${edge.to}\`${edge.label ? ` — ${mdInline(edge.label)}` : ""}`),
    ...[...model.plan.waves, ...model.plan.work_items]
      .flatMap((item) => item.dependencies.map((dependency) => `- \`${dependency}\` → \`${item.id}\``))
  ];
  const responsibilities = model.governance.responsibilities.length
    ? model.governance.responsibilities.map((item) => `| ${item.id} | ${item.subject_ref} | ${item.role} | ${mdInline(item.actor_ref)} | ${mdInline(item.detail ?? "—")} |`)
    : ["| — | — | — | None recorded | — |"];
  const risks = model.analysis.risks.length
    ? model.analysis.risks.map((item) => `| ${item.id} | ${mdInline(item.title)} | ${item.status} | ${item.likelihood} | ${item.impact} | ${item.blocking ? "yes" : "no"} | ${mdInline(item.mitigation ?? "—")} |`)
    : ["| — | None recorded | — | — | — | — | — |"];
  const next = model.plan.next_action;

  add(
    `# ${mdInline(model.metadata.title)}`, "",
    `- **Artifact:** \`${artifactId(model)}\``,
    `- **Scope:** ${mdInline(model.metadata.scope)}`,
    `- **Readiness:** **${derived.readiness}**`,
    `- **Critical-path head:** ${derived.critical_path_head ? `\`${derived.critical_path_head}\`` : "none"}`,
    `- **Status counts:** ${derived.status_counts.map(({ status, count }) => `${status}=${count}`).join(" · ")}`,
    "", "## Intent", "",
    `**Goal:** ${mdInline(model.intent.goal)}`,
    "", "### Motivations", "",
    ...model.intent.motivations.map((item) => `- ${mdInline(item)}`),
    "", "### Definition of Ready", "", statusTable(model.intent.definition_of_ready, "Criterion"),
    "", "### Definition of Done", "", statusTable(model.intent.definition_of_done, "Criterion"),
    "", "### Objectives", "", statusTable(objectives, "Objective"),
    "", "## Topology", "",
    statusTable(model.topology.nodes.map((item) => ({
      ...item,
      title: `${item.label} · lane=${item.lane} · column=${item.column} · kind=${item.component_kind}`
    })), "Node"),
    "", "### Dependencies", "", ...(dependencyLines.length ? dependencyLines : ["- None recorded"]),
    "", "## Governance", "",
    "### Responsibilities", "",
    "| ID | Subject | Role | Actor | Detail |", "|---|---|---|---|---|", ...responsibilities,
    "", "### Authority Constraints", "", statusTable(model.governance.authority_constraints, "Constraint"),
    "", "### Acceptance Criteria", "", statusTable(model.governance.acceptance_criteria, "Criterion"),
    "", "## Analysis", "",
    "### Root Causes", "",
    ...(model.analysis.root_causes.length
      ? model.analysis.root_causes.map((item) => `- **${mdInline(item.problem)}** — ${mdInline(item.root_cause)} \\(chain: ${item.why_chain.map(mdInline).join(" → ")}\\)`)
      : ["- None recorded"]),
    "", "### Gaps", "", statusTable(model.analysis.gaps, "Gap"),
    "", "### Failures", "", statusTable(model.analysis.failures, "Failure"),
    "", "### Risks", "",
    "| ID | Risk | Status | Likelihood | Impact | Blocking | Mitigation |",
    "|---|---|---|---|---|---|---|", ...risks,
    "", "## Plan", "",
    "### Next Action", "",
    `- **What:** ${mdInline(next.what)}`,
    `- **Why:** ${mdInline(next.why)}`,
    `- **Where:** ${mdInline(next.where)}`,
    `- **When:** ${mdInline(next.when)}`,
    `- **Who:** ${mdInline(next.who)}`,
    `- **How:** ${mdInline(next.how)}`,
    ...(next.cost ? [`- **Cost:** ${mdInline(next.cost)}`] : []),
    "", "### Waves", "", statusTable(model.plan.waves, "Wave"),
    "", "### Work Items", "", statusTable(model.plan.work_items, "Work item"),
    "", "## References", "",
    ...model.references.map((reference) => `- \`${reference.id}\` \\[${reference.role}\\] — ${mdInline(reference.uri)} \\(sha256:${reference.digest.value}\\)`)
  );
  return `${lines.join("\n")}\n`;
}

function standardSections(model, workflow) {
  const titles = (base) => workflow.cards.map((card) => card.title).filter((title) => title === base || title.startsWith(`${base} · `));
  const section = (id, pointer, heading, htmlTokens, workflowTokens = []) => ({
    id, source_pointer: pointer,
    projections: [
      { role: "workflow", locator: `workflow:${id}`, visible_tokens: workflowTokens },
      { role: "diagram_html", locator: `visible:${id}`, visible_tokens: htmlTokens },
      { role: "markdown", locator: heading, visible_tokens: [heading] }
    ]
  });
  return [
    section("intent", "/intent", "## Intent", [...titles("Derived Facts"), ...titles("Intent Status")]),
    section("topology", "/topology", "## Topology", [...titles("Topology Nodes"), ...titles("Dependencies")], model.topology.nodes.map((node) => node.id)),
    section("governance", "/governance", "## Governance", [...titles("Authority Constraints"), ...titles("Responsibilities"), ...titles("Acceptance Criteria")]),
    section("analysis", "/analysis", "## Analysis", [...titles("Gaps and Failures"), ...titles("Risks")]),
    section("plan", "/plan", "## Plan", titles("Plan"))
  ];
}

function portableSections() {
  return [
    ["plan", "/plan", "#next", "Current Disposition"],
    ["identity", "/identity", "#identity", "Identity — eight facets"],
    ["traceability", "/traceability", "#traceability", "Traceability"],
    ["organization", "/organization", "#contexts", "Artifact world and target-project world"],
    ["topology", "/topology", "#workflow", "Workflow and interdependencies"],
    ["governance", "/governance", "#governance", "Nonbinding governance snapshot"],
    ["analysis", "/analysis", "#criteria", "Criteria and risks"],
    ["references", "/references", "#evidence", "Evidence & References"],
    ["child_derivation", "/child_derivation", "#lineage", "Child blueprint and lineage"],
    ["inert_material", "/inert_material", "#materials", "Inert seed, DNA, template, instruction, prompt, directive, governance material"]
  ].map(([id, source_pointer, locator, token]) => ({
    id, source_pointer,
    projections: [{ role: "sidecard_html", locator, visible_tokens: [token] }]
  }));
}

function visibleHtmlTextForSidecard(html) {
  return decodeHtmlEntities(html
    .replace(/<!--[\s\S]*?-->/gu, " ")
    .replace(/<script\b[^>]*>[\s\S]*?<\/script>/giu, " ")
    .replace(/<style\b[^>]*>[\s\S]*?<\/style>/giu, " ")
    .replace(/<[^>]+>/gu, " "))
    .replace(/\s+/gu, " ")
    .trim();
}

function resolvePointer(value, pointer) {
  return pointer.split("/").slice(1).reduce((current, segment) => current?.[segment.replaceAll("~1", "/").replaceAll("~0", "~")], value);
}

function decodeHtmlEntities(value) {
  const named = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", bull: "•", nbsp: " " };
  return value.replace(/&(#x[0-9a-f]+|#\d+|[a-z]+);/giu, (whole, entity) => {
    if (entity.startsWith("#x")) return String.fromCodePoint(Number.parseInt(entity.slice(2), 16));
    if (entity.startsWith("#")) return String.fromCodePoint(Number.parseInt(entity.slice(1), 10));
    return named[entity.toLowerCase()] ?? whole;
  });
}

function visibleHtmlBuckets(html) {
  const hiddenClasses = new Set();
  for (const style of html.matchAll(/<style\b[^>]*>([\s\S]*?)<\/style>/giu)) {
    for (const rule of style[1].matchAll(/([^{}]+)\{([^{}]*)\}/gu)) {
      if (!/(?:display\s*:\s*none|visibility\s*:\s*hidden|opacity\s*:\s*0(?:\D|$))/iu.test(rule[2])) continue;
      for (const selectorClass of rule[1].matchAll(/\.([A-Za-z_][A-Za-z0-9_-]*)/gu)) {
        hiddenClasses.add(selectorClass[1]);
      }
    }
  }
  let cleaned = html
    .replace(/<!--[\s\S]*?-->/gu, " ")
    .replace(/<(script|style)\b[^>]*>[\s\S]*?<\/\1>/giu, " ")
    .replace(/<([a-z][\w:-]*)\b[^>]*(?:\shidden(?:\s|=|>)|\saria-hidden\s*=\s*["']?true|\sdisplay\s*=\s*["']?none|\svisibility\s*=\s*["']?hidden|\sopacity\s*=\s*["']?0(?:["'\s>])|style\s*=\s*["'][^"']*(?:display\s*:\s*none|visibility\s*:\s*hidden|opacity\s*:\s*0(?:\D|$)))[^>]*>[\s\S]*?<\/\1>/giu, " ");
  for (const className of hiddenClasses) {
    const escaped = className.replace(/[.*+?^${}()|[\]\\]/gu, "\\$&");
    cleaned = cleaned.replace(
      new RegExp(`<([a-z][\\w:-]*)\\b[^>]*class=["'][^"']*\\b${escaped}\\b[^"']*["'][^>]*>[\\s\\S]*?<\\/\\1>`, "giu"),
      " "
    );
  }
  const text = (fragment) => decodeHtmlEntities(fragment.replace(/<[^>]+>/gu, " ")).replace(/\s+/gu, " ").trim();
  const collect = (source, pattern) => [...source.matchAll(pattern)].map((match) => text(match[1])).filter(Boolean);
  const svg = cleaned.match(/<svg\b[^>]*>([\s\S]*?)<\/svg>/iu)?.[1] || "";
  return {
    header: [
      ...collect(cleaned, /<h1\b[^>]*>([\s\S]*?)<\/h1>/giu),
      ...collect(cleaned, /<p\b[^>]*class=["'][^"']*\bsubtitle\b[^"']*["'][^>]*>([\s\S]*?)<\/p>/giu)
    ],
    svg: collect(svg, /<text\b[^>]*>([\s\S]*?)<\/text>/giu),
    cards: [
      ...collect(cleaned, /<h3\b[^>]*>([\s\S]*?)<\/h3>/giu),
      ...collect(cleaned, /<li\b[^>]*>([\s\S]*?)<\/li>/giu).map((value) => value.replace(/^•\s*/u, ""))
    ]
  };
}

function expectedWorkflowBuckets(workflow) {
  return {
    header: [workflow.meta.title, workflow.meta.subtitle].filter(Boolean),
    svg: [
      ...workflow.lanes.map((lane, index) => `${String(index + 1).padStart(2, "0")} / ${lane.label}`),
      ...(workflow.phases || []).map((phase) => phase.label),
      ...(workflow.groups || []).map((group) => group.label),
      ...workflow.nodes.flatMap((node) => [node.label, node.sublabel, node.tag]),
      ...workflow.edges.map((edge) => edge.label).filter(Boolean),
      "Legend", "User UI", "Agent logic", "Policy", "Tool action", "Context / trace"
    ].filter(Boolean),
    cards: workflow.cards.flatMap((card) => [card.title, ...card.items]).filter(Boolean)
  };
}

function missingVisibleTokens(actual, expected) {
  const missing = [];
  for (const bucket of ["header", "svg", "cards"]) {
    const counts = new Map();
    for (const token of actual[bucket]) counts.set(token, (counts.get(token) || 0) + 1);
    for (const token of expected[bucket]) {
      const remaining = counts.get(token) || 0;
      if (remaining === 0) missing.push({ bucket, reason: "missing visible occurrence" });
      else counts.set(token, remaining - 1);
    }
  }
  return missing;
}

function visibleTokenDifferences(actual, expected) {
  const differences = [];
  for (const bucket of ["header", "svg", "cards"]) {
    const available = [...actual[bucket]];
    for (const token of expected[bucket]) {
      const index = available.indexOf(token);
      if (index < 0) differences.push({ bucket, reason: "missing exact visible occurrence" });
      else available.splice(index, 1);
    }
  }
  return differences;
}

function manifestSemanticErrors(manifest) {
  const errors = [];
  const roles = manifest.subjects.map((subject) => subject.role);
  const paths = manifest.subjects.map((subject) => subject.path);
  if (new Set(roles).size !== roles.length) errors.push({ path: "/subjects", code: "DUPLICATE_SUBJECT_ROLE", message: "subject roles must be unique" });
  if (new Set(paths).size !== paths.length) errors.push({ path: "/subjects", code: "DUPLICATE_SUBJECT_PATH", message: "subject paths must be unique" });
  manifest.subjects.forEach((subject, index) => {
    if (ROLE_MEDIA[subject.role] !== subject.media_type) errors.push({ path: `/subjects/${index}/media_type`, code: "SUBJECT_MEDIA_MISMATCH", message: `${subject.role} requires ${ROLE_MEDIA[subject.role]}` });
    if (subject.path !== path.basename(subject.path) || subject.path === "." || subject.path === ".." || subject.path.includes("/") || subject.path.includes("\\")) errors.push({ path: `/subjects/${index}/path`, code: "SUBJECT_PATH_REJECTED", message: "subject paths must be bundle-local basenames" });
  });
  const requiredRoles = manifest.profile === "standard"
    ? ["source", "workflow", "diagram_html", "markdown"]
    : ["source", "sidecard_html"];
  if (!deepEqual([...roles].sort(), [...requiredRoles].sort())) errors.push({ path: "/subjects", code: "SUBJECT_ROLE_SET_INVALID", message: `profile ${manifest.profile} requires its canonical subject roles` });
  if (manifest.status === "VALIDATED") {
    if (manifest.checks.some((check) => check.status !== "PASS")) errors.push({ path: "/checks", code: "VALIDATED_CHECK_FAILED", message: "VALIDATED manifest cannot contain a failed check" });
    if (!deepEqual(manifest.checks.map((check) => check.name), CHECKS_BY_PROFILE[manifest.profile])) errors.push({ path: "/checks", code: "CHECK_SET_INVALID", message: "manifest check set differs from profile contract" });
  }
  if (manifest.profile === "standard" && manifest.embedded_blocks.length !== 0) errors.push({ path: "/embedded_blocks", code: "BLOCK_SET_INVALID", message: "standard profile has no embedded blocks" });
  if (manifest.profile === "portable_sidecard") {
    const blockPairs = manifest.embedded_blocks.map((block) => `${block.id}:${block.role}`);
    if (!deepEqual(blockPairs, ["vasm-semantic-source:semantic_source", "vasm-render-receipt:render_receipt"])) errors.push({ path: "/embedded_blocks", code: "BLOCK_SET_INVALID", message: "portable profile requires the canonical two blocks" });
  }
  if (!deepEqual(manifest.derived.status_counts.map((entry) => entry.status), STATUS_VALUES)) errors.push({ path: "/derived/status_counts", code: "STATUS_COUNTS_ORDER", message: "status counts must contain the canonical eleven states in order" });
  return errors;
}

function generatorIdentity() {
  return { name: TOOL, version: VERSION, runtime: `node ${process.version}` };
}

function bundleSubject(file, role, mediaType, bytes) {
  return {
    role,
    path: path.basename(file),
    media_type: mediaType,
    digest: digest(bytes)
  };
}

async function atomicWrite(file, bytes) {
  const temporary = path.join(path.dirname(file), `.${path.basename(file)}.${randomUUID()}.tmp`);
  let handle;
  try {
    handle = await open(temporary, "wx", 0o600);
    await handle.writeFile(bytes);
    await handle.sync();
    await handle.close();
    handle = undefined;
    await rename(temporary, file);
  } catch (error) {
    if (handle) await handle.close().catch(() => {});
    await unlink(temporary).catch(() => {});
    throw error;
  }
}

async function acquireLock(file) {
  const owner_token = randomUUID();
  let handle;
  try {
    handle = await open(file, "wx", 0o600);
    await handle.writeFile(`${JSON.stringify({ pid: process.pid, owner_token, created_at: new Date().toISOString() })}\n`);
    await handle.sync();
  } catch (error) {
    if (handle) await handle.close().catch(() => {});
    if (handle) await unlink(file).catch(() => {});
    if (error.code === "EEXIST") {
      throw new AppError("LOCK_HELD", "Bundle lock is held or requires manual recovery", 1, {
        lock: file,
        recovery: "Confirm that no writer owns the lock, then remove it manually"
      });
    }
    throw new AppError("LOCK_FAILED", `Cannot acquire bundle lock ${file}: ${error.code || "unavailable"}`);
  }
  return async () => {
    await handle.close().catch(() => {});
    try {
      const current = JSON.parse((await readBounded(file, "bundle lock")).toString("utf8"));
      if (current.owner_token === owner_token) await unlink(file);
    } catch {
      // Fail closed: a missing, malformed, stale, or replaced lock is never
      // unlinked by a process that can no longer prove ownership.
    }
  };
}

function compareVersion(actual, minimum) {
  const left = actual.split(".").map(Number);
  const right = minimum.split(".").map(Number);
  for (let index = 0; index < Math.max(left.length, right.length); index += 1) {
    const difference = (left[index] || 0) - (right[index] || 0);
    if (difference !== 0) return difference;
  }
  return 0;
}

function canonicalStandardArchifyRoots() {
  const roots = [];
  const home = os.userInfo().homedir;
  for (const candidate of [
    path.join(home, ".agents", "skills", "archify"),
    path.join(home, ".claude", "skills", "archify")
  ]) {
    try {
      const canonical = fs.realpathSync(candidate);
      if (!roots.includes(canonical)) roots.push(canonical);
    } catch {
      // Missing standard locations are reported together by detectArchify.
    }
  }
  return roots;
}

function detectArchify(explicit) {
  const trustedRoots = canonicalStandardArchifyRoots();
  let roots = trustedRoots;
  if (explicit) {
    let requested;
    try {
      requested = fs.realpathSync(path.resolve(explicit));
    } catch {
      throw new AppError("DEPENDENCY_UNAVAILABLE", "The explicit Archify path is unavailable", 2);
    }
    if (!trustedRoots.includes(requested)) {
      throw new AppError("DEPENDENCY_UNAVAILABLE", "The explicit Archify path is not a canonical standard user-scope installation", 2, { trusted_roots: trustedRoots });
    }
    roots = [requested];
  }
  const uid = typeof process.getuid === "function" ? process.getuid() : undefined;
  const rejected = [];
  for (const root of roots) {
    const cli = path.join(root, "bin", "archify.mjs");
    const workflowSchema = path.join(root, "schemas", "workflow.schema.json");
    const commonSchema = path.join(root, "schemas", "common.schema.json");
    const skill = path.join(root, "SKILL.md");
    try {
      const rootStat = fs.statSync(root);
      if (!rootStat.isDirectory() || (uid !== undefined && rootStat.uid !== uid)) throw new Error("root ownership/type");
      for (const file of [cli, workflowSchema, commonSchema, skill]) {
        const metadata = fs.lstatSync(file);
        if (!metadata.isFile() || metadata.isSymbolicLink() || (uid !== undefined && metadata.uid !== uid)) throw new Error(`untrusted file ${path.basename(file)}`);
      }
      const definition = fs.readFileSync(skill, "utf8");
      const name = definition.match(/^name:\s*([a-z0-9-]+)\s*$/mu)?.[1];
      const version = definition.match(/^\s*version:\s*["']?([0-9]+(?:\.[0-9]+)+)/mu)?.[1];
      if (name !== "archify" || !version || compareVersion(version, "2.11") < 0) throw new Error("identity/version");
      return { root, cli, workflowSchema, version };
    } catch (error) {
      rejected.push({ root, reason: error.message });
    }
  }
  throw new AppError("DEPENDENCY_UNAVAILABLE", "No trusted Archify v2.11 or newer installation is available", 2, { trusted_roots: trustedRoots, rejected });
}

function runArchify(archify, args, code) {
  const result = spawnSync(process.execPath, [archify.cli, ...args], {
    cwd: archify.root,
    encoding: "utf8",
    maxBuffer: MAX_BYTES,
    timeout: ARCHIFY_TIMEOUT_MS,
    killSignal: "SIGKILL"
  });
  if (result.error?.code === "ETIMEDOUT") {
    throw new AppError("ARCHIFY_TIMEOUT", `Archify ${args[0]} exceeded the 30 second limit`);
  }
  if (result.error || result.status !== 0) {
    throw new AppError(code, `Archify ${args[0]} failed`, 1, {
      status: result.status,
      stderr: compact(result.stderr || result.error?.code || "no diagnostic", 2000)
    });
  }
  return result.stdout;
}

function parseArguments(argv) {
  const [command, ...rest] = argv;
  if (!command || ["-h", "--help", "help"].includes(command)) return { command: "help" };
  const commands = ["validate", "render", "verify", "inspect", "next", "transition", "derive-child"];
  if (!commands.includes(command)) throw new AppError("USAGE", `Unknown subcommand: ${command}`, 2, { usage: usage() });
  const positionals = [];
  const options = {};
  const valueOptions = new Set(["--out", "--archify-dir", "--profile", "--event", "--expected-digest", "--request"]);
  for (let index = 0; index < rest.length; index += 1) {
    const arg = rest[index];
    if (valueOptions.has(arg)) {
      const key = arg.slice(2);
      if (options[key] !== undefined) throw new AppError("USAGE", `Option supplied more than once: ${arg}`, 2, { usage: usage() });
      const value = rest[index + 1];
      if (!value || value.startsWith("--")) throw new AppError("USAGE", `${arg} requires a value`, 2, { usage: usage() });
      options[key] = value;
      index += 1;
    } else if (arg.startsWith("--")) throw new AppError("USAGE", `Unknown option: ${arg}`, 2, { usage: usage() });
    else positionals.push(arg);
  }
  if (positionals.length !== 1) throw new AppError("USAGE", `${command} requires exactly one input path`, 2, { usage: usage() });
  if (command === "render") {
    if (!options.out || !["standard", "portable-sidecard"].includes(options.profile)) throw new AppError("USAGE", "render requires --profile standard|portable-sidecard and --out <dir>", 2, { usage: usage() });
    if (options.profile === "portable-sidecard" && options["archify-dir"]) throw new AppError("USAGE", "portable-sidecard does not accept --archify-dir", 2, { usage: usage() });
  }
  if (["transition", "derive-child"].includes(command)) {
    const requestKey = command === "transition" ? "event" : "request";
    if (!options[requestKey] || !options["expected-digest"] || !options.out) throw new AppError("USAGE", `${command} requires --${requestKey}, --expected-digest, and --out`, 2, { usage: usage() });
  }
  const allowedByCommand = {
    validate: [], next: [], inspect: [], verify: ["archify-dir"],
    render: ["out", "profile", "archify-dir"],
    transition: ["event", "expected-digest", "out"],
    "derive-child": ["request", "expected-digest", "out"]
  };
  for (const key of Object.keys(options)) if (!allowedByCommand[command].includes(key)) throw new AppError("USAGE", `--${key} is not valid for ${command}`, 2, { usage: usage() });
  return { command, input: path.resolve(positionals[0]), options };
}

async function ensureOwnedDirectory(directory) {
  await mkdir(directory, { recursive: true });
  const metadata = await lstat(directory);
  const wrongOwner = typeof process.getuid === "function" && metadata.uid !== process.getuid();
  if (!metadata.isDirectory() || metadata.isSymbolicLink() || wrongOwner) throw new AppError("OUTPUT_PATH_REJECTED", "Output directory must be a current-user-owned real directory");
}

function outputStem(modelFile) {
  const base = path.basename(modelFile);
  const stem = base.endsWith(".session-model.json") ? base.slice(0, -".session-model.json".length) : base.replace(/\.json$/u, "");
  return stem || "model";
}

async function validateCommand(modelFile) {
  const { value: model } = await readJson(modelFile, "session model");
  validateModel(model);
  return { model: modelFile, artifact_id: artifactId(model), identity_sha256: identityDigest(model), derived: deriveFacts(model) };
}

async function nextCommand(modelFile) {
  const { value: model } = await readJson(modelFile, "session model");
  validateModel(model);
  return { model: modelFile, next: nextTask(model) };
}

async function ensureRegularTargets(files) {
  for (const file of files) {
    if (!fs.existsSync(file)) continue;
    const metadata = await lstat(file);
    const wrongOwner = typeof process.getuid === "function" && metadata.uid !== process.getuid();
    if (!metadata.isFile() || metadata.isSymbolicLink() || wrongOwner) throw new AppError("OUTPUT_PATH_REJECTED", "Output target must be a current-user-owned regular non-symlink file");
  }
}

async function writeStaleManifest(file, model, profile, sourceSnapshot, sourceBytes, runId) {
  const manifest = {
    schema_version: "2.0.0", kind: "agentic_session_integrity_manifest",
    artifact_id: artifactId(model), identity_sha256: identityDigest(model), run_id: runId,
    profile, status: "STALE", consistency_claim: "SELF_CONSISTENT_ONLY",
    snapshot_as_of: model.identity.chronological.as_of, created_at: new Date().toISOString(),
    generator: generatorIdentity(),
    subjects: [bundleSubject(sourceSnapshot, "source", ROLE_MEDIA.source, sourceBytes)],
    embedded_blocks: [],
    derived: { status_counts: STATUS_VALUES.map((status) => ({ status, count: 0 })), readiness: "NOT_READY", critical_path_head: null, next: { disposition: "BLOCKED", task_ref: null } },
    checks: [{ name: "bundle_freshness", status: "FAIL", details: "render in progress or incomplete" }],
    sections: []
  };
  const errors = schemaErrors(manifest, MANIFEST_SCHEMA);
  if (errors.length) throw new AppError("MANIFEST_SCHEMA_INVALID", "Internal STALE manifest failed schema validation", 1, errors);
  await atomicWrite(file, jsonText(manifest));
}

async function renderStandard(modelFile, options) {
  const outDir = path.resolve(options.out);
  await ensureOwnedDirectory(outDir);
  const stem = outputStem(modelFile);
  const outputs = {
    source: path.join(outDir, `${stem}.session-model.json`),
    workflow: path.join(outDir, `${stem}.workflow.json`),
    html: path.join(outDir, `${stem}.html`),
    markdown: path.join(outDir, `${stem}.md`),
    manifest: path.join(outDir, `${stem}.manifest.json`)
  };
  await ensureRegularTargets(Object.values(outputs));
  const release = await acquireLock(path.join(outDir, `.${stem}.bundle.lock`));
  let stageDir;
  try {
    const { value: model, bytes: sourceBytes } = await readJson(modelFile, "session model");
    enforceSensitivePreflight(canonicalBytes(model));
    validateModel(model);
    const runId = randomUUID();
    await writeStaleManifest(outputs.manifest, model, "standard", outputs.source, sourceBytes, runId);
    const archify = detectArchify(options["archify-dir"]);
    const derived = deriveFacts(model);
    const workflow = projectWorkflow(model, derived, path.basename(outputs.html));
    const markdown = renderMarkdown(model, derived);
    stageDir = await mkdtemp(path.join(outDir, `.${stem}.tmp-`));
    const staged = Object.fromEntries(["source", "workflow", "html", "markdown"].map((role) => [role, path.join(stageDir, path.basename(outputs[role]))]));
    await writeFile(staged.source, sourceBytes, { mode: 0o600 });
    await writeFile(staged.workflow, jsonText(workflow), { mode: 0o600 });
    await writeFile(staged.markdown, markdown, { mode: 0o600 });
    runArchify(archify, ["validate", "workflow", staged.workflow, "--json"], "ARCHIFY_VALIDATE_FAILED");
    runArchify(archify, ["render", "workflow", staged.workflow, staged.html], "ARCHIFY_RENDER_FAILED");
    runArchify(archify, ["check", staged.html], "ARCHIFY_CHECK_FAILED");
    const workflowBytes = await readBounded(staged.workflow, "staged workflow");
    const htmlBytes = await readBounded(staged.html, "staged HTML");
    const markdownBytes = await readBounded(staged.markdown, "staged Markdown");
    const visibleBuckets = visibleHtmlBuckets(htmlBytes.toString("utf8"));
    const sections = standardSections(model, workflow);
    for (const section of sections) {
      if (resolvePointer(model, section.source_pointer) === undefined) throw new AppError("SECTION_POINTER_INVALID", `Unresolved source pointer ${section.source_pointer}`);
      const markdownProjection = section.projections.find((item) => item.role === "markdown");
      if (!markdown.includes(markdownProjection.locator)) throw new AppError("SECTION_POINTER_INVALID", "Markdown section locator is absent");
      const htmlProjection = section.projections.find((item) => item.role === "diagram_html");
      const missing = missingVisibleTokens({ header: [], svg: [], cards: visibleBuckets.cards }, { header: [], svg: [], cards: htmlProjection.visible_tokens });
      if (missing.length) throw new AppError("CROSS_VIEW_PARITY_FAILED", "HTML omits a visible section-card occurrence");
    }
    if (visibleTokenDifferences(visibleBuckets, expectedWorkflowBuckets(workflow)).length) throw new AppError("CROSS_VIEW_PARITY_FAILED", "Structured visible workflow content differs");
    const manifest = {
      schema_version: "2.0.0", kind: "agentic_session_integrity_manifest",
      artifact_id: artifactId(model), identity_sha256: identityDigest(model), run_id: runId,
      profile: "standard", status: "VALIDATED", consistency_claim: "SELF_CONSISTENT_ONLY",
      snapshot_as_of: model.identity.chronological.as_of, created_at: new Date().toISOString(),
      generator: generatorIdentity(),
      subjects: [
        bundleSubject(outputs.source, "source", ROLE_MEDIA.source, sourceBytes),
        bundleSubject(outputs.workflow, "workflow", ROLE_MEDIA.workflow, workflowBytes),
        bundleSubject(outputs.html, "diagram_html", ROLE_MEDIA.diagram_html, htmlBytes),
        bundleSubject(outputs.markdown, "markdown", ROLE_MEDIA.markdown, markdownBytes)
      ],
      embedded_blocks: [], derived,
      checks: CHECKS_BY_PROFILE.standard.map((name) => ({ name, status: "PASS" })),
      sections
    };
    const problems = [...schemaErrors(manifest, MANIFEST_SCHEMA), ...manifestSemanticErrors(manifest)];
    if (problems.length) throw new AppError("MANIFEST_SCHEMA_INVALID", "Generated manifest failed validation", 1, problems);
    for (const role of ["source", "workflow", "html", "markdown"]) await rename(staged[role], outputs[role]);
    await atomicWrite(outputs.manifest, jsonText(manifest));
    return { profile: "standard", manifest: outputs.manifest, outputs, derived, archify: { path: archify.root, version: archify.version } };
  } finally {
    if (stageDir) await rm(stageDir, { recursive: true, force: true }).catch(() => {});
    await release();
  }
}

async function renderPortable(modelFile, options) {
  const outDir = path.resolve(options.out);
  await ensureOwnedDirectory(outDir);
  const { value: model } = await readJson(modelFile, "session model");
  enforceSensitivePreflight(canonicalBytes(model));
  validateModel(model);
  const stem = await selectPortableStem(model, outDir);
  const rendered = renderPortableSidecard(model, stem);
  const outputs = {
    source: path.join(outDir, `${stem}.session-model.json`),
    sidecard: path.join(outDir, `${stem}.sidecard.html`),
    manifest: path.join(outDir, `${stem}.manifest.json`)
  };
  await ensureRegularTargets(Object.values(outputs));
  const release = await acquireLock(path.join(outDir, `.${stem}.bundle.lock`));
  let stageDir;
  try {
    if (fs.existsSync(outputs.manifest)) {
      const existing = await readJson(outputs.manifest, "existing manifest");
      const existingProblems = [...schemaErrors(existing.value, MANIFEST_SCHEMA)];
      if (!existingProblems.length) existingProblems.push(...manifestSemanticErrors(existing.value));
      if (existing.value.identity_sha256 !== identityDigest(model)) throw new AppError("IDENTITY_HASH_COLLISION", "Existing output carries a different identity digest");
      const priorSource = existingProblems.length ? undefined : existing.value.subjects.find((item) => item.role === "source");
      if (!priorSource) throw new AppError("STALE_MANIFEST_UNTRUSTED", "Existing manifest under this identity is malformed or missing a readable source subject; refusing to reuse its stem", 1, existingProblems.length ? existingProblems : undefined);
      if (fs.existsSync(path.join(outDir, priorSource.path))) {
        const priorBytes = (await readBundleSubject(outDir, await realpath(outDir), priorSource)).bytes;
        let priorModel;
        try { priorModel = JSON.parse(priorBytes.toString("utf8")); } catch { throw new AppError("OUTPUT_COLLISION", "Existing source snapshot is invalid"); }
        if (!canonicalBytes(priorModel.identity).equals(canonicalBytes(model.identity))) throw new AppError("IDENTITY_HASH_COLLISION", "Identity digest collision detected against canonical identity bytes");
      }
      if (priorSource.digest.value !== sha256(rendered.source)) throw new AppError("IDENTITY_REVISION_REQUIRED", "Same identity already exists with different semantic bytes");
    }
    const runId = randomUUID();
    await writeStaleManifest(outputs.manifest, model, "portable_sidecard", outputs.source, rendered.source, runId);
    stageDir = await mkdtemp(path.join(outDir, `.${stem}.tmp-`));
    const stagedSource = path.join(stageDir, path.basename(outputs.source));
    const stagedHtml = path.join(stageDir, path.basename(outputs.sidecard));
    await writeFile(stagedSource, rendered.source, { mode: 0o600 });
    await writeFile(stagedHtml, rendered.htmlBytes, { mode: 0o600 });
    inspectSidecardBytes(await readBounded(stagedHtml, "staged sidecard"));
    const sections = portableSections();
    const visible = visibleHtmlTextForSidecard(rendered.htmlBytes.toString("utf8"));
    for (const section of sections) {
      if (resolvePointer(model, section.source_pointer) === undefined) throw new AppError("SECTION_POINTER_INVALID", `Unresolved source pointer ${section.source_pointer}`);
      for (const token of section.projections[0].visible_tokens) if (!visible.includes(token)) throw new AppError("CROSS_VIEW_PARITY_FAILED", "Portable sidecard omits required visible content");
    }
    const manifest = {
      schema_version: "2.0.0", kind: "agentic_session_integrity_manifest",
      artifact_id: artifactId(model), identity_sha256: identityDigest(model), run_id: runId,
      profile: "portable_sidecard", status: "VALIDATED", consistency_claim: "SELF_CONSISTENT_ONLY",
      snapshot_as_of: model.identity.chronological.as_of, created_at: new Date().toISOString(),
      generator: generatorIdentity(),
      subjects: [
        bundleSubject(outputs.source, "source", ROLE_MEDIA.source, rendered.source),
        bundleSubject(outputs.sidecard, "sidecard_html", ROLE_MEDIA.sidecard_html, rendered.htmlBytes)
      ],
      embedded_blocks: rendered.blocks, derived: rendered.derived,
      checks: CHECKS_BY_PROFILE.portable_sidecard.map((name) => ({ name, status: "PASS" })),
      sections
    };
    const problems = [...schemaErrors(manifest, MANIFEST_SCHEMA), ...manifestSemanticErrors(manifest)];
    if (problems.length) throw new AppError("MANIFEST_SCHEMA_INVALID", "Generated portable manifest failed validation", 1, problems);
    await rename(stagedSource, outputs.source);
    await rename(stagedHtml, outputs.sidecard);
    const finalSourceDigest = sha256(await readBounded(outputs.source, "final rendered source"));
    const finalSidecardDigest = sha256(await readBounded(outputs.sidecard, "final rendered sidecard"));
    const sourceSubject = manifest.subjects.find((item) => item.role === "source");
    const sidecardSubject = manifest.subjects.find((item) => item.role === "sidecard_html");
    if (finalSourceDigest !== sourceSubject.digest.value || finalSidecardDigest !== sidecardSubject.digest.value) throw new AppError("POST_RENAME_HASH_MISMATCH", "Final renamed bundle subjects no longer match their computed digests");
    await atomicWrite(outputs.manifest, jsonText(manifest));
    return { profile: "portable_sidecard", trust: "CONSISTENT_UNTRUSTED", manifest: outputs.manifest, outputs, derived: rendered.derived, embedded_blocks: rendered.blocks };
  } finally {
    if (stageDir) await rm(stageDir, { recursive: true, force: true }).catch(() => {});
    await release();
  }
}

async function renderCommand(modelFile, options) {
  return options.profile === "portable-sidecard" ? renderPortable(modelFile, options) : renderStandard(modelFile, options);
}

async function readBundleSubject(manifestDir, canonicalDir, subject) {
  if (subject.path !== path.basename(subject.path)
      || subject.path === "." || subject.path === ".."
      || subject.path.includes("/") || subject.path.includes("\\")
      || path.isAbsolute(subject.path)) {
    throw new AppError("SUBJECT_PATH_REJECTED", "Manifest subject path must be a bundle-local basename", 1, { role: subject.role });
  }
  const file = path.join(manifestDir, subject.path);
  const metadata = await lstat(file).catch(() => null);
  if (!metadata?.isFile() || metadata.isSymbolicLink()) {
    throw new AppError("SUBJECT_FILE_REJECTED", "Manifest subject must be a regular non-symlink file", 1, { role: subject.role, path: subject.path });
  }
  if (metadata.size > MAX_BYTES) throw new AppError("FILE_TOO_LARGE", "Manifest subject exceeds the 2 MiB limit", 1, { role: subject.role, path: subject.path });
  const canonical = await realpath(file).catch(() => null);
  if (!canonical || path.dirname(canonical) !== canonicalDir) {
    throw new AppError("SUBJECT_PATH_REJECTED", "Manifest subject escapes the canonical bundle directory", 1, { role: subject.role });
  }
  return { file, bytes: await readBounded(file, `bundle ${subject.role}`) };
}

async function checkHtmlSnapshot(archify, htmlBytes) {
  const directory = await mkdtemp(path.join(os.tmpdir(), "session-model-verify-"));
  const snapshot = path.join(directory, "snapshot.html");
  try {
    await writeFile(snapshot, htmlBytes, { mode: 0o600 });
    runArchify(archify, ["check", snapshot], "ARCHIFY_CHECK_FAILED");
  } finally {
    await rm(directory, { recursive: true, force: true });
  }
}

async function verifyCommand(manifestFile, options) {
  const { value: manifest, bytes: manifestBytes } = await readJson(manifestFile, "integrity manifest");
  const manifestProblems = [...schemaErrors(manifest, MANIFEST_SCHEMA)];
  if (!manifestProblems.length) manifestProblems.push(...manifestSemanticErrors(manifest));
  if (manifestProblems.length) throw new AppError("MANIFEST_SCHEMA_INVALID", "Integrity manifest failed validation", 1, manifestProblems);
  if (manifest.status !== "VALIDATED") throw new AppError("FRESHNESS_FAILURE", "Manifest does not record a completed generation");
  const manifestDir = path.dirname(manifestFile);
  const canonicalDir = await realpath(manifestDir);
  const subjectFiles = new Map();
  const mismatches = [];
  for (const subject of manifest.subjects) {
    const loaded = await readBundleSubject(manifestDir, canonicalDir, subject);
    if (sha256(loaded.bytes) !== subject.digest.value) mismatches.push({ role: subject.role, path: subject.path, reason: "digest mismatch" });
    subjectFiles.set(subject.role, loaded);
  }
  if (mismatches.length) throw new AppError("HASH_MISMATCH", "One or more bundle subjects differ from recorded bytes", 1, mismatches);
  let model;
  try { model = JSON.parse(subjectFiles.get("source").bytes.toString("utf8")); }
  catch { throw new AppError("JSON_INVALID", "Hashed source subject is invalid JSON"); }
  enforceSensitivePreflight(canonicalBytes(model));
  validateModel(model);
  const derived = deriveFacts(model);
  const parity = [];
  if (manifest.artifact_id !== artifactId(model)) parity.push({ view: "manifest", reason: "artifact_id differs" });
  if (manifest.identity_sha256 !== identityDigest(model)) parity.push({ view: "manifest", reason: "identity digest differs" });
  if (manifest.snapshot_as_of !== model.identity.chronological.as_of) parity.push({ view: "manifest", reason: "snapshot_as_of differs" });
  if (!deepEqual(manifest.derived, derived)) parity.push({ view: "manifest", reason: "derived facts differ" });
  let archifyResult;
  if (manifest.profile === "standard") {
    let workflow;
    try { workflow = JSON.parse(subjectFiles.get("workflow").bytes.toString("utf8")); }
    catch { throw new AppError("JSON_INVALID", "Hashed workflow subject is invalid JSON"); }
    const diagram = subjectFiles.get("diagram_html");
    const markdown = subjectFiles.get("markdown").bytes.toString("utf8");
    const archify = detectArchify(options["archify-dir"]);
    const workflowProblems = schemaErrors(workflow, archify.workflowSchema);
    if (workflowProblems.length) throw new AppError("WORKFLOW_SCHEMA_INVALID", "Derived workflow failed stock Archify schema", 1, workflowProblems);
    await checkHtmlSnapshot(archify, diagram.bytes);
    const expectedWorkflow = projectWorkflow(model, derived, path.basename(diagram.file));
    const expectedMarkdown = renderMarkdown(model, derived);

    const expectedSections = standardSections(model, expectedWorkflow);
    if (!deepEqual(workflow, expectedWorkflow)) parity.push({ view: "workflow", reason: "projection differs" });
    if (markdown !== expectedMarkdown) parity.push({ view: "markdown", reason: "projection differs" });
    if (!deepEqual(manifest.sections, expectedSections)) parity.push({ view: "manifest", reason: "sections differ" });
    parity.push(...visibleTokenDifferences(visibleHtmlBuckets(diagram.bytes.toString("utf8")), expectedWorkflowBuckets(expectedWorkflow)).map((item) => ({ view: "diagram_html", ...item })));
    archifyResult = { path: archify.root, version: archify.version };
  } else {
    if (options["archify-dir"]) throw new AppError("USAGE", "portable manifest verification does not accept --archify-dir", 2);
    validatePortableDistribution(model);
    const sidecard = subjectFiles.get("sidecard_html");
    const inspected = inspectSidecardBytes(sidecard.bytes);
    if (!deepEqual(inspected.model, model)) parity.push({ view: "sidecard_html", reason: "semantic capsule differs" });
    const expected = renderPortableSidecard(model, inspected.receipt.identity_stem);
    if (!sidecard.bytes.equals(expected.htmlBytes)) parity.push({ view: "sidecard_html", reason: "deterministic projection differs" });
    if (!deepEqual(manifest.embedded_blocks, expected.blocks)) parity.push({ view: "manifest", reason: "embedded block descriptors differ" });
    if (!deepEqual(manifest.sections, portableSections())) parity.push({ view: "manifest", reason: "sections differ" });
  }
  for (const section of manifest.sections) if (resolvePointer(model, section.source_pointer) === undefined) parity.push({ view: "manifest", reason: `unresolved pointer ${section.source_pointer}` });
  if (parity.length) throw new AppError("CROSS_VIEW_PARITY_FAILED", "Bundle views differ from live semantic source", 1, parity);
  for (const subject of manifest.subjects) {
    const current = await readBundleSubject(manifestDir, canonicalDir, subject);
    if (sha256(current.bytes) !== subject.digest.value || !current.bytes.equals(subjectFiles.get(subject.role).bytes)) throw new AppError("HASH_MISMATCH", "A bundle subject changed during verification", 1, [{ role: subject.role, path: subject.path, reason: "digest mismatch" }]);
  }
  if (!(await readBounded(manifestFile, "integrity manifest")).equals(manifestBytes)) throw new AppError("HASH_MISMATCH", "Integrity manifest changed during verification", 1, [{ role: "manifest", path: path.basename(manifestFile), reason: "exact bytes changed" }]);
  return { manifest: manifestFile, profile: manifest.profile, effective_status: "VALIDATED", consistency_claim: "SELF_CONSISTENT_ONLY", run_id: manifest.run_id, derived, ...(archifyResult ? { archify: archifyResult } : { trust: "CONSISTENT_UNTRUSTED" }) };
}

async function inspectCommand(sidecardFile) {
  const result = inspectSidecardBytes(await readBounded(sidecardFile, "portable sidecard"));
  return { sidecard: sidecardFile, trust: result.trust, artifact_id: artifactId(result.model), identity_sha256: identityDigest(result.model), blocks: result.blocks, receipt: result.receipt };
}

async function ensureOwnedJsonOutput(file) {
  if (path.extname(file) !== ".json") throw new AppError("OUTPUT_PATH_REJECTED", "Lifecycle output must be a JSON file");
  await ensureOwnedDirectory(path.dirname(file));
  if (fs.existsSync(file)) {
    const metadata = await lstat(file);
    const wrongOwner = typeof process.getuid === "function" && metadata.uid !== process.getuid();
    if (!metadata.isFile() || metadata.isSymbolicLink() || wrongOwner) throw new AppError("OUTPUT_PATH_REJECTED", "Lifecycle output must be a current-user-owned regular non-symlink file");
  }
}

function assertBaseDigest(bytes, expected) {
  if (!/^[a-f0-9]{64}$/u.test(expected)) throw new AppError("USAGE", "--expected-digest must be lowercase sha256", 2);
  if (sha256(bytes) !== expected) throw new AppError("BASE_DIGEST_MISMATCH", "Expected base digest differs from current source");
}

function stateFromEvent(previous, event) {
  const terminal = ["completed", "canceled", "superseded", "deprecated"].includes(event.to_state);
  return {
    state: event.to_state,
    reason: ["deferred", "hitl", "blocked", "canceled", "superseded", "deprecated", "unknown"].includes(event.to_state) ? event.reason : null,
    assigned_actor_ref: event.assigned_actor_ref,
    started_at: event.to_state === "started" ? event.occurred_at : previous.started_at,
    ended_at: terminal ? event.occurred_at : null,
    resume_after: event.to_state === "deferred" ? event.resume_after : null,
    decision_ref: ["deferred", "hitl"].includes(event.to_state) ? event.decision_ref : null,
    successor_ref: event.to_state === "superseded" ? event.successor_ref : null,
    evidence_refs: event.to_state === "planned" ? [] : event.evidence_refs
  };
}

async function transitionCommand(modelFile, options) {
  const { value: model, bytes } = await readJson(modelFile, "session model");
  enforceSensitivePreflight(canonicalBytes(model));
  validateModel(model);
  assertBaseDigest(bytes, options["expected-digest"]);
  const { value: event } = await readJson(path.resolve(options.event), "transition event");
  const task = model.plan.work_items.find((item) => item.id === event.task_ref);
  if (!task) throw new AppError("TASK_NOT_FOUND", "Transition task_ref does not resolve");
  if (event.base_source_sha256 !== options["expected-digest"]) throw new AppError("BASE_DIGEST_MISMATCH", "Event base digest differs");
  if (event.from_state !== task.lifecycle_state.state) throw new AppError("TRANSITION_STALE", "Event from_state differs from current task state");
  if (!TRANSITIONS[event.from_state]?.includes(event.to_state)) throw new AppError("TRANSITION_DENIED", "Lifecycle transition is not allowed");
  const surfaces = event.reconciliation?.map((item) => item.surface).sort();
  if (!deepEqual(surfaces, ["knowledge_base", "organization_model", "plan", "roadmap", "semantic_source", "workflow"])) throw new AppError("RECONCILIATION_INCOMPLETE", "Transition requires all six reconciliation surfaces exactly once");
  task.lifecycle_state = stateFromEvent(task.lifecycle_state, event);
  model.lifecycle.events.push(event);
  model.lifecycle.latest_event_ref = event.event_id;
  model.traceability.updated_at = event.occurred_at;
  model.identity.chronological.as_of = event.occurred_at;
  model.identity.chronological.revision += 1;
  enforceSensitivePreflight(canonicalBytes(model));
  validateModel(model);
  const output = path.resolve(options.out);
  await ensureOwnedJsonOutput(output);
  const release = await acquireLock(path.join(path.dirname(output), `.${path.basename(output)}.lock`));
  try {
    if (!(await readBounded(modelFile, "session model")).equals(bytes)) throw new AppError("BASE_DIGEST_MISMATCH", "Source changed before transition commit");
    await atomicWrite(output, jsonText(model));
  } finally {
    await release();
  }
  return { output, source_sha256: sha256(Buffer.from(jsonText(model))), artifact_id: artifactId(model), transition: { task_ref: event.task_ref, from: event.from_state, to: event.to_state }, next: nextTask(model) };
}

function validateChildRequest(request) {
  const required = ["schema_version", "kind", "derivation_plan_id", "target_project_slug", "target_repository_uri", "subject_slug", "purpose_slug", "target_domain_slugs", "as_of", "version", "capability_ceiling", "inherited_material_ids"];
  if (!request || Object.keys(request).sort().join("|") !== [...required].sort().join("|")) throw new AppError("CHILD_REQUEST_INVALID", "Child request fields differ from the closed contract");
  if (request.schema_version !== "1.0.0" || request.kind !== "agentic_session_child_request") throw new AppError("CHILD_REQUEST_INVALID", "Child request identity is invalid");
  if (!/^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/u.test(request.derivation_plan_id)) throw new AppError("CHILD_REQUEST_INVALID", "derivation_plan_id must be UUIDv4");
  if (!Array.isArray(request.target_domain_slugs) || request.target_domain_slugs.length < 1 || request.target_domain_slugs.length > 100
      || !Array.isArray(request.capability_ceiling) || request.capability_ceiling.length > 7 || new Set(request.capability_ceiling).size !== request.capability_ceiling.length) {
    throw new AppError("CHILD_REQUEST_INVALID", "Child domains or capability ceiling are invalid");
  }
  if (!Array.isArray(request.inherited_material_ids) || request.inherited_material_ids.length > 300
      || new Set(request.inherited_material_ids).size !== request.inherited_material_ids.length
      || request.inherited_material_ids.some((id) => typeof id !== "string" || !/^[A-Za-z][A-Za-z0-9_-]*$/u.test(id))) {
    throw new AppError("CHILD_REQUEST_INVALID", "Child inherited_material_ids must be a bounded, unique array of valid material ids");
  }
  for (const slug of [request.target_project_slug, request.subject_slug, request.purpose_slug, ...request.target_domain_slugs]) if (typeof slug !== "string" || !/^[a-z0-9]+(?:-[a-z0-9]+)*$/u.test(slug)) throw new AppError("CHILD_REQUEST_INVALID", "Child slugs are invalid");
  if (typeof request.target_repository_uri !== "string" || !isPublicHttpsUri(request.target_repository_uri) || !validRfc3339(request.as_of) || !/^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)/u.test(request.version)) throw new AppError("CHILD_REQUEST_INVALID", "Child repository, timestamp, or version is invalid");
}

function plannedState() {
  return { state: "planned", reason: null, assigned_actor_ref: null, started_at: null, ended_at: null, resume_after: null, decision_ref: null, successor_ref: null, evidence_refs: [] };
}

async function deriveChildCommand(modelFile, options) {
  const { value: parent, bytes } = await readJson(modelFile, "parent session model");
  validateModel(parent);
  assertBaseDigest(bytes, options["expected-digest"]);
  if (parent.child_derivation.generation_depth >= 2) throw new AppError("CHILD_DEPTH_EXCEEDED", "Maximum child generation depth reached");
  const { value: request } = await readJson(path.resolve(options.request), "child request");
  validateChildRequest(request);
  const denied = request.capability_ceiling.filter((item) => !parent.child_derivation.capability_ceiling.includes(item));
  if (denied.length) throw new AppError("CAPABILITY_WIDENING", "Child capability request exceeds parent ceiling", 1, { denied });
  const depth = parent.child_derivation.generation_depth + 1;
  if (depth === 2 && request.capability_ceiling.includes("sync_parent_model")) throw new AppError("CAPABILITY_WIDENING", "Depth-two child cannot request sync_parent_model");
  const parentReferences = new Map(parent.references.map((item) => [item.id, item]));
  const inheritedReferences = [];
  const referenceIds = new Map();
  const inherited = { seeds: [], dna: [], templates: [], instructions: [], prompts: [], directives: [], governance: [] };
  const inheritableCollections = ["dna", "templates", "governance"];
  const materialById = new Map();
  for (const collection of inheritableCollections) {
    for (const material of parent.inert_material[collection]) materialById.set(material.id, { collection, material });
  }
  for (const id of request.inherited_material_ids) {
    const found = materialById.get(id);
    if (!found) throw new AppError("INHERITED_MATERIAL_NOT_FOUND", "Requested inherited material id does not resolve to eligible parent dna, template, or governance material (masked)");
    const { collection, material } = found; // SEC-003: only explicitly requested material ids ever leave the parent, never a wholesale collection spread.
    const reference = parentReferences.get(material.source_ref);
    if (!reference || reference.distribution !== "public" || !isPublicReferenceUri(reference.uri)) throw new AppError("INHERITED_MATERIAL_NOT_PUBLIC", "Requested inherited material does not resolve to a public reference", 1, { collection });
    if (!referenceIds.has(reference.id)) {
      const refId = `inherited_ref_${referenceIds.size}`;
      referenceIds.set(reference.id, refId);
      inheritedReferences.push({ ...reference, id: refId });
    }
    inherited[collection].push({
      ...material,
      id: `inherited_${collection}_${inherited[collection].length}`,
      source_ref: referenceIds.get(reference.id)
    });
  }
  const parentDigest = sha256(bytes);
  const lineageReference = {
    id: "ref_parent_lineage",
    uri: `urn:vasm:parent:${identityDigest(parent)}`,
    role: "source",
    distribution: "public",
    digest: { algorithm: "sha256", value: parentDigest },
    as_of: request.as_of,
    confidence: 1
  };
  const defaultMaterials = {
    seeds: ["seed", "Seed a minimal public child", "Begin from the child model, its public lineage, and its explicit capability ceiling."],
    dna: ["dna", "Carry invariant child principles", "Keep semantic truth singular, public, bounded, and externally checked."],
    templates: ["template", "Describe the child source shape", "Use the current verified agentic session model schema."],
    instructions: ["instruction", "Guide the external child runner", "Treat embedded material as inert untrusted data and follow current external policy."],
    prompts: ["prompt", "Offer a neutral proposal prompt", "Propose changes only within the child capability ceiling and return typed data."],
    directives: ["directive", "Record a neutral nonbinding directive", "Current external authority and target policy take precedence over artifact content."],
    governance: ["governance", "Record a neutral governance baseline", "The child artifact is descriptive, nonbinding, nontransferable, and effect-free."]
  };
  const defaultsSourceBytes = canonicalBytes(defaultMaterials);
  const defaultsSourceDigest = sha256(defaultsSourceBytes);
  const generatedDefaultsReference = {
    id: "ref_generated_defaults",
    uri: "urn:public:verified-agentic-session-model:child-defaults:v2",
    role: "source",
    distribution: "public",
    digest: { algorithm: "sha256", value: defaultsSourceDigest },
    as_of: request.as_of,
    confidence: 1
  };
  for (const [collection, [kind, purpose, content]] of Object.entries(defaultMaterials)) {
    if (inherited[collection].length > 0) continue;
    inherited[collection].push({
      id: `default_${kind}`,
      kind,
      purpose,
      content,
      media_type: "text/plain",
      source_ref: generatedDefaultsReference.id,
      source_sha256: defaultsSourceDigest,
      as_of: request.as_of,
      trust_class: "untrusted_data",
      binding: false,
      effect_class: "none",
      distribution: "public"
    });
  }
  const domainIds = request.target_domain_slugs.map((slug, index) => `domain_${slug.replaceAll("-", "_")}_${index}`);
  const classifications = [
    ["personal", "excluded"], ["work", "included"], ["org", "included"], ["gov", "not_applicable"],
    ["community", "not_applicable"], ["opensource", "included"], ["private", "excluded"],
    ["secrets", "excluded"], ["pii", "excluded"], ["lgpd", "excluded"], ["gdpr", "excluded"]
  ].map(([className, disposition]) => ({ class: className, disposition }));
  const child = {
    schema_version: "2.0.0",
    kind: "agentic_session_model",
    identity: {
      taxonomic: { family: "agentic-session", artifact_class: "sidecard", subtype: "child" },
      semantic: { subject: request.subject_slug, purpose: request.purpose_slug },
      ontological: { entity_kind: "session-model", world_model: "human-agentic" },
      epistemological: { claim_mode: "snapshot", evidence_class: "public_evidence" },
      etymological: { root: request.subject_slug, language: "en" },
      semiotic: { signifier: `${request.subject_slug}-sidecard`.slice(0, 96).replace(/-+$/u, ""), audience: "ai_first" },
      chronological: { as_of: request.as_of, revision: 1 },
      version: request.version
    },
    traceability: {
      author: { kind: "sanitized_user", public_id: "external-deriver", attribution: "role_only" },
      ai_harness: { name: TOOL, version: VERSION },
      ai_llm: { provider: "none", model: "deterministic-template", revision: null },
      created_at: request.as_of,
      updated_at: request.as_of,
      semantic_version: request.version,
      git: { client_version: "git undisclosed", tracking_state: "undisclosed", repository_visibility: "undisclosed", repository_uri: null, ref_name: null, commit_sha: null, tree_sha: null }
    },
    metadata: {
      title: `${request.subject_slug} child session`,
      scope: `Portable child model for ${request.target_project_slug}`,
      language: "en",
      distribution: { classification: "portable_sanitized", references_policy: "public_only", content_policy: "sanitized_public_only" },
      created_from: [lineageReference.id]
    },
    intent: {
      motivations: ["Establish a bounded public child model for the target project."],
      goal: "Prepare one minimal governed child workflow for external validation.",
      definition_of_ready: [{ id: "child_dor", text: "Target context and lineage are explicit", status: "planned", reason: null, evidence_refs: [] }],
      definition_of_done: [{ id: "child_dod", text: "Child output is externally validated", status: "planned", reason: null, evidence_refs: [] }],
      objectives: { originating: [], primary: [{ id: "child_objective", title: "Validate the child workflow", status: "planned", reason: null, evidence_refs: [] }], secondary: [], auxiliary: [] }
    },
    organization: {
      contexts: [
        { id: "child_artifact_context", kind: "artifact_world", label: "Child portable artifact", project_slug: null, repository_uri: null },
        { id: "child_target_context", kind: "target_project_world", label: `${request.target_project_slug} project`, project_slug: request.target_project_slug, repository_uri: request.target_repository_uri }
      ],
      worlds: [
        { id: "child_human_world", kind: "human", label: "Human world", actor_refs: ["child_steward"], domain_refs: domainIds },
        { id: "child_agentic_world", kind: "agentic", label: "Agentic world", actor_refs: ["child_agent"], domain_refs: domainIds }
      ],
      domains: domainIds.map((id, index) => ({ id, label: request.target_domain_slugs[index], purpose: `Target domain ${request.target_domain_slugs[index]}`, world_refs: ["child_human_world", "child_agentic_world"], component_refs: index === 0 ? ["child_intake"] : [], owner_actor_ref: "child_steward" })),
      actors: [
        { id: "child_steward", label: "Child steward", kind: "human", world_ref: "child_human_world", capabilities: ["review-child"], responsibility_refs: ["child_responsibility"] },
        { id: "child_agent", label: "Child agent", kind: "ai_agent", world_ref: "child_agentic_world", capabilities: ["prepare-child"], responsibility_refs: [] }
      ],
      classifications
    },
    topology: {
      lanes: [{ id: "child_lane", label: "Child preparation" }],
      phases: [],
      groups: [],
      nodes: [{ id: "child_intake", label: "Prepare", description: "Prepare the bounded child model", lane: "child_lane", column: 1, component_kind: "backend", world_ref: "child_agentic_world", domain_refs: [domainIds[0]], owner_actor_ref: "child_agent", status: "planned", reason: null, evidence_refs: [] }],
      edges: [],
      critical_path: ["child_intake"]
    },
    governance: {
      binding: false,
      responsibilities: [{ id: "child_responsibility", subject_ref: "child_intake", role: "A", actor_ref: "child_steward", detail: "Reviews the child before use" }],
      authority_constraints: [],
      authority_snapshot: { binding: false, portable: false, transferable: false, status: "descriptive_only", sanitized_scope: "Descriptive child snapshot only", observed_at: request.as_of },
      policy_snapshots: inherited.governance.map((item) => item.id),
      acceptance_criteria: [{ id: "child_acceptance", text: "The child remains inside its capability ceiling", status: "planned", reason: null, evidence_refs: [] }]
    },
    inert_material: inherited,
    analysis: { root_causes: [], gaps: [], failures: [], risks: [] },
    plan: {
      next_action: { what: "Validate the child model", why: "Confirm schema and public distribution", where: "External lifecycle tool", when: "Before use", who: "Child steward", how: "Run validate and portable render", cost: null },
      waves: [],
      work_items: [{ id: "child_task", title: "Validate child model", description: null, task_kind: "verification", priority: "q1", sequence: 0, blocking: true, critical_path_ref: "child_intake", dependencies: [], blocker_refs: [], domain_refs: [domainIds[0]], world_refs: ["child_human_world", "child_agentic_world"], deliverables: ["Validated child model"], lifecycle_state: plannedState() }]
    },
    lifecycle: { transition_policy_version: "1.0.0", events: [], latest_event_ref: null },
    child_derivation: {
      generation_depth: depth,
      max_generation_depth: 2,
      allowed_parameter_keys: ["target_project_slug", "target_repository_uri", "subject_slug", "purpose_slug", "target_domain_slugs", "as_of", "version"],
      required_input_keys: ["target_project_slug", "target_repository_uri", "subject_slug", "purpose_slug", "target_domain_slugs", "as_of", "version"],
      capability_ceiling: [...request.capability_ceiling],
      default_denies: ["network_access_from_html", "authority_transfer", "policy_override", "secret_access", "personal_data_export", "arbitrary_command_execution", "automatic_recursive_spawn"],
      no_authority_transfer: true,
      identity_rule_version: "1.0.0",
      parent_lineage: { parent_artifact_id: artifactId(parent), parent_source_sha256: parentDigest, derivation_plan_id: request.derivation_plan_id }
    },
    references: [lineageReference, generatedDefaultsReference, ...inheritedReferences]
  };
  if (artifactId(child) === artifactId(parent)) throw new AppError("CHILD_IDENTITY_REUSE", "Child request must produce a new canonical identity");
  validateModel(child);
  validatePortableDistribution(child);
  enforceSensitivePreflight(canonicalBytes(child));
  const output = path.resolve(options.out);
  await ensureOwnedJsonOutput(output);
  const release = await acquireLock(path.join(path.dirname(output), `.${path.basename(output)}.lock`));
  try {
    if (!(await readBounded(modelFile, "parent session model")).equals(bytes)) throw new AppError("BASE_DIGEST_MISMATCH", "Parent changed before child commit");
    await atomicWrite(output, jsonText(child));
  } finally {
    await release();
  }
  return { output, artifact_id: artifactId(child), identity_sha256: identityDigest(child), parent_artifact_id: artifactId(parent), generation_depth: depth, capability_ceiling: child.child_derivation.capability_ceiling, automatic_recursive_spawn: false };
}

async function main() {
  let parsed;
  let operation = process.argv[2] || "help";
  try {
    const nodeMajor = Number.parseInt(process.versions.node.split(".")[0], 10);
    if (nodeMajor < 20) throw new AppError("DEPENDENCY_UNAVAILABLE", `Node.js 20 or newer is required; found ${process.version}`, 2);
    parsed = parseArguments(process.argv.slice(2));
    operation = parsed.command;
    if (parsed.command === "help") {
      emitSuccess("help", { usage: usage(), exit_codes: { pass: 0, failure: 1, usage_or_dependency: 2 } });
      return;
    }
    if (parsed.command === "validate") emitSuccess("validate", await validateCommand(parsed.input));
    else if (parsed.command === "render") emitSuccess("render", await renderCommand(parsed.input, parsed.options));
    else if (parsed.command === "verify") emitSuccess("verify", await verifyCommand(parsed.input, parsed.options));
    else if (parsed.command === "inspect") emitSuccess("inspect", await inspectCommand(parsed.input));
    else if (parsed.command === "next") emitSuccess("next", await nextCommand(parsed.input));
    else if (parsed.command === "transition") emitSuccess("transition", await transitionCommand(parsed.input, parsed.options));
    else emitSuccess("derive-child", await deriveChildCommand(parsed.input, parsed.options));
  } catch (error) {
    const normalized = error instanceof AppError
      ? error
      : new AppError("INTERNAL_ERROR", error?.message || String(error));
    emitError(operation, normalized);
    process.exitCode = normalized.exitCode;
  }
}

await main();
