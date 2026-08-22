import 'package:whatchord/whatchord.dart';

/// One deterministic MIDI realization of an existing snapshot corpus entry.
final class PolychordBenchmarkCase {
  const PolychordBenchmarkCase({
    required this.id,
    required this.input,
    required this.midiNotes,
    required this.lowerCohortCount,
  });

  final String id;
  final ChordInput input;
  final List<int> midiNotes;
  final int lowerCohortCount;

  /// Complete note-on trace with two coherent, orientation-neutral cohorts.
  List<PolychordTemporalEvent> noteOnEvents(int baseTimestampMs) {
    return [
      for (var index = 0; index < midiNotes.length; index++)
        PolychordNoteOnEvent(
          timestampMs:
              baseTimestampMs + (index < lowerCohortCount ? 0 : cohortGapMs),
          midiNote: midiNotes[index],
          velocity: benchmarkVelocity,
        ),
    ];
  }

  /// Primary-analyzer snapshots after every event in [noteOnEvents].
  List<ChordInput> get prefixInputs => [
    for (var end = 1; end <= midiNotes.length; end++)
      chordInputFromMidi(midiNotes.take(end)),
  ];
}

/// Frozen automatic-product cue boundary used only to construct workload time.
const int cohortGapMs = 80;
const int benchmarkVelocity = 80;
const int minimumTimedFinalEventsPerSample = 1000;
const int minimumAllocationEvents = 10000;

typedef PolychordMemoryReplay = ({
  int timestampMs,
  List<PolychordTemporalEvent> events,
});

/// Repetitions needed to make one final-event timing sample long enough.
int finalTimingRepetitions(int caseCount) {
  if (caseCount <= 0) {
    throw RangeError.range(caseCount, 1, null, 'caseCount');
  }
  return (minimumTimedFinalEventsPerSample + caseCount - 1) ~/ caseCount;
}

/// Complete corpus passes needed to amortize allocation-probe overhead.
int allocationPassRepetitions(int eventsPerPass) {
  if (eventsPerPass <= 0) {
    throw RangeError.range(eventsPerPass, 1, null, 'eventsPerPass');
  }
  return (minimumAllocationEvents + eventsPerPass - 1) ~/ eventsPerPass;
}

/// Preconstructs reset-delimited event replays outside an allocation window.
List<PolychordMemoryReplay> memoryReplays(
  List<PolychordBenchmarkCase> cases,
  int passCount,
) {
  if (cases.isEmpty) {
    throw ArgumentError.value(cases, 'cases', 'must not be empty');
  }
  if (passCount <= 0) {
    throw RangeError.range(passCount, 1, null, 'passCount');
  }
  final replays = <PolychordMemoryReplay>[];
  var baseTimestampMs = 0;
  for (var passIndex = 0; passIndex < passCount; passIndex++) {
    for (final benchmarkCase in cases) {
      replays.add((
        timestampMs: baseTimestampMs,
        events: benchmarkCase.noteOnEvents(baseTimestampMs),
      ));
      baseTimestampMs += 1000;
    }
  }
  return replays;
}

/// Projects a snapshot corpus entry into one compact, deterministic voicing.
///
/// The bass is placed from C2 through B2 according to [ChordInput.bassPc]. Each
/// other present pitch class appears once at its first position above the bass.
/// Existing benchmark corpora contain no octave-count-only distinctions; fail
/// closed if a future entry would require inventing a duplicate note.
PolychordBenchmarkCase projectPolychordBenchmarkCase(
  String id,
  ChordInput input,
) {
  final pitchClassCount = _bitCount(input.pcMask);
  if (pitchClassCount != input.noteCount) {
    throw StateError(
      '$id has noteCount ${input.noteCount} but $pitchClassCount pitch classes; '
      'the frozen projection does not invent octave duplicates',
    );
  }
  if ((input.pcMask & (1 << input.bassPc)) == 0) {
    throw StateError('$id does not contain its declared bass pitch class');
  }

  final bassMidi = 36 + input.bassPc;
  final notes = <int>[];
  for (var offset = 0; offset < 12; offset++) {
    final pitchClass = (input.bassPc + offset) % 12;
    if ((input.pcMask & (1 << pitchClass)) != 0) {
      notes.add(bassMidi + offset);
    }
  }
  return PolychordBenchmarkCase(
    id: id,
    input: input,
    midiNotes: List<int>.unmodifiable(notes),
    lowerCohortCount: notes.length ~/ 2,
  );
}

