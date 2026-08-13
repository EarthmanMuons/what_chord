import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'polychord_candidate.dart';
import 'polychord_onset_evidence.dart';
import 'polychord_release_pedal_evidence.dart';
import 'polychord_temporal_event.dart';

/// Endpoint register role assigned by one structural candidate.
enum PolychordLayerRole { lower, upper }

/// One of the four complete source-to-target layer relations.
enum PolychordLayerRelationKind {
  lowerToLower(
    id: 'lower-to-lower',
    sourceRole: PolychordLayerRole.lower,
    targetRole: PolychordLayerRole.lower,
  ),
  lowerToUpper(
    id: 'lower-to-upper',
    sourceRole: PolychordLayerRole.lower,
    targetRole: PolychordLayerRole.upper,
  ),
  upperToLower(
    id: 'upper-to-lower',
    sourceRole: PolychordLayerRole.upper,
    targetRole: PolychordLayerRole.lower,
  ),
  upperToUpper(
    id: 'upper-to-upper',
    sourceRole: PolychordLayerRole.upper,
    targetRole: PolychordLayerRole.upper,
  );

  const PolychordLayerRelationKind({
    required this.id,
    required this.sourceRole,
    required this.targetRole,
  });

  final String id;
  final PolychordLayerRole sourceRole;
  final PolychordLayerRole targetRole;
}

/// One of the two unranked bijections between endpoint register roles.
enum PolychordLayerCorrespondenceKind {
  registerRolePreserving(
    id: 'register-role-preserving',
    relations: [
      PolychordLayerRelationKind.lowerToLower,
      PolychordLayerRelationKind.upperToUpper,
    ],
  ),
  registerRoleExchanging(
    id: 'register-role-exchanging',
    relations: [
      PolychordLayerRelationKind.lowerToUpper,
      PolychordLayerRelationKind.upperToLower,
    ],
  );

  const PolychordLayerCorrespondenceKind({
    required this.id,
    required this.relations,
  });

  final String id;
  final List<PolychordLayerRelationKind> relations;
}

/// Identity of one sounding instance within a reset-delimited tracker epoch.
@immutable
final class PolychordSoundingInstanceIdentity {
  const PolychordSoundingInstanceIdentity._({
    required this.midiNote,
    required this.onsetEventIndex,
    required this.onsetTimestampMs,
  });

  factory PolychordSoundingInstanceIdentity.fromHistory(
    PolychordSoundingNoteHistory history,
  ) => PolychordSoundingInstanceIdentity._(
    midiNote: history.midiNote,
    onsetEventIndex: history.onset?.eventIndex,
    onsetTimestampMs: history.onset?.timestampMs,
  );

  final int midiNote;
  final int? onsetEventIndex;
  final int? onsetTimestampMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'midiNote': midiNote,
    'onsetEventIndex': onsetEventIndex,
    'onsetTimestampMs': onsetTimestampMs,
  };

  Map<String, Object?> toCompactJson() => <String, Object?>{
    'midiNote': midiNote,
    'onsetEventIndex': onsetEventIndex,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordSoundingInstanceIdentity &&
          other.midiNote == midiNote &&
          other.onsetEventIndex == onsetEventIndex &&
          other.onsetTimestampMs == onsetTimestampMs;

  @override
  int get hashCode => Object.hash(midiNote, onsetEventIndex, onsetTimestampMs);
}

/// An uninterrupted sounding instance present at both selected endpoints.
@immutable
final class PolychordRetainedInstance {
  @internal
  const PolychordRetainedInstance.internal({
    required this.identity,
    required this.sourceLayer,
    required this.targetLayer,
    required this.sourceSoundingState,
    required this.targetSoundingState,
  });

  final PolychordSoundingInstanceIdentity identity;
  final PolychordLayerRole sourceLayer;
  final PolychordLayerRole targetLayer;
  final PolychordSoundingState sourceSoundingState;
  final PolychordSoundingState targetSoundingState;

  Map<String, Object?> toJson() => <String, Object?>{
    ...identity.toJson(),
    'sourceLayer': sourceLayer.name,
    'targetLayer': targetLayer.name,
    'sourceSoundingState': sourceSoundingState.name,
    'targetSoundingState': targetSoundingState.name,
  };
}

