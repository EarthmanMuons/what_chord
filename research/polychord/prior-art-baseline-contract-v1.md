# Polychord prior-art baseline contract v1

Status: preregistered adapter, normalization, and reporting contract for
`polychord-prior-art-baselines/1`. No baseline output on the product suite has
been read. Adapters, dependency locks, smoke controls, and result serializers
must be committed and pinned before the comparison runs.

The comparison is descriptive. None of these systems supplies ground truth, sets
WhatChord's product vocabulary, or acts as a threshold WhatChord must beat.

## Comparison tasks

Two tasks remain separate:

1. `named-snapshot/1` runs each detector independently on every declared static
   target in `polychord-product-suite/1`.
2. `adapted-stream/1` reruns each static detector after every musical event that
   changes the sounding MIDI-note set. Raw frame output is primary. An optional
   common display wrapper is reported separately and is never described as the
   detector's native real-time behavior.

Static detectors do not receive timer, primary-availability, or tracker-reset
actions. They do not receive source identity, case title, expected construction,
candidate assignment, primary chord, key, onset record, or prior output.

## Common observation record

Each invocation receives one adapter-neutral JSON object containing only:

```text
observationId
orderedMidiNotes
scientificPitchSharps
pitchClassSharps
```

`orderedMidiNotes` is the exact sorted, distinct registered sounding state.
Scientific pitch uses MIDI 60 = C4 and the ASCII sharp spellings C, C#, D, D#,
E, F, F#, G, G#, A, A#, B. `pitchClassSharps` preserves the same array order and
duplicates. Case-specific enharmonic spellings are not passed because they would
give a baseline contextual information unavailable to another baseline.

The neutral record never deduplicates pitch classes, folds octaves, transposes,
revoices, adds roots, or removes doublings. An individual adapter may be forced
by its public API to lose some of this information. That loss is recorded as a
native limitation rather than repaired with expected labels.

Every invocation produces exactly one result record with:

- baseline ID and immutable source or package pin;
- observation ID and a digest of the neutral input;
- exact adapter input after unavoidable API conversion;
- options and runtime identity;
- raw return value in a stable JSON representation;
- raw standard output and standard error when a subprocess is used;
- elapsed time as a diagnostic, not a quality metric;
- status: `ok`, `no-output`, `exception`, `timeout`, `build-unavailable`, or
  `unparseable`; and
- zero or more normalized composite alternatives.

Exceptions, empty output, and unsupported vocabulary remain results. The harness
cannot retry with different options, reorder notes, or select a more favorable
alternate after reading the expected answer.

## Executable pins and invocations

### WhatChord register-only baseline

Baseline ID: `whatchord-register-policy-1`.

Use the frozen Python and pure-Dart implementations of
`polychord-register-policy/1` on `orderedMidiNotes`. Both must first agree
exactly. Retain the complete structural candidate list, decision traces,
selected exact candidate or reasons, and serialized symbols. This is a static
register policy; it receives no onset evidence and no product display wrapper
unless the adapted result explicitly says so.

### musicpy

Baseline ID: `musicpy-7.15-poly-chord-first`.

The executable artifact is the PyPI source distribution `musicpy-7.15.tar.gz`,
published 2026-06-19:

```text
SHA-256 b6e10025648632a666ce99b0647655158a87dc554ebd9edbb9547d87fbf2a3e1
```

The repository discovery commit is not the executable pin. Install the exact
source distribution into an isolated environment only after a hash-locked
transitive dependency file has been committed. Record the Python executable,
`python --version`, platform, installed distributions, and hashes. The first
baseline environment uses the repository's Python 3.12.13 pin; incompatibility
is a retained failure, not permission to change package code.

Convert each MIDI note with `musicpy.degree_to_note(midiNote)`, preserving the
ascending registered order and octave. Invoke exactly:

```python
musicpy.alg.detect_chord_type(
    converted_notes,
    change_from_first=True,
    original_first=True,
    same_note_special=False,
    whole_detect=True,
    poly_chord_first=True,
    root_preference=False,
    show_degree=False,
    get_chord_type=True,
    original_first_ratio=0.86,
    similarity_ratio=0.6,
    custom_mapping=None,
    standardize_note=False,
)
```

Serialize every public `chord_type` field recursively. For a polychord,
`polychords[0]` is the lower fixed-split result and `polychords[1]` is the upper
result; the library's `to_text()` reverses these for its displayed upper/lower
form. Retain both the structured order and exact `to_text()` output. Do not run
the wider detector as a fallback when a component is unknown: with
`poly_chord_first=True`, the fixed split is the baseline being evaluated.

### python-mingus

Baseline ID: `python-mingus-6558cac-polychords`.

Use source commit `6558cacffeaab4f084a3eedda12b0e86fd24c430`. The inspected
GitHub commit archive had SHA-256
`b0723787b69943940ca7ad1c7dffa3cb27eb83755a2a1bc25f8a8f90cd935462`. Archive
provenance and the checked-out commit must both be verified before execution.
Install it with a committed hash-locked dependency set in an isolated Python
3.12.13 environment and retain the same runtime inventory as musicpy.

Mingus chord recognition has no octave-bearing input. Pass `pitchClassSharps`
unchanged, including repeated names and ascending-register order, to:

```python
mingus.core.chords.determine(
    pitch_class_sharps,
    shorthand=True,
    no_inversions=False,
    no_polychords=False,
)
```

Retain the complete ordered list. A string containing `|` is a composite
alternative in mingus's own upper-chord-first syntax. Strings without `|` are
retained single-chord output, not adapter abstention or failure. The adapter
does not infer MIDI assignments because mingus did not return them.

