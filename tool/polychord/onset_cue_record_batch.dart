// Persistent JSON-lines adapter for Python/Dart onset-cue-record equivalence.
//
// Request: {"id":"...","frame":{...}}
// Response: {"id":"...","cueRecords":[{...}]}

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

const _builder = PolychordOnsetCueRecordBuilder();

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    final request = jsonDecode(line) as Map<String, dynamic>;
    final frameValue = request['frame'] as Map<String, dynamic>;
    final frame = PolychordOnsetTrackingFrame(
      trackerEpoch: frameValue['trackerEpoch'] as int,
      afterEventIndex: frameValue['afterEventIndex'] as int,
      timestampMs: frameValue['timestampMs'] as int,
      pedalDown: frameValue['pedalDown'] as bool,
      soundingNoteOnsets: (frameValue['onsetNotes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(_parseNote),
    );
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'id': request['id'],
        'cueRecords': [
          for (final record in _builder.build(frame)) record.toJson(),
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
