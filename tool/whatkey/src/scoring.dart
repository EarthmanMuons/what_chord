// Metric scaffolding for the WhatKey harness, per research/whatkey/PROTOCOL.md.
//
// Pinned rules implemented here: top-1 event-weighted scoring; the
// selective-prediction frame (coverage and accuracy-on-claimed as a pair,
// abstentions are never errors); switches counted between consecutive claims
// only; ambiguous-labeled events accept abstention or any acceptable key and
// stay out of accuracy pools.
//
// Provisional (deferred-to-freeze) definitions, implemented in their simplest
// form and reported as such: modulation lag is censored at the next annotated
// change or piece end; a switch is spurious when the annotated local key did
// not change between the two claims' events; global key reports both the
// final-event claim and the duration-weighted majority claim against the first
// annotated local key.

import 'dart:math' as math;

import 'package:whatkey/whatkey.dart';

import 'fixtures.dart';

/// MIREX near-miss weighting (see PROTOCOL.md references).
double mirexWeight(KeyLabel claim, KeyLabel truth) {
  if (claim.matches(truth)) return 1.0;
  final interval = (claim.tonicPc - truth.tonicPc + 12) % 12;
  if (claim.isMinor == truth.isMinor && (interval == 7 || interval == 5)) {
    return 0.5;
  }
  if (!truth.isMinor && claim.isMinor && interval == 9) return 0.3;
  if (truth.isMinor && !claim.isMinor && interval == 3) return 0.3;
  if (interval == 0) return 0.2;
  return 0.0;
}

class PieceScore {
  final String id;
  final String title;
  final int events;

  final int claimed;
  final int labeledClaimed;
  final double exactOnClaimed;
  final double mirexOnClaimed;

  final int ambiguousEvents;
  final int ambiguousOk;

  final int? timeToFirstClaim;
  final int switches;
  final int spuriousSwitches;

  final int annotatedChanges;
  final List<int> modulationLags;
  final int censoredModulations;

  final KeyLabel? globalTruth;
  final double? globalFinalMirex;
  final double? globalMajorityMirex;

  PieceScore._({
    required this.id,
    required this.title,
    required this.events,
    required this.claimed,
    required this.labeledClaimed,
    required this.exactOnClaimed,
    required this.mirexOnClaimed,
    required this.ambiguousEvents,
    required this.ambiguousOk,
    required this.timeToFirstClaim,
    required this.switches,
    required this.spuriousSwitches,
    required this.annotatedChanges,
    required this.modulationLags,
    required this.censoredModulations,
    required this.globalTruth,
    required this.globalFinalMirex,
    required this.globalMajorityMirex,
  });

  double get coverage => events == 0 ? 0 : claimed / events;

