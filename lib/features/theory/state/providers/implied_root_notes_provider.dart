import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/input/input.dart';

import 'analysis_mode_provider.dart';
import 'chord_candidates_providers.dart';

/// The nearest key with [rootPc] strictly below [bassMidi]: where a covering
/// bassist would sound an ensemble reading's implied root.
int impliedRootMidiBelow({required int bassMidi, required int rootPc}) {
  final delta = (bassMidi % 12 - rootPc + 12) % 12;
  return bassMidi - (delta == 0 ? 12 : delta);
}

/// MIDI note numbers to render as hollow implied keys on the live keyboard:
/// the chosen reading's implied root under ensemble analysis, or empty.
final impliedRootNoteNumbersProvider = Provider<Set<int>>((ref) {
  if (ref.watch(analysisModeProvider) != AnalysisMode.chord) {
    return const <int>{};
  }

  final identity = ref.watch(bestChordCandidateProvider)?.identity;
  if (identity == null || !identity.hasImpliedRoot) return const <int>{};

  final midis = ref.watch(soundingNoteNumbersSortedProvider);
  if (midis.isEmpty) return const <int>{};

  return {impliedRootMidiBelow(bassMidi: midis.first, rootPc: identity.rootPc)};
});
