import 'package:whatchord/whatchord.dart';

/// Musician-friendly prose for the analyzer's ranking explanations.
///
/// [decisionRuleNames] is tested against
/// [ChordCandidateRanking.decisionRuleNames], so a ranking-policy change cannot
/// silently fall back to generic prose in the "Why This Chord?" sheet.
abstract final class ChordRankingExplanations {
  static const _upperStructureDominantRule =
      'prefer upper-structure dominant7 slash';

  static const Map<String, String> _decisionSentences = <String, String>{
    'cost difference beyond tie-break range':
        'it explains the notes much more simply.',
    'prefer idiomatic implied-root reading':
        'in Ensemble mode, the voicing reads naturally as a rootless chord.',
    'prefer in-key member of the half-diminished/major-seventh pair': 'it uses the same notes as the next chord, but its root fits the current key.',
    'prefer dominant flat-nine shell over colored diminished':
        'it keeps the full dominant flat-nine chord intact.',
    'prefer flat-nine-bass dominant over remote reinterpretation':
        'the dominant name gives the flat-nine bass a clear role.',
    'prefer complete dominant sharp-nine over non-seventh color':
        'it keeps the full dominant sharp-nine chord intact.',
    'prefer complete altered sharp-five dominant over remote spellings':
        'the complete altered dominant is the clearer reading.',
    'prefer conventional inversion in split-nine tritone dominant ambiguity': 'its bass gives the tritone-related dominant a more familiar inversion.',
    'prefer altered dominant7 over dim7 slash':
        'the dominant seventh is clearer than the diminished slash chord.',
    'prefer conventional altered seventh over add11 slash':
        'the altered seventh is more familiar than the add-eleven slash chord.',
    'prefer close root-position dominant7 over non-dominant slash':
        'the root-position dominant seventh is clearer than the slash chord.',
    'prefer ninth-bass seventh chord over altered slash':
        'the seventh chord gives the ninth in the bass a clearer role.',
    'prefer root-position altered-fifth dominant over slash':
        'the root-position altered dominant is clearer than the slash chord.',
    'prefer root-position add-chord over sus slash': 'the root-position added-tone chord is clearer than the suspended slash chord.',
    'prefer complete triad over structurally deficient reading':
        'it contains a complete triad.',
    'prefer root-position minor-eleventh shell over sus slash': 'the root-position minor eleventh is clearer than the suspended slash chord.',
    'prefer simple triad add-tone over seventh-family unusual quality': 'a simple triad with an added note is clearer than the unusual seventh chord.',
    'prefer readable sharp-eleven major over flat-five spelling':
        'the sharp-eleven major spelling is easier to read.',
    'prefer voicing-supported upper-structure slash':
        'the voicing forms a complete chord above a separate bass note.',
    'prefer key-functional seventh over sixth-chord twin': 'this key expects the seventh-chord name, not the equivalent sixth chord.',
    'prefer dominant reading among implied roots':
        'the guide tones and color notes point to the dominant chord.',
    'prefer root-position 6th over inverted 7th': 'the sixth chord is in root position while the seventh chord is inverted.',
    'prefer complete triad over incomplete 6th':
        'a complete triad is clearer than a sixth chord missing its fifth.',
    'prefer major-seventh upper-structure sus slash':
        'a complete major seventh above the bass is the clearest reading.',
    'prefer root-position dominant sus over slash':
        'the root-position suspended dominant gives the bass a clearer role.',
    'prefer cleaner-spelled tritone-twin extended dominant':
        'its accidental spelling is easier to read.',
    'prefer stable extended dominant over altered-fifth slash':
        'it keeps the bass and extensions in a more natural dominant voicing.',
    'prefer complete altered thirteenth dominant over altered minor thirteenth': 'it preserves a complete dominant chord and avoids unusual minor-chord alterations.',
    'prefer complete flat-nine flat-thirteen dominant over remote spelling': 'the complete altered dominant explains the flat ninth and flat thirteenth directly.',
    'prefer complete major sharp-eleven inversion over major13sus4': 'the complete major sharp-eleven inversion is clearer than the suspended chord.',
    'prefer complete major inversion over seventh-family color-bass slash':
        'it treats the bass as a normal inversion of a complete major chord.',
    'prefer root-position diminished7':
        'the diminished seventh is clearest with its root in the bass.',
    'prefer dominant7 shell slash over non-dominant seventh-family slash':
        'the dominant seventh gives the slash bass a clearer role.',
    'prefer voicing that names every tone':
        'its name accounts for every sounding note.',
    'prefer lower-cost add chord over missing-third unusual seventh': 'the added-tone chord fits better than an unusual seventh missing its third.',
    'prefer harmonic-minor tonic over split-third inversion':
        'the harmonic-minor tonic explains both thirds more directly.',
    'prefer lower-cost major-seventh-bass inversion over color-bass slash': "it treats the bass as the chord's major seventh, not a remote color note.",
    'prefer fewer altered/tension colors':
        'it needs fewer altered color tones.',
    'prefer diatonic chords': 'it fits the selected key more directly.',
    'prefer root-position relative minor7 over major6 slash': 'the root-position relative minor seventh is clearer than the major-sixth slash chord.',
    'prefer tonic chord': 'it is the tonic chord in the selected key.',
    'prefer complete triad add-tone over sparse seventh-family color': 'a complete triad with one added note is clearer than the sparse seventh chord.',
    'prefer natural extensions over adds, then fewer total':
        'natural extensions make a cleaner name than added tones.',
    'prefer root position': 'its bass is the chord root.',
    'prefer common naming preference':
        'musicians commonly use this name for these notes.',
    'prefer cleaner tritone flat-five dominant spelling':
        'its flat-five spelling is easier to read.',
    'prefer more conventional inversion':
        'its bass is a more stable chord tone.',
    'prefer 7th chords over triads':
        'the seventh chord explains more of the voicing.',
    'prefer fewer extensions': 'it needs fewer extensions.',
    'avoid suspended chords':
        'a chord with a clear third is more specific than a suspended chord.',
    'prefer cleaner spelling': 'its accidentals make the chord easier to read.',
    'deterministic fallback: rootPc': 'the readings are effectively tied, so the app chooses a consistent spelling.',
  };

