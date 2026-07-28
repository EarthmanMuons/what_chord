import 'dart:collection';

import 'package:meta/meta.dart';

import '../models/analysis_context.dart';
import '../models/chord_candidate.dart';
import '../models/chord_extension.dart';
import '../models/chord_identity.dart';
import '../models/chord_input.dart';
import '../models/chord_tone_role.dart';
import '../models/observed_voicing.dart';
import '../models/playing_context.dart';
import '../services/bit_masks.dart';
import '../services/chord_tone_roles.dart';
import '../services/interval_constants.dart';
import '../services/pitch_class.dart';
import 'chord_analysis_profile.dart';
import 'chord_candidate_ranking.dart';
import 'chord_templates.dart';
import 'engine_counters.dart';

/// One labeled component of a candidate's explanation cost.
@immutable
class CostReason {
  /// Short label for the priced aspect (e.g. "vocabulary", "bass").
  final String label;

  /// The cost delta; positive makes the reading less likely.
  final double cost;

  /// Optional elaboration on what was priced.
  final String? detail;

  /// Root-relative interval mask for the notes in this category, when the
  /// reason describes a tone set (required, optional, penalty, missing).
  /// Null for contextual modifiers that have no note set.
  final int? intervals;

  /// Number of tones in [intervals], when this reason describes a tone set.
  ///
  /// This remains separate from [intervals] so consumers do not need to parse
  /// [detail] to render a count.
  final int? count;

  const CostReason(
    this.label,
    this.cost, {
    this.detail,
    this.intervals,
    this.count,
  });

  @override
  String toString() {
    final d = cost >= 0
        ? '+${cost.toStringAsFixed(2)}'
        : cost.toStringAsFixed(2);
    return detail == null ? '$label $d' : '$label $d ($detail)';
  }
}

/// Stable labels emitted in [CostReason.label].
///
/// Keep [values] synchronized with the labels emitted by [ChordAnalyzer].
abstract final class CostReasonLabel {
  static const requiredTones = 'required tones';
  static const optionalTones = 'optional tones';
  static const vocabularyRarity = 'vocabulary rarity';
  static const colorTones = 'color tones';
  static const fifthlessSixth = 'fifthless sixth';
  static const penaltyTones = 'penalty tones';
  static const missingRequired = 'missing required';
  static const missingRoot = 'missing root';
  static const bassFit = 'bass fit';

  /// Every label the analyzer can emit in a [CostReason].
  static const Set<String> values = <String>{
    requiredTones,
    optionalTones,
    vocabularyRarity,
    colorTones,
    fifthlessSixth,
    penaltyTones,
    missingRequired,
    missingRoot,
    bassFit,
  };
}

/// A ranked candidate together with the reasons for its cost and position.
///
/// Produced by [ChordAnalyzer.explain]; powers "why this name" explanations.
@immutable
class ExplainedCandidate {
  /// The ranked candidate being explained.
  final ChordCandidate candidate;

  /// Rank in the full list returned by the ranking pass. Explanation views
  /// can filter candidates while still showing where each row originally
  /// landed.
  final int? originalRank;

  /// High-signal cost deltas explaining this candidate's price.
  final List<CostReason> costReasons;

  /// Why this candidate is ordered where it is relative to the previous one.
  /// (Null for the first result.)
  final RankingDecision? vsPrevious;

  /// The quality of the template that generated this candidate.
  final ChordQuality templateQuality;

  const ExplainedCandidate({
    required this.candidate,
    this.originalRank,
    required this.costReasons,
    required this.vsPrevious,
    required this.templateQuality,
  });
}

/// Analyzes pitch-class sets to generate and rank chord interpretations.
///
/// Core pipeline:
/// 1. Generate candidates from all possible roots present in the voicing
/// 2. Price each candidate against chord templates using fit metrics
/// 3. Rank candidates using cost + tie-breaking heuristics
/// 4. Cache results keyed by input + context
///
/// Pricing philosophy: a candidate's cost is the price of explaining the input
/// under that name; lower is better. Core chord tones are free, and the name
/// pays for its rarity, appended colors, missing essentials, unexplained tones,
/// and awkward bass placement.
///
/// NOTE: https://whatchord.earthmanmuons.com/articles/chord-recognition-algorithm.html
/// documents this pipeline in detail. Update the article when prices or
/// algorithm structure change.
final class ChordAnalyzer {
  /// Each instance owns its cache and tuning; the app shares one instance so
  /// every feature that names chords shares the LRU cache.
  ChordAnalyzer({
    this.cacheCapacity = 512,
    this.rankingPruneMargin = 2.0,
    this.analysisProfile = ChordAnalysisProfile.current,
    this.unexplainedToneCost = defaultUnexplainedToneCost,
  });

  /// Maximum cached analysis results (LRU eviction). Configurable so the
  /// cache test can shrink capacity and exercise eviction without hundreds
  /// of analyses.
  final int cacheCapacity;

  /// Candidates priced more than this above the cheapest reading are dropped
  /// before the O(n^2) ranking. A reading this far down can never surface as
  /// the #1 pick or an alternative; chord_ranking_prune_guard_test measures
  /// the widest surfaced gap and asserts it stays under this margin.
  /// Configurable so that guard test can disable pruning (raise to infinity)
  /// and measure the unpruned surfaced gap.
  final double rankingPruneMargin;

  /// Ranking policy used by this analyzer instance.
  ///
  /// The app leaves this at [ChordAnalysisProfile.current]. Research tooling
  /// may request a frozen policy when rebuilding published fixtures.
  final ChordAnalysisProfile analysisProfile;

  /// Price of a sounding tone the name cannot account for at all.
  ///
  /// The app uses [defaultUnexplainedToneCost]; research tooling may override
  /// it to prototype tolerance levers (research/tone-pricing/) without
  /// touching the shipped ranking.
  final double unexplainedToneCost;

  final LinkedHashMap<int, List<ChordCandidate>> _cache =
      LinkedHashMap<int, List<ChordCandidate>>();

