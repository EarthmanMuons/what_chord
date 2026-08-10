# Polychord output and evaluation contract

Status: active research contract for `polychord-output/1`. This document freezes
the v0 composite representation, presentation semantics, stability behavior,
scoring model, adoption bar, and performance budget before any product selector
is designed or evaluated. It does not choose a selector, authorize an engine or
UI change, make the internal seed independent ground truth, or spend held data.

The decision and its architectural provenance are recorded in log 2026-08-10-18.

## Product boundary

A polychord is an optional secondary annotation attached to an unchanged primary
single-chord analysis. It is not another candidate in the existing single-chord
ranking and does not receive a comparable ranking cost.

The following existing behavior remains unchanged:

- `ChordAnalyzer.analyze()` returns the same ordered `ChordCandidate` list with
  the same identities, costs, and near-tie alternatives;
- the primary identity card displays the same chosen `ChordIdentity`;
- key inference consumes the same committed single-chord candidates;
- chord-event segmentation keys on the primary identity only;
- the recent-chords strip shows the primary identity only;
- tapping the primary card opens Explore for the primary identity; and
- existing links continue to describe input notes and analysis context rather
  than asserting an inferred polychord label.

The secondary annotation must therefore travel through a parallel pure-Dart
analysis path and a separate presentation model. It must not be inserted into
`ChordCandidate`, priced against a primary chord, or allowed to change a primary
ranking.

## Composite identity

The conceptual pure-Dart types are:

```text
PolychordLayerIdentity
  rootPc: 0..11
  quality: major | minor | dominant7 | major7 | minor7

PolychordIdentity
  upper: PolychordLayerIdentity
  lower: PolychordLayerIdentity

PolychordCandidate
  identity: PolychordIdentity
  upperMidiNotes: sorted, distinct MIDI notes
  lowerMidiNotes: sorted, distinct MIDI notes
  sharedPitchClasses: sorted pitch classes
  registerBoundary: lower top, upper bottom, and gap

PolychordDecision
  schema: polychord-output/1
  candidates: every structural candidate
  selected: zero or one selected candidate
  selectorId: versioned selector name
  support: named evidence results
  reasonCodes: selection or abstention reasons
```

These names describe the contract; their eventual Dart spelling may follow
package conventions without changing the semantics.

`PolychordIdentity` equality is order-sensitive and compares the upper and lower
root pitch classes and qualities. It deliberately ignores enharmonic spelling,
MIDI-note assignment, register gap, evidence, selector version, and
presentation. Layer-local inversions and octave doublings are preserved in a
candidate's note assignment but do not change the chordal-unit identity or add
slash basses to the polychord symbol.

Candidate equality includes the composite identity and both exact MIDI-note
assignments. If several assignments yield the same composite identity, retain
all assignments for selection and diagnostics, but group them under one identity
for presentation. The selector must choose one exact assignment as well as its
identity, or abstain when the assignment remains unresolved; iteration order
must never choose a display.

The upper and lower assignments must be disjoint at the MIDI-note level and
together exhaust the observed notes. A shared pitch class remains valid only
when separate sounding notes supply it on both sides, as specified by
`FRAMEWORK.md`.

## Relationship to primary analysis

The combined UI-facing concept is:

```text
ChordAnalysisDisplay
  primary: existing ChordPresentation
  secondaryPolychord: PolychordPresentation?
```

This is composition, not a new kind of `ChordIdentity`. The primary result is
required; the secondary result is nullable. If the primary analyzer has no
displayable chord, the polychord annotation is also absent.

A selector may inspect the observed voicing, structural candidates, the
unchanged primary identity and surfaced single-chord alternatives, and evidence
explicitly admitted by its versioned specification. It may not consume an
internal-suite expectation, score label, corpus annotation, source instrument,
or private construction record that live input does not contain.

## Evidence and abstention

The adjacent-register structural candidate is necessary but not sufficient for a
displayed annotation. Candidate generation and product selection remain separate
operations.

V0 defines no scalar confidence and no hidden weighted score. Evidence is
reported by named, enumerable results:

