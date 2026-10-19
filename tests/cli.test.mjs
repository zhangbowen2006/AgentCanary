import test from 'node:test';
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { audit, compare_policies } from '../dist/engine.js';
const run = (...args) => spawnSync(process.execPath, ['bin/agentcanary.mjs', ...args], { encoding: 'utf8' });
const auditArgs = ['audit', '--policy', 'examples/policy.json', '--trace', 'examples/incident.jsonl'];

test('actual incident finds lineage, consent reuse and budget excess', () => {
  const result = run(...auditArgs, '--format', 'json');
  assert.equal(result.status, 0);
  const report = JSON.parse(result.stdout);
  assert.equal(report.calls, 9);
  assert.equal(report.denied, 3);
  assert.deepEqual(report.decisions.find(d => d.event_id === 'external-upload').findings[0].evidence, ['read-private']);
  assert.equal(report.decisions.find(d => d.event_id === 'publish-public').decision, 'allow');
});

test('audit gate fails on denied calls and preserves parseable stdout', () => {
  const result = run(...auditArgs, '--fail-on-deny', '--format', 'json');
  assert.equal(result.status, 1);
  assert.equal(JSON.parse(result.stdout).denied, 3);
});

test('comparison quantifies tightening without replaying real tools', () => {
  const r = run('compare', '--baseline', 'examples/baseline.json', '--candidate', 'examples/policy.json', '--trace', 'examples/incident.jsonl', '--format', 'json', '--fail-on-new-deny');
  assert.equal(r.status, 1);
  assert.equal(JSON.parse(r.stdout).newly_denied, 2);
});

test('stdin trace equals file trace', () => {
  const result = spawnSync(process.execPath, ['bin/agentcanary.mjs', 'audit', '--policy', 'examples/policy.json', '--trace', '-', '--format', 'json'], { encoding: 'utf8', input: readFileSync('examples/incident.jsonl', 'utf8') });
  assert.equal(result.status, 0);
  assert.equal(result.stdout, run(...auditArgs, '--format', 'json').stdout);
});

test('portable regression suite passes', () => {
  const r = run('test', 'examples/regressions.json', '--format', 'json');
  assert.equal(r.status, 0);
  assert.equal(JSON.parse(r.stdout).passed, 2);
});

test('a changed expectation really makes the suite gate fail', () => {
  const dir = mkdtempSync(join(tmpdir(), 'agentcanary-test-'));
  try {
    const suite = JSON.parse(readFileSync('examples/regressions.json', 'utf8'));
    suite.cases[0].expect[2] = { event_id: 'send', decision: 'allow' };
    writeFileSync(join(dir, 'failing.json'), JSON.stringify(suite));
    const result = run('test', join(dir, 'failing.json'), '--format', 'json');
    assert.equal(result.status, 1);
    assert.equal(JSON.parse(result.stdout).failed, 1);
  } finally { rmSync(dir, { recursive: true }); }
});

test('invalid data produces a domain error without raw values', () => {
  const result = JSON.parse(audit(readFileSync('examples/policy.json', 'utf8'), '[{"id":"my-sensitive-value"}]'));
  assert.equal(result.error.code, 'INVALID_INPUT');
  assert.ok(!JSON.stringify(result).includes('my-sensitive-value'));
});

test('strict CLI arguments and missing files return exit 2', () => {
  for (const args of [['audit'], [...auditArgs, '--typo'], [...auditArgs, '--policy', 'x'], [...auditArgs, '--format', 'yaml'], ['audit', '--policy', 'missing.json', '--trace', 'x']]) {
    assert.equal(run(...args).status, 2);
  }
});

test('help and version do not require a trace', () => {
  assert.equal(run('--help').status, 0);
  assert.equal(run('--version').stdout.trim(), '0.1.1');
});

test('repeated pure engine calls are byte deterministic', () => {
  const p = readFileSync('examples/policy.json', 'utf8');
  const t = readFileSync('examples/incident.jsonl', 'utf8');
  assert.equal(audit(p, t), audit(p, t));
  assert.equal(JSON.parse(compare_policies(p, p, t)).changes.length, 0);
});
