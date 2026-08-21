import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';

/// Shared divider treatment for the Scale Explorer's chord and scale lists, so
/// both panes look the same: a slightly thicker rule beneath a section header,
/// thin separators between adjacent rows, and no trailing line at the foot of a
/// section.
abstract final class ScaleListStyle {
  static const double headerRuleThickness = 2;

  /// The flat, full-width background tint marking the selected row in either
  /// list. Shared with the key signature picker via [SelectionColors].
  static Color selectedRow(ColorScheme cs) => SelectionColors.selectedRow(cs);

  /// Row text color: neutral at rest, [ColorScheme.primary] when selected
  /// (echoing the outlined note chips). Pair with a slight weight bump.
  static Color rowText(ColorScheme cs, {required bool selected}) =>
      selected ? SelectionColors.selectedRowText(cs) : cs.onSurface;

  static Color _ruleColor(ColorScheme cs) => cs.outlineVariant;

  static Color _separatorColor(ColorScheme cs) =>
      cs.outlineVariant.withValues(alpha: 0.4);

  /// A full-width rule drawn directly beneath a section header.
  static Widget headerRule(ColorScheme cs) =>
      Container(height: headerRuleThickness, color: _ruleColor(cs));

  /// A full-width separator drawn between two adjacent rows (used where rows can
  /// take their natural height, e.g. the chord list's plain column).
  static Widget rowSeparator(ColorScheme cs) =>
      Container(height: 1, color: _separatorColor(cs));

  /// The same separator as a [BorderSide], for fixed-extent rows that draw it as
  /// a bottom border rather than an inserted widget (e.g. the scale picker).
  static BorderSide separatorSide(ColorScheme cs) =>
      BorderSide(color: _separatorColor(cs));
}
