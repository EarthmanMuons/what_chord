import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/persistence/core_preferences_keys.dart';
import 'package:whatchord_app/core/providers/app_palette_notifier.dart';
import 'package:whatchord_app/core/providers/app_theme_mode_notifier.dart';
import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/audio/audio.dart';
import 'package:whatchord_app/features/chords/chords.dart';
import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/key/key.dart';
import 'package:whatchord_app/features/midi/midi.dart';
import 'package:whatchord_app/features/onboarding/onboarding.dart';
import 'package:whatchord_app/features/piano/piano.dart';
import 'package:whatchord_app/features/scales/scales.dart';
import 'package:whatchord_app/features/theory/theory.dart';

final settingsResetProvider = Provider<SettingsResetService>((ref) {
  return SettingsResetService(ref);
});

class SettingsResetService {
  SettingsResetService(this._ref);
  final Ref _ref;

  Future<void> resetAllToDefaults() async {
    final prefs = _ref.read(sharedPreferencesProvider);

    // Exit demo first so any snapshot restoration happens before preference
    // keys are cleared. Otherwise demo shutdown can re-persist old values.
    _ref
        .read(demoModeProvider.notifier)
        .setEnabledFor(enabled: false, variant: DemoModeVariant.interactive);

    // Core preferences
    await prefs.remove(CorePreferencesKeys.themeMode);
    await prefs.remove(CorePreferencesKeys.appPalette);

    // Theory preferences
    await prefs.remove(TheoryPreferencesKeys.chordNotationStyle);
    await prefs.remove(TheoryPreferencesKeys.noteNameSystem);
    await prefs.remove(TheoryPreferencesKeys.playingContext);
    await prefs.remove(TheoryPreferencesKeys.selectedTonality);

    // Explore preferences
    await prefs.remove(ExplorePreferencesKeys.showChordMemberDegrees);

    // Scale preferences
    await prefs.remove(ScalePreferencesKeys.showScaleDegrees);

    // Key preferences
    await prefs.remove(KeyPreferencesKeys.autoModeEnabled);
    await prefs.remove(KeyPreferencesKeys.behavior);

    // Cancel any reconnect/backoff workflow before mutating persisted MIDI data.
    // This immediately normalizes connection UI to "Not connected" when idle.
    final connectionState = _ref.read(midiConnectionStateProvider.notifier);
    await connectionState.cancel(reason: MidiCancelReason.settingsReset);

    // MIDI preferences (delegate to MIDI's own reset)
    await _ref.read(midiPreferencesProvider.notifier).clearAllMidiData();
    await _ref.read(audioMonitorSettingsNotifier.notifier).clearAllAudioData();
    await _ref.read(pianoViewSettingsProvider.notifier).clearAllPianoData();
    await _ref.read(onboardingTourProvider.notifier).reset();

    // Force rebuilds
    _ref.invalidate(appThemeModeProvider);
    _ref.invalidate(appPaletteProvider);
    _ref.invalidate(chordNotationStyleProvider);
    _ref.invalidate(noteNameSystemProvider);
    _ref.invalidate(playingContextProvider);
    _ref.invalidate(selectedTonalityProvider);
    _ref.invalidate(exploreChordMemberDegreesProvider);
    _ref.invalidate(showScaleDegreesProvider);
    _ref.invalidate(keyModeProvider);
    // Rebuilding the behavior also rebuilds the key detector, so detection
    // restarts clean along with everything else.
    _ref.invalidate(keyBehaviorProvider);
    _ref.invalidate(audioMonitorSettingsNotifier);
    _ref.invalidate(pianoViewSettingsProvider);
    _ref.invalidate(onboardingTourProvider);

    // Ensure transport is disconnected after reset.
    await connectionState.disconnect();
  }
}
