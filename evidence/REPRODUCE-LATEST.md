# Latest release reproduction — Turbos Launchpad

Verified on 2026-10-14. Mainnet v3: `0x9554595a9b1bc9fcd3253ad0c74e99983181267c8dea6b7ea2a898ec7a09cea5`.
MVR: `@turbos/launchpad`. Source: [`ef143cc811638f77436d8c8bf712efa4afed34b3`](https://github.com/turbos-finance/turbos-presale-public/tree/ef143cc811638f77436d8c8bf712efa4afed34b3).

## Result and scope

Fresh compilation reproduced all 2 root modules exactly, byte for byte, with no missing/extra modules.
[Machine-readable hashes and result](bytecode-verification-2026-10-14.json).
Source and existing tests were checked against the pinned revision and were not edited.
Only disposable manifests/dependency resolution were adjusted: current published-at, original
named address and explicit local dependencies. Recipe manifests are committed under tools/repro.
This does not assert that the original historical manifest builds unchanged today.

The report records mainnet linkage but does not independently verify dependency linkage
or type-origin tables. It is not a complete sui client verify-source result, security
audit, mvr add consumer validation, or historical-version verification. September's
build-verification.json is archived evidence, not this fresh result.

## Toolchain and dependencies

- Sui CLI: `sui 1.66.2-a9a6825eaf62` (verification host: Darwin arm64).
- Node.js >=22; comparator SDK `@mysten/sui@2.22.1`.
- Build framework: [`25804c243d07dd73c0d199e7794383bd855cd436`](https://github.com/MystenLabs/sui/tree/25804c243d07dd73c0d199e7794383bd855cd436/crates/sui-framework/packages).

## Re-run

Install the exact Sui CLI recorded above first. From this public repository's current
main branch (which supplies tools; the script separately checks out the immutable release):

```bash
cd tools/repro
npm install --ignore-scripts
# Choose a new path that does not already exist.
node reproduce.mjs /tmp/turbos-launchpad-repro build
```

The script clones public source/dependencies at full SHAs, builds in a new workspace,
and reads immutable mainnet module BCS over gRPC. It never signs or submits a transaction.
It refuses to overwrite an existing workspace and exits nonzero for compilation errors
or any module mismatch. Network access to GitHub and the Sui mainnet fullnode is required.
The recipe mirrors the completed local build; an independent clean-network runner remains
a useful additional check.

A fresh test run/coverage report for this project is not part of this bytecode evidence.

Historical GitInfo is deferred while latest-release evidence is prioritized.
