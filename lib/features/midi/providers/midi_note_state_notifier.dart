import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/midi_connection.dart';
import '../models/midi_constants.dart';
import '../models/midi_message.dart';
import '../models/midi_note_state.dart';
import 'midi_connection_notifier.dart';
import 'midi_message_providers.dart';

final midiNoteStateProvider =
    NotifierProvider<MidiNoteStateNotifier, MidiNoteState>(
      MidiNoteStateNotifier.new,
    );

class MidiNoteStateNotifier extends Notifier<MidiNoteState> {
  bool _pedalLatch = false;

  @override
  MidiNoteState build() {
    const initialState = MidiNoteState(
      pressed: {},
      sustained: {},
      isPedalDown: false,
    );

    ref.listen<MidiConnectionPhase>(
      midiConnectionStateProvider.select((s) => s.phase),
      (prev, next) {
        if (prev == MidiConnectionPhase.connected &&
            next != MidiConnectionPhase.connected) {
          state = initialState;
        }
      },
    );

    ref.listen(midiMessageProvider, (previous, next) {
      next.when(
        data: _handleMidiMessage,
        loading: () {},
        error: (error, stack) {
          if (!kReleaseMode) {
            debugPrint('MIDI message error: $error');
          }
        },
      );
    });

    return initialState;
  }

  void _handleMidiMessage(MidiMessage message) {
    switch (message.type) {
      case MidiMessageType.noteOn:
        final note = message.note;
        final velocity = message.velocity ?? 0;
        if (note == null) break;

        if (velocity == 0) {
          noteOff(note);
        } else {
          noteOn(note);
        }
        break;

      case MidiMessageType.noteOff:
        if (message.note != null) {
          noteOff(message.note!);
        }
        break;

      case MidiMessageType.controlChange:
        if (MidiConstants.endsAllNotes(message.ccNumber)) {
          allNotesOff();
        } else if (message.ccNumber == MidiConstants.ccSustainPedal &&
            message.ccValue != null) {
          handlePedalValue(message.ccValue!);
        }
        break;

      default:
        break;
    }
  }

  void noteOn(int midiNote) {
    final nextPressed = {...state.pressed, midiNote};
    final nextSustained = {...state.sustained}..remove(midiNote);
    state = state.copyWith(pressed: nextPressed, sustained: nextSustained);
  }

  void noteOff(int midiNote) {
    final nextPressed = {...state.pressed}..remove(midiNote);

    if (state.isPedalDown) {
      final nextSustained = {...state.sustained, midiNote};
      state = state.copyWith(pressed: nextPressed, sustained: nextSustained);
    } else {
      final nextSustained = {...state.sustained}..remove(midiNote);
      state = state.copyWith(pressed: nextPressed, sustained: nextSustained);
    }
  }

  void allNotesOff() {
    state = state.copyWith(pressed: <int>{}, sustained: <int>{});
  }

  void setPedalDown(bool down) => _setPedalDown(down);

  void setPedalLatch(bool enabled) {
    _pedalLatch = enabled;
  }

  void _setPedalDown(bool down) {
    if (down == state.isPedalDown) return;

    if (!down) {
      // Pedal released: clear all sustained notes.
      state = state.copyWith(isPedalDown: false, sustained: <int>{});
    } else {
      state = state.copyWith(isPedalDown: true);
    }
  }

  void handlePedalValue(int value) {
    final down = value >= MidiConstants.sustainPedalThreshold;
    if (!down && _pedalLatch) return;
    setPedalDown(down);
  }
}

// MIDI note numbers for keyboard highlighting.
final midiSoundingNoteNumbersProvider = Provider<Set<int>>((ref) {
  return ref.watch(midiNoteStateProvider.select((s) => s.soundingNoteNumbers));
});

// Sustain pedal state.
final midiPedalDownProvider = Provider<bool>((ref) {
  return ref.watch(midiNoteStateProvider.select((s) => s.isPedalDown));
});
