# Glossary

Plain-English definitions of the measurement and engineering terms used across
the research archive. Each initiative's PROTOCOL.md is the normative source for
its own rules; this file explains, it does not define. READMEs and log entries
should link here rather than re-explain terms, and keep their own plain-English
sections for interpreting specific results.

Link a term once per document, at its first substantive use in body prose: not
in headings, table headers, or file lists, and not again on every later mention.

Each term is a heading so it can be linked directly from logs, reports, and pull
requests.

---

## Ablation

An experiment that removes, disables, or swaps one ingredient while keeping the
rest of the system fixed. The point is to ask whether that ingredient is
actually doing useful work, not just whether a final system performs well. In
WhatKey, examples include turning duration weighting, functional blends, or
recognizer-confidence weighting on and off under the same detector.

## Abstention

The detector saying nothing rather than naming a key. A first-class outcome,
never counted as an error: on genuinely ambiguous music, staying quiet is the
correct answer.

## Accuracy on claimed events

Of the events where the detector was willing to name a key, the fraction it got
right. Always reported together with coverage; either number alone is
meaningless, because a detector can trade one for the other.

## Adoption bar

The threshold a proposed change must clear before it can ship, written into the
initiative's PROTOCOL.md before any result is seen. Usually a significant
[paired](#paired-statistics) win on the primary [ruler](#ruler), no significant
regression on the others, and a clean behavioral suite.

## Attribution arm

A rerun of the same evaluation with one source of error removed, so a residual
can be split into causes instead of reported as one lump. Comparing an arm
against the live baseline says how much of the error belonged to the thing that
arm took away.

## Bayesian online changepoint detection (BOCPD)

An adaptive-memory alternative to the HMM's fixed decay: instead of letting
evidence fade on a fixed half-life, it maintains a belief about where the
current musical section started and pools evidence back to that point. It
catches more key changes at the cost of more false switches; not adopted
([log entry 2026-07-07-26](whatkey/log/2026-07-07-26-bocpd-negative.md)).

## Bootstrap CI95

A 95% confidence interval computed by
[resampling](https://en.wikipedia.org/wiki/Bootstrapping_%28statistics%29):
re-draw the per-piece results (with replacement) thousands of times, compute the
average difference each time, and report the range the middle 95% of those
averages fall in. Plainly: the plausible range for the true average improvement,
given only these pieces. If the whole interval sits above zero, even the
pessimistic reading is a win. Ours uses a fixed seed so the interval reproduces
exactly.

## Causal / streaming detector

A detector that answers as the music arrives, using only the present and past.
It cannot inspect the rest of the piece, revise earlier events, or wait until
the ending explains the beginning. This is stricter than an offline analyzer,
which may read the whole score or song before producing one answer. WhatKey
fixtures are stored on disk, but the harness still replays them causally: the
detector receives events in order and never sees future labels or future chords.

## Censored modulation

An annotated key change the detector never caught up with: it did not reach the
new key before the next change (or the piece) arrived. Counted separately rather
than averaged into lag, because "never got there" is not a large lag, it is a
miss. (The name borrows from
[censoring in statistics](https://en.wikipedia.org/wiki/Censoring_%28statistics%29):
a value known only to exceed what was observed.)

## Claim

The detector's top-ranked key at one event, when it is confident enough to
speak. Every metric scores the claim; the rest of the ranked list is diagnostic.

## Confidence weighting

Weighting each chord event by how sure the chord recognizer was about its
reading, so confidently identified chords count more than ambiguous ones.
Measured as a no-op across every detector and timescale tried; off by default
([log entry 2026-07-07-20](whatkey/log/2026-07-07-20-reflex-scale-ablation.md)).

## Coverage

The fraction of events where the detector made a claim rather than abstaining.
The partner number to accuracy on claimed events.

## Coverage-accuracy curve

What happens to both numbers as the confidence threshold sweeps from lax to
strict: coverage falls, accuracy should rise. The curve describes the whole menu
of trades a detector offers without depending on any one threshold choice, which
is why the protocol reports it rather than a single operating point.

## Development split and held-out split

The development split is the part of a corpus used while making choices:
selecting constants, comparing variants, diagnosing failures, and deciding what
to freeze. The held-out split (or test split) is set aside until those choices
are fixed, then evaluated once to check whether the result generalizes. If a
held-out result changes the model, constants, or reporting choices, it has been
used for tuning and is no longer a clean held-out test.

## Duration weighting

Weighting each chord event by how long it was held, so a whole-note chord
influences the key estimate more than a passing eighth. On by default.

## Emission

In the HMM, the per-event observation model: how likely the chords we just heard
would be under each candidate key. Ours scores each key by how well the recent
pitch classes match its profile, then converts those scores into a probability
distribution with a [softmax](https://en.wikipedia.org/wiki/Softmax_function);
its temperature sets how decisive one event is allowed to be. In the textbook
HMM an emission is memoryless (one event's worth of evidence), because the
transition model already carries the history and would otherwise count it twice;
ours deliberately relaxes that with the emission-memory window below, treating
the window as the detector's timescale selector rather than as a pure textbook
HMM emission.

## Emission memory (decay half-life)

How much recent context the emission scorer integrates when judging "the chords
we just heard": pitch-class evidence decays exponentially with this half-life.
Short memory makes each emission a snapshot of the immediate harmony, quick to
see excursions; long memory makes it a summary of the current section. Log
entries [2026-07-07-16](whatkey/log/2026-07-07-16-isophonics-timescale.md) and
[2026-07-07-17](whatkey/log/2026-07-07-17-section-scale-default.md) found this
dial selects which timescale of key structure the detector reports (see
Section-key vs. local-key annotations).

## Event

One committed chord from live play: the chord the player held, with the
recognizer's ranked readings of it, its voicing, timing, and duration. Committed
by the [segmenter](#segmenter), which decides where one chord ends and the next
begins. The unit everything is scored over, each counting once regardless of how
long it was held.

## Exact vs. MIREX-weighted

Exact scores a claim 1 only for the annotated key.
[MIREX-weighted](https://music-ir.org/mirex/wiki/2019:Audio_Key_Detection) gives
partial credit for musically close misses: the key a fifth away 0.5, the
relative major/minor 0.3, the parallel major/minor 0.2. A gap between the two
numbers means the errors are mostly neighboring keys, not random ones.

## Explanation cost

The chord recognizer's internal penalty for how awkwardly the sounding notes fit
one candidate chord reading; lower is better, and every event carries its ranked
candidates with their costs. The gap between the best and second-best cost is
the recognizer-confidence signal that confidence weighting tried, and failed, to
exploit.

## Exposure weighting

Ranking a proposed change by how much real playing time it touches rather than
by how many catalog rows it flips, using a weight table built from recorded
performances. The two orderings frequently disagree.

## Filtered posterior (forward algorithm)

The [forward algorithm](https://en.wikipedia.org/wiki/Forward_algorithm) run
causally: after each event, the probability of each key given everything heard
so far, and nothing from the future (unlike
[Viterbi decoding](#viterbi-decoding), which waits for the ending before
explaining the beginning). This is what the HMM claims from, and why its
confidence is a true probability.

## Fixture

A stored, labeled event stream the harness replays: what the detector would have
seen live, plus the ground-truth keys only the scorer may read. Versioned like a
dataset because fixtures embed engine output.

## Functional blend

Mixes a second signal into the emission: instead of only asking which key's
scale the notes fit, it also asks which key the chord would have a familiar job
in (a V7 wants to be the dominant of somewhere). Helps when the target is
tracking brief excursions, hurts when it is naming the section's key; the
shipped configuration leaves it at zero.

## Global vs. local key

Global: one key per piece, the whole-piece answer the older literature reports.
Local: the key at each moment, which is what the app displays and what
modulation tracking is about. This is a different distinction from annotation
granularity; a moment-by-moment detector can still report either kind of key
described under
[Section-key vs. local-key annotations](#section-key-vs-local-key-annotations).

## Golden test

A pinned case: one specific voicing with the expected output chosen in advance
by musical judgment. Goldens encode naming conventions that corpus frequency
cannot see, which makes them a veto on a change that scores well on a
[ruler](#ruler). They are curated judgments rather than ground truth.

## Hidden Markov model (HMM)

A [model](https://en.wikipedia.org/wiki/Hidden_Markov_model) that treats the key
as a hidden state we never observe directly: each chord event gives noisy
evidence (the emission), and the key itself changes only occasionally (the
transitions). Inference balances the two, so an established key persists through
momentary contradictions but yields to sustained ones.

## Hysteresis

A rule that makes the detector wait for repeated evidence before changing its
answer, like a thermostat that will not flip the furnace on and off for every
draft. Claim hysteresis here means "do not adopt a new key until it has appeared
for several consecutive claiming events." It reduces flicker at the cost of
delaying real modulations; not adopted
([log entry 2026-07-07-07](whatkey/log/2026-07-07-07-decay-and-hysteresis.md)).

## Margin floor

The confidence bar for speaking at all. At each event the detector ranks all 24
keys; if the leader is not ahead of the runner-up by at least the floor, it
abstains rather than naming a narrow leader. Higher floor: fewer, more accurate
claims. It gates every claim, not just key changes.

## Matched-coverage comparison

Grading two detectors on the identical subset of events (the ones a reference
run claimed on), so neither gets an advantage from skipping harder questions.
This is how "different coverage" is ruled out as the explanation for an accuracy
difference.

## Mode tilt

A per-event nudge within one parallel pair of keys (same tonic, major vs.
minor): when the chord just played is rooted on that tonic and is clearly major
or clearly minor, some probability shifts toward the matching twin. The pair's
total is preserved, so the tilt can pick between a key's twins but can never
favor a different tonic. Adopted
([log entry 2026-07-07-23](whatkey/log/2026-07-07-23-mode-tilt.md)).

## Modulation lag

After an annotated
[key change](https://en.wikipedia.org/wiki/Modulation_%28music%29), how many
events pass before the detector's claim arrives in the new key. Reported as
median and p90 (the [90th percentile](https://en.wikipedia.org/wiki/Percentile),
the value only the worst tenth of cases exceed), with censored modulations
counted separately.

## Near-tie window

The score gap inside which two competing chord readings count as close enough
that musical tie-breaker rules decide the order, rather than the raw score
alone. Readings further apart than the window are ordered on score, and the
tie-breaker rules never run.

## One-shot evaluation

The first and only evaluation of a frozen result on a held-out split. "One-shot"
does not mean one command or one table; it means the result set was specified
before seeing the test data, then run without using those test outcomes to tune
the system. Additional diagnostic passes can be valid if they do not change the
claims, but any new model choice after seeing the test split belongs in a new,
clearly labeled study.

## Paired statistics

Comparing two detectors
[piece by piece](https://en.wikipedia.org/wiki/Paired_difference_test) (who won
on _this_ piece?) instead of comparing their overall averages, then testing
whether one wins consistently (Wilcoxon signed-rank). An average can be won on a
few long pieces while losing on most; a paired win cannot. The protocol requires
this standard for decisions like changing the default profile pair.

## P-value

A way to ask how surprising a result would be if two systems were actually tied.
For example: if system A beats system B on many pieces, the p-value asks how
often a pattern that strong would happen by chance. A small p-value is evidence
that the difference is real enough to take seriously. It does not say how large
the improvement is, so WhatKey reports the size of the effect alongside the
p-value.

## Posterior

The detector's updated probabilities after the newest chord event has been taken
into account. In the HMM, the posterior starts from the prior, adds the new
event's evidence, and normalizes the result so all key probabilities add to 1.
This is the distribution the detector claims from: if C major is the top
posterior key, C major is the current best guess.

## Posterior calibration / reliability

Whether a probability number should be taken literally. If the detector says "C
major, 80%" on 100 events, a calibrated detector should be right on about 80 of
them. The harness checks this by putting events into confidence bands (0-10%,
10-20%, ..., 90-100%) and comparing each band's average confidence with its
actual accuracy.

The summary numbers are compact ways to read the same idea:
[expected calibration error](https://en.wikipedia.org/wiki/Expected_calibration_error)
(ECE) is the average confidence-vs-accuracy gap across the bands; lower is
better.
[Negative log likelihood](<https://en.wikipedia.org/wiki/Loss_functions_for_classification#Cross_entropy_loss_(log_loss)>)
penalizes putting too little probability on the true key; lower is better. The
[Brier score](https://en.wikipedia.org/wiki/Brier_score) is the squared error of
the whole probability distribution; lower is better. This is different from the
coverage-accuracy curve: abstentions can be useful even when the raw posterior
probabilities are overconfident.

## Pre-declaration

Writing down what will be measured, and what will count as success, before
running it. Applied most strictly to a
[held-out split](#development-split-and-held-out-split), where the full result
set is named in a dated log entry before the split is touched, so no number can
be quietly reframed once it arrives.

## Prior

The detector's probabilities before the newest chord event is used. In the HMM,
the prior is made by carrying the previous posterior forward through the
transition model: mostly keep the same key, but allow some chance of moving to a
nearby or distant key. Plainly, the prior is "what we expected before hearing
this chord"; the posterior is "what we believe after hearing it."

## Profile pair

A published pair of 12-number templates (one major, one minor) describing how
strongly each scale degree characterizes a key. The profile-correlation detector
tries the pair at every tonic in both modes (24 candidate keys) and asks which
best matches the recent pitch histogram by
[Pearson correlation](https://en.wikipedia.org/wiki/Pearson_correlation_coefficient).
The shipped detector uses the Albrecht-Shanahan pair
([log entry 2026-07-07-09](whatkey/log/2026-07-07-09-profile-revisit.md)). The
published sources for each pair are cited in the
[design doc's references](whatkey/temporal-context-key-detection.md#references),
and their values are verified against reference implementations
([log entry 2026-07-06-08](whatkey/log/2026-07-06-08-profile-provenance.md)).

## Progression blend

Mixes cadence patterns into the emission: short chord-to-chord moves (like V7 to
I) vote for the key they resolve into. A wash under the HMM; the shipped
configuration leaves it at zero.

## Ruler

A frozen benchmark: a fixed corpus plus the exact rules for scoring against it.
Rulers are versioned and frozen so results stay comparable across months of
work, and changing one produces a new ruler rather than an edit to the old. "The
live ruler", "the classical ruler", and "the stability ruler" each name a
different corpus-and-scoring pair, so numbers measured on different rulers are
not comparable with each other.

## Section-key vs. local-key annotations

Two granularities of "the key," both legitimate. Section-key annotations name
the home key of a stretch of music, the sense in which a whole song or movement
is "in G." Local-key annotations also track brief local assertions: the few
measures an analyst marks as V-of, a tonicization, or the relative minor. Corpus
labels come at different granularities (Isophonics song keys and ASAP key
signatures are section-key; When in Rome analyst local keys are local-key), so
accuracy numbers are only comparable against the same ruler. WhatChord ships the
section-key setting
([log entry 2026-07-07-17](whatkey/log/2026-07-07-17-section-scale-default.md)).
Older logs sometimes call the local-key setting "tonicization-scale" or
"reflex-scale."

## Segmenter

The component that decides where one chord ends and the next begins in a stream
of live MIDI. It enforces a minimum duration, holds notes through the sustain
pedal, and debounces a pending challenger before committing, which is what turns
continuous playing into the discrete [events](#event) everything else is scored
over. Its judgment also drives what the app puts on screen.

## Self-transition

The HMM's probability that the key this event is the same as the key last event.
Higher values mean a steadier detector that needs more sustained evidence to
change its mind: the principled version of the persistence that decay tuning and
claim hysteresis approximated. The remaining probability spreads over other
keys, nearer ones on the circle of fifths getting more.

## Shell omission

A voicing that leaves out a tone its chord name implies, most often the third,
so no complete name honestly fits it. The counterpart to
[superset absorption](#superset-absorption): one case has a note too many for
the name, the other a note too few, and both are governed by the same
[explanation-cost](#explanation-cost) tolerance.

## Spurious switch

A key switch the annotation gives no reason for: the labeled key did not change
between the detector's previous claim and this one, and the new claim does not
land on the labeled key. The stability metric counts these per piece; a lagged
catch-up switch onto the annotated key is not spurious.

## Stability metrics

What the display does over time, rather than whether it is right. Flicker share
is the fraction of labeled time spent on names that live under half a second;
switches per minute counts how often the shown name changes; settle time is how
long after a chord starts before its final name arrives. Measured because a name
can be correct and still unreadable.

## Superset absorption

The ranker folding an extra sounding note into a larger chord name instead of
naming the base chord and leaving that note unexplained. A held melody note over
a triad turning the display into an extended chord is the usual shape. See
[shell omission](#shell-omission) for the opposite case.

## Temperature scaling

The one-knob calibration fix: raise every probability to 1/T and renormalize. T
above 1 flattens an overconfident distribution toward honesty without ever
reordering the candidates, so rankings, claims, and abstention are untouched.
WhatKey applies it only to displayed probabilities (fit in
[log entry 2026-07-08-03](whatkey/log/2026-07-08-03-display-calibration.md));
the detector's internal numbers stay raw.

## Time to first claim

How many events pass before the detector commits to any key at all. Trades off
against stability and lag, which is why all three are reported and never
blended.

## Top-1 exact

For chord naming, the fraction of events where the app's first-ranked name
matches the reference exactly, in both root and quality. The naming counterpart
to [accuracy on claimed events](#accuracy-on-claimed-events), and the number
most initiative headlines quote. Like every such figure it means nothing without
the [ruler](#ruler) it was measured on.

## Transition model

The HMM's map of how likely the key is to move from one event to the next. Most
probability stays on the same key; the rest spreads to other keys, with closer
keys on the circle of fifths favored over distant ones. The transition model is
what turns the previous posterior into the next prior before the newest chord
evidence is added.

## Viterbi decoding

The offline counterpart to the filtered posterior: given a complete piece, the
[Viterbi algorithm](https://en.wikipedia.org/wiki/Viterbi_algorithm) finds the
single most probable key sequence over the whole thing at once, letting the
ending explain the beginning. Powerful for after-the-fact analysis, but not
causal: the protocol rules it out for the live detector, and offline Viterbi
results are not directly comparable with streaming ones (the paper cites offline
systems only as caveated anchors).

## Warmup

The `minEvents` rule: the detector abstains until it has seen a minimum number
of events, regardless of confidence, so it never guesses a key from one chord.
The shipped HMM sets it to 1, leaving the [margin floor](#margin-floor) to
decide whether the evidence is strong enough. The paper recipes pin 3 so the
frozen results reproduce, and the older pre-HMM detectors default to 3
([log entry 2026-07-26-14](whatkey-local/log/2026-07-26-14-warmup-gate-and-full-cold-start.md)).

## Wilcoxon signed-rank test

The [statistical test](https://en.wikipedia.org/wiki/Wilcoxon_signed-rank_test)
behind our paired comparisons. It looks at the piece-by-piece differences
between two detectors, ranks them by size, and asks: if the two were actually
equally good, how often would luck alone produce differences this consistently
one-sided? The answer is the p-value; a small one (conventionally below 0.05)
means the win is unlikely to be corpus noise. It makes no assumption about the
differences following any particular distribution, which is why it is the
standard choice for this kind of comparison. Implemented in
`tool/whatkey/compare.py`.
