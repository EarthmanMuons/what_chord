import '../models/polychord_onset_tracking_frame.dart';
import '../models/polychord_product_onset_cue_record.dart';
import '../models/polychord_product_output.dart';

/// Continuous exact-authorization reducer for the product display.
final class PolychordContinuousAuthorizationGate {
  PolychordContinuousAuthorizationGate({this.minimumDurationMs = 200}) {
    if (minimumDurationMs < 0) {
      throw RangeError.range(minimumDurationMs, 0, null, 'minimumDurationMs');
    }
  }

  final int minimumDurationMs;

  PolychordProductDisplayState _state = PolychordProductDisplayState.absent;
  PolychordProductAuthorizationKey? _key;
  int? _deadlineMs;

  PolychordProductDisplay reset() {
    final active = _state != PolychordProductDisplayState.absent;
    _state = PolychordProductDisplayState.absent;
    _key = null;
    _deadlineMs = null;
    return _result(
      active
          ? PolychordProductDisplayTransition.clear
          : PolychordProductDisplayTransition.none,
      'tracker-reset',
    );
  }

  PolychordProductDisplay step({
    required int timestampMs,
    required PolychordOnsetTrackingFrame frame,
    required Iterable<PolychordProductOnsetCueRecord> candidateRecords,
    required PolychordProductAuthorization authorization,
  }) {
    final newKey = authorization.key;
    if (newKey != null) {
      if (_state == PolychordProductDisplayState.absent) {
        _state = PolychordProductDisplayState.pending;
        _key = newKey;
        _deadlineMs = timestampMs + minimumDurationMs;
        return _result(
          PolychordProductDisplayTransition.pending,
          'awaiting-display-stability',
        );
      }
      if (_key != newKey) {
        _state = PolychordProductDisplayState.pending;
        _key = newKey;
        _deadlineMs = timestampMs + minimumDurationMs;
        return _result(
          PolychordProductDisplayTransition.pending,
          'authorization-key-changed',
        );
      }
      if (_state == PolychordProductDisplayState.visible) {
        return _result(PolychordProductDisplayTransition.stable, null);
      }
      if (timestampMs >= _deadlineMs!) {
        _state = PolychordProductDisplayState.visible;
        _deadlineMs = null;
        return _result(PolychordProductDisplayTransition.appearance, null);
      }
      return _result(
        PolychordProductDisplayTransition.none,
        'awaiting-display-stability',
      );
    }

    if (_state == PolychordProductDisplayState.absent) {
      return _result(PolychordProductDisplayTransition.none, null);
    }
    if (frame.soundingMidiNotes.isEmpty) return _clear('silence');
    if (authorization.reasonCode == 'primary-not-displayable') {
      return _clear('primary-not-displayable');
    }
    final previousKey = _key!;
    final invalidated = candidateRecords.any((record) {
      final binding = record.targetBinding;
      return binding.trackerEpoch == previousKey.trackerEpoch &&
          binding.candidate == previousKey.candidate &&
          binding != previousKey.binding;
    });
    return _clear(
      invalidated ? 'invalidated-support-binding' : 'raw-selector-abstention',
    );
  }

  PolychordProductDisplay _clear(String reasonCode) {
    final active = _state != PolychordProductDisplayState.absent;
    _state = PolychordProductDisplayState.absent;
    _key = null;
    _deadlineMs = null;
    return _result(
      active
          ? PolychordProductDisplayTransition.clear
          : PolychordProductDisplayTransition.none,
      active ? reasonCode : null,
    );
  }

  PolychordProductDisplay _result(
    PolychordProductDisplayTransition transition,
    String? reasonCode,
  ) => PolychordProductDisplay(
    state: _state,
    transition: transition,
    key: _key,
    deadlineMs: _deadlineMs,
    reasonCode: reasonCode,
  );
}
