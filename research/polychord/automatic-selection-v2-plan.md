# Automatic polychord selection v2 plan

Status: paused at the source-evidence and timing-calibration prerequisites. This
post-v1 research decision is not an exact selector preregistration, does not
amend the frozen v0 suite in place, and does not authorize held-reserve use or
product integration.

The evidence boundary is recorded in log 2026-08-11-13. Logs 2026-08-12-01 and
2026-08-12-02 record the source-coverage audit. The latter also corrects the
coupling of source admission to the inherited display dwell.

## Why a second selection contract is necessary

`polychord-register-candidates/1` remains a valid structural enumerator: it asks
whether the observed notes admit two complete chordal units across an adjacent
register boundary. The development result shows that this observation alone does
not answer the separate product question of whether WhatChord should
automatically display the decomposition.

All 73 stable displays from `polychord-register-policy/1` in the exposed POP909
sample were out of scope. More importantly, one error family has the same
transposition-invariant static structure as a frozen positive. The suite's
`C|Gm` cases and the development corpus's `G|Dm` cases each contain a major
upper triad, minor lower triad, upper root five semitones above the lower root,
and one shared pitch class. Both frozen cases retain `C9/G` as an ordinary
single-chord alternative; the development cases prefer `G9/D`. Register gaps do
not separate them: the source and synthetic positives use gaps of 2 and 10
semitones, while the development errors use 9.

Consequently, expanding the integrated-chord mask, consulting the primary root,
or adding a gap cutoff cannot distinguish this collision without also rejecting
a declared positive or adding case-shaped exceptions. Version 2 must change the
evidence claim rather than fit a larger static blacklist.

## Product boundary for version 2

For automatic inference from raw MIDI, a register candidate is a proposal, not a
sufficient display license. The next selector hypothesis must require at least
one positively observed, preregistered cue that supports separate chordal units
in addition to the structural register candidate. Neutral, incomplete, or
unavailable evidence from a source independent of static register must cause
automatic abstention. This is a grouping-evidence requirement, not a claim that
the resulting layers are perceptually independent streams.

This narrows what the detector claims to recover; it does not narrow the musical
definition of a polychord or the symmetric five-quality layer vocabulary.
Constructional positives remain polychords even when the current input cannot
establish their decomposition. Candidate generation remains available for
diagnostics and future evidence models.

Explicit manual structure is a different input condition. If a future user
interface accepts upper and lower chordal units directly, the user supplies the
decomposition that automatic inference lacks. Such input may be eligible under a
separate contract without pretending that static raw MIDI revealed the layers.

## Candidate evidence families

The first admissible families are:

- separated, internally compact onset cohorts;
- coherent layer motion under an explicit correspondence model; and
- a later channel, source, or timbre cue only if the transport preserves it
  reliably and a separate study establishes its semantics.

The existing `coherent-separated-onsets-50-200ms/1` and
`rigid-layers-oblique-or-contrary/1` rules are conservative construct probes,
not automatically adopted product gates. Their thresholds, logical combination,
duration requirements, and behavior after evidence becomes stale must be frozen
in the exact selector preregistration. A new rule may reuse one unchanged, but
it may not loosen either rule after inspecting the existing zero-positive POP909
results and call the result confirmatory.

A prospectively named comparison may evaluate alternate parameters as
development-informed calibration. It must retain the original profiles, report
the full declared sensitivity comparison, and reserve later material for any
confirmation claim. `automatic-timing-calibration-plan.md` defines that
boundary.

Release and pedal state remains raw evidence. The bounded audit and the v1
display review do not justify treating pedal-down state or sustained notes as a
categorical rejection. The primary analyzer may remain a reported parallel
interpretation, but its identity, cost, and alternatives must not become truth
labels or unregistered selector inputs.

## Required evidence before exact selector preregistration

Complete the following in order:

