import 'package:meta/meta.dart';

import '../models/polychord_candidate.dart';

/// One validated note collection and its complete generated candidate set.
///
/// This package-internal proof object lets product orchestration reuse one
/// generation without weakening validation at public API boundaries.
@internal
final class PolychordGeneratedCandidateSet {
  const PolychordGeneratedCandidateSet._({
    required this.midiNotes,
    required this.pitchClassMask,
    required this.candidates,
  });

  final List<int> midiNotes;
  final int pitchClassMask;
  final List<PolychordCandidate> candidates;
}

/// Pure-Dart implementation of `polychord-register-candidates/1`.
final class PolychordRegisterCandidateGenerator {
  const PolychordRegisterCandidateGenerator();

  /// Enumerates every v1 candidate at every adjacent register boundary.
  List<PolychordCandidate> generate(Iterable<int> midiNotes) =>
      generateSet(midiNotes).candidates;

  /// Generates one reusable, validated structural set for package internals.
  @internal
  PolychordGeneratedCandidateSet generateSet(Iterable<int> midiNotes) {
    final notes = _validateMidiNotes(midiNotes);
    final suffixMasks = List<int>.filled(notes.length + 1, 0);
    for (var index = notes.length - 1; index >= 0; index--) {
      suffixMasks[index] = suffixMasks[index + 1] | (1 << (notes[index] % 12));
    }

    final candidates = <PolychordCandidate>[];
    var lowerPitchClassMask = 0;
    for (
      var splitAfterIndex = 0;
      splitAfterIndex < notes.length - 1;
      splitAfterIndex++
    ) {
      lowerPitchClassMask |= 1 << (notes[splitAfterIndex] % 12);
      final upperPitchClassMask = suffixMasks[splitAfterIndex + 1];
      if (!_canBeSupportedLayer(lowerPitchClassMask) ||
          !_canBeSupportedLayer(upperPitchClassMask)) {
        continue;
      }

      final lowerNotes = notes.sublist(0, splitAfterIndex + 1);
      final upperNotes = notes.sublist(splitAfterIndex + 1);
      final lowerMatches = _chordMatches(lowerPitchClassMask);
      final upperMatches = _chordMatches(upperPitchClassMask);
      final lowerPitchClasses = _pitchClasses(lowerPitchClassMask);
      final upperPitchClasses = _pitchClasses(upperPitchClassMask);

      for (final lowerIdentity in lowerMatches) {
        for (final upperIdentity in upperMatches) {
          if (lowerIdentity.rootPc == upperIdentity.rootPc) continue;
          final lower = _layerCandidate(
            lowerNotes,
            lowerPitchClasses,
            lowerIdentity,
          );
          final upper = _layerCandidate(
            upperNotes,
            upperPitchClasses,
            upperIdentity,
          );
          final sharedPitchClasses = _pitchClasses(
            lowerPitchClassMask & upperPitchClassMask,
          );
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
    return PolychordGeneratedCandidateSet._(
      midiNotes: notes,
      pitchClassMask: suffixMasks.first,
      candidates: List<PolychordCandidate>.unmodifiable(candidates),
    );
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

bool _canBeSupportedLayer(int pitchClassMask) {
  final count = _bitCount(pitchClassMask);
  return count == 3 || count == 4;
}

List<PolychordLayerIdentity> _chordMatches(int pitchClassMask) {
  final pitchClasses = _pitchClasses(pitchClassMask);
  final matches = <PolychordLayerIdentity>[];
  for (final rootPc in pitchClasses) {
    final relativeMask = _relativeMask(pitchClassMask, rootPc);
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
  List<int> pitchClasses,
  PolychordLayerIdentity identity,
) => PolychordLayerCandidate(
  identity: identity,
  midiNotes: midiNotes,
  pitchClasses: pitchClasses,
);

List<int> _pitchClasses(int mask) => [
  for (var pitchClass = 0; pitchClass < 12; pitchClass++)
    if ((mask & (1 << pitchClass)) != 0) pitchClass,
];

int _relativeMask(int pitchClassMask, int rootPc) {
  var result = 0;
  for (var pitchClass = 0; pitchClass < 12; pitchClass++) {
    if ((pitchClassMask & (1 << pitchClass)) != 0) {
      result |= 1 << ((pitchClass - rootPc) % 12);
    }
  }
  return result;
}

int _bitCount(int value) {
  var count = 0;
  var remaining = value;
  while (remaining != 0) {
    count += remaining & 1;
    remaining >>= 1;
  }
  return count;
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
