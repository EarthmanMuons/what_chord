// Offline A/B for the lever 0 m7/6 tie-breaker (log entry 2026-07-20-01).
//
// Arms, evaluated on clean-pool events at the root+quality level:
//   base:   the engine's neutral-context ranking as-is.
//   closed: the lever 0 flip under the key the WhatKey HMM detector has
//           inferred from the event stream so far (claim before the current
//           event; no claim, no flip). The evaluated system: label-isolated.
//   oracle: the same flip under the annotated local key. Diagnostic only.
//
// The flip (scope per the decision in log entry 2026-07-20-01): when
// the chosen candidate is a major6/minor6 and a near-tie candidate holds the
// relative seventh-chord reading (root a minor third below, minor7 for
// major6, halfDiminished7 for minor6), prefer the seventh reading iff its
// root sits on degree ii of the key (minor7 in either mode; halfDiminished7
// in minor) or on the leading tone (halfDiminished7, either mode).
//
// Usage mirrors headroom.dart:
//   dart run tool/chord-context/lever0_eval.dart \
//     --fixtures ... --labels ... --split-file ... --split development \
//     --out build/chord-context/lever0/<name>

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

import '../src/chord_id_engine.dart';
import '../whatkey/src/fixtures.dart';

const _take = 10000;
const _minNotes = 3;

final _analyzer = ChordAnalyzer();

void main(List<String> args) {
  final options = _parseArgs(args);
  final fixtureSet = FixtureSet.load(Directory(options['fixtures']!));
  final labels = jsonDecode(
    File(options['labels']!).readAsStringSync(),
  ) as Map<String, dynamic>;
  final pieces = (labels['pieces'] as Map).cast<String, dynamic>();

  final splitFile = SplitFile.load(File(options['split-file']!));
  splitFile.validateAgainst(fixtureSet);
  final titles = splitFile
      .pieceTitles(options['split'] ?? 'development')
      .toSet();
  final selected = [
    for (final fixture in fixtureSet.fixtures)
      if (titles.contains(fixture.title)) fixture,
  ];

  final neutral = _contextFor(fixtureSet.manifest['context'] as String);
  final perPiece = <Map<String, dynamic>>[];
  var pooledN = 0, pooledBase = 0, pooledClosed = 0, pooledOracle = 0;
  var pooledEngine = 0, parityDisagreements = 0;
  var flips = 0, flipsHelped = 0, flipsHurt = 0, claimed = 0;

  final behavior = KeyBehavior.values.byName(options['behavior'] ?? 'stable');

  for (final fixture in selected) {
    final entries = (pieces[fixture.id] as List).cast<Map>();
    final detector = HmmKeyDetector(decayHalfLife: behavior.emissionHalfLife);
    Tonality? inferred;
    var n = 0, base = 0, closed = 0, oracle = 0, engine = 0;
    for (var i = 0; i < fixture.events.length; i++) {
      final event = fixture.events[i];
      final entry = entries[i].cast<String, dynamic>();
      final inferredBefore = inferred;
      inferred = detector.onEvent(event).claim?.tonality ?? inferred;

      if (entry['category'] != 'ok') continue;
      if (event.input.noteCount < _minNotes) continue;
      final expected = (entry['expected'] as Map).cast<String, dynamic>();
      final expectedQuality = expected['quality'] as String?;
      if (expectedQuality == null) continue;
      final expectedRootPc = expected['rootPc'] as int;

      final ranked = _analyzer.analyze(
        event.input,
        context: neutral,
        voicing: event.voicing,
        take: _take,
      );
      bool matches(ChordIdentity identity) =>
          identity.rootPc == expectedRootPc &&
          identity.quality.name == expectedQuality;

      final baseTop = ranked.first.identity;
      final closedTop = inferredBefore == null
          ? baseTop
          : _lever0Top(ranked, inferredBefore);
      final oracleTop = _lever0Top(
        ranked,
        parseTonality(entry['localKey'] as String),
      );
      // The production path: a full re-rank under the inferred key, so the
      // engine's own tonality-gated rules (including the new twin rule)
      // decide. Compared against the simulated flip for parity.
      final engineTop = inferredBefore == null
          ? baseTop
          : _analyzer
                .analyze(
                  event.input,
                  context: _contextForTonality(inferredBefore),
                  voicing: event.voicing,
                  take: _take,
                )
                .first
                .identity;

      n++;
      if (inferredBefore != null) claimed++;
      final baseRight = matches(baseTop);
      final closedRight = matches(closedTop);
      if (baseRight) base++;
      if (closedRight) closed++;
      if (matches(oracleTop)) oracle++;
      if (matches(engineTop)) engine++;
      if (engineTop != closedTop &&
          !(engineTop.rootPc == closedTop.rootPc &&
              engineTop.quality == closedTop.quality)) {
        parityDisagreements++;
      }
      if (!identical(closedTop, baseTop) && closedTop != baseTop) {
        flips++;
        if (closedRight && !baseRight) flipsHelped++;
        if (!closedRight && baseRight) flipsHurt++;
      }
    }
    if (n == 0) continue;
    perPiece.add({
      'id': fixture.id,
      'n': n,
      'base': base / n,
      'closed': closed / n,
      'oracle': oracle / n,
      'engine': engine / n,
    });
    pooledN += n;
    pooledBase += base;
    pooledClosed += closed;
    pooledOracle += oracle;
    pooledEngine += engine;
  }

  final report = {
    'schema': 'chord-context-lever0/1',
    'set': fixtureSet.name,
    'configuration': {
      'fixtures': options['fixtures'],
      'labels': options['labels'],
      'splitFile': options['split-file'],
      'split': options['split'] ?? 'development',
      'take': _take,
      'minNotes': _minNotes,
      'behavior': behavior.name,
      'detector': HmmKeyDetector(decayHalfLife: behavior.emissionHalfLife)
          .configuration,
      'neutralContext': fixtureSet.manifest['context'],
    },
    'pooled': {
      'n': pooledN,
      'base': pooledBase / pooledN,
      'closed': pooledClosed / pooledN,
      'oracle': pooledOracle / pooledN,
      'engine': pooledEngine / pooledN,
      'parityDisagreements': parityDisagreements,
      'claimCoverage': claimed / pooledN,
      'flips': flips,
      'flipsHelped': flipsHelped,
      'flipsHurt': flipsHurt,
    },
    'perPiece': perPiece,
  };
  final outDir = Directory(options['out']!)..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');

  String pct(num value) => '${(value * 100).toStringAsFixed(2)}%';
  stdout
    ..writeln(
      'lever0 A/B [${behavior.name}]: ${fixtureSet.name} '
      '(${perPiece.length} pieces, n=$pooledN clean events, claim coverage '
      '${pct(claimed / pooledN)})',
    )
    ..writeln('  base:   ${pct(pooledBase / pooledN)}')
    ..writeln(
      '  closed: ${pct(pooledClosed / pooledN)}  '
      '(flips $flips, helped $flipsHelped, hurt $flipsHurt)',
    )
    ..writeln('  oracle: ${pct(pooledOracle / pooledN)}')
    ..writeln(
      '  engine: ${pct(pooledEngine / pooledN)}  '
      '(parity disagreements with closed: $parityDisagreements)',
    );
}

