import '../../models/chord_extension.dart';
import '../../models/chord_identity.dart';
import '../models/chord_symbol.dart';
import 'chord_quality_labels.dart';

/// Formats the "quality+extensions" portion of a chord symbol.
class ChordQualityFormatter {
  static String format({
    required ChordQuality quality,
    required Set<ChordExtension> extensions,
    required ChordNotationStyle notation,
    ChordQualityLabelForm? qualityFormOverride,
    bool rootEndsInSharpOrFlat = false,
    bool omitThird = false,
  }) {
    final form = qualityFormOverride ?? _defaultQualityFormFor(notation);

    final textualMinorMajor =
        quality == ChordQuality.minorMajor7 &&
        form == ChordQualityLabelForm.textual;

    var base = textualMinorMajor ? 'm' : quality.coreLabel(form);

    // Bare flat-seven shell: the omitted third is the identity information.
    // Only the extensionless dominant seventh shell sets this, so the marker is
    // the whole trailing group.
    if (omitThird) return '$base(omit3)';

    // Canonical ordering.
    final ordered = extensions.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    // Conventional 6/9 spelling (a six-family chord plus add9).
    if (quality.isSixFamily && extensions.contains(ChordExtension.add9)) {
      base = '$base/9';
    }

    // Headline promotion (9/11/13) for eligible seventh-family chords.
    final has9 = extensions.contains(ChordExtension.nine);
    final has11 = extensions.contains(ChordExtension.eleven);
    final has13 = extensions.contains(ChordExtension.thirteen);

    ChordExtension? headline;
    if (quality.isSeventhFamily &&
        _allowsHeadlinePromotion(quality: quality, form: form)) {
      if (has13) {
        headline = ChordExtension.thirteen;
      } else if (has11) {
        headline = ChordExtension.eleven;
      } else if (has9) {
        headline = ChordExtension.nine;
      }
    }

    var bareHeadline = false;
    if (headline != null && !textualMinorMajor) {
      final promoted = _replaceSeventhWithExtension(base, headline.shortLabel);
      if (promoted != base) {
        bareHeadline = base == '7' || base.startsWith('7sus');
        base = promoted;
      } else {
        // Promotion not supported for this base form; keep headline as a modifier.
        headline = null;
      }
    }

    final mods = <ChordExtension>[];
    final absorbedAdd9 = quality.isSixFamily && base.endsWith('/9');

    for (final ext in ordered) {
      if (ext == headline) continue;
      if (absorbedAdd9 && ext == ChordExtension.add9) continue;

      // A headline extension implies the stack beneath it, so a 9 or 11 below a
      // 13 is absorbed rather than listed, whether stacked (nine/eleven) or
      // added (add11 when no ninth makes the 11 an add tone).
      if (headline == ChordExtension.thirteen) {
        if (ext == ChordExtension.nine ||
            ext == ChordExtension.eleven ||
            ext == ChordExtension.add11) {
          continue;
        }
      } else if (headline == ChordExtension.eleven) {
        if (ext == ChordExtension.nine) continue;
      }

      final displayExt = _displayExtensionFor(quality: quality, ext: ext);
      mods.add(displayExt);
    }

    final fifth = quality.fifthModifierLabel(form);

    final labels = [
      if (textualMinorMajor) _minorMajorModifierLabel(headline),
      ...mods.map((e) => e.shortLabel),
    ];

    // A bare promoted headline after a sharp or flat root reads ambiguously
    // (C#11 could be C# plus 11 or C plus #11), so the whole label becomes
    // one group: C#(11), Eb(13,b9), F#(13,#11).
    if (bareHeadline && rootEndsInSharpOrFlat) {
      final parts = [base, ?fifth, ...labels];
      return '(${parts.join(_modsSeparator(notation))})';
    }

    if (mods.isEmpty && !textualMinorMajor) {
      if (fifth == null) return base;
      return quality.fifthParenthesizedWhenLone
          ? '$base($fifth)'
          : '$base$fifth';
    }

    final useParens = _shouldUseParens(
      quality: quality,
      notation: notation,
      mods: mods,
      headline: headline,
      textualMinorMajor: textualMinorMajor,
    );

    if (fifth == null) {
      return textualMinorMajor || useParens
          ? '$base(${labels.join(_modsSeparator(notation))})'
          : '$base${labels.join()}';
    }

    // An altered fifth and other modifiers share one trailing group, so the
    // symbol never has parentheses mid-label or two separate groups. The fifth
    // folds into the group when it is conventionally parenthesized (Cm13(b5,b13)),
    // when another alteration would collide with a bare fifth (C9(b5,b9)), or
    // when a group is forming anyway (C7(b5,add13)). A bare fifth beside a lone
    // inline add-tone stays inline (Em#5add13), since "add" already delimits it.
    final hasCollidingMod = mods.any((e) => !e.isAddTone);
    final fold =
        quality.fifthParenthesizedWhenLone || hasCollidingMod || useParens;

    if (fold) {
      final grouped = [fifth, ...labels].join(_modsSeparator(notation));
      return '$base($grouped)';
    }

    return '$base$fifth${labels.join()}';
  }

