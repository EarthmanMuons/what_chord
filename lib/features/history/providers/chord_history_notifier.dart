import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/lookup/lookup.dart';
import 'package:whatchord_app/features/theory/theory.dart';

/// Memory cap on stored events; the oldest are dropped beyond this count.
final historyCapacityProvider = Provider<int>((ref) => 100);

/// How long an identity must persist to count as real. Serves double duty:
/// a challenger identity must outlive this to end the current chord
/// (debounce), and a committed chord must have been held this long to be
/// recorded. Split into separate providers if tuning ever needs them apart.
final historyMinChordDurationProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 200),
);

/// Clock behind event timestamps and durations; injectable for tests.
final historyClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final chordHistoryProvider =
    NotifierProvider<ChordHistoryNotifier, List<ChordEvent>>(
      ChordHistoryNotifier.new,
    );

/// The analyzed live chord currently eligible for capture, or null while demo
/// or lookup is active or fewer than three notes sound.
///
/// Gating capture here rather than at commit time is what keeps demo and
/// lookup chords out of history: their toggle-off transitions land after the
/// mode flags have already flipped, so a commit-time check would let a stale
/// non-live chord through.
final _captureFrameProvider = Provider<CaptureFrame?>((ref) {
  if (ref.watch(demoModeProvider)) return null;
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

  // Chosen candidate plus its surfaced near-tie alternatives, so history and
  // the UI agree on what counts as a relevant alternative.
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

/// Sliding-window history of committed live chords, oldest first.
///
/// The segmentation rules live in [ChordEventSegmenter] (pure Dart, shared
/// with offline replay); this notifier owns the Riverpod wiring, the pending
/// timer, and retention.
class ChordHistoryNotifier extends Notifier<List<ChordEvent>> {
  late ChordEventSegmenter _segmenter;
  Timer? _pendingTimer;

  @override
  List<ChordEvent> build() {
    _segmenter = ChordEventSegmenter(
      minChordDuration: ref.watch(historyMinChordDurationProvider),
    );
    ref.onDispose(_cancelPendingTimer);
    ref.listen(
      _captureFrameProvider,
      (previous, next) => _onFrame(next),
      fireImmediately: true,
    );
    return const [];
  }

  void record(ChordEvent event) {
    final capacity = ref.read(historyCapacityProvider);
    final appended = <ChordEvent>[...state, event];
    final overflow = appended.length - capacity;
    state = List.unmodifiable(
      overflow > 0 ? appended.sublist(overflow) : appended,
    );
  }

  void clear() {
    _cancelPendingTimer();
    _segmenter.reset();
    state = const [];
  }

  /// Swaps [original] for [replacement] in place, preserving order: the
  /// one-event-deep history relabel (research/whatkey-local/log/2026-07-26-09).
  /// Record-only by contract: callers never replace the newest entry, so
  /// detector listeners, which key on the appended tail, do not reprocess a
  /// relabeled event. No-op when [original] is already gone (capacity
  /// overflow or a clear).
  void replace(ChordEvent original, ChordEvent replacement) {
    final index = state.indexWhere((event) => identical(event, original));
    if (index < 0) return;
    final next = [...state]..[index] = replacement;
    state = List.unmodifiable(next);
  }

  /// Events whose start time falls within [window] of now, oldest first.
  List<ChordEvent> recentEvents(Duration window) {
    final cutoff = ref.read(historyClockProvider)().subtract(window);
    return state.where((e) => !e.timestamp.isBefore(cutoff)).toList();
  }

  void _onFrame(CaptureFrame? frame) {
    final now = ref.read(historyClockProvider)();
    _segmenter.onFrame(frame, now).forEach(record);
    _reschedulePendingTimer();
  }

  /// Without this timer, a stabilized challenger would only be noticed at the
  /// next input change, delaying the previous chord's commit by one chord.
  void _reschedulePendingTimer() {
    _cancelPendingTimer();
    final deadline = _segmenter.pendingDeadline;
    if (deadline == null) return;
    final now = ref.read(historyClockProvider)();
    _pendingTimer = Timer(deadline.difference(now), () {
      _pendingTimer = null;
      _segmenter.resolveDue(ref.read(historyClockProvider)()).forEach(record);
    });
  }

  void _cancelPendingTimer() {
    _pendingTimer?.cancel();
    _pendingTimer = null;
  }
}
