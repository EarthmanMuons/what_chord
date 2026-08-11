import 'package:meta/meta.dart';

import '../models/polychord_candidate.dart';
import 'polychord_register_candidate_generator.dart';

/// Full selector and fixed leave-one-component-out diagnostic profiles.
enum PolychordRegisterSelectorProfile {
  full(
    selectorId: 'polychord-register-policy/1',
    assignmentVeto: true,
    integratedTertianVeto: true,
    gapResolution: true,
  ),
  withoutIntegratedTertianVeto(
    selectorId: 'polychord-register-policy-without-integrated-tertian-veto/1',
    assignmentVeto: true,
    integratedTertianVeto: false,
    gapResolution: true,
  ),
  withoutAssignmentVeto(
    selectorId: 'polychord-register-policy-without-assignment-veto/1',
    assignmentVeto: false,
    integratedTertianVeto: true,
    gapResolution: true,
  ),
  withoutGapResolution(
    selectorId: 'polychord-register-policy-without-gap-resolution/1',
    assignmentVeto: true,
    integratedTertianVeto: true,
    gapResolution: false,
  );

  const PolychordRegisterSelectorProfile({
    required this.selectorId,
    required this.assignmentVeto,
    required this.integratedTertianVeto,
    required this.gapResolution,
  });

  /// Stable selector identifier recorded in decisions and measurements.
  final String selectorId;

  final bool assignmentVeto;
  final bool integratedTertianVeto;
  final bool gapResolution;
}

/// Named integrated-tertian predicates retained for diagnostics.
@immutable
final class IntegratedTertianTests {
  const IntegratedTertianTests({
    required this.compact,
    required this.rootedNinth,
    required this.rootedSeventhExtension,
  });

  final bool compact;
  final bool rootedNinth;
  final bool rootedSeventhExtension;

  bool get any => compact || rootedNinth || rootedSeventhExtension;

  Map<String, bool> toJson() => <String, bool>{
    'compact': compact,
    'rootedNinth': rootedNinth,
    'rootedSeventhExtension': rootedSeventhExtension,
  };
}

/// Per-candidate explanation of the deterministic policy filters.
@immutable
final class PolychordSelectorTrace {
  const PolychordSelectorTrace({
    required this.candidate,
    required this.identityAssignmentCount,
    required this.integratedTertian,
    required this.removedByAssignmentVeto,
    required this.removedByIntegratedTertianVeto,
    required this.survived,
  });

  final PolychordCandidate candidate;
  final int identityAssignmentCount;
  final IntegratedTertianTests integratedTertian;
  final bool removedByAssignmentVeto;
  final bool removedByIntegratedTertianVeto;
  final bool survived;

  Map<String, Object> toJson() => <String, Object>{
    'candidate': candidate.toJson(),
    'identityAssignmentCount': identityAssignmentCount,
    'integratedTertian': integratedTertian.toJson(),
    'removedByAssignmentVeto': removedByAssignmentVeto,
    'removedByIntegratedTertianVeto': removedByIntegratedTertianVeto,
    'survived': survived,
  };
}

/// One raw selector result before the frozen 200-millisecond display gate.
@immutable
final class PolychordRegisterDecision {
  PolychordRegisterDecision({
    required this.selectorId,
    required Iterable<int> midiNotes,
    required Iterable<PolychordCandidate> candidates,
    required Iterable<PolychordSelectorTrace> traces,
    required this.selected,
    required Iterable<String> reasonCodes,
  }) : midiNotes = List<int>.unmodifiable(midiNotes),
       candidates = List<PolychordCandidate>.unmodifiable(candidates),
       traces = List<PolychordSelectorTrace>.unmodifiable(traces),
       reasonCodes = List<String>.unmodifiable(reasonCodes);

  static const schema = 'polychord-register-selector-decision/1';

  final String selectorId;
  final List<int> midiNotes;
  final List<PolychordCandidate> candidates;
  final List<PolychordSelectorTrace> traces;
  final PolychordCandidate? selected;
  final List<String> reasonCodes;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'selectorId': selectorId,
    'midiNotes': midiNotes,
    'candidates': [for (final candidate in candidates) candidate.toJson()],
    'traces': [for (final trace in traces) trace.toJson()],
    'selected': selected?.toJson(),
    'reasonCodes': reasonCodes,
  };
}

/// Threshold-free implementation of `polychord-register-policy/1`.
final class PolychordRegisterSelector {
  const PolychordRegisterSelector();

  /// Generates candidates and applies [profile] to one registered frame.
  PolychordRegisterDecision decide(
    Iterable<int> midiNotes, {
    PolychordRegisterSelectorProfile profile =
        PolychordRegisterSelectorProfile.full,
  }) {
    final notes = List<int>.unmodifiable(midiNotes);
    return decideCandidates(
      notes,
      const PolychordRegisterCandidateGenerator().generate(notes),
      profile: profile,
    );
  }

