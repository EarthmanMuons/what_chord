# Reproducing WhatKey Data

This document describes how to rebuild the WhatKey Phase 2 data inputs from a
fresh checkout and how to verify the headline result table. Generated
corpus-derived fixtures stay under `build/` unless a separate commit explicitly
packages them with the required provenance and notices.

## Headline Reproduction

To reproduce the README headline table by rerunning the detector and music21
baseline code:

```sh
mise install
mise research:whatkey-headline-rerun -- --yes
```

This downloads pinned external checkouts into `build/whatkey-corpora/`,
regenerates the Isophonics fixtures under `build/whatkey-fixtures/`, reruns the
Dart detector and music21 baselines, and checks the rounded coverage, exact, and
MIREX values against the committed result manifest. Omit `--yes` to review the
download and license-gated fixture warning before proceeding.

For a fast no-download verification that only checks the committed one-shot
artifacts against the landing-page table:

```sh
mise install && mise research:whatkey-headline-verify
```

That task reads `research/whatkey/results/test-split-2026-07-07/` and
`MANIFEST.json`; it does not rerun detectors or baselines.

## Historical Reproduction Contract

The current codebase keeps the paper-era behavior behind two explicit names:

- fixture extraction uses the `whatKeyPaper2026` chord-analysis profile;
- detector reruns use the `whatKeyPaper2026` and `whatKeyPaper2026Reflex`
  recipes, which pin every detector parameter instead of inheriting mutable
  defaults.

The app continues to use the current chord-analysis behavior. The historical
profile is selected only by research tooling, so product improvements do not
silently rewrite the paper's observation stream.

The canonical SHA-256 values for every paper fixture set and committed result
directory are recorded in `results/reproduction-v2026.7.14.json`. Canonical JSON
hashing ignores object key order and whitespace. Fixture hashes cover every
observation file. Result hashes cover `claims.json` plus the stable scored
fields of `report.json`; additive diagnostics and run metadata are intentionally
outside that second hash.

To regenerate all license-gated fixtures and verify the complete lock:

```sh
mise research:whatkey-prepare-data -- --all --verify-splits --yes
mise research:whatkey-reproduction-verify
```

The headline rerun performs the corresponding Isophonics fixture and result hash
checks automatically after checking the displayed table.

## Required Tools

Use the repository's normal toolchain:

- `git`
- `mise`
- Flutter/Dart, as used by the app
- Python 3.12.13 and `uv` 0.11.16, both managed by `mise.toml`

The research tasks pin optional Python packages that affect results:

- `music21==10.1.0`
- `pychord==1.4.0`

The complete direct and transitive Python pin set is committed at
`tool/requirements-research.txt`; `mise research:python-install` installs from
that file into the repository-local `.venv`.

From the repository root, make sure the mise environment is active:

```sh
mise install
```

## Automated Fixture Preparation

The manual steps below are wrapped by:

```sh
mise research:whatkey-prepare-data
```

By default this prepares the Isophonics/ChoCo fixtures needed to rerun the
headline table. The script downloads pinned external checkouts into
`build/whatkey-corpora/` and writes generated fixtures under
`build/whatkey-fixtures/`, so nothing is installed system-wide and no gated
fixture data is committed.

The script asks for confirmation before external downloads and license-gated
fixture preparation. For unattended one-shot reruns of the headline table:

```sh
mise research:whatkey-headline-rerun -- --yes
```

Useful variants:

```sh
mise research:whatkey-prepare-data -- --all --verify-splits --yes
mise research:whatkey-prepare-data -- --when-in-rome --yes
mise research:whatkey-headline-rerun -- --yes
mise research:whatkey-prepare-data -- --headline --verify-only
```

`--verify-only` is read-only: it checks existing checkout commits, fixture
manifests, fixture files, and split counts, but it does not clone, fetch,
download, or regenerate data.

The manual commands remain documented below so the exact pins and intermediate
states are visible.

## External Corpus Checkout

