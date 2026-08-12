# Automatic timestamped-MIDI suite plan

Status: preregistered construction plan for the version-2 automatic suite. This
document fixes the suite boundary and required coverage before any exact
selector is defined or evaluated. It does not create a scorable suite, promote
an onset or motion rule to a licensing cue, authorize corpus evaluation, or
authorize use of the held POP909 reserve.

The planning decision and source audit are recorded in log 2026-08-11-15.

## Purpose

The frozen `data/internal-suite/suite-v0.json` answers a product-policy question
for static and source-adjudicated constructions. Version 2 asks a narrower,
input-dependent question: whether a normalized timestamped MIDI stream contains
enough observed evidence to authorize one exact polychord candidate and keep it
authorized through the display gate.

Those questions must not be collapsed. A source-established polychord can be
unrecoverable from the automatic input, while an ordinary integrated chord can
produce both a structural candidate and a positive temporal cue. The new suite
will therefore preserve construction truth and evaluate automatic evidence as a
separate condition.

## Versioning and inheritance

The new artifact will use its own schema and directory:

- schema: `polychord-automatic-suite/1`;
- input condition: `automaticTimestampedMidi`;
- initial status: `active-author-adjudicated-seed` with `scoringAllowed: false`;
  and
- planned path: `data/automatic-suite/suite-v0.json`.

It will pin the complete frozen internal suite by path and SHA-256 digest and
reference all 17 base case identifiers. It will not copy and edit their
construction, product-expectation, source, input-eligibility, or register
baseline records. New automatic cases may add source passages or synthetic
contract controls, but no automatic-suite field may revise a frozen v0 label.

This reference design makes later changes auditable: a new base-suite digest is
a new dependency, not a silent reinterpretation. The suite remains a
maintainer-adjudicated product-policy instrument rather than independent ground
truth.

## Separate scoring axes

Each automatic case must keep these outcomes separate:

1. **Construction status:** the inherited or newly admitted musical construction
   and product expectation.
2. **Observation coverage:** whether the exact normalized event history needed
   by the input condition is available.
3. **Structural opportunity:** every register candidate at every scored event
   frame, including the absence of a candidate.
4. **Cue interpretation:** the exact candidate-bound result of every named cue,
   including neutral, incomplete, and unavailable results.
5. **Automatic decision:** the selected exact candidate or the one expected
   abstention reason, with all true predicates retained.
6. **Display behavior:** the authorization key, pending interval, display,
   persistence, reset, and clear events around the 200-millisecond gate.

An automatic decision can be scored even when a positive construction is a
coverage exclusion for automatic positive recall. For example, a moving source
construction with no simultaneous structural candidate should produce
`no-structural-candidate`; that correct abstention is not evidence that the
automatic input recovered the construction.

The scorer must report at least:

- inherited construction inventory and coverage exclusions;
- exact cue-record conformance by cue ID;
- exact decision conformance on every automatically scorable observation;
- source-attested automatic-positive coverage by licensing branch;
- boundary and negative-guard conformance; and
- exact display-transition conformance.

No pooled accuracy or recall number may hide exclusions, synthetic-only
coverage, or a branch with no source-attested automatic positive.

## Audit of the frozen 17-case suite

Only three frozen cases currently have an eligible timestamped event stream:

| Base case                             | Product class | Automatic-suite role                                                                                                                                                                                                                                           |
| ------------------------------------- | ------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `stravinsky-petrushka-r49-arpeggios`  | positive      | Source construction and event history are complete, but no replay frame contains a complete register candidate. Score the expected structural abstention and report the case as excluded from automatic-positive coverage. Never verticalize the window union. |
| `stravinsky-shrovetide-second-attack` | boundary      | The source-derived transition supplies positive strict oblique-motion support for an endpoint whose compact integrated reading is Gm7. This is the required source-backed guard that a positive motion cue alone cannot authorize a display.                   |
| `synthetic-layered-c-over-g-minor`    | positive      | The generated replay supplies complete, separated onset cohorts for exact <code>C&#124;Gm</code> mechanics. It can test binding and display behavior but cannot establish source validity for an onset licensing branch.                                       |

The other 14 frozen cases have no frame-accurate event history. Their
construction and static-candidate records remain pinned, but they are explicit
temporal coverage exclusions unless a new, separately sourced replay is later
admitted. Absence of history must not be converted to a neutral cue or a false
negative.

