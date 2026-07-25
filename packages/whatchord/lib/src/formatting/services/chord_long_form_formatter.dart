import '../../models/chord_extension.dart';
import '../../models/chord_identity.dart';
import '../../models/tonality.dart';
import '../../services/note_spelling.dart';
import '../models/chord_symbol.dart';
import 'chord_display_conventions.dart';
import 'chord_quality_labels.dart';
import 'note_display_formatter.dart';

/// Renders a chord identity as its long-form academic name
/// (e.g. "C dominant seventh, flat nine").
class ChordLongFormFormatter {
  /// Renders [identity] in the key of [tonality].
  static String format({
    required ChordIdentity identity,
    required Tonality tonality,
    NoteNameSystem noteNameSystem = NoteNameSystem.international,
    ChordLongFormAccidentalStyle accidentalStyle =
        ChordLongFormAccidentalStyle.glyph,
    String? rootNameOverride,
  }) {
    final rootName =
        rootNameOverride ?? spellChordRoot(identity, tonality: tonality);
    final root = _noteName(rootName, accidentalStyle, noteNameSystem);
    final extensions = ChordDisplayConventions.displayedExtensions(identity);

    final quality = _qualityLongPhrase(
      quality: identity.quality,
      extensions: extensions,
    );
    final extPhrase = _extensionsLongPhrase(
      extensions,
      absorbedHeadline: _absorbedLongFormExtensionForParts(
        quality: identity.quality,
        extensions: extensions,
      ),
      qualityFifthModifier: identity.quality.fifthModifierLabel(
        ChordQualityLabelForm.academic,
      ),
    );

    final modifierCount = _extensionModifierCount(
      extensions,
      absorbedHeadline: _absorbedLongFormExtensionForParts(
        quality: identity.quality,
        extensions: extensions,
      ),
      qualityFifthModifier: identity.quality.fifthModifierLabel(
        ChordQualityLabelForm.academic,
      ),
    );

    // Base: "C major seventh", "F♯ half-diminished seventh", etc.
    var s = '$root $quality$extPhrase';

    if (identity.hasSlashBass && !identity.hasImpliedRoot) {
      final interval = (identity.bassPc - identity.rootPc) % 12;
      final role = identity.toneRolesByInterval[interval];

      final bassName = spellPitchClass(
        identity.bassPc,
        tonality: tonality,
        chordRootName: rootName,
        role: role,
      );
      final bass = _noteName(bassName, accidentalStyle, noteNameSystem);

      if (bass != root) {
        final connector = ChordDisplayConventions.bassIsInversionTone(identity)
            ? 'slash'
            : 'over';
        final prefix = modifierCount >= 2 ? ',' : '';
        s = '$s$prefix $connector $bass';
      }
    }

    return s.trim();
  }
}

/// Whether long-form names write accidentals as glyphs ("♭9") or words
/// ("flat nine").
enum ChordLongFormAccidentalStyle { glyph, plainText }

/// The long-form phrase for an extension set (e.g. "flat nine, sharp
/// eleven").
String extensionsLongPhrase(Set<ChordExtension> exts) {
  return _extensionsLongPhrase(exts);
}

List<String> _buildExtensionParts(
  Set<ChordExtension> exts, {
  ChordExtension? absorbedHeadline,
  String? qualityFifthModifier,
}) {
  final ordered = exts.toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  final adds = <String>[];
  final real = <String>[?qualityFifthModifier];

  for (final e in ordered) {
    if (_isAbsorbedExtension(e, absorbedHeadline)) continue;
    if (e.isAddTone) {
      adds.add(e.longLabel);
    } else {
      real.add(e.longLabel);
    }
  }

  return [...real, ...adds];
}

int _extensionModifierCount(
  Set<ChordExtension> exts, {
  ChordExtension? absorbedHeadline,
  String? qualityFifthModifier,
}) => _buildExtensionParts(
  exts,
  absorbedHeadline: absorbedHeadline,
  qualityFifthModifier: qualityFifthModifier,
).length;

String _extensionsLongPhrase(
  Set<ChordExtension> exts, {
  ChordExtension? absorbedHeadline,
  String? qualityFifthModifier,
}) {
  final parts = _buildExtensionParts(
    exts,
    absorbedHeadline: absorbedHeadline,
    qualityFifthModifier: qualityFifthModifier,
  );

  // Example outputs:
  // - "with flat nine and sharp eleven"
  // - "with nine and thirteen"
  // - "with added nine"
  // - "with nine, sharp eleven, and added thirteen"
  if (parts.isEmpty) return '';

  return ' with ${_englishJoin(parts)}';
}

String _qualityLongPhrase({
  required ChordQuality quality,
  required Set<ChordExtension> extensions,
}) {
  final base = quality.coreLabel(ChordQualityLabelForm.academic);
  final headline = _headlineExtensionForParts(
    quality: quality,
    extensions: extensions,
  );

  if (headline == null) return base;

  final headlineLabel = switch (headline) {
    ChordExtension.nine => 'ninth',
    ChordExtension.eleven => 'eleventh',
    ChordExtension.thirteen => 'thirteenth',
    _ => headline.longLabel,
  };
  final promoted = _replaceSeventhWithHeadline(base, headlineLabel);
  return promoted == base ? base : promoted;
}

ChordExtension? _absorbedLongFormExtensionForParts({
  required ChordQuality quality,
  required Set<ChordExtension> extensions,
}) {
  return _headlineExtensionForParts(quality: quality, extensions: extensions);
}

ChordExtension? _headlineExtensionForParts({
  required ChordQuality quality,
  required Set<ChordExtension> extensions,
}) {
  if (!quality.isSeventhFamily || quality == ChordQuality.diminished7) {
    return null;
  }

  if (extensions.contains(ChordExtension.thirteen)) {
    return ChordExtension.thirteen;
  }
  if (extensions.contains(ChordExtension.eleven)) {
    return ChordExtension.eleven;
  }
  if (extensions.contains(ChordExtension.nine)) {
    return ChordExtension.nine;
  }

  return null;
}

bool _isAbsorbedExtension(ChordExtension extension, ChordExtension? headline) {
  switch (headline) {
    case ChordExtension.nine:
      return extension == ChordExtension.nine;
    case ChordExtension.eleven:
      return extension == ChordExtension.nine ||
          extension == ChordExtension.eleven;
    case ChordExtension.thirteen:
      return extension == ChordExtension.nine ||
          extension == ChordExtension.eleven ||
          extension == ChordExtension.thirteen;
    case ChordExtension.add9:
      return extension == ChordExtension.add9;
    default:
      return false;
  }
}

String _replaceSeventhWithHeadline(String base, String headline) {
  if (base.contains('seventh')) {
    return base.replaceFirst('seventh', headline);
  }
  return base;
}

String _noteName(
  String noteName,
  ChordLongFormAccidentalStyle style,
  NoteNameSystem noteNameSystem,
) {
  return switch (style) {
    ChordLongFormAccidentalStyle.glyph => noteDisplayLabel(
      noteName,
      noteNameSystem: noteNameSystem,
    ),
    ChordLongFormAccidentalStyle.plainText => noteSemanticLabel(
      noteName,
      noteNameSystem: noteNameSystem,
      includeNatural: false,
    ),
  };
}

String _englishJoin(List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.single;
  if (items.length == 2) return '${items[0]} and ${items[1]}';
  final allButLast = items.sublist(0, items.length - 1);
  return '${allButLast.join(', ')}, and ${items.last}';
}