- register: exact structural candidate or unavailable;
- onset cohort: positive, neutral, or unavailable;
- rigid-layer motion: positive, neutral, or unavailable;
- release and pedal: raw evidence available or unavailable, with no v0 product
  interpretation; and
- channel or source grouping: unavailable until a later transport-specific
  contract establishes reliable semantics.

Onset and motion are one-sided support. Positive support may be retained in
diagnostics, but it does not independently authorize display. Neutral,
incomplete, or unavailable temporal history never rejects an otherwise selected
static candidate. Release and pedal evidence does not affect selection in v0.
Any future selector that gives a temporal or source cue selection weight must be
preregistered as a new named ablation before its result is read.

Every frame produces either one selected annotation or an explicit abstention.
Reason codes are machine-readable, stable tokens. At minimum the implementation
must distinguish:

- `missing-register-evidence`;
- `no-structural-candidate`;
- `multiple-unresolved-identities`;
- `not-selected-by-policy`;
- `unstable-selection`; and
- `primary-not-displayable`.

Additional selector-specific reason codes require a versioned amendment. User
copy must not expose these technical tokens directly.

Current pitch-class-only lookup input has no octave/register evidence and is
therefore `missing-register-evidence`, not temporally disqualified. Static MIDI
input with real register remains eligible even when it has no onset or motion
history. A later manual-entry design may become eligible by preserving explicit
register or explicit upper/lower units.

## Notation and wording

Canonical machine and plain-text notation is `upper|lower`, with ASCII `|` and
the upper chord first. This matches the engraving-software convention already
adopted by `FRAMEWORK.md`. A slash is never used between the two chordal units.

Enharmonic spelling is presentation state. Each live layer root is spelled
through the existing tonality, notation-style, and note-name-system services.
The research identity remains pitch-class based. Score spellings stay in source
fixtures but are not injected into live analysis. Canonical diagnostics include
both pitch-class identities and the rendered spelling so a presentation change
cannot masquerade as an analysis change.

For C major above G minor, the presentation forms are:

- Canonical plain text: `C|Gm`.
- Short visual: a `Polychord` label with C above Gm.
- Long form: `Polychord: C major above G minor`.
- Semantic and spoken: `Polychord. Upper chord: C major. Lower chord: G minor.`

The actual visual may use a stacked fraction-style symbol or a side-by-side pipe
fallback, but both serialize to the same canonical string. Screen readers must
receive the explicit upper/lower sentence and must never be asked to infer the
meaning of a pipe or horizontal rule. User-facing text must not call the result
bitonal, polytonal, a split, or a detector candidate.

Layer long and spoken names reuse the existing chord formatters, including the
selected note-name system and plain-text accidental pronunciation. The words
`upper chord` and `lower chord` are retained even when the roots themselves
would make the register relation seem obvious.

## Placement and accessibility

The primary identity card remains visually and semantically primary. A selected
polychord appears in a dedicated secondary region immediately after the primary
card and before the list of alternative single-chord candidates. It is labeled
`Polychord` so it cannot be mistaken for another primary-ranking alternative.

The secondary region:

- exposes one semantic node using the frozen spoken sentence;
- does not duplicate or replace the primary card's semantic label;
- is not an automatic route into single-chord Explore;
- may open analysis details but must not imply that Explore can construct the
  composite until such support exists;
- supports platform text scaling without horizontal scrolling or ellipsis;
- may change from side-by-side to stacked layout as space narrows; and
- respects reduced-motion settings for appearance and change transitions.

No raw MIDI numbers, pitch classes, evidence tokens, or confidence language
appear in the ordinary secondary label. Those belong in analysis details.
VoiceOver and TalkBack checks, keyboard/switch focus order, 200% text scaling,
landscape, and narrow split-screen layouts are required device-level adoption
checks.

## Stable-display behavior

Candidate generation and raw selection are measured on every observed frame.
Product display uses an asymmetric safety gate:

1. A new selected identity and its exact note assignment must persist unchanged
   for the existing 200-millisecond chord stability duration before appearing.
