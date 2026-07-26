import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatkey/whatkey.dart';

import 'package:whatchord_app/features/history/history.dart';

import '../models/inferred_key_state.dart';
import 'key_behavior_notifier.dart';

/// How long without a committed chord before the inferred key is displayed
/// dimmed. Scales with the behavior preset: shorter emission memory means
/// the evidence behind a claim genuinely fades sooner, so faster modes dim
/// sooner (see [KeyBehavior.staleAfter]).
final inferredKeyStaleAfterProvider = Provider<Duration>(
  (ref) => ref.watch(keyBehaviorProvider).staleAfter,
);

/// How long without a committed chord before the detector forgets entirely.
/// The posterior only updates per event, so without this it would hold the
/// previous song's key with full conviction across any silence; past this
/// window a fresh start is more likely than a continuation.
final inferredKeyResetAfterProvider = Provider<Duration>(
  (ref) => const Duration(minutes: 2),
);

final inferredKeyProvider =
    NotifierProvider<InferredKeyNotifier, InferredKeyState>(
      InferredKeyNotifier.new,
    );

/// Live key inference over the committed chord history.
///
/// Owns one [HmmKeyDetector] configured by the selected [KeyBehavior] preset
/// and feeds it each committed event exactly once, in order, never re-running
/// history (the detector is causal and stateful). Detection runs regardless
/// of the manual/auto UI mode so the auto view is warm the moment it opens;
/// the mode only controls presentation and write-back.
///
/// Resets when history is cleared, after [inferredKeyResetAfterProvider] of
/// silence, and when the behavior preset changes (a fresh detector with
/// different memory starts blank); marks the state stale after
/// [inferredKeyStaleAfterProvider].
class InferredKeyNotifier extends Notifier<InferredKeyState> {
  late HmmKeyDetector _detector;
  ChordEvent? _lastProcessed;
  Timer? _staleTimer;
  Timer? _resetTimer;

  /// The behavior preset this detector runs, watched so a preset change
  /// rebuilds with fresh memory. [InternalKeyNotifier] overrides both hooks
  /// with a pinned preset so the internal key never depends on display state.
  @protected
  KeyBehavior watchBehavior() => ref.watch(keyBehaviorProvider);

  /// See [watchBehavior].
  @protected
  Duration get staleAfter => ref.read(inferredKeyStaleAfterProvider);

  @override
  InferredKeyState build() {
    final behavior = watchBehavior();
    _detector = HmmKeyDetector(decayHalfLife: behavior.emissionHalfLife);
    ref.onDispose(_cancelTimers);
    ref.listen(chordHistoryProvider, _onHistory);
    // resetAt marks this detector's birth: history committed before it (or
    // before the behavior switch that rebuilt it) no longer contributes, and
    // the recent-chords display drops those events accordingly. Marking the
    // current tail as processed enforces that from the first notification,
    // even one caused by a record-only mutation (the history relabel).
    final history = ref.read(chordHistoryProvider);
    _lastProcessed = history.isEmpty ? null : history.last;
    return InferredKeyState.initial(resetAt: ref.read(historyClockProvider)());
  }

  /// Forgets everything: detector posterior, retained claim, timers.
  void reset() {
    _cancelTimers();
    _detector.reset();
    _lastProcessed = null;
    state = InferredKeyState.initial(resetAt: ref.read(historyClockProvider)());
  }

  void _onHistory(List<ChordEvent>? previous, List<ChordEvent> next) {
    if (next.isEmpty) {
      if (_lastProcessed != null || (previous?.isNotEmpty ?? false)) reset();
      return;
    }
    // record() appends exactly one event per state change, so a changed tail
    // is that one new event. An identical tail is a record-only mutation
    // (the history relabel) or a re-notification; tracking the processed
    // tail here rather than trusting the listener's previous value keeps
    // those from re-feeding the causal detector across rebuilds.
    if (identical(next.last, _lastProcessed)) return;
    _lastProcessed = next.last;
    _onEvent(next.last);
  }

  void _onEvent(ChordEvent event) {
    final frame = _detector.onEvent(event);
    state = InferredKeyState(
      ranked: frame.ranked,
      claim: frame.claim,
      lastClaim: frame.claim ?? state.lastClaim,
      lastEventAt: ref.read(historyClockProvider)(),
      freshness: InferredKeyFreshness.fresh,
      resetAt: state.resetAt,
    );
    _rescheduleTimers();
  }

  void _rescheduleTimers() {
    _cancelTimers();
    _staleTimer = Timer(staleAfter, () {
      _staleTimer = null;
      if (state.freshness == InferredKeyFreshness.fresh) {
        state = state.copyWith(freshness: InferredKeyFreshness.stale);
      }
    });
    _resetTimer = Timer(ref.read(inferredKeyResetAfterProvider), reset);
  }

  void _cancelTimers() {
    _staleTimer?.cancel();
    _staleTimer = null;
    _resetTimer?.cancel();
    _resetTimer = null;
  }
}
