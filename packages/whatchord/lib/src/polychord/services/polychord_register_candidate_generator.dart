import '../models/polychord_candidate.dart';

/// Pure-Dart implementation of `polychord-register-candidates/1`.
final class PolychordRegisterCandidateGenerator {
  const PolychordRegisterCandidateGenerator();

  /// Enumerates every v1 candidate at every adjacent register boundary.
  List<PolychordCandidate> generate(Iterable<int> midiNotes) {
    final notes = _validateMidiNotes(midiNotes);
    final candidates = <PolychordCandidate>[];
    for (
      var splitAfterIndex = 0;
      splitAfterIndex < notes.length - 1;
      splitAfterIndex++
    ) {
      final lowerNotes = notes.sublist(0, splitAfterIndex + 1);
      final upperNotes = notes.sublist(splitAfterIndex + 1);
      final lowerMatches = _chordMatches(lowerNotes);
      final upperMatches = _chordMatches(upperNotes);

      for (final lowerIdentity in lowerMatches) {
        for (final upperIdentity in upperMatches) {
          if (lowerIdentity.rootPc == upperIdentity.rootPc) continue;
          final lower = _layerCandidate(lowerNotes, lowerIdentity);
          final upper = _layerCandidate(upperNotes, upperIdentity);
          final lowerPitchClasses = lower.pitchClasses.toSet();
          final sharedPitchClasses = upper.pitchClasses
              .where(lowerPitchClasses.contains)
              .toList();
          candidates.add(
            PolychordCandidate(
              splitAfterIndex: splitAfterIndex,
              lowerTopMidi: lowerNotes.last,
              upperBottomMidi: upperNotes.first,
              gapSemitones: upperNotes.first - lowerNotes.last,
              lower: lower,
              upper: upper,
              sharedPitchClasses: sharedPitchClasses,
            ),
          );
        }
      }
    }

    candidates.sort(_compareCandidates);
    return List<PolychordCandidate>.unmodifiable(candidates);
  }
}

List<int> _validateMidiNotes(Iterable<int> midiNotes) {
  final notes = List<int>.of(midiNotes);
  for (var index = 0; index < notes.length; index++) {
    final note = notes[index];
    if (note < 0 || note > 127) {
      throw RangeError.range(note, 0, 127, 'midiNotes[$index]');
    }
    if (index > 0 && note <= notes[index - 1]) {
      throw ArgumentError.value(
        notes,
        'midiNotes',
        'must be strictly increasing without duplicates',
      );
    }
  }
  return List<int>.unmodifiable(notes);
}

List<PolychordLayerIdentity> _chordMatches(List<int> midiNotes) {
  final pitchClasses = midiNotes.map((note) => note % 12).toSet().toList()
    ..sort();
  final matches = <PolychordLayerIdentity>[];
  for (final rootPc in pitchClasses) {
    var relativeMask = 0;
    for (final pitchClass in pitchClasses) {
      relativeMask |= 1 << ((pitchClass - rootPc) % 12);
    }
    final quality = _qualityByRelativeMask[relativeMask];
    if (quality != null) {
      matches.add(PolychordLayerIdentity(rootPc: rootPc, quality: quality));
    }
  }
  matches.sort((a, b) {
    final rootComparison = a.rootPc.compareTo(b.rootPc);
    return rootComparison != 0
        ? rootComparison
        : a.quality.index.compareTo(b.quality.index);
  });
  return matches;
}

PolychordLayerCandidate _layerCandidate(
  List<int> midiNotes,
  PolychordLayerIdentity identity,
) {
  final pitchClasses = midiNotes.map((note) => note % 12).toSet().toList()
    ..sort();
  return PolychordLayerCandidate(
    identity: identity,
    midiNotes: midiNotes,
    pitchClasses: pitchClasses,
  );
}

int _compareCandidates(PolychordCandidate a, PolychordCandidate b) {
  final splitComparison = a.splitAfterIndex.compareTo(b.splitAfterIndex);
  if (splitComparison != 0) return splitComparison;
  final upperRootComparison = a.upper.identity.rootPc.compareTo(
    b.upper.identity.rootPc,
  );
  if (upperRootComparison != 0) return upperRootComparison;
  final upperQualityComparison = a.upper.identity.quality.index.compareTo(
    b.upper.identity.quality.index,
  );
  if (upperQualityComparison != 0) return upperQualityComparison;
  final lowerRootComparison = a.lower.identity.rootPc.compareTo(
    b.lower.identity.rootPc,
  );
  if (lowerRootComparison != 0) return lowerRootComparison;
  return a.lower.identity.quality.index.compareTo(
    b.lower.identity.quality.index,
  );
}

const _qualityByRelativeMask = <int, PolychordLayerQuality>{
  0x091: PolychordLayerQuality.major,
  0x089: PolychordLayerQuality.minor,
  0x491: PolychordLayerQuality.dominant7,
  0x891: PolychordLayerQuality.major7,
  0x489: PolychordLayerQuality.minor7,
};
