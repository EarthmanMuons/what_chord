import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

import 'package:whatchord/testing.dart';

/// The comping acceptance suite, ported case for case from
/// research/chord-context/data/sources/comping/comping-suite-v1.json
/// (chord-context-comping-suite/1). Rootless and shell cases run under
/// ensemble analysis; solo cases guard mode-off behavior. Keep in sync with
/// the JSON suite, which stays the ruler for the research harnesses.
final _analyzer = ChordAnalyzer();

const _cMajor = Tonality(Tonic.c, TonalityMode.major);
const _cMinor = Tonality(Tonic.c, TonalityMode.minor);
const _bFlatMajor = Tonality(Tonic.bFlat, TonalityMode.major);
const _eFlatMajor = Tonality(Tonic.eFlat, TonalityMode.major);

class _Case {
  const _Case(
    this.id,
    this.ensemble,
    this.tonality,
    this.midiNotes,
    this.rootPc,
    this.quality,
    this.extensions,
  );

  final String id;
  final bool ensemble;
  final Tonality tonality;
  final List<int> midiNotes;
  final int rootPc;
  final ChordQuality quality;
  final Set<ChordExtension> extensions;
}

const _cases = <_Case>[
  _Case(
    'rootless-ii-V-I-C-Aform-ii',
    true,
    _cMajor,
    [65, 69, 72, 76],
    2,
    ChordQuality.minor7,
    {ChordExtension.nine},
  ),
  _Case(
    'rootless-ii-V-I-C-Aform-V',
    true,
    _cMajor,
    [65, 69, 71, 76],
    7,
    ChordQuality.dominant7,
    {ChordExtension.nine, ChordExtension.thirteen},
  ),
  _Case(
    'rootless-ii-V-I-C-Aform-I',
    true,
    _cMajor,
    [64, 67, 71, 74],
    0,
    ChordQuality.major7,
    {ChordExtension.nine},
  ),
  _Case(
    'rootless-ii-V-I-C-Bform-ii',
    true,
    _cMajor,
    [60, 64, 65, 69],
    2,
    ChordQuality.minor7,
    {ChordExtension.nine},
  ),
  _Case(
    'rootless-ii-V-I-C-Bform-V',
    true,
    _cMajor,
    [59, 64, 65, 69],
    7,
    ChordQuality.dominant7,
    {ChordExtension.nine, ChordExtension.thirteen},
  ),
  _Case(
    'rootless-ii-V-I-C-Bform-I',
    true,
    _cMajor,
    [59, 62, 64, 67],
    0,
    ChordQuality.major7,
    {ChordExtension.nine},
  ),
  _Case(
    'rootless-ii-V-I-Bb-Aform-ii',
    true,
    _bFlatMajor,
    [63, 67, 70, 74],
    0,
    ChordQuality.minor7,
    {ChordExtension.nine},
  ),
  _Case(
    'rootless-ii-V-I-Bb-Aform-V',
    true,
    _bFlatMajor,
    [63, 67, 69, 74],
    5,
    ChordQuality.dominant7,
    {ChordExtension.nine, ChordExtension.thirteen},
  ),
  _Case(
    'rootless-ii-V-I-Bb-Aform-I',
    true,
    _bFlatMajor,
    [62, 65, 69, 72],
    10,
    ChordQuality.major7,
    {ChordExtension.nine},
  ),
  _Case(
    'rootless-13-guide-tones',
    true,
    _cMajor,
    [64, 70, 74, 81],
    0,
    ChordQuality.dominant7,
    {ChordExtension.nine, ChordExtension.thirteen},
  ),
  _Case(
    'guard-minor-ii-065-inversion',
    false,
    _cMinor,
    [65, 68, 72, 74],
    2,
    ChordQuality.halfDiminished7,
    {},
  ),
  _Case(
    'shell-3-7-9-Dm7',
    true,
    _cMajor,
    [65, 72, 76],
    2,
    ChordQuality.minor7,
    {ChordExtension.nine},
  ),
  _Case(
    'shell-3-7-13-G7',
    true,
    _cMajor,
    [65, 71, 76],
    7,
    ChordQuality.dominant7,
    {ChordExtension.thirteen},
  ),
  _Case(
    'solo-Ebmaj7-root-position',
    false,
    _eFlatMajor,
    [63, 67, 70, 74],
    3,
    ChordQuality.major7,
    {},
  ),
  _Case(
    'solo-Dm7-root-position',
    false,
    _cMajor,
    [62, 65, 69, 72],
    2,
    ChordQuality.minor7,
    {},
  ),
  _Case(
    'solo-Cmaj9-with-root',
    false,
    _cMajor,
    [60, 64, 67, 71, 74],
    0,
    ChordQuality.major7,
    {ChordExtension.nine},
  ),
  _Case(
    'solo-Am7-root-position',
    false,
    _cMajor,
    [57, 60, 64, 67],
    9,
    ChordQuality.minor7,
    {},
  ),
  _Case(
    'solo-C6-tonic',
    false,
    _cMajor,
    [60, 64, 67, 69],
    0,
    ChordQuality.major6,
    {},
  ),
];

void main() {
  for (final c in _cases) {
    test('comping suite: ${c.id}', () {
      var pcMask = 0;
      for (final note in c.midiNotes) {
        pcMask |= 1 << (note % 12);
      }
      final ranked = _analyzer.analyze(
        ChordInput(
          pcMask: pcMask,
          bassPc: c.midiNotes.first % 12,
          noteCount: c.midiNotes.length,
        ),
        context: makeAnalysisContext(
          tonality: c.tonality,
          playingContext: c.ensemble
              ? PlayingContext.ensemble
              : PlayingContext.solo,
        ),
        voicing: ObservedVoicing.fromMidi(c.midiNotes),
      );

      final top = ranked.first.identity;
      expect(top.rootPc, c.rootPc, reason: c.id);
      expect(top.quality, c.quality, reason: c.id);
      expect(top.extensions, c.extensions, reason: c.id);
      expect(top.hasImpliedRoot, c.ensemble, reason: c.id);
    });
  }
}