/// Policy-bearing controls whose final frames exercise candidate-bound
/// evidence, selection, ambiguity, and integrated-reading vetoes.
List<PolychordBenchmarkCase> structuralControlCases() => [
  _structuralCase(
    id: 'basic-positive',
    midiNotes: const [43, 46, 50, 60, 64, 67],
    lowerCohortCount: 3,
  ),
  _structuralCase(
    id: 'upper-seventh',
    midiNotes: const [28, 40, 44, 47, 51, 55, 58, 61],
    lowerCohortCount: 4,
  ),
  _structuralCase(
    id: 'assignment-ambiguity',
    midiNotes: const [48, 52, 55, 67, 71, 74, 79],
    lowerCohortCount: 3,
  ),
  _structuralCase(
    id: 'multiple-identities',
    midiNotes: const [44, 48, 51, 54, 67, 71, 74],
    lowerCohortCount: 4,
  ),
  _structuralCase(
    id: 'seventh-extension-veto',
    midiNotes: const [47, 48, 52, 55, 62, 66, 69],
    lowerCohortCount: 4,
  ),
];

PolychordBenchmarkCase _structuralCase({
  required String id,
  required List<int> midiNotes,
  required int lowerCohortCount,
}) {
  if (lowerCohortCount <= 0 || lowerCohortCount >= midiNotes.length) {
    throw ArgumentError.value(
      lowerCohortCount,
      'lowerCohortCount',
      'must leave both cohorts nonempty',
    );
  }
  return PolychordBenchmarkCase(
    id: id,
    input: chordInputFromMidi(midiNotes),
    midiNotes: List<int>.unmodifiable(midiNotes),
    lowerCohortCount: lowerCohortCount,
  );
}

ChordInput chordInputFromMidi(Iterable<int> midiNotes) {
  final notes = midiNotes.toList()..sort();
  if (notes.isEmpty) {
    throw ArgumentError.value(notes, 'midiNotes', 'must not be empty');
  }
  var mask = 0;
  for (final note in notes) {
    if (note < 0 || note > 127) {
      throw RangeError.range(note, 0, 127, 'midiNotes');
    }
    mask |= 1 << (note % 12);
  }
  return ChordInput(
    pcMask: mask,
    bassPc: notes.first % 12,
    noteCount: notes.length,
  );
}

/// Full supported-range storm: attack, pedal capture, release, pedal clear.
List<PolychordTemporalEvent> fullMidiRangeStorm(int baseTimestampMs) {
  final events = <PolychordTemporalEvent>[];
  for (var note = 0; note <= 127; note++) {
    events.add(
      PolychordNoteOnEvent(
        timestampMs: baseTimestampMs + note,
        midiNote: note,
        velocity: benchmarkVelocity,
      ),
    );
  }
  events.add(
    PolychordSustainPedalEvent(timestampMs: baseTimestampMs + 128, down: true),
  );
  for (var note = 0; note <= 127; note++) {
    events.add(
      PolychordNoteOffEvent(
        timestampMs: baseTimestampMs + 129 + note,
        midiNote: note,
        velocity: 0,
      ),
    );
  }
  events.add(
    PolychordSustainPedalEvent(timestampMs: baseTimestampMs + 257, down: false),
  );
  return List<PolychordTemporalEvent>.unmodifiable(events);
}

/// Positive path followed by sustain, release, reattack, and final clear.
List<PolychordTemporalEvent> positiveReattackStorm(int baseTimestampMs) => [
  for (final note in const [43, 46, 50])
    PolychordNoteOnEvent(
      timestampMs: baseTimestampMs,
      midiNote: note,
      velocity: benchmarkVelocity,
    ),
  for (final note in const [60, 64, 67])
    PolychordNoteOnEvent(
      timestampMs: baseTimestampMs + cohortGapMs,
      midiNote: note,
      velocity: benchmarkVelocity,
    ),
  PolychordSustainPedalEvent(timestampMs: baseTimestampMs + 280, down: true),
  PolychordNoteOffEvent(
    timestampMs: baseTimestampMs + 300,
    midiNote: 60,
    velocity: 0,
  ),
  PolychordNoteOnEvent(
    timestampMs: baseTimestampMs + 320,
    midiNote: 60,
    velocity: benchmarkVelocity,
  ),
  for (final note in const [43, 46, 50, 60, 64, 67])
    PolychordNoteOffEvent(
      timestampMs: baseTimestampMs + 340,
      midiNote: note,
      velocity: 0,
    ),
  PolychordSustainPedalEvent(timestampMs: baseTimestampMs + 360, down: false),
];

int _bitCount(int value) {
  var count = 0;
  var remaining = value;
  while (remaining != 0) {
    count += remaining & 1;
    remaining >>= 1;
  }
  return count;
}
