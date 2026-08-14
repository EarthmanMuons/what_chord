import '../models/polychord_onset_tracking_frame.dart';
import '../models/polychord_product_decision.dart';
import '../models/polychord_product_output.dart';
import '../models/polychord_temporal_event.dart';
import 'polychord_continuous_authorization_gate.dart';
import 'polychord_onset_register_selector.dart';
import 'polychord_onset_tracker.dart';
import 'polychord_product_authorizer.dart';

/// Stateful product composition for automatic timestamped-MIDI polychords.
///
/// The snapshot chord analyzer remains separate and stateless. This engine owns
/// only reset-scoped onset identity, the frozen raw selector, outer primary
/// authorization, and the secondary annotation's presentation stability.
final class PolychordProductEngine {
  PolychordProductEngine({
    required bool initialPrimaryDisplayable,
    Iterable<int> initiallyPressedMidiNotes = const [],
    Iterable<int> initiallySustainedMidiNotes = const [],
    bool initiallyPedalDown = false,
  }) : _primaryDisplayable = initialPrimaryDisplayable,
       _tracker = PolychordOnsetTracker(
         initiallyPressedMidiNotes: initiallyPressedMidiNotes,
         initiallySustainedMidiNotes: initiallySustainedMidiNotes,
         initiallyPedalDown: initiallyPedalDown,
       );

  final PolychordOnsetTracker _tracker;
  final PolychordContinuousAuthorizationGate _displayGate =
      PolychordContinuousAuthorizationGate();
  bool _primaryDisplayable;
  int? _lastObservationTimestampMs;
  PolychordOnsetTrackingFrame? _frame;
  PolychordOnsetRegisterDecision? _decision;
  PolychordProductAuthorization? _authorization;

  bool get primaryDisplayable => _primaryDisplayable;
  PolychordProductObservation? get latestObservation => _latestObservation;
  PolychordProductObservation? _latestObservation;

  PolychordProductObservation observeEvent(PolychordTemporalEvent event) {
    _checkTimestamp(event.timestampMs);
    final frame = _tracker.step(event);
    _frame = frame;
    _decision = const PolychordOnsetRegisterSelector().decide(frame);
    _authorization = const PolychordProductAuthorizer().authorize(
      primaryDisplayable: _primaryDisplayable,
      decision: _decision!,
    );
    final display = _displayGate.step(
      timestampMs: event.timestampMs,
      frame: frame,
      candidateRecords: _decision!.candidateRecords,
      authorization: _authorization!,
    );
    return _publish(event.timestampMs, display);
  }

  PolychordProductObservation observeTimer(int timestampMs) {
    _checkTimestamp(timestampMs);
    final frame = _requireFrame('timer observation');
    final display = _displayGate.step(
      timestampMs: timestampMs,
      frame: frame,
      candidateRecords: _decision!.candidateRecords,
      authorization: _authorization!,
    );
    return _publish(timestampMs, display);
  }

  PolychordProductObservation setPrimaryDisplayable({
    required int timestampMs,
    required bool displayable,
  }) {
    _checkTimestamp(timestampMs);
    final frame = _requireFrame('primary availability');
    _primaryDisplayable = displayable;
    _authorization = const PolychordProductAuthorizer().authorize(
      primaryDisplayable: displayable,
      decision: _decision!,
    );
    final display = _displayGate.step(
      timestampMs: timestampMs,
      frame: frame,
      candidateRecords: _decision!.candidateRecords,
      authorization: _authorization!,
    );
    return _publish(timestampMs, display);
  }

  PolychordProductObservation reset({
    required int timestampMs,
    Iterable<int> initiallyPressedMidiNotes = const [],
    Iterable<int> initiallySustainedMidiNotes = const [],
    bool initiallyPedalDown = false,
  }) {
    _checkTimestamp(timestampMs);
    _tracker.reset(
      initiallyPressedMidiNotes: initiallyPressedMidiNotes,
      initiallySustainedMidiNotes: initiallySustainedMidiNotes,
      initiallyPedalDown: initiallyPedalDown,
    );
    _frame = null;
    _decision = null;
    _authorization = null;
    return _publish(timestampMs, _displayGate.reset());
  }

  PolychordOnsetTrackingFrame _requireFrame(String action) {
    final frame = _frame;
    if (frame == null) {
      throw StateError('$action requires a prior musical frame');
    }
    return frame;
  }

  void _checkTimestamp(int timestampMs) {
    if (timestampMs < 0 || timestampMs > _maximumExactJsonInteger) {
      throw RangeError.range(
        timestampMs,
        0,
        _maximumExactJsonInteger,
        'timestampMs',
      );
    }
    final previous = _lastObservationTimestampMs;
    if (previous != null && timestampMs < previous) {
      throw ArgumentError.value(
        timestampMs,
        'timestampMs',
        'must be nondecreasing across product observations',
      );
    }
  }

  PolychordProductObservation _publish(
    int timestampMs,
    PolychordProductDisplay display,
  ) {
    _lastObservationTimestampMs = timestampMs;
    final observation = PolychordProductObservation(
      observationTimestampMs: timestampMs,
      frame: _frame,
      candidates: _decision?.candidates ?? const [],
      candidateRecords: _decision?.candidateRecords ?? const [],
      rawDecision: _decision,
      authorization: _authorization,
      display: display,
    );
    _latestObservation = observation;
    return observation;
  }
}

const _maximumExactJsonInteger = 9007199254740991;