  /// Scores [frames] against the fixture's labels.
  ///
  /// With [evaluateMask], coverage, accuracy, and ambiguous-event metrics are
  /// computed over the masked-in events only (the matched-coverage
  /// comparison); streaming metrics (time-to-first-claim, switches, lag,
  /// global key) always use the full stream, since restricting them has no
  /// meaning.
  static PieceScore compute(
    LabeledFixture fixture,
    List<KeyEstimateFrame> frames, {
    List<bool>? evaluateMask,
  }) {
    assert(frames.length == fixture.events.length);
    assert(evaluateMask == null || evaluateMask.length == frames.length);
    final labels = fixture.labels;

    var evaluated = 0;
    var claimed = 0;
    var labeledClaimed = 0;
    var exactSum = 0.0;
    var mirexSum = 0.0;
    var ambiguousEvents = 0;
    var ambiguousOk = 0;
    int? timeToFirstClaim;

    final claims = <({int index, KeyLabel key})>[];
    for (var i = 0; i < frames.length; i++) {
      final claim = frames[i].claim;
      final truth = labels[i].localKey;
      if (claim != null) {
        timeToFirstClaim ??= i;
        claims.add((index: i, key: KeyLabel.of(claim.tonality)));
      }

      if (evaluateMask != null && !evaluateMask[i]) continue;
      evaluated += 1;
      if (labels[i].localKey == null && labels[i].acceptableKeys.isNotEmpty) {
        ambiguousEvents += 1;
        final ok =
            claim == null ||
            labels[i].acceptableKeys.any(
              (key) => key.matches(KeyLabel.of(claim.tonality)),
            );
        if (ok) ambiguousOk += 1;
      }
      if (claim == null) continue;
      claimed += 1;
      if (truth != null) {
        final claimKey = KeyLabel.of(claim.tonality);
        labeledClaimed += 1;
        exactSum += claimKey.matches(truth) ? 1 : 0;
        mirexSum += mirexWeight(claimKey, truth);
      }
    }

    var switches = 0;
    var spuriousSwitches = 0;
    for (var c = 1; c < claims.length; c++) {
      if (claims[c].key.matches(claims[c - 1].key)) continue;
      switches += 1;
      // Provisional: spurious means the annotation did not change across the
      // window AND the switch does not land on the annotated key. The second
      // condition keeps a lagged catch-up switch (annotation changed earlier,
      // detector arrives late) from being charged as spurious.
      final previousTruth = labels[claims[c - 1].index].localKey;
      final currentTruth = labels[claims[c].index].localKey;
      if (previousTruth != null &&
          currentTruth != null &&
          previousTruth.matches(currentTruth) &&
          !claims[c].key.matches(currentTruth)) {
        spuriousSwitches += 1;
      }
    }

    final changes = <({int index, KeyLabel newKey})>[];
    for (var i = 1; i < labels.length; i++) {
      final previous = labels[i - 1].localKey;
      final current = labels[i].localKey;
      if (previous != null && current != null && !previous.matches(current)) {
        changes.add((index: i, newKey: current));
      }
    }
    final modulationLags = <int>[];
    var censored = 0;
    for (var c = 0; c < changes.length; c++) {
      final horizon = c + 1 < changes.length
          ? changes[c + 1].index
          : frames.length;
      var matched = false;
      for (final claim in claims) {
        if (claim.index < changes[c].index) continue;
        if (claim.index >= horizon) break;
        if (claim.key.matches(changes[c].newKey)) {
          modulationLags.add(claim.index - changes[c].index);
          matched = true;
          break;
        }
      }
      if (!matched) censored += 1;
    }

    final globalTruth = labels
        .map((label) => label.localKey)
        .firstWhere((key) => key != null, orElse: () => null);
    double? globalFinalMirex;
    double? globalMajorityMirex;
    if (globalTruth != null && claims.isNotEmpty) {
      globalFinalMirex = mirexWeight(claims.last.key, globalTruth);
      final weightByKey = <String, double>{};
      final keyByName = <String, KeyLabel>{};
      for (final claim in claims) {
        final ms = fixture.events[claim.index].duration.inMilliseconds;
        weightByKey.update(
          claim.key.toString(),
          (weight) => weight + ms,
          ifAbsent: () => ms.toDouble(),
        );
        keyByName[claim.key.toString()] = claim.key;
      }
      final majority = weightByKey.entries.reduce(
        (a, b) => b.value > a.value ? b : a,
      );
      globalMajorityMirex = mirexWeight(keyByName[majority.key]!, globalTruth);
    }

    return PieceScore._(
      id: fixture.id,
      title: fixture.title,
      events: evaluated,
      claimed: claimed,
      labeledClaimed: labeledClaimed,
      exactOnClaimed: labeledClaimed == 0 ? 0 : exactSum / labeledClaimed,
      mirexOnClaimed: labeledClaimed == 0 ? 0 : mirexSum / labeledClaimed,
      ambiguousEvents: ambiguousEvents,
      ambiguousOk: ambiguousOk,
      timeToFirstClaim: timeToFirstClaim,
      switches: switches,
      spuriousSwitches: spuriousSwitches,
      annotatedChanges: changes.length,
      modulationLags: modulationLags,
      censoredModulations: censored,
      globalTruth: globalTruth,
      globalFinalMirex: globalFinalMirex,
      globalMajorityMirex: globalMajorityMirex,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'title': title,
    'events': events,
    'claimed': claimed,
    'coverage': coverage,
    'labeledClaimed': labeledClaimed,
    'exactOnClaimed': exactOnClaimed,
    'mirexOnClaimed': mirexOnClaimed,
    'ambiguousEvents': ambiguousEvents,
    'ambiguousOk': ambiguousOk,
    'timeToFirstClaim': timeToFirstClaim,
    'switches': switches,
    'spuriousSwitches': spuriousSwitches,
    'annotatedChanges': annotatedChanges,
    'modulationLags': modulationLags,
    'censoredModulations': censoredModulations,
    'globalTruth': globalTruth?.toString(),
    'globalFinalMirex': globalFinalMirex,
    'globalMajorityMirex': globalMajorityMirex,
  };
}

/// Per-piece aggregation per the protocol's reporting rules: means for
/// accuracy-like metrics, median and p90 for latency- and count-like metrics,
/// n everywhere.
Map<String, Object?> summarize(List<PieceScore> pieces) {
  final withClaims = pieces.where((p) => p.labeledClaimed > 0).toList();
  final withExactReference = pieces
      .where((p) => p.globalTruth != null)
      .toList();
  final lags = [for (final p in pieces) ...p.modulationLags];
  final neverClaimed = pieces.where((p) => p.timeToFirstClaim == null).length;
  final globalScored = pieces.where((p) => p.globalFinalMirex != null).toList();

  return {
    'pieces': pieces.length,
    'events': pieces.fold<int>(0, (sum, p) => sum + p.events),
    'coverage': {
      'meanPerPiece': _mean([for (final p in pieces) p.coverage]),
    },
    'accuracyOnClaimed': {
      'piecesWithClaims': withClaims.length,
      'meanExactPerPiece': _mean([
        for (final p in withClaims) p.exactOnClaimed,
      ]),
      'meanMirexPerPiece': _mean([
        for (final p in withClaims) p.mirexOnClaimed,
      ]),
    },
    'timeToFirstClaim': {
      'neverClaimedPieces': neverClaimed,
      ..._distribution([
        for (final p in pieces)
          if (p.timeToFirstClaim != null) p.timeToFirstClaim!.toDouble(),
      ]),
    },
    'switchesPerPiece': _distribution([
      for (final p in pieces) p.switches.toDouble(),
    ]),
    'spuriousSwitchesPerPiece': _distribution([
      for (final p in withExactReference) p.spuriousSwitches.toDouble(),
    ]),
    'modulation': {
      'annotatedChanges': pieces.fold<int>(
        0,
        (sum, p) => sum + p.annotatedChanges,
      ),
      'matched': lags.length,
      'censored': pieces.fold<int>(0, (sum, p) => sum + p.censoredModulations),
      'lagEvents': _distribution([for (final lag in lags) lag.toDouble()]),
    },
    'globalKey': {
      'scoredPieces': globalScored.length,
      'meanFinalMirex': _mean([
        for (final p in globalScored) p.globalFinalMirex!,
      ]),
      'meanMajorityMirex': _mean([
        for (final p in globalScored) p.globalMajorityMirex!,
      ]),
    },
  };
}

/// Reliability diagnostics for detectors whose ranked frame is a probability
/// distribution over keys, such as the HMM and BOCPD posterior.
///
/// Calibration is computed only on events with one exact local-key label.
/// Acceptable-key-only events are skipped because they define a set of correct
/// answers rather than a single probability target.
Map<String, Object?> posteriorCalibration(
  List<LabeledFixture> fixtures,
  Map<String, List<KeyEstimateFrame>> framesByFixture, {
  int binCount = 10,
  double temperature = 1,
}) {
  final all = _CalibrationAccumulator(binCount);
  final claimed = _CalibrationAccumulator(binCount);
  var skippedNoExactLabel = 0;
  var skippedNonProbabilistic = 0;

  for (final fixture in fixtures) {
    final frames = framesByFixture[fixture.id]!;
    assert(frames.length == fixture.labels.length);
    for (var i = 0; i < frames.length; i++) {
      final truth = fixture.labels[i].localKey;
      if (truth == null) {
        skippedNoExactLabel += 1;
        continue;
      }
      final frame = frames[i];
      var distribution = _probabilityDistribution(frame);
      if (distribution == null) {
        skippedNonProbabilistic += 1;
        continue;
      }
      distribution = applyDisplayTemperature(distribution, temperature);
      final top = frame.ranked.first;
      final topKey = KeyLabel.of(top.tonality);
      final correct = topKey.matches(truth);
      final topProbability = distribution[topKey.toString()] ?? 0.0;
      final truthProbability = distribution[truth.toString()] ?? 0.0;
      var brier = 0.0;
      for (final entry in distribution.entries) {
        final target = entry.key == truth.toString() ? 1.0 : 0.0;
        final error = entry.value - target;
        brier += error * error;
      }
      if (!distribution.containsKey(truth.toString())) {
        brier += 1.0;
      }
      all.add(
        confidence: topProbability,
        correct: correct,
        truthProbability: truthProbability,
        brier: brier,
        claimed: frame.claim != null,
      );
      if (frame.claim != null) {
        claimed.add(
          confidence:
              distribution[KeyLabel.of(frame.claim!.tonality).toString()] ??
              0.0,
          correct: KeyLabel.of(frame.claim!.tonality).matches(truth),
          truthProbability: truthProbability,
          brier: brier,
          claimed: true,
        );
      }
    }
  }

  return {
    'schema': 'whatkey-posterior-calibration/1',
    'binCount': binCount,
    'temperature': temperature,
    'allExactLabeledEvents': all.toJson(),
    'claimedExactLabeledEvents': claimed.toJson(),
    'skipped': {
      'noExactLocalKey': skippedNoExactLabel,
      'nonProbabilisticFrame': skippedNonProbabilistic,
    },
  };
}

/// Display-layer temperature scaling: raises every probability to 1/T and
/// renormalizes. Monotone, so it never reorders keys; T > 1 flattens an
/// overconfident distribution. T = 1 is the identity. Applied only to
/// displayed probabilities, never to the detector's internal margins.
Map<String, double> applyDisplayTemperature(
  Map<String, double> distribution,
  double temperature,
) {
  if (temperature == 1) return distribution;
  var total = 0.0;
  final scaled = <String, double>{
    for (final entry in distribution.entries)
      entry.key: math.pow(entry.value, 1 / temperature).toDouble(),
  };
  for (final value in scaled.values) {
    total += value;
  }
  if (total <= 0) return distribution;
  return {for (final entry in scaled.entries) entry.key: entry.value / total};
}

Map<String, double>? _probabilityDistribution(KeyEstimateFrame frame) {
  if (frame.ranked.isEmpty) return null;
  var sum = 0.0;
  final distribution = <String, double>{};
  for (final estimate in frame.ranked) {
    final value = estimate.confidence;
    if (value.isNaN || value.isInfinite || value < -1e-9 || value > 1 + 1e-9) {
      return null;
    }
    sum += value;
    distribution[KeyLabel.of(estimate.tonality).toString()] = value;
  }
  if ((sum - 1).abs() > 1e-6) return null;
  return distribution;
}

class _CalibrationAccumulator {
  final int binCount;
  final List<_CalibrationBin> _bins;
  var _count = 0;
  var _confidenceSum = 0.0;
  var _correctSum = 0.0;
  var _truthProbabilitySum = 0.0;
  var _nllSum = 0.0;
  var _brierSum = 0.0;
  var _claimedSum = 0;

