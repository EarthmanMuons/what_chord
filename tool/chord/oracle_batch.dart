// tool/chord/oracle_batch.dart
//
// Persistent batch entry point for the oracle comparison harness
// (tool/chord/oracle_compare.py). Reads one JSON request per stdin line and
// writes one JSON response per stdout line, keeping a single warm Dart VM for
// the whole run instead of paying `dart run` startup per case.
//
// Each response is the same payload `bin/chord-debug --format=json` emits (via
// the shared chordDebugJsonPayload), wrapped with the request "id", so the
// Python harness consumes it without any output-shape changes.
//
// Request line: {"id": "...", "notes": ["C","E","G"], "bass": "C",
//                "top": 4, "key": "C:maj"}

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

import '../chord_debug.dart';
import '../src/chord_id_engine.dart';

final _analyzers = <double?, ChordAnalyzer>{null: ChordAnalyzer()};

ChordAnalyzer _analyzerFor(double? shellSeventhCost) => _analyzers.putIfAbsent(
  shellSeventhCost,
  () => ChordAnalyzer(shellSeventhCost: shellSeventhCost),
);

void main() {
  stdin.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
    if (line.trim().isEmpty) return;

    final request = jsonDecode(line) as Map<String, dynamic>;
    final id = request['id'];
    final notes = (request['notes'] as List).cast<String>();
    final bass = request['bass'] as String?;
    final top = (request['top'] as num?)?.toInt() ?? 5;
    final keyFlag = (request['key'] as String?) ?? 'C:maj';

    final tonality = parseTonality(keyFlag);
    final ks = KeySignature.fromTonality(tonality);
    final context = AnalysisContext(
      tonality: tonality,
      keySignature: ks,
      spellingPolicy: NoteSpellingPolicy(preferFlats: ks.prefersFlats),
    );

    final prepared = prepareChordDebugInput(
      noteTokens: notes,
      bassName: bass,
      context: context,
    );
    if (prepared == null) {
      stdout.writeln(
        jsonEncode(<String, Object?>{
          'id': id,
          'input': null,
          'candidates': [],
        }),
      );
      return;
    }

    final analyzer = _analyzerFor(
      (request['shellSeventhCost'] as num?)?.toDouble(),
    );
    final results = analyzer.explain(
      prepared.input,
      context: context,
      take: top,
    );
    final payload = chordDebugJsonPayload(
      input: prepared.input,
      context: context,
      notation: ChordNotationStyle.textual,
      pcDisplays: prepared.pcDisplays,
      bassLabel: prepared.bassLabel,
      results: results,
    );

    stdout.writeln(jsonEncode(<String, Object?>{'id': id, ...payload}));
  });
}
