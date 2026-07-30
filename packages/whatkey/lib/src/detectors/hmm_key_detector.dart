import 'dart:math' as math;

import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'detector_support.dart';
import 'hybrid_key_detector.dart';
import 'key_detector.dart';
import 'key_profiles.dart';
import 'key_space.dart';

/// **App status: Shipped.**
///
/// Hidden Markov key detection (design plan section 2c): the key is a hidden
/// state over the 24-key space, observed through the hybrid detector's
/// per-key scores.
///
/// Per event, the filtered posterior is updated with the causal forward
/// algorithm (never Viterbi, which needs the future the task definition
/// forbids): predict through the transition matrix, then weigh by an
/// emission distribution obtained as a softmax of the hybrid's scores at
/// [emissionTemperature]. The claim is the posterior's top key; confidence is
/// its actual posterior probability, and abstention triggers when the
/// posterior margin between the top two keys falls below [marginFloor].
///
/// The transition matrix is built from three parameters: [selfTransition] is
/// the probability mass of staying in the current key (the principled form of
/// the persistence that decay tuning and claim hysteresis approximated, log
/// entry 2026-07-07-07); the remaining mass goes to other keys weighted by
/// [fifthsDecay] per step of key-signature distance on the circle of fifths
/// (relative keys are at distance zero) and discounted by [modeSwitchFactor]
/// when the mode changes.
///
/// NOTE: https://whatchord.earthmanmuons.com/articles/key-detection-algorithm.html
/// documents this model in detail. Update the article when the update loop,
/// the transition parameters, or the shipped constants change.
class HmmKeyDetector implements KeyDetector {
  /// The emission memory selects which timescale of key structure the
  /// detector reports (log entry 2026-07-07-16): one-second, effectively
  /// per-event emissions win on tonicization-scale labels (When in Rome),
  /// while long memory wins accuracy and stability on section-scale labels
  /// (Isophonics, ASAP). WhatChord's key indicator means the settled,
  /// section-level key (product decision, log entry 2026-07-07-17), so the
  /// shipped default is long memory; pass one second to evaluate against
  /// tonicization-scale ground truth. The harness references this constant
  /// so the CLI default cannot silently diverge.
  static const int defaultEmissionHalfLifeSeconds = 30;

  /// Shipped operating point on the calibration curve (log entries
  /// 2026-07-07-12 and -17): clean behavioral suite at the section-scale
  /// default.
  static const double defaultMarginFloor = 0.3;

  /// **App status: Disabled.**
  ///
  /// Emission blends for the shipped section-scale configuration (log entry
  /// 2026-07-07-18): the ablation factorial showed the functional and
  /// progression terms vote for exactly the tonicization-scale excursions
  /// the product absorbs, and removing them is a significant paired win on
  /// section-scale labels (and what finally fixed blues). The hybrid
  /// detector's named research baseline keeps the earlier nonzero blends for
  /// tonicization-scale work; its unnamed defaults match these shipped values.
  static const double defaultEmissionFunctionalBlend =
      HybridKeyDetector.defaultFunctionalBlend;

  /// **App status: Disabled.**
  ///
  /// See [defaultEmissionFunctionalBlend].
  static const double defaultEmissionProgressionBlend =
      HybridKeyDetector.defaultProgressionBlend;

  /// **App status: Disabled.**
  ///
  /// See [defaultEmissionFunctionalBlend].
  static const bool defaultEmissionConfidenceWeighted =
      HybridKeyDetector.defaultConfidenceWeighted;

  /// Log-odds tilt applied within the parallel-key pair rooted on the event's
  /// chord when that chord has a home quality ([KeySpace.tonicQualities]):
  /// toward major for major-tonic qualities, toward minor for minor-tonic
  /// ones. The pair's emission sum is preserved, so the tilt redistributes
  /// mode evidence without adding evidence for any other tonic; this is the
  /// mode-only extraction of the evidence model's rejected tonic bonus (log
  /// entry 2026-07-07-11), which cannot fight modulation tracking by
  /// construction. Adopted at 2 (log entry 2026-07-07-23): a significant
  /// paired exact win on both development rulers, parallel-mode confusion
  /// roughly halved, no behavioral-suite or stability cost on the product
  /// genre; strengths 2-4 are a plateau, so the gentlest plateau value ships.
  static const double defaultModeTilt = 2;

