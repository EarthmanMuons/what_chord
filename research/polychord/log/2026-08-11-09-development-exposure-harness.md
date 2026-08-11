# 2026-08-11: Implement the development-exposure harness

**Goal.** Implement and verify the preregistered development-exposure path on
synthetic inputs only, without opening a development, test, or held item through
the selector and without generating a corpus outcome.

**Setup.** Work began at repository commit `50f2c596`, after
`development-exposure-v1.md` and log 2026-08-11-08 fixed the measurement. The
official output directory did not exist. Python was 3.14.6, Dart was 3.12.2, and
the intentionally exact Flutter pin was 3.44.8. The corpus and roster pins
remain those preregistered in log 2026-08-11-08:

- ASAP commit `afc815c75c42e83a79c03feb6da8a35e77d4c6b8`;
- POP909 commit `d83e6edba6872a704f5d3b8b32f5cb540088dae6`;
- ASAP development split SHA-256
  `240cab19043f8d4c1877a3d24c67a5a6ba7ddfc0058a29f4791209d0eeed440f`;
- POP909 roster SHA-256
  `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781`; and
- When in Rome split SHA-256
  `4f55b18f88130fd62718c358b62a2c81302bbb11eede3c67d133f23161795684`.

The verification commands were:

```sh
dart format .
flutter analyze
dart run import_order_lint:import_order

cd packages/whatchord
dart analyze
dart run import_order_lint:import_order
dart test
cd ../..

mise python:format
mise python:lint
python3 -m unittest discover -s tool/polychord -p '*_test.py'

npx prettier --write --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/development-exposure-v1.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/log/2026-08-11-09-development-exposure-harness.md
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/development-exposure-v1.md \
  research/polychord/output-evaluation-contract.md \
  research/polychord/log/2026-08-11-09-development-exposure-harness.md
git diff --check
```

The first sandboxed Dart formatting attempt could not write the Flutter SDK's
external cache. The identical command passed after granting that cache access.
This was the Codex workspace boundary, not a nono sandbox or a repository
permission problem.

## Implementation

`PolychordStableDisplayGate` is the pure-Dart implementation of the frozen
200-millisecond secondary display reducer. It compares the ordered polychord
identity and exact lower and upper MIDI-note assignments, inserts no primary
timing, retains an old display only while its assignment still exhausts the
sounding set, and clears immediately for silence, unavailable primary,
abstention, or an invalidated assignment.

The measurement harness is deliberately split in two:

- `development_exposure.py` owns source resolution, hash and checkout guards,
  Mido parsing, current channel-blind note and sustain normalization, local
  output, provenance, review rendering, and disposition validation.
- `development_exposure_batch.dart` is one persistent pure-Dart process. It
  receives observation-only JSON, runs the current primary analyzer and all four
  frozen selector profiles, advances independent display gates at timer
  deadlines, and returns complete decisions and accounting.

The raw path has no switch for an ASAP test entry, the POP909 `held` field, or a
When in Rome test fixture. It resolves exactly 23, 101, and 59 permitted source
items, respectively; hashes that complete source plan before output; verifies a
source again around its analysis; requires the pinned external checkouts to be
clean; and requires the WhatChord repository itself to be clean. Detailed
copyrighted or license-gated observations can only be written to a new child of
`build/`.

The Dart result is checked before each piece report is written. The check binds
every returned observation to its label-free request, requires exactly the four
frozen profiles, reconciles frame, transition, episode, and duration totals,
requires each displayed assignment to exhaust its sounding notes, and requires
the exact selector trace that supported every appearance. Aggregate reports add
nearest-rank appearance-latency and episode-duration distributions. The When in
Rome summary uses the explicit names `committedEventProposals` and
`committedIdentityDurationAttributedMs` and contains no display state.

The local review packet names notes by pitch and octave, shows plain-language
layer and primary-chord names, gives the exact register boundary, and renders a
time-scaled note-state view with separate held, pedal-sustained, attack,
release, and pedal-change marks. A When in Rome proposal instead carries a
prominent static-snapshot warning; the harness does not manufacture an event
timeline from its sparse fixture. A separate review index binds every blank
disposition item. The validator requires exact item coverage and complete
frozen-category judgments while permitting a correction to be appended to the
original judgment history.

## Pre-result contract correction

The complete Python suite initially stopped with 29 failures and three errors
before any case logic ran. Every failure reported the same dependency mismatch:
the frozen suite pins output contract SHA-256
`e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44`, but log
2026-08-11-08 had also edited that already-frozen document to SHA-256
`56befc025222647f2e7111cbe5b1962a2b3102b00fd5dce3a07bfcc1db002bc4`.