Existing replay fixtures and unit controls that are not frozen musical cases
remain useful contract evidence. In particular, synchronous versus separated
`C|Gm` cohorts hold the static candidate constant; contrary, oblique,
inner-motion, static, common-translation, unequal-similar-direction, and
non-rigid controls test the motion interpretation; and carried-in, pedal, and
reattack histories test availability and binding. Reset and complete
stable-display controls still have to be added. All of these are mechanics
evidence, not independent product labels.

## Licensing-branch admission rule

A cue branch may be named as licensing only after the suite contains all of the
following:

1. at least one evidence-complete, source-attested automatic positive for which
   the exact intended candidate receives that cue's positive support;
2. continuous positive authorization of that exact candidate and sounding-note
   binding for at least 200 milliseconds, or a documented source-fixed timing
   representation that can test the gate without choosing a favorable tempo;
3. at least one source-backed boundary or ordinary integrated control that can
   receive positive support from the same cue but must abstain;
4. synthetic positive, neutral, unavailable, invalidation, and exact-threshold
   controls; and
5. explicit behavior when several structural candidates or cue hypotheses are
   present.

Synthetic generation may prove an implementation invariant but cannot satisfy
item 1 or item 3. A scholarly construction label without an eligible automatic
observation cannot satisfy item 1. Cue support does not replace product policy:
the positive cue must bind the intended exact assignment, and the selector must
still reject source-backed compact integrated readings.

If only one branch satisfies this rule, the first selector may license only that
branch. Other cue records remain diagnostics. There is no requirement to ship
onset and motion together or to weaken their existing interpretations for
symmetry.

## Source-attested motion lead

The strongest current lead is the passage identified as polychordal in Robert
Hutchinson's open _Music Theory for the 21st-Century Classroom_, section 32.4:
chromatically ascending dominant seventh chords in the left hand against a
repeating G-F-C triad cycle in the right hand. The public-domain 1922 piano
score of Stravinsky's _Three Movements from Petrouchka_, printed page 37, shows
the relevant attacks.

The first two attacks after _p sub. e staccatissimo_ are the candidate window:

| Endpoint | Lower source unit    | Upper source unit | Sounding MIDI notes      |
| -------- | -------------------- | ----------------- | ------------------------ |
| Source   | F7: F2 A2 C3 Eb3     | G major: G4 B4 D5 | `41 45 48 51 / 67 71 74` |
| Target   | Gb7: Gb2 Bb2 Db3 Fb3 | F major: F4 A4 C5 | `42 46 49 52 / 65 69 72` |

Under the register-role-preserving hypothesis, the lower unit translates up one
semitone and the upper unit translates down two semitones. The frozen
`rigid-layers-oblique-or-contrary/1` interpretation therefore has a
threshold-free contrary-motion hypothesis. The source frame generates exactly
`G|F7`. The target generates both `Fmaj7|F#` at an earlier split and the
source-hand assignment `F|F#7`; candidate-specific motion can distinguish the
intended assignment without relying on generator order.

This is a lead, not yet an admitted automatic positive. Before admission:

- verify the exact attacks and spellings against the pinned score at high
  resolution and record the source location unambiguously;
- encode the complete release, attack, and sounding-state window without
  deleting zero-dwell intermediate frames;
- pin a source-supported temporal scale and verify that the intended target
  remains continuously authorized for 200 milliseconds; if that cannot be
  established, retain the passage as a motion construct check rather than a
  display-positive case;
- retain both target structural candidates and every primary single-chord
  alternative; and
- admit the product expectation in a new dated entry before any selector output
  is read.

The current verification artifacts are:

- textbook page: <https://musictheory.pugetsound.edu/mt21c/polychords.html>,
  locally captured with SHA-256
  `7b59a70a0ea33bdc88242afbb459451e3b547593b471d837bcee7af7d2e00904`; and
- score PDF:
  <https://petruccilibrary.us/autoindex/index.php?dir=imslp-us_files%2FStravinsky_Igor_1971%2F&file=Stravinsky_-_Petrushka_3mvts.pdf>,
  SHA-256 `90d0b14d929697f33762eacb715c3331a6ebf0faf1e722e0f50598241ebf5664`.