/// A sounding instance present only at the source endpoint.
@immutable
final class PolychordDepartedInstance {
  @internal
  const PolychordDepartedInstance.internal({
    required this.identity,
    required this.sourceLayer,
    required this.sourceSoundingState,
  });

  final PolychordSoundingInstanceIdentity identity;
  final PolychordLayerRole sourceLayer;
  final PolychordSoundingState sourceSoundingState;

  Map<String, Object?> toJson() => <String, Object?>{
    ...identity.toJson(),
    'sourceLayer': sourceLayer.name,
    'sourceSoundingState': sourceSoundingState.name,
  };
}

/// A sounding instance present only at the target endpoint.
@immutable
final class PolychordArrivedInstance {
  @internal
  const PolychordArrivedInstance.internal({
    required this.identity,
    required this.targetLayer,
    required this.targetSoundingState,
  });

  final PolychordSoundingInstanceIdentity identity;
  final PolychordLayerRole targetLayer;
  final PolychordSoundingState targetSoundingState;

  Map<String, Object?> toJson() => <String, Object?>{
    ...identity.toJson(),
    'targetLayer': targetLayer.name,
    'targetSoundingState': targetSoundingState.name,
  };
}

/// Exact sounding-instance continuity between two candidate endpoints.
@immutable
final class PolychordInstanceContinuity {
  @internal
  PolychordInstanceContinuity.internal({
    required Iterable<PolychordRetainedInstance> retainedInstances,
    required Iterable<PolychordDepartedInstance> departedInstances,
    required Iterable<PolychordArrivedInstance> arrivedInstances,
  }) : retainedInstances = List.unmodifiable(retainedInstances),
       departedInstances = List.unmodifiable(departedInstances),
       arrivedInstances = List.unmodifiable(arrivedInstances);

  final List<PolychordRetainedInstance> retainedInstances;
  final List<PolychordDepartedInstance> departedInstances;
  final List<PolychordArrivedInstance> arrivedInstances;

  Map<String, Object> toJson() => <String, Object>{
    'retainedInstances': [for (final item in retainedInstances) item.toJson()],
    'departedInstances': [for (final item in departedInstances) item.toJson()],
    'arrivedInstances': [for (final item in arrivedInstances) item.toJson()],
  };
}

/// Complete raw facts for one source-layer to target-layer relation.
@immutable
final class PolychordLayerRelationEvidence {
  @internal
  PolychordLayerRelationEvidence.internal({
    required this.kind,
    required this.sourceLayer,
    required this.targetLayer,
    required Iterable<PolychordSoundingInstanceIdentity> retainedInstances,
  }) : retainedInstances = List.unmodifiable(retainedInstances);

  final PolychordLayerRelationKind kind;
  final PolychordLayerCandidate sourceLayer;
  final PolychordLayerCandidate targetLayer;
  final List<PolychordSoundingInstanceIdentity> retainedInstances;

  int get rootPitchClassDeltaMod12 =>
      (targetLayer.identity.rootPc - sourceLayer.identity.rootPc) % 12;

  List<List<int>> get allPairTargetMinusSourceSemitones =>
      List<List<int>>.unmodifiable([
        for (final sourceNote in sourceLayer.midiNotes)
          List<int>.unmodifiable([
            for (final targetNote in targetLayer.midiNotes)
              targetNote - sourceNote,
          ]),
      ]);

  Map<String, Object> toJson() => <String, Object>{
    'id': kind.id,
    'sourceLayer': kind.sourceRole.name,
    'targetLayer': kind.targetRole.name,
    'sourceMidiNotes': sourceLayer.midiNotes,
    'targetMidiNotes': targetLayer.midiNotes,
    'sourceRootPc': sourceLayer.identity.rootPc,
    'targetRootPc': targetLayer.identity.rootPc,
    'rootPitchClassDeltaMod12': rootPitchClassDeltaMod12,
    'sameRootPc': sourceLayer.identity.rootPc == targetLayer.identity.rootPc,
    'sourceQuality': sourceLayer.identity.quality.name,
    'targetQuality': targetLayer.identity.quality.name,
    'sameQuality': sourceLayer.identity.quality == targetLayer.identity.quality,
    'sourcePitchClasses': sourceLayer.pitchClasses,
    'targetPitchClasses': targetLayer.pitchClasses,
    'samePitchClasses': _intListEquality.equals(
      sourceLayer.pitchClasses,
      targetLayer.pitchClasses,
    ),
    'allPairTargetMinusSourceSemitones': allPairTargetMinusSourceSemitones,
    'retainedInstances': [
      for (final identity in retainedInstances) identity.toCompactJson(),
    ],
    'retainedInstanceCount': retainedInstances.length,
  };
}

