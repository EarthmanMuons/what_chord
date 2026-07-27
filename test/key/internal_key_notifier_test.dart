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

    // With the one-event warmup gate a claim already stood at the second
    // arrival, so even the opening entry was relabeled at its moment.
    expect(history[0].tonality, isNot(_cMajorTonality));
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

  test(
    'resolution relabels a flat-nine dominant to the resolving twin',
    () async {
      // The tones B-D-F-Ab are the rootless flat-nine stack shared by four
      // dominants a minor third apart. The record holds the E7(b9) reading;
      // when C major arrives next, G7(b9) is the member that resolves down a
      // fifth, so the relabel promotes it (ensemble-tiebreak log
      // 2026-07-26-07).
      final container = await setUpContainer();
      final tones = [11, 2, 5, 8];
      var mask = 0;
      for (final pc in tones) {
        mask |= 1 << pc;
      }
      final misread = ChordEvent(
        timestamp: DateTime.fromMillisecondsSinceEpoch(0),
        input: ChordInput(pcMask: mask, bassPc: 11, noteCount: tones.length),
        voicing: ObservedVoicing.fromMidi([for (final pc in tones) 60 + pc]),
        candidates: [
          ChordCandidate(
            identity: ChordIdentity(
              rootPc: 4,
              bassPc: 11,
              quality: ChordQuality.dominant7,
              // Even mask: bit zero clear marks the root as implied.
              presentIntervalsMask: 2,
              extensions: {ChordExtension.flat9},
            ),
            cost: 0,
          ),
        ],
        tonality: _cMajorTonality,
        playingContext: PlayingContext.ensemble,
        duration: const Duration(seconds: 2),
      );
      record(container, [misread]);
      record(container, [
        _event(1, [0, 4, 7], ChordQuality.major),
      ]);
      await flushMicrotasks();

      final relabeled = container.read(chordHistoryProvider)[0];
      expect(relabeled.identity.rootPc, 7);
      expect(relabeled.identity.quality.isDominantFamily, isTrue);
      expect(relabeled.identity.hasImpliedRoot, isTrue);
      // The newest entry is never touched.
      expect(container.read(chordHistoryProvider)[1].identity.rootPc, 0);
    },
  );

  test('a natural-color dominant is not resolution-relabeled', () async {
    // Without the flat-nine stack the minor-third re-rooting is not
    // tone-identical, so the rule must not fire.
    final container = await setUpContainer();
    final natural = ChordEvent(
      timestamp: DateTime.fromMillisecondsSinceEpoch(0),
      input: ChordInput(
        pcMask: (1 << 4) | (1 << 10) | (1 << 2),
        bassPc: 4,
        noteCount: 3,
      ),
      voicing: ObservedVoicing.fromMidi([64, 70, 74]),
      candidates: [
        ChordCandidate(
          identity: ChordIdentity(
            rootPc: 4,
            bassPc: 4,
            quality: ChordQuality.dominant7,
            presentIntervalsMask: 2,
            extensions: {ChordExtension.nine},
          ),
          cost: 0,
        ),
      ],
      tonality: _cMajorTonality,
      playingContext: PlayingContext.ensemble,
      duration: const Duration(seconds: 2),
    );
    record(container, [natural]);
    record(container, [
      _event(1, [0, 4, 7], ChordQuality.major),
    ]);
    await flushMicrotasks();

    expect(container.read(chordHistoryProvider)[0].identity.rootPc, 4);
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
