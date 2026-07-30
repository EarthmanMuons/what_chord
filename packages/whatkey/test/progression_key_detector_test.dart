import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

const _cMajorTonality = Tonality(Tonic.c, TonalityMode.major);

ChordEvent _event(
  int index,
  List<int> pcs,
  ChordQuality quality, {
  int? bassPc,
}) {
  var mask = 0;
  for (final pc in pcs) {
    mask |= 1 << (pc % 12);
  }
  final bass = bassPc ?? pcs.first % 12;
  return ChordEvent(
    timestamp: DateTime.fromMillisecondsSinceEpoch(index * 2000),
    input: ChordInput(pcMask: mask, bassPc: bass, noteCount: pcs.length),
    voicing: ObservedVoicing.fromMidi([for (final pc in pcs) 60 + pc]),
    candidates: [
      ChordCandidate(
        identity: ChordIdentity(
          rootPc: pcs.first % 12,
          bassPc: bass,
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

KeyEstimate _estimateFor(KeyEstimateFrame frame, int tonicPc, bool isMinor) =>
    frame.ranked.firstWhere(
      (e) =>
          e.tonality.tonicPitchClass == tonicPc &&
          e.tonality.isMinor == isMinor,
    );

void main() {
  test('a G7 to C cadence tops the ranking with C major', () {
    final frames = _run(ProgressionKeyDetector(minEvents: 2), [
      _event(0, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(1, [0, 4, 7], ChordQuality.major),
    ]);
    final top = frames.last.ranked.first;
    expect(top.tonality.tonicPitchClass, 0);
    expect(top.tonality.isMajor, isTrue);
  });

  test('ii-V-I completion scores above a bare V-I', () {
    final bare = _run(ProgressionKeyDetector(minEvents: 2), [
      _event(0, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(1, [0, 4, 7], ChordQuality.major),
    ]);
    final complete = _run(ProgressionKeyDetector(minEvents: 2), [
      _event(0, [2, 5, 9, 0], ChordQuality.minor7),
      _event(1, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(2, [0, 4, 7], ChordQuality.major),
    ]);
    final bareC = _estimateFor(bare.last, 0, false).confidence;
    final completeC = _estimateFor(complete.last, 0, false).confidence;
    expect(completeC, greaterThan(bareC));
  });

  test('blues: V7 to I7 reads as a cadence in the tonic major', () {
    // G7 -> C7: with dominant7 in the tonic quality set, this is V7 -> I7 in
    // C, not motion toward F.
    final frames = _run(ProgressionKeyDetector(minEvents: 2), [
      _event(0, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(1, [0, 4, 7, 10], ChordQuality.dominant7),
    ]);
    final top = frames.last.ranked.first;
    expect(top.tonality.tonicPitchClass, 0);
    expect(top.tonality.isMajor, isTrue);
  });

  test('E7 to Am cadence supports A minor', () {
    final frames = _run(ProgressionKeyDetector(minEvents: 2), [
      _event(0, [4, 8, 11, 2], ChordQuality.dominant7),
      _event(1, [9, 0, 4], ChordQuality.minor),
    ]);
    final top = frames.last.ranked.first;
    expect(top.tonality.tonicPitchClass, 9);
    expect(top.tonality.isMinor, isTrue);
  });

  test('repeated identical chords accumulate no transition evidence', () {
    final frames = _run(ProgressionKeyDetector(minEvents: 1), [
      for (var i = 0; i < 4; i++)
        _event(i, [0, 4, 7, 10], ChordQuality.dominant7),
    ]);
    expect(frames.every((frame) => frame.isAbstention), isTrue);
  });

  test('hybrid with progression blend claims C on the blues loop', () {
    // I7 I7 IV7 I7 V7 IV7 I7 V7, roughly the 12-bar skeleton.
    final blues = [
      _event(0, [0, 4, 7, 10], ChordQuality.dominant7),
      _event(1, [0, 4, 7, 10], ChordQuality.dominant7),
      _event(2, [5, 9, 0, 3], ChordQuality.dominant7),
      _event(3, [0, 4, 7, 10], ChordQuality.dominant7),
      _event(4, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(5, [5, 9, 0, 3], ChordQuality.dominant7),
      _event(6, [0, 4, 7, 10], ChordQuality.dominant7),
      _event(7, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(8, [0, 4, 7, 10], ChordQuality.dominant7),
    ];
    final without = _run(
      HybridKeyDetector(functionalBlend: 0.1, progressionBlend: 0),
      blues,
    );
    final with_ = _run(
      HybridKeyDetector(functionalBlend: 0.1, progressionBlend: 0.1),
      blues,
    );

    final withoutClaim = without.last.claim;
    final withClaim = with_.last.claim;
    expect(withClaim, isNotNull);
    expect(withClaim!.tonality.tonicPitchClass, 0);
    expect(withClaim.tonality.isMajor, isTrue);
    // The progression term is what makes the difference: without it the
    // hybrid reads the loop as F (the V-of-F pull from entry 04).
    expect(
      withoutClaim == null || withoutClaim.tonality.tonicPitchClass != 0,
      isTrue,
    );
  });

  test('explicit progression blend of zero is deterministic across runs', () {
    final cadence = [
      _event(0, [0, 4, 7], ChordQuality.major),
      _event(1, [5, 9, 0], ChordQuality.major),
      _event(2, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(3, [0, 4, 7], ChordQuality.major),
    ];
    final base = _run(
      HybridKeyDetector(functionalBlend: 0.1, progressionBlend: 0),
      cadence,
    );
    final zero = _run(
      HybridKeyDetector(functionalBlend: 0.1, progressionBlend: 0),
      cadence,
    );
    for (var i = 0; i < cadence.length; i++) {
      expect(zero[i].ranked.length, base[i].ranked.length);
      for (var k = 0; k < base[i].ranked.length; k++) {
        expect(zero[i].ranked[k].tonality, base[i].ranked[k].tonality);
        expect(
          zero[i].ranked[k].confidence,
          closeTo(base[i].ranked[k].confidence, 1e-12),
        );
      }
    }
  });
}
