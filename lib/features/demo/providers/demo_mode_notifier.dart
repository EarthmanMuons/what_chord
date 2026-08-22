import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/providers/app_theme_mode_notifier.dart';
import 'package:whatchord_app/features/chords/chords.dart';
import 'package:whatchord_app/features/scales/scales.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import 'demo_mode_variant_notifier.dart';
import 'demo_sequence_notifier.dart';

final demoModeProvider = NotifierProvider<DemoModeNotifier, bool>(
  DemoModeNotifier.new,
);

class _DemoSnapshot {
  final ThemeMode themeMode;
  final Tonality tonality;
  final bool showChordMemberDegrees;
  final bool showScaleDegrees;

  const _DemoSnapshot({
    required this.themeMode,
    required this.tonality,
    required this.showChordMemberDegrees,
    required this.showScaleDegrees,
  });
}

class DemoModeNotifier extends Notifier<bool> {
  _DemoSnapshot? _snapshot;
  Timer? _autoAdvanceTimer;

  static const Duration _autoAdvanceInterval = Duration(milliseconds: 2000);

  @override
  bool build() {
    ref.onDispose(_cancelAutoAdvance);
    return false; // Default to off.
  }

  void _cancelAutoAdvance() {
    _autoAdvanceTimer?.cancel();
    _autoAdvanceTimer = null;
  }

  void _updateAutoAdvance() {
    final isAnimation =
        ref.read(demoModeVariantProvider) == DemoModeVariant.animation;
    if (state && isAnimation) {
      _autoAdvanceTimer ??= Timer.periodic(_autoAdvanceInterval, (_) {
        ref.read(demoSequenceProvider.notifier).next();
        applyCurrentStep();
      });
    } else {
      _cancelAutoAdvance();
    }
  }

  void setEnabled(bool v) {
    setEnabledFor(enabled: v, variant: ref.read(demoModeVariantProvider));
  }

  void toggle() => setEnabled(!state);

  void setEnabledFor({
    required bool enabled,
    required DemoModeVariant variant,
  }) {
    final variantNotifier = ref.read(demoModeVariantProvider.notifier);
    final currentVariant = ref.read(demoModeVariantProvider);

    if (!enabled) {
      if (state) {
        _exitDemo();
      }
      variantNotifier.setVariant(variant);
      state = false;
      return;
    }

    if (!state) {
      variantNotifier.setVariant(variant);
      _enterDemo();
      state = true;
      _updateAutoAdvance();
      return;
    }

    if (variant != currentVariant) {
      variantNotifier.setVariant(variant);
      ref.read(demoSequenceProvider.notifier).reset();
      unawaited(Future<void>.microtask(applyCurrentStep));
      _updateAutoAdvance();
    }
  }

  void applyCurrentStep() {
    if (!state) return;

    final step = ref.read(demoCurrentStepProvider);

    if (step.themeMode != null) {
      unawaited(
        ref.read(appThemeModeProvider.notifier).setThemeMode(step.themeMode!),
      );
    }
    if (step.tonality != null) {
      unawaited(
        ref.read(selectedTonalityProvider.notifier).setTonality(step.tonality!),
      );
    }
    if (step.showChordMemberDegrees != null) {
      unawaited(
        ref
            .read(exploreChordMemberDegreesProvider.notifier)
            .setShowDegrees(step.showChordMemberDegrees!),
      );
    }
    if (step.showScaleDegrees != null) {
      unawaited(
        ref
            .read(showScaleDegreesProvider.notifier)
            .setShowDegrees(step.showScaleDegrees!),
      );
    }
  }

  void _enterDemo() {
    _snapshot = _DemoSnapshot(
      themeMode: ref.read(appThemeModeProvider),
      tonality: ref.read(selectedTonalityProvider),
      showChordMemberDegrees: ref.read(exploreChordMemberDegreesProvider),
      showScaleDegrees: ref.read(showScaleDegreesProvider),
    );

    // Important: apply AFTER providers have finished building.
    unawaited(Future<void>.microtask(applyCurrentStep));
  }

  void _exitDemo() {
    _cancelAutoAdvance();
    final snap = _snapshot;
    _snapshot = null;
    if (snap == null) return;

    unawaited(
      ref.read(appThemeModeProvider.notifier).setThemeMode(snap.themeMode),
    );
    unawaited(
      ref.read(selectedTonalityProvider.notifier).setTonality(snap.tonality),
    );
    unawaited(
      ref
          .read(exploreChordMemberDegreesProvider.notifier)
          .setShowDegrees(snap.showChordMemberDegrees),
    );
    unawaited(
      ref
          .read(showScaleDegreesProvider.notifier)
          .setShowDegrees(snap.showScaleDegrees),
    );

    // Reset demo sequence so next session starts clean.
    ref.read(demoSequenceProvider.notifier).reset();
  }
}
