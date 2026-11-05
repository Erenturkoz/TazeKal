import test from 'node:test';
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { contentIssues, inside, pathIssue } from './repo-audit.mjs';

test('Local credentials and generated artifacts cannot be exported', () => {
  for (const path of ['backend/.env', 'backend/.env.before-port-change', 'mobile/config/local.json', 'mobile/config/private.local.json', 'client_secret_download.json', '.npmrc', 'backup.dump', 'mobile/build/app.apk', 'data/raw/download.json', 'local-data/receipts/receipt.png', 'github-upload/copy/README.md', 'cert.pfx', 'mobile/ios/Flutter/Generated.xcconfig']) assert.ok(pathIssue(path), path);
});
test('Examples cannot bypass forbidden directories or private file extensions', () => {
  assert.ok(pathIssue('mobile/build/config.example.json'));
  assert.ok(pathIssue('private.example.key'));
  assert.ok(pathIssue('backend/.env.secret.example.txt'));
});
test('Source, lockfiles, migrations and documented configuration examples remain eligible', () => {
  for (const path of ['backend/.env.example', 'backend/.env.production.example', 'mobile/config/development.example.json', 'mobile/ios/Flutter/Google.example.xcconfig', 'backend/package-lock.json', 'mobile/pubspec.lock', 'backend/src/schema.sql', 'mobile/lib/main.dart', 'mobile/android/app/src/main/res/mipmap-hdpi/ic_launcher.png', '.github/workflows/ci.yml']) assert.equal(pathIssue(path), null, path);
});
test('Secret matches expose reason and location but never the matched value', () => {
  const token = ['ghp', 'x'.repeat(36)].join('_');
  const matches = contentIssues('first line\n' + token);
  assert.deepEqual(matches, [{ line: 2, reason: 'GitHub token' }]);
  assert.ok(!JSON.stringify(matches).includes(token));
  assert.equal(contentIssues(['-----BEGIN ', 'PRIVATE KEY-----'].join('')).length, 1);
  assert.equal(contentIssues('JWT_SECRET=replace-with-a-random-secret').length, 0);
});
test('Unsafe paths and sibling directories cannot escape the export root', () => {
  assert.ok(pathIssue('../outside.txt'));
  assert.ok(pathIssue('C:/private.txt'));
  assert.ok(pathIssue('backend/file.txt:secret'));
  const parent = resolve('test-parent');
  assert.equal(inside(parent, resolve(parent, 'safe/file.txt')), true);
  assert.equal(inside(parent, resolve(parent, '../test-parent-other/file.txt')), false);
});
