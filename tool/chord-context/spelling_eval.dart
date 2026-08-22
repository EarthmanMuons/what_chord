// Track B spelling headroom (design doc Track B; log entry 2026-07-20-06).
//
// Compares the engine's member spelling against the score's actual spelling
// (DCML note-table tpc, line of fifths with 0 = C), per event, under three
// contexts: the set's neutral context, the closed-loop inferred key (the
// production path), and the annotated local key (oracle diagnostic).
//
// Spelling is scored only on events whose identity the arm got right at
// root+quality (so spelling errors are not confounded by wrong identities),
// and only for pitch classes the score spells one way within the span
// (conflicting spellings are counted and skipped). Each pitch class is
// spelled the way the app's display path spells it: the root via
// spellChordRoot, role-classified tones via spellPitchClass, unexplained
// tones via noteNameForPitchClass.
//
// Usage mirrors cue_eval.dart (--fixtures/--labels/--split-file/--split/
// --behavior/--out).

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

import '../src/chord_id_engine.dart';
import '../whatkey/src/fixtures.dart';

const _take = 10000;
const _minNotes = 3;
const _arms = [
  'neutral',
  'inferred',
  'sideChosen',
  // Oracle diagnostic: the inferred key's pitch class and mode, but the
  // annotated key's enharmonic side whenever they agree on pc+mode. The gap
  // from `inferred` to here is exactly what perfect side-following could
  // win; the gap from here to `annotated` is key-detection error, not
  // spelling.
  'inferredRightSide',
  'annotated',
];
const _defaultAlpha = 0.15;

final _analyzer = ChordAnalyzer();

const _letterTpc = {'F': -1, 'C': 0, 'G': 1, 'D': 2, 'A': 3, 'E': 4, 'B': 5};

int? _nameToTpc(String name) {
  if (name.isEmpty) return null;
  final normalized = name
      .replaceAll('♭', 'b')
      .replaceAll('♯', '#')
      .replaceAll('\u{1D12B}', 'bb')
      .replaceAll('\u{1D12A}', '##');
  var tpc = _letterTpc[normalized[0].toUpperCase()];
  if (tpc == null) return null;
  for (final accidental in normalized.substring(1).split('')) {
    if (accidental == '#') {
      tpc = tpc! + 7;
    } else if (accidental == 'b') {
      tpc = tpc! - 7;
    } else {
      return null;
    }
  }
  return tpc;
}

