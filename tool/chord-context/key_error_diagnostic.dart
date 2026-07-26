// Diagnostic: structure of local-key disagreements for the shipped HMM
// detector, to see whether the Track B residual's key-detection error
// (log entry 2026-07-20-17) points at an addressable WhatKey weakness.
//
// IMPORTANT FRAMING. This scores per-event LOCAL-key agreement against the
// annotated local keys. WhatKey is optimized and frozen for SECTION-key
// stability, a different target; local-key tracking is a declared separate
// project (research/whatkey/log/2026-07-08-04). Nothing here is a WhatKey
// result under its protocol; it is a characterization to decide whether such
// a project is worth opening.
//
// For every claimed event whose annotated local key is known, the inferred
// key is bucketed by its relation to the annotation:
//   exact | relative (shared signature) | parallel (same tonic, other mode)
//   | dominant/subdominant (+/- a fifth) | other.
// Mismatches are additionally checked for LAG: does the inferred key match
// the annotated local key of a nearby event (tracking late) rather than
// being unrelated? Abstention (no claim yet) is counted separately.
//
// Usage mirrors the other harnesses (--fixtures/--labels/--split-file/
// --split/--behavior), plus --cadence-boost to characterize the whatkey-local
// cadence-conditioned transition prior (default 0, shipped behavior).

import 'dart:convert';
import 'dart:io';

import 'package:whatkey/whatkey.dart';

import '../src/chord_id_engine.dart';
import '../whatkey/src/fixtures.dart';

const _lagWindow = 4;

void main(List<String> args) {
  final options = _parseArgs(args);
  final fixtureSet = FixtureSet.load(Directory(options['fixtures']!));
  final labels =
      jsonDecode(File(options['labels']!).readAsStringSync())
          as Map<String, dynamic>;
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
  final behavior = KeyBehavior.values.byName(options['behavior'] ?? 'stable');
  final cadenceBoost = double.parse(
    options['cadence-boost'] ?? '${HmmKeyDetector.defaultCadenceBoost}',
  );
  final minEvents = int.parse(
    options['min-events'] ?? '${HmmKeyDetector.defaultMinEvents}',
  );
  final relativeEvidenceTilt = double.parse(
    options['relative-evidence-tilt'] ??
        '${HmmKeyDetector.defaultRelativeEvidenceTilt}',
  );

  final relation = <String, int>{};
  var labeledEvents = 0, abstained = 0, claimed = 0, exact = 0;
  var mismatchLag = 0, mismatch = 0;

  for (final fixture in selected) {
    final entries = (pieces[fixture.id] as List).cast<Map>();
    final events = fixture.events;
    final annotated = <int, ({int tonic, bool minor})>{};
    for (var i = 0; i < events.length; i++) {
      final localKey = (entries[i].cast<String, dynamic>())['localKey'];
      if (localKey is String) {
        final t = parseTonality(localKey);
        annotated[i] = (tonic: t.tonicPitchClass, minor: t.isMinor);
      }
    }

    final detector = HmmKeyDetector(
      decayHalfLife: behavior.emissionHalfLife,
      cadenceBoost: cadenceBoost,
      relativeEvidenceTilt: relativeEvidenceTilt,
      minEvents: minEvents,
    );
    for (var i = 0; i < events.length; i++) {
      final claim = detector.onEvent(events[i]).claim?.tonality;
      final truth = annotated[i];
      if (truth == null) continue;
      labeledEvents++;
      if (claim == null) {
        abstained++;
        continue;
      }
      claimed++;
      final inferred = (tonic: claim.tonicPitchClass, minor: claim.isMinor);
      if (inferred.tonic == truth.tonic && inferred.minor == truth.minor) {
        exact++;
        relation['exact'] = (relation['exact'] ?? 0) + 1;
        continue;
      }
      mismatch++;
      final bucket = _relation(inferred, truth);
      relation[bucket] = (relation[bucket] ?? 0) + 1;
      // Lag: does the claim match any annotated local key within the window?
      var lagged = false;
      for (var j = i - _lagWindow; j <= i + _lagWindow; j++) {
        final near = annotated[j];
        if (near != null &&
            near.tonic == inferred.tonic &&
            near.minor == inferred.minor) {
          lagged = true;
          break;
        }
      }
      if (lagged) mismatchLag++;
    }
  }

  final report = {
    'schema': 'chord-context-key-diagnostic/1',
    'set': fixtureSet.name,
    'behavior': behavior.name,
    'cadenceBoost': cadenceBoost,
    'relativeEvidenceTilt': relativeEvidenceTilt,
    'labeledEvents': labeledEvents,
    'abstained': abstained,
    'claimed': claimed,
    'exactOnClaimed': exact / claimed,
    'coverage': claimed / labeledEvents,
    'relationAmongClaimed': relation,
    'mismatchAttributableToLag': mismatchLag / mismatch,
    'lagWindow': _lagWindow,
  };
  final outDir = Directory(options['out'] ?? 'build/chord-context/key-diag')
    ..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');

  String pct(num a, num b) => '${(a / b * 100).toStringAsFixed(1)}%';
  stdout
    ..writeln('local-key diagnostic [${behavior.name}]: ${fixtureSet.name}')
    ..writeln(
      '  labeled $labeledEvents  coverage ${pct(claimed, labeledEvents)}  '
      'abstained ${pct(abstained, labeledEvents)}',
    )
    ..writeln('  exact-on-claimed ${pct(exact, claimed)}')
    ..writeln('  relation among claimed:');
  final ordered = relation.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  for (final e in ordered) {
    stdout.writeln('    ${e.key}: ${e.value} (${pct(e.value, claimed)})');
  }
  stdout.writeln(
    '  of mismatches, ${pct(mismatchLag, mismatch)} match a local key '
    'within +/-$_lagWindow events (tracking lag, not confusion)',
  );
}

String _relation(
  ({int tonic, bool minor}) inferred,
  ({int tonic, bool minor}) truth,
) {
  final interval = (inferred.tonic - truth.tonic) % 12;
  // Parallel and relative carry a direction tag (which mode was claimed) so
  // the residual's mode asymmetry is visible (whatkey-local log
  // 2026-07-26-04 Next: mine the relative residual for structure).
  if (inferred.tonic == truth.tonic) {
    return inferred.minor
        ? 'parallel (claimed minor, truth major)'
        : 'parallel (claimed major, truth minor)';
  }
  if (inferred.minor != truth.minor) {
    if (!truth.minor && inferred.minor && interval == 9) {
      return 'relative (claimed minor, truth major)';
    }
    if (truth.minor && !inferred.minor && interval == 3) {
      return 'relative (claimed major, truth minor)';
    }
  }
  if (inferred.minor == truth.minor && interval == 7) return 'dominant (+5th)';
  if (inferred.minor == truth.minor && interval == 5) {
    return 'subdominant (-5th)';
  }
  return 'other';
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!args[i].startsWith('--') || i + 1 >= args.length) {
      throw ArgumentError('Expected --flag value pairs, got: ${args[i]}');
    }
    options[args[i].substring(2)] = args[i + 1];
  }
  for (final required in ['fixtures', 'labels', 'split-file']) {
    if (!options.containsKey(required)) {
      throw ArgumentError('Missing required --$required');
    }
  }
  return options;
}
