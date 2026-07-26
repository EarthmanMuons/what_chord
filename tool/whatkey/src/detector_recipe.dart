import 'package:whatkey/whatkey.dart';

/// A complete detector configuration attached to a published result set.
///
/// Recipes deliberately repeat every consequential value instead of referring
/// to mutable detector defaults. The app's user-facing behavior presets remain
/// independent of these research contracts.
enum DetectorRecipe {
  /// Detector used for the WhatKey paper's frozen v2026.7.14 result set.
  whatKeyPaper2026(
    detectorName: 'hmm',
    confidenceWeighted: false,
    functionalBlend: 0,
    progressionBlend: 0,
    selfTransition: 0.9,
    emissionTemperature: 0.25,
    hysteresis: 1,
    profiles: KeyProfilePair.albrechtShanahan,
    durationWeighted: true,
    decayHalfLifeSeconds: 30,
    decayHalfLifeEvents: null,
    minEvents: 3,
    marginFloor: 0.3,
    modeTilt: 2,
    relativeTilt: 0,
    relativeCadenceTilt: 0,
    cadenceBoost: 0,
    cadenceTriadBoost: 0,
    relativeSwitchFactor: 1,
  ),

  /// Faster-decay comparison reported alongside the shipped paper detector.
  whatKeyPaper2026Reflex(
    detectorName: 'hmm',
    confidenceWeighted: false,
    functionalBlend: 0.1,
    progressionBlend: 0,
    selfTransition: 0.9,
    emissionTemperature: 0.25,
    hysteresis: 1,
    profiles: KeyProfilePair.albrechtShanahan,
    durationWeighted: true,
    decayHalfLifeSeconds: 1,
    decayHalfLifeEvents: null,
    minEvents: 3,
    marginFloor: 0.3,
    modeTilt: 2,
    relativeTilt: 0,
    relativeCadenceTilt: 0,
    cadenceBoost: 0,
    cadenceTriadBoost: 0,
    relativeSwitchFactor: 1,
  );

  const DetectorRecipe({
    required this.detectorName,
    required this.confidenceWeighted,
    required this.functionalBlend,
    required this.progressionBlend,
    required this.selfTransition,
    required this.emissionTemperature,
    required this.hysteresis,
    required this.profiles,
    required this.durationWeighted,
    required this.decayHalfLifeSeconds,
    required this.decayHalfLifeEvents,
    required this.minEvents,
    required this.marginFloor,
    required this.modeTilt,
    required this.relativeTilt,
    required this.relativeCadenceTilt,
    required this.cadenceBoost,
    required this.cadenceTriadBoost,
    required this.relativeSwitchFactor,
  });

  final String detectorName;
  final bool confidenceWeighted;
  final double functionalBlend;
  final double progressionBlend;
  final double selfTransition;
  final double emissionTemperature;
  final int hysteresis;
  final KeyProfilePair profiles;
  final bool durationWeighted;
  final int decayHalfLifeSeconds;
  final double? decayHalfLifeEvents;
  final int minEvents;
  final double marginFloor;
  final double modeTilt;
  final double relativeTilt;
  final double relativeCadenceTilt;
  final double cadenceBoost;
  final double cadenceTriadBoost;
  final double relativeSwitchFactor;
}