  /// **App status: Disabled.**
  ///
  /// Log-odds tilts within the relative pair of the event chord's home key
  /// (same key signature, so neither can add evidence for any other
  /// signature; the relative analog of [modeTilt], design plan mode
  /// disambiguation). Relative twins share every pitch class, and the
  /// rival's tonic chord is common diatonic harmony (vi/III), so isolated
  /// chord quality is weak evidence; each variant gates on a sharper cue.
  /// [relativeTilt] fires when the chord's root is also its bass;
  /// [relativeCadenceTilt] fires when the previous event was a
  /// dominant-quality chord a fifth above (a cadential resolution). Neither
  /// variant met the adoption bar, so both remain disabled in the app and are
  /// retained only for research reproduction (log entry 2026-07-07-24).
  static const double defaultRelativeTilt = 0;

  /// **App status: Disabled.**
  ///
  /// See [defaultRelativeTilt].
  static const double defaultRelativeCadenceTilt = 0;

  /// **App status: Disabled.**
  ///
  /// Log-odds tilt toward the major twin of each relative pair on events
  /// that carry no minor-defining evidence for that pair's minor key: the
  /// minor key's raised seventh is not sounding and the event chord is not a
  /// minor-tonic quality on its root. Pair sums are conserved (the mode-tilt
  /// construction), so no other signature gains or loses evidence.
  ///
  /// Aimed at a measured structural asymmetry (whatkey-local log
  /// 2026-07-26-07): the minor profile spreads weight across both sixths and
  /// both sevenths, so every relative-major scale tone carries non-trivial
  /// minor weight and sustained major-key content never votes against the
  /// relative minor, while minor-specific content votes hard against the
  /// major twin. The result is relative confusion that leans claimed-minor
  /// against a major truth. This tilt supplies the missing vote in the one
  /// direction the profiles cannot. This is a research-only option, disabled
  /// in the app pending measurement.
  static const double defaultRelativeEvidenceTilt = 0;

  /// **App status: Disabled.**
  ///
  /// How many recent events (including the current one) the
  /// [relativeEvidenceTilt] gate looks across. At 1 the gate is per-event,
  /// which punishes genuine minor passages between cadences (the raised
  /// seventh sounds at cadences, not in every chord); a wider window tests
  /// the actual structural claim, that sustained content without the raised
  /// seventh is major evidence. It has no effect in the app while
  /// [relativeEvidenceTilt] is disabled.
  static const int defaultRelativeEvidenceWindow = 1;

  /// Log-space boost on transition mass into a key whose cadence the incoming
  /// event completes: the previous event was a dominant-seventh-family chord
  /// rooted a fifth above the current chord's root, and the current chord has
  /// a tonic quality in the target mode. Unlike the rejected emission blends,
  /// this conditions the transition prior, not the evidence: it gives the
  /// chain permission to move exactly when harmony licenses a key change,
  /// while ordinary tonicization drift still pays the full switch cost. Each
  /// row renormalizes, so a cadence in the incumbent key stabilizes it rather
  /// than leaking mass. Two deliberate exclusions keep the trigger honest: a
  /// plain major triad does not count as the dominant (two root-position
  /// major triads a fifth apart are the same bigram as I moving to IV, so
  /// only the seventh disambiguates the direction), and dominant-quality
  /// resolution targets do not count as tonics (a blues I7 to IV7 would
  /// otherwise read as V7 to I in the IV key, the failure that disqualified
  /// the functional blend). Adopted at 4 per the decision in
  /// research/whatkey-local/log/2026-07-26-05: local-key exactness improves
  /// at every preset timescale on both classical rulers (paired wins on the
  /// primary ruler and the performed-input overlap), the behavioral suite is
  /// clean, and the accepted cost is about one point of pop coverage at the
  /// stable timescale and one to two points of pop exactness at the faster
  /// ones (full matrix in that entry).
  static const double defaultCadenceBoost = 4;

  /// **App status: Disabled.**
  ///
  /// Log-space boost for the plain-triad variant of the cadence trigger: the
  /// previous event is a plain major triad a fifth above a tonic-quality
  /// current chord, and the event before that was predominant-functioned in
  /// the target key (ii-family on the second degree, or IV-family on the
  /// fourth). The predominant gate is what [cadenceBoost] cannot have: two
  /// root-position major triads a fifth apart are the same bigram as I moving
  /// to IV, but ii-V-I and IV-V-I trigrams are directional. Independent of
  /// [cadenceBoost] and mutually exclusive with it per event (a
  /// dominant-seventh previous chord takes the main trigger). Measurement found
  /// the trigger inert, with no additional matched modulations, so it remains
  /// disabled and is retained for research reproduction (whatkey-local log
  /// 2026-07-26-04).
  static const double defaultCadenceTriadBoost = 0;

