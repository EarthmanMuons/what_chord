import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/input/models/input_temporal_event.dart';
import 'package:whatchord_app/features/input/providers/input_event_clock_provider.dart';

import '../models/midi_connection.dart';
import '../models/midi_constants.dart';
import '../models/midi_message.dart';
import 'midi_connection_notifier.dart';
import 'midi_message_providers.dart';
import 'midi_note_state_notifier.dart';

/// Normalizes the actual adopted MIDI state into the temporal product stream.
final midiTemporalEventsProvider =
    Provider.autoDispose<Stream<InputTemporalEvent>>((ref) {
      // A single-subscription controller buffers the reset until the selected
      // input StreamProvider subscribes. This closes the otherwise possible
      // gap between reading initial state and attaching the raw MIDI listener.
      final controller = StreamController<InputTemporalEvent>(sync: true);
      final clock = ref.watch(inputEventClockProvider);
      final initial = ref.read(midiNoteStateProvider);
      final pressed = <int>{...initial.pressed};
      final sustained = <int>{...initial.sustained};
      var pedalDown = initial.isPedalDown;

      void addReset() {
        final snapshot = ref.read(midiNoteStateProvider);
        pressed
          ..clear()
          ..addAll(snapshot.pressed);
        sustained
          ..clear()
          ..addAll(snapshot.sustained);
        pedalDown = snapshot.isPedalDown;
        controller.add(
          InputTemporalResetEvent(
            timestampMs: clock(),
            snapshot: InputTemporalSnapshot(
              pressedNoteNumbers: pressed,
              sustainedNoteNumbers: sustained,
              pedalDown: pedalDown,
            ),
          ),
        );
      }

      ref.listen<MidiConnectionPhase>(
        midiConnectionStateProvider.select((state) => state.phase),
        (previous, next) {
          if (previous == next) return;
          addReset();
        },
      );

      // Read the adopted pedal state rather than raw CC64 so touch latching and
      // the app's sustain threshold remain exactly aligned with sounding notes.
      ref.listen<bool>(
        midiNoteStateProvider.select((state) => state.isPedalDown),
        (previous, next) {
          if (previous == next || next == pedalDown) return;
          pedalDown = next;
          if (!next) sustained.clear();
          controller.add(
            InputTemporalPedalEvent(timestampMs: clock(), down: next),
          );
        },
      );

      ref.listen(midiMessageProvider, (previous, next) {
        final message = next.asData?.value;
        if (message == null) return;

        if (message.type == MidiMessageType.controlChange &&
            message.ccNumber == MidiConstants.ccAllNotesOff) {
          pressed.clear();
          sustained.clear();
          controller.add(
            InputTemporalResetEvent(
              timestampMs: clock(),
              snapshot: InputTemporalSnapshot(pedalDown: pedalDown),
            ),
          );
          return;
        }

        if (message.type != MidiMessageType.noteOn &&
            message.type != MidiMessageType.noteOff) {
          return;
        }

        final rawNote = message.note;
        if (rawNote == null) return;
        final note = rawNote.clamp(0, 127);
        final velocity = (message.velocity ?? 0).clamp(0, 127);
        final isNoteOn = message.type == MidiMessageType.noteOn && velocity > 0;

        if (isNoteOn) {
          // Repeated note-ons for a physically held key are input no-ops under
          // the normalized contract. A reattack after pedal sustain is valid.
          if (!pressed.add(note)) return;
          sustained.remove(note);
          controller.add(
            InputTemporalNoteOnEvent(
              timestampMs: clock(),
              noteNumber: note,
              velocity: velocity,
            ),
          );
          return;
        }

        if (!pressed.remove(note)) return;
        if (pedalDown) {
          sustained.add(note);
        } else {
          sustained.remove(note);
        }
        controller.add(
          InputTemporalNoteOffEvent(
            timestampMs: clock(),
            noteNumber: note,
            velocity: velocity,
          ),
        );
      });

      controller.add(
        InputTemporalResetEvent(
          timestampMs: clock(),
          snapshot: InputTemporalSnapshot(
            pressedNoteNumbers: pressed,
            sustainedNoteNumbers: sustained,
            pedalDown: pedalDown,
          ),
        ),
      );

      ref.onDispose(() async {
        await controller.close();
      });
      return controller.stream;
    });
