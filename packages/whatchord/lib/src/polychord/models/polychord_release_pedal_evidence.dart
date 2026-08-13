import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

import 'polychord_candidate.dart';
import 'polychord_onset_evidence.dart';

/// One normalized note event that established a causal fact.
@immutable
final class PolychordNoteEventOrigin {
  PolychordNoteEventOrigin({
    required this.eventIndex,
    required this.timestampMs,
    required this.velocity,
  }) {
    _checkExactNonnegativeInteger(eventIndex, 'eventIndex');
    _checkExactNonnegativeInteger(timestampMs, 'timestampMs');
    if (velocity < 0 || velocity > 127) {
      throw RangeError.range(velocity, 0, 127, 'velocity');
    }
  }

  final int eventIndex;
  final int timestampMs;
  final int velocity;

  bool precedes(PolychordNoteEventOrigin other) =>
      eventIndex < other.eventIndex && timestampMs <= other.timestampMs;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordNoteEventOrigin &&
          other.eventIndex == eventIndex &&
          other.timestampMs == timestampMs &&
          other.velocity == velocity;

  @override
  int get hashCode => Object.hash(eventIndex, timestampMs, velocity);
}

/// Latest observed transition into the current sustain-pedal state.
@immutable
final class PolychordPedalTransition {
  PolychordPedalTransition({
    required this.eventIndex,
    required this.timestampMs,
    required this.down,
  }) {
    _checkExactNonnegativeInteger(eventIndex, 'eventIndex');
    _checkExactNonnegativeInteger(timestampMs, 'timestampMs');
  }

  final int eventIndex;
  final int timestampMs;
  final bool down;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordPedalTransition &&
          other.eventIndex == eventIndex &&
          other.timestampMs == timestampMs &&
          other.down == down;

  @override
  int get hashCode => Object.hash(eventIndex, timestampMs, down);
}

/// Complete observed causal history for one currently sounding MIDI note.
///
/// Null origins preserve facts carried into the available event history rather
/// than inventing events at the stream boundary.
@immutable
final class PolychordSoundingNoteHistory {
  PolychordSoundingNoteHistory({
    required this.midiNote,
    required this.soundingState,
    required this.onset,
    required this.release,
    required this.currentStateSince,
    required this.reattackedFromSustain,
    required this.priorSustainRelease,
  }) {
    if (midiNote < 0 || midiNote > 127) {
      throw RangeError.range(midiNote, 0, 127, 'midiNote');
    }
    if (onset != null && onset!.velocity == 0) {
      throw ArgumentError.value(onset, 'onset', 'must be a nonzero note-on');
    }
    if (onset == null && reattackedFromSustain != null) {
      throw ArgumentError(
        'reattackedFromSustain must be unknown when onset is unknown',
      );
    }
    if (onset != null && reattackedFromSustain == null) {
      throw ArgumentError(
        'reattackedFromSustain must be known when onset is known',
      );
    }
    if (reattackedFromSustain != true && priorSustainRelease != null) {
      throw ArgumentError('priorSustainRelease requires reattackedFromSustain');
    }
    switch (soundingState) {
      case PolychordSoundingState.pressed:
        if (release != null) {
          throw ArgumentError('a pressed note cannot have a current release');
        }
        if (currentStateSince != onset) {
          throw ArgumentError(
            'a pressed note current-state origin must equal its onset',
          );
        }
      case PolychordSoundingState.sustained:
        if (currentStateSince != release) {
          throw ArgumentError(
            'a sustained note current-state origin must equal its release',
          );
        }
        if (onset != null && release == null) {
          throw ArgumentError(
            'a sustained note with a known onset must have a known release',
          );
        }
    }
    if (onset != null && release != null && !onset!.precedes(release!)) {
      throw ArgumentError('release must occur after onset in event order');
    }
    if (priorSustainRelease != null &&
        onset != null &&
        !priorSustainRelease!.precedes(onset!)) {
      throw ArgumentError(
        'prior sustain release must occur before the reattack',
      );
    }
  }

