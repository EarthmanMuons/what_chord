// Track D gate measurement: rootless and ensemble voicings.
//
// Scores the hand-authored comping suite
// (research/chord-context/data/sources/comping/) two ways:
//
//   current: the shipped engine's top-1 under the case's key. This is the
//     baseline a jazz pianist comping over a bassist sees today.
//   rootless: a simulated missing-root hypothesis per
//     research/chord-context/rootless-voicings-notes.md item 1 - for every
//     root NOT sounding, accept the reading when the guide tones (3rd and
//     7th) are present and every remaining tone is a legal color. Reports
//     ALL surviving hypotheses per case, because the gate's real question
//     is whether relaxing the no-ghost-roots rule yields a unique answer or
//     an ambiguity explosion.
//   engine: the real engine under the case's intended playing context
//     (ensemble for rootless and shell cases, solo for solo cases), scoring
//     the shipped ensemble implementation against the same suite.
//
// Pass/fail probes; excluded from pooled statistics per PROTOCOL.md.
//
// Usage:
//   dart run tool/chord-context/comping_gate.dart \
//     --suite research/chord-context/data/sources/comping/comping-suite-v1.json

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

import '../src/chord_id_engine.dart';

/// Colors a rootless voicing may carry above its (absent) root, as semitone
/// intervals: 5th, and the tension set b9/9/11/#11/b13/13.
const _legalColors = {1, 2, 5, 6, 7, 8, 9};

void main(List<String> args) {
  final options = _parseArgs(args);
  final suite = jsonDecode(
    File(options['suite']!).readAsStringSync(),
  ) as Map<String, dynamic>;
  final cases = (suite['cases'] as List).cast<Map>();
  final analyzer = ChordAnalyzer();

  var currentExact = 0, currentRootQuality = 0, scored = 0;
  var rootlessContains = 0, rootlessUnique = 0, rootlessCases = 0;
  var rootlessKeyUnique = 0;
  var soloCases = 0, soloCorrect = 0, soloAtRisk = 0;
  var engineExact = 0, engineRootQuality = 0;
  var engineEnsembleExact = 0, engineSoloExact = 0;
  final rows = <Map<String, dynamic>>[];

  for (final raw in cases) {
    final testCase = raw.cast<String, dynamic>();
    final midiNotes = (testCase['midiNotes'] as List).cast<int>()..sort();
    final expected = (testCase['expected'] as Map).cast<String, dynamic>();
    final tonality = parseTonality(testCase['key'] as String);
    final keySignature = KeySignature.fromTonality(tonality);
    final context = AnalysisContext(
      tonality: tonality,
      keySignature: keySignature,
      spellingPolicy: NoteSpellingPolicy(
        preferFlats: keySignature.prefersFlats,
      ),
    );
    final intendedContext = AnalysisContext(
      tonality: tonality,
      keySignature: keySignature,
      spellingPolicy: NoteSpellingPolicy(
        preferFlats: keySignature.prefersFlats,
      ),
      playingContext: testCase['intent'] == 'solo'
          ? PlayingContext.solo
          : PlayingContext.ensemble,
    );

    var pcMask = 0;
    for (final note in midiNotes) {
      pcMask |= 1 << (note % 12);
    }
    final input = ChordInput(
      pcMask: pcMask,
      bassPc: midiNotes.first % 12,
      noteCount: midiNotes.length,
    );
    final observed = ObservedVoicing.fromMidi(midiNotes);
    final ranked = analyzer.analyze(input, context: context, voicing: observed);
    final top = ranked.first.identity;
    final engineTop = analyzer
        .analyze(input, context: intendedContext, voicing: observed)
        .first
        .identity;
    final expectedRoot = expected['rootPc'] as int;
    final expectedQuality = expected['quality'] as String;
    final expectedExtensions = (expected['extensions'] as List).cast<String>()
      ..sort();

    final rootQualityMatch =
        top.rootPc == expectedRoot && top.quality.name == expectedQuality;
    final actualExtensions = [for (final e in top.extensions) e.name]..sort();
    final exactMatch =
        rootQualityMatch &&
        actualExtensions.join(',') == expectedExtensions.join(',');
    scored++;
    if (rootQualityMatch) currentRootQuality++;
    if (exactMatch) currentExact++;

    final engineRootQualityMatch =
        engineTop.rootPc == expectedRoot &&
        engineTop.quality.name == expectedQuality;
    final engineExtensions = [for (final e in engineTop.extensions) e.name]
      ..sort();
    final engineExactMatch =
        engineRootQualityMatch &&
        engineExtensions.join(',') == expectedExtensions.join(',');
    if (engineRootQualityMatch) engineRootQuality++;
    if (engineExactMatch) engineExact++;

    final hypotheses = _rootlessHypotheses(pcMask);
    // Key-filtered hypotheses: an ensemble mode would run with a prevailing
    // key, so the gate must know whether diatonic filtering resolves the
    // ambiguity that ghost roots alone create.
    final keyFiltered = [
      for (final h in hypotheses)
        if (tonality.containsPitchClass(h.rootPc)) h,
    ];
    final intent = testCase['intent'] as String;
    final containsExpected = hypotheses.any(
      (h) => h.rootPc == expectedRoot && h.quality == expectedQuality,
    );
    final keyFilteredUnique =
        keyFiltered.length == 1 &&
        keyFiltered.single.rootPc == expectedRoot &&
        keyFiltered.single.quality == expectedQuality;
    if (intent == 'rootless' || intent == 'shell') {
      rootlessCases++;
      if (containsExpected) rootlessContains++;
      if (containsExpected && hypotheses.length == 1) rootlessUnique++;
      if (keyFilteredUnique) rootlessKeyUnique++;
      if (engineExactMatch) engineEnsembleExact++;
    }
    if (intent == 'solo') {
      soloCases++;
      if (rootQualityMatch) soloCorrect++;
      if (engineExactMatch) engineSoloExact++;
      // A solo case is at risk if a rootless hypothesis exists at all: an
      // ensemble mode that trusts ghost roots could overturn the correct
      // bass-rooted reading on exactly these pitch sets.
      if (hypotheses.isNotEmpty) soloAtRisk++;
    }

    rows.add({
      'id': testCase['id'],
      'intent': intent,
      'voicing': testCase['voicing'],
      'expected': '$expectedRoot/$expectedQuality',
      'current': '${top.rootPc}/${top.quality.name}',
      'currentRootQualityMatch': rootQualityMatch,
      'engine': '${engineTop.rootPc}/${engineTop.quality.name}',
      'engineExactMatch': engineExactMatch,
      'rootlessHypotheses': [
        for (final h in hypotheses) '${h.rootPc}/${h.quality}',
      ],
      'rootlessContainsExpected': containsExpected,
    });
  }

  final report = {
    'schema': 'chord-context-comping-gate/1',
    'suite': options['suite'],
    'summary': {
      'cases': scored,
      'currentExact': currentExact,
      'currentRootQuality': currentRootQuality,
      'rootlessCases': rootlessCases,
      'rootlessContainsExpected': rootlessContains,
      'rootlessUniquelyExpected': rootlessUnique,
      'rootlessUniqueAfterKeyFilter': rootlessKeyUnique,
      'soloCases': soloCases,
      'soloCorrectToday': soloCorrect,
      'soloAtRiskUnderGhostRoots': soloAtRisk,
      'engineExact': engineExact,
      'engineRootQuality': engineRootQuality,
      'engineEnsembleExact': engineEnsembleExact,
      'engineSoloExact': engineSoloExact,
    },
    'cases': rows,
  };
  final outDir = Directory(options['out'] ?? 'build/chord-context/comping')
    ..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');

  stdout.writeln('comping gate: ${cases.length} cases');
  stdout.writeln(
    '  current engine: $currentRootQuality/$scored root+quality, '
    '$currentExact/$scored exact',
  );
  stdout.writeln(
    '  rootless/shell cases: $rootlessCases; ghost-root hypothesis '
    'contains expected in $rootlessContains, uniquely in $rootlessUnique, '
    'uniquely after diatonic key filter in $rootlessKeyUnique',
  );
  stdout.writeln(
    '  solo cases: $soloCorrect/$soloCases correct today; '
    '$soloAtRisk would admit a ghost-root competitor',
  );
  stdout.writeln(
    '  engine (intended playing context): '
    '$engineEnsembleExact/$rootlessCases rootless+shell exact, '
    '$engineSoloExact/$soloCases solo exact, '
    '$engineExact/$scored exact overall',
  );
  stdout.writeln('');
  for (final row in rows) {
    final mark = row['engineExactMatch'] as bool ? 'ok  ' : 'MISS';
    final hyps = (row['rootlessHypotheses'] as List).join(' ');
    stdout.writeln(
      '  $mark ${(row['id'] as String).padRight(34)} '
      '${(row['voicing'] as String).padRight(11)} '
      'want ${(row['expected'] as String).padRight(18)} '
      'engine ${(row['engine'] as String).padRight(18)} '
      'ghost[${(row['rootlessHypotheses'] as List).length}] $hyps',
    );
  }
}

