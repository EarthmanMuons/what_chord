import 'package:meta/meta.dart';

import 'polychord_candidate_instance_binding.dart';
import 'polychord_onset_cue_record.dart';
import 'polychord_onset_support.dart';
import 'polychord_onset_tracking_frame.dart';

/// Product-licensing onset cue bound to one exact candidate and note instance.
@immutable
final class PolychordProductOnsetCueRecord {
  @internal
  const PolychordProductOnsetCueRecord.internal({
    required this.targetObservation,
    required this.targetBinding,
    required this.interpretation,
    required this.availability,
    required this.support,
  });

  static const cueId = 'coherent-separated-onsets-50-80ms/product-1';
  static const evidenceSchemaId = 'polychord-onset-evidence/1';

  final PolychordOnsetTrackingFrame targetObservation;
  final PolychordCandidateInstanceBinding targetBinding;
  final PolychordCandidateOnsetInterpretation interpretation;
  final PolychordCueAvailability availability;
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
