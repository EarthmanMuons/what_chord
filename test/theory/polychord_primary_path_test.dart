import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/midi/midi_input_source.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class _NotesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void add(int note) => state = {...state, note};
}

final _notesProvider = NotifierProvider<_NotesNotifier, Set<int>>(
  _NotesNotifier.new,
);

class _StubDemoModeNotifier extends DemoModeNotifier {
  @override
  bool build() => false;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'raw primary availability matures in parallel, not as a second gate',
    () async {
      final temporalEvents = StreamController<InputTemporalEvent>.broadcast(
        sync: true,
      );
      var nowMs = 0;
      SharedPreferences.setMockInitialValues(const {});
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          inputEventClockProvider.overrideWithValue(() => nowMs),
          inputTemporalEventsProvider.overrideWith(
            (ref) => temporalEvents.stream,
          ),
          midiSoundingNoteNumbersProvider.overrideWith(
            (ref) => ref.watch(_notesProvider),
          ),
          demoModeProvider.overrideWith(_StubDemoModeNotifier.new),
          demoSoundingNoteNumbersProvider.overrideWithValue(const {}),
        ],
      );
      addTearDown(temporalEvents.close);
      addTearDown(container.dispose);
      final subscription = container.listen(
        polychordProductObservationProvider,
        (previous, next) {},
      );
      addTearDown(subscription.close);

      Future<void> noteOn(int note, int timestampMs) async {
        nowMs = timestampMs;
        container.read(_notesProvider.notifier).add(note);
        temporalEvents.add(
          InputTemporalNoteOnEvent(
            timestampMs: timestampMs,
            noteNumber: note,
            velocity: 80,
          ),
        );
        await pumpEventQueue();
      }

      for (final note in [43, 46, 50]) {
        await noteOn(note, 0);
      }
      expect(container.read(polychordPrimaryDisplayableProvider), isTrue);

      for (final note in [60, 64, 67]) {
        await noteOn(note, 80);
      }

      final observation = container.read(polychordProductObservationProvider)!;
      expect(observation.rawDecision?.selected?.symbol, 'C|Gm');
      expect(observation.display.state, PolychordProductDisplayState.pending);
      expect(
        observation.display.deadlineMs,
        280,
        reason: 'the raw primary path must not add another 200 ms interval',
      );
    },
  );
}
