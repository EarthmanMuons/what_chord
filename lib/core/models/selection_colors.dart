import 'package:material_ui/material_ui.dart';

/// Shared treatment for a selected full-width list row, so row selection looks
/// identical wherever it appears (the Scale Explorer chord and scale lists, the
/// key signature picker). Compact toggles, segments, and chips fill solidly with
/// [ColorScheme.primaryContainer]; full-width rows take this lighter primary
/// wash instead so a whole row never reads as a heavy block.
abstract final class SelectionColors {
  /// Flat background tint for a selected row. Blends [ColorScheme.primary] into
  /// [surface] (the row's own background) so the wash reads the same on any
  /// container shade; pass the local background when rows sit on something other
  /// than [ColorScheme.surface].
  static Color selectedRow(ColorScheme cs, {Color? surface}) =>
      Color.alphaBlend(
        cs.primary.withValues(alpha: 0.10),
        surface ?? cs.surface,
      );

  /// Selected-row text color: [ColorScheme.primary] (the darker blue in light
  /// mode), echoing the outlined active note chips. Pair with a slight weight
  /// bump.
  static Color selectedRowText(ColorScheme cs) => cs.primary;

  /// Border for a chip in the filled, active "note chip" state: a primary ring
  /// at the weight the active note chips use. Shared by the active note chip and
  /// the key signature picker's mode chip so the highlight reads identically.
  static BorderSide selectedChipBorder(ColorScheme cs) =>
      BorderSide(color: cs.primary.withValues(alpha: 0.82), width: 1.6);

  /// Border for a chip at rest: the faint outline of an unselected note chip.
  static BorderSide restChipBorder(ColorScheme cs) =>
      BorderSide(color: cs.outlineVariant.withValues(alpha: 0.60), width: 1.0);
}
