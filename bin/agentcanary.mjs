#!/usr/bin/env node
import { readFileSync, statSync } from 'node:fs';

const help = `AgentCanary 0.1.1 — offline AI tool policy replay

  audit   --policy FILE --trace FILE|- [--format json|text] [--fail-on-deny]
  compare --baseline FILE --candidate FILE --trace FILE|- [--format json|text]
          [--fail-on-new-deny] [--fail-on-new-allow]
  test    SUITE.json [--format json|text]

Exit codes: 0 passed, 1 policy/regression gate failed, 2 invalid input or setup.
Reports omit resource paths and raw payloads. No tools or network calls are executed.`;

function parse(args) {
  if (args.length === 0 || args.includes('--help') || args[0] === 'help') return { help: true };
  if (args[0] === '--version') return { version: true };
  const command = args.shift();
  if (!['audit', 'compare', 'test'].includes(command)) throw new Error('Unknown command. Use --help.');
  const result = { command, format: 'text' };
  if (command === 'test') {
    if (!args[0] || args[0].startsWith('--')) throw new Error('test requires a suite filename.');
    result.suite = args.shift();
  }
  const valued = new Set(command === 'audit' ? ['policy', 'trace', 'format'] : command === 'compare' ? ['baseline', 'candidate', 'trace', 'format'] : ['format']);
  const flags = new Set(command === 'audit' ? ['fail-on-deny'] : command === 'compare' ? ['fail-on-new-deny', 'fail-on-new-allow'] : []);
  const seen = new Set();
  while (args.length) {
    const token = args.shift();
    const key = token.startsWith('--') ? token.slice(2) : '';
    if ((!valued.has(key) && !flags.has(key)) || seen.has(key)) throw new Error('Unknown or repeated option. Use --help.');
    seen.add(key);
    if (flags.has(key)) result[key] = true;
    else {
      if (!args[0] || args[0].startsWith('--')) throw new Error('Missing option value.');
      result[key] = args.shift();
    }
  }
  for (const key of command === 'audit' ? ['policy', 'trace'] : command === 'compare' ? ['baseline', 'candidate', 'trace'] : []) {
    if (!result[key]) throw new Error(`Missing --${key}.`);
  }
  if (!['json', 'text'].includes(result.format)) throw new Error('--format must be json or text.');
  return result;
}

async function read(path) {
  const limit = 16 * 1024 * 1024;
  if (path !== '-') {
    const stat = statSync(path);
    if (!stat.isFile() || stat.size > limit) throw new Error('Input must be a regular file of at most 16 MiB.');
    return readFileSync(path, 'utf8');
  }
  const chunks = [];
  let size = 0;
  for await (const chunk of process.stdin) {
    size += chunk.length;
    if (size > limit) throw new Error('stdin exceeds 16 MiB.');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}

function textReport(result, command) {
  if (command === 'audit') {
    return [`${result.policy}: ${result.calls} calls · ${result.allowed} allowed · ${result.denied} denied · ${result.observed_cost} microcredits`,
      ...result.decisions.map(d => `${d.decision.toUpperCase().padEnd(5)} ${d.event_id}  ${d.tool}${d.findings.length ? '  [' + d.findings.map(f => f.code).join(', ') + ']' : ''}`),
      ...result.decisions.flatMap(d => d.findings.map(f => `  ${d.event_id} / ${f.rule_id}: ${f.message}${f.evidence.length ? ' Sources: ' + f.evidence.join(', ') : ''}`))].join('\n');
  }
  if (command === 'compare') return [`${result.baseline} → ${result.candidate}: ${result.newly_denied} newly denied · ${result.newly_allowed} newly allowed · ${result.explanation_changes} explanation changes`, ...result.changes.map(c => `${c.event_id}: ${c.before} → ${c.after} [${c.after_rules.join(', ')}]`)].join('\n');
  return [`${result.policy}: ${result.passed}/${result.cases} cases passed`, ...result.results.flatMap(r => [`${r.passed ? 'PASS' : 'FAIL'} ${r.name}`, ...r.mismatches.map(m => `  ${m.event_id}: expected ${m.expected} [${m.expected_codes}], got ${m.actual} [${m.actual_codes}]`)])].join('\n');
}

let options;
try {
  options = parse(process.argv.slice(2));
  if (options.help) console.log(help);
  else if (options.version) console.log('0.1.1');
  else {
    let engine;
    try { engine = await import('../dist/engine.js'); }
    catch { throw new Error('Engine is not built. Run npm run build first.'); }
    const { command } = options;
    const raw = command === 'audit' ? engine.audit(await read(options.policy), await read(options.trace))
      : command === 'compare' ? engine.compare_policies(await read(options.baseline), await read(options.candidate), await read(options.trace))
      : engine.test_suite(await read(options.suite));
    const result = JSON.parse(raw);
    if (result.error) {
      if (options.format === 'json') console.log(raw); else console.error(result.error.message);
      process.exitCode = 2;
    } else {
      console.log(options.format === 'json' ? raw : textReport(result, command));
      if ((command === 'audit' && options['fail-on-deny'] && result.denied > 0) ||
          (command === 'compare' && ((options['fail-on-new-deny'] && result.newly_denied > 0) || (options['fail-on-new-allow'] && result.newly_allowed > 0))) ||
          (command === 'test' && result.failed > 0)) process.exitCode = 1;
    }
  }
} catch (error) {
  const message = error.code ? `Input I/O failed (${error.code}).` : error.message;
  if (options?.format === 'json') console.log(JSON.stringify({ schema_version: 1, error: { code: 'CLI_INPUT', message } }));
  else console.error(message);
  process.exitCode = 2;
}
