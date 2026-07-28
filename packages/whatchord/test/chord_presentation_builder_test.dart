import 'package:test/test.dart';

import 'package:whatchord/src/services/chord_tone_roles.dart';
import 'package:whatchord/whatchord.dart';

void main() {
  const notation = ChordNotationStyle.textual;

  test('builds presentation for a diatonic triad', () {
    final identity = _identity(
      root: 'C',
      quality: ChordQuality.major,
      intervals: const [0, 4, 7],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'C');
    expect(presentation.longLabel, 'C major');
    expect(presentation.members, ['C', 'E', 'G']);
    expect(presentation.memberDegrees, ['1', '3', '5']);
    expect(presentation.scaleDegree, ScaleDegree.one);
    expect(presentation.normalizedVoicing, [60, 64, 67]);
  });

  test('rotates first-inversion slash bass above root position', () {
    final identity = _identity(
      root: 'C',
      bass: 'E',
      quality: ChordQuality.major,
      intervals: const [0, 4, 7],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'C/E');
    expect(presentation.longLabel, 'C major slash E');
    expect(presentation.normalizedVoicing, [64, 67, 72]);
  });

  test('rotates second-inversion slash bass above root position', () {
    final identity = _identity(
      root: 'C',
      bass: 'G',
      quality: ChordQuality.major,
      intervals: const [0, 4, 7],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.normalizedVoicing, [67, 72, 76]);
  });

  test('rotates seventh-chord slash bass without duplicated pitch classes', () {
    final identity = _identity(
      root: 'C',
      bass: 'Bb',
      quality: ChordQuality.dominant7,
      intervals: const [0, 4, 7, 10],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.normalizedVoicing, [70, 72, 76, 79]);
  });

  test('keeps extensions above the selected slash bass', () {
    final identity = _identity(
      root: 'C',
      bass: 'E',
      quality: ChordQuality.dominant7,
      extensions: const {ChordExtension.nine},
      intervals: const [0, 2, 4, 7, 10],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.normalizedVoicing, [64, 67, 70, 72, 74]);
  });

  test('uses upper-structure slash display for add9 slash bass triads', () {
    final identity = _identity(
      root: 'G',
      bass: 'A',
      quality: ChordQuality.major,
      extensions: const {ChordExtension.add9},
      intervals: const [0, 2, 4, 7],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'G/A');
    expect(presentation.longLabel, 'G major over A');
    expect(presentation.semanticLabel, 'G major over A');
    expect(InversionFormatter.format(identity), 'non-root bass: add9');
    expect(presentation.members, ['G', 'A', 'B', 'D']);
    expect(presentation.memberDegrees, ['1', '3', '5', '9']);
  });

  test('keeps root-position add9 triads explicit', () {
    final identity = _identity(
      root: 'G',
      quality: ChordQuality.major,
      extensions: const {ChordExtension.add9},
      intervals: const [0, 2, 4, 7],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'Gadd9');
    expect(presentation.longLabel, 'G major with added nine');
    expect(InversionFormatter.format(identity), isNull);
  });

  test('uses six-slash-bass display when slash bass supplies the ninth', () {
    final identity = _identity(
      root: 'C',
      bass: 'D',
      quality: ChordQuality.major6,
      extensions: const {ChordExtension.add9},
      intervals: const [0, 2, 4, 7, 9],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'C6/D');
    expect(presentation.longLabel, 'C major sixth over D');
    expect(InversionFormatter.format(identity), 'non-root bass: add9');
    expect(presentation.members, ['C', 'D', 'E', 'G', 'A']);
    expect(presentation.memberDegrees, ['1', '3', '5', '6', '9']);
  });

  test(
    'uses seventh-slash-bass display when slash bass supplies the ninth',
    () {
      final dominant = _identity(
        root: 'C',
        bass: 'D',
        quality: ChordQuality.dominant7,
        extensions: const {ChordExtension.nine},
        intervals: const [0, 2, 4, 7, 10],
      );
      final major = _identity(
        root: 'C',
        bass: 'D',
        quality: ChordQuality.major7,
        extensions: const {ChordExtension.nine},
        intervals: const [0, 2, 4, 7, 11],
      );

      final dominantPresentation = ChordPresentationBuilder.fromIdentity(
        identity: dominant,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
        notation: notation,
      );
      final majorPresentation = ChordPresentationBuilder.fromIdentity(
        identity: major,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
        notation: notation,
      );

      expect(dominantPresentation.symbol.toString(), 'C7/D');
      expect(dominantPresentation.longLabel, 'C dominant seventh over D');
      expect(InversionFormatter.format(dominant), 'slash bass: 9');
      expect(dominantPresentation.memberDegrees, ['1', '3', '5', 'b7', '9']);

      expect(majorPresentation.symbol.toString(), 'Cmaj7/D');
      expect(majorPresentation.longLabel, 'C major seventh over D');
      expect(InversionFormatter.format(major), 'slash bass: 9');
      expect(majorPresentation.memberDegrees, ['1', '3', '5', '7', '9']);
    },
  );

  test(
    'uses minor7-slash-bass display when slash bass supplies the eleventh',
    () {
      final identity = _identity(
        root: 'A',
        bass: 'D',
        quality: ChordQuality.minor7,
        extensions: const {ChordExtension.add11},
        intervals: const [0, 3, 5, 7, 10],
      );

      final presentation = ChordPresentationBuilder.fromIdentity(
        identity: identity,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
        notation: notation,
      );

      expect(presentation.symbol.toString(), 'Am7/D');
      expect(presentation.longLabel, 'A minor seventh over D');
      expect(InversionFormatter.format(identity), 'non-root bass: add11');
      expect(presentation.memberDegrees, ['1', 'b3', '5', 'b7', '11']);
    },
  );

  test('uses conventional long labels for root-position six-nine chords', () {
    final major = _identity(
      root: 'C',
      quality: ChordQuality.major6,
      extensions: const {ChordExtension.add9},
      intervals: const [0, 2, 4, 7, 9],
    );
    final minor = _identity(
      root: 'C',
      quality: ChordQuality.minor6,
      extensions: const {ChordExtension.add9},
      intervals: const [0, 2, 3, 7, 9],
    );

    final majorPresentation = ChordPresentationBuilder.fromIdentity(
      identity: major,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );
    final minorPresentation = ChordPresentationBuilder.fromIdentity(
      identity: minor,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(majorPresentation.symbol.toString(), 'C6/9');
    expect(majorPresentation.longLabel, 'C major sixth with added nine');
    expect(minorPresentation.symbol.toString(), 'Cm6/9');
    expect(minorPresentation.longLabel, 'C minor sixth with added nine');
  });

  test('compresses add9 slash triads even when the fifth is absent', () {
    final identity = _identity(
      root: 'G',
      bass: 'A',
      quality: ChordQuality.major,
      extensions: const {ChordExtension.add9},
      intervals: const [0, 2, 4],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    // The add9 is redundant with the slash bass (A = 9th of G + bass note),
    // so it is compressed: "G/A" is the conventional musician symbol.
    // The 5th is implied as with any triad name.
    expect(presentation.symbol.toString(), 'G/A');
    expect(presentation.longLabel, 'G major over A');
    expect(InversionFormatter.format(identity), 'non-root bass: add9');
  });

  test('stacks root-position seventh extensions above the core chord', () {
    final identity = _identity(
      root: 'C',
      quality: ChordQuality.dominant7,
      extensions: const {ChordExtension.nine},
      intervals: const [0, 2, 4, 7, 10],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.normalizedVoicing, [60, 64, 67, 70, 74]);
  });

  test('includes extension labels and altered member degrees', () {
    final identity = _identity(
      root: 'G',
      quality: ChordQuality.dominant7,
      extensions: const {ChordExtension.flat9, ChordExtension.sharp11},
      intervals: const [0, 4, 6, 7, 10, 1],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'G7(b9,#11)');
    expect(
      presentation.longLabel,
      'G dominant seventh with flat nine and sharp eleven',
    );
    expect(presentation.members, ['G', 'Ab', 'B', 'C#', 'D', 'F']);
    expect(presentation.memberDegrees, ['1', '3', '5', 'b7', 'b9', '#11']);
    expect(presentation.scaleDegree, isNull);

    expect(
      ChordLongFormFormatter.format(
        identity: identity,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
        accidentalStyle: ChordLongFormAccidentalStyle.plainText,
      ),
      'G dominant seventh with flat nine and sharp eleven',
    );
  });

  test('marks the omitted third of a bare flat-seven shell', () {
    final identity = _identity(
      root: 'D',
      quality: ChordQuality.dominant7,
      intervals: const [0, 7, 10],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'D7(omit3)');
    expect(presentation.longLabel, 'D dominant seventh, omitted third');
    expect(presentation.members, ['D', 'A', 'C']);
    expect(presentation.memberDegrees, ['1', '5', 'b7']);
  });

  test('promotes symbolic major seventh sus ninths into the headline', () {
    final identity = _identity(
      root: 'C',
      quality: ChordQuality.major7sus4,
      extensions: const {ChordExtension.nine},
      intervals: const [0, 2, 5, 7, 11],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: ChordNotationStyle.symbolic,
    );

    expect(presentation.symbol.toString(), 'CΔ9sus4');
  });

  test('groups textual minor-major markers with other modifiers', () {
    final minorMajorSeventh = _identity(
      root: 'C',
      quality: ChordQuality.minorMajor7,
      intervals: const [0, 3, 7, 11],
    );
    final minorMajorNinthFlatThirteenth = _identity(
      root: 'C',
      quality: ChordQuality.minorMajor7,
      extensions: const {ChordExtension.nine, ChordExtension.flat13},
      intervals: const [0, 2, 3, 7, 8, 11],
    );

    final seventhPresentation = ChordPresentationBuilder.fromIdentity(
      identity: minorMajorSeventh,
      tonality: const Tonality(Tonic.c, TonalityMode.minor),
      notation: notation,
    );
    final extendedPresentation = ChordPresentationBuilder.fromIdentity(
      identity: minorMajorNinthFlatThirteenth,
      tonality: const Tonality(Tonic.c, TonalityMode.minor),
      notation: notation,
    );

    expect(seventhPresentation.symbol.toString(), 'Cm(maj7)');
    expect(extendedPresentation.symbol.toString(), 'Cm(maj9,b13)');
  });

  test('groups lone modifiers after dense promoted major-family labels', () {
    final majorEleventhFlatThirteenth = _identity(
      root: 'C',
      quality: ChordQuality.major7,
      extensions: const {
        ChordExtension.nine,
        ChordExtension.eleven,
        ChordExtension.flat13,
      },
      intervals: const [0, 2, 4, 5, 7, 8, 11],
    );
    final majorThirteenthSharpEleventh = _identity(
      root: 'C',
      quality: ChordQuality.major7,
      extensions: const {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
      intervals: const [0, 2, 4, 6, 7, 9, 11],
    );
    final dominantThirteenthSharpEleventh = _identity(
      root: 'C',
      quality: ChordQuality.dominant7,
      extensions: const {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
      intervals: const [0, 2, 4, 6, 7, 9, 10],
    );

    final majorEleventhPresentation = ChordPresentationBuilder.fromIdentity(
      identity: majorEleventhFlatThirteenth,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );
    final majorThirteenthPresentation = ChordPresentationBuilder.fromIdentity(
      identity: majorThirteenthSharpEleventh,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );
    final dominantPresentation = ChordPresentationBuilder.fromIdentity(
      identity: dominantThirteenthSharpEleventh,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(majorEleventhPresentation.symbol.toString(), 'Cmaj11(b13)');
    expect(majorThirteenthPresentation.symbol.toString(), 'Cmaj13(#11)');
    expect(dominantPresentation.symbol.toString(), 'C13#11');
  });

  test('groups lone altered extensions after plain major labels', () {
    final majorSharpEleventh = _identity(
      root: 'C',
      quality: ChordQuality.major,
      extensions: const {ChordExtension.sharp11},
      intervals: const [0, 4, 6, 7],
    );
    final majorFlatThirteenth = _identity(
      root: 'C',
      quality: ChordQuality.major,
      extensions: const {ChordExtension.flat13},
      intervals: const [0, 4, 7, 8],
    );

    final sharpEleventhPresentation = ChordPresentationBuilder.fromIdentity(
      identity: majorSharpEleventh,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );
    final flatThirteenthPresentation = ChordPresentationBuilder.fromIdentity(
      identity: majorFlatThirteenth,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(sharpEleventhPresentation.symbol.toString(), 'C(#11)');
    expect(flatThirteenthPresentation.symbol.toString(), 'C(b13)');
  });

  test('groups promoted extensions after accidental roots', () {
    final dominantEleventh = _identity(
      root: 'C#',
      quality: ChordQuality.dominant7,
      extensions: const {ChordExtension.eleven},
      intervals: const [0, 4, 5, 7, 10],
    );
    final dominantThirteenthSharpEleventh = _identity(
      root: 'F#',
      quality: ChordQuality.dominant7,
      extensions: const {ChordExtension.sharp11, ChordExtension.thirteen},
      intervals: const [0, 4, 6, 7, 9, 10],
    );

    final eleventhPresentation = ChordPresentationBuilder.fromIdentity(
      identity: dominantEleventh,
      tonality: const Tonality(Tonic.cSharp, TonalityMode.major),
      notation: notation,
      rootName: 'C#',
    );
    final thirteenthPresentation = ChordPresentationBuilder.fromIdentity(
      identity: dominantThirteenthSharpEleventh,
      tonality: const Tonality(Tonic.fSharp, TonalityMode.major),
      notation: notation,
      rootName: 'F#',
    );

    expect(eleventhPresentation.symbol.toString(), 'C#(11)');
    expect(thirteenthPresentation.symbol.toString(), 'F#(13,#11)');

    final symbolicThirteenthPresentation =
        ChordPresentationBuilder.fromIdentity(
          identity: dominantThirteenthSharpEleventh,
          tonality: const Tonality(Tonic.fSharp, TonalityMode.major),
          notation: ChordNotationStyle.symbolic,
          rootName: 'F#',
        );

    expect(symbolicThirteenthPresentation.symbol.toString(), 'F#(13#11)');

    final glyphRootPresentation = ChordPresentationBuilder.fromIdentity(
      identity: dominantEleventh,
      tonality: const Tonality(Tonic.cSharp, TonalityMode.major),
      notation: notation,
      rootName: 'C♯',
    );

    expect(glyphRootPresentation.symbol.toString(), 'C♯(11)');
  });

  test(
    'inserts comma before bass connector when multiple modifiers present',
    () {
      final identity = _identity(
        root: 'G',
        bass: 'B',
        quality: ChordQuality.dominant7,
        extensions: const {ChordExtension.flat9, ChordExtension.sharp11},
        intervals: const [0, 4, 6, 7, 10, 1],
      );

      expect(
        ChordLongFormFormatter.format(
          identity: identity,
          tonality: const Tonality(Tonic.c, TonalityMode.major),
          accidentalStyle: ChordLongFormAccidentalStyle.plainText,
        ),
        'G dominant seventh with flat nine and sharp eleven, slash B',
      );
    },
  );

  test('promotes seventh-family natural extensions in long labels', () {
    final dominantNinth = _identity(
      root: 'C',
      quality: ChordQuality.dominant7,
      extensions: const {ChordExtension.nine},
      intervals: const [0, 2, 4, 7, 10],
    );
    final minorEleventh = _identity(
      root: 'D',
      quality: ChordQuality.minor7,
      extensions: const {ChordExtension.nine, ChordExtension.eleven},
      intervals: const [0, 2, 3, 5, 7, 10],
    );
    final majorThirteenth = _identity(
      root: 'F',
      quality: ChordQuality.major7,
      extensions: const {
        ChordExtension.nine,
        ChordExtension.eleven,
        ChordExtension.thirteen,
      },
      intervals: const [0, 2, 4, 5, 7, 9, 11],
    );

    expect(
      ChordLongFormFormatter.format(
        identity: dominantNinth,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
      ),
      'C dominant ninth',
    );
    expect(
      ChordLongFormFormatter.format(
        identity: minorEleventh,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
      ),
      'D minor eleventh',
    );
    expect(
      ChordLongFormFormatter.format(
        identity: majorThirteenth,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
      ),
      'F major thirteenth',
    );
  });

  test('keeps added tones and alterations as long-label modifiers', () {
    final minorAddEleventh = _identity(
      root: 'D',
      quality: ChordQuality.minor7,
      extensions: const {ChordExtension.add11},
      intervals: const [0, 3, 5, 7, 10],
    );
    final dominantSharpEleventh = _identity(
      root: 'G',
      quality: ChordQuality.dominant7,
      extensions: const {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
      intervals: const [0, 2, 4, 6, 7, 9, 10],
    );

    expect(
      ChordLongFormFormatter.format(
        identity: minorAddEleventh,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
      ),
      'D minor seventh with added eleven',
    );
    expect(
      ChordLongFormFormatter.format(
        identity: dominantSharpEleventh,
        tonality: const Tonality(Tonic.c, TonalityMode.major),
      ),
      'G dominant thirteenth with sharp eleven',
    );
  });

  test('returns null scale degree for non-diatonic presentation', () {
    final identity = _identity(
      root: 'Db',
      quality: ChordQuality.major,
      intervals: const [0, 4, 7],
    );

    final presentation = ChordPresentationBuilder.fromIdentity(
      identity: identity,
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      notation: notation,
    );

    expect(presentation.symbol.toString(), 'Db');
    expect(presentation.longLabel, 'D♭ major');
    expect(presentation.scaleDegree, isNull);
  });
}

ChordIdentity _identity({
  required String root,
  required ChordQuality quality,
  required List<int> intervals,
  String? bass,
  Set<ChordExtension> extensions = const {},
}) {
  final presentIntervalsMask = _maskOfIntervals(intervals);

  return ChordIdentity(
    rootPc: pitchClassFromNoteName(root),
    bassPc: pitchClassFromNoteName(bass ?? root),
    quality: quality,
    extensions: extensions,
    toneRolesByInterval: ChordToneRoles.build(
      quality: quality,
      extensions: extensions,
      relMask: presentIntervalsMask,
    ),
    presentIntervalsMask: presentIntervalsMask,
  );
}

int _maskOfIntervals(Iterable<int> intervals) {
  var mask = 0;
  for (final interval in intervals) {
    mask |= 1 << (interval % 12);
  }
  return mask;
}
