// Track A temporal-cue ablation for the chord-context initiative
// (design doc Phase 2; baseline is the shipped engine after lever 0).
//
// The baseline arm re-ranks each event under the closed-loop inferred key
// (label-isolated, exactly like lever0_eval's engine arm). Each cue is an
// independent arm that may re-prefer a near-tie candidate using one causal
// signal: the previous event's displayed identity (the baseline top of the
// prior event with three or more sounding notes). Cues, scored on the clean
// pool at root+quality:
//
//   appliedTonicization: after a dominant7 on X, run the m7/6 twin flip
//     against the transient tonic a fourth above X, catching applied
//     predominants the local-key rule cannot see.
//   postDominant: after a dominant7 on X, prefer a near-tie candidate rooted
//     a fourth above X (the resolution target).
//   dominantExpectation: after a predominant in the inferred key (seventh
//     chord on degree ii or triad family on degree IV/iv), prefer a near-tie
//     dominant7 rooted on degree V.
//   rootContinuity: prefer a near-tie candidate that keeps the previous
//     root (display hysteresis as a naming cue).
//
// Usage mirrors lever0_eval.dart (--fixtures/--labels/--split-file/--split/
// --behavior/--out).

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

import '../src/chord_id_engine.dart';
import '../whatkey/src/fixtures.dart';

const _take = 10000;
const _minNotes = 3;

const _cues = [
  'appliedTonicization',
  'postDominant',
  'dominantExpectation',
  'rootContinuity',
];

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

  final behavior = KeyBehavior.values.byName(options['behavior'] ?? 'stable');
  final perPiece = <Map<String, dynamic>>[];
  var pooledN = 0, pooledBase = 0;
  final pooledCue = {for (final cue in _cues) cue: 0};
  final flips = {for (final cue in _cues) cue: 0};
  final helped = {for (final cue in _cues) cue: 0};
  final hurt = {for (final cue in _cues) cue: 0};

  for (final fixture in selected) {
    final entries = (pieces[fixture.id] as List).cast<Map>();
    final detector = HmmKeyDetector(decayHalfLife: behavior.emissionHalfLife);
    Tonality? inferred;
    ChordIdentity? previousTop;
    var n = 0, base = 0;
    final cueCorrect = {for (final cue in _cues) cue: 0};

    for (var i = 0; i < fixture.events.length; i++) {
      final event = fixture.events[i];
      final entry = entries[i].cast<String, dynamic>();
      final inferredBefore = inferred;
      inferred = detector.onEvent(event).claim?.tonality ?? inferred;
      if (event.input.noteCount < _minNotes) continue;

      final ranked = _analyzer.analyze(
        event.input,
        context: inferredBefore == null
            ? _contextFor(fixtureSet.manifest['context'] as String)
            : _contextForTonality(inferredBefore),
        voicing: event.voicing,
        take: _take,
      );
      final baseTop = ranked.first.identity;
      final context = previousTop;
      previousTop = baseTop;

      if (entry['category'] != 'ok') continue;
      final expected = (entry['expected'] as Map).cast<String, dynamic>();
      final expectedQuality = expected['quality'] as String?;
      if (expectedQuality == null) continue;
      final expectedRootPc = expected['rootPc'] as int;
      bool matches(ChordIdentity identity) =>
          identity.rootPc == expectedRootPc &&
          identity.quality.name == expectedQuality;

      n++;
      final baseRight = matches(baseTop);
      if (baseRight) base++;
      for (final cue in _cues) {
        final cueTop = _applyCue(cue, ranked, context, inferredBefore);
        final cueRight = matches(cueTop);
        if (cueRight) cueCorrect[cue] = cueCorrect[cue]! + 1;
        if (!identical(cueTop, baseTop)) {
          flips[cue] = flips[cue]! + 1;
          if (cueRight && !baseRight) helped[cue] = helped[cue]! + 1;
          if (!cueRight && baseRight) hurt[cue] = hurt[cue]! + 1;
        }
      }
    }
    if (n == 0) continue;
    perPiece.add({
      'id': fixture.id,
      'n': n,
      'base': base / n,
      for (final cue in _cues) cue: cueCorrect[cue]! / n,
    });
    pooledN += n;
    pooledBase += base;
    for (final cue in _cues) {
      pooledCue[cue] = pooledCue[cue]! + cueCorrect[cue]!;
    }
  }

  final report = {
    'schema': 'chord-context-cues/1',
    'set': fixtureSet.name,
    'configuration': {
      'fixtures': options['fixtures'],
      'labels': options['labels'],
      'splitFile': options['split-file'],
      'split': options['split'] ?? 'development',
      'take': _take,
      'minNotes': _minNotes,
      'behavior': behavior.name,
      'cues': _cues,
    },
    'pooled': {
      'n': pooledN,
      'base': pooledBase / pooledN,
      'claimCoverage': null,
      for (final cue in _cues) cue: pooledCue[cue]! / pooledN,
      'flips': flips,
      'helped': helped,
      'hurt': hurt,
    },
    'perPiece': perPiece,
  };
  final outDir = Directory(options['out']!)..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');

  String pct(num value) => '${(value * 100).toStringAsFixed(2)}%';
  stdout.writeln(
    'cue ablation [${behavior.name}]: ${fixtureSet.name} '
    '(${perPiece.length} pieces, n=$pooledN clean events)',
  );
  stdout.writeln('  base:   ${pct(pooledBase / pooledN)}');
  for (final cue in _cues) {
    stdout.writeln(
      '  $cue: ${pct(pooledCue[cue]! / pooledN)}  '
      '(flips ${flips[cue]}, helped ${helped[cue]}, hurt ${hurt[cue]})',
    );
  }
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

