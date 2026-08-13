import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'polychord_onset_evidence.dart';

/// Immutable onset-tracking state immediately after one normalized event.
@immutable
final class PolychordOnsetTrackingFrame {
  factory PolychordOnsetTrackingFrame({
    required int trackerEpoch,
    required int afterEventIndex,
    required int timestampMs,
    required bool pedalDown,
    required Iterable<PolychordSoundingNoteOnset> soundingNoteOnsets,
  }) {
    _checkExactNonnegativeInteger(trackerEpoch, 'trackerEpoch');
    _checkExactNonnegativeInteger(afterEventIndex, 'afterEventIndex');
    _checkExactNonnegativeInteger(timestampMs, 'timestampMs');
    final notes = List<PolychordSoundingNoteOnset>.unmodifiable(
      soundingNoteOnsets,
    );
    final origins = <int, PolychordOnsetOrigin>{};
    for (var index = 0; index < notes.length; index++) {
      final note = notes[index];
      if (index > 0 && note.midiNote <= notes[index - 1].midiNote) {
        throw ArgumentError.value(
          soundingNoteOnsets,
          'soundingNoteOnsets',
          'must be strictly increasing without duplicate MIDI notes',
        );
      }
      if (note.soundingState == PolychordSoundingState.sustained &&
          !pedalDown) {
        throw ArgumentError.value(
          soundingNoteOnsets,
          'soundingNoteOnsets',
          'cannot contain sustained notes while the pedal is up',
        );
      }
      final origin = note.origin;
      if (origin == null) continue;
      if (origin.eventIndex > afterEventIndex ||
          origin.timestampMs > timestampMs) {
        throw ArgumentError.value(
          origin,
          'soundingNoteOnsets',
          'onset origins must not occur after the frame',
        );
      }
      if (origins.containsKey(origin.eventIndex)) {
        throw ArgumentError.value(
          origin.eventIndex,
          'soundingNoteOnsets',
          'must not reuse an onset event index',
        );
      }
      origins[origin.eventIndex] = origin;
    }
    final orderedOrigins = origins.values.toList()
      ..sort((a, b) => a.eventIndex.compareTo(b.eventIndex));
    for (var index = 1; index < orderedOrigins.length; index++) {
      if (orderedOrigins[index].timestampMs <
          orderedOrigins[index - 1].timestampMs) {
        throw ArgumentError.value(
          soundingNoteOnsets,
          'soundingNoteOnsets',
          'onset timestamps must be nondecreasing in event order',
        );
      }
    }
    return PolychordOnsetTrackingFrame._(
      trackerEpoch: trackerEpoch,
      afterEventIndex: afterEventIndex,
      timestampMs: timestampMs,
      pedalDown: pedalDown,
      soundingNoteOnsets: notes,
    );
  }

  const PolychordOnsetTrackingFrame._({
    required this.trackerEpoch,
    required this.afterEventIndex,
    required this.timestampMs,
    required this.pedalDown,
    required this.soundingNoteOnsets,
  });

  /// Reset-delimited stream epoch in which event indices are meaningful.
  final int trackerEpoch;

  /// Zero-based order of the event within the current tracker epoch.
  final int afterEventIndex;

  /// Monotonic elapsed timestamp of the event.
  final int timestampMs;

  /// Whether the sustain pedal is down after the event.
  final bool pedalDown;

  /// Every sounding note in ascending MIDI order, with state and onset origin.
  final List<PolychordSoundingNoteOnset> soundingNoteOnsets;

  List<int> get pressedMidiNotes => List<int>.unmodifiable(
    soundingNoteOnsets
        .where((note) => note.soundingState == PolychordSoundingState.pressed)
        .map((note) => note.midiNote),
  );

  List<int> get sustainedMidiNotes => List<int>.unmodifiable(
    soundingNoteOnsets
        .where((note) => note.soundingState == PolychordSoundingState.sustained)
        .map((note) => note.midiNote),
  );

  List<int> get soundingMidiNotes =>
      List<int>.unmodifiable(soundingNoteOnsets.map((note) => note.midiNote));

  Map<String, Object> toJson() => <String, Object>{
    'trackerEpoch': trackerEpoch,
    'afterEventIndex': afterEventIndex,
    'timestampMs': timestampMs,
    'pressedMidiNotes': pressedMidiNotes,
    'sustainedMidiNotes': sustainedMidiNotes,
    'soundingMidiNotes': soundingMidiNotes,
    'pedalDown': pedalDown,
    'onsetNotes': [for (final note in soundingNoteOnsets) note.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordOnsetTrackingFrame &&
          other.trackerEpoch == trackerEpoch &&
          other.afterEventIndex == afterEventIndex &&
          other.timestampMs == timestampMs &&
          other.pedalDown == pedalDown &&
          _onsetListEquality.equals(
            other.soundingNoteOnsets,
            soundingNoteOnsets,
          );

  @override
  int get hashCode => Object.hash(
    trackerEpoch,
    afterEventIndex,
    timestampMs,
    pedalDown,
    _onsetListEquality.hash(soundingNoteOnsets),
  );
}

const _maximumExactJsonInteger = 9007199254740991;
const _onsetListEquality = ListEquality<PolychordSoundingNoteOnset>();

void _checkExactNonnegativeInteger(int value, String name) {
  if (value < 0 || value > _maximumExactJsonInteger) {
    throw RangeError.range(value, 0, _maximumExactJsonInteger, name);
  }
}
