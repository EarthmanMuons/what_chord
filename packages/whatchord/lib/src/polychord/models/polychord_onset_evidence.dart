import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'polychord_candidate.dart';

/// Whether a currently sounding note is physically held or pedal-sustained.
enum PolychordSoundingState { pressed, sustained }

/// The attack that created one currently sounding MIDI-note instance.
///
/// [timestampMs] is a nonnegative monotonic elapsed time supplied by the
/// caller. [eventIndex] preserves ordering when several attacks share a
/// timestamp.
@immutable
final class PolychordOnsetOrigin {
  PolychordOnsetOrigin({
    required this.eventIndex,
    required this.timestampMs,
    required this.velocity,
  }) {
    if (eventIndex < 0 || eventIndex > _maximumExactJsonInteger) {
      throw RangeError.range(
        eventIndex,
        0,
        _maximumExactJsonInteger,
        'eventIndex',
      );
    }
    if (timestampMs < 0 || timestampMs > _maximumExactJsonInteger) {
      throw RangeError.range(
        timestampMs,
        0,
        _maximumExactJsonInteger,
        'timestampMs',
      );
    }
    if (velocity < 1 || velocity > 127) {
      throw RangeError.range(velocity, 1, 127, 'velocity');
    }
  }

  final int eventIndex;
  final int timestampMs;
  final int velocity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordOnsetOrigin &&
          other.eventIndex == eventIndex &&
          other.timestampMs == timestampMs &&
          other.velocity == velocity;

  @override
  int get hashCode => Object.hash(eventIndex, timestampMs, velocity);
}

/// Current state and attack provenance for one sounding MIDI note.
///
/// A null [origin] represents a note carried into the available history. It is
/// unknown evidence, not an attack at time zero.
@immutable
final class PolychordSoundingNoteOnset {
  PolychordSoundingNoteOnset({
    required this.midiNote,
    required this.soundingState,
    this.origin,
  }) {
    if (midiNote < 0 || midiNote > 127) {
      throw RangeError.range(midiNote, 0, 127, 'midiNote');
    }
  }

  final int midiNote;
  final PolychordSoundingState soundingState;
  final PolychordOnsetOrigin? origin;

  Map<String, Object?> toJson() => <String, Object?>{
    'midiNote': midiNote,
    'soundingState': soundingState.name,
    'onsetEventIndex': origin?.eventIndex,
    'onsetTimestampMs': origin?.timestampMs,
    'onsetVelocity': origin?.velocity,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordSoundingNoteOnset &&
          other.midiNote == midiNote &&
          other.soundingState == soundingState &&
          other.origin == origin;

  @override
  int get hashCode => Object.hash(midiNote, soundingState, origin);
}

/// Threshold-free onset summary for one exact candidate layer.
@immutable
final class PolychordLayerOnsetEvidence {
  factory PolychordLayerOnsetEvidence({
    required Iterable<PolychordSoundingNoteOnset> notes,
  }) {
    final immutableNotes = List<PolychordSoundingNoteOnset>.unmodifiable(notes);
    if (immutableNotes.isEmpty) {
      throw ArgumentError.value(notes, 'notes', 'must not be empty');
    }
    for (var index = 1; index < immutableNotes.length; index++) {
      if (immutableNotes[index].midiNote <=
          immutableNotes[index - 1].midiNote) {
        throw ArgumentError.value(
          notes,
          'notes',
          'must be strictly increasing without duplicate MIDI notes',
        );
      }
    }
    final knownTimestamps = [
      for (final note in immutableNotes)
        if (note.origin != null) note.origin!.timestampMs,
    ];
    final distinctTimestamps = knownTimestamps.toSet().toList()..sort();
    final earliest = knownTimestamps.isEmpty
        ? null
        : knownTimestamps.reduce((a, b) => a < b ? a : b);
    final latest = knownTimestamps.isEmpty
        ? null
        : knownTimestamps.reduce((a, b) => a > b ? a : b);
    return PolychordLayerOnsetEvidence._(
      notes: immutableNotes,
      knownOnsetCount: knownTimestamps.length,
      unknownOnsetCount: immutableNotes.length - knownTimestamps.length,
      distinctKnownOnsetTimestampsMs: distinctTimestamps,
      earliestKnownOnsetMs: earliest,
      latestKnownOnsetMs: latest,
    );
  }

  const PolychordLayerOnsetEvidence._({
    required this.notes,
    required this.knownOnsetCount,
    required this.unknownOnsetCount,
    required this.distinctKnownOnsetTimestampsMs,
    required this.earliestKnownOnsetMs,
    required this.latestKnownOnsetMs,
  });

  final List<PolychordSoundingNoteOnset> notes;
  final int knownOnsetCount;
  final int unknownOnsetCount;
  final List<int> distinctKnownOnsetTimestampsMs;
  final int? earliestKnownOnsetMs;
  final int? latestKnownOnsetMs;