  // ---- Explanation-cost prices -----------------------------------------
  // A candidate's cost is the price of explaining every sounding pitch under
  // that name: core chord tones are free, and the name pays for its own
  // rarity, each color tone it appends, essential tones it lacks, tones it
  // cannot account for, and awkward bass placement. Lower is better. Prices are
  // musician-judged priors calibrated against the reviewed oracle pool.
  // See https://whatchord.earthmanmuons.com/articles/chord-recognition-algorithm.html.

  // Vocabulary rarity: how readily a musician reaches for the quality name.
  static const _vocabularyMarked = 0.1; // dim, aug, sus2, dim7, m7b5, ...
  static const _vocabularyUncommon = 0.4; // 7b5, 7#5, maj7sus4, maj7#5
  static const _vocabularyRare = 1.0; // m#5, m7#5, majb5, maj7b5, sus2 7ths

  // Natural color tones. Upper extensions are idiomatic on everyday hosts
  // (a 13 on a dominant, an 11 on a minor seventh); on marked-vocabulary
  // hosts (a 13 on a half-diminished or minor-major seventh) they are far
  // rarer and cost proportionally more.
  static const _priceNine = 0.35;
  static const _priceEleven = 0.3;
  static const _priceThirteen = 0.3;
  static const _priceAdd9 = 0.4;
  static const _priceAdd11 = 0.3;
  static const _priceAdd13 = 0.3;
  static const _markedHostExtensionMultiplier = 1.75;

  // Altered color tones. The alt palette lives on dominant chords; hosting
  // one of these on another quality doubles its price (#11 stays unmultiplied
  // on the qualities where it is idiomatic Lydian color).
  static const _priceFlat9 = 0.45;
  static const _priceSharp9 = 0.5;
  static const _priceSharp11 = 0.55;
  static const _priceFlat13 = 0.5;
  static const _priceSplitThird = 0.4;
  static const _offDominantAlterationMultiplier = 2.0;

  // Structural surcharges on individual color tones.
  static const _unsupportedElevenSurcharge = 0.15; // 11 with no 9 below it
  static const _unsupportedThirteenSurcharge = 0.25; // 13 with no 9 below it
  static const _elevenOverMajorThirdSurcharge = 0.5; // avoid-tone clash
  static const _splitFourthSurcharge = 0.6; // natural 4 and #11 at once
  static const _splitSecondSurcharge = 0.4; // natural 2 and b9/#9 at once
  static const _splitSixthSurcharge = 0.8; // natural 6/13 and b13 at once
  static const _paper2026SplitSixthSurcharge = 0.4;
  static const _splitSharpFiveThirteenSurcharge = 0.8; // #5 and 13 at once
  static const _alteredMajorSeventhFlatNineSurcharge = 0.25; // b9 on maj7#5/b5
  static const _sharpElevenEmptyFifthSurcharge = 0.75; // #11 with no 5th tone
  static const _flatThirteenEmptyFifthSurcharge = 0.5; // b13 with no 5th
  static const _sixChordNoFifthSurcharge = 0.45; // bare R-3-6 set as a 6th
  static const _flatNineMajorHostSurcharge = 0.3; // b9 on a major 6th/7th
  static const _minorMajorFlatNineElevenSurcharge = 0.9;
  static const _stackedChromaticAddSurcharge = 0.15; // addb9/add#9 in a pile
  static const _upperTriadNinthBassCost = 0.15; // D/E idiom: add9 as pedal

  // Missing essential tones (candidate generation allows at most one).
  static const _missingThirdCost = 1.7;
  static const _missingSusToneCost = 1.4;
  static const _missingAlteredFifthCost = 0.9;
  static const _missingSeventhCost = 0.75;
  static const _missingFifthCost = 0.5;

  // The implied root of an ensemble rootless reading: cheap because the mode
  // assumes another instrument covers it, but not free, so among otherwise
  // equal readings the sounding root wins.
  static const _missingRootCost = 0.25;

  // A sounding tone the name cannot account for at all.
  static const defaultUnexplainedToneCost = 2.0;

  // Bass placement: root is free, conventional inversions are cheap, color
  // tones and especially suspended tones in the bass read awkwardly. An
  // integrated extension in the bass (the 11 of a m7) reads smoother than a
  // bare add tone (the add9 under a 6/9), which reads like a pedal the name
  // fails to acknowledge.
  static const _bassCoreToneCost = 0.15;
  static const _bassSusToneCost = 0.7;
  static const _bassAlteredFifthCost = 0.3;
  static const _bassNaturalColorCost = 0.3;
  static const _bassAddToneCost = 0.65;
  static const _bassAlteredColorCost = 0.5;
  static const _bassUnexplainedCost = 1.0;

  /// Names [input], returning up to [take] candidates ranked most plausible
  /// first.
  ///
  /// [context] biases ranking and spelling toward the prevailing key, and
  /// [voicing] lets register evidence (e.g. a low bass) nudge close calls.
  /// Results are cached.
  List<ChordCandidate> analyze(
    ChordInput input, {
    required AnalysisContext context,
    ObservedVoicing? voicing,
    int take = 5,
  }) {
    // Cache includes context because tonality affects ranking tie-breakers
    // (e.g., diatonic preference, tonic-as-I rule), and the voicing signature
    // because register evidence nudges the ranking.
    final key = Object.hash(
      input.cacheKey,
      voicing?.signature ?? 0,
      context,
      take,
    );
    final cache = _cache;
    final cached = cache[key];
    if (cached != null) {
      if (engineCountersEnabled) EngineCounters.cacheHits++;
      // Promote cache hits so eviction removes the least recently used entry,
      // not merely the oldest inserted entry.
      cache
        ..remove(key)
        ..[key] = cached;
      return cached;
    }
    if (engineCountersEnabled) EngineCounters.cacheMisses++;

    final eval = _evaluateAll(
      input,
      context: context,
      voicing: voicing,
      debug: false,
      take: take,
    );

    final result = eval
        .take(take)
        .map((e) => e.candidate)
        .toList(growable: false);

    cache[key] = result;
    if (cache.length > cacheCapacity) {
      cache.remove(cache.keys.first);
    }
    return result;
  }

  /// Empties the analysis result cache.
  void clearCache() => _cache.clear();

