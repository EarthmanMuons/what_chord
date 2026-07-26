import '../../models/chord_candidate.dart';
import '../../models/chord_extension.dart';
import '../../models/chord_identity.dart';
import '../../models/tonality.dart';
import '../candidate_features.dart';

/// Prefers an implied-root (rootless) reading over any sounding-root reading.
///
/// Implied-root candidates exist only under ensemble analysis, where the
/// played voicing deliberately omits its root; the reading that reinstates it
/// must outrank every reading of the remaining tones, however cheap those are
/// (a rootless Cm9 is also a complete, zero-cost Ebmaj7). Readings whose color
/// is off-idiom for a rootless voicing (an altered extension on a non-dominant
/// host) do not get the preference and compete on cost alone, so a complete
/// sounding chord is not displaced by a strained ghost reading.
int? preferIdiomaticImpliedRootReading(
  ChordCandidate a,
  ChordCandidate b,
  CandidateFeatures fa,
  CandidateFeatures fb,
  Tonality tonality,
) {
  final aPreferred = _isIdiomaticImpliedRoot(a.identity, tonality);
  final bPreferred = _isIdiomaticImpliedRoot(b.identity, tonality);
  if (aPreferred == bPreferred) return null;
  return aPreferred ? -1 : 1;
}

/// The half-diminished/major-seventh semitone pair: a rootless
/// half-diminished seventh and the rootless major seventh a semitone below
/// leave identical sounding tones (B half-diminished and B flat major
/// seventh both leave D-F-A), so the two implied readings are pure
/// re-rootings of one another. When exactly one of the pair's roots is in
/// the key, that reading wins; when both or neither are, the pair falls
/// through to the rules below (where the common-name prior keeps the major
/// seventh). Deliberately narrow: both candidates must be implied-root,
/// carry exactly these qualities a semitone apart, and explain the same
/// pitch content.
int? preferInKeyMemberOfSemitonePair(
  ChordCandidate a,
  ChordCandidate b,
  CandidateFeatures fa,
  CandidateFeatures fb,
  Tonality tonality,
) {
  if (!a.identity.hasImpliedRoot || !b.identity.hasImpliedRoot) return null;
  final ChordIdentity half;
  final ChordIdentity major;
  final bool aIsHalf;
  if (a.identity.quality == ChordQuality.halfDiminished7 &&
      b.identity.quality == ChordQuality.major7) {
    half = a.identity;
    major = b.identity;
    aIsHalf = true;
  } else if (b.identity.quality == ChordQuality.halfDiminished7 &&
      a.identity.quality == ChordQuality.major7) {
    half = b.identity;
    major = a.identity;
    aIsHalf = false;
  } else {
    return null;
  }
  if ((major.rootPc + 1) % 12 != half.rootPc) return null;
  final halfInKey = tonality.containsPitchClass(half.rootPc);
  final majorInKey = tonality.containsPitchClass(major.rootPc);
  if (halfInKey == majorInKey) return null;
  final halfWins = halfInKey;
  return (halfWins == aIsHalf) ? -1 : 1;
}

/// Among implied-root readings, prefers the dominant-family one.
///
/// The near-tie ambiguity a diatonic root filter cannot settle is a dominant
/// reading against a strained tonic-family stack on another diatonic root
/// (F-B-E in C: G13, or Cmaj7 with an 11 against its major third). Comping
/// treats the guide-tone-plus-color set as dominant vocabulary, so the
/// dominant reading wins the pair. Fires only between implied-root readings;
/// sounding-root pairs are untouched.
int? preferDominantAmongImpliedRoots(
  ChordCandidate a,
  ChordCandidate b,
  CandidateFeatures fa,
  CandidateFeatures fb,
  Tonality tonality,
) {
  if (!a.identity.hasImpliedRoot || !b.identity.hasImpliedRoot) return null;
  final aDominant = a.identity.quality.isDominantFamily;
  final bDominant = b.identity.quality.isDominantFamily;
  if (aDominant == bDominant) return null;
  return aDominant ? -1 : 1;
}

bool _isIdiomaticImpliedRoot(ChordIdentity id, Tonality tonality) {
  if (!id.hasImpliedRoot) return false;
  // In-key ghost roots: dominants own the full alt palette; elsewhere an
  // altered extension marks the ghost reading as a stretch rather than a
  // comping form. Out-of-key ghost roots (admission is key-open so secondary
  // and substitute dominants can be named at all) must carry all-natural
  // colors even on a dominant host: a real sub-five voicing reads with
  // natural nine and thirteen, while a complete sounding dominant reread as
  // its own tritone-sub ghost shows up as an altered stack, which is exactly
  // the promotion this gate refuses.
  final inKey = tonality.containsPitchClass(id.rootPc);
  if (inKey && id.quality.isDominantFamily) return true;
  return !_hasAlteredColor(id);
}

bool _hasAlteredColor(ChordIdentity id) {
  for (final e in id.extensions) {
    switch (e) {
      case ChordExtension.flat9:
      case ChordExtension.sharp9:
      case ChordExtension.flat13:
      case ChordExtension.addFlat9:
      case ChordExtension.addSharp9:
        return true;
      case ChordExtension.sharp11:
        if (!id.quality.sharp11IsNaturalColor) return true;
      default:
        break;
    }
  }
  return false;
}
