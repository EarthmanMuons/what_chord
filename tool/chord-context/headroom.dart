// Phase 0 headroom harness for the chord-context initiative
// (research/chord-context/temporal-context-chord-recognition.md).
//
// For every labeled fixture event, re-analyzes the sounding notes at full
// depth under two contexts (the set's neutral context and the annotated local
// key) and buckets where the expected identity landed: chosen, within the
// near-tie window, within the ranking prune margin, generated at all, or
// absent. The near-tie bucket is the addressable market for contextual
// re-ranking as a tie-breaker; the prune bucket is the market for capped-rule
// promotion; absences are candidate-generation territory.
//
// Usage:
//   dart run tool/chord-context/headroom.dart \
//     --fixtures research/whatkey/data/fixtures/when-in-rome-v1 \
//     --labels build/chord-context/labels/when-in-rome-v1.labels.json \
//     --split-file research/whatkey/data/splits/when-in-rome-v1.json \
//     --split development \
//     --out build/chord-context/headroom/wir-dev

import 'dart:convert';
import 'dart:io';

import 'package:whatchord/whatchord.dart';

import '../src/chord_id_engine.dart';
import '../whatkey/src/fixtures.dart';

const _take = 10000;
const _minNotes = 3;

final _analyzer = ChordAnalyzer();

enum Bucket { top1, nearTie, prune, generated, absent }

enum Level { rootQuality, root }

enum Context { neutral, annotated }

/// Pools scored independently; every other category is only counted.
const _scoredCategories = ['ok', 'extra-tones', 'mismatch'];

void main(List<String> args) {
  final options = _parseArgs(args);
  final fixtureSet = FixtureSet.load(Directory(options['fixtures']!));
  final labels = jsonDecode(
    File(options['labels']!).readAsStringSync(),
  ) as Map<String, dynamic>;
  final pieces = (labels['pieces'] as Map).cast<String, dynamic>();

  var selected = fixtureSet.fixtures;
  if (options.containsKey('split-file')) {
    final splitFile = SplitFile.load(File(options['split-file']!));
    splitFile.validateAgainst(fixtureSet);
    final titles = splitFile
        .pieceTitles(options['split'] ?? 'development')
        .toSet();
    selected = [
      for (final fixture in selected)
        if (titles.contains(fixture.title)) fixture,
    ];
  }

  final report = _run(fixtureSet, selected, pieces);
  report['configuration'] = {
    'fixtures': options['fixtures'],
    'labels': options['labels'],
    'splitFile': options['split-file'],
    'split': options.containsKey('split-file')
        ? (options['split'] ?? 'development')
        : null,
    'take': _take,
    'minNotes': _minNotes,
    'rankingPruneMargin': _analyzer.rankingPruneMargin,
    'neutralContext': fixtureSet.manifest['context'],
  };

  final outDir = Directory(options['out']!)..createSync(recursive: true);
  File(
    '${outDir.path}/report.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent(' ').convert(report)}\n');
  final text = _formatReport(report);
  File('${outDir.path}/report.txt').writeAsStringSync(text);
  stdout.write(text);
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    if (!args[i].startsWith('--') || i + 1 >= args.length) {
      throw ArgumentError('Expected --flag value pairs, got: ${args[i]}');
    }
    options[args[i].substring(2)] = args[i + 1];
  }
  for (final required in ['fixtures', 'labels', 'out']) {
    if (!options.containsKey(required)) {
      throw ArgumentError('Missing required --$required');
    }
  }
  return options;
}

