import '../models/chord_identity.dart';
import 'rules/common_name_prior_rule.dart';
import 'rules/coverage_simplicity_rules.dart';
import 'rules/dominant_slash_rules.dart';
import 'rules/ensemble_rules.dart';
import 'rules/named_rule.dart';
import 'rules/six_chord_rules.dart';
import 'rules/triad_completeness_rules.dart';

export 'rules/named_rule.dart';

// The two ordered lists below ARE the ranking policy: rules are tried top to
// bottom and the first one to return a non-zero result decides the pair. Order
// is therefore significant; read these lists to audit ranking behavior.
//
// NOTE: https://whatchord.earthmanmuons.com/articles/chord-recognition-algorithm.html documents these
// rules and their order in detail. Update the article when rules or their order
// change.

/// Cost-independent overrides, applied before the near-tie window check.
/// A hard rule can promote a higher-cost reading to the top, so each is
/// deliberately narrow and guarded.
final List<NamedRule> hardRules = <NamedRule>[
  // First on purpose: an implied-root candidate can only exist under ensemble
  // analysis, and every implied-vs-sounding pair must be decided here before
  // the sounding-root-era rules below see it. In solo analysis the rule never
  // fires.
  NamedRule(
    'prefer idiomatic implied-root reading',
    preferIdiomaticImpliedRootReading,
  ),
  NamedRule(
    'prefer dominant flat-nine shell over colored diminished',
    preferCompleteDom7Flat9OverColoredDim7,
    gate: (c, f, _) =>
        isStableDominantFlatNineShell(c.identity, f) ||
        f.isDimFamily ||
        c.identity.quality == ChordQuality.diminished,
  ),
  NamedRule(
    'prefer flat-nine-bass dominant over remote reinterpretation',
    preferFlatNineBassDominantOverRemoteReinterpretation,
    gate: (c, f, _) =>
        f.isFifthlessFlatNineBassDominant ||
        c.identity.quality == ChordQuality.minorMajor7 ||
        c.identity.quality == ChordQuality.diminished,
  ),
  NamedRule(
    'prefer complete dominant sharp-nine over non-seventh color',
    preferCompleteDominantSharp9OverNonSeventhColor,
    gate: (c, f, _) =>
        isCompleteDominantSharpNineReading(c.identity) ||
        isStableNonSeventhSharpNineCompetitor(c.identity, f),
  ),
  NamedRule(
    'prefer complete altered sharp-five dominant over remote spellings',
    preferCompleteAlteredSharpFiveDominantOverRemoteSpellings,
    gate: (c, _, _) =>
        isAlteredSharpFiveDominant(c.identity) ||
        isNaturalEleventhSharpFiveDominant(c.identity) ||
        isRemoteAlteredNonDominantReading(c.identity),
  ),
  NamedRule(
    'prefer conventional inversion in split-nine tritone dominant ambiguity',
    preferConventionalSplitNineTritoneDominant,
    gate: (c, _, _) =>
        isSplitNineFlatFiveDominant(c.identity) ||
        isSharp11Flat13Dominant(c.identity),
  ),
  NamedRule(
    'prefer altered dominant7 over dim7 slash',
    preferAlteredDom7,
    gate: (c, f, _) => f.isDom7 || f.isDimFamily,
  ),
  NamedRule(
    'prefer conventional altered seventh over add11 slash',
    preferConventionalAlteredSeventhOverAdd11Slash,
    gate: (c, f, _) =>
        f.isQuestionableAdd11Slash ||
        (f.isSeventhFamily && f.extensionTensionCount > 0),
  ),
  NamedRule(
    'prefer close root-position dominant7 over non-dominant slash',
    preferDom7RootOverNonDomSlash,
    gate: (c, f, _) =>
        (f.isDom7RootPosition && f.dom7HasShell) ||
        (f.isSlashBass && !f.isDom7 && !f.isAlteredFifthDom7),
  ),
  NamedRule(
    'prefer ninth-bass seventh chord over altered slash',
    preferNinthBassSeventhOverAlteredSlash,
    gate: (c, f, _) =>
        f.isCompleteNinthBassSeventhChord ||
        (f.isSlashBass &&
            (f.extensionTensionCount > 0 || f.isUnusualSeventhQuality)),
  ),
  NamedRule(
    'prefer root-position altered-fifth dominant over slash',
    preferRootAlteredFifthDom7,
    gate: (c, f, _) => f.isAlteredFifthDom7,
  ),
  NamedRule(
    'prefer root-position add-chord over sus slash',
    preferRootAddChordOverSusSlash,
    gate: (c, f, _) =>
        f.isRootPositionNaturalAddChord || (f.isSus && f.isSlashBass),
  ),
  NamedRule(
    'prefer complete triad over structurally deficient reading',
    preferCompleteTriadOverDeficientReading,
    gate: (c, f, _) => f.isCompleteMajorMinorTriad || f.isStructurallyDeficient,
  ),
  NamedRule(
    'prefer root-position minor-eleventh shell over sus slash',
    preferRootMinor7Add11ShellOverSusSlash,
    gate: (c, f, _) =>
        f.isRootPositionMinor7Add11Shell ||
        c.identity.quality == ChordQuality.dominant7sus4 ||
        c.identity.quality == ChordQuality.sus2sus4,
  ),
  NamedRule(
    'prefer simple triad add-tone over seventh-family unusual quality',
    preferSimpleTriadAddToneOverSeventhFamilyUnusualQuality,
    gate: (c, f, _) =>
        (!f.isSeventhFamily && !f.isSus && f.hasOnlyAddColor) ||
        (f.isSeventhFamily && f.isUnusualSeventhQuality),
  ),
  NamedRule(
    'prefer readable sharp-eleven major over flat-five spelling',
    preferReadableSharpElevenMajorOverFlatFive,
    gate: (c, _, _) =>
        c.identity.quality == ChordQuality.major ||
        c.identity.quality == ChordQuality.major7 ||
        c.identity.quality == ChordQuality.major7Flat5 ||
        c.identity.quality == ChordQuality.majorFlat5,
  ),
];

