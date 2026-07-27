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
  /// tonality the entry was ranked under, or when the newest event's
  /// resolution disambiguates a flat-nine dominant re-rooting
  /// (ensemble-tiebreak log 2026-07-26-07).
  void _relabelPrevious(InferredKeyState internal) {
    final history = ref.read(chordHistoryProvider);
    if (history.length < 2) return;
    final target = history[history.length - 2];
    final witness = history[history.length - 1];
    final claim = internal.lastClaim?.tonality;
    final keyChanged = claim != null && claim != target.tonality;
    // Cheap prefilter: re-analysis is warranted only when the key moved or
    // the entry is a resolution-eligible ensemble dominant.
    if (!keyChanged &&
        _resolutionTwinRoot(target.identity, witness.identity) == null) {
      return;
    }

    final tonality = keyChanged ? claim : target.tonality;
    final keySignature = KeySignature.fromTonality(tonality);
    final ranked = ref
        .read(chordAnalyzerProvider)
        .analyze(
          target.input,
          context: AnalysisContext(
            tonality: tonality,
            keySignature: keySignature,
            spellingPolicy: NoteSpellingPolicy(
              preferFlats: keySignature.prefersFlats,
            ),
            playingContext: target.playingContext,
          ),
          voicing: target.voicing,
          take: 24,
        );
    if (ranked.isEmpty) return;

    // Resolution promotion: a flat-nine dominant's minor-third re-rootings
    // sound identical, and only the next chord reveals the root. When the
    // re-analyzed top does not resolve into the newest event but its twin
    // does, the twin leads the record (90% flip precision in simulation,
    // ensemble-tiebreak log 2026-07-26-07).
    var ordered = ranked;
    final twinRoot = _resolutionTwinRoot(
      ranked.first.identity,
      witness.identity,
    );
    if (twinRoot != null) {
      ChordCandidate? twin;
      for (final candidate in ranked) {
        final id = candidate.identity;
        if (id.hasImpliedRoot &&
            id.quality.isDominantFamily &&
            id.rootPc == twinRoot) {
          twin = candidate;
          break;
        }
      }
      if (twin != null) {
        ordered = [twin, ...ranked.where((c) => !identical(c, twin))];
      }
    }

    // Record-only churn guard: nothing changed, nothing to write.
    if (!keyChanged && ordered.first.identity == target.identity) return;

    final replacement = ChordEvent(
      timestamp: target.timestamp,
      input: target.input,
      voicing: target.voicing,
      candidates: [
        ordered.first,
        ...ChordCandidateRanking.alternatives(ordered),
      ],
      tonality: tonality,
      playingContext: target.playingContext,
      duration: target.duration,
    );
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      ref.read(chordHistoryProvider.notifier).replace(target, replacement);
    });
  }

  /// The minor-third-axis re-rooting of [previous] that resolves down a
  /// fifth into [witness], or null when the rule does not apply: [previous]
  /// must be an implied-root dominant carrying the flat-nine stack (the
  /// symmetry that makes its re-rootings sound identical), and must not
  /// already resolve into [witness] down a fifth or by half step (the
  /// substitute; its tritone twin resolves into the same target, so
  /// resolution carries no information about that pair).
  static int? _resolutionTwinRoot(
    ChordIdentity previous,
    ChordIdentity witness,
  ) {
    if (!previous.hasImpliedRoot || !previous.quality.isDominantFamily) {
      return null;
    }
    const flatNineStack = {
      ChordExtension.flat9,
      ChordExtension.addFlat9,
      ChordExtension.sharp9,
      ChordExtension.addSharp9,
    };
    if (!previous.extensions.any(flatNineStack.contains)) return null;
    final target = witness.rootPc;
    final down = (target + 7) % 12;
    if (previous.rootPc == down || previous.rootPc == (target + 1) % 12) {
      return null;
    }
    if ((previous.rootPc + 3) % 12 == down ||
        (previous.rootPc + 9) % 12 == down) {
      return down;
    }
    return null;
  }
}
