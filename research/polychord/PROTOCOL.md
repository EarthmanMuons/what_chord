# Polychord research protocol

Status: SCOPING. The schema-3 census profiles are fixed for the measurements in
log 2026-08-02-06. `FRAMEWORK.md`, adopted in log 2026-08-10-01, fixes the
theory-derived v0 product semantics and evidence boundaries as a working
hypothesis. It is not an independently annotated ruler. The composite data and
presentation contract, scoring model, adoption bar, stable-display policy, and
performance budget are fixed by `output-evaluation-contract.md` and log
2026-08-10-18. The complete author-adjudicated adoption suite is frozen by log
2026-08-11-03. It is a product-policy conformance ruler, not independent ground
truth. The register-only selector passed its frozen author-adjudicated suite but
failed the development exposure gate: log 2026-08-11-12 dispositions all 73
stable POP909 displays as ordinary integrated harmonies or zero-duration
serialization artifacts. No v1 selector reached the held 808-song POP909 reserve
or product integration. Log 2026-08-11-13 records the static observability
collision that requires evidence beyond register for automatic version 2.
`automatic-output-contract-v2.md` fixes that input and output boundary, and
`automatic-suite-v2-plan.md` fixes the suite construction and source-coverage
requirements that must be satisfied before an exact version-2 selector is
preregistered. Log 2026-08-12-01 records that neither prospective motion source
positive met those requirements. Log 2026-08-12-02 records that the bounded
follow-up source search also admitted no onset or motion branch, corrects the
coupling of source admission to display dwell, and pauses scientific-validation
selector work before suite construction. `automatic-timing-calibration-plan.md`
governs prospective timing work.
`automatic-timing-sensitivity-preregistration.md` fixes the first exploratory
onset-gap and appearance-dwell comparison without authorizing a threshold
choice. Log 2026-08-12-06 records its successful result: no timing profile was
selected, and source coverage remains the next prerequisite for that
scientific-validation route. Log 2026-08-12-07 corrects the result's guard
interpretation: Liszt fills the onset boundary-guard cell at the 50- and
80-millisecond profiles, while the source-positive and
ordinary-integrated-control cells remain empty. The satisfied v0 coverage and
stopping record remains normative in `adoption-suite-plan.md`. That
source-admission route remains the prerequisite for an independently validated
or publication-oriented claim, not for an explicitly author-adjudicated product
policy. `product-completion-plan.md` and log 2026-08-13-08 define a separate
product track under a new output and selector identity without weakening the
preserved `polychord-output/2` contract.

The author-adjudicated product path has since passed its frozen suite,
development exposure, and prior-art comparison through log 2026-08-14-06. Log
2026-08-14-07 records app integration and automated presentation, history,
diagnostic, primary-isolation, and unchanged-engine guards. The dedicated
polychord benchmark is frozen prospectively by log 2026-08-22-01; its timed run
and the hands-on device checks remain. The held POP909 reserve has not been
opened.

## Task and claim boundary

Determine whether WhatChord should name a sonority as two chordal layers, when
that decomposition is preferable to or useful beside a single chord symbol, and
what evidence is sufficient to show it.

The working constructional definition is two or more conventional chordal units
combined in one sonority. "Polychord" names that construction or notation; it
does not by itself claim concurrent keys, perceptually independent streams, or
compositional intent. The current analyzer input contains sorted, distinct MIDI
pitches, so the snapshot path can observe pitch content and register but not
timbre, instrumentation, channel, or independent onset and motion cues. The live
input stream can support timestamped note-on, note-off, and pedal evidence
before that collapse. Successive frames expose exact transitions and retained
sounding-note instances, but changed-pitch voice or layer continuity requires a
declared assignment model. Those cues are a declared research avenue, not
evidence the current analyzer already possesses. Any result must state which
input evidence and assignment model it used.

The scoping census measures voicings that satisfy declared split rules. It is
not an accuracy test, a product detector, or evidence that its fires should be
shown to users.

`FRAMEWORK.md` is the normative record for the current layer scope, notation,
evidence tiers, and epistemic labels. This protocol governs how those hypotheses
are developed and evaluated. `register-candidate-schema.md` fixes the exact
structural proposal surface for the register-only baseline.
`output-evaluation-contract.md` fixes how a later selected proposal may coexist
with the primary result and how that output must be measured.
`adoption-suite-plan.md`, preregistered in log 2026-08-10-19, fixes the coverage
and stopping rules satisfied before the active seed became the frozen scorable
adoption ruler in log 2026-08-11-03. `development-exposure-v1.md` fixes the
first implementation-shaped development measurement without pretending that a
sparse committed-event fixture is a live event stream.

