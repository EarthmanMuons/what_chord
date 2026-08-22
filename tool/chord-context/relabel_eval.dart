// History-relabel measurement (log entry 2026-07-20-13's sketch).
//
// Arms, scored on the clean pool at root+quality:
//   base:      the live path (re-rank under the claim BEFORE each event),
//              what the display showed.
//   retroKey:  relabel each committed event under the claim AFTER it, the
//              half-step of hindsight history has and the display never
//              does (recovers detector warm-up).
//   retroRes:  retroKey plus Rameau's resolution rule: when the chosen
//              reading is a sixth chord and the NEXT event's live root sits
//              a fourth above the twin seventh root (the twin's dominant),
//              flip to the seventh reading. Two scopes: 'policy' respects
//              the m7/6 naming decisions (only the lever 0 cells flip,
//              resolution simply substitutes for key knowledge); 'all'
//              flips on resolution evidence alone, surfacing how often it
//              would override the decided lead-sheet cells (reported, so
//              the product question is sized by data).
//
// Value path (b): a second detector consumes the relabeled stream (recorded
// candidates reordered so the relabeled identity leads) and its key claims
// are scored against the annotated local keys, versus the original stream.
//
// Usage mirrors lever0_eval.dart.

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

  final behavior = KeyBehavior.values.byName(options['behavior'] ?? 'stable');
  final neutral = _contextFor(fixtureSet.manifest['context'] as String);

  const arms = ['base', 'retroKey', 'retroResPolicy', 'retroResAll'];
  final perPiece = <Map<String, dynamic>>[];
  var pooledN = 0;
  final pooled = {for (final arm in arms) arm: 0};
  var resolutionFlips = 0, policyOverrides = 0;
  var keyEventsOriginal = 0, keyExactOriginal = 0;
  var keyEventsRelabeled = 0, keyExactRelabeled = 0;
  final overrideCells = <String, int>{};
  final overrideCorrect = <String, int>{};

  for (final fixture in selected) {
    final entries = (pieces[fixture.id] as List).cast<Map>();
    final events = fixture.events;

    // Pass 1: original stream. Record claim before and after each event.
    final detector = HmmKeyDetector(decayHalfLife: behavior.emissionHalfLife);
    final claimBefore = List<Tonality?>.filled(events.length, null);
    final claimAfter = List<Tonality?>.filled(events.length, null);
    Tonality? running;
    for (var i = 0; i < events.length; i++) {
      claimBefore[i] = running;
      running = detector.onEvent(events[i]).claim?.tonality ?? running;
      claimAfter[i] = running;
    }

    // Live tops for every event (context for the resolution rule's "next").
    final liveTop = <ChordIdentity>[];
    for (var i = 0; i < events.length; i++) {
      liveTop.add(_rank(events[i], claimBefore[i], neutral).first.identity);
    }

    var n = 0;
    final correct = {for (final arm in arms) arm: 0};
    final relabeledEvents = <ChordEvent>[];
    for (var i = 0; i < events.length; i++) {
      final event = events[i];
      final entry = entries[i].cast<String, dynamic>();

      final retroRanked = _rank(event, claimAfter[i], neutral);
      final nextRoot = i + 1 < events.length ? liveTop[i + 1].rootPc : null;
      final policyTop = _retroResolve(
        retroRanked,
        claimAfter[i],
        nextRoot,
        policyOnly: true,
      );
      final allTop = _retroResolve(
        retroRanked,
        claimAfter[i],
        nextRoot,
        policyOnly: false,
      );
      // The path-(b) stream carries the strongest relabeling (all-scope
      // resolution): the whole question is whether corrected identities
      // help detection, so the arm that actually flips must be the one
      // detectors consume.
      relabeledEvents.add(_withLeadingIdentity(event, allTop));

      if (event.input.noteCount < _minNotes) continue;
      if (entry['category'] != 'ok') continue;
      final expected = (entry['expected'] as Map).cast<String, dynamic>();
      final expectedQuality = expected['quality'] as String?;
      if (expectedQuality == null) continue;
      final expectedRootPc = expected['rootPc'] as int;
      bool matches(ChordIdentity identity) =>
          identity.rootPc == expectedRootPc &&
          identity.quality.name == expectedQuality;

      if (allTop != policyTop) {
        policyOverrides++;
        // Characterize each override: applied figures are cells a local-key
        // rule cannot reach (analyst and lead-sheet reading agree there),
        // while plain figures in the non-policy cells are the readings the
        // m7/6 decision deliberately kept as sixth chords.
        final figure = (entry['figure'] as String?) ?? '';
        final key = claimAfter[i];
        final degree = key == null
            ? -1
            : (allTop.rootPc - key.tonicPitchClass) % 12;
        final bucket = figure.contains('/') ? 'applied' : 'plain';
        final mode = key == null ? 'none' : (key.isMinor ? 'min' : 'maj');
        final label = '$bucket/$mode/deg$degree/${allTop.quality.name}';
        overrideCells[label] = (overrideCells[label] ?? 0) + 1;
        if (matches(allTop)) {
          overrideCorrect[label] = (overrideCorrect[label] ?? 0) + 1;
        }
      }
      if (policyTop != retroRanked.first.identity &&
          policyTop.quality != retroRanked.first.identity.quality) {
        resolutionFlips++;
      }

      n++;
      if (matches(liveTop[i])) correct['base'] = correct['base']! + 1;
      if (matches(retroRanked.first.identity)) {
        correct['retroKey'] = correct['retroKey']! + 1;
      }
      if (matches(policyTop)) {
        correct['retroResPolicy'] = correct['retroResPolicy']! + 1;
      }
      if (matches(allTop)) correct['retroResAll'] = correct['retroResAll']! + 1;
    }

    // Pass 2 (path b): a fresh detector consumes the relabeled stream.
    final detectorB = HmmKeyDetector(decayHalfLife: behavior.emissionHalfLife);
    Tonality? runningB;
    for (var i = 0; i < events.length; i++) {
      final beforeB = runningB;
      runningB =
          detectorB.onEvent(relabeledEvents[i]).claim?.tonality ?? runningB;
      final localKey = entries[i]['localKey'] as String?;
      if (localKey == null) continue;
      final annotated = parseTonality(localKey);
      if (claimBefore[i] != null) {
        keyEventsOriginal++;
        if (claimBefore[i]!.tonicPitchClass == annotated.tonicPitchClass &&
            claimBefore[i]!.isMinor == annotated.isMinor) {
          keyExactOriginal++;
        }
      }
      if (beforeB != null) {
        keyEventsRelabeled++;
        if (beforeB.tonicPitchClass == annotated.tonicPitchClass &&
            beforeB.isMinor == annotated.isMinor) {
          keyExactRelabeled++;
        }
      }
    }

    if (n == 0) continue;
    perPiece.add({
      'id': fixture.id,
      'n': n,
      for (final arm in arms) arm: correct[arm]! / n,
    });
    pooledN += n;
    for (final arm in arms) {
      pooled[arm] = pooled[arm]! + correct[arm]!;
    }
  }

  final report = {
    'schema': 'chord-context-relabel/1',
    'set': fixtureSet.name,
    'configuration': {
      'fixtures': options['fixtures'],
      'labels': options['labels'],
      'splitFile': options['split-file'],
      'split': options['split'] ?? 'development',
      'take': _take,
      'minNotes': _minNotes,
      'behavior': behavior.name,
    },
    'pooled': {
      'n': pooledN,
      for (final arm in arms) arm: pooled[arm]! / pooledN,
      'resolutionFlips': resolutionFlips,
      'policyOverrides': policyOverrides,
      'overrideCells': overrideCells,
      'overrideCorrect': overrideCorrect,
      'keyExactOriginal': keyEventsOriginal == 0
          ? null
          : keyExactOriginal / keyEventsOriginal,
      'keyExactRelabeled': keyEventsRelabeled == 0
          ? null
          : keyExactRelabeled / keyEventsRelabeled,
    },
    'perPiece': perPiece,
  };
  final outDir = Directory(options['out']!)..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');

  String pct(num value) => '${(value * 100).toStringAsFixed(2)}%';
  stdout.writeln(
    'relabel [${behavior.name}]: ${fixtureSet.name} '
    '(${perPiece.length} pieces, n=$pooledN clean events)',
  );
  for (final arm in arms) {
    stdout.writeln('  $arm: ${pct(pooled[arm]! / pooledN)}');
  }
  stdout
    ..writeln(
      '  resolution flips: $resolutionFlips  '
      'policy-cell overrides by all-scope: $policyOverrides',
    )
    ..writeln(
      '  key exact (claim-before vs annotated): original '
      '${pct(keyExactOriginal / keyEventsOriginal)}  relabeled-stream '
      '${pct(keyExactRelabeled / keyEventsRelabeled)}',
    );
  final cells = overrideCells.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  stdout.writeln('  override cells (bucket/mode/degree/quality):');
  for (final cell in cells.take(12)) {
    final right = overrideCorrect[cell.key] ?? 0;
    stdout.writeln('    ${cell.key}: ${cell.value} (correct $right)');
  }
}

