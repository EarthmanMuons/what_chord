import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const evidenceAnalyzer = PolychordOnsetEvidenceAnalyzer();
  const interpreter = PolychordCoherentSeparatedOnsetInterpreter();

  test('publishes the fixed named parameters', () {
    expect(
      PolychordCoherentSeparatedOnsetInterpreter.ablationId,
      'coherent-separated-onsets-50-200ms/1',
    );
    expect(PolychordCoherentSeparatedOnsetInterpreter.parameters, {
      'withinLayerCohortSpanMaximumMs': 50,
      'betweenLayerSeparationMinimumMs': 200,
    });
  });

  test('gives coherent separated cohorts one-sided positive support', () {
    final evidence = evidenceAnalyzer
        .analyzeFrame(
          _observations(lower: const [0, 0, 0], upper: const [400, 400, 400]),
        )
        .single;

    final result = interpreter.interpret(evidence);

    expect(result.availability, PolychordOnsetSupportAvailability.complete);
    expect(result.lowerWithinCohortSpanMaximum, isTrue);
    expect(result.upperWithinCohortSpanMaximum, isTrue);
    expect(result.layerOnsetOrder, PolychordLayerOnsetOrder.lowerThenUpper);
    expect(result.betweenLayerOnsetIntervalGapMs, 400);
    expect(result.onsetCohortSupport, PolychordOnsetCohortSupport.positive);
    expect(result.reasonCodes, ['separate-coherent-onset-cohorts']);
  });

  test('treats layer order symmetrically', () {
    final result = interpreter.interpret(
      evidenceAnalyzer
          .analyzeFrame(
            _observations(
              lower: const [300, 320, 340],
              upper: const [0, 25, 50],
            ),
          )
          .single,
    );

    expect(result.layerOnsetOrder, PolychordLayerOnsetOrder.upperThenLower);
    expect(result.betweenLayerOnsetIntervalGapMs, 250);
    expect(result.onsetCohortSupport, PolychordOnsetCohortSupport.positive);
  });

  test('freezes inclusive and just-outside timing boundaries', () {
    final cases = [
      (
        lower: const [0, 25, 50],
        upper: const [250, 275, 300],
        support: PolychordOnsetCohortSupport.positive,
        reasons: const ['separate-coherent-onset-cohorts'],
      ),
      (
        lower: const [0, 25, 50],
        upper: const [249, 274, 299],
        support: PolychordOnsetCohortSupport.neutral,
        reasons: const ['between-layer-separation-below-minimum'],
      ),
      (
        lower: const [0, 25, 51],
        upper: const [251, 275, 300],
        support: PolychordOnsetCohortSupport.neutral,
        reasons: const ['lower-span-exceeds-maximum'],
      ),
      (
        lower: const [0, 25, 50],
        upper: const [250, 275, 301],
        support: PolychordOnsetCohortSupport.neutral,
        reasons: const ['upper-span-exceeds-maximum'],
      ),
    ];

    for (final item in cases) {
      final result = interpreter.interpret(
        evidenceAnalyzer
            .analyzeFrame(_observations(lower: item.lower, upper: item.upper))
            .single,
      );

      expect(result.onsetCohortSupport, item.support);
      expect(result.reasonCodes, item.reasons);
    }
  });

  test('keeps overlapping cohorts neutral', () {
    final result = interpreter.interpret(
      evidenceAnalyzer
          .analyzeFrame(
            _observations(lower: const [0, 0, 0], upper: const [0, 0, 0]),
          )
          .single,
    );

    expect(result.layerOnsetOrder, PolychordLayerOnsetOrder.overlapping);
    expect(result.betweenLayerOnsetIntervalGapMs, 0);
    expect(result.onsetCohortSupport, PolychordOnsetCohortSupport.neutral);
    expect(result.reasonCodes, ['between-layer-separation-below-minimum']);
  });

  test('does not partially interpret incomplete onset history', () {
    final observations = _observations(
      lower: const [0, 0, 0],
      upper: const [400, 400, 400],
    );
    observations[0] = PolychordSoundingNoteOnset(
      midiNote: observations[0].midiNote,
      soundingState: PolychordSoundingState.sustained,
    );

    final result = interpreter.interpret(
      evidenceAnalyzer.analyzeFrame(observations).single,
    );

    expect(result.toInterpretationJson(), {
      'availability': 'incomplete',
      'lowerWithinCohortSpanMaximum': null,
      'upperWithinCohortSpanMaximum': null,
      'layerOnsetOrder': null,
      'betweenLayerOnsetIntervalGapMs': null,
      'onsetCohortSupport': 'neutral',
      'reasonCodes': ['onset-history-incomplete'],
    });
  });

  test('returns all candidate interpretations without a selection', () {
    final evidence = evidenceAnalyzer.analyzeFrame(
      _observationsForNotes([36, 40, 43, 59, 74, 78, 81]),
    );

    final results = interpreter.interpretAll(evidence);

    expect(results.map((result) => result.evidence.candidate.symbol), [
      'Bm7|C',
      'D|Cmaj7',
    ]);
    expect(results, hasLength(evidence.length));
  });
}

List<PolychordSoundingNoteOnset> _observations({
  required List<int> lower,
  required List<int> upper,
}) {
  final timestamps = [...lower, ...upper];
  final sortedIndices = List.generate(6, (index) => index)
    ..sort((left, right) {
      final timestampComparison = timestamps[left].compareTo(timestamps[right]);
      return timestampComparison != 0
          ? timestampComparison
          : left.compareTo(right);
    });
  final eventIndexByNoteIndex = <int, int>{
    for (var eventIndex = 0; eventIndex < sortedIndices.length; eventIndex++)
      sortedIndices[eventIndex]: eventIndex,
  };
  return [
    for (var index = 0; index < 6; index++)
      PolychordSoundingNoteOnset(
        midiNote: const [43, 46, 50, 60, 64, 67][index],
        soundingState: PolychordSoundingState.pressed,
        origin: PolychordOnsetOrigin(
          eventIndex: eventIndexByNoteIndex[index]!,
          timestampMs: timestamps[index],
          velocity: 80,
        ),
      ),
  ];
}

List<PolychordSoundingNoteOnset> _observationsForNotes(List<int> midiNotes) => [
  for (var index = 0; index < midiNotes.length; index++)
    PolychordSoundingNoteOnset(
      midiNote: midiNotes[index],
      soundingState: PolychordSoundingState.pressed,
      origin: PolychordOnsetOrigin(
        eventIndex: index,
        timestampMs: 0,
        velocity: 80,
      ),
    ),
];
