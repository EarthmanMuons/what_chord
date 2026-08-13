import 'package:meta/meta.dart';

import 'polychord_candidate_instance_binding.dart';
import 'polychord_onset_support.dart';
import 'polychord_onset_tracking_frame.dart';

/// Whether a cue has enough causal history to be interpreted for a binding.
enum PolychordCueAvailability { complete, incomplete, unavailable }

/// One-sided cue support for a candidate's chordal-layer decomposition.
enum PolychordCueSupport { positive, neutral }

/// Diagnostic onset interpretation bound to one exact frame and candidate.
///
/// This record implements the cue-record shape of `polychord-output/2`, but is
/// not a licensing-cue declaration and cannot authorize selection or display.
@immutable
final class PolychordCandidateOnsetCueRecord {
  @internal
  const PolychordCandidateOnsetCueRecord.internal({
    required this.targetObservation,
    required this.targetBinding,
    required this.interpretation,
    required this.availability,
    required this.support,
  });

  static const cueId = 'coherent-separated-onsets-50-200ms/1';
  static const evidenceSchemaId = 'polychord-onset-evidence/1';

  /// Current event frame whose onset provenance supplies the interpretation.
  final PolychordOnsetTrackingFrame targetObservation;

  /// Exact candidate assignment and reset-scoped sounding instances.
  final PolychordCandidateInstanceBinding targetBinding;

  /// Complete underlying diagnostic, retained without collapsing its fields.
  final PolychordCandidateOnsetInterpretation interpretation;

  final PolychordCueAvailability availability;

  /// Null when [availability] is not [PolychordCueAvailability.complete].
  final PolychordCueSupport? support;

  List<String> get reasonCodes => interpretation.reasonCodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'cueId': cueId,
    'evidenceSchemaId': evidenceSchemaId,
    'targetObservation': targetObservation.toJson(),
    'targetBinding': targetBinding.toJson(),
    'availability': availability.name,
    'support': support?.name,
    'reasonCodes': reasonCodes,
    'diagnostic': interpretation.toJson(),
  };
}