2. A different selected identity restarts that duration; the old annotation may
   remain only while its exact note assignment is still valid in the sounding
   frame.
3. Any note change that invalidates the displayed assignment, an abstention, a
   missing primary chord, or silence clears the annotation immediately.
4. The gate never delays, replaces, or changes the primary chord display.
5. Pitch-class-only lookup has no timed gate, but remains ineligible until it
   carries register or explicit-layer evidence.

This is intentionally stricter on disappearance than the primary identity gate:
a secondary construction must not remain visible after its assigned notes stop
sounding. Appearance latency, clears, changes, and suppressed unstable
selections are all measured rather than hidden.

## History, key inference, Explore, links, and diagnostics

V0 does not add a polychord field to `ChordEvent`. The existing event snapshot,
segmentation, recent-chords strip, and key detector remain single-chord-only.
Secondary appearance, change, or disappearance does not create, end, replace, or
relabel a chord event. Persisted polychord history requires a later versioned
event contract that defines when a secondary annotation is sampled.

The primary card continues to seed Explore with its `ChordIdentity`. The
secondary annotation may expose details, but it does not silently choose one of
its layers as an Explore seed.

Current share links preserve ordered pitch classes and context, not octave
register, so they cannot reproduce an adjacent-register polychord decision. V0
must not serialize an inferred polychord label into a link as if it were input
evidence. Until a versioned register-preserving link grammar exists, ordinary
sharing remains primary/input-only and makes no promise that the recipient will
see the secondary annotation.

Copyable analysis details add a `Polychord Annotation` section containing:

- output schema and selector identifier;
- displayed canonical, long, and semantic forms;
- upper and lower root pitch classes, qualities, rendered roots, and exact MIDI
  assignments;
- register boundary and shared pitch classes;
- every structural candidate before deduplication;
- named evidence availability and support results; and
- selection or abstention reason codes.

Diagnostics must show an abstention as explicitly as a selection. They must not
print source expectations or describe the selected result as ground truth.

## Evaluation unit and eligibility

Evaluation is performed against one exact observation under one named input
condition. Scores from adjacent-register snapshots, general pitch/register
snapshots, and timestamped event streams are never pooled.

For the adjacent-register condition:

- positive recall includes positive cases whose
  `inputEligibility.adjacentRegisterSnapshot.status` is `eligible`;
- positive cases marked `ineligible` or `not-available` are coverage exclusions,
  reported by identifier and reason rather than counted as misses;
- every boundary and negative-guard case with an exact observation tests
  abstention, including cases marked `ambiguous` or structurally ineligible; and
- synthetic and literature-attested results are reported separately before any
  combined descriptive total.

The current seed remains non-scorable because it is not yet the complete frozen
adoption suite. This contract freezes how it will be scored, not that it is
ready to authorize implementation.

## Metrics and partial credit

For one predicted annotation and one acceptable expected decomposition:

- **ordered composite exact**: 1 only when upper and lower root pitch class and
  quality both match in order, otherwise 0;
- **assignment exact**: 1 only when the predicted upper and lower MIDI-note sets
  exactly match the expected units, otherwise 0;
- **layer identity credit**: the number of expected `(rootPc, quality)` units
  present in the predicted unordered pair divided by 2, yielding 0, 0.5, or 1;
- **orientation correct**: defined only when layer identity credit is 1, and 1
  only when the two units occupy the expected upper and lower roles;
- **note assignment accuracy**: after matching units by `(rootPc, quality)`, the
  number of observed MIDI notes assigned to their expected unit divided by the
  total observed notes; unmatched units contribute zero correct notes; and
- **abstention correct**: 1 for no annotation on a boundary or negative-guard
  case, otherwise 0.

When a case has several acceptable expected decompositions, score against each
and retain the maximum result as well as the winning expected identifier. An
abstention on a positive receives zero on every positive metric. A prediction on
a boundary or negative guard receives zero abstention credit; partial layer
similarity does not excuse the fire.

