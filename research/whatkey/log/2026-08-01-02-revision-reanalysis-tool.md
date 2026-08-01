# 2026-08-01: Build the revision reanalysis tool

**Goal.** Implement and test the scorer declared in log entry 2026-08-01-01
without calculating any R1-R4 endpoint.

**Setup.** Work began from commit `f29deaace8925f8b4812f8b2edac99404e63b30f`,
which contains the committed predeclaration. Frozen input paths and hashes are
exactly those in entry -01. The implementation and non-scoring validation
commands were:

```sh
mise python:format
mise python:lint
python3 tool/whatkey/revision_reanalysis_test.py
python3 -m py_compile \
  tool/whatkey/revision_reanalysis.py \
  tool/whatkey/revision_reanalysis_test.py
python3 tool/whatkey/revision_reanalysis.py validate-frozen-inputs
```

**What happened.** `tool/whatkey/revision_reanalysis.py` now implements the four
declared command interfaces:

- `isophonics-cohort` pairs coverage and exact accuracy on the same non-null
  24-key reference events while retaining out-of-ontology behavior separately.
- `overlap-segments` reports own-claim coverage/accuracy and an identical-event
  common-claim view at only the four already inspected thresholds.
- `dual-reference` maps analyst keys, detector claims, and ASAP key signatures
  to the same 12 diatonic-collection classes and reports the declared
  piece-level interaction.
- `factorial` verifies and summarizes the eight development-only harness cells,
  including the simple effects and their difference of differences.

Every analysis enforces the fixed seed and resample count, records its command,
repository state, input hashes, counts, and piece-level results, and refuses to
write license-gated output under `research/`. Frozen claim commands rescore
event streams directly instead of trusting archived aggregate reports. The
factorial reader verifies the fixture set, development split, claim/report
identity, and every consequential detector-setting fragment before accepting a
cell.

The first real-input validation caught two provenance details before scoring.
Modern fixture manifests store canonical-JSON hashes for enclosed fixtures, not
raw byte hashes. The tracked `when-in-rome-v1` manifest is older and has neither
per-file hashes nor an embedded content hash; its canonical set hash already
exists in the v2026.7.14 reproduction lock. The final verifier therefore uses
raw SHA-256 only for the exact files pinned in entry -01, canonical JSON for
fixture contents, and the existing reproduction-lock hash
`0bc6551265f15bc397fa5cece06a909349ac35e27d3ff2891a3dc0e721bba224` for the
legacy When in Rome set. It rejects mixed hashed/unhashed manifests and checks
modern aggregate content hashes as well as every modern per-file hash.

The final checks passed: Ruff formatting and lint, Python byte compilation, and
9 synthetic unit tests covering ontology mapping, key-signature timing,
segment-span filtering, scorable-cohort scoring, abstention/switch semantics,
factorial-effect direction, claim alignment, and both modern and legacy fixture
hash contracts. The non-scoring frozen-input command validated 224 Isophonics
fixtures and 41 held-out claim streams, 36 overlap fixtures and both claim
streams, and 59 When in Rome development fixtures. No accuracy, coverage,
interaction, or factorial endpoint was calculated.

**Plain-English reading.** The calculator is now built, but it has not opened
the answer sheet. Its tests use invented examples, and its only pass over the
real files checked identity and shape: are these exactly the declared files, do
their pieces match the frozen splits, and is there one claim position for every
event? The two failures encountered were useful guardrail bugs in the new
checker, not findings about the detector.

**Decisions.** Keep the implementation in one standard-library Python tool so
all four analyses share cohort, macro/micro summary, bootstrap, ontology, and
provenance rules. Treat canonical fixture content as the authoritative
event-data identity while retaining the exact raw-file pins from the
predeclaration. Preserve all original reports and claims; the tool only reads
them. Do not run R1-R4 until this implementation is reviewed and committed.

**Next.** Commit the tool and this audit as a clean pre-results checkpoint. Then
run R1-R3 from frozen claims, inspect internal count invariants, run the eight
R4 development cells, and record each result in a new append-only log entry
before editing the manuscript.
