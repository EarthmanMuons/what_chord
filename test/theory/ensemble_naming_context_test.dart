import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/theory/theory.dart';

const _gMajor = Tonality(Tonic.g, TonalityMode.major);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<ProviderContainer> setUpContainer() async {
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test(
    'ensemble identity follows the naming tonality, spelling stays',
    () async {
      final container = await setUpContainer();
      final selected = container.read(selectedTonalityProvider);
      final displaySignature = KeySignature.fromTonality(selected);
      expect(selected, isNot(_gMajor));

      await container
          .read(playingContextProvider.notifier)
          .setContext(PlayingContext.ensemble);
      container.read(ensembleNamingTonalityProvider.notifier).set(_gMajor);

      final context = container.read(analysisContextProvider);
      expect(context.tonality, _gMajor);
      // Decision 3 in research/whatkey-local/log/2026-07-26-09: only the
      // ranking tonality moves; the spelling inputs stay with the display key.
      expect(
        context.keySignature.accidentalCount,
        displaySignature.accidentalCount,
      );
      expect(context.playingContext, PlayingContext.ensemble);
    },
  );

  test('a cleared naming tonality falls back to the selected key', () async {
    final container = await setUpContainer();
    await container
        .read(playingContextProvider.notifier)
        .setContext(PlayingContext.ensemble);
    container.read(ensembleNamingTonalityProvider.notifier).set(_gMajor);
    container.read(ensembleNamingTonalityProvider.notifier).set(null);

    expect(
      container.read(analysisContextProvider).tonality,
      container.read(selectedTonalityProvider),
    );
  });

  test('solo analysis never reads the naming tonality', () async {
    final container = await setUpContainer();
    container.read(ensembleNamingTonalityProvider.notifier).set(_gMajor);

    final context = container.read(analysisContextProvider);
    expect(context.playingContext, PlayingContext.solo);
    expect(context.tonality, container.read(selectedTonalityProvider));
  });
}
