// Persistent JSON-lines adapter for Python/Dart polychord equivalence checks.
//
// Request: {"id":"...","midiNotes":[48,52,...],"selectorIds":["..."]}
// Response: {"id":"...","decisions":{"selector-id":{...}}}

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

const _selector = PolychordRegisterSelector();

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    final request = jsonDecode(line) as Map<String, dynamic>;
    final id = request['id'];
    final midiNotes = (request['midiNotes'] as List<dynamic>).cast<int>();
    final selectorIds = (request['selectorIds'] as List<dynamic>)
        .cast<String>();
    final decisions = <String, Object?>{};
    for (final selectorId in selectorIds) {
      final profile = PolychordRegisterSelectorProfile.values.singleWhere(
        (profile) => profile.selectorId == selectorId,
      );
      decisions[selectorId] = _selector
          .decide(midiNotes, profile: profile)
          .toJson();
    }

    stdout.writeln(
      jsonEncode(<String, Object?>{'id': id, 'decisions': decisions}),
    );
  });
}