  /// **App status: Disabled.**
  ///
  /// Multiplier on the claim margin floor for the event that fires the
  /// cadence trigger. The residual after the cadence boost is
  /// boundary-shaped: nearly half of all abstentions sit within two events
  /// of an annotated key change (whatkey-local log 2026-07-26-12), and the
  /// cadence event is the one moment a trusted signal has just moved the
  /// posterior, so the gate can afford to be braver exactly there. 1 keeps
  /// the shipped floor unchanged. This experimental adjustment is therefore
  /// neutral in the app and retained for research evaluation.
  static const double defaultCadenceMarginFactor = 1;

  /// **App status: Disabled.**
  ///
  /// Log-space boost applied once, on the first event after a reset, to the
  /// key that reads that chord as its tonic (mode from the chord quality,
  /// per [KeySpace.tonicQualities]). Musicians usually start on or near the
  /// tonic; a uniform prior wastes that. Targets warmup, about a fifth of
  /// abstentions (whatkey-local log 2026-07-26-12). This is a research-only
  /// option and is disabled in the app.
  static const double defaultColdStartTonicPrior = 0;

  /// **App status: Disabled.**
  ///
  /// Multiplier on transition weight between relative major/minor twins.
  /// The kernel places relative pairs at signature distance zero, so a
  /// relative switch is the cheapest move in the space and relative
  /// confusion is 8.6% of claims on the DCML diagnostic (chord-context log
  /// 2026-07-20-18). Values below 1 make the twin pay more than its
  /// signature distance suggests. This experimental adjustment is neutral at
  /// 1 in the app and retained for research evaluation.
  static const double defaultRelativeSwitchFactor = 1;

  final HybridKeyDetector _emissions;

  /// Probability mass of staying in the current key per event.
  final double selfTransition;

  /// Off-key transition weight per step of circle-of-fifths distance.
  final double fifthsDecay;

  /// Discount on transitions that change mode.
  final double modeSwitchFactor;

  /// Softmax temperature converting hybrid scores into emissions.
  final double emissionTemperature;

  /// Events required before the detector may claim a key. Shipped at 1 per
  /// the decision in research/whatkey-local/log/2026-07-26-15: the margin
  /// floor is the real gate (deliberately ambiguous openings still abstain),
  /// and letting confident first-chord claims through improves exact
  /// accuracy on both classical rulers and the performed-input overlap with
  /// significance, while the key indicator lights on the first chord. The
  /// original value of 3 predated the HMM and was never re-measured until
  /// that entry; the paper recipes pin it.
  static const int defaultMinEvents = 1;

  /// See [defaultMinEvents].
  final int minEvents;

  /// Minimum posterior margin between the top two keys to claim; below it
  /// the detector abstains.
  final double marginFloor;

  /// Parallel-pair mode tilt strength (see [defaultModeTilt]).
  final double modeTilt;

  /// Relative-pair tilt strength (see [defaultRelativeTilt]).
  final double relativeTilt;

  /// Cadence-gated relative-pair tilt strength (see [defaultRelativeTilt]).
  final double relativeCadenceTilt;

  /// Minor-evidence-gated relative-pair tilt (see
  /// [defaultRelativeEvidenceTilt]).
  final double relativeEvidenceTilt;

  /// Gate window for [relativeEvidenceTilt] (see
  /// [defaultRelativeEvidenceWindow]).
  final int relativeEvidenceWindow;

  /// Cadence-conditioned transition boost (see [defaultCadenceBoost]).
  final double cadenceBoost;

  /// Predominant-gated plain-triad cadence boost (see
  /// [defaultCadenceTriadBoost]).
  final double cadenceTriadBoost;

  /// Cadence-event margin relief (see [defaultCadenceMarginFactor]).
  final double cadenceMarginFactor;

  /// First-event tonic prior (see [defaultColdStartTonicPrior]).
  final double coldStartTonicPrior;

  /// Relative-twin transition multiplier (see [defaultRelativeSwitchFactor]).
  final double relativeSwitchFactor;
  ChordIdentity? _previousIdentity;
  ChordIdentity? _penultimateIdentity;

