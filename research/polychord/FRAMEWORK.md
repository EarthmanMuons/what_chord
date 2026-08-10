# Polychord framework v0

Status: active theory-derived research specification. This framework records
WhatChord's working product semantics and evidence boundaries. It is not an
independently annotated accuracy ruler and does not authorize a production
change. The decision and its provenance are recorded in log 2026-08-10-01.

## Claim

For this initiative, a **polychord** is a useful constructional or notational
decomposition of one sonority or event window into conventional chordal units.
The term does not assert simultaneous keys, perceptually independent streams, or
a composer's private intention.

WhatChord v0 considers two-layer decompositions. More-than-two-layer structures
remain part of the general musical definition but are outside the initial
product scope.

A polychord name is a secondary annotation. It does not replace or compete with
the analyzer's primary single-chord identity until a later, separately recorded
decision establishes otherwise.

## Initial layer scope

The conservative v0 generator uses the same vocabulary for both layers:

- complete major and minor triads;
- complete dominant, major, and minor seventh chords; and
- different recognized roots for the two layers.

This is an operational product subset, not a universal definition of a chordal
unit.

Shared pitch classes are in scope when separate sounded notes can be assigned to
the two layers. Allowing one sounded note to serve both layer templates is a
later overlapping-cover question, not part of v0.

The following remain useful musical or analytical descriptions but are outside
the initial positive generator:

- a lone bass note, slash-chord bass, power dyad, fifth, shell, or other
  incomplete unit as one layer;
- an upper-structure triad over a rooted seventh-chord shell when an established
  integrated extension names the whole sonority;
- two registral groups that express the same rooted harmony;
- three or more simultaneous chordal layers; and
- augmented, diminished, suspended, quartal, or extended layer vocabularies
  until a later named profile justifies them.

These exclusions limit what the first implementation may propose. They do not
declare that excluded constructions can never be called polychords in analysis
or pedagogy.

## Notation and ordering

The symbolic research notation is `upper|lower`, matching the upper-chord-first
pipe convention used by current engraving software. A displayed result must not
use a slash because slash notation denotes a chord over a bass note.

Layer order follows the notated or evidenced chordal roles, not merely root
pitch. A candidate whose roles cannot be established from the available input
must remain unresolved rather than receiving an arbitrary order.

Enharmonic spelling belongs to presentation, not pitch-class detection. Source
spellings are preserved for score-derived cases. Unspelled MIDI input may use a
neutral spelling internally, but user-facing spelling must follow a separately
frozen output contract.

## Evidence contract

Construction evidence and detector evidence are different records:

- A score, recording, analytical source, or explicit generation recipe may
  establish how a passage was constructed.
- A WhatChord input condition determines whether the app could recover that
  construction from the information it actually receives.

Source-established construction never licenses the detector to consume source
labels, instrumentation, or annotations that are absent from live input.

The required detector baseline is a simultaneous snapshot with one contiguous
boundary between adjacent notes in register. Both groups must satisfy the v0
layer vocabulary. This boundary is candidate-generation evidence, not proof that
the candidate should be displayed.

Register-blind and noncontiguous pitch assignments remain research comparators.
They may measure missed possibilities and ambiguity, but they are not v0 product
licenses.

Temporal evidence may support, weaken, or leave unchanged a candidate produced
from observable notes. It must be developed incrementally:

1. register-only candidate;
2. onset and release grouping;
3. held versus pedal-sustained state;
4. stable note-to-layer assignment and coherent motion across frames; and
5. channel or source evidence only when the transport preserves it reliably.

The absence of temporal history must not silently reject a static or manually
entered polychord. Temporal evidence also must not combine unrelated moments
into a fictional simultaneous sonority.

An event-window fixture used to study timing or motion must record note-on,
note-off, pedal changes, pressed-note state, sustained-note state, and the
derived observation at each evaluated frame. An onset list and aggregate pitch
set alone are not a complete temporal representation. The normative wire format
and transition rules are `frame-replay-schema.md`.

## Case provenance and epistemic status

Every case records musical classification separately from source verification
and product eligibility. Use these epistemic labels:

- **literature-attested construction:** a stable scholarly, pedagogical, score,
  or notation source explicitly supports the decomposition;
- **theory-derived boundary:** the maintainers expect an integrated, slash, or
  upper-structure reading under the documented framework;
- **synthetic regression guard:** an exact generated input tests one declared
  rule or failure mode;
- **unresolved candidate:** sources, voicing, interpretation, or input evidence
  remain insufficient.

Score verification establishes what notes or events the source contains; it does
not turn an interpretation into independent ground truth. Likewise, a
maintainer-authored expected result is a product-policy regression expectation,
not an accuracy label supplied by an external population.

Internal suites may use positive, boundary, and negative expectations to test
the declared product policy. Reports must call them internal regression or
author-adjudicated results, never independent accuracy.

## External validation

External review is not a prerequisite for framework development, source
verification, candidate generation, temporal infrastructure, corpus exposure
measurement, or an internal regression suite.

It becomes necessary before claiming that qualified annotators can reproduce the
task, that a ruler is independently validated, or that an accuracy result
generalizes beyond the author-adjudicated suite.

Any later study must separate two questions:

1. Is a stated constructional decomposition musically appropriate?
2. Could a named machine-input condition recover that decomposition?

Score tasks must identify the exact passage and musical material being judged.
If the proposed layers are shown, the study measures acceptance of a candidate,
not independent discovery. Temporal tasks must present complete event state or a
separately registered performance condition. Ambiguous scans and attack-only
summaries are not sufficient evidence for a temporal judgment.

The archived six-case pilot and review instrument do not meet these requirements
and must not collect research responses. They remain in the repository as
provenance for the design correction recorded in log 2026-08-10-01.

## What remains unfrozen

Before production adoption, later dated decisions must still define:

- the exact composite data type, equality, deduplication, and spelling rules;
- short, long-form, symbolic, and spoken presentation;
- accessibility, history, diagnostics, sharing, and large-text behavior;
- how temporal evidence affects confidence, abstention, and display;
- stable-display behavior and performance budgets; and
- the internal adoption threshold and every required regression and exposure
  guard.
