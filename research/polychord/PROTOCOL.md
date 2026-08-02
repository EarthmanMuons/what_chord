# Polychord research protocol

Status: SCOPING. The schema-3 census profiles are fixed for the measurements in
log 2026-08-02-06. The product semantics, ruler, scoring model, adoption bar,
and performance budget are not frozen. Each must be fixed in a dated log entry
before an engine lever is evaluated.

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

## Research record and change control

- Each experiment, measurement correction, or significant decision gets a
  dated entry under `log/` with the exact commands, fixture and code pins,
  results, and interpretation.
- Development and held-out data remain separate. No held-out result is read
  until the ruler, generator, scoring model, and adoption bar are frozen.
- Negative results and corrections remain in the log. Once a ruler or result
  set is frozen, changes require a later dated amendment rather than silent
  revision.
- Generated reports must identify their schema, command, working directory,
  runtime, script hash, fixture hashes and manifest pins, and split-file hash.

## Data isolation and splits

Current scoping corpora, all octave-preserving:

- When in Rome v1, development split only
  (`research/whatkey/data/splits/when-in-rome-v1.json`).
- ASAP x When in Rome, development split only
  (`research/performed-input/data/splits/asap-wir-nc-v2.json`).
- The committed POP909 sample fixtures, used as an advisory corpus. The
  808-song held pool remains evaluation-virgin.

Rules:

- No test split has been read or scored in this initiative.
- Corpus results are reported separately and never pooled. Pieces represented
  in more than one corpus are not treated as independent observations.
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
  same vocabulary: complete major and minor triads and complete dominant,
  major, and minor seventh chords.
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
The census therefore measures committed-event exposure only. It does not
measure every frame seen by a live generator or the subset that survives a
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

## Ruler and annotation

No surveyed corpus provides verified positive polychord labels. The accuracy
ruler must therefore be a versioned, hand-authored suite of exact voicings with
three declared tags:

- positive: a polychord reading is expected, at least as an alternative;
- boundary: a single symbol is preferred, with a decomposition acceptable only
  as a pedagogical or secondary reading;
- negative guard: the voicing must not produce a polychord reading.

Candidate examples are not ground truth. Before entering the ruler, each
literature example must be checked against a stable score source and ideally a
recording. Each entry must record the sounded notes, upper and lower identities,
note-to-layer assignment, source, admissible alternatives, scope feature
(shared tone, incomplete unit, bass-only unit, and so on), and the evidence that
licenses or blocks the split.

The annotation guidelines must distinguish canonical shared-tone polychords
from integrated sixth, seventh, and extended chords; polychords from slash
chords and upper-structure voicings; and constructional decompositions from
perceptual or intentional claims. If publication remains an objective, a second
independent annotator must apply the frozen guidelines and the record must
include agreement statistics and adjudication.

The complete ruler, metrics, and adoption threshold must be frozen before any
proposed engine rule is evaluated against it.

## Prior-art baselines

The scoped search claim and exact query record live in `prior-art-search.md`.
Before adoption, the proposed method must be compared on the same verified
ruler with pinned versions of at least musicpy and mingus. ChordRecGen should be
included if its archived toolchain can be executed reproducibly.

For every baseline record the package or source version, input ordering,
options, raw output, normalization, failures, and runtime. These systems are
comparison baselines, not scientific ground truth. A WhatChord result must not
be described as the first computational polychord detector; the provisional
research contribution is an explicit task and annotation method, a verified
ruler, and an evaluated register-licensed naming method.

## Required output and evidence contract

Before an engine lever is designed or measured, a dated decision must specify:

- whether a polychord is a secondary annotation, an alternative candidate, or a
  primary identity, and how it competes with the single-symbol reading;
- the composite data representation, layer order, enharmonic spelling rules,
  equality, deduplication, and partial-credit scoring;
- symbolic, short, long-form, and spoken wording, including note-name systems;
- history, diagnostics, sharing/link behavior, accessibility semantics,
  large-text layout, and behavior when a decomposition appears or disappears;
- how register, onset cohorts, motion, pedal state, and any reliable source cues
  affect confidence, abstention, and display, including fallback behavior when
  temporal evidence is absent;
- the frame-level generator and stable-display measurements, performance
  budget, and adoption threshold.

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
- Report annotator agreement with a metric appropriate to the frozen label and
  partial-credit representation, plus raw agreement and adjudication counts.
- Report each ruler and corpus separately. Disagreement among them is a result,
  not a reason to pool them.

## Open decisions before ruler freeze

The following decisions must be dated and made in order:

1. Product semantics: what the feature names, primary versus secondary display,
   and whether shared-tone, incomplete, and bass-only layers are in scope.
2. Evidence program: define the register-only baseline, then evaluate onset and
   motion as incremental grouping evidence. Decide whether each cue affects
   confidence, abstention, or eligibility, and define behavior when it is
   unavailable. Treat channel or source evidence as a later optional ablation.
3. Pilot annotation: score-verify and independently review a small suite that
   resolves the shared-tone versus integrated-chord boundary.
4. Frozen ruler and evaluation: encode the full suite, metrics, output contract,
   adoption threshold, and performance budget before evaluating a lever.
5. Implementation-shaped exposure: measure the proposed generator at frame
   level and after the stable-display gate before making a safety claim.

## Engine and product guards

Any adopted lever must pass all of the following:

- the solo chord golden and ranking suites;
- the comping suite at 18/18;
- `tool/benchmark.sh --check` against its committed baseline;
- oracle-pool blast-radius comparison via `tool/chord/pool_diff.py`;
- the dense-set stress census and POP909 corroboration;
- the polychord ruler and its frozen adoption threshold;
- frame-level counts of proposed decompositions and stable-display counts on
  every scoping corpus, with a complete disposition of every new fire;
- the frozen polychord performance budget and on-device note-storm profiling.

Single-chord pool differences cannot reveal an incorrect secondary
decomposition when the primary identity is unchanged. The generator and display
guards are therefore additive to the existing engine checks.