### ChordRecGen

Baseline ID: `chordrecgen-3790a4d-swift`.

Use source commit `3790a4df5f1c3bbef4ff0a27c43ddacc020a6639`. The inspected
GitHub commit archive had SHA-256
`6f5bb36fda9156e1dff518387dcf8e95e788f342ec1963cb715573d3541994eb`. The
preferred implementation is the original Swift library under
`IOS/ChordRecognizeGenerate/ChordRecognizeGenerate`, not an independently
evolving port.

Compile the unmodified pinned Swift recognition sources plus a repository-owned
JSON command-line wrapper. Record `swift --version`, the compiler invocation,
source hashes, and executable hash. The wrapper converts `orderedMidiNotes`
losslessly to `[ChordNote]`, creates `ChordRecognizer`, and calls exactly:

```swift
ChordRecognizer().notesToChord(midiNoteValues: notes)
```

Serialize every returned `ChordGroup` in order, including `getFullName()`,
`isPolyChord()`, score when accessible without source changes, every component
chord's root, quality, factor, full name, and MIDI notes. The adapter must not
take only the first group: alternatives tied by the native score are all raw
results.

If the pinned source cannot compile with an available archived or current Swift
toolchain without editing recognition source, record `build-unavailable` with
the exact failure. Do not patch recognition logic, switch silently to the Kotlin
port, or omit the baseline. A later explicitly pinned compatibility study may
compare ports, but it is not this baseline.

## Smoke controls before suite execution

Each adapter must pass source-independent transport controls before it may see a
suite target:

- input order and duplicate preservation are exactly as declared;
- empty, one-note, and two-note behavior is retained without harness failure;
- one root-position major triad and one seventh chord exercise ordinary output;
- one six-note fixed-split control exercises a composite-capable path;
- raw alternatives are neither dropped nor reordered;
- an injected exception is serialized as failure rather than converted to
  abstention; and
- two runs of the same input produce byte-equivalent normalized output after
  removing elapsed-time diagnostics.

Smoke controls contain no product-suite expected label. Their purpose is to
prove the adapter faithfully transports input and output, not that the detector
is musically correct.

## Composite normalization

Raw output is authoritative. Normalization adds a comparison view and never
rewrites raw data.

Roots normalize enharmonically to pitch class. Only the five product qualities
normalize as supported components:

| Canonical quality | Accepted native forms after exact source inspection |
| ----------------- | --------------------------------------------------- |
| `major`           | native root-position major triad                    |
| `minor`           | native root-position minor triad                    |
| `dominant7`       | native dominant seventh                             |
| `major7`          | native major seventh                                |
| `minor7`          | native minor seventh                                |

The committed adapter tests must pin the exact token mapping for each system
before suite execution. Altered, suspended, diminished, added-note, incomplete,
single-note, and unknown components remain `unsupported-component`; they are not
coerced to the nearest supported quality.

A normalized alternative is one of:

- `ordered-composite`, with exactly two supported component identities;
- `single-chord-output`;
- `unsupported-composite`, when native output has two or more components but
  cannot be represented by the product vocabulary;
- `unparseable`; or
- an invocation failure status.

Musicpy's structured lower/upper roles and mingus's documented pipe order set
orientation directly. For ChordRecGen, infer upper and lower only when exactly
two returned component note sets are nonempty, disjoint, exhaust the input, and
one lies entirely above the other in register. Otherwise retain an unordered or
unsupported composite rather than treating recursion order as register order.

Do not infer missing component notes from chord names. Assignment scoring is
defined only for systems that return or mechanically fix an exact input
partition. Capability exclusions are reported separately; they are not zeros and
do not improve a pass count.

## Metrics and reporting

For every named-snapshot target, report:

- whether any composite was emitted;
- ordered composite exact against each acceptable expected identity;
- unordered component credit as matched supported units over two;
- assignment exact when the baseline exposes an exact partition;
- correct composite abstention on boundary and negative-guard targets;
- unsupported, unparseable, exception, timeout, and unavailable counts; and
- the complete raw and normalized alternatives.

Coverage exclusions, including unresolved construction order and a baseline's
missing assignment capability, retain case IDs and reasons. Exact counts and
denominators are reported per baseline and per inherited, authored-positive, and
authored-guard stratum before any combined descriptive total.

For adapted streams, report raw output after every changed sounding-note frame,
identity changes, composite frame and dwell exposure, exceptions, and no-output
frames. If the common 200-ms continuous-identity wrapper is run, it consumes
only the normalized composite identity and musical-frame timestamps. It cannot
use WhatChord onset support or expected labels. Its appearances, clears, and
dwell are published under `evaluation-wrapper`, alongside the unwrapped raw
frames.

Baseline results cannot change suite expectations or product policy in place. A
discrepancy may motivate a later versioned experiment only after the complete
frozen comparison is retained.

## Implementation and freeze boundary

Before any suite target is passed to a baseline:

1. commit adapter source, source-fetch verification, and hash-locked dependency
   files;
2. commit raw and normalized JSON schemas;
3. pass all adapter smoke controls and normalization tests;
4. record runtime and executable hashes;
5. pin those files in the product suite; and
6. record a dated baseline freeze with a clean repository state.

Changing an input conversion, option, source pin, runtime, parser, component
mapping, orientation rule, failure rule, target set, metric, or display wrapper
after results are visible creates a new baseline contract and a separately
reported run. Raw version-1 output is never replaced.
