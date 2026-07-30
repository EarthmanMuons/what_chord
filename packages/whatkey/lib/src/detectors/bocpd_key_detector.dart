import 'dart:math' as math;

import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'detector_support.dart';
import 'hmm_key_detector.dart';
import 'key_detector.dart';
import 'key_profiles.dart';
import 'key_space.dart';
import 'rotated_correlation.dart';

/// **App status: Research-only.**
///
/// This alternative was built and measured but did not beat the HMM at the
/// shipped stability target. It remains implemented, tested, and available to
/// the research harness so the negative result can be reproduced (research log
/// 2026-07-07-26).
///
/// Bayesian online changepoint detection over the 24-key space (Adams &
/// MacKay 2007, arXiv:0710.3742; design plan, future model directions):
/// maintains a posterior over the current key section's run length, so
/// evidence pools back exactly to the inferred section start instead of
/// through a fixed decay window.
///
/// Model: sections begin at changepoints drawn per event with constant
/// [hazard] (a geometric section-length prior, the same dwell family the HMM's
/// self-transition implies; what differs is the evidence window, not the
/// dwell). Within a run the key is constant with a uniform prior; each event
/// contributes an independent likelihood per key, the softmax at
/// [emissionTemperature] of the event's own profile correlation, with the
/// shipped mode tilt applied (log entry 2026-07-07-23). Per run length the
/// accumulated log-likelihoods give a run-conditional key posterior; the
/// claim is the run-marginal key posterior, abstaining under [marginFloor]
/// exactly like the HMM.
///
/// Run lengths are truncated at [maxRunLength] by folding the tail into the
/// last bin, which bounds work per event at O(maxRunLength * 24).
class BocpdKeyDetector implements KeyDetector {
  /// Per-event changepoint probability; 1/64 puts the prior mean section
  /// length in the neighborhood the corpora show.
  static const double defaultHazard = 1 / 64;

  /// Run-length truncation bound; the tail folds into the last bin.
  static const int defaultMaxRunLength = 128;

  /// Pitch-class profiles scoring each event against the 24 keys.
  final KeyProfilePair profiles;

  /// Whether an event's evidence is weighted by how long it was held.
  final bool durationWeighted;

  /// Per-event changepoint probability (see [defaultHazard]).
  final double hazard;

  /// Maximum tracked run length (see [defaultMaxRunLength]).
  final int maxRunLength;

  /// Softmax temperature converting profile correlations into likelihoods.
  final double emissionTemperature;

  /// Parallel-pair mode tilt strength (see [HmmKeyDetector.defaultModeTilt]).
  final double modeTilt;

  /// Events required before the detector may claim a key.
  final int minEvents;

  /// Minimum posterior margin between the top two keys to claim; below it
  /// the detector abstains.
  final double marginFloor;

  /// Parallel lists indexed by run length: posterior weight and accumulated
  /// per-key log-likelihoods (shift-normalized; softmax is shift-invariant).
  final List<double> _runWeights = [];
  final List<List<double>> _runLogScores = [];
  int _eventCount = 0;

  BocpdKeyDetector({
    this.profiles = KeyProfilePair.albrechtShanahan,
    this.durationWeighted = true,
    this.hazard = defaultHazard,
    this.maxRunLength = defaultMaxRunLength,
    this.emissionTemperature = 0.25,
    this.modeTilt = HmmKeyDetector.defaultModeTilt,
    this.minEvents = 3,
    this.marginFloor = HmmKeyDetector.defaultMarginFloor,
  }) : assert(hazard > 0 && hazard < 1);

  @override
  String get name => 'bocpd';

  @override
  String get configuration =>
      'hazard=$hazard maxRunLength=$maxRunLength '
      'emissionTemperature=$emissionTemperature modeTilt=$modeTilt '
      'minEvents=$minEvents marginFloor=$marginFloor '
      'profiles=${profiles.name} durationWeighted=$durationWeighted';

