import { execFileSync } from 'node:child_process';
import { lstatSync, readFileSync, realpathSync } from 'node:fs';
import { isAbsolute, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = realpathSync(fileURLToPath(new URL('../', import.meta.url)));
export const gitPaths = (...args) => execFileSync('git', [...args, '-z'], { cwd: root, encoding: 'utf8' }).split('\0').filter(Boolean);
export const candidatePaths = () => [...new Set(gitPaths('ls-files', '--cached', '--others', '--exclude-standard'))].sort();
const forbiddenDirectory = /(^|\/)(\.git|node_modules|\.dart_tool|build|dist|coverage|\.gradle|\.cxx|backups|Pods|DerivedData|xcuserdata|__pycache__|\.cache|\.pub-cache|\.pub|test-results|playwright-report|github-upload|local-data|\.venv|venv|\.pytest_cache|\.mypy_cache|\.ruff_cache|\.agents|\.codex)(\/|$)/i;
export function pathIssue(path) {
  if (isAbsolute(path) || path.includes('\\') || path.split('/').some(p => p === '..' || p === '.') || path.includes(':')) return 'unsafe relative path';
  if (forbiddenDirectory.test(path) || /^data\/raw\//i.test(path)) return 'local/generated directory';
  if (/\.(apk|aab|ipa|db(?:-shm|-wal|-journal)?|sqlite(?:3)?(?:-shm|-wal)?|dump|sql\.gz|jks|keystore|pem|key|p12|p8|pfx|mobileprovision|hprof|dmp|zip|7z|tar|tgz|bak|orig|rej)$/i.test(path)) return 'private data, signing material or generated artifact';
  const base = path.split('/').at(-1);
  const example = /^\.env(?:\.[\w-]+)?\.example$/.test(base) || /\.example\.(json|xcconfig)$/.test(base);
  if (!example && (/^\.env(?:$|\.)/.test(base) || /^(?:\.npmrc|\.pypirc|\.netrc|\.envrc|auth\.json|google-services\.json|GoogleService-Info\.plist|local\.properties|key\.properties)$/i.test(base)
    || /^(?:credentials|secrets|client_secret|oauth-client).*\.json$/i.test(base)
    || /service[-_]account.*\.json$/i.test(base) || /\.local\.(json|xcconfig)$/.test(base)
    || /(^|\/)config\/local[^/]*\.json$/i.test(path))) return 'local configuration or credentials';
  if (/\.(log|tmp|temp|pyc|tsbuildinfo|xcuserstate)$/i.test(base) || /(^|\/)Flutter\/(Generated\.xcconfig|flutter_export_environment\.sh)$/.test(path)) return 'generated output';
  return null;
}

// Findings expose locations and detector names, never matched credential values.
const detectors = [
  ['private key', /-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----/],
  ['GitHub token', /\b(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{50,})\b/],
  ['Google API key', /\bAIza[A-Za-z0-9_-]{35}\b/],
  ['Google OAuth client secret', /\bGOCSPX-[A-Za-z0-9_-]{20,}\b/],
  ['AWS access key', /\b(?:AKIA|ASIA)[A-Z0-9]{16}\b/],
  ['Slack token', /\bxox[baprs]-[A-Za-z0-9-]{20,}\b/],
  ['OpenAI-style API key', /\bsk-(?:proj-|svcacct-)?[A-Za-z0-9_-]{24,}\b/],
  ['JWT token', /\beyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{16,}\b/],
];
export function contentIssues(text) {
  const findings = [];
  text.split(/\r?\n/).forEach((line, index) => {
    for (const [kind, pattern] of detectors) if (pattern.test(line)) findings.push({ line: index + 1, reason: kind });
  });
  return findings;
}
export function inside(parent, target) {
  const path = relative(parent, target);
  return path !== '..' && !path.startsWith('../') && !path.startsWith('..\\') && !isAbsolute(path);
}
export function auditRepository() {
  const files = candidatePaths(), issues = [];
  for (const path of files) {
    const reason = pathIssue(path);
    if (reason) { issues.push({ path, reason }); continue; }
    const absolute = resolve(root, path);
    try {
      if (lstatSync(absolute).isSymbolicLink() || !inside(root, realpathSync(absolute))) {
        issues.push({ path, reason: 'symlink or file outside repository' }); continue;
      }
      const data = readFileSync(absolute);
      if (!data.includes(0)) issues.push(...contentIssues(data.toString('utf8')).map(f => ({ path, ...f })));
    } catch { issues.push({ path, reason: 'unreadable or missing file; review index/working tree' }); }
  }
  for (const path of gitPaths('ls-files', '-ci', '--exclude-standard')) issues.push({ path, reason: 'already tracked despite ignore rule' });
  return { files, issues };
}
export function reportIssues(issues) {
  for (const item of issues) console.error(`${item.path}${item.line ? ':' + item.line : ''}: ${item.reason}`);
}
