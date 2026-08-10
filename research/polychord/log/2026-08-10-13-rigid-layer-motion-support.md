# 2026-08-10: Define rigid-layer motion support

**Goal.** Fix the narrowest musically defensible motion interpretation over the
threshold-free frame-transition contract without introducing a monophonic
voice-assignment model, tuned distance, or hidden candidate correspondence.

**Setup.** Work began from repository commit `c234bf3b`. The source evidence
contract was `polychord-frame-transition-evidence/1`. No corpus measurement,
candidate-exposure total, product-policy result, or held data was read before
fixing this ablation.

The voice-assignment sources recorded in log 2026-08-10-12 established that
changed-pitch note identity is inferred rather than observed. Four additional
exact searches, now queries 8-11 in `prior-art-search.md`, checked whether the
product question could begin with a narrower set-level motion criterion:

1. `"Pitch Co-modulation Principle" music auditory stream`
2. `"common fate" "parallel motion" auditory streaming music`
3. `Huron voice leading parallel motion perceptual fusion common fate`
4. `site:mtosmt.org issues mto.25.31.4 Moreira parallel motion polychord`

The material result was Moreira's polychord-specific synthesis in paragraphs
6.2-6.3 of
["Weird, Menacing, and Colorful: Bernard Herrmann's Harmonic Polytonality"](https://mtosmt.org/issues/mto.25.31.4/mto.25.31.4.moreira.html),
which applies Bregman and Huron to moving chordal groups. It describes
internally parallel triadic groups as textural streams and oblique or contrary
motion between the groups as favoring separation. Huron's broader source is
_Voice Leading: The Science Behind a Musical Art_
([2016](https://doi.org/10.7551/mitpress/9780262034852.001.0001)). Neither
source defines a computational polychord detector or a numerical boundary.

The final pins are:

- motion-support contract:
  `7608888f5a10c565038858b17b79660600d1cd83031b860dfb32cf64e72af77f`;
- synthetic contrary-motion fixture:
  `6afce7ce6e094fc6777f36816b78f2d11157a997204363f71764c9f7d6385791`;
- seven-fixture replay manifest:
  `4a04d0721187e3b365bf3ce2f52cef8784ace84b711a536a1a1972bf1264750a`;
- implementation:
  `89cb372cb8f3055779624d4d4870c08381d5da65c24531fde5de1791152c61cf`; and
- focused test module:
  `44a920373098f6dd8372e4d262d47168d470c6cb4c1975f98fa3c8ae6861e7d7`.

The exact validation commands were:

```sh
python3 tool/polychord/motion_support.py \
  --fixture \
  research/polychord/data/frame-replay/two-register-contrary-motion.json \
  --from-after-event-index 5 \
  --to-after-event-index 17
python3 tool/polychord/motion_support.py \
  --fixture \
  research/polychord/data/frame-replay/two-register-inner-motion.json \
  --from-after-event-index 5 \
  --to-after-event-index 9
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/prior-art-search.md \
  research/polychord/motion-support-ablation.md \
  research/polychord/log/2026-08-10-13-rigid-layer-motion-support.md
shasum -a 256 \
  research/polychord/motion-support-ablation.md \
  research/polychord/data/frame-replay/two-register-contrary-motion.json \
  research/polychord/data/frame-replay/manifest.json \
  tool/polychord/motion_support.py \
  tool/polychord/motion_support_test.py
git diff --check
```

**What happened.** The fixed ablation is `rigid-layers-oblique-or-contrary/1`,
emitted as `polychord-motion-support/1`. It evaluates both unranked endpoint
layer-correspondence hypotheses independently.

Within a mapped layer, the complete target MIDI-note set must equal the complete
source set shifted by one signed integer number of semitones. Cardinality,
doubling, inversion, and internal intervals must remain exact. The output
records this raw set relation separately from its chord-identity guard: motion
support also requires the same quality and a root pitch class shifted by that
same interval. This defines strict chordal-group translation, not a learned or
optimized link between monophonic voices.

When both mapped layers are exact translations, the two signed deltas are
classified as static, common translation, oblique, contrary, or unequal
same-direction motion. Only oblique and contrary classes provide one-sided
positive support. Static layers and common translation do not differentiate the
proposed groups. Unequal same-direction motion remains neutral because the
polychord-specific source gives a clearer basis for oblique and contrary motion
than for that intermediate case.

Exact retained sounding instances are classified as consistent, contradictory,
or absent relative to each hypothesis. Any retained instance outside a
hypothesis forces that hypothesis to neutral. Retained continuity is not
required: a complete rearticulation can still instantiate an exact set-level
translation, but the output reports that retained-instance evidence is absent.

The new `two-register-contrary-motion` fixture moves the lower G-minor set down
two semitones to F minor and the upper C-major set up two semitones to D major.
All source note-offs and target note-ons occur at 100 milliseconds, and the
replay preserves their exact zero-dwell order. The register-role-preserving
hypothesis is a contrary pair of rigid translations and receives positive
support; the exchanging hypothesis is non-rigid and neutral.

The previously committed inner-motion fixture is deliberately neutral. Its
register-role-preserving minor-to-major and major-to-minor changes are not exact
translations. The exchanging correspondence happens to yield rigid translations
of plus and minus 17 semitones, but all four retained sounding instances
contradict it, forcing neutral support. The apparent inner links between
departed and arrived pitches remain unassigned. Unit controls additionally
freeze positive oblique motion and neutral static, common-translation, unequal
same-direction, cardinality-change, malformed-identity, retained-contradiction,
and empty-candidate outcomes.

Adding the fixture changes the replay manifest digest to
`4a04d0721187e3b365bf3ce2f52cef8784ace84b711a536a1a1972bf1264750a`, which is
pinned by the unchanged eight-case internal suite. No suite case, expectation,
eligibility field, corpus split, score, or previous evidence schema changed.
Twelve focused tests bring the complete polychord Python suite to 137 passing
tests.

**Plain-English reading.** If every note in one proposed chord moves together by
the same interval, that chord can be treated as one moving block. When the other
proposed chord also moves as a block but goes the opposite way, or stays still
while the first moves, that difference supplies conservative evidence for two
layers. If the notes are rearranged, added, removed, or all move together as one
large sonority, this first rule makes no claim.

**Decisions.** Begin motion work at the chordal-set level rather than importing
a full voice-separation model. Adopt exact MIDI-set translation as the first
threshold-free operational meaning of internal parallel motion. Grant one-sided
support only to oblique and contrary between-layer classes. Interpret both
correspondence hypotheses and select neither. Allow modeled support without a
retained instance, but never allow support when retained continuity contradicts
the hypothesis.

Treat revoicing, note entry or exit, changed doubling, same-direction unequal
motion, static layers, and whole-sonority translation as neutral. Do not add a
distance optimizer, crossing rule, entry or exit cost, learned weights,
confidence, rejection, endpoint selection, or display policy. Any more
permissive motion profile requires a new named model and provenance.

**Next.** Commit the contract, implementation, fixture, tests, and literature
record as one logical ablation change. Before measuring corpus exposure,
preregister how source and target endpoints are enumerated from the event
stream, including candidate entry and exit, zero-dwell construction frames,
intervening noncandidate frames, maximum temporal separation if any, and the
unit of exposure. Keep the 808-song reserve untouched. Stable-display behavior
remains a later, separate contract.
