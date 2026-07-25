import 'package:meta/meta.dart';

import '../models/chord_identity.dart';
import '../services/chord_quality_intervals.dart';
import '../services/interval_constants.dart';

/// Chord structure templates for pitch-class matching.
///
/// Each template defines the expected interval structure for a chord quality:
/// - Required: tones that define the quality (e.g., M3 + P5 for major)
/// - Optional: tones often omitted in real voicings (typically the 5th)
/// - Penalty: tones that contradict the quality (e.g., m3 in a major chord)
///
/// Intervals are encoded as 12-bit masks where bit N represents interval N
/// above the assumed root (N = 0-11 semitones).
///
/// Design philosophy:
/// - Fifths are usually optional (shell voicing support)
/// - Penalties are soft (cost penalty, not hard rejection)
/// - Third quality defines major/minor family membership
/// - Seventh presence/type defines extended chord categories
@immutable
class ChordTemplate {
  /// Quality token for this template.
  final ChordQuality quality;

  /// Required intervals (as a 12-bit mask relative to root).
  final int requiredMask;

  /// Optional intervals (often omitted in real voicings).
  final int optionalMask;

  /// Intervals that strongly contradict this quality (penalty, not hard forbid).
  final int penaltyMask;

  /// Whether the observed pitch classes must exactly match the base template.
  final bool requiresExactMatch;

  /// Whether ensemble analysis may hypothesize this template on an absent
  /// (implied) root. Every required tone must then sound: the guide tones
  /// carry the identity, so the missing-essential allowance does not apply.
  final bool allowsMissingRoot;

  const ChordTemplate({
    required this.quality,
    required this.requiredMask,
    this.optionalMask = 0,
    this.penaltyMask = 0,
    this.requiresExactMatch = false,
    this.allowsMissingRoot = false,
  });

  ChordTemplate.fromIntervals(
    ChordQualityIntervals intervals, {
    required this.penaltyMask,
    this.requiresExactMatch = false,
    this.allowsMissingRoot = false,
  }) : quality = intervals.quality,
       requiredMask = intervals.templateRequiredMask,
       optionalMask = intervals.omittableMask;

  int get baseMask => requiredMask | optionalMask;
}

// ---- Interval meanings -----------------------------------------------
// Interval identity is canonical; chord-function aliases are contextual.
//
// 0  = P1  unison / root
// 1  = m2  (functional alias: b9; enharmonic spelling: A1)
// 2  = M2  (functional alias: 9)
// 3  = m3  (functional alias: #9 in dominant context)
// 4  = M3
// 5  = P4  (functional alias: 11)
// 6  = tritone (A4 / d5; functional aliases: #11 or b5)
// 7  = P5
// 8  = m6  (enharmonic: A5; functional alias: b13; also "#5" in augmented context)
// 9  = M6  (functional alias: 13; enharmonic: d7 is rare; avoid as primary name)
// 10 = m7  (functional alias: b7 / "dominant 7")
// 11 = M7

// Note: P1 is always enforced by the analyzer, not templates.
// Note: m2 is handled as an extension, not in base templates.

