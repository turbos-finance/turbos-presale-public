# Turbos Launchpad - deployed source

Mainnet package version 3:
`0x9554595a9b1bc9fcd3253ad0c74e99983181267c8dea6b7ea2a898ec7a09cea5`.
Original package: `0x3846dc55562cb04f10580e8e02ae2b532247994abb472b4faf47842079fbf437`.

This is a source-only snapshot of original revision
`83ae1a30b9f112523e3b80de14d62209d0e83851`. Runtime logs and private Git history are
excluded. Every contract source file is byte-for-byte identical to the original revision;
[source provenance](evidence/source-provenance.json) records the hashes.

See [build verification](evidence/build-verification.json), [audit evidence](audits/README.md),
and [security contact](SECURITY.md). The repository includes source snapshots for the
three commits cited in the original TurboStar audit under `audits/source-anchors/`.

## Architecture

`ido` manages presale configuration, funding, refunds and proceeds.
`claim` manages token vesting and claims, with a capability-controlled emergency switch.
The IDO version-retirement design remains a separate remediation item.

## Reproduction

Use Sui CLI 1.49.2, as recorded in `Move.lock`. Pin the mutable `mainnet` framework
dependency to `62b9f371e37e618b7048417e2d232d6cd678c967` (mainnet-v1.49.2).
Pin `published-at` to v3 and the `presale` named address to the original package address.

```sh
sui move build
sui client verify-source
```

The archived source verification passed on 2026-09-29. No standalone Move unit-test
files are present in the deployed revision. Comprehensive authorization tests and
published line/branch coverage are still required; this release does not claim those complete.

## Current-release metadata verification (2026-10-15)

See [verified build configuration and official source-verification evidence](evidence/mvr-source-2026-10-15/README.md). This update does not change production functions. MVR GitInfo update and a fresh-cache registry-consumer run are separate follow-ups.

## Public MVR consumer result (2026-10-15)

The owner executed the current-version GitInfo update. The official MVR add and a real-import consumer build both passed using a new empty cache for the validation run. See [consumer logs, manifest, lockfile and results](evidence/mvr-consumer-2026-10-15/README.md). This supersedes the earlier metadata-update-pending status, without changing the source commit recorded in MVR.
