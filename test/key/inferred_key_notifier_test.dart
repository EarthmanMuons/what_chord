import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/history/history.dart';
import 'package:whatchord_app/features/key/key.dart';
import 'package:whatchord_app/features/midi/midi_input_source.dart';

const _cMajorTonality = Tonality(Tonic.c, TonalityMode.major);

ChordEvent _event(int index, List<int> pcs, ChordQuality quality) {
  var mask = 0;
  for (final pc in pcs) {
    mask |= 1 << (pc % 12);
  }
  return ChordEvent(
    timestamp: DateTime.fromMillisecondsSinceEpoch(index * 2000),
    input: ChordInput(
      pcMask: mask,
      bassPc: pcs.first % 12,
      noteCount: pcs.length,
    ),
    voicing: ObservedVoicing.fromMidi([for (final pc in pcs) 60 + pc]),
    candidates: [
      ChordCandidate(
        identity: ChordIdentity(
          rootPc: pcs.first % 12,
          bassPc: pcs.first % 12,
          quality: quality,
          presentIntervalsMask: 1,
        ),
        cost: 0,
      ),
    ],
    tonality: _cMajorTonality,
    duration: const Duration(seconds: 2),
  );
}

List<ChordEvent> _cCadence() => [
  _event(0, [0, 4, 7], ChordQuality.major),
  _event(1, [5, 9, 0], ChordQuality.major),
  _event(2, [7, 11, 2, 5], ChordQuality.dominant7),
  _event(3, [0, 4, 7], ChordQuality.major),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, InferredKeyNotifier)> setUpContainer({
    Duration staleAfter = const Duration(seconds: 30),
    Duration resetAfter = const Duration(minutes: 2),
  }) async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Sever the live MIDI chain so the capture providers never reach the
        // real device manager; events are recorded directly in these tests.
        midiSoundingNoteNumbersProvider.overrideWith((ref) => const <int>{}),
        inferredKeyStaleAfterProvider.overrideWithValue(staleAfter),
        inferredKeyResetAfterProvider.overrideWithValue(resetAfter),
      ],
    );
    addTearDown(container.dispose);
    container.listen(inferredKeyProvider, (_, _) {});
    return (container, container.read(inferredKeyProvider.notifier));
  }

  void record(ProviderContainer container, Iterable<ChordEvent> events) {
    final history = container.read(chordHistoryProvider.notifier);
    events.forEach(history.record);
  }

  test('claims the key from committed history events', () async {
    final (container, _) = await setUpContainer();
    record(container, _cCadence());

    final state = container.read(inferredKeyProvider);
    expect(state.freshness, InferredKeyFreshness.fresh);
    expect(state.ranked, hasLength(24));
    expect(state.claim, isNotNull);
    expect(state.claim!.tonality.tonicPitchClass, 0);
    expect(state.claim!.tonality.isMajor, isTrue);
    expect(state.displayKey, state.claim);
    expect(state.emphasized, isTrue);
  });

  test('shows no key while the margin gate abstains', () async {
    // The shipped warmup gate is one event; the margin floor is the real
    // gate (whatkey-local log 2026-07-26-15), so a maximally ambiguous
    // cluster keeps the display empty.
    final (container, _) = await setUpContainer();
    record(container, [
      _event(0, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], ChordQuality.major),
    ]);

    final state = container.read(inferredKeyProvider);
    expect(state.freshness, InferredKeyFreshness.fresh);
    expect(state.claim, isNull);
    expect(state.lastClaim, isNull);
    expect(state.displayKey, isNull);
    expect(state.emphasized, isFalse);
  });

  test(
    'dims after the stale window and forgets after the reset window',
    () async {
      final (container, _) = await setUpContainer(
        staleAfter: const Duration(milliseconds: 40),
        resetAfter: const Duration(milliseconds: 120),
      );
      record(container, _cCadence());
      expect(container.read(inferredKeyProvider).emphasized, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 70));
      var state = container.read(inferredKeyProvider);
      expect(state.freshness, InferredKeyFreshness.stale);
      expect(state.displayKey, isNotNull);
      expect(state.emphasized, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 100));
      state = container.read(inferredKeyProvider);
      expect(state.freshness, InferredKeyFreshness.none);
      expect(state.displayKey, isNull);
      expect(state.ranked, isEmpty);
    },
  );

  test('a new event within the windows keeps the state fresh', () async {
    final (container, _) = await setUpContainer(
      staleAfter: const Duration(milliseconds: 80),
      resetAfter: const Duration(seconds: 10),
    );
    record(container, _cCadence());
    await Future<void>.delayed(const Duration(milliseconds: 50));
    record(container, [
      _event(4, [0, 4, 7], ChordQuality.major),
    ]);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(
      container.read(inferredKeyProvider).freshness,
      InferredKeyFreshness.fresh,
    );
  });

  test('reset after silence restarts the detector warmup', () async {
    final (container, _) = await setUpContainer(
      staleAfter: const Duration(milliseconds: 20),
      resetAfter: const Duration(milliseconds: 40),
    );
    record(container, _cCadence());
    await Future<void>.delayed(const Duration(milliseconds: 80));
    expect(
      container.read(inferredKeyProvider).freshness,
      InferredKeyFreshness.none,
    );

    // An ambiguous event after the reset must not surface any key: the
    // pre-reset claim was truly discarded, and the fresh posterior alone
    // cannot clear the margin on a cluster.
    record(container, [
      _event(9, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], ChordQuality.major),
    ]);
    final state = container.read(inferredKeyProvider);
    expect(state.freshness, InferredKeyFreshness.fresh);
    expect(state.claim, isNull);
    expect(state.lastClaim, isNull);
  });

  test('clearing history resets the inferred key', () async {
    final (container, _) = await setUpContainer();
    record(container, _cCadence());
    expect(container.read(inferredKeyProvider).claim, isNotNull);

    container.read(chordHistoryProvider.notifier).clear();
    final state = container.read(inferredKeyProvider);
    expect(state.freshness, InferredKeyFreshness.none);
    expect(state.displayKey, isNull);
  });

  test('retains the last claim through a later abstention', () async {
    final (container, notifier) = await setUpContainer();
    record(container, _cCadence());
    final claimed = container.read(inferredKeyProvider).claim;
    expect(claimed, isNotNull);

    // A maximally ambiguous cluster drives the posterior margin down; even if
    // the detector abstains, the display keeps the last claim (dimmed).
    record(container, [
      for (var i = 4; i < 10; i++)
        _event(i, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], ChordQuality.major),
    ]);
    final state = container.read(inferredKeyProvider);
    expect(state.lastClaim, isNotNull);
    expect(state.displayKey, isNotNull);

    notifier.reset();
    expect(container.read(inferredKeyProvider).lastClaim, isNull);
  });

  test('switching the behavior preset restarts detection', () async {
    final (container, _) = await setUpContainer();
    record(container, _cCadence());
    expect(container.read(inferredKeyProvider).claim, isNotNull);

    await container
        .read(keyBehaviorProvider.notifier)
        .setBehavior(KeyBehavior.reactive);

    var state = container.read(inferredKeyProvider);
    expect(state.freshness, InferredKeyFreshness.none);
    expect(state.displayKey, isNull);
    // The rebuild marks a reset so stale recent chords drop from the display.
    expect(state.resetAt, isNotNull);

    // The fresh detector heard none of the history: an ambiguous event
    // yields no claim and no retained key from before the switch.
    record(container, [
      _event(9, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], ChordQuality.major),
    ]);
    state = container.read(inferredKeyProvider);
    expect(state.freshness, InferredKeyFreshness.fresh);
    expect(state.claim, isNull);
    expect(state.lastClaim, isNull);
  });
}
