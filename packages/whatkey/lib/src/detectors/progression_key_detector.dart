import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'detector_support.dart';
import 'key_detector.dart';
import 'key_space.dart';

/// **App status: Research-only.**
///
/// The app does not construct this detector. `HybridKeyDetector` creates it only
/// when a research configuration explicitly supplies a nonzero progression
/// blend. It remains implemented and tested for reproduction and ablation.
///
/// Progression-pattern key detection (design plan section 2e): scores chord
/// _transitions_ instead of chord contents, because motion between functions
/// carries far more key information than any single sonority.
///
/// Per event, each of the 24 keys is scored for the patterns the latest
/// transition completes under that key's functional reading (function is
/// key-relative, so the same transition reads differently under each tonic
/// hypothesis):
///
/// - Authentic cadence: dominant-family on the fifth degree resolving to a
///   tonic-quality chord, the strongest single signal. A plain major triad on
///   V scores less (no tritone); a root-position resolution scores a bonus.
///   The tonic quality set includes dominant7 in major, so a blues I7 counts
///   as home rather than as V-of-IV.
/// - Leading-tone diminished resolving to the tonic.
/// - ii to V motion, plus a completion bonus when it lands as ii-V-I.
/// - Deceptive cadence (V to vi, major keys).
/// - Secondary-dominant resolution onto any diatonic degree.
/// - Bass falling a fifth onto the tonic, quality-independent.
///
/// - Plagal return (IV to I, including the blues IV7 to I7), the signal that
///   breaks the blues symmetry: I7 to IV7 reads as a cadence into the
///   subdominant key, and only the return home distinguishes the true tonic.
///
/// Scores decay on elapsed time; contributions are weighted by the resolving
/// event's hold duration and recognizer confidence, like the other detectors.
/// Unlike the per-event-normalized evidence model, confidence here is the
/// decayed weighted sum of pattern points: patterns are sparse, and a recent
/// cadence must keep its full vote until decay fades it rather than being
/// diluted by pattern-less transitions.
class ProgressionKeyDetector implements KeyDetector {
  /// Points for an authentic cadence with a seventh (V7 to tonic).
  final double cadencePoints;

  /// Points for an authentic cadence from a plain major triad on V.
  final double cadenceTriadPoints;

  /// Bonus when a cadence resolves with both chords in root position.
  final double rootPositionBonusPoints;

  /// Points for a leading-tone diminished chord resolving to the tonic.
  final double leadingTonePoints;

  /// Points for ii to V motion.
  final double iiToVPoints;

  /// Completion bonus when ii-V lands on I.
  final double iiVICompletionPoints;

  /// Points for a deceptive cadence (V to vi in major).
  final double deceptivePoints;

  /// Points for a plagal return (IV to I, including blues IV7 to I7).
  final double plagalPoints;

  /// Points for a secondary dominant resolving onto a diatonic degree.
  final double secondaryResolutionPoints;

  /// Points for the bass falling a fifth onto the tonic, any quality.
  final double bassFifthPoints;

  /// Whether pattern points are weighted by recognizer confidence.
  final bool confidenceWeighted;

  /// Whether pattern points are weighted by the resolving chord's hold
  /// duration.
  final bool durationWeighted;

  /// Score half-life; null disables decay.
  final Duration? decayHalfLife;

  /// **App status: Disabled.**
  ///
  /// Event-count half-life: when set, scores decay by a fixed factor per
  /// event instead of on elapsed wall-clock time, normalizing the memory
  /// dial across corpora with different event rates (log entry 2026-07-07-15).
  /// The app leaves it null.
  final double? decayHalfLifeEvents;

  /// Events required before the detector may claim a key.
  final int minEvents;

  /// Minimum score margin between the top two keys to claim; below it the
  /// detector abstains.
  final double marginFloor;

  final List<double> _scores = List.filled(24, 0);
  int _eventCount = 0;
  late final DecayClock _decay = DecayClock(
    halfLife: decayHalfLife,
    halfLifeEvents: decayHalfLifeEvents,
  );
  ChordIdentity? _previous;
  ChordIdentity? _previous2;

  ProgressionKeyDetector({
    this.cadencePoints = 5,
    this.cadenceTriadPoints = 3,
    this.rootPositionBonusPoints = 1,
    this.leadingTonePoints = 4,
    this.iiToVPoints = 2,
    this.iiVICompletionPoints = 3,
    this.deceptivePoints = 2,
    this.plagalPoints = 2,
    this.secondaryResolutionPoints = 1,
    this.bassFifthPoints = 1,
    this.confidenceWeighted = true,
    this.durationWeighted = true,
    this.decayHalfLife = const Duration(seconds: 30),
    this.decayHalfLifeEvents,
    this.minEvents = 3,
    this.marginFloor = 0.5,
  });

  @override
  String get name => 'progression';

  @override
  String get configuration =>
      'points=$cadencePoints/$cadenceTriadPoints/+$rootPositionBonusPoints/'
      '$leadingTonePoints/$iiToVPoints/$iiVICompletionPoints/'
      '$deceptivePoints/$plagalPoints/$secondaryResolutionPoints/'
      '$bassFifthPoints '
      'confidenceWeighted=$confidenceWeighted '
      'durationWeighted=$durationWeighted '
      'decayHalfLifeMs=${decayHalfLife?.inMilliseconds} '
      'decayHalfLifeEvents=$decayHalfLifeEvents '
      'minEvents=$minEvents marginFloor=$marginFloor';

