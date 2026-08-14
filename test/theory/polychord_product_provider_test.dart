import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class _PrimaryNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final _primaryProvider = NotifierProvider<_PrimaryNotifier, bool>(
  _PrimaryNotifier.new,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late StreamController<InputTemporalEvent> events;
  late ProviderContainer container;
  late int nowMs;

  setUp(() async {
    events = StreamController<InputTemporalEvent>.broadcast(sync: true);
    nowMs = 0;
    container = ProviderContainer(
      overrides: [
        inputEventClockProvider.overrideWithValue(() => nowMs),
        inputTemporalEventsProvider.overrideWith((ref) => events.stream),
        polychordPrimaryDisplayableProvider.overrideWith(
          (ref) => ref.watch(_primaryProvider),
        ),
      ],
    );
    addTearDown(events.close);
    addTearDown(container.dispose);
    container.read(_primaryProvider.notifier).set(true);
    final subscription = container.listen(
      polychordProductObservationProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    await pumpEventQueue();
  });

  Future<void> add(InputTemporalEvent event) async {
    nowMs = event.timestampMs;
    events.add(event);
    await pumpEventQueue();
  }

  Future<void> addPositiveLayers() async {
    for (final note in [43, 46, 50]) {
      await add(
        InputTemporalNoteOnEvent(
          timestampMs: 0,
          noteNumber: note,
          velocity: 80,
        ),
      );
    }
    for (final note in [60, 64, 67]) {
      await add(
        InputTemporalNoteOnEvent(
          timestampMs: 80,
          noteNumber: note,
          velocity: 80,
        ),
      );
    }
  }

  test('drives the frozen policy to a stable secondary annotation', () async {
    await addPositiveLayers();

    final pending = container.read(polychordProductObservationProvider)!;
    expect(pending.rawDecision?.selected?.symbol, 'C|Gm');
    expect(pending.display.state, PolychordProductDisplayState.pending);
    expect(pending.display.deadlineMs, 280);

    await add(InputTemporalPedalEvent(timestampMs: 280, down: true));

    final visible = container.read(polychordProductObservationProvider)!;
    expect(visible.displayedCandidate?.symbol, 'C|Gm');
    expect(
      visible.display.transition,
      PolychordProductDisplayTransition.appearance,
    );
    expect(visible.toJson()['schema'], PolychordProductObservation.schema);
    expect(visible.candidateRecords, isNotEmpty);
  });

  test('the app timer promotes without another input event', () async {
    await addPositiveLayers();
    nowMs = 280;

    await Future<void>.delayed(const Duration(milliseconds: 230));
    await pumpEventQueue();

    final visible = container.read(polychordProductObservationProvider)!;
    expect(visible.displayedCandidate?.symbol, 'C|Gm');
    expect(
      visible.display.transition,
      PolychordProductDisplayTransition.appearance,
    );
  });

  test(
    'primary availability clears without changing the raw decision',
    () async {
      await addPositiveLayers();
      await add(InputTemporalPedalEvent(timestampMs: 280, down: true));

      nowMs = 300;
      container.read(_primaryProvider.notifier).set(false);
      await pumpEventQueue();

      final cleared = container.read(polychordProductObservationProvider)!;
      expect(cleared.rawDecision?.selected?.symbol, 'C|Gm');
      expect(cleared.authorization?.reasonCode, 'primary-not-displayable');
      expect(cleared.display.state, PolychordProductDisplayState.absent);
      expect(
        cleared.display.transition,
        PolychordProductDisplayTransition.clear,
      );
    },
  );

  test('a source reset clears state and carries no onset authority', () async {
    await addPositiveLayers();
    await add(InputTemporalPedalEvent(timestampMs: 280, down: true));
    await add(
      InputTemporalResetEvent(
        timestampMs: 320,
        snapshot: InputTemporalSnapshot(
          pressedNoteNumbers: const [43, 46, 50, 60, 64, 67],
          pedalDown: true,
        ),
      ),
    );

    final reset = container.read(polychordProductObservationProvider)!;
    expect(reset.frame, isNull);
    expect(reset.candidates, isEmpty);
    expect(reset.display.transition, PolychordProductDisplayTransition.clear);
    expect(reset.display.reasonCode, 'tracker-reset');
  });
}
