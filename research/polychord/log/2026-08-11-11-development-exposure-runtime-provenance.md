# 2026-08-11: Correct development-exposure runtime provenance

**Goal.** Verify the corrected development exposure before inspecting selector
summaries, and preserve or reject the artifact according to the preregistered
provenance contract.

**Setup.** The repository was clean at correction commit `079f1f79`. The first
failed attempt remained preserved, and the designated output directory was
absent. The ASAP and POP909 checkouts were clean at their pinned commits. The
exact command was:

```sh
./.venv/bin/python tool/polychord/development_exposure.py \
  --asap-root build/whatkey-corpora/asap-dataset \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory \
    build/polychord/register-selector-development-exposure-v1
```

The correction is verified with:

```sh
mise python:format
mise python:lint
./.venv/bin/python -m unittest discover -s tool/polychord -p '*_test.py'
npx prettier --check --prose-wrap always \
  research/polychord/log/2026-08-11-11-development-exposure-runtime-provenance.md
git diff --check
```

**What happened.** The harness completed all 23 ASAP development performances,
101 POP909 sample songs, and 59 When in Rome development fixtures. Its console
reported 73 review items. Before any selector profile summary was inspected, the
manifest audit found an empty `runtime.dartVersion`. Direct read-only inspection
confirmed Dart SDK 3.12.2. The installed Dart command writes its version to
standard output, while the harness retained only standard error.

The rest of the pre-outcome integrity audit passed:

- the repository commit was `079f1f798cdfacadb29b35ad2b71134bdb1af6c6`, with
  `repositoryDirty` false;
- the manifest declared 189 non-manifest outputs, exactly matching the 189 files
  present, with no missing, unexpected, or hash-mismatched output;
- all 13 contract and split pins matched;
- all 183 source hashes and all 183 summary piece-index hashes matched;
- summary indexes contained exactly 23 ASAP, 101 POP909, and 59 When in Rome
  pieces;
- manifest, review-index, and disposition-template counts all agreed at 73; and
- the isolation record says no ASAP test MIDI or POP909 held song was opened, no
  corpus label was supplied to analysis, and When in Rome was not treated as
  stable-display evidence.

The 190-file artifact is preserved locally, unchanged, at
`build/polychord/register-selector-development-exposure-v1-failed-attempt-2-missing-dart-runtime`.
The SHA-256 of the compact JSON inventory of relative path and file SHA-256
pairs is `7cf047a10f53b08777988295cd6681ab1fc8520ed95dde19eac2a7a19e754f19`. No
selector metrics or individual review item was inspected.

**Plain-English reading.** The musical analysis finished and its files are
internally intact, but the result does not meet its own reproducibility rule: it
fails to say which Dart runtime produced it. That missing fact does not justify
quietly editing the manifest after the run. Preserving and rerunning is cheaper
and scientifically cleaner.

**Decisions.** Reject this artifact as provenance-incomplete. Preserve it rather
than patching or overwriting it. Capture runtime version text from standard
output with standard error as a compatibility fallback, and abort manifest
creation if both are empty. Cover all three behaviors with a synthetic
regression. This changes only provenance capture; corpus inputs, analyzer,
selector profiles, review items, and adoption bars remain frozen.

**Next.** Commit the runtime correction as a new clean premeasurement boundary.
Then rerun the same designated command and repeat the manifest and accounting
audit before reading selector outcomes.
