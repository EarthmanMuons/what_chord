import '../../models/chord_identity.dart';
import '../../models/tonality.dart';
import '../../services/note_spelling.dart';
import '../models/chord_symbol.dart';
import 'chord_display_conventions.dart';
import 'chord_quality_formatter.dart';

/// Renders a chord identity as a structured [ChordSymbol].
class ChordSymbolBuilder {
  /// Builds the symbol for [identity], spelling the root and bass for
  /// [tonality] unless [rootName] overrides the root.
  static ChordSymbol fromIdentity({
    required ChordIdentity identity,
    required Tonality tonality,
    required ChordNotationStyle notation,
    String? rootName,
  }) {
    final root = rootName ?? spellChordRoot(identity, tonality: tonality);

    // An implied-root reading has a non-root lowest voice by construction;
    // its symbol is the plain chord name, never a slash.
    String? bass;
    if (identity.hasSlashBass && !identity.hasImpliedRoot) {
      final interval = (identity.bassPc - identity.rootPc) % 12;
      final role = identity.toneRolesByInterval[interval];
      bass = spellSlashBass(
        identity.bassPc,
        tonality: tonality,
        chordRootName: root,
        role: role,
      );
    }

    final quality = ChordQualityFormatter.format(
      quality: identity.quality,
      extensions: ChordDisplayConventions.displayedExtensions(identity),
      notation: notation,
      rootEndsInSharpOrFlat: endsInSharpOrFlat(root),
      omitThird: ChordDisplayConventions.showsOmittedThird(identity),
    );

    return ChordSymbol(root: root, quality: quality, bass: bass);
  }

  /// [fromIdentity] rendered to a plain string (e.g. "Cm7/Eb").
  static String formatIdentity({
    required ChordIdentity identity,
    required Tonality tonality,
    required ChordNotationStyle notation,
  }) {
    return fromIdentity(
      identity: identity,
      tonality: tonality,
      notation: notation,
    ).toString();
  }
}
