import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/history/history.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/midi/midi_input_source.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class _NotesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void set(Set<int> notes) => state = notes;
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

  test('secondary polychords never create or segment history events', () async {
    final temporalEvents = StreamController<InputTemporalEvent>.broadcast(
      sync: true,
    );
    var productNowMs = 0;
    var historyNow = DateTime(2026, 8, 14, 12);
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        historyClockProvider.overrideWithValue(() => historyNow),
        inputEventClockProvider.overrideWithValue(() => productNowMs),
        inputTemporalEventsProvider.overrideWith(
          (ref) => temporalEvents.stream,
        ),
        polychordPrimaryDisplayableProvider.overrideWithValue(true),
        midiSoundingNoteNumbersProvider.overrideWith(
          (ref) => ref.watch(_notesProvider),
        ),
        demoModeProvider.overrideWith(_StubDemoModeNotifier.new),
        demoSoundingNoteNumbersProvider.overrideWithValue(const {}),
      ],
    );
    addTearDown(temporalEvents.close);
    addTearDown(container.dispose);
    final historySubscription = container.listen(
      chordHistoryProvider,
      (previous, next) {},
    );
    final productSubscription = container.listen(
      polychordProductObservationProvider,
      (previous, next) {},
    );
    addTearDown(historySubscription.close);
    addTearDown(productSubscription.close);

    const sounding = {43, 46, 50, 60, 64, 67};
    container.read(_notesProvider.notifier).set(sounding);
    for (final note in [43, 46, 50]) {
      temporalEvents.add(
        InputTemporalNoteOnEvent(
          timestampMs: 0,
          noteNumber: note,
          velocity: 80,
        ),
      );
    }
    productNowMs = 80;
    for (final note in [60, 64, 67]) {
      temporalEvents.add(
        InputTemporalNoteOnEvent(
          timestampMs: 80,
          noteNumber: note,
          velocity: 80,
        ),
      );
    }
    productNowMs = 280;
    temporalEvents.add(InputTemporalPedalEvent(timestampMs: 280, down: true));
    await pumpEventQueue();

    expect(
      container
          .read(polychordProductObservationProvider)
          ?.displayedCandidate
          ?.symbol,
      'C|Gm',
    );
    expect(container.read(chordHistoryProvider), isEmpty);

    historyNow = historyNow.add(const Duration(seconds: 1));
    container.read(_notesProvider.notifier).set(const {});
    await pumpEventQueue();

    final history = container.read(chordHistoryProvider);
    expect(history, hasLength(1));
    expect(history.single.duration, const Duration(seconds: 1));
    expect(history.single.voicing.midiNotes.toSet(), sounding);
  });
}