  @override
  void reset() {
    _runWeights.clear();
    _runLogScores.clear();
    _eventCount = 0;
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    _eventCount += 1;
    final logLikelihood = _eventLogLikelihood(event);

    // Predictive probability of this event under each existing run, and
    // under a fresh run started by a changepoint (uniform key prior).
    final grown = List<double>.filled(_runWeights.length, 0);
    var changepointMass = 0.0;
    for (var r = 0; r < _runWeights.length; r++) {
      final posterior = _softmax(_runLogScores[r]);
      var predictive = 0.0;
      for (var k = 0; k < 24; k++) {
        predictive += posterior[k] * math.exp(logLikelihood[k]);
      }
      grown[r] = _runWeights[r] * (1 - hazard) * predictive;
      changepointMass += _runWeights[r] * hazard;
    }
    var newRunPredictive = 0.0;
    for (var k = 0; k < 24; k++) {
      newRunPredictive += math.exp(logLikelihood[k]) / 24;
    }
    final newRunWeight = _runWeights.isEmpty
        ? newRunPredictive
        : changepointMass * newRunPredictive;

    // Advance run states: every survivor absorbs this event's evidence.
    for (var r = 0; r < _runLogScores.length; r++) {
      final scores = _runLogScores[r];
      var top = double.negativeInfinity;
      for (var k = 0; k < 24; k++) {
        scores[k] += logLikelihood[k];
        if (scores[k] > top) top = scores[k];
      }
      for (var k = 0; k < 24; k++) {
        scores[k] -= top;
      }
    }
    _runWeights.insert(0, newRunWeight);
    _runLogScores.insert(0, List<double>.of(logLikelihood));
    for (var r = 0; r < grown.length; r++) {
      _runWeights[r + 1] = grown[r];
    }
    if (_runWeights.length > maxRunLength) {
      final tail = _runWeights.removeLast();
      _runLogScores.removeLast();
      _runWeights[_runWeights.length - 1] += tail;
    }
    var total = 0.0;
    for (final weight in _runWeights) {
      total += weight;
    }
    if (total > 0) {
      for (var r = 0; r < _runWeights.length; r++) {
        _runWeights[r] /= total;
      }
    }

    // Run-marginal key posterior.
    final marginal = List<double>.filled(24, 0);
    for (var r = 0; r < _runWeights.length; r++) {
      final posterior = _softmax(_runLogScores[r]);
      for (var k = 0; k < 24; k++) {
        marginal[k] += _runWeights[r] * posterior[k];
      }
    }
    final ranked = [
      for (var k = 0; k < 24; k++)
        KeyEstimate(
          tonality: KeySpace.canonicalTonalities[k],
          confidence: marginal[k],
        ),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    return claimOrAbstain(
      ranked,
      eventCount: _eventCount,
      minEvents: minEvents,
      marginFloor: marginFloor,
    );
  }

  /// Per-key log-likelihood of one event: softmax at [emissionTemperature]
  /// of the event's own profile correlation, mode-tilted, raised to the
  /// event's duration weight.
  List<double> _eventLogLikelihood(ChordEvent event) {
    final histogram = List<double>.filled(12, 0);
    final mask = event.input.pcMask;
    for (var pc = 0; pc < 12; pc++) {
      if ((mask & (1 << pc)) != 0) histogram[pc] = 1;
    }
    final histogramStats = VectorStats.of(histogram);
    final scores = List<double>.filled(24, 0);
    for (var k = 0; k < 24; k++) {
      final tonality = KeySpace.canonicalTonalities[k];
      scores[k] = rotatedCorrelation(
        histogramStats,
        VectorStats.ofProfile(
          tonality.isMajor ? profiles.major : profiles.minor,
        ),
        tonality.tonicPitchClass,
      );
    }
    final top = scores.reduce(math.max);
    final likelihood = List<double>.filled(24, 0);
    var total = 0.0;
    for (var k = 0; k < 24; k++) {
      likelihood[k] = math.exp((scores[k] - top) / emissionTemperature);
      total += likelihood[k];
    }
    for (var k = 0; k < 24; k++) {
      likelihood[k] /= total;
    }
    _applyModeTilt(likelihood, event);
    final weight = durationWeighted
        ? math.max(event.duration.inMilliseconds / 1000.0, 0.1)
        : 1.0;
    return [for (final p in likelihood) weight * math.log(p)];
  }

  /// Same within-parallel-pair redistribution as the shipped HMM (log entry
  /// 2026-07-07-23); duplicated to keep the detectors decoupled.
  void _applyModeTilt(List<double> likelihood, ChordEvent event) {
    if (modeTilt == 0) return;
    final quality = event.identity.quality;
    final int direction;
    if (KeySpace.majorTonicQualities.contains(quality)) {
      direction = 1;
    } else if (KeySpace.minorTonicQualities.contains(quality)) {
      direction = -1;
    } else {
      return;
    }
    final majorK = KeySpace.majorIndex(event.identity.rootPc);
    final minorK = KeySpace.minorIndex(event.identity.rootPc);
    final pairSum = likelihood[majorK] + likelihood[minorK];
    if (pairSum == 0) return;
    final factor = math.exp(modeTilt * direction);
    final major = likelihood[majorK] * factor;
    final minor = likelihood[minorK] / factor;
    final rescale = pairSum / (major + minor);
    likelihood[majorK] = major * rescale;
    likelihood[minorK] = minor * rescale;
  }

  static List<double> _softmax(List<double> logScores) {
    var top = double.negativeInfinity;
    for (final value in logScores) {
      if (value > top) top = value;
    }
    final result = List<double>.filled(logScores.length, 0);
    var total = 0.0;
    for (var i = 0; i < logScores.length; i++) {
      result[i] = math.exp(logScores[i] - top);
      total += result[i];
    }
    for (var i = 0; i < result.length; i++) {
      result[i] /= total;
    }
    return result;
  }
}