AnalysisContext _contextForTonality(Tonality tonality) {
  final keySignature = KeySignature.fromTonality(tonality);
  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: NoteSpellingPolicy(preferFlats: keySignature.prefersFlats),
  );
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!args[i].startsWith('--') || i + 1 >= args.length) {
      throw ArgumentError('Expected --flag value pairs, got: ${args[i]}');
    }
    options[args[i].substring(2)] = args[i + 1];
  }
  for (final required in ['fixtures', 'labels', 'split-file', 'out']) {
    if (!options.containsKey(required)) {
      throw ArgumentError('Missing required --$required');
    }
  }
  return options;
}

AnalysisContext _contextFor(String wire) {
  final tonality = parseTonality(wire);
  final keySignature = KeySignature.fromTonality(tonality);
  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: NoteSpellingPolicy(preferFlats: keySignature.prefersFlats),
  );
}

/// The effective top identity after the lever 0 flip under [key].
ChordIdentity _lever0Top(List<ChordCandidate> ranked, Tonality key) {
  final chosen = ranked.first.identity;
  final ChordQuality target;
  if (chosen.quality == ChordQuality.major6) {
    target = ChordQuality.minor7;
  } else if (chosen.quality == ChordQuality.minor6) {
    target = ChordQuality.halfDiminished7;
  } else {
    return chosen;
  }
  final seventhRootPc = (chosen.rootPc + 9) % 12;
  final degree = (seventhRootPc - key.tonicPitchClass) % 12;
  final applies = target == ChordQuality.minor7
      ? degree == 2
      : degree == 11 || (degree == 2 && key.isMinor);
  if (!applies) return chosen;
  for (var i = 1; i < ranked.length; i++) {
    final candidate = ranked[i];
    if (!ChordCandidateRanking.isNearTie(ranked.first.cost, candidate.cost)) {
      break;
    }
    if (candidate.identity.rootPc == seventhRootPc &&
        candidate.identity.quality == target) {
      return candidate.identity;
    }
  }
  return chosen;
}