  /// Applies [profile] to an already-generated complete candidate list.
  PolychordRegisterDecision decideCandidates(
    Iterable<int> midiNotes,
    Iterable<PolychordCandidate> candidates, {
    PolychordRegisterSelectorProfile profile =
        PolychordRegisterSelectorProfile.full,
  }) {
    final notes = List<int>.unmodifiable(midiNotes);
    final structural = List<PolychordCandidate>.unmodifiable(candidates);
    _validateCandidates(notes, structural);

    final identityCounts = <PolychordIdentity, int>{};
    for (final candidate in structural) {
      identityCounts.update(
        candidate.identity,
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }

    final traces = <PolychordSelectorTrace>[];
    final survivors = <PolychordCandidate>[];
    for (final candidate in structural) {
      final assignmentCount = identityCounts[candidate.identity]!;
      final integratedTertian = _integratedTertianTests(notes, candidate);
      final assignmentRemoved = profile.assignmentVeto && assignmentCount > 1;
      final integratedRemoved =
          !assignmentRemoved &&
          profile.integratedTertianVeto &&
          integratedTertian.any;
      final survived = !assignmentRemoved && !integratedRemoved;
      if (survived) survivors.add(candidate);
      traces.add(
        PolychordSelectorTrace(
          candidate: candidate,
          identityAssignmentCount: assignmentCount,
          integratedTertian: integratedTertian,
          removedByAssignmentVeto: assignmentRemoved,
          removedByIntegratedTertianVeto: integratedRemoved,
          survived: survived,
        ),
      );
    }

    PolychordCandidate? selected;
    List<String> reasonCodes;
    if (structural.isEmpty) {
      reasonCodes = const ['no-structural-candidate'];
    } else if (survivors.isEmpty) {
      reasonCodes = const ['not-selected-by-policy'];
    } else if (!profile.gapResolution) {
      if (survivors.length == 1) {
        selected = survivors.single;
        reasonCodes = const [];
      } else {
        reasonCodes = const ['multiple-unresolved-identities'];
      }
    } else {
      final greatestGap = survivors
          .map((candidate) => candidate.gapSemitones)
          .reduce((a, b) => a > b ? a : b);
      final widest = survivors
          .where((candidate) => candidate.gapSemitones == greatestGap)
          .toList();
      if (widest.length == 1) {
        selected = widest.single;
        reasonCodes = const [];
      } else {
        reasonCodes = const ['multiple-unresolved-identities'];
      }
    }

    return PolychordRegisterDecision(
      selectorId: profile.selectorId,
      midiNotes: notes,
      candidates: structural,
      traces: traces,
      selected: selected,
      reasonCodes: reasonCodes,
    );
  }
}

IntegratedTertianTests _integratedTertianTests(
  List<int> midiNotes,
  PolychordCandidate candidate,
) {
  final pitchClasses = midiNotes.map((note) => note % 12).toSet();
  return IntegratedTertianTests(
    compact: _isCompactIntegrated(pitchClasses),
    rootedNinth: _isRootedNinthIntegrated(pitchClasses, candidate),
    rootedSeventhExtension: _isRootedSeventhExtensionIntegrated(
      pitchClasses,
      candidate,
    ),
  );
}

Set<int> _relativeShape(Set<int> pitchClasses, int rootPc) => {
  for (final pitchClass in pitchClasses) (pitchClass - rootPc) % 12,
};

bool _isCompactIntegrated(Set<int> pitchClasses) {
  for (var rootPc = 0; rootPc < 12; rootPc++) {
    if (_setOfIntEquality(
      _relativeShape(pitchClasses, rootPc),
      _compactIntegratedShapes,
    )) {
      return true;
    }
  }
  return false;
}

bool _isRootedNinthIntegrated(
  Set<int> pitchClasses,
  PolychordCandidate candidate,
) {
  final shapes = _rootedNinthShapes[candidate.lower.identity.quality];
  if (shapes == null) return false;
  final relative = _relativeShape(
    pitchClasses,
    candidate.lower.identity.rootPc,
  );
  return shapes.any((shape) => _setsEqual(relative, shape));
}

bool _isRootedSeventhExtensionIntegrated(
  Set<int> pitchClasses,
  PolychordCandidate candidate,
) {
  final allowed =
      _rootedSeventhExtensionIntervals[candidate.lower.identity.quality];
  if (allowed == null) return false;
  final added = pitchClasses.difference(candidate.lower.pitchClasses.toSet());
  if (added.isEmpty) return false;
  final addedIntervals = _relativeShape(added, candidate.lower.identity.rootPc);
  return allowed.containsAll(addedIntervals);
}

bool _setOfIntEquality(Set<int> value, List<Set<int>> options) =>
    options.any((option) => _setsEqual(value, option));

bool _setsEqual(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

void _validateCandidates(
  List<int> midiNotes,
  List<PolychordCandidate> candidates,
) {
  final generated = const PolychordRegisterCandidateGenerator().generate(
    midiNotes,
  );
  if (candidates.length != candidates.toSet().length) {
    throw ArgumentError.value(candidates, 'candidates', 'must be distinct');
  }
  for (final candidate in candidates) {
    if (!generated.contains(candidate)) {
      throw ArgumentError.value(
        candidate,
        'candidates',
        'must contain exact generated candidates for midiNotes',
      );
    }
  }
  if (generated.any((candidate) => !candidates.contains(candidate))) {
    throw ArgumentError.value(
      candidates,
      'candidates',
      'must contain the complete generated candidate set',
    );
  }
}

const _compactIntegratedShapes = <Set<int>>[
  {0, 4, 7, 10},
  {0, 4, 7, 11},
  {0, 3, 7, 10},
  {0, 4, 7, 9},
  {0, 3, 7, 9},
];

const _rootedNinthShapes = <PolychordLayerQuality, List<Set<int>>>{
  PolychordLayerQuality.major: [
    {0, 2, 4, 7, 10},
    {0, 2, 4, 7, 11},
  ],
  PolychordLayerQuality.minor: [
    {0, 2, 3, 7, 10},
  ],
};

const _rootedSeventhExtensionIntervals = <PolychordLayerQuality, Set<int>>{
  PolychordLayerQuality.dominant7: {1, 2, 3, 5, 6, 8, 9},
  PolychordLayerQuality.major7: {2, 6, 9},
  PolychordLayerQuality.minor7: {2, 5, 9},
};
