# 2026-08-10: Freeze frame-transition evidence

**Goal.** Establish the minimum reproducible substrate for studying motion
across polychord candidates without silently treating an inferred note pairing
as observed voice identity.

**Setup.** Work began from repository commit `023c59c8`, after the
threshold-free release/pedal evidence contract was committed. A bounded
adjacent-literature screen used seven exact queries recorded in
`prior-art-search.md` and followed material results to primary publication
records. The resulting boundary is documented in
`frame-transition-evidence-schema.md`.

The final contract and control pins are:

- framework: `a5d83115be7d700e007110fe8f1313d435ad456f4c122f5f7d184baf423a212a`;
- schema document:
  `7db90bb1a40fc0a34be5a1ab84da0724ae2da1db0dd8529b81e2d31970eccc78`;
- synthetic fixture:
  `25c9e9f4327b364c33338467104d0dc2a07c1080a20ff665718909a7f98178a2`;
- frame-replay manifest:
  `eebf4a53916f87ff68ea27bed9aa91cb73ff77e1f8edf1fa1ed76e17923cc6aa`;
- implementation:
  `6a843a87ed7e8b9223f480495d6237318944b6d36510dc6e939bc59a23c0fa84`; and
- focused test module:
  `fb7ba43047a2322db236b824818687110283b6198d5a3e3a2cd998e89f279b0f`.

The exact validation commands were:

```sh
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 tool/polychord/transition_evidence.py \
  --fixture \
  research/polychord/data/frame-replay/two-register-inner-motion.json \
  --from-after-event-index 5 \
  --to-after-event-index 9
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/FRAMEWORK.md \
  research/polychord/PROTOCOL.md \
  research/polychord/release-pedal-evidence-schema.md \
  research/polychord/frame-transition-evidence-schema.md \
  research/polychord/prior-art-search.md \
  research/polychord/log/2026-08-10-12-frame-transition-evidence-contract.md
git diff --check
```

**What happened.** The adjacent literature consistently treats voice separation
or voice segregation as an inference task. Surveyed methods use explicit
perceptual rules and parameters, supervised note-to-voice assignments,
contextual note affinity, or predicted links between successive notes. A
channel-blind MIDI event sequence therefore observes continuation only while the
same sounding instance remains alive; it does not observe that a departed pitch
became a newly arrived pitch.

The new `polychord-frame-transition-evidence/1` contract accepts two exact,
caller-selected replay frames. It retains every ordered event and derived frame
between the endpoints, including same-timestamp and zero-dwell transitions. It
generates each endpoint candidate set independently and reports their Cartesian
product, without choosing a predecessor, successor, or path.

For every candidate pair, a sounding instance is keyed by MIDI note and the
note-on event that established its current life. The contract partitions exact
instances into retained, departed, and arrived sets. A restrike of the same MIDI
note is a departure plus an arrival, not retention. Pressed-to-sustained state
change under the pedal can retain the same instance. Carried-in unknown onsets
remain usable only while uninterrupted replay proves their continuity.

Each candidate pair exposes all four source-to-target layer relations and both
possible two-layer bijections: register-role preserving and register-role
exchanging. It reports root, quality, pitch-class, complete all-pairs
pitch-delta matrices, and exact retained-instance membership. Neither bijection
is ranked, and no departed pitch is paired with an arrival.

The synthetic `two-register-inner-motion` control changes `C|Gm` to `Cm|G` by
releasing MIDI notes 46 and 64 and attacking 47 and 63. Notes 43, 50, 60, and 67
remain the same sounding instances in the same endpoint register roles. The
contract reports those four continuities but intentionally does not report the
obvious generation-recipe links 46-to-47 and 64-to-63 as facts.

The replay manifest now contains six fixtures, and its updated digest is pinned
by the unchanged eight-case internal suite. No suite case, expectation,
eligibility field, corpus split, or score was changed. The full polychord test
discovery passed 125 tests.

**Plain-English reading.** The new tool can say that a particular still-sounding
key belongs to the lower group at both selected moments, or that it moved from
one endpoint group to the other. It can also show every pitch distance between
the two endpoint chords. It will not say that one released key "became" a newly
pressed key, because MIDI did not tell us that. Making that musical connection
is the next model to define and test.

**Decisions.** Name this layer `frame-transition evidence`, not motion evidence.
Use the established terms `voice separation` and `voice segregation` for the
adjacent inference problem, while preserving WhatChord's constructional
polychord claim boundary. Treat only uninterrupted sounding-instance continuity
as observed note identity. Enumerate all endpoint layer relations and both
two-layer correspondences, and rank neither. Preserve all intermediate event
steps. Leave endpoint selection, changed-pitch assignment, crossings, coherence,
confidence, abstention, and display behavior outside schema 1.

**Next.** Commit the contract, fixture, documentation, and tests as one logical
change. Then preregister a bounded voice-assignment and motion-coherence
ablation, including its exact target claim, treatment of note entry and exit,
crossing behavior, parameters or trained weights, and synthetic controls. Do not
run a corpus measurement or let motion affect product output until that model
and its evaluation are fixed. Stable-display aggregation remains a later,
separate contract.
