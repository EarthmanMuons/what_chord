import 'package:meta/meta.dart';

/// One normalized event available to temporal polychord evidence trackers.
///
/// Timestamps are monotonic elapsed milliseconds. Array or delivery order is
/// authoritative when several events share a timestamp.
@immutable
sealed class PolychordTemporalEvent {
  PolychordTemporalEvent({required this.timestampMs}) {
    _checkExactNonnegativeInteger(timestampMs, 'timestampMs');
  }

  final int timestampMs;
}

/// A normalized note-on attack with nonzero velocity.
final class PolychordNoteOnEvent extends PolychordTemporalEvent {
  PolychordNoteOnEvent({
    required super.timestampMs,
    required this.midiNote,
    required this.velocity,
  }) {
    _checkMidiNote(midiNote);
    if (velocity < 1 || velocity > 127) {
      throw RangeError.range(velocity, 1, 127, 'velocity');
    }
  }

  final int midiNote;
  final int velocity;
}

/// A normalized release of one physically pressed note.
final class PolychordNoteOffEvent extends PolychordTemporalEvent {
  PolychordNoteOffEvent({
    required super.timestampMs,
    required this.midiNote,
    required this.velocity,
  }) {
    _checkMidiNote(midiNote);
    if (velocity < 0 || velocity > 127) {
      throw RangeError.range(velocity, 0, 127, 'velocity');
    }
  }

  final int midiNote;
  final int velocity;
}

/// A normalized binary sustain-pedal transition.
final class PolychordSustainPedalEvent extends PolychordTemporalEvent {
  PolychordSustainPedalEvent({required super.timestampMs, required this.down});

  final bool down;
}

const _maximumExactJsonInteger = 9007199254740991;

void _checkExactNonnegativeInteger(int value, String name) {
  if (value < 0 || value > _maximumExactJsonInteger) {
    throw RangeError.range(value, 0, _maximumExactJsonInteger, name);
  }
}

void _checkMidiNote(int midiNote) {
  if (midiNote < 0 || midiNote > 127) {
    throw RangeError.range(midiNote, 0, 127, 'midiNote');
  }
}