  late final List<List<double>> _transition = _buildTransitionMatrix();
  final List<double> _posterior = List.filled(24, 1 / 24);
  int _eventCount = 0;

  HmmKeyDetector({
    KeyProfilePair profiles = KeyProfilePair.albrechtShanahan,
    bool durationWeighted = true,
    Duration? decayHalfLife = const Duration(
      seconds: defaultEmissionHalfLifeSeconds,
    ),
    // App status: Disabled.
    //
    // Retained to reproduce the event-count decay ablation. The app leaves
    // this null and uses elapsed-time behavior presets.
    double? decayHalfLifeEvents,
    bool confidenceWeighted = defaultEmissionConfidenceWeighted,
    double functionalBlend = defaultEmissionFunctionalBlend,
    double progressionBlend = defaultEmissionProgressionBlend,
    this.selfTransition = 0.9,
    this.fifthsDecay = 0.5,
    this.modeSwitchFactor = 0.5,
    this.emissionTemperature = 0.25,
    this.minEvents = defaultMinEvents,
    this.marginFloor = defaultMarginFloor,
    this.modeTilt = defaultModeTilt,
    this.relativeTilt = defaultRelativeTilt,
    this.relativeCadenceTilt = defaultRelativeCadenceTilt,
    this.relativeEvidenceTilt = defaultRelativeEvidenceTilt,
    this.relativeEvidenceWindow = defaultRelativeEvidenceWindow,
    this.cadenceBoost = defaultCadenceBoost,
    this.cadenceTriadBoost = defaultCadenceTriadBoost,
    this.cadenceMarginFactor = defaultCadenceMarginFactor,
    this.coldStartTonicPrior = defaultColdStartTonicPrior,
    this.relativeSwitchFactor = defaultRelativeSwitchFactor,
  }) : assert(selfTransition > 0 && selfTransition < 1),
       assert(relativeSwitchFactor > 0),
       _emissions = HybridKeyDetector(
         profiles: profiles,
         durationWeighted: durationWeighted,
         decayHalfLife: decayHalfLife,
         decayHalfLifeEvents: decayHalfLifeEvents,
         confidenceWeighted: confidenceWeighted,
         functionalBlend: functionalBlend,
         progressionBlend: progressionBlend,
         minEvents: 1,
         marginFloor: 0,
       );

  @override
  String get name => 'hmm';

  @override
  String get configuration =>
      'selfTransition=$selfTransition fifthsDecay=$fifthsDecay '
      'modeSwitchFactor=$modeSwitchFactor '
      'emissionTemperature=$emissionTemperature '
      'minEvents=$minEvents marginFloor=$marginFloor modeTilt=$modeTilt '
      'relativeTilt=$relativeTilt relativeCadenceTilt=$relativeCadenceTilt '
      'relativeEvidenceTilt=$relativeEvidenceTilt '
      'relativeEvidenceWindow=$relativeEvidenceWindow '
      'cadenceBoost=$cadenceBoost cadenceTriadBoost=$cadenceTriadBoost '
      'cadenceMarginFactor=$cadenceMarginFactor '
      'coldStartTonicPrior=$coldStartTonicPrior '
      'relativeSwitchFactor=$relativeSwitchFactor '
      '| emissions: ${_emissions.configuration}';

