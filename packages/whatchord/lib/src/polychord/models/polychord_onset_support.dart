import 'package:meta/meta.dart';

import 'polychord_onset_evidence.dart';

/// Whether every candidate-note onset required by the interpretation is known.
enum PolychordOnsetSupportAvailability { complete, incomplete }

/// Orientation-neutral order of two candidate-layer onset intervals.
enum PolychordLayerOnsetOrder {
  lowerThenUpper(jsonName: 'lower-then-upper'),
  upperThenLower(jsonName: 'upper-then-lower'),
  overlapping(jsonName: 'overlapping');

  const PolychordLayerOnsetOrder({required this.jsonName});

  final String jsonName;
}

/// One-sided result from the fixed onset-cohort interpretation.
enum PolychordOnsetCohortSupport { positive, neutral }

/// Fixed onset-cohort interpretation bound to one exact candidate and history.
@immutable
final class PolychordCandidateOnsetInterpretation {
  @internal
  PolychordCandidateOnsetInterpretation.internal({
    required this.evidence,
    required this.availability,
    required this.lowerWithinCohortSpanMaximum,
    required this.upperWithinCohortSpanMaximum,
    required this.layerOnsetOrder,
    required this.betweenLayerOnsetIntervalGapMs,
    required this.onsetCohortSupport,
    required Iterable<String> reasonCodes,
  }) : reasonCodes = List.unmodifiable(reasonCodes);

  final PolychordCandidateOnsetEvidence evidence;
  final PolychordOnsetSupportAvailability availability;
  final bool? lowerWithinCohortSpanMaximum;
  final bool? upperWithinCohortSpanMaximum;
  final PolychordLayerOnsetOrder? layerOnsetOrder;
  final int? betweenLayerOnsetIntervalGapMs;
  final PolychordOnsetCohortSupport onsetCohortSupport;
  final List<String> reasonCodes;

  Map<String, Object?> toInterpretationJson() => <String, Object?>{
    'availability': availability.name,
    'lowerWithinCohortSpanMaximum': lowerWithinCohortSpanMaximum,
    'upperWithinCohortSpanMaximum': upperWithinCohortSpanMaximum,
    'layerOnsetOrder': layerOnsetOrder?.jsonName,
    'betweenLayerOnsetIntervalGapMs': betweenLayerOnsetIntervalGapMs,
    'onsetCohortSupport': onsetCohortSupport.name,
    'reasonCodes': reasonCodes,
  };

  Map<String, Object?> toJson() => <String, Object?>{
    ...evidence.toJson(),
    'onsetInterpretation': toInterpretationJson(),
  };
}