WhatKey uses the Contrapunctus benchmark checkout as the prepared access layer
for When-in-Rome. The benchmark provides the pinned When-in-Rome submodule,
piece manifest, common-subset flags, provenance fields, and score-alignment
helpers used by `tool/whatkey/fixture_extract.py`.

Clone the benchmark outside this repository:

```sh
git clone https://github.com/Tomczik76/contrapunctus-bench /private/tmp/contrapunctus-bench
cd /private/tmp/contrapunctus-bench
git checkout b9e011c8cf34c5e76691dcf2c835b8c99ebd9d59
git submodule update --init corpus/When-in-Rome
```

Verify the pins:

```sh
git rev-parse HEAD
git -C corpus/When-in-Rome rev-parse HEAD
```

Expected values:

```text
b9e011c8cf34c5e76691dcf2c835b8c99ebd9d59
aa7539f1cf480997a68998405c0783ebf6339c16
```

If you use another checkout location, export it before running repository tasks:

```sh
export CONTRAPUNCTUS_BENCH_ROOT=/path/to/contrapunctus-bench
```

## Prepare Local Corpus State

Install the optional Python dependency used by the When-in-Rome extraction path:

Run this from the WhatChord repository root:

```sh
mise research:when-in-rome-install
```

The `when-in-rome-v1` fixture set includes TAVERN. TAVERN scores are remote in
When-in-Rome and must be fetched into the benchmark checkout's machine-state
`corpus/scores-local/` directory:

```sh
cd "${CONTRAPUNCTUS_BENCH_ROOT:-/private/tmp/contrapunctus-bench}"
python3 corpus/prep/fetch_tavern_scores.py
```

Expected TAVERN prep result:

```text
Done: 11/11 TAVERN scores fetched + converted.
```

Do not fetch chorales for `when-in-rome-v1`. Chorales are intentionally outside
the committed-fixture gate because their score source is noncommercial-gated.

## Regenerate Fixtures

Return to the WhatChord repository root:

```sh
cd -
```

Regenerate the hand-authored pop/jazz fixtures:

```sh
mise research:whatkey-fixtures-pop-jazz
```

Output:

```text
research/whatkey/data/fixtures/pop-jazz-v1/
```

The generated `when-in-rome-v1` set is committed at
`data/fixtures/when-in-rome-v1/` (the protocol is frozen against it), so
regeneration is only needed to verify the committed files or to build a new
fixture version. Regenerate the license-gated When-in-Rome fixtures:

```sh
mise research:whatkey-fixtures-when-in-rome
```

Output:

```text
build/whatkey-fixtures/when-in-rome-v1/
```

Expected sanity result:

```text
77 fixtures -> build/whatkey-fixtures/when-in-rome-v1
```

The upstream manifest selects 79 license-gated pieces, but
`Bach WTC I Prelude 13` and `Schubert Ave Maria` currently produce no fixture
rows through the loader and are not part of the frozen split.

## Regenerate The Frozen Split

The split is frozen before detector tuning. Regenerate it only to verify the
recorded file or before tuning has begun for a new fixture version.

```sh
python3 tool/whatkey/freeze_split.py \
  --bench-root "${CONTRAPUNCTUS_BENCH_ROOT:-/private/tmp/contrapunctus-bench}" \
  --fixtures-manifest build/whatkey-fixtures/when-in-rome-v1/manifest.json
```

Output:

```text
research/whatkey/data/splits/when-in-rome-v1.json
```

Expected split counts:

```text
development: 59 pieces, 3694 events
test:        18 pieces, 1513 events
total:       77 pieces, 5207 events
```

The split seed is recorded in the JSON file:

```text
whatkey-when-in-rome-v1-split-2026-07-06
```

The test split is held out. Tuning, ablation, threshold selection, and detector
selection happen on the development split only.

## License-Gated Corpora (ASAP, Isophonics, Overlap Set)

