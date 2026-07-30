import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'detector_support.dart';
import 'key_detector.dart';
import 'key_profiles.dart';
import 'key_space.dart';
import 'rotated_correlation.dart';

/// **App status: Shipped.**
///
/// This supplies the pitch-class scores used by the shipped HMM through
/// `HybridKeyDetector`. The app lets `HmmKeyDetector` apply the posterior,
/// abstention rule, and behavior preset.
///
/// Profile-correlation key detection (Krumhansl-Schmuckler family): the floor
/// every later model must beat.
///
/// Maintains a 12-bin pitch-class histogram over the event stream and ranks
/// all 24 keys by Pearson correlation against a rotated key profile.
/// Weighting options follow the design plan: each event's pitch classes
/// contribute its hold duration (or a flat count), and the histogram decays
/// exponentially on elapsed time so older evidence fades regardless of
/// engagement boundaries.
///
/// Abstains until [minEvents] events have arrived, and whenever the
/// correlation margin between the best and second-best key falls below
/// [marginFloor]. Estimate confidence is the correlation coefficient.
class ProfileCorrelationKeyDetector implements KeyDetector {
  /// Pitch-class profiles the histogram correlates against.
  final KeyProfilePair profiles;

  /// Whether an event's pitch classes are weighted by hold duration.
  final bool durationWeighted;

  /// Histogram half-life; null disables decay.
  final Duration? decayHalfLife;

  /// **App status: Disabled.**
  ///
  /// Event-count half-life: when set, the histogram decays by a fixed factor
  /// per event instead of on elapsed wall-clock time, normalizing the memory
  /// dial across corpora with different event rates (log entry
  /// 2026-07-07-15). The app leaves it null and uses elapsed-time behavior
  /// presets.
  final double? decayHalfLifeEvents;

  /// Events required before the detector may claim a key.
  final int minEvents;

  /// Minimum correlation margin between the top two keys to claim; below it
  /// the detector abstains.
  final double marginFloor;

  final List<double> _histogram = List.filled(12, 0);
  int _eventCount = 0;
  late final DecayClock _decay = DecayClock(
    halfLife: decayHalfLife,
    halfLifeEvents: decayHalfLifeEvents,
  );

  /// **App status: Reproduction default.**
  ///
  /// The constructor defaults retain the standalone research baseline. The
  /// shipped HMM overrides the claim gate and supplies the app's behavior
  /// preset.
  ProfileCorrelationKeyDetector({
    this.profiles = KeyProfilePair.albrechtShanahan,
    this.durationWeighted = true,
    this.decayHalfLife = const Duration(seconds: 30),
    this.decayHalfLifeEvents,
    this.minEvents = 3,
    this.marginFloor = 0.05,
  });

  @override
  String get name => 'profile-correlation';

  @override
  String get configuration =>
      'profiles=${profiles.name} durationWeighted=$durationWeighted '
      'decayHalfLifeMs=${decayHalfLife?.inMilliseconds} '
      'decayHalfLifeEvents=$decayHalfLifeEvents '
      'minEvents=$minEvents marginFloor=$marginFloor';

  @override
  void reset() {
    _histogram.fillRange(0, 12, 0);
    _eventCount = 0;
    _decay.reset();
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    final decay = _decay.advance(event.timestamp);
    if (decay != null) _applyDecay(decay);
    _accumulate(event);
    _eventCount += 1;

    final ranked = _rankKeys();
    return claimOrAbstain(
      ranked,
      eventCount: _eventCount,
      minEvents: minEvents,
      marginFloor: marginFloor,
      requirePositiveTop: true,
    );
  }

  void _applyDecay(double factor) {
    for (var pc = 0; pc < 12; pc++) {
      _histogram[pc] *= factor;
    }
  }

  void _accumulate(ChordEvent event) {
    final weight = durationWeighted
        ? event.duration.inMilliseconds / 1000.0
        : 1.0;
    if (weight <= 0) return;
    final mask = event.input.pcMask;
    for (var pc = 0; pc < 12; pc++) {
      if ((mask & (1 << pc)) != 0) _histogram[pc] += weight;
    }
  }

  List<KeyEstimate> _rankKeys() {
    final stats = VectorStats.of(_histogram);
    if (stats.deviation == 0) return const [];

    final estimates = <KeyEstimate>[];
    for (final tonality in KeySpace.canonicalTonalities) {
      final profile = tonality.isMajor ? profiles.major : profiles.minor;
      estimates.add(
        KeyEstimate(
          tonality: tonality,
          confidence: rotatedCorrelation(
            stats,
            VectorStats.ofProfile(profile),
            tonality.tonicPitchClass,
          ),
        ),
      );
    }
    estimates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return estimates;
  }
}
