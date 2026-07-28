import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/lookup/lookup.dart';
import 'package:whatchord_app/features/midi/midi_input_source.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class _NotesNotifier extends Notifier<Set<int>> {
  @override
  Set<int> build() => const {};

  void set(Set<int> notes) => state = notes;
}

final _midiNotesProvider = NotifierProvider<_NotesNotifier, Set<int>>(
  _NotesNotifier.new,
);

final _demoNotesProvider = NotifierProvider<_NotesNotifier, Set<int>>(
  _NotesNotifier.new,
);

/// Bypasses the real demo notifier's enter/exit side effects; tests only need
/// the mode flag to flip.
class _StubDemoModeNotifier extends DemoModeNotifier {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const cMajor = {60, 64, 67};
  const cMajorDoubled = {60, 64, 67, 76};
  const fMajor = {65, 69, 72};
  const fMajorDoubled = {65, 69, 72, 77};

  late DateTime now;
  DateTime clock() => now;

  Future<ProviderContainer> makeContainer({
    List<Override> overrides = const [],
  }) async {
    now = DateTime(2026, 1, 1, 12);
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        displayedChordClockProvider.overrideWithValue(clock),
        midiSoundingNoteNumbersProvider.overrideWith(
          (ref) => ref.watch(_midiNotesProvider),
        ),
        demoModeProvider.overrideWith(_StubDemoModeNotifier.new),
        demoSoundingNoteNumbersProvider.overrideWith(
          (ref) => ref.watch(_demoNotesProvider),
        ),
        ...overrides,
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      displayedChordProvider,
      (previous, next) {},
    );
    addTearDown(subscription.close);
    return container;
  }

  Future<void> play(ProviderContainer container, Set<int> notes) async {
    container.read(_midiNotesProvider.notifier).set(notes);
    await pumpEventQueue();
  }

  void advance(Duration duration) => now = now.add(duration);

  int? displayedRoot(ProviderContainer container) =>
      container.read(displayedChordProvider)?.identity.rootPc;

  test('a chord displays only after surviving the stability window', () async {
    final container = await makeContainer();

    await play(container, cMajor);
    expect(container.read(displayedChordProvider), isNull);

    // A same-identity revoicing past the window promotes on the next frame.
    advance(const Duration(milliseconds: 250));
    await play(container, cMajorDoubled);
    expect(displayedRoot(container), 0);
  });

  test('the previous chord holds while a challenger proves itself', () async {
    final container = await makeContainer();
    await play(container, cMajor);
    advance(const Duration(milliseconds: 250));
    await play(container, cMajorDoubled);
    expect(displayedRoot(container), 0);

    await play(container, fMajor);
    expect(displayedRoot(container), 0);

    advance(const Duration(milliseconds: 250));
    await play(container, fMajorDoubled);
    expect(displayedRoot(container), 5);
  });

  test('the warmup timer promotes without an input change', () async {
    final container = await makeContainer();
    await play(container, cMajor);
    expect(container.read(displayedChordProvider), isNull);

    advance(const Duration(milliseconds: 250));
    await Future<void>.delayed(const Duration(milliseconds: 260));
    expect(displayedRoot(container), 0);
  });

  test('silence clears the display', () async {
    final container = await makeContainer();
    await play(container, cMajor);
    advance(const Duration(milliseconds: 250));
    await play(container, cMajorDoubled);
    expect(displayedRoot(container), 0);

    await play(container, const <int>{});
    expect(container.read(displayedChordProvider), isNull);
  });

  test('demo playback flows through the gate', () async {
    final container = await makeContainer();
    container.read(demoModeProvider.notifier as dynamic).set(true);
    container.read(_demoNotesProvider.notifier).set(cMajor);
    await pumpEventQueue();
    expect(container.read(displayedChordProvider), isNull);

    advance(const Duration(milliseconds: 250));
    container.read(_demoNotesProvider.notifier).set(cMajorDoubled);
    await pumpEventQueue();
    expect(displayedRoot(container), 0);
  });

  test('the held display bridges the note-dyad-chord warmup', () async {
    final container = await makeContainer();
    final held = container.listen(heldIdentityDisplayProvider, (_, _) {});
    addTearDown(held.close);

    await play(container, {60});
    expect(held.read(), isA<NoteDisplay>());

    await play(container, {60, 64});
    expect(held.read(), isA<IntervalDisplay>());

    // The third note enters chord mode; the interval label holds through the
    // gate's warmup instead of flashing the waiting placeholder.
    await play(container, cMajor);
    expect(held.read(), isA<IntervalDisplay>());

    advance(const Duration(milliseconds: 250));
    await play(container, cMajorDoubled);
    expect(held.read(), isA<ChordDisplay>());

    await play(container, const <int>{});
    expect(held.read(), isNull);
  });

  test('lookup bypasses the gate for instant manual feedback', () async {
    final container = await makeContainer(
      overrides: [lookupModeProvider.overrideWith(_StubLookupNotifier.new)],
    );
    await pumpEventQueue();
    expect(container.read(displayedChordProvider), isNull);
    expect(container.read(displayedBestCandidateProvider)?.identity.rootPc, 0);
  });
}

/// A C major selection on the lookup pad, active from the start.
class _StubLookupNotifier extends LookupModeNotifier {
  @override
  LookupState build() =>
      const LookupState(active: true, pitchClasses: [0, 4, 7]);
}
