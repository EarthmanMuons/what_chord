import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

import 'package:whatchord/testing.dart';

final _analyzer = ChordAnalyzer();

const _cMajor = Tonality(Tonic.c, TonalityMode.major);
const _bFlatMajor = Tonality(Tonic.bFlat, TonalityMode.major);

AnalysisContext _ensemble(Tonality tonality) => makeAnalysisContext(
  tonality: tonality,
  playingContext: PlayingContext.ensemble,
);

void main() {
  test('solo analysis never produces implied-root candidates', () {
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['F', 'A', 'C', 'E']),
      context: makeAnalysisContext(tonality: _cMajor),
      take: 12,
    );

    expect(results, isNotEmpty);
    expect(results.any((c) => c.identity.hasImpliedRoot), isFalse);
    expect(results.first.identity.rootPc, 5);
    expect(results.first.identity.quality, ChordQuality.major7);
  });

  test('ensemble names the rootless A-form ii voicing (Dm9)', () {
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['F', 'A', 'C', 'E']),
      context: _ensemble(_cMajor),
    );

    final top = results.first.identity;
    expect(top.hasImpliedRoot, isTrue);
    expect(top.rootPc, 2);
    expect(top.quality, ChordQuality.minor7);
    expect(top.extensions, {ChordExtension.nine});
  });

  test(
    'ensemble prefers the rootless reading over its complete rooted twin',
    () {
      final input = chordInputFromNames(names: ['Eb', 'G', 'Bb', 'D']);

      final soloTop = _analyzer
          .analyze(input, context: makeAnalysisContext(tonality: _bFlatMajor))
          .first
          .identity;
      expect(soloTop.rootPc, 3);
      expect(soloTop.quality, ChordQuality.major7);

      final ensembleTop = _analyzer
          .analyze(input, context: _ensemble(_bFlatMajor))
          .first
          .identity;
      expect(ensembleTop.hasImpliedRoot, isTrue);
      expect(ensembleTop.rootPc, 0);
      expect(ensembleTop.quality, ChordQuality.minor7);
      expect(ensembleTop.extensions, {ChordExtension.nine});
    },
  );

  test('ensemble names the worked C13 example', () {
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['E', 'Bb', 'D', 'A']),
      context: _ensemble(_cMajor),
    );

    final top = results.first.identity;
    expect(top.hasImpliedRoot, isTrue);
    expect(top.rootPc, 0);
    expect(top.quality, ChordQuality.dominant7);
    expect(top.extensions, {ChordExtension.nine, ChordExtension.thirteen});
  });

  test('a three-note shell with no fifth still reads rootless (Dm9 shell)', () {
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['F', 'C', 'E']),
      context: _ensemble(_cMajor),
    );

    final top = results.first.identity;
    expect(top.hasImpliedRoot, isTrue);
    expect(top.rootPc, 2);
    expect(top.quality, ChordQuality.minor7);
    expect(top.extensions, {ChordExtension.nine});
  });

  test('implied roots are restricted to the diatonic pitch classes', () {
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['E', 'Bb', 'D', 'A']),
      context: _ensemble(_cMajor),
      take: 12,
    );

    final implied = results.where((c) => c.identity.hasImpliedRoot);
    expect(implied, isNotEmpty);
    for (final candidate in implied) {
      expect(_cMajor.containsPitchClass(candidate.identity.rootPc), isTrue);
    }
  });

  test('an off-idiom ghost reading does not displace a complete chord', () {
    // C7 admits an Am7(b9) ghost (Bb as a flat nine on a minor host); the
    // altered color on a non-dominant host is off-idiom, so C7 keeps the top.
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['C', 'E', 'G', 'Bb']),
      context: _ensemble(_cMajor),
    );

    final top = results.first.identity;
    expect(top.hasImpliedRoot, isFalse);
    expect(top.rootPc, 0);
    expect(top.quality, ChordQuality.dominant7);
  });

  test('the rooted twin surfaces among the ranked candidates', () {
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['Eb', 'G', 'Bb', 'D']),
      context: _ensemble(_bFlatMajor),
    );

    expect(
      results.any(
        (c) =>
            !c.identity.hasImpliedRoot &&
            c.identity.rootPc == 3 &&
            c.identity.quality == ChordQuality.major7,
      ),
      isTrue,
    );
  });

  test('symmetric diminished sevenths are never hypothesized rootless', () {
    // E-G-Bb is a rootless C#dim7 in D major, but dim7 ghost roots are
    // excluded; any implied reading here must be another quality.
    final results = _analyzer.analyze(
      chordInputFromNames(names: ['E', 'G', 'Bb']),
      context: _ensemble(const Tonality(Tonic.d, TonalityMode.major)),
      take: 12,
    );

    for (final candidate in results) {
      if (candidate.identity.hasImpliedRoot) {
        expect(candidate.identity.quality, isNot(ChordQuality.diminished7));
      }
    }
  });

  test('explain reports the implied root as a missing-root cost', () {
    final explained = _analyzer.explain(
      chordInputFromNames(names: ['F', 'A', 'C', 'E']),
      context: _ensemble(_cMajor),
    );

    final top = explained.first;
    expect(top.candidate.identity.hasImpliedRoot, isTrue);
    final reason = top.costReasons.firstWhere(
      (r) => r.label == CostReasonLabel.missingRoot,
    );
    expect(reason.count, 1);
    expect(reason.intervals, 0x1);
  });
}
