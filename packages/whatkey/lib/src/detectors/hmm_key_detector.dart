import 'dart:math' as math;

import 'package:whatchord/whatchord.dart';

import '../models/key_estimate.dart';
import 'detector_support.dart';
import 'hybrid_key_detector.dart';
import 'key_detector.dart';
import 'key_profiles.dart';
import 'key_space.dart';

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

  /// Emission blends for the shipped section-scale configuration (log entry
  /// 2026-07-07-18): the ablation factorial showed the functional and
  /// progression terms vote for exactly the tonicization-scale excursions
  /// the product absorbs, and removing them is a significant paired win on
  /// section-scale labels (and what finally fixed blues). The hybrid
  /// detector keeps its own nonzero blend defaults for tonicization-scale
  /// work; these constants configure only the HMM's emissions.
  static const double defaultEmissionFunctionalBlend = 0;

  /// See [defaultEmissionFunctionalBlend].
  static const double defaultEmissionProgressionBlend = 0;

  /// See [defaultEmissionFunctionalBlend].
  static const bool defaultEmissionConfidenceWeighted = false;

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

  /// Log-odds tilts within the relative pair of the event chord's home key
  /// (same key signature, so neither can add evidence for any other
  /// signature; the relative analog of [modeTilt], design plan mode
  /// disambiguation). Relative twins share every pitch class, and the
  /// rival's tonic chord is common diatonic harmony (vi/III), so isolated
  /// chord quality is weak evidence; each variant gates on a sharper cue.
  /// [relativeTilt] fires when the chord's root is also its bass;
  /// [relativeCadenceTilt] fires when the previous event was a
  /// dominant-quality chord a fifth above (a cadential resolution).
  static const double defaultRelativeTilt = 0;

  /// See [defaultRelativeTilt].
  static const double defaultRelativeCadenceTilt = 0;

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
  /// the functional blend). Local-key initiative lead from
  /// research/chord-context/log/2026-07-20-18; default off pending
  /// measurement.
  static const double defaultCadenceBoost = 0;

  /// Multiplier on transition weight between relative major/minor twins.
  /// The kernel places relative pairs at signature distance zero, so a
  /// relative switch is the cheapest move in the space and relative
  /// confusion is 8.6% of claims on the DCML diagnostic (chord-context log
  /// 2026-07-20-18). Values below 1 make the twin pay more than its
  /// signature distance suggests; 1 preserves the shipped kernel.
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

  /// Events required before the detector may claim a key.
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

  /// Cadence-conditioned transition boost (see [defaultCadenceBoost]).
  final double cadenceBoost;

  /// Relative-twin transition multiplier (see [defaultRelativeSwitchFactor]).
  final double relativeSwitchFactor;
  ChordIdentity? _previousIdentity;

  late final List<List<double>> _transition = _buildTransitionMatrix();
  final List<double> _posterior = List.filled(24, 1 / 24);
  int _eventCount = 0;

  HmmKeyDetector({
    KeyProfilePair profiles = KeyProfilePair.albrechtShanahan,
    bool durationWeighted = true,
    Duration? decayHalfLife = const Duration(
      seconds: defaultEmissionHalfLifeSeconds,
    ),
    double? decayHalfLifeEvents,
    bool confidenceWeighted = defaultEmissionConfidenceWeighted,
    double functionalBlend = defaultEmissionFunctionalBlend,
    double progressionBlend = defaultEmissionProgressionBlend,
    this.selfTransition = 0.9,
    this.fifthsDecay = 0.5,
    this.modeSwitchFactor = 0.5,
    this.emissionTemperature = 0.25,
    this.minEvents = 3,
    this.marginFloor = defaultMarginFloor,
    this.modeTilt = defaultModeTilt,
    this.relativeTilt = defaultRelativeTilt,
    this.relativeCadenceTilt = defaultRelativeCadenceTilt,
    this.cadenceBoost = defaultCadenceBoost,
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
      'cadenceBoost=$cadenceBoost relativeSwitchFactor=$relativeSwitchFactor '
      '| emissions: ${_emissions.configuration}';

  @override
  void reset() {
    _emissions.reset();
    _posterior.fillRange(0, 24, 1 / 24);
    _eventCount = 0;
    _previousIdentity = null;
  }

  @override
  KeyEstimateFrame onEvent(ChordEvent event) {
    final emissionFrame = _emissions.onEvent(event);
    _eventCount += 1;

    // Predict: posterior through the transition matrix. When the incoming
    // event completes a cadence into some key, that key's transition column
    // is boosted by exp(cadenceBoost) with each row renormalized, so the
    // prior over key changes (not the evidence) is what the cadence informs.
    final cadenceKey = cadenceBoost == 0 ? null : _cadenceTargetKey(event);
    final boost = cadenceKey == null ? 1.0 : math.exp(cadenceBoost);
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
    _posterior.setAll(0, predicted);
    _previousIdentity = event.identity;

    final ranked = [
      for (var k = 0; k < 24; k++)
        KeyEstimate(
          tonality: KeySpace.canonicalTonalities[k],
          confidence: _posterior[k],
        ),
    ]..sort((a, b) => b.confidence.compareTo(a.confidence));

    return claimOrAbstain(
      ranked,
      eventCount: _eventCount,
      minEvents: minEvents,
      marginFloor: marginFloor,
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

  /// Chord qualities that read as a settled major tonic when a cadence lands
  /// on them. Deliberately narrower than [KeySpace.majorTonicQualities]:
  /// dominant7 is excluded so a blues I7 moving to IV7 never reads as an
  /// authentic cadence into the IV key (see [defaultCadenceBoost]).
  static const Set<ChordQuality> _majorCadenceTargets = {
    ChordQuality.major,
    ChordQuality.major6,
    ChordQuality.major7,
  };

  /// The key whose authentic cadence the incoming event completes, or null:
  /// the previous event was a dominant-seventh-family chord rooted a fifth
  /// above the current chord, and the current chord has a tonic quality; the
  /// resolved chord's quality selects the target mode (see
  /// [defaultCadenceBoost] for the deliberate exclusions).
  int? _cadenceTargetKey(ChordEvent event) {
    final previous = _previousIdentity;
    if (previous == null) return null;
    final current = event.identity;
    if (previous.rootPc != (current.rootPc + 7) % 12) return null;
    if (!KeySpace.dominantQualities.contains(previous.quality)) return null;
    if (_majorCadenceTargets.contains(current.quality)) {
      return KeySpace.majorIndex(current.rootPc);
    }
    if (KeySpace.minorTonicQualities.contains(current.quality)) {
      return KeySpace.minorIndex(current.rootPc);
    }
    return null;
  }

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