/// One unranked endpoint layer-correspondence hypothesis.
@immutable
final class PolychordLayerCorrespondenceHypothesis {
  @internal
  PolychordLayerCorrespondenceHypothesis.internal({
    required this.kind,
    required Iterable<PolychordSoundingInstanceIdentity>
    retainedInstancesFollowingRelations,
    required Iterable<PolychordSoundingInstanceIdentity>
    retainedInstancesOutsideRelations,
  }) : retainedInstancesFollowingRelations = List.unmodifiable(
         retainedInstancesFollowingRelations,
       ),
       retainedInstancesOutsideRelations = List.unmodifiable(
         retainedInstancesOutsideRelations,
       );

  final PolychordLayerCorrespondenceKind kind;
  final List<PolychordSoundingInstanceIdentity>
  retainedInstancesFollowingRelations;
  final List<PolychordSoundingInstanceIdentity>
  retainedInstancesOutsideRelations;

  Map<String, Object> toJson() => <String, Object>{
    'id': kind.id,
    'relationIds': [for (final relation in kind.relations) relation.id],
    'retainedInstancesFollowingRelations': [
      for (final identity in retainedInstancesFollowingRelations)
        identity.toCompactJson(),
    ],
    'retainedInstancesOutsideRelations': [
      for (final identity in retainedInstancesOutsideRelations)
        identity.toCompactJson(),
    ],
    'retainedInstanceCountFollowingRelations':
        retainedInstancesFollowingRelations.length,
    'retainedInstanceCountOutsideRelations':
        retainedInstancesOutsideRelations.length,
  };
}

/// Threshold-free transition evidence for one endpoint candidate pair.
@immutable
final class PolychordCandidateTransitionEvidence {
  @internal
  PolychordCandidateTransitionEvidence.internal({
    required this.sourceCandidateIndex,
    required this.targetCandidateIndex,
    required this.sourceCandidate,
    required this.targetCandidate,
    required this.instanceContinuity,
    required Iterable<PolychordLayerRelationEvidence> layerRelations,
    required Iterable<PolychordLayerCorrespondenceHypothesis>
    layerCorrespondenceHypotheses,
  }) : layerRelations = List.unmodifiable(layerRelations),
       layerCorrespondenceHypotheses = List.unmodifiable(
         layerCorrespondenceHypotheses,
       );

  final int sourceCandidateIndex;
  final int targetCandidateIndex;
  final PolychordCandidate sourceCandidate;
  final PolychordCandidate targetCandidate;
  final PolychordInstanceContinuity instanceContinuity;
  final List<PolychordLayerRelationEvidence> layerRelations;
  final List<PolychordLayerCorrespondenceHypothesis>
  layerCorrespondenceHypotheses;

  Map<String, Object> toJson() => <String, Object>{
    'sourceCandidateIndex': sourceCandidateIndex,
    'targetCandidateIndex': targetCandidateIndex,
    'sameSymbol': sourceCandidate.symbol == targetCandidate.symbol,
    'sameExactCandidate': sourceCandidate == targetCandidate,
    'instanceContinuity': instanceContinuity.toJson(),
    'layerRelations': [
      for (final relation in layerRelations) relation.toJson(),
    ],
    'layerCorrespondenceHypotheses': [
      for (final hypothesis in layerCorrespondenceHypotheses)
        hypothesis.toJson(),
    ],
  };
}

/// One normalized event paired with the complete tracker frame it produced.
///
/// Keeping this pairing prevents zero-dwell note-off, note-on, and pedal order
/// from disappearing between caller-selected endpoints.
@immutable
final class PolychordFrameTransitionStep {
  PolychordFrameTransitionStep({required this.event, required this.frame}) {
    if (event.timestampMs != frame.timestampMs) {
      throw ArgumentError(
        'transition-step event and frame timestamps must match',
      );
    }
  }

  final PolychordTemporalEvent event;
  final PolychordReleasePedalTrackingFrame frame;

  Map<String, Object> toJson() => <String, Object>{
    'event': _eventToJson(event, frame.afterEventIndex),
    'frame': _replayFrameToJson(frame),
  };
}

