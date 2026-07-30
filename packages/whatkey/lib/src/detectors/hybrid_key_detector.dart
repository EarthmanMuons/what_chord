import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'detector_support.dart';
import 'key_detector.dart';
import 'key_profiles.dart';
import 'key_space.dart';
import 'profile_correlation_key_detector.dart';
import 'progression_key_detector.dart';
import 'weighted_evidence_key_detector.dart';

/// **App status: Shipped.**
///
/// Used inside `HmmKeyDetector` as its emission-scoring container. The shipped
/// HMM supplies zero functional and progression blends, so only the
/// profile-correlation term from this container reaches the HMM.
///
/// Hybrid key detection: profile correlation as the base score with the
/// weighted evidence model's functional points, and optionally the
/// progression detector's transition points, as adjustments.
///
/// The ingredients fail in complementary places (log entries 2026-07-07-03
/// and -04): histograms are robust on dense romantic harmony but blind to
/// function, so they lag modulations; the functional rules track cadences but
/// tie on purely diatonic or dominant-heavy stretches. Per key, the hybrid
/// score is
///
///   correlation
///     + functionalBlend * functional points per weighted event
///     + progressionBlend * progression points per weighted event
///
/// so profile shape breaks functional ties and functional evidence moves the
/// histogram's supertanker at key changes. With both blends at zero this
/// reduces exactly to pure profile correlation, the ablation anchor; each
/// term toggles independently per the protocol's ablation rules.
class HybridKeyDetector implements KeyDetector {
  /// **App status: Reproduction default.**
  ///
  /// These standalone defaults were selected before the HMM ablation (log
  /// entries 2026-07-07-04 and -08). The harness parse defaults reference them
  /// so historical recipes remain reproducible. `HmmKeyDetector` overrides both
  /// blends with zero for the shipped configuration.
  static const double defaultFunctionalBlend = 0.1;

  /// See [defaultFunctionalBlend].
  static const double defaultProgressionBlend = 0.02;

  final ProfileCorrelationKeyDetector _profile;
  final WeightedEvidenceKeyDetector _evidence;
  final ProgressionKeyDetector _progression;

  /// Weight of one functional point per weighted event, in correlation units.
  final double functionalBlend;

  /// Weight of one progression point per weighted event, in correlation
  /// units. Zero disables the progression term entirely.
  final double progressionBlend;

  /// Events required before the detector may claim a key.
  final int minEvents;

  /// Minimum blended-score margin between the top two keys to claim; below
  /// it the detector abstains.
  final double marginFloor;

  int _eventCount = 0;

  /// **App status: Reproduction default.**
  ///
  /// The constructor defaults reproduce the standalone hybrid research
  /// configuration. The shipped HMM overrides its non-shipped settings.
  HybridKeyDetector({
    KeyProfilePair profiles = KeyProfilePair.albrechtShanahan,
    bool durationWeighted = true,
    Duration? decayHalfLife = const Duration(seconds: 30),
    // App status: Disabled.
    //
    // Retained for the event-count decay ablation. The app leaves this null
    // and uses elapsed-time behavior presets.
    double? decayHalfLifeEvents,
    // The standalone research configuration weights recognizer confidence.
    // The shipped HMM explicitly disables it.
    bool confidenceWeighted = true,
    // Selected on the development split: the blend sweep plateaus at
    // 0.1-0.15 and the paired test against the profile floor is decisive
    // there (log entry 2026-07-07-04).
    this.functionalBlend = defaultFunctionalBlend,
    // Selected on the development split: paired coverage win at unchanged
    // accuracy, plus more modulations matched (log entry 2026-07-07-08).
    this.progressionBlend = defaultProgressionBlend,
    this.minEvents = 3,
    this.marginFloor = 0.05,
  }) : _profile = ProfileCorrelationKeyDetector(
         profiles: profiles,
         durationWeighted: durationWeighted,
         decayHalfLife: decayHalfLife,
         decayHalfLifeEvents: decayHalfLifeEvents,
         minEvents: 1,
         marginFloor: 0,
       ),
       _evidence = WeightedEvidenceKeyDetector(
         durationWeighted: durationWeighted,
         decayHalfLife: decayHalfLife,
         decayHalfLifeEvents: decayHalfLifeEvents,
         confidenceWeighted: confidenceWeighted,
         minEvents: 1,
         marginFloor: 0,
       ),
       _progression = ProgressionKeyDetector(
         durationWeighted: durationWeighted,
         decayHalfLife: decayHalfLife,
         decayHalfLifeEvents: decayHalfLifeEvents,
         confidenceWeighted: confidenceWeighted,
         minEvents: 1,
         marginFloor: 0,
       );

  @override
  String get name => 'hybrid';

  @override
  String get configuration =>
      'functionalBlend=$functionalBlend progressionBlend=$progressionBlend '
      'minEvents=$minEvents marginFloor=$marginFloor '
      '| profile: ${_profile.configuration} '
      '| evidence: ${_evidence.configuration} '
      '| progression: ${_progression.configuration}';

  @override
  void reset() {
    _profile.reset();
    _evidence.reset();
    _progression.reset();
    _eventCount = 0;
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    final profileFrame = _profile.onEvent(event);
    final evidenceFrame = _evidence.onEvent(event);
    final progressionFrame = _progression.onEvent(event);
    _eventCount += 1;

    final combined = <int, double>{};
    for (final estimate in profileFrame.ranked) {
      combined[KeySpace.index(estimate.tonality)] = estimate.confidence;
    }
    void blend(List<KeyEstimate> ranked, double factor) {
      if (factor == 0) return;
      for (final estimate in ranked) {
        combined.update(
          KeySpace.index(estimate.tonality),
          (base) => base + factor * estimate.confidence,
          ifAbsent: () => factor * estimate.confidence,
        );
      }
    }

    blend(evidenceFrame.ranked, functionalBlend);
    blend(progressionFrame.ranked, progressionBlend);
    if (combined.isEmpty) return const KeyEstimateFrame.abstain([]);

    final ranked = [
      // A tonality's position in canonicalTonalities equals its KeySpace
      // index, so the combined map's keys index the list directly.
      for (final entry in combined.entries)
        KeyEstimate(
          tonality: KeySpace.canonicalTonalities[entry.key],
          confidence: entry.value,
        ),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    return claimOrAbstain(
      ranked,
      eventCount: _eventCount,
      minEvents: minEvents,
      marginFloor: marginFloor,
      requirePositiveTop: true,
    );
  }
}
