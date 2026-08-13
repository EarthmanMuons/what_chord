import '../models/polychord_candidate.dart';
import '../models/polychord_candidate_instance_binding.dart';
import '../models/polychord_onset_evidence.dart';
import '../models/polychord_onset_tracking_frame.dart';
import '../models/polychord_release_pedal_evidence.dart';
import '../models/polychord_sounding_instance_key.dart';
import 'polychord_onset_evidence_analyzer.dart';

/// Binds structural candidates to reset-scoped sounding-note identities.
///
/// Binding and revalidation implement causal bookkeeping only. They do not
/// interpret evidence, choose licensing cues, select candidates, or expire a
/// binding based on elapsed time.
final class PolychordCandidateInstanceBinder {
  const PolychordCandidateInstanceBinder();

  /// Binds every candidate generated from one current sounding state.
  List<PolychordCandidateInstanceBinding> bindOnsetFrame(
    PolychordOnsetTrackingFrame frame,
  ) => _bindFrame(
    trackerEpoch: frame.trackerEpoch,
    soundingNotes: frame.soundingNoteOnsets,
  );

  /// Binds every candidate in one richer release/pedal tracking frame.
  List<PolychordCandidateInstanceBinding> bindReleasePedalFrame(
    PolychordReleasePedalTrackingFrame frame,
  ) => _bindFrame(
    trackerEpoch: frame.trackerEpoch,
    soundingNotes: frame.soundingNoteHistories.map(
      (history) => history.onsetObservation,
    ),
  );

  /// Binds one exact generated candidate to the current sounding instances.
  PolychordCandidateInstanceBinding bindCandidateToOnsetFrame({
    required PolychordCandidate candidate,
    required PolychordOnsetTrackingFrame frame,
  }) => _bindCandidate(
    trackerEpoch: frame.trackerEpoch,
    candidate: candidate,
    soundingNotes: frame.soundingNoteOnsets,
  );

  /// Binds one exact candidate to a release/pedal tracking frame.
  PolychordCandidateInstanceBinding bindCandidateToReleasePedalFrame({
    required PolychordCandidate candidate,
    required PolychordReleasePedalTrackingFrame frame,
  }) => _bindCandidate(
    trackerEpoch: frame.trackerEpoch,
    candidate: candidate,
    soundingNotes: frame.soundingNoteHistories.map(
      (history) => history.onsetObservation,
    ),
  );

  /// Whether the exact candidate, note assignment, and instances still match.
  ///
  /// Sustain-state changes may preserve a binding. A reattack, note-set change,
  /// candidate change, or tracker reset invalidates it.
  bool remainsCurrentInOnsetFrame({
    required PolychordCandidateInstanceBinding binding,
    required PolychordOnsetTrackingFrame frame,
  }) => bindOnsetFrame(frame).contains(binding);

  /// Revalidates a binding against one release/pedal tracking frame.
  bool remainsCurrentInReleasePedalFrame({
    required PolychordCandidateInstanceBinding binding,
    required PolychordReleasePedalTrackingFrame frame,
  }) => bindReleasePedalFrame(frame).contains(binding);
}

List<PolychordCandidateInstanceBinding> _bindFrame({
  required int trackerEpoch,
  required Iterable<PolychordSoundingNoteOnset> soundingNotes,
}) {
  final evidence = const PolychordOnsetEvidenceAnalyzer().analyzeFrame(
    soundingNotes,
  );
  return List<PolychordCandidateInstanceBinding>.unmodifiable(
    evidence.map(
      (item) => _bindEvidence(trackerEpoch: trackerEpoch, evidence: item),
    ),
  );
}

PolychordCandidateInstanceBinding _bindCandidate({
  required int trackerEpoch,
  required PolychordCandidate candidate,
  required Iterable<PolychordSoundingNoteOnset> soundingNotes,
}) {
  final evidence = const PolychordOnsetEvidenceAnalyzer().analyzeCandidate(
    candidate,
    soundingNotes,
  );
  return _bindEvidence(trackerEpoch: trackerEpoch, evidence: evidence);
}

PolychordCandidateInstanceBinding _bindEvidence({
  required int trackerEpoch,
  required PolychordCandidateOnsetEvidence evidence,
}) {
  final instances =
      [
          ...evidence.lower.notes,
          ...evidence.upper.notes,
        ].map(PolychordSoundingInstanceKey.fromOnset).toList()
        ..sort((left, right) => left.midiNote.compareTo(right.midiNote));
  return PolychordCandidateInstanceBinding.internal(
    trackerEpoch: trackerEpoch,
    candidate: evidence.candidate,
    targetInstances: instances,
  );
}
