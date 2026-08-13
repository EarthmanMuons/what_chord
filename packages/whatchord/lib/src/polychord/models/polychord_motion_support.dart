import 'package:meta/meta.dart';

import 'polychord_frame_transition_evidence.dart';

/// Relation of exact retained instances to one endpoint correspondence.
enum PolychordRetainedInstanceEvidence { consistent, contradictory, none }

/// Classification of two exact rigid-layer translations.
enum PolychordBetweenLayerMotionClass {
  static(jsonName: 'static'),
  commonTranslation(jsonName: 'common-translation'),
  oblique(jsonName: 'oblique'),
  contrary(jsonName: 'contrary'),
  unequalSimilarDirection(jsonName: 'unequal-similar-direction');

  const PolychordBetweenLayerMotionClass({required this.jsonName});

  final String jsonName;
}

/// One-sided support emitted by the fixed rigid-layer interpretation.
enum PolychordMotionSupport { positive, neutral }

/// Exact set-translation facts for one mapped layer relation.
@immutable
final class PolychordLayerTranslationEvidence {
  @internal
  PolychordLayerTranslationEvidence.internal({
    required this.relation,
    required this.sameCardinality,
    required this.exactMidiSetTranslation,
    required this.translationSemitones,
    required this.chordIdentityFollowsTranslation,
  });

  final PolychordLayerRelationEvidence relation;
  final bool sameCardinality;
  final bool exactMidiSetTranslation;
  final int? translationSemitones;
  final bool? chordIdentityFollowsTranslation;

  Map<String, Object?> toJson() => <String, Object?>{
    'relationId': relation.kind.id,
    'sourceLayer': relation.kind.sourceRole.name,
    'targetLayer': relation.kind.targetRole.name,
    'sourceMidiNotes': relation.sourceLayer.midiNotes,
    'targetMidiNotes': relation.targetLayer.midiNotes,
    'sameCardinality': sameCardinality,
    'exactMidiSetTranslation': exactMidiSetTranslation,
    'translationSemitones': translationSemitones,
    'chordIdentityFollowsTranslation': chordIdentityFollowsTranslation,
  };
}

/// Interpretation of one explicit, unranked correspondence hypothesis.
@immutable
final class PolychordMotionHypothesisInterpretation {
  @internal
  PolychordMotionHypothesisInterpretation.internal({
    required this.hypothesis,
    required this.retainedInstanceEvidence,
    required Iterable<PolychordLayerTranslationEvidence> layerTranslations,
    required this.bothLayersExactTranslations,
    required this.betweenLayerMotionClass,
    required this.motionSupport,
    required Iterable<String> reasonCodes,
  }) : layerTranslations = List.unmodifiable(layerTranslations),
       reasonCodes = List.unmodifiable(reasonCodes);

  final PolychordLayerCorrespondenceHypothesis hypothesis;
  final PolychordRetainedInstanceEvidence retainedInstanceEvidence;
  final List<PolychordLayerTranslationEvidence> layerTranslations;
  final bool bothLayersExactTranslations;
  final PolychordBetweenLayerMotionClass? betweenLayerMotionClass;
  final PolychordMotionSupport motionSupport;
  final List<String> reasonCodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'hypothesisId': hypothesis.kind.id,
    'relationIds': [
      for (final relation in hypothesis.kind.relations) relation.id,
    ],
    'retainedInstanceEvidence': retainedInstanceEvidence.name,
    'layerTranslations': [
      for (final translation in layerTranslations) translation.toJson(),
    ],
    'bothLayersExactTranslations': bothLayersExactTranslations,
    'betweenLayerMotionClass': betweenLayerMotionClass?.jsonName,
    'motionSupport': motionSupport.name,
    'reasonCodes': reasonCodes,
  };
}

/// Motion interpretations for both unranked correspondences of one pair.
@immutable
final class PolychordCandidateMotionInterpretation {
  @internal
  PolychordCandidateMotionInterpretation.internal({
    required this.transitionEvidence,
    required Iterable<PolychordMotionHypothesisInterpretation>
    hypothesisInterpretations,
  }) : hypothesisInterpretations = List.unmodifiable(hypothesisInterpretations);

  final PolychordCandidateTransitionEvidence transitionEvidence;
  final List<PolychordMotionHypothesisInterpretation> hypothesisInterpretations;

  Map<String, Object> toJson() => <String, Object>{
    'sourceCandidateIndex': transitionEvidence.sourceCandidateIndex,
    'targetCandidateIndex': transitionEvidence.targetCandidateIndex,
    'transitionEvidence': transitionEvidence.toJson(),
    'hypothesisInterpretations': [
      for (final interpretation in hypothesisInterpretations)
        interpretation.toJson(),
    ],
  };
}
