import 'package:meta/meta.dart';

import '../models/chord_candidate.dart';
import '../models/chord_identity.dart';
import '../models/chord_input.dart';
import '../models/observed_voicing.dart';
import '../models/playing_context.dart';
import '../models/tonality.dart';
import 'chord_event.dart';

/// One analyzed live chord eligible for capture: the data a [ChordEvent]
/// snapshots at identity onset.
@immutable
class CaptureFrame {
  final ChordInput input;
  final ObservedVoicing voicing;
  final List<ChordCandidate> candidates;
  final Tonality tonality;
  final PlayingContext playingContext;

  const CaptureFrame({
    required this.input,
    required this.voicing,
    required this.candidates,
    required this.tonality,
    this.playingContext = PlayingContext.solo,
  });

  ChordIdentity get identity => candidates.first.identity;
}

/// The pure segmentation core behind chord history capture: commits a
/// [ChordEvent] when a held identity ends.
///
/// The unit of history is a held chord identity. A different identity showing
/// up does not end the current chord immediately: it becomes a pending
/// challenger, and only ends (commits) the current chord once it has itself
/// persisted past [minChordDuration]. A challenger that vanishes back into
/// the current identity was a finger roll or passing voicing, and the current
/// chord continues as one uninterrupted event. A null frame (release, decay
/// below three notes, capture gating-off) ends the current chord directly.
/// Committed chords shorter than [minChordDuration] are dropped.
///
/// Events snapshot their frame at identity onset; same-identity changes
/// mid-hold neither update the snapshot nor re-segment the event.
///
/// Pure Dart and clock-agnostic: callers pass `now`, so the app notifier
/// drives it from live providers and a timer, while offline replay (the ASAP
/// pipeline) drives it from recorded timestamps. This class IS the capture
/// path; replay through it is replay through the real thing.
class ChordEventSegmenter {
  final Duration minChordDuration;

  DateTime? _startedAt;
  CaptureFrame? _current;
  DateTime? _pendingSince;
  CaptureFrame? _pending;

  ChordEventSegmenter({required this.minChordDuration});

  /// When the pending challenger becomes resolvable, or null if none is
  /// pending. The app notifier schedules its timer against this.
  DateTime? get pendingDeadline => _pendingSince?.add(minChordDuration);

  /// The chord currently accumulating (not yet committed), or null when
  /// nothing eligible sounds. A challenger takeover backdates this to the
  /// challenger's onset, so after a takeover its age already exceeds
  /// [minChordDuration].
  CaptureFrame? get active => _current;

  /// When [active] began, or null when nothing is active.
  DateTime? get activeSince => _startedAt;

  void reset() {
    _startedAt = null;
    _current = null;
    _clearPending();
  }

  /// Consumes the currently-analyzed frame (null when nothing is eligible for
  /// capture) and returns any events this observation committed, oldest
  /// first.
  List<ChordEvent> onFrame(CaptureFrame? frame, DateTime now) {
    final committed = <ChordEvent>[];
    _resolvePending(now, committed);

    if (frame == null) {
      // The current chord ended when an unresolved challenger began, else now.
      final end = _pendingSince ?? now;
      _clearPending();
      _commitCurrent(end, committed);
      return committed;
    }

    if (_current != null && frame.identity == _current!.identity) {
      // Back to (or still) the stable identity: any challenger was a blip.
      _clearPending();
      return committed;
    }

    if (_pending != null && frame.identity == _pending!.identity) {
      // The challenger continues; its stabilization clock keeps running.
      return committed;
    }

    if (_current == null) {
      // Nothing to protect with a debounce; the identity starts immediately
      // and the commit-time duration check drops it if it turns out fleeting.
      _startedAt = now;
      _current = frame;
      return committed;
    }

    _clearPending();
    _pendingSince = now;
    _pending = frame;
    return committed;
  }

  /// Resolves a pending challenger whose deadline has passed without a new
  /// frame arriving (the app notifier calls this from its timer).
  List<ChordEvent> resolveDue(DateTime now) {
    final committed = <ChordEvent>[];
    _resolvePending(now, committed);
    return committed;
  }

  /// Ends the stream: commits whatever is in progress, as a release would.
  List<ChordEvent> flush(DateTime now) => onFrame(null, now);

  /// Promotes the pending challenger once it has outlived the debounce:
  /// commits the current chord as ending at the challenger's onset, and the
  /// challenger becomes the current chord, backdated to that onset.
  void _resolvePending(DateTime now, List<ChordEvent> committed) {
    final pending = _pending;
    final since = _pendingSince;
    if (pending == null || since == null) return;
    if (now.difference(since) < minChordDuration) return;

    _clearPending();
    _commitCurrent(since, committed);
    _startedAt = since;
    _current = pending;
  }

  void _commitCurrent(DateTime end, List<ChordEvent> committed) {
    final startedAt = _startedAt;
    final frame = _current;
    _startedAt = null;
    _current = null;
    if (startedAt == null || frame == null) return;

    final held = end.difference(startedAt);
    if (held < minChordDuration) return;

    committed.add(
      ChordEvent(
        timestamp: startedAt,
        input: frame.input,
        voicing: frame.voicing,
        candidates: frame.candidates,
        tonality: frame.tonality,
        playingContext: frame.playingContext,
        duration: held,
      ),
    );
  }

  void _clearPending() {
    _pendingSince = null;
    _pending = null;
  }
}