AnalysisContext _contextFor(String wire) =>
    _contextForTonality(parseTonality(wire));

AnalysisContext _contextForTonality(Tonality tonality) {
  final keySignature = KeySignature.fromTonality(tonality);
  return AnalysisContext(
    tonality: tonality,
    keySignature: keySignature,
    spellingPolicy: NoteSpellingPolicy(preferFlats: keySignature.prefersFlats),
  );
}

ChordIdentity _applyCue(
  String cue,
  List<ChordCandidate> ranked,
  ChordIdentity? previous,
  Tonality? key,
) {
  final chosen = ranked.first.identity;
  if (previous == null) return chosen;
  switch (cue) {
    case 'appliedTonicization':
      if (previous.quality != ChordQuality.dominant7) return chosen;
      final transientTonicPc = (previous.rootPc + 5) % 12;
      return _twinFlip(ranked, transientTonicPc);
    case 'postDominant':
      if (previous.quality != ChordQuality.dominant7) return chosen;
      final target = (previous.rootPc + 5) % 12;
      if (chosen.rootPc == target) return chosen;
      return _nearTieWithRoot(ranked, target) ?? chosen;
    case 'dominantExpectation':
      if (key == null) return chosen;
      final tonic = key.tonicPitchClass;
      final previousDegree = (previous.rootPc - tonic) % 12;
      final isPredominant =
          (previousDegree == 2 &&
              (previous.quality == ChordQuality.minor7 ||
                  previous.quality == ChordQuality.halfDiminished7 ||
                  previous.quality == ChordQuality.minor)) ||
          (previousDegree == 5 &&
              (previous.quality == ChordQuality.major ||
                  previous.quality == ChordQuality.minor));
      if (!isPredominant) return chosen;
      final target = (tonic + 7) % 12;
      if (chosen.rootPc == target) return chosen;
      for (var i = 1; i < ranked.length; i++) {
        final candidate = ranked[i];
        if (!ChordCandidateRanking.isNearTie(
          ranked.first.cost,
          candidate.cost,
        )) {
          break;
        }
        if (candidate.identity.rootPc == target &&
            candidate.identity.quality == ChordQuality.dominant7) {
          return candidate.identity;
        }
      }
      return chosen;
    case 'rootContinuity':
      if (chosen.rootPc == previous.rootPc) return chosen;
      return _nearTieWithRoot(ranked, previous.rootPc) ?? chosen;
  }
  return chosen;
}

/// The lever 0 m7/6 twin flip evaluated against an arbitrary tonic pc,
/// mode-agnostic (both half-diminished cells accepted), for transient
/// tonicization contexts.
ChordIdentity _twinFlip(List<ChordCandidate> ranked, int tonicPc) {
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
  final degree = (seventhRootPc - tonicPc) % 12;
  final applies = target == ChordQuality.minor7
      ? degree == 2
      : degree == 11 || degree == 2;
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

ChordIdentity? _nearTieWithRoot(List<ChordCandidate> ranked, int rootPc) {
  for (var i = 1; i < ranked.length; i++) {
    final candidate = ranked[i];
    if (!ChordCandidateRanking.isNearTie(ranked.first.cost, candidate.cost)) {
      break;
    }
    if (candidate.identity.rootPc == rootPc) return candidate.identity;
  }
  return null;
}
