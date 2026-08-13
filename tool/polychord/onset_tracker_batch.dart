// Persistent JSON-lines adapter for Python/Dart onset-tracker equivalence.
//
// Request: {"id":"...","initialState":{...},"events":[{...}]}
// Response: {"id":"...","frames":[{...}]}

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    final request = jsonDecode(line) as Map<String, dynamic>;
    final initialState = request['initialState'] as Map<String, dynamic>;
    final tracker = PolychordOnsetTracker(
      initiallyPressedMidiNotes: (initialState['pressedMidiNotes'] as List)
          .cast<int>(),
      initiallySustainedMidiNotes: (initialState['sustainedMidiNotes'] as List)
          .cast<int>(),
      initiallyPedalDown: initialState['pedalDown'] as bool,
    );
    final events = (request['events'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    final frames = [
      for (final event in events) tracker.step(_parseEvent(event)).toJson(),
    ];
    stdout.writeln(
      jsonEncode(<String, Object?>{'id': request['id'], 'frames': frames}),
    );
  });
}

PolychordTemporalEvent _parseEvent(Map<String, dynamic> value) {
  final timestampMs = value['timestampMs'] as int;
  return switch (value['type']) {
    'noteOn' => PolychordNoteOnEvent(
      timestampMs: timestampMs,
      midiNote: value['midiNote'] as int,
      velocity: value['velocity'] as int,
    ),
    'noteOff' => PolychordNoteOffEvent(
      timestampMs: timestampMs,
      midiNote: value['midiNote'] as int,
      velocity: value['velocity'] as int,
    ),
    'pedal' => PolychordSustainPedalEvent(
      timestampMs: timestampMs,
      down: value['down'] as bool,
    ),
    final type => throw ArgumentError.value(type, 'event.type'),
  };
}
