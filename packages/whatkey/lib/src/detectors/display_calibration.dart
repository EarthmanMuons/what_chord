import 'dart:math' as math;

import '../models/key_estimate.dart';

/// Display-layer calibration of the key posterior (log entry 2026-07-08-03).
///
/// The detector's raw posterior is well ranked and well gated but numerically
/// overconfident (its emissions are deliberately sharpened, and nothing in
/// tuning rewarded literal probabilities). Any probability shown to the user
/// passes through temperature scaling: every probability is raised to
/// 1/[temperature] and renormalized. Monotone, so key order and the claim
/// itself never change; the detector's internal margins stay raw.
///
/// [temperature] was fit on the Isophonics development split (negative
/// log-likelihood argmin over exact-labeled events) and verified frozen on
/// the held-out test split: expected calibration error 0.192 raw to 0.041
/// calibrated, mean displayed confidence 0.76 against 0.72 accuracy. The
/// number is calibrated to section-scale correctness on pop material, the
/// question the key indicator answers; against local-scale analyst
/// labels it remains overconfident by design (the timescale trade).
///
/// NOTE: https://whatchord.earthmanmuons.com/articles/key-detection-algorithm.html
/// explains this step and quotes the raw-versus-calibrated gap. Update the
/// article when the temperature is refit or the scaling changes.
abstract final class DisplayCalibration {
  /// Temperature fitted on the held-out split for the shipped section-scale
  /// configuration.
  static const double temperature = 1.55;

  /// The [ranked] posterior with display calibration applied; order and
  /// relative ranking are preserved, and the result sums to one.
  static List<KeyEstimate> calibrate(
    List<KeyEstimate> ranked, {
    double temperature = temperature,
  }) {
    if (ranked.isEmpty || temperature == 1) return ranked;
    var total = 0.0;
    final scaled = <double>[
      for (final estimate in ranked)
        math.pow(estimate.confidence, 1 / temperature).toDouble(),
    ];
    for (final value in scaled) {
      total += value;
    }
    if (total <= 0) return ranked;
    return [
      for (var i = 0; i < ranked.length; i++)
        KeyEstimate(
          tonality: ranked[i].tonality,
          confidence: scaled[i] / total,
        ),
    ];
  }
}
