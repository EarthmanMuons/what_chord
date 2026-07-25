import 'dart:async';

import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/key/key.dart';
import 'package:whatchord_app/features/settings/settings.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class TonalityBar extends ConsumerWidget {
  const TonalityBar({
    super.key,
    required this.height,
    this.horizontalInset = 16,
    this.keyTextScaleMultiplier = 1.0,
    this.scaleDegreesTextScaleMultiplier = 1.0,
    this.onScaleDegreesTap,
    this.scaleDegreeAnalysis,
    this.useDetectedScaleDegrees = true,
  });

  final double height;
  final double horizontalInset;
  final double keyTextScaleMultiplier;
  final double scaleDegreesTextScaleMultiplier;
  final VoidCallback? onScaleDegreesTap;

  /// Scale degrees to render when [useDetectedScaleDegrees] is false; the
  /// Explore pages pass their example chord's analysis instead of the live
  /// detection.
  final ScaleDegreeAnalysis? scaleDegreeAnalysis;
  final bool useDetectedScaleDegrees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final autoKey = ref.watch(keyModeProvider) == KeyMode.auto;
    // Watching here is what activates live key detection; the inferred state
    // stays warm for the Key page's auto view even in manual mode.
    final inferred = ref.watch(inferredKeyProvider);
    return TonalityBarView(
      height: height,
      horizontalInset: horizontalInset,
      keyTextScaleMultiplier: keyTextScaleMultiplier,
      scaleDegreesTextScaleMultiplier: scaleDegreesTextScaleMultiplier,
      tonality: ref.watch(selectedTonalityProvider),
      scaleDegreeAnalysis: useDetectedScaleDegrees
          ? ref.watch(detectedScaleDegreeAnalysisProvider)
          : scaleDegreeAnalysis,
      onScaleDegreesTap: onScaleDegreesTap,
      autoKey: autoKey,
      autoKeyTonality: inferred.displayKey?.tonality,
      autoKeyDimmed: inferred.displayKey != null && !inferred.emphasized,
      onOpenPicker: () =>
          unawaited(Navigator.of(context).push(KeyPage.route())),
      onEnsembleTap: () => unawaited(
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => const SettingsPage(scrollToPlayingMode: true),
          ),
        ),
      ),
    );
  }
}