  static const Map<String, String> _costReasonLabels = <String, String>{
    CostReasonLabel.requiredTones: 'Required notes present',
    CostReasonLabel.missingRequired: 'Missing essential notes',
    CostReasonLabel.missingRoot: 'Implied root (not played)',
    CostReasonLabel.optionalTones: 'Optional color tones',
    CostReasonLabel.penaltyTones: 'Conflicting tones',
    CostReasonLabel.colorTones: 'Named color tones',
    CostReasonLabel.vocabularyRarity: 'Uncommon chord name',
    CostReasonLabel.fifthlessSixth: 'Sixth chord missing fifth',
    CostReasonLabel.bassFit: 'Bass placement',
  };

  /// Decision names with dedicated prose in [decision].
  static final Set<String> decisionRuleNames = Set<String>.unmodifiable({
    ..._decisionSentences.keys,
    _upperStructureDominantRule,
  });

  /// Cost-reason labels with musician-friendly labels in [costReasonLabel].
  static Set<String> get costReasonLabels => _costReasonLabels.keys.toSet();

  static String decision(String? rule, {ChordCandidate? winner}) {
    final sentence = switch (rule) {
      _upperStructureDominantRule => _upperStructureDominantReason(winner),
      final rule? =>
        _decisionSentences[rule] ??
            'the ranking rules make it the clearest name for this voicing.',
      null => 'the ranking rules make it the clearest name for this voicing.',
    };

    return 'It ranks higher because $sentence';
  }

  static String costReasonLabel(String label) =>
      _costReasonLabels[label] ?? label;

  static String _upperStructureDominantReason(ChordCandidate? winner) {
    if (winner?.identity.hasSlashBass ?? false) {
      return 'the bass sounds like a color note, not a separate chord root.';
    }

    return 'the root-position dominant is clearer than the slash-bass chord.';
  }
}
