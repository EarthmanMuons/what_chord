import 'package:flutter/foundation.dart';

/// Exact input state carried across a temporal-stream reset.
@immutable
final class InputTemporalSnapshot {
  InputTemporalSnapshot({
    Iterable<int> pressedNoteNumbers = const [],
    Iterable<int> sustainedNoteNumbers = const [],
    required this.pedalDown,
  }) : pressedNoteNumbers = Set<int>.unmodifiable(pressedNoteNumbers),
       sustainedNoteNumbers = Set<int>.unmodifiable(sustainedNoteNumbers) {
    _validateNotes(this.pressedNoteNumbers, 'pressedNoteNumbers');
    _validateNotes(this.sustainedNoteNumbers, 'sustainedNoteNumbers');
    final overlap = this.pressedNoteNumbers.intersection(
      this.sustainedNoteNumbers,
    );
    if (overlap.isNotEmpty) {
      throw ArgumentError.value(
        overlap,
        'pressedNoteNumbers/sustainedNoteNumbers',
        'must be disjoint',
      );
    }
    if (this.sustainedNoteNumbers.isNotEmpty && !pedalDown) {
      throw ArgumentError.value(
        this.sustainedNoteNumbers,
        'sustainedNoteNumbers',
        'requires pedalDown',
      );
    }
  }

  final Set<int> pressedNoteNumbers;
  final Set<int> sustainedNoteNumbers;
  final bool pedalDown;
}

/// One normalized, monotonically timestamped input observation.
@immutable
sealed class InputTemporalEvent {
  InputTemporalEvent({required this.timestampMs}) {
    if (timestampMs < 0 || timestampMs > _maximumExactJsonInteger) {
      throw RangeError.range(
        timestampMs,
        0,
        _maximumExactJsonInteger,
        'timestampMs',
      );
    }
  }

  final int timestampMs;
}

final class InputTemporalNoteOnEvent extends InputTemporalEvent {
  InputTemporalNoteOnEvent({
    required super.timestampMs,
    required this.noteNumber,
    required this.velocity,
  }) {
    _validateNote(noteNumber, 'noteNumber');
    if (velocity < 1 || velocity > 127) {
      throw RangeError.range(velocity, 1, 127, 'velocity');
    }
  }

  final int noteNumber;
  final int velocity;
}

final class InputTemporalNoteOffEvent extends InputTemporalEvent {
  InputTemporalNoteOffEvent({
    required super.timestampMs,
    required this.noteNumber,
    required this.velocity,
  }) {
    _validateNote(noteNumber, 'noteNumber');
    if (velocity < 0 || velocity > 127) {
      throw RangeError.range(velocity, 0, 127, 'velocity');
    }
  }

  final int noteNumber;
  final int velocity;
}

final class InputTemporalPedalEvent extends InputTemporalEvent {
  InputTemporalPedalEvent({required super.timestampMs, required this.down});

  final bool down;
}

/// Administrative boundary for disconnects, source swaps, and state repairs.
final class InputTemporalResetEvent extends InputTemporalEvent {
  InputTemporalResetEvent({required super.timestampMs, required this.snapshot});

  final InputTemporalSnapshot snapshot;
}

const _maximumExactJsonInteger = 9007199254740991;

void _validateNotes(Iterable<int> notes, String name) {
  for (final note in notes) {
    _validateNote(note, name);
  }
}

void _validateNote(int note, String name) {
  if (note < 0 || note > 127) {
    throw RangeError.range(note, 0, 127, name);
  }
}
