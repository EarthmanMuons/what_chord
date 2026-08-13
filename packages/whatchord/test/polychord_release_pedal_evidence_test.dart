import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const analyzer = PolychordReleasePedalEvidenceAnalyzer();

  group('PolychordReleasePedalTracker', () {
    test('preserves grouped releases as raw per-note facts', () {
      final frames = _pedalHistoryFrames();

      final evidence = analyzer.analyzeFrame(frames[12]).single;
      final json = evidence.toJson();
      final release = json['releasePedalEvidence']! as Map<String, Object?>;
      final lower = release['lower']! as Map<String, Object?>;
      final upper = release['upper']! as Map<String, Object?>;

      expect(evidence.candidate.symbol, 'C|Gm');
      expect(release['pedal'], {
        'down': true,
        'lastTransitionEventIndex': 6,
        'lastTransitionTimestampMs': 200,
        'lastTransitionDown': true,
        'currentStateAgeMs': 200,
      });
      expect(lower['distinctKnownReleaseTimestampsMs'], [300]);
      expect(upper['distinctKnownReleaseTimestampsMs'], [400]);
      expect(lower['knownReleaseSpanMs'], 0);
      expect(upper['knownReleaseSpanMs'], 0);
      expect(
        () => evidence.lower.distinctKnownReleaseTimestampsMs.add(999),
        throwsUnsupportedError,
      );
      expect(release['pressedCandidateNoteCount'], 0);
      expect(release['sustainedCandidateNoteCount'], 6);
      expect(release['allSustainedReleasesKnown'], isTrue);
      expect(release['onsetBeforeCurrentPedalDownCount'], 6);
      expect(
        (lower['notes']! as List).cast<Map<String, Object?>>().map(
          (note) => note['releaseVelocity'],
        ),
        [1, 2, 3],
      );
      expect(
        (upper['notes']! as List).cast<Map<String, Object?>>().map(
          (note) => note['releaseVelocity'],
        ),
        [4, 5, 6],
      );
    });

    test('reattack keeps the prior sustained-instance release', () {
      final frames = _pedalHistoryFrames();

      final reattacked = frames[13].soundingNoteHistories.first;
      final reattackJson = reattacked.toJson(
        frameTimestampMs: frames[13].timestampMs,
        pedalDown: frames[13].pedalDown,
        pedalTransition: frames[13].pedalTransition,
      );
      final rereleased = frames[14].soundingNoteHistories.first;

      expect(reattacked.midiNote, 43);
      expect(reattacked.soundingState, PolychordSoundingState.pressed);
      expect(reattacked.onset?.eventIndex, 13);
      expect(reattacked.reattackedFromSustain, isTrue);
      expect(reattacked.priorSustainRelease?.eventIndex, 7);
      expect(reattackJson['priorSustainReleaseAgeMs'], 200);
      expect(reattackJson['onsetBeforeCurrentPedalDown'], isFalse);
      expect(rereleased.release?.eventIndex, 14);
      expect(rereleased.release?.velocity, 7);
      expect(rereleased.priorSustainRelease?.eventIndex, 7);
    });

    test('carried-in origins stay unknown after observed events', () {
      final tracker = PolychordReleasePedalTracker(
        initiallyPressedMidiNotes: const [48],
        initiallySustainedMidiNotes: const [36],
        initiallyPedalDown: true,
      );

      final first = tracker.step(_noteOn(200, 60, 80));
      final second = tracker.step(_noteOff(300, 48));
      final summary = PolychordLayerReleasePedalEvidence(
        notes: second.soundingNoteHistories,
        frameTimestampMs: second.timestampMs,
        pedalDown: second.pedalDown,
        pedalTransition: second.pedalTransition,
      );

      expect(first.pedalEvidence.transition, isNull);
      expect(summary.knownOnsetCount, 1);
      expect(summary.unknownOnsetCount, 2);
      expect(summary.knownReleaseCount, 1);
      expect(summary.unknownReleaseCount, 1);
      expect(summary.knownCurrentStateOriginCount, 2);
      expect(summary.unknownCurrentStateOriginCount, 1);
      expect(summary.notReattackedFromSustainCount, 1);
      expect(summary.unknownReattackCount, 2);
      expect(summary.unknownPedalRelationCount, 3);
    });

    test('pedal release clears sustained notes and keeps pressed history', () {
      final tracker = PolychordReleasePedalTracker(
        initiallyPressedMidiNotes: const [48],
        initiallySustainedMidiNotes: const [36],
        initiallyPedalDown: true,
      );
      tracker.step(_noteOn(200, 60, 80));
      tracker.step(_noteOff(300, 48));

      final frame = tracker.step(
        PolychordSustainPedalEvent(timestampMs: 400, down: false),
      );

      expect(frame.pedalDown, isFalse);
      expect(frame.pedalTransition?.eventIndex, 2);
      expect(frame.soundingNoteHistories.map((note) => note.midiNote), [60]);
      expect(frame.soundingNoteHistories.single.onset?.eventIndex, 0);
      expect(
        frame.soundingNoteHistories.single.currentStateSince?.eventIndex,
        0,
      );
    });

    test('same-timestamp pedal relation follows event order', () {
      final tracker = PolychordReleasePedalTracker();
      tracker.step(_noteOn(100, 60, 80));
      tracker.step(PolychordSustainPedalEvent(timestampMs: 100, down: true));
      final frame = tracker.step(_noteOn(100, 64, 80));

      final records = {
        for (final note in frame.soundingNoteHistories)
          note.midiNote: note.toJson(
            frameTimestampMs: frame.timestampMs,
            pedalDown: frame.pedalDown,
            pedalTransition: frame.pedalTransition,
          ),
      };
      expect(records[60]!['onsetBeforeCurrentPedalDown'], isTrue);
      expect(records[64]!['onsetBeforeCurrentPedalDown'], isFalse);
    });

    test('matches onset tracker facts on every successful event', () {
      final onsetTracker = PolychordOnsetTracker();
      final releaseTracker = PolychordReleasePedalTracker();
      final events = <PolychordTemporalEvent>[
        _noteOn(0, 60, 90),
        PolychordSustainPedalEvent(timestampMs: 100, down: true),
        _noteOff(200, 60, velocity: 7),
        _noteOn(300, 60, 72),
        _noteOff(400, 60),
        PolychordSustainPedalEvent(timestampMs: 500, down: false),
      ];

      for (final event in events) {
        final onsetFrame = onsetTracker.step(event);
        final releaseFrame = releaseTracker.step(event);
        expect(releaseFrame.soundingNoteOnsets, onsetFrame.soundingNoteOnsets);
      }
    });

    test('invalid events and invalid resets are atomic', () {
      final tracker = PolychordReleasePedalTracker();
      tracker.step(_noteOn(100, 60, 90));

      expect(() => tracker.step(_noteOn(200, 60, 90)), throwsStateError);
      expect(() => tracker.step(_noteOff(200, 61)), throwsStateError);
      expect(() => tracker.step(_noteOn(99, 64, 90)), throwsArgumentError);
      expect(
        () => tracker.reset(initiallySustainedMidiNotes: const [61]),
        throwsArgumentError,
      );
      expect(tracker.nextEventIndex, 1);
      expect(tracker.soundingNoteHistories.single.midiNote, 60);

      final frame = tracker.step(_noteOn(200, 64, 90));
      expect(frame.afterEventIndex, 1);
    });

    test('reset starts a separate provenance epoch', () {
      final tracker = PolychordReleasePedalTracker();
      tracker.step(_noteOn(500, 60, 90));

      tracker.reset(
        initiallySustainedMidiNotes: const [36],
        initiallyPedalDown: true,
      );
      final frame = tracker.step(_noteOn(0, 60, 80));

      expect(frame.trackerEpoch, 1);
      expect(frame.afterEventIndex, 0);
      expect(frame.pedalEvidence.transition, isNull);
      expect(frame.soundingNoteHistories.first.onset, isNull);
    });
  });

  group('release/pedal evidence models', () {
    test('reject contradictory history and future origins', () {
      final onset = PolychordNoteEventOrigin(
        eventIndex: 0,
        timestampMs: 100,
        velocity: 80,
      );
      expect(
        () => PolychordSoundingNoteHistory(
          midiNote: 60,
          soundingState: PolychordSoundingState.pressed,
          onset: onset,
          release: PolychordNoteEventOrigin(
            eventIndex: 1,
            timestampMs: 200,
            velocity: 0,
          ),
          currentStateSince: onset,
          reattackedFromSustain: false,
          priorSustainRelease: null,
        ),
        throwsArgumentError,
      );
      expect(
        () => PolychordSoundingNoteHistory(
          midiNote: 60,
          soundingState: PolychordSoundingState.sustained,
          onset: onset,
          release: null,
          currentStateSince: null,
          reattackedFromSustain: false,
          priorSustainRelease: null,
        ),
        throwsArgumentError,
      );
      final earlierIndex = PolychordNoteEventOrigin(
        eventIndex: 0,
        timestampMs: 200,
        velocity: 0,
      );
      final laterIndex = PolychordNoteEventOrigin(
        eventIndex: 1,
        timestampMs: 100,
        velocity: 80,
      );
      expect(laterIndex.precedes(earlierIndex), isFalse);
      final history = PolychordSoundingNoteHistory(
        midiNote: 60,
        soundingState: PolychordSoundingState.pressed,
        onset: onset,
        release: null,
        currentStateSince: onset,
        reattackedFromSustain: false,
        priorSustainRelease: null,
      );
      expect(
        () => PolychordReleasePedalTrackingFrame(
          trackerEpoch: 0,
          afterEventIndex: 0,
          timestampMs: 99,
          pedalDown: false,
          pedalTransition: null,
          soundingNoteHistories: [history],
        ),
        throwsArgumentError,
      );
    });

    test(
      'analyzer returns all structural candidates without policy fields',
      () {
        final tracker = PolychordReleasePedalTracker();
        PolychordReleasePedalTrackingFrame? frame;
        for (final midiNote in const [36, 40, 43, 59, 74, 78, 81]) {
          frame = tracker.step(_noteOn(0, midiNote, 80));
        }

        final evidence = analyzer.analyzeFrame(frame!);
        final serialized = evidence.map((item) => item.toJson()).toString();

        expect(evidence.map((item) => item.candidate.symbol), [
          'Bm7|C',
          'D|Cmaj7',
        ]);
        for (final forbidden in const [
          'support',
          'confidence',
          'eligible',
          'penalty',
          'display',
        ]) {
          expect(serialized.toLowerCase(), isNot(contains(forbidden)));
        }
      },
    );

    test('candidate evidence rejects summaries from different frames', () {
      final frames = _pedalHistoryFrames();
      final first = analyzer.analyzeFrame(frames[12]).single;
      final second = analyzer.analyzeFrame(frames[13]).single;

      expect(
        () => PolychordCandidateReleasePedalEvidence(
          candidate: first.candidate,
          pedal: first.pedal,
          lower: first.lower,
          upper: second.upper,
        ),
        throwsArgumentError,
      );
      expect(
        () => PolychordCandidateReleasePedalEvidence(
          candidate: first.candidate,
          pedal: PolychordPedalEvidence(
            down: false,
            transition: null,
            frameTimestampMs: first.lower.frameTimestampMs,
          ),
          lower: first.lower,
          upper: first.upper,
        ),
        throwsArgumentError,
      );
    });
  });
}

