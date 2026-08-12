# Automatic timestamped-MIDI suite plan

Status: preregistered construction plan for the version-2 automatic suite. This
document fixes the suite boundary and required coverage before any exact
selector is defined or evaluated. It does not create a scorable suite, promote
an onset or motion rule to a licensing cue, authorize corpus evaluation, or
authorize use of the held POP909 reserve.

The planning decision is recorded in log 2026-08-11-15. Log 2026-08-12-01
records that the first two prospective motion positives did not satisfy this
plan's admission rule.

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

## Motion-source audit: no admitted lead

The passage identified as polychordal in Robert Hutchinson's open _Music Theory
for the 21st-Century Classroom_, section 32.4, remains a valid construction and
motion lead: chromatically ascending dominant seventh chords in the left hand
against a repeating G-F-C triad cycle in the right hand. The public-domain 1922
piano score of Stravinsky's _Three Movements from Petrouchka_, printed page 37,
shows the relevant attacks under _p sub. e staccatissimo_.

Log 2026-08-11-15 proposed an exact two-attack transcription and
register-role-preserving contrary-motion hypothesis. Log 2026-08-12-01 retains
that proposal for provenance but does not admit its exact note assignment: the
independent sequence located during the audit does not corroborate it
note-for-note.

It is not an automatic display-positive case. High-resolution score inspection
can establish the notated construction, attack order, rhythm, and articulation,
but it cannot turn the written staccatissimo into an exact note-off time. An
independently authored public MIDI sequence of the closing passage spaces
successive attacks about 428.571 milliseconds apart while releasing the notes
after 125 milliseconds. That sequence is corroboration rather than ground truth,
and its exact voicings must not replace the score transcription. It does,
however, demonstrate why inter-onset spacing is not display dwell: the intended
candidate ceases to be authorized when its sounding instances release, and the
following silence cannot count toward the frozen 200-millisecond appearance
gate.

No fixture may lengthen these attacks merely to make the gate pass. The proposed
pitch assignment also remains provisional unless it is reused in a later
score-pinned construct check; the public sequence does not supply note-for-note
confirmation of it.

Moreira's Example 6 from Bernard Herrmann's “The Pass” supplies a second exact
motion lead. Its notation and analysis name A-flat minor below G minor followed
later by F-sharp minor below G minor. The two registered states each generate
one candidate, and a role-preserving comparison gives oblique motion: the lower
triad moves down two semitones while the upper triad remains static.

That pair is not admitted either. The notation places a noncandidate gap between
the two sections, and the current motion program defines no causal endpoint,
lookback, or memory rule that may bridge it. The frozen corpus endpoint rule
deliberately does not skip a positive-duration noncandidate state. Silently
deleting the gap from a suite fixture would manufacture evidence that the source
does not contain. The example also lacks authoritative per-note millisecond
timing for the display gate.

These are negative source-audit results, not reasons to retune the motion rule
or display threshold. Motion remains diagnostic until a source provides all of
the following in one observation:

- an analytically or notationally attested polychord decomposition;
- exact timestamped note-on and note-off evidence;
- a direct candidate-to-candidate transition under a preregistered causal
  endpoint rule;
- positive support for the intended exact candidate and assignment; and
- at least 200 milliseconds of continuous target authorization.

The current verification artifacts are:

- textbook page: <https://musictheory.pugetsound.edu/mt21c/polychords.html>,
  locally captured with SHA-256
  `7b59a70a0ea33bdc88242afbb459451e3b547593b471d837bcee7af7d2e00904`; and
- score PDF:
  <https://petruccilibrary.us/autoindex/index.php?dir=imslp-us_files%2FStravinsky_Igor_1971%2F&file=Stravinsky_-_Petrushka_3mvts.pdf>,
  SHA-256 `90d0b14d929697f33762eacb715c3331a6ebf0faf1e722e0f50598241ebf5664`;
- public David Siu MIDI listing: <https://www.midi-karaoke.info/215c5051.html>,
  locally captured with SHA-256
  `c1632a84c30cd3f83c722589c843b45d61bd9b216b3d3805b73ff2f34406b395`;
- public David Siu MIDI sequence: <https://www.midi-karaoke.info/215c5051.mid>,
  SHA-256 `5430dffb2056f226bc82a79fe8f9a3244aaf9744c1db07a04226714bd359ebf8`;
  and
- Moreira examples PDF, SHA-256
  `09cd7f3bcbcee61a5def436d342c01576ca47d6481bdbb9932454616a04ecb62`.

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

## Revised freeze sequence after the source audit

Complete these steps without reading selector output:

1. Preserve the rejected Stravinsky and Herrmann leads as coverage findings; do
   not encode either as an automatic positive or tune a threshold against it.
2. Run a bounded source search for an analytically attested passage with
   authoritative timestamped note-level data that satisfies one licensing branch
   and the display gate.
3. If no branch meets the admission rule, stop automatic selector work under
   `polychord-output/2`. Changing the input or output claim requires a separate
   dated decision and contract version.
4. Only after a branch is admitted, encode and validate the new schema with all
   17 frozen-case references and explicit temporal coverage dispositions.
5. Finish that branch's synthetic contract matrix and source-backed guards.
6. Freeze the suite, exact cue IDs, correspondence and endpoint selection,
   structural policy, scorer, stable-display reducer, and all dependency pins.
7. Implement the selector independently in Python and pure Dart, then run
   label-free equivalence checks before evaluating the suite once.
8. Preregister a new development source or resampling design before reading any
   new corpus outcome.

Previously exposed POP909, ASAP, and When in Rome material remains development
evidence. The held 808-song POP909 reserve remains untouched. Failure to admit a
source-valid automatic positive is an acceptable result and means that no
automatic selector using the current cue set is justified.