## Research record and change control

- Each experiment, measurement correction, or significant decision gets a dated
  entry under `log/` with the exact commands, fixture and code pins, results,
  and interpretation.
- Development and held-out data remain separate. No held-out result is read
  until the ruler, generator, scoring model, and adoption bar are frozen.
- Negative results and corrections remain in the log. Once a ruler or result set
  is frozen, changes require a later dated amendment rather than silent
  revision.
- Generated reports must identify their schema, command, working directory,
  runtime, script hash, fixture hashes and manifest pins, and split-file hash.

## Data isolation and splits

Current scoping sources, all octave-preserving but not equally time-complete:

- When in Rome v1, development split only, as a committed-event proposal
  companion (`research/whatkey/data/splits/when-in-rome-v1.json`). Its sparse
  snapshots do not support stable-display replay.
- ASAP x When in Rome, development split only, replayed from raw performance
  MIDI (`research/performed-input/data/splits/asap-wir-nc-v2.json`).
- The frozen 101-song POP909 sample roster, used as an advisory corpus. The
  stable-display measurement reuses the exact raw-MIDI `BRIDGE` plus `PIANO`
  projection already frozen for that sample. The 808-song clean reserve remains
  evaluation-virgin; it is not yet a declared final test set. Freeze a
  fit-for-purpose development/test allocation from that reserve only if POP909
  later gains a formal evaluation role.

Rules:

- No test split has been run or scored with a polychord generator or selector.
  Log 2026-08-11-08 records one incidentally printed committed When in Rome test
  fixture during a schema-shape audit; future work must not describe that
  source's test fixtures as wholly unseen. No raw ASAP test performance or held
  POP909 song has been opened in this initiative.
- Corpus results are reported separately and never pooled. Pieces represented in
  more than one corpus are not treated as independent observations.
- Fixture sets and split files are versioned and immutable for a result set.
  Split pins must match fixture manifests, and results from different fixture
  versions are not combined.
- Corpus annotations, reference chord labels, candidate-list tags, and expected
  polychord readings are scoring data only. A candidate generator, ranking rule,
  or display gate may not consume them.
- Scoping corpora are negative-exposure evidence because they contain no
  verified positive polychord annotations. They are not accuracy rulers.
- Frame, duration, and display claims are made only from sources preserving the
  required evidence. Committed-event duration is never substituted for exact
  assignment persistence.

## Scoping census

The census implementation is `tool/polychord/split_census.py`, report schema 3.
It has two detector families:

- Registral split: examine every adjacent-note register boundary meeting the
  declared minimum gap and retain every boundary whose lower and upper groups
  match the selected profile.
- Pitch-class-only cover: discard register and find every upper/lower template
  cover whose lower unit contains the bass pitch class. This is the
  register-blind exposure comparator.

Every run must name one exact template profile:

- `complete-common` is the primary constructional profile. Both layers use the
  same vocabulary: complete major and minor triads and complete dominant, major,
  and minor seventh chords.
- `bichord-triads` is the narrower symmetric two-triad profile used to measure
  the bichord/polytriad subset.
- `upper-structure-triads` admits a major or minor upper triad over a complete
  common chord, power dyad, or seventh shell.
- `upper-structure-common` admits a complete common upper chord over the same
  lower vocabulary. The two upper-structure profiles measure jazz, sus, shell,
  and incomplete-lower boundaries; they are not definitions of a polychord.

All profiles require different recognized roots. Two register groups spelling
the same rooted harmony do not form a polychord candidate. Separate sounded
notes in the two registral groups may project to the same pitch class. The
pitch-class-only comparator permits a shared pitch class only when the input has
enough note instances to allocate one to each layer. A single sounded note never
serves both layers in schema 3.

`complete-common` is an operational subset, not an exhaustive translation of
"conventional chordal units." It excludes augmented and diminished families,
incomplete units, bass-only units, extensions beyond the seventh, and
three-or-more layers. Any wider scope requires ruler support and a new named
profile rather than an unlabeled switch.

### Census unit and evidence trail

Fixture events snapshot the voicing at a committed chord-identity onset,
attribute the event duration to that snapshot, and omit same-identity revoicing.
The census therefore measures committed-event exposure only. It does not measure
every frame seen by a live generator or the subset that survives a
stable-display gate. The When in Rome development companion retains this same
limitation in `development-exposure-v1.md`; only raw ASAP and POP909 MIDI are
eligible for the stable-display safety measurement.

