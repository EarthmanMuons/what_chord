# 2026-08-10: Fix the register-only candidate generator

**Goal.** Turn Framework v0's conservative register baseline into an exact,
executable research contract without introducing ranking, display policy, or
temporal inference.

**Setup.** Base repository commit `acd08771`. No development or held-out corpus
fixture, corpus annotation, reference chord label, or detector result was read.
The committed neutral frame-replay fixtures and synthetic split-census tests
were used. The historical schema-3 census implementation was inspected and left
unchanged because its bytes are pinned to earlier measurements.

The implementation was checked with:

```sh
python3 tool/polychord/register_candidates.py 48 52 55 66 70 73
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/README.md \
  research/polychord/PROTOCOL.md \
  research/polychord/README.md \
  research/polychord/register-candidate-schema.md \
  research/polychord/log/2026-08-10-03-register-only-candidate-generator.md
shasum -a 256 \
  research/polychord/register-candidate-schema.md \
  tool/polychord/register_candidates.py \
  tool/polychord/register_candidates_test.py \
  tool/polychord/split_census.py
git diff --check
```

**What happened.** `polychord-register-candidates/1` now enumerates every
qualifying boundary between adjacent sounding notes in one frame. Both the lower
and upper group use the same complete-common vocabulary: major and minor triads
plus dominant, major, and minor seventh chords. Both groups must account for
every note on their side of the boundary, their recognized roots must differ,
and any shared pitch class must be supplied by a separate sounded MIDI note in
each group.

Every proposal retains the zero-based boundary index, adjacent boundary notes,
gap in semitones, upper and lower root and quality, exact MIDI-note assignment,
pitch-class assignment, shared pitch classes, and neutral `upper|lower` research
symbol. Ordering is deterministic. The generator does not consume event history,
labels, current analyzer output, or corpus annotations, and it performs no
ranking, confidence estimation, symbol deduplication, stable-display filtering,
or temporal inference.

There is no minimum register gap in generation. A synthetic integrated D6
voicing therefore exposes its exact `Bm|D` structural split at a two-semitone
boundary. That is intentional: it proves that a proposal is not a display
decision and leaves gap evidence available for a later named ablation instead of
burying a perceptual threshold in the baseline.

Twelve new tests cover the exact symmetric vocabulary, serialized schema,
complete note assignments, separate-note shared pitch classes, inversions and
internal octave doubling, same-root exclusion, incomplete-layer exclusion, the
absence of a hidden gap threshold, multiple qualifying boundaries, strict frame
input, identical register output for replay states with different event
histories, and compatibility with the historical `complete-common` detector on
four synthetic cases. The full polychord Python suite contains 44 passing tests.

Pinned SHA-256 digests:

- register-candidate schema:
  `533c20205d07e14291029af3455c366e0605d1a5c4b96311be85879069f22538`;
- generator: `7aa7758e91bf1279df8b26e03d1cbbbf90cedfc45ae2c5b0aeddf1ee18d8e250`;
- generator tests:
  `675e5a9667f1838af053f2876c4c61b4acf2961c327b4f2b4d0b4eb9069ec496`;
- unchanged historical census:
  `493f8daead302572b8548b6ae581a0f2fac4735bb69a3ce1e189647790e1179b`.

**Plain-English reading.** The first detector stage now does only one auditable
job. It finds all places where the notes can be cut into a complete lower chord
and a complete upper chord. It does not decide that the two-chord description is
the best musical reading. Timing, pedal behavior, motion, and product display
rules can now be tested later without changing what the baseline means.

**Decisions.** Adopt `polychord-register-candidates/1` as the structural
proposal contract for the register-only baseline. Keep the layer vocabulary
symmetric; the upper structure is not restricted to triads. Enumerate all valid
boundaries and retain exact note assignments rather than collapsing candidates
that happen to share a symbol.

Do not encode a minimum register gap, rank, confidence, or display gate in the
generator. Keep sharp-name `upper|lower` symbols as neutral research labels;
enharmonic and user-facing presentation remain part of the later product output
contract. Preserve `tool/polychord/split_census.py` unchanged so the schema-3
measurement record remains reconstructible from its original implementation.

**Next.** Build the initial author-adjudicated internal suite with exact input
fixtures, source and epistemic provenance, product expectation, and separate
eligibility for register-only and temporal input. Then define onset, release,
pedal, and motion evidence as named ablations over the fixed replay and
candidate contracts before evaluating any product lever.
