# Audit evidence - Turbos Launchpad / TurboStar

Audit PDFs retain their original authors' copyright and terms. The repository's MIT
license applies to Turbos-owned source and documentation; it does not relicense third-party reports.

The original [MoveBit report](movebit-launchpad-2023.pdf) is preserved unchanged.

| Item | Evidence |
|---|---|
| Auditor | MoveBit (individual reviewer names not disclosed) |
| Review period | 2023-05-06 through 2023-05-15 |
| Reviewed commits | `297c0ff8e9b1dd52e970fe282fd7cb902696f537`, `7cd3aaa328b86769935490d90fad464473899d80`, `52f292ae5331dd9f795bffbe66441950aa58a977` |
| Scope | `sources/ido.move`, `sources/claim.move`; SHA-1 file hashes in the report |
| Method | Architecture review, unit testing and manual review; report section 1.5 |
| Findings | 9: 8 fixed, IDO-8 (medium) acknowledged |

The commits are printed across wrapped lines in the report's project-information table.
They are not absent. Each source tree is published under `source-anchors/<original SHA>/`.
This is a source-drop mapping: snapshot directory names identify original private commits;
they are not claims that those commits exist unchanged in this sanitized repository.
Machine-readable file hashes are in `evidence/audit-source-provenance.json`.

Fix anchors include `7cd3aaa...` (time validation) and `52f292a...` (ClaimEvent).
The report remains authoritative for each finding's disposition. No reviewer sign-off
on subsequent versions is implied.

## Deployed-source delta and gaps

Deployed v3 originates from `83ae1a30b9f112523e3b80de14d62209d0e83851`.
Relative to the last audited commit, the two source modules contain 647 insertions and
140 deletions. A delta review, complete finding-to-fix/test matrix, standalone Move tests,
coverage evidence and IDO version-retirement remediation are outstanding.