  @override
  void reset() {
    _scores.fillRange(0, 24, 0);
    _eventCount = 0;
    _decay.reset();
    _previous = null;
    _previous2 = null;
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    final decay = _decay.advance(event.timestamp);
    if (decay != null) _applyDecay(decay);
    _eventCount += 1;

    final current = event.identity;
    final previous = _previous;
    final weight = _eventWeight(event);
    if (previous != null && weight > 0 && previous != current) {
      for (var k = 0; k < 24; k++) {
        _scores[k] +=
            weight *
            _transitionPoints(
              KeySpace.canonicalTonalities[k],
              _previous2,
              previous,
              current,
            );
      }
    }
    _previous2 = previous;
    _previous = current;

    final ranked = _rankKeys();
    return claimOrAbstain(
      ranked,
      eventCount: _eventCount,
      minEvents: minEvents,
      marginFloor: marginFloor,
      requirePositiveTop: true,
    );
  }

  double _transitionPoints(
    Tonality key,
    ChordIdentity? older,
    ChordIdentity from,
    ChordIdentity to,
  ) {
    final tonic = key.tonicPitchClass;
    int interval(int pc) => (pc - tonic + 12) % 12;
    final fromInterval = interval(from.rootPc);
    final toInterval = interval(to.rootPc);
    var points = 0.0;

    final toIsTonic =
        toInterval == 0 && KeySpace.tonicQualities(key).contains(to.quality);

    if (toIsTonic && fromInterval == 7) {
      if (_dominantFamily.contains(from.quality)) {
        points += cadencePoints;
      } else if (from.quality == ChordQuality.major) {
        points += cadenceTriadPoints;
      }
      if (points > 0 && !from.hasSlashBass && !to.hasSlashBass) {
        points += rootPositionBonusPoints;
      }
      // ii-V-I completion: the chord before the dominant sat on the second
      // degree with pre-dominant quality.
      if (older != null &&
          interval(older.rootPc) == 2 &&
          _predominantFamily.contains(older.quality)) {
        points += iiVICompletionPoints;
      }
    }

    if (toIsTonic &&
        fromInterval == 11 &&
        _leadingToneFamily.contains(from.quality)) {
      points += leadingTonePoints;
    }

    if (fromInterval == 2 &&
        toInterval == 7 &&
        _predominantFamily.contains(from.quality) &&
        (_dominantFamily.contains(to.quality) ||
            to.quality == ChordQuality.major)) {
      points += iiToVPoints;
    }

    if (toIsTonic &&
        fromInterval == 5 &&
        (from.quality == ChordQuality.major ||
            from.quality == ChordQuality.dominant7 ||
            from.quality == ChordQuality.minor)) {
      points += plagalPoints;
    }

    if (key.isMajor &&
        fromInterval == 7 &&
        toInterval == 9 &&
        _dominantFamily.contains(from.quality) &&
        (to.quality == ChordQuality.minor ||
            to.quality == ChordQuality.minor7)) {
      points += deceptivePoints;
    }

    // Any dominant falling a fifth onto a diatonic degree confirms the key's
    // functional fabric (secondary dominants resolving); the tonic landing is
    // already covered by the cadence rule above.
    if (!toIsTonic &&
        _dominantFamily.contains(from.quality) &&
        (from.rootPc - to.rootPc + 12) % 12 == 7 &&
        (KeySpace.scaleMask(key) & (1 << to.rootPc)) != 0) {
      points += secondaryResolutionPoints;
    }

    if (interval(from.bassPc) == 7 && interval(to.bassPc) == 0) {
      points += bassFifthPoints;
    }

    return points;
  }

  double _eventWeight(ChordEvent event) {
    var weight = durationWeighted
        ? event.duration.inMilliseconds / 1000.0
        : 1.0;
    if (confidenceWeighted) weight *= identityConfidence(event);
    return weight;
  }

  void _applyDecay(double factor) {
    for (var k = 0; k < 24; k++) {
      _scores[k] *= factor;
    }
  }

  List<KeyEstimate> _rankKeys() {
    if (_scores.every((score) => score == 0)) return const [];
    final estimates = <KeyEstimate>[
      for (var k = 0; k < 24; k++)
        KeyEstimate(
          tonality: KeySpace.canonicalTonalities[k],
          confidence: _scores[k],
        ),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));
    return estimates;
  }

  static const Set<ChordQuality> _dominantFamily = {
    ChordQuality.dominant7,
    ChordQuality.dominant7sus2,
    ChordQuality.dominant7sus4,
    ChordQuality.dominant7Flat5,
    ChordQuality.dominant7Sharp5,
  };

  /// Pre-dominant qualities on the second degree: ii/ii7 in major, ii°/ii-7b5
  /// in minor.
  static const Set<ChordQuality> _predominantFamily = {
    ChordQuality.minor,
    ChordQuality.minor7,
    ChordQuality.diminished,
    ChordQuality.halfDiminished7,
  };

  static const Set<ChordQuality> _leadingToneFamily = {
    ChordQuality.diminished,
    ChordQuality.diminished7,
    ChordQuality.halfDiminished7,
  };
}
