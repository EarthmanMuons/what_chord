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
  final aPreferred = _isIdiomaticImpliedRoot(a.identity);
  final bPreferred = _isIdiomaticImpliedRoot(b.identity);
  if (aPreferred == bPreferred) return null;
  return aPreferred ? -1 : 1;
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

bool _isIdiomaticImpliedRoot(ChordIdentity id) {
  if (!id.hasImpliedRoot) return false;
  // Dominants own the full alt palette; elsewhere an altered extension marks
  // the ghost reading as a stretch rather than a comping form.
  if (id.quality.isDominantFamily) return true;
  for (final e in id.extensions) {
    switch (e) {
      case ChordExtension.flat9:
      case ChordExtension.sharp9:
      case ChordExtension.flat13:
      case ChordExtension.addFlat9:
      case ChordExtension.addSharp9:
        return false;
      case ChordExtension.sharp11:
        if (!id.quality.sharp11IsNaturalColor) return false;
      default:
        break;
    }
  }
  return true;
}
