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
}
