import '../models/polychord_onset_evidence.dart';
import '../models/polychord_onset_support.dart';

/// Frozen `coherent-separated-onsets-50-80ms/product-1` interpretation.
///
/// This product cue is separate from the preserved 50/200-millisecond
/// research diagnostic. Its thresholds are inclusive and orientation-neutral.
final class PolychordProductOnsetInterpreter {
  const PolychordProductOnsetInterpreter();

  static const cueId = 'coherent-separated-onsets-50-80ms/product-1';
  static const withinLayerCohortSpanMaximumMs = 50;
  static const betweenLayerSeparationMinimumMs = 80;
  static const parameters = <String, int>{
    'withinLayerCohortSpanMaximumMs': withinLayerCohortSpanMaximumMs,
    'betweenLayerSeparationMinimumMs': betweenLayerSeparationMinimumMs,
  };

  List<PolychordCandidateOnsetInterpretation> interpretAll(
    Iterable<PolychordCandidateOnsetEvidence> evidence,
  ) => List.unmodifiable(evidence.map(interpret));

  PolychordCandidateOnsetInterpretation interpret(
    PolychordCandidateOnsetEvidence evidence,
  ) {
    if (!evidence.allCandidateOnsetsKnown) {
      return PolychordCandidateOnsetInterpretation.internal(
        evidence: evidence,
        availability: PolychordOnsetSupportAvailability.incomplete,
        lowerWithinCohortSpanMaximum: null,
        upperWithinCohortSpanMaximum: null,
        layerOnsetOrder: null,
        betweenLayerOnsetIntervalGapMs: null,
        onsetCohortSupport: PolychordOnsetCohortSupport.neutral,
        reasonCodes: const ['onset-history-incomplete'],
      );
    }

    final lowerCoherent =
        evidence.lower.knownOnsetSpanMs! <= withinLayerCohortSpanMaximumMs;
    final upperCoherent =
        evidence.upper.knownOnsetSpanMs! <= withinLayerCohortSpanMaximumMs;
    final (:order, :gapMs) = _intervalOrderAndGap(evidence);
    final reasons = <String>[
      if (!lowerCoherent) 'lower-span-exceeds-maximum',
      if (!upperCoherent) 'upper-span-exceeds-maximum',
      if (gapMs < betweenLayerSeparationMinimumMs)
        'between-layer-separation-below-minimum',
    ];
    final positive = reasons.isEmpty;
    return PolychordCandidateOnsetInterpretation.internal(
      evidence: evidence,
      availability: PolychordOnsetSupportAvailability.complete,
      lowerWithinCohortSpanMaximum: lowerCoherent,
      upperWithinCohortSpanMaximum: upperCoherent,
      layerOnsetOrder: order,
      betweenLayerOnsetIntervalGapMs: gapMs,
      onsetCohortSupport: positive
          ? PolychordOnsetCohortSupport.positive
          : PolychordOnsetCohortSupport.neutral,
      reasonCodes: positive
          ? const ['separate-coherent-onset-cohorts']
          : reasons,
    );
  }
}

({PolychordLayerOnsetOrder order, int gapMs}) _intervalOrderAndGap(
  PolychordCandidateOnsetEvidence evidence,
) {
  final lowerEarliest = evidence.lower.earliestKnownOnsetMs!;
  final lowerLatest = evidence.lower.latestKnownOnsetMs!;
  final upperEarliest = evidence.upper.earliestKnownOnsetMs!;
  final upperLatest = evidence.upper.latestKnownOnsetMs!;
  if (lowerLatest < upperEarliest) {
    return (
      order: PolychordLayerOnsetOrder.lowerThenUpper,
      gapMs: upperEarliest - lowerLatest,
    );
  }
  if (upperLatest < lowerEarliest) {
    return (
      order: PolychordLayerOnsetOrder.upperThenLower,
      gapMs: lowerEarliest - upperLatest,
    );
  }
  return (order: PolychordLayerOnsetOrder.overlapping, gapMs: 0);
}
