import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import '../../state/providers/analysis_context_provider.dart';
import '../../state/providers/theory_preferences_notifier.dart';
import 'scale_degrees.dart';
import 'tonality_picker_sheet.dart';

typedef TonalitySideSheetPresenter = void Function({
  required BuildContext context,
  required String barrierLabel,
  required WidgetBuilder builder,
});

class TonalityBarView extends ConsumerWidget {
  const TonalityBarView({
    super.key,
    required this.height,
    required this.tonality,
    required this.scaleDegreeAnalysis,
    required this.onOpenPicker,
    this.onScaleDegreesTap,
    this.horizontalInset = 16,
    this.keyTextScaleMultiplier = 1.0,
    this.scaleDegreesTextScaleMultiplier = 1.0,
    this.autoKey = false,
    this.autoKeyTonality,
    this.autoKeyDimmed = false,
    this.onEnsembleTap,
  });

  final double height;
  final Tonality tonality;
  final ScaleDegreeAnalysis? scaleDegreeAnalysis;
  final VoidCallback onOpenPicker;
  final VoidCallback? onScaleDegreesTap;
  final double horizontalInset;
  final double keyTextScaleMultiplier;
  final double scaleDegreesTextScaleMultiplier;

  /// When true the key button renders auto-mode detection state instead of
  /// the selected tonality: [autoKeyTonality] (or an unknown marker when
  /// null), dimmed per [autoKeyDimmed], with an auto glyph in place of the
  /// note icon. Passed as plain values so this view stays independent of the
  /// key-detection feature.
  final bool autoKey;
  final Tonality? autoKeyTonality;
  final bool autoKeyDimmed;

  /// Invoked when the ensemble badge is tapped; typically opens the playing
  /// mode setting. The badge is not tappable when null.
  final VoidCallback? onEnsembleTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    // Effective context, not the raw setting, so the badge disappears while
    // demo mode pins analysis to solo.
    final ensembleActive =
        ref.watch(analysisContextProvider.select((c) => c.playingContext)) ==
        PlayingContext.ensemble;

    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    final verticalPadding = textScale > 1.2 ? 4.0 : 12.0;
    final minButtonHeight = textScale > 1.2 ? height : 48.0;
    final effectiveMinButtonHeight = minButtonHeight < 48.0
        ? 48.0
        : minButtonHeight;
    final displayTonality = autoKey ? autoKeyTonality : tonality;
    final keySemanticLabel = autoKey
        ? (displayTonality == null
              ? 'Detected key: not enough evidence yet'
              : 'Detected key: '
                    '${tonalitySemanticLabel(displayTonality, noteNameSystem: noteNameSystem)}'
                    '${autoKeyDimmed ? ', uncertain' : ''}')
        : 'Key: ${tonalitySemanticLabel(tonality, noteNameSystem: noteNameSystem)}';
    final keyLabel = displayTonality == null
        ? 'Unknown'
        : tonalityDisplayLabel(displayTonality, noteNameSystem: noteNameSystem);

    TextStyle? scaledKeyLabelStyle(TextStyle? baseStyle) {
      final fontSize = baseStyle?.fontSize;
      if (fontSize == null) return baseStyle;
      return baseStyle?.copyWith(
        fontSize: fontSize * keyTextScaleMultiplier.clamp(1.0, 1.3),
      );
    }

    TextScaler clampLabelScaler(TextStyle? baseStyle) {
      final scaledBase = scaledKeyLabelStyle(baseStyle);
      final fontSize = scaledBase?.fontSize ?? 14;
      final lineHeight = fontSize * (baseStyle?.height ?? 1.2);
      final availableHeight = height - (verticalPadding * 2);
      final maxScale = (availableHeight / lineHeight).clamp(1.0, 2.8);
      return TextScaler.linear(textScale.clamp(1.0, maxScale));
    }

