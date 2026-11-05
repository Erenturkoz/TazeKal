import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { createHash, randomUUID } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { join, resolve } from 'node:path';
import { auditRepository, pathIssue, reportIssues, root } from './repo-audit.mjs';

const { files, issues } = auditRepository();
if (issues.length) {
  reportIssues(issues);
  console.error('Export stopped: fix audit findings first. No upload was performed.');
  process.exit(1);
}
// Exclusive new directory every time; never erase or overwrite a snapshot.
const parent = join(root, 'github-upload');
mkdirSync(parent, { recursive: true });
const output = join(parent, 'TazeKal-' + new Date().toISOString().replace(/[:.]/g, '-') + '-' + randomUUID().slice(0, 8));
mkdirSync(output);
const manifest = [];
for (const path of files) {
  if (pathIssue(path)) throw new Error('Export rejected a forbidden path');
  const data = readFileSync(resolve(root, path));
  manifest.push({ path, bytes: data.length, sha256: createHash('sha256').update(data).digest('hex') });
}
const manifestPath = join(output, 'manifest.json'), archivePath = join(output, 'TazeKal-source.zip');
writeFileSync(manifestPath, JSON.stringify({ createdAt: new Date().toISOString(), fileCount: manifest.length, files: manifest }, null, 2) + '\n');
execFileSync('powershell.exe', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', join(root, 'tools/write-source-archive.ps1'), '-RepositoryRoot', root, '-ManifestPath', manifestPath, '-ArchivePath', archivePath], { cwd: root, stdio: 'inherit' });
console.log(`Verified export: ${files.length} files`);
console.log(`Source archive: ${archivePath}`);
console.log(`Local inventory: ${manifestPath}`);
console.log('Extract outside the active Flutter workspace, then upload the archive CONTENTS, not the ZIP as a single source file.');
console.log('No commit, network upload, repository creation or push was performed. Regenerate after source changes.');
