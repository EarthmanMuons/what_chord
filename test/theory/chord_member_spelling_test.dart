import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whatchord_app/features/theory/theory.dart';

import 'package:whatchord/testing.dart';

final _analyzer = ChordAnalyzer();

void main() {
  // Regression: a non-diatonic chord root must be spelled with chord context,
  // not the plain chromatic noteNameForPitchClass. Bbmaj9/D in C major identifies with root
  // pitch class 10; noteNameForPitchClass(10) is "A#", which would spell every member
  // relative to A# (Cx, E#, Gx, B#). The chips must match the identity card's
  // Bb spelling instead.
  test('member chips use the chord-aware root spelling, not plain noteNameForPitchClass', () {
    const cMajor = Tonality(Tonic.c, TonalityMode.major);

    final input = chordInputFromNames(
      names: ['D', 'F', 'A', 'C', 'Bb'],
      bass: 'D',
    );
    final identity = _analyzer
        .analyze(input, context: makeAnalysisContext(tonality: cMajor))
        .first
        .identity;

    // Guard the underlying contract both call sites depend on.
    expect(identity.rootPc, 10);
    expect(noteNameForPitchClass(identity.rootPc, tonality: cMajor), 'A#');
    expect(spellChordRoot(identity, tonality: cMajor), 'Bb');

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: cMajor,
      notation: ChordNotationStyle.textual,
    );

    final container = ProviderContainer(
      overrides: [
        chordPresentationProvider.overrideWithValue(presentation),
        analysisContextProvider.overrideWithValue(
          makeAnalysisContext(tonality: cMajor),
        ),
      ],
    );
    addTearDown(container.dispose);

    final byPc = container.read(chordMemberSpellingsByPcProvider);
    expect(byPc[10], 'Bb');
    expect(byPc[0], 'C');
    expect(byPc[2], 'D');
    expect(byPc[5], 'F');
    expect(byPc[9], 'A');
  });
}
