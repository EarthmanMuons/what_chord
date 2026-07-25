/// Plain-text analysis-details documents behind each identity display's
/// `debugText`: the copyable report of what sounded, how it was identified,
/// and under what context.
library;

import 'dart:io';

import 'package:whatchord/whatchord.dart';

String analysisDetailsForNote({
  required List<int> midis,
  required String keyName,
  required String noteName,
  required String longLabel,
  required String? appVersion,
}) {
  return _debugDoc(
    sections: [
      _debugSection('Note Identity', [
        'Displayed: $noteName',
        'Full name: $longLabel',
      ]),
      _debugContext(keyName: keyName),
      _debugInput(midis: midis),
      _debugApp(appVersion: appVersion),
    ],
  );
}

String analysisDetailsForInterval({
  required List<int> midis,
  required String keyName,
  required int bassMidi,
  required int upperMidi,
  required int semitones,
  required String fromRoot,
  required String intervalLong,
  required String? appVersion,
}) {
  return _debugDoc(
    sections: [
      _debugSection('Interval Identity', [
        'Full name: $intervalLong',
        'Reference: from $fromRoot',
      ]),
      _debugContext(keyName: keyName),
      _debugInput(midis: midis),
      _debugSection('Details', [
        'Bass MIDI: $bassMidi',
        'Upper MIDI: $upperMidi',
        'Semitones: $semitones',
      ]),
      _debugApp(appVersion: appVersion),
    ],
  );
}

String analysisDetailsForChord({
  required List<int> midis,
  required String keyName,
  required String chosenSymbol,
  required String longLabel,
  required int rootPc,
  required String quality,
  required List<String> extensions,
  required List<String> alternatives,
  required ScaleDegreeAnalysis? scaleDegreeAnalysis,
  required List<String> members,
  required List<String> degrees,
  required String? appVersion,
  String? playingMode,
}) {
  final realizedBassPc = midis.first % 12;

  return _debugDoc(
    sections: [
      _debugSection('Chord Identity', [
        'Displayed: $chosenSymbol',
        'Full name: $longLabel',
        'Degrees: ${degrees.isEmpty ? '(none)' : degrees.join(', ')}',
        'Members: ${members.isEmpty ? '(none)' : members.join('-')}',
      ]),
      _debugAlternatives(alternatives),
      _debugContext(keyName: keyName, playingMode: playingMode),
      _debugInput(midis: midis),
      _debugSection('Details', [
        'Root pitch class: $rootPc',
        'Quality: $quality',
        'Extensions: ${_fmtList(extensions)}',
        'Bass pitch class: $realizedBassPc',
        'Scale degree: ${_scaleDegreeDebugLabel(scaleDegreeAnalysis)}',
      ]),
      _debugApp(appVersion: appVersion),
    ],
  );
}

String _scaleDegreeDebugLabel(ScaleDegreeAnalysis? analysis) {
  if (analysis == null) return '(none)';
  return '${analysis.romanNumeral} (${analysis.functionName}, '
      '${analysis.source.displayLabel})';
}

String _fmtList<T>(Iterable<T> items, {String empty = '(none)'}) {
  final list = items.toList();
  return list.isEmpty ? empty : '[${list.join(', ')}]';
}

String _debugSection(String title, List<String> lines) {
  return [title, ...lines.map((l) => '• $l')].join('\n');
}

String _debugAlternatives(List<String> alternatives) {
  final lines = alternatives.isEmpty ? const ['(none)'] : alternatives;
  return _debugSection('Alternatives', lines);
}

String _debugContext({required String keyName, String? playingMode}) {
  return _debugSection('Context', [
    'Key: $keyName',
    if (playingMode != null) 'Playing mode: $playingMode',
  ]);
}

String _debugInput({required List<int> midis}) {
  final pcs = (midis.map((m) => m % 12).toSet().toList()..sort());

  return _debugSection('Input', [
    'MIDI notes: ${_fmtList(midis)}',
    'Pitch classes (C=0): ${_fmtList(pcs)}',
    'Note count: ${midis.length}',
  ]);
}

String _debugApp({required String? appVersion}) {
  final String title;
  if (Platform.isAndroid) {
    title = 'Android App';
  } else if (Platform.isIOS) {
    title = 'iOS App';
  } else {
    title = 'App';
  }

  final versionLine = appVersion != null
      ? 'WhatChord v$appVersion'
      : 'WhatChord v(loading)';

  return _debugSection(title, [versionLine]);
}

String _debugDoc({required List<String> sections}) {
  return [
    ...sections.expand((s) => [s, '']).toList()..removeLast(),
  ].join('\n');
}