/// Template list (ordered for clarity, not cost priority).
///
/// The analyzer tests all templates; order doesn't affect results.
/// Organized by complexity: triads -> 6ths -> 7ths
///
/// NOTE: https://whatchord.earthmanmuons.com/articles/chord-recognition-algorithm.html lists and
/// describes each template. Update the article when templates are added,
/// removed, or changed.
final chordTemplates = <ChordTemplate>[
  // Major triad: R + M3 + (P5)
  // - M3 defines major quality
  // - P5 optional for sparse voicings
  // - Penalty: m3, b7, M7 (would suggest minor/seventh chords)
  ChordTemplate.fromIntervals(
    ChordQuality.major.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval),
  ),

  // Major flat 5: R + M3 + b5
  // - M3 defines major quality; b5 replaces the perfect fifth
  // - No optional tones (all three intervals are the chord)
  // - Penalty: P5 (contradicts b5), m3 (contradicts major), b7/M7 (would suggest seventh chords)
  ChordTemplate.fromIntervals(
    ChordQuality.majorFlat5.intervals,
    penaltyMask:
        (1 << perfectFifthInterval) |
        (1 << minorThirdInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval),
  ),

  // Minor triad: R + m3 + (P5)
  // - m3 defines minor quality
  // - Penalty: M3, b7, M7 (would suggest major/seventh chords)
  ChordTemplate.fromIntervals(
    ChordQuality.minor.intervals,
    penaltyMask:
        (1 << majorThirdInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval),
  ),

  // Minor sharp 5: R + m3 + #5
  // - m3 + #5 define the altered minor color
  // - No optional tones; the altered fifth is the distinguishing tone
  // - Penalty: M3, P5, b7, M7 (would suggest other minor/seventh qualities)
  ChordTemplate.fromIntervals(
    ChordQuality.minorSharp5.intervals,
    penaltyMask:
        (1 << majorThirdInterval) |
        (1 << perfectFifthInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval),
  ),

  // Diminished triad: R + m3 + b5
  // - m3 + b5 define diminished quality
  // - No optional tones (tight structure)
  // - Penalty: M3, P5 (would contradict diminished quality)
  ChordTemplate.fromIntervals(
    ChordQuality.diminished.intervals,
    penaltyMask: (1 << majorThirdInterval) | (1 << perfectFifthInterval),
  ),

  // Augmented triad: R + M3 + #5
  // - M3 + #5 define augmented quality
  // - No optional tones (symmetric structure)
  // - Penalty: m3, P5 (would contradict augmented quality)
  ChordTemplate.fromIntervals(
    ChordQuality.augmented.intervals,
    penaltyMask: (1 << minorThirdInterval) | (1 << perfectFifthInterval),
  ),

  // Power chord: R + P5, no third at all
  // - The bare fifth is the chord; a third resolves it to major/minor, a
  //   seventh belongs to a (possibly shell) seventh chord, and tritone or
  //   sixth colors imply other harmony, so all are penalties rather than
  //   color
  // - Second and fourth extras stay nameable so sparse fifth-plus-color
  //   voicings can be read directly (C-Db-G as C5(addb9))
  ChordTemplate.fromIntervals(
    ChordQuality.power.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << majorThirdInterval) |
        (1 << diminishedFifthInterval) |
        (1 << minorSixthInterval) |
        (1 << majorSixthInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval),
  ),

  // Sus2: R + M2 + P5
  // - Replaces third with major second (suspended harmony)
  // - P5 required (standard triad definition; prevents ambiguous two-note matches)
  // - Penalty: any third (would resolve the suspension) or seventh (would suggest 7sus2)
  ChordTemplate.fromIntervals(
    ChordQuality.sus2.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << majorThirdInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval),
  ),

  // Sus4: R + P4 + P5
  // - Replaces third with perfect fourth (suspended harmony)
  // - P5 required (standard triad definition)
  // - Penalty: any third (would resolve the suspension) or seventh (would suggest 7sus4)
  ChordTemplate.fromIntervals(
    ChordQuality.sus4.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << majorThirdInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval),
  ),

  // Sus2sus4: R + M2 + P4 + P5
  // - Both suspended tones replace the third
  // - Exact match prevents incomplete or extended double-sus readings
  ChordTemplate.fromIntervals(
    ChordQuality.sus2sus4.intervals,
    penaltyMask: 0,
    requiresExactMatch: true,
  ),

  // Major 6th: R + M3 + (P5) + 6
  // - Major third + major sixth
  // - P5 optional (like other major-family chords)
  // - Penalty: b7/M7 (ambiguous with inverted minor7/major7)
  //            m3 (would suggest minor6)
  ChordTemplate.fromIntervals(
    ChordQuality.major6.intervals,
    penaltyMask:
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval) |
        (1 << minorThirdInterval),
  ),

  // Minor 6th: R + m3 + (P5) + 6
  // - Minor third + major sixth
  // - P5 optional
  // - Penalty: b7/M7 (ambiguous with seventh chords)
  //            M3 (would suggest major6)
  ChordTemplate.fromIntervals(
    ChordQuality.minor6.intervals,
    penaltyMask:
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval) |
        (1 << majorThirdInterval),
  ),

  // Dominant 7th: R + M3 + (P5) + b7
  // - Major third + minor seventh (dominant function)
  // - P5 optional (shell voicing: R-3-b7)
  // - Penalty: M7 (would suggest major7), m3 (would suggest minor7)
  ChordTemplate.fromIntervals(
    ChordQuality.dominant7.intervals,
    penaltyMask: (1 << majorSeventhInterval) | (1 << minorThirdInterval),
    allowsMissingRoot: true,
  ),

  // 7sus2: R + M2 + (P5) + b7
  // - Suspended second replaces the third in a dominant seventh context
  // - P5 optional (common voicings omit it: R-2-b7)
  // - Penalty: any third (would resolve suspension), P4 (sus4), M7
  ChordTemplate.fromIntervals(
    ChordQuality.dominant7sus2.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << majorThirdInterval) |
        (1 << perfectFourthInterval) |
        (1 << majorSeventhInterval),
  ),

  // 7sus4: R + P4 + (P5) + b7
  // - Dominant seventh with suspended 4th
  // - P5 optional (common voicings omit it: R-4-b7)
  // - Penalty: any third (would resolve suspension), M7 (would suggest maj7 color)
  ChordTemplate.fromIntervals(
    ChordQuality.dominant7sus4.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << majorThirdInterval) |
        (1 << majorSeventhInterval),
  ),

  // Dominant 7 flat 5: R + M3 + b5 + b7
  // - Diminished fifth is a defining chord tone, not a #11 color
  // - Penalty: P5 (would suggest plain dominant7), M7, m3
  ChordTemplate.fromIntervals(
    ChordQuality.dominant7Flat5.intervals,
    penaltyMask:
        (1 << perfectFifthInterval) |
        (1 << majorSeventhInterval) |
        (1 << minorThirdInterval),
  ),

  // Dominant 7 sharp 5: R + M3 + #5 + b7
  // - Augmented fifth is a defining chord tone, not a b13 color
  // - Penalty: P5 (would suggest plain dominant7), M7, m3
  ChordTemplate.fromIntervals(
    ChordQuality.dominant7Sharp5.intervals,
    penaltyMask:
        (1 << perfectFifthInterval) |
        (1 << majorSeventhInterval) |
        (1 << minorThirdInterval),
  ),

  // Major 7th: R + M3 + (P5) + M7
  // - Major third + major seventh (stable, color chord)
  // - P5 optional
  // - Penalty: b7 (would suggest dominant7), m3 (would suggest minor-major7)
  ChordTemplate.fromIntervals(
    ChordQuality.major7.intervals,
    penaltyMask: (1 << minorSeventhInterval) | (1 << minorThirdInterval),
    allowsMissingRoot: true,
  ),

  // Major 7 suspended 2: R + M2 + (P5) + M7
  // - Suspended second replaces the third in a major seventh context
  // - P5 optional
  // - Penalty: any third (would resolve suspension), P4 (sus4), b7
  ChordTemplate.fromIntervals(
    ChordQuality.major7sus2.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << majorThirdInterval) |
        (1 << perfectFourthInterval) |
        (1 << minorSeventhInterval),
  ),

  // Major 7 suspended 4: R + P4 + (P5) + M7
  // - Suspended fourth replaces the third in a major seventh context
  // - P5 optional
  // - Penalty: any third (would resolve suspension), b7
  // - M2 is allowed as natural ninth color, e.g. maj9sus4
  ChordTemplate.fromIntervals(
    ChordQuality.major7sus4.intervals,
    penaltyMask:
        (1 << minorThirdInterval) |
        (1 << majorThirdInterval) |
        (1 << minorSeventhInterval),
  ),

  // Major 7 flat 5: R + M3 + b5 + M7
  // - Diminished fifth is a defining chord tone, not a #11 color
  // - Penalty: P5 (would suggest plain major7), b7, m3
  ChordTemplate.fromIntervals(
    ChordQuality.major7Flat5.intervals,
    penaltyMask:
        (1 << perfectFifthInterval) |
        (1 << minorSeventhInterval) |
        (1 << minorThirdInterval),
  ),

  // Major 7 sharp 5: R + M3 + #5 + M7
  // - Augmented major seventh color, common as maj7#5
  // - Penalty: P5 (would suggest plain major7), b7, m3
  ChordTemplate.fromIntervals(
    ChordQuality.major7Sharp5.intervals,
    penaltyMask:
        (1 << perfectFifthInterval) |
        (1 << minorSeventhInterval) |
        (1 << minorThirdInterval),
  ),

  // Minor 7th: R + m3 + (P5) + b7
  // - Minor third + minor seventh (subdominant/tonic function)
  // - P5 optional
  // - Penalty: M7 (would suggest minor-major7), M3 (would suggest dominant7)
  ChordTemplate.fromIntervals(
    ChordQuality.minor7.intervals,
    penaltyMask: (1 << majorSeventhInterval) | (1 << majorThirdInterval),
    allowsMissingRoot: true,
  ),

  // Minor 7 sharp 5: R + m3 + #5 + b7
  // - Augmented fifth is a defining chord tone, not a b13 color
  // - Penalty: P5 (would suggest plain minor7), M7, M3
  ChordTemplate.fromIntervals(
    ChordQuality.minor7Sharp5.intervals,
    penaltyMask:
        (1 << perfectFifthInterval) |
        (1 << majorSeventhInterval) |
        (1 << majorThirdInterval),
  ),

  // Minor-major 7th: R + m3 + (P5) + M7
  // - Minor third + major seventh (tonic minor color chord)
  // - P5 optional (shell voicings)
  // - Penalty: M3 (contradicts m3), b7 (would suggest minor7)
  ChordTemplate.fromIntervals(
    ChordQuality.minorMajor7.intervals,
    penaltyMask: (1 << majorThirdInterval) | (1 << minorSeventhInterval),
    allowsMissingRoot: true,
  ),

  // Half-diminished 7th: R + m3 + b5 + b7
  // - Minor third + diminished fifth + minor seventh
  // - No optional tones (all intervals define the quality)
  // - Penalty: P5 (contradicts b5), M3 (contradicts m3), M7 (contradicts b7)
  ChordTemplate.fromIntervals(
    ChordQuality.halfDiminished7.intervals,
    penaltyMask:
        (1 << perfectFifthInterval) |
        (1 << majorThirdInterval) |
        (1 << majorSeventhInterval),
    allowsMissingRoot: true,
  ),

  // Fully diminished 7th: R + m3 + b5 + d7 (enharmonic M6)
  // - Symmetrical: stacked minor thirds (R - m3 - b5 - d7)
  // - The top tone is spelled as diminished 7th in theory, but is pitch-class = M6 (9 semitones)
  // - No optional tones (tight, symmetrical structure)
  // - Penalty: b7 (would suggest half-diminished), P5/M3/M7 (contradict structure)
  // - Never allowsMissingRoot: a rootless dim7 has four equally valid roots
  ChordTemplate.fromIntervals(
    ChordQuality.diminished7.intervals,
    penaltyMask:
        (1 << minorSeventhInterval) |
        (1 << perfectFifthInterval) |
        (1 << majorThirdInterval) |
        (1 << majorSeventhInterval),
  ),
];
