import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/features/lookup/lookup.dart';

import 'analysis_context_provider.dart';
import 'chord_candidates_providers.dart';
import 'chord_input_provider.dart';

/// How long an identity must persist to count as real, shared by chord
/// history capture and the display gate so the identity card, history, and
/// key detection agree on what a chord is
/// (research/performed-input/log/2026-07-28-06).
final chordStabilityMinDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 200),
);

/// Clock behind display-gate promotion; injectable for tests.
final displayedChordClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

/// The analyzed frame feeding the display gate. Unlike history capture, demo
/// playback is included (the demo showcases the real display experience);
/// lookup stays out because manual pad entry has no timing dimension and
/// bypasses the gate entirely.
final displayFrameProvider = Provider<CaptureFrame?>((ref) {
  if (ref.watch(lookupActiveProvider)) return null;

  final candidates = ref.watch(chordCandidatesProvider);
  if (candidates.isEmpty) return null;

  final input = ref.watch(chordInputProvider);
  final voicing = ref.watch(observedVoicingProvider);
  if (input == null || voicing == null) return null;

  final tonality = ref.watch(analysisContextProvider.select((c) => c.tonality));
  final playingContext = ref.watch(
    analysisContextProvider.select((c) => c.playingContext),
  );

  return CaptureFrame(
    input: input,
    voicing: voicing,
    candidates: [
      candidates.first,
      ...ChordCandidateRanking.alternatives(candidates),
    ],
    tonality: tonality,
    playingContext: playingContext,
  );
});

final displayedChordProvider =
    NotifierProvider<DisplayedChordNotifier, CaptureFrame?>(
      DisplayedChordNotifier.new,
    );

/// Routes the identity card through the same segmentation judgment as chord
/// history: a chord displays once its identity has survived
/// [chordStabilityMinDurationProvider], the previous chord holds while a
/// challenger is pending, and the display clears when nothing eligible
/// sounds (falling through to the note/dyad/blank branches). Display-policy
/// decision record: research/performed-input/log/2026-07-28-06; measured
/// frontier: logs 2026-07-27-15 and 2026-07-28-02.
class DisplayedChordNotifier extends Notifier<CaptureFrame?> {
  late ChordEventSegmenter _segmenter;
  Timer? _timer;

  @override
  CaptureFrame? build() {
    _segmenter = ChordEventSegmenter(
      minChordDuration: ref.watch(chordStabilityMinDurationProvider),
    );
    ref.onDispose(_cancelTimer);
    ref.listen(
      displayFrameProvider,
      (previous, next) => _onFrame(next),
      fireImmediately: true,
    );
    return null;
  }

  void _onFrame(CaptureFrame? frame) {
    _segmenter.onFrame(frame, _now());
    // Frames arrive inside provider notifications while a refresh pass may
    // still be flushing; writing state synchronously re-dirties providers
    // that already rebuilt in that pass (Riverpod's same-frame rebuild
    // assertion), so land the display write between passes
    // (KeyModeNotifier._adopt pattern).
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      final now = _now();
      _publish(now);
      _reschedule(now);
    });
  }

  DateTime _now() => ref.read(displayedChordClockProvider)();

  /// The active chord once old enough; holds the previous stable chord while
  /// a newer identity is still proving itself, and clears on silence.
  void _publish(DateTime now) {
    final active = _segmenter.active;
    final since = _segmenter.activeSince;
    if (active == null || since == null) {
      state = null;
      return;
    }
    final minDuration = ref.read(chordStabilityMinDurationProvider);
    if (now.difference(since) >= minDuration) {
      state = active;
    }
  }

  /// Wakes when the pending challenger resolves or the warming-up active
  /// chord becomes displayable, whichever comes first; without it, both
  /// transitions would wait for the next input change.
  void _reschedule(DateTime now) {
    _cancelTimer();
    final minDuration = ref.read(chordStabilityMinDurationProvider);
    final since = _segmenter.activeSince;
    final warmupDeadline = since != null && !identical(state, _segmenter.active)
        ? since.add(minDuration)
        : null;
    final pendingDeadline = _segmenter.pendingDeadline;
    final deadline = switch ((warmupDeadline, pendingDeadline)) {
      (null, null) => null,
      (final w?, null) => w,
      (null, final p?) => p,
      (final w?, final p?) => w.isBefore(p) ? w : p,
    };
    if (deadline == null) return;
    _timer = Timer(deadline.difference(now), () {
      _timer = null;
      final at = _now();
      _segmenter.resolveDue(at);
      _publish(at);
      _reschedule(at);
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}

/// The displayed chord's chosen candidate: gate output for live play, the
/// raw ranking for lookup's untimed manual entry.
final displayedBestCandidateProvider = Provider<ChordCandidate?>((ref) {
  if (ref.watch(lookupActiveProvider)) {
    return ref.watch(bestChordCandidateProvider);
  }
  return ref.watch(displayedChordProvider)?.candidates.first;
});

/// The displayed chord's surfaced near-tie alternatives, mirroring
/// [displayedBestCandidateProvider]'s source.
final displayedAlternativeCandidatesProvider = Provider<List<ChordCandidate>>((
  ref,
) {
  if (ref.watch(lookupActiveProvider)) {
    return ref.watch(alternativeChordCandidatesProvider);
  }
  final frame = ref.watch(displayedChordProvider);
  if (frame == null || frame.candidates.length < 2) {
    return const <ChordCandidate>[];
  }
  return frame.candidates.sublist(1);
});
