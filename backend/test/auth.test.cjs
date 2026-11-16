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
  const register = async (email = 'eren@example.com') => (await api.post('/v1/auth/register').send({ email, displayName: 'Eren', password: 'a-strong-password' }).expect(201)).body;
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
  await api.get('/v1/users/me').auth(next.body.accessToken, { type: 'bearer' }).expect(200);
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
  await api.post('/v1/auth/register').send({ email: 'eren@example.com', displayName: 'Eren', password: 'a-strong-password' }).expect(409);
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
  const created = await api.post('/v1/auth/google').send({ idToken: 'another-valid-google-id-token' }).expect(200);
  assert.deepEqual(created.body.user.providers, ['google']);
  const local = await register();
  await api.post('/v1/auth/google/link').auth(local.accessToken, { type: 'bearer' }).send({ idToken: 'another-valid-google-id-token' }).expect(409);
});
test('Login brute-force attempts are throttled', async t => {
  const { api } = await setup(t);
  for (let i = 0; i < 5; i++) await api.post('/v1/auth/login').send({ email: 'none@example.com', password: 'wrong-password' }).expect(401);
  await api.post('/v1/auth/login').send({ email: 'none@example.com', password: 'wrong-password' }).expect(429);
});

const bearer = token => ({ type: 'bearer' });
test('Replaying a rotated refresh token revokes the whole session (stolen-token detection)', async t => {
  const { api, register } = await setup(t), session = await register();
  const next = await api.post('/v1/auth/refresh').send({ refreshToken: session.refreshToken }).expect(200);
  // Attacker (or old copy) replays the previous token: rejected AND the live session is killed.
  await api.post('/v1/auth/refresh').send({ refreshToken: session.refreshToken }).expect(401);
  await api.get('/v1/users/me').auth(next.body.accessToken, bearer()).expect(401);
  await api.post('/v1/auth/refresh').send({ refreshToken: next.body.refreshToken }).expect(401);
});
test('Password change verifies the current password, keeps this device and revokes other devices', async t => {
  const { api, register } = await setup(t), phone = await register();
  const tablet = (await api.post('/v1/auth/login').send({ email: 'eren@example.com', password: 'a-strong-password' }).expect(200)).body;
  await api.post('/v1/auth/password').send({ currentPassword: 'a-strong-password', newPassword: 'another-strong-password' }).expect(401);
  await api.post('/v1/auth/password').auth(phone.accessToken, bearer()).send({ currentPassword: 'wrong-password', newPassword: 'another-strong-password' }).expect(403);
  await api.post('/v1/auth/password').auth(phone.accessToken, bearer()).send({ currentPassword: 'a-strong-password', newPassword: 'short' }).expect(400);
  await api.post('/v1/auth/password').auth(phone.accessToken, bearer()).send({ currentPassword: 'a-strong-password', newPassword: 'a-strong-password' }).expect(400);
  const changed = await api.post('/v1/auth/password').auth(phone.accessToken, bearer()).send({ currentPassword: 'a-strong-password', newPassword: 'another-strong-password' }).expect(200);
  assert.equal(changed.body.revokedSessions, 1); assert.equal(changed.body.user.password_hash, undefined);
  await api.get('/v1/users/me').auth(phone.accessToken, bearer()).expect(200);
  await api.get('/v1/users/me').auth(tablet.accessToken, bearer()).expect(401);
  await api.post('/v1/auth/refresh').send({ refreshToken: tablet.refreshToken }).expect(401);
  await api.post('/v1/auth/login').send({ email: 'eren@example.com', password: 'a-strong-password' }).expect(401);
  await api.post('/v1/auth/login').send({ email: 'eren@example.com', password: 'another-strong-password' }).expect(200);
});
test('Google-only accounts cannot change a password they do not have', async t => {
  const { api, identities } = await setup(t);
  identities.set('google-only-valid-id-token-xx', { sub: 'g-only', email: 'g@example.com', name: 'G' });
  const g = (await api.post('/v1/auth/google').send({ idToken: 'google-only-valid-id-token-xx' }).expect(200)).body;
  await api.post('/v1/auth/password').auth(g.accessToken, bearer()).send({ currentPassword: 'anything', newPassword: 'another-strong-password' }).expect(400);
});
test('Logout from all devices revokes every session of only that user', async t => {
  const { api, register } = await setup(t), a1 = await register(), other = await register('other@example.com');
  const a2 = (await api.post('/v1/auth/login').send({ email: 'eren@example.com', password: 'a-strong-password' }).expect(200)).body;
  await api.post('/v1/auth/logout-all').expect(401);
  await api.post('/v1/auth/logout-all').auth(a1.accessToken, bearer()).expect(204);
  await api.get('/v1/users/me').auth(a1.accessToken, bearer()).expect(401);
  await api.get('/v1/users/me').auth(a2.accessToken, bearer()).expect(401);
  await api.post('/v1/auth/refresh').send({ refreshToken: a2.refreshToken }).expect(401);
  await api.get('/v1/users/me').auth(other.accessToken, bearer()).expect(200);
});
test('Expired sessions are pruned on the next login', async t => {
  const { api, pool, register } = await setup(t), first = await register();
  await pool.query("UPDATE sessions SET expires_at = now() - interval '1 day'");
  await api.get('/v1/users/me').auth(first.accessToken, bearer()).expect(401);
  await api.post('/v1/auth/login').send({ email: 'eren@example.com', password: 'a-strong-password' }).expect(200);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM sessions')).rows[0].n, 1);
});
test('Display names reject control characters and Google names are sanitised', async t => {
  const { api, register } = await setup(t), s = await register();
  await api.patch('/v1/users/me').auth(s.accessToken, bearer()).send({ displayName: 'Eren\u001b[31m' }).expect(400);
  await api.post('/v1/auth/register').send({ email: 'x@example.com', displayName: 'Bad\nName', password: 'a-strong-password' }).expect(400);
  const { googleName } = require('../dist/google');
  assert.equal(googleName('Ayşe\u0000 Yılmaz'), 'Ayşe Yılmaz');
  assert.equal(googleName('A'), 'Taze Kal kullanıcısı');
  assert.equal(googleName(undefined), 'Taze Kal kullanıcısı');
});
test('TRUST_PROXY parsing refuses the spoofable "true" setting', () => {
  const { parseTrustProxy } = require('../dist/config');
  assert.equal(parseTrustProxy(undefined), false); assert.equal(parseTrustProxy('0'), false);
  assert.equal(parseTrustProxy('1'), 1); assert.deepEqual(parseTrustProxy('loopback, 10.0.0.0/8'), ['loopback', '10.0.0.0/8']);
  assert.throws(() => parseTrustProxy('true'));
});
test('Malformed refresh token ids are rejected as 401, not a database error', async t => {
  const { api } = await setup(t);
  await api.post('/v1/auth/refresh').send({ refreshToken: '-'.repeat(36) + '.' + 'x'.repeat(20) }).expect(401);
  await api.post('/v1/auth/refresh').send({ refreshToken: randomUUID() + '.' + 'x'.repeat(20) }).expect(401);
});
