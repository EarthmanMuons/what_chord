# 2026-08-10: Fix the threshold-free onset-evidence contract

**Goal.** Preserve exact attack provenance for every sounding note in a register
candidate before deciding how onset grouping should affect confidence,
abstention, or display.

**Setup.** Base repository commit `b2f1e440`. No development or held-out corpus
fixture, corpus annotation, product-policy label, or corpus detector result was
read. The work used only the four neutral replay fixtures fixed in log
2026-08-10-02 and the structural candidate generator fixed in log 2026-08-10-03.
The active internal-suite expectations were not consumed by the implementation.

The contract was checked with:

```sh
python3 tool/polychord/onset_evidence.py \
  --fixture research/polychord/data/frame-replay/synchronous-six-note-cohort.json \
  --after-event-index 5
python3 tool/polychord/onset_evidence.py \
  --fixture research/polychord/data/frame-replay/two-register-held-cohorts.json \
  --after-event-index 5
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/README.md \
  research/polychord/onset-evidence-schema.md \
  research/polychord/log/2026-08-10-05-onset-evidence-contract.md
shasum -a 256 \
  research/polychord/onset-evidence-schema.md \
  tool/polychord/onset_evidence.py \
  tool/polychord/onset_evidence_test.py \
  research/polychord/data/frame-replay/manifest.json \
  tool/polychord/frame_replay.py \
  tool/polychord/register_candidates.py
git diff --check
```

**What happened.** `polychord-onset-evidence/1` now reconstructs the note-on
event that created each currently sounding note instance. Every per-note record
retains MIDI pitch, pressed or pedal-sustained state, onset event index, onset
timestamp, and raw attack velocity. Notes carried into a cropped replay window
retain `null` origins rather than receiving invented attacks. The document
builder loads a fixture path and hashes those same bytes internally, so callers
cannot pair an evidence record with an unrelated digest.

Note-off under a down sustain pedal preserves the onset while the note keeps
sounding. Reattacking a pedal-sustained note replaces only that note's origin
with the new event. Pedal release removes origins for notes that stop sounding.
Attacks at one timestamp keep distinct event indices, preserving causal order
without falsely treating delivery order as an onset-time difference.

Each exact lower and upper candidate assignment reports known and unknown onset
counts, distinct known timestamps, earliest and latest known times, and raw
within-layer span. When every onset is known in both layers, two signed endpoint
differences locate the upper onset interval relative to the lower interval. They
remain `null` for incomplete history.

The matched six-note controls confirm the intended separation:

- both final frames produce the identical `C|Gm` candidate;
- the synchronous fixture reports zero-millisecond lower and upper spans and
  zero for both signed relations; and
- the layered fixture reports zero-millisecond within-layer spans and 400
  milliseconds for both signed relations.

These are raw evidence facts, not positive and negative product labels. The
implementation contains no onset tolerance, cohort threshold, confidence,
ranking, abstention, or display rule. It also never creates a new candidate from
timing and never reads an internal-suite expectation. Attack velocity is
retained as provenance but receives no grouping or confidence weight.

Twelve new tests cover identical structural output across matched histories, the
zero-versus-400-millisecond evidence difference, same-timestamp event order,
unknown carried-in origins, sustain retention, reattack replacement, pedal-up
cleanup, frames without candidates, exact output fields, unknown frames, and
invalid replay rejection. The complete polychord Python suite contains 69
passing tests.

Pinned SHA-256 digests:

- onset-evidence schema:
  `7b6107917a0df80f00d8c84a6b5a081271a28305adc5042eef7f3875a3178fe1`;
- onset-evidence implementation:
  `647f3c47b4ba5347d4b67c4a6fa0e90689dddb566b7a658b30c31697b4c3ec01`;
- onset-evidence tests:
  `064f2515b0be339b49089b55228179c3edf55ca2ba1977203e9d74ab063ea69a`;
- unchanged frame-replay manifest:
  `9168ae68010415bf38439d8d774040e4272bbb5529c2e4089680c9ab4fdaa06e`;
- unchanged frame-replay validator:
  `826a593721f14e673a8a70a351ba78f1179b58977a5574fa6f9ece0c430f31f0`;
- unchanged register generator:
  `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`.

**Plain-English reading.** We can now distinguish notes attacked together from
two note groups attacked at different times without yet deciding what difference
is large enough to matter. We also know when a note's attack happened before the
recording window, survived only through the pedal, or was replaced by a new
attack. The evidence remains inspectable instead of being collapsed into a
premature score.

**Decisions.** Adopt `polychord-onset-evidence/1` as the raw onset contract.
Require every output document to identify the exact fixture bytes. Treat the
most recent note-on as the origin of the current sounding instance, retain
unknown initial origins, and compute candidate relations only when all onsets
are known.

Do not classify onset cohorts or apply a tolerance in this contract. Do not use
simultaneous onset as automatic evidence against a polychord, and do not use
separated onset as automatic permission to show one. Any such interpretation
must be a separately named, pinned ablation with explicit fallback behavior.

**Next.** Define the smallest musically defensible onset interpretation as a
named ablation over this raw contract, including tolerance and unknown-history
behavior, before measuring it. Release grouping, pedal weighting, and motion
remain later incremental evidence rather than implicit parts of the onset step.