These sets generate into `build/whatkey-fixtures/` only; their extractors refuse
to write under `research/` (see License Boundaries below). Their split files are
committed because splits record identifiers and counts, not corpus content.

### ASAP (`asap-nc-v2`)

Clone ASAP outside this repository and verify the pin:

```sh
git clone https://github.com/fosfrancesco/asap-dataset /private/tmp/asap-dataset
git -C /private/tmp/asap-dataset checkout afc815c75c42e83a79c03feb6da8a35e77d4c6b8
```

Regenerate the fixtures (or `mise research:whatkey-fixtures-asap` with
`ASAP_ROOT` exported):

```sh
python3 tool/whatkey/asap_extract.py \
  --asap-root /private/tmp/asap-dataset \
  --set asap-nc-v2 --max-performances 60
```

Regenerate the frozen split (verification only; the committed file is
normative):

```sh
python3 tool/whatkey/asap_split.py \
  --fixtures-manifest build/whatkey-fixtures/asap-nc-v2/manifest.json \
  --seed whatkey-asap-nc-v2-split-2026-07-07 \
  --out research/whatkey/data/splits/asap-nc-v2.json
```

Expected split counts:

```text
development: 50 pieces, 15407 events
test:        10 pieces,  4139 events
```

### Isophonics via ChoCo (`isophonics-nc-v1`)

Clone ChoCo outside this repository and verify the pin:

```sh
git clone https://github.com/smashub/choco /private/tmp/choco
git -C /private/tmp/choco checkout 5fe168fd55be5c84512abcfbc4e6f1b1f8f0092a
```

Regenerate the fixtures and the frozen split:

```sh
python3 tool/whatkey/isophonics_extract.py \
  --choco-root /private/tmp/choco --set isophonics-nc-v1
python3 tool/whatkey/asap_split.py \
  --fixtures-manifest build/whatkey-fixtures/isophonics-nc-v1/manifest.json \
  --seed whatkey-isophonics-nc-v1-split-2026-07-07 \
  --out research/whatkey/data/splits/isophonics-nc-v1.json
```

Expected split counts:

```text
development: 183 pieces, 15497 events
test:         41 pieces,  3565 events
```

### ASAP plus When in Rome overlap (`asap-wir-nc-v1`)

Requires both the ASAP checkout and the contrapunctus-bench checkout above. This
set is evaluation-only (no tuning, configurations committed beforehand), so it
has no split file:

```sh
python3 tool/whatkey/asap_wir_extract.py \
  --asap-root /private/tmp/asap-dataset \
  --bench-root "${CONTRAPUNCTUS_BENCH_ROOT:-/private/tmp/contrapunctus-bench}"
```

Expected sanity result: 36 fixtures, each piece's opening key matching the known
sonata key, with unalignable performances reported as skipped.

CORRECTION (2026-07-27): the v1 labels carry measure-shifted analyst keys in 11
of 36 movements (3.34% of events); discovery, fix, and corrected numbers are in
log entry 2026-07-27-01 and performed-input logs 2026-07-27-02/-03. The current
extractor emits the corrected, harmony-labeled `asap-wir-nc-v2` (and requires
the repo venv for music21). Reproducing the published v1 numbers bit for bit
requires the extractor as of the v2026.7.14 contract commit; every published
conclusion also reproduces on v2, with the corrected values in the addendum.

## Verify Outputs

Validate the split JSONs:

```sh
for f in research/whatkey/data/splits/*.json; do
  python3 -m json.tool "$f" > /dev/null && echo "ok: $f"
done
```

## License Boundaries

Read these files before committing corpus-derived fixtures:

- `research/whatkey/data/NOTICE.md`
- `research/whatkey/data/provenance/when-in-rome-v1.md`

For `when-in-rome-v1`, committed fixtures are limited to these groups:

- `bach-wtc`
- `brahms-lieder`
- `schubert-lieder`
- `tavern`

The fixture extractor rejects unverified When-in-Rome groups by default. Use
`--allow-unverified-license` only for local, uncommitted experiments under
`build/`.