class _Hypothesis {
  _Hypothesis(this.rootPc, this.quality);
  final int rootPc;
  final String quality;
}

/// Missing-root readings of [pcMask]: for every absent root, require the
/// guide tones (a third and a seventh) and legal colors for the rest.
List<_Hypothesis> _rootlessHypotheses(int pcMask) {
  final sounding = [
    for (var pc = 0; pc < 12; pc++)
      if (pcMask & (1 << pc) != 0) pc,
  ];
  final results = <_Hypothesis>[];
  for (var root = 0; root < 12; root++) {
    if (pcMask & (1 << root) != 0) continue; // root must be absent
    final intervals = {for (final pc in sounding) (pc - root) % 12};
    final hasMajorThird = intervals.contains(4);
    final hasMinorThird = intervals.contains(3);
    final hasMinorSeventh = intervals.contains(10);
    final hasMajorSeventh = intervals.contains(11);
    if (!(hasMajorThird ^ hasMinorThird)) continue;
    if (!(hasMinorSeventh ^ hasMajorSeventh)) continue;
    final rest = intervals.difference({
      if (hasMajorThird) 4,
      if (hasMinorThird) 3,
      if (hasMinorSeventh) 10,
      if (hasMajorSeventh) 11,
    });
    if (!rest.every(_legalColors.contains)) continue;
    // Diminished fifth with a minor third and minor seventh reads as
    // half-diminished rather than a colored minor seventh.
    final String quality;
    if (hasMinorThird && hasMinorSeventh) {
      quality = intervals.contains(6) && !intervals.contains(7)
          ? 'halfDiminished7'
          : 'minor7';
    } else if (hasMinorThird && hasMajorSeventh) {
      quality = 'minorMajor7';
    } else if (hasMajorThird && hasMinorSeventh) {
      quality = 'dominant7';
    } else {
      quality = 'major7';
    }
    results.add(_Hypothesis(root, quality));
  }
  return results;
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!args[i].startsWith('--') || i + 1 >= args.length) {
      throw ArgumentError('Expected --flag value pairs, got: ${args[i]}');
    }
    options[args[i].substring(2)] = args[i + 1];
  }
  if (!options.containsKey('suite')) {
    throw ArgumentError('Missing required --suite');
  }
  return options;
}
