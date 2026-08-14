// Persistent JSON-lines adapter for Python/Dart product-policy equivalence.
//
// Session requests carry only fixture events and product-control actions.
// Decision requests carry one complete onset frame. Neither request shape
// contains expected labels or product-suite checkpoint values.

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;
    final request = jsonDecode(line) as Map<String, dynamic>;
    final response = switch (request['mode']) {
      'session' => _runSession(request),
      'decision' => _runDecision(request),
      final mode => throw FormatException('unsupported request mode: $mode'),
    };
    stdout.writeln(jsonEncode(response));
  });
}

Map<String, Object?> _runSession(Map<String, dynamic> request) {
  final initial = request['initialState'] as Map<String, dynamic>;
  final engine = PolychordProductEngine(
    initialPrimaryDisplayable: request['initialPrimaryDisplayable'] as bool,
    initiallyPressedMidiNotes: (initial['pressedMidiNotes'] as List<dynamic>)
        .cast<int>(),
    initiallySustainedMidiNotes:
        (initial['sustainedMidiNotes'] as List<dynamic>).cast<int>(),
    initiallyPedalDown: initial['pedalDown'] as bool,
  );
  final events = (request['events'] as List<dynamic>)
      .cast<Map<String, dynamic>>();
  final observations = <Map<String, Object?>>[];
  for (final action
      in (request['actions'] as List<dynamic>).cast<Map<String, dynamic>>()) {
    final timestampMs = action['timestampMs'] as int;
    final observation = switch (action['type']) {
      'musicalEvent' => engine.observeEvent(
        _parseEvent(events[action['eventIndex'] as int]),
      ),
      'timer' => engine.observeTimer(timestampMs),
      'primaryAvailability' => engine.setPrimaryDisplayable(
        timestampMs: timestampMs,
        displayable: action['displayable'] as bool,
      ),
      'trackerReset' => engine.reset(timestampMs: timestampMs),
      final type => throw FormatException('unsupported action type: $type'),
    };
    observations.add(<String, Object?>{
      'actionId': action['id'],
      'observation': observation.toJson(),
    });
  }
  return <String, Object?>{'id': request['id'], 'observations': observations};
}

Map<String, Object?> _runDecision(Map<String, dynamic> request) {
  final frame = _parseFrame(request['frame'] as Map<String, dynamic>);
  return <String, Object?>{
    'id': request['id'],
    'decision': const PolychordOnsetRegisterSelector().decide(frame).toJson(),
  };
}

PolychordTemporalEvent _parseEvent(Map<String, dynamic> value) =>
    switch (value['type']) {
      'noteOn' => PolychordNoteOnEvent(
        timestampMs: value['timestampMs'] as int,
        midiNote: value['midiNote'] as int,
        velocity: value['velocity'] as int,
      ),
      'noteOff' => PolychordNoteOffEvent(
        timestampMs: value['timestampMs'] as int,
        midiNote: value['midiNote'] as int,
        velocity: value['velocity'] as int,
      ),
      'pedal' => PolychordSustainPedalEvent(
        timestampMs: value['timestampMs'] as int,
        down: value['down'] as bool,
      ),
      final type => throw FormatException('unsupported event type: $type'),
    };

PolychordOnsetTrackingFrame _parseFrame(Map<String, dynamic> value) =>
    PolychordOnsetTrackingFrame(
      trackerEpoch: value['trackerEpoch'] as int,
      afterEventIndex: value['afterEventIndex'] as int,
      timestampMs: value['timestampMs'] as int,
      pedalDown: value['pedalDown'] as bool,
      soundingNoteOnsets: (value['onsetNotes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_parseOnsetNote),
    );

PolychordSoundingNoteOnset _parseOnsetNote(Map<String, dynamic> value) {
  final eventIndex = value['onsetEventIndex'] as int?;
  return PolychordSoundingNoteOnset(
    midiNote: value['midiNote'] as int,
    soundingState: PolychordSoundingState.values.byName(
      value['soundingState'] as String,
    ),
    origin: eventIndex == null
        ? null
        : PolychordOnsetOrigin(
            eventIndex: eventIndex,
            timestampMs: value['onsetTimestampMs'] as int,
            velocity: value['onsetVelocity'] as int,
          ),
  );
}
