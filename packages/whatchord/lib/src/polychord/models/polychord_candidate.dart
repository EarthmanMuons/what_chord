import 'package:collection/collection.dart';
import 'package:meta/meta.dart';

/// Complete common-chord qualities admitted as v1 polychord layers.
enum PolychordLayerQuality { major, minor, dominant7, major7, minor7 }

/// One root-and-quality identity within an ordered polychord identity.
@immutable
final class PolychordLayerIdentity {
  const PolychordLayerIdentity({required this.rootPc, required this.quality})
    : assert(rootPc >= 0 && rootPc < 12);

  /// Chord root pitch class from 0 through 11.
  final int rootPc;

  /// Complete common-chord quality.
  final PolychordLayerQuality quality;

  Map<String, Object> toJson() => <String, Object>{
    'rootPc': rootPc,
    'quality': quality.name,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordLayerIdentity &&
          other.rootPc == rootPc &&
          other.quality == quality;

  @override
  int get hashCode => Object.hash(rootPc, quality);
}

/// Ordered upper-then-lower identity for one two-layer decomposition.
@immutable
final class PolychordIdentity {
  const PolychordIdentity({required this.upper, required this.lower});

  /// Identity of the upper register group.
  final PolychordLayerIdentity upper;

  /// Identity of the lower register group.
  final PolychordLayerIdentity lower;

  Map<String, Object> toJson() => <String, Object>{
    'upper': upper.toJson(),
    'lower': lower.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordIdentity &&
          other.upper == upper &&
          other.lower == lower;

  @override
  int get hashCode => Object.hash(upper, lower);
}

/// One recognized chordal layer and its exact sounded-note assignment.
@immutable
final class PolychordLayerCandidate {
  PolychordLayerCandidate({
    required this.identity,
    required Iterable<int> midiNotes,
    required Iterable<int> pitchClasses,
  }) : midiNotes = List<int>.unmodifiable(midiNotes),
       pitchClasses = List<int>.unmodifiable(pitchClasses);

  /// Layer root and quality.
  final PolychordLayerIdentity identity;

  /// Sorted, distinct MIDI notes assigned to this layer.
  final List<int> midiNotes;

  /// Sorted, distinct pitch classes projected by [midiNotes].
  final List<int> pitchClasses;

  Map<String, Object> toJson() => <String, Object>{
    ...identity.toJson(),
    'midiNotes': midiNotes,
    'pitchClasses': pitchClasses,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordLayerCandidate &&
          other.identity == identity &&
          _intListEquality.equals(other.midiNotes, midiNotes) &&
          _intListEquality.equals(other.pitchClasses, pitchClasses);

  @override
  int get hashCode => Object.hash(
    identity,
    _intListEquality.hash(midiNotes),
    _intListEquality.hash(pitchClasses),
  );
}

/// One exact two-layer decomposition at an adjacent register boundary.
@immutable
final class PolychordCandidate {
  PolychordCandidate({
    required this.splitAfterIndex,
    required this.lowerTopMidi,
    required this.upperBottomMidi,
    required this.gapSemitones,
    required this.lower,
    required this.upper,
    required Iterable<int> sharedPitchClasses,
  }) : sharedPitchClasses = List<int>.unmodifiable(sharedPitchClasses);

  /// Zero-based index of the final note assigned to [lower].
  final int splitAfterIndex;

  /// Highest MIDI note in [lower].
  final int lowerTopMidi;

  /// Lowest MIDI note in [upper].
  final int upperBottomMidi;

  /// Observed semitone distance from [lowerTopMidi] to [upperBottomMidi].
  final int gapSemitones;

  /// Exact lower-register layer.
  final PolychordLayerCandidate lower;

  /// Exact upper-register layer.
  final PolychordLayerCandidate upper;

  /// Pitch classes supplied by separate notes in both assignments.
  final List<int> sharedPitchClasses;

  /// Ordered identity, independent of exact note assignment.
  PolychordIdentity get identity =>
      PolychordIdentity(upper: upper.identity, lower: lower.identity);

  /// Neutral upper-first research symbol.
  String get symbol =>
      '${_layerSymbol(upper.identity)}|'
      '${_layerSymbol(lower.identity)}';

  Map<String, Object> toJson() => <String, Object>{
    'splitAfterIndex': splitAfterIndex,
    'lowerTopMidi': lowerTopMidi,
    'upperBottomMidi': upperBottomMidi,
    'gapSemitones': gapSemitones,
    'lower': lower.toJson(),
    'upper': upper.toJson(),
    'sharedPitchClasses': sharedPitchClasses,
    'symbol': symbol,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordCandidate &&
          other.splitAfterIndex == splitAfterIndex &&
          other.lowerTopMidi == lowerTopMidi &&
          other.upperBottomMidi == upperBottomMidi &&
          other.gapSemitones == gapSemitones &&
          other.lower == lower &&
          other.upper == upper &&
          _intListEquality.equals(other.sharedPitchClasses, sharedPitchClasses);

  @override
  int get hashCode => Object.hash(
    splitAfterIndex,
    lowerTopMidi,
    upperBottomMidi,
    gapSemitones,
    lower,
    upper,
    _intListEquality.hash(sharedPitchClasses),
  );
}

const _pitchClassNames = <String>[
  'C',
  'C#',
  'D',
  'D#',
  'E',
  'F',
  'F#',
  'G',
  'G#',
  'A',
  'A#',
  'B',
];

String _layerSymbol(PolychordLayerIdentity identity) {
  final suffix = switch (identity.quality) {
    PolychordLayerQuality.major => '',
    PolychordLayerQuality.minor => 'm',
    PolychordLayerQuality.dominant7 => '7',
    PolychordLayerQuality.major7 => 'maj7',
    PolychordLayerQuality.minor7 => 'm7',
  };
  return _pitchClassNames[identity.rootPc] + suffix;
}

const _intListEquality = ListEquality<int>();
