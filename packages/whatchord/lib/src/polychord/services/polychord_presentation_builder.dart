import '../../formatting/models/chord_presentation.dart';
import '../../formatting/models/chord_symbol.dart';
import '../../formatting/services/chord_presentation_builder.dart';
import '../../models/chord_identity.dart';
import '../../models/tonality.dart';
import '../../services/chord_quality_intervals.dart';
import '../../services/chord_tone_roles.dart';
import '../models/polychord_candidate.dart';
import '../models/polychord_presentation.dart';

/// Renders a selected structural decomposition without changing either layer.
abstract final class PolychordPresentationBuilder {
  static PolychordPresentation fromCandidate({
    required PolychordCandidate candidate,
    required Tonality tonality,
    required ChordNotationStyle notation,
    NoteNameSystem noteNameSystem = NoteNameSystem.international,
  }) {
    final upper = _presentationForLayer(
      candidate.upper.identity,
      tonality: tonality,
      notation: notation,
      noteNameSystem: noteNameSystem,
    );
    final lower = _presentationForLayer(
      candidate.lower.identity,
      tonality: tonality,
      notation: notation,
      noteNameSystem: noteNameSystem,
    );

    return PolychordPresentation(
      candidate: candidate,
      upper: upper,
      lower: lower,
      symbol: PolychordSymbol(upper: upper.symbol, lower: lower.symbol),
      longLabel: 'Polychord: ${upper.longLabel} above ${lower.longLabel}',
      semanticLabel:
          'Polychord. Upper chord: ${upper.semanticLabel}. '
          'Lower chord: ${lower.semanticLabel}.',
    );
  }

  static ChordPresentation _presentationForLayer(
    PolychordLayerIdentity layer, {
    required Tonality tonality,
    required ChordNotationStyle notation,
    required NoteNameSystem noteNameSystem,
  }) {
    final quality = switch (layer.quality) {
      PolychordLayerQuality.major => ChordQuality.major,
      PolychordLayerQuality.minor => ChordQuality.minor,
      PolychordLayerQuality.dominant7 => ChordQuality.dominant7,
      PolychordLayerQuality.major7 => ChordQuality.major7,
      PolychordLayerQuality.minor7 => ChordQuality.minor7,
    };
    final mask = quality.canonicalMask;
    final identity = ChordIdentity(
      rootPc: layer.rootPc,
      bassPc: layer.rootPc,
      quality: quality,
      toneRolesByInterval: ChordToneRoles.build(
        quality: quality,
        extensions: const {},
        relMask: mask,
      ),
      presentIntervalsMask: mask,
    );
    return ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: tonality,
      notation: notation,
      noteNameSystem: noteNameSystem,
    );
  }
}