  /// Current number of cached results.
  @visibleForTesting
  int get cacheSize => _cache.length;

  /// Like [analyze], but each candidate carries its cost breakdown and the
  /// reason it is ordered relative to the previous one.
  List<ExplainedCandidate> explain(
    ChordInput input, {
    required AnalysisContext context,
    ObservedVoicing? voicing,
    int take = 5,
  }) {
    final eval = _evaluateAll(
      input,
      context: context,
      voicing: voicing,
      debug: true,
      take: take,
    ).take(take).toList(growable: false);

    final out = <ExplainedCandidate>[];
    for (var i = 0; i < eval.length; i++) {
      final current = eval[i];
      final prev = i == 0 ? null : eval[i - 1];

      out.add(
        ExplainedCandidate(
          candidate: current.candidate,
          originalRank: i + 1,
          templateQuality: current.template.quality,
          costReasons: current.reasons ?? const <CostReason>[],
          vsPrevious: prev == null
              ? null
              : ChordCandidateRanking.explain(
                  prev.candidate,
                  current.candidate,
                  tonality: context.tonality,
                  voicing: voicing,
                  profile: analysisProfile,
                ),
        ),
      );
    }
    return out;
  }

  List<_Evaluated> _evaluateAll(
    ChordInput input, {
    required AnalysisContext context,
    required ObservedVoicing? voicing,
    required bool debug,
    required int take,
  }) {
    final pcMask = input.pcMask;
    if (pcMask == 0) return const <_Evaluated>[];

    final out = <_Evaluated>[];

    void evaluateRoot(int rootPc, {required bool impliedRoot}) {
      if (engineCountersEnabled) EngineCounters.rootsConsidered++;

      final relMask = _rotateMaskToRoot(pcMask, rootPc);
      final bassInterval = intervalAboveRoot(input.bassPc, rootPc);

      for (final tmpl in chordTemplates) {
        if (impliedRoot && !tmpl.allowsMissingRoot) continue;
        if (engineCountersEnabled) EngineCounters.templatesEvaluated++;
        final reasons = debug ? <CostReason>[] : null;

        final priced = _priceTemplate(
          relMask: relMask,
          bassInterval: bassInterval,
          template: tmpl,
          rootPc: rootPc,
          context: context,
          impliedRoot: impliedRoot,
          reasons: reasons,
        );
        if (priced == null) continue;

        final candidate = ChordCandidate(
          identity: ChordIdentity(
            rootPc: rootPc,
            bassPc: input.bassPc,
            quality: tmpl.quality,
            extensions: priced.extensions,
            toneRolesByInterval: priced.roles,
            presentIntervalsMask: relMask,
          ),
          cost: priced.cost,
        );

        if (engineCountersEnabled) EngineCounters.candidatesProduced++;
        out.add(
          _Evaluated(candidate: candidate, template: tmpl, reasons: reasons),
        );
      }
    }

    // Chord roots are spelled on notes actually present in the voicing; no
    // "ghost root" interpretations under solo analysis.
    for (var rootPc = 0; rootPc < 12; rootPc++) {
      if ((pcMask & (1 << rootPc)) == 0) continue;
      evaluateRoot(rootPc, impliedRoot: false);
    }

    // Ensemble analysis also hypothesizes rootless readings: the root may be
    // covered by another instrument, so every absent pitch class is tried as
    // an implied root against the ensemble-eligible templates. Admission is
    // deliberately key-open: secondary and substitute dominants put roots
    // outside the key constantly (12-22% of jazz seventh chords by quality,
    // research/ensemble-tiebreak/log/2026-07-26-02), and a diatonic gate
    // silently renames them all as their in-key twins. Key preference
    // belongs to ranking, not admission.
    if (context.playingContext == PlayingContext.ensemble) {
      for (var rootPc = 0; rootPc < 12; rootPc++) {
        if ((pcMask & (1 << rootPc)) != 0) continue;
        evaluateRoot(rootPc, impliedRoot: true);
      }
    }

    // Drop the long tail of high-cost readings before the O(n^2) ranking.
    // Costs are a pure function of the input, so this is transposition-invariant
    // (both a chord and its transposition prune to the same set).
    final toRank = _pruneForRanking(out, take);
    if (engineCountersEnabled) {
      EngineCounters.candidatesRanked += toRank.length;
    }

    // `compare` is intentionally non-transitive (hard rules and the near-tie
    // window override raw cost), so a plain sort would be undefined and could
    // bury a strong candidate. `rank` linearizes the relation deterministically.
    return ChordCandidateRanking.rank(
      toRank,
      (e) => e.candidate,
      tonality: context.tonality,
      voicing: voicing,
      profile: analysisProfile,
    );
  }

  /// Trims the candidate set before the O(n^2) ranking, keeping whichever is
  /// larger of: every candidate within [rankingPruneMargin] of the cheapest raw
  /// cost (which preserves the #1 pick and the surfaced alternatives set, see
  /// [rankingPruneMargin]), or the cheapest [take] by cost.
  ///
  /// The [take] floor keeps the requested result count honest: a caller asking
  /// for N ranked candidates gets up to N even on a strong voicing where only
  /// the winner is within the margin (e.g. C E G as Cmaj, or the top-5/top-12
  /// lists the try page and the Why This Chord modal show regardless of cost).
  /// Tooling that wants the full list passes a large [take]. The floor only
  /// engages when the margin set is smaller than [take], i.e. on clear voicings
  /// with few near-top readings, which are cheap to rank anyway; ambiguous and
  /// dense voicings keep the (larger) margin set, so the prune's win is intact.
  List<_Evaluated> _pruneForRanking(List<_Evaluated> out, int take) {
    if (out.length <= take) return out;
    // Implied-root and sounding-root readings are pruned against their own
    // group's cheapest: a hard rule can rank a rootless reading above a
    // cheaper complete one, so the sounding-root minimum must not evict the
    // implied-root group before ranking. In solo analysis no implied
    // candidates exist and this reduces to a single minimum.
    var minSounding = double.infinity;
    var minImplied = double.infinity;
    for (final e in out) {
      final cost = e.candidate.cost;
      if (e.candidate.identity.hasImpliedRoot) {
        if (cost < minImplied) minImplied = cost;
      } else {
        if (cost < minSounding) minSounding = cost;
      }
    }
    final within = [
      for (final e in out)
        if (e.candidate.cost <=
            (e.candidate.identity.hasImpliedRoot ? minImplied : minSounding) +
                rankingPruneMargin)
          e,
    ];
    if (within.length >= take) return within;
    // Margin set is smaller than the requested count. Keep the cheapest [take]
    // by cost; beyond the surfaced set the ranking is essentially cost order, so
    // these fill the lower positions. The margin set is a subset (the cheapest
    // readings), so the #1 pick and surfaced alternatives are still preserved.
    final sorted = [...out]
      ..sort((a, b) => a.candidate.cost.compareTo(b.candidate.cost));
    return sorted.sublist(0, take);
  }