List<PolychordReleasePedalTrackingFrame> _pedalHistoryFrames() {
  final tracker = PolychordReleasePedalTracker();
  final events = <PolychordTemporalEvent>[
    for (final midiNote in const [43, 46, 50]) _noteOn(0, midiNote, 80),
    for (final midiNote in const [60, 64, 67]) _noteOn(100, midiNote, 80),
    PolychordSustainPedalEvent(timestampMs: 200, down: true),
    _noteOff(300, 43, velocity: 1),
    _noteOff(300, 46, velocity: 2),
    _noteOff(300, 50, velocity: 3),
    _noteOff(400, 60, velocity: 4),
    _noteOff(400, 64, velocity: 5),
    _noteOff(400, 67, velocity: 6),
    _noteOn(500, 43, 72),
    _noteOff(600, 43, velocity: 7),
    PolychordSustainPedalEvent(timestampMs: 700, down: false),
  ];
  return [for (final event in events) tracker.step(event)];
}

PolychordNoteOnEvent _noteOn(int timestampMs, int midiNote, int velocity) =>
    PolychordNoteOnEvent(
      timestampMs: timestampMs,
      midiNote: midiNote,
      velocity: velocity,
    );

PolychordNoteOffEvent _noteOff(
  int timestampMs,
  int midiNote, {
  int velocity = 0,
}) => PolychordNoteOffEvent(
  timestampMs: timestampMs,
  midiNote: midiNote,
  velocity: velocity,
);
