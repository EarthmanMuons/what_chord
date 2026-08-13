import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const analyzer = PolychordFrameTransitionEvidenceAnalyzer();
  const motion = PolychordRigidLayerMotionInterpreter();

  group('frame-transition evidence', () {
    test('preserves the complete inner-motion window and continuity', () {
      final trace = _trace(_innerMotionEvents());
      final evidence = analyzer.analyze(window: trace.window(5, 9));
      final transition = evidence.candidateTransitions.single;
      final json = transition.toJson();
      final continuity = json['instanceContinuity']! as Map<String, Object>;
      final window = evidence.window.toJson();

      expect(evidence.sourceCandidates.single.symbol, 'C|Gm');
      expect(evidence.targetCandidates.single.symbol, 'Cm|G');
      expect(window['elapsedMs'], 200);
      expect(window['transitionEventCount'], 4);
      expect(window['interveningFrameCount'], 3);
      expect(
        (window['transitionSteps']! as List).cast<Map<String, Object>>().map(
          (step) => (step['event']! as Map)['index'],
        ),
        [6, 7, 8, 9],
      );
      expect(
        (continuity['retainedInstances']! as List)
            .cast<Map<String, Object?>>()
            .map((note) => note['midiNote']),
        [43, 50, 60, 67],
      );
      expect(
        (continuity['departedInstances']! as List)
            .cast<Map<String, Object?>>()
            .map((note) => note['midiNote']),
        [46, 64],
      );
      expect(
        (continuity['arrivedInstances']! as List)
            .cast<Map<String, Object?>>()
            .map((note) => note['midiNote']),
        [47, 63],
      );
      expect(
        transition.layerRelations
            .firstWhere(
              (relation) =>
                  relation.kind == PolychordLayerRelationKind.lowerToLower,
            )
            .allPairTargetMinusSourceSemitones,
        [
          [0, 4, 7],
          [-3, 1, 4],
          [-7, -3, 0],
        ],
      );
      expect(
        transition.layerCorrespondenceHypotheses.map(
          (hypothesis) => (
            hypothesis.kind,
            hypothesis.retainedInstancesFollowingRelations.length,
            hypothesis.retainedInstancesOutsideRelations.length,
          ),
        ),
        [
          (PolychordLayerCorrespondenceKind.registerRolePreserving, 4, 0),
          (PolychordLayerCorrespondenceKind.registerRoleExchanging, 0, 4),
        ],
      );
    });

    test('accepts zero elapsed time but rejects incomplete windows', () {
      final trace = _trace(_innerMotionEvents());

      final evidence = analyzer.analyze(window: trace.window(0, 1));

      expect(evidence.elapsedMs, 0);
      expect(evidence.window.transitionEventCount, 1);
      expect(evidence.candidateTransitions, isEmpty);
      expect(
        () => PolychordFrameTransitionWindow(
          sourceFrame: trace.frames[5],
          transitionSteps: [trace.steps[7]],
        ),
        throwsArgumentError,
      );
    });

    test('rejects an event paired with a different same-time frame', () {
      final trace = _trace(_innerMotionEvents());
      final mismatchedStep = PolychordFrameTransitionStep(
        event: _on(0, 47),
        frame: trace.frames[1],
      );

      expect(
        () => PolychordFrameTransitionWindow(
          sourceFrame: trace.frames[0],
          transitionSteps: [mismatchedStep],
        ),
        throwsArgumentError,
      );
    });

    test('treats a same-note reattack as departure and arrival', () {
      final trace = _trace(_pedalHistoryEvents());
      final transition = analyzer
          .analyze(window: trace.window(12, 14))
          .candidateTransitions
          .single;
      final continuity = transition.instanceContinuity;

      expect(continuity.retainedInstances, hasLength(5));
      expect(
        continuity.departedInstances.map(
          (item) => (item.identity.midiNote, item.identity.onsetEventIndex),
        ),
        [(43, 0)],
      );
      expect(
        continuity.arrivedInstances.map(
          (item) => (item.identity.midiNote, item.identity.onsetEventIndex),
        ),
        [(43, 13)],
      );
    });
  });

  group('rigid-layer motion interpretation', () {
    test('gives contrary exact translations one-sided positive support', () {
      final trace = _trace(_contraryMotionEvents());
      final evidence = analyzer.analyze(window: trace.window(5, 17));
      final preserving = motion
          .interpret(evidence)
          .single
          .hypothesisInterpretations
          .firstWhere(
            (item) =>
                item.hypothesis.kind ==
                PolychordLayerCorrespondenceKind.registerRolePreserving,
          );

      expect(evidence.sourceCandidates.single.symbol, 'C|Gm');
      expect(evidence.targetCandidates.single.symbol, 'D|Fm');
      expect(
        preserving.retainedInstanceEvidence,
        PolychordRetainedInstanceEvidence.none,
      );
      expect(
        preserving.layerTranslations.map(
          (translation) => translation.translationSemitones,
        ),
        [-2, 2],
      );
      expect(
        preserving.betweenLayerMotionClass,
        PolychordBetweenLayerMotionClass.contrary,
      );
      expect(preserving.motionSupport, PolychordMotionSupport.positive);
      expect(preserving.reasonCodes, ['rigid-layer-translations-contrary']);
    });

    test('keeps conflicting retained instances neutral', () {
      final trace = _trace(_innerMotionEvents());
      final evidence = analyzer.analyze(window: trace.window(5, 9));
      final interpretations = motion
          .interpret(evidence)
          .single
          .hypothesisInterpretations;
      final preserving = interpretations.first;
      final exchanging = interpretations.last;

      expect(preserving.bothLayersExactTranslations, isFalse);
      expect(preserving.betweenLayerMotionClass, isNull);
      expect(preserving.motionSupport, PolychordMotionSupport.neutral);
      expect(preserving.reasonCodes, [
        'lower-to-lower-not-exact-midi-set-translation',
        'upper-to-upper-not-exact-midi-set-translation',
      ]);
      expect(exchanging.bothLayersExactTranslations, isTrue);
      expect(
        exchanging.betweenLayerMotionClass,
        PolychordBetweenLayerMotionClass.contrary,
      );
      expect(
        exchanging.retainedInstanceEvidence,
        PolychordRetainedInstanceEvidence.contradictory,
      );
      expect(exchanging.motionSupport, PolychordMotionSupport.neutral);
      expect(exchanging.reasonCodes, [
        'retained-instance-contradicts-correspondence',
      ]);
    });

    test('freezes every exact between-layer motion class', () {
      final cases =
          <
            ({
              List<int> target,
              PolychordBetweenLayerMotionClass motionClass,
              PolychordMotionSupport support,
              String reason,
            })
          >[
            (
              target: [43, 46, 50, 60, 64, 67],
              motionClass: PolychordBetweenLayerMotionClass.static,
              support: PolychordMotionSupport.neutral,
              reason: 'both-layer-translations-static',
            ),
            (
              target: [45, 48, 52, 62, 66, 69],
              motionClass: PolychordBetweenLayerMotionClass.commonTranslation,
              support: PolychordMotionSupport.neutral,
              reason: 'whole-sonority-common-translation',
            ),
            (
              target: [43, 46, 50, 62, 66, 69],
              motionClass: PolychordBetweenLayerMotionClass.oblique,
              support: PolychordMotionSupport.positive,
              reason: 'rigid-layer-translations-oblique',
            ),
            (
              target: [41, 44, 48, 62, 66, 69],
              motionClass: PolychordBetweenLayerMotionClass.contrary,
              support: PolychordMotionSupport.positive,
              reason: 'rigid-layer-translations-contrary',
            ),
            (
              target: [44, 47, 51, 62, 66, 69],
              motionClass:
                  PolychordBetweenLayerMotionClass.unequalSimilarDirection,
              support: PolychordMotionSupport.neutral,
              reason: 'layer-translations-unequal-similar-direction',
            ),
          ];

      for (final item in cases) {
        final preserving = _interpretMotion(item.target);

        expect(
          preserving.betweenLayerMotionClass,
          item.motionClass,
          reason: item.motionClass.name,
        );
        expect(
          preserving.motionSupport,
          item.support,
          reason: item.motionClass.name,
        );
        expect(preserving.reasonCodes, [
          item.reason,
        ], reason: item.motionClass.name);
      }
    });

    test('publishes fixed threshold-free interpretation parameters', () {
      expect(
        PolychordRigidLayerMotionInterpreter.ablationId,
        'rigid-layers-oblique-or-contrary/1',
      );
      expect(PolychordRigidLayerMotionInterpreter.parameters, {
        'withinLayerTransform': 'exact-midi-set-translation',
        'betweenLayerSupportClasses': ['oblique', 'contrary'],
        'retainedInstanceContradictionPolicy': 'neutral',
        'nonRigidOrCardinalityChangePolicy': 'neutral',
      });
    });
  });
}