  // ---- Template pricing: fit voicing to chord structure -----------------
  //
  // Weights are tuned empirically to balance:
  // - Structural integrity (required > optional)
  // - Penalty for ambiguity and complexity (missing tones, extras)
  // - Bass role appropriateness

  _PricedTemplate? _priceTemplate({
    required int relMask,
    required int bassInterval,
    required ChordTemplate template,
    required int rootPc,
    required AnalysisContext context,
    bool impliedRoot = false,
    List<CostReason>? reasons,
  }) {
    void add(
      String label,
      double costContribution, {
      String? detail,
      int? intervals,
      int? count,
    }) {
      reasons?.add(
        CostReason(
          label,
          costContribution,
          detail: detail,
          intervals: intervals,
          count: count,
        ),
      );
    }

    if (!impliedRoot && (relMask & 0x1) == 0) return null;

    // A sounding root is always required for stability; an implied root is
    // absent by definition (the caller guarantees it).
    final required = impliedRoot
        ? template.requiredMask
        : template.requiredMask | 0x1;
    final optional = template.optionalMask;
    final penalty = template.penaltyMask;

    if (template.requiresExactMatch && relMask != (required | optional)) {
      return null;
    }

    final missingRequiredMask = required & ~relMask;
    final presentRequiredMask = required & relMask;
    final presentOptionalMask = optional & relMask;
    final functionalPenaltyExtensionsMask = _functionalPenaltyExtensionsMask(
      template: template,
      relMask: relMask,
      bassInterval: bassInterval,
    );

    final missCount = popCount(missingRequiredMask);

    // Allow up to 1 missing required tone for sparse voicings.
    // Example: dominant7 without the 5th (shell voicing) is still valid.
    // More than 1 missing tone suggests wrong template entirely. A power
    // chord is nothing but its fifth, so it gets no such allowance, and an
    // implied-root reading gets none either: with no root sounding, the guide
    // tones are all the identity there is.
    if (missCount > (impliedRoot ? 0 : 1)) return null;
    if (missCount > 0 && template.quality == ChordQuality.power) {
      return null;
    }

    // Extras: tones outside the base template. These may become named
    // extensions in the final chord identity.
    final base = required | optional;
    final extrasMask =
        (relMask & ~(base | penalty)) | functionalPenaltyExtensionsMask;

    // A bare triad plus the major sixth is a sixth chord (C6, Cm6); the add13
    // labeling of the same tones would duplicate the six-family template
    // under a name the symbol guide reserves for seventh chords. When the
    // sixth is the bass, the add13 label compresses into the slash and the
    // reading survives as the conventional triad-over-sixth symbol (A-C-E as
    // C/A), so only tones above the bass trigger the rejection.
    final isBareTriad =
        template.quality == ChordQuality.major ||
        template.quality == ChordQuality.minor;
    if (isBareTriad &&
        (extrasMask & (1 << majorSixthInterval)) != 0 &&
        bassInterval != majorSixthInterval) {
      return null;
    }

    final extensions = _extensionsFromExtras(
      extrasMask,
      has7: template.quality.isSeventhFamily,
      quality: template.quality,
    );

    // The seventh is what makes a chord a ninth, eleventh, or thirteenth.
    // Without that required seventh sounding, the same tones should be named
    // as add tones or sixth chords, not as a stacked seventh-family extension.
    if (_missesSeventhUnderStackedExtensions(
      template: template,
      missingRequiredMask: missingRequiredMask,
      extensions: extensions,
    )) {
      return null;
    }

    if (_flatFiveConflictsWithNaturalThirteenth(
      quality: template.quality,
      extensions: extensions,
      relMask: relMask,
      bassInterval: bassInterval,
    )) {
      return null;
    }

    final roles = ChordToneRoles.build(
      quality: template.quality,
      extensions: extensions,
      relMask: relMask,
    );

    var cost = 0.0;

    final vocabulary = _vocabularyCost(template.quality);
    if (vocabulary != 0) {
      cost += vocabulary;
      add(CostReasonLabel.vocabularyRarity, vocabulary);
    }

    // Core tones are free; report them so downstream tone ledgers can show
    // what the name accounts for.
    add(
      CostReasonLabel.requiredTones,
      0,
      detail: 'count=${popCount(presentRequiredMask)}',
      intervals: presentRequiredMask,
      count: popCount(presentRequiredMask),
    );
    if (presentOptionalMask != 0) {
      add(
        CostReasonLabel.optionalTones,
        0,
        detail: 'count=${popCount(presentOptionalMask)}',
        intervals: presentOptionalMask,
        count: popCount(presentOptionalMask),
      );
    }

    // A complete plain triad voiced over its added ninth in the bass is the
    // upper-structure slash idiom (D/E, C#/D#): the bass reads as an
    // independent pedal, not as chord color the name must justify.
    final isUpperTriadOverNinthBass =
        (template.quality == ChordQuality.major ||
            template.quality == ChordQuality.minor) &&
        bassInterval == majorSecondInterval &&
        extensions.length == 1 &&
        extensions.contains(ChordExtension.add9) &&
        (relMask & (1 << perfectFifthInterval)) != 0;

    final isStackedColor = extensions.length > 1;
    final isStackedChromaticAdd =
        isStackedColor &&
        (extensions.contains(ChordExtension.addFlat9) ||
            extensions.contains(ChordExtension.addSharp9));

    // Each color tone the name appends is priced by its role; tones with no
    // role are contradictions the name cannot account for.
    var colorCost = 0.0;
    var colorMask = 0;
    var unexplainedMask = 0;
    final colorDetails = reasons == null ? null : <String>[];
    for (var interval = 1; interval < 12; interval++) {
      if ((relMask & (1 << interval)) == 0) continue;
      final role = roles[interval];
      if (role == null) {
        unexplainedMask |= 1 << interval;
        continue;
      }
      final price = role == ChordToneRole.add9 && isUpperTriadOverNinthBass
          ? _upperTriadNinthBassCost
          : _tonePrice(
              role: role,
              quality: template.quality,
              relMask: relMask,
              roles: roles,
              isBassTone: interval == bassInterval,
              isStackedColor: isStackedColor,
              isStackedChromaticAdd: isStackedChromaticAdd,
            );
      if (price == 0) continue;
      colorCost += price;
      colorMask |= 1 << interval;
      colorDetails?.add('${role.name}=${price.toStringAsFixed(2)}');
    }
    if (colorCost != 0) {
      cost += colorCost;
      add(
        CostReasonLabel.colorTones,
        colorCost,
        detail: colorDetails?.join(' '),
        intervals: colorMask,
      );
    }

    // A bare root-third-sixth set is better read as the relative minor's
    // triad; a sixth chord needs its fifth to anchor the sixth as color.
    final isBareFifthlessSixChord =
        template.quality.isSixFamily &&
        (relMask & (1 << perfectFifthInterval)) == 0 &&
        popCount(relMask) == 3;
    if (isBareFifthlessSixChord) {
      cost += _sixChordNoFifthSurcharge;
      add(CostReasonLabel.fifthlessSixth, _sixChordNoFifthSurcharge);
    }

    // A power chord is only a credible reading when the bare fifth plus its
    // named colors account for every sounding tone; a leftover tone means
    // some other harmony is in play. An implied-root reading is held to the
    // same bar: hypothesizing an unplayed root is only credible when the name
    // fully explains what was played.
    if (unexplainedMask != 0 &&
        (impliedRoot || template.quality == ChordQuality.power)) {
      return null;
    }

    if (unexplainedMask != 0) {
      final unexplainedCost = popCount(unexplainedMask) * unexplainedToneCost;
      cost += unexplainedCost;
      add(
        CostReasonLabel.penaltyTones,
        unexplainedCost,
        detail: 'count=${popCount(unexplainedMask)}',
        intervals: unexplainedMask,
        count: popCount(unexplainedMask),
      );
    }

    if (missingRequiredMask != 0) {
      var missingCost = 0.0;
      for (var interval = 1; interval < 12; interval++) {
        if ((missingRequiredMask & (1 << interval)) != 0) {
          missingCost += _missingEssentialCost(interval);
        }
      }
      cost += missingCost;
      add(
        CostReasonLabel.missingRequired,
        missingCost,
        detail: 'count=$missCount',
        intervals: missingRequiredMask,
        count: missCount,
      );
    }

    if (impliedRoot) {
      cost += _missingRootCost;
      add(
        CostReasonLabel.missingRoot,
        _missingRootCost,
        intervals: 0x1,
        count: 1,
      );
    }

    // A rootless voicing puts a guide tone in the lowest voice by design, so
    // its bass placement carries no evidence against the reading.
    final bassCost = impliedRoot || isUpperTriadOverNinthBass
        ? 0.0
        : _bassPlacementCost(roles[bassInterval], template.quality);
    if (bassCost != 0) {
      cost += bassCost;
      add(CostReasonLabel.bassFit, bassCost, detail: 'interval=$bassInterval');
    }

    return _PricedTemplate(cost: cost, extensions: extensions, roles: roles);
  }

