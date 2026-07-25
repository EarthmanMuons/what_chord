import 'package:meta/meta.dart';

import '../models/chord_candidate.dart';
import '../models/chord_identity.dart';
import '../models/chord_input.dart';
import '../models/observed_voicing.dart';
import '../models/playing_context.dart';
import '../models/tonality.dart';

/// One committed chord from live play: what sounded, how it was identified,
/// and how long it was held.
///
/// Events are the input to key detection, so they preserve everything a
/// detector needs without re-running analysis: raw pitch classes, register,
/// the ranked identification with its cost gaps, and timing.
///
/// Everything but [duration] is a snapshot from identity onset. Same-identity
/// changes mid-hold (an added octave doubling, a manual tonality switch) do
/// not update it, so [candidates] always reflect a ranking performed under
/// [tonality].
@immutable
class ChordEvent {
  /// When this identity began sounding (not when it was committed).
  final DateTime timestamp;

  /// Raw pitch-class data the identification was computed from.
  final ChordInput input;

  /// Live register evidence. Always present: only live MIDI chords with 3+
  /// sounding notes enter history, and those always carry a real voicing.
  final ObservedVoicing voicing;

  /// Ranked identification, best first: the chosen candidate followed by its
  /// surfaced near-tie alternatives. Never empty. Cost gaps are intact so
  /// detectors can down-weight ambiguous events.
  final List<ChordCandidate> candidates;

  /// Tonality the candidates were ranked under. Ranking tie-breakers are
  /// tonality-gated, so detectors need this to reason about history recorded
  /// across a tonality change.
  final Tonality tonality;

  /// Playing context the candidates were generated and ranked under. Like
  /// [tonality], a second ranking-gating input: ensemble events may carry
  /// implied-root identities a solo replay could never produce.
  final PlayingContext playingContext;

  /// How long this identity persisted before the next one stabilized or the
  /// input released.
  final Duration duration;

  ChordEvent({
    required this.timestamp,
    required this.input,
    required this.voicing,
    required List<ChordCandidate> candidates,
    required this.tonality,
    this.playingContext = PlayingContext.solo,
    required this.duration,
  }) : assert(candidates.isNotEmpty, 'ChordEvent requires a chosen candidate'),
       candidates = List.unmodifiable(candidates);

  ChordIdentity get identity => candidates.first.identity;

  double get cost => candidates.first.cost;

  @override
  String toString() =>
      'ChordEvent($timestamp, $identity, duration=$duration, '
      '${candidates.length} candidates, $tonality)';
}
