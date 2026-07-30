import 'dart:math' as math;

import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';

/// Model-neutral plumbing shared by the detectors. Model behavior (scoring,
/// profiles, tilts) stays in each detector; only the mechanics live here.

/// Exponential-decay clock: tracks the last event timestamp and yields the
/// factor by which accumulated state should decay.
///
/// With [halfLifeEvents] set, state decays by a fixed factor per event,
/// normalizing the memory dial across corpora with different event rates
/// (log entry 2026-07-07-15). That mode is retained for research reproduction
/// and is not selected by the app. Otherwise [halfLife] decays on elapsed
/// wall-clock time; null disables decay.
class DecayClock {
  final Duration? halfLife;

  /// **App status: Disabled.**
  ///
  /// Event-count decay is retained for research reproduction. The app leaves
  /// this null and uses elapsed-time behavior presets.
  final double? halfLifeEvents;
  DateTime? _last;

  DecayClock({required this.halfLife, required this.halfLifeEvents});

  void reset() {
    _last = null;
  }

  /// Advances the clock to [timestamp] and returns the decay factor to apply,
  /// or null when no decay is due (first event, decay disabled, or no time
  /// elapsed).
  double? advance(DateTime timestamp) {
    final last = _last;
    _last = timestamp;
    if (last == null) return null;
    final eventHalfLife = halfLifeEvents;
    if (eventHalfLife != null) {
      return math.pow(0.5, 1 / eventHalfLife) as double;
    }
    final duration = halfLife;
    if (duration == null) return null;
    final elapsedMs = timestamp.difference(last).inMilliseconds;
    if (elapsedMs <= 0) return null;
    return math.pow(0.5, elapsedMs / duration.inMilliseconds) as double;
  }
}

/// Recognizer confidence in the chord identity: 1.0 for an uncontested
/// identification, scaling down to 0.0 as the best-to-second cost gap closes
/// to a dead tie relative to the ranking near-tie window.
double identityConfidence(ChordEvent event) {
  if (event.candidates.length < 2) return 1.0;
  final gap = event.candidates[1].cost - event.candidates.first.cost;
  return (gap / ChordCandidateRanking.nearTieWindow).clamp(0.0, 1.0);
}

/// The shared claim epilogue: abstains until [minEvents] events have arrived
/// and whenever the confidence margin between the top two keys falls below
/// [marginFloor]; otherwise claims the top key.
///
/// Score-based detectors pass [requirePositiveTop] so a non-positive top
/// score abstains rather than claiming on the least-bad key.
KeyEstimateFrame claimOrAbstain(
  List<KeyEstimate> ranked, {
  required int eventCount,
  required int minEvents,
  required double marginFloor,
  bool requirePositiveTop = false,
}) {
  if (ranked.isEmpty || eventCount < minEvents) {
    return KeyEstimateFrame.abstain(ranked);
  }
  final margin = ranked.length < 2
      ? double.infinity
      : ranked[0].confidence - ranked[1].confidence;
  if ((requirePositiveTop && ranked[0].confidence <= 0) ||
      margin < marginFloor) {
    return KeyEstimateFrame.abstain(ranked);
  }
  return KeyEstimateFrame(ranked: ranked, claim: ranked.first);
}
