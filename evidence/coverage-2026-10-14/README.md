# Production-code coverage — launchpad

Generated on 2026-10-14 with official Sui 1.66.2-a9a6825eaf62, tracing enabled.
Source anchor: `ef143cc811638f77436d8c8bf712efa4afed34b3`. Mainnet package: `0x9554595a9b1bc9fcd3253ad0c74e99983181267c8dea6b7ea2a898ec7a09cea5`.

**Scope: all tests in the currently published test overlay**.
19 traced tests passed, zero failed.

## Results

- Production line coverage: **48.85%** (170/348).
- Production CFG-edge branch coverage: **42.31%** (99/234).
- Production function coverage: **37.84%**.

| Production file | Lines hit/found | CFG edges hit/found | Functions hit/found |
|---|---:|---:|---:|
| sources/claim.move | 81/167 | 50/113 | 6/18 |
| sources/ido.move | 89/181 | 49/121 | 8/19 |

## Counting methodology

Official `sui move coverage lcov` supplies hits and CFG successor edges (including
unconditional/single-successor edges). This is the native Sui branch metric, not a
decision-only percentage. Function names from the separately verified normal build
exclude dependency modules, tests modules, inline tests/test-only helpers and compiler
test poison. Compiler JSON source maps supply instrumented line numbers; the full
test-build line denominator is checked against official LCOV in every root module
before exclusions. Zero-hit production lines are retained in production-lcov.info.

Raw test-build LCOV and the instruction-summary log are retained for comparison; neither
is labelled production line coverage. Raw SF paths are normalized to workspace-relative
paths; no local user paths or traces containing arbitrary live transaction state are published.
Normal-build function inventory is linked to the existing bytecode-verification result.

## Evidence

- [Machine-readable production results and uncovered functions/lines](production-coverage.json).
- [Production-only LCOV](production-lcov.info), [raw test-build LCOV](raw-lcov.info).
- [Trace test output](traced-tests.log), [instruction summary](instruction-summary.log).
- [Normal-build function inventory](normal-build-functions.json).
- [Official release SHA-256 provenance](release-download.json).

## Reproduce

The source/dependencies and explicit test overlay are the same as AUTH-TEST-MATRIX.md.
Obtain the official tracing-enabled CLI for your platform from the pinned release:
https://github.com/MystenLabs/sui/releases/tag/mainnet-v1.66.2
The macOS arm64 archive used here has SHA-256
`6e1256e494f5ef234c0ac78b2b52669cb07b2216950e3304565da629b19de9d1`.
Do not reuse that platform-specific hash for another archive.

```bash
cd tools/repro
npm install --ignore-scripts
SUI_BINARY=/absolute/path/to/tracing/sui node reproduce.mjs /tmp/turbos-launchpad-coverage coverage
```

The destination must not exist. Coverage uses one test thread, RUST_MIN_STACK=536870912
and a 1,000,000,000 VM test budget. These are host/unit-test settings, not mainnet gas.
A five-GiB free-disk guard stops the dedicated child process if needed. No transaction
is signed or broadcast. The parser validates totals before emitting reports.

## Remaining work

These percentages show real gaps; they are not an assertion of exhaustive authorization
or invariant testing, sufficient audit scope, or R10 closure. Add positive/negative
cases for every remaining privileged call site and invariant, use uncoveredFunctions
and uncoveredLines to prioritize, and regenerate the report.
