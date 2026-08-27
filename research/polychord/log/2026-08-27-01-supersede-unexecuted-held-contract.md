# 2026-08-27: Supersede the unexecuted held contract

**Goal.** Preserve an exact product-path held replay after the app adopted MIDI
All Sound Off (CC120) as the same empty temporal reset as All Notes Off (CC123),
without opening or informally inspecting the POP909 held reserve.

**Setup.** The v1 release-candidate freeze was committed at `bd411ee87`. App
commit `1a1cb852c990c436438ba82120b7a295d006bf0b` subsequently made CC120 clear
pressed and sustained notes in both the note-state and temporal-event providers,
while preserving pedal state. The v1 held command had not run and
`build/polychord/product-held-exposure-v1` and v2 were absent. Only repository
history, the public roster identity, artifact hashes, and output-directory
absence were inspected; no held MIDI was opened.

The v1 harness reused `development_exposure.normalize_midi_messages`, whose
frozen historical behavior deliberately ignored CC120. Running it after the app
change would therefore have measured a near-equivalent but no longer exact
input stream.

The correction leaves the shared historical parser unchanged. The held harness
now maps raw CC120 messages to the parser's CC123 reset immediately before
normalization, records `mappedAllSoundOffMessages`, and otherwise uses the same
source parser, projection, product engine, timers, primary-availability replay,
output, review, and verifier. The measurement ID advances from
`pop909-held-product-false-display/1` to `/2`, and output moves to a fresh v2
directory.

The controls and required repository checks were:

```sh
dart format .
flutter analyze
dart run import_order_lint:import_order
mise python:format
mise python:lint
./.venv/bin/python -m unittest discover \
  -s tool/polychord -p 'held_exposure_test.py'
npx prettier --write \
  research/polychord/PROTOCOL.md \
  research/polychord/product-completion-plan.md \
  research/polychord/held-exposure-v2.md \
  research/polychord/log/2026-08-27-01-supersede-unexecuted-held-contract.md
git diff --check
```

All four harness controls passed, including a synthetic note-on followed by
CC120 that must yield an `allNotesOff` event and empty sounding frame. Flutter
analysis, Python formatting and lint, Dart formatting, import ordering, Markdown
formatting, and whitespace validation passed.

**Prospective artifact pins.** These SHA-256 values were computed before the
held reserve was opened:

| Artifact                    | SHA-256                                                            |
| --------------------------- | ------------------------------------------------------------------ |
| Held exposure v2 contract   | `add2182d8bba4fd3b7db791be37457635b531960a12cc8818a8330a06aadfb5c` |
| Held Python harness         | `28f20c0782e026ea56c932c66688e5dfa523b69af115214e20af3650d32148b1` |
| Held Dart product batch     | `354786dc225b42c551cb6c40e6977eaacc766f6e52cad5e903cbe54ea14b98e9` |
| Held harness controls       | `0e917fd7eb8255b5b72eabc9a3aecd2beb95766534ac6cfb0c469a925b87519f` |
| Held result verifier        | `570f649886c0a0c5e0699b05e5f3ac011f53b8ff601bd66a9f06ea2ae9c3dc8c` |
| POP909 roster               | `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781` |
| Product engine              | `3e042ec8b7a8a29fd94787eb9faf70e89476773379b6b0bfc926bd9d4fa66aaa` |
| Onset/register selector     | `26555ac9f6730d6bcfaede93a38bf637b98b709762c5f9c1823b77855d8dd4ba` |
| Authorization gate          | `b4fcca861ed98fb8378fd9273a2fe0466585ccf1115a8e142d4fdb7060805c3e` |
| Shared historical parser    | `21d3de85923d488f35a93bfd5c8aa1317ca087eea7c7ba889aca7b5ec338e6ab` |
| App MIDI constants          | `afcebea37caf32db329799028ba94008b9cdd49d0afd13272e5e07ecf5b9774a` |
| App temporal-event provider | `3adfa65779fb1d08da779f105b4b67e058f933b2d68d1ff6b238ca47f162911d` |

**Plain-English reading.** The feature did not change. One general MIDI reset
message changed elsewhere in the app after the first held plan was frozen. The
held replay now performs that same reset, so it will test the app users actually
receive. Because no held song was read, replacing the unexecuted plan does not
contaminate the reserve.

**Decisions.** Preserve v1 and its log unchanged. Adopt `held-exposure-v2.md` as
the sole authorized held measurement. Freeze the current app behavior at
`1a1cb852c`; permit only this harness correction and research record in the next
commit. Do not run either held command until that commit is clean.

**Next.** Commit this prospective v2 boundary. From that clean commit, execute
the two commands registered in `held-exposure-v2.md` exactly once, retain the
result even if it fails, and record the final product decision.
