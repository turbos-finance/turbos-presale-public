# Tests integrated into the current public checkout — 2026-10-15

**19 passed, 0 failed**. [Result](result.json), [full log](tests.log), [normal-bytecode check](normal-bytecode.json).

The two previously published clock-fixture corrections are directly in the existing inline IDO tests. Production functions and assertions are unchanged.

These tests are now ordinary tracked source/test files in this repository, not only patches under tools/repro. Existing source-anchor overlay recipes remain for historical reproducibility; they are not the current-checkout test command.

## Run the current checkout

Install the recorded Sui 1.66.2-a9a6825eaf62 and Node.js 22+, then:

```sh
node tools/test-current.mjs /tmp/turbos-launchpad-current-tests
```

The destination must not exist. This copies THIS checkout's sources/tests to a disposable directory and pins the test framework to `a9a6825eaf6273cc819ee3bcf65fd4909f7624a9`, matching the CLI's test natives. Only that disposable manifest is adjusted; the producer Move.toml, Published.toml, and current MVR GitInfo are unchanged. No old test overlay is applied to the copied source. VM test gas limit is 1,000,000,000, not a mainnet gas payment. No keystore is read and no transaction is published.

A separate normal, non-test build matches all 2 module hashes previously read from the immutable deployed package. No production remediation was published or deployed; inline helpers are excluded from normal builds. No MVR metadata transaction is needed for this test-only follow-up.

## Limits

October 14 coverage remains a dated report with its original tracing limits; this run does not regenerate coverage.

This is not evidence that every authorization check/invariant is covered. See the historical [authorization matrix](../AUTH-TEST-MATRIX.md) and dated [coverage report](../coverage-2026-10-14/README.md) for remaining gaps.
