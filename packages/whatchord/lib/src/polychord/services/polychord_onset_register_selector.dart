import '../models/polychord_candidate.dart';
import '../models/polychord_onset_cue_record.dart';
import '../models/polychord_onset_tracking_frame.dart';
import '../models/polychord_product_decision.dart';
import '../models/polychord_product_onset_cue_record.dart';
import 'polychord_product_onset_cue_record_builder.dart';
import 'polychord_register_candidate_generator.dart';
import 'polychord_register_selector.dart';

/// Frozen implementation of `polychord-onset-register-policy/1`.
final class PolychordOnsetRegisterSelector {
  const PolychordOnsetRegisterSelector();

  PolychordOnsetRegisterDecision decide(PolychordOnsetTrackingFrame frame) {
    final generated = const PolychordRegisterCandidateGenerator().generateSet(
      frame.soundingMidiNotes,
    );
    final records = const PolychordProductOnsetCueRecordBuilder()
        .buildGenerated(frame, generated);
    return _decideOrdered(frame, generated, records);
  }

  /// Decides from a complete record set without treating its order as evidence.
  PolychordOnsetRegisterDecision decideRecords(
    PolychordOnsetTrackingFrame frame,
    Iterable<PolychordProductOnsetCueRecord> candidateRecords,
  ) {
    final generated = const PolychordRegisterCandidateGenerator().generateSet(
      frame.soundingMidiNotes,
    );
    final records = _validateAndOrderRecords(
      frame,
      generated.candidates,
      candidateRecords,
    );
    return _decideOrdered(frame, generated, records);
  }

  PolychordOnsetRegisterDecision _decideOrdered(
    PolychordOnsetTrackingFrame frame,
    PolychordGeneratedCandidateSet generated,
    List<PolychordProductOnsetCueRecord> records,
  ) {
    final candidates = generated.candidates;
    final staticTraces = const PolychordRegisterSelector().evaluateGenerated(
      generated,
      profile: PolychordRegisterSelectorProfile.withoutGapResolution,
    );
    final assignment = <PolychordCandidate>[];
    final integrated = <PolychordCandidate>[];
    final positive = <PolychordCandidate>[];
    final aggregateSupport = <PolychordProductAggregateSupport>[];
    final removals = <PolychordProductRemovalStage?>[];
    var hasNeutralIntegratedCandidate = false;
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final staticTrace = staticTraces[index];
      final aggregate = _aggregate(records[index]);
      aggregateSupport.add(aggregate);
      if (staticTrace.removedByAssignmentVeto) {
        removals.add(PolychordProductRemovalStage.assignment);
        continue;
      }
      assignment.add(candidate);
      if (staticTrace.removedByIntegratedTertianVeto) {
        removals.add(PolychordProductRemovalStage.integrated);
        continue;
      }
      integrated.add(candidate);
      if (aggregate == PolychordProductAggregateSupport.neutral) {
        hasNeutralIntegratedCandidate = true;
      }
      if (aggregate != PolychordProductAggregateSupport.positive) {
        removals.add(PolychordProductRemovalStage.support);
        continue;
      }
      positive.add(candidate);
      removals.add(null);
    }
    if (positive.length > 1) {
      throw StateError('positive-survivor uniqueness was violated');
    }

