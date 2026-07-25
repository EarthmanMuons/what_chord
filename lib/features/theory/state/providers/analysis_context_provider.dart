import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/features/demo/demo.dart';

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

  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: spellingPolicy,
    playingContext: playingContext,
  );
});
