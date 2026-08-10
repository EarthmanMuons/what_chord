# Polychord research protocol

Status: SCOPING. The schema-3 census profiles are fixed for the measurements in
log 2026-08-02-06. `FRAMEWORK.md`, adopted in log 2026-08-10-01, fixes the
theory-derived v0 product semantics and evidence boundaries as a working
hypothesis. It is not an independently annotated ruler. The composite data
contract, regression suite, scoring model, adoption bar, and performance budget
remain unfrozen and require later dated decisions before an engine lever is
evaluated.

## Task and claim boundary

Determine whether WhatChord should name a sonority as two chordal layers, when
that decomposition is preferable to or useful beside a single chord symbol, and
what evidence is sufficient to show it.

The working constructional definition is two or more conventional chordal units
combined in one sonority. "Polychord" names that construction or notation; it
does not by itself claim concurrent keys, perceptually independent streams, or
compositional intent. The current analyzer input contains sorted MIDI pitches,
so the snapshot path can observe pitch content and register but not timbre,
instrumentation, channel, or independent onset and motion cues. The live input
stream can support timestamped note-on, note-off, and pedal evidence before that
collapse, and motion can be derived from successive frames. Those cues are a
declared research avenue, not evidence the current analyzer already possesses.
Any result must state which input evidence it used.

The scoping census measures voicings that satisfy declared split rules. It is
not an accuracy test, a product detector, or evidence that its fires should be
shown to users.

`FRAMEWORK.md` is the normative record for the current layer scope, notation,
evidence tiers, and epistemic labels. This protocol governs how those hypotheses
are developed and evaluated. `register-candidate-schema.md` fixes the exact
structural proposal surface for the register-only baseline without freezing the
later product output contract.

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

Current scoping corpora, all octave-preserving:

- When in Rome v1, development split only
  (`research/whatkey/data/splits/when-in-rome-v1.json`).
- ASAP x When in Rome, development split only
  (`research/performed-input/data/splits/asap-wir-nc-v2.json`).
- The committed POP909 sample fixtures, used as an advisory corpus. The 808-song
  held pool remains evaluation-virgin.

Rules:

- No test split has been read or scored in this initiative.
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
stable-display gate.

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
3. register plus onset and motion-coherence evidence;
4. channel or source evidence only if the input transport preserves it reliably
   and measurements show that it represents musical grouping.

Onset evidence may include within-layer attack synchrony, separation between
layer attack cohorts, release grouping, restrikes, and the distinction between
physically pressed and pedal-sustained notes. Motion evidence may include stable
note-to-layer assignment and coherent movement of each proposed layer across
successive frames.

These cues may raise or lower decomposition confidence or justify abstention.
Their absence must not silently disqualify a polychord: simultaneous attacks,
static sonorities, manual lookup, and transports without reliable event history
remain valid inputs. Before adoption, the output contract must define whether
each cue is optional evidence, a display gate, or a requirement, and must define
fallback behavior when it is unavailable.

Temporal ablations require frame-accurate replay. Committed-event fixtures
cannot evaluate them because they omit within-event revoicing and note-event
order.

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

Construction truth and input eligibility are separate annotations. A score can
establish a polychordal construction while a pitch-and-register snapshot cannot
recover it; such a case is ineligible for that input condition, not a detector
false negative. Eligibility must be recorded separately for adjacent-register
snapshots, general pitch-and-register snapshots, and timestamped event streams.

The annotation guidelines must distinguish canonical shared-tone polychords from
integrated sixth, seventh, and extended chords; polychords from slash chords and
upper-structure voicings; and constructional decompositions from perceptual or
intentional claims.

`internal-suite-schema.md` fixes the active author-adjudicated seed format, and
`data/internal-suite/suite-v0.json` contains the first exact cases. Its
`scoringAllowed` field remains false: the seed exercises provenance,
eligibility, and structural generation but is not the frozen adoption ruler. The
suite validator must reproduce every register-baseline candidate from the exact
observation while keeping that mechanical result separate from the product
expectation.

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

The complete internal suite, metrics, and adoption threshold must be frozen
before any proposed engine rule is evaluated against it. Without independent
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
scope, notation order, and evidence hierarchy. Before an engine lever is
designed or measured, a later dated decision must additionally specify:

- how the secondary polychord annotation coexists with the unchanged primary
  single-symbol reading and alternative candidates;
- the composite data representation, layer order, enharmonic spelling rules,
  equality, deduplication, and partial-credit scoring;
- symbolic, short, long-form, and spoken wording, including note-name systems;
- history, diagnostics, sharing/link behavior, accessibility semantics,
  large-text layout, and behavior when a decomposition appears or disappears;
- how register, onset cohorts, motion, pedal state, and any reliable source cues
  affect confidence, abstention, and display, including fallback behavior when
  temporal evidence is absent;
- the frame-level generator and stable-display measurements, performance budget,
  and adoption threshold.

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
- Report the register-only, onset, and motion configurations as named ablations
  on the same eligible frames; do not attribute a combined result to an
  individual cue.
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
   fixed by `register-candidate-schema.md` and log 2026-08-10-03. Study onset,
   release, pedal, and motion next as named incremental evidence. Channel or
   source evidence remains a later ablation.
3. Internal suite: score-verify literature examples, encode exact machine-input
   fixtures, assign epistemic status, and keep construction evidence separate
   from input eligibility. The non-scorable seed, schema, and validator are
   fixed by `internal-suite-schema.md` and log 2026-08-10-04; expand and freeze
   the adoption ruler only after remaining source and output questions are
   resolved.
4. Output and evaluation freeze: encode the composite type, metrics, adoption
   threshold, stable-display behavior, and performance budget before evaluating
   a lever.
5. Implementation-shaped exposure: measure proposals and stable displays at
   frame level before making a safety claim.
6. Optional external validation: use a newly registered, evidence-complete study
   before any reproducibility, independently validated ruler, or generalized
   accuracy claim. This is not a prerequisite for the preceding research work.

## Engine and product guards

Any adopted lever must pass all of the following:

- the solo chord golden and ranking suites;
- the comping suite at 18/18;
- `tool/benchmark.sh --check` against its committed baseline;
- oracle-pool blast-radius comparison via `tool/chord/pool_diff.py`;
- the dense-set stress census and POP909 corroboration;
- the author-adjudicated polychord suite and its frozen adoption threshold;
- frame-level counts of proposed decompositions and stable-display counts on
  every scoping corpus, with a complete disposition of every new fire;
- the frozen polychord performance budget and on-device note-storm profiling.

Single-chord pool differences cannot reveal an incorrect secondary decomposition
when the primary identity is unchanged. The generator and display guards are
therefore additive to the existing engine checks.
