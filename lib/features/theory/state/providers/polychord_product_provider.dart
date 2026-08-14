import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/features/input/input.dart';

import 'displayed_chord_provider.dart';

/// Matches the research replay's live `CaptureFrame` availability definition;
/// this intentionally does not wait for the card's separate stability timer.
final polychordPrimaryDisplayableProvider = Provider<bool>((ref) {
  return ref.watch(displayFrameProvider) != null;
});

final polychordProductObservationProvider =
    NotifierProvider<PolychordProductNotifier, PolychordProductObservation?>(
      PolychordProductNotifier.new,
    );

/// Keeps temporal tracking alive even while the home analysis region is absent.
final appPolychordLifecycleProvider = Provider<void>((ref) {
  ref.listen(polychordProductObservationProvider, (previous, next) {});
});

/// App adapter around the pure-Dart product engine.
///
/// Input and primary-provider notifications from one MIDI message may arrive in
/// different Riverpod microtasks. Commands are drained in timestamp order on
/// the next event turn so an availability notification cannot overtake the
/// musical event that caused it.
class PolychordProductNotifier extends Notifier<PolychordProductObservation?> {
  late PolychordProductEngine _engine;
  late bool _appliedPrimaryDisplayable;
  final List<_PolychordAppCommand> _commands = [];
  int _nextCommandOrder = 0;
  Timer? _commandTimer;
  Timer? _displayTimer;

  @override
  PolychordProductObservation? build() {
    _appliedPrimaryDisplayable = ref.read(polychordPrimaryDisplayableProvider);
    _engine = PolychordProductEngine(
      initialPrimaryDisplayable: _appliedPrimaryDisplayable,
    );

    ref.onDispose(() {
      _commandTimer?.cancel();
      _displayTimer?.cancel();
    });
    ref.listen<AsyncValue<InputTemporalEvent>>(inputTemporalEventsProvider, (
      previous,
      next,
    ) {
      final event = next.asData?.value;
      if (event == null) return;
      _enqueue(_InputCommand(event: event));
    });
    ref.listen<bool>(polychordPrimaryDisplayableProvider, (previous, next) {
      if (previous == next) return;
      _enqueue(_PrimaryCommand(timestampMs: _now(), displayable: next));
    });
    return null;
  }

  void _enqueue(_PolychordAppCommand command) {
    command.order = _nextCommandOrder++;
    _commands.add(command);
    _commandTimer ??= Timer(Duration.zero, _drainCommands);
  }

  void _drainCommands() {
    _commandTimer = null;
    _commands.sort((left, right) {
      final timestamp = left.timestampMs.compareTo(right.timestampMs);
      return timestamp != 0 ? timestamp : left.order.compareTo(right.order);
    });
    final commands = List<_PolychordAppCommand>.of(_commands);
    _commands.clear();

    for (final command in commands) {
      final timestampMs = _effectiveTimestamp(command.timestampMs);
      final observation = switch (command) {
        _InputCommand(:final event) => _observeInput(event, timestampMs),
        _PrimaryCommand(:final displayable) => _observePrimary(
          timestampMs,
          displayable,
        ),
        _TimerCommand() => _engine.observeTimer(timestampMs),
      };
      if (observation != null) _publish(observation);
    }
  }

  PolychordProductObservation _observeInput(
    InputTemporalEvent event,
    int timestampMs,
  ) {
    if (event case InputTemporalResetEvent(:final snapshot)) {
      return _engine.reset(
        timestampMs: timestampMs,
        initiallyPressedMidiNotes: snapshot.pressedNoteNumbers,
        initiallySustainedMidiNotes: snapshot.sustainedNoteNumbers,
        initiallyPedalDown: snapshot.pedalDown,
      );
    }

    final temporalEvent = switch (event) {
      InputTemporalNoteOnEvent(:final noteNumber, :final velocity) =>
        PolychordNoteOnEvent(
          timestampMs: timestampMs,
          midiNote: noteNumber,
          velocity: velocity,
        ),
      InputTemporalNoteOffEvent(:final noteNumber, :final velocity) =>
        PolychordNoteOffEvent(
          timestampMs: timestampMs,
          midiNote: noteNumber,
          velocity: velocity,
        ),
      InputTemporalPedalEvent(:final down) => PolychordSustainPedalEvent(
        timestampMs: timestampMs,
        down: down,
      ),
      InputTemporalResetEvent() => throw StateError('handled above'),
    };
    var observation = _engine.observeEvent(temporalEvent);
    if (_engine.primaryDisplayable != _appliedPrimaryDisplayable) {
      observation = _engine.setPrimaryDisplayable(
        timestampMs: timestampMs,
        displayable: _appliedPrimaryDisplayable,
      );
    }
    return observation;
  }

  PolychordProductObservation? _observePrimary(
    int timestampMs,
    bool displayable,
  ) {
    _appliedPrimaryDisplayable = displayable;
    if (_engine.primaryDisplayable == displayable ||
        _engine.latestObservation?.frame == null) {
      return null;
    }
    return _engine.setPrimaryDisplayable(
      timestampMs: timestampMs,
      displayable: displayable,
    );
  }

  void _publish(PolychordProductObservation observation) {
    _displayTimer?.cancel();
    _displayTimer = null;
    final deadlineMs = observation.display.deadlineMs;
    if (deadlineMs != null) {
      final delayMs = deadlineMs - _now();
      _displayTimer = Timer(
        Duration(milliseconds: delayMs > 0 ? delayMs : 0),
        () {
          _displayTimer = null;
          _enqueue(
            _TimerCommand(
              timestampMs: _now() < deadlineMs ? deadlineMs : _now(),
            ),
          );
        },
      );
    }

    // Provider callbacks can land during a refresh pass. Publish between passes
    // while retaining every immutable diagnostic observation in event order.
    scheduleMicrotask(() {
      if (ref.mounted) state = observation;
    });
  }

  int _now() => ref.read(inputEventClockProvider)();

  int _effectiveTimestamp(int requested) {
    final previous = _engine.latestObservation?.observationTimestampMs;
    return previous != null && requested < previous ? previous : requested;
  }
}

sealed class _PolychordAppCommand {
  _PolychordAppCommand({required this.timestampMs});

  final int timestampMs;
  late int order;
}

final class _InputCommand extends _PolychordAppCommand {
  _InputCommand({required this.event}) : super(timestampMs: event.timestampMs);

  final InputTemporalEvent event;
}

final class _PrimaryCommand extends _PolychordAppCommand {
  _PrimaryCommand({required super.timestampMs, required this.displayable});

  final bool displayable;
}

final class _TimerCommand extends _PolychordAppCommand {
  _TimerCommand({required super.timestampMs});
}
