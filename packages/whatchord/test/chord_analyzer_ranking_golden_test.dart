import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

import 'helpers/chord_analyzer_golden_helpers.dart';
import 'package:whatchord/testing.dart';

final _analyzer = ChordAnalyzer();

void main() {
  final cases = <GoldenCase>[
    // -------------------------------------------------------------------------
    // Root-position extended harmony vs remote slash reinterpretations
    // -------------------------------------------------------------------------
    golden(
      description: 'root-position lydian dominant beats altered-fifth slash',
      expectedSymbol: 'C9#11',
      pcs: ['C', 'E', 'G', 'Bb', 'D', 'F#'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
    ),

    golden(
      description: 'third-inversion lydian dominant beats altered-fifth slash',
      expectedSymbol: 'C9#11/Bb',
      pcs: ['C', 'D', 'E', 'F#', 'G', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'C',
      expectedBass: 'Bb',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
    ),

    golden(
      description: 'root-position thirteenth sharp eleventh beats remote slash',
      expectedSymbol: 'C13#11',
      pcs: ['C', 'E', 'G', 'Bb', 'D', 'F#', 'A'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    // -------------------------------------------------------------------------
    // Slash and inversion disambiguation
    // -------------------------------------------------------------------------
    golden(
      description: 'complete minor sharp eleventh beats altered sus slash',
      expectedSymbol: 'Am#11/E',
      pcs: ['E', 'A', 'C', 'D#'],
      bass: 'E',
      expectedRoot: 'A',
      expectedBass: 'E',
      expectedQuality: ChordQuality.minor,
      expectedExtensions: {ChordExtension.sharp11},
    ),

    golden(
      description: 'complete triad beats incomplete inverted sixth',
      expectedSymbol: 'Em/B',
      pcs: ['B', 'E', 'G'],
      bass: 'B',
      noteCount: 4,
      tonality: const Tonality(Tonic.d, TonalityMode.major),
      expectedRoot: 'E',
      expectedBass: 'B',
      expectedQuality: ChordQuality.minor,
    ),

    golden(
      description: 'complete major inversion beats minor sharp fifth',
      expectedSymbol: 'Ab/C',
      pcs: ['C', 'Eb', 'Ab'],
      bass: 'C',
      expectedRoot: 'Ab',
      expectedBass: 'C',
      expectedQuality: ChordQuality.major,
    ),

    golden(
      description:
          'complete second-inversion major triad beats minor sharp fifth',
      expectedSymbol: 'Ab/Eb',
      pcs: ['C', 'Eb', 'Ab'],
      bass: 'Eb',
      expectedRoot: 'Ab',
      expectedBass: 'Eb',
      expectedQuality: ChordQuality.major,
    ),

    golden(
      description: 'complete add-nine inversion beats minor seven sharp five',
      expectedSymbol: 'Cadd9/E',
      expectedAlternatives: ['D7sus4/E'],
      pcs: ['C', 'D', 'E', 'G'],
      bass: 'E',
      expectedRoot: 'C',
      expectedBass: 'E',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description:
          'complete major triad with flat ninth beats note-dropping '
          'diminished triad',
      expectedSymbol: 'Caddb9/G',
      pcs: ['C', 'Db', 'E', 'G'],
      bass: 'G',
      expectedRoot: 'C',
      expectedBass: 'G',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.addFlat9},
    ),

    golden(
      description: 'upper-structure major triad over ninth bass',
      expectedSymbol: 'C#/D#',
      pcs: ['D#', 'C#', 'E#', 'G#'],
      bass: 'D#',
      tonality: const Tonality(Tonic.cSharp, TonalityMode.major),
      expectedRoot: 'C#',
      expectedBass: 'D#',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description:
          'root-position dominant sus beats complete second-inversion sus',
      expectedSymbol: 'G7sus4',
      expectedAlternatives: ['Csus4/G'],
      pcs: ['C', 'F', 'G'],
      bass: 'G',
      expectedRoot: 'G',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7sus4,
    ),

    golden(
      description: 'root-position ninth sus beats remote slash readings',
      expectedSymbol: 'D9sus4',
      expectedAlternatives: ['Am7/D'],
      pcs: ['C', 'D', 'E', 'G', 'A'],
      bass: 'D',
      expectedRoot: 'D',
      expectedBass: 'D',
      expectedQuality: ChordQuality.dominant7sus4,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description: 'root-position flat-nine sus beats half-diminished slash',
      expectedSymbol: 'C7sus4(b9)',
      pcs: ['C', 'Db', 'F', 'G', 'Bb'],
      bass: 'C',
      expectedRoot: 'C',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7sus4,
      expectedExtensions: {ChordExtension.flat9},
    ),

    golden(
      description: 'ninth-bass dominant stack beats altered slash',
      expectedSymbol: 'C7/D',
      expectedAlternatives: ['Gm6add11/D'],
      pcs: ['D', 'C', 'E', 'G', 'Bb'],
      bass: 'D',
      expectedRoot: 'C',
      expectedBass: 'D',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description: 'minor-major ninth bass chord beats altered major7 slash',
      expectedSymbol: 'C#m(maj7)/D#',
      expectedAlternatives: ['D#(13sus4,b9)'],
      pcs: ['C', 'Db', 'Eb', 'E', 'Ab'],
      bass: 'Eb',
      expectedRoot: 'C#',
      expectedBass: 'D#',
      expectedQuality: ChordQuality.minorMajor7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description: 'minor-major ninth beats augmented-major thirteenth',
      expectedSymbol: 'C#m(maj9)/E',
      pcs: ['C', 'Db', 'Eb', 'E', 'Ab'],
      bass: 'E',
      expectedRoot: 'C#',
      expectedBass: 'E',
      expectedQuality: ChordQuality.minorMajor7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description:
          'minor-major ninth flat-thirteenth beats augmented-major eleventh',
      expectedSymbol: 'C#m(maj9,b13)/E',
      pcs: ['C', 'Db', 'Eb', 'E', 'Ab', 'A'],
      bass: 'E',
      expectedRoot: 'C#',
      expectedBass: 'E',
      expectedQuality: ChordQuality.minorMajor7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.flat13},
    ),

    golden(
      description: 'complete dominant flat-nine beats colored diminished7',
      expectedSymbol: 'C7b9/G',
      pcs: ['C', 'Db', 'E', 'G', 'Bb'],
      bass: 'G',
      expectedRoot: 'C',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9},
    ),

    golden(
      description: 'complete dominant flat-nine beats diminished add-nine',
      expectedSymbol: 'C7b9/E',
      pcs: ['C', 'Db', 'E', 'Bb'],
      bass: 'E',
      expectedRoot: 'C',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9},
    ),

    golden(
      description:
          'complete dominant flat-nine sharp-nine beats colored diminished7',
      expectedSymbol: 'C7(b9,#9)/G',
      expectedAlternatives: ['A#dim7(add9,add11)/G', 'Eb(13,b9)/G'],
      pcs: ['C', 'Db', 'Eb', 'E', 'G', 'Bb'],
      bass: 'G',
      expectedRoot: 'C',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.sharp9},
    ),

    golden(
      description:
          'complete dominant flat-nine sharp-eleven beats colored diminished7',
      expectedSymbol: 'F#7(b9,#11)/C#',
      pcs: ['C', 'Db', 'E', 'F#', 'G', 'Bb'],
      bass: 'Db',
      expectedRoot: 'F#',
      expectedBass: 'C#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.sharp11},
    ),

    golden(
      description:
          'complete dominant flat-nine sharp-eleven handles fifth bass',
      expectedSymbol: 'C7(b9,#11)/G',
      pcs: ['C', 'Db', 'E', 'F#', 'G', 'Bb'],
      bass: 'G',
      expectedRoot: 'C',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.sharp11},
    ),

    golden(
      description:
          'complete dominant flat-nine sharp-eleven handles major-third bass',
      expectedSymbol: 'C7(b9,#11)/Bb',
      expectedAlternatives: ['F#7(b9,#11)/A#'],
      pcs: ['C', 'Db', 'E', 'F#', 'G', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'C',
      expectedBass: 'Bb',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.sharp11},
    ),

    // -------------------------------------------------------------------------
    // Sixth-family ranking
    // -------------------------------------------------------------------------
    golden(
      description: 'sixth-family beats seventh-family when seventh is absent',
      expectedSymbol: 'Gm6',
      pcs: ['G', 'Bb', 'D', 'E'],
      expectedRoot: 'G',
      expectedQuality: ChordQuality.minor6,
    ),

    golden(
      description: 'minor-key tonality bias changes best interpretation',
      expectedSymbol: 'Am11/C',
      pcs: ['C', 'E', 'G', 'A', 'D'],
      tonality: const Tonality(Tonic.a, TonalityMode.minor),
      expectedRoot: 'A',
      expectedBass: 'C',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.eleven},
    ),

    // The relative-major reading and the tonic-minor reading of the same
    // pitches cost almost the same; in A minor the tonic name wins.
    golden(
      description: 'minor tonic beats relative-major reading of the same notes',
      expectedSymbol: 'Am9/C',
      expectedAlternatives: ['Cmaj13'],
      pcs: ['C', 'E', 'G', 'A', 'B'],
      tonality: const Tonality(Tonic.a, TonalityMode.minor),
      expectedRoot: 'A',
      expectedBass: 'C',
      expectedQuality: ChordQuality.minor7,
    ),

    // The symmetric augmented triad has three equal-cost spellings; the
    // diatonic tie-breaker picks the one rooted on a scale degree.
    golden(
      description: 'diatonic augmented spelling wins in minor key',
      expectedSymbol: 'Caug/E',
      expectedAlternatives: ['Eaug'],
      pcs: ['C', 'E', 'Ab'],
      bass: 'E',
      tonality: const Tonality(Tonic.a, TonalityMode.minor),
      expectedRoot: 'C',
      expectedBass: 'E',
      expectedQuality: ChordQuality.augmented,
    ),

    golden(
      description: 'common-name prior breaks sixth versus minor seventh tie',
      expectedSymbol: 'Dm7/A',
      expectedAlternatives: ['F6/A'],
      pcs: ['C', 'D', 'F', 'A'],
      bass: 'A',
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      expectedRoot: 'D',
      expectedBass: 'A',
      expectedQuality: ChordQuality.minor7,
    ),

    golden(
      description: 'root-position minor7 beats relative-major sixth slash',
      expectedSymbol: 'Am7',
      expectedAlternatives: ['C6/A'],
      pcs: ['C', 'E', 'G', 'A'],
      bass: 'A',
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      expectedRoot: 'A',
      expectedBass: 'A',
      expectedQuality: ChordQuality.minor7,
    ),

    golden(
      description:
          'root-position minor7 eleventh beats relative-major six-nine slash',
      expectedSymbol: 'Am11',
      expectedAlternatives: ['C6/9/A', 'D9sus4/A'],
      pcs: ['C', 'D', 'E', 'G', 'A'],
      bass: 'A',
      tonality: const Tonality(Tonic.c, TonalityMode.major),
      expectedRoot: 'A',
      expectedBass: 'A',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.eleven},
    ),

    // -------------------------------------------------------------------------
    // Sus-tone-in-bass penalty
    // -------------------------------------------------------------------------

    // {A, C, D, E} with E bass could be read as D7sus2/E (sus2 in bass),
    // C6/9/E (incomplete inverted sixth), or Amadd11/E (complete minor triad
    // with added color). The sus-bass penalty demotes D7sus2/E into a near-tie,
    // and the complete-triad-core rule prefers the Am reading over C6/9/E.
    golden(
      description: 'am add11 beats incomplete inverted sixth',
      expectedSymbol: 'Amadd11/E',
      pcs: ['A', 'C', 'D', 'E'],
      bass: 'E',
      expectedRoot: 'A',
      expectedBass: 'E',
      expectedQuality: ChordQuality.minor,
      expectedExtensions: {ChordExtension.add11},
    ),

    golden(
      description: 'am add11 beats sus2-tone-in-bass in A minor context',
      expectedSymbol: 'Amadd11/E',
      pcs: ['A', 'C', 'D', 'E'],
      bass: 'E',
      tonality: const Tonality(Tonic.a, TonalityMode.minor),
      expectedRoot: 'A',
      expectedBass: 'E',
      expectedQuality: ChordQuality.minor,
      expectedExtensions: {ChordExtension.add11},
    ),

    golden(
      description: 'transposed add11 beats incomplete inverted sixth',
      expectedSymbol: 'Dmadd11/A',
      pcs: ['D', 'F', 'G', 'A'],
      bass: 'A',
      tonality: const Tonality(Tonic.f, TonalityMode.major),
      expectedRoot: 'D',
      expectedBass: 'A',
      expectedQuality: ChordQuality.minor,
      expectedExtensions: {ChordExtension.add11},
    ),

    // -------------------------------------------------------------------------
    // Compact voicing disambiguation
    // -------------------------------------------------------------------------
    golden(
      description:
          'minor-major sharp eleventh beats remote major sharp-five slash',
      expectedSymbol: 'Fm(maj7,#11)/Ab',
      pcs: ['Ab', 'B', 'C', 'E', 'F'],
      expectedRoot: 'F',
      expectedQuality: ChordQuality.minorMajor7,
      expectedExtensions: {ChordExtension.sharp11},
    ),

    // -------------------------------------------------------------------------
    // Dominant7 shell slash beats non-dominant seventh-family slash
    // -------------------------------------------------------------------------
    // {C, Db, Eb, F, Ab, A} with Ab bass: the F altered dominant reading
    // (F7#9b13 with Ab=G# as the sharp-9 bass) is what musicians expect.
    // The competing C#maj9b13/Ab interpretation has a lower raw cost, but
    // the dom7 shell-slash rule correctly promotes F7.
    golden(
      description: 'dominant7 shell slash beats major7 family slash',
      expectedSymbol: 'F7(#9,b13)/G#',
      pcs: ['C', 'Db', 'Eb', 'F', 'Ab', 'A'],
      bass: 'Ab',
      expectedRoot: 'F',
      expectedBass: 'G#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.flat13},
    ),

    golden(
      description:
          'complete dominant sharp-nine flat-thirteen handles flat-thirteenth bass',
      expectedSymbol: 'C#maj9b13',
      pcs: ['C', 'Db', 'Eb', 'F', 'Ab', 'A'],
      bass: 'Db',
      expectedRoot: 'C#',
      expectedBass: 'C#',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.flat13},
    ),

    golden(
      description: 'complete dominant nine flat-thirteen handles fifth bass',
      expectedSymbol: 'F9b13/C',
      expectedAlternatives: ['Cm6(b9,add11)'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G', 'A'],
      bass: 'C',
      expectedRoot: 'F',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.flat13},
    ),

    golden(
      description: 'third-bass lydian thirteenth beats nine flat-thirteen twin',
      expectedSymbol: 'Eb(13,#11)/G',
      expectedAlternatives: ['F9b13/G', 'Cm6(b9,add11)/G'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G', 'A'],
      bass: 'G',
      expectedRoot: 'Eb',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description: 'complete dominant nine flat-thirteen handles third bass',
      expectedSymbol: 'F9b13/A',
      pcs: ['C', 'Db', 'Eb', 'F', 'G', 'A'],
      bass: 'A',
      expectedRoot: 'F',
      expectedBass: 'A',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.flat13},
    ),

    golden(
      // The Eb13b5 reading stays available, but it spells its flat fifth as
      // B double-flat; the complete dominant b13 stack names the same notes
      // plainly and matches the other basses of this collection.
      description:
          'complete dominant nine flat-thirteen handles flat-thirteenth bass',
      expectedSymbol: 'Eb(13,#11)/Db',
      expectedAlternatives: ['F9b13/Db', 'Eb(13,b5)/Db'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G', 'A'],
      bass: 'Db',
      expectedRoot: 'Eb',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'complete altered flat-nine flat-thirteen dominant handles seventh bass',
      expectedSymbol: 'F7(b9,b13)/Eb',
      expectedAlternatives: ['D#m13(b5)'],
      pcs: ['C', 'Db', 'Eb', 'F', 'F#', 'A'],
      bass: 'Eb',
      expectedRoot: 'F',
      expectedBass: 'Eb',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.flat13},
    ),

    golden(
      description:
          'complete altered flat-nine flat-thirteen dominant handles flat-nine bass',
      expectedSymbol: 'F7(b9,b13)/Gb',
      expectedAlternatives: ['D#m13(b5)/F#'],
      pcs: ['C', 'Db', 'Eb', 'F', 'F#', 'A'],
      bass: 'F#',
      expectedRoot: 'F',
      expectedBass: 'Gb',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.flat13},
    ),

    golden(
      description: 'complete altered dominant inversion beats altered major7',
      expectedSymbol: 'A7(#5,#9)/C#',
      pcs: ['C', 'Db', 'F', 'G', 'A'],
      bass: 'Db',
      expectedRoot: 'A',
      expectedBass: 'C#',
      expectedQuality: ChordQuality.dominant7Sharp5,
      expectedExtensions: {ChordExtension.sharp9},
    ),

    golden(
      description:
          'complete altered dominant sharp-nine bass beats sus add-color',
      expectedSymbol: 'A7(#5,#9)/C',
      pcs: ['C', 'Db', 'F', 'G', 'A'],
      bass: 'C',
      expectedRoot: 'A',
      expectedBass: 'B#',
      expectedQuality: ChordQuality.dominant7Sharp5,
      expectedExtensions: {ChordExtension.sharp9},
    ),

    golden(
      description: 'complete dominant sharp-nine beats sixth flat-nine',
      expectedSymbol: 'C7#9/D#',
      pcs: ['C', 'Eb', 'E', 'G', 'Bb'],
      bass: 'Eb',
      expectedRoot: 'C',
      expectedBass: 'D#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9},
    ),

    golden(
      description:
          'complete sharp-nine sharp-eleven dominant beats split-third sixth',
      expectedSymbol: 'A7(#9,#11)/C',
      pcs: ['C', 'Db', 'Eb', 'E', 'G', 'A'],
      bass: 'C',
      expectedRoot: 'A',
      expectedBass: 'B#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.sharp11},
    ),

    golden(
      description:
          'complete altered dominant fifth bass beats split-third sixth',
      expectedSymbol: 'A7(#9,#11)/E',
      pcs: ['C', 'Db', 'Eb', 'E', 'G', 'A'],
      bass: 'E',
      expectedRoot: 'A',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.sharp11},
    ),

    golden(
      description:
          'complete altered dominant seventh bass beats split-third sixth',
      expectedSymbol: 'A7(#9,#11)/G',
      pcs: ['C', 'Db', 'Eb', 'E', 'G', 'A'],
      bass: 'G',
      expectedRoot: 'A',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.sharp11},
    ),

    golden(
      description:
          'complete altered dominant thirteenth beats colored split-third sixth',
      expectedSymbol: 'A13(#9,#11)/C',
      expectedAlternatives: ['Eb(13,b9,#9,#11)/C'],
      pcs: ['C', 'Db', 'Eb', 'E', 'F#', 'G', 'A'],
      bass: 'C',
      expectedRoot: 'A',
      expectedBass: 'B#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.sharp9,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'complete altered dominant thirteenth fifth bass beats colored split-third sixth',
      expectedSymbol: 'A13(#9,#11)/E',
      pcs: ['C', 'Db', 'Eb', 'E', 'F#', 'G', 'A'],
      bass: 'E',
      expectedRoot: 'A',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.sharp9,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'complete altered dominant thirteenth seventh bass beats colored split-third sixth',
      expectedSymbol: 'A13(#9,#11)/G',
      pcs: ['C', 'Db', 'Eb', 'E', 'F#', 'G', 'A'],
      bass: 'G',
      expectedRoot: 'A',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.sharp9,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'complete altered dominant thirteenth beats altered minor thirteenth',
      expectedSymbol: 'A13(#9,#11)/F#',
      expectedAlternatives: ['F#m13(b9,#11)'],
      pcs: ['C', 'Db', 'Eb', 'E', 'F#', 'G', 'A'],
      bass: 'F#',
      expectedRoot: 'A',
      expectedBass: 'F#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.sharp9,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'complete flat-thirteenth altered dominant beats add-eleven split-third sixth',
      expectedSymbol: 'F#7(#9,#11,b13)/E',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'A', 'Bb'],
      bass: 'E',
      expectedRoot: 'F#',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.sharp9,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    golden(
      description:
          'complete flat-thirteenth altered dominant beats root-position add-eleven split-third sixth',
      expectedSymbol: 'F#7(#9,#11,b13)/A',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'A', 'Bb'],
      bass: 'A',
      expectedRoot: 'F#',
      expectedBass: 'Gx',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.sharp9,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    golden(
      description:
          'complete sharp-nine thirteenth dominant beats colored sixth',
      expectedSymbol: 'Eb(13,#9)/Db',
      pcs: ['C', 'Db', 'Eb', 'F#', 'G', 'Bb'],
      bass: 'Db',
      expectedRoot: 'Eb',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.thirteen},
    ),

    golden(
      description:
          'complete sharp-nine thirteenth dominant beats root-position colored sixth',
      expectedSymbol: 'Eb(13,#9)/F#',
      pcs: ['C', 'Db', 'Eb', 'F#', 'G', 'Bb'],
      bass: 'F#',
      expectedRoot: 'Eb',
      expectedBass: 'F#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.thirteen},
    ),

    golden(
      description:
          'complete sharp-nine thirteenth dominant beats third-bass colored sixth',
      expectedSymbol: 'Eb(13,#9)/Bb',
      pcs: ['C', 'Db', 'Eb', 'F#', 'G', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'Eb',
      expectedBass: 'Bb',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.thirteen},
    ),

    golden(
      description: 'split-nine tritone dominant follows conventional inversion',
      expectedSymbol: 'F#7(#11,b13)/A#',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'F#',
      expectedBass: 'A#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp11, ChordExtension.flat13},
    ),

    golden(
      description:
          'split-nine dominant keeps tritone substitute visible in third bass',
      expectedSymbol: 'F#7(#11,b13)/E',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'Bb'],
      bass: 'E',
      expectedRoot: 'F#',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp11, ChordExtension.flat13},
    ),

    golden(
      description: 'tritone flat-five dominant tie uses cleaner spelling',
      expectedSymbol: 'D7b5/C',
      expectedAlternatives: ['G#7b5/B#'],
      pcs: ['C', 'D', 'F#', 'Ab'],
      bass: 'C',
      expectedRoot: 'D',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7Flat5,
    ),

    // -------------------------------------------------------------------------
    // Simple triad add-tone beats inverted unusual seventh-family quality
    // -------------------------------------------------------------------------
    golden(
      description: 'simple triad add-tone beats inverted unusual seventh',
      expectedSymbol: 'Cadd9/G',
      pcs: ['C', 'D', 'E', 'G'],
      bass: 'G',
      expectedRoot: 'C',
      expectedBass: 'G',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description:
          'root-position split-ninth add triad beats remote unusual seventh slash',
      expectedSymbol: 'C(addb9,add9)',
      pcs: ['C', 'Db', 'D', 'E', 'G'],
      bass: 'C',
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.addFlat9, ChordExtension.add9},
    ),

    golden(
      description:
          'split-ninth add triad inversion beats sharp-five thirteenth stack',
      expectedSymbol: 'C(addb9,add9)/E',
      pcs: ['C', 'Db', 'D', 'E', 'G'],
      bass: 'E',
      expectedRoot: 'C',
      expectedBass: 'E',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.addFlat9, ChordExtension.add9},
    ),

    golden(
      description:
          'complete add-nine triad inversion beats sparse major-thirteenth shell',
      expectedSymbol: 'Bbmadd9/Db',
      expectedAlternatives: ['Dbmaj13'],
      pcs: ['C', 'Db', 'F', 'Bb'],
      bass: 'Db',
      expectedRoot: 'Bb',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.minor,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description: 'root-position augmented add-tone beats altered dominant',
      expectedSymbol: 'Abaug(add9)',
      expectedAlternatives: ['C7#5/G#'],
      pcs: ['C', 'E', 'Ab', 'Bb'],
      bass: 'Ab',
      expectedRoot: 'Ab',
      expectedQuality: ChordQuality.augmented,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description:
          'complete altered dominant inversion beats augmented add-tone slash',
      expectedSymbol: 'C7#5/E',
      pcs: ['C', 'E', 'Ab', 'Bb'],
      bass: 'E',
      expectedRoot: 'C',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7Sharp5,
    ),

    golden(
      description: 'root-position double suspension beats dominant sus slash',
      expectedSymbol: 'Gsus2sus4',
      pcs: ['G', 'D', 'A', 'C'],
      bass: 'G',
      tonality: const Tonality(Tonic.d, TonalityMode.major),
      expectedRoot: 'G',
      expectedQuality: ChordQuality.sus2sus4,
      expectedToneRolesByInterval: {
        2: ChordToneRole.sus2,
        5: ChordToneRole.sus4,
      },
    ),

    golden(
      description: 'root-position minor-eleventh shell beats sus slash',
      expectedSymbol: 'Dm11',
      pcs: ['C', 'D', 'F', 'G'],
      bass: 'D',
      expectedRoot: 'D',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.eleven},
    ),

    golden(
      // Cm11/Bb and Eb6/9/Bb tie on cost; the natural-extension tie-break
      // selects the minor-eleventh reading.
      description: 'minor-eleventh slash beats major six-nine slash',
      expectedSymbol: 'Cm11/Bb',
      expectedAlternatives: ['Eb6/9/Bb', 'Bbsus4(add9,add13)'],
      pcs: ['C', 'Eb', 'F', 'G', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'C',
      expectedBass: 'Bb',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.eleven},
    ),

    golden(
      description: 'root-position minor six-nine beats half-diminished slash',
      expectedSymbol: 'Bbm6/9',
      pcs: ['C', 'Db', 'F', 'G', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'Bb',
      expectedQuality: ChordQuality.minor6,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description:
          'sixth-bass minor-six flat-nine beats suspended major-seventh slash',
      expectedSymbol: 'Cm6b9/A',
      pcs: ['C', 'Db', 'Eb', 'A'],
      bass: 'A',
      expectedRoot: 'C',
      expectedBass: 'A',
      expectedQuality: ChordQuality.minor6,
      expectedExtensions: {ChordExtension.flat9},
    ),

    golden(
      // Ebm13 and Gb6/9#11/Eb tie on cost; the natural-extension tie-break
      // selects the root-position minor thirteenth.
      description: 'minor-thirteenth beats lydian major six-nine slash',
      expectedSymbol: 'Ebm13',
      expectedAlternatives: ['Gb6/9#11/Eb'],
      pcs: ['C', 'Db', 'Eb', 'F#', 'Ab', 'Bb'],
      bass: 'Eb',
      expectedRoot: 'Eb',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.eleven, ChordExtension.thirteen},
    ),

    golden(
      // With its root sounding, the complete suspended major-thirteenth is
      // the root-position reading of this collection; the relative m13 and
      // Lydian six-nine slashes stay as alternatives.
      description: 'suspended major-thirteenth root bass beats slash readings',
      expectedSymbol: 'Dbmaj13sus4',
      expectedAlternatives: ['Ebm13/Db', 'Gb6/9#11/Db'],
      pcs: ['C', 'Db', 'Eb', 'F#', 'Ab', 'Bb'],
      bass: 'Db',
      expectedRoot: 'Db',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.major7sus4,
      expectedExtensions: {ChordExtension.nine, ChordExtension.thirteen},
    ),

    golden(
      // The stacked-natural minor thirteenth wins over the Lydian six-nine
      // slash on the natural-extension preference, matching the Eb-bass
      // sibling case.
      description: 'minor-thirteenth fifth bass beats lydian six-nine slash',
      expectedSymbol: 'Ebm13/Bb',
      expectedAlternatives: ['Gb6/9#11/Bb', 'Ab(11)/Bb', 'Dbmaj13sus4/Bb'],
      pcs: ['C', 'Db', 'Eb', 'F#', 'Ab', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'Eb',
      expectedBass: 'Bb',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.eleven, ChordExtension.thirteen},
    ),

    golden(
      description: 'root-position major-sixth sharp-eleven beats minor slash',
      expectedSymbol: 'Eb6#11',
      expectedAlternatives: ['Cm13/Eb'],
      pcs: ['C', 'Eb', 'G', 'A', 'Bb'],
      bass: 'Eb',
      expectedRoot: 'Eb',
      expectedQuality: ChordQuality.major6,
      expectedExtensions: {ChordExtension.sharp11},
    ),

    // B6/9#11 (1-6 of B Lydian) and the G#m13/B slash tie on cost; the
    // natural-extension tie-break selects the minor-thirteenth slash.
    golden(
      description: 'minor-thirteenth slash beats lydian six-nine sharp-eleven',
      expectedSymbol: 'G#m13/B',
      expectedAlternatives: ['B6/9#11', 'C#(11)/B'],
      pcs: ['B', 'C#', 'D#', 'E#', 'F#', 'G#'],
      bass: 'B',
      expectedRoot: 'G#',
      expectedBass: 'B',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.eleven, ChordExtension.thirteen},
    ),

    golden(
      description:
          'fifthless major-nine sharp-eleven beats major-nine flat-five',
      expectedSymbol: 'Dbmaj9#11',
      expectedAlternatives: ['Eb(13)/Db'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G'],
      bass: 'Db',
      expectedRoot: 'Db',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
      expectedToneRolesByInterval: {6: ChordToneRole.sharp11},
    ),

    golden(
      description:
          'fifthless major-seven sharp-eleven beats major-seven flat-five',
      expectedSymbol: 'Dbmaj7#11',
      expectedAlternatives: ['C#maj7b5'],
      pcs: ['C', 'Db', 'F', 'G'],
      bass: 'Db',
      expectedRoot: 'Db',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.sharp11},
      expectedToneRolesByInterval: {6: ChordToneRole.sharp11},
    ),

    golden(
      description: 'readable sharp-eleven major beats flat-five respelling',
      expectedSymbol: 'Ab(#11)/C',
      expectedAlternatives: ['G#(b5)/B#'],
      pcs: ['C', 'D', 'Ab'],
      bass: 'C',
      expectedRoot: 'Ab',
      expectedBass: 'C',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.sharp11},
      expectedToneRolesByInterval: {6: ChordToneRole.sharp11},
    ),

    golden(
      description:
          'major sharp-eleven inversion beats sparse major-thirteen sus4',
      expectedSymbol: 'Gb(#11)/Db',
      expectedAlternatives: ['Dbmaj13sus4'],
      pcs: ['C', 'Db', 'Gb', 'Bb'],
      bass: 'Db',
      expectedRoot: 'Gb',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.sharp11},
      expectedToneRolesByInterval: {6: ChordToneRole.sharp11},
    ),

    golden(
      description:
          'sharp-eleven color bass does not displace sparse major-thirteen sus4',
      expectedSymbol: 'Dbmaj13sus4/C',
      expectedAlternatives: ['Gb(#11)/C'],
      pcs: ['C', 'Db', 'Gb', 'Bb'],
      bass: 'C',
      expectedRoot: 'Db',
      expectedBass: 'C',
      expectedQuality: ChordQuality.major7sus4,
      expectedExtensions: {ChordExtension.thirteen},
    ),

    golden(
      description:
          'lydian add-color triad displaces suspended major-thirteenth slash',
      expectedSymbol: 'Gb(#11,add9)',
      pcs: ['C', 'Db', 'Gb', 'Ab', 'Bb'],
      bass: 'Gb',
      expectedRoot: 'Gb',
      expectedBass: 'Gb',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.sharp11, ChordExtension.add9},
    ),

    golden(
      description: 'root-position sharp-eleven sus beats add-flat-nine slash',
      expectedSymbol: 'Gsus4#11',
      pcs: ['C', 'Db', 'D', 'G'],
      bass: 'G',
      expectedRoot: 'G',
      expectedBass: 'G',
      expectedQuality: ChordQuality.sus4,
      expectedExtensions: {ChordExtension.sharp11},
      expectedToneRolesByInterval: {6: ChordToneRole.sharp11},
    ),

    golden(
      description:
          'add-eleven inversion beats missing-third unusual seventh spelling',
      expectedSymbol: 'Aadd11/C#',
      pcs: ['C', 'Db', 'D', 'A'],
      bass: 'Db',
      expectedRoot: 'A',
      expectedBass: 'C#',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.add11},
    ),

    golden(
      description:
          'minor add-eleven slash beats missing-third unusual seventh spelling',
      expectedSymbol: 'Am/D',
      pcs: ['C', 'Db', 'D', 'A'],
      bass: 'D',
      expectedRoot: 'A',
      expectedBass: 'D',
      expectedQuality: ChordQuality.minor,
      expectedExtensions: {ChordExtension.add11},
    ),

    golden(
      description:
          'major-nine slash beats fifthless sus2 thirteenth reinterpretation',
      expectedSymbol: 'Dbmaj7/Eb',
      pcs: ['C', 'Db', 'Eb', 'F'],
      bass: 'Eb',
      expectedRoot: 'Db',
      expectedBass: 'Eb',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description:
          'chromatic add-chord does not displace major-nine slash alternative',
      expectedSymbol: 'Dbmaj9/C',
      pcs: ['C', 'Db', 'Eb', 'F'],
      bass: 'C',
      expectedRoot: 'Db',
      expectedBass: 'C',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description:
          'seventh-bass thirteenth beats fifthless major-nine '
          'sharp-eleven inversion',
      expectedSymbol: 'Eb(13)/C',
      expectedAlternatives: ['Dbmaj9#11/C'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G'],
      bass: 'C',
      expectedRoot: 'Eb',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.thirteen},
      expectedToneRolesByInterval: {9: ChordToneRole.thirteen},
    ),

    golden(
      description:
          'lydian major-nine beats natural-eleventh major-thirteenth inversion',
      expectedSymbol: 'Dbmaj9#11/G',
      expectedAlternatives: ['Abmaj13/G'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G', 'Ab'],
      bass: 'G',
      expectedRoot: 'Db',
      expectedBass: 'G',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
      expectedToneRolesByInterval: {6: ChordToneRole.sharp11},
    ),

    golden(
      description:
          'supported minor-thirteenth beats natural-eleventh major thirteenth',
      expectedSymbol: 'Ebm13/Db',
      pcs: ['C', 'Db', 'Eb', 'F', 'F#', 'Bb'],
      bass: 'Db',
      expectedRoot: 'Eb',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.thirteen},
    ),

    golden(
      description:
          'dominant thirteenth inversion beats fifthless lydian major thirteenth',
      expectedSymbol: 'Eb(13)/Db',
      expectedAlternatives: ['Bbm6/9add11/Db'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G', 'Bb'],
      bass: 'Db',
      expectedRoot: 'Eb',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.thirteen},
    ),

    golden(
      description: 'dominant thirteenth ninth bass beats minor-six added tones',
      expectedSymbol: 'Eb(13)/F',
      expectedAlternatives: ['Bbm6/9add11/F', 'F9sus4(b13)'],
      pcs: ['C', 'Db', 'Eb', 'F', 'G', 'Bb'],
      bass: 'F',
      expectedRoot: 'Eb',
      expectedBass: 'F',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.thirteen},
    ),

    golden(
      description: 'fifthless dominant nine flat-five beats sharp-eleven',
      expectedSymbol: 'D9b5',
      expectedAlternatives: ['E9#5/D'],
      pcs: ['C', 'D', 'E', 'F#', 'Ab'],
      bass: 'D',
      expectedRoot: 'D',
      expectedQuality: ChordQuality.dominant7Flat5,
      expectedExtensions: {ChordExtension.nine},
      expectedToneRolesByInterval: {6: ChordToneRole.flat5},
    ),

    golden(
      description:
          'seventh-bass flat-five dominant beats altered-fifth bass dominant',
      expectedSymbol: 'D9b5/C',
      expectedAlternatives: ['E9#5/C', 'Ab7(#5,#11)/C'],
      pcs: ['C', 'D', 'E', 'F#', 'Ab'],
      bass: 'C',
      expectedRoot: 'D',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7Flat5,
      expectedExtensions: {ChordExtension.nine},
      expectedToneRolesByInterval: {6: ChordToneRole.flat5},
    ),

    golden(
      description: 'fifthless thirteenth beats altered sus slash',
      expectedSymbol: 'Eb(13)',
      pcs: ['C', 'Db', 'Eb', 'F', 'G'],
      bass: 'Eb',
      expectedRoot: 'Eb',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.thirteen},
    ),

    golden(
      description: 'altered fifth dominant beats flat-thirteen stack',
      expectedSymbol: 'C9(#5,#11)',
      expectedAlternatives: ['Ab(9,#5,#11)/C'],
      pcs: ['C', 'D', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'C',
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7Sharp5,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
      expectedToneRolesByInterval: {8: ChordToneRole.sharp5},
    ),

    golden(
      description:
          'complete lydian flat-thirteen dominant beats remote altered fifth dominant',
      expectedSymbol: 'F#(9,#11,b13)/C',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'C',
      expectedRoot: 'F#',
      expectedBass: 'B#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    golden(
      description:
          'complete lydian flat-thirteen dominant handles flat-thirteen bass',
      expectedSymbol: 'F#(9,#11,b13)/D',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'D',
      expectedRoot: 'F#',
      expectedBass: 'D',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    golden(
      description:
          'complete lydian flat-thirteen dominant handles major-third bass',
      expectedSymbol: 'F#(9,#11,b13)/A#',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'F#',
      expectedBass: 'A#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    golden(
      description:
          'complete lydian thirteenth dominant handles flat-seventh bass',
      expectedSymbol: 'F#(13,#11)/E',
      pcs: ['C', 'Db', 'Eb', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'E',
      expectedRoot: 'F#',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'complete lydian thirteenth dominant handles major-third bass',
      expectedSymbol: 'F#(13,#11)/A#',
      pcs: ['C', 'Db', 'Eb', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'F#',
      expectedBass: 'A#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'complete altered flat-nine dominant beats remote minor thirteenth',
      expectedSymbol: 'C9(b9,#11)',
      expectedAlternatives: ['F#7(b9,#11,b13)/C'],
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'G', 'Bb'],
      bass: 'C',
      expectedRoot: 'C',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.flat9,
        ChordExtension.nine,
        ChordExtension.sharp11,
      },
    ),

    golden(
      description:
          'complete altered flat-nine dominant handles flat-thirteen bass',
      expectedSymbol: 'C9(b9,#11)/D',
      expectedAlternatives: ['F#7(b9,#11,b13)/D'],
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'G', 'Bb'],
      bass: 'D',
      expectedRoot: 'C',
      expectedBass: 'D',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.flat9,
        ChordExtension.nine,
        ChordExtension.sharp11,
      },
    ),

    golden(
      description:
          'complete altered flat-nine dominant handles flat-seventh bass',
      expectedSymbol: 'F#7(b9,#11,b13)/E',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'G', 'Bb'],
      bass: 'E',
      expectedRoot: 'F#',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.flat9,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    golden(
      description:
          'complete altered flat-nine dominant handles major-third bass',
      expectedSymbol: 'F#7(b9,#11,b13)/A#',
      pcs: ['C', 'Db', 'D', 'E', 'F#', 'G', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'F#',
      expectedBass: 'A#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.flat9,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    golden(
      description:
          'altered sharp-five dominant beats natural-eleventh sharp-five dominant',
      expectedSymbol: 'F#(9,#11)/E',
      pcs: ['C', 'Db', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'E',
      expectedRoot: 'F#',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
    ),

    golden(
      description:
          'altered sharp-five dominant beats root-position natural-eleventh sharp-five dominant',
      expectedSymbol: 'F#(9,#11)/G#',
      pcs: ['C', 'Db', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'Ab',
      expectedRoot: 'F#',
      expectedBass: 'G#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
    ),

    golden(
      description:
          'altered sharp-five dominant beats ninth-bass natural-eleventh sharp-five dominant',
      expectedSymbol: 'F#(9,#11)/A#',
      pcs: ['C', 'Db', 'E', 'F#', 'Ab', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'F#',
      expectedBass: 'A#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.sharp11},
    ),

    golden(
      // The minor sharp-five respelling of the same stack no longer
      // surfaces; the rare-vocabulary cost keeps the flat-side spelling.
      description: 'relative minor-thirteenth names locrian collection',
      expectedSymbol: 'Ebm13/C',
      pcs: ['C', 'Db', 'Eb', 'F', 'F#', 'Ab', 'Bb'],
      bass: 'C',
      expectedRoot: 'Eb',
      expectedBass: 'C',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.eleven,
        ChordExtension.thirteen,
      },
    ),

    golden(
      description:
          'common altered dominant beats rarer enharmonic ninth inversion',
      expectedSymbol: 'F9b5/A',
      expectedAlternatives: ['G7#5/A', 'B7(#5,#11)/A'],
      pcs: ['A', 'G', 'D#', 'F', 'B'],
      bass: 'A',
      tonality: const Tonality(Tonic.b, TonalityMode.minor),
      expectedRoot: 'F',
      expectedBass: 'A',
      expectedQuality: ChordQuality.dominant7Flat5,
      expectedExtensions: {ChordExtension.nine},
    ),

    // -------------------------------------------------------------------------
    // Root-position add-chord beats dominant sus slash
    // -------------------------------------------------------------------------
    golden(
      description: 'root-position add-chord beats dominant sus slash',
      expectedSymbol: 'Abadd9',
      pcs: ['C', 'Eb', 'Ab', 'Bb'],
      bass: 'Ab',
      expectedRoot: 'Ab',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.add9},
    ),

    // -------------------------------------------------------------------------
    // Root-position dominant sus beats conventional add-tone slash
    // -------------------------------------------------------------------------
    golden(
      description:
          'root-position dominant sus beats conventional add-tone slash',
      expectedSymbol: 'Eb(13sus4)',
      pcs: ['C', 'Db', 'Eb', 'Ab'],
      bass: 'Eb',
      expectedRoot: 'Eb',
      expectedBass: 'Eb',
      expectedQuality: ChordQuality.dominant7sus4,
      expectedExtensions: {ChordExtension.thirteen},
    ),

    // -------------------------------------------------------------------------
    // Bare flat-seven shell: complete triad keeps the top, the omitted-third
    // dominant reading surfaces beside it (research/tone-pricing/ log -13)
    // -------------------------------------------------------------------------
    golden(
      description:
          'complete minor triad slash keeps the top over the bare shell, '
          'which surfaces as the omitted-third dominant alternative',
      expectedSymbol: 'Am/D',
      expectedAlternatives: ['D7(omit3)'],
      pcs: ['C', 'D', 'A'],
      bass: 'D',
      expectedRoot: 'A',
      expectedBass: 'D',
      expectedQuality: ChordQuality.minor,
    ),
  ];

  runChordAnalyzerGoldenCases(cases);

  test('rejects missing-seventh thirteenth slash candidates', () {
    final input = chordInputFromNames(
      names: ['C', 'G', 'Bb', 'D', 'E'],
      bass: 'C',
    );
    final results = _analyzer.analyze(
      input,
      context: makeAnalysisContext(),
      take: 40,
    );
    final symbols = results
        .map(
          (candidate) => ChordSymbolBuilder.fromIdentity(
            identity: candidate.identity,
            tonality: defaultTestTonality,
            notation: ChordNotationStyle.textual,
          ).toString(),
        )
        .toSet();

    expect(symbols, contains('Gm6/C'));
    expect(symbols, isNot(contains('Gm13/C')));
    expect(symbols, isNot(contains('Gm(maj13)/C')));
    expect(symbols, isNot(contains('Bb(13,#11)/C')));
  });
}
