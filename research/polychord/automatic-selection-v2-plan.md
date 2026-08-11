# Automatic polychord selection v2 plan

Status: post-v1 research decision and prerequisite plan. This is not an exact
selector preregistration, does not amend the frozen v0 suite in place, and does
not authorize held-reserve use or product integration.

The decision and its evidence are recorded in log 2026-08-11-13.

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

Release and pedal state remains raw evidence. The bounded audit and the v1
display review do not justify treating pedal-down state or sustained notes as a
categorical rejection. The primary analyzer may remain a reported parallel
interpretation, but its identity, cost, and alternatives must not become truth
labels or unregistered selector inputs.

## Required evidence before exact selector preregistration

Complete the following in order:

1. Write a versioned output amendment for automatic timestamped input. It must
   define the layer-separation support result, abstention semantics, history
   fallback, stability interaction, and machine-readable reason vocabulary. The
   frozen `polychord-output/1` contract remains the record governing v1.
2. Create a new versioned suite instead of editing suite v0. Preserve every
   construction label and static candidate expectation, but score automatic
   temporal eligibility separately. Static positives without adequate event
   evidence become transparent coverage exclusions for that input condition, not
   false negatives and not deleted cases.
3. Admit at least one evidence-complete, source-attested positive for every cue
   branch that could authorize a display. Synthetic cases may test mechanics but
   cannot be the only evidence that a branch represents useful musical behavior.
   Include ordinary integrated controls with closely matched static structures.
4. Freeze the exact cue interpretation, branch combination, assignment rule,
   stability behavior, suite, scorer, and development protocol before reading
   new selector output.
5. Treat all previously exposed POP909, ASAP, and When in Rome outcomes as
   development evidence. A retrospective temporal filter on those artifacts may
   diagnose implementation behavior, but it cannot serve as independent
   confirmation. Identify a new development source or a predeclared resampling
   design before making a safety claim.
6. Keep the 808-song POP909 reserve untouched until the version-2 development
   bar passes. A quiet selector is not sufficient; every development display
   must still receive a complete musical disposition.

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

This stage is complete when the static observability limitation is explicit and
the next selector cannot be mistaken for a larger chord-name blacklist. It does
not predict that temporal evidence will be sufficient. Failure to find
source-valid, observable positive support is an acceptable outcome and would
mean that automatic polychord display is not justified for the current input
surface.
