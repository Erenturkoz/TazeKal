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
const { SETTINGS, GoogleVerifier } = require('../dist/google');
const { hashPassword, checkPassword } = require('../dist/crypto');
const { TERMS_VERSION } = require('../dist/auth.service');

async function setup(t) {
  let pool, admin, schema;
  if (process.env.TEST_DATABASE_URL) {
    const { Pool } = require('pg');
    schema = 'test_' + randomUUID().replaceAll('-', '');
    admin = new Pool({ connectionString: process.env.TEST_DATABASE_URL });
    await admin.query('CREATE SCHEMA ' + schema);
    pool = new Pool({ connectionString: process.env.TEST_DATABASE_URL, options: '-c search_path=' + schema });
    await pool.query(readFileSync('src/schema.sql', 'utf8'));
  } else {
    const memory = newDb();
    memory.public.none(readFileSync('src/schema.sql', 'utf8'));
    const { Pool } = memory.adapters.createPg();
    pool = new Pool();
  }
  const config = { secret: 'a-test-only-secret-that-is-at-least-32-characters', databaseUrl: 'memory', port: 3000, googleIds: ['test-client'], origins: [] };
  const identities = new Map();
  const module = await Test.createTestingModule({ imports: [AppModule] })
    .overrideProvider(DATABASE).useValue(pool).overrideProvider(SETTINGS).useValue(config)
    .overrideProvider(GoogleVerifier).useValue({ verify: async token => {
      const identity = identities.get(token);
      if (!identity) { const { UnauthorizedException } = require('@nestjs/common'); throw new UnauthorizedException(); }
      return identity;
    } }).compile();
  const app = module.createNestApplication(); configureHttp(app); await app.init();
  t.after(async () => { await app.close(); if (admin) { await admin.query('DROP SCHEMA ' + schema + ' CASCADE'); await admin.end(); } });
  const api = request(app.getHttpServer());
  const register = async (email = 'eren@example.com') => (await api.post('/v1/auth/register').send({ email, displayName: 'Eren', password: 'a-strong-password', acceptedTermsVersion: TERMS_VERSION }).expect(201)).body;
  return { api, pool, identities, register };
}
test('Password hashes have distinct salts and reject wrong passwords', async () => {
  const a = await hashPassword('a-strong-password'), b = await hashPassword('a-strong-password');
  assert.notEqual(a, b); assert.equal(await checkPassword('a-strong-password', a), true);
  assert.equal(await checkPassword('wrong', a), false);
});
test('Registration, login, profile and public serialization', async t => {
  const { api, register, pool } = await setup(t), session = await register(' EREN@example.com ');
  assert.equal(session.user.email, 'eren@example.com'); assert.equal(session.user.emailVerified, false);
  assert.equal(session.user.password_hash, undefined); assert.equal(session.user.google_sub, undefined);
  const stored = (await pool.query('SELECT * FROM users')).rows[0];
  assert.match(stored.password_hash, /^scrypt\$/); assert.notEqual(stored.password_hash, 'a-strong-password');
  await api.post('/v1/auth/login').send({ email: 'eren@example.com', password: 'incorrect' }).expect(401);
  const login = await api.post('/v1/auth/login').send({ email: 'EREN@example.com', password: 'a-strong-password' }).expect(200);
  await api.patch('/v1/users/me').auth(login.body.accessToken, { type: 'bearer' }).send({ displayName: 'Eren Yeni' }).expect(200);
  const profile = await api.get('/v1/users/me').auth(login.body.accessToken, { type: 'bearer' }).expect(200);
  assert.equal(profile.body.displayName, 'Eren Yeni');
});
test('Refresh is rotated, cannot be replayed, and logout revokes access immediately', async t => {
  const { api, register } = await setup(t), session = await register();
  const next = await api.post('/v1/auth/refresh').send({ refreshToken: session.refreshToken }).expect(200);
  assert.notEqual(next.body.refreshToken, session.refreshToken);
  await api.post('/v1/auth/refresh').send({ refreshToken: session.refreshToken }).expect(401);
  await api.post('/v1/auth/logout').auth(next.body.accessToken, { type: 'bearer' }).expect(204);
  await api.get('/v1/users/me').auth(next.body.accessToken, { type: 'bearer' }).expect(401);
  await api.post('/v1/auth/refresh').send({ refreshToken: next.body.refreshToken }).expect(401);
});
test('Validation and user isolation prevent changing someone else’s profile', async t => {
  const { api, register } = await setup(t), a = await register(), b = await register('other@example.com');
  await api.get('/v1/users/me').expect(401);
  await api.get('/v1/users/me').auth('forged-token', { type: 'bearer' }).expect(401);
  await api.patch('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).send({ displayName: 'Hacked', id: b.user.id }).expect(400);
  await api.patch('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).send({ displayName: 'Only A' }).expect(200);
  const other = await api.get('/v1/users/me').auth(b.accessToken, { type: 'bearer' }).expect(200);
  assert.equal(other.body.displayName, 'Eren');
  await api.post('/v1/auth/register').send({ email: 'bad', displayName: 'A', password: 'weak' }).expect(400);
  await api.post('/v1/auth/register').send({ email: 'eren@example.com', displayName: 'Eren', password: 'a-strong-password', acceptedTermsVersion: TERMS_VERSION }).expect(409);
});
test('Google identity is server-verified and linking requires an existing authenticated account', async t => {
  const { api, identities, register } = await setup(t);
  const token = 'a-valid-google-id-token-for-test';
  identities.set(token, { sub: 'google-123', email: 'eren@example.com', name: 'Google Eren' });
  await api.post('/v1/auth/google').send({ idToken: 'invalid-google-id-token-for-test' }).expect(401);
  const session = await register();
  await api.post('/v1/auth/google').send({ idToken: token }).expect(409);
  await api.post('/v1/auth/google/link').send({ idToken: token }).expect(401);
  await api.post('/v1/auth/google/link').auth(session.accessToken, { type: 'bearer' }).send({ idToken: token }).expect(200);
  const google = await api.post('/v1/auth/google').send({ idToken: token }).expect(200);
  assert.equal(google.body.user.id, session.user.id);
  assert.deepEqual(google.body.user.providers, ['password', 'google']);
  assert.equal(google.body.user.emailVerified, true);
});
test('Google-only registration and wrong-email linking', async t => {
  const { api, identities, register } = await setup(t);
  identities.set('another-valid-google-id-token', { sub: 'another-sub', email: 'another@example.com', name: 'Another' });
  await api.post('/v1/auth/google').send({ idToken: 'another-valid-google-id-token' }).expect(400);
  const created = await api.post('/v1/auth/google').send({ idToken: 'another-valid-google-id-token', acceptedTermsVersion: TERMS_VERSION }).expect(200);
  assert.equal(created.body.user.termsVersion, TERMS_VERSION);
  assert.deepEqual(created.body.user.providers, ['google']);
  const local = await register();
  await api.post('/v1/auth/google/link').auth(local.accessToken, { type: 'bearer' }).send({ idToken: 'another-valid-google-id-token' }).expect(409);
});
test('Login brute-force attempts are throttled', async t => {
  const { api } = await setup(t);
  for (let i = 0; i < 5; i++) await api.post('/v1/auth/login').send({ email: 'none@example.com', password: 'wrong-password' }).expect(401);
  await api.post('/v1/auth/login').send({ email: 'none@example.com', password: 'wrong-password' }).expect(429);
});

test('Registration requires accepting the current Terms of Use and stores the accepted version', async t => {
  const { api, pool } = await setup(t);
  const body = { email: 'terms@example.com', displayName: 'Eren', password: 'a-strong-password' };
  await api.post('/v1/auth/register').send(body).expect(400);
  await api.post('/v1/auth/register').send({ ...body, acceptedTermsVersion: '2000-01-01' }).expect(400);
  await api.post('/v1/auth/register').send({ ...body, acceptedTermsVersion: true }).expect(400);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM users')).rows[0].n, 0);
  const created = await api.post('/v1/auth/register').send({ ...body, acceptedTermsVersion: TERMS_VERSION }).expect(201);
  assert.equal(created.body.user.termsVersion, TERMS_VERSION);
  const row = (await pool.query('SELECT terms_version, terms_accepted_at FROM users')).rows[0];
  assert.equal(row.terms_version, TERMS_VERSION); assert.ok(row.terms_accepted_at);
});
test('Account deletion requires the password, revokes every session and erases the user’s data only', async t => {
  const { api, pool, register } = await setup(t);
  const a = await register('delete-me@example.com'), b = await register('keep-me@example.com');
  const second = (await api.post('/v1/auth/login').send({ email: 'delete-me@example.com', password: 'a-strong-password' }).expect(200)).body;
  const product = { id: 'milk', name: 'Süt', quantity: '1 L', location: 'Buzdolabı', purchased_at: '2026-11-16', expires_at: '2026-11-20', opened_at: null, after_opening_days: null, status: 'active', opening_profile_id: 'milk_uht_v1', cold_storage_confirmed: 1 };
  for (const s of [a, b]) {
    await api.post('/v1/products/sync').auth(s.accessToken, { type: 'bearer' })
      .send({ mutations: [{ mutationId: randomUUID(), productId: 'milk', baseVersion: 0, deleted: false, product }] }).expect(201);
  }
  await api.delete('/v1/users/me').send({ password: 'a-strong-password' }).expect(401);
  await api.delete('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).send({}).expect(403);
  await api.delete('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).send({ password: 'wrong-password' }).expect(403);
  await api.delete('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).send({ password: 'a-strong-password', userId: b.user.id }).expect(400);
  await api.get('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).expect(200);
  await api.delete('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).send({ password: 'a-strong-password' }).expect(204);
  await api.get('/v1/users/me').auth(a.accessToken, { type: 'bearer' }).expect(401);
  await api.get('/v1/users/me').auth(second.accessToken, { type: 'bearer' }).expect(401);
  await api.post('/v1/auth/refresh').send({ refreshToken: second.refreshToken }).expect(401);
  await api.post('/v1/auth/login').send({ email: 'delete-me@example.com', password: 'a-strong-password' }).expect(401);
  for (const table of ['users', 'sessions', 'user_products', 'product_mutations', 'product_sync_heads']) {
    const column = table === 'users' ? 'id' : 'user_id';
    assert.equal((await pool.query(`SELECT count(*)::int AS n FROM ${table} WHERE ${column}=$1`, [a.user.id])).rows[0].n, 0, table);
  }
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM user_products WHERE user_id=$1', [b.user.id])).rows[0].n, 1);
  await api.get('/v1/users/me').auth(b.accessToken, { type: 'bearer' }).expect(200);
  // The e-mail address is free again after deletion.
  await register('delete-me@example.com');
});
test('Google-only accounts confirm deletion with a fresh token for the same Google identity', async t => {
  const { api, pool, identities } = await setup(t);
  identities.set('google-owner-token-for-deletion', { sub: 'owner-sub', email: 'owner@example.com', name: 'Owner' });
  identities.set('google-other-token-for-deletion', { sub: 'other-sub', email: 'other@example.com', name: 'Other' });
  const owner = (await api.post('/v1/auth/google').send({ idToken: 'google-owner-token-for-deletion', acceptedTermsVersion: TERMS_VERSION }).expect(200)).body;
  await api.delete('/v1/users/me').auth(owner.accessToken, { type: 'bearer' }).send({ password: 'anything' }).expect(403);
  await api.delete('/v1/users/me').auth(owner.accessToken, { type: 'bearer' }).send({ idToken: 'invalid-google-token-for-deletion' }).expect(403);
  await api.delete('/v1/users/me').auth(owner.accessToken, { type: 'bearer' }).send({ idToken: 'google-other-token-for-deletion' }).expect(403);
  await api.delete('/v1/users/me').auth(owner.accessToken, { type: 'bearer' }).send({ idToken: 'google-owner-token-for-deletion' }).expect(204);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM users')).rows[0].n, 0);
});
