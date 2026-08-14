import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/input/models/input_temporal_event.dart';
import 'package:whatchord_app/features/input/providers/input_event_clock_provider.dart';

import 'demo_note_state_notifier.dart';

/// Converts the authored demo's direct sounding-state changes into ordered
/// events. A reset repairs transitions that cannot be expressed as MIDI
/// releases because the demo intentionally does not simulate pedal sustain.
final demoTemporalEventsProvider =
    Provider.autoDispose<Stream<InputTemporalEvent>>((ref) {
      // Buffer the boundary reset until the selected input stream subscribes,
      // so the initial snapshot and subsequent state events cannot race.
      final controller = StreamController<InputTemporalEvent>(sync: true);
      final clock = ref.watch(inputEventClockProvider);
      var previous = ref.read(demoNoteStateProvider);

      ref.listen<DemoNoteState>(demoNoteStateProvider, (_, next) {
        final turnedOff =
            previous.soundingNoteNumbers
                .difference(next.soundingNoteNumbers)
                .toList()
              ..sort();
        final turnedOn =
            next.soundingNoteNumbers
                .difference(previous.soundingNoteNumbers)
                .toList()
              ..sort();

        if (previous.isPedalDown != next.isPedalDown) {
          controller.add(
            InputTemporalPedalEvent(
              timestampMs: clock(),
              down: next.isPedalDown,
            ),
          );
        }

        if (turnedOff.isNotEmpty && next.isPedalDown) {
          controller.add(
            InputTemporalResetEvent(
              timestampMs: clock(),
              snapshot: InputTemporalSnapshot(
                pressedNoteNumbers: next.soundingNoteNumbers,
                pedalDown: next.isPedalDown,
              ),
            ),
          );
          previous = next;
          return;
        }

        for (final note in turnedOff) {
          controller.add(
            InputTemporalNoteOffEvent(
              timestampMs: clock(),
              noteNumber: note,
              velocity: 0,
            ),
          );
        }
        for (final note in turnedOn) {
          controller.add(
            InputTemporalNoteOnEvent(
              timestampMs: clock(),
              noteNumber: note,
              velocity: 100,
            ),
          );
        }
        previous = next;
      });

      controller.add(
        InputTemporalResetEvent(
          timestampMs: clock(),
          snapshot: InputTemporalSnapshot(
            pressedNoteNumbers: previous.soundingNoteNumbers,
            pedalDown: previous.isPedalDown,
          ),
        ),
      );

      ref.onDispose(() async {
        await controller.close();
      });
      return controller.stream;
    });
