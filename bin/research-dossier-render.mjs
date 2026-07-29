#!/usr/bin/env node
/**
 * MAOS — research-dossier · renderer + the two deterministic gates
 *
 * Function: consume an IR (skills/research-dossier/templates/ir.schema.json) and
 *   fan it out to html / md / json (+ hand-off manifests for pdf / pptx / xlsx),
 *   but ONLY after both f=0 gates pass. The gates are the point; the rendering is
 *   the easy half.
 *
 *   GATE 1 — provenance.  Fails the build when the dossier's evidential chain is
 *     broken: a claim missing source/as_of/confidence, a chart or recommendation
 *     citing a claim id that does not exist, a truncated magnitude axis that was
 *     not declared, or an empty not_checked[]. This is what carries the text-level
 *     faithfulness discipline into the VISUAL layer — a truncated axis distorts a
 *     magnitude whether or not anyone intended it to.
 *
 *   GATE 2 — palette.  Shells out to the bundled `dataviz` skill's own
 *     validate_palette.js (CVD ΔE OKLab per protan/deutan/tritan, lightness band,
 *     chroma floor, normal-vision floor, surface contrast) in BOTH light and dark.
 *     Not reimplemented here: dataviz owns color, we cite it. The validator path is
 *     DISCOVERED AT RUNTIME because it lives in a version-and-hash-keyed temp dir
 *     that moves on every CLI upgrade; when it cannot be found the gate degrades to
 *     a VISIBLE WARN rather than a silent pass (a security-by-absence failure would
 *     be worse than no gate at all, because it would look green).
 *
 * Why deterministic: both gates are f=0 oracles — same input, same verdict, no model
 *   judgement anywhere in the path. A gate a model can talk itself past is theater.
 *
 * Fail-safe: unknown/unreadable => FAIL (never render blind). Exception: gate 2's
 *   MISSING VALIDATOR, which is an environment fact rather than a palette defect, and
 *   which is therefore a loud WARN — see DATAVIZ_VALIDATOR to force-fail in CI.
 *
 * Portability: Node >= 18, ZERO dependencies (no package.json at repo root; that is
 *   deliberate). No organization-specific content — Layer-Purity clean.
 *
 * Usage:
 *   research-dossier-render.mjs --ir <path> [--formats html,md,json] [--out <dir>]
 *                               [--gates-only] [--strict] [--quiet]
 * Env:
 *   DATAVIZ_VALIDATOR   explicit path to validate_palette.js; set to a nonexistent
 *                       path to exercise the degradation branch.
 * Exit: 0 ok · 1 gate failure · 2 usage/IO error
 */

