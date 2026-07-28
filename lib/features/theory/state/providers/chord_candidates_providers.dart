import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/features/lookup/lookup.dart';

import 'analysis_context_provider.dart';
import 'analysis_mode_provider.dart';
import 'chord_analyzer_provider.dart';
import 'chord_input_provider.dart';
import 'displayed_chord_provider.dart';

const _rankingDetailsCandidateLimit = 5;

final chordCandidatesProvider = Provider<List<ChordCandidate>>((ref) {
  final input = ref.watch(chordInputProvider);
  if (input == null) return const <ChordCandidate>[];

  final mode = ref.watch(analysisModeProvider);
  if (mode != AnalysisMode.chord) return const <ChordCandidate>[];

  final context = ref.watch(analysisContextProvider);
  final voicing = ref.watch(observedVoicingProvider);
  final analyzer = ref.watch(chordAnalyzerProvider);
  return analyzer.analyze(input, context: context, voicing: voicing);
});

final bestChordCandidateProvider = Provider<ChordCandidate?>((ref) {
  final candidates = ref.watch(chordCandidatesProvider);
  return candidates.isNotEmpty ? candidates.first : null;
});

final alternativeChordCandidatesProvider = Provider<List<ChordCandidate>>((
  ref,
) {
  final candidates = ref.watch(chordCandidatesProvider);
  return ChordCandidateRanking.alternatives(candidates);
});

final rankedChordCandidateDebugProvider = Provider<List<ExplainedCandidate>>((
  ref,
) {
  final mode = ref.watch(analysisModeProvider);
  if (mode != AnalysisMode.chord) return const <ExplainedCandidate>[];

  // Explain the chord the user is looking at: the display gate's frame for
  // live play, the raw live input for lookup's untimed manual entry.
  final lookup = ref.watch(lookupActiveProvider);
  final frame = lookup ? null : ref.watch(displayedChordProvider);
  if (!lookup && frame == null) return const <ExplainedCandidate>[];
  final input = lookup ? ref.watch(chordInputProvider) : frame!.input;
  final voicing = lookup ? ref.watch(observedVoicingProvider) : frame!.voicing;
  if (input == null || voicing == null) return const <ExplainedCandidate>[];

  final context = ref.watch(analysisContextProvider);
  return ref
      .watch(chordAnalyzerProvider)
      .explain(
        input,
        context: context,
        voicing: voicing,
        take: _rankingDetailsCandidateLimit,
      );
});