  _CalibrationAccumulator(this.binCount)
    : _bins = [for (var i = 0; i < binCount; i++) _CalibrationBin()];

  void add({
    required double confidence,
    required bool correct,
    required double truthProbability,
    required double brier,
    required bool claimed,
  }) {
    final clippedConfidence = confidence.clamp(0.0, 1.0).toDouble();
    final clippedTruthProbability = truthProbability
        .clamp(1e-12, 1.0)
        .toDouble();
    final correctValue = correct ? 1.0 : 0.0;
    final bin = math.min((clippedConfidence * binCount).floor(), binCount - 1);
    _count += 1;
    _confidenceSum += clippedConfidence;
    _correctSum += correctValue;
    _truthProbabilitySum += truthProbability;
    _nllSum += -math.log(clippedTruthProbability);
    _brierSum += brier;
    if (claimed) _claimedSum += 1;
    _bins[bin].add(
      confidence: clippedConfidence,
      correct: correctValue,
      claimed: claimed,
    );
  }

  Map<String, Object?> toJson() {
    var ece = 0.0;
    var mce = 0.0;
    for (final bin in _bins) {
      if (bin.count == 0 || _count == 0) continue;
      final gap = (bin.accuracy - bin.meanConfidence).abs();
      ece += (bin.count / _count) * gap;
      if (gap > mce) mce = gap;
    }
    return {
      'events': _count,
      'meanConfidence': _count == 0 ? null : _confidenceSum / _count,
      'accuracy': _count == 0 ? null : _correctSum / _count,
      'meanTruthProbability': _count == 0
          ? null
          : _truthProbabilitySum / _count,
      'meanNegativeLogLikelihood': _count == 0 ? null : _nllSum / _count,
      'meanBrier': _count == 0 ? null : _brierSum / _count,
      'claimRate': _count == 0 ? null : _claimedSum / _count,
      'expectedCalibrationError': _count == 0 ? null : ece,
      'maximumCalibrationError': _count == 0 ? null : mce,
      'bins': [
        for (final (index, bin) in _bins.indexed)
          {
            'lowerInclusive': index / binCount,
            'upperExclusive': index + 1 == binCount
                ? null
                : (index + 1) / binCount,
            'count': bin.count,
            'meanConfidence': bin.count == 0 ? null : bin.meanConfidence,
            'accuracy': bin.count == 0 ? null : bin.accuracy,
            'claimRate': bin.count == 0 ? null : bin.claimRate,
          },
      ],
    };
  }
}

class _CalibrationBin {
  var count = 0;
  var confidenceSum = 0.0;
  var correctSum = 0.0;
  var claimedSum = 0;

