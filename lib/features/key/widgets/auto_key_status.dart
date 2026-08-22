import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whatkey/whatkey.dart';

import 'package:whatchord_app/features/theory/theory.dart';

import '../models/inferred_key_state.dart';
import '../providers/inferred_key_notifier.dart';
import '../providers/key_behavior_notifier.dart';

/// Headline for the auto key view: the detected key with its calibrated
/// confidence, or a plain-language account of why there is no claim.
class AutoKeyStatus extends ConsumerWidget {
  const AutoKeyStatus({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(inferredKeyProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final displayKey = state.displayKey;
    final String headline;
    final String detail;
    if (displayKey == null) {
      headline = 'Listening…';
      detail = state.freshness == InferredKeyFreshness.none
          ? 'Play a few chords to detect the key.'
          : 'Not enough evidence yet. Keep playing.';
    } else {
      headline = tonalityDisplayLabel(
        displayKey.tonality,
        noteNameSystem: noteNameSystem,
      );
      final confidence = _calibratedConfidence(
        state,
        displayKey.tonality,
        ref.watch(keyBehaviorProvider).displayTemperature,
      );
      final percent = confidence == null
          ? null
          : '${(confidence * 100).round()}% confident';
      detail = switch ((state.claim != null, state.freshness)) {
        (true, InferredKeyFreshness.fresh) => percent ?? '',
        (true, _) => '${percent ?? ''} · evidence fading',
        (false, _) => 'Uncertain · showing the last detected key',
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: displayKey == null ? cs.onSurfaceVariant : cs.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          detail,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  double? _calibratedConfidence(
    InferredKeyState state,
    Tonality tonality,
    double temperature,
  ) {
    final calibrated = DisplayCalibration.calibrate(
      state.ranked,
      temperature: temperature,
    );
    for (final estimate in calibrated) {
      if (estimate.tonality == tonality) return estimate.confidence;
    }
    return null;
  }
}
