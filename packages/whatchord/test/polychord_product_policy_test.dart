import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  group('product onset cue', () {
    test('accepts inclusive 50 and 80 millisecond boundaries', () {
      final decision = const PolychordOnsetRegisterSelector().decide(
        _frame([43, 46, 50, 60, 64, 67], [0, 25, 50, 130, 155, 180]),
      );

      final record = decision.candidateRecords.single;
      expect(record.support, PolychordCueSupport.positive);
      expect(record.interpretation.lowerWithinCohortSpanMaximum, isTrue);
      expect(record.interpretation.upperWithinCohortSpanMaximum, isTrue);
      expect(record.interpretation.betweenLayerOnsetIntervalGapMs, 80);
      expect(record.reasonCodes, ['separate-coherent-onset-cohorts']);
    });

    test('rejects just-outside span and separation boundaries', () {
      final selector = const PolychordOnsetRegisterSelector();
      final span = selector
          .decide(_frame([43, 46, 50, 60, 64, 67], [0, 25, 51, 131, 156, 181]))
          .candidateRecords
          .single;
      final gap = selector
          .decide(_frame([43, 46, 50, 60, 64, 67], [0, 0, 0, 79, 79, 79]))
          .candidateRecords
          .single;

      expect(span.support, PolychordCueSupport.neutral);
      expect(span.reasonCodes, ['lower-span-exceeds-maximum']);
      expect(gap.support, PolychordCueSupport.neutral);
      expect(gap.reasonCodes, ['between-layer-separation-below-minimum']);
    });

    test(
      'treats upper-first order equivalently and preserves unknown history',
      () {
        final selector = const PolychordOnsetRegisterSelector();
        final upperFirst = selector
            .decide(_frame([42, 46, 49, 60, 64, 67], [80, 80, 80, 0, 0, 0]))
            .candidateRecords
            .single;
        final incomplete = selector
            .decide(
              _frame(
                [43, 46, 50, 60, 64, 67],
                [null, null, null, null, null, null],
              ),
            )
            .candidateRecords
            .single;

        expect(upperFirst.support, PolychordCueSupport.positive);
        expect(
          upperFirst.interpretation.layerOnsetOrder,
          PolychordLayerOnsetOrder.upperThenLower,
        );
        expect(incomplete.availability, PolychordCueAvailability.incomplete);
        expect(incomplete.support, isNull);
        expect(incomplete.reasonCodes, ['onset-history-incomplete']);
      },
    );
  });

  group('onset register selector', () {
    test('applies the frozen abstention precedence', () {
      final selector = const PolychordOnsetRegisterSelector();
      final positive = selector.decide(
        _frame([43, 46, 50, 60, 64, 67], [0, 0, 0, 80, 80, 80]),
      );
      final ambiguous = selector.decide(
        _frame([48, 52, 55, 67, 71, 74, 79], [0, 0, 0, 80, 80, 80, 80]),
      );
      final integrated = selector.decide(
        _frame([48, 52, 55, 67, 71, 74], [0, 0, 0, 80, 80, 80]),
      );
      final neutral = selector.decide(
        _frame([43, 46, 50, 60, 64, 67], [0, 0, 0, 79, 79, 79]),
      );
      final incomplete = selector.decide(
        _frame([43, 46, 50, 60, 64, 67], [null, null, null, null, null, null]),
      );

      expect(positive.selected?.symbol, 'C|Gm');
      expect(positive.reasonCode, isNull);
      expect(ambiguous.reasonCode, 'ambiguous-exact-assignment');
      expect(integrated.reasonCode, 'integrated-tertian-reading');
      expect(neutral.reasonCode, 'layer-separation-not-supported');
      expect(incomplete.reasonCode, 'missing-layer-separation-history');
    });

    test('admits a complete seventh chord in the upper layer', () {
      final decision = const PolychordOnsetRegisterSelector().decide(
        _frame([28, 40, 44, 47, 51, 55, 58, 61], [0, 0, 0, 0, 80, 80, 80, 80]),
      );

      expect(decision.selected?.symbol, 'D#7|E');
      expect(
        decision.selected?.upper.identity.quality,
        PolychordLayerQuality.dominant7,
      );
    });

    test('is independent of supplied cue-record order', () {
      final frame = _frame(
        [44, 48, 51, 54, 67, 71, 74],
        [0, 0, 0, 0, 80, 80, 80],
      );
      final records = const PolychordProductOnsetCueRecordBuilder().build(
        frame,
      );
      final selector = const PolychordOnsetRegisterSelector();

      expect(
        selector.decideRecords(frame, records.reversed).toJson(),
        selector.decideRecords(frame, records).toJson(),
      );
    });

    test(
      'positive survivors are unique across the complete structural matrix',
      () {
        var checked = 0;
        for (final lowerQuality in PolychordLayerQuality.values) {
          for (final upperQuality in PolychordLayerQuality.values) {
            for (var relativeRoot = 1; relativeRoot < 12; relativeRoot++) {
              for (var transposition = 0; transposition < 12; transposition++) {
                final lower = _rootPositionNotes(
                  transposition,
                  lowerQuality,
                  36,
                );
                final upper = _rootPositionNotes(
                  (transposition + relativeRoot) % 12,
                  upperQuality,
                  72,
                );
                final notes = [...lower, ...upper]..sort();
                final frame = _frame(notes, [
                  ...List.filled(lower.length, 0),
                  ...List.filled(upper.length, 80),
                ]);
                const selector = PolychordOnsetRegisterSelector();
                final decision = selector.decide(frame);
                final records = const PolychordProductOnsetCueRecordBuilder()
                    .build(frame);
                expect(
                  decision.stageSurvivors.positiveSupport.length,
                  lessThanOrEqualTo(1),
                );
                expect(
                  decision.toJson(),
                  selector.decideRecords(frame, records).toJson(),
                );
                checked++;
              }
            }
          }
        }
        expect(checked, 3300);
      },
    );
  });

  group('product engine', () {
    test('appears at the inclusive deadline and remains stable', () {
      final engine = _positiveEngine();

      final before = engine.observeTimer(279);
      final visible = engine.observeTimer(280);
      final stable = engine.observeTimer(281);

      expect(before.display.state, PolychordProductDisplayState.pending);
      expect(before.display.transition, PolychordProductDisplayTransition.none);
      expect(visible.display.state, PolychordProductDisplayState.visible);
      expect(
        visible.display.transition,
        PolychordProductDisplayTransition.appearance,
      );
      expect(
        stable.display.transition,
        PolychordProductDisplayTransition.stable,
      );
      expect(stable.displayedCandidate?.symbol, 'C|Gm');
    });

    test('primary loss clears and restoration starts a fresh interval', () {
      final engine = _positiveEngine()..observeTimer(280);

      final cleared = engine.setPrimaryDisplayable(
        timestampMs: 300,
        displayable: false,
      );
      final restarted = engine.setPrimaryDisplayable(
        timestampMs: 310,
        displayable: true,
      );

      expect(
        cleared.display.transition,
        PolychordProductDisplayTransition.clear,
      );
      expect(cleared.display.reasonCode, 'primary-not-displayable');
      expect(
        restarted.display.transition,
        PolychordProductDisplayTransition.pending,
      );
      expect(restarted.display.deadlineMs, 510);
    });

    test(
      'reattack invalidates an equal assignment with a new instance key',
      () {
        final engine = _positiveEngine()..observeTimer(280);
        engine.observeEvent(
          PolychordSustainPedalEvent(timestampMs: 300, down: true),
        );
        engine.observeEvent(
          PolychordNoteOffEvent(timestampMs: 320, midiNote: 60, velocity: 0),
        );

        final reattack = engine.observeEvent(
          PolychordNoteOnEvent(timestampMs: 330, midiNote: 60, velocity: 80),
        );

        expect(
          reattack.rawDecision?.reasonCode,
          'layer-separation-not-supported',
        );
        expect(
          reattack.display.transition,
          PolychordProductDisplayTransition.clear,
        );
        expect(reattack.display.reasonCode, 'invalidated-support-binding');
      },
    );

    test('reset clears all product state', () {
      final engine = _positiveEngine()..observeTimer(280);

      final reset = engine.reset(timestampMs: 300);

      expect(reset.frame, isNull);
      expect(reset.rawDecision, isNull);
      expect(reset.authorization, isNull);
      expect(reset.candidates, isEmpty);
      expect(reset.display.transition, PolychordProductDisplayTransition.clear);
      expect(reset.display.reasonCode, 'tracker-reset');
    });

    test('reset can restore carried notes only as incomplete history', () {
      final engine = _positiveEngine()..observeTimer(280);
      engine.reset(
        timestampMs: 300,
        initiallyPressedMidiNotes: [43, 46, 50, 60, 64, 67],
      );

      final restored = engine.observeEvent(
        PolychordSustainPedalEvent(timestampMs: 310, down: true),
      );

      expect(restored.frame?.trackerEpoch, 1);
      expect(
        restored.rawDecision?.reasonCode,
        'missing-layer-separation-history',
      );
      expect(restored.authorization?.key, isNull);
      expect(restored.display.state, PolychordProductDisplayState.absent);
    });
  });
}

