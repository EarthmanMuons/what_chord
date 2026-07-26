import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/features/demo/demo.dart';

import 'ensemble_naming_tonality_provider.dart';
import 'playing_context_notifier.dart';
import 'selected_key_signature_provider.dart';
import 'selected_tonality_notifier.dart';

final analysisContextProvider = Provider<AnalysisContext>((ref) {
  final tonality = ref.watch(selectedTonalityProvider);
  final keySignature = ref.watch(selectedKeySignatureProvider);

  final spellingPolicy = NoteSpellingPolicy(
    preferFlats: keySignature.prefersFlats,
  );

  // Demo sequences are authored as solo voicings; pinning them keeps the
  // scripted tour stable regardless of the user's playing-context setting.
  final playingContext = ref.watch(demoModeProvider)
      ? PlayingContext.solo
      : ref.watch(playingContextProvider);

  // Ensemble identity follows the internal naming key when one is standing;
  // keySignature and spellingPolicy stay with the selected key so visible
  // spelling never contradicts the key display (decision 3 in
  // research/whatkey-local/log/2026-07-26-09).
  final namingTonality = playingContext == PlayingContext.ensemble
      ? ref.watch(ensembleNamingTonalityProvider)
      : null;

  return AnalysisContext(
    tonality: namingTonality ?? tonality,
    keySignature: keySignature,
    spellingPolicy: spellingPolicy,
    playingContext: playingContext,
  );
});
