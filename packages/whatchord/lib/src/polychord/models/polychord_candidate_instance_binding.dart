import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'polychord_candidate.dart';
import 'polychord_sounding_instance_key.dart';

/// Completeness of an exact candidate-to-sounding-instance binding.
enum PolychordInstanceBindingAvailability { complete, incomplete }

/// Exact structural candidate bound to every current sounding-note instance.
///
/// This is causal identity only. A complete binding does not license, rank, or
/// display a polychord candidate.
@immutable
final class PolychordCandidateInstanceBinding {
  @internal
  factory PolychordCandidateInstanceBinding.internal({
    required int trackerEpoch,
    required PolychordCandidate candidate,
    required Iterable<PolychordSoundingInstanceKey> targetInstances,
  }) {
    if (trackerEpoch < 0 || trackerEpoch > _maximumExactJsonInteger) {
      throw RangeError.range(
        trackerEpoch,
        0,
        _maximumExactJsonInteger,
        'trackerEpoch',
      );
    }
    final instances = List<PolychordSoundingInstanceKey>.unmodifiable(
      targetInstances,
    );
    final expectedMidiNotes = [
      ...candidate.lower.midiNotes,
      ...candidate.upper.midiNotes,
    ];
    if (!_intListEquality.equals(
      instances.map((instance) => instance.midiNote).toList(),
      expectedMidiNotes,
    )) {
      throw ArgumentError.value(
        targetInstances,
        'targetInstances',
        'must exhaust the exact candidate in ascending MIDI order',
      );
    }
    return PolychordCandidateInstanceBinding._(
      trackerEpoch: trackerEpoch,
      candidate: candidate,
      targetInstances: instances,
    );
  }

  const PolychordCandidateInstanceBinding._({
    required this.trackerEpoch,
    required this.candidate,
    required this.targetInstances,
  });

  /// Reset-delimited namespace in which onset event indices are meaningful.
  final int trackerEpoch;

  /// Ordered identities and complete MIDI-note assignment being bound.
  final PolychordCandidate candidate;

  /// Every assigned note in ascending MIDI order.
  final List<PolychordSoundingInstanceKey> targetInstances;

  PolychordInstanceBindingAvailability get availability =>
      targetInstances.every((instance) => instance.onsetEventIndex != null)
      ? PolychordInstanceBindingAvailability.complete
      : PolychordInstanceBindingAvailability.incomplete;

  bool get isComplete =>
      availability == PolychordInstanceBindingAvailability.complete;

  Map<String, Object> toJson() => <String, Object>{
    'trackerEpoch': trackerEpoch,
    'candidate': candidate.toJson(),
    'targetInstances': [
      for (final instance in targetInstances) instance.toJson(),
    ],
    'availability': availability.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordCandidateInstanceBinding &&
          other.trackerEpoch == trackerEpoch &&
          other.candidate == candidate &&
          _instanceListEquality.equals(other.targetInstances, targetInstances);

  @override
  int get hashCode => Object.hash(
    trackerEpoch,
    candidate,
    _instanceListEquality.hash(targetInstances),
  );
}

const _maximumExactJsonInteger = 9007199254740991;
const _intListEquality = ListEquality<int>();
const _instanceListEquality = ListEquality<PolychordSoundingInstanceKey>();
