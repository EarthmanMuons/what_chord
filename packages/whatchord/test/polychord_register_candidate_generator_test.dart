import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const generator = PolychordRegisterCandidateGenerator();

  test('generates an exact disjoint triad candidate', () {
    final candidates = generator.generate([48, 52, 55, 66, 70, 73]);

    expect(candidates, hasLength(1));
    final candidate = candidates.single;
    expect(candidate.symbol, 'F#|C');
    expect(candidate.splitAfterIndex, 2);
    expect(candidate.lower.midiNotes, [48, 52, 55]);
    expect(candidate.upper.midiNotes, [66, 70, 73]);
    expect(candidate.lower.pitchClasses, [0, 4, 7]);
    expect(candidate.upper.pitchClasses, [1, 6, 10]);
    expect(candidate.gapSemitones, 11);
    expect(candidate.sharedPitchClasses, isEmpty);
  });

  test('preserves separate-note shared pitch classes', () {
    final candidates = generator.generate([43, 46, 50, 60, 64, 67]);

    expect(candidates.map((candidate) => candidate.symbol), ['C|Gm']);
    expect(candidates.single.sharedPitchClasses, [7]);
  });

  test('uses the symmetric five-quality vocabulary on both layers', () {
    final candidates = generator.generate([36, 40, 43, 59, 74, 78, 81]);

    expect(candidates.map((candidate) => candidate.symbol), [
      'Bm7|C',
      'D|Cmaj7',
    ]);
    expect(candidates.map((candidate) => candidate.splitAfterIndex), [2, 3]);
  });

  test('excludes same-root register groups and incomplete units', () {
    expect(generator.generate([36, 40, 43, 60, 64, 67]), isEmpty);
    expect(generator.generate([36, 52, 58, 62, 66, 69]), isEmpty);
  });

  test('requires strictly increasing in-range MIDI notes', () {
    expect(() => generator.generate([60, 59]), throwsArgumentError);
    expect(() => generator.generate([60, 60]), throwsArgumentError);
    expect(() => generator.generate([-1]), throwsRangeError);
    expect(() => generator.generate([128]), throwsRangeError);
  });

  test('serializes the frozen register-candidate field names', () {
    final json = generator.generate([48, 52, 55, 66, 70, 73]).single.toJson();

    expect(json.keys, {
      'splitAfterIndex',
      'lowerTopMidi',
      'upperBottomMidi',
      'gapSemitones',
      'lower',
      'upper',
      'sharedPitchClasses',
      'symbol',
    });
    expect((json['lower']! as Map).keys, {
      'rootPc',
      'quality',
      'midiNotes',
      'pitchClasses',
    });
  });

  test('matches the preregistered boundary scan exhaustively', () {
    for (var mask = 0; mask < 1 << 12; mask++) {
      final notes = [
        for (var offset = 0; offset < 12; offset++)
          if ((mask & (1 << offset)) != 0) 48 + offset,
      ];
      expect(
        generator.generate(notes),
        _referenceGenerate(notes),
        reason: 'chromatic-subset mask 0x${mask.toRadixString(16)}',
      );
    }

    for (final notes in [
      const [36, 48, 52, 55, 60, 64, 67],
      const [36, 40, 43, 48, 55, 59, 62, 67],
      const [0, 12, 24, 36, 48, 60, 72, 84, 96, 108, 120],
      [for (var note = 0; note < 128; note++) note],
    ]) {
      expect(generator.generate(notes), _referenceGenerate(notes));
    }
  });
}

List<PolychordCandidate> _referenceGenerate(List<int> midiNotes) {
  final candidates = <PolychordCandidate>[];
  for (
    var splitAfterIndex = 0;
    splitAfterIndex < midiNotes.length - 1;
    splitAfterIndex++
  ) {
    final lowerNotes = midiNotes.sublist(0, splitAfterIndex + 1);
    final upperNotes = midiNotes.sublist(splitAfterIndex + 1);
    final lowerMatches = _referenceMatches(lowerNotes);
    final upperMatches = _referenceMatches(upperNotes);
    for (final lowerIdentity in lowerMatches) {
      for (final upperIdentity in upperMatches) {
        if (lowerIdentity.rootPc == upperIdentity.rootPc) continue;
        final lower = _referenceLayer(lowerNotes, lowerIdentity);
        final upper = _referenceLayer(upperNotes, upperIdentity);
        final lowerPitchClasses = lower.pitchClasses.toSet();
        candidates.add(
          PolychordCandidate(
            splitAfterIndex: splitAfterIndex,
            lowerTopMidi: lowerNotes.last,
            upperBottomMidi: upperNotes.first,
            gapSemitones: upperNotes.first - lowerNotes.last,
            lower: lower,
            upper: upper,
            sharedPitchClasses: upper.pitchClasses.where(
              lowerPitchClasses.contains,
            ),
          ),
        );
      }
    }
  }
  candidates.sort(_compareReferenceCandidates);
  return candidates;
}

List<PolychordLayerIdentity> _referenceMatches(List<int> midiNotes) {
  final pitchClasses = midiNotes.map((note) => note % 12).toSet().toList()
    ..sort();
  final matches = <PolychordLayerIdentity>[];
  for (final rootPc in pitchClasses) {
    var relativeMask = 0;
    for (final pitchClass in pitchClasses) {
      relativeMask |= 1 << ((pitchClass - rootPc) % 12);
    }
    final quality = _referenceQualities[relativeMask];
    if (quality != null) {
      matches.add(PolychordLayerIdentity(rootPc: rootPc, quality: quality));
    }
  }
  matches.sort((left, right) {
    final root = left.rootPc.compareTo(right.rootPc);
    return root != 0 ? root : left.quality.index.compareTo(right.quality.index);
  });
  return matches;
}

PolychordLayerCandidate _referenceLayer(
  List<int> midiNotes,
  PolychordLayerIdentity identity,
) => PolychordLayerCandidate(
  identity: identity,
  midiNotes: midiNotes,
  pitchClasses: midiNotes.map((note) => note % 12).toSet().toList()..sort(),
);

int _compareReferenceCandidates(
  PolychordCandidate left,
  PolychordCandidate right,
) {
  final split = left.splitAfterIndex.compareTo(right.splitAfterIndex);
  if (split != 0) return split;
  final upperRoot = left.upper.identity.rootPc.compareTo(
    right.upper.identity.rootPc,
  );
  if (upperRoot != 0) return upperRoot;
  final upperQuality = left.upper.identity.quality.index.compareTo(
    right.upper.identity.quality.index,
  );
  if (upperQuality != 0) return upperQuality;
  final lowerRoot = left.lower.identity.rootPc.compareTo(
    right.lower.identity.rootPc,
  );
  if (lowerRoot != 0) return lowerRoot;
  return left.lower.identity.quality.index.compareTo(
    right.lower.identity.quality.index,
  );
}

const _referenceQualities = <int, PolychordLayerQuality>{
  0x091: PolychordLayerQuality.major,
  0x089: PolychordLayerQuality.minor,
  0x491: PolychordLayerQuality.dominant7,
  0x891: PolychordLayerQuality.major7,
  0x489: PolychordLayerQuality.minor7,
};
