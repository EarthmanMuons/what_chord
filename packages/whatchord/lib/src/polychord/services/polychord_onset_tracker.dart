import '../models/polychord_onset_evidence.dart';
import '../models/polychord_onset_tracking_frame.dart';
import '../models/polychord_temporal_event.dart';

/// Tracks currently sounding note instances and their most recent attacks.
///
/// This pure state machine follows `polychord-frame-replay/1` note and sustain
/// semantics. It does not generate candidates, interpret timing, or select a
/// display. [reset] is an administrative stream boundary rather than a
/// fabricated MIDI event.
final class PolychordOnsetTracker {
  factory PolychordOnsetTracker({
    Iterable<int> initiallyPressedMidiNotes = const [],
    Iterable<int> initiallySustainedMidiNotes = const [],
    bool initiallyPedalDown = false,
  }) {
    final state = _InitialState.validate(
      pressedMidiNotes: initiallyPressedMidiNotes,
      sustainedMidiNotes: initiallySustainedMidiNotes,
      pedalDown: initiallyPedalDown,
    );
    return PolychordOnsetTracker._().._setInitialState(state);
  }

  PolychordOnsetTracker._();

  final Map<int, PolychordOnsetOrigin?> _pressed = {};
  final Map<int, PolychordOnsetOrigin?> _sustained = {};
  bool _pedalDown = false;
  int _trackerEpoch = 0;
  int _nextEventIndex = 0;
  int? _lastTimestampMs;

  /// Whether the sustain pedal is currently down.
  bool get pedalDown => _pedalDown;

  /// Index that the next successful event will receive.
  int get nextEventIndex => _nextEventIndex;

  /// Reset-delimited epoch in which [nextEventIndex] is meaningful.
  int get trackerEpoch => _trackerEpoch;

  /// Current sounding-note facts in ascending MIDI order.
  List<PolychordSoundingNoteOnset> get soundingNoteOnsets =>
      List<PolychordSoundingNoteOnset>.unmodifiable(_soundingNoteOnsets());

  /// Applies one event atomically and returns the resulting immutable frame.
  PolychordOnsetTrackingFrame step(PolychordTemporalEvent event) {
    if (_nextEventIndex > _maximumExactJsonInteger) {
      throw StateError('event index exceeds the exact JSON integer range');
    }
    final previousTimestamp = _lastTimestampMs;
    if (previousTimestamp != null && event.timestampMs < previousTimestamp) {
      throw ArgumentError.value(
        event.timestampMs,
        'event.timestampMs',
        'must be nondecreasing',
      );
    }

    switch (event) {
      case PolychordNoteOnEvent():
        if (_pressed.containsKey(event.midiNote)) {
          throw StateError(
            'noteOn repeats physically pressed note ${event.midiNote}',
          );
        }
      case PolychordNoteOffEvent():
        if (!_pressed.containsKey(event.midiNote)) {
          throw StateError(
            'noteOff releases note ${event.midiNote}, which is not pressed',
          );
        }
      case PolychordSustainPedalEvent():
        if (event.down == _pedalDown) {
          throw StateError('pedal event repeats the current state');
        }
    }

    final eventIndex = _nextEventIndex;
    switch (event) {
      case PolychordNoteOnEvent():
        _sustained.remove(event.midiNote);
        _pressed[event.midiNote] = PolychordOnsetOrigin(
          eventIndex: eventIndex,
          timestampMs: event.timestampMs,
          velocity: event.velocity,
        );
      case PolychordNoteOffEvent():
        final origin = _pressed.remove(event.midiNote);
        if (_pedalDown) _sustained[event.midiNote] = origin;
      case PolychordSustainPedalEvent():
        _pedalDown = event.down;
        if (!event.down) _sustained.clear();
    }
    _lastTimestampMs = event.timestampMs;
    _nextEventIndex++;

    return PolychordOnsetTrackingFrame(
      trackerEpoch: _trackerEpoch,
      afterEventIndex: eventIndex,
      timestampMs: event.timestampMs,
      pedalDown: _pedalDown,
      soundingNoteOnsets: _soundingNoteOnsets(),
    );
  }