import { readFileSync, writeFileSync, mkdirSync, existsSync, readdirSync, statSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SKILL_DIR = resolve(HERE, '..', 'skills', 'research-dossier');

const EXIT_OK = 0, EXIT_GATE = 1, EXIT_USAGE = 2;

// ── tiny arg parser (zero-dep) ──────────────────────────────────────────────
function parseArgs(argv) {
  const a = { formats: ['html', 'md', 'json'], out: 'out', gatesOnly: false, strict: false, quiet: false };
  for (let i = 0; i < argv.length; i++) {
    const t = argv[i];
    if (t === '--ir') a.ir = argv[++i];
    else if (t === '--formats') a.formats = String(argv[++i]).split(',').map(s => s.trim()).filter(Boolean);
    else if (t === '--out') a.out = argv[++i];
    else if (t === '--gates-only') a.gatesOnly = true;
    else if (t === '--strict') a.strict = true;
    else if (t === '--quiet') a.quiet = true;
    else if (t === '--help' || t === '-h') a.help = true;
    else if (t.startsWith('--')) { a.unknown = t; }
  }
  return a;
}

// ── report accumulator ──────────────────────────────────────────────────────
const report = { fail: [], warn: [], info: [] };
const FAIL = (code, msg) => report.fail.push({ code, msg });
const WARN = (code, msg) => report.warn.push({ code, msg });
const INFO = m => report.info.push(m);

// ═══════════════════════════════════════════════════════════════════════════
// GATE 1 — provenance
// ═══════════════════════════════════════════════════════════════════════════
const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;
const CONFIDENCE = new Set(['high', 'medium', 'low']);
/** Forms where the y-axis encodes MAGNITUDE — the family where a truncated
 *  baseline lies about proportion. A line chart of a bounded index may legitimately
 *  start above zero; a bar chart may not. */
const MAGNITUDE_FORMS = new Set(['bar', 'column', 'stacked-bar', 'area', 'diverging-bar']);

function gateProvenance(ir) {
  // -- structural minimums the schema also states, re-checked here because the
  //    renderer must never assume an upstream validator ran.
  for (const f of ['question', 'as_of', 'audience', 'claims', 'not_checked', 'methodology']) {
    if (ir[f] === undefined || ir[f] === null) FAIL('IR_MISSING_FIELD', `required top-level field missing: ${f}`);
  }
  if (ir.as_of && !ISO_DATE.test(ir.as_of)) FAIL('IR_BAD_DATE', `as_of must be YYYY-MM-DD, got: ${ir.as_of}`);

  // -- claims: the five-field contract. Everything downstream rests on this.
  const claims = Array.isArray(ir.claims) ? ir.claims : [];
  if (claims.length === 0) FAIL('NO_CLAIMS', 'claims[] is empty — a dossier with no evidence is prose');

  const ids = new Map();
  const confidences = [];
  for (const [i, c] of claims.entries()) {
    const at = `claims[${i}]${c && c.id ? ` (${c.id})` : ''}`;
    if (!c || typeof c !== 'object') { FAIL('CLAIM_SHAPE', `${at}: not an object`); continue; }
    if (!c.id) FAIL('CLAIM_NO_ID', `${at}: missing id`);
    else if (ids.has(c.id)) FAIL('CLAIM_DUP_ID', `${at}: duplicate id "${c.id}" (first at claims[${ids.get(c.id)}])`);
    else ids.set(c.id, i);

    if (!c.text) FAIL('CLAIM_NO_TEXT', `${at}: missing text`);
    if (!c.source || !c.source.label) FAIL('CLAIM_NO_SOURCE', `${at}: missing source.label — an unsourced claim cannot be rendered as evidence`);
    if (!c.as_of) FAIL('CLAIM_NO_AS_OF', `${at}: missing as_of`);
    else if (!ISO_DATE.test(c.as_of)) FAIL('CLAIM_BAD_AS_OF', `${at}: as_of must be YYYY-MM-DD, got "${c.as_of}"`);
    else if (ir.as_of && c.as_of > ir.as_of) FAIL('CLAIM_FUTURE', `${at}: as_of ${c.as_of} is newer than the dossier's as_of ${ir.as_of}`);

    if (!c.confidence) FAIL('CLAIM_NO_CONFIDENCE', `${at}: missing confidence`);
    else if (!CONFIDENCE.has(c.confidence)) FAIL('CLAIM_BAD_CONFIDENCE', `${at}: confidence must be high|medium|low, got "${c.confidence}"`);
    else confidences.push(c.confidence);

    if (c.entity && Array.isArray(ir.entities) && !ir.entities.some(e => e.id === c.entity))
      FAIL('CLAIM_DANGLING_ENTITY', `${at}: entity "${c.entity}" not in entities[]`);
  }

  // A real comparison has softer and harder cells. Uniform high confidence across a
  // non-trivial corpus is the signature of a field filled in rather than assessed.
  if (confidences.length >= 5 && confidences.every(c => c === 'high'))
    WARN('UNIFORM_CONFIDENCE', `all ${confidences.length} claims are confidence:high — plausible only if every one was equally verified`);

  // -- referential integrity: every source_claims[] resolves.
  //    A dangling ref is worse than no ref: it LOOKS sourced.
  const checkRefs = (refs, where) => {
    if (!Array.isArray(refs) || refs.length === 0) {
      FAIL('NO_SOURCE_CLAIMS', `${where}: source_claims is required and must be non-empty`);
      return;
    }
    for (const r of refs) if (!ids.has(r)) FAIL('DANGLING_CLAIM_REF', `${where}: source_claims references "${r}", which is not a claim id`);
  };

  for (const key of ['insights', 'gaps', 'risks', 'opportunities']) {
    for (const [i, d] of (ir[key] || []).entries()) {
      if (!d.text) FAIL('DERIVED_NO_TEXT', `${key}[${i}]: missing text`);
      checkRefs(d.source_claims, `${key}[${i}]`);
    }
  }

  for (const [i, r] of (ir.recommendations || []).entries()) {
    const at = `recommendations[${i}]`;
    if (!r.text) FAIL('REC_NO_TEXT', `${at}: missing text`);
    // owner+eta are the line between a decision and a wish.
    if (!r.owner) FAIL('REC_NO_OWNER', `${at}: missing owner — a recommendation nobody owns is a wish`);
    if (!r.eta) FAIL('REC_NO_ETA', `${at}: missing eta — a recommendation with no date is a wish`);
    checkRefs(r.source_claims, at);
  }

  // -- charts: source_claims + the axis-truncation cross-check.
  for (const [i, ch] of (ir.charts || []).entries()) {
    const at = `charts[${i}]${ch && ch.id ? ` (${ch.id})` : ''}`;
    if (!ch || typeof ch !== 'object') { FAIL('CHART_SHAPE', `${at}: not an object`); continue; }
    if (!ch.form) FAIL('CHART_NO_FORM', `${at}: missing form`);
    if (!ch.title) FAIL('CHART_NO_TITLE', `${at}: missing title`);
    checkRefs(ch.source_claims, at);

    const series = Array.isArray(ch.series) ? ch.series : [];
    if (series.length === 0) FAIL('CHART_NO_SERIES', `${at}: series[] is empty`);
    for (const [j, s] of series.entries()) {
      if (!s.label) FAIL('SERIES_NO_LABEL', `${at}.series[${j}]: missing label`);
      if (!Array.isArray(s.data) || s.data.length === 0) FAIL('SERIES_NO_DATA', `${at}.series[${j}]: data[] is empty`);
      if (s.entity && Array.isArray(ir.entities) && !ir.entities.some(e => e.id === s.entity))
        FAIL('SERIES_DANGLING_ENTITY', `${at}.series[${j}]: entity "${s.entity}" not in entities[]`);
      for (const [k, p] of (s.data || []).entries())
        if (p && p.claim && !ids.has(p.claim))
          FAIL('POINT_DANGLING_CLAIM', `${at}.series[${j}].data[${k}]: claim "${p.claim}" is not a claim id`);
    }

    // THE magnitude-distortion check. A bar chart starting at 90 turns a 2%
    // difference into a visual landslide; declaring it is the price of doing it.
    const ax = ch.axis || {};
    if (MAGNITUDE_FORMS.has(ch.form)) {
      const ys = series.flatMap(s => (s.data || []).map(p => p && p.y)).filter(v => typeof v === 'number');
      const dataMin = ys.length ? Math.min(...ys) : null;
      const naturalBaseline = dataMin !== null && dataMin < 0 ? dataMin : 0;
      const truncates = typeof ax.y_min === 'number' && ax.y_min > naturalBaseline;
      if (truncates && ax.axis_truncated !== true)
        FAIL('UNDECLARED_TRUNCATION',
          `${at}: y_min=${ax.y_min} truncates a "${ch.form}" magnitude axis above its natural baseline (${naturalBaseline}) without axis.axis_truncated:true — this is magnitude distortion`);
      if (ax.axis_truncated === true && !truncates)
        WARN('TRUNCATION_FLAG_UNUSED', `${at}: axis_truncated:true but y_min does not truncate — flag is misleading`);
    }
    if (ax.axis_truncated === true && !ax.truncation_rationale)
      FAIL('TRUNCATION_NO_RATIONALE', `${at}: axis_truncated:true requires axis.truncation_rationale`);
    if (typeof ax.y_min === 'number' && typeof ax.y_max === 'number' && ax.y_min >= ax.y_max)
      FAIL('AXIS_INVERTED', `${at}: y_min (${ax.y_min}) >= y_max (${ax.y_max})`);

    if (ch.emphasis && Array.isArray(ir.entities) && !ir.entities.some(e => e.id === ch.emphasis))
      FAIL('CHART_DANGLING_EMPHASIS', `${at}: emphasis "${ch.emphasis}" not in entities[]`);
  }

  // -- scorecard
  if (ir.scorecard) {
    const sc = ir.scorecard;
    const optIds = new Set(sc.options || []);
    const critIds = new Set((sc.criteria || []).map(c => c.id));
    if (optIds.size < 2) FAIL('SCORECARD_THIN', 'scorecard.options needs >= 2 — a scorecard of one is a profile');
    if (critIds.size < 1) FAIL('SCORECARD_NO_CRITERIA', 'scorecard.criteria[] is empty');

    for (const o of sc.options || [])
      if (Array.isArray(ir.entities) && !ir.entities.some(e => e.id === o))
        FAIL('SCORECARD_DANGLING_OPTION', `scorecard.options: "${o}" not in entities[]`);

    for (const [i, c] of (sc.criteria || []).entries()) {
      if (typeof c.weight === 'number' && !(c.weight >= 0))
        FAIL('SCORECARD_BAD_WEIGHT', `scorecard.criteria[${i}] (${c.id}): weight must be >= 0`);
    }

    const seen = new Set();
    for (const [i, cell] of (sc.cells || []).entries()) {
      const at = `scorecard.cells[${i}]`;
      if (!optIds.has(cell.option)) FAIL('CELL_DANGLING_OPTION', `${at}: option "${cell.option}" not in scorecard.options`);
      if (!critIds.has(cell.criterion)) FAIL('CELL_DANGLING_CRITERION', `${at}: criterion "${cell.criterion}" not in scorecard.criteria`);
      if (cell.value === undefined || cell.value === null) FAIL('CELL_NO_VALUE', `${at}: missing value`);
      if (!cell.confidence) FAIL('CELL_NO_CONFIDENCE', `${at}: missing confidence`);
      else if (!CONFIDENCE.has(cell.confidence)) FAIL('CELL_BAD_CONFIDENCE', `${at}: confidence must be high|medium|low`);
      checkRefs(cell.source_claims, at);
      const key = `${cell.option}::${cell.criterion}`;
      if (seen.has(key)) FAIL('CELL_DUPLICATE', `${at}: duplicate cell for (${cell.option}, ${cell.criterion})`);
      seen.add(key);
    }

    const v = sc.verdict;
    if (v) {
      if (v.winner && !optIds.has(v.winner)) FAIL('VERDICT_DANGLING_WINNER', `scorecard.verdict.winner "${v.winner}" is not an option`);
      if (v.runner_up && !optIds.has(v.runner_up)) FAIL('VERDICT_DANGLING_RUNNER_UP', `scorecard.verdict.runner_up "${v.runner_up}" is not an option`);
      if (v.winner && !v.rationale) FAIL('VERDICT_NO_RATIONALE', 'scorecard.verdict declares a winner with no rationale');
      // A verdict that names no loser is an endorsement, not a decision.
      if (v.winner && !v.runner_up && optIds.size > 1)
        WARN('VERDICT_NO_RUNNER_UP', 'scorecard.verdict names a winner but no runner_up — the rejected alternative is the field that ages best');
    }
  }

  // -- not_checked: required, non-empty, each with a reason.
  const nc = Array.isArray(ir.not_checked) ? ir.not_checked : [];
  if (nc.length === 0)
    FAIL('EMPTY_NOT_CHECKED', 'not_checked[] is empty — that is a claim of omniscience; if nothing was left unexamined, say so with a reason');
  for (const [i, n] of nc.entries()) {
    if (!n.text) FAIL('NOT_CHECKED_NO_TEXT', `not_checked[${i}]: missing text`);
    if (!n.reason) FAIL('NOT_CHECKED_NO_REASON', `not_checked[${i}]: missing reason`);
  }

  // -- stakes=high tightens the bar.
  if (ir.stakes === 'high') {
    for (const c of claims)
      if (c.confidence === 'low' && !nc.some(n => (n.text || '').includes(c.id)))
        WARN('HIGH_STAKES_LOW_CONFIDENCE', `stakes=high but claim "${c.id}" is confidence:low and not surfaced in not_checked[]`);
    if (nc.some(n => n.impact === 'high'))
      WARN('HIGH_STAKES_HIGH_IMPACT_GAP', 'stakes=high with a not_checked[] entry of impact:high — the dossier is admitting its conclusion may not hold');
  }

  // -- summary numerals that appear in no claim (advisory: numbers are the part a
  //    reader will quote, so an unsourced one in the summary is the costliest kind).
  if (typeof ir.summary === 'string') {
    const claimText = claims.map(c => `${c.text} ${c.metric ? c.metric.value : ''}`).join(' ');
    const orphans = [...new Set((ir.summary.match(/\b\d[\d.,]*\b/g) || []))]
      .filter(n => n.length > 1 && !claimText.includes(n));
    if (orphans.length) WARN('SUMMARY_ORPHAN_NUMERAL', `summary contains numerals absent from every claim: ${orphans.join(', ')}`);
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// GATE 2 — palette (delegates to the bundled dataviz validator)
// ═══════════════════════════════════════════════════════════════════════════

/** The bundled skill materializes under a version+hash keyed temp dir that changes
 *  on every CLI upgrade, so the path is discovered rather than pinned. Newest mtime
 *  wins when several versions coexist. */
function discoverValidator() {
  const explicit = process.env.DATAVIZ_VALIDATOR;
  if (explicit) return existsSync(explicit) ? explicit : null;

  const roots = [
    process.env.TMPDIR ? join(process.env.TMPDIR, '..') : null,
    '/private/tmp', '/tmp',
  ].filter(Boolean);

  const found = [];
  for (const root of roots) {
    let entries = [];
    try { entries = readdirSync(root); } catch { continue; }
    for (const e of entries) {
      if (!e.startsWith('claude-')) continue;
      const base = join(root, e, 'bundled-skills');
      let versions = [];
      try { versions = readdirSync(base); } catch { continue; }
      for (const v of versions) {
        let hashes = [];
        try { hashes = readdirSync(join(base, v)); } catch { continue; }
        for (const h of hashes) {
          const p = join(base, v, h, 'dataviz', 'scripts', 'validate_palette.js');
          try { if (statSync(p).isFile()) found.push({ p, m: statSync(p).mtimeMs }); } catch { /* not this one */ }
        }
      }
    }
  }
  if (!found.length) return null;
  found.sort((a, b) => b.m - a.m);
  return found[0].p;
}

const DEFAULT_LIGHT = ['#2a78d6', '#eb6834', '#1baf7a'];
const DEFAULT_DARK  = ['#3987e5', '#d95926', '#199e70'];
const SURFACE_LIGHT = '#fcfcfb';
const SURFACE_DARK  = '#1a1a19';

function resolvePalette(ir) {
  const t = (ir.theme && ir.theme.palette) || {};
  return {
    light: t.categorical_light && t.categorical_light.length ? t.categorical_light : DEFAULT_LIGHT,
    dark:  t.categorical_dark  && t.categorical_dark.length  ? t.categorical_dark  : DEFAULT_DARK,
    surfaceLight: t.surface_light || SURFACE_LIGHT,
    surfaceDark:  t.surface_dark  || SURFACE_DARK,
  };
}

function gatePalette(ir, opts) {
  const pal = resolvePalette(ir);
  const validator = discoverValidator();

  if (!validator) {
    const msg = 'dataviz validate_palette.js not found — the palette was NOT colorblind-validated. '
      + 'Set DATAVIZ_VALIDATOR to an explicit path, or run inside a Claude Code session where the bundled skill is materialized.';
    if (opts.strict) FAIL('PALETTE_VALIDATOR_MISSING', `${msg} (--strict: treated as failure)`);
    else WARN('PALETTE_VALIDATOR_MISSING', msg);
    return { validator: null, runs: [] };
  }
  INFO(`palette validator: ${validator}`);

  const runs = [];
  for (const [mode, colors, surface] of [
    ['light', pal.light, pal.surfaceLight],
    ['dark',  pal.dark,  pal.surfaceDark],
  ]) {
    // A duplicate hex is a degenerate ΔE 0 the validator would flag anyway, but the
    // message is clearer here.
    const dupes = colors.filter((c, i) => colors.indexOf(c) !== i);
    if (dupes.length) FAIL('PALETTE_DUPLICATE', `${mode}: duplicate colors in palette: ${[...new Set(dupes)].join(', ')}`);

    let out = '', code = 0;
    try {
      // execFileSync (not exec) — no shell, so a hex string can never be a command.
      out = execFileSync(process.execPath, [validator, colors.join(','), '--mode', mode, '--surface', surface],
        { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'], timeout: 20000 });
    } catch (e) {
      // Non-zero exit IS the FAIL verdict; capture output rather than treating it as a crash.
      code = typeof e.status === 'number' ? e.status : -1;
      out = `${e.stdout || ''}${e.stderr || ''}`;
      if (code === -1) {
        FAIL('PALETTE_VALIDATOR_ERROR', `${mode}: validator could not be executed: ${e.message}`);
        runs.push({ mode, code, out });
        continue;
      }
    }
    runs.push({ mode, code, out: out.trim() });
    if (code !== 0) {
      const lines = out.split('\n').filter(l => l.includes('[FAIL]')).map(l => l.trim());
      FAIL('PALETTE_FAIL', `${mode} mode failed dataviz validation:\n      ${lines.join('\n      ') || out.trim()}`);
    } else {
      for (const l of out.split('\n').filter(l => l.includes('[WARN]')))
        WARN('PALETTE_WARN', `${mode}: ${l.trim()}`);
    }
  }
  return { validator, runs };
}

// ═══════════════════════════════════════════════════════════════════════════
// renderers
// ═══════════════════════════════════════════════════════════════════════════
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function renderMarkdown(ir) {
  const L = [];
  const claimById = new Map((ir.claims || []).map(c => [c.id, c]));
  const cite = refs => (refs || []).map(r => `[^${r}]`).join('');

  L.push(`# ${ir.title || ir.question}`, '');
  L.push(`> **Question** ${ir.question}  `);
  L.push(`> **As of** ${ir.as_of} · **Audience** ${ir.audience}${ir.stakes ? ` · **Stakes** ${ir.stakes}` : ''}`, '');
  if (ir.summary) L.push('## Summary', '', ir.summary, '');

  if (ir.scorecard) {
    const sc = ir.scorecard;
    const label = id => (ir.entities || []).find(e => e.id === id)?.label || id;
    const cellOf = (o, c) => (sc.cells || []).find(x => x.option === o && x.criterion === c);
    L.push('## Comparison', '');
    L.push(`| Criterion | ${sc.options.map(label).join(' | ')} |`);
    L.push(`|---|${sc.options.map(() => '---').join('|')}|`);
    for (const cr of sc.criteria) {
      const w = typeof cr.weight === 'number' ? ` _(w${cr.weight})_` : '';
      const row = sc.options.map(o => {
        const cell = cellOf(o, cr.id);
        if (!cell) return '— _not measured_';
        return `${esc(cell.display ?? cell.value)} <sub>${cell.confidence}</sub>${cite(cell.source_claims)}`;
      });
      L.push(`| **${cr.label}**${w} | ${row.join(' | ')} |`);
    }
    L.push('');
    if (sc.verdict?.winner) {
      L.push(`**Verdict — ${label(sc.verdict.winner)}.** ${sc.verdict.rationale || ''}`, '');
      if (sc.verdict.runner_up) L.push(`_Runner-up ${label(sc.verdict.runner_up)}: ${sc.verdict.rejected_because || 'no reason recorded'}_`, '');
    }
  }

  const section = (title, arr, fmt) => {
    if (!arr?.length) return;
    L.push(`## ${title}`, '');
    for (const it of arr) L.push(`- ${fmt(it)}`);
    L.push('');
  };
  section('Insights', ir.insights, i => `${i.text}${cite(i.source_claims)}`);
  section('Risks', ir.risks, r => `${r.severity ? `**[${r.severity}]** ` : ''}${r.text}${cite(r.source_claims)}${r.mitigation ? ` — _mitigation:_ ${r.mitigation}` : ''}`);
  section('Opportunities', ir.opportunities, o => `${o.text}${cite(o.source_claims)}`);
  section('Gaps', ir.gaps, g => `${g.text}${cite(g.source_claims)}`);
  section('Recommendations', ir.recommendations, r => `${r.priority ? `**${r.priority}** ` : ''}${r.text} — **${r.owner}**, ${r.eta}${cite(r.source_claims)}`);

  L.push('## Not checked', '');
  for (const n of ir.not_checked) L.push(`- ${n.text} — _${n.reason}_${n.impact ? ` (impact: ${n.impact})` : ''}`);
  L.push('');

  L.push('## Methodology', '', ir.methodology.approach, '');
  if (ir.methodology.sources_consulted != null) L.push(`- Sources consulted: ${ir.methodology.sources_consulted}`);
  if (ir.methodology.window) L.push(`- Window: ${ir.methodology.window.from || '?'} → ${ir.methodology.window.to || '?'}`);
  for (const l of ir.methodology.limitations || []) L.push(`- Limitation: ${l}`);
  L.push('');

  L.push('## Evidence', '');
  for (const c of claimById.values()) {
    const src = c.source.url ? `[${c.source.label}](${c.source.url})` : c.source.label;
    L.push(`[^${c.id}]: ${c.text} — ${src}, ${c.as_of}, confidence ${c.confidence}${c.contested ? ' ⚠︎ contested' : ''}`);
  }
  L.push('');
  return L.join('\n');
}

/** Server-side HTML body.
 *  Everything renders here, not in the browser: a decision artifact that needs a
 *  script to display its own evidence is not archival. The only client-side script
 *  in the output reveals the theme toggle; with JS off the dossier is complete.
 *  That is affordable because theming is pure CSS — the validated palette lands as
 *  --series-N under both scopes and the SVG marks reference them by var(). */
/** audience → density. See references/audience-map.md.
 *  Density is a real parameter, not a mood: it changes how many charts survive
 *  into the render and whether the evidence table starts expanded. It NEVER
 *  changes the claims, the scorecard cells, or not_checked[] — an exec dossier
 *  and an engineer dossier carry the same evidence and pass the same gates.
 *  stakes:"high" overrides density downward everywhere (gaps stay expanded). */
const DENSITY = {
  exec:     { maxCharts: 3, tablesOpen: false },
  client:   { maxCharts: 3, tablesOpen: false },
  public:   { maxCharts: 2, tablesOpen: false },
  team:     { maxCharts: 5, tablesOpen: false },
  engineer: { maxCharts: Infinity, tablesOpen: true }
};
function densityOf(ir) {
  const d = DENSITY[ir.audience] || DENSITY.team;
  // High stakes expands evidence regardless of audience: the reader with the
  // least context must not get the least-qualified version of the truth.
  return ir.stakes === 'high' ? { ...d, tablesOpen: true } : d;
}

function renderHtmlBody(ir) {
  const H = [];
  const den = densityOf(ir);
  const claimIds = new Set((ir.claims || []).map(c => c.id));
  const entityLabel = id => (ir.entities || []).find(e => e.id === id)?.label ?? id;
  const entityIdx = id => {
    const i = (ir.entities || []).findIndex(e => e.id === id);
    return i < 0 ? 0 : i;
  };
  const cites = refs => (refs || [])
    .map(r => `<a class="cite" href="#claim-${esc(r)}"${claimIds.has(r) ? '' : ' data-dangling="1"'}>[${esc(r)}]</a>`)
    .join('');
  const conf = c => (c ? `<span class="conf">${esc(c)}</span>` : '');
  const STATUS_ICON = { good: '●', warning: '▲', serious: '◆', critical: '■' };

  // header
  H.push('<header class="head"><div>');
  H.push(`<h1>${esc(ir.title || ir.question)}</h1>`);
  H.push(`<div class="meta"><b>As of ${esc(ir.as_of)}</b> · audience ${esc(ir.audience)}${ir.stakes ? ` · stakes ${esc(ir.stakes)}` : ''}</div>`);
  H.push('</div>');
  H.push('<button class="theme" type="button" id="theme-toggle" aria-pressed="false" aria-label="Toggle colour theme">◑ theme</button>');
  H.push('</header>');

  if (ir.summary) H.push(`<section><h2>Summary</h2><div class="card"><p class="lede">${esc(ir.summary)}</p></div></section>`);

  // scorecard
  if (ir.scorecard) {
    const sc = ir.scorecard;
    const cellOf = (o, c) => (sc.cells || []).find(x => x.option === o && x.criterion === c);
    H.push('<section><h2>Comparison</h2><div class="card"><table>');
    H.push('<caption>Evidence per cell. A blank cell was not measured — it is not a zero.</caption>');
    H.push(`<thead><tr><th scope="col">Criterion</th>${sc.options.map(o => `<th scope="col">${esc(entityLabel(o))}</th>`).join('')}</tr></thead><tbody>`);
    for (const cr of sc.criteria || []) {
      const w = typeof cr.weight === 'number' ? `<span class="conf">w${cr.weight}</span>` : '';
      const cells = sc.options.map(o => {
        const c = cellOf(o, cr.id);
        return c
          ? `<td>${esc(c.display ?? c.value)}${conf(c.confidence)}${cites(c.source_claims)}</td>`
          : '<td><span class="nomeasure">— not measured</span></td>';
      }).join('');
      H.push(`<tr><th scope="row">${esc(cr.label)}${w}</th>${cells}</tr>`);
    }
    H.push('</tbody></table>');
    const v = sc.verdict;
    if (v?.winner) {
      H.push(`<p style="margin:16px 0 0"><b>Verdict — ${esc(entityLabel(v.winner))}.</b> ${esc(v.rationale || '')}</p>`);
      if (v.runner_up) H.push(`<p class="meta" style="margin:8px 0 0">Runner-up ${esc(entityLabel(v.runner_up))}: ${esc(v.rejected_because || 'no reason recorded')}</p>`);
    }
    H.push('</div></section>');
  }

  // charts — inline SVG + mandatory data table
  if ((ir.charts || []).length) {
    // Density caps how many charts survive. A dropped chart is DISCLOSED, never
    // silently swallowed: an omission the reader cannot see is an edit, not a
    // summary. The charts' underlying claims stay in the evidence table either way.
    const shown = ir.charts.slice(0, den.maxCharts);
    const dropped = ir.charts.length - shown.length;
    H.push('<section><h2>Charts</h2>');
    if (dropped > 0) {
      H.push(`<p class="note">${dropped} further chart${dropped === 1 ? '' : 's'} omitted at "${esc(ir.audience)}" density; the underlying claims remain in the evidence table below.</p>`);
    }
    for (const ch of shown) {
      const pts = [];
      for (const s of ch.series || [])
        for (const p of s.data || []) pts.push({ ...p, entity: s.entity, sLabel: s.label });

      const ax = ch.axis || {};
      const nums = pts.map(p => (typeof p.y === 'number' ? p.y : 0));
      const lo = typeof ax.y_min === 'number' ? ax.y_min : 0;
      const hi = typeof ax.y_max === 'number' ? ax.y_max : Math.max(...nums, 1);
      const span = (hi - lo) || 1;
      const rowH = 34, padL = 168, padR = 78, W = 860, padT = 6;
      const height = padT + pts.length * rowH + 6;

      const desc = `${ch.title}${ch.subtitle ? ` — ${ch.subtitle}` : ''}. `
        + pts.map(p => `${p.x}: ${p.y == null ? 'no data' : p.y}`).join('; ')
        + '. Equivalent data table follows.';

      const marks = pts.map((p, i) => {
        const y = padT + i * rowH;
        const frac = p.y == null ? 0 : Math.max(0, Math.min(1, (p.y - lo) / span));
        const barW = p.y == null ? 0 : Math.max(2, frac * (W - padL - padR));
        // Colour follows the ENTITY (dataviz non-negotiable), via a CSS var so the
        // theme toggle recolours with no redraw.
        const emphasised = ch.emphasis && p.entity === ch.emphasis;
        const fill = (ch.emphasis && !emphasised) ? 'var(--muted)' : `var(--series-${(p.entity != null ? entityIdx(p.entity) : i) + 1}, var(--series-1))`;
        const label = `<text x="${padL - 12}" y="${y + 20}" text-anchor="end" class="bar-label">${esc(p.x)}</text>`;
        if (p.y == null) return `${label}<text x="${padL}" y="${y + 20}" class="bar-label">no data</text>`;
        return `${label}<rect x="${padL}" y="${y + 5}" width="${barW.toFixed(1)}" height="${rowH - 12}" rx="4" fill="${fill}"/>`
          + `<text x="${(padL + barW + 10).toFixed(1)}" y="${y + 20}" class="bar-value">${esc(p.y)}</text>`;
      }).join('');

      const rows = pts.map(p =>
        `<tr><th scope="row">${esc(p.x)}</th><td class="num">${p.y == null ? 'no data' : esc(p.y)}${p.claim ? cites([p.claim]) : ''}</td></tr>`
      ).join('');

      H.push('<div class="card">');
      H.push(`<p class="chart-title">${esc(ch.title)}${cites(ch.source_claims)}</p>`);
      H.push('<figure class="chart">');
      if (ch.subtitle) H.push(`<figcaption>${esc(ch.subtitle)}</figcaption>`);
      H.push(`<svg viewBox="0 0 ${W} ${height}" width="100%" height="${height}" role="img" aria-label="${esc(desc)}">`);
      H.push(marks);
      H.push(`<line x1="${padL}" y1="${padT}" x2="${padL}" y2="${height - 6}" stroke="var(--baseline)" stroke-width="1"/>`);
      H.push('</svg>');
      // A declared truncation is stated in the OUTPUT, not just in the IR.
      if (ax.axis_truncated === true)
        H.push(`<p class="axis-note">⚠ Axis truncated at ${esc(ax.y_min)} — ${esc(ax.truncation_rationale || 'rationale not recorded')}. Bar lengths are not proportional to values.</p>`);
      H.push(`<details class="tableview"${den.tablesOpen ? ' open' : ''}><summary>Data table</summary><table>`);
      H.push(`<thead><tr><th scope="col">${esc(ax.x_label || 'Item')}</th><th scope="col" class="num">${esc(ax.y_label || 'Value')}</th></tr></thead><tbody>${rows}</tbody>`);
      H.push('</table></details></figure></div>');
    }
    H.push('</section>');
  }

  const listSection = (title, arr, fmt, cls) => {
    if (!arr?.length) return;
    H.push(`<section><h2>${esc(title)}</h2><div class="card${cls ? ` ${cls}` : ''}"><ul class="items">`);
    for (const it of arr) H.push(`<li>${fmt(it)}</li>`);
    H.push('</ul></div></section>');
  };

  listSection('Insights', ir.insights, i => `${esc(i.text)}${cites(i.source_claims)}`);
  listSection('Risks', ir.risks, r =>
    `${r.severity ? `<span class="tag st-${esc(r.severity)}">${STATUS_ICON[r.severity] || '•'} ${esc(r.severity)}</span>` : ''}`
    + `${esc(r.text)}${cites(r.source_claims)}`
    + `${r.mitigation ? `<div class="meta" style="margin-top:5px">Mitigation: ${esc(r.mitigation)}</div>` : ''}`);
  listSection('Opportunities', ir.opportunities, o => `${esc(o.text)}${cites(o.source_claims)}`);
  listSection('Gaps', ir.gaps, g => `${esc(g.text)}${cites(g.source_claims)}`);
  listSection('Recommendations', ir.recommendations, r =>
    `${r.priority ? `<span class="tag">${esc(r.priority)}</span>` : ''}${esc(r.text)}${cites(r.source_claims)}`
    + `<div class="meta" style="margin-top:5px">Owner: ${esc(r.owner)} · ETA: ${esc(r.eta)}${r.effort ? ` · Effort: ${esc(r.effort)}` : ''}</div>`);

  listSection('Not checked', ir.not_checked, n =>
    `${esc(n.text)}<div class="meta" style="margin-top:5px">${esc(n.reason)}${n.impact ? ` · potential impact on the conclusion: ${esc(n.impact)}` : ''}</div>`,
    'notchecked');

  if (ir.methodology) {
    H.push('<section><h2>Methodology</h2><div class="card">');
    H.push(`<p style="margin:0">${esc(ir.methodology.approach)}</p>`);
    const bits = [];
    if (ir.methodology.sources_consulted != null) bits.push(`Sources consulted: ${ir.methodology.sources_consulted}`);
    if (ir.methodology.window) bits.push(`Window: ${ir.methodology.window.from || '?'} → ${ir.methodology.window.to || '?'}`);
    for (const l of ir.methodology.limitations || []) bits.push(`Limitation: ${l}`);
    if (bits.length) H.push(`<ul class="items" style="margin-top:10px">${bits.map(b => `<li>${esc(b)}</li>`).join('')}</ul>`);
    H.push('</div></section>');
  }

  // evidence — every citation lands here
  H.push('<section><h2>Evidence</h2><div class="card"><table>');
  H.push('<thead><tr><th scope="col">id</th><th scope="col">Claim</th><th scope="col">Source</th><th scope="col">As of</th><th scope="col">Confidence</th></tr></thead><tbody>');
  for (const c of ir.claims || []) {
    const src = c.source?.url
      ? `<a href="${esc(c.source.url)}" rel="noopener noreferrer">${esc(c.source.label)}</a>`
      : esc(c.source?.label || '—');
    H.push(`<tr id="claim-${esc(c.id)}"><th scope="row"><code class="cid">${esc(c.id)}</code></th>`
      + `<td>${esc(c.text)}${c.contested ? '<span class="tag st-warning" style="margin-left:8px">▲ contested</span>' : ''}</td>`
      + `<td>${src}</td><td style="white-space:nowrap">${esc(c.as_of)}</td><td style="white-space:nowrap">${esc(c.confidence)}</td></tr>`);
  }
  H.push('</tbody></table></div></section>');

  H.push(`<footer class="foot">Question: ${esc(ir.question)}<br>`
    + 'Rendered by research-dossier — provenance and palette gates passed before this file was written.</footer>');

  return H.join('\n');
}

function renderHtml(ir) {
  const tplPath = join(SKILL_DIR, 'templates', 'dossier.html');
  if (!existsSync(tplPath)) {
    WARN('TEMPLATE_MISSING', `fallback template not found at ${tplPath} — html skipped`);
    return null;
  }
  const tpl = readFileSync(tplPath, 'utf8');
  const pal = resolvePalette(ir);
  const vars = list => list.map((hex, i) => `--series-${i + 1}: ${hex};`).join(' ');

  // Every substitution is GLOBAL. A single-match .replace() here was a real bug:
  // the template's own header comment named the placeholders, so the first match
  // was the documentation and the live slot went unfilled — producing a page that
  // looked plausible while carrying no dossier at all. Global replace plus the
  // assertion below makes that failure mode structurally impossible rather than
  // merely fixed once.
  const html = tpl
    .replace(/\/\*__PALETTE_VARS_LIGHT__\*\//g, vars(pal.light))
    .replace(/\/\*__PALETTE_VARS_DARK__\*\//g, vars(pal.dark))
    .replace(/__LANG__/g, 'en')
    .replace(/__TITLE__/g, esc(ir.title || ir.question))
    .replace(/<!--__BODY__-->/g, renderHtmlBody(ir))
    // A literal </script> inside the JSON island would close the tag early.
    .replace(/<!--__IR_JSON__-->/g, JSON.stringify(ir).replace(/</g, '\\u003c'));

  const survivors = [...new Set(html.match(/__[A-Z_]+__/g) || [])];
  if (survivors.length) {
    FAIL('TEMPLATE_SLOT_UNFILLED',
      `template placeholders survived substitution: ${survivors.join(', ')} — the output would look plausible while carrying no data`);
    return null;
  }
  return html;
}

// ═══════════════════════════════════════════════════════════════════════════
// main
// ═══════════════════════════════════════════════════════════════════════════
function main() {
  const a = parseArgs(process.argv.slice(2));

  if (a.help || !a.ir) {
    console.log(`research-dossier-render — IR to multi-format, behind two f=0 gates

  --ir <path>          IR JSON (required)
  --formats <list>     html,md,json          [default: html,md,json]
  --out <dir>          output directory      [default: out]
  --gates-only         run both gates, render nothing
  --strict             a missing dataviz validator FAILS instead of warning
  --quiet              suppress the report on success

Env: DATAVIZ_VALIDATOR   explicit validator path (nonexistent => exercises degradation)
Exit: 0 ok · 1 gate failure · 2 usage/IO`);
    return a.help ? EXIT_OK : EXIT_USAGE;
  }
  if (a.unknown) { console.error(`unknown flag: ${a.unknown}`); return EXIT_USAGE; }

  let ir;
  try {
    ir = JSON.parse(readFileSync(a.ir, 'utf8'));
  } catch (e) {
    console.error(`✗ cannot read IR: ${e.message}`);
    return EXIT_USAGE;
  }

  gateProvenance(ir);
  const paletteInfo = gatePalette(ir, a);

  const failed = report.fail.length > 0;
  const show = failed || !a.quiet;

  if (show) {
    console.log('');
    console.log(`research-dossier · gates  (${a.ir})`);
    for (const i of report.info) console.log(`  ·  ${i}`);
    console.log(`  ${failed ? '[FAIL]' : '[PASS]'} Gate 1 — provenance      ${report.fail.filter(f => !f.code.startsWith('PALETTE')).length} failure(s)`);
    console.log(`  ${report.fail.some(f => f.code.startsWith('PALETTE')) ? '[FAIL]' : (report.warn.some(w => w.code.startsWith('PALETTE')) ? '[WARN]' : '[PASS]')} Gate 2 — palette (dataviz)  ${paletteInfo.validator ? 'validated light + dark' : 'NOT VALIDATED'}`);
    for (const f of report.fail) console.log(`    ✗ ${f.code}  ${f.msg}`);
    for (const w of report.warn) console.log(`    ⚠ ${w.code}  ${w.msg}`);
    console.log('');
  }

  if (failed) {
    console.log(`  → BUILD FAILED — ${report.fail.length} gate failure(s); nothing rendered.`);
    console.log('');
    return EXIT_GATE;
  }
  if (a.gatesOnly) {
    if (show) console.log('  → GATES PASS (--gates-only; nothing rendered)\n');
    return EXIT_OK;
  }

  mkdirSync(a.out, { recursive: true });
  const written = [];
  for (const fmt of a.formats) {
    try {
      if (fmt === 'json') {
        const p = join(a.out, 'dossier.json');
        writeFileSync(p, JSON.stringify(ir, null, 2)); written.push(p);
      } else if (fmt === 'md') {
        const p = join(a.out, 'dossier.md');
        writeFileSync(p, renderMarkdown(ir)); written.push(p);
      } else if (fmt === 'html') {
        const html = renderHtml(ir);
        if (html) { const p = join(a.out, 'dossier.html'); writeFileSync(p, html); written.push(p); }
      } else if (['pdf', 'pptx', 'xlsx'].includes(fmt)) {
        // Handed off, not reimplemented: make-pdf / document-skills own these.
        const p = join(a.out, `handoff.${fmt}.json`);
        writeFileSync(p, JSON.stringify({
          format: fmt, ir_path: resolve(a.ir),
          via: { pdf: 'make-pdf (or print-CSS from dossier.html)', pptx: 'document-skills:pptx (fallback marp-cli)', xlsx: 'document-skills:xlsx (fallback csv)' }[fmt],
          note: 'gates already passed; this manifest is the handoff contract',
        }, null, 2));
        written.push(p);
      } else {
        WARN('UNKNOWN_FORMAT', `unknown format "${fmt}" — skipped`);
      }
    } catch (e) {
      console.error(`✗ render ${fmt}: ${e.message}`);
      return EXIT_USAGE;
    }
  }

  if (show) {
    console.log('  → GATES PASS');
    for (const w of report.warn) console.log(`    ⚠ ${w.code}`);
    for (const p of written) console.log(`    wrote ${p}`);
    console.log('');
  }
  return EXIT_OK;
}

process.exit(main());
