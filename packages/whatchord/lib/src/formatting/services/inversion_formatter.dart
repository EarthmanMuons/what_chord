import '../../models/chord_extension.dart';
import '../../models/chord_identity.dart';
import 'chord_display_conventions.dart';
import 'chord_tone_role_token_labels.dart';
import 'note_display_formatter.dart';

/// Describes a slash bass in words (e.g. "1st inversion", "non-root bass").
abstract final class InversionFormatter {
  /// The inversion description for [id], or null without a slash bass.
  ///
  /// An implied-root reading is not an inversion of anything the player
  /// sounded, so it gets no description; callers label rootless separately.
  static String? format(ChordIdentity id) {
    if (!id.hasSlashBass || id.hasImpliedRoot) return null;

    final bassInterval = _interval(id.bassPc, id.rootPc);

    if (ChordDisplayConventions.usesExtensionSlashBassCompression(id)) {
      return 'slash bass: ${id.extensions.first.shortLabel}';
    }

    // Only treat true chord-members as inversions (root/3rd/5th/7th).
    final isCoreMember = _coreMemberIntervals(
      id.quality,
    ).contains(bassInterval);

    if (!isCoreMember) {
      final role = id.toneRolesByInterval[bassInterval];
      return role == null
          ? 'non-root bass'
          : 'non-root bass: ${toGlyphAccidentals(role.label)}';
    }

    // Bass is a core chord tone -> classical inversion naming is appropriate.
    return id.quality.isSeventhFamily
        ? _seventhInversion(bassInterval)
        : _triadInversion(bassInterval);
  }

  static Set<int> _coreMemberIntervals(ChordQuality q) {
    switch (q) {
      // Triad-family
      case ChordQuality.major:
      case ChordQuality.major6:
        return const {0, 4, 7}; // 1, 3, 5

      case ChordQuality.majorFlat5:
        return const {0, 4, 6}; // 1, 3, b5

      case ChordQuality.minor:
      case ChordQuality.minor6:
        return const {0, 3, 7}; // 1, b3, 5

      case ChordQuality.minorSharp5:
        return const {0, 3, 8}; // 1, b3, #5

      case ChordQuality.diminished:
        return const {0, 3, 6}; // 1, b3, b5

      case ChordQuality.augmented:
        return const {0, 4, 8}; // 1, 3, #5

      case ChordQuality.power:
        return const {0, 7}; // 1, 5

      case ChordQuality.sus2:
        return const {0, 2, 7}; // 1, 2, 5

      case ChordQuality.sus4:
        return const {0, 5, 7}; // 1, 4, 5

      case ChordQuality.sus2sus4:
        return const {0, 2, 5, 7}; // 1, 2, 4, 5

      // Seventh-family (include the seventh as core)
      case ChordQuality.dominant7:
        return const {0, 4, 7, 10}; // 1, 3, 5, b7

      case ChordQuality.dominant7sus2:
        return const {0, 2, 7, 10}; // 1, 2, 5, b7

      case ChordQuality.dominant7sus4:
        return const {0, 5, 7, 10}; // 1, 4, 5, b7

      case ChordQuality.dominant7Flat5:
        return const {0, 4, 6, 10}; // 1, 3, b5, b7

      case ChordQuality.dominant7Sharp5:
        return const {0, 4, 8, 10}; // 1, 3, #5, b7

      case ChordQuality.major7:
        return const {0, 4, 7, 11}; // 1, 3, 5, 7

      case ChordQuality.major7sus2:
        return const {0, 2, 7, 11}; // 1, 2, 5, 7

      case ChordQuality.major7sus4:
        return const {0, 5, 7, 11}; // 1, 4, 5, 7

      case ChordQuality.major7Flat5:
        return const {0, 4, 6, 11}; // 1, 3, b5, 7

      case ChordQuality.major7Sharp5:
        return const {0, 4, 8, 11}; // 1, 3, #5, 7

      case ChordQuality.minor7:
        return const {0, 3, 7, 10}; // 1, b3, 5, b7

      case ChordQuality.minor7Sharp5:
        return const {0, 3, 8, 10}; // 1, b3, #5, b7

      case ChordQuality.minorMajor7:
        return const {0, 3, 7, 11}; // 1, b3, 5, 7

      case ChordQuality.halfDiminished7:
        return const {0, 3, 6, 10}; // 1, b3, b5, b7

      case ChordQuality.diminished7:
        return const {0, 3, 6, 9}; // 1, b3, b5, bb7(=6)
    }
  }

  static String? _triadInversion(int bassInterval) {
    return switch (bassInterval) {
      3 || 4 || 5 || 2 => '1st inversion', // 3rd-ish bass incl sus
      7 || 6 || 8 => '2nd inversion', // 5th-ish bass
      _ => null,
    };
  }

  static String? _seventhInversion(int bassInterval) {
    return switch (bassInterval) {
      3 || 4 || 5 || 2 => '1st inversion',
      7 || 6 || 8 => '2nd inversion',
      9 || 10 || 11 => '3rd inversion', // dim7=9, dom/min7=10, maj7=11
      _ => null,
    };
  }

  static int _interval(int pc, int rootPc) {
    final d = pc - rootPc;
    final m = d % 12;
    return m < 0 ? m + 12 : m;
  }
}