PolychordMotionHypothesisInterpretation _interpretMotion(List<int> target) {
  const source = [43, 46, 50, 60, 64, 67];
  final events = <PolychordTemporalEvent>[
    for (final note in source) _on(0, note),
    for (final note in source)
      if (!target.contains(note)) _off(100, note),
    for (final note in target)
      if (!source.contains(note)) _on(100, note),
    if (source.every(target.contains))
      PolychordSustainPedalEvent(timestampMs: 100, down: true),
  ];
  final trace = _trace(events);
  final evidence = const PolychordFrameTransitionEvidenceAnalyzer().analyze(
    window: trace.window(5, trace.frames.length - 1),
  );
  return const PolychordRigidLayerMotionInterpreter()
      .interpret(evidence)
      .single
      .hypothesisInterpretations
      .firstWhere(
        (item) =>
            item.hypothesis.kind ==
            PolychordLayerCorrespondenceKind.registerRolePreserving,
      );
}

_Trace _trace(List<PolychordTemporalEvent> events) {
  final tracker = PolychordReleasePedalTracker();
  final frames = <PolychordReleasePedalTrackingFrame>[];
  final steps = <PolychordFrameTransitionStep>[];
  for (final event in events) {
    final frame = tracker.step(event);
    frames.add(frame);
    steps.add(PolychordFrameTransitionStep(event: event, frame: frame));
  }
  return _Trace(frames: frames, steps: steps);
}

