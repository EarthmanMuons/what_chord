import '../models/polychord_onset_evidence.dart';
import '../models/polychord_release_pedal_evidence.dart';
import '../models/polychord_temporal_event.dart';

/// Tracks threshold-free release, reattack, note-state, and pedal provenance.
///
/// This pure state machine follows `polychord-release-pedal-evidence/1`. It
/// records causal facts only and does not interpret age, release grouping,
/// sustain use, confidence, eligibility, or display policy.
final class PolychordReleasePedalTracker {
  factory PolychordReleasePedalTracker({
    Iterable<int> initiallyPressedMidiNotes = const [],
    Iterable<int> initiallySustainedMidiNotes = const [],
    bool initiallyPedalDown = false,
  }) {
    final state = _InitialState.validate(
      pressedMidiNotes: initiallyPressedMidiNotes,
      sustainedMidiNotes: initiallySustainedMidiNotes,
      pedalDown: initiallyPedalDown,
    );
    return PolychordReleasePedalTracker._().._setInitialState(state);
  }

  PolychordReleasePedalTracker._();

  final Map<int, PolychordSoundingNoteHistory> _notes = {};
  bool _pedalDown = false;
  PolychordPedalTransition? _pedalTransition;
  int _trackerEpoch = 0;
  int _nextEventIndex = 0;
  int? _lastTimestampMs;

  bool get pedalDown => _pedalDown;
  int get trackerEpoch => _trackerEpoch;
  int get nextEventIndex => _nextEventIndex;

  List<PolychordSoundingNoteHistory> get soundingNoteHistories =>
      List<PolychordSoundingNoteHistory>.unmodifiable(_orderedHistories());

  /// Applies one event atomically and returns the resulting immutable frame.
  PolychordReleasePedalTrackingFrame step(PolychordTemporalEvent event) {
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

    final prior = switch (event) {
      PolychordNoteOnEvent(:final midiNote) => _notes[midiNote],
      PolychordNoteOffEvent(:final midiNote) => _notes[midiNote],
      PolychordSustainPedalEvent() => null,
    };
    switch (event) {
      case PolychordNoteOnEvent():
        if (prior?.soundingState == PolychordSoundingState.pressed) {
          throw StateError(
            'noteOn repeats physically pressed note ${event.midiNote}',
          );
        }
      case PolychordNoteOffEvent():
        if (prior?.soundingState != PolychordSoundingState.pressed) {
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
        final reattacked =
            prior?.soundingState == PolychordSoundingState.sustained;
        final origin = PolychordNoteEventOrigin(
          eventIndex: eventIndex,
          timestampMs: event.timestampMs,
          velocity: event.velocity,
        );
        _notes[event.midiNote] = PolychordSoundingNoteHistory(
          midiNote: event.midiNote,
          soundingState: PolychordSoundingState.pressed,
          onset: origin,
          release: null,
          currentStateSince: origin,
          reattackedFromSustain: reattacked,
          priorSustainRelease: reattacked ? prior?.release : null,
        );
      case PolychordNoteOffEvent():
        if (_pedalDown) {
          final origin = PolychordNoteEventOrigin(
            eventIndex: eventIndex,
            timestampMs: event.timestampMs,
            velocity: event.velocity,
          );
          _notes[event.midiNote] = PolychordSoundingNoteHistory(
            midiNote: event.midiNote,
            soundingState: PolychordSoundingState.sustained,
            onset: prior!.onset,
            release: origin,
            currentStateSince: origin,
            reattackedFromSustain: prior.reattackedFromSustain,
            priorSustainRelease: prior.priorSustainRelease,
          );
        } else {
          _notes.remove(event.midiNote);
        }
      case PolychordSustainPedalEvent():
        _pedalDown = event.down;
        _pedalTransition = PolychordPedalTransition(
          eventIndex: eventIndex,
          timestampMs: event.timestampMs,
          down: event.down,
        );
        if (!event.down) {
          _notes.removeWhere(
            (_, note) => note.soundingState == PolychordSoundingState.sustained,
          );
        }
    }
    _lastTimestampMs = event.timestampMs;
    _nextEventIndex++;

    return PolychordReleasePedalTrackingFrame(
      trackerEpoch: _trackerEpoch,
      afterEventIndex: eventIndex,
      timestampMs: event.timestampMs,
      pedalDown: _pedalDown,
      pedalTransition: _pedalTransition,
      soundingNoteHistories: _orderedHistories(),
    );
  }

  /// Clears history and optionally establishes unknown carried-in state.
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

  List<PolychordSoundingNoteHistory> _orderedHistories() {
    final midiNotes = _notes.keys.toList()..sort();
    return [for (final midiNote in midiNotes) _notes[midiNote]!];
  }

  void _setInitialState(_InitialState state) {
    _notes
      ..clear()
      ..addEntries(
        state.pressedMidiNotes.map(
          (midiNote) => MapEntry(
            midiNote,
            PolychordSoundingNoteHistory(
              midiNote: midiNote,
              soundingState: PolychordSoundingState.pressed,
              onset: null,
              release: null,
              currentStateSince: null,
              reattackedFromSustain: null,
              priorSustainRelease: null,
            ),
          ),
        ),
      )
      ..addEntries(
        state.sustainedMidiNotes.map(
          (midiNote) => MapEntry(
            midiNote,
            PolychordSoundingNoteHistory(
              midiNote: midiNote,
              soundingState: PolychordSoundingState.sustained,
              onset: null,
              release: null,
              currentStateSince: null,
              reattackedFromSustain: null,
              priorSustainRelease: null,
            ),
          ),
        ),
      );
    _pedalDown = state.pedalDown;
    _pedalTransition = null;
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