  bool get allOnsetsKnown => unknownOnsetCount == 0;

  int? get knownOnsetSpanMs {
    final earliest = earliestKnownOnsetMs;
    final latest = latestKnownOnsetMs;
    return earliest == null || latest == null ? null : latest - earliest;
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'notes': [for (final note in notes) note.toJson()],
    'knownOnsetCount': knownOnsetCount,
    'unknownOnsetCount': unknownOnsetCount,
    'allOnsetsKnown': allOnsetsKnown,
    'distinctKnownOnsetTimestampsMs': distinctKnownOnsetTimestampsMs,
    'earliestKnownOnsetMs': earliestKnownOnsetMs,
    'latestKnownOnsetMs': latestKnownOnsetMs,
    'knownOnsetSpanMs': knownOnsetSpanMs,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordLayerOnsetEvidence &&
          _noteListEquality.equals(other.notes, notes) &&
          other.knownOnsetCount == knownOnsetCount &&
          other.unknownOnsetCount == unknownOnsetCount &&
          _intListEquality.equals(
            other.distinctKnownOnsetTimestampsMs,
            distinctKnownOnsetTimestampsMs,
          ) &&
          other.earliestKnownOnsetMs == earliestKnownOnsetMs &&
          other.latestKnownOnsetMs == latestKnownOnsetMs;

  @override
  int get hashCode => Object.hash(
    _noteListEquality.hash(notes),
    knownOnsetCount,
    unknownOnsetCount,
    _intListEquality.hash(distinctKnownOnsetTimestampsMs),
    earliestKnownOnsetMs,
    latestKnownOnsetMs,
  );
}

/// Raw onset evidence bound to one exact structural candidate.
///
/// The two signed relations locate the upper onset interval relative to the
/// lower interval. They remain null unless every assigned note has known onset
/// provenance. This model applies no synchrony, separation, or display rule.
@immutable
final class PolychordCandidateOnsetEvidence {
  factory PolychordCandidateOnsetEvidence({
    required PolychordCandidate candidate,
    required PolychordLayerOnsetEvidence lower,
    required PolychordLayerOnsetEvidence upper,
  }) {
    if (!_intListEquality.equals(
          lower.notes.map((note) => note.midiNote).toList(),
          candidate.lower.midiNotes,
        ) ||
        !_intListEquality.equals(
          upper.notes.map((note) => note.midiNote).toList(),
          candidate.upper.midiNotes,
        )) {
      throw ArgumentError(
        'lower and upper onset evidence must match the candidate assignments',
      );
    }
    final complete = lower.allOnsetsKnown && upper.allOnsetsKnown;
    return PolychordCandidateOnsetEvidence._(
      candidate: candidate,
      lower: lower,
      upper: upper,
      upperEarliestMinusLowerLatestMs: complete
          ? upper.earliestKnownOnsetMs! - lower.latestKnownOnsetMs!
          : null,
      upperLatestMinusLowerEarliestMs: complete
          ? upper.latestKnownOnsetMs! - lower.earliestKnownOnsetMs!
          : null,
    );
  }

  const PolychordCandidateOnsetEvidence._({
    required this.candidate,
    required this.lower,
    required this.upper,
    required this.upperEarliestMinusLowerLatestMs,
    required this.upperLatestMinusLowerEarliestMs,
  });

  final PolychordCandidate candidate;
  final PolychordLayerOnsetEvidence lower;
  final PolychordLayerOnsetEvidence upper;
  final int? upperEarliestMinusLowerLatestMs;
  final int? upperLatestMinusLowerEarliestMs;

  bool get allCandidateOnsetsKnown =>
      lower.allOnsetsKnown && upper.allOnsetsKnown;

  Map<String, Object?> toJson() => <String, Object?>{
    'candidate': candidate.toJson(),
    'onsetEvidence': <String, Object?>{
      'allCandidateOnsetsKnown': allCandidateOnsetsKnown,
      'lower': lower.toJson(),
      'upper': upper.toJson(),
      'upperEarliestMinusLowerLatestMs': upperEarliestMinusLowerLatestMs,
      'upperLatestMinusLowerEarliestMs': upperLatestMinusLowerEarliestMs,
    },
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordCandidateOnsetEvidence &&
          other.candidate == candidate &&
          other.lower == lower &&
          other.upper == upper &&
          other.upperEarliestMinusLowerLatestMs ==
              upperEarliestMinusLowerLatestMs &&
          other.upperLatestMinusLowerEarliestMs ==
              upperLatestMinusLowerEarliestMs;

  @override
  int get hashCode => Object.hash(
    candidate,
    lower,
    upper,
    upperEarliestMinusLowerLatestMs,
    upperLatestMinusLowerEarliestMs,
  );
}

const _intListEquality = ListEquality<int>();
const _noteListEquality = ListEquality<PolychordSoundingNoteOnset>();
const _maximumExactJsonInteger = 9007199254740991;
