# Polychords

A dense sonority can often be forced into one extended-chord name even when the
music is more clearly built from two familiar chords. When should the app also
show that two-layer reading, and what evidence can live MIDI provide without
pretending to know what a listener hears or a composer intended?

**Status:** complete. A conservative secondary annotation is implemented and
approved for release after the author-adjudicated product ruler, prior-art
comparison, performance gate, cross-platform acceptance, and final false-display
reserve all passed. Independent validation remains optional future work.

## What came out

- **The implementation leaves the primary chord unchanged.** Live timestamped
  MIDI can add a stacked upper-over-lower annotation when two complete chordal
  groups in adjacent registers have qualifying attack histories. The snapshot
  analyzer, ranking, history segmentation, key inference, and Explore behavior
  remain unchanged.
- **Register alone was not enough.** The first register-only selector passed its
  maintained suite and then produced 73 stable annotations on the 101-song
  POP909 development sample. Every one was an ordinary integrated harmony or a
  serialization artifact. That failure established onset evidence as a required
  product cue rather than an optional refinement.
- **Both layers use the same vocabulary.** Major and minor triads plus dominant,
  major, and minor seventh chords are available above or below. This is not an
  upper-triad-only detector. Shared pitch classes are allowed only when separate
  sounded notes can support both layers; bass notes, fifths, shells, same-root
  groups, and three-or-more-layer readings stay outside the initial scope.
- **The evidence claim stays narrow.** _Polychord_ names a useful constructional
  or notational decomposition, not two simultaneous keys, perceptually
  independent streams, or compositional intent. No surveyed corpus supplies
  verified positive labels, so corpus runs measure false-display exposure, not
  recall or general detection accuracy.
- **Existing software did not supply the required behavior.** The frozen
  descriptive comparison found complementary partial matches from musicpy,
  mingus, and ChordRecGen, but none combined ordered layers, exact note
  assignment, temporal evidence, and conservative abstention under the product
  contract. The broader literature search found no published computational
  polychord detector within its recorded scope.

## Results

The pure-Dart product matched the Python reference on the frozen product suite
and passed all 108 timestamped checkpoints across 20 cases. Its primary output
and established regressions remained unchanged, the optimized live path passed
the frozen performance budget, and hands-on iPhone and Android checks found the
functional and accessibility behavior acceptable.

The final POP909 safety replay covered 808 songs and 2,303,088 app-equivalent
source frames. Two candidates briefly entered the hidden pending state, both
cleared after 69 milliseconds, and neither reached the 200-millisecond display
deadline. The result was **zero stable annotations and zero displayed time**.
Because an earlier replay aborted after exposing one negative song, this is
recorded as a post-abort completion rather than a perfectly pristine held
estimate. Because the corpus has no verified positive labels, it says nothing
about how many real polychords the detector may have missed.

The author-adjudicated named-snapshot comparison is descriptive rather than an
independent benchmark. On the 14 positives with an eligible ordered register
split, the WhatChord register policy matched all 14, compared with 5 for musicpy
and 2 each for mingus and ChordRecGen. The other systems were not designed for
this product vocabulary or evidence contract, so these figures establish
behavioral differences, not a general accuracy ranking.

## Where this fits

This initiative separates two questions that a static pitch set cannot answer by
itself: whether notes admit a two-chord decomposition, and whether the live
evidence justifies showing that decomposition. The failed register-only version
made that distinction operational. The implemented feature therefore lives in
the timestamped MIDI path as a secondary annotation rather than inside the pure
snapshot chord analyzer.

Two musically important classes remain outside the automatic policy:
overlapping-register constructions such as Stravinsky's _Augurs_ and unfolding
constructions such as the _Petrushka_ chord. Supporting either would require a
new observable assignment model, not merely a looser threshold. A future claim
of reproducibility or generalized accuracy would likewise require a separately
registered study with evidence-complete examples and independent annotation.

## Contents

- [Protocol](PROTOCOL.md): claim boundaries, evidence rules, project
  progression, and product guards.
- [Framework](FRAMEWORK.md): theory-derived vocabulary and the separation of
  construction, perception, and intent.
- [Product completion plan](product-completion-plan.md): the acceptance gates
  and completed delivery sequence.
- [Product output contract](product-output-contract-v3.md) and
  [selector](onset-register-selector-v1.md): the implemented secondary output
  and timestamped-MIDI policy.
- [Prior-art search](prior-art-search.md): the academic, software, terminology,
  and notation survey.
- [Results](results/): committed comparison and reserve summaries.
- [Log](log/): dated, append-only record of experiments, corrections, and
  decisions. The final reserve result is
  [2026-08-27-04](log/2026-08-27-04-complete-product-held-exposure.md).

Supporting research code lives in `tool/polychord/`. The product implementation
lives in the pure-Dart engine under `packages/whatchord/` and in the app's
timestamped MIDI presentation path.