Schema-3 reports retain every registral and pitch-class-only fire with piece,
event index, timestamp, MIDI voicing, every split or cover, and the current
top-ranked single chord. They also retain ambiguity counts, per-piece tallies,
event and duration totals, the full generating command, and all reproducibility
pins listed above.

## Temporal grouping exploration

Register-only decomposition is the required baseline, not a commitment that
register must be the final or only license. A separate pure-Dart temporal
tracker may consume normalized timestamped note-on, note-off, and pedal events
and emit immutable grouping evidence for a proposed split. The snapshot chord
analyzer remains deterministic and stateless; temporal history does not become
hidden analyzer state.

The temporal evidence program must be evaluated incrementally:

1. register-only split evidence;
2. register plus onset-cohort evidence;
3. register plus onset and release/pedal evidence;
4. register plus onset, release/pedal, exact frame transitions, and a separately
   declared motion-coherence model;
5. channel or source evidence only if the input transport preserves it reliably
   and measurements show that it represents musical grouping.

Onset evidence may include within-layer attack synchrony and separation between
layer attack cohorts. Release/pedal evidence may include release grouping,
restrikes, state age, pedal transitions, and the distinction between physically
pressed and pedal-sustained notes. Frame-transition evidence may include exact
sounding-instance continuity and endpoint layer relations. Motion evidence may
include stable note-to-layer assignment and coherent movement only after the
assignment method is explicit.

Under the frozen v0 output contract, these cues are one-sided diagnostics:
positive onset or motion support may accompany a selected candidate, but neutral
or unavailable history cannot lower, reject, or create a selection. Release and
pedal evidence remains uninterpreted. A later selector version may let a named
cue weaken a decomposition or justify abstention only after a preregistered
contract amendment defines its interpretation and unavailable-history fallback.
Simultaneous attacks, static sonorities, manual lookup, and transports without
reliable event history remain valid inputs.

The completed v1 development result supplies the reason for that later version.
Log 2026-08-11-13 establishes a static observability collision: the same
transposition-invariant register candidate structure occurs in both a frozen
source positive and ordinary integrated development harmonies. For the next
automatic raw-MIDI selector, register is therefore proposal evidence only and a
display must also receive positive support from a separately preregistered
evidence source independent of static register. Neutral, incomplete, or
unavailable support will mean abstention under that new input condition. This
does not retroactively change the v0 contract, the v1 result, the musical
definition, or a future explicit manual-layer condition.
`automatic-selection-v2-plan.md` fixes the prerequisites that must be completed
before an exact version-2 selector is preregistered.
`automatic-output-contract-v2.md` and log 2026-08-11-14 complete the first
prerequisite as `polychord-output/2`: automatic timestamped selection requires
candidate-specific positive support bound to the current sounding instances,
with causal invalidation and a support-aware 200-millisecond display gate.
`automatic-suite-v2-plan.md` and log 2026-08-11-15 complete the next planning
prerequisite: all frozen construction records remain pinned, temporal coverage
and automatic scoring stay separate, and a cue branch cannot license display
without a source-attested automatic positive plus source-backed guards.

Temporal ablations require frame-accurate replay. Committed-event fixtures
cannot evaluate them because they omit within-event revoicing and note-event
order.

`onset-evidence-schema.md` fixes the first threshold-free temporal evidence
surface. It reconstructs the most recent note-on instance of each currently
sounding candidate note, preserves unknown carried-in onsets and pedal state,
and reports raw layer spans and signed interval relations. It does not define a
synchrony tolerance, cohort label, confidence effect, or display gate; those
must be a later named and pinned ablation.

`onset-support-ablation.md` fixes that first named interpretation as
`coherent-separated-onsets-50-200ms/1`. It grants one-sided positive support
only to two complete onset intervals whose layers each span at most 50
milliseconds and whose intervals are separated by at least 200 milliseconds.
Every other result is neutral, including synchronous and incomplete history. The
rule is not a perceptual-independence claim or a product display gate.

`onset-exposure-census.md` preregisters the first corpus measurement. It uses
only the previously exposed 101-song POP909 sample, projects the paper-defined
`BRIDGE` plus `PIANO` accompaniment through WhatChord's channel-blind pitch-set
and global-pedal input semantics, preserves the 808-song held pool, and reports
event-frame, sounding-time, candidate-instance, normalization, and per-piece
evidence separately. The corpus has no verified polychord labels, so this is
exposure rather than accuracy. The detailed report remains under `build/` and
the fixed census must be committed before it is run.