Report exact counts and denominators for every metric. Layer identity credit and
note assignment accuracy are diagnostics for error analysis and future external
agreement; they cannot satisfy the adoption gate. Symbols and enharmonic
spellings are presentation diagnostics, not identity scoring dimensions.

## Stable-display and corpus reporting

Every implementation-shaped corpus run reports, per piece and in aggregate:

- sounding frames and milliseconds;
- frames and milliseconds with one or more structural candidates;
- raw selected frames and milliseconds before stability gating;
- stable displayed annotation episodes and milliseconds;
- appearance latency from first unchanged raw selection to display;
- selection changes, clears, and suppressed unstable selections;
- distinct candidate identities and distinct exact assignments;
- abstention and selection reason-code counts; and
- every stable-display fire with piece, time, notes, primary chord, selected
  polychord, evidence, and duration for disposition.

Latency and count distributions report sample size, minimum, nearest-rank
median, nearest-rank p90, and maximum. Corpus results remain exposure and safety
evidence, not accuracy estimates, because the corpora have no verified polychord
labels.

## Adoption bar

A selector may proceed from development research to a held evaluation only if
all of the following are true:

1. The complete adoption suite and its dependency pins were frozen before the
   selector result was read.
2. Every eligible positive has ordered-composite-exact and assignment-exact
   scores of 1; no aggregate average may hide a miss.
3. Every boundary and negative guard has abstention-correct score 1.
4. Literature-attested and synthetic strata each pass their applicable exact
   gates and are reported separately.
5. Every stable display on the declared development corpora is dispositioned,
   with zero displays judged to be ordinary integrated, slash, same-root, or
   otherwise out-of-scope cases under the frozen framework.
6. Primary analyzer output, key claims, committed chord events, current golden
   suites, the 18/18 comping suite, and clearly-correct oracle-pool entries have
   zero regressions.
7. Required prior-art baselines are run on the same frozen suite and reported;
   they are comparisons, not thresholds WhatChord must beat.
8. The performance budget and device accessibility checks below pass.

This is agreement with a conservative author-adjudicated product specification,
not an accuracy percentage or a generalized musical claim. The held 808-song
POP909 reserve remains untouched unless a later dated decision gives it a
formal, preregistered role. No development result spends it implicitly.

## Performance budget

The polychord path is pure Dart, deterministic, bounded by the sounding-note
count, and free of I/O. It must not make another `ChordAnalyzer.analyze()` call,
change the analyzer cache key, or alter existing deterministic engine counters.

Before adoption:

- `tool/benchmark.sh --check` passes against the unchanged primary-engine
  baseline;
- a dedicated benchmark replays candidate generation, evidence attachment,
  selection, and decision serialization over the adversarial oracle and common
  voicing corpora using the existing normalized-time methodology;
- the added cold normalized time is at most 5% of the primary snapshot baseline,
  outside the harness's combined uncertainty window;
- allocation churn, retained memory, candidate counts, and maximum candidates
  per frame are reported, with no unbounded cache keyed by temporal history;
- worst-case frames spanning the supported MIDI range and rapid note-on/off and
  pedal changes are included in the benchmark; and
- on-device profiling on the oldest supported iOS and Android performance tiers
  shows no dropped frames during note storms, with reduced motion both enabled
  and disabled.

The 5% limit is a budget, not a target. An amendment may change it only before
held evaluation and with a development-evidence justification.

## Required implementation order

1. Complete and freeze the adoption suite without reading selector outcomes.
2. Implement the machine-readable scorer for the metrics above and test it with
   synthetic exact, swapped, one-layer, wrong-assignment, abstention, and
   multiple-acceptable controls.
3. Define and preregister one selector or selector ablation.
4. Implement the pure-Dart composite types, candidate adapter, selector, and
   diagnostic serializer without changing primary analysis.
5. Run the internal suite and development exposure measurements.
6. Only after the adoption bar passes, integrate the secondary presentation and
   stable-display gate behind a disabled-by-default development flag.
7. Run device accessibility and note-storm checks before any default-on or
   release decision.
