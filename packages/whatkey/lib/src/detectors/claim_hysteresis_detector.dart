import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'key_detector.dart';

/// **App status: Research-only.**
///
/// Requiring repeated winning claims reduced some brief switches but delayed
/// real key changes, so the shipped HMM is not wrapped in this detector. It
/// remains implemented, tested, and available to the research harness for
/// reproducibility (research log 2026-07-07-07).
///
/// Claim-level hysteresis around any detector: a different key must win for
/// [minStreak] consecutive claiming frames before the output claim switches.
///
/// This is the same pending-challenger idea as the history capture debounce,
/// applied to key claims: a one-frame blip to another key (a tonicization, a
/// noisy event) does not switch the claim, while a real modulation switches
/// after [minStreak] frames, costing `minStreak - 1` events of lag. While a
/// challenger is pending, the output keeps claiming the committed key at the
/// inner detector's current confidence for it. Inner abstentions pass through
/// as abstentions (the wrapper never invents claims) and reset the
/// challenger's streak, but leave the committed key in place.
class ClaimHysteresisDetector implements KeyDetector {
  /// The wrapped detector whose claims are debounced.
  final KeyDetector inner;

  /// Consecutive claiming frames a challenger key needs to take over.
  final int minStreak;

  Tonality? _committed;
  Tonality? _challenger;
  int _challengerStreak = 0;

  ClaimHysteresisDetector({required this.inner, this.minStreak = 2})
    : assert(minStreak >= 1);

  @override
  String get name => '${inner.name}+hysteresis';

  @override
  String get configuration =>
      'minStreak=$minStreak | inner: ${inner.configuration}';

  @override
  void reset() {
    inner.reset();
    _committed = null;
    _challenger = null;
    _challengerStreak = 0;
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    final frame = inner.onEvent(event);
    final innerClaim = frame.claim;

    if (innerClaim == null) {
      _challenger = null;
      _challengerStreak = 0;
      return frame;
    }

    if (_committed == null) {
      _committed = _commitFirst(innerClaim.tonality);
      return _committed == null
          ? KeyEstimateFrame.abstain(frame.ranked)
          : frame;
    }
    if (innerClaim.tonality == _committed) {
      _challenger = null;
      _challengerStreak = 0;
      return frame;
    }

    if (innerClaim.tonality == _challenger) {
      _challengerStreak += 1;
    } else {
      _challenger = innerClaim.tonality;
      _challengerStreak = 1;
    }
    if (_challengerStreak >= minStreak) {
      _committed = _challenger;
      _challenger = null;
      _challengerStreak = 0;
      return frame;
    }

    // Challenger still pending: keep claiming the committed key at the inner
    // detector's current confidence in it.
    final committed = _committed!;
    for (final estimate in frame.ranked) {
      if (estimate.tonality == committed) {
        return KeyEstimateFrame(ranked: frame.ranked, claim: estimate);
      }
    }
    return KeyEstimateFrame.abstain(frame.ranked);
  }

  /// The first-ever claim also waits out the streak, so a noisy opening does
  /// not commit instantly; with `minStreak = 1` this commits immediately.
  Tonality? _commitFirst(Tonality tonality) {
    if (tonality == _challenger) {
      _challengerStreak += 1;
    } else {
      _challenger = tonality;
      _challengerStreak = 1;
    }
    if (_challengerStreak >= minStreak) {
      _challenger = null;
      _challengerStreak = 0;
      return tonality;
    }
    return null;
  }
}
