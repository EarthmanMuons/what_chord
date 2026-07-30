import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

const _cMajorTonality = Tonality(Tonic.c, TonalityMode.major);

ChordEvent _event(int index, List<int> pcs, ChordQuality quality) {
  var mask = 0;
  for (final pc in pcs) {
    mask |= 1 << (pc % 12);
  }
  return ChordEvent(
    timestamp: DateTime.fromMillisecondsSinceEpoch(index * 2000),
    input: ChordInput(
      pcMask: mask,
      bassPc: pcs.first % 12,
      noteCount: pcs.length,
    ),
    voicing: ObservedVoicing.fromMidi([for (final pc in pcs) 60 + pc]),
    candidates: [
      ChordCandidate(
        identity: ChordIdentity(
          rootPc: pcs.first % 12,
          bassPc: pcs.first % 12,
          quality: quality,
          presentIntervalsMask: 1,
        ),
        cost: 0,
      ),
    ],
    tonality: _cMajorTonality,
    duration: const Duration(seconds: 2),
  );
}

List<KeyEstimateFrame> _run(KeyDetector detector, List<ChordEvent> events) {
  detector.reset();
  return [for (final event in events) detector.onEvent(event)];
}

void main() {
  final cCadence = [
    _event(0, [0, 4, 7], ChordQuality.major),
    _event(1, [5, 9, 0], ChordQuality.major),
    _event(2, [7, 11, 2, 5], ChordQuality.dominant7),
    _event(3, [0, 4, 7], ChordQuality.major),
  ];

  test('claims C major for a C major cadence', () {
    final frames = _run(HybridKeyDetector.researchBaseline(), cCadence);
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 0);
    expect(claim.tonality.isMajor, isTrue);
  });

  test('shipped hybrid defaults rank identically to profile scoring', () {
    final hybridFrames = _run(HybridKeyDetector(), cCadence);
    final profileFrames = _run(ProfileCorrelationKeyDetector(), cCadence);
    for (var i = 0; i < cCadence.length; i++) {
      final hybrid = hybridFrames[i].ranked;
      final profile = profileFrames[i].ranked;
      expect(hybrid.length, profile.length);
      for (var k = 0; k < hybrid.length; k++) {
        expect(hybrid[k].tonality, profile[k].tonality);
        expect(hybrid[k].confidence, closeTo(profile[k].confidence, 1e-9));
      }
    }
  });

  test('hybrid defaults stay aligned with the shipped HMM emissions', () {
    expect(
      HybridKeyDetector.defaultFunctionalBlend,
      HmmKeyDetector.defaultEmissionFunctionalBlend,
    );
    expect(
      HybridKeyDetector.defaultProgressionBlend,
      HmmKeyDetector.defaultEmissionProgressionBlend,
    );
    expect(
      HybridKeyDetector.defaultConfidenceWeighted,
      HmmKeyDetector.defaultEmissionConfidenceWeighted,
    );
    final configuration = HybridKeyDetector().configuration;
    expect(configuration, contains('evidence: disabled'));
    expect(configuration, contains('progression: disabled'));
  });

  test('named research baseline preserves the historical configuration', () {
    final configuration = HybridKeyDetector.researchBaseline().configuration;

    expect(
      configuration,
      contains('functionalBlend=0.1 progressionBlend=0.02'),
    );
    expect(configuration, contains('minEvents=3 marginFloor=0.05'));
    expect(configuration, contains('evidence: points='));
    expect(configuration, contains('confidenceWeighted=true'));
    expect(configuration, isNot(contains('evidence: disabled')));
    expect(configuration, isNot(contains('progression: disabled')));
  });

  test('claims A minor for a harmonic-minor cadence with E7', () {
    final frames = _run(HybridKeyDetector.researchBaseline(), [
      _event(0, [9, 0, 4], ChordQuality.minor),
      _event(1, [2, 5, 9], ChordQuality.minor),
      _event(2, [4, 8, 11, 2], ChordQuality.dominant7),
      _event(3, [9, 0, 4], ChordQuality.minor),
    ]);
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 9);
    expect(claim.tonality.isMinor, isTrue);
  });

  test('claims C major on the diatonic pop loop where evidence alone ties', () {
    final frames = _run(HybridKeyDetector.researchBaseline(), [
      for (var repeat = 0; repeat < 2; repeat++) ...[
        _event(repeat * 4, [0, 4, 7], ChordQuality.major),
        _event(repeat * 4 + 1, [7, 11, 2], ChordQuality.major),
        _event(repeat * 4 + 2, [9, 0, 4], ChordQuality.minor),
        _event(repeat * 4 + 3, [5, 9, 0], ChordQuality.major),
      ],
    ]);
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 0);
    expect(claim.tonality.isMajor, isTrue);
  });

  test('ranked list covers all 24 keys exactly once', () {
    final frames = _run(HybridKeyDetector.researchBaseline(), cCadence);
    final ranked = frames.last.ranked;
    expect(ranked, hasLength(24));
    final distinct = {
      for (final estimate in ranked)
        estimate.tonality.tonicPitchClass * 2 +
            (estimate.tonality.isMinor ? 1 : 0),
    };
    expect(distinct, hasLength(24));
  });
}
