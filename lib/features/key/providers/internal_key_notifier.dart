import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatkey/whatkey.dart';

import 'package:whatchord_app/features/history/history.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../models/inferred_key_state.dart';
import 'inferred_key_notifier.dart';
import 'key_mode_notifier.dart';

/// The internal key: a second detector pinned to the reactive timescale,
/// independent of the display preset, per the decisions in
/// research/whatkey-local/log/2026-07-26-09. It serves the two adopted
/// mechanisms: ensemble naming consults it in auto key mode, and the
/// one-event history relabel follows its claims in every mode.
final internalKeyProvider =
    NotifierProvider<InternalKeyNotifier, InferredKeyState>(
      InternalKeyNotifier.new,
    );

/// See [internalKeyProvider]. Runs the same lifecycle as the display
/// detector ([InferredKeyNotifier]) with the preset hooks pinned, so the
/// naming path never depends on display state, even when the user's chosen
/// preset happens to be reactive too.
class InternalKeyNotifier extends InferredKeyNotifier {
  /// Pinned timescale: measured best for ensemble naming (93.5% against
  /// 92.8% under stable, whatkey-local log 2026-07-26-07).
  static const behavior = KeyBehavior.reactive;

  @override
  KeyBehavior watchBehavior() => behavior;

  @override
  Duration get staleAfter => behavior.staleAfter;
}

/// Wires the internal key to its two consumers.
final internalKeyCoordinatorProvider =
    NotifierProvider<InternalKeyCoordinator, void>(InternalKeyCoordinator.new);

/// Keeps the internal key and its wiring alive for the app session.
final appInternalKeyLifecycleProvider = Provider<void>((ref) {
  ref.watch(internalKeyCoordinatorProvider);
});

/// Applies the internal key per research/whatkey-local/log/2026-07-26-09:
///
/// - Ensemble naming tonality (decision 2): pushed into the theory-side
///   [ensembleNamingTonalityProvider] in auto key mode, cleared in manual
///   mode so an explicit selection keeps governing live naming.
/// - One-event history relabel (decision 1): when the event just processed
///   moves the internal claim, the previous history entry is re-ranked under
///   that claim, in every playing and key mode.
///
/// Both writes land through [scheduleMicrotask] so they settle between
/// provider passes (the same-frame rebuild hazard documented on
/// [KeyModeNotifier]).
class InternalKeyCoordinator extends Notifier<void> {
  @override
  void build() {
    ref.listen(internalKeyProvider, _onInternalKey);
    ref.listen(keyModeProvider, (_, _) => _syncNamingTonality());
  }

  void _onInternalKey(InferredKeyState? previous, InferredKeyState next) {
    _syncNamingTonality();
    // Only a committed event can move the claim past a new entry; timer
    // transitions (stale, reset) re-emit without a new event.
    if (next.lastEventAt != null && next.lastEventAt != previous?.lastEventAt) {
      _relabelPrevious(next);
    }
  }

  void _syncNamingTonality() {
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      final tonality = ref.read(keyModeProvider) == KeyMode.auto
          ? ref.read(internalKeyProvider).lastClaim?.tonality
          : null;
      ref.read(ensembleNamingTonalityProvider.notifier).set(tonality);
    });
  }

  /// Record-only and one event deep: the newest entry is never touched, so
  /// detector listeners, which key on the appended tail, never reprocess a
  /// relabeled event. Net-positive rather than per-flip perfect (whatkey-local
  /// log 2026-07-26-08), applied whenever the claim disagrees with the
  /// tonality the entry was ranked under.
  void _relabelPrevious(InferredKeyState internal) {
    final claim = internal.lastClaim?.tonality;
    if (claim == null) return;
    final history = ref.read(chordHistoryProvider);
    if (history.length < 2) return;
    final target = history[history.length - 2];
    if (target.tonality == claim) return;

    final keySignature = KeySignature.fromTonality(claim);
    final candidates = ref
        .read(chordAnalyzerProvider)
        .analyze(
          target.input,
          context: AnalysisContext(
            tonality: claim,
            keySignature: keySignature,
            spellingPolicy: NoteSpellingPolicy(
              preferFlats: keySignature.prefersFlats,
            ),
            playingContext: target.playingContext,
          ),
          voicing: target.voicing,
        );
    if (candidates.isEmpty) return;
    final replacement = ChordEvent(
      timestamp: target.timestamp,
      input: target.input,
      voicing: target.voicing,
      candidates: [
        candidates.first,
        ...ChordCandidateRanking.alternatives(candidates),
      ],
      tonality: claim,
      playingContext: target.playingContext,
      duration: target.duration,
    );
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      ref.read(chordHistoryProvider.notifier).replace(target, replacement);
    });
  }
}