    final reasonCode = switch ((
      candidates.isEmpty,
      assignment.isEmpty,
      integrated.isEmpty,
      positive.isEmpty,
    )) {
      (true, _, _, _) => 'no-structural-candidate',
      (false, true, _, _) => 'ambiguous-exact-assignment',
      (false, false, true, _) => 'integrated-tertian-reading',
      (false, false, false, true) =>
        hasNeutralIntegratedCandidate
            ? 'layer-separation-not-supported'
            : 'missing-layer-separation-history',
      (false, false, false, false) => null,
    };
    final selected = positive.isEmpty ? null : positive.single;
    final traces = <PolychordProductCandidateTrace>[];
    for (var index = 0; index < candidates.length; index++) {
      final candidate = candidates[index];
      final staticTrace = staticTraces[index];
      traces.add(
        PolychordProductCandidateTrace(
          candidate: candidate,
          identityAssignmentCount: staticTrace.identityAssignmentCount,
          integratedTertian: PolychordProductIntegratedTertianTests(
            compact: staticTrace.integratedTertian.compact,
            rootedNinth: staticTrace.integratedTertian.rootedNinth,
            rootedSeventhExtension:
                staticTrace.integratedTertian.rootedSeventhExtension,
          ),
          aggregateSupport: aggregateSupport[index],
          removedAt: removals[index],
          selected: candidate == selected,
        ),
      );
    }
    final stages = PolychordProductStageSurvivors(
      structural: candidates,
      assignment: assignment,
      integrated: integrated,
      positiveSupport: positive,
    );
    return PolychordOnsetRegisterDecision(
      targetObservation: frame,
      candidates: candidates,
      candidateRecords: records,
      stageSurvivors: stages,
      candidateTraces: traces,
      selected: selected,
      selectedBinding: selected == null
          ? null
          : records[candidates.indexOf(selected)].targetBinding,
      reasonCode: reasonCode,
      terminalPredicates: _terminalPredicates(stages, reasonCode),
    );
  }
}

List<PolychordProductOnsetCueRecord> _validateAndOrderRecords(
  PolychordOnsetTrackingFrame frame,
  List<PolychordCandidate> candidates,
  Iterable<PolychordProductOnsetCueRecord> candidateRecords,
) {
  final supplied = List<PolychordProductOnsetCueRecord>.of(candidateRecords);
  if (supplied.length != candidates.length) {
    throw ArgumentError.value(
      candidateRecords,
      'candidateRecords',
      'must cover the complete generated candidate set',
    );
  }
  final byCandidate = <PolychordCandidate, PolychordProductOnsetCueRecord>{};
  for (final record in supplied) {
    if (record.targetObservation != frame) {
      throw ArgumentError.value(
        candidateRecords,
        'candidateRecords',
        'must target the selected frame',
      );
    }
    if (byCandidate.containsKey(record.targetBinding.candidate)) {
      throw ArgumentError.value(
        candidateRecords,
        'candidateRecords',
        'must not contain duplicate candidates',
      );
    }
    byCandidate[record.targetBinding.candidate] = record;
  }
  if (!candidates.every(byCandidate.containsKey)) {
    throw ArgumentError.value(
      candidateRecords,
      'candidateRecords',
      'must match the complete generated candidate set',
    );
  }
  return [for (final candidate in candidates) byCandidate[candidate]!];
}

PolychordProductAggregateSupport _aggregate(
  PolychordProductOnsetCueRecord record,
) => switch ((record.availability, record.support)) {
  (PolychordCueAvailability.complete, PolychordCueSupport.positive) =>
    PolychordProductAggregateSupport.positive,
  (PolychordCueAvailability.complete, PolychordCueSupport.neutral) =>
    PolychordProductAggregateSupport.neutral,
  _ => PolychordProductAggregateSupport.unavailable,
};

List<PolychordProductTerminalPredicate> _terminalPredicates(
  PolychordProductStageSurvivors stages,
  String? reasonCode,
) {
  final values = <(String, int, String?)>[
    ('structural', stages.structural.length, 'no-structural-candidate'),
    ('assignment', stages.assignment.length, 'ambiguous-exact-assignment'),
    ('integrated', stages.integrated.length, 'integrated-tertian-reading'),
    (
      'positiveSupport',
      stages.positiveSupport.length,
      switch (reasonCode) {
        'layer-separation-not-supported' ||
        'missing-layer-separation-history' => reasonCode,
        _ => null,
      },
    ),
  ];
  return List.unmodifiable([
    for (final (stage, survivorCount, stageReason) in values)
      PolychordProductTerminalPredicate(
        stage: stage,
        survivorCount: survivorCount,
        terminal: reasonCode != null && stageReason == reasonCode,
      ),
  ]);
}
