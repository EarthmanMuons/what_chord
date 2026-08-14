import '../models/polychord_candidate_instance_binding.dart';
import '../models/polychord_onset_cue_record.dart';
import '../models/polychord_onset_support.dart';
import '../models/polychord_onset_tracking_frame.dart';
import '../models/polychord_product_onset_cue_record.dart';
import 'polychord_candidate_instance_binder.dart';
import 'polychord_onset_evidence_analyzer.dart';
import 'polychord_product_onset_interpreter.dart';

/// Builds every exact candidate-bound record for the product onset cue.
final class PolychordProductOnsetCueRecordBuilder {
  const PolychordProductOnsetCueRecordBuilder();

  List<PolychordProductOnsetCueRecord> build(
    PolychordOnsetTrackingFrame frame,
  ) {
    final evidence = const PolychordOnsetEvidenceAnalyzer().analyzeFrame(
      frame.soundingNoteOnsets,
    );
    final interpretations = const PolychordProductOnsetInterpreter()
        .interpretAll(evidence);
    final bindings = const PolychordCandidateInstanceBinder().bindOnsetFrame(
      frame,
    );
    if (interpretations.length != bindings.length) {
      throw StateError('onset interpretations and bindings must align');
    }
    return List<PolychordProductOnsetCueRecord>.unmodifiable([
      for (var index = 0; index < interpretations.length; index++)
        _buildRecord(
          interpretation: interpretations[index],
          binding: bindings[index],
          frame: frame,
        ),
    ]);
  }
}

PolychordProductOnsetCueRecord _buildRecord({
  required PolychordCandidateOnsetInterpretation interpretation,
  required PolychordCandidateInstanceBinding binding,
  required PolychordOnsetTrackingFrame frame,
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
  return PolychordProductOnsetCueRecord.internal(
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