The prior entry correctly narrowed what the sparse When in Rome source can
measure, but applying that clarification to a pinned dependency made the frozen
suite impossible to validate. This step restores `output-evaluation-contract.md`
byte-for-byte to its frozen digest. The source-specific clarification remains
normative in `development-exposure-v1.md` and `PROTOCOL.md`: ASAP and POP909 are
the declared frame-replay development corpora for stable-display safety, while
When in Rome is a separately named proposal-only companion. No selector rule,
suite case, score, adoption threshold, or development result changed. The
complete Python suite then passed.

The preregistration's packet wording also said every item had a time-scaled
event timeline even though the same document prohibited synthesizing one for
When in Rome. Before any report existed, this step corrected that internal
contradiction: common item fields are fixed for every source, the complete
unfolding timeline is required only for frame-capable sources, and sparse
proposal items must disclose their missing event evidence.

## Results

All verification was synthetic or repository-internal:

- the pure-Dart stable reducer passed 9 focused tests;
- the development-exposure controls passed 15 tests, including a live
  Python-to-Dart timer cross-check;
- the complete polychord Python suite passed 261 tests after the frozen digest
  was restored;
- the complete `packages/whatchord` suite passed 563 tests;
- root and package Dart analysis, both import-order checks, Python formatting
  and lint, Markdown formatting, and whitespace validation passed; and
- source-isolation controls constructed temporary 23/101/59 rosters and proved
  that only the permitted development and sample files were hashed. Those
  controls did not open a real corpus item.

No ASAP development or test performance, POP909 sample or held song, or When in
Rome development or test fixture was sent to the generator, selector, primary
analyzer, or display gate in this step. No official or partial output directory
was created. In particular,
`build/polychord/register-selector-development-exposure-v1` remains absent.

Final implementation and contract hashes are recorded after formatting:

- `packages/whatchord/lib/src/polychord/services/polychord_stable_display_gate.dart`:
  `df40fac84aa5d2570754ce69482a0697fc6f8fb7eabf3f59b9b929199ecefd8c`;
- `tool/polychord/development_exposure_batch.dart`:
  `5e3085805d60a5ca72c529f4f01588d4b87b8c5c654e7eba82a4daa31bc97fd2`;
- `tool/polychord/development_exposure.py`:
  `05516fce9ea1dc89079f7507f42bbb13c11a990d2131277c7adac772ff761b52`;
- `tool/polychord/development_exposure_test.py`:
  `e3b5fb4729e42ed3293f4bb6c5329e32cceec01b0d3a31e3f3efaa7e54e5f1f9`;
- `tool/polychord/validate_development_dispositions.py`:
  `9bfa792df75c3360b325107fcfaefb690d3b17cd860e118f71b32d9043685a7d`;
- `research/polychord/development-exposure-v1.md`:
  `e63c26c93523b1ea99358dfe0ac5ec109964137f1b97fac44b2a96831dbc92e4`;
- `research/polychord/PROTOCOL.md`:
  `176718e03afd0bf6926bd4958a6f07bd1399d55f0547a990e11678ed7e63f668`; and
- restored `research/polychord/output-evaluation-contract.md`:
  `e698a659800a16ea5bcb94942ed69fe1a5adb0fa4d60257bd1054979055ecb44`.

**Plain-English reading.** The next measurement now has a committed-shape
implementation that cannot quietly read the reserve, use chord labels as inputs,
turn sparse snapshots into fake performances, or omit inconvenient fires. Its
musician-facing review surface shows how the notes actually unfold where that
evidence exists. This step also repaired a provenance mistake: a helpful
source-specific clarification had accidentally changed a document that the
frozen ruler was designed to verify byte-for-byte.

**Decision.** Treat this worktree as the premeasurement implementation boundary.
The stable reducer is shared pure-Dart analysis infrastructure; the corpus
adapters and reports remain research tooling. Keep the restored output contract
immutable and put source-specific measurement refinements in separately pinned
measurement contracts. Do not read or tune from a development result before this
boundary is committed.

**Next.** After this worktree is committed and clean, the first and only
designated run is:

```sh
./.venv/bin/python tool/polychord/development_exposure.py \
  --asap-root build/whatkey-corpora/asap-dataset \
  --pop909-root build/whatkey-corpora/POP909-Dataset/POP909 \
  --out-directory \
    build/polychord/register-selector-development-exposure-v1
```

Run it to completion without reading partial selector summaries, verify the
manifest and accounting, then disposition every full-selector item. Do not open
the 808-song POP909 reserve.
