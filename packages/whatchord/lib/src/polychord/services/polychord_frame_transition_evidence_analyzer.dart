import '../models/polychord_candidate.dart';
import '../models/polychord_frame_transition_evidence.dart';
import '../models/polychord_release_pedal_evidence.dart';
import 'polychord_register_candidate_generator.dart';

/// Enumerates exact candidate-transition facts without voice assignment.
final class PolychordFrameTransitionEvidenceAnalyzer {
  const PolychordFrameTransitionEvidenceAnalyzer();

  PolychordFrameTransitionEvidence analyze({
    required PolychordFrameTransitionWindow window,
  }) {
    final sourceFrame = window.sourceFrame;
    final targetFrame = window.targetFrame;
    final sourceCandidates = const PolychordRegisterCandidateGenerator()
        .generate(
          sourceFrame.soundingNoteHistories.map((note) => note.midiNote),
        );
    final targetCandidates = const PolychordRegisterCandidateGenerator()
        .generate(
          targetFrame.soundingNoteHistories.map((note) => note.midiNote),
        );
    final transitions = <PolychordCandidateTransitionEvidence>[];
    for (
      var sourceIndex = 0;
      sourceIndex < sourceCandidates.length;
      sourceIndex++
    ) {
      for (
        var targetIndex = 0;
        targetIndex < targetCandidates.length;
        targetIndex++
      ) {
        transitions.add(
          _analyzeCandidatePair(
            sourceCandidateIndex: sourceIndex,
            targetCandidateIndex: targetIndex,
            sourceCandidate: sourceCandidates[sourceIndex],
            targetCandidate: targetCandidates[targetIndex],
            sourceFrame: sourceFrame,
            targetFrame: targetFrame,
          ),
        );
      }
    }
    return PolychordFrameTransitionEvidence.internal(
      window: window,
      sourceCandidates: sourceCandidates,
      targetCandidates: targetCandidates,
      candidateTransitions: transitions,
    );
  }
}

PolychordCandidateTransitionEvidence _analyzeCandidatePair({
  required int sourceCandidateIndex,
  required int targetCandidateIndex,
  required PolychordCandidate sourceCandidate,
  required PolychordCandidate targetCandidate,
  required PolychordReleasePedalTrackingFrame sourceFrame,
  required PolychordReleasePedalTrackingFrame targetFrame,
}) {
  final sourceNotes = {
    for (final note in sourceFrame.soundingNoteHistories)
      _instanceKey(note): note,
  };
  final targetNotes = {
    for (final note in targetFrame.soundingNoteHistories)
      _instanceKey(note): note,
  };
  final sourceKeys = sourceNotes.keys.toSet();
  final targetKeys = targetNotes.keys.toSet();
  final retainedKeys = sourceKeys.intersection(targetKeys).toList()
    ..sort(_compareInstanceKeys);
  final departedKeys = sourceKeys.difference(targetKeys).toList()
    ..sort(_compareInstanceKeys);
  final arrivedKeys = targetKeys.difference(sourceKeys).toList()
    ..sort(_compareInstanceKeys);

  final retained = [
    for (final key in retainedKeys)
      _retainedInstance(
        sourceNotes[key]!,
        targetNotes[key]!,
        sourceCandidate,
        targetCandidate,
      ),
  ];
  final continuity = PolychordInstanceContinuity.internal(
    retainedInstances: retained,
    departedInstances: [
      for (final key in departedKeys)
        PolychordDepartedInstance.internal(
          identity: PolychordSoundingInstanceIdentity.fromHistory(
            sourceNotes[key]!,
          ),
          sourceLayer: _layerForNote(sourceCandidate, key.midiNote),
          sourceSoundingState: sourceNotes[key]!.soundingState,
        ),
    ],
    arrivedInstances: [
      for (final key in arrivedKeys)
        PolychordArrivedInstance.internal(
          identity: PolychordSoundingInstanceIdentity.fromHistory(
            targetNotes[key]!,
          ),
          targetLayer: _layerForNote(targetCandidate, key.midiNote),
          targetSoundingState: targetNotes[key]!.soundingState,
        ),
    ],
  );

  final relations = [
    for (final kind in PolychordLayerRelationKind.values)
      PolychordLayerRelationEvidence.internal(
        kind: kind,
        sourceLayer: _layer(sourceCandidate, kind.sourceRole),
        targetLayer: _layer(targetCandidate, kind.targetRole),
        retainedInstances: [
          for (final item in retained)
            if (item.sourceLayer == kind.sourceRole &&
                item.targetLayer == kind.targetRole)
              item.identity,
        ],
      ),
  ];
  final hypotheses = [
    for (final kind in PolychordLayerCorrespondenceKind.values)
      PolychordLayerCorrespondenceHypothesis.internal(
        kind: kind,
        retainedInstancesFollowingRelations: [
          for (final item in retained)
            if (_follows(kind, item)) item.identity,
        ],
        retainedInstancesOutsideRelations: [
          for (final item in retained)
            if (!_follows(kind, item)) item.identity,
        ],
      ),
  ];
  return PolychordCandidateTransitionEvidence.internal(
    sourceCandidateIndex: sourceCandidateIndex,
    targetCandidateIndex: targetCandidateIndex,
    sourceCandidate: sourceCandidate,
    targetCandidate: targetCandidate,
    instanceContinuity: continuity,
    layerRelations: relations,
    layerCorrespondenceHypotheses: hypotheses,
  );
}

