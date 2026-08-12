# Automatic polychord timing calibration plan

Status: planning boundary. No alternate timing profile, selector, suite, corpus
measurement, or product change is authorized by this document.

## Why this step is necessary

The current record contains two independent 200-millisecond parameters:

1. `coherent-separated-onsets-50-200ms/1` requires at least 200 milliseconds
   between two compact layer-onset intervals before onset timing supplies
   one-sided positive grouping support.
2. `polychord-output/2` inherits the app's 200-millisecond appearance dwell
   before a continuously authorized secondary annotation becomes visible.

They answer different questions. The onset parameter interprets evidence about
how the sonority formed. The appearance dwell is a product policy for
suppressing unstable labels. A shared numerical value does not make either
parameter evidence for the other.

The onset value came from an intentionally conservative analogy to auditory
grouping research. No reviewed study establishes a 200-millisecond polychord
identification boundary. The display value was measured and adopted for the
app's primary chord and history behavior, but it has not been calibrated for a
secondary polychord annotation. Both are legitimate named baselines. Neither is
an immutable scientific constant.

The primary literature argues against treating one value as universal:

- Palmer's performers used 20-50-millisecond melody leads to communicate voice
  structure ([DOI 10.2307/40285708](https://doi.org/10.2307/40285708)).
- Hove, Keller, and Krumhansl found that 25-, 30-, and 50-millisecond
  within-chord asynchronies affected synchronization and perceptual centers
  ([DOI 10.3758/BF03193772](https://doi.org/10.3758/BF03193772)).
- Tillmann and Bharucha tested detection of a 50-millisecond delayed chord tone
  and found that harmonic context affected sensitivity
  ([DOI 10.3758/BF03194732](https://doi.org/10.3758/BF03194732)).
- Borchert, Micheyl, and Oxenham compared one 200-millisecond onset-asynchrony
  condition for filtered complex tones; the task concerned pitch comparison and
  perceptual fusion, not polychord naming, and did not estimate a polychord
  threshold. In the same experiment, their method says the separate
  200-millisecond silent-gap condition was chosen to create a clear interval
  while keeping the trial short
  ([DOI 10.1037/a0020670](https://doi.org/10.1037/a0020670)).
- Hukin and Darwin found that the useful onset asynchrony depended on the
  perceptual task: a leading component's pitch contribution began to fall after
  about 80 milliseconds and approached zero near 300 milliseconds, while a
  vowel-category task needed roughly 40 milliseconds
  ([DOI 10.3758/BF03206505](https://doi.org/10.3758/BF03206505)).

These values establish sensitivity and task dependence. They provide plausible
comparison regions, not a ready-made product cutoff.

The initial split census also consumed committed chord events whose upstream
segmentation required 200 milliseconds of stability. That is provenance for the
observation unit, not a third polychord threshold. Its conclusions are already
limited to committed-event exposure, and later work separately measures raw
event frames and stable display.

## Provenance rule

The existing `coherent-separated-onsets-50-200ms/1` measurements remain valid
results for that exact profile. They must not be relabeled after the fact. An
alternate onset interpretation must receive a new identity, and an alternate
adopted display policy must receive a new output or display-profile version.

That protection against silent retuning does not require the project to assume
that 200 milliseconds is correct. It requires us to distinguish:

- a result under a named parameter setting;
- exploratory calibration used to choose a later setting; and
- independent evaluation of the setting after it is frozen.

Known source timings and exposed development-corpus outcomes may inform
exploration, but they cannot later be presented as independent confirmation of
the chosen threshold.

## Separate evaluation layers

Future automatic work must report three layers independently:

1. **Cue interpretation:** whether the observed onset or motion evidence
   supports an exact candidate under each named cue profile.
2. **Automatic decision:** whether the candidate is selected or the system
   abstains, independent of whether the selection lives long enough to appear.
3. **Display policy:** whether a continuously authorized decision survives the
   named appearance dwell and when it clears.

A source-attested polychord that lasts less than the current display dwell may
still be an automatic-decision positive and useful cue evidence. It is a display
coverage exclusion under that dwell, not a false construction and not grounds
for rejecting the cue branch. Conversely, surviving a display dwell does not
validate the musical decomposition.

## Required threshold-free record

Before choosing another timing profile, every eligible source or control must
retain the raw quantities from which interpretations are derived:

- each assigned note's onset, release, sustain state, and sounding-instance
  identity;
- each layer's complete onset interval and within-layer span;
- the signed gap or overlap between layer-onset intervals;
- the exact candidate and cue-authorization lifetime;
- every event that ends or changes the candidate binding;
- the source's notated tempo or beat position when authoritative, kept as
  contextual metadata rather than silently substituted for observed time; and
- cue, decision, and display outcomes under every preregistered comparison
  profile.

Raw continuous distributions and sensitivity curves take priority over a single
pass total. Absolute milliseconds remain necessary because live MIDI supplies
wall-clock events, but tempo and articulation diagnostics must be preserved so
one absolute threshold is not mistaken for a tempo-invariant musical law.

## Calibration sequence

Before another automatic selector is evaluated:

1. Admit source-attested construction positives and matched ordinary integrated
   or boundary guards based on construction, exact event coverage, and
   candidate-bound cue evidence. Do not require them to survive a display dwell.
2. Freeze a finite family of onset interpretations and display dwells before
   running them. The family must include the existing profiles unchanged, state
   the literature and product rationale for every comparison, and expose a
   sensitivity curve rather than select the most favorable case silently.
3. Run the comparison only on declared calibration material. Record case-level,
   piece-level, duration-weighted, and threshold-sensitivity results, including
   every neutral reason and display suppression.
4. If a profile is selected, freeze it before using new confirmation material.
   If no independently labeled confirmation set is available, describe the
   result as calibrated product policy or author-adjudicated conformance, not
   generalized detection accuracy.
5. Keep the 808-song POP909 reserve untouched until a selector, scorer, source
   coverage, and interpretation rule for that reserve have been preregistered.

The comparison family itself is not fixed here. The already exposed 96-, 97-,
125-, and 200-millisecond observations make a threshold grid chosen now
development-informed by definition. The next dated measurement entry must say so
explicitly and must freeze the grid before producing comparison results.

## Current consequence

The bounded source search remains useful and its exact measurements stand. It
did not supply the candidate-bound source positives and matched guards needed to
preregister an automatic selector. That is a pause at the evidence-calibration
prerequisite, not proof that automatic polychord inference is impossible and not
justification for closing the avenue because examples miss 200 milliseconds.

The current 200-millisecond display policy may remain the conservative
`polychord-output/2` baseline while this work proceeds. It must not be used as a
construction label, cue threshold, source-admission criterion, or claim about
polychord perception.
