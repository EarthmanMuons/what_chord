// Persistent JSON-lines adapter for the frozen WhatChord register-only baseline.

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

const _profile = PolychordRegisterSelectorProfile.full;
const _selector = PolychordRegisterSelector();

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;
    final request = jsonDecode(line) as Map<String, dynamic>;
    final stopwatch = Stopwatch()..start();
    final midiNotes = (request['orderedMidiNotes'] as List<dynamic>)
        .cast<int>();
    final decision = _selector.decide(midiNotes, profile: _profile).toJson();
    stopwatch.stop();
    stdout.writeln(
      jsonEncode(<String, Object?>{
        'id': request['id'],
        'decision': decision,
        'elapsedMicroseconds': stopwatch.elapsedMicroseconds,
      }),
    );
  });
}