/// Complete, gap-free event/frame provenance between selected endpoints.
@immutable
final class PolychordFrameTransitionWindow {
  factory PolychordFrameTransitionWindow({
    required PolychordReleasePedalTrackingFrame sourceFrame,
    required Iterable<PolychordFrameTransitionStep> transitionSteps,
  }) {
    final steps = List<PolychordFrameTransitionStep>.unmodifiable(
      transitionSteps,
    );
    if (steps.isEmpty) {
      throw ArgumentError.value(
        transitionSteps,
        'transitionSteps',
        'must contain at least the target event and frame',
      );
    }
    var priorFrame = sourceFrame;
    for (final step in steps) {
      final frame = step.frame;
      if (frame.trackerEpoch != sourceFrame.trackerEpoch) {
        throw ArgumentError(
          'transition window must remain within one tracker epoch',
        );
      }
      if (frame.afterEventIndex != priorFrame.afterEventIndex + 1) {
        throw ArgumentError(
          'transition window must contain every consecutive event frame',
        );
      }
      if (frame.timestampMs < priorFrame.timestampMs) {
        throw ArgumentError(
          'transition-window timestamps must be nondecreasing',
        );
      }
      _validateEventTransition(priorFrame, step);
      priorFrame = frame;
    }
    return PolychordFrameTransitionWindow._(
      sourceFrame: sourceFrame,
      transitionSteps: steps,
    );
  }

  const PolychordFrameTransitionWindow._({
    required this.sourceFrame,
    required this.transitionSteps,
  });

  final PolychordReleasePedalTrackingFrame sourceFrame;
  final List<PolychordFrameTransitionStep> transitionSteps;

  PolychordReleasePedalTrackingFrame get targetFrame =>
      transitionSteps.last.frame;

  int get elapsedMs => targetFrame.timestampMs - sourceFrame.timestampMs;
  int get transitionEventCount => transitionSteps.length;
  int get interveningFrameCount => transitionSteps.length - 1;

  Map<String, Object> toJson() => <String, Object>{
    'sourceFrame': _replayFrameToJson(sourceFrame),
    'targetFrame': _replayFrameToJson(targetFrame),
    'elapsedMs': elapsedMs,
    'transitionEventCount': transitionEventCount,
    'interveningFrameCount': interveningFrameCount,
    'transitionSteps': [for (final step in transitionSteps) step.toJson()],
  };
}

/// Complete candidate surface for one caller-selected transition window.
@immutable
final class PolychordFrameTransitionEvidence {
  @internal
  PolychordFrameTransitionEvidence.internal({
    required this.window,
    required Iterable<PolychordCandidate> sourceCandidates,
    required Iterable<PolychordCandidate> targetCandidates,
    required Iterable<PolychordCandidateTransitionEvidence>
    candidateTransitions,
  }) : sourceCandidates = List.unmodifiable(sourceCandidates),
       targetCandidates = List.unmodifiable(targetCandidates),
       candidateTransitions = List.unmodifiable(candidateTransitions);

  final PolychordFrameTransitionWindow window;
  final List<PolychordCandidate> sourceCandidates;
  final List<PolychordCandidate> targetCandidates;
  final List<PolychordCandidateTransitionEvidence> candidateTransitions;

  PolychordReleasePedalTrackingFrame get sourceFrame => window.sourceFrame;
  PolychordReleasePedalTrackingFrame get targetFrame => window.targetFrame;
  int get elapsedMs => window.elapsedMs;

  Map<String, Object> toJson() => <String, Object>{
    'window': window.toJson(),
    'sourceCandidates': [
      for (final candidate in sourceCandidates) candidate.toJson(),
    ],
    'targetCandidates': [
      for (final candidate in targetCandidates) candidate.toJson(),
    ],
    'candidateTransitions': [
      for (final transition in candidateTransitions) transition.toJson(),
    ],
  };
}

Map<String, Object> _eventToJson(
  PolychordTemporalEvent event,
  int eventIndex,
) => switch (event) {
  PolychordNoteOnEvent(:final midiNote, :final velocity) => <String, Object>{
    'index': eventIndex,
    'timestampMs': event.timestampMs,
    'type': 'noteOn',
    'midiNote': midiNote,
    'velocity': velocity,
  },
  PolychordNoteOffEvent(:final midiNote, :final velocity) => <String, Object>{
    'index': eventIndex,
    'timestampMs': event.timestampMs,
    'type': 'noteOff',
    'midiNote': midiNote,
    'velocity': velocity,
  },
  PolychordSustainPedalEvent(:final down) => <String, Object>{
    'index': eventIndex,
    'timestampMs': event.timestampMs,
    'type': 'pedal',
    'down': down,
  },
};

