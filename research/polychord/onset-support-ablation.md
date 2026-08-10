# Conservative polychord onset-support ablation

Status: active research contract for `coherent-separated-onsets-50-200ms/1`,
emitted as `polychord-onset-support/1`. This is a named interpretation of the
raw `polychord-onset-evidence/1` contract. It supplies one-sided evidence for a
register candidate; it does not reject, rank, or authorize displaying one.

The canonical implementation is `tool/polychord/onset_support.py`. Its numeric
parameters are constants, not command-line options.

## Claim boundary

The ablation asks one narrow question:

> Do the known attack times form two internally tight, temporally separated
> cohorts that align with the candidate's lower and upper register layers?

A positive result means only that onset timing supports the proposed
decomposition. It does not establish two auditory streams, compositional intent,
two keys, or a ground-truth polychord identity. A neutral result is not negative
evidence. In particular, simultaneous attacks, expressive asynchronies, static
manual input, and incomplete history do not disqualify a candidate.

MIDI note-on timestamps are physical transport events, not measured perceptual
attack times. Instrument envelopes, latency, timbre, harmonic relation,
register, and musical context can all change perceived grouping. The profile is
therefore a reproducible conservative ablation, not a universal perceptual
boundary.

## Fixed rule

The profile has two inclusive parameters:

- `withinLayerCohortSpanMaximumMs`: 50; and
- `betweenLayerSeparationMinimumMs`: 200.

It emits `onsetCohortSupport: positive` only when all of the following are true:

1. every candidate-note onset is known;
2. the lower layer's latest onset is no more than 50 milliseconds after its
   earliest onset;
3. the upper layer satisfies the same 50-millisecond bound; and
4. the non-overlapping layer-onset intervals are separated by at least 200
   milliseconds.

Layer order is orientation-neutral: either lower then upper or upper then lower
can qualify. Intervals that overlap or touch have a separation of zero. Exact
50- and 200-millisecond boundaries qualify.

Every other case emits `onsetCohortSupport: neutral` with machine-readable
reason codes. If any onset is unknown, availability is `incomplete` and all
derived booleans, order, and gap are `null`; partial history is not interpreted.
Attack velocity and pressed-versus-pedal-sustained state remain in the raw
evidence but have no effect on this ablation.

## Why 50 and 200 milliseconds

No reviewed source establishes a numerical polychord threshold. The two bounds
instead create a deliberately wide neutral region between ordinary chord-event
asynchrony and a demonstrated segregation manipulation:

- Palmer found that 20-50 millisecond melody leads conveyed voice structure in
  piano chords ([1996, DOI 10.2307/40285708](https://doi.org/10.2307/40285708)).
- Hove, Keller, and Krumhansl treated chords with 25-, 30-, and 50-millisecond
  tone-onset asynchronies as chord events while showing that those differences
  affected synchronization and perceptual centers
  ([2007, DOI 10.3758/BF03193772](https://doi.org/10.3758/BF03193772)).
- Tillmann and Bharucha used a detectable 50-millisecond delayed chord tone and
  found that harmonic context changed asynchrony judgments
  ([2002, DOI 10.3758/BF03194732](https://doi.org/10.3758/BF03194732)). This is
  a reason not to treat a 50-millisecond difference as sufficient proof of a
  separate layer.
- Borchert, Micheyl, and Oxenham found that a 200-millisecond onset asynchrony
  between overlapping, spectrally separated complex tones disrupted fusion
  ([2011, DOI 10.1037/a0020670](https://doi.org/10.1037/a0020670)). Their
  stimuli and task were not polychord identification, so 200 milliseconds is
  adopted only as a conservative positive-support minimum.

This rule was fixed before any corpus outcome measurement, but not blind to the
already committed neutral controls. The 0- and 400-millisecond matched-history
fixtures predate it and are disclosed in the dated research record.

## Output

The command preserves the source fixture identity, hash, observation frame,
candidate, and complete raw onset evidence. It adds:

- `ablationId` and the two exact `parameters`;
- `availability`: `complete` or `incomplete`;
- per-layer booleans stating whether the cohort-span maximum is met;
- `layerOnsetOrder`: `lower-then-upper`, `upper-then-lower`, or `overlapping`;
- `betweenLayerOnsetIntervalGapMs`;
- `onsetCohortSupport`: `positive` or `neutral`; and
- ordered `reasonCodes` explaining the result.

The implementation contains no confidence value, negative evidence, ranking,
abstention, display rule, release grouping, pedal weighting, motion tracking, or
velocity weighting.

## Reproduction

```sh
python3 tool/polychord/onset_support.py \
  --fixture research/polychord/data/frame-replay/two-register-held-cohorts.json \
  --after-event-index 5
```