  /// How readily a musician reaches for this quality name. Everyday names
  /// (major, minor, 7, m7, maj7, sus4, 6ths) are free; a rare name has to be
  /// much cheaper at explaining the tones than a common one to win.
  static double _vocabularyCost(ChordQuality quality) {
    return switch (quality.vocabularyTier) {
      ChordVocabularyTier.common => 0,
      ChordVocabularyTier.marked => _vocabularyMarked,
      ChordVocabularyTier.uncommon => _vocabularyUncommon,
      ChordVocabularyTier.rare => _vocabularyRare,
    };
  }

  double _tonePrice({
    required ChordToneRole role,
    required ChordQuality quality,
    required int relMask,
    required Map<int, ChordToneRole> roles,
    required bool isBassTone,
    required bool isStackedColor,
    required bool isStackedChromaticAdd,
  }) {
    final hasNinth = (relMask & (1 << majorSecondInterval)) != 0;
    final hasMajorThirdRole = roles[majorThirdInterval] == ChordToneRole.major3;

    switch (role) {
      case ChordToneRole.root:
      case ChordToneRole.sus2:
      case ChordToneRole.minor3:
      case ChordToneRole.major3:
      case ChordToneRole.sus4:
      case ChordToneRole.flat5:
      case ChordToneRole.perfect5:
      case ChordToneRole.sharp5:
      case ChordToneRole.sixth:
      case ChordToneRole.dim7:
      case ChordToneRole.flat7:
      case ChordToneRole.major7:
        return 0;

      case ChordToneRole.nine:
        return _naturalExtensionPrice(_priceNine, quality);
      case ChordToneRole.add9:
        return _naturalExtensionPrice(_priceAdd9, quality);
      case ChordToneRole.eleven:
        // An 11 with no 9 below it is really an add-tone wearing a stack
        // name, unless the 11 is the bass itself (the sus-pedal idiom, e.g.
        // Am7/D, needs no stack support); an 11 against a major third is the
        // classic avoid-tone clash.
        return _naturalExtensionPrice(_priceEleven, quality) +
            (hasNinth || isBassTone ? 0 : _unsupportedElevenSurcharge) +
            (hasMajorThirdRole ? _elevenOverMajorThirdSurcharge : 0);
      case ChordToneRole.add11:
        return _naturalExtensionPrice(_priceAdd11, quality) +
            (hasMajorThirdRole ? _elevenOverMajorThirdSurcharge : 0);
      case ChordToneRole.thirteen:
        return _naturalExtensionPrice(_priceThirteen, quality) +
            (hasNinth ? 0 : _unsupportedThirteenSurcharge) +
            (_hasSharpFifthRole(roles) ? _splitSharpFiveThirteenSurcharge : 0);
      case ChordToneRole.add13:
        return _naturalExtensionPrice(_priceAdd13, quality);

      case ChordToneRole.flat9:
      case ChordToneRole.sharp9:
      case ChordToneRole.sharp11:
      case ChordToneRole.flat13:
      case ChordToneRole.splitMinor3:
      case ChordToneRole.addSharp9:
        return _alteredTonePrice(
          role: role,
          quality: quality,
          relMask: relMask,
          roles: roles,
          isStackedColor: isStackedColor,
          isStackedChromaticAdd: isStackedChromaticAdd,
        );
    }
  }