  final int midiNote;
  final PolychordSoundingState soundingState;
  final PolychordNoteEventOrigin? onset;
  final PolychordNoteEventOrigin? release;
  final PolychordNoteEventOrigin? currentStateSince;
  final bool? reattackedFromSustain;
  final PolychordNoteEventOrigin? priorSustainRelease;

  PolychordSoundingNoteOnset get onsetObservation => PolychordSoundingNoteOnset(
    midiNote: midiNote,
    soundingState: soundingState,
    origin: onset == null
        ? null
        : PolychordOnsetOrigin(
            eventIndex: onset!.eventIndex,
            timestampMs: onset!.timestampMs,
            velocity: onset!.velocity,
          ),
  );

  Map<String, Object?> toJson({
    required int frameTimestampMs,
    required bool pedalDown,
    required PolychordPedalTransition? pedalTransition,
  }) {
    _checkExactNonnegativeInteger(frameTimestampMs, 'frameTimestampMs');
    if (pedalTransition != null &&
        (pedalTransition.down != pedalDown ||
            pedalTransition.timestampMs > frameTimestampMs)) {
      throw ArgumentError.value(
        pedalTransition,
        'pedalTransition',
        'must establish the current pedal state at or before the frame',
      );
    }
    for (final origin in <PolychordNoteEventOrigin?>[
      onset,
      release,
      currentStateSince,
      priorSustainRelease,
    ]) {
      if (origin != null && origin.timestampMs > frameTimestampMs) {
        throw ArgumentError.value(
          origin,
          'frameTimestampMs',
          'must not precede a note-history origin',
        );
      }
    }
    final onsetBeforePedalDown =
        onset == null || !pedalDown || pedalTransition == null
        ? null
        : _originPrecedesPedal(onset!, pedalTransition);
    return <String, Object?>{
      'midiNote': midiNote,
      'soundingState': soundingState.name,
      'onsetEventIndex': onset?.eventIndex,
      'onsetTimestampMs': onset?.timestampMs,
      'onsetVelocity': onset?.velocity,
      'onsetAgeMs': _age(frameTimestampMs, onset),
      'releaseEventIndex': release?.eventIndex,
      'releaseTimestampMs': release?.timestampMs,
      'releaseVelocity': release?.velocity,
      'releaseAgeMs': _age(frameTimestampMs, release),
      'currentStateSinceEventIndex': currentStateSince?.eventIndex,
      'currentStateSinceTimestampMs': currentStateSince?.timestampMs,
      'currentStateAgeMs': _age(frameTimestampMs, currentStateSince),
      'reattackedFromSustain': reattackedFromSustain,
      'priorSustainReleaseEventIndex': priorSustainRelease?.eventIndex,
      'priorSustainReleaseTimestampMs': priorSustainRelease?.timestampMs,
      'priorSustainReleaseVelocity': priorSustainRelease?.velocity,
      'priorSustainReleaseAgeMs': _age(frameTimestampMs, priorSustainRelease),
      'onsetBeforeCurrentPedalDown': onsetBeforePedalDown,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordSoundingNoteHistory &&
          other.midiNote == midiNote &&
          other.soundingState == soundingState &&
          other.onset == onset &&
          other.release == release &&
          other.currentStateSince == currentStateSince &&
          other.reattackedFromSustain == reattackedFromSustain &&
          other.priorSustainRelease == priorSustainRelease;

  @override
  int get hashCode => Object.hash(
    midiNote,
    soundingState,
    onset,
    release,
    currentStateSince,
    reattackedFromSustain,
    priorSustainRelease,
  );
}

/// Raw release and pedal state immediately after one normalized event.
@immutable
final class PolychordReleasePedalTrackingFrame {
  factory PolychordReleasePedalTrackingFrame({
    required int trackerEpoch,
    required int afterEventIndex,
    required int timestampMs,
    required bool pedalDown,
    required PolychordPedalTransition? pedalTransition,
    required Iterable<PolychordSoundingNoteHistory> soundingNoteHistories,
  }) {
    _checkExactNonnegativeInteger(trackerEpoch, 'trackerEpoch');
    _checkExactNonnegativeInteger(afterEventIndex, 'afterEventIndex');
    _checkExactNonnegativeInteger(timestampMs, 'timestampMs');
    if (pedalTransition != null) {
      if (pedalTransition.eventIndex > afterEventIndex ||
          pedalTransition.timestampMs > timestampMs) {
        throw ArgumentError.value(
          pedalTransition,
          'pedalTransition',
          'must not occur after the frame',
        );
      }
      if (pedalTransition.down != pedalDown) {
        throw ArgumentError.value(
          pedalTransition,
          'pedalTransition',
          'must establish the current pedal state',
        );
      }
    }
    final notes = List<PolychordSoundingNoteHistory>.unmodifiable(
      soundingNoteHistories,
    );
    final originsByEventIndex = <int, PolychordNoteEventOrigin>{};
    for (var index = 0; index < notes.length; index++) {
      final note = notes[index];
      if (index > 0 && note.midiNote <= notes[index - 1].midiNote) {
        throw ArgumentError.value(
          soundingNoteHistories,
          'soundingNoteHistories',
          'must be strictly increasing without duplicate MIDI notes',
        );
      }
      if (note.soundingState == PolychordSoundingState.sustained &&
          !pedalDown) {
        throw ArgumentError.value(
          note,
          'soundingNoteHistories',
          'cannot contain sustained notes while the pedal is up',
        );
      }
      for (final origin in <PolychordNoteEventOrigin?>{
        note.onset,
        note.release,
        note.currentStateSince,
        note.priorSustainRelease,
      }) {
        if (origin != null &&
            (origin.eventIndex > afterEventIndex ||
                origin.timestampMs > timestampMs)) {
          throw ArgumentError.value(
            origin,
            'soundingNoteHistories',
            'origins must not occur after the frame',
          );
        }
        if (origin != null &&
            originsByEventIndex.containsKey(origin.eventIndex)) {
          throw ArgumentError.value(
            origin.eventIndex,
            'soundingNoteHistories',
            'must not reuse a note-event index',
          );
        }
        if (origin != null) originsByEventIndex[origin.eventIndex] = origin;
      }
    }
    if (pedalTransition != null &&
        originsByEventIndex.containsKey(pedalTransition.eventIndex)) {
      throw ArgumentError.value(
        pedalTransition.eventIndex,
        'pedalTransition',
        'must not reuse a note-event index',
      );
    }
    final orderedEvents = <({int eventIndex, int timestampMs})>[
      for (final origin in originsByEventIndex.values)
        (eventIndex: origin.eventIndex, timestampMs: origin.timestampMs),
      if (pedalTransition != null)
        (
          eventIndex: pedalTransition.eventIndex,
          timestampMs: pedalTransition.timestampMs,
        ),
    ]..sort((a, b) => a.eventIndex.compareTo(b.eventIndex));
    for (var index = 1; index < orderedEvents.length; index++) {
      if (orderedEvents[index].timestampMs <
          orderedEvents[index - 1].timestampMs) {
        throw ArgumentError.value(
          soundingNoteHistories,
          'soundingNoteHistories',
          'event timestamps must be nondecreasing in event order',
        );
      }
    }
    return PolychordReleasePedalTrackingFrame._(
      trackerEpoch: trackerEpoch,
      afterEventIndex: afterEventIndex,
      timestampMs: timestampMs,
      pedalDown: pedalDown,
      pedalTransition: pedalTransition,
      soundingNoteHistories: notes,
    );
  }

  const PolychordReleasePedalTrackingFrame._({
    required this.trackerEpoch,
    required this.afterEventIndex,
    required this.timestampMs,
    required this.pedalDown,
    required this.pedalTransition,
    required this.soundingNoteHistories,
  });

  final int trackerEpoch;
  final int afterEventIndex;
  final int timestampMs;
  final bool pedalDown;
  final PolychordPedalTransition? pedalTransition;
  final List<PolychordSoundingNoteHistory> soundingNoteHistories;

  List<PolychordSoundingNoteOnset> get soundingNoteOnsets =>
      List<PolychordSoundingNoteOnset>.unmodifiable(
        soundingNoteHistories.map((note) => note.onsetObservation),
      );

  PolychordPedalEvidence get pedalEvidence => PolychordPedalEvidence(
    down: pedalDown,
    transition: pedalTransition,
    frameTimestampMs: timestampMs,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'trackerEpoch': trackerEpoch,
    'afterEventIndex': afterEventIndex,
    'timestampMs': timestampMs,
    'pedal': pedalEvidence.toJson(),
    'notes': [
      for (final note in soundingNoteHistories)
        note.toJson(
          frameTimestampMs: timestampMs,
          pedalDown: pedalDown,
          pedalTransition: pedalTransition,
        ),
    ],
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordReleasePedalTrackingFrame &&
          other.trackerEpoch == trackerEpoch &&
          other.afterEventIndex == afterEventIndex &&
          other.timestampMs == timestampMs &&
          other.pedalDown == pedalDown &&
          other.pedalTransition == pedalTransition &&
          _historyListEquality.equals(
            other.soundingNoteHistories,
            soundingNoteHistories,
          );

  @override
  int get hashCode => Object.hash(
    trackerEpoch,
    afterEventIndex,
    timestampMs,
    pedalDown,
    pedalTransition,
    _historyListEquality.hash(soundingNoteHistories),
  );
}

/// Current pedal state and its latest observed transition.
@immutable
final class PolychordPedalEvidence {
  PolychordPedalEvidence({
    required this.down,
    required this.transition,
    required this.frameTimestampMs,
  }) {
    _checkExactNonnegativeInteger(frameTimestampMs, 'frameTimestampMs');
    if (transition != null &&
        (transition!.down != down ||
            transition!.timestampMs > frameTimestampMs)) {
      throw ArgumentError.value(
        transition,
        'transition',
        'must establish the current pedal state at or before the frame',
      );
    }
  }

  final bool down;
  final PolychordPedalTransition? transition;
  final int frameTimestampMs;

  int? get currentStateAgeMs =>
      transition == null ? null : frameTimestampMs - transition!.timestampMs;

  Map<String, Object?> toJson() => <String, Object?>{
    'down': down,
    'lastTransitionEventIndex': transition?.eventIndex,
    'lastTransitionTimestampMs': transition?.timestampMs,
    'lastTransitionDown': transition?.down,
    'currentStateAgeMs': currentStateAgeMs,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordPedalEvidence &&
          other.down == down &&
          other.transition == transition &&
          other.frameTimestampMs == frameTimestampMs;

  @override
  int get hashCode => Object.hash(down, transition, frameTimestampMs);
}

/// Inclusive minimum and maximum of known nonnegative millisecond ages.
@immutable
final class PolychordAgeRange {
  PolychordAgeRange({required this.minimum, required this.maximum}) {
    _checkExactNonnegativeInteger(minimum, 'minimum');
    _checkExactNonnegativeInteger(maximum, 'maximum');
    if (minimum > maximum) {
      throw ArgumentError('minimum must not exceed maximum');
    }
  }

  final int minimum;
  final int maximum;

  Map<String, Object> toJson() => <String, Object>{
    'minimum': minimum,
    'maximum': maximum,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordAgeRange &&
          other.minimum == minimum &&
          other.maximum == maximum;

  @override
  int get hashCode => Object.hash(minimum, maximum);
}

/// Threshold-free release and pedal summary for one exact candidate layer.
@immutable
final class PolychordLayerReleasePedalEvidence {
  factory PolychordLayerReleasePedalEvidence({
    required Iterable<PolychordSoundingNoteHistory> notes,
    required int frameTimestampMs,
    required bool pedalDown,
    required PolychordPedalTransition? pedalTransition,
  }) {
    _checkExactNonnegativeInteger(frameTimestampMs, 'frameTimestampMs');
    if (pedalTransition != null &&
        (pedalTransition.down != pedalDown ||
            pedalTransition.timestampMs > frameTimestampMs)) {
      throw ArgumentError.value(
        pedalTransition,
        'pedalTransition',
        'must establish the current pedal state at or before the frame',
      );
    }
    final immutableNotes = List<PolychordSoundingNoteHistory>.unmodifiable(
      notes,
    );
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
    for (final note in immutableNotes) {
      if (note.soundingState == PolychordSoundingState.sustained &&
          !pedalDown) {
        throw ArgumentError.value(
          note,
          'notes',
          'cannot contain sustained notes while the pedal is up',
        );
      }
      for (final origin in <PolychordNoteEventOrigin?>[
        note.onset,
        note.release,
        note.currentStateSince,
        note.priorSustainRelease,
      ]) {
        if (origin != null && origin.timestampMs > frameTimestampMs) {
          throw ArgumentError.value(
            origin,
            'notes',
            'origins must not occur after the frame',
          );
        }
      }
    }
    final records = [
      for (final note in immutableNotes)
        note.toJson(
          frameTimestampMs: frameTimestampMs,
          pedalDown: pedalDown,
          pedalTransition: pedalTransition,
        ),
    ];
    final sustained = [
      for (var index = 0; index < immutableNotes.length; index++)
        if (immutableNotes[index].soundingState ==
            PolychordSoundingState.sustained)
          records[index],
    ];
    final onsetAges = _knownInts(records, 'onsetAgeMs');
    final releaseTimestamps = _knownInts(sustained, 'releaseTimestampMs');
    final stateAges = _knownInts(records, 'currentStateAgeMs');
    final distinctReleaseTimestamps = releaseTimestamps.toSet().toList()
      ..sort();
    final earliestRelease = _minimum(releaseTimestamps);
    final latestRelease = _maximum(releaseTimestamps);
    return PolychordLayerReleasePedalEvidence._(
      notes: immutableNotes,
      frameTimestampMs: frameTimestampMs,
      pedalDown: pedalDown,
      pedalTransition: pedalTransition,
      pressedNoteCount: immutableNotes.length - sustained.length,
      sustainedNoteCount: sustained.length,
      knownOnsetCount: onsetAges.length,
      knownOnsetAgeRangeMs: _range(onsetAges),
      knownReleaseCount: releaseTimestamps.length,
      distinctKnownReleaseTimestampsMs: List<int>.unmodifiable(
        distinctReleaseTimestamps,
      ),
      earliestKnownReleaseMs: earliestRelease,
      latestKnownReleaseMs: latestRelease,
      knownCurrentStateOriginCount: stateAges.length,
      knownCurrentStateAgeRangeMs: _range(stateAges),
      reattackedFromSustainCount: _count(
        records,
        'reattackedFromSustain',
        true,
      ),
      notReattackedFromSustainCount: _count(
        records,
        'reattackedFromSustain',
        false,
      ),
      onsetBeforeCurrentPedalDownCount: _count(
        records,
        'onsetBeforeCurrentPedalDown',
        true,
      ),
      onsetAtOrAfterCurrentPedalDownCount: _count(
        records,
        'onsetBeforeCurrentPedalDown',
        false,
      ),
    );
  }

  const PolychordLayerReleasePedalEvidence._({
    required this.notes,
    required this.frameTimestampMs,
    required this.pedalDown,
    required this.pedalTransition,
    required this.pressedNoteCount,
    required this.sustainedNoteCount,
    required this.knownOnsetCount,
    required this.knownOnsetAgeRangeMs,
    required this.knownReleaseCount,
    required this.distinctKnownReleaseTimestampsMs,
    required this.earliestKnownReleaseMs,
    required this.latestKnownReleaseMs,
    required this.knownCurrentStateOriginCount,
    required this.knownCurrentStateAgeRangeMs,
    required this.reattackedFromSustainCount,
    required this.notReattackedFromSustainCount,
    required this.onsetBeforeCurrentPedalDownCount,
    required this.onsetAtOrAfterCurrentPedalDownCount,
  });

  final List<PolychordSoundingNoteHistory> notes;
  final int frameTimestampMs;
  final bool pedalDown;
  final PolychordPedalTransition? pedalTransition;
  final int pressedNoteCount;
  final int sustainedNoteCount;
  final int knownOnsetCount;
  final PolychordAgeRange? knownOnsetAgeRangeMs;
  final int knownReleaseCount;
  final List<int> distinctKnownReleaseTimestampsMs;
  final int? earliestKnownReleaseMs;
  final int? latestKnownReleaseMs;
  final int knownCurrentStateOriginCount;
  final PolychordAgeRange? knownCurrentStateAgeRangeMs;
  final int reattackedFromSustainCount;
  final int notReattackedFromSustainCount;
  final int onsetBeforeCurrentPedalDownCount;
  final int onsetAtOrAfterCurrentPedalDownCount;

  int get unknownOnsetCount => notes.length - knownOnsetCount;
  int get unknownReleaseCount => sustainedNoteCount - knownReleaseCount;
  bool get allSustainedReleasesKnown => unknownReleaseCount == 0;
  int get unknownCurrentStateOriginCount =>
      notes.length - knownCurrentStateOriginCount;
  int get unknownReattackCount =>
      notes.length - reattackedFromSustainCount - notReattackedFromSustainCount;
  int get unknownPedalRelationCount =>
      notes.length -
      onsetBeforeCurrentPedalDownCount -
      onsetAtOrAfterCurrentPedalDownCount;
  int? get knownReleaseSpanMs =>
      earliestKnownReleaseMs == null || latestKnownReleaseMs == null
      ? null
      : latestKnownReleaseMs! - earliestKnownReleaseMs!;

  Map<String, Object?> toJson() => <String, Object?>{
    'notes': [
      for (final note in notes)
        note.toJson(
          frameTimestampMs: frameTimestampMs,
          pedalDown: pedalDown,
          pedalTransition: pedalTransition,
        ),
    ],
    'pressedNoteCount': pressedNoteCount,
    'sustainedNoteCount': sustainedNoteCount,
    'knownOnsetCount': knownOnsetCount,
    'unknownOnsetCount': unknownOnsetCount,
    'knownOnsetAgeRangeMs': knownOnsetAgeRangeMs?.toJson(),
    'knownReleaseCount': knownReleaseCount,
    'unknownReleaseCount': unknownReleaseCount,
    'allSustainedReleasesKnown': allSustainedReleasesKnown,
    'distinctKnownReleaseTimestampsMs': distinctKnownReleaseTimestampsMs,
    'earliestKnownReleaseMs': earliestKnownReleaseMs,
    'latestKnownReleaseMs': latestKnownReleaseMs,
    'knownReleaseSpanMs': knownReleaseSpanMs,
    'knownCurrentStateOriginCount': knownCurrentStateOriginCount,
    'unknownCurrentStateOriginCount': unknownCurrentStateOriginCount,
    'knownCurrentStateAgeRangeMs': knownCurrentStateAgeRangeMs?.toJson(),
    'reattackedFromSustainCount': reattackedFromSustainCount,
    'notReattackedFromSustainCount': notReattackedFromSustainCount,
    'unknownReattackCount': unknownReattackCount,
    'onsetBeforeCurrentPedalDownCount': onsetBeforeCurrentPedalDownCount,
    'onsetAtOrAfterCurrentPedalDownCount': onsetAtOrAfterCurrentPedalDownCount,
    'unknownPedalRelationCount': unknownPedalRelationCount,
  };
}

/// Raw release and pedal evidence bound to one exact structural candidate.
@immutable
final class PolychordCandidateReleasePedalEvidence {
  PolychordCandidateReleasePedalEvidence({
    required this.candidate,
    required this.pedal,
    required this.lower,
    required this.upper,
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
        'lower and upper release/pedal evidence must match the candidate '
        'assignments',
      );
    }
    if (lower.frameTimestampMs != upper.frameTimestampMs ||
        lower.pedalDown != upper.pedalDown ||
        lower.pedalTransition != upper.pedalTransition) {
      throw ArgumentError(
        'lower and upper release/pedal evidence must describe the same frame',
      );
    }
    final expectedPedal = PolychordPedalEvidence(
      down: lower.pedalDown,
      transition: lower.pedalTransition,
      frameTimestampMs: lower.frameTimestampMs,
    );
    if (pedal != expectedPedal) {
      throw ArgumentError.value(
        pedal,
        'pedal',
        'must describe the same frame as the layer evidence',
      );
    }
  }

  final PolychordCandidate candidate;
  final PolychordPedalEvidence pedal;
  final PolychordLayerReleasePedalEvidence lower;
  final PolychordLayerReleasePedalEvidence upper;

  int get pressedCandidateNoteCount =>
      lower.pressedNoteCount + upper.pressedNoteCount;
  int get sustainedCandidateNoteCount =>
      lower.sustainedNoteCount + upper.sustainedNoteCount;
  bool get allSustainedReleasesKnown =>
      lower.allSustainedReleasesKnown && upper.allSustainedReleasesKnown;
  int get reattackedFromSustainCount =>
      lower.reattackedFromSustainCount + upper.reattackedFromSustainCount;
  int get onsetBeforeCurrentPedalDownCount =>
      lower.onsetBeforeCurrentPedalDownCount +
      upper.onsetBeforeCurrentPedalDownCount;
  int get onsetAtOrAfterCurrentPedalDownCount =>
      lower.onsetAtOrAfterCurrentPedalDownCount +
      upper.onsetAtOrAfterCurrentPedalDownCount;
  int get unknownPedalRelationCount =>
      lower.unknownPedalRelationCount + upper.unknownPedalRelationCount;

  Map<String, Object?> toJson() => <String, Object?>{
    'candidate': candidate.toJson(),
    'releasePedalEvidence': <String, Object?>{
      'pedal': pedal.toJson(),
      'lower': lower.toJson(),
      'upper': upper.toJson(),
      'pressedCandidateNoteCount': pressedCandidateNoteCount,
      'sustainedCandidateNoteCount': sustainedCandidateNoteCount,
      'allSustainedReleasesKnown': allSustainedReleasesKnown,
      'reattackedFromSustainCount': reattackedFromSustainCount,
      'onsetBeforeCurrentPedalDownCount': onsetBeforeCurrentPedalDownCount,
      'onsetAtOrAfterCurrentPedalDownCount':
          onsetAtOrAfterCurrentPedalDownCount,
      'unknownPedalRelationCount': unknownPedalRelationCount,
    },
  };
}

const _maximumExactJsonInteger = 9007199254740991;
const _historyListEquality = ListEquality<PolychordSoundingNoteHistory>();
const _intListEquality = ListEquality<int>();

int? _age(int frameTimestampMs, PolychordNoteEventOrigin? origin) =>
    origin == null ? null : frameTimestampMs - origin.timestampMs;

bool _originPrecedesPedal(
  PolychordNoteEventOrigin origin,
  PolychordPedalTransition pedal,
) =>
    origin.timestampMs < pedal.timestampMs ||
    (origin.timestampMs == pedal.timestampMs &&
        origin.eventIndex < pedal.eventIndex);

List<int> _knownInts(List<Map<String, Object?>> records, String key) => [
  for (final record in records)
    if (record[key] case final int value) value,
];

int _count(List<Map<String, Object?>> records, String key, bool value) =>
    records.where((record) => record[key] == value).length;

int? _minimum(List<int> values) => values.isEmpty
    ? null
    : values.reduce((left, right) => left < right ? left : right);

int? _maximum(List<int> values) => values.isEmpty
    ? null
    : values.reduce((left, right) => left > right ? left : right);

PolychordAgeRange? _range(List<int> values) => values.isEmpty
    ? null
    : PolychordAgeRange(minimum: _minimum(values)!, maximum: _maximum(values)!);

void _checkExactNonnegativeInteger(int value, String name) {
  if (value < 0 || value > _maximumExactJsonInteger) {
    throw RangeError.range(value, 0, _maximumExactJsonInteger, name);
  }
}
