import '../models/polychord_candidate_instance_binding.dart';
import '../models/polychord_onset_cue_record.dart';
import '../models/polychord_onset_support.dart';
import '../models/polychord_onset_tracking_frame.dart';
import 'polychord_candidate_instance_binder.dart';
import 'polychord_coherent_separated_onset_interpreter.dart';
import 'polychord_onset_evidence_analyzer.dart';

/// Builds complete diagnostic records for the fixed onset interpretation.
///
/// The builder retains every candidate in generator order. It does not name a
/// licensing cue, aggregate support, rank candidates, or authorize a display.
final class PolychordOnsetCueRecordBuilder {
  const PolychordOnsetCueRecordBuilder();

  List<PolychordCandidateOnsetCueRecord> build(
    PolychordOnsetTrackingFrame frame,
  ) {
    final evidence = const PolychordOnsetEvidenceAnalyzer().analyzeFrame(
      frame.soundingNoteOnsets,
    );
    final interpretations = const PolychordCoherentSeparatedOnsetInterpreter()
        .interpretAll(evidence);
    final bindings = const PolychordCandidateInstanceBinder().bindOnsetFrame(
      frame,
    );
    if (interpretations.length != bindings.length) {
      throw StateError('onset interpretations and bindings must align');
    }
    return List<PolychordCandidateOnsetCueRecord>.unmodifiable([
      for (var index = 0; index < interpretations.length; index++)
        _buildRecord(
          frame: frame,
          interpretation: interpretations[index],
          binding: bindings[index],
        ),
    ]);
  }
}

PolychordCandidateOnsetCueRecord _buildRecord({
  required PolychordOnsetTrackingFrame frame,
  required PolychordCandidateOnsetInterpretation interpretation,
  required PolychordCandidateInstanceBinding binding,
}) {
  if (interpretation.evidence.candidate != binding.candidate) {
    throw StateError('onset interpretation and binding candidates must match');
  }
  final complete =
      interpretation.availability == PolychordOnsetSupportAvailability.complete;
  if (complete != binding.isComplete) {
    throw StateError(
      'onset interpretation and instance-binding availability must agree',
    );
  }
  return PolychordCandidateOnsetCueRecord.internal(
    targetObservation: frame,
    targetBinding: binding,
    interpretation: interpretation,
    availability: complete
        ? PolychordCueAvailability.complete
        : PolychordCueAvailability.incomplete,
    support: complete
        ? switch (interpretation.onsetCohortSupport) {
            PolychordOnsetCohortSupport.positive =>
              PolychordCueSupport.positive,
            PolychordOnsetCohortSupport.neutral => PolychordCueSupport.neutral,
          }
        : null,
  );
}
