// Persistent JSON-lines adapter for Python/Dart transition/motion equivalence.
//
// Request: {"id":"...","initialState":{...},"events":[{...}]}
// Response: {"id":"...","windows":[{...}]}

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    final request = jsonDecode(line) as Map<String, dynamic>;
    final initialState = request['initialState'] as Map<String, dynamic>;
    final tracker = PolychordReleasePedalTracker(
      initiallyPressedMidiNotes: (initialState['pressedMidiNotes'] as List)
          .cast<int>(),
      initiallySustainedMidiNotes: (initialState['sustainedMidiNotes'] as List)
          .cast<int>(),
      initiallyPedalDown: initialState['pedalDown'] as bool,
    );
    final frames = <PolychordReleasePedalTrackingFrame>[];
    final steps = <PolychordFrameTransitionStep>[];
    for (final value
        in (request['events'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      if (value['index'] != frames.length) {
        throw ArgumentError('event indices must be consecutive from zero');
      }
      final event = _parseEvent(value);
      final frame = tracker.step(event);
      frames.add(frame);
      steps.add(PolychordFrameTransitionStep(event: event, frame: frame));
    }

    const analyzer = PolychordFrameTransitionEvidenceAnalyzer();
    const interpreter = PolychordRigidLayerMotionInterpreter();
    final windows = <Map<String, Object>>[];
    for (var source = 0; source < frames.length - 1; source++) {
      for (var target = source + 1; target < frames.length; target++) {
        final evidence = analyzer.analyze(
          window: PolychordFrameTransitionWindow(
            sourceFrame: frames[source],
            transitionSteps: steps.sublist(source + 1, target + 1),
          ),
        );
        windows.add(<String, Object>{
          'sourceAfterEventIndex': source,
          'targetAfterEventIndex': target,
          ...evidence.toJson(),
          'candidateInterpretations': [
            for (final interpretation in interpreter.interpret(evidence))
              interpretation.toJson(),
          ],
        });
      }
    }
    stdout.writeln(
      jsonEncode(<String, Object?>{'id': request['id'], 'windows': windows}),
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
