import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  group('PolychordOnsetTracker', () {
    test('starts with unknown carried-in note origins', () {
      final tracker = PolychordOnsetTracker(
        initiallyPressedMidiNotes: const [60, 48],
        initiallySustainedMidiNotes: const [36],
        initiallyPedalDown: true,
      );

      expect(tracker.pedalDown, isTrue);
      expect(tracker.trackerEpoch, 0);
      expect(tracker.nextEventIndex, 0);
      expect(tracker.soundingNoteOnsets.map((note) => note.midiNote), [
        36,
        48,
        60,
      ]);
      expect(tracker.soundingNoteOnsets.map((note) => note.soundingState), [
        PolychordSoundingState.sustained,
        PolychordSoundingState.pressed,
        PolychordSoundingState.pressed,
      ]);
      expect(
        tracker.soundingNoteOnsets.every((note) => note.origin == null),
        isTrue,
      );
    });

    test('tracks same-timestamp attacks in delivery order', () {
      final tracker = PolychordOnsetTracker();

      final first = tracker.step(_noteOn(0, 60, 90));
      final second = tracker.step(_noteOn(0, 64, 91));

      expect(first.afterEventIndex, 0);
      expect(second.afterEventIndex, 1);
      expect(second.timestampMs, 0);
      expect(second.soundingNoteOnsets.map((note) => note.origin?.eventIndex), [
        0,
        1,
      ]);
      expect(second.soundingNoteOnsets.map((note) => note.origin?.velocity), [
        90,
        91,
      ]);
    });

    test('removes a released note while the pedal is up', () {
      final tracker = PolychordOnsetTracker();
      tracker.step(_noteOn(0, 60, 90));

      final frame = tracker.step(_noteOff(100, 60));

      expect(frame.soundingNoteOnsets, isEmpty);
      expect(frame.soundingMidiNotes, isEmpty);
      expect(frame.pedalDown, isFalse);
    });

    test('sustain preserves an origin and reattack replaces it', () {
      final tracker = PolychordOnsetTracker();
      tracker.step(_noteOn(0, 60, 90));
      tracker.step(PolychordSustainPedalEvent(timestampMs: 100, down: true));
      final sustained = tracker.step(_noteOff(200, 60, velocity: 7));

      expect(sustained.sustainedMidiNotes, [60]);
      expect(sustained.soundingNoteOnsets.single.origin?.eventIndex, 0);
      expect(sustained.soundingNoteOnsets.single.origin?.timestampMs, 0);

      final reattacked = tracker.step(_noteOn(300, 60, 72));
      expect(reattacked.pressedMidiNotes, [60]);
      expect(reattacked.sustainedMidiNotes, isEmpty);
      expect(reattacked.soundingNoteOnsets.single.origin?.eventIndex, 3);
      expect(reattacked.soundingNoteOnsets.single.origin?.timestampMs, 300);
      expect(reattacked.soundingNoteOnsets.single.origin?.velocity, 72);
    });

    test('pedal release clears sustained notes but retains pressed notes', () {
      final tracker = PolychordOnsetTracker();
      tracker.step(_noteOn(0, 60, 90));
      tracker.step(_noteOn(0, 64, 91));
      tracker.step(PolychordSustainPedalEvent(timestampMs: 100, down: true));
      tracker.step(_noteOff(200, 60));

      final frame = tracker.step(
        PolychordSustainPedalEvent(timestampMs: 300, down: false),
      );

      expect(frame.pedalDown, isFalse);
      expect(frame.pressedMidiNotes, [64]);
      expect(frame.sustainedMidiNotes, isEmpty);
      expect(frame.soundingMidiNotes, [64]);
      expect(frame.soundingNoteOnsets.single.origin?.eventIndex, 1);
    });

    test('invalid events are atomic and do not consume an index', () {
      final tracker = PolychordOnsetTracker();
      tracker.step(_noteOn(100, 60, 90));

      expect(() => tracker.step(_noteOn(200, 60, 90)), throwsStateError);
      expect(() => tracker.step(_noteOff(200, 61)), throwsStateError);
      expect(
        () => tracker.step(
          PolychordSustainPedalEvent(timestampMs: 200, down: false),
        ),
        throwsStateError,
      );
      expect(() => tracker.step(_noteOn(99, 64, 90)), throwsArgumentError);
      expect(tracker.nextEventIndex, 1);
      expect(tracker.soundingNoteOnsets.map((note) => note.midiNote), [60]);

      final frame = tracker.step(_noteOn(200, 64, 90));
      expect(frame.afterEventIndex, 1);
    });

    test('reset starts a new epoch and may establish carried-in state', () {
      final tracker = PolychordOnsetTracker();
      tracker.step(_noteOn(500, 60, 90));

      tracker.reset(
        initiallyPressedMidiNotes: const [48],
        initiallySustainedMidiNotes: const [36],
        initiallyPedalDown: true,
      );

      expect(tracker.trackerEpoch, 1);
      expect(tracker.nextEventIndex, 0);
      expect(
        tracker.soundingNoteOnsets.every((note) => note.origin == null),
        isTrue,
      );
      final frame = tracker.step(_noteOn(0, 60, 80));
      expect(frame.afterEventIndex, 0);
      expect(frame.trackerEpoch, 1);
      expect(frame.soundingMidiNotes, [36, 48, 60]);
    });

    test('rejects invalid initial state without disturbing a reset', () {
      expect(
        () => PolychordOnsetTracker(initiallySustainedMidiNotes: const [60]),
        throwsArgumentError,
      );
      expect(
        () => PolychordOnsetTracker(
          initiallyPressedMidiNotes: const [60],
          initiallySustainedMidiNotes: const [60],
          initiallyPedalDown: true,
        ),
        throwsArgumentError,
      );
      expect(
        () => PolychordOnsetTracker(initiallyPressedMidiNotes: const [60, 60]),
        throwsArgumentError,
      );
      expect(
        () => PolychordOnsetTracker(initiallyPressedMidiNotes: const [128]),
        throwsRangeError,
      );

      final tracker = PolychordOnsetTracker();
      tracker.step(_noteOn(0, 60, 90));
      expect(
        () => tracker.reset(initiallySustainedMidiNotes: const [61]),
        throwsArgumentError,
      );
      expect(tracker.nextEventIndex, 1);
      expect(tracker.soundingNoteOnsets.single.midiNote, 60);
    });

    test('validates event fields at normalization boundary', () {
      expect(() => _noteOn(-1, 60, 90), throwsRangeError);
      expect(() => _noteOn(9007199254740992, 60, 90), throwsRangeError);
      expect(() => _noteOn(0, -1, 90), throwsRangeError);
      expect(() => _noteOn(0, 60, 0), throwsRangeError);
      expect(() => _noteOff(0, 60, velocity: -1), throwsRangeError);
    });

    test('serializes the combined replay and onset frame', () {
      final tracker = PolychordOnsetTracker();

      final json = tracker.step(_noteOn(25, 60, 90)).toJson();

      expect(json, {
        'trackerEpoch': 0,
        'afterEventIndex': 0,
        'timestampMs': 25,
        'pressedMidiNotes': [60],
        'sustainedMidiNotes': <int>[],
        'soundingMidiNotes': [60],
        'pedalDown': false,
        'onsetNotes': [
          {
            'midiNote': 60,
            'soundingState': 'pressed',
            'onsetEventIndex': 0,
            'onsetTimestampMs': 25,
            'onsetVelocity': 90,
          },
        ],
      });
    });

    test('feeds tracked facts directly into the onset evidence analyzer', () {
      final tracker = PolychordOnsetTracker();
      PolychordOnsetTrackingFrame? frame;
      for (final midiNote in const [43, 46, 50]) {
        frame = tracker.step(_noteOn(0, midiNote, 80));
      }
      for (final midiNote in const [60, 64, 67]) {
        frame = tracker.step(_noteOn(400, midiNote, 80));
      }

      final evidence = const PolychordOnsetEvidenceAnalyzer()
          .analyzeFrame(frame!.soundingNoteOnsets)
          .single;

      expect(evidence.candidate.symbol, 'C|Gm');
      expect(evidence.upperEarliestMinusLowerLatestMs, 400);
      expect(evidence.upperLatestMinusLowerEarliestMs, 400);
    });

    test('frame model rejects contradictory replay state', () {
      final pressed = PolychordSoundingNoteOnset(
        midiNote: 60,
        soundingState: PolychordSoundingState.pressed,
        origin: PolychordOnsetOrigin(
          eventIndex: 0,
          timestampMs: 0,
          velocity: 90,
        ),
      );
      final sustained = PolychordSoundingNoteOnset(
        midiNote: 64,
        soundingState: PolychordSoundingState.sustained,
      );

      expect(
        () => PolychordOnsetTrackingFrame(
          trackerEpoch: 0,
          afterEventIndex: 0,
          timestampMs: 0,
          pedalDown: false,
          soundingNoteOnsets: [pressed, sustained],
        ),
        throwsArgumentError,
      );
      expect(
        () => PolychordOnsetTrackingFrame(
          trackerEpoch: 0,
          afterEventIndex: 0,
          timestampMs: 0,
          pedalDown: false,
          soundingNoteOnsets: [sustained, pressed],
        ),
        throwsArgumentError,
      );
      expect(
        () => PolychordOnsetTrackingFrame(
          trackerEpoch: 0,
          afterEventIndex: 0,
          timestampMs: 0,
          pedalDown: false,
          soundingNoteOnsets: [
            PolychordSoundingNoteOnset(
              midiNote: 60,
              soundingState: PolychordSoundingState.pressed,
              origin: PolychordOnsetOrigin(
                eventIndex: 1,
                timestampMs: 0,
                velocity: 90,
              ),
            ),
          ],
        ),
        throwsArgumentError,
      );
    });
  });
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
