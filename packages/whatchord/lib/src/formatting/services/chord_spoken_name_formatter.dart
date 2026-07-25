import '../../models/chord_extension.dart';
import '../../models/chord_identity.dart';
import '../../models/tonality.dart';
import '../../services/note_spelling.dart';
import '../models/chord_symbol.dart';
import 'chord_display_conventions.dart';
import 'chord_quality_labels.dart';
import 'note_display_formatter.dart';

/// Renders a chord identity as its idiomatic spoken name
/// (e.g. "C minor major seven").
class ChordSpokenNameFormatter {
  /// Renders [identity] in the key of [tonality].
  static String format({
    required ChordIdentity identity,
    required Tonality tonality,
    NoteNameSystem noteNameSystem = NoteNameSystem.international,
    String? rootNameOverride,
  }) {
    final rootName =
        rootNameOverride ?? spellChordRoot(identity, tonality: tonality);
    final root = noteDisplayLabel(rootName, noteNameSystem: noteNameSystem);
    final extensions = ChordDisplayConventions.displayedExtensions(identity);

    final (qualityPhrase, absorbedHeadline) = _qualitySpokenPhraseAndHeadline(
      quality: identity.quality,
      extensions: extensions,
    );
    final extPhrase = _extensionsSpokenPhrase(
      extensions,
      absorbedHeadline: absorbedHeadline,
    );

    final qualityPart = qualityPhrase.isEmpty ? '' : ' $qualityPhrase';
    var s = '$root$qualityPart$extPhrase';

    if (identity.hasSlashBass && !identity.hasImpliedRoot) {
      final interval = (identity.bassPc - identity.rootPc) % 12;
      final role = identity.toneRolesByInterval[interval];

      final bassName = spellPitchClass(
        identity.bassPc,
        tonality: tonality,
        chordRootName: rootName,
        role: role,
      );
      final bass = noteDisplayLabel(bassName, noteNameSystem: noteNameSystem);

      if (bass != root) {
        final connector = ChordDisplayConventions.bassIsInversionTone(identity)
            ? 'slash'
            : 'over';
        s = '$s $connector $bass';
      }
    }

    return s.trim();
  }
}

(String quality, ChordExtension? absorbed) _qualitySpokenPhraseAndHeadline({
  required ChordQuality quality,
  required Set<ChordExtension> extensions,
}) {
  if (quality.isSixFamily && extensions.contains(ChordExtension.add9)) {
    final q = switch (quality) {
      ChordQuality.major6 => 'six-nine',
      ChordQuality.minor6 => 'minor six-nine',
      _ => quality.label(ChordQualityLabelForm.idiomatic),
    };
    return (q, ChordExtension.add9);
  }

  final base = quality.label(ChordQualityLabelForm.idiomatic);
  final headline = _headlineExtension(quality: quality, extensions: extensions);

  if (headline == null) return (base, null);

  final promoted = _replaceSevenWithHeadline(base, headline.longLabel);
  if (promoted == base) return (base, null);

  return (promoted, headline);
}

String _extensionsSpokenPhrase(
  Set<ChordExtension> exts, {
  ChordExtension? absorbedHeadline,
}) {
  if (exts.isEmpty) return '';

  final ordered = exts.toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

  final parts = <String>[];
  for (final e in ordered) {
    if (_isAbsorbed(e, absorbedHeadline)) continue;
    parts.add(e.spokenLabel);
  }

  if (parts.isEmpty) return '';
  return ' ${parts.join(' ')}';
}

ChordExtension? _headlineExtension({
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

bool _isAbsorbed(ChordExtension ext, ChordExtension? headline) {
  switch (headline) {
    case ChordExtension.nine:
      return ext == ChordExtension.nine;
    case ChordExtension.eleven:
      return ext == ChordExtension.nine || ext == ChordExtension.eleven;
    case ChordExtension.thirteen:
      return ext == ChordExtension.nine ||
          ext == ChordExtension.eleven ||
          ext == ChordExtension.thirteen;
    case ChordExtension.add9:
      return ext == ChordExtension.add9;
    default:
      return false;
  }
}

String _replaceSevenWithHeadline(String base, String headline) {
  if (base.contains('seven')) {
    return base.replaceFirst('seven', headline);
  }
  return base;
}
