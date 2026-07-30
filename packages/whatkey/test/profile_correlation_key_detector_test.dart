import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

const _cMajorTonality = Tonality(Tonic.c, TonalityMode.major);

ChordEvent _event(int index, List<int> pcs) {
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
          quality: ChordQuality.major,
          presentIntervalsMask: 1,
        ),
        cost: 0,
      ),
    ],
    tonality: _cMajorTonality,
    duration: const Duration(seconds: 2),
  );
}

// Triads/sevenths as pitch-class lists, bass first.
const _c = [0, 4, 7];
const _f = [5, 9, 0];
const _g7 = [7, 11, 2, 5];
const _am = [9, 0, 4];
const _dm = [2, 5, 9];
const _e7 = [4, 8, 11, 2];
const _gMajor = [7, 11, 2];
const _d7 = [2, 6, 9, 0];

List<KeyEstimateFrame> _run(
  ProfileCorrelationKeyDetector detector,
  List<List<int>> chords,
) {
  detector.reset();
  return [
    for (var i = 0; i < chords.length; i++)
      detector.onEvent(_event(i, chords[i])),
  ];
}

void main() {
  test('abstains until minEvents have arrived', () {
    final frames = _run(ProfileCorrelationKeyDetector.researchBaseline(), [
      _c,
      _f,
      _g7,
      _c,
    ]);
    expect(frames[0].isAbstention, isTrue);
    expect(frames[1].isAbstention, isTrue);
    expect(frames[2].isAbstention, isFalse);
  });

  test('claims C major for a C major cadence under every profile pair', () {
    for (final profiles in KeyProfilePair.values) {
      final frames = _run(
        ProfileCorrelationKeyDetector.researchBaseline(profiles: profiles),
        [_c, _f, _g7, _c],
      );
      final claim = frames.last.claim;
      expect(claim, isNotNull, reason: profiles.name);
      expect(claim!.tonality.tonicPitchClass, 0, reason: profiles.name);
      expect(claim.tonality.isMajor, isTrue, reason: profiles.name);
    }
  });

  test('claims A minor for a harmonic-minor cadence with E7', () {
    final frames = _run(ProfileCorrelationKeyDetector.researchBaseline(), [
      _am,
      _dm,
      _e7,
      _am,
    ]);
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 9);
    expect(claim.tonality.isMinor, isTrue);
  });

  test('decay lets the claim follow a modulation to the dominant', () {
    final chords = [
      _c,
      _f,
      _g7,
      _c,
      for (var i = 0; i < 6; i++) ...[_d7, _gMajor],
    ];
    final frames = _run(
      ProfileCorrelationKeyDetector.researchBaseline(),
      chords,
    );
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 7);
    expect(claim.tonality.isMajor, isTrue);
  });

  test('an unreachable margin floor abstains forever', () {
    final detector = ProfileCorrelationKeyDetector.researchBaseline(
      marginFloor: 10,
    );
    final frames = _run(detector, [_c, _f, _g7, _c]);
    expect(frames.every((frame) => frame.isAbstention), isTrue);
    // The ranked list is still produced for diagnostics.
    expect(frames.last.ranked, isNotEmpty);
  });

  test('ranked list covers all 24 keys exactly once', () {
    final frames = _run(ProfileCorrelationKeyDetector.researchBaseline(), [
      _c,
      _f,
      _g7,
    ]);
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