PolychordProductEngine _positiveEngine() {
  final engine = PolychordProductEngine(initialPrimaryDisplayable: true);
  for (final note in [43, 46, 50]) {
    engine.observeEvent(
      PolychordNoteOnEvent(timestampMs: 0, midiNote: note, velocity: 80),
    );
  }
  for (final note in [60, 64, 67]) {
    engine.observeEvent(
      PolychordNoteOnEvent(timestampMs: 80, midiNote: note, velocity: 80),
    );
  }
  expect(
    engine.latestObservation?.display.transition,
    PolychordProductDisplayTransition.pending,
  );
  expect(engine.latestObservation?.display.deadlineMs, 280);
  return engine;
}

PolychordOnsetTrackingFrame _frame(List<int> midiNotes, List<int?> timestamps) {
  final known =
      <({int midiNote, int timestampMs})>[
        for (var index = 0; index < midiNotes.length; index++)
          if (timestamps[index] != null)
            (midiNote: midiNotes[index], timestampMs: timestamps[index]!),
      ]..sort((left, right) {
        final time = left.timestampMs.compareTo(right.timestampMs);
        return time != 0 ? time : left.midiNote.compareTo(right.midiNote);
      });
  final eventIndexByNote = <int, int>{
    for (var index = 0; index < known.length; index++)
      known[index].midiNote: index,
  };
  final timestampMs = timestamps.whereType<int>().fold<int>(
    0,
    (maximum, value) => value > maximum ? value : maximum,
  );
  return PolychordOnsetTrackingFrame(
    trackerEpoch: 0,
    afterEventIndex: known.isEmpty ? 0 : known.length - 1,
    timestampMs: timestampMs,
    pedalDown: false,
    soundingNoteOnsets: [
      for (var index = 0; index < midiNotes.length; index++)
        PolychordSoundingNoteOnset(
          midiNote: midiNotes[index],
          soundingState: PolychordSoundingState.pressed,
          origin: timestamps[index] == null
              ? null
              : PolychordOnsetOrigin(
                  eventIndex: eventIndexByNote[midiNotes[index]]!,
                  timestampMs: timestamps[index]!,
                  velocity: 80,
                ),
        ),
    ],
  );
}

List<int> _rootPositionNotes(
  int rootPc,
  PolychordLayerQuality quality,
  int octaveBase,
) {
  final intervals = switch (quality) {
    PolychordLayerQuality.major => const [0, 4, 7],
    PolychordLayerQuality.minor => const [0, 3, 7],
    PolychordLayerQuality.dominant7 => const [0, 4, 7, 10],
    PolychordLayerQuality.major7 => const [0, 4, 7, 11],
    PolychordLayerQuality.minor7 => const [0, 3, 7, 10],
  };
  return [for (final interval in intervals) octaveBase + rootPc + interval];
}
