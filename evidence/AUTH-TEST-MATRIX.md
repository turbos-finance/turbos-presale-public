> October 15 update: the tests/corrections described below are now directly tracked in the current source/test tree. The current suite passes 19 tests; use [current-checkout instructions](tests-current-2026-10-15/README.md). The remaining sections describe the October 14 overlay baseline, not a claim of exhaustive coverage.

# First authorization/invariant test batch — Turbos Launchpad

Pinned deployed source: `ef143cc811638f77436d8c8bf712efa4afed34b3`.
[Results](tests-security-2026-10-14.json): **19 passed, 0 failed**.
[Full output](tests-security-2026-10-14.log), [before-overlay baseline](tests-before-overlay-2026-10-14.json).

## Explicit test changes

There are 19 inline tests despite no standalone tests directory. Two positive withdrawal tests now advance the test clock to (END_TIME + 1) * 1000 milliseconds, after the sale end time in seconds. No production function or assertion changed; IDO contract remediation remains out of scope.

The source anchors and production functions are untouched in this repository. The test
patch/new files are versioned under tools/repro and applied only in a disposable test
checkout. Normal build mode never applies the overlay. No mainnet transaction is needed.

A separate normal build after the overlay still matches every deployed root module BCS byte: [result](test-overlay-bytecode-2026-10-14.json).

## Test mapping and remaining scope

| Existing coverage area | Runnable tests |
|---|---|
| Claim / cliff / vesting | claim module: 5 |
| IDO funding / whitelist / timing / management | ido module: 14 |

The two corrected withdrawal tests prove the post-sale positive paths. Existing negative
cases such as test_starttime, test_endtime and funding/whitelist limits use broad
expected_failure annotations; tighten their abort code/location before treating them as
complete security proof. Every wrong-sale capability check and requested IDO version
gating still needs targeted evidence/design work; this overlay does not fix R6.

## Re-run

Install the pinned CLI from REPRODUCE-LATEST.md, then:

```bash
cd tools/repro
npm install --ignore-scripts
node reproduce.mjs /tmp/turbos-launchpad-security-tests test
```

The path must not exist. Framework native functions are aligned with the CLI; VM test
budget is 1,000,000,000, not a mainnet gas payment.

A separate official tracing-enabled CLI now supplies a
[production-only coverage report](coverage-2026-10-14/README.md). Its precise full/partial
tracing scope is disclosed there; this original passing test baseline remains unchanged.
The complete every-auth/every-invariant matrix is still required. R10 is not closed.
