import '../models/polychord_onset_evidence.dart';
import '../models/polychord_onset_support.dart';

/// Fixed `coherent-separated-onsets-50-200ms/1` onset interpretation.
///
/// This separately named research policy emits one-sided support only. It does
/// not reject or rank candidates, infer streams, choose a selector licensing
/// cue, or authorize a display.
final class PolychordCoherentSeparatedOnsetInterpreter {
  const PolychordCoherentSeparatedOnsetInterpreter();

  static const ablationId = 'coherent-separated-onsets-50-200ms/1';
  static const withinLayerCohortSpanMaximumMs = 50;
  static const betweenLayerSeparationMinimumMs = 200;
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
