import { audit } from '../dist/engine.js';
import { performance } from 'node:perf_hooks';
import { mkdirSync, writeFileSync } from 'node:fs';
const policy = JSON.stringify({ schema_version: 1, name: 'benchmark', default_decision: 'allow', rules: [
  { id: 'secret', kind: 'block_labels', tool: 'net.*', labels: ['secret'] },
  { id: 'budget', kind: 'budget', tool: 'llm.*', limit: 1000000 },
  { id: 'rate', kind: 'rate', tool: 'net.*', limit: 100, window_ms: 1000 },
  { id: 'approve', kind: 'require_approval', tool: 'fs.delete' },
] });
const results = [];
for (const size of [100, 1000, 5000, 10000]) {
  const events = Array.from({ length: size }, (_, i) => ({ id: `e${i}`, session: 'bench', seq: i, at_ms: i * 10, tool: i === size - 1 ? 'net.post' : i === 0 ? 'fs.read' : 'text.transform', resource: 'synthetic', ...(i > 0 ? { inputs: [`a${i - 1}`] } : { labels: ['secret'] }), output: `a${i}` }));
  const trace = JSON.stringify(events);
  for (let i = 0; i < 3; i++) audit(policy, trace);
  const times = [];
  for (let i = 0; i < 10; i++) {
    const start = performance.now(); const raw = audit(policy, trace); const elapsed = performance.now() - start;
    const report = JSON.parse(raw);
    if (report.calls !== size || report.denied !== 1 || report.decisions.at(-1).findings[0].evidence[0] !== 'e0') throw new Error('Benchmark correctness check failed');
    times.push(elapsed);
  }
  times.sort((a, b) => a - b);
  results.push({ events: size, input_bytes: Buffer.byteLength(trace), median_ms: Number(((times[4] + times[5]) / 2).toFixed(2)), sample_max_ms: Number(times.at(-1).toFixed(2)) });
}
const output = { measured_at: new Date().toISOString(), node: process.version, platform: process.platform, arch: process.arch, workload: 'synthetic single-session artifact chain; 4 rules; parse + validate + replay + JSON serialize', warmups: 3, samples: 10, results };
mkdirSync('artifacts', { recursive: true });
writeFileSync('artifacts/benchmark.json', JSON.stringify(output, null, 2) + '\n');
console.log(JSON.stringify(output, null, 2));