`release-pedal-evidence-schema.md` fixes the second threshold-free temporal
evidence surface after the bounded audit in logs 2026-08-10-09 and
2026-08-10-10. It retains exact held state, onset, release, current-state,
reattack, prior-release, and pedal-transition provenance for every candidate
note. It preserves carried-in unknowns and raw layer summaries without defining
an age limit, release cohort, penalty, confidence effect, or display gate.
Corpus run grouping remains audit methodology rather than a field in the
single-frame evidence object.

`frame-transition-evidence-schema.md` fixes the third threshold-free temporal
surface. The caller selects two exact replay frames; the output retains every
ordered intervening event and frame, independently generates both endpoint
candidate sets, compares their Cartesian product, and records exact continuity
of sounding note instances. It enumerates every endpoint layer relation and both
two-layer correspondence hypotheses without choosing one. In line with the
symbolic voice-separation literature, a departed pitch and newly arrived pitch
are not treated as the same voice unless a later named and pinned assignment
model links them. The contract defines no window-selection rule, pairing cost,
coherence label, confidence effect, or display gate.

`motion-support-ablation.md` fixes the first interpretation of that transition
surface as `rigid-layers-oblique-or-contrary/1`. For each explicit endpoint
correspondence, both candidate layers must preserve their complete MIDI sets
under exact signed translations. Only oblique or contrary translations between
the two layers supply one-sided positive support. Static layers, common
whole-sonority translation, unequal same-direction motion, revoicing, note entry
or exit, changed doubling, retained-instance contradiction, and non-rigid
relations remain neutral. The profile selects no correspondence and defines no
endpoint-enumeration, confidence, rejection, or display rule.

`motion-exposure-census.md` preregisters the first endpoint enumeration and
corpus measurement for that ablation. It selects only the final replay frame at
each distinct timestamp and pairs adjacent terminal frames without skipping or
an elapsed-time cutoff. Same-timestamp construction frames remain reported but
cannot become endpoints; a positive-duration noncandidate state breaks the
chain. The census reuses the frozen 101-song POP909 sample and accompaniment
projection, keeps the 808-song reserve untouched, and separates endpoint-frame,
transition, target-dwell, candidate-pair, and hypothesis exposure. It must be
committed before execution.

## Internal suite and case provenance

No surveyed corpus provides verified positive polychord labels. The initial
regression suite must therefore be a versioned, author-adjudicated collection of
exact snapshots or event windows with three declared product expectations:

- positive: a polychord reading is expected, at least as an alternative;
- boundary: a single symbol is preferred, with a decomposition acceptable only
  as a pedagogical or secondary reading;
- negative guard: the voicing must not produce a polychord reading.

These expectations test the declared product policy; they are not independent
accuracy labels. Each case must also carry one epistemic status from
`FRAMEWORK.md`: literature-attested construction, theory-derived boundary,
synthetic regression guard, or unresolved candidate.

Candidate examples are not ground truth. Before entering the internal suite,
each literature example must be checked against a stable score source and
ideally a recording. Each entry must record the sounded notes or event window,
upper and lower identities, note-to-layer assignment, source, admissible
alternatives, scope feature (shared tone, incomplete unit, bass-only unit, and
so on), and the evidence that licenses or blocks the split. A passage may not be
silently verticalized into a simultaneous voicing that the source never sounds.
An octave-normalized or otherwise generated observation must never identify
itself as a literal score transcription. When a stable analytical source
explicitly supplies both the complete pitch collection and named decomposition,
the suite may preserve that literature-attested construction through an
`analysis` source record that pins the artifact and discloses the normalization.
When the normalization instead supplies or changes the analytical decomposition,
the case remains synthetic and theory-derived, with its context sources confined
to the dated admission record.

Construction truth and input eligibility are separate annotations. A score can
establish a polychordal construction while a pitch-and-register snapshot cannot
recover it; such a case is ineligible for that input condition, not a detector
false negative. Eligibility must be recorded separately for adjacent-register
snapshots, general pitch-and-register snapshots, and timestamped event streams.

The annotation guidelines must distinguish canonical shared-tone polychords from
integrated sixth, seventh, and extended chords; polychords from slash chords and
upper-structure voicings; and constructional decompositions from perceptual or
intentional claims.

`internal-suite-schema.md` fixes the author-adjudicated suite format, and
`data/internal-suite/suite-v0.json` contains the frozen exact ruler. Its
`scoringAllowed` field is true only under the paired
`frozen-author-adjudicated-adoption` status. The suite validator must reproduce
every register-baseline candidate from the exact observation while keeping that
mechanical result separate from the product expectation.

### Deferred pilot and later external validation

