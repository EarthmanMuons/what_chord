import 'package:meta/meta.dart';

import '../../formatting/models/chord_presentation.dart';
import '../../formatting/models/chord_symbol.dart';
import 'polychord_candidate.dart';

/// Upper-first rendered symbol for one polychord decomposition.
@immutable
final class PolychordSymbol {
  const PolychordSymbol({required this.upper, required this.lower});

  final ChordSymbol upper;
  final ChordSymbol lower;

  @override
  String toString() => '$upper|$lower';
}

/// Existing chord presentation applied independently to both selected layers.
@immutable
final class PolychordPresentation {
  const PolychordPresentation({
    required this.candidate,
    required this.upper,
    required this.lower,
    required this.symbol,
    required this.longLabel,
    required this.semanticLabel,
  });

  final PolychordCandidate candidate;
  final ChordPresentation upper;
  final ChordPresentation lower;
  final PolychordSymbol symbol;

  /// Explicit construction wording for details and copy surfaces.
  final String longLabel;

  /// Unambiguous upper/lower wording for assistive technology.
  final String semanticLabel;
}
