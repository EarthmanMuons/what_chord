# Polychord adoption-suite plan

Status: preregistered coverage plan for the still non-scorable
`polychord-internal-suite/1` seed. This plan defines what must be resolved
before the adoption suite can be frozen and before any selector outcome is read.
It is not the frozen suite, an accuracy ruler, or permission to use held data.

The audit and its provenance are recorded in log 2026-08-10-19. The output and
scoring rules remain those of `output-evaluation-contract.md`.

## Why the suite has three layers

Three different questions require separate evidence:

1. **Structural conformance:** does the generator symmetrically enumerate the
   complete v0 chord vocabulary and preserve exact note assignments?
2. **Product-policy conformance:** on an author-adjudicated musical case, should
   a structural proposal become a secondary annotation or an abstention?
3. **External validity:** do independent musicians accept the task and labels?

Generated tests can answer the first question but cannot establish the second.
The internal suite can answer the second only as conformance to the declared
WhatChord policy. Neither supports a population accuracy claim. External
validation remains optional research after the task and instrument are mature;
it is not a prerequisite for continuing implementation research.

## Structural conformance matrix

Before a selector is evaluated, a generated pure-Python conformance test must
exercise the register candidate contract independently of product labels.

The required core matrix contains every ordered pair of the five v0 qualities
(major, minor, dominant seventh, major seventh, and minor seventh), every one of
the 11 nonzero relative-root intervals, and every chromatic transposition. That
is 3,300 identity combinations. For each combination, a deterministic voicing
recipe must create two adjacent complete units and assert that the intended
ordered identity and exact assignment are present. Extra mechanically valid
candidates are recorded rather than hidden.

Focused controls additionally cover:

- layer inversions and internal octave doublings;
- zero, one, and multiple shared pitch classes supplied by separate notes;
- one-semitone through wide register boundaries, without creating a hidden gap
  threshold;
- exclusion of same-root pairs, incomplete units, and a single note reused by
  both templates;
- more than one candidate identity in one observation; and
- more than one exact assignment for one identity, or a documented exhaustive
  demonstration that the frozen contiguous-boundary model cannot produce that
  condition.

This matrix is a generator regression suite. Its generated constructions do not
become 3,300 positive product examples.

## Product-policy coverage required before freeze

The adoption suite must contain exact observations for every applicable cell
below. A missing positive cell can be resolved only by admitting a pinned source
case or by narrowing the v0 display scope before selector evaluation. A
synthetic construction alone cannot satisfy a source-attested cell.

### Construction anchors

- **Satisfied:** a recoverable literature positive with a separate-note shared
  pitch class and concise integrated alternative. Ives's _Psalm 67_ supplies
  `C|Gm` versus `C9/G`.
- **Satisfied:** a recoverable source-attested positive with disjoint chordal
  units. Moreira's Example 6 supplies the first A-flat-minor attack under a
  sustained G-minor triad from Herrmann's “The Pass,” encoded as `Gm|Abm`.
- **Satisfied:** a recoverable source-attested positive containing at least one
  complete seventh-chord layer. Stravinsky's 1922 piano score and Hutchinson's
  pedagogical analysis supply `G|Ab7` in the chromatically ascending
  dominant-seventh passage on printed page 37.
- **Satisfied:** a literature construction excluded by overlapping register,
  supplied by the Stravinsky Augurs chord.
- **Missing:** a moving or arpeggiated literature construction represented
  without a false vertical snapshot. Petrushka rehearsal 49 is score-verified
  but has no exact replay.

The last two cells establish construct and input boundaries and are excluded
from adjacent-register positive recall when ineligible. They still prevent the
research record from redefining polychords around only what the first detector
can recover.

### Abstention and confusion guards

The frozen suite must include exact cases for:

- an integrated compact chord that nevertheless generates a split, currently the
  `D6` / `Bm|D` guard;
- an integrated extended chord with complete units on both sides of a generated
  split, currently `Cmaj13(#11)` / `D|Cmaj7`;
- source-attested moving layers whose endpoint has a conventional integrated
  name, currently the Shrovetide `Gm7` boundary;
- same-root register groups, currently doubled C major;
- an incomplete seventh shell under an upper-structure triad, currently
  `C13(#11)`;
- a source-backed lone-bass or bare-fifth boundary;
- an ordinary open, drop, modal, or doubled accompaniment voicing that could be
  mistaken for two layers;
- multiple structural identities in one observation, supplied by the
  source-backed `G|Ab7` case and not to be chosen by iteration order;
- an exact-assignment ambiguity within one identity if structurally feasible;
  and
- a one-sounded-note overlapping cover, which remains outside v0 even when its
  pitch classes can describe both proposed units.

A guard with no structural candidate still tests scope and regression behavior.
A guard with one or more candidates additionally tests selector abstention.

## Input-condition and scorer controls

The snapshot suite does not stand in for every input mode. Before selector
evaluation, executable controls must separately establish:

- registered static MIDI input remains eligible without temporal history;
- neutral or unavailable onset and motion support does not become a rejection;
- positive temporal support is recorded without independently authorizing a
  display;
- pitch-class-only lookup returns `missing-register-evidence`; and
- silence, primary absence, and an invalidated assignment clear the secondary
  result according to the frozen stability contract.

The scorer must be tested with exact, swapped-orientation, one-correct-layer,
wrong-assignment, abstention, unexpected-fire, and multiple-acceptable-answer
controls. Partial metrics remain diagnostic and cannot pass an exact gate.

## Freeze and amendment rule

The suite may change while `scoringAllowed` is false, but every change requires
a dated rationale and fresh dependency pins. It becomes the adoption ruler only
through a dated freeze that:

1. resolves every required cell as satisfied, explicitly out of scope, or
   unavailable after a documented search;
2. narrows the advertised display vocabulary when a required positive cell is
   unresolved rather than filling it with an arbitrary synthetic label;
3. pins the framework, output contract, this plan, suite schema, candidate
   schema, replay manifest, validator, scorer, and complete suite;
4. records exact stratum counts and identifiers;
5. sets `scoringAllowed` true only after all files are final; and
6. records that no selector result and no held POP909 item was read during
   construction.

After the freeze, an outcome-motivated case, label, threshold, or metric change
requires a new versioned suite and a new evaluation. Typographical or provenance
corrections that can affect interpretation receive the same treatment. The held
808-song POP909 reserve remains untouched unless a later preregistration gives
it a formal role.