String _tpcToName(int tpc) {
  final letter = 'FCGDAEB'[(tpc + 1) % 7];
  // Floor division: Dart's ~/ truncates toward zero, wrong for flat-side tpc.
  final accidentals = ((tpc + 1) - ((tpc + 1) % 7)) ~/ 7;
  return letter + (accidentals > 0 ? '#' * accidentals : 'b' * -accidentals);
}

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
  final alpha = double.parse(options['alpha'] ?? '$_defaultAlpha');
  final inertia = options['inertia'] == 'true';
  final staticSides = options['static-sides'] == 'true';
  final sides = _tonalitySides();

  final perPiece = <Map<String, dynamic>>[];
  final pooled = {
    for (final arm in _arms)
      arm: {
        'identityCorrect': 0,
        'tones': 0,
        'tonesCorrect': 0,
        'roots': 0,
        'rootsCorrect': 0,
        'eventsAllCorrect': 0,
      },
  };
  var pooledN = 0, conflictedPcs = 0, unmappedNames = 0;
  final confusions = {for (final arm in _arms) arm: <String, int>{}};
  final errorPaths = {for (final arm in _arms) arm: <String, int>{}};
  // Tone tallies split by key-episode type (cold-start vs modulation-
  // reached), sizing the two halves of the side-chooser decomposition.
  final groupTallies = {
    for (final group in ['cold', 'mod'])
      group: {
        for (final arm in _arms) arm: {'tones': 0, 'correct': 0},
      },
  };

  for (final fixture in selected) {
    final entries = (pieces[fixture.id] as List).cast<Map>();
    final detector = HmmKeyDetector(decayHalfLife: behavior.emissionHalfLife);
    Tonality? inferred;
    // Running line-of-fifths center of this piece's own spellings, the
    // causal window that chooses the enharmonic side of ambiguous keys.
    var fifthsCenter = 0.0;
    Tonality? heldSide;
    final sideMemory = <(int, bool), Tonality>{};
    var episodeIndex = -1;
    var episodeType = 'none';
    var n = 0;
    final pieceTones = {for (final arm in _arms) arm: 0};
    final pieceTonesCorrect = {for (final arm in _arms) arm: 0};

    for (var i = 0; i < fixture.events.length; i++) {
      final event = fixture.events[i];
      final entry = entries[i].cast<String, dynamic>();
      final inferredBefore = inferred;
      inferred = detector.onEvent(event).claim?.tonality ?? inferred;
      if (event.input.noteCount < _minNotes) continue;

      // The side-chosen tonality for this event: decided once per key
      // episode (when the claimed pc/mode changes) and held while the claim
      // persists. The piece's first episode is a cold start, where a
      // pitch-class stream carries no side information, so the
      // conventional-practice prior decides; later (modulation-reached)
      // episodes use the running line-of-fifths center of the arm's own
      // spellings, which updates causally on every event.
      final Tonality sideTonality;
      if (inferredBefore == null) {
        sideTonality = neutral.tonality;
        episodeType = 'none';
      } else if (heldSide != null &&
          heldSide.tonicPitchClass == inferredBefore.tonicPitchClass &&
          heldSide.isMinor == inferredBefore.isMinor) {
        sideTonality = heldSide;
      } else {
        episodeIndex++;
        episodeType = episodeIndex == 0 ? 'cold' : 'mod';
        // Spelling inertia (--inertia true; rejected in log entry
        // 2026-07-20-08, kept for reproducibility): a key already spelled
        // in this piece keeps its side on re-arrival. The mechanism of
        // record re-decides every episode: cold start by the conventional
        // prior, later episodes by the window.
        final memoryKey = (
          inferredBefore.tonicPitchClass,
          inferredBefore.isMinor,
        );
        sideTonality =
            (inertia ? sideMemory[memoryKey] : null) ??
            (staticSides || episodeIndex == 0
                ? _conventionalSide(sides, inferredBefore)
                : _chooseSide(sides, inferredBefore, fifthsCenter));
        if (inertia) sideMemory[memoryKey] = sideTonality;
        heldSide = sideTonality;
      }
      fifthsCenter = _updateCenter(
        fifthsCenter,
        alpha,
        event.input.pcMask,
        sideTonality,
      );

      if (entry['category'] != 'ok') continue;
      final expected = (entry['expected'] as Map).cast<String, dynamic>();
      final expectedQuality = expected['quality'] as String?;
      if (expectedQuality == null) continue;
      final expectedRootPc = expected['rootPc'] as int;
      final spelling = (entry['spelling'] as Map? ?? const {})
          .cast<String, dynamic>();
      if (spelling.isEmpty) continue;

      n++;
      pooledN++;
      for (final arm in _arms) {
        final annotatedTonality = parseTonality(entry['localKey'] as String);
        final tonality = switch (arm) {
          'neutral' => neutral.tonality,
          'inferred' => inferredBefore ?? neutral.tonality,
          'sideChosen' => sideTonality,
          'inferredRightSide' => _withAnnotatedSide(
            inferredBefore ?? neutral.tonality,
            annotatedTonality,
          ),
          _ => annotatedTonality,
        };
        final ranked = _analyzer.analyze(
          event.input,
          context: _contextForTonality(tonality),
          voicing: event.voicing,
          take: _take,
        );
        final identity = ranked.first.identity;
        if (identity.rootPc != expectedRootPc ||
            identity.quality.name != expectedQuality) {
          continue;
        }
        final tallies = pooled[arm]!;
        tallies['identityCorrect'] = tallies['identityCorrect']! + 1;

        final rootName = spellChordRoot(identity, tonality: tonality);
        var allCorrect = true;
        var scoredAny = false;
        for (var pc = 0; pc < 12; pc++) {
          if (event.input.pcMask & (1 << pc) == 0) continue;
          final truth = (spelling['$pc'] as List?)?.cast<int>();
          if (truth == null) continue;
          if (truth.length != 1) {
            conflictedPcs++;
            continue;
          }
          final interval = (pc - identity.rootPc) % 12;
          final role = identity.toneRolesByInterval[interval];
          final path = pc == identity.rootPc
              ? 'root'
              : role != null
              ? 'role'
              : 'fallback';
          final name = switch (path) {
            'root' => rootName,
            'role' => spellPitchClass(
              pc,
              tonality: tonality,
              chordRootName: rootName,
              role: role,
            ),
            _ => noteNameForPitchClass(pc, tonality: tonality),
          };
          final got = _nameToTpc(name);
          if (got == null) {
            unmappedNames++;
            continue;
          }
          scoredAny = true;
          tallies['tones'] = tallies['tones']! + 1;
          pieceTones[arm] = pieceTones[arm]! + 1;
          final correct = got == truth.single;
          if (episodeType != 'none') {
            final group = groupTallies[episodeType]![arm]!;
            group['tones'] = group['tones']! + 1;
            if (correct) group['correct'] = group['correct']! + 1;
          }
          if (correct) {
            tallies['tonesCorrect'] = tallies['tonesCorrect']! + 1;
            pieceTonesCorrect[arm] = pieceTonesCorrect[arm]! + 1;
          } else {
            allCorrect = false;
            final key = '${_tpcToName(got)}->${_tpcToName(truth.single)}';
            confusions[arm]![key] = (confusions[arm]![key] ?? 0) + 1;
            // Which speller produced the error, and whether the tone is
            // diatonic in the ranking key: chromatic non-chord tones are
            // the line-rule target, diatonic chord tones are not.
            final diatonic = tonality.containsPitchClass(pc)
                ? 'diatonic'
                : 'chromatic';
            final bucket = '$path/$diatonic';
            errorPaths[arm]![bucket] = (errorPaths[arm]![bucket] ?? 0) + 1;
          }
          if (pc == identity.rootPc) {
            tallies['roots'] = tallies['roots']! + 1;
            if (correct) {
              tallies['rootsCorrect'] = tallies['rootsCorrect']! + 1;
            }
          }
        }
        if (scoredAny && allCorrect) {
          tallies['eventsAllCorrect'] = tallies['eventsAllCorrect']! + 1;
        }
      }
    }
    if (n == 0) continue;
    perPiece.add({
      'id': fixture.id,
      'n': n,
      for (final arm in _arms)
        arm: pieceTones[arm]! == 0
            ? null
            : pieceTonesCorrect[arm]! / pieceTones[arm]!,
    });
  }

  final report = {
    'schema': 'chord-context-spelling/1',
    'set': fixtureSet.name,
    'configuration': {
      'fixtures': options['fixtures'],
      'labels': options['labels'],
      'splitFile': options['split-file'],
      'split': options['split'] ?? 'development',
      'take': _take,
      'minNotes': _minNotes,
      'behavior': behavior.name,
      'alpha': alpha,
      'inertia': inertia,
    },
    'pooled': {
      'n': pooledN,
      'conflictedPcs': conflictedPcs,
      'unmappedNames': unmappedNames,
      for (final arm in _arms) arm: pooled[arm],
    },
    'episodeGroups': groupTallies,
    'errorPaths': errorPaths,
    'confusions': {
      for (final arm in _arms)
        arm: Map.fromEntries(
          (confusions[arm]!.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .take(20),
        ),
    },
    'perPiece': perPiece,
  };
  final outDir = Directory(options['out']!)..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');

  String pct(int a, int b) =>
      b == 0 ? 'n/a' : '${(a / b * 100).toStringAsFixed(2)}%';
  stdout.writeln(
    'spelling headroom [${behavior.name}]: ${fixtureSet.name} '
    '(${perPiece.length} pieces, n=$pooledN scoreable events, '
    '$conflictedPcs conflicted pcs skipped)',
  );
  for (final arm in _arms) {
    final tallies = pooled[arm]!;
    stdout.writeln(
      '  $arm: identity ${pct(tallies['identityCorrect']!, pooledN)}  '
      'tones ${pct(tallies['tonesCorrect']!, tallies['tones']!)}  '
      'roots ${pct(tallies['rootsCorrect']!, tallies['roots']!)}  '
      'events-all-correct '
      '${pct(tallies['eventsAllCorrect']!, tallies['identityCorrect']!)}',
    );
    final top = confusions[arm]!.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (top.isNotEmpty) {
      stdout.writeln(
        '    top confusions: '
        '${top.take(6).map((e) => '${e.key} x${e.value}').join(', ')}',
      );
    }
  }
  for (final group in ['cold', 'mod']) {
    final byArm = groupTallies[group]!;
    stdout.writeln(
      '  episodes[$group]: '
      '${_arms.map((arm) {
        final tallies = byArm[arm]!;
        return '$arm ${pct(tallies['correct']!, tallies['tones']!)}';
      }).join('  ')} '
      '(n=${byArm['inferred']!['tones']})',
    );
  }
}

