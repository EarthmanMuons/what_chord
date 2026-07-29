import '../detectors/display_calibration.dart';
import '../detectors/hmm_key_detector.dart';

/// User-facing key detection presets (research/whatkey/key-behavior-modes.md):
/// the shipped detector with a per-mode emission half-life, paired with the
/// display calibration temperature fitted for that timescale. Every other
/// detector knob measured best at its default at all three timescales.
///
/// NOTE: https://whatchord.earthmanmuons.com/articles/key-detection-algorithm.html
/// tabulates these presets. Update the article when a preset's half-life or
/// display temperature changes, or when a knob stops being shared.
enum KeyBehavior {
  /// Section-scale reading: names the song's key and absorbs brief detours.
  /// The shipped configuration.
  stable(
    emissionHalfLife: Duration(
      seconds: HmmKeyDetector.defaultEmissionHalfLifeSeconds,
    ),
    displayTemperature: DisplayCalibration.temperature,
    staleAfter: Duration(seconds: 30),
  ),

  /// Follows section-scale key changes within a few chords at section
  /// accuracy statistically matching [stable].
  balanced(
    emissionHalfLife: Duration(seconds: 4),
    displayTemperature: 1.5,
    staleAfter: Duration(seconds: 20),
  ),

  /// Local-scale reading: re-bases on the current tonal center quickly, at
  /// the cost of more switching and more abstention.
  reactive(
    emissionHalfLife: Duration(seconds: 1),
    displayTemperature: 1.75,
    staleAfter: Duration(seconds: 10),
  );

  const KeyBehavior({
    required this.emissionHalfLife,
    required this.displayTemperature,
    required this.staleAfter,
  });

  /// Emission memory for the detector: how far back chord evidence counts.
  final Duration emissionHalfLife;

  /// Temperature for [DisplayCalibration.calibrate], fitted per mode so the
  /// displayed confidence stays honest for what this mode's claims mean.
  final double displayTemperature;

  /// Silence before the displayed key dims. For [stable] this matches the
  /// emission half-life (the frozen rationale); the faster modes dim sooner
  /// because their evidence genuinely fades sooner, but not at the literal
  /// half-life, which would flicker during ordinary phrase breaks. A feel
  /// compromise, not a fitted value. The two-minute full reset is shared.
  final Duration staleAfter;
}