1. **Complete:** `automatic-output-contract-v2.md` and log 2026-08-11-14 define
   `polychord-output/2` for automatic timestamped input, including exact
   candidate and sounding-instance binding, three-state support aggregation,
   abstention semantics, causal history fallback, support-aware stability, and
   machine-readable reason vocabulary. The frozen `polychord-output/1` contract
   remains the record governing v1.
2. **Plan complete; suite construction did not begin:**
   `automatic-suite-v2-plan.md` and log 2026-08-11-15 fix the new schema
   boundary, preserve all 17 frozen construction and static-candidate records by
   pinned reference, classify their existing temporal coverage, and preregister
   the branch-admission and coverage requirements. Static positives without
   adequate event evidence remain transparent coverage exclusions for that input
   condition, not false negatives and not deleted cases.
3. **Not satisfied:** admit at least one evidence-complete, source-attested
   automatic-decision positive for every cue branch that could authorize a
   candidate, with a matched ordinary integrated control. Display survival is a
   separate coverage axis. The bounded search in log 2026-08-12-02 found no
   source satisfying the candidate-bound cue and guard requirements.
4. **Plan recorded; comparison not frozen:**
   `automatic-timing-calibration-plan.md` separates cue interpretation,
   automatic decision, and display policy. The exact comparison family still
   must be frozen before it is run.
5. **Not started:** identify a new development source or a predeclared
   resampling design. Previously exposed POP909, ASAP, and When in Rome outcomes
   remain development evidence and cannot serve as independent confirmation.
6. **Preserved:** keep the 808-song POP909 reserve untouched. No version-2
   selector reached development evaluation.

Log 2026-08-12-01 completes the first source-admission attempt with a negative
result. The Stravinsky closing-passage lead lacks an authoritative note-for-note
event representation, while a public sequence independently demonstrates that
source inter-onset spacing does not establish candidate dwell: it uses
125-millisecond notes in the staccatissimo passage. The Herrmann “The Pass”
alternative places its useful motion endpoints across a noncandidate gap for
which no causal lookback rule is frozen. Neither motion nor onset currently
satisfies item 3, so no exact version-2 selector or automatic suite was eligible
to be built at that point.

Log 2026-08-12-02 completes the bounded follow-up search. Moreira's “The Scar”
is strong scholarly evidence for asynchronous attacks separating complete
chordal layers, but its score transcription and mixed audio do not provide
authoritative per-note event timing or the required matched integrated guard.
The same search corrects the Liszt _Malediction_ backlog case: the score rapidly
alternates B-major and F-major chords, while a pinned hand sequence produces
brief pedal overlap that is neutral under the existing onset profile and
display-suppressed under the existing dwell. The other screened score, corpus,
and perception sources fail complementary coverage requirements. Item 3
therefore remains unmet: the automatic suite stays unencoded, onset and motion
remain diagnostic, and no exact version-2 selector is built yet. The
sub-200-millisecond observations are not the reason the Liszt construction is a
boundary and no longer close the automatic avenue.

## Rejected shortcuts

- **Broaden every integrated-chord mask to every root.** This catches many v1
  errors but also rejects source positives with documented ordinary
  alternatives, including `C|Gm` alongside `C9/G`.
- **Use the primary analyzer as a veto.** A coherent primary reading is present
  for both true constructional positives and development errors. This would also
  couple the secondary result to ranking changes.
- **Set a minimum register gap.** The 9-semitone development collision lies
  between the two frozen `C|Gm` positive gaps of 2 and 10 semitones.
- **Reject pedal-sustained sonorities.** Pedal accumulation explains much of the
  exposed corpus behavior, but pedal use is ordinary performance practice and
  the current evidence establishes no categorical threshold.
- **Patch the frozen suite or v1 selector.** Versioned artifacts preserve the
  negative result and make the changed evidence claim auditable.

## Success criterion for this planning stage

This planning stage has identified the static observability limitation and the
missing source-valid, candidate-bound cue evidence. Automatic polychord display
is not yet justified for the current input surface and cue set. The next
eligible step is prospective timing calibration plus source and guard coverage,
not automatic selector evaluation or held-reserve use.