Map<String, dynamic> _run(
  FixtureSet fixtureSet,
  List<LabeledFixture> selected,
  Map<String, dynamic> labeledPieces,
) {
  final neutral = _contextFor(fixtureSet.manifest['context'] as String);
  final categoryCounts = <String, int>{};
  final perPiece = <Map<String, dynamic>>[];
  // pool -> context -> level -> bucket -> count, pooled over events.
  final pooled = _emptyTallies();
  // prevClass -> bucket -> count, ok pool, neutral context, rootQuality.
  final transitions = <String, Map<String, int>>{};
  // Non-top1 ok-pool events (neutral, rootQuality): the Track A seed cases.
  final misses = <Map<String, dynamic>>[];

  for (final fixture in selected) {
    final entries = (labeledPieces[fixture.id] as List?)?.cast<Map>();
    if (entries == null) {
      throw StateError('Labels file has no entry for ${fixture.id}');
    }
    if (entries.length != fixture.events.length) {
      throw StateError(
        'Label/event count mismatch for ${fixture.id}: '
        '${entries.length} vs ${fixture.events.length}',
      );
    }
    final pieceTallies = _emptyTallies();
    for (var i = 0; i < fixture.events.length; i++) {
      final event = fixture.events[i];
      final entry = entries[i].cast<String, dynamic>();
      var category = entry['category'] as String;
      if (event.input.noteCount < _minNotes) category = 'below-min-notes';
      categoryCounts[category] = (categoryCounts[category] ?? 0) + 1;
      if (!_scoredCategories.contains(category)) continue;

      final expected = (entry['expected'] as Map).cast<String, dynamic>();
      final expectedRootPc = expected['rootPc'] as int;
      final expectedQuality = expected['quality'] as String?;
      final localKey = entry['localKey'] as String;

      for (final context in Context.values) {
        final analysisContext = context == Context.neutral
            ? neutral
            : _contextFor(localKey);
        final ranked = _analyzer.analyze(
          event.input,
          context: analysisContext,
          voicing: event.voicing,
          take: _take,
        );
        for (final level in Level.values) {
          if (level == Level.rootQuality && expectedQuality == null) continue;
          final bucket = _locate(ranked, (identity) {
            if (identity.rootPc != expectedRootPc) return false;
            return level == Level.root ||
                identity.quality.name == expectedQuality;
          });
          _tally(pieceTallies, category, context, level, bucket);
          _tally(pooled, category, context, level, bucket);
          if (category == 'ok' &&
              context == Context.neutral &&
              level == Level.rootQuality) {
            final prevClass = entry['prevClass'] as String;
            final byBucket = transitions.putIfAbsent(prevClass, () => {});
            byBucket[bucket.name] = (byBucket[bucket.name] ?? 0) + 1;
            if (bucket != Bucket.top1) {
              final chosen = ranked.first.identity;
              misses.add({
                'piece': fixture.id,
                'index': i,
                'figure': entry['figure'],
                'prevFigure': i > 0 ? entries[i - 1]['figure'] : null,
                'localKey': localKey,
                'expected': '$expectedRootPc/$expectedQuality',
                'chosen':
                    '${chosen.rootPc}/${chosen.quality.name}'
                    '${chosen.hasSlashBass ? '/bass${chosen.bassPc}' : ''}',
                'bucket': bucket.name,
              });
            }
          }
        }
      }
    }
    perPiece.add({'id': fixture.id, 'tallies': pieceTallies});
  }

  return {
    'schema': 'chord-context-headroom/1',
    'set': fixtureSet.name,
    'pieces': selected.length,
    'categoryCounts': categoryCounts,
    'pooled': pooled,
    'perPiece': perPiece,
    'transitions': transitions,
    'misses': misses,
    'perPieceMeans': _perPieceMeans(perPiece),
  };
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

/// Buckets the best-ranked matching candidate by its cost gap to the chosen
/// candidate.
Bucket _locate(
  List<ChordCandidate> ranked,
  bool Function(ChordIdentity) matches,
) {
  for (var i = 0; i < ranked.length; i++) {
    if (!matches(ranked[i].identity)) continue;
    if (i == 0) return Bucket.top1;
    final gap = ranked[i].cost - ranked.first.cost;
    if (ChordCandidateRanking.isNearTie(ranked.first.cost, ranked[i].cost)) {
      return Bucket.nearTie;
    }
    if (gap <= _analyzer.rankingPruneMargin) return Bucket.prune;
    return Bucket.generated;
  }
  return Bucket.absent;
}

Map<String, dynamic> _emptyTallies() => {
  for (final category in _scoredCategories)
    category: {
      for (final context in Context.values)
        context.name: {
          for (final level in Level.values)
            level.name: {for (final bucket in Bucket.values) bucket.name: 0},
        },
    },
};

void _tally(
  Map<String, dynamic> tallies,
  String category,
  Context context,
  Level level,
  Bucket bucket,
) {
  final byBucket =
      ((tallies[category] as Map)[context.name] as Map)[level.name] as Map;
  byBucket[bucket.name] = (byBucket[bucket.name] as int) + 1;
}

/// Per-piece mean of the top1 rate and cumulative ceilings, ok pool only.
Map<String, dynamic> _perPieceMeans(List<Map<String, dynamic>> perPiece) {
  final means = <String, dynamic>{};
  for (final context in Context.values) {
    for (final level in Level.values) {
      final top1 = <double>[];
      final nearTieCeiling = <double>[];
      final pruneCeiling = <double>[];
      final generatedCeiling = <double>[];
      for (final piece in perPiece) {
        final byBucket =
            (((piece['tallies'] as Map)['ok'] as Map)[context.name]
                    as Map)[level.name]
                as Map;
        final counts = {
          for (final bucket in Bucket.values)
            bucket: byBucket[bucket.name] as int,
        };
        final total = counts.values.fold(0, (a, b) => a + b);
        if (total == 0) continue;
        var cumulative = 0;
        final ceilings = <Bucket, double>{};
        for (final bucket in Bucket.values) {
          cumulative += counts[bucket]!;
          ceilings[bucket] = cumulative / total;
        }
        top1.add(ceilings[Bucket.top1]!);
        nearTieCeiling.add(ceilings[Bucket.nearTie]!);
        pruneCeiling.add(ceilings[Bucket.prune]!);
        generatedCeiling.add(ceilings[Bucket.generated]!);
      }
      means['${context.name}.${level.name}'] = {
        'pieces': top1.length,
        'top1': _mean(top1),
        'nearTieCeiling': _mean(nearTieCeiling),
        'pruneCeiling': _mean(pruneCeiling),
        'generatedCeiling': _mean(generatedCeiling),
      };
    }
  }
  return means;
}

double _mean(List<double> values) =>
    values.isEmpty ? 0 : values.fold(0.0, (a, b) => a + b) / values.length;

String _formatReport(Map<String, dynamic> report) {
  final buffer = StringBuffer()
    ..writeln('chord-context headroom: ${report['set']}')
    ..writeln('pieces: ${report['pieces']}')
    ..writeln()
    ..writeln('event categories:');
  final categories = (report['categoryCounts'] as Map).cast<String, int>();
  final totalEvents = categories.values.fold(0, (a, b) => a + b);
  for (final entry
      in categories.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value))) {
    final share = (entry.value / totalEvents * 100).toStringAsFixed(1);
    buffer.writeln('  ${entry.key}: ${entry.value} ($share%)');
  }

  buffer.writeln();
  for (final category in _scoredCategories) {
    buffer.writeln('pool "$category" (pooled events, cumulative ceilings):');
    for (final context in Context.values) {
      for (final level in Level.values) {
        final byBucket =
            (((report['pooled'] as Map)[category] as Map)[context.name]
                    as Map)[level.name]
                as Map;
        final counts = [
          for (final bucket in Bucket.values) byBucket[bucket.name] as int,
        ];
        final total = counts.fold(0, (a, b) => a + b);
        if (total == 0) continue;
        var cumulative = 0;
        final cells = <String>[];
        for (var i = 0; i < Bucket.values.length; i++) {
          cumulative += counts[i];
          final pct = (cumulative / total * 100).toStringAsFixed(1);
          cells.add('${Bucket.values[i].name} $pct%');
        }
        buffer.writeln(
          '  ${context.name}/${level.name} (n=$total): ${cells.join('  ')}',
        );
      }
    }
    buffer.writeln();
  }

  buffer.writeln('per-piece means, ok pool:');
  final means = (report['perPieceMeans'] as Map).cast<String, dynamic>();
  for (final entry in means.entries) {
    final m = (entry.value as Map).cast<String, dynamic>();
    String pct(String key) =>
        '${((m[key] as double) * 100).toStringAsFixed(1)}%';
    buffer.writeln(
      '  ${entry.key} (pieces=${m['pieces']}): top1 ${pct('top1')}  '
      'nearTie ${pct('nearTieCeiling')}  prune ${pct('pruneCeiling')}  '
      'generated ${pct('generatedCeiling')}',
    );
  }

  buffer
    ..writeln()
    ..writeln(
      'transitions (ok pool, neutral/rootQuality, by previous figure class):',
    );
  final transitions = (report['transitions'] as Map).cast<String, dynamic>();
  for (final entry
      in transitions.entries.toList()..sort((a, b) => a.key.compareTo(b.key))) {
    final byBucket = (entry.value as Map).cast<String, int>();
    final total = byBucket.values.fold(0, (a, b) => a + b);
    final top1 = byBucket[Bucket.top1.name] ?? 0;
    final nearTie = byBucket[Bucket.nearTie.name] ?? 0;
    buffer.writeln(
      '  ${entry.key} (n=$total): top1 '
      '${(top1 / total * 100).toStringAsFixed(1)}%  '
      '+nearTie ${((top1 + nearTie) / total * 100).toStringAsFixed(1)}%',
    );
  }
  return buffer.toString();
}
