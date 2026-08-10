# 2026-08-10: Establish the author-adjudicated suite seed

**Goal.** Create the first exact internal product-policy suite without treating
maintainer judgments as independent ground truth, turning a moving score passage
into a false snapshot, or conflating structural candidates with display
expectations.

**Setup.** Base repository commit `8f32e96c`. No development or held-out corpus
fixture, corpus annotation, or corpus detector result was read. The exact
synthetic observations come from the already committed register-generator and
frame-replay work. The Augurs observation and score provenance were promoted
from the score-verification record in log 2026-08-02-07; the score was not
redownloaded or reinterpreted in this session. Its pinned source remains the
composer's four-hand reduction, Archive.org identifier
`lesacreduprintem00stra_3`, SHA-256
`6871f14d62c39eeaa7a1482c644947870bbb30b297f0ed2b89321dad85f35495`, rehearsal
13, printed page 16, PDF page 18.

The seed was checked with:

```sh
python3 tool/polychord/internal_suite.py \
  research/polychord/data/internal-suite/suite-v0.json
python3 tool/polychord/frame_replay.py \
  --manifest research/polychord/data/frame-replay/manifest.json
python3 -m unittest discover -s tool/polychord -p '*_test.py'
mise python:format
mise python:lint
npx prettier --check --prose-wrap always \
  research/polychord/PROTOCOL.md \
  research/polychord/README.md \
  research/polychord/golden-candidates.md \
  research/polychord/internal-suite-schema.md \
  research/polychord/data/internal-suite/suite-v0.json \
  research/polychord/log/2026-08-10-04-author-adjudicated-suite-seed.md
shasum -a 256 \
  research/polychord/internal-suite-schema.md \
  research/polychord/data/internal-suite/suite-v0.json \
  tool/polychord/internal_suite.py \
  tool/polychord/internal_suite_test.py
git diff --check
```

**What happened.** `polychord-internal-suite/1` now records each claim at four
separate levels: musical construction, author product expectation, eligibility
of three named machine-input conditions, and exact unranked output from the
register-only generator. The suite pins its framework, schema, candidate schema,
frame-replay manifest, and validator. A dependency change invalidates the suite
until it is deliberately reviewed and repinned.

Every MIDI observation carries parallel scientific-pitch spellings. The
validator checks accidentals across octave boundaries, including the Augurs
spellings F-flat 2 and C-flat 3, so the machine representation remains auditable
without asking a musical reviewer to interpret MIDI numbers. It also checks the
F-double-sharp third required by the synthetic D-sharp dominant seventh instead
of accepting its enharmonic G spelling silently.

The eight-case seed contains:

- five positive construction cases: four exact synthetic register cases and the
  score-verified Augurs chord;
- one theory-derived upper-structure boundary; and
- two synthetic negative guards for an integrated D6 and same-root C-major
  register doubling.

The synthetic positives exercise triads and common sevenths symmetrically in
both layer roles, separate-note shared pitch classes, octave doubling, and a
pinned frame-replay observation. The D6 guard intentionally requires the
register baseline to emit `Bm|D` while the product expectation remains no
polychord annotation. The Augurs construction is the converse: it is a positive
two-unit construction with zero contiguous-register candidates because the
score-assigned units overlap in register. It is marked ineligible for that input
condition rather than counted as a miss. Its `upper|lower` symbol order remains
unresolved instead of being guessed from register.

Petrushka rehearsal 49 was not admitted. Its construction is score-verified, but
its concurrent arpeggiated streams do not yet have an exact frame-replay
transcription. The schema admission policy rejects the tempting six-note
verticalization because that collection is not one observed score snapshot.

Thirteen new tests validate dependency pins, all three product-policy classes,
upper and lower seventh-layer coverage, the Augurs eligibility separation, the
D6 proposal-versus-product distinction, the exact shared-tone replay frame,
enharmonic spellings, and rejection of changed candidates, invented notation
order, spelling mismatches, and changed dependency pins. The complete polychord
Python suite contains 57 passing tests.

Pinned SHA-256 digests:

- internal-suite schema:
  `cff86b7306681c4a72c8e9df31d229e96af55927c206e172f0ce48302d39866f`;
- eight-case suite:
  `8f44c6c9112926b3418948b743bf7efec5d0ba5f18a71a71f6eb4cce5a8e6c16`;
- validator: `6e93274594f185cd04325268d55ba5bf84f3492ff69f7757966f1e81bc4f7cd7`;
- validator tests:
  `5d288312db6665f0691be507b57c50de3643e7c657db47a5d6c2e5f1e039e8b1`.

**Plain-English reading.** We now have a small set of cases that says exactly
what notes are present, how a musician would spell them, what construction the
case represents, what the app could know from each kind of input, and what the
first mechanical split stage must return. A real two-chord construction does not
automatically become a detector error when the input hides its grouping, and a
mechanically valid split does not automatically become something the app should
show.

**Decisions.** Adopt `polychord-internal-suite/1` and the eight cases as an
active author-adjudicated seed. Keep `scoringAllowed` false until the composite
output representation, metric, adoption threshold, and display contract are
frozen. Results may be described as conformance to maintainer product policy,
never independent accuracy.

Require one musician-facing spelling per observed MIDI note and exact replay
references for temporal observations. Require construction units to assign every
observed note without sharing a MIDI instance. Preserve unresolved notation
order and input ineligibility rather than manufacturing a symbol or a false
detector target.

Do not admit moving literature examples until their exact event windows are
encoded. Continue using `golden-candidates.md` as an admission backlog, not as a
test ruler.

**Next.** Extend the seed with additional score-verified cases only where an
exact snapshot or replay can be encoded. In parallel, define the first onset
ablation over the fixed candidate, replay, and suite contracts. Do not score or
tune a product lever until the remaining output and evaluation decisions are
frozen.
