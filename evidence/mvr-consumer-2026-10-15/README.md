# Public MVR consumer validation — 2026-10-15

**Passed:** official `mvr add @turbos/launchpad/3` followed by a normal Move build containing a real non-empty import/function call.

The run started with a new empty Move cache, downloaded dependencies normally, and reused that new cache between its five consumers. It used no pre-populated or manually modified dependency checkout. Sui 1.66.2-a9a6825eaf62 and MVR 0.1.0-d85f8ad92add; mainnet read-only, empty keystore, no verifier-signed transaction.

MVR's versioned and unversioned names both resolve to deployed package `0x9554595a9b1bc9fcd3253ad0c74e99983181267c8dea6b7ea2a898ec7a09cea5` and metadata commit `992d27abad738653ad9dc8acbc14c34217fbe0c5`. The owner-executed GitInfo update succeeded: [3HB1FGc4ZVXe55sXaDAuKckBWpxBhZ5uT7rJYUzt2qkv](https://suivision.xyz/txblock/3HB1FGc4ZVXe55sXaDAuKckBWpxBhZ5uT7rJYUzt2qkv). PackageInfo remains on the expected multisig.

## Reproduce

Copy the supplied Move.toml and sources/smoke.move to a new directory. Install the stated official Sui/MVR versions and configure the client for mainnet. Then run:

```sh
mvr add @turbos/launchpad/3
sui move build --build-env mainnet --silence-warnings --no-lint
```

The supplied manifest already includes the dependency that `mvr add` adds. For a first-add reproduction, remove that dependency entry before the first command. Published Move.lock records the exact resolved graph. See [result.json](result.json), [mvr-add.log](mvr-add.log), and [build.log](build.log).

This completes the latest-release MVR consumer check for this package. See [official root source/bytecode verification](../mvr-source-2026-10-15/README.md) for its separate deployed-bytecode proof. No production source or existing tests changed; no unpublished Fun changes included. This is not runtime testing, every-auth/invariant coverage, audit closure, or historical/peripheral-package completion.

The 2 dependency module BCS blobs freshly compiled through MVR also hash-identically to the previously read immutable mainnet package: [artifact-comparison.json](artifact-comparison.json). This comparison reused the recorded deployed-byte hashes; it did not perform another chain fetch.
