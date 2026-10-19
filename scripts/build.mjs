import { spawnSync } from 'node:child_process';
import { mkdirSync, copyFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const run = spawnSync(process.platform === 'win32' ? 'moon.exe' : 'moon', ['build', 'api', '--target', 'js', '--release', '--deny-warn'], { cwd: root, stdio: 'inherit' });
if (run.error || run.status !== 0) { console.error('MoonBit build failed. Install the MoonBit toolchain and put moon on PATH.'); process.exit(2); }
mkdirSync(resolve(root, 'dist'), { recursive: true });
mkdirSync(resolve(root, 'web'), { recursive: true });
mkdirSync(resolve(root, 'web/data'), { recursive: true });
for (const folder of ['dist/licenses', 'web/licenses']) {
  mkdirSync(resolve(root, folder), { recursive: true });
  for (const name of ['LICENSE', 'NOTICE']) {
    copyFileSync(resolve(root, `third_party/MoonBit-core-${name}.txt`), resolve(root, folder, `MoonBit-core-${name}.txt`));
  }
}
for (const output of ['dist/engine.js', 'web/engine.js']) {
  copyFileSync(resolve(root, '_build/js/release/build/api/api.js'), resolve(root, output));
}
for (const file of ['policy.json', 'baseline.json', 'incident.jsonl', 'regressions.json']) {
  copyFileSync(resolve(root, 'examples', file), resolve(root, 'web/data', file));
}
console.log('Built the MoonBit engine for CLI and browser.');
