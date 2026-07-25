/// Test-support factories for analysis contexts and chord inputs.
library;

import 'package:whatchord/whatchord.dart';

/// The tonality tests assume unless they say otherwise: C major.
const defaultTestTonality = Tonality(Tonic.c, TonalityMode.major);

/// Builds an [AnalysisContext] from a tonality, deriving key signature and
/// default spelling policy the same way production analysis does.
AnalysisContext makeAnalysisContext({
  Tonality tonality = defaultTestTonality,
  NoteSpellingPolicy? spellingPolicy,
  PlayingContext playingContext = PlayingContext.solo,
}) {
  final keySignature = KeySignature.fromTonality(tonality);
  final policy =
      spellingPolicy ??
      NoteSpellingPolicy(preferFlats: keySignature.prefersFlats);

  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: policy,
    playingContext: playingContext,
  );
}

/// Shorthand for [pitchClassFromNoteName].
int pc(String name) => pitchClassFromNoteName(name);

/// Builds a 12-bit pitch-class mask from pitch classes.
int maskOf(Iterable<int> pcs) {
  var mask = 0;
  for (final pc in pcs) {
    mask |= 1 << (pc % 12);
  }
  return mask;
}

/// Builds a 12-bit pitch-class mask from note names.
int maskOfNames(Iterable<String> names) => maskOf(names.map(pc));

/// Builds a [ChordInput] from note names, defaulting the bass to the first
/// name.
ChordInput chordInputFromNames({
  required Iterable<String> names,
  String? bass,
  int? noteCount,
}) {
  final noteNames = names.toList(growable: false);

  return ChordInput(
    pcMask: maskOfNames(noteNames),
    bassPc: pc(bass ?? noteNames.first),
    noteCount: noteCount ?? noteNames.length,
  );
}
