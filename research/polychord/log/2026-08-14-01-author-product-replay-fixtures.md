# 2026-08-14: Author the product replay fixtures

**Goal.** Implement and pin the exact timestamped-MIDI fixture substrate
preregistered for `polychord-product-suite/1` without changing the inherited
replay ruler or producing a selector, product prediction, or baseline result.

**Setup.** Work began from repository commit
`759e412bc174604ba634c611c6f88256d583b0a3`, which preregistered the complete
20-case inventory. The inherited frame-replay manifest remained pinned at
`d75da154da03079a69c4ceade54cc9989b24f36fdf477308ae797c3ac77e6cd4`. The
unchanged replay validator was
`826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`.

The exact validation and formatting commands were:

```sh
python3 tool/polychord/frame_replay.py \
  research/polychord/data/product-suite/fixtures/*.json
PYTHONPATH=tool/polychord python3 -m unittest \
  tool/polychord/product_suite_test.py
python3 tool/polychord/product_suite.py \
  --fixture-manifest \
  research/polychord/data/product-suite/fixture-manifest.json
mise python:format
mise python:lint
prettier --prose-wrap always \
  research/polychord/product-suite-v1.md \
  research/polychord/log/2026-08-14-01-author-product-replay-fixtures.md
git diff --check
```

**What happened.** A separate `polychord-product-fixture-manifest/1` now pins 19
streams:

- four unchanged inherited replays for Petrushka rehearsal 49, Shrovetide,
  synchronous cohorts, and the earlier lower-first positive control; and
- fifteen explicitly authored product realizations covering reverse onset order,
  a seventh chord in the upper layer, a seventh chord in the lower layer,
  multiple identities, exact-assignment ambiguity, all three integrated
  predicates, incomplete history, the exact and just-outside 50/80 ms cue
  boundaries, pedal-held releases, reattack, and authorization-key change.

The 20 automatic cases need only 19 fixture streams because
`primary-gate-clears-and-restarts` and `tracker-reset-clears` begin from the
same six-note 80 ms realization and differ only in non-MIDI product-control
actions. Those actions remain suite data and were not fabricated as musical
events.

Every authored JSON file contains its complete normalized event stream and one
literal replay frame per event. The existing `polychord-frame-replay/1` state
machine accepted all fifteen. The new strict manifest validator rejects unknown
fields, changed digests, duplicate identifiers or paths, repository escapes,
unsupported provenance labels, invalid replay transitions, and fixture-ID
mismatches. Six tests passed, including explicit checks for the 50/80 ms
boundary values, the four-note upper vocabulary, missing carried-in onset
origins, and pedal-held sounding-instance continuity.

The resulting artifact digests were:

- product fixture manifest:
  `f4f9d4bb51a1a2bf450ca6ce7dce2e01a89ff586b75c2c34c8f003bf48c3d2c0`;
- partial product-suite validator:
  `2408ec1ad042ac9709e731892d6a2cc655897d823d89ea4577d82d3471c7a4bf`; and
- validator tests:
  `6abb445198ba264ad17da328571d173125150bc34f1c20571f69d60283b9fd41`.

The manifest itself records every individual replay digest. No selector, product
observation, prior-art adapter, development corpus, or held corpus was run.

**Plain-English reading.** The musical event histories needed by the automatic
ruler now exist as inspectable, hash-locked data. They do not yet say that an
implementation passed. They only make the test inputs stable and distinguish
real inherited histories from timing that we authored specifically to exercise
the declared product rules.

**Decisions.** Keep these product fixtures isolated from
`data/frame-replay/manifest.json`; preserving that file's digest avoids silently
changing the earlier construction ruler. Reuse one musical stream when cases
differ only in timer, primary-availability, or reset controls. Keep those
controls out of MIDI fixtures.

This is a data-provenance checkpoint, not the suite freeze. Scoring remains
disabled. Any correction before freeze must be recorded; after a product result
is read, an outcome-affecting correction requires the change control declared in
`product-suite-v1.md`.

**Next.** Extend the strict validator to the complete machine-readable case and
action schema, encode every expected checkpoint literally, and implement the
independent exact scorer with deliberate pass/fail controls. Freeze those
artifacts before implementing `polychord-onset-register-policy/1`.
