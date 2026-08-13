import '../models/polychord_frame_transition_evidence.dart';
import '../models/polychord_motion_support.dart';

/// Fixed `rigid-layers-oblique-or-contrary/1` motion interpretation.
///
/// This separately named policy grants one-sided support only when both mapped
/// chordal sets translate exactly and their deltas are oblique or contrary. It
/// does not select a correspondence, rank or reject candidates, infer voices,
/// choose endpoints, or authorize a display.
final class PolychordRigidLayerMotionInterpreter {
  const PolychordRigidLayerMotionInterpreter();

  static const ablationId = 'rigid-layers-oblique-or-contrary/1';

  static const parameters = <String, Object>{
    'withinLayerTransform': 'exact-midi-set-translation',
    'betweenLayerSupportClasses': <String>['oblique', 'contrary'],
    'retainedInstanceContradictionPolicy': 'neutral',
    'nonRigidOrCardinalityChangePolicy': 'neutral',
  };

  List<PolychordCandidateMotionInterpretation> interpret(
    PolychordFrameTransitionEvidence evidence,
  ) => List.unmodifiable([
    for (final transition in evidence.candidateTransitions)
      PolychordCandidateMotionInterpretation.internal(
        transitionEvidence: transition,
        hypothesisInterpretations: [
          for (final hypothesis in transition.layerCorrespondenceHypotheses)
            _interpretHypothesis(transition, hypothesis),
        ],
      ),
  ]);
}

PolychordMotionHypothesisInterpretation _interpretHypothesis(
  PolychordCandidateTransitionEvidence transition,
  PolychordLayerCorrespondenceHypothesis hypothesis,
) {
  final relationsByKind = {
    for (final relation in transition.layerRelations) relation.kind: relation,
  };
  final translations = [
    for (final kind in hypothesis.kind.relations)
      _translation(relationsByKind[kind]!),
  ];
  final bySourceLayer = {
    for (final translation in translations)
      translation.relation.kind.sourceRole: translation,
  };
  final bothExact = translations.every(
    (translation) =>
        translation.exactMidiSetTranslation &&
        translation.chordIdentityFollowsTranslation == true,
  );
  final motionClass = bothExact
      ? _classify(
          bySourceLayer[PolychordLayerRole.lower]!.translationSemitones!,
          bySourceLayer[PolychordLayerRole.upper]!.translationSemitones!,
        )
      : null;
  final retained = _retainedEvidence(hypothesis);
  final reasons = <String>[];
  if (retained == PolychordRetainedInstanceEvidence.contradictory) {
    reasons.add('retained-instance-contradicts-correspondence');
  }
  for (final translation in translations) {
    if (!translation.exactMidiSetTranslation) {
      reasons.add(
        '${translation.relation.kind.id}-not-exact-midi-set-translation',
      );
    } else if (translation.chordIdentityFollowsTranslation != true) {
      reasons.add(
        '${translation.relation.kind.id}-chord-identity-does-not-follow-translation',
      );
    }
  }
  final positive =
      reasons.isEmpty &&
      (motionClass == PolychordBetweenLayerMotionClass.oblique ||
          motionClass == PolychordBetweenLayerMotionClass.contrary);
  if (reasons.isEmpty) {
    switch (motionClass) {
      case PolychordBetweenLayerMotionClass.oblique ||
          PolychordBetweenLayerMotionClass.contrary:
        reasons.add('rigid-layer-translations-${motionClass!.jsonName}');
      case PolychordBetweenLayerMotionClass.static:
        reasons.add('both-layer-translations-static');
      case PolychordBetweenLayerMotionClass.commonTranslation:
        reasons.add('whole-sonority-common-translation');
      case PolychordBetweenLayerMotionClass.unequalSimilarDirection:
        reasons.add('layer-translations-unequal-similar-direction');
      case null:
        break;
    }
  }
  return PolychordMotionHypothesisInterpretation.internal(
    hypothesis: hypothesis,
    retainedInstanceEvidence: retained,
    layerTranslations: translations,
    bothLayersExactTranslations: bothExact,
    betweenLayerMotionClass: motionClass,
    motionSupport: positive
        ? PolychordMotionSupport.positive
        : PolychordMotionSupport.neutral,
    reasonCodes: reasons,
  );
}

PolychordLayerTranslationEvidence _translation(
  PolychordLayerRelationEvidence relation,
) {
  final source = relation.sourceLayer.midiNotes;
  final target = relation.targetLayer.midiNotes;
  final sameCardinality = source.length == target.length;
  final delta = sameCardinality ? target.first - source.first : null;
  final exact =
      sameCardinality &&
      List.generate(
        source.length,
        (index) => source[index] + delta!,
      ).indexed.every((entry) => target[entry.$1] == entry.$2);
  final identityConsistent = exact
      ? relation.sourceLayer.identity.quality ==
                relation.targetLayer.identity.quality &&
            relation.targetLayer.identity.rootPc ==
                (relation.sourceLayer.identity.rootPc + delta!) % 12
      : null;
  return PolychordLayerTranslationEvidence.internal(
    relation: relation,
    sameCardinality: sameCardinality,
    exactMidiSetTranslation: exact,
    translationSemitones: exact ? delta : null,
    chordIdentityFollowsTranslation: identityConsistent,
  );
}

PolychordRetainedInstanceEvidence _retainedEvidence(
  PolychordLayerCorrespondenceHypothesis hypothesis,
) {
  if (hypothesis.retainedInstancesOutsideRelations.isNotEmpty) {
    return PolychordRetainedInstanceEvidence.contradictory;
  }
  if (hypothesis.retainedInstancesFollowingRelations.isNotEmpty) {
    return PolychordRetainedInstanceEvidence.consistent;
  }
  return PolychordRetainedInstanceEvidence.none;
}

PolychordBetweenLayerMotionClass _classify(int lower, int upper) {
  if (lower == 0 && upper == 0) {
    return PolychordBetweenLayerMotionClass.static;
  }
  if (lower == upper) {
    return PolychordBetweenLayerMotionClass.commonTranslation;
  }
  if (lower == 0 || upper == 0) {
    return PolychordBetweenLayerMotionClass.oblique;
  }
  if ((lower < 0 && upper > 0) || (upper < 0 && lower > 0)) {
    return PolychordBetweenLayerMotionClass.contrary;
  }
  return PolychordBetweenLayerMotionClass.unequalSimilarDirection;
}