final class _Trace {
  const _Trace({required this.frames, required this.steps});

  final List<PolychordReleasePedalTrackingFrame> frames;
  final List<PolychordFrameTransitionStep> steps;

  PolychordFrameTransitionWindow window(int source, int target) =>
      PolychordFrameTransitionWindow(
        sourceFrame: frames[source],
        transitionSteps: steps.sublist(source + 1, target + 1),
      );
}

List<PolychordTemporalEvent> _innerMotionEvents() => [
  for (final note in const [43, 46, 50, 60, 64, 67]) _on(0, note),
  _off(100, 46),
  _off(100, 64),
  _on(200, 47),
  _on(200, 63),
];

List<PolychordTemporalEvent> _contraryMotionEvents() => [
  for (final note in const [43, 46, 50, 60, 64, 67]) _on(0, note),
  for (final note in const [43, 46, 50, 60, 64, 67]) _off(100, note),
  for (final note in const [41, 44, 48, 62, 66, 69]) _on(100, note),
];

List<PolychordTemporalEvent> _pedalHistoryEvents() => [
  for (final note in const [43, 46, 50]) _on(0, note, velocity: 80),
  for (final note in const [60, 64, 67]) _on(100, note, velocity: 80),
  PolychordSustainPedalEvent(timestampMs: 200, down: true),
  _off(300, 43, velocity: 1),
  _off(300, 46, velocity: 2),
  _off(300, 50, velocity: 3),
  _off(400, 60, velocity: 4),
  _off(400, 64, velocity: 5),
  _off(400, 67, velocity: 6),
  _on(500, 43, velocity: 72),
  _off(600, 43, velocity: 7),
  PolychordSustainPedalEvent(timestampMs: 700, down: false),
];

PolychordNoteOnEvent _on(int timestampMs, int midiNote, {int velocity = 96}) =>
    PolychordNoteOnEvent(
      timestampMs: timestampMs,
      midiNote: midiNote,
      velocity: velocity,
    );

PolychordNoteOffEvent _off(int timestampMs, int midiNote, {int velocity = 0}) =>
    PolychordNoteOffEvent(
      timestampMs: timestampMs,
      midiNote: midiNote,
      velocity: velocity,
    );
