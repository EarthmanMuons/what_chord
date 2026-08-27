# 2026-08-27: Freeze post-abort reserve completion

**Goal.** Prospectively freeze an app-equivalent completion replay after the v2
technical abort, without using musical output to change the feature or harness.

**Setup.** Log 2026-08-27-02 retains the v2 command, error, and sole completed
piece. Product behavior remains commit
`1a1cb852c990c436438ba82120b7a295d006bf0b`; release-candidate commit
`6f9c4afb5c03f145646761eeda45cd9c46bd43a1` added only the now-aborted v2
measurement correction. The v2 partial directory remains unchanged, and
`build/polychord/product-held-exposure-v3` is absent.

V3 replaces the historical development state normalizer in the held harness with
a dedicated projection of current `midiTemporalEventsProvider` behavior. It
filters repeated pressed-note attacks and unmatched releases, transitions valid
releases to sustain only while pedal is down, filters repeated pedal states,
clears sustained notes on pedal release, and emits an empty reset for every
CC120 or CC123 while preserving pedal state. The unchanged historical Mido
parser still owns source selection and deterministic message order.

The five label-free controls were run with:

```sh
mise python:format
mise python:lint
./.venv/bin/python -m unittest discover \
  -s tool/polychord -p 'held_exposure_test.py'
npx prettier --write \
  research/polychord/PROTOCOL.md \
  research/polychord/product-completion-plan.md \
  research/polychord/held-exposure-v3.md \
  research/polychord/log/2026-08-27-02-retain-aborted-held-exposure.md \
  research/polychord/log/2026-08-27-03-freeze-post-abort-reserve-completion.md
git diff --check
```

All five controls passed. The new failure-shaped control applies pedal down and
then releases unpressed note 69; it requires one pedal event, zero sounding
notes, and one filtered-unmatched-release count. No additional held piece was
replayed while developing or validating the correction.

**Prospective artifact pins.** These SHA-256 values were computed before the v3
completion run:

| Artifact                    | SHA-256                                                            |
| --------------------------- | ------------------------------------------------------------------ |
| Held exposure v3 contract   | `7eeef88ab3a27b299dad2ad89b930cd10b92aaac8ed27de7c72f9e858b544ec2` |
| Held Python harness         | `b01723ab661539ba2c63bcbc1c6264fd1a40481853ca35a7ae51d9cbc439de03` |
| Held Dart product batch     | `354786dc225b42c551cb6c40e6977eaacc766f6e52cad5e903cbe54ea14b98e9` |
| Held harness controls       | `2874b5b3eeeecbab41ed00b3f082f7a5a01c5d588fe33070c1da10590e4ec537` |
| Held result verifier        | `570f649886c0a0c5e0699b05e5f3ac011f53b8ff601bd66a9f06ea2ae9c3dc8c` |
| POP909 roster               | `b368b33c488680393b5c397d37faee4332ad39a3caee05fd547687dcc969d781` |
| Product engine              | `3e042ec8b7a8a29fd94787eb9faf70e89476773379b6b0bfc926bd9d4fa66aaa` |
| Onset/register selector     | `26555ac9f6730d6bcfaede93a38bf637b98b709762c5f9c1823b77855d8dd4ba` |
| Authorization gate          | `b4fcca861ed98fb8378fd9273a2fe0466585ccf1115a8e142d4fdb7060805c3e` |
| Historical source parser    | `21d3de85923d488f35a93bfd5c8aa1317ca087eea7c7ba889aca7b5ec338e6ab` |
| App temporal provider       | `3adfa65779fb1d08da779f105b4b67e058f933b2d68d1ff6b238ca47f162911d` |
| Retained v2 song 002 report | `a09a183a7b11dba36c35ded81e696e45007811c06c7031407ffafed2985cf4d0` |

**Plain-English reading.** V3 changes only how the test reconstructs the MIDI
events the app would accept. It does not change which polychords qualify. The
reserve is no longer perfectly untouched because one negative song completed and
the next exposed an input irregularity, but no musical decision was tuned.

**Decisions.** Adopt `held-exposure-v3.md` as the sole completion contract.
Describe its result as post-abort reserve evidence, not a pristine held
estimate. Keep v2 unchanged. Require a clean commit before running v3, and
retain v3 regardless of outcome.

**Next.** Commit this prospective boundary, execute the two v3 commands exactly
once, adjudicate every stable display if any, and record the final release
decision with the v2 deviation attached.
