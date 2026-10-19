# AgentCanary

Deterministic, artifact-aware policy replay and regression tests for AI tool traces. Written in MoonBit; no third-party Mooncakes dependencies. The Node CLI and browser UI use the same compiled MoonBit engine.

**Why:** a customer file can be summarized and then uploaded. A stateless tool filter cannot explain that flow. AgentCanary propagates explicit sensitivity labels along artifact dependencies, retains origin event IDs, and evaluates single-use approvals, budgets, rates and prerequisite calls. Compare two policies against the same observation before rolling out a policy change.

```sh
moon check --deny-warn
moon test --deny-warn
moon run cmd/demo
node scripts/build.mjs
node bin/agentcanary.mjs audit --policy examples/policy.json --trace examples/incident.jsonl
node bin/agentcanary.mjs test examples/regressions.json
node scripts/serve.mjs
```

Requires MoonBit and Node 22+ for adapters. No npm dependencies, credentials, models or external API calls. Visit `http://127.0.0.1:4173` or the [hosted demo](https://zhangbowen2006.github.io/AgentCanary/). Imported data stays in the browser.

Install the reusable library with `moon add zhangbowen2006/agentcanary@0.1.0`. Public APIs: `parse_policy`, `parse_trace`, `evaluate`, `compare`, `run_suite`, and their JSON interfaces. [Executable API examples](API.mbt.md) are compiled and tested. [Generated interface](pkg.generated.mbti).

Supports `allow`, `deny`, `block_labels`, `require_approval`, `budget`, `rate`, and `require_before`. Deny overrides allow. Unmatched calls follow an explicit default verdict. Every regression-suite call requires an expectation; missing assertions fail the case. CLI exit codes: 0 passed, 1 gate/test failure, 2 invalid input/setup. Use `--help` for all flags.

Replay preserves **observed history**: historically executed calls still propagate data and consume observed cost even if a candidate policy denies them. Comparison is a per-call policy comparison, not a simulation of new agent behavior after blocking an action. Collectors must authenticate approval events, label data and record dependencies faithfully. No tool execution, OS sandbox, natural-language attack detection or implicit content classification is provided.

Read the [format contract](docs/FORMAT.md), [semantics and trust boundary](docs/SEMANTICS.md), [architecture](docs/ARCHITECTURE.md), [benchmark method](docs/BENCHMARK.md) and [provenance](docs/PROVENANCE.md). CI covers all four backends on three operating systems. Native needs a system C compiler. Default Wasm GC, JS CLI and browser use do not.

MIT. Original October 2026 project by zhangbowen2006. AI assistance is disclosed; example traces are synthetic.