PolychordRetainedInstance _retainedInstance(
  PolychordSoundingNoteHistory source,
  PolychordSoundingNoteHistory target,
  PolychordCandidate sourceCandidate,
  PolychordCandidate targetCandidate,
) {
  if (source.onset?.timestampMs != target.onset?.timestampMs ||
      source.onset?.velocity != target.onset?.velocity) {
    throw ArgumentError(
      'matching sounding-instance keys must preserve their onset origin',
    );
  }
  return PolychordRetainedInstance.internal(
    identity: PolychordSoundingInstanceIdentity.fromHistory(source),
    sourceLayer: _layerForNote(sourceCandidate, source.midiNote),
    targetLayer: _layerForNote(targetCandidate, target.midiNote),
    sourceSoundingState: source.soundingState,
    targetSoundingState: target.soundingState,
  );
}

bool _follows(
  PolychordLayerCorrespondenceKind hypothesis,
  PolychordRetainedInstance instance,
) => hypothesis.relations.any(
  (relation) =>
      relation.sourceRole == instance.sourceLayer &&
      relation.targetRole == instance.targetLayer,
);

PolychordLayerCandidate _layer(
  PolychordCandidate candidate,
  PolychordLayerRole role,
) => switch (role) {
  PolychordLayerRole.lower => candidate.lower,
  PolychordLayerRole.upper => candidate.upper,
};

PolychordLayerRole _layerForNote(PolychordCandidate candidate, int midiNote) {
  if (candidate.lower.midiNotes.contains(midiNote)) {
    return PolychordLayerRole.lower;
  }
  if (candidate.upper.midiNotes.contains(midiNote)) {
    return PolychordLayerRole.upper;
  }
  throw ArgumentError.value(
    midiNote,
    'midiNote',
    'candidate must assign every sounding note',
  );
}

({int midiNote, int? onsetEventIndex}) _instanceKey(
  PolychordSoundingNoteHistory note,
) => (midiNote: note.midiNote, onsetEventIndex: note.onset?.eventIndex);

int _compareInstanceKeys(
  ({int midiNote, int? onsetEventIndex}) left,
  ({int midiNote, int? onsetEventIndex}) right,
) {
  final midiComparison = left.midiNote.compareTo(right.midiNote);
  if (midiComparison != 0) return midiComparison;
  return (left.onsetEventIndex ?? -1).compareTo(right.onsetEventIndex ?? -1);
}