    return Material(
      color: cs.surfaceContainerLow,
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalInset),
          child: Row(
            children: [
              Semantics(
                container: true,
                button: true,
                label: keySemanticLabel,
                hint: 'Choose a key or detection mode.',
                onTap: onOpenPicker,
                onTapHint: 'Open key and detection settings',
                excludeSemantics: true,
                child: Tooltip(
                  message: 'Choose a key or detection mode',
                  child: FilledButton.tonalIcon(
                    onPressed: onOpenPicker,
                    style: ButtonStyle(
                      minimumSize: WidgetStatePropertyAll(
                        Size(0, effectiveMinButtonHeight),
                      ),
                      padding: const WidgetStatePropertyAll(
                        EdgeInsetsDirectional.fromSTEB(10, 0, 12, 0),
                      ),
                      visualDensity: VisualDensity.standard,
                    ),
                    icon: _KeyModeIcon(auto: autoKey),
                    label: AnimatedOpacity(
                      opacity: autoKey && autoKeyDimmed ? 0.55 : 1.0,
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.easeInOut,
                      child: AnimatedSize(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 400),
                          child: Text(
                            keyLabel,
                            key: ValueKey(keyLabel),
                            style: scaledKeyLabelStyle(textTheme.labelLarge),
                            textScaler: clampLabelScaler(textTheme.labelLarge),
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (ensembleActive) ...[
                const SizedBox(width: 8),
                _EnsembleBadge(onTap: onEnsembleTap),
              ],
              const SizedBox(width: 10),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Builder(
                    builder: (context) {
                      final scaleDegrees = ScaleDegrees(
                        current: scaleDegreeAnalysis,
                        mode: tonality.mode,
                        tonalityDisplayName: tonalitySemanticLabel(
                          tonality,
                          noteNameSystem: noteNameSystem,
                        ),
                        maxHeight: height,
                        fadeColor: cs.surfaceContainerLow,
                        textScaleMultiplier: scaleDegreesTextScaleMultiplier,
                      );

                      final onTap = onScaleDegreesTap;
                      if (onTap == null) return scaleDegrees;

                      return Semantics(
                        button: true,
                        onTap: onTap,
                        hint: 'Open scale explorer',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: onTap,
                          child: scaleDegrees,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Identifies the key control while marking automatic detection in-place.
class _KeyModeIcon extends StatelessWidget {
  const _KeyModeIcon({required this.auto});

  final bool auto;

  @override
  Widget build(BuildContext context) {
    final foreground =
        IconTheme.of(context).color ?? DefaultTextStyle.of(context).style.color;

    return SizedBox(
      // Automatic mode uses the trailing edge for its A. Avoid reserving that
      // otherwise-empty space between the key and label in manual mode.
      width: auto ? 24 : 20,
      height: 24,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(alignment: Alignment.center, child: Icon(Icons.key)),
          if (auto)
            PositionedDirectional(
              top: -1,
              end: 0,
              child: Text(
                'A',
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: foreground,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Persistent marker that ensemble analysis is on: naming changes globally in
/// that mode, and without a visible reminder a forgotten toggle reads as a
/// broken analyzer. Icon-only to spare the bar's horizontal space; tapping
/// opens the playing mode setting.
class _EnsembleBadge extends StatelessWidget {
  const _EnsembleBadge({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final badge = Container(
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        Icons.groups_outlined,
        size: 18,
        color: cs.onSecondaryContainer,
      ),
    );

    return Tooltip(
      message: 'Ensemble mode',
      child: Semantics(
        label: 'Ensemble mode is on',
        button: onTap != null,
        onTap: onTap,
        onTapHint: onTap == null ? null : 'Open playing mode setting',
        child: onTap == null
            ? badge
            : InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: onTap,
                child: badge,
              ),
      ),
    );
  }
}

void openTonalityPicker(
  BuildContext context, {
  required bool useSideSheet,
  required TonalitySideSheetPresenter showSideSheet,
}) {
  if (!context.mounted) return;

  if (useSideSheet) {
    showSideSheet(
      context: context,
      barrierLabel: 'Dismiss key signature picker',
      builder: (_) => const TonalityPickerSheet(
        presentation: TonalityPickerPresentation.sideSheet,
      ),
    );
    return;
  }

  unawaited(
    Navigator.of(context, rootNavigator: true).push(
      ModalBottomSheetRoute(
        builder: (_) => const TonalityPickerSheet(),
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerLow,
      ),
    ),
  );
}