void _validateEventTransition(
  PolychordReleasePedalTrackingFrame priorFrame,
  PolychordFrameTransitionStep step,
) {
  final event = step.event;
  final frame = step.frame;
  final eventIndex = frame.afterEventIndex;
  var pedalDown = priorFrame.pedalDown;
  var pedalTransition = priorFrame.pedalTransition;
  final notes = {
    for (final note in priorFrame.soundingNoteHistories) note.midiNote: note,
  };

  switch (event) {
    case PolychordNoteOnEvent(:final midiNote, :final velocity):
      final prior = notes[midiNote];
      if (prior?.soundingState == PolychordSoundingState.pressed) {
        throw ArgumentError('transition step repeats a pressed note-on');
      }
      final origin = PolychordNoteEventOrigin(
        eventIndex: eventIndex,
        timestampMs: event.timestampMs,
        velocity: velocity,
      );
      final reattacked =
          prior?.soundingState == PolychordSoundingState.sustained;
      notes[midiNote] = PolychordSoundingNoteHistory(
        midiNote: midiNote,
        soundingState: PolychordSoundingState.pressed,
        onset: origin,
        release: null,
        currentStateSince: origin,
        reattackedFromSustain: reattacked,
        priorSustainRelease: reattacked ? prior?.release : null,
      );
    case PolychordNoteOffEvent(:final midiNote, :final velocity):
      final prior = notes[midiNote];
      if (prior?.soundingState != PolychordSoundingState.pressed) {
        throw ArgumentError('transition step releases a note not pressed');
      }
      if (pedalDown) {
        final origin = PolychordNoteEventOrigin(
          eventIndex: eventIndex,
          timestampMs: event.timestampMs,
          velocity: velocity,
        );
        notes[midiNote] = PolychordSoundingNoteHistory(
          midiNote: midiNote,
          soundingState: PolychordSoundingState.sustained,
          onset: prior!.onset,
          release: origin,
          currentStateSince: origin,
          reattackedFromSustain: prior.reattackedFromSustain,
          priorSustainRelease: prior.priorSustainRelease,
        );
      } else {
        notes.remove(midiNote);
      }
    case PolychordSustainPedalEvent(:final down):
      if (down == pedalDown) {
        throw ArgumentError('transition step repeats the current pedal state');
      }
      pedalDown = down;
      pedalTransition = PolychordPedalTransition(
        eventIndex: eventIndex,
        timestampMs: event.timestampMs,
        down: down,
      );
      if (!down) {
        notes.removeWhere(
          (_, note) => note.soundingState == PolychordSoundingState.sustained,
        );
      }
  }

  final midiNotes = notes.keys.toList()..sort();
  final expected = PolychordReleasePedalTrackingFrame(
    trackerEpoch: priorFrame.trackerEpoch,
    afterEventIndex: eventIndex,
    timestampMs: event.timestampMs,
    pedalDown: pedalDown,
    pedalTransition: pedalTransition,
    soundingNoteHistories: [for (final midiNote in midiNotes) notes[midiNote]!],
  );
  if (expected != frame) {
    throw ArgumentError(
      'transition-step frame must be the exact result of its paired event',
    );
  }
}

Map<String, Object> _replayFrameToJson(
  PolychordReleasePedalTrackingFrame frame,
) => <String, Object>{
  'afterEventIndex': frame.afterEventIndex,
  'timestampMs': frame.timestampMs,
  'pressedMidiNotes': [
    for (final note in frame.soundingNoteHistories)
      if (note.soundingState == PolychordSoundingState.pressed) note.midiNote,
  ],
  'sustainedMidiNotes': [
    for (final note in frame.soundingNoteHistories)
      if (note.soundingState == PolychordSoundingState.sustained) note.midiNote,
  ],
  'soundingMidiNotes': [
    for (final note in frame.soundingNoteHistories) note.midiNote,
  ],
  'pedalDown': frame.pedalDown,
};

const _intListEquality = ListEquality<int>();
