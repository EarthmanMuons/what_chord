import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

/// Tonality the ensemble naming path ranks under, or null to follow the
/// selected tonality.
///
/// Written by the key feature's internal detector in auto key mode, per the
/// decisions in research/whatkey-local/log/2026-07-26-09: identity follows
/// the freshest key belief while spelling stays with the selected key
/// signature, and a manual key selection clears it so the user's choice
/// governs live naming. Solo analysis never reads it.
final ensembleNamingTonalityProvider =
    NotifierProvider<EnsembleNamingTonalityNotifier, Tonality?>(
      EnsembleNamingTonalityNotifier.new,
    );

class EnsembleNamingTonalityNotifier extends Notifier<Tonality?> {
  @override
  Tonality? build() => null;

  void set(Tonality? tonality) {
    if (state != tonality) state = tonality;
  }
}
