# Third-party notices

AgentCanary's original source is MIT licensed. The compiled JavaScript engine
includes portions of MoonBit's standard library. Preserve the accompanying
`third_party/MoonBit-core-LICENSE.txt` and `third_party/MoonBit-core-NOTICE.txt`
when distributing compiled builds. The latter also preserves upstream notices
for standard-library components with their own permissive attributions.

- Upstream: https://github.com/moonbitlang/core
- Bundled notice snapshot: toolchain 0.10.16+b1a0e846e (2026-10-16)
- Upstream code was not modified. AgentCanary uses its APIs and compiles the
  required library portions into the generated engine.

`scripts/build.mjs` copies both documents into the browser's `licenses/` and
CLI distribution's `licenses/` directories. Node.js, Playwright, compilers and
GitHub Actions are development/host dependencies and their binaries are not
included in the source/demo archive.