The six-case pilot and static review instrument created in logs 2026-08-02-07
through -11 are deferred without collecting responses. They remain byte-pinned
historical artifacts. Their score views do not identify the exact material a
reviewer must judge without also revealing the proposed decomposition, and their
temporal cases expose attacks and an aggregate note set without complete
duration, release, pedal, or held-state evidence. Results from that instrument
would therefore conflate musical judgment with evidence-presentation failure.

External annotation is not a gate for developing the framework, verifying
sources, building candidate generators or temporal infrastructure, measuring
corpus exposure, or maintaining an author-adjudicated regression suite. Those
activities must describe their expectations as theory-derived product policy,
not independent ground truth or general accuracy.

External validation is required before claiming that qualified annotators can
reproduce the construct, that a ruler is independently validated, or that an
accuracy estimate generalizes beyond the author-adjudicated suite. A later study
must separate constructional appropriateness from recoverability by a named
machine-input condition. It must identify the exact musical material to judge
and present complete event state for temporal questions. Showing a candidate
decomposition measures acceptance of that candidate, not independent discovery.

If a later study seeks a reproducibility claim, obtain at least two independent
qualified responses, preferably three. Pin the task and analysis before data
collection, retain abstentions and raw disagreements, compute all pairwise
comparisons before discussion, and never overwrite an original response with
adjudication. One external response supplies face validation only.

The complete internal suite, metrics, and adoption threshold were frozen before
any proposed engine rule was evaluated against them. Without independent
validation, report results as agreement with the author-adjudicated product
specification rather than accuracy against musical ground truth.

## Prior-art baselines

The scoped search claim and exact query record live in `prior-art-search.md`.
Before adoption, the proposed method must be compared on the same frozen
author-adjudicated suite with pinned versions of at least musicpy and mingus.
ChordRecGen should be included if its archived toolchain can be executed
reproducibly.

For every baseline record the package or source version, input ordering,
options, raw output, normalization, failures, and runtime. These systems are
comparison baselines, not scientific ground truth. A WhatChord result must not
be described as the first computational polychord detector; the provisional
research contribution is an explicit task definition, a provenance-rich internal
suite, and an evaluated register-licensed naming method. An independently
validated task or ruler may be claimed only after a later external study.

## Required output and evidence contract

`FRAMEWORK.md` fixes the v0 secondary-annotation semantics, conservative layer
scope, notation order, and evidence hierarchy. `output-evaluation-contract.md`,
adopted in log 2026-08-10-18, additionally fixes:

- a parallel optional secondary result that cannot change primary ranking,
  history segmentation, key inference, or Explore;
- ordered composite and assignment identity, spelling and deduplication rules,
  exact and partial-credit metrics, and the all-cases-exact adoption gate;
- canonical, visual, long-form, semantic, and spoken wording;
- accessibility, diagnostics, input-only sharing, and deliberately
  single-chord-only v0 history behavior;
- one-sided temporal support without numeric confidence or rejection for neutral
  and unavailable history;
- an asymmetric 200-millisecond appearance gate with immediate invalidation; and
- frame-level and stable-display reporting plus the 5% normalized-time and
  on-device note-storm performance budget.

The contract freezes the interface and evaluation. It does not choose a
selector. The complete adoption suite was frozen before any selector result was
read.

The 200-millisecond appearance gate is a product display profile inherited from
the measured primary-chord stability work. It is not a construction label, a cue
threshold, or a polychord-perception claim. Cue interpretation, automatic
decision, and display survival must be reported separately. The independent
200-millisecond onset parameter remains only one conservative named ablation;
`automatic-timing-calibration-plan.md` governs any prospective comparison.

## Statistics and reporting

- Report event counts and duration-weighted exposure together, per corpus and
  per piece. Pooled event totals may accompany per-piece results but never
  replace them.
- Retain and disposition every generator or display fire used to support a
  safety claim. Report proposal and display exposure separately.
- For paired accuracy comparisons, report the per-piece mean, bootstrap 95%
  confidence interval, Wilcoxon signed-rank result, and sample size. Record all
  random seeds.
- Report latency and count distributions with at least median and p90.
- Report the register-only, onset, release/pedal, and motion configurations as
  named ablations on the same eligible frames; do not attribute a combined
  result to an individual cue.
- If a later external study is run, report annotator agreement with a metric
  appropriate to its frozen label and partial-credit representation, plus raw
  agreement and adjudication counts. A small formative study must not support
  kappa, inferential statistics, or a population-level reliability claim.
- Report each ruler and corpus separately. Disagreement among them is a result,
  not a reason to pool them.