/// [inferred] with its enharmonic side replaced by [annotated]'s when the two
/// agree on tonic pitch class and mode; otherwise [inferred] unchanged. The
/// oracle for perfect side-following.
Tonality _withAnnotatedSide(Tonality inferred, Tonality annotated) {
  if (inferred.tonicPitchClass != annotated.tonicPitchClass) return inferred;
  if (inferred.isMinor != annotated.isMinor) return inferred;
  return annotated;
}

/// Supported tonalities grouped by (tonic pc, mode), from the 15 key
/// signatures; ambiguous entries are the enharmonic pairs (F#/Gb, C#/Db,
/// B/Cb major; G#/Ab, D#/Eb, A#/Bb minor).
Map<(int, bool), List<Tonality>> _tonalitySides() {
  final sides = <(int, bool), List<Tonality>>{};
  for (final signature in keySignatures) {
    for (final tonality in [signature.relativeMajor, signature.relativeMinor]) {
      final key = (tonality.tonicPitchClass, tonality.isMinor);
      final list = sides.putIfAbsent(key, () => []);
      if (!list.contains(tonality)) list.add(tonality);
    }
  }
  return sides;
}

double _diatonicCenterTpc(Tonality tonality) {
  final tonicTpc = _nameToTpc(tonality.tonic.label)!;
  // Major diatonic set spans tonic-1..tonic+5 in fifths; natural minor
  // spans tonic-4..tonic+2.
  return tonicTpc + (tonality.isMinor ? -1.0 : 2.0);
}

