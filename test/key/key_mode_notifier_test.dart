import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/history/history.dart';
import 'package:whatchord_app/features/key/key.dart';
import 'package:whatchord_app/features/midi/midi_input_source.dart';
import 'package:whatchord_app/features/theory/theory.dart';

const _cMajorTonality = Tonality(Tonic.c, TonalityMode.major);
const _aMinorTonality = Tonality(Tonic.a, TonalityMode.minor);

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

/// Enough G major evidence to establish a confident claim streak.
List<ChordEvent> _gMajorPhrase([int start = 0]) => [
  for (var i = 0; i < 8; i++)
    _event(
      start + i,
      [
        [7, 11, 2],
        [0, 4, 7],
        [2, 6, 9, 0],
        [7, 11, 2],
      ][i % 4],
      i % 4 == 2 ? ChordQuality.dominant7 : ChordQuality.major,
    ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> makeContainer([
    Map<String, Object> initial = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(initial);
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
    container.listen(inferredKeyProvider, (_, _) {});
    container.listen(keyModeProvider, (_, _) {});
    return container;
  }

  void record(ProviderContainer container, Iterable<ChordEvent> events) {
    final history = container.read(chordHistoryProvider.notifier);
    events.forEach(history.record);
  }

  test('defaults to manual and restores a persisted auto mode', () async {
    final manual = await makeContainer();
    expect(manual.read(keyModeProvider), KeyMode.manual);

    final auto = await makeContainer({'key.autoModeEnabled': true});
    expect(auto.read(keyModeProvider), KeyMode.auto);
  });

  test('manual mode never writes the tonality back', () async {
    final container = await makeContainer();
    record(container, _gMajorPhrase());
    expect(container.read(inferredKeyProvider).claim, isNotNull);
    expect(container.read(selectedTonalityProvider), _cMajorTonality);
  });

  test('auto mode adopts a persistent claim into the tonality', () async {
    final container = await makeContainer({'key.autoModeEnabled': true});
    record(container, _gMajorPhrase());
    // Adoption lands a microtask after the claim (see KeyModeNotifier._adopt).
    await pumpEventQueue();

    final selected = container.read(selectedTonalityProvider);
    expect(selected.tonic, Tonic.g);
    expect(selected.mode, TonalityMode.major);
    expect(container.read(keyModeProvider), KeyMode.auto);
  });

  test('enabling auto adopts an already standing fresh claim', () async {
    final container = await makeContainer();
    record(container, _gMajorPhrase());
    expect(container.read(selectedTonalityProvider), _cMajorTonality);

    await container.read(keyModeProvider.notifier).setMode(KeyMode.auto);
    expect(container.read(selectedTonalityProvider).tonic, Tonic.g);
    expect(
      container.read(sharedPreferencesProvider).getBool('key.autoModeEnabled'),
      isTrue,
    );
  });

  test('a manual tonality change while auto drops back to manual', () async {
    final container = await makeContainer({'key.autoModeEnabled': true});
    record(container, _gMajorPhrase());
    expect(container.read(keyModeProvider), KeyMode.auto);

    await container
        .read(selectedTonalityProvider.notifier)
        .setTonality(_aMinorTonality);
    expect(container.read(keyModeProvider), KeyMode.manual);
    expect(container.read(selectedTonalityProvider), _aMinorTonality);
    expect(
      container.read(sharedPreferencesProvider).getBool('key.autoModeEnabled'),
      isFalse,
    );

    // Later claims must not fight the user's choice.
    record(container, _gMajorPhrase(20));
    expect(container.read(selectedTonalityProvider), _aMinorTonality);
  });

  test('adoption waits for the claim streak', () async {
    final container = await makeContainer({'key.autoModeEnabled': true});
    // The shipped warmup gate is one event, so a clear G major triad claims
    // immediately; a single claiming event is still below the streak
    // threshold of two.
    record(container, [
      _event(0, [7, 11, 2], ChordQuality.major),
    ]);
    await pumpEventQueue();
    expect(container.read(inferredKeyProvider).claim, isNotNull);
    expect(container.read(selectedTonalityProvider), _cMajorTonality);

    record(container, [
      _event(1, [7, 11, 2], ChordQuality.major),
    ]);
    // Adoption lands a microtask after the claim (see KeyModeNotifier._adopt).
    await pumpEventQueue();
    expect(container.read(selectedTonalityProvider).tonic, Tonic.g);
  });
}
