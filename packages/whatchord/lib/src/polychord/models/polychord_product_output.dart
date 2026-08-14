import 'package:meta/meta.dart';

import 'polychord_candidate.dart';
import 'polychord_candidate_instance_binding.dart';
import 'polychord_onset_tracking_frame.dart';
import 'polychord_product_decision.dart';
import 'polychord_product_onset_cue_record.dart';

/// Complete reset-scoped product authorization identity.
@immutable
final class PolychordProductAuthorizationKey {
  factory PolychordProductAuthorizationKey({
    required PolychordCandidateInstanceBinding binding,
  }) {
    if (!binding.isComplete) {
      throw ArgumentError.value(
        binding,
        'binding',
        'must contain every onset-event identifier',
      );
    }
    return PolychordProductAuthorizationKey._(binding: binding);
  }

  const PolychordProductAuthorizationKey._({required this.binding});

  final PolychordCandidateInstanceBinding binding;

  int get trackerEpoch => binding.trackerEpoch;
  PolychordCandidate get candidate => binding.candidate;

  Map<String, Object> toJson() => <String, Object>{
    'trackerEpoch': trackerEpoch,
    'candidate': candidate.toJson(),
    'targetInstances': [
      for (final instance in binding.targetInstances) instance.toJson(),
    ],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordProductAuthorizationKey && other.binding == binding;

  @override
  int get hashCode => binding.hashCode;
}

/// Authorization output before presentation stability is applied.
@immutable
final class PolychordProductAuthorization {
  factory PolychordProductAuthorization({
    required PolychordProductAuthorizationKey? key,
    required String? reasonCode,
  }) {
    if ((key == null) == (reasonCode == null)) {
      throw ArgumentError(
        'authorization must contain exactly one key or reason code',
      );
    }
    return PolychordProductAuthorization._(key: key, reasonCode: reasonCode);
  }

  const PolychordProductAuthorization._({
    required this.key,
    required this.reasonCode,
  });

  final PolychordProductAuthorizationKey? key;
  final String? reasonCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'key': key?.toJson(),
    'reasonCode': reasonCode,
  };
}

enum PolychordProductDisplayState { absent, pending, visible }

enum PolychordProductDisplayTransition {
  none,
  pending,
  appearance,
  stable,
  clear,
}

/// One result from the continuous-authorization presentation reducer.
@immutable
final class PolychordProductDisplay {
  factory PolychordProductDisplay({
    required PolychordProductDisplayState state,
    required PolychordProductDisplayTransition transition,
    required PolychordProductAuthorizationKey? key,
    required int? deadlineMs,
    required String? reasonCode,
  }) {
    switch (state) {
      case PolychordProductDisplayState.absent:
        if (key != null || deadlineMs != null) {
          throw ArgumentError(
            'an absent display cannot retain a key or deadline',
          );
        }
      case PolychordProductDisplayState.pending:
        if (key == null || deadlineMs == null) {
          throw ArgumentError('a pending display requires a key and deadline');
        }
      case PolychordProductDisplayState.visible:
        if (key == null || deadlineMs != null) {
          throw ArgumentError(
            'a visible display requires a key without a deadline',
          );
        }
    }
    if (deadlineMs != null && deadlineMs < 0) {
      throw RangeError.range(deadlineMs, 0, null, 'deadlineMs');
    }
    if (transition == PolychordProductDisplayTransition.clear &&
        state != PolychordProductDisplayState.absent) {
      throw ArgumentError('a clear transition requires absent state');
    }
    if (transition == PolychordProductDisplayTransition.pending &&
        state != PolychordProductDisplayState.pending) {
      throw ArgumentError('a pending transition requires pending state');
    }
    if ((transition == PolychordProductDisplayTransition.appearance ||
            transition == PolychordProductDisplayTransition.stable) &&
        state != PolychordProductDisplayState.visible) {
      throw ArgumentError('appearance and stable require visible state');
    }
    return PolychordProductDisplay._(
      state: state,
      transition: transition,
      key: key,
      deadlineMs: deadlineMs,
      reasonCode: reasonCode,
    );
  }

  const PolychordProductDisplay._({
    required this.state,
    required this.transition,
    required this.key,
    required this.deadlineMs,
    required this.reasonCode,
  });

  static const profileId = 'polychord-continuous-authorization-200ms/1';