## Progression before adoption

The following work must be dated and completed in order:

1. Framework v0: complete. Log 2026-08-10-01 fixes the theory-derived product
   semantics, initial layer scope, notation order, and evidence boundaries.
2. Evidence infrastructure: exact frame replay is fixed by
   `frame-replay-schema.md` and log 2026-08-10-02. The register-only baseline is
   fixed by `register-candidate-schema.md` and log 2026-08-10-03. Threshold-free
   onset provenance is fixed by `onset-evidence-schema.md` and log
   2026-08-10-05. The first conservative onset interpretation is fixed by
   `onset-support-ablation.md` and log 2026-08-10-06. Its POP909 measurement is
   preregistered by `onset-exposure-census.md` and log 2026-08-10-07, then
   executed unchanged in log 2026-08-10-08. It found zero positively supported
   instances and makes release/pedal history the next threshold-free evidence
   question. `release-pedal-audit.md` and log 2026-08-10-09 preregister a
   label-free audit of the complete 59-instance pitch-class-disjoint subset,
   executed unchanged in log 2026-08-10-10. All 59 observations occurred with
   pedal down and sustained notes, and every observation contained either a
   sustained-note reattack or an onset predating the current pedal-down episode.
   The reusable threshold-free contract is fixed by
   `release-pedal-evidence-schema.md` and log 2026-08-10-11; it does not define
   a rejection rule. Threshold-free frame-transition evidence is fixed by
   `frame-transition-evidence-schema.md` and log 2026-08-10-12. The first
   conservative set-level motion interpretation is fixed by
   `motion-support-ablation.md` and log 2026-08-10-13. Its first endpoint and
   exposure measurement is preregistered by `motion-exposure-census.md` and log
   2026-08-10-14, then executed unchanged in log 2026-08-10-15. It found zero
   positive rigid-motion hypotheses or windows: none of the 776 hypotheses on
   127 pitch-changing candidate windows contained a nonzero exact layer
   translation. Log 2026-08-10-16 then records a transparent post-result
   construct check against Moreira's score excerpt from Stravinsky's “The
   Shrovetide Fair”: the frozen rule recognizes its first depicted oblique
   triadic-layer transition, but that evidence does not settle the user-facing
   label for its compact C9 and Gm7 endpoint collections. Channel or other
   source evidence remains a later ablation.
3. Internal suite: complete. Score-verify literature examples, encode exact
   machine-input fixtures, assign epistemic status, and keep construction
   evidence separate from input eligibility. The non-scorable seed, schema, and
   validator are fixed by `internal-suite-schema.md` and log 2026-08-10-04. Log
   2026-08-10-17 admits the first literature-attested positive that the
   adjacent-register baseline can recover: Ives's _Psalm 67_ opening yields
   `C|Gm` while retaining `C9/G` as the exact single-chord alternative. The
   coverage and stopping rules are preregistered in `adoption-suite-plan.md`;
   complete every applicable cell before freezing the ruler. The
   selector-independent 3,300-combination structural matrix and focused
   ambiguity controls passed in log 2026-08-10-20; they do not fill
   source-attested cells. Log 2026-08-10-21 separately admits recoverable source
   positives from Moreira's Herrmann transcription and Stravinsky's 1922 _Three
   Movements from Petrouchka_ score, covering disjoint units and a complete
   dominant-seventh layer without reading a selector or corpus outcome. Log
   2026-08-10-22 adds Petrushka rehearsal 49 as a bounded event window without
   verticalizing its arpeggios. Log 2026-08-10-23 corrects the Elektra chord's
   former bare-fifth classification and admits its one-sounded-note overlapping
   cover as a theory-derived v0 boundary. Log 2026-08-10-24 adds a doubled
   two-hand Cmaj7 accompaniment whose exact register split generates `Em|C` but
   whose product expectation remains the integrated chord. Log 2026-08-10-25
   promotes the conformance harness's same-identity assignment ambiguity into an
   integrated Cmaj9 negative guard: two boundaries generate `G|C` with different
   exact note assignments. Log 2026-08-11-01 fills the remaining source-backed
   scope cell with Waters's A-minor-seventh-over-D analysis of _Maiden Voyage_,
   represented as a disclosed octave normalization and an executable lone-bass
   boundary. Log 2026-08-11-02 resolves the freeze-order and multiple-answer
   scoring gaps, adds the pinned exact scorer, and makes the input,
   temporal-support, and stable-display controls executable without reading a
   selector result. Log 2026-08-11-03 records the final 17-case inventory and
   coverage disposition, verifies the complete dependency closure, and freezes
   the ruler before any selector is defined or evaluated.