## Onset branch remains diagnostic

Moreira's Example 6 from Bernard Herrmann's “The Pass” remains the strongest
onset-ordering lead. The analysis describes a sustained G-minor triad against a
later A-flat-minor attack, and the verified notation supplies the exact
registered units `56 59 63 / 67 70 74`. It supports the musical premise that
separate chord attacks can articulate polychordal construction.

It does not yet establish the physical threshold in
`coherent-separated-onsets-50-200ms/1`. The excerpt has no local tempo, and an
arbitrary score-to-millisecond normalization could determine whether the rule
passes. The official audio is a stereo film mix rather than authoritative
per-note MIDI; it can corroborate the passage but cannot establish the exact
attack span of every candidate note. The existing generated 400-millisecond
control proves mechanics only.

Consequently, onset must remain diagnostic in the first exact selector unless a
new source supplies defensible note-level timing and a matched onset-positive
integrated guard. This is a coverage result, not evidence that onset is
musically irrelevant and not a reason to tune the 50/200-millisecond thresholds
against the current examples.

The official MTO verification artifacts are the examples PDF, SHA-256
`09cd7f3bcbcee61a5def436d342c01576ca47d6481bdbb9932454616a04ecb62`, and Example
6 audio, SHA-256
`84bb6602bc0f66b130b82304118ebeda45ed6e96a4c5f605de3e7d86c9f31e37`.

## Required coverage before freeze

The automatic suite must contain executable cases for every applicable row:

| Coverage family               | Minimum requirement                                                                                                                                                               |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Licensing evidence            | One source-attested automatic positive per licensing cue branch, satisfying the 200-millisecond authorization requirement.                                                        |
| Cue-positive guard            | One source-backed boundary or integrated reading per licensing branch whose cue is positive but whose decision abstains.                                                          |
| Construction/input separation | A source positive with complete event history but no simultaneous structural candidate, retaining expected abstention and positive-coverage exclusion separately.                 |
| Synthetic mechanics           | Positive and neutral controls for every licensing cue, plus diagnostic-only cues if their implementation is present.                                                              |
| Matched static state          | The same exact candidate and assignment with positive, neutral, and unavailable histories where the cue permits such matching.                                                    |
| Candidate ambiguity           | Multiple structural candidates with support bound only to the intended exact candidate and assignment.                                                                            |
| Motion interpretation         | Oblique and contrary positives; static, common translation, unequal similar direction, non-rigid change, and retained-instance contradiction as neutral controls.                 |
| Onset interpretation          | Both layer orders, exact 50- and 200-millisecond boundaries, just-inside neutral boundaries, synchronous attacks, incomplete history, and carried-in state.                       |
| Causal invalidation           | Note release, sustain retention, same-pitch reattack, assignment change, tracker reset, and restoration from a static snapshot.                                                   |
| Stable display                | Continuous authorization at 199 and 200 milliseconds, sub-200-millisecond suppression, persistence without an event, support loss, binding invalidation, and a changed candidate. |
| Decision diagnostics          | Exact abstention reason precedence and complete ordered predicate retention for every multi-failure control.                                                                      |

Rows for a non-licensing diagnostic cue test only its declared cue record; they
do not imply that its positive result can authorize selection or display.

## Freeze sequence

Complete these steps without reading selector output:

1. encode and validate the new schema with all 17 frozen-case references and
   explicit temporal coverage dispositions;
2. resolve the motion lead, including display dwell, and either admit it or
   record why it cannot satisfy automatic-positive coverage;
3. decide which evidence branches meet the admission rule; onset remains
   diagnostic unless its missing source coverage is filled;
4. finish the synthetic contract matrix and source-backed guards;
5. freeze the suite, exact cue IDs, correspondence and endpoint selection,
   structural policy, scorer, stable-display reducer, and all dependency pins;
6. implement the selector independently in Python and pure Dart, then run
   label-free equivalence checks before evaluating the suite once; and
7. preregister a new development source or resampling design before reading any
   new corpus outcome.

Previously exposed POP909, ASAP, and When in Rome material remains development
evidence. The held 808-song POP909 reserve remains untouched. Failure to admit a
source-valid automatic positive is an acceptable result and means that no
automatic selector using the current cue set is justified.
