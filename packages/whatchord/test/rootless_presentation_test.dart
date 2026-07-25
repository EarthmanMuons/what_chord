import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

import 'package:whatchord/testing.dart';

final _analyzer = ChordAnalyzer();

const _bFlatMajor = Tonality(Tonic.bFlat, TonalityMode.major);

ChordIdentity _rootlessCm9() {
  final top = _analyzer
      .analyze(
        chordInputFromNames(names: ['Eb', 'G', 'Bb', 'D']),
        context: makeAnalysisContext(
          tonality: _bFlatMajor,
          playingContext: PlayingContext.ensemble,
        ),
      )
      .first
      .identity;
  assert(top.hasImpliedRoot);
  return top;
}

void main() {
  test('a rootless identity renders a plain symbol, never a slash', () {
    final symbol = ChordSymbolBuilder.fromIdentity(
      identity: _rootlessCm9(),
      tonality: _bFlatMajor,
      notation: ChordNotationStyle.textual,
    );

    expect(symbol.root, 'C');
    expect(symbol.bass, isNull);
    expect(symbol.toString(), isNot(contains('/')));
  });

  test('a rootless identity has no inversion description', () {
    expect(InversionFormatter.format(_rootlessCm9()), isNull);
  });

  test('long and spoken names carry no slash-bass phrase', () {
    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: _rootlessCm9(),
      tonality: _bFlatMajor,
      notation: ChordNotationStyle.textual,
    );

    expect(presentation.longLabel, isNot(contains('slash')));
    expect(presentation.longLabel, isNot(contains('over')));
    expect(presentation.spokenLabel, isNot(contains('slash')));
    expect(presentation.spokenLabel, isNot(contains('over')));
  });
}