4. Output and evaluation freeze: complete. `output-evaluation-contract.md` and
   log 2026-08-10-18 fix the composite type, presentation, metrics, adoption
   threshold, stable-display behavior, and performance budget without choosing
   or evaluating a selector.
5. Register-only selector preregistration: complete. `register-selector-v1.md`
   and log 2026-08-11-04 fix the deterministic v1 policy, its admissible
   evidence, integrated-tertian and exact-assignment abstention rules,
   widest-gap resolution, and three diagnostic ablations before implementation
   or evaluation.
6. Selector implementation and internal conformance: complete. Log 2026-08-11-05
   records independent Python and pure-Dart implementations and zero mismatches
   across 13,244 complete decisions on the pinned structural matrix. Log
   2026-08-11-06 freezes the suite-evaluation harness before any prediction
   exists. The single run in log 2026-08-11-07 then records zero Python/Dart
   mismatches, six of six exact eligible positives, and nine of nine correct
   guards for the full selector, satisfying adoption-bar items 2 through 4 only.
7. Implementation-shaped exposure: complete; adoption-bar item 5 failed.
   `development-exposure-v1.md` and log 2026-08-11-08 fix exact frame and stable
   display exposure on raw ASAP development MIDI and the frozen POP909 sample,
   plus a separately named committed-event proposal companion for When in Rome.
   Log 2026-08-11-09 records the pure-Dart exact-assignment display reducer,
   label-blind replay adapters, complete provenance and accounting controls,
   musician-readable review packet, append-only disposition validation, and
   synthetic verification. Logs 2026-08-11-10 and -11 preserve two attempts
   rejected before outcome inspection for input projection and runtime
   provenance defects. The valid result in log 2026-08-11-12 has 73 full-policy
   POP909 stable episodes: 70 ordinary integrated harmonies and three
   zero-duration serialization artifacts, with no in-scope polychord. ASAP has
   zero full-policy stable episodes and When in Rome has zero full-policy event
   proposals. Do not proceed to the held reserve or product integration with
   `polychord-register-policy/1`.
8. Version-2 evidence boundary: complete. Log 2026-08-11-13 records that a
   frozen `C|Gm` positive and three `G|Dm` development errors share the same
   transposition-invariant static layer structure, while their register gaps do
   not separate them. `automatic-selection-v2-plan.md` therefore keeps the
   generator and vocabulary, rejects a broader static blacklist, and requires a
   versioned automatic timestamped-input contract plus source-attested positive
   controls before an exact selector using evidence beyond register is
   preregistered. This is a research plan, not a version-2 selector or
   permission to use the reserve.
9. Version-2 output contract: complete. `automatic-output-contract-v2.md` and
   log 2026-08-11-14 define `polychord-output/2` for `automaticTimestampedMidi`.
   Positive support binds one exact candidate and its current sounding
   instances; neutral or unavailable support abstains; reattack, reset, or
   support loss invalidates authorization; and the existing 200-millisecond
   appearance gate runs only while authorization is continuous. Static v1
   eligibility and explicit manual grouping remain separate input conditions. No
   licensing cue, selector, suite, or new corpus result is chosen here.
10. Version-2 automatic-suite plan: complete; suite construction did not begin.
    `automatic-suite-v2-plan.md` and log 2026-08-11-15 preserve the frozen
    17-case suite by pinned reference, classify its three event-complete cases
    and 14 temporal coverage exclusions, and fix separate construction, cue,
    decision, and display scoring axes. A licensing branch requires a
    source-attested automatic-decision positive with exact candidate-bound event
    evidence plus a source-backed cue-positive guard; display survival is a
    separate scoring axis. The Stravinsky ascending-sevenths passage is the
    first motion lead; onset remains diagnostic because its current source
    evidence does not establish the ablation's millisecond threshold. No
    automatic suite or selector has been run.
11. First automatic motion-source audit: complete with no admitted positive. Log
    2026-08-12-01 records that score rhythm and attack spacing cannot substitute
    for sounding-instance dwell. A public sequence corroborates 125-millisecond
    releases in the Stravinsky staccatissimo passage, below the frozen
    200-millisecond display gate. Moreira's “The Pass” supplies an exact
    oblique-motion construct, but its useful endpoints are separated by a
    noncandidate gap that no frozen causal endpoint rule may bridge. The active
    suite plan triggered a bounded search for a source with authoritative
    note-level timing before suite construction. Falling below that display
    baseline is a display-coverage result, not a cue or construction label. No
    selector or corpus outcome was read.
