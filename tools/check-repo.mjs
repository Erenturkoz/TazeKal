import { auditRepository, reportIssues } from './repo-audit.mjs';
const { files, issues } = auditRepository();
if (issues.length) {
  console.error('Repository audit failed. Secret values are not printed.');
  reportIssues(issues);
  process.exitCode = 1;
} else {
  console.log(`Repository hygiene passed (${files.length} files; paths and recognizable secret formats checked).`);
  console.log('Pattern checks are not a guarantee: review upload contents for other confidential information.');
}