List<ChordCandidate> _rank(
  ChordEvent event,
  Tonality? tonality,
  AnalysisContext neutral,
) {
  return _analyzer.analyze(
    event.input,
    context: tonality == null ? neutral : _contextForTonality(tonality),
    voicing: event.voicing,
    take: _take,
  );
}

/// The retro-resolution arm's identity: the retroKey top, twin-flipped when
/// the next live root confirms the resolution (a fourth above the twin
/// seventh root). In policy scope the flip also requires the lever 0 key
/// conditions to hold under [key]; in all scope resolution evidence alone
/// suffices.
ChordIdentity _retroResolve(
  List<ChordCandidate> ranked,
  Tonality? key,
  int? nextRoot, {
  required bool policyOnly,
}) {
  final chosen = ranked.first.identity;
  final ChordQuality twin;
  if (chosen.quality == ChordQuality.major6) {
    twin = ChordQuality.minor7;
  } else if (chosen.quality == ChordQuality.minor6) {
    twin = ChordQuality.halfDiminished7;
  } else {
    return chosen;
  }
  final seventhRootPc = (chosen.rootPc + 9) % 12;
  if (nextRoot == null || nextRoot != (seventhRootPc + 5) % 12) return chosen;
  if (policyOnly) {
    if (key == null) return chosen;
    final degree = (seventhRootPc - key.tonicPitchClass) % 12;
    final applies = twin == ChordQuality.minor7
        ? degree == 2
        : degree == 11 || (degree == 2 && key.isMinor);
    if (!applies) return chosen;
  }
  for (var i = 1; i < ranked.length; i++) {
    final candidate = ranked[i];
    if (!ChordCandidateRanking.isNearTie(ranked.first.cost, candidate.cost)) {
      break;
    }
    if (candidate.identity.rootPc == seventhRootPc &&
        candidate.identity.quality == twin) {
      return candidate.identity;
    }
  }
  return chosen;
}

/// Rebuilds a committed event with [identity] leading its recorded candidate
/// list (for the relabeled stream detectors consume). If the identity is not
/// among the recorded candidates the event is returned unchanged.
ChordEvent _withLeadingIdentity(ChordEvent event, ChordIdentity identity) {
  final index = event.candidates.indexWhere(
    (candidate) =>
        candidate.identity.rootPc == identity.rootPc &&
        candidate.identity.quality == identity.quality,
  );
  if (index <= 0) return event;
  final reordered = [
    event.candidates[index],
    for (var i = 0; i < event.candidates.length; i++)
      if (i != index) event.candidates[i],
  ];
  return ChordEvent(
    timestamp: event.timestamp,
    input: event.input,
    voicing: event.voicing,
    candidates: reordered,
    tonality: event.tonality,
    duration: event.duration,
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
