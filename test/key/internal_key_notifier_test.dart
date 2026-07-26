import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/history/history.dart';
import 'package:whatchord_app/features/key/key.dart';
import 'package:whatchord_app/features/midi/midi_input_source.dart';
import 'package:whatchord_app/features/theory/theory.dart';

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

/// A G major cadence, deliberately authored under a C major tonality so the
/// relabel has a disagreement to correct.
List<ChordEvent> _gCadence() => [
  _event(0, [7, 11, 2], ChordQuality.major),
  _event(1, [0, 4, 7], ChordQuality.major),
  _event(2, [2, 6, 9, 0], ChordQuality.dominant7),
  _event(3, [7, 11, 2], ChordQuality.major),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> setUpContainer() async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        // Sever the live MIDI chain so the capture providers never reach the
        // real device manager; events are recorded directly in these tests.
        midiSoundingNoteNumbersProvider.overrideWith((ref) => const <int>{}),
      ],
    );
    addTearDown(container.dispose);
    container.listen(internalKeyCoordinatorProvider, (_, _) {});
    container.listen(inferredKeyProvider, (_, _) {});
    return container;
  }

  void record(ProviderContainer container, Iterable<ChordEvent> events) {
    final history = container.read(chordHistoryProvider.notifier);
    events.forEach(history.record);
  }

  Future<void> flushMicrotasks() => Future<void>.delayed(Duration.zero);

  test('claims independently of the display behavior preset', () async {
    final container = await setUpContainer();
    record(container, _gCadence());
    expect(container.read(internalKeyProvider).claim, isNotNull);

    // Switching the display preset away from the default rebuilds the
    // display detector but must leave the pinned internal detector untouched.
    expect(container.read(keyBehaviorProvider), isNot(KeyBehavior.stable));
    await container
        .read(keyBehaviorProvider.notifier)
        .setBehavior(KeyBehavior.stable);
    expect(
      container.read(inferredKeyProvider).freshness,
      InferredKeyFreshness.none,
    );
    final internal = container.read(internalKeyProvider);
    expect(internal.freshness, InferredKeyFreshness.fresh);
    expect(internal.claim, isNotNull);
  });

  test('relabels the previous entry under the moved claim, one deep', () async {
    final container = await setUpContainer();
    record(container, _gCadence());
    await flushMicrotasks();

    final claim = container.read(internalKeyProvider).lastClaim;
    expect(claim, isNotNull);
    final history = container.read(chordHistoryProvider);
    expect(history, hasLength(4));

    // The entry before the newest was re-ranked under the claim: its
    // recorded tonality follows, and the candidates are a real re-analysis
    // (D7 keeps its root under any nearby key).
    final relabeled = history[2];
    expect(relabeled.tonality, claim!.tonality);
    expect(relabeled.candidates.first.identity.rootPc, 2);

    // One event deep: entries that never sat second-from-last while a claim
    // stood keep their original tonality (warmup covered the first arrivals).
    expect(history[0].tonality, _cMajorTonality);
    // The newest entry is never touched.
    expect(history[3].tonality, _cMajorTonality);
  });

  test('relabel is record-only: detectors are not re-fed', () async {
    final container = await setUpContainer();
    record(container, _gCadence());
    final before = container.read(inferredKeyProvider);
    await flushMicrotasks();

    // The history write happened (relabel applied) without the display
    // detector observing another event.
    expect(
      container.read(chordHistoryProvider)[2].tonality,
      isNot(_cMajorTonality),
    );
    final after = container.read(inferredKeyProvider);
    expect(identical(before.ranked, after.ranked), isTrue);
    expect(after.lastEventAt, before.lastEventAt);
  });

  test('naming tonality follows the claim only in auto key mode', () async {
    final container = await setUpContainer();
    record(container, _gCadence());
    await flushMicrotasks();

    // Manual mode (the default): live naming stays with the user's key.
    expect(container.read(ensembleNamingTonalityProvider), isNull);

    await container.read(keyModeProvider.notifier).setMode(KeyMode.auto);
    await flushMicrotasks();
    expect(
      container.read(ensembleNamingTonalityProvider),
      container.read(internalKeyProvider).lastClaim!.tonality,
    );

    await container.read(keyModeProvider.notifier).setMode(KeyMode.manual);
    await flushMicrotasks();
    expect(container.read(ensembleNamingTonalityProvider), isNull);
  });

  test('replace is a no-op once the original event is gone', () async {
    final container = await setUpContainer();
    record(container, _gCadence());
    final original = container.read(chordHistoryProvider)[1];
    container.read(chordHistoryProvider.notifier).clear();
    record(container, [
      _event(9, [0, 4, 7], ChordQuality.major),
    ]);

    container.read(chordHistoryProvider.notifier).replace(original, original);
    expect(container.read(chordHistoryProvider), hasLength(1));
  });
}