/// The cold-start side table used in log entries 2026-07-20-08/-09, kept for
/// reproducibility. The non-tie cells are uncontested (fewer accidentals
/// wins) and match the shipped KeySpace sides; the six-accidental tie cells
/// are contested bets (see entry -09: the F# major cell measured well on the
/// classical corpus only because that repertoire skews F# four to one, and
/// the relabel it briefly motivated was reversed).
const _conventionalTonics = {
  (1, false): 'Db',
  (6, false): 'F#',
  (11, false): 'B',
  (3, true): 'Eb',
  (8, true): 'G#',
  (10, true): 'Bb',
};

Tonality _conventionalSide(
  Map<(int, bool), List<Tonality>> sides,
  Tonality claim,
) {
  final candidates = sides[(claim.tonicPitchClass, claim.isMinor)];
  if (candidates == null || candidates.isEmpty) return claim;
  if (candidates.length == 1) return candidates.single;
  final tonic = _conventionalTonics[(claim.tonicPitchClass, claim.isMinor)];
  return candidates.firstWhere(
    (candidate) => candidate.tonic.label == tonic,
    orElse: () => candidates.first,
  );
}

Tonality _chooseSide(
  Map<(int, bool), List<Tonality>> sides,
  Tonality claim,
  double fifthsCenter,
) {
  final candidates = sides[(claim.tonicPitchClass, claim.isMinor)];
  if (candidates == null || candidates.isEmpty) return claim;
  Tonality best = candidates.first;
  var bestDistance = double.infinity;
  for (final candidate in candidates) {
    final distance = (_diatonicCenterTpc(candidate) - fifthsCenter).abs();
    if (distance < bestDistance) {
      bestDistance = distance;
      best = candidate;
    }
  }
  return best;
}

double _updateCenter(
  double center,
  double alpha,
  int pcMask,
  Tonality tonality,
) {
  var sum = 0.0;
  var count = 0;
  for (var pc = 0; pc < 12; pc++) {
    if (pcMask & (1 << pc) == 0) continue;
    final tpc = _nameToTpc(noteNameForPitchClass(pc, tonality: tonality));
    if (tpc == null) continue;
    sum += tpc;
    count++;
  }
  if (count == 0) return center;
  return (1 - alpha) * center + alpha * (sum / count);
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
