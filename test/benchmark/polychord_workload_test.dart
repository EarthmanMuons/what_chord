import 'package:flutter_test/flutter_test.dart';
import 'package:whatchord/whatchord.dart';

import '../../benchmark/src/polychord_workload.dart';

void main() {
  test('projects a snapshot upward from its declared bass', () {
    final benchmarkCase = projectPolychordBenchmarkCase(
      'C/E',
      const ChordInput(
        pcMask: (1 << 0) | (1 << 4) | (1 << 7),
        bassPc: 4,
        noteCount: 3,
      ),
    );

    expect(benchmarkCase.midiNotes, [40, 43, 48]);
    expect(benchmarkCase.lowerCohortCount, 1);
    expect(benchmarkCase.prefixInputs.last, benchmarkCase.input);
    expect(benchmarkCase.noteOnEvents(100).map((event) => event.timestampMs), [
      100,
      180,
      180,
    ]);
  });

  test('structural controls exercise selected and ambiguous candidates', () {
    final finalObservations = <PolychordProductObservation>[];

    for (final control in structuralControlCases()) {
      final engine = PolychordProductEngine(initialPrimaryDisplayable: true);
      for (final event in control.noteOnEvents(0)) {
        engine.observeEvent(event);
      }
      finalObservations.add(engine.latestObservation!);
    }

    expect(finalObservations.first.display.key?.candidate.symbol, 'C|Gm');
    expect(finalObservations[2].candidates.length, greaterThan(1));
    expect(
      finalObservations[2].rawDecision?.reasonCode,
      'ambiguous-exact-assignment',
    );
    expect(
      finalObservations.last.rawDecision?.reasonCode,
      'integrated-tertian-reading',
    );
  });

  test('fails closed when a snapshot would require invented doubling', () {
    expect(
      () => projectPolychordBenchmarkCase(
        'doubled C',
        const ChordInput(pcMask: 1, bassPc: 0, noteCount: 2),
      ),
      throwsStateError,
    );
  });

  test('full-range storm covers every attack, release, and pedal boundary', () {
    final events = fullMidiRangeStorm(1000);
    expect(events, hasLength(258));
    for (var index = 1; index < events.length; index++) {
      expect(
        events[index].timestampMs,
        greaterThanOrEqualTo(events[index - 1].timestampMs),
      );
    }
    expect(events.take(128), everyElement(isA<PolychordNoteOnEvent>()));
    expect(events[128], isA<PolychordSustainPedalEvent>());
    expect(
      events.skip(129).take(128),
      everyElement(isA<PolychordNoteOffEvent>()),
    );
    expect(events.last, isA<PolychordSustainPedalEvent>());
  });

  test('positive storm exercises appearance, reattack, and clear', () {
    final engine = PolychordProductEngine(initialPrimaryDisplayable: true);
    final transitions = <PolychordProductDisplayTransition>[];

    for (final event in positiveReattackStorm(0)) {
      transitions.add(engine.observeEvent(event).display.transition);
    }

    expect(transitions, contains(PolychordProductDisplayTransition.appearance));
    expect(transitions, contains(PolychordProductDisplayTransition.clear));
    expect(engine.latestObservation?.frame?.soundingMidiNotes, isEmpty);
  });
}
