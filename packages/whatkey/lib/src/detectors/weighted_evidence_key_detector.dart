import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'detector_support.dart';
import 'key_detector.dart';
import 'key_space.dart';

/// **App status: Research-only.**
///
/// The app does not construct this detector. `HybridKeyDetector` creates it only
/// when a research configuration explicitly supplies a nonzero functional
/// blend. It remains implemented and tested for reproduction and ablation.
///
/// Weighted evidence key detection (design plan section 2d): the first model
/// that uses chord identities and recognizer confidence rather than pitch
/// classes alone.
///
/// Maintains a running score per key, updated incrementally per event with
/// small musician-like rules: diatonic roots and fully diatonic chords add
/// points, chromatic tones subtract, and the two strongest single-chord
/// functions (a dominant-family chord on the fifth degree, a diminished chord
/// on the leading tone) add a bonus for their tonic. Scores decay on elapsed
/// time so old evidence fades.
///
/// Minor keys are scored against the union of natural and harmonic minor,
/// mirroring `ScaleDegreeClassifier`'s sources: in A minor, E7's G# is
/// diatonic evidence for the key, not a chromatic penalty (the natural-minor
/// trap the design plan warns about).
///
/// Each event's contribution is weighted by hold duration and, when
/// [confidenceWeighted] is on, by the recognizer's confidence in the chord
/// identity: the best-to-second explanation-cost gap measured against the
/// ranking near-tie window, so ambiguous identifications carry less weight.
class WeightedEvidenceKeyDetector implements KeyDetector {
  /// Points for a chord root that is a scale degree of the key.
  final double rootDiatonicPoints;

  /// Points for a tonic-degree chord with a home quality (the tonic set
  /// includes dominant7 in major, so a blues I7 can be home evidence rather
  /// than only V-of-IV). Default 0: at +4 and +2 it failed to flip blues
  /// while regressing the modulating-chain probe and the corpus, because a
  /// per-event tonic reward strengthens whatever key the current chord could
  /// be tonic of and so fights modulation tracking (log entry 2026-07-07-11).
  /// Kept as an ablatable parameter.
  final double tonicBonusPoints;

  /// Points when every sounding pitch class fits the key's scale.
  final double allTonesDiatonicPoints;

  /// Points subtracted per sounding pitch class outside the key's scale.
  final double chromaticPenaltyPoints;

  /// Tonic bonus for a dominant-seventh-family chord on the fifth degree.
  final double dominantBonusPoints;

  /// Smaller tonic bonus for a plain major triad on the fifth degree: still
  /// dominant function, but without the tritone that pins it (design plan
  /// section 2e). This is also what separates C major from A minor on a
  /// diatonic pop loop, where every chord fits both keys and only the G triad
  /// points at C.
  final double dominantTriadBonusPoints;

  /// Tonic bonus for a diminished-family chord on the leading tone.
  final double leadingToneBonusPoints;

  /// Whether an event's evidence is weighted by recognizer confidence.
  final bool confidenceWeighted;

  /// Whether an event's evidence is weighted by how long it was held.
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
  double _weightMass = 0;
  int _eventCount = 0;
  late final DecayClock _decay = DecayClock(
    halfLife: decayHalfLife,
    halfLifeEvents: decayHalfLifeEvents,
  );

  WeightedEvidenceKeyDetector({
    this.rootDiatonicPoints = 2,
    this.tonicBonusPoints = 0,
    this.allTonesDiatonicPoints = 3,
    this.chromaticPenaltyPoints = 1,
    this.dominantBonusPoints = 4,
    this.dominantTriadBonusPoints = 2,
    this.leadingToneBonusPoints = 3,
    this.confidenceWeighted = true,
    this.durationWeighted = true,
    this.decayHalfLife = const Duration(seconds: 30),
    this.decayHalfLifeEvents,
    this.minEvents = 3,
    this.marginFloor = 0.5,
  });

  @override
  String get name => 'weighted-evidence';

  @override
  String get configuration =>
      'points=$rootDiatonicPoints/$tonicBonusPoints/$allTonesDiatonicPoints/'
      '-$chromaticPenaltyPoints/$dominantBonusPoints/'
      '$dominantTriadBonusPoints/$leadingToneBonusPoints '
      'confidenceWeighted=$confidenceWeighted '
      'durationWeighted=$durationWeighted '
      'decayHalfLifeMs=${decayHalfLife?.inMilliseconds} '
      'decayHalfLifeEvents=$decayHalfLifeEvents '
      'minEvents=$minEvents marginFloor=$marginFloor';

  @override
  void reset() {
    _scores.fillRange(0, 24, 0);
    _weightMass = 0;
    _eventCount = 0;
    _decay.reset();
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    final decay = _decay.advance(event.timestamp);
    if (decay != null) _applyDecay(decay);
    _eventCount += 1;

    final weight = _eventWeight(event);
    if (weight > 0) {
      final identity = event.identity;
      final pcMask = event.input.pcMask;
      final tonalities = KeySpace.canonicalTonalities;
      for (var k = 0; k < 24; k++) {
        _scores[k] += weight * _points(tonalities[k], identity, pcMask);
      }
      _weightMass += weight;
    }

    final ranked = _rankKeys();
    return claimOrAbstain(
      ranked,
      eventCount: _eventCount,
      minEvents: minEvents,
      marginFloor: marginFloor,
      requirePositiveTop: true,
    );
  }

  double _points(Tonality tonality, ChordIdentity identity, int pcMask) {
    final scaleMask = KeySpace.scaleMask(tonality);
    var points = 0.0;

    if (scaleMask & (1 << identity.rootPc) != 0) {
      points += rootDiatonicPoints;
    }

    final chromatic = popCount(pcMask & ~scaleMask);
    if (chromatic == 0) {
      points += allTonesDiatonicPoints;
    } else {
      points -= chromaticPenaltyPoints * chromatic;
    }

    final rootInterval = (identity.rootPc - tonality.tonicPitchClass + 12) % 12;
    if (rootInterval == 0 &&
        KeySpace.tonicQualities(tonality).contains(identity.quality)) {
      points += tonicBonusPoints;
    }
    if (rootInterval == 7 && _dominantFamily.contains(identity.quality)) {
      points += dominantBonusPoints;
    }
    if (rootInterval == 7 && identity.quality == ChordQuality.major) {
      points += dominantTriadBonusPoints;
    }
    if (rootInterval == 11 && _leadingToneFamily.contains(identity.quality)) {
      points += leadingToneBonusPoints;
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
    _weightMass *= factor;
  }

  List<KeyEstimate> _rankKeys() {
    if (_weightMass <= 0) return const [];
    final tonalities = KeySpace.canonicalTonalities;
    final estimates = <KeyEstimate>[
      // Confidence is points per weighted event, so it is scale-free across
      // stream lengths and decay states.
      for (var k = 0; k < 24; k++)
        KeyEstimate(
          tonality: tonalities[k],
          confidence: _scores[k] / _weightMass,
        ),
    ];
    estimates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return estimates;
  }

  static const Set<ChordQuality> _dominantFamily = KeySpace.dominantQualities;

  static const Set<ChordQuality> _leadingToneFamily = {
    ChordQuality.diminished,
    ChordQuality.halfDiminished7,
    ChordQuality.diminished7,
  };
}
