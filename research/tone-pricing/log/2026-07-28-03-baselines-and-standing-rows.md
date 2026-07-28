# 2026-07-28: Dense-census baseline, standing rows, and a corrected reading

**Goal.** Build-order step 2: the dense-set self-consistency baseline and the
committed standing-row inventory.

**Setup.** New `tool/performed-input/dense_census.py` (the stress guard from
PROTOCOL.md): dense event mass share, top-1 quality distribution on dense
events, and mass-weighted revoicing consistency over canonical classes seen
under multiple octave layouts. Standing rows generated into
`research/tone-pricing/data/standing-rows.json` from the exposure table and the
reviewed verdicts.

**A corrected reading, found by the census.** Performed-input log 2026-07-28-05
(and the exposure exploration) described the outside-pool mass as "more than 7
pitch classes": 10.9% of event mass, 21.8% of sounding time. That read the
probe's "outside 3-7" bucket wrong. The bucket is dominated by the LOW side:
octave-doubled voicings collapsing to 1-2 pitch classes carry 10.3% (pop) and
13.6% (classical) of event mass, and are already served by the shipped power and
dyad vocabulary. Genuine 8-plus density is 0.7% (pop) and 0.2% (classical) of
event mass. This strengthens the declined 8-plus pool tier and shrinks the
dense-set stakes.

**Dense-census baseline.** At 8-plus the data is too thin to guard with (zero
multi-layout classes on classical dev), so the guard runs at 7-plus, where the
pedal-wash mass lives:

| corpus        | dense share | consistency | classes / layouts | top qualities                       |
| ------------- | ----------- | ----------- | ----------------- | ----------------------------------- |
| POP909 sample | 0.045       | 0.9755      | 21 / 144          | major7 0.55, minor7 0.24, dom7 0.21 |
| classical dev | 0.005       | 1.0000      | 2 / 8             | dom7 0.76, minor7 0.11              |

POP909 is the guard's primary corpus (meaningful layout counts); classical is
secondary. Dense sets draw ordinary seventh-family vocabulary, no exotic
explosion. Baseline frozen for before/after comparison under any lever.

**Standing rows committed** (13 rows in `data/standing-rows.json`): the ten
top-exposure soft verdicts from the skim plus the three remaining shell-family
rows (`0-2-9`/`0-1-8` under other basses) the omission lever targets, with
exposure shares attached. Re-read against every candidate lever; flips
re-review.

**Plain-English reading.** The scary-sounding fifth of playing time the chord
catalog supposedly could not see turns out to be mostly octave doublings the app
already names fine; truly dense note piles are under one percent of playing. The
dense-behavior safety check now has its baseline number, and the thirteen
judgment-call chords every pricing experiment must answer to are written down in
one place with their real-world weight attached.

**Next.** Build-order step 3: experiment-mechanism scoping, how pricing variants
are prototyped (research analysis profile or debug pricing overrides) without
touching shipped ranking.