  @override
  void reset() {
    _emissions.reset();
    _posterior.fillRange(0, 24, 1 / 24);
    _eventCount = 0;
    _previousIdentity = null;
    _penultimateIdentity = null;
    _evidenceWindow.clear();
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    final emissionFrame = _emissions.onEvent(event);
    _eventCount += 1;

    // Predict: posterior through the transition matrix. When the incoming
    // event completes a cadence into some key, that key's transition column
    // is boosted by exp(cadenceBoost) with each row renormalized, so the
    // prior over key changes (not the evidence) is what the cadence informs.
    final cadence = _cadenceTarget(event);
    final cadenceKey = cadence?.key;
    final boost = cadence == null ? 1.0 : math.exp(cadence.strength);
    final predicted = List<double>.filled(24, 0);
    for (var from = 0; from < 24; from++) {
      final mass = _posterior[from];
      if (mass == 0) continue;
      final row = _transition[from];
      if (cadenceKey == null) {
        for (var to = 0; to < 24; to++) {
          predicted[to] += mass * row[to];
        }
      } else {
        final rowNorm = 1 + (boost - 1) * row[cadenceKey];
        for (var to = 0; to < 24; to++) {
          final weight = to == cadenceKey ? row[to] * boost : row[to];
          predicted[to] += mass * weight / rowNorm;
        }
      }
    }

    // Update: weigh by the emission distribution and renormalize. An empty
    // emission frame (hybrid warming up) carries no information; the
    // prediction stands.
    if (emissionFrame.ranked.isNotEmpty) {
      final emission = _emissionDistribution(emissionFrame.ranked);
      _applyModeTilt(emission, event);
      _applyRelativeTilt(emission, event);
      _applyRelativeEvidenceTilt(emission, event);
      var total = 0.0;
      for (var k = 0; k < 24; k++) {
        predicted[k] *= emission[k];
        total += predicted[k];
      }
      if (total > 0) {
        for (var k = 0; k < 24; k++) {
          predicted[k] /= total;
        }
      } else {
        predicted.setAll(0, _posterior);
      }
    }
    // First event after a reset: seed the belief with the tonic reading of
    // the opening chord (see [defaultColdStartTonicPrior]).
    if (coldStartTonicPrior != 0 && _eventCount == 1) {
      final quality = event.identity.quality;
      final int? tonicK;
      if (KeySpace.majorTonicQualities.contains(quality)) {
        tonicK = KeySpace.majorIndex(event.identity.rootPc);
      } else if (KeySpace.minorTonicQualities.contains(quality)) {
        tonicK = KeySpace.minorIndex(event.identity.rootPc);
      } else {
        tonicK = null;
      }
      if (tonicK != null) {
        predicted[tonicK] *= math.exp(coldStartTonicPrior);
        var total = 0.0;
        for (var k = 0; k < 24; k++) {
          total += predicted[k];
        }
        for (var k = 0; k < 24; k++) {
          predicted[k] /= total;
        }
      }
    }
    _posterior.setAll(0, predicted);
    _penultimateIdentity = _previousIdentity;
    _previousIdentity = event.identity;

    final ranked = [
      for (var k = 0; k < 24; k++)
        KeyEstimate(
          tonality: KeySpace.canonicalTonalities[k],
          confidence: _posterior[k],
        ),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    // The cadence event is the one moment a trusted signal has just moved
    // the posterior; the claim gate may be braver exactly there (see
    // [defaultCadenceMarginFactor]).
    final effectiveFloor = cadenceKey != null
        ? marginFloor * cadenceMarginFactor
        : marginFloor;
    return claimOrAbstain(
      ranked,
      eventCount: _eventCount,
      minEvents: minEvents,
      marginFloor: effectiveFloor,
    );
  }

  /// Redistributes emission mass within the parallel pair rooted on the
  /// event's chord by [modeTilt] log-odds when the chord quality reads as a
  /// tonic. The pair sum is unchanged, so no other tonic gains or loses.
  void _applyModeTilt(List<double> emission, ChordEvent event) {
    if (modeTilt == 0) return;
    final quality = event.identity.quality;
    final int direction;
    if (KeySpace.majorTonicQualities.contains(quality)) {
      direction = 1;
    } else if (KeySpace.minorTonicQualities.contains(quality)) {
      direction = -1;
    } else {
      return;
    }
    final majorK = KeySpace.majorIndex(event.identity.rootPc);
    final minorK = KeySpace.minorIndex(event.identity.rootPc);
    final pairSum = emission[majorK] + emission[minorK];
    if (pairSum == 0) return;
    final factor = math.exp(modeTilt * direction);
    final major = emission[majorK] * factor;
    final minor = emission[minorK] / factor;
    final rescale = pairSum / (major + minor);
    emission[majorK] = major * rescale;
    emission[minorK] = minor * rescale;
  }

  /// Redistributes emission mass within the relative pair of the event
  /// chord's home key (same signature): [relativeTilt] log-odds when the
  /// chord's root is also its bass, plus [relativeCadenceTilt] when the
  /// previous event was a dominant-quality chord a fifth above. The pair sum
  /// is unchanged, so no other key signature gains or loses emission
  /// evidence (posterior near-tie crossings between signatures can still
  /// shift timing, since priors differ within a pair).
  void _applyRelativeTilt(List<double> emission, ChordEvent event) {
    if (relativeTilt == 0 && relativeCadenceTilt == 0) return;
    final identity = event.identity;
    final quality = identity.quality;
    final root = identity.rootPc;
    final int homeK;
    final int twinK;
    if (KeySpace.majorTonicQualities.contains(quality)) {
      homeK = KeySpace.majorIndex(root);
      twinK = KeySpace.minorIndex(KeySpace.relativeMinorPc(root));
    } else if (KeySpace.minorTonicQualities.contains(quality)) {
      homeK = KeySpace.minorIndex(root);
      twinK = KeySpace.majorIndex(KeySpace.relativeMajorPc(root));
    } else {
      return;
    }
    var strength = 0.0;
    if (relativeTilt != 0 && identity.bassPc == root) {
      strength += relativeTilt;
    }
    final previous = _previousIdentity;
    if (relativeCadenceTilt != 0 &&
        previous != null &&
        KeySpace.dominantQualities.contains(previous.quality) &&
        previous.rootPc == (root + 7) % 12) {
      strength += relativeCadenceTilt;
    }
    if (strength == 0) return;
    final pairSum = emission[homeK] + emission[twinK];
    if (pairSum == 0) return;
    final factor = math.exp(strength);
    final home = emission[homeK] * factor;
    final twin = emission[twinK] / factor;
    final rescale = pairSum / (home + twin);
    emission[homeK] = home * rescale;
    emission[twinK] = twin * rescale;
  }

  /// Tilts every relative pair toward its major twin by
  /// [relativeEvidenceTilt] log-odds unless the last
  /// [relativeEvidenceWindow] events carry minor-defining evidence for that
  /// pair's minor key: its raised seventh sounding, or a
  /// minor-tonic-quality chord on its root. Each pair's emission sum is
  /// preserved, so no signature's total evidence moves.
  void _applyRelativeEvidenceTilt(List<double> emission, ChordEvent event) {
    if (relativeEvidenceTilt == 0) return;
    final identity = event.identity;
    final current = (
      pcMask: event.input.pcMask,
      minorTonicRoots: KeySpace.minorTonicQualities.contains(identity.quality)
          ? 1 << identity.rootPc
          : 0,
    );
    var pcUnion = current.pcMask;
    var minorTonicRoots = current.minorTonicRoots;
    for (final past in _evidenceWindow) {
      pcUnion |= past.pcMask;
      minorTonicRoots |= past.minorTonicRoots;
    }
    _evidenceWindow.add(current);
    if (_evidenceWindow.length >= relativeEvidenceWindow) {
      _evidenceWindow.removeAt(0);
    }
    final factor = math.exp(relativeEvidenceTilt);
    for (var minorPc = 0; minorPc < 12; minorPc++) {
      if (pcUnion & (1 << ((minorPc + 11) % 12)) != 0) continue;
      if (minorTonicRoots & (1 << minorPc) != 0) continue;
      final minorK = KeySpace.minorIndex(minorPc);
      final majorK = KeySpace.majorIndex(KeySpace.relativeMajorPc(minorPc));
      final pairSum = emission[minorK] + emission[majorK];
      if (pairSum == 0) continue;
      final major = emission[majorK] * factor;
      final minor = emission[minorK] / factor;
      final rescale = pairSum / (major + minor);
      emission[majorK] = major * rescale;
      emission[minorK] = minor * rescale;
    }
  }

  final List<({int pcMask, int minorTonicRoots})> _evidenceWindow = [];

  /// Chord qualities that read as a settled major tonic when a cadence lands
  /// on them. Deliberately narrower than [KeySpace.majorTonicQualities]:
  /// dominant7 is excluded so a blues I7 moving to IV7 never reads as an
  /// authentic cadence into the IV key (see [defaultCadenceBoost]).
  static const Set<ChordQuality> _majorCadenceTargets = {
    ChordQuality.major,
    ChordQuality.major6,
    ChordQuality.major7,
  };

  /// The key whose authentic cadence the incoming event completes and the
  /// boost strength to apply, or null: the previous event sat a fifth above a
  /// tonic-quality current chord as either a dominant-seventh-family chord
  /// ([cadenceBoost]) or a predominant-gated plain major triad
  /// ([cadenceTriadBoost]); the resolved chord's quality selects the target
  /// mode (see [defaultCadenceBoost] for the deliberate exclusions).
  ({int key, double strength})? _cadenceTarget(ChordEvent event) {
    final previous = _previousIdentity;
    if (previous == null) return null;
    final current = event.identity;
    if (previous.rootPc != (current.rootPc + 7) % 12) return null;
    final int targetKey;
    final bool targetMinor;
    if (_majorCadenceTargets.contains(current.quality)) {
      targetKey = KeySpace.majorIndex(current.rootPc);
      targetMinor = false;
    } else if (KeySpace.minorTonicQualities.contains(current.quality)) {
      targetKey = KeySpace.minorIndex(current.rootPc);
      targetMinor = true;
    } else {
      return null;
    }
    if (cadenceBoost != 0 &&
        KeySpace.dominantQualities.contains(previous.quality)) {
      return (key: targetKey, strength: cadenceBoost);
    }
    if (cadenceTriadBoost != 0 &&
        previous.quality == ChordQuality.major &&
        _predominantBefore(current.rootPc, targetMinor)) {
      return (key: targetKey, strength: cadenceTriadBoost);
    }
    return null;
  }

  /// Whether the event two back was predominant-functioned in the key on
  /// [tonicPc]: an ii-family chord on the second degree or a IV-family chord
  /// on the fourth, with the family sets matching the target mode.
  bool _predominantBefore(int tonicPc, bool targetMinor) {
    final penultimate = _penultimateIdentity;
    if (penultimate == null) return false;
    final root = penultimate.rootPc;
    final quality = penultimate.quality;
    if (root == (tonicPc + 2) % 12) {
      return targetMinor
          ? _diminishedFamily.contains(quality)
          : KeySpace.minorTonicQualities.contains(quality);
    }
    if (root == (tonicPc + 5) % 12) {
      return targetMinor
          ? KeySpace.minorTonicQualities.contains(quality)
          : _majorCadenceTargets.contains(quality);
    }
    return false;
  }

  /// Qualities that read as the diminished supertonic of a minor key.
  static const Set<ChordQuality> _diminishedFamily = {
    ChordQuality.diminished,
    ChordQuality.halfDiminished7,
    ChordQuality.diminished7,
  };

  /// Softmax of the hybrid's scores at [emissionTemperature], as a 24-vector
  /// indexed by [KeySpace.index].
  List<double> _emissionDistribution(List<KeyEstimate> ranked) {
    final scores = List<double>.filled(24, double.negativeInfinity);
    for (final estimate in ranked) {
      scores[KeySpace.index(estimate.tonality)] = estimate.confidence;
    }
    final top = scores.reduce(math.max);
    final emission = List<double>.filled(24, 0);
    var total = 0.0;
    for (var k = 0; k < 24; k++) {
      if (scores[k] == double.negativeInfinity) continue;
      final value = math.exp((scores[k] - top) / emissionTemperature);
      emission[k] = value;
      total += value;
    }
    for (var k = 0; k < 24; k++) {
      emission[k] /= total;
    }
    return emission;
  }

  List<List<double>> _buildTransitionMatrix() {
    final tonalities = KeySpace.canonicalTonalities;
    final matrix = <List<double>>[];
    for (var from = 0; from < 24; from++) {
      final row = List<double>.filled(24, 0);
      var switchTotal = 0.0;
      for (var to = 0; to < 24; to++) {
        if (to == from) continue;
        final distance = _signatureDistance(tonalities[from], tonalities[to]);
        var weight = math.pow(fifthsDecay, distance).toDouble();
        if (tonalities[from].isMajor != tonalities[to].isMajor) {
          weight *= modeSwitchFactor;
          // Distance zero with a mode change is exactly the relative twin.
          if (distance == 0) weight *= relativeSwitchFactor;
        }
        row[to] = weight;
        switchTotal += weight;
      }
      for (var to = 0; to < 24; to++) {
        row[to] = to == from
            ? selfTransition
            : (1 - selfTransition) * row[to] / switchTotal;
      }
      matrix.add(row);
    }
    return matrix;
  }

  /// Steps around the circle of fifths between two keys' signatures
  /// (0..6); relative major/minor pairs are at distance zero.
  static int _signatureDistance(Tonality a, Tonality b) {
    final delta = (_signaturePosition(a) - _signaturePosition(b)).abs() % 12;
    return math.min(delta, 12 - delta);
  }

  /// Position of the key's signature on the circle of fifths: the relative
  /// major's tonic mapped through [KeySpace.fifthsPosition].
  static int _signaturePosition(Tonality tonality) {
    final relativeMajorPc = tonality.isMajor
        ? tonality.tonicPitchClass
        : KeySpace.relativeMajorPc(tonality.tonicPitchClass);
    return KeySpace.fifthsPosition(relativeMajorPc);
  }
}
