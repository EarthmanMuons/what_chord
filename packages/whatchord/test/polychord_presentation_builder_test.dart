import 'package:test/test.dart';
import 'package:whatchord/whatchord.dart';

void main() {
  test('renders the frozen upper-first product wording', () {
    final presentation = PolychordPresentationBuilder.fromCandidate(
      candidate: _candidate(
        upperRoot: 0,
        upperQuality: PolychordLayerQuality.major,
        lowerRoot: 7,
        lowerQuality: PolychordLayerQuality.minor,
      ),
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: ChordNotationStyle.textual,
    );

    expect(presentation.symbol.toString(), 'C|Gm');
    expect(presentation.longLabel, 'Polychord: C major above G minor');
    expect(
      presentation.semanticLabel,
      'Polychord. Upper chord: C major. Lower chord: G minor.',
    );
  });

  test('uses the existing enharmonic spelling context for both layers', () {
    final presentation = PolychordPresentationBuilder.fromCandidate(
      candidate: _candidate(
        upperRoot: 10,
        upperQuality: PolychordLayerQuality.major7,
        lowerRoot: 5,
        lowerQuality: PolychordLayerQuality.minor7,
      ),
      tonality: const Tonality(Tonic.f, TonalityMode.major),
      notation: ChordNotationStyle.textual,
    );

    expect(presentation.symbol.toString(), 'Bbmaj7|Fm7');
    expect(presentation.longLabel, contains('B♭ major seventh'));
    expect(presentation.semanticLabel, contains('B flat major seventh'));
  });

  test(
    'maps every registered layer quality to the existing chord vocabulary',
    () {
      const expected = <PolychordLayerQuality, String>{
        PolychordLayerQuality.major: 'C',
        PolychordLayerQuality.minor: 'Cm',
        PolychordLayerQuality.dominant7: 'C7',
        PolychordLayerQuality.major7: 'Cmaj7',
        PolychordLayerQuality.minor7: 'Cm7',
      };

      for (final entry in expected.entries) {
        final presentation = PolychordPresentationBuilder.fromCandidate(
          candidate: _candidate(
            upperRoot: 0,
            upperQuality: entry.key,
            lowerRoot: 7,
            lowerQuality: PolychordLayerQuality.major,
          ),
          tonality: const Tonality(Tonic.c, TonalityMode.major),
          notation: ChordNotationStyle.textual,
        );
        expect(presentation.symbol.upper.toString(), entry.value);
      }
    },
  );
}

PolychordCandidate _candidate({
  required int upperRoot,
  required PolychordLayerQuality upperQuality,
  required int lowerRoot,
  required PolychordLayerQuality lowerQuality,
}) {
  final lowerNotes = _notes(lowerRoot, lowerQuality, 36);
  final upperNotes = _notes(upperRoot, upperQuality, 72);
  return PolychordCandidate(
    splitAfterIndex: lowerNotes.length - 1,
    lowerTopMidi: lowerNotes.last,
    upperBottomMidi: upperNotes.first,
    gapSemitones: upperNotes.first - lowerNotes.last,
    lower: PolychordLayerCandidate(
      identity: PolychordLayerIdentity(
        rootPc: lowerRoot,
        quality: lowerQuality,
      ),
      midiNotes: lowerNotes,
      pitchClasses: lowerNotes.map((note) => note % 12).toSet().toList()
        ..sort(),
    ),
    upper: PolychordLayerCandidate(
      identity: PolychordLayerIdentity(
        rootPc: upperRoot,
        quality: upperQuality,
      ),
      midiNotes: upperNotes,
      pitchClasses: upperNotes.map((note) => note % 12).toSet().toList()
        ..sort(),
    ),
    sharedPitchClasses: const [],
  );
}

List<int> _notes(int rootPc, PolychordLayerQuality quality, int octaveBase) {
  final intervals = switch (quality) {
    PolychordLayerQuality.major => const [0, 4, 7],
    PolychordLayerQuality.minor => const [0, 3, 7],
    PolychordLayerQuality.dominant7 => const [0, 4, 7, 10],
    PolychordLayerQuality.major7 => const [0, 4, 7, 11],
    PolychordLayerQuality.minor7 => const [0, 3, 7, 10],
  };
  return [for (final interval in intervals) octaveBase + rootPc + interval];
}
