import 'package:meta/meta.dart';

import 'polychord_candidate.dart';
import 'polychord_candidate_instance_binding.dart';
import 'polychord_onset_tracking_frame.dart';
import 'polychord_product_onset_cue_record.dart';

enum PolychordProductAggregateSupport { positive, neutral, unavailable }

enum PolychordProductRemovalStage { assignment, integrated, support }

/// Product-local copy of the three frozen integrated-tertian predicates.
@immutable
final class PolychordProductIntegratedTertianTests {
  const PolychordProductIntegratedTertianTests({
    required this.compact,
    required this.rootedNinth,
    required this.rootedSeventhExtension,
  });

  final bool compact;
  final bool rootedNinth;
  final bool rootedSeventhExtension;

  Map<String, bool> toJson() => <String, bool>{
    'compact': compact,
    'rootedNinth': rootedNinth,
    'rootedSeventhExtension': rootedSeventhExtension,
  };
}

/// Complete candidate trace through every ordered selector stage.
@immutable
final class PolychordProductCandidateTrace {
  const PolychordProductCandidateTrace({
    required this.candidate,
    required this.identityAssignmentCount,
    required this.integratedTertian,
    required this.aggregateSupport,
    required this.removedAt,
    required this.selected,
  });

  final PolychordCandidate candidate;
  final int identityAssignmentCount;
  final PolychordProductIntegratedTertianTests integratedTertian;
  final PolychordProductAggregateSupport aggregateSupport;
  final PolychordProductRemovalStage? removedAt;
  final bool selected;

  Map<String, Object?> toJson() => <String, Object?>{
    'candidate': candidate.toJson(),
    'identityAssignmentCount': identityAssignmentCount,
    'integratedTertian': integratedTertian.toJson(),
    'aggregateSupport': aggregateSupport.name,
    'removedAt': removedAt?.name,
    'selected': selected,
  };
}

/// Candidates surviving each ordered selector stage in canonical order.
@immutable
final class PolychordProductStageSurvivors {
  PolychordProductStageSurvivors({
    required Iterable<PolychordCandidate> structural,
    required Iterable<PolychordCandidate> assignment,
    required Iterable<PolychordCandidate> integrated,
    required Iterable<PolychordCandidate> positiveSupport,
  }) : structural = List.unmodifiable(structural),
       assignment = List.unmodifiable(assignment),
       integrated = List.unmodifiable(integrated),
       positiveSupport = List.unmodifiable(positiveSupport);

  final List<PolychordCandidate> structural;
  final List<PolychordCandidate> assignment;
  final List<PolychordCandidate> integrated;
  final List<PolychordCandidate> positiveSupport;

  Map<String, Object> toJson() => <String, Object>{
    'structural': [for (final candidate in structural) candidate.toJson()],
    'assignment': [for (final candidate in assignment) candidate.toJson()],
    'integrated': [for (final candidate in integrated) candidate.toJson()],
    'positiveSupport': [
      for (final candidate in positiveSupport) candidate.toJson(),
    ],
  };
}

/// Ordered terminal diagnostic for one selector stage.
@immutable
final class PolychordProductTerminalPredicate {
  const PolychordProductTerminalPredicate({
    required this.stage,
    required this.survivorCount,
    required this.terminal,
  });

  final String stage;
  final int survivorCount;
  final bool terminal;

  Map<String, Object> toJson() => <String, Object>{
    'stage': stage,
    'survivorCount': survivorCount,
    'terminal': terminal,
  };
}

/// Raw result from `polychord-onset-register-policy/1`.
@immutable
final class PolychordOnsetRegisterDecision {
  PolychordOnsetRegisterDecision({
    required this.targetObservation,
    required Iterable<PolychordCandidate> candidates,
    required Iterable<PolychordProductOnsetCueRecord> candidateRecords,
    required this.stageSurvivors,
    required Iterable<PolychordProductCandidateTrace> candidateTraces,
    required this.selected,
    required this.selectedBinding,
    required this.reasonCode,
    required Iterable<PolychordProductTerminalPredicate> terminalPredicates,
  }) : candidates = List.unmodifiable(candidates),
       candidateRecords = List.unmodifiable(candidateRecords),
       candidateTraces = List.unmodifiable(candidateTraces),
       terminalPredicates = List.unmodifiable(terminalPredicates);

  static const schema = 'polychord-onset-register-decision/1';
  static const selectorId = 'polychord-onset-register-policy/1';

  final PolychordOnsetTrackingFrame targetObservation;
  final List<PolychordCandidate> candidates;
  final List<PolychordProductOnsetCueRecord> candidateRecords;
  final PolychordProductStageSurvivors stageSurvivors;
  final List<PolychordProductCandidateTrace> candidateTraces;
  final PolychordCandidate? selected;
  final PolychordCandidateInstanceBinding? selectedBinding;
  final String? reasonCode;
  final List<PolychordProductTerminalPredicate> terminalPredicates;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'selectorId': selectorId,
    'targetObservation': targetObservation.toJson(),
    'candidates': [for (final candidate in candidates) candidate.toJson()],
    'candidateRecords': [
      for (final record in candidateRecords) record.toJson(),
    ],
    'stageSurvivors': stageSurvivors.toJson(),
    'candidateTraces': [for (final trace in candidateTraces) trace.toJson()],
    'selected': selected?.toJson(),
    'selectedBinding': selectedBinding?.toJson(),
    'reasonCode': reasonCode,
    'terminalPredicates': [
      for (final predicate in terminalPredicates) predicate.toJson(),
    ],
  };
}
