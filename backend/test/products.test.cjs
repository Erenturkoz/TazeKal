require('reflect-metadata');
const { test } = require('node:test');
const assert = require('node:assert/strict');
const { readFileSync } = require('node:fs');
const { randomUUID } = require('node:crypto');
const { newDb } = require('pg-mem');
const { Test } = require('@nestjs/testing');
const request = require('supertest');
const { AppModule, configureHttp } = require('../dist/app.module');
const { DATABASE } = require('../dist/store');
const { SETTINGS } = require('../dist/google');

async function setup(t) {
  let pool, admin, schema;
  if (process.env.TEST_DATABASE_URL) {
    const { Pool } = require('pg'); schema = 'test_' + randomUUID().replaceAll('-', '');
    admin = new Pool({ connectionString: process.env.TEST_DATABASE_URL }); await admin.query('CREATE SCHEMA ' + schema);
    pool = new Pool({ connectionString: process.env.TEST_DATABASE_URL, options: '-c search_path=' + schema });
    await pool.query(readFileSync('src/schema.sql', 'utf8'));
  } else {
    const db = newDb(); db.public.none(readFileSync('src/schema.sql', 'utf8')); const { Pool } = db.adapters.createPg(); pool = new Pool();
  }
  const config = { secret: 'a-test-only-secret-that-is-at-least-32-characters', databaseUrl: 'memory', port: 3000, googleIds: [], origins: [] };
  const module = await Test.createTestingModule({ imports: [AppModule] }).overrideProvider(DATABASE).useValue(pool).overrideProvider(SETTINGS).useValue(config).compile();
  const app = module.createNestApplication(); configureHttp(app); await app.init();
  t.after(async () => { await app.close(); if (admin) { await admin.query('DROP SCHEMA ' + schema + ' CASCADE'); await admin.end(); } });
  const api = request(app.getHttpServer());
  const account = async email => (await api.post('/v1/auth/register').send({ email, displayName: 'Test', password: 'a-strong-password' }).expect(201)).body;
  const push = (session, mutations) => api.post('/v1/products/sync').auth(session.accessToken, { type: 'bearer' }).send({ mutations });
  const pull = (session, after = 0, limit = 200) => api.get(`/v1/products/changes?after=${after}&limit=${limit}`).auth(session.accessToken, { type: 'bearer' });
  return { api, pool, account, push, pull };
}
const product = (id = 'milk', name = 'Süt') => ({ id, name, quantity: '1 L', location: 'Buzdolabı', purchased_at: '2026-11-01', expires_at: '2026-11-10',
  opened_at: null, after_opening_days: null, status: 'active', opening_profile_id: 'milk_uht_v1', cold_storage_confirmed: 1 });
const mutation = (p = product(), baseVersion = 0, deleted = false) => ({ mutationId: randomUUID(), productId: p.id, baseVersion, deleted, product: deleted ? null : p });

test('Unknown and estimated expiry metadata round trip, while inconsistent date sources are rejected', async t => {
  const { account, push, pull } = await setup(t), a = await account('dates@example.com');
  const unknown = { ...product('unknown'), expires_at: null, expiry_source: 'unknown' };
  const estimated = { ...product('estimate'), expires_at: '2026-11-06', expiry_source: 'estimated', shelf_life_profile_id: 'fresh_milk_v1' };
  await push(a, [mutation(unknown), mutation(estimated)]).expect(201);
  const rows = (await pull(a).expect(200)).body.changes;
  assert.equal(rows.find(r => r.id === 'unknown').product.expires_at, null);
  assert.equal(rows.find(r => r.id === 'estimate').product.expiry_source, 'estimated');
  await push(a, [mutation({ ...product('bad'), expires_at: null, expiry_source: 'label' })]).expect(400);
  await push(a, [mutation({ ...product('bad'), expiry_source: 'estimated' })]).expect(400);
  await push(a, [mutation({ ...product('bad'), expiry_source: 'unknown' })]).expect(400);
});