  final PolychordProductDisplayState state;
  final PolychordProductDisplayTransition transition;
  final PolychordProductAuthorizationKey? key;
  final int? deadlineMs;
  final String? reasonCode;

  Map<String, Object?> toJson() => <String, Object?>{
    'profileId': profileId,
    'state': state.name,
    'transition': transition.name,
    'key': key?.toJson(),
    'deadlineMs': deadlineMs,
    'reasonCode': reasonCode,
  };
}

/// Complete diagnostic product state after one musical or control observation.
@immutable
final class PolychordProductObservation {
  factory PolychordProductObservation({
    required int observationTimestampMs,
    required PolychordOnsetTrackingFrame? frame,
    required Iterable<PolychordCandidate> candidates,
    required Iterable<PolychordProductOnsetCueRecord> candidateRecords,
    required PolychordOnsetRegisterDecision? rawDecision,
    required PolychordProductAuthorization? authorization,
    required PolychordProductDisplay display,
  }) {
    if (observationTimestampMs < 0 ||
        observationTimestampMs > _maximumExactJsonInteger) {
      throw RangeError.range(
        observationTimestampMs,
        0,
        _maximumExactJsonInteger,
        'observationTimestampMs',
      );
    }
    final immutableCandidates = List<PolychordCandidate>.unmodifiable(
      candidates,
    );
    final immutableRecords = List<PolychordProductOnsetCueRecord>.unmodifiable(
      candidateRecords,
    );
    if (frame == null) {
      if (immutableCandidates.isNotEmpty ||
          immutableRecords.isNotEmpty ||
          rawDecision != null ||
          authorization != null) {
        throw ArgumentError('a reset observation cannot retain product state');
      }
    } else {
      if (rawDecision == null || authorization == null) {
        throw ArgumentError('a musical observation requires decision state');
      }
      if (rawDecision.targetObservation != frame ||
          !_candidateListsEqual(rawDecision.candidates, immutableCandidates) ||
          rawDecision.candidateRecords.length != immutableRecords.length) {
        throw ArgumentError('observation state must match its raw decision');
      }
      if (display.state != PolychordProductDisplayState.absent &&
          display.key != authorization.key) {
        throw ArgumentError('an active display must use the authorized key');
      }
    }
    return PolychordProductObservation._(
      observationTimestampMs: observationTimestampMs,
      frame: frame,
      candidates: immutableCandidates,
      candidateRecords: immutableRecords,
      rawDecision: rawDecision,
      authorization: authorization,
      display: display,
    );
  }

  const PolychordProductObservation._({
    required this.observationTimestampMs,
    required this.frame,
    required this.candidates,
    required this.candidateRecords,
    required this.rawDecision,
    required this.authorization,
    required this.display,
  });

  static const schema = 'polychord-output/3';
  static const inputCondition = 'automaticTimestampedMidi';
  static const versionIds = <String, String>{
    'output': schema,
    'tracker': 'polychord-onset-tracker/1',
    'candidateGenerator': 'polychord-register-candidates/1',
    'cue': 'coherent-separated-onsets-50-80ms/product-1',
    'selector': 'polychord-onset-register-policy/1',
    'display': 'polychord-continuous-authorization-200ms/1',
  };

  final int observationTimestampMs;
  final PolychordOnsetTrackingFrame? frame;
  final List<PolychordCandidate> candidates;
  final List<PolychordProductOnsetCueRecord> candidateRecords;
  final PolychordOnsetRegisterDecision? rawDecision;
  final PolychordProductAuthorization? authorization;
  final PolychordProductDisplay display;

  PolychordCandidate? get displayedCandidate =>
      display.state == PolychordProductDisplayState.visible
      ? display.key?.candidate
      : null;

  Map<String, Object?> toJson() => <String, Object?>{
    'schema': schema,
    'inputCondition': inputCondition,
    'observationTimestampMs': observationTimestampMs,
    'frame': frame?.toJson(),
    'candidates': [for (final candidate in candidates) candidate.toJson()],
    'candidateRecords': [
      for (final record in candidateRecords) record.toJson(),
    ],
    'rawDecision': rawDecision?.toJson(),
    'authorization': authorization?.toJson(),
    'display': display.toJson(),
    'versionIds': versionIds,
  };
}

bool _candidateListsEqual(
  List<PolychordCandidate> left,
  List<PolychordCandidate> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

const _maximumExactJsonInteger = 9007199254740991;