/// Near-tie tie-breakers, applied in priority order only when two candidates
/// cost within the near-tie window of each other. These encode musical
/// preferences:
/// - Structural clarity (root position, shell tones)
/// - Functional harmony (diatonic, dominant alterations)
/// - Simplicity (fewer extensions/alterations, avoid suspensions)
/// WhatKey's v2026.7.14 tie-breaker policy.
///
/// Production-only rules belong in [tieBreakerRules], not in this historical
/// list. Fixture hashes guard behavior-preserving changes to shared rules.
final List<NamedRule> whatKeyPaper2026TieBreakerRules = <NamedRule>[
  // Voicing evidence is consulted first: when the register clearly presents one
  // reading as an upper-structure slash and the other not, that observation
  // outranks the naming conventions below.
  NamedRule(
    'prefer voicing-supported upper-structure slash',
    preferVoicingUpperStructureSlash,
  ),
  NamedRule('prefer root-position 6th over inverted 7th', prefer6thInRoot),
  NamedRule(
    'prefer complete triad over incomplete 6th',
    preferCompleteTriadOverIncompleteSixth,
  ),
  NamedRule('prefer upper-structure dominant7 slash', preferUpperStructureDom7),
  NamedRule(
    'prefer major-seventh upper-structure sus slash',
    preferMajorSeventhUpperStructureSusSlash,
  ),
  NamedRule(
    'prefer root-position dominant sus over slash',
    preferRootDominantSusOverSlash,
  ),
  NamedRule(
    'prefer cleaner-spelled tritone-twin extended dominant',
    preferCleanerSpelledTritoneTwinExtendedDominant,
  ),
  NamedRule(
    'prefer stable extended dominant over altered-fifth slash',
    preferRootExtendedDom7OverAlteredFifthSlash,
  ),
  NamedRule(
    'prefer complete altered thirteenth dominant over altered minor thirteenth',
    preferCompleteAlteredThirteenthDominantOverAlteredMinorThirteenth,
  ),
  NamedRule(
    'prefer complete flat-nine flat-thirteen dominant over remote spelling',
    preferCompleteFlatNineFlatThirteenthDominantOverRemoteSpelling,
  ),
  NamedRule(
    'prefer complete major sharp-eleven inversion over major13sus4',
    preferCompleteMajorSharpElevenInversionOverMajor13Sus4,
  ),
  NamedRule(
    'prefer complete major inversion over seventh-family color-bass slash',
    preferCompleteMajorInversionOverSeventhColorBassSlash,
  ),
  NamedRule('prefer root-position diminished7', preferDim7InRoot),
  NamedRule(
    'prefer dominant7 shell slash over non-dominant seventh-family slash',
    preferDom7ShellSlashOverSeventhFamilySlash,
  ),
  NamedRule(
    'prefer voicing that names every tone',
    preferFullyExplainedVoicing,
  ),
  NamedRule(
    'prefer lower-cost add chord over missing-third unusual seventh',
    preferLowerCostAddChordOverMissingThirdUnusualSeventh,
  ),
  NamedRule(
    'prefer harmonic-minor tonic over split-third inversion',
    preferHarmonicMinorTonicOverSplitThirdInversion,
  ),
  NamedRule(
    'prefer lower-cost major-seventh-bass inversion over color-bass slash',
    preferLowerCostMajorSeventhBassInversionOverColorBassSlash,
  ),
  NamedRule('prefer fewer altered/tension colors', preferFewerAlterations),
  NamedRule('prefer diatonic chords', preferDiatonic),
  NamedRule(
    'prefer root-position relative minor7 over major6 slash',
    preferRootMinor7OverMajor6Slash,
  ),
  NamedRule('prefer tonic chord', preferTonicChord),
  NamedRule(
    'prefer complete triad add-tone over sparse seventh-family color',
    preferCompleteTriadAddToneOverSeventhFamilyAddTone,
  ),
  NamedRule(
    'prefer natural extensions over adds, then fewer total',
    preferNaturalExtensions,
  ),
  NamedRule('prefer root position', preferRootPosition),
  NamedRule('prefer common naming preference', preferCommonNamePrior),
  NamedRule(
    'prefer cleaner tritone flat-five dominant spelling',
    preferCleanerTritoneFlatFiveDominantSpelling,
  ),
  NamedRule('prefer more conventional inversion', preferConventionalInversion),
  NamedRule('prefer 7th chords over triads', prefer7thChords),
  NamedRule('prefer fewer extensions', preferFewerExtensions),
  NamedRule('avoid suspended chords', avoidSuspended),
  NamedRule('prefer cleaner spelling', preferCleanerSpelling),
];

/// Current production policy: the historical ordering plus later improvements.
///
/// The key-functional-seventh rule slots in directly after the voicing rule.
/// Anchoring by name keeps that intent stable if the historical list is later
/// reordered, where a positional splice would silently shift the insertion.
final List<NamedRule> tieBreakerRules = _insertAfter(
  whatKeyPaper2026TieBreakerRules,
  anchor: 'prefer voicing-supported upper-structure slash',
  rule: NamedRule(
    'prefer key-functional seventh over sixth-chord twin',
    preferKeyFunctionalSeventhOverSixthTwin,
  ),
);

List<NamedRule> _insertAfter(
  List<NamedRule> rules, {
  required String anchor,
  required NamedRule rule,
}) {
  final index = rules.indexWhere((rule) => rule.name == anchor);
  if (index < 0) {
    throw StateError('Tie-breaker anchor rule not found: "$anchor"');
  }
  return [...rules.take(index + 1), rule, ...rules.skip(index + 1)];
}
