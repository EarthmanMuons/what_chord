import 'package:test/test.dart';
import 'package:whatchord/whatchord.dart';

void main() {
  group('PolychordStableDisplayGate', () {
    test('delays appearance until the exact selection survives 200 ms', () {
      final gate = PolychordStableDisplayGate();
      final candidate = _candidate(
        lowerNotes: const [48, 52, 55],
        upperNotes: const [62, 66, 69],
      );
      final notes = _assigned(candidate);

      expect(
        gate
            .step(
              timestamp: Duration.zero,
              rawSelected: candidate,
              primaryDisplayable: true,
              soundingMidiNotes: notes,
            )
            .transition,
        PolychordDisplayTransition.pending,
      );
      expect(gate.pendingDeadline, const Duration(milliseconds: 200));
      expect(
        gate
            .step(
              timestamp: const Duration(milliseconds: 199),
              rawSelected: candidate,
              primaryDisplayable: true,
              soundingMidiNotes: notes,
            )
            .transition,
        PolychordDisplayTransition.pending,
      );
      final appeared = gate.step(
        timestamp: const Duration(milliseconds: 200),
        rawSelected: candidate,
        primaryDisplayable: true,
        soundingMidiNotes: notes,
      );
      expect(appeared.transition, PolychordDisplayTransition.appearance);
      expect(appeared.displayed, candidate);
      expect(appeared.reasonCode, isNull);
    });

    test('uses the exact assignment instead of identity alone', () {
      final gate = PolychordStableDisplayGate();
      final first = _candidate(
        lowerNotes: const [48, 52, 55],
        upperNotes: const [67, 71, 74, 79],
        upperRootPc: 7,
      );
      final reassigned = _candidate(
        lowerNotes: const [48, 52, 55, 67],
        upperNotes: const [71, 74, 79],
        upperRootPc: 7,
      );
      final notes = _assigned(first);

      _appear(gate, first, notes);
      final changed = gate.step(
        timestamp: const Duration(milliseconds: 300),
        rawSelected: reassigned,
        primaryDisplayable: true,
        soundingMidiNotes: notes,
      );
      expect(changed.transition, PolychordDisplayTransition.pending);
      expect(changed.displayed, first);
      expect(
        gate
            .step(
              timestamp: const Duration(milliseconds: 500),
              rawSelected: reassigned,
              primaryDisplayable: true,
              soundingMidiNotes: notes,
            )
            .transition,
        PolychordDisplayTransition.change,
      );
      expect(gate.displayed, reassigned);
    });

    test('clears immediately when the displayed assignment is invalidated', () {
      final gate = PolychordStableDisplayGate();
      final candidate = _candidate(
        lowerNotes: const [48, 52, 55],
        upperNotes: const [62, 66, 69],
      );
      _appear(gate, candidate, _assigned(candidate));

      final cleared = gate.step(
        timestamp: const Duration(milliseconds: 250),
        rawSelected: null,
        primaryDisplayable: true,
        soundingMidiNotes: const [48, 52, 55, 62, 66],
      );
      expect(cleared.transition, PolychordDisplayTransition.clear);
      expect(cleared.reasonCode, 'invalidated-assignment');
      expect(cleared.displayed, isNull);
    });

    for (final condition in <({String name, String reason})>[
      (name: 'absent primary', reason: 'primary-not-displayable'),
      (name: 'silence', reason: 'silence'),
      (name: 'selector abstention', reason: 'abstention'),
    ]) {
      test('clears immediately for ${condition.name}', () {
        final gate = PolychordStableDisplayGate();
        final candidate = _candidate(
          lowerNotes: const [48, 52, 55],
          upperNotes: const [62, 66, 69],
        );
        final notes = _assigned(candidate);
        _appear(gate, candidate, notes);

        final result = gate.step(
          timestamp: const Duration(milliseconds: 250),
          rawSelected: condition.reason == 'abstention' ? null : candidate,
          primaryDisplayable: condition.reason != 'primary-not-displayable',
          soundingMidiNotes: condition.reason == 'silence' ? const [] : notes,
        );
        expect(result.transition, PolychordDisplayTransition.clear);
        expect(result.reasonCode, condition.reason);
        expect(result.displayed, isNull);
      });
    }

    test(
      'rejects a raw selection that does not exhaust the sounding notes',
      () {
        final gate = PolychordStableDisplayGate();
        final candidate = _candidate(
          lowerNotes: const [48, 52, 55],
          upperNotes: const [62, 66, 69],
        );
        expect(
          () => gate.step(
            timestamp: Duration.zero,
            rawSelected: candidate,
            primaryDisplayable: true,
            soundingMidiNotes: const [48, 52, 55, 62, 66, 69, 72],
          ),
          throwsArgumentError,
        );
      },
    );

    test('requires nondecreasing nonnegative timestamps', () {
      final gate = PolychordStableDisplayGate();
      gate.step(
        timestamp: const Duration(milliseconds: 1),
        rawSelected: null,
        primaryDisplayable: true,
        soundingMidiNotes: const [],
      );
      expect(
        () => gate.step(
          timestamp: Duration.zero,
          rawSelected: null,
          primaryDisplayable: true,
          soundingMidiNotes: const [],
        ),
        throwsArgumentError,
      );
      expect(
        () => PolychordStableDisplayGate().step(
          timestamp: const Duration(milliseconds: -1),
          rawSelected: null,
          primaryDisplayable: true,
          soundingMidiNotes: const [],
        ),
        throwsRangeError,
      );
    });

    test('requires a nonnegative stability duration', () {
      expect(
        () => PolychordStableDisplayGate(
          minDuration: const Duration(milliseconds: -1),
        ),
        throwsRangeError,
      );
    });
  });
}

void _appear(
  PolychordStableDisplayGate gate,
  PolychordCandidate candidate,
  List<int> notes,
) {
  gate.step(
    timestamp: Duration.zero,
    rawSelected: candidate,
    primaryDisplayable: true,
    soundingMidiNotes: notes,
  );
  gate.step(
    timestamp: const Duration(milliseconds: 200),
    rawSelected: candidate,
    primaryDisplayable: true,
    soundingMidiNotes: notes,
  );
}

List<int> _assigned(PolychordCandidate candidate) =>
    [...candidate.lower.midiNotes, ...candidate.upper.midiNotes]..sort();

PolychordCandidate _candidate({
  required List<int> lowerNotes,
  required List<int> upperNotes,
  int upperRootPc = 2,
}) {
  const lowerIdentity = PolychordLayerIdentity(
    rootPc: 0,
    quality: PolychordLayerQuality.major,
  );
  final upperIdentity = PolychordLayerIdentity(
    rootPc: upperRootPc,
    quality: PolychordLayerQuality.major,
  );
  return PolychordCandidate(
    splitAfterIndex: lowerNotes.length - 1,
    lowerTopMidi: lowerNotes.last,
    upperBottomMidi: upperNotes.first,
    gapSemitones: upperNotes.first - lowerNotes.last,
    lower: PolychordLayerCandidate(
      identity: lowerIdentity,
      midiNotes: lowerNotes,
      pitchClasses: lowerNotes.map((note) => note % 12).toSet().toList()
        ..sort(),
    ),
    upper: PolychordLayerCandidate(
      identity: upperIdentity,
      midiNotes: upperNotes,
      pitchClasses: upperNotes.map((note) => note % 12).toSet().toList()
        ..sort(),
    ),
    sharedPitchClasses: const [],
  );
}
