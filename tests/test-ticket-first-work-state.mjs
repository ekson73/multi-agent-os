/** Opt-in conformance smoke against an already installed claude-mem source tree.
 * No live worker/MCP calls. All writes use a temporary synthetic database.
 * Run: MAOS_CLAUDE_MEM_SOURCE=<checkout> bun tests/test-ticket-first-work-state.mjs
 */
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';

const source = process.env.MAOS_CLAUDE_MEM_SOURCE;
assert.ok(source, 'Set MAOS_CLAUDE_MEM_SOURCE to an already installed source checkout; nothing is installed by this test');
const phase = process.argv[2];
if (!phase) {
  const fixture = mkdtempSync(join(tmpdir(), 'maos-ticket-first-'));
  try {
    // Distinct processes prove recovery without a retained handle, locator or seed.
    for (const step of ['write', 'resume']) {
      const result = spawnSync(process.execPath, [fileURLToPath(import.meta.url), step, fixture], {
        encoding: 'utf8',
        env: { ...process.env, MAOS_CLAUDE_MEM_SOURCE: resolve(source),
          CLAUDE_MEM_DATA_DIR: join(fixture, 'provider-data'), HOME: fixture },
      });
      assert.equal(result.status, 0, `${step}: ${result.error ?? ''}\n${result.stderr}\n${result.stdout}`);
      process.stdout.write(result.stdout);
    }
    console.log('PASS: actual storage/renderer conformance; MCP scope and deployment are NOT verified');
  } finally {
    rmSync(fixture, { recursive: true, force: true });
  }
} else {
  assert.ok(['write', 'resume'].includes(phase), 'Unknown test phase');
  const fixture = process.argv[3];
  const { Database } = await import('bun:sqlite');
  const load = (name) => import(pathToFileURL(join(source, name)).href);
  const store = await load('src/services/sqlite/work-state.ts');
  const renderer = await load('src/services/context/sections/WorkStateRenderer.ts');
  const dbPath = join(fixture, 'synthetic.sqlite');
  const db = new Database(dbPath);
  const project = 'maos-ticket-first-fixture';
  const list = 'pending-ticket:synthetic-484';
  const record = {
    local_id: 'synthetic-484', intent: 'Synthetic offline task',
    acceptance_criteria: '["Recover without a seed"]', dependencies: '[]',
    owner: 'fixture', destination: 'unknown', visibility: 'unknown',
    ticket_status: 'pending', status: 'todo', reason: 'Provider unavailable',
    updated_at: '2026-01-01T00:00:00.000Z', retry_condition: 'Provider available',
    canonical_url: null,
  };
  // Fixture conforms to the documented provider input boundary; this is not an
  // implementation of an adapter or a substitute for the provider HTTP validator.
  assert.ok(JSON.stringify(record).length <= 2000);
  assert.equal(Object.hasOwn(record, 'task'), false);
  const read = () => store.getWorkStateEntries(db, [project], list);
  const append = (fields) => store.appendWorkStateEntry(db, { project, listName: list, fields });
  try {
    if (phase === 'write') {
      store.createWorkStateSchema(db);
      append(record);
      assert.deepEqual(renderer.foldWorkStateList(read()).state, record);
      // Force startup truncation. The cold recovery test must not depend on it.
      for (let n = 0; n < 80; n++) {
        store.appendWorkStateEntry(db, { project, listName: `other-list-${n}`,
          fields: { status: 'todo', note: 'synthetic '.repeat(15) } });
      }
      store.appendWorkStateEntry(db, { project: 'different-domain', listName: list,
        fields: { status: 'todo', intent: 'Not in the authorized fixture project' } });
      console.log('PASS: append and complete field read-back');
    } else {
      // Enumerate the project index without the stored list name or a seed.
      const indexed = store.getWorkStateEntries(db, [project]);
      const found = [...new Set(indexed.map(row => row.list_name))]
        .filter(name => name.startsWith('pending-ticket:'));
      assert.deepEqual(found, [list]);
      assert.ok(indexed.every(row => row.project === project));
      assert.deepEqual(store.getWorkStateEntries(db, ['unknown-project']), []);
      const startup = renderer.buildWorkStateContextSection(indexed, Date.now());
      assert.ok(startup.includes('more lines'));
      assert.ok(!startup.includes(list), 'Fixture must exercise a truncated-away pending record');
      assert.deepEqual(renderer.foldWorkStateList(read()).state, record);
      assert.ok(!renderer.renderWorkStateLines(read(), Date.now(), true).join('\n').includes('canonical_url='));
      append({ ticket_status: 'error', reason: 'Synthetic timeout; reconcile before create' });
      assert.equal(renderer.foldWorkStateList(read()).state.status, 'todo');
      assert.equal(renderer.foldWorkStateList(read()).state.ticket_status, 'error');
      for (const terminal of ['resolved', 'duplicate']) {
        append({ ticket_status: terminal, status: 'done', canonical_url: 'https://example.invalid/ticket/484' });
        assert.deepEqual(renderer.renderWorkStateLines(read(), Date.now()), []);
        const closed = renderer.renderWorkStateLines(read(), Date.now(), true).join('\n');
        assert.ok(closed.includes(`ticket_status=${terminal}`));
        assert.ok(closed.includes('canonical_url=https://example.invalid/ticket/484'));
      }
      append({ ticket_status: 'cancelled', status: 'dropped', reason: 'Synthetic explicit cancellation', canonical_url: null });
      const cancelled = renderer.foldWorkStateList(read()).state;
      assert.equal(cancelled.canonical_url, null);
      assert.equal(cancelled.reason, 'Synthetic explicit cancellation');
      assert.ok(!renderer.renderWorkStateLines(read(), Date.now(), true).join('\n').includes('canonical_url='));
      assert.deepEqual(renderer.renderWorkStateLines(read(), Date.now()), []);
      assert.equal(read().length, 5, 'Append-only audit entries must survive closure');
      const readonly = new Database(dbPath, { readonly: true });
      try {
        assert.throws(() => store.appendWorkStateEntry(readonly, { project, listName: list, fields: { reason: 'Must not persist' } }));
      } finally {
        readonly.close();
      }
      assert.equal(read().length, 5, 'Failed write must not be mistaken for persistence');
      console.log('PASS: cold indexed recovery despite startup truncation, isolation, terminal history, cleared URL, failed write');
    }
  } finally {
    db.close();
  }
}
