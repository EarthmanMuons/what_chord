import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const binder = PolychordCandidateInstanceBinder();

  test('binds the exact candidate and every sounding instance', () {
    final trace = _playCandidate();
    final binding = _bind(trace.frame);

    expect(binding.candidate.symbol, 'C|Gm');
    expect(binding.availability, PolychordInstanceBindingAvailability.complete);
    expect(
      binding.targetInstances.map(
        (instance) => (instance.midiNote, instance.onsetEventIndex),
      ),
      [(43, 0), (46, 1), (50, 2), (60, 3), (64, 4), (67, 5)],
    );
    expect(binding.toJson().keys, {
      'trackerEpoch',
      'candidate',
      'targetInstances',
      'availability',
    });
  });

  test('preserves carried-in notes as an incomplete binding', () {
    final tracker = PolychordOnsetTracker(
      initiallyPressedMidiNotes: _candidateNotes,
    );
    final frame = tracker.step(
      PolychordSustainPedalEvent(timestampMs: 0, down: true),
    );

    final binding = _bind(frame);

    expect(
      binding.availability,
      PolychordInstanceBindingAvailability.incomplete,
    );
    expect(binding.isComplete, isFalse);
    expect(
      binding.targetInstances.map((instance) => instance.onsetEventIndex),
      everyElement(isNull),
    );
    expect(
      (binding.toJson()['targetInstances']! as List)
          .cast<Map<String, Object?>>()
          .every((instance) => instance['onsetEventIndex'] == null),
      isTrue,
    );
  });

  test('sustain and unrelated pedal events preserve exact instances', () {
    final trace = _playCandidate();
    final binding = _bind(trace.frame);
    final pedalFrame = trace.tracker.step(
      PolychordSustainPedalEvent(timestampMs: 10000, down: true),
    );
    final sustainFrame = trace.tracker.step(
      PolychordNoteOffEvent(timestampMs: 10001, midiNote: 43, velocity: 0),
    );

    expect(_remains(binding, pedalFrame), isTrue);
    expect(_remains(binding, sustainFrame), isTrue);
  });

  test('same-note reattack invalidates the prior sounding instance', () {
    final trace = _playCandidate();
    trace.tracker.step(PolychordSustainPedalEvent(timestampMs: 10, down: true));
    final sustained = trace.tracker.step(
      PolychordNoteOffEvent(timestampMs: 11, midiNote: 43, velocity: 0),
    );
    final priorBinding = _bind(sustained);
    final reattacked = trace.tracker.step(
      PolychordNoteOnEvent(timestampMs: 12, midiNote: 43, velocity: 80),
    );
    final nextBinding = _bind(reattacked);

    expect(_remains(priorBinding, reattacked), isFalse);
    expect(nextBinding.candidate, priorBinding.candidate);
    expect(nextBinding.targetInstances.first.onsetEventIndex, 8);
    expect(nextBinding, isNot(priorBinding));
  });

  test('a note-set change invalidates the exact candidate assignment', () {
    final trace = _playCandidate();
    final binding = _bind(trace.frame);
    final reduced = trace.tracker.step(
      PolychordNoteOffEvent(timestampMs: 10, midiNote: 43, velocity: 0),
    );

    expect(_remains(binding, reduced), isFalse);
  });

  test('a reset invalidates identical event indices and note assignments', () {
    final trace = _playCandidate();
    final priorBinding = _bind(trace.frame);

    trace.tracker.reset();
    PolychordOnsetTrackingFrame? frame;
    for (var index = 0; index < _candidateNotes.length; index++) {
      frame = trace.tracker.step(
        PolychordNoteOnEvent(
          timestampMs: index,
          midiNote: _candidateNotes[index],
          velocity: 80,
        ),
      );
    }
    final nextBinding = _bind(frame!);

    expect(nextBinding.candidate, priorBinding.candidate);
    expect(nextBinding.targetInstances, priorBinding.targetInstances);
    expect(nextBinding.trackerEpoch, 1);
    expect(priorBinding.trackerEpoch, 0);
    expect(_remains(priorBinding, frame), isFalse);
  });

  test('requires the candidate to exhaust the current sounding state', () {
    final trace = _playCandidate();
    final candidate = const PolychordRegisterCandidateGenerator()
        .generate(_candidateNotes)
        .single;

    expect(
      () => binder.bindCandidateToOnsetFrame(
        candidate: candidate,
        frame: PolychordOnsetTrackingFrame(
          trackerEpoch: trace.frame.trackerEpoch,
          afterEventIndex: trace.frame.afterEventIndex,
          timestampMs: trace.frame.timestampMs,
          pedalDown: trace.frame.pedalDown,
          soundingNoteOnsets: trace.frame.soundingNoteOnsets.take(5),
        ),
      ),
      throwsArgumentError,
    );
    expect(
      () => PolychordOnsetTrackingFrame(
        trackerEpoch: -1,
        afterEventIndex: trace.frame.afterEventIndex,
        timestampMs: trace.frame.timestampMs,
        pedalDown: trace.frame.pedalDown,
        soundingNoteOnsets: trace.frame.soundingNoteOnsets,
      ),
      throwsRangeError,
    );
  });

  test('onset and release trackers share one instance-key representation', () {
    final onsetTrace = _playCandidate();
    final releaseTracker = PolychordReleasePedalTracker();
    PolychordReleasePedalTrackingFrame? releaseFrame;
    for (var index = 0; index < _candidateNotes.length; index++) {
      releaseFrame = releaseTracker.step(
        PolychordNoteOnEvent(
          timestampMs: index,
          midiNote: _candidateNotes[index],
          velocity: 80,
        ),
      );
    }

    final onsetBinding = _bind(onsetTrace.frame);
    final releaseBinding = binder.bindReleasePedalFrame(releaseFrame!).single;
    final historyKeys = releaseFrame.soundingNoteHistories
        .map(PolychordSoundingInstanceIdentity.fromHistory)
        .map((identity) => identity.key);

    expect(releaseBinding, onsetBinding);
    expect(releaseBinding.targetInstances, historyKeys);
    expect(
      binder.remainsCurrentInReleasePedalFrame(
        binding: onsetBinding,
        frame: releaseFrame,
      ),
      isTrue,
    );
  });
}

({PolychordOnsetTracker tracker, PolychordOnsetTrackingFrame frame})
_playCandidate() {
  final tracker = PolychordOnsetTracker();
  PolychordOnsetTrackingFrame? frame;
  for (var index = 0; index < _candidateNotes.length; index++) {
    frame = tracker.step(
      PolychordNoteOnEvent(
        timestampMs: index,
        midiNote: _candidateNotes[index],
        velocity: 80,
      ),
    );
  }
  return (tracker: tracker, frame: frame!);
}

PolychordCandidateInstanceBinding _bind(PolychordOnsetTrackingFrame frame) =>
    const PolychordCandidateInstanceBinder().bindOnsetFrame(frame).single;

bool _remains(
  PolychordCandidateInstanceBinding binding,
  PolychordOnsetTrackingFrame frame,
) => const PolychordCandidateInstanceBinder().remainsCurrentInOnsetFrame(
  binding: binding,
  frame: frame,
);

const _candidateNotes = [43, 46, 50, 60, 64, 67];