  double _alteredTonePrice({
    required ChordToneRole role,
    required ChordQuality quality,
    required int relMask,
    required Map<int, ChordToneRole> roles,
    required bool isStackedColor,
    required bool isStackedChromaticAdd,
  }) {
    bool has(int interval) => (relMask & (1 << interval)) != 0;

    var price = switch (role) {
      ChordToneRole.flat9 => _priceFlat9,
      ChordToneRole.sharp9 => _priceSharp9,
      ChordToneRole.sharp11 => _priceSharp11,
      ChordToneRole.flat13 => _priceFlat13,
      _ => _priceSplitThird,
    };
    if (role == ChordToneRole.sharp11 && _hasNaturalFourthRole(roles)) {
      price += _splitFourthSurcharge;
    }
    // A #11 is color above an occupied fifth slot; with no fifth-slot tone
    // sounding at all, the tritone reads as the altered fifth instead
    // (C-E-Gb is C(b5), not a fifthless Cadd#11). A natural 13 keeps the
    // #11 reading (C13#11 shells; the b5-plus-13 template is rejected
    // outright), as do fifthless major-family Lydian stacks with a
    // supporting ninth (Dbmaj9#11).
    final majorFamilyLydianStack =
        has(majorSecondInterval) &&
        switch (quality) {
          ChordQuality.major ||
          ChordQuality.major6 ||
          ChordQuality.major7 => true,
          _ => false,
        };
    if (role == ChordToneRole.sharp11 &&
        !has(perfectFifthInterval) &&
        !has(minorSixthInterval) &&
        !has(majorSixthInterval) &&
        !majorFamilyLydianStack) {
      price += _sharpElevenEmptyFifthSurcharge;
    }
    // Same fifth-slot logic for the flat thirteen: with no fifth-slot tone
    // sounding, the m6 interval reads as a sharp five (G-B-F-A-D# is G7#5(9),
    // not a fifthless G9b13). On a minor-third flat-five host (m7b5, dim) the
    // flat five occupies the slot and the sharp-five re-reading would respell
    // the whole chord, so Em7(b5,b13) keeps its plain name; major-third
    // flat-five hosts keep the surcharge because the #5/#11 reading stays
    // available (whole-tone sets prefer C9(#5,#11) over C9(b5,b13)).
    // Minor-major sevenths are exempt: the fifthless m(maj7)b13 is the
    // harmonic-minor tonic idiom and has no competing sharp-five reading.
    final flatFiveMinorHost =
        roles[tritoneInterval] == ChordToneRole.flat5 &&
        roles[minorThirdInterval] == ChordToneRole.minor3;
    if (role == ChordToneRole.flat13 &&
        !has(perfectFifthInterval) &&
        !flatFiveMinorHost &&
        quality != ChordQuality.minorMajor7) {
      price += _flatThirteenEmptyFifthSurcharge;
    }
    if ((role == ChordToneRole.flat9 || role == ChordToneRole.sharp9) &&
        _hasNaturalSecondRole(roles)) {
      price += _splitSecondSurcharge;
    }
    if (role == ChordToneRole.flat13 && _hasNaturalSixthRole(roles)) {
      price += analysisProfile == ChordAnalysisProfile.whatKeyPaper2026
          ? _paper2026SplitSixthSurcharge
          : _splitSixthSurcharge;
    }
    // Flat-nine color on altered major-seventh hosts is much rarer than the
    // same alteration on a dominant. The off-dominant multiplier below doubles
    // this surcharge along with the base alteration price.
    if (role == ChordToneRole.flat9 &&
        analysisProfile == ChordAnalysisProfile.current &&
        (quality == ChordQuality.major7Flat5 ||
            quality == ChordQuality.major7Sharp5)) {
      price += _alteredMajorSeventhFlatNineSurcharge;
    }
    // A b9 stacked among other colors on a major sixth or seventh chord is
    // the alt sound without its dominant context; musicians do not write
    // F#6(b9,#11). As the single color it stays the harmonic-minor gesture
    // (C6b9, Cmaddb9), like the add-b9 Phrygian color on a bare triad.
    if (role == ChordToneRole.flat9 &&
        isStackedColor &&
        switch (quality) {
          ChordQuality.major6 ||
          ChordQuality.major7 ||
          ChordQuality.major7Flat5 ||
          ChordQuality.major7Sharp5 => true,
          _ => false,
        }) {
      price += _flatNineMajorHostSurcharge;
    }
    if (role == ChordToneRole.flat9 &&
        quality == ChordQuality.minorMajor7 &&
        roles[perfectFifthInterval] != ChordToneRole.perfect5 &&
        roles.containsValue(ChordToneRole.eleven)) {
      price += _minorMajorFlatNineElevenSurcharge;
    }
    // A lone chromatic add is the Phrygian gesture (Cmaddb9); stacked among
    // other colors it reads as alt tension the name fails to integrate
    // (F#(addb9,#11,add13)).
    if (isStackedChromaticAdd &&
        (role == ChordToneRole.flat9 || role == ChordToneRole.splitMinor3)) {
      price += _stackedChromaticAddSurcharge;
    }
    // The alt-palette discount belongs to sounding dominants; a dominant name
    // whose flat seventh is missing is a phantom host, and its alterations
    // pay the off-dominant rate like any other quality's.
    final soundingDominant =
        quality.isDominantFamily && has(minorSeventhInterval);
    final multiplied =
        !soundingDominant &&
        !(role == ChordToneRole.sharp11 && quality.isSharpElevenFriendly);
    return multiplied ? price * _offDominantAlterationMultiplier : price;
  }

