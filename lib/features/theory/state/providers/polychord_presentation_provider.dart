import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'analysis_context_provider.dart';
import 'polychord_product_provider.dart';
import 'theory_preferences_notifier.dart';

final polychordPresentationProvider = Provider<PolychordPresentation?>((ref) {
  final candidate = ref.watch(
    polychordProductObservationProvider.select(
      (observation) => observation?.displayedCandidate,
    ),
  );
  if (candidate == null) return null;

  final tonality = ref.watch(analysisContextProvider.select((c) => c.tonality));
  final notation = ref.watch(chordNotationStyleProvider);
  final noteNameSystem = ref.watch(noteNameSystemProvider);
  return PolychordPresentationBuilder.fromCandidate(
    candidate: candidate,
    tonality: tonality,
    notation: notation,
    noteNameSystem: noteNameSystem,
  );
});
