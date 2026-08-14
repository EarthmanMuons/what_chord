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

  PolychordOnsetRegisterDecision decide(PolychordOnsetTrackingFrame frame) =>
      decideRecords(
        frame,
        const PolychordProductOnsetCueRecordBuilder().build(frame),
      );

  /// Decides from a complete record set without treating its order as evidence.
  PolychordOnsetRegisterDecision decideRecords(
    PolychordOnsetTrackingFrame frame,
    Iterable<PolychordProductOnsetCueRecord> candidateRecords,
  ) {
    final candidates = const PolychordRegisterCandidateGenerator().generate(
      frame.soundingMidiNotes,
    );
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
    final records = [
      for (final candidate in candidates) byCandidate[candidate]!,
    ];

    final staticDecision = const PolychordRegisterSelector().decideCandidates(
      frame.soundingMidiNotes,
      candidates,
      profile: PolychordRegisterSelectorProfile.withoutGapResolution,
    );
    final staticByCandidate = {
      for (final trace in staticDecision.traces) trace.candidate: trace,
    };
    final assignment = [
      for (final candidate in candidates)
        if (!staticByCandidate[candidate]!.removedByAssignmentVeto) candidate,
    ];
    final integrated = [
      for (final candidate in assignment)
        if (!staticByCandidate[candidate]!.removedByIntegratedTertianVeto)
          candidate,
    ];
    final positive = [
      for (final candidate in integrated)
        if (_aggregate(byCandidate[candidate]!) ==
            PolychordProductAggregateSupport.positive)
          candidate,
    ];
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
        integrated.any(
              (candidate) =>
                  _aggregate(byCandidate[candidate]!) ==
                  PolychordProductAggregateSupport.neutral,
            )
            ? 'layer-separation-not-supported'
            : 'missing-layer-separation-history',
      (false, false, false, false) => null,
    };
    final selected = positive.isEmpty ? null : positive.single;
    final traces = <PolychordProductCandidateTrace>[];
    for (final candidate in candidates) {
      final staticTrace = staticByCandidate[candidate]!;
      final removal = !assignment.contains(candidate)
          ? PolychordProductRemovalStage.assignment
          : !integrated.contains(candidate)
          ? PolychordProductRemovalStage.integrated
          : !positive.contains(candidate)
          ? PolychordProductRemovalStage.support
          : null;
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
          aggregateSupport: _aggregate(byCandidate[candidate]!),
          removedAt: removal,
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
          : byCandidate[selected]!.targetBinding,
      reasonCode: reasonCode,
      terminalPredicates: _terminalPredicates(stages, reasonCode),
    );
  }
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