  double get meanConfidence => confidenceSum / count;
  double get accuracy => correctSum / count;
  double get claimRate => claimedSum / count;

  void add({
    required double confidence,
    required double correct,
    required bool claimed,
  }) {
    count += 1;
    confidenceSum += confidence;
    correctSum += correct;
    if (claimed) claimedSum += 1;
  }
}

double? _mean(List<double> values) =>
    values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;

Map<String, Object?> _distribution(List<double> values) {
  if (values.isEmpty) return {'n': 0, 'median': null, 'p90': null};
  final sorted = [...values]..sort();
  return {
    'n': sorted.length,
    'median': _percentile(sorted, 0.5),
    'p90': _percentile(sorted, 0.9),
  };
}

/// Nearest-rank percentile over an ascending [sorted] list.
double _percentile(List<double> sorted, double p) {
  final rank = (p * sorted.length).ceil().clamp(1, sorted.length);
  return sorted[rank - 1];
}

/// Re-applies a margin floor to frames produced with `marginFloor: 0`.
///
/// The margin floor is a post-hoc threshold: claims never feed back into the
/// detector's histogram, so one floor-zero pass plus this function yields the
/// whole coverage-accuracy curve without re-running the detector.
List<KeyEstimateFrame> applyMarginFloor(
  List<KeyEstimateFrame> frames,
  double floor,
) => [
  for (final frame in frames)
    frame.claim != null && _margin(frame) < floor
        ? KeyEstimateFrame.abstain(frame.ranked)
        : frame,
];

double _margin(KeyEstimateFrame frame) => frame.ranked.length < 2
    ? double.infinity
    : frame.ranked[0].confidence - frame.ranked[1].confidence;