  static ChordQualityLabelForm _defaultQualityFormFor(
    ChordNotationStyle notation,
  ) {
    return notation == ChordNotationStyle.symbolic
        ? ChordQualityLabelForm.symbolic
        : ChordQualityLabelForm.textual;
  }

  /// Whether it is conventional to "promote" 9/11/13 into the headline
  /// (C9, C11, C13, Cmaj9, Cm11, etc.) for this quality/form.
  static bool _allowsHeadlinePromotion({
    required ChordQuality quality,
    required ChordQualityLabelForm form,
  }) {
    // Seventh-family qualities are the ones that headline 9/11/13.
    switch (quality) {
      case ChordQuality.dominant7:
      case ChordQuality.dominant7sus2:
      case ChordQuality.dominant7sus4:
      case ChordQuality.dominant7Flat5:
      case ChordQuality.dominant7Sharp5:
      case ChordQuality.major7:
      case ChordQuality.major7sus2:
      case ChordQuality.major7sus4:
      case ChordQuality.major7Flat5:
      case ChordQuality.major7Sharp5:
      case ChordQuality.minor7:
      case ChordQuality.minor7Sharp5:
      case ChordQuality.minorMajor7:
      case ChordQuality.halfDiminished7:
        return true;
      default:
        return false;
    }
  }

  static ChordExtension _displayExtensionFor({
    required ChordQuality quality,
    required ChordExtension ext,
  }) {
    // For fully diminished seventh chords, natural extensions are commonly
    // rendered as added tones: Cdim7(add9), Cdim7(add11), etc.
    if (quality == ChordQuality.diminished7 && ext.isNaturalExtension) {
      switch (ext) {
        case ChordExtension.nine:
          return ChordExtension.add9;
        case ChordExtension.eleven:
          return ChordExtension.add11;
        case ChordExtension.thirteen:
          return ChordExtension.add13;
        default:
          return ext;
      }
    }
    return ext;
  }

  static String _replaceSeventhWithExtension(String base, String ext) {
    // Suspended headline: 7sus4 -> 9sus4, maj7sus4 -> maj9sus4,
    // Δ7sus4 -> Δ9sus4.
    if (base.startsWith('7sus')) {
      return '$ext${base.substring(1)}';
    }
    if (base.startsWith('maj7sus')) {
      return 'maj$ext${base.substring(4)}';
    }
    if (base.startsWith('Δ7sus')) {
      return 'Δ$ext${base.substring(2)}';
    }

    // Plain seventh-family cores end in '7': 7 -> 9, maj7 -> maj9, m7 -> m9,
    // Δ7 -> Δ9, ø7 -> ø9.
    if (base == '7') return ext;
    if (base.endsWith('7')) {
      return '${base.substring(0, base.length - 1)}$ext';
    }
    return base;
  }

  static String _minorMajorModifierLabel(ChordExtension? headline) {
    if (headline == null) return 'maj7';
    return 'maj${headline.shortLabel}';
  }

  static bool _shouldUseParens({
    required ChordQuality quality,
    required ChordNotationStyle notation,
    required List<ChordExtension> mods,
    required ChordExtension? headline,
    required bool textualMinorMajor,
  }) {
    if (textualMinorMajor) return true;
    if (quality == ChordQuality.diminished7) return true;
    if (mods.isEmpty) return false;

    // Suspended seventh-family chords group their modifiers instead of running
    // them onto the sus label: C7sus4(b13), CΔ9sus4(b13).
    if (quality.isSeventhFamily && quality.isSus) return true;

    // Single modifier: generally inline, except add-tones on seventh-family chords.
    if (mods.length == 1) {
      final ext = mods.first;

      // Added tones read cleanly inline after the bare root (Cadd9), the fused
      // single-letter "m" (Cmadd9), and the symbolic +/° quality symbols, which
      // already delimit (C+add13). They need parentheses on seventh-family
      // chords (Cm7(add11)) and after the spelled-out word qualities "aug"/"dim",
      // whose letters would otherwise collide with "add" ("Caugadd13").
      if (ext.isAddTone) {
        if (quality.isSeventhFamily) return true;
        return notation == ChordNotationStyle.textual &&
            (quality == ChordQuality.augmented ||
                quality == ChordQuality.diminished);
      }

      if (_isDensePromotedMajorFamilyLabel(quality, headline)) return true;

      if (quality == ChordQuality.major && ext.isAlteration) return true;

      return false; // Delimited qualities keep lone modifiers inline.
    }

    // Multiple modifiers: group them.
    return true;
  }

  static bool _isDensePromotedMajorFamilyLabel(
    ChordQuality quality,
    ChordExtension? headline,
  ) {
    if (headline != ChordExtension.eleven &&
        headline != ChordExtension.thirteen) {
      return false;
    }

    switch (quality) {
      case ChordQuality.major7:
      case ChordQuality.major7Flat5:
      case ChordQuality.major7Sharp5:
        return true;
      default:
        return false;
    }
  }

  static String _modsSeparator(ChordNotationStyle notation) {
    return notation == ChordNotationStyle.symbolic ? '' : ',';
  }
}
