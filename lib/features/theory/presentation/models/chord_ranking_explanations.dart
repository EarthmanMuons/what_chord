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
        'its explanation cost was clearly lower.',
    'prefer idiomatic implied-root reading':
        'in Ensemble mode the voicing reads as a rootless chord, so the name that reinstates the missing root wins over readings built only on the played notes.',
    'prefer dominant flat-nine shell over colored diminished':
        'the dominant-flat-nine name keeps the complete dominant shell together, while the diminished reading treats one of the dominant tones as added color.',
    'prefer flat-nine-bass dominant over remote reinterpretation':
        'the dominant name gives the flat-nine bass a direct role instead of recasting the same notes as a more remote chord.',
    'prefer complete dominant sharp-nine over non-seventh color':
        'the dominant-sharp-nine name keeps the complete dominant shell together, while the other reading treats the same tension as non-seventh color.',
    'prefer complete altered sharp-five dominant over remote spellings':
        'the complete altered dominant shell is clearer than the more remote spelling.',
    'prefer conventional inversion in split-nine tritone dominant ambiguity':
        'its bass note gives the tritone-related dominant the more conventional inversion.',
    'prefer altered dominant7 over dim7 slash':
        'the dominant-seventh shell gives the voicing a clearer dominant reading.',
    'prefer conventional altered seventh over add11 slash':
        'the altered seventh chord is more conventional than the add-eleven slash reading.',
    'prefer close root-position dominant7 over non-dominant slash':
        'a root-position dominant seventh is clearer than the alternative slash-chord name for these notes.',
    'prefer ninth-bass seventh chord over altered slash':
        'the seventh-chord inversion gives the ninth bass a more direct role than the altered slash reading.',
    'prefer root-position altered-fifth dominant over slash':
        'the root-position altered dominant name is clearer than the slash reading.',
    'prefer root-position add-chord over sus slash':
        'the root-position added-tone chord is clearer than the suspended slash reading.',
    'prefer complete triad over structurally deficient reading':
        'the complete triad accounts for the essential chord tones more clearly.',
    'prefer root-position minor-eleventh shell over sus slash':
        'the root-position minor-eleventh shell is clearer than the suspended slash reading.',
    'prefer simple triad add-tone over seventh-family unusual quality':
        'the simple triad with an added color is clearer than the unusual seventh-chord quality.',
    'prefer readable sharp-eleven major over flat-five spelling':
        'the sharp-eleven major spelling is easier to read than the flat-five alternative.',
    'prefer voicing-supported upper-structure slash':
        'the way it was played stacks a complete chord above an isolated bass note, so this slash name reads more naturally than a root-position reading.',
    'prefer key-functional seventh over sixth-chord twin':
        'in the current key this reading works as the seventh chord musicians expect here, so it wins over the sixth-chord name built on the same notes.',
    'prefer dominant reading among implied roots':
        'between two rootless readings, the guide tones and colors spell classic dominant vocabulary, so the dominant chord wins over the other diatonic root.',
    'prefer root-position 6th over inverted 7th':
        'the sixth-chord name is in root position, while the alternative reading puts another chord over a non-root bass.',
    'prefer complete triad over incomplete 6th':
        'a complete triad is clearer than a sixth chord missing its fifth.',
    'prefer major-seventh upper-structure sus slash':
        'a complete major-seventh upper-structure slash is a clearer spelling for this suspended dominant color.',
    'prefer root-position dominant sus over slash':
        'the root-position suspended dominant gives the bass a clearer role than the slash reading.',
    'prefer cleaner-spelled tritone-twin extended dominant':
        'the tritone-related dominant uses the cleaner accidental spelling.',
    'prefer stable extended dominant over altered-fifth slash':
        'the extended dominant name keeps the bass, seventh shell, and upper extensions in a stable inversion more naturally than an altered-fifth slash reading.',
    'prefer complete altered thirteenth dominant over altered minor thirteenth':
        'the altered dominant-thirteenth name keeps the complete dominant shell together, while the minor-thirteenth reading needs rarer flat-nine and sharp-eleven minor color.',
    'prefer complete flat-nine flat-thirteen dominant over remote spelling':
        'the complete altered dominant shell explains the flat-nine and flat-thirteen more directly than the remote spelling.',
    'prefer complete major sharp-eleven inversion over major13sus4':
        'the complete major sharp-eleven inversion is clearer than a major-thirteen suspended reading.',
    'prefer complete major inversion over seventh-family color-bass slash':
        'the complete major chord gives the bass a conventional inversion role instead of treating it as remote color.',
    'prefer root-position diminished7':
        'the diminished seventh is clearest when the bass is named as the root.',
    'prefer dominant7 shell slash over non-dominant seventh-family slash':
        'the dominant-seventh shell gives the slash bass a clearer harmonic role.',
    'prefer voicing that names every tone':
        'its name accounts for every sounding note more directly.',
    'prefer lower-cost add chord over missing-third unusual seventh':
        'the lower-cost added-tone chord is clearer than an unusual seventh chord without its third.',
    'prefer harmonic-minor tonic over split-third inversion':
        'the harmonic-minor tonic gives the split third a more direct role.',
    'prefer lower-cost major-seventh-bass inversion over color-bass slash':
        'the better-fitting name gives the bass a conventional major-seventh inversion role instead of treating it as a remote color tone.',
    'prefer fewer altered/tension colors':
        'it needs fewer altered color tones.',
    'prefer diatonic chords': 'it fits the selected key more directly.',
    'prefer root-position relative minor7 over major6 slash':
        'the root-position relative minor seventh is clearer than the major-sixth slash reading.',
    'prefer tonic chord': 'it is the tonic chord in the selected key.',
    'prefer complete triad add-tone over sparse seventh-family color':
        'the complete triad with a simple added tone is clearer than a sparse seventh-chord name that treats the same pitch as remote color.',
    'prefer natural extensions over adds, then fewer total':
        'natural extensions give a cleaner chord name than added-tone spellings.',
    'prefer root position': 'its bass is the chord root.',
    'prefer common naming preference':
        'common naming practice favors this chord name for the same kind of sonority.',
    'prefer cleaner tritone flat-five dominant spelling':
        'the tritone-related dominant uses the cleaner flat-five spelling.',
    'prefer more conventional inversion':
        'its bass note is a more stable chord tone.',
    'prefer 7th chords over triads':
        'the seventh-chord reading explains more of the voicing.',
    'prefer fewer extensions': 'it needs fewer extensions.',
    'avoid suspended chords':
        'a chord with a clear third is a more specific match than a suspended reading.',
    'prefer cleaner spelling':
        'its accidentals make the chord easier to read and name.',
    'deterministic fallback: rootPc':
        'these interpretations were essentially equivalent, so the app chose a consistent spelling.',
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
            'the ranking rules made it the clearest name for this voicing.',
      null => 'the ranking rules made it the clearest name for this voicing.',
    };

    return 'Ranked better than the next option because $sentence';
  }

  static String costReasonLabel(String label) =>
      _costReasonLabels[label] ?? label;

  static String _upperStructureDominantReason(ChordCandidate? winner) {
    if (winner?.identity.hasSlashBass ?? false) {
      return 'the bass note sounds like an intentional color note rather than a separate chord root.';
    }

    return 'the root-position dominant reading is clearer than the slash-bass alternative.';
  }
}
