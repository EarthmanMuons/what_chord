// Persistent JSON-lines adapter for Python/Dart onset-support equivalence.
//
// Request: {"id":"...","soundingNotes":[{...}]}
// Response: {"id":"...","candidateInterpretations":[{...}]}

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

const _analyzer = PolychordOnsetEvidenceAnalyzer();
const _interpreter = PolychordCoherentSeparatedOnsetInterpreter();

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    final request = jsonDecode(line) as Map<String, dynamic>;
    final notes = (request['soundingNotes'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(_parseNote);
    final interpretations = _interpreter.interpretAll(
      _analyzer.analyzeFrame(notes),
    );
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'id': request['id'],
        'candidateInterpretations': [
          for (final interpretation in interpretations) interpretation.toJson(),
        ],
      }),
    );
  });
}

PolychordSoundingNoteOnset _parseNote(Map<String, dynamic> value) {
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