  static double _naturalExtensionPrice(double base, ChordQuality quality) {
    return quality.isMarkedExtensionHost
        ? base * _markedHostExtensionMultiplier
        : base;
  }

  static bool _hasNaturalFourthRole(Map<int, ChordToneRole> roles) {
    return roles.containsValue(ChordToneRole.sus4) ||
        roles.containsValue(ChordToneRole.eleven) ||
        roles.containsValue(ChordToneRole.add11);
  }

  static bool _hasNaturalSecondRole(Map<int, ChordToneRole> roles) {
    return roles.containsValue(ChordToneRole.sus2) ||
        roles.containsValue(ChordToneRole.nine) ||
        roles.containsValue(ChordToneRole.add9);
  }

  static bool _hasNaturalSixthRole(Map<int, ChordToneRole> roles) {
    return roles.containsValue(ChordToneRole.sixth) ||
        roles.containsValue(ChordToneRole.thirteen) ||
        roles.containsValue(ChordToneRole.add13);
  }

  static bool _hasSharpFifthRole(Map<int, ChordToneRole> roles) {
    return roles.containsValue(ChordToneRole.sharp5);
  }

  /// True when a seventh-family name is missing its seventh while promoting
  /// stacked natural extensions (a 9, 11, or 13 in the symbol). Under the
  /// [isSeventhFamily] guard, interval 9 can only be a required diminished
  /// seventh, never a sixth.
  static bool _missesSeventhUnderStackedExtensions({
    required ChordTemplate template,
    required int missingRequiredMask,
    required Set<ChordExtension> extensions,
  }) {
    if (!template.quality.isSeventhFamily) return false;
    const seventhMask =
        (1 << majorSixthInterval) |
        (1 << minorSeventhInterval) |
        (1 << majorSeventhInterval);
    if ((missingRequiredMask & seventhMask) == 0) return false;
    return extensions.contains(ChordExtension.nine) ||
        extensions.contains(ChordExtension.eleven) ||
        extensions.contains(ChordExtension.thirteen);
  }

  /// Price of a required tone the voicing omits, by the degree it would fill.
  /// A perfect fifth is routinely dropped; a third, seventh, or the tone that
  /// defines a suspension or altered fifth is the name's identity.
  static double _missingEssentialCost(int interval) {
    return switch (interval) {
      majorSecondInterval || perfectFourthInterval => _missingSusToneCost,
      minorThirdInterval || majorThirdInterval => _missingThirdCost,
      diminishedFifthInterval ||
      augmentedFifthInterval => _missingAlteredFifthCost,
      perfectFifthInterval => _missingFifthCost,
      _ => _missingSeventhCost,
    };
  }

  static double _bassPlacementCost(
    ChordToneRole? bassRole,
    ChordQuality quality,
  ) {
    // Diminished and augmented chords invert freely; their fifth in the bass
    // is a plain core tone, unlike the altered fifth of a m#5 or 7#5.
    final fifthIsDefinitional = switch (quality) {
      ChordQuality.diminished ||
      ChordQuality.diminished7 ||
      ChordQuality.halfDiminished7 ||
      ChordQuality.augmented => true,
      _ => false,
    };
    if (bassRole == null) return _bassUnexplainedCost;
    return switch (bassRole) {
      ChordToneRole.root => 0,
      ChordToneRole.sus2 || ChordToneRole.sus4 => _bassSusToneCost,
      ChordToneRole.flat5 || ChordToneRole.sharp5 =>
        fifthIsDefinitional ? _bassCoreToneCost : _bassAlteredFifthCost,
      ChordToneRole.minor3 ||
      ChordToneRole.major3 ||
      ChordToneRole.perfect5 ||
      ChordToneRole.sixth ||
      ChordToneRole.dim7 ||
      ChordToneRole.flat7 ||
      ChordToneRole.major7 => _bassCoreToneCost,
      ChordToneRole.nine ||
      ChordToneRole.eleven ||
      ChordToneRole.thirteen => _bassNaturalColorCost,
      ChordToneRole.add9 ||
      ChordToneRole.add11 ||
      ChordToneRole.add13 => _bassAddToneCost,
      ChordToneRole.flat9 ||
      ChordToneRole.sharp9 ||
      ChordToneRole.sharp11 ||
      ChordToneRole.flat13 ||
      ChordToneRole.splitMinor3 ||
      ChordToneRole.addSharp9 => _bassAlteredColorCost,
    };
  }

  static int _functionalPenaltyExtensionsMask({
    required ChordTemplate template,
    required int relMask,
    required int bassInterval,
  }) {
    final quality = template.quality;
    if (_supportsSplitThirdMajorFamilyVoicing(bassInterval, relMask) &&
        _isSplitThirdMajorQuality(quality, relMask)) {
      return 1 << minorThirdInterval;
    }

    if (quality == ChordQuality.major7 &&
        _hasMajorSeventhSharpNineColor(relMask)) {
      return 1 << minorThirdInterval;
    }

    final isSharpNineDominantQuality =
        quality == ChordQuality.dominant7 ||
        quality == ChordQuality.dominant7Flat5 ||
        quality == ChordQuality.dominant7Sharp5;
    if (!isSharpNineDominantQuality) return 0;

    final hasDominantShell =
        (relMask & (1 << majorThirdInterval)) != 0 &&
        (relMask & (1 << minorSeventhInterval)) != 0;
    if (!hasDominantShell) return 0;

    // In dominant context, interval 3 is the altered ninth rather than a
    // contradictory minor third: G-B-D-F-A# is G7#9, not plain G7 with a penalty.
    const sharpNineBit =
        1 << minorThirdInterval; // same interval, dominant function
    if ((relMask & sharpNineBit) == 0) return 0;
    return sharpNineBit;
  }