test('Product API requires a live session, derives ownership, and isolates identical product IDs', async t => {
  const { api, account, push, pull } = await setup(t);
  const a = await account('a@example.com'), b = await account('b@example.com');
  await api.get('/v1/products/changes').expect(401);
  await api.post('/v1/products/sync').send({ mutations: [] }).expect(401);
  await push(a, [mutation()]).expect(201);
  const empty = await pull(b).expect(200); assert.deepEqual(empty.body, { changes: [], cursor: 0, hasMore: false });
  await push(b, [mutation(product('milk', 'B hesabı sütü'))]).expect(201);
  assert.equal((await pull(a).expect(200)).body.changes[0].product.name, 'Süt');
  assert.equal((await pull(b).expect(200)).body.changes[0].product.name, 'B hesabı sütü');
  await api.post('/v1/products/sync').auth(a.accessToken, { type: 'bearer' }).send({ userId: b.user.id, mutations: [] }).expect(400);
  await push(a, [mutation({ ...product('other'), owner_id: b.user.id })]).expect(400);
  await api.post('/v1/auth/logout').auth(a.accessToken, { type: 'bearer' }).expect(204);
  await pull(a).expect(401); await push(a, []).expect(401);
});

test('Lost acknowledgements can be retried without duplicate updates; IDs cannot change payload', async t => {
  const { account, push, pull } = await setup(t), a = await account('a@example.com');
  const op = mutation();
  const first = (await push(a, [op]).expect(201)).body;
  assert.deepEqual((await push(a, [op]).expect(201)).body, first);
  assert.equal((await pull(a).expect(200)).body.cursor, 1);
  await push(a, [{ ...op, product: product('milk', 'Different') }]).expect(409);
  assert.equal((await pull(a).expect(200)).body.changes[0].product.name, 'Süt');
});

test('Concurrent edits preserve the server copy until the client resolves the conflict', async t => {
  const { account, push, pull } = await setup(t), a = await account('a@example.com');
  await push(a, [mutation()]).expect(201);
  const stale = (await push(a, [mutation(product('milk', 'Offline edit'), 0)]).expect(201)).body.results[0];
  assert.equal(stale.outcome, 'conflict'); assert.equal(stale.remote.version, 1); assert.equal(stale.remote.product.name, 'Süt');
  assert.equal((await pull(a).expect(200)).body.changes[0].product.name, 'Süt');
  const chosen = (await push(a, [mutation(product('milk', 'Chosen edit'), 1)]).expect(201)).body.results[0];
  assert.equal(chosen.outcome, 'applied'); assert.equal(chosen.remote.version, 2);
});

test('Deletes travel as tombstones and change pages do not omit the last revision', async t => {
  const { account, push, pull } = await setup(t), a = await account('a@example.com');
  await push(a, [mutation(product('one')), mutation(product('two'))]).expect(201);
  const page1 = (await pull(a, 0, 1).expect(200)).body;
  assert.equal(page1.changes.length, 1); assert.equal(page1.hasMore, true);
  const page2 = (await pull(a, page1.cursor, 1).expect(200)).body;
  assert.equal(page2.changes.length, 1); assert.notEqual(page1.changes[0].id, page2.changes[0].id);
  await push(a, [mutation(product('one'), 1, true)]).expect(201);
  const deletion = (await pull(a, page2.cursor).expect(200)).body.changes[0];
  assert.equal(deletion.id, 'one'); assert.equal(deletion.deleted, true); assert.equal(deletion.product, null); assert.equal(deletion.version, 2);
  await pull(a, 999).expect(409);
});

test('Invalid dates, versions and mixed invalid batches never store a partial request', async t => {
  const { account, push, pull } = await setup(t), a = await account('a@example.com');
  await push(a, [mutation(product('valid')), mutation({ ...product('invalid'), opened_at: '2026-02-30' })]).expect(400);
  assert.equal((await pull(a).expect(200)).body.changes.length, 0);
  await push(a, [{ ...mutation(), baseVersion: -1 }]).expect(400);
  await push(a, [{ ...mutation(), product: null }]).expect(400);
  await push(a, [{ ...mutation(), deleted: true }]).expect(400);
  await pull(a, '-1').expect(400);
  await pull(a, 0, 201).expect(400);
});

test('PostgreSQL account lock serializes parallel writers', { skip: !process.env.TEST_DATABASE_URL }, async t => {
  const { account, push, pull } = await setup(t), a = await account('a@example.com');
  const results = await Promise.all([push(a, [mutation()]).expect(201), push(a, [mutation(product('milk', 'Other device'))]).expect(201)]);
  assert.deepEqual(results.map(r => r.body.results[0].outcome).sort(), ['applied', 'conflict']);
  assert.equal((await pull(a).expect(200)).body.cursor, 1);
});
