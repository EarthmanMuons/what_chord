import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../models/selection_colors.dart';
import 'chip_flip_transition.dart';

/// The visual state of a [NoteChip].
///
/// - [plain]: faint resting outline. Explore tones that are neither members nor
///   playing; live notes held down with the sustain pedal up.
/// - [outline]: a solid primary ring (no fill). Explore scale/chord members.
/// - [fill]: filled with [ColorScheme.primaryContainer]. Explore tones that are
///   currently playing.
/// - [engaged]: darker resting outline. Live notes held down while the sustain
///   pedal is engaged.
/// - [sustained]: heaviest outline. Live notes held only by the sustain pedal.
enum NoteChipState { plain, outline, fill, engaged, sustained }

/// A note/degree chip that flips between [label] and [alternateLabel] when its
/// primary label changes and animates its width to fit, with five visual
/// [NoteChipState]s. Shared by the home live-input display and the Explore
/// Chords/Scales tone strips.
class NoteChip extends StatelessWidget {
  const NoteChip({
    super.key,
    required this.label,
    required this.alternateLabel,
    required this.semanticLabel,
    required this.state,
    this.semanticValue,
    this.sizeScale = 1.0,
    this.verticalScale = 1.0,
    this.horizontalPadding = 10.0,
  });

  static const Duration _resizeDuration = Duration(milliseconds: 90);

  final String label;
  final String alternateLabel;
  final String semanticLabel;
  final NoteChipState state;
  final String? semanticValue;
  final double sizeScale;
  final double verticalScale;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final fill = state == NoteChipState.fill;

    final labelStyle = theme.textTheme.titleMedium?.copyWith(
      color: fill ? cs.onPrimaryContainer : cs.onSurface,
      fontWeight: fill ? FontWeight.w700 : null,
    );
    final filledLabelStyle = labelStyle?.copyWith(fontWeight: FontWeight.w700);
    final fontSize = labelStyle?.fontSize ?? 16.0;
    final defaultHeight = labelStyle?.height ?? 1.2;
    final extraVertical = ((defaultHeight - 1.0) * fontSize / 2).clamp(
      0.0,
      8.0,
    );
    final labelStrut = StrutStyle(
      fontSize: fontSize,
      height: 1.0,
      forceStrutHeight: true,
    );
    // The fill and plain borders are the shared chip-selection treatment; the
    // other three are note-chip specific: [outline] is Explore's primary ring,
    // while [engaged] and [sustained] are progressively heavier resting
    // outlines for the sustain pedal's hold states.
    final border = switch (state) {
      NoteChipState.fill => SelectionColors.selectedChipBorder(cs),
      NoteChipState.outline => BorderSide(color: cs.primary, width: 1.5),
      NoteChipState.engaged => BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.78),
        width: 1.0,
      ),
      NoteChipState.sustained => BorderSide(
        color: cs.outlineVariant.withValues(alpha: 0.92),
        width: 1.6,
      ),
      NoteChipState.plain => SelectionColors.restChipBorder(cs),
    };

    // A BoxDecoration border adds its width to the chip's layout size, so a
    // heavier border (e.g. when sustained) would otherwise grow the box and
    // nudge neighboring chips. Trim the inner padding by the extra width past
    // the thinnest border so every state keeps a plain chip's footprint.
    const baseBorderWidth = 1.0;
    final borderInset = border.width - baseBorderWidth;
    final scaledHorizontalPadding = horizontalPadding * sizeScale;
    final chipTextWidth = math.max(
      math.max(
        _measureLabelWidth(context, label, labelStyle),
        _measureLabelWidth(context, label, filledLabelStyle),
      ),
      math.max(
        _measureLabelWidth(context, alternateLabel, labelStyle),
        _measureLabelWidth(context, alternateLabel, filledLabelStyle),
      ),
    );

    return Semantics(
      container: true,
      label: semanticLabel,
      value: semanticValue,
      child: ExcludeSemantics(
        child: AnimatedSize(
          duration: _resizeDuration,
          curve: Curves.easeOutCubic,
          alignment: Alignment.centerLeft,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 340),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (currentChild, previousChildren) {
              return CurrentSizeSwitcherLayout(
                currentChild: currentChild,
                previousChildren: previousChildren,
              );
            },
            transitionBuilder: (child, animation) {
              return ChipFlipTransition(
                animation: animation,
                incoming: child.key == ValueKey(label),
                child: child,
              );
            },
            child: AnimatedContainer(
              key: ValueKey(label),
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                color: fill ? cs.primaryContainer : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10 * sizeScale),
                border: Border.fromBorderSide(border),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: scaledHorizontalPadding - borderInset,
                vertical: (6 * verticalScale) + extraVertical - borderInset,
              ),
              child: SizedBox(
                width: chipTextWidth,
                child: Text(
                  label,
                  strutStyle: labelStrut,
                  style: labelStyle,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _measureLabelWidth(
    BuildContext context,
    String text,
    TextStyle? style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    return painter.width;
  }
}