12. Bounded automatic source search: complete with a coverage and calibration
    result. Log 2026-08-12-02 screens the frozen source cases, Moreira's
    complete official examples supplement, relevant GiantMIDI-Piano and
    specialist archive entries, the public _Detection of clash of keys_
    materials, and targeted open symbolic-source leads. Moreira's “The Scar”
    strengthens the onset premise with explicitly asynchronous complete triads
    and article-hosted audio. A hand-sequenced _Malediction_ supplies exact
    source-fixed events; its pedal-derived candidate is neutral under the named
    50/200 onset profile and suppressed under the current display baseline. The
    score independently corrects that backlog case from a static positive to an
    alternating-chord boundary. No source satisfies a licensing branch together
    with its required matched cue-positive guard. The Ives opening is confirmed
    as a simultaneous-onset control, not a license. Pause before encoding the
    suite, evaluating a selector, or reading the held reserve. Continuing
    requires the corrected source coverage; existing results retain their exact
    named profiles, and any further timing comparison remains governed by
    `automatic-timing-calibration-plan.md`.
13. Automatic timing sensitivity: complete. The first measurement attempt failed
    before output and its correction was committed separately.
    `automatic-timing-sensitivity-preregistration.md` freezes the
    development-informed 50/80/100/200/300-millisecond onset-gap comparison,
    independent 0/50/100/200/300-millisecond authorization-survival comparison,
    fixed POP909 and Liszt inputs, raw evidence requirements, monotonicity and
    baseline checks, and stopping rules. Log 2026-08-12-04 records the
    fail-closed implementation, historical source-pin validation, exact
    candidate-instance episode accounting, committed matched-history controls,
    and passing unit suite. Log 2026-08-12-05 records the failed registered run:
    the complete Liszt stream contained a later channel-collapsed unmatched
    release that the strict evidence-fixture grammar cannot represent. The
    correction searches every normalized frame for the exact target, then
    strictly replays only through the final relevant frame. Log 2026-08-12-06
    records the successful clean-commit measurement. Every POP909 profile stayed
    at zero: all 33 instances with two layers inside the fixed 50-millisecond
    span were synchronous, so lowering only the between-layer minimum could not
    change them. The Liszt boundary supplied two cue-positive episodes at the 50
    and 80-millisecond profiles; both survived 0 and 50-millisecond dwells and
    neither survived 100 milliseconds. This selects no row: the within-layer
    maximum remains unvalidated, Liszt remains a boundary and supplies the
    preregistered onset boundary guard for those two profiles, no
    source-attested positive or cue-positive ordinary integrated control exists
    under either profile, no selector is run, and the held reserve remains
    untouched. Log 2026-08-12-07 preserves the correction to the initial guard
    interpretation and the stronger frozen control requirement.
14. Product completion track: active. `product-completion-plan.md` and logs
    2026-08-13-08 through 2026-08-14-06 preserve the frozen contract, policy,
    suite, equivalent Python and Dart implementations, development exposure, and
    prior-art comparison. Log 2026-08-14-07 records integration into the app's
    normalized timestamped-event path and accessible secondary output. Automated
    engine, app, presentation, diagnostic, history-isolation, and
    unchanged-primary benchmark guards pass. Log 2026-08-22-01 freezes the
    dedicated pure-Dart performance benchmark without running its timed
    measurement. That run and hands-on MIDI, accessibility, and device
    note-storm checks remain before the release candidate can be frozen. The
    held POP909 reserve remains untouched, and the product claim remains
    author-adjudicated rather than an independently validated accuracy claim.
15. Optional external validation: use a newly registered, evidence-complete
    study before any reproducibility, independently validated ruler, or
    generalized accuracy claim. This is not a prerequisite for the preceding
    research work.

## Engine and product guards

Any adopted lever must pass all of the following:

- the solo chord golden and ranking suites;
- the comping suite at 18/18;
- `tool/benchmark.sh --check` against its committed baseline;
- oracle-pool blast-radius comparison via `tool/chord/pool_diff.py`;
- the dense-set stress census and POP909 corroboration;
- the author-adjudicated polychord suite and its frozen adoption threshold;
- frame-level counts of proposed decompositions and stable-display counts on
  every frame-capable scoping corpus, with a complete disposition of every new
  fire, plus separately labeled committed-event proposal diagnostics where raw
  replay is unavailable;
- the frozen polychord performance budget and on-device note-storm profiling.

Single-chord pool differences cannot reveal an incorrect secondary decomposition
when the primary identity is unchanged. The generator and display guards are
therefore additive to the existing engine checks.