  /// Clears history and optionally establishes unknown carried-in notes.
  ///
  /// The next successful event starts a new epoch at index zero and may use any
  /// nonnegative timestamp.
  void reset({
    Iterable<int> initiallyPressedMidiNotes = const [],
    Iterable<int> initiallySustainedMidiNotes = const [],
    bool initiallyPedalDown = false,
  }) {
    final state = _InitialState.validate(
      pressedMidiNotes: initiallyPressedMidiNotes,
      sustainedMidiNotes: initiallySustainedMidiNotes,
      pedalDown: initiallyPedalDown,
    );
    if (_trackerEpoch >= _maximumExactJsonInteger) {
      throw StateError('tracker epoch exceeds the exact JSON integer range');
    }
    _trackerEpoch++;
    _setInitialState(state);
  }

  List<PolychordSoundingNoteOnset> _soundingNoteOnsets() {
    final midiNotes = {..._pressed.keys, ..._sustained.keys}.toList()..sort();
    return [
      for (final midiNote in midiNotes)
        PolychordSoundingNoteOnset(
          midiNote: midiNote,
          soundingState: _pressed.containsKey(midiNote)
              ? PolychordSoundingState.pressed
              : PolychordSoundingState.sustained,
          origin: _pressed.containsKey(midiNote)
              ? _pressed[midiNote]
              : _sustained[midiNote],
        ),
    ];
  }

  void _setInitialState(_InitialState state) {
    _pressed
      ..clear()
      ..addEntries(state.pressedMidiNotes.map((note) => MapEntry(note, null)));
    _sustained
      ..clear()
      ..addEntries(
        state.sustainedMidiNotes.map((note) => MapEntry(note, null)),
      );
    _pedalDown = state.pedalDown;
    _nextEventIndex = 0;
    _lastTimestampMs = null;
  }
}

const _maximumExactJsonInteger = 9007199254740991;

final class _InitialState {
  const _InitialState({
    required this.pressedMidiNotes,
    required this.sustainedMidiNotes,
    required this.pedalDown,
  });

  factory _InitialState.validate({
    required Iterable<int> pressedMidiNotes,
    required Iterable<int> sustainedMidiNotes,
    required bool pedalDown,
  }) {
    final pressed = _validateMidiNotes(
      pressedMidiNotes,
      'initiallyPressedMidiNotes',
    );
    final sustained = _validateMidiNotes(
      sustainedMidiNotes,
      'initiallySustainedMidiNotes',
    );
    final overlap = pressed.toSet().intersection(sustained.toSet());
    if (overlap.isNotEmpty) {
      throw ArgumentError.value(
        overlap.toList()..sort(),
        'initiallyPressedMidiNotes/initiallySustainedMidiNotes',
        'must be disjoint',
      );
    }
    if (sustained.isNotEmpty && !pedalDown) {
      throw ArgumentError.value(
        sustained,
        'initiallySustainedMidiNotes',
        'requires initiallyPedalDown',
      );
    }
    return _InitialState(
      pressedMidiNotes: pressed,
      sustainedMidiNotes: sustained,
      pedalDown: pedalDown,
    );
  }

  final List<int> pressedMidiNotes;
  final List<int> sustainedMidiNotes;
  final bool pedalDown;
}

List<int> _validateMidiNotes(Iterable<int> midiNotes, String name) {
  final notes = List<int>.of(midiNotes);
  for (final note in notes) {
    if (note < 0 || note > 127) {
      throw RangeError.range(note, 0, 127, name);
    }
  }
  if (notes.toSet().length != notes.length) {
    throw ArgumentError.value(notes, name, 'must not contain duplicates');
  }
  notes.sort();
  return List<int>.unmodifiable(notes);
}
