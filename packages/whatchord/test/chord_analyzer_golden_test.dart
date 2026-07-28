import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

import 'helpers/chord_analyzer_golden_helpers.dart';
import 'package:whatchord/testing.dart';

final _analyzer = ChordAnalyzer();

void main() {
  final cases = <GoldenCase>[
    // -------------------------------------------------------------------------
    // Major / dominant / extended tertian harmony
    // -------------------------------------------------------------------------
    golden(
      description: 'plain major triad',
      expectedSymbol: 'C',
      pcs: ['C', 'E', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major,
    ),

    golden(
      description: 'major triad with added ninth',
      expectedSymbol: 'Cadd9',
      pcs: ['C', 'E', 'G', 'D'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description: 'major triad with split third as added sharp ninth',
      expectedSymbol: 'Cadd#9',
      pcs: ['C', 'Eb', 'E', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.addSharp9},
      expectedToneRolesByInterval: {3: ChordToneRole.splitMinor3},
    ),

    golden(
      description: 'split third shell without fifth',
      expectedSymbol: 'Cadd#9',
      pcs: ['C', 'Eb', 'E'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.addSharp9},
      expectedToneRolesByInterval: {3: ChordToneRole.splitMinor3},
    ),

    golden(
      description: 'major sixth with split third as added sharp ninth',
      expectedSymbol: 'C6add#9',
      pcs: ['C', 'Eb', 'E', 'G', 'A'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major6,
      expectedExtensions: {ChordExtension.addSharp9},
      expectedToneRolesByInterval: {3: ChordToneRole.splitMinor3},
    ),

    golden(
      description: 'split-third major triad in second inversion',
      expectedSymbol: 'Aadd#9/E',
      expectedAlternatives: ['C#m(maj7,b13)/E', 'C6b9/E'],
      pcs: ['C', 'Db', 'E', 'A'],
      bass: 'E',
      expectedRoot: 'A',
      expectedBass: 'E',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.addSharp9},
      expectedToneRolesByInterval: {3: ChordToneRole.splitMinor3},
    ),

    golden(
      description: 'split-third major triad in first inversion',
      expectedSymbol: 'Aadd#9/C#',
      expectedAlternatives: ['C#m(maj7,b13)'],
      pcs: ['C', 'Db', 'E', 'A'],
      bass: 'Db',
      expectedRoot: 'A',
      expectedBass: 'C#',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.addSharp9},
      expectedToneRolesByInterval: {3: ChordToneRole.splitMinor3},
    ),

    golden(
      description: 'harmonic-minor tonic beats split-third major inversion',
      expectedSymbol: 'C#m(maj7,b13)',
      expectedAlternatives: ['Aadd#9/C#'],
      pcs: ['C', 'Db', 'E', 'A'],
      bass: 'Db',
      tonality: const Tonality(Tonic.cSharp, TonalityMode.minor),
      expectedRoot: 'C#',
      expectedBass: 'C#',
      expectedQuality: ChordQuality.minorMajor7,
      expectedExtensions: {ChordExtension.flat13},
    ),

    golden(
      description:
          'transposed harmonic-minor tonic beats split-third major inversion',
      expectedSymbol: 'Fm(maj7,b13)',
      expectedAlternatives: ['Dbadd#9/F'],
      pcs: ['E', 'F', 'Ab', 'Db'],
      bass: 'F',
      tonality: const Tonality(Tonic.f, TonalityMode.minor),
      expectedRoot: 'F',
      expectedBass: 'F',
      expectedQuality: ChordQuality.minorMajor7,
      expectedExtensions: {ChordExtension.flat13},
    ),

    golden(
      description: 'split-third color bass does not become major inversion',
      expectedSymbol: 'C6b9',
      pcs: ['C', 'Db', 'E', 'A'],
      bass: 'C',
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major6,
      expectedExtensions: {ChordExtension.flat9},
    ),

    golden(
      description: 'straight dominant seventh',
      expectedSymbol: 'C7',
      pcs: ['C', 'E', 'G', 'Bb'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectNoExtensions: true,
    ),

    golden(
      description: 'dominant ninth',
      expectedSymbol: 'C9',
      pcs: ['C', 'E', 'G', 'Bb', 'D'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description: 'dominant eleventh without ninth beats sus slash',
      expectedSymbol: 'C11',
      expectedAlternatives: ['Fmaj9sus4/C'],
      pcs: ['C', 'E', 'G', 'Bb', 'F'],
      bass: 'C',
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.eleven},
    ),

    golden(
      description: 'dominant eleventh with ninth present',
      expectedSymbol: 'C11',
      pcs: ['C', 'E', 'G', 'Bb', 'D', 'F'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.eleven},
    ),

    golden(
      description: 'major ninth',
      expectedSymbol: 'Cmaj9',
      pcs: ['C', 'E', 'G', 'B', 'D'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description: 'altered major seventh keeps sharp ninth color',
      expectedSymbol: 'Dmaj7(#9,b13)/A',
      pcs: ['A', 'D', 'F', 'F#', 'A#', 'C#'],
      bass: 'A',
      expectedRoot: 'D',
      expectedBass: 'A',
      expectedQuality: ChordQuality.major7,
      expectedExtensions: {ChordExtension.sharp9, ChordExtension.flat13},
      expectedToneRolesByInterval: {3: ChordToneRole.sharp9},
    ),

    // 13th (as 7 + 9 + 13).
    golden(
      description: 'dominant thirteenth with ninth',
      expectedSymbol: 'C13',
      pcs: ['C', 'E', 'G', 'Bb', 'D', 'A'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine, ChordExtension.thirteen},
    ),

    // The fifth is optional in extended dominant voicings.
    golden(
      description: 'dominant thirteenth sharp eleventh with omitted fifth',
      expectedSymbol: 'C13#11',
      pcs: ['C', 'E', 'Bb', 'D', 'F#', 'A'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.nine,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    // -------------------------------------------------------------------------
    // Slash bass / inversions (explicit bass handling)
    // -------------------------------------------------------------------------

    // Same sonority as C9, but with a non-root bass should render a slash chord.
    golden(
      description: 'dominant ninth over fifth in the bass',
      expectedSymbol: 'C9/G',
      pcs: ['C', 'E', 'G', 'Bb', 'D'],
      bass: 'G',
      expectedRoot: 'C',
      expectedBass: 'G',
      expectedQuality: ChordQuality.dominant7,
    ),

    golden(
      description: 'major sixth in first inversion',
      expectedSymbol: 'C6/E',
      pcs: ['C', 'E', 'G', 'A'],
      bass: 'E',
      expectedRoot: 'C',
      expectedBass: 'E',
      expectedQuality: ChordQuality.major6,
    ),

    // Doubling the bass does not make a fifthless sixth chord more complete.
    // Prefer the complete inverted minor triad.
    golden(
      description: 'complete minor inversion beats doubled fifthless sixth',
      expectedSymbol: 'Am/C',
      pcs: ['C', 'E', 'A'],
      noteCount: 4,
      expectedRoot: 'A',
      expectedBass: 'C',
      expectedQuality: ChordQuality.minor,
    ),

    // -------------------------------------------------------------------------
    // Altered/colored dominants
    // -------------------------------------------------------------------------
    golden(
      description: 'dominant seventh flat ninth',
      expectedSymbol: 'C7b9',
      pcs: ['C', 'E', 'G', 'Bb', 'Db'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9},
    ),

    golden(
      description: 'root-position sharp-five flat-nine dominant',
      expectedSymbol: 'C7(#5,b9)',
      expectedAlternatives: ['C#m(maj13)/B#', 'C7(b9,b13)'],
      pcs: ['C', 'Db', 'E', 'Ab', 'Bb'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7Sharp5,
      expectedExtensions: {ChordExtension.flat9},
    ),

    // In neutral context, prefer the familiar fifthless altered-dominant shell
    // while retaining the bass-rooted reinterpretations as ranked candidates.
    golden(
      description: 'flat-nine-bass dominant without fifth',
      expectedSymbol: 'C7b9/Db',
      expectedAlternatives: ['C#m(maj13)', 'A#dim(add9)/C#'],
      pcs: ['C', 'Db', 'E', 'Bb'],
      bass: 'Db',
      expectedRoot: 'C',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9},
    ),

    golden(
      description: 'root-position diminished add-nine beats deficient slash',
      expectedSymbol: 'A#dim(add9)',
      expectedAlternatives: ['C7b9/Bb'],
      pcs: ['C', 'Db', 'E', 'Bb'],
      bass: 'Bb',
      expectedRoot: 'A#',
      expectedQuality: ChordQuality.diminished,
      expectedExtensions: {ChordExtension.add9},
    ),

    golden(
      description: 'tonic minor-major7 context beats flat-nine-bass dominant',
      expectedSymbol: 'C#m(maj13)',
      pcs: ['C', 'Db', 'E', 'Bb'],
      bass: 'Db',
      tonality: const Tonality(Tonic.cSharp, TonalityMode.minor),
      expectedRoot: 'Db',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.minorMajor7,
      expectedExtensions: {ChordExtension.thirteen},
    ),

    golden(
      description: 'split-ninth flat-nine-bass dominant beats minor-major root',
      expectedSymbol: 'C9b9/Db',
      expectedAlternatives: ['C#m(maj13,b9)'],
      pcs: ['C', 'Db', 'D', 'E', 'Bb'],
      bass: 'Db',
      expectedRoot: 'C',
      expectedBass: 'Db',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.nine},
    ),

    // Hendrix chord: dominant shell plus #9 should not be treated as a minor-third penalty.
    golden(
      description: 'dominant seventh sharp ninth',
      expectedSymbol: 'G7#9',
      pcs: ['G', 'B', 'D', 'F', 'A#'],
      expectedRoot: 'G',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.sharp9},
    ),

    golden(
      description:
          'minor ninth slash beats exact altered major seventh bookkeeping',
      expectedSymbol: 'Dm9/C',
      expectedAlternatives: ['Dbmaj7(b9,#9)/C'],
      pcs: ['C', 'Db', 'D', 'E', 'F'],
      bass: 'C',
      expectedRoot: 'D',
      expectedBass: 'C',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description:
          'minor ninth first inversion beats exact altered major seventh bookkeeping',
      expectedSymbol: 'Dm9/F',
      expectedAlternatives: ['Dbmaj7(b9,#9)/F'],
      pcs: ['C', 'Db', 'D', 'E', 'F'],
      bass: 'F',
      expectedRoot: 'D',
      expectedBass: 'F',
      expectedQuality: ChordQuality.minor7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description:
          'dominant ninth slash beats exact minor-major flat-nine bookkeeping',
      expectedSymbol: 'D9/C',
      pcs: ['C', 'Db', 'D', 'E', 'F#'],
      bass: 'C',
      expectedRoot: 'D',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description:
          'dominant seventh over ninth bass beats exact altered bookkeeping',
      expectedSymbol: 'D7/E',
      pcs: ['C', 'Db', 'D', 'E', 'F#'],
      bass: 'E',
      expectedRoot: 'D',
      expectedBass: 'E',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description: 'dominant seventh with flat ninth and sharp eleventh',
      expectedSymbol: 'C7(b9,#11)',
      pcs: ['C', 'E', 'G', 'Bb', 'Db', 'F#'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9, ChordExtension.sharp11},
    ),

    golden(
      description: 'dominant seventh with three altered extensions',
      expectedSymbol: 'C7(b9,#11,b13)',
      pcs: ['C', 'E', 'G', 'Bb', 'Db', 'F#', 'Ab'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.flat9,
        ChordExtension.sharp11,
        ChordExtension.flat13,
      },
    ),

    // A natural thirteenth over a full stack still headlines as 13 even when the
    // intervening ninth/eleventh are altered: C7(#9,#11,add13) collapses to
    // C13(#9,#11).
    golden(
      description: 'thirteenth headline with altered ninth and eleventh',
      expectedSymbol: 'C13(#9,#11)',
      pcs: ['C', 'E', 'G', 'Bb', 'D#', 'F#', 'A'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {
        ChordExtension.sharp9,
        ChordExtension.sharp11,
        ChordExtension.thirteen,
      },
    ),

    // Dominant 7 suspended 4 with 9 should promote to the combined headline.
    golden(
      description: 'dominant ninth suspended fourth',
      expectedSymbol: 'C9sus4',
      pcs: ['C', 'F', 'G', 'Bb', 'D'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7sus4,
      expectedExtensions: {ChordExtension.nine},
    ),

    golden(
      description: 'dominant seventh suspended second respells as minor slash',
      expectedSymbol: 'Gm/C',
      pcs: ['C', 'D', 'G', 'Bb'],
      expectedRoot: 'G',
      expectedQuality: ChordQuality.minor,
    ),

    // Power chord: a bare fifth is named directly rather than borrowing a
    // third or suspension to fill out a triad.
    golden(
      description: 'bare fifth names a power chord',
      expectedSymbol: 'C5',
      pcs: ['C', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.power,
    ),

    golden(
      description: 'power chord fifth in the bass',
      expectedSymbol: 'C5/G',
      pcs: ['C', 'G'],
      bass: 'G',
      expectedRoot: 'C',
      expectedBass: 'G',
      expectedQuality: ChordQuality.power,
    ),

    // A sparse fifth-plus-color voicing reads as the power chord carrying that
    // color, not a remote third-bearing fragment.
    golden(
      description: 'power chord carries flat-nine color',
      expectedSymbol: 'C5addb9',
      pcs: ['C', 'Db', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.power,
      expectedExtensions: {ChordExtension.addFlat9},
    ),

    // A genuine suspended second is more idiomatic than reading its 2nd as an
    // added tone over a power chord.
    golden(
      description: 'genuine sus2 beats power chord add-nine',
      expectedSymbol: 'Csus2',
      pcs: ['C', 'D', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.sus2,
    ),

    // The bare flat-seven shell in root position: the dominant reading
    // carries the omitted-third marker (Brandt/Roemer's D7(omit 3)) and
    // surfaces beside the complete-triad slash, never above it.
    golden(
      description: 'bare shell surfaces the omitted-third dominant reading',
      expectedSymbol: 'Gm/C',
      expectedAlternatives: ['C7(omit3)'],
      pcs: ['C', 'G', 'Bb'],
      bass: 'C',
      expectedRoot: 'G',
      expectedBass: 'C',
      expectedQuality: ChordQuality.minor,
    ),

    golden(
      description: 'major seventh suspended second',
      expectedSymbol: 'Cmaj7sus2',
      pcs: ['C', 'D', 'G', 'B'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major7sus2,
    ),

    golden(
      description: 'major seventh suspended fourth',
      expectedSymbol: 'Cmaj7sus4',
      pcs: ['C', 'F', 'G', 'B'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major7sus4,
    ),

    golden(
      description: 'major ninth suspended fourth',
      expectedSymbol: 'Dbmaj9sus4',
      pcs: ['C', 'Db', 'Eb', 'F#', 'Ab'],
      bass: 'Db',
      expectedRoot: 'Db',
      expectedQuality: ChordQuality.major7sus4,
      expectedExtensions: {ChordExtension.nine},
    ),

    // Dominant 7 sharp 5 should treat the augmented fifth as a core tone.
    golden(
      description: 'dominant seventh sharp fifth',
      expectedSymbol: 'C7#5',
      pcs: ['C', 'E', 'G#', 'Bb'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7Sharp5,
      expectedToneRolesByInterval: {8: ChordToneRole.sharp5},
    ),

    // The pitch-class set also admits Cm#5, but a complete first-inversion
    // major triad is the more conventional default for MIDI-style input.
    golden(
      description: 'first-inversion major triad beats minor sharp fifth',
      expectedSymbol: 'Ab/C',
      pcs: ['C', 'Eb', 'G#'],
      expectedRoot: 'Ab',
      expectedBass: 'C',
      expectedQuality: ChordQuality.major,
    ),

    // The same inversion-over-minorSharp5 preference that produces F(#11)/A for
    // {A, C, F, B} also applies here: Ab major (Ab, C, Eb) is a complete triad
    // in first inversion with D as #11, which is more natural than reading D as
    // add9 on the less common Cm#5 quality.
    golden(
      description:
          'major triad inversion beats minor sharp-five with added ninth',
      expectedSymbol: 'Ab(#11)/C',
      pcs: ['C', 'Eb', 'G#', 'D'],
      expectedRoot: 'Ab',
      expectedBass: 'C',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.sharp11},
      expectedToneRolesByInterval: {6: ChordToneRole.sharp11},
    ),

    // Minor 7 sharp 5 is rare vocabulary; its canonical voicing reads as the
    // more common first-inversion add-nine major it respells.
    golden(
      description:
          'minor seventh sharp fifth respells as inverted add-nine major',
      expectedSymbol: 'Abadd9/C',
      pcs: ['C', 'Eb', 'G#', 'Bb'],
      expectedRoot: 'Ab',
      expectedQuality: ChordQuality.major,
      expectedToneRolesByInterval: {2: ChordToneRole.add9},
    ),

    // Dominant 7 flat 5 should treat the diminished fifth as a core tone.
    golden(
      description: 'dominant seventh flat fifth',
      expectedSymbol: 'C7b5',
      pcs: ['C', 'E', 'Gb', 'Bb'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7Flat5,
      expectedToneRolesByInterval: {6: ChordToneRole.flat5},
    ),

    // Major 7 sharp 5 should treat the augmented fifth as a core tone.
    golden(
      description: 'major seventh sharp fifth',
      expectedSymbol: 'Cmaj7#5',
      pcs: ['C', 'E', 'G#', 'B'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major7Sharp5,
      expectedToneRolesByInterval: {8: ChordToneRole.sharp5},
    ),

    // Major 7 flat 5 should treat the diminished fifth as a core tone.
    golden(
      description: 'major seventh flat fifth',
      expectedSymbol: 'Cmaj7b5',
      pcs: ['C', 'E', 'Gb', 'B'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major7Flat5,
      expectedToneRolesByInterval: {6: ChordToneRole.flat5},
    ),

    // Major flat 5: three-note root+M3+tritone. The tritone replaces the fifth,
    // so it reads as a flat-five chord rather than a major triad with a #11
    // extension. When the natural fifth (P5) is absent, the flat-five template
    // wins cleanly; adding P5 to the voicing shifts the winner back to the
    // plain major template with a #11 extension.
    golden(
      description: 'major flat fifth triad (tritone replaces fifth)',
      expectedSymbol: 'C(b5)',
      pcs: ['C', 'E', 'Gb'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.majorFlat5,
      expectNoExtensions: true,
      expectedToneRolesByInterval: {6: ChordToneRole.flat5},
    ),

    // The oracle case: Ab-C-D in a flat-key context spells as Ab(b5).
    golden(
      description: 'major flat fifth triad in flat key context',
      expectedSymbol: 'Ab(b5)',
      pcs: ['Ab', 'C', 'D'],
      bass: 'Ab',
      tonality: Tonality(Tonic.aFlat, TonalityMode.major),
      expectedRoot: 'Ab',
      expectedQuality: ChordQuality.majorFlat5,
      expectNoExtensions: true,
      expectedToneRolesByInterval: {6: ChordToneRole.flat5},
    ),

    golden(
      description:
          'major flat fifth triad with P5 present reverts to major #11',
      expectedSymbol: 'Ab(#11)',
      pcs: ['Ab', 'C', 'Eb', 'D'],
      bass: 'Ab',
      expectedRoot: 'Ab',
      expectedQuality: ChordQuality.major,
      expectedExtensions: {ChordExtension.sharp11},
    ),

    // Altered augmented dominants keep both the #5 core tone and #9 color.
    golden(
      description: 'altered augmented dominant with sharp ninth',
      expectedSymbol: 'C7(#5,#9)',
      pcs: ['C', 'E', 'G#', 'Bb', 'D#'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7Sharp5,
      expectedExtensions: {ChordExtension.sharp9},
      expectedToneRolesByInterval: {8: ChordToneRole.sharp5},
    ),

    // Altered flat-five dominants keep both the b5 core tone and #9 color.
    golden(
      description: 'altered flat-five dominant with sharp ninth',
      expectedSymbol: 'C7(b5,#9)',
      pcs: ['C', 'E', 'Gb', 'Bb', 'D#'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7Flat5,
      expectedExtensions: {ChordExtension.sharp9},
      expectedToneRolesByInterval: {6: ChordToneRole.flat5},
    ),

    // -------------------------------------------------------------------------
    // Suspended chords
    // -------------------------------------------------------------------------
    golden(
      description: 'suspended fourth triad',
      expectedSymbol: 'Csus4',
      pcs: ['C', 'F', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.sus4,
    ),

    golden(
      description: 'suspended second triad',
      expectedSymbol: 'Csus2',
      pcs: ['C', 'D', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.sus2,
    ),

    golden(
      description: 'double-suspended chord',
      expectedSymbol: 'Csus2sus4',
      pcs: ['C', 'D', 'F', 'G'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.sus2sus4,
      expectedToneRolesByInterval: {
        2: ChordToneRole.sus2,
        5: ChordToneRole.sus4,
      },
    ),

    // -------------------------------------------------------------------------
    // 6th-family
    // -------------------------------------------------------------------------
    golden(
      description: 'major sixth',
      expectedSymbol: 'C6',
      pcs: ['C', 'E', 'G', 'A'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major6,
    ),

    golden(
      description: 'minor sixth',
      expectedSymbol: 'Am6',
      pcs: ['A', 'C', 'E', 'F#'],
      expectedRoot: 'A',
      expectedQuality: ChordQuality.minor6,
    ),

    // 6/9 sonority: represented as major6 + add9 in this system.
    golden(
      description: 'six-nine sonority',
      expectedSymbol: 'C6/9',
      pcs: ['C', 'E', 'G', 'A', 'D'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.major6,
      expectedExtensions: {ChordExtension.add9},
    ),

    // Dominant 7 with a lone 13 (no ninth) is a 13th chord; the ninth and
    // eleventh in the stack are optional.
    golden(
      description: 'dominant thirteenth without a ninth',
      expectedSymbol: 'C13',
      pcs: ['C', 'E', 'G', 'Bb', 'A'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.thirteen},
      unexpectedExtensions: {ChordExtension.add13},
    ),

    // -------------------------------------------------------------------------
    // Diminished-family (half-diminished and diminished7)
    // -------------------------------------------------------------------------
    golden(
      description: 'half-diminished seventh',
      expectedSymbol: 'Bm7(b5)',
      pcs: ['B', 'D', 'F', 'A'],
      expectedRoot: 'B',
      expectedQuality: ChordQuality.halfDiminished7,
    ),

    golden(
      description: 'half-diminished ninth headline',
      expectedSymbol: 'Cm9(b5)',
      pcs: ['C', 'Eb', 'Gb', 'Bb', 'D'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.halfDiminished7,
      expectedExtensions: {ChordExtension.nine},
    ),

    // Diminished seventh with color tones: verify extension mapping stays stable
    // unless the same pitch set forms a complete dominant flat-nine in a stable
    // inversion.
    golden(
      description: 'diminished seventh with added ninth',
      expectedSymbol: 'Cdim7(add9)',
      pcs: ['C', 'Eb', 'Gb', 'A', 'D'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.diminished7,
      expectedExtensions: {ChordExtension.nine},
    ),
    golden(
      description: 'complete dominant flat-nine beats diminished add-eleventh',
      expectedSymbol: 'F7b9/C',
      pcs: ['C', 'Eb', 'Gb', 'A', 'F'],
      expectedRoot: 'F',
      expectedBass: 'C',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9},
    ),
    golden(
      description: 'complete dominant flat-nine beats diminished flat-thirteen',
      expectedSymbol: 'G#7b9/B#',
      pcs: ['C', 'Eb', 'Gb', 'A', 'Ab'],
      expectedRoot: 'G#',
      expectedBass: 'B#',
      expectedQuality: ChordQuality.dominant7,
      expectedExtensions: {ChordExtension.flat9},
    ),
    golden(
      description: 'diminished seventh with flat ninth',
      expectedSymbol: 'Cdim7(b9)',
      pcs: ['C', 'Eb', 'Gb', 'A', 'Db'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.diminished7,
      expectedExtensions: {ChordExtension.flat9},
    ),

    // -------------------------------------------------------------------------
    // Shells / compact voicings
    // -------------------------------------------------------------------------
    golden(
      description: 'minor-major seventh shell without fifth',
      expectedSymbol: 'Cm(maj7)',
      pcs: ['C', 'Eb', 'B'],
      expectedRoot: 'C',
      expectedQuality: ChordQuality.minorMajor7,
    ),
  ];

  runChordAnalyzerGoldenCases(cases);

  test(
    'complete dominant flat-thirteen beats enharmonic major-nine sharp-five',
    () {
      for (final bass in ['C', 'A']) {
        final input = chordInputFromNames(
          names: ['C', 'Db', 'Eb', 'F', 'A'],
          bass: bass,
        );
        final results = _analyzer.analyze(
          input,
          context: makeAnalysisContext(),
        );

        expect(results.first.identity.rootPc, pc('F'));
        expect(results.first.identity.quality, ChordQuality.dominant7);
        expect(
          results.first.identity.extensions,
          contains(ChordExtension.flat13),
        );

        // The enharmonic Dbmaj9#5 stays ranked but no longer near-ties.
        expect(
          results,
          contains(
            isA<ChordCandidate>()
                .having((c) => c.identity.rootPc, 'root', pc('Db'))
                .having(
                  (c) => c.identity.quality,
                  'quality',
                  ChordQuality.major7Sharp5,
                ),
          ),
          reason: 'Dbmaj9#5 should stay a ranked reading for bass $bass',
        );
      }
    },
  );
}
