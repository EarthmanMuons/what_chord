/// Published key-profile pairs for profile-correlation detection.
///
/// The literature is clear that profile choice matters more than the
/// correlation formula, so the pair is a parameter, not a constant. Values are
/// indexed by interval above the tonic (0..11). Sources are cited in
/// research/whatkey/temporal-context-key-detection.md; each pair's values are
/// verified against reference implementations (music21, justkeydding), see
/// research/whatkey/log/2026-07-06-08-profile-provenance.md.
enum KeyProfilePair {
  /// **App status: Disabled.**
  ///
  /// Krumhansl & Kessler probe-tone ratings (Krumhansl 1990). The historical
  /// baseline; known to underperform in minor. Retained for research
  /// comparison, not selected by the app.
  krumhanslKessler(
    major: [
      6.35, 2.23, 3.48, 2.33, 4.38, 4.09, //
      2.52, 5.19, 2.39, 3.66, 2.29, 2.88,
    ],
    minor: [
      6.33, 2.68, 3.52, 5.38, 2.60, 3.53, //
      2.54, 4.75, 3.98, 2.69, 3.34, 3.17,
    ],
  ),

  /// **App status: Disabled.**
  ///
  /// Temperley's 1999 revision ("What's Key for Key?").
  ///
  /// Not the same as the Temperley Kostka-Payne probability profiles (2007)
  /// that music21's TemperleyKostkaPayne and justkeydding's "temperley" use;
  /// name the profile pair precisely when comparing against external
  /// baselines. Retained for research comparison, not selected by the app.
  temperley(
    major: [
      5.0, 2.0, 3.5, 2.0, 4.5, 4.0, //
      2.0, 4.5, 2.0, 3.5, 1.5, 4.0,
    ],
    minor: [
      5.0, 2.0, 3.5, 4.5, 2.0, 4.0, //
      2.0, 4.5, 3.5, 2.0, 1.5, 4.0,
    ],
  ),

  /// **App status: Disabled.**
  ///
  /// Temperley's Kostka-Payne probability profiles (_Music and Probability_,
  /// 2007), the refined pair that modern implementations settled on: this is
  /// what music21's TemperleyKostkaPayne and justkeydding's "temperley" use.
  /// Retained for research comparison, not selected by the app.
  temperleyKostkaPayne(
    major: [
      0.748, 0.060, 0.488, 0.082, 0.670, 0.460, //
      0.096, 0.715, 0.104, 0.366, 0.057, 0.400,
    ],
    minor: [
      0.712, 0.084, 0.474, 0.618, 0.049, 0.460, //
      0.105, 0.747, 0.404, 0.067, 0.133, 0.330,
    ],
  ),

  /// **App status: Shipped.**
  ///
  /// Albrecht & Shanahan (2013) corpus-trained profiles; notably better in
  /// minor and selected by the shipped detector.
  albrechtShanahan(
    major: [
      0.238, 0.006, 0.111, 0.006, 0.137, 0.094, //
      0.016, 0.214, 0.009, 0.080, 0.008, 0.081,
    ],
    minor: [
      0.220, 0.006, 0.104, 0.123, 0.019, 0.103, //
      0.012, 0.214, 0.062, 0.022, 0.061, 0.052,
    ],
  );

  /// Weight per pitch class (0..11 relative to the tonic) for major keys.
  final List<double> major;

  /// Weight per pitch class (0..11 relative to the tonic) for minor keys.
  final List<double> minor;

  const KeyProfilePair({required this.major, required this.minor});
}