  static bool _hasMajorSeventhSharpNineColor(int relMask) {
    const majorThirdBit = 1 << majorThirdInterval;
    const sharpNineBit = 1 << minorThirdInterval;
    const majorSeventhBit = 1 << majorSeventhInterval;

    return (relMask & majorThirdBit) != 0 &&
        (relMask & sharpNineBit) != 0 &&
        (relMask & majorSeventhBit) != 0;
  }

  static bool _supportsSplitThirdMajorFamilyVoicing(
    int bassInterval,
    int relMask,
  ) {
    if (bassInterval == 0) return true;

    final isConventionalInversion =
        bassInterval == majorThirdInterval ||
        bassInterval == perfectFifthInterval;
    final hasPerfectFifth = (relMask & (1 << perfectFifthInterval)) != 0;
    return isConventionalInversion && hasPerfectFifth;
  }

  static bool _allowsAddSharpNine(ChordQuality quality) {
    return quality == ChordQuality.major ||
        quality == ChordQuality.major6 ||
        quality == ChordQuality.augmented;
  }

  static bool _isSplitThirdMajorQuality(ChordQuality quality, int relMask) {
    if (!_allowsAddSharpNine(quality)) return false;
    const majorThirdBit = 1 << majorThirdInterval;
    const minorThirdBit = 1 << minorThirdInterval;
    return (relMask & majorThirdBit) != 0 && (relMask & minorThirdBit) != 0;
  }

  static bool _flatFiveConflictsWithNaturalThirteenth({
    required ChordQuality quality,
    required Set<ChordExtension> extensions,
    required int relMask,
    required int bassInterval,
  }) {
    final isFlatFiveQuality =
        quality == ChordQuality.dominant7Flat5 ||
        quality == ChordQuality.major7Flat5;
    if (!isFlatFiveQuality) return false;

    // With a natural thirteenth present, the tritone usually functions as #11
    // color rather than a literal b5 core tone: C-E-Bb-D-F#-A -> C13#11.
    // If the perfect fifth is absent, the flat seventh is in the bass, and the
    // extension stack is the clean 9 + 13 color, the same tritone can be the
    // defining altered fifth: Eb-G-Db-F-A-C -> Eb13b5/Db. Keep altered/split
    // ninth stacks on the sharper #11 side.
    if ((relMask & (1 << perfectFifthInterval)) == 0 &&
        bassInterval == minorSeventhInterval &&
        extensions.length == 2 &&
        extensions.contains(ChordExtension.nine) &&
        extensions.contains(ChordExtension.thirteen)) {
      return false;
    }
    return extensions.contains(ChordExtension.thirteen) ||
        extensions.contains(ChordExtension.add13);
  }

  /// Rotates a 12-bit pitch-class mask to be relative to the given root.
  /// Example: {C, E, G} with root=C → bitmask 100010001 (intervals 0, 4, 7)
  static int _rotateMaskToRoot(int pcMask, int rootPc) {
    var rel = 0;
    for (var pc = 0; pc < 12; pc++) {
      if ((pcMask & (1 << pc)) == 0) continue;
      final interval = intervalAboveRoot(pc, rootPc);
      rel |= (1 << interval);
    }
    return rel;
  }

  /// Extracts extension tokens from the "extra" tone mask.
  ///
  /// Maps interval positions to ChordExtension enums:
  /// - Alterations: b9(1), #9(3), #11(6), b13(8)
  /// - Natural extensions: 9(2), 11(5), 13(9)
  ///
  /// Natural extensions become "add9/add11/add13" for triads,
  /// or stacked "9/11/13" for 7th-family chords (where they're more idiomatic).
  static Set<ChordExtension> _extensionsFromExtras(
    int extrasMask, {
    required bool has7,
    required ChordQuality quality,
  }) {
    final out = <ChordExtension>{};

    // Alterations.
    if ((extrasMask & (1 << minorSecondInterval)) != 0) {
      // Without a seventh (or sixth) to anchor a stacked ♭9, the flat ninth is
      // an added tone: C-E-G-D♭ is Cadd♭9, not C♭9. Mirrors add9/add#9.
      out.add(
        has7 || quality.isSixFamily
            ? ChordExtension.flat9
            : ChordExtension.addFlat9,
      );
    }
    if ((extrasMask & (1 << minorThirdInterval)) != 0) {
      out.add(
        has7 || !_allowsAddSharpNine(quality)
            ? ChordExtension.sharp9
            : ChordExtension.addSharp9,
      );
    }
    if ((extrasMask & (1 << sharpEleventhInterval)) != 0) {
      out.add(ChordExtension.sharp11);
    }
    if ((extrasMask & (1 << minorSixthInterval)) != 0) {
      out.add(ChordExtension.flat13);
    }

    // Natural extensions/add tones. A natural 9, 11, or 13 reads as a stacked
    // upper extension (eligible to headline) whenever the chord has a seventh;
    // the lower stack members are optional, so C-E-G-B♭-A is C13 and
    // C-E-G-B♭-F is C11, not C7(addN). Without a seventh the tone is an added
    // color (and a plain triad plus a sixth is a sixth chord).
    final has9 = (extrasMask & (1 << majorSecondInterval)) != 0;
    final has11 = (extrasMask & (1 << perfectFourthInterval)) != 0;
    final has13 = (extrasMask & (1 << majorSixthInterval)) != 0;

    if (has9) out.add(has7 ? ChordExtension.nine : ChordExtension.add9);
    if (has11) out.add(has7 ? ChordExtension.eleven : ChordExtension.add11);
    if (has13) out.add(has7 ? ChordExtension.thirteen : ChordExtension.add13);

    return out;
  }
}

class _Evaluated {
  final ChordCandidate candidate;
  final ChordTemplate template;
  final List<CostReason>? reasons;

  const _Evaluated({
    required this.candidate,
    required this.template,
    required this.reasons,
  });
}

class _PricedTemplate {
  final double cost;
  final Set<ChordExtension> extensions;
  final Map<int, ChordToneRole> roles;

  const _PricedTemplate({
    required this.cost,
    required this.extensions,
    required this.roles,
  });
}
