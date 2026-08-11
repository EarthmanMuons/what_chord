import 'package:meta/meta.dart';

import '../models/polychord_candidate.dart';

/// Stable transition names emitted by [PolychordStableDisplayGate].
enum PolychordDisplayTransition {
  none,
  pending,
  stable,
  appearance,
  change,
  clear,
}

/// One state transition from the exact-assignment polychord display gate.
@immutable
final class PolychordStableDisplayResult {
  const PolychordStableDisplayResult({
    required this.displayed,
    required this.transition,
    required this.reasonCode,
  });

  /// Candidate visible after this transition, or null when none is visible.
  final PolychordCandidate? displayed;

  /// State-machine transition produced by the observation.
  final PolychordDisplayTransition transition;

  /// Stable diagnostic token explaining a non-visible or pending result.
  final String? reasonCode;
}

/// Pure 200-millisecond appearance gate for a secondary polychord annotation.
///
/// The primary chord owns a separate identity-stability path. This reducer
/// delays only the optional secondary annotation, compares exact note
/// assignments rather than identity alone, and clears immediately when the
/// displayed assignment stops matching the complete sounding set.
final class PolychordStableDisplayGate {
  PolychordStableDisplayGate({
    this.minDuration = const Duration(milliseconds: 200),
  }) {
    if (minDuration.isNegative) {
      throw RangeError.range(
        minDuration.inMicroseconds,
        0,
        null,
        'minDuration',
        'must be nonnegative',
      );
    }
  }

  /// Required persistence before a new exact selection may appear.
  final Duration minDuration;

  Duration? _lastTimestamp;
  PolychordCandidate? _pending;
  Duration? _pendingSince;
  PolychordCandidate? _displayed;

  /// Candidate currently visible, or null when the annotation is absent.
  PolychordCandidate? get displayed => _displayed;

  /// Exact raw selection currently proving itself, if any.
  PolychordCandidate? get pending => _pending;

  /// When [pending] becomes eligible for a timer-driven promotion.
  Duration? get pendingDeadline {
    final since = _pendingSince;
    return since == null ? null : since + minDuration;
  }

  /// Clears all timing and display state.
  void reset() {
    _lastTimestamp = null;
    _displayed = null;
    _resetPending();
  }

  /// Applies one raw selector observation at a monotonic elapsed timestamp.
  PolychordStableDisplayResult step({
    required Duration timestamp,
    required PolychordCandidate? rawSelected,
    required bool primaryDisplayable,
    required Iterable<int> soundingMidiNotes,
  }) {
    if (timestamp.isNegative) {
      throw RangeError.range(
        timestamp.inMicroseconds,
        0,
        null,
        'timestamp',
        'must be nonnegative',
      );
    }
    final previousTimestamp = _lastTimestamp;
    if (previousTimestamp != null && timestamp < previousTimestamp) {
      throw ArgumentError.value(
        timestamp,
        'timestamp',
        'must be nondecreasing',
      );
    }
    _lastTimestamp = timestamp;

    final notes = _validateMidiNotes(soundingMidiNotes);
    if (!primaryDisplayable) return _clear('primary-not-displayable');
    if (notes.isEmpty) return _clear('silence');

    final noteSet = notes.toSet();
    if (rawSelected != null &&
        !_setsEqual(_assignedNotes(rawSelected), noteSet)) {
      throw ArgumentError.value(
        rawSelected,
        'rawSelected',
        'must exhaust soundingMidiNotes',
      );
    }

    final displayedInvalid =
        _displayed != null && !_setsEqual(_assignedNotes(_displayed!), noteSet);
    if (displayedInvalid) {
      _displayed = null;
      _resetPending();
      if (rawSelected != null) {
        _pending = rawSelected;
        _pendingSince = timestamp;
      }
      return _result(
        PolychordDisplayTransition.clear,
        'invalidated-assignment',
      );
    }
    if (rawSelected == null) return _clear('abstention');
    if (rawSelected == _displayed) {
      _resetPending();
      return _result(PolychordDisplayTransition.stable, null);
    }

    if (rawSelected != _pending) {
      _pending = rawSelected;
      _pendingSince = timestamp;
      return _result(PolychordDisplayTransition.pending, 'unstable-selection');
    }

    final pendingSince = _pendingSince!;
    if (timestamp - pendingSince < minDuration) {
      return _result(PolychordDisplayTransition.pending, 'unstable-selection');
    }

    final transition = _displayed == null
        ? PolychordDisplayTransition.appearance
        : PolychordDisplayTransition.change;
    _displayed = rawSelected;
    _resetPending();
    return _result(transition, null);
  }

  PolychordStableDisplayResult _clear(String reasonCode) {
    final transition = _displayed == null
        ? PolychordDisplayTransition.none
        : PolychordDisplayTransition.clear;
    _displayed = null;
    _resetPending();
    return _result(transition, reasonCode);
  }

  void _resetPending() {
    _pending = null;
    _pendingSince = null;
  }

  PolychordStableDisplayResult _result(
    PolychordDisplayTransition transition,
    String? reasonCode,
  ) => PolychordStableDisplayResult(
    displayed: _displayed,
    transition: transition,
    reasonCode: reasonCode,
  );
}

List<int> _validateMidiNotes(Iterable<int> midiNotes) {
  final notes = List<int>.of(midiNotes);
  for (var index = 0; index < notes.length; index++) {
    final note = notes[index];
    if (note < 0 || note > 127) {
      throw RangeError.range(note, 0, 127, 'soundingMidiNotes[$index]');
    }
    if (index > 0 && note <= notes[index - 1]) {
      throw ArgumentError.value(
        notes,
        'soundingMidiNotes',
        'must be strictly increasing without duplicates',
      );
    }
  }
  return List<int>.unmodifiable(notes);
}

Set<int> _assignedNotes(PolychordCandidate candidate) => {
  ...candidate.lower.midiNotes,
  ...candidate.upper.midiNotes,
};

bool _setsEqual(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);
