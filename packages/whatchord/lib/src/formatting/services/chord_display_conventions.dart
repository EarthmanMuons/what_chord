import '../../models/chord_extension.dart';
import '../../models/chord_identity.dart';
import '../../models/chord_tone_role.dart';
import '../../services/interval_constants.dart';
import '../../services/pitch_class.dart';

abstract final class ChordDisplayConventions {
  static const _bareShellIntervalsMask =
      1 | (1 << perfectFifthInterval) | (1 << minorSeventhInterval);

  /// True for the bare flat-seven shell (root, fifth, and flat seventh only)
  /// read as a dominant seventh: the symbol carries an omitted-third marker
  /// (D7(omit3)), because with no third sounding the omission is identity
  /// information rather than voicing detail.
  static bool showsOmittedThird(ChordIdentity identity) {
    return identity.quality == ChordQuality.dominant7 &&
        identity.extensions.isEmpty &&
        identity.presentIntervalsMask == _bareShellIntervalsMask;
  }

  /// True when a seventh-family chord carries a single natural extension
  /// (9, 11, or 13) and the slash bass is that extension, so the symbol drops
  /// it rather than restate the bass: "C9/D" -> "C7/D" and "Ab11/Db" ->
  /// "Ab7/Db". These stacked extensions are not add-tones, so the universal
  /// compression in [displayedExtensions] does not cover them.
  static bool usesExtensionSlashBassCompression(ChordIdentity identity) {
    if (!identity.hasSlashBass) return false;
    if (!identity.quality.isSeventhFamily) return false;
    if (identity.extensions.length != 1) return false;

    final ext = identity.extensions.first;
    if (ext != ChordExtension.nine &&
        ext != ChordExtension.eleven &&
        ext != ChordExtension.thirteen) {
      return false;
    }

    final bassInterval = (identity.bassPc - identity.rootPc) % 12;
    return ext.intervalAboveRoot == bassInterval;
  }

  /// Returns true when the bass note is a standard inversion tone of the chord
  /// (third, fifth, seventh, sixth, or diminished seventh), as opposed to an
  /// extension, suspension, or foreign note in the bass.
  ///
  /// Inversions and bass-note specifications are spoken as "slash" (e.g.,
  /// "C major slash E"); foreign-bass upper-structure readings use "over"
  /// (e.g., "A major over G").
  static bool bassIsInversionTone(ChordIdentity identity) {
    if (!identity.hasSlashBass) return false;
    final interval = intervalAboveRoot(identity.bassPc, identity.rootPc);
    final role = identity.toneRolesByInterval[interval];
    if (role == null) return false;
    return role == ChordToneRole.major3 ||
        role == ChordToneRole.minor3 ||
        role == ChordToneRole.perfect5 ||
        role == ChordToneRole.flat5 ||
        role == ChordToneRole.sharp5 ||
        role == ChordToneRole.sixth ||
        role == ChordToneRole.flat7 ||
        role == ChordToneRole.major7 ||
        role == ChordToneRole.dim7;
  }

  static Set<ChordExtension> displayedExtensions(ChordIdentity identity) {
    if (usesExtensionSlashBassCompression(identity)) {
      return const {};
    }

    if (!identity.hasSlashBass) return identity.extensions;

    final bassInterval = (identity.bassPc - identity.rootPc) % 12;
    return identity.extensions.where((ext) {
      // Drop add-tone extensions whose pitch class is already supplied by the
      // slash bass, avoiding redundant chord symbols like "Ab7(add11)/Db".
      if (!ext.isAddTone) return true;
      if (ext.intervalAboveRoot != bassInterval) return true;
      return false;
    }).toSet();
  }
}
