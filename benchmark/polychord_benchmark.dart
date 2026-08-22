// Dedicated performance qualification for the automatic polychord path.
//
// Measures the pure-Dart product engine independently of Flutter/Riverpod UI
// scheduling. See research/polychord/product-performance-benchmark-v1.md for
// the frozen workload, metric definitions, and adoption gate.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:whatchord/whatchord.dart';

import 'src/allocation_probe.dart';
import 'src/common_voicings.dart';
import 'src/corpus.dart';
import 'src/polychord_workload.dart';
import 'src/reference.dart';
import 'src/stats.dart';

const String _schema = 'whatchord-polychord-benchmark/1';
const String _defaultOutPath = 'benchmark/polychord_last_run.json';
const double _targetRelCi = 0.015;
const double _budgetRatio = 0.05;
const int _retentionPasses = 20;
const Map<String, String> _structuralFixturePaths = {
  'basic-positive':
      'research/polychord/data/product-suite/fixtures/'
      'product-basic-positive-80.json',
  'upper-seventh':
      'research/polychord/data/product-suite/fixtures/'
      'product-upper-seventh-80.json',
  'assignment-ambiguity':
      'research/polychord/data/product-suite/fixtures/'
      'product-assignment-ambiguity-80.json',
  'multiple-identities':
      'research/polychord/data/product-suite/fixtures/'
      'product-lower-seventh-multiple-identities-80.json',
  'seventh-extension-veto':
      'research/polychord/data/product-suite/fixtures/'
      'product-rooted-seventh-extension-80.json',
};

int _sink = 0;

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }

  final corpora = _buildCorpora();
  if (args.contains('--validate-only')) {
    _validateWorkloads(corpora);
    return;
  }

  final outPath = _argValue(args, '--out=') ?? _defaultOutPath;
  final check = args.contains('--check');
  final result = await _runBenchmark(corpora);
  File(outPath)
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  _printSummary(result);

  final verdicts = [
    for (final corpus in ['oracle', 'common', 'structural'])
      ((result['corpora'] as Map<String, Object?>)[corpus]
              as Map<String, Object?>)['budget']
          as Map<String, Object?>,
  ];
  final passed = verdicts.every((budget) => budget['status'] == 'pass');
  if (check) {
    stdout.writeln('');
    stdout.writeln('Polychord performance check: ${passed ? 'PASS' : 'FAIL'}');
    if (!passed) exitCode = 1;
  }
}

Future<Map<String, Object?>> _runBenchmark(
  Map<String, List<PolychordBenchmarkCase>> corpora,
) async {
  final context = buildContext();
  final reference = collect(
    () => _timeMicros(() => _sink ^= referenceWork(referenceIterations)),
    budget: const Duration(seconds: 8),
    targetRelCi: _targetRelCi,
  );

  final corpusResults = <String, Object?>{};
  for (final entry in corpora.entries) {
    final cases = entry.value;
    final primaryFinal = _measurePrimaryFinal(cases, context);
    final productCoreFinal = _measureProductFinal(cases, serialize: false);
    final productSerializedFinal = _measureProductFinal(cases, serialize: true);
    final primaryEntry = _measurePrimaryEntry(cases, context);
    final productEntry = _measureProductEntry(cases);
    final diagnostics = _diagnoseCorpus(cases);

    corpusResults[entry.key] = <String, Object?>{
      'caseCount': cases.length,
      'eventCount': diagnostics.eventCount,
      'time': {
        'primaryFinal': _timeJson(primaryFinal, reference),
        'productCoreFinal': _timeJson(productCoreFinal, reference),
        'productSerializedFinal': _timeJson(productSerializedFinal, reference),
        'primaryEntry': _timeJson(primaryEntry, reference),
        'productSerializedEntry': _timeJson(productEntry, reference),
      },
      'budget': _budgetJson(
        primary: primaryFinal,
        product: productSerializedFinal,
      ),
      'practicalEntryOverhead': _ratioJson(
        numerator: productEntry,
        denominator: primaryEntry,
      ),
      'candidatesPerFrame': diagnostics.candidates.toJson(),
      'finalCandidatesPerCase': diagnostics.finalCandidates.toJson(),
      'displayedFrameCount': diagnostics.displayedFrameCount,
      'serializedUtf8Bytes': diagnostics.serializedUtf8Bytes,
    };
  }

  final memory = <String, Object?>{
    'oracle': await _measureMemory('oracle', corpora['oracle']!),
    'structural': await _measureMemory('structural', corpora['structural']!),
  };
  final stress = <String, Object?>{
    'fullMidiRange': _measureStress(
      id: 'full-midi-range',
      relativeEvents: fullMidiRangeStorm,
    ),
    'positiveReattack': _measureStress(
      id: 'positive-reattack',
      relativeEvents: positiveReattackStorm,
    ),
  };

  if (_sink == -1) stderr.writeln();
  return <String, Object?>{
    'schema': _schema,
    'meta': {
      'gitHead': _gitOutput(['rev-parse', 'HEAD']),
      'gitDirty': _gitOutput(['status', '--porcelain']).isNotEmpty,
      'dartVersion': Platform.version,
      'targetRelCi95': _targetRelCi,
      'budgetRatio': _budgetRatio,
      'referenceIterations': referenceIterations,
      'referenceDisplayScale': referenceDisplayScale,
      'oracleFixtureSha256': _sha256File('tool/chord/oracle_reviewed.json'),
      'commonFixtureSha256': _sha256File('benchmark/src/common_voicings.dart'),
      'structuralFixtureSha256': {
        for (final entry in _structuralFixturePaths.entries)
          entry.key: _sha256File(entry.value),
      },
      'retentionPasses': _retentionPasses,
    },
    'referenceUs': reference.toJson(targetRelCi: _targetRelCi),
    'corpora': corpusResults,
    'memory': memory,
    'stress': stress,
  };
}

Map<String, List<PolychordBenchmarkCase>> _buildCorpora() {
  final oracle = loadCorpus();
  final common = commonVoicings();
  final structural = structuralControlCases();
  _validateStructuralSources(structural);
  return {
    'oracle': [
      for (var index = 0; index < oracle.length; index++)
        projectPolychordBenchmarkCase('oracle-$index', oracle[index]),
    ],
    'common': [
      for (final voicing in common)
        projectPolychordBenchmarkCase(voicing.label, voicing.input),
    ],
    'structural': structural,
  };
}

void _validateStructuralSources(List<PolychordBenchmarkCase> cases) {
  final byId = {
    for (final benchmarkCase in cases) benchmarkCase.id: benchmarkCase,
  };
  if (byId.length != _structuralFixturePaths.length ||
      !byId.keys.toSet().containsAll(_structuralFixturePaths.keys)) {
    throw StateError(
      'structural control IDs do not match their frozen sources',
    );
  }

  for (final entry in _structuralFixturePaths.entries) {
    final fixture = jsonDecode(
      File(entry.value).readAsStringSync(),
    ) as Map<String, dynamic>;
    final initial = fixture['initialState']! as Map<String, dynamic>;
    if ((initial['pressedMidiNotes']! as List<dynamic>).isNotEmpty ||
        (initial['sustainedMidiNotes']! as List<dynamic>).isNotEmpty ||
        initial['pedalDown'] != false) {
      throw StateError('${entry.key} must begin from the empty input state');
    }
    final events = (fixture['events']! as List<dynamic>)
        .cast<Map<String, dynamic>>();
    if (events.any((event) => event['type'] != 'noteOn')) {
      throw StateError('${entry.key} must contain only note-on events');
    }
    final notes = [for (final event in events) event['midiNote']! as int];
    final timestamps = [
      for (final event in events) event['timestampMs']! as int,
    ];
    final benchmarkCase = byId[entry.key]!;
    final expectedTimestamps = [
      for (var index = 0; index < benchmarkCase.midiNotes.length; index++)
        index < benchmarkCase.lowerCohortCount ? 0 : cohortGapMs,
    ];
    if (!_listsEqual(notes, benchmarkCase.midiNotes) ||
        !_listsEqual(timestamps, expectedTimestamps)) {
      throw StateError('${entry.key} diverges from ${entry.value}');
    }
  }
}

bool _listsEqual(List<int> left, List<int> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

Stats _measurePrimaryFinal(
  List<PolychordBenchmarkCase> cases,
  AnalysisContext context,
) {
  final analyzer = ChordAnalyzer();
  return collect(
    () {
      analyzer.clearCache();
      return _timeMicros(() {
            for (final benchmarkCase in cases) {
              _sink ^= analyzer
                  .analyze(benchmarkCase.input, context: context)
                  .length;
            }
          }) /
          cases.length;
    },
    budget: const Duration(seconds: 30),
    targetRelCi: _targetRelCi,
  );
}

Stats _measureProductFinal(
  List<PolychordBenchmarkCase> cases, {
  required bool serialize,
}) {
  final engines = [
    for (var index = 0; index < cases.length; index++)
      PolychordProductEngine(initialPrimaryDisplayable: true),
  ];
  var generation = 0;
  return collect(
    () {
      generation += 1000;
      final lastEvents = <PolychordTemporalEvent>[];
      for (var index = 0; index < cases.length; index++) {
        final engine = engines[index];
        final events = cases[index].noteOnEvents(generation);
        engine.reset(timestampMs: generation);
        for (final event in events.take(events.length - 1)) {
          engine.observeEvent(event);
        }
        lastEvents.add(events.last);
      }
      return _timeMicros(() {
            for (var index = 0; index < cases.length; index++) {
              final observation = engines[index].observeEvent(
                lastEvents[index],
              );
              _consumeObservation(observation, serialize: serialize);
            }
          }) /
          cases.length;
    },
    budget: const Duration(seconds: 30),
    targetRelCi: _targetRelCi,
  );
}

Stats _measurePrimaryEntry(
  List<PolychordBenchmarkCase> cases,
  AnalysisContext context,
) {
  final analyzers = [
    for (var index = 0; index < cases.length; index++) ChordAnalyzer(),
  ];
  final eventCount = cases.fold<int>(
    0,
    (total, benchmarkCase) => total + benchmarkCase.midiNotes.length,
  );
  return collect(
    () {
      for (final analyzer in analyzers) {
        analyzer.clearCache();
      }
      return _timeMicros(() {
            for (var index = 0; index < cases.length; index++) {
              for (final input in cases[index].prefixInputs) {
                _sink ^= analyzers[index]
                    .analyze(input, context: context)
                    .length;
              }
            }
          }) /
          eventCount;
    },
    budget: const Duration(seconds: 30),
    targetRelCi: _targetRelCi,
  );
}

Stats _measureProductEntry(List<PolychordBenchmarkCase> cases) {
  final engines = [
    for (var index = 0; index < cases.length; index++)
      PolychordProductEngine(initialPrimaryDisplayable: true),
  ];
  final eventCount = cases.fold<int>(
    0,
    (total, benchmarkCase) => total + benchmarkCase.midiNotes.length,
  );
  var generation = 0;
  return collect(
    () {
      generation += 1000;
      final events = [
        for (final benchmarkCase in cases)
          benchmarkCase.noteOnEvents(generation),
      ];
      for (final engine in engines) {
        engine.reset(timestampMs: generation);
      }
      return _timeMicros(() {
            for (var index = 0; index < cases.length; index++) {
              for (final event in events[index]) {
                _consumeObservation(
                  engines[index].observeEvent(event),
                  serialize: true,
                );
              }
            }
          }) /
          eventCount;
    },
    budget: const Duration(seconds: 30),
    targetRelCi: _targetRelCi,
  );
}

_CorpusDiagnostics _diagnoseCorpus(List<PolychordBenchmarkCase> cases) {
  final engine = PolychordProductEngine(initialPrimaryDisplayable: true);
  final candidates = <int>[];
  final finalCandidates = <int>[];
  var displayedFrameCount = 0;
  var serializedUtf8Bytes = 0;
  var baseTimestampMs = 0;
  for (final benchmarkCase in cases) {
    engine.reset(timestampMs: baseTimestampMs);
    final events = benchmarkCase.noteOnEvents(baseTimestampMs);
    for (final event in events) {
      final observation = engine.observeEvent(event);
      candidates.add(observation.candidates.length);
      if (observation.displayedCandidate != null) displayedFrameCount++;
      serializedUtf8Bytes += utf8
          .encode(jsonEncode(observation.toJson()))
          .length;
    }
    finalCandidates.add(engine.latestObservation!.candidates.length);
    baseTimestampMs += 1000;
  }
  return _CorpusDiagnostics(
    eventCount: candidates.length,
    candidates: _Distribution.from(candidates),
    finalCandidates: _Distribution.from(finalCandidates),
    displayedFrameCount: displayedFrameCount,
    serializedUtf8Bytes: serializedUtf8Bytes,
  );
}

Future<Map<String, Object?>> _measureMemory(
  String corpusName,
  List<PolychordBenchmarkCase> cases,
) async {
  final probe = await AllocationProbe.connect();
  final engine = PolychordProductEngine(initialPrimaryDisplayable: true);
  var baseTimestampMs = 0;
  var eventCount = 0;

  void pass() {
    for (final benchmarkCase in cases) {
      engine.reset(timestampMs: baseTimestampMs);
      for (final event in benchmarkCase.noteOnEvents(baseTimestampMs)) {
        eventCount++;
        _consumeObservation(engine.observeEvent(event), serialize: true);
      }
      baseTimestampMs += 1000;
    }
  }

  final baselineHeap = (await probe.sample()).heapUsage;
  await probe.resetAndGc();
  eventCount = 0;
  pass();
  final firstPassEvents = eventCount;
  final first = await probe.sample();
  final firstRetainedBytes = first.heapUsage - baselineHeap;

  await probe.resetAndGc();
  eventCount = 0;
  for (var passIndex = 0; passIndex < _retentionPasses; passIndex++) {
    pass();
  }
  final repeated = await probe.sample();
  await probe.dispose();

  return <String, Object?>{
    'corpus': corpusName,
    'eventCount': firstPassEvents,
    'churnBytes': first.churnBytes,
    'churnObjects': first.churnObjects,
    'churnBytesPerEvent': first.churnBytes / firstPassEvents,
    'churnObjectsPerEvent': first.churnObjects / firstPassEvents,
    'retainedBytesAfterOnePass': firstRetainedBytes,
    'liveHeapBytesAfterOnePass': first.heapUsage,
    'repeatedPassCount': _retentionPasses,
    'repeatedEventCount': eventCount,
    'retainedGrowthBytesAfterRepeatedPasses':
        repeated.heapUsage - first.heapUsage,
    'liveHeapBytesAfterRepeatedPasses': repeated.heapUsage,
  };
}

Map<String, Object?> _measureStress({
  required String id,
  required List<PolychordTemporalEvent> Function(int) relativeEvents,
}) {
  final engine = PolychordProductEngine(initialPrimaryDisplayable: true);
  var generation = 0;
  final eventCount = relativeEvents(0).length;
  final time = collect(
    () {
      generation += 1000;
      final events = relativeEvents(generation);
      engine.reset(timestampMs: generation);
      return _timeMicros(() {
        for (final event in events) {
          _consumeObservation(engine.observeEvent(event), serialize: true);
        }
      });
    },
    targetRelCi: 0.02,
    budget: const Duration(seconds: 20),
  );

  generation += 1000;
  engine.reset(timestampMs: generation);
  final candidateCounts = <int>[];
  for (final event in relativeEvents(generation)) {
    candidateCounts.add(engine.observeEvent(event).candidates.length);
  }
  return <String, Object?>{
    'id': id,
    'eventCount': eventCount,
    'traceUs': time.toJson(targetRelCi: 0.02),
    'meanUsPerEvent': time.mean / eventCount,
    'candidatesPerFrame': _Distribution.from(candidateCounts).toJson(),
  };
}

Map<String, Object?> _timeJson(Stats stats, Stats reference) => {
  'normalized': referenceDisplayScale * stats.mean / reference.mean,
  'normalizedRelCi95': math.sqrt(
    stats.relCi95 * stats.relCi95 + reference.relCi95 * reference.relCi95,
  ),
  'usPerEvent': stats.toJson(targetRelCi: _targetRelCi),
};

Map<String, Object?> _budgetJson({
  required Stats primary,
  required Stats product,
}) {
  final ratio = product.mean / primary.mean;
  final relCi95 = math.sqrt(
    product.relCi95 * product.relCi95 + primary.relCi95 * primary.relCi95,
  );
  final lower = math.max(0.0, ratio * (1 - relCi95));
  final upper = ratio * (1 + relCi95);
  final status = ratio <= _budgetRatio
      ? 'pass'
      : lower <= _budgetRatio
      ? 'indeterminate'
      : 'fail';
  return <String, Object?>{
    'productToPrimaryRatio': ratio,
    'budgetRatio': _budgetRatio,
    'ratioRelCi95': relCi95,
    'ratioCi95Lower': lower,
    'ratioCi95Upper': upper,
    'status': status,
  };
}

Map<String, Object?> _ratioJson({
  required Stats numerator,
  required Stats denominator,
}) {
  final ratio = numerator.mean / denominator.mean;
  final relCi95 = math.sqrt(
    numerator.relCi95 * numerator.relCi95 +
        denominator.relCi95 * denominator.relCi95,
  );
  return <String, Object?>{
    'ratio': ratio,
    'ratioRelCi95': relCi95,
    'ratioCi95Lower': math.max(0.0, ratio * (1 - relCi95)),
    'ratioCi95Upper': ratio * (1 + relCi95),
  };
}

void _consumeObservation(
  PolychordProductObservation observation, {
  required bool serialize,
}) {
  _sink ^= observation.observationTimestampMs;
  _sink ^= observation.candidates.length;
  if (serialize) {
    final json = observation.toJson();
    _sink ^= json.length;
    _sink ^= (json['candidateRecords']! as List<Object?>).length;
  }
}

void _validateWorkloads(Map<String, List<PolychordBenchmarkCase>> corpora) {
  for (final entry in corpora.entries) {
    final diagnostics = _diagnoseCorpus(entry.value);
    stdout.writeln(
      '${entry.key}: ${entry.value.length} cases, '
      '${diagnostics.eventCount} events, '
      'max ${diagnostics.candidates.max} candidates/frame',
    );
  }
  stdout.writeln(
    'full-midi-range: ${fullMidiRangeStorm(0).length} events; '
    'positive-reattack: ${positiveReattackStorm(0).length} events',
  );
}

void _printSummary(Map<String, Object?> result) {
  final corpora = result['corpora']! as Map<String, Object?>;
  stdout.writeln('Polychord product-path benchmark');
  stdout.writeln('');
  stdout.writeln('Final dense event, microseconds per event');
  stdout.writeln(
    '  ${'Corpus'.padRight(10)}'
    '${'Primary'.padLeft(12)}'
    '${'Product'.padLeft(12)}'
    '${'+ toJson'.padLeft(12)}'
    '${'Budget'.padLeft(11)}',
  );
  for (final corpusName in ['oracle', 'common', 'structural']) {
    final corpus = corpora[corpusName]! as Map<String, Object?>;
    final time = corpus['time']! as Map<String, Object?>;
    final budget = corpus['budget']! as Map<String, Object?>;
    double mean(String key) =>
        (((time[key]! as Map<String, Object?>)['usPerEvent']!
                    as Map<String, Object?>)['mean']!
                as num)
            .toDouble();
    stdout.writeln(
      '  ${corpusName.padRight(10)}'
      '${mean('primaryFinal').toStringAsFixed(3).padLeft(12)}'
      '${mean('productCoreFinal').toStringAsFixed(3).padLeft(12)}'
      '${mean('productSerializedFinal').toStringAsFixed(3).padLeft(12)}'
      '${('${((budget['productToPrimaryRatio']! as num) * 100).toStringAsFixed(2)}% '
          '${budget['status']}').padLeft(11)}',
    );
  }

  stdout.writeln('');
  stdout.writeln('Whole chord-entry overhead');
  for (final corpusName in ['oracle', 'common', 'structural']) {
    final corpus = corpora[corpusName]! as Map<String, Object?>;
    final practical = corpus['practicalEntryOverhead']! as Map<String, Object?>;
    final overhead =
        '${((practical['ratio']! as num) * 100).toStringAsFixed(2)}%';
    stdout.writeln(
      '  ${corpusName.padRight(10)}'
      '${overhead.padLeft(9)} of cold primary event-path time',
    );
  }

  stdout.writeln('');
  stdout.writeln('Memory, serialized event replay');
  final memoryByCorpus = result['memory']! as Map<String, Object?>;
  for (final corpusName in ['oracle', 'structural']) {
    final memory = memoryByCorpus[corpusName]! as Map<String, Object?>;
    stdout.writeln(
      '  ${corpusName.padRight(10)}'
      '${(memory['churnBytesPerEvent']! as num).toStringAsFixed(0).padLeft(8)} '
      'bytes/event, '
      '${(memory['churnObjectsPerEvent']! as num).toStringAsFixed(1).padLeft(6)} '
      'objects/event, retained growth '
      '${memory['retainedGrowthBytesAfterRepeatedPasses']} bytes',
    );
  }

  final stress = result['stress']! as Map<String, Object?>;
  stdout.writeln('');
  stdout.writeln('Serialized stress traces');
  for (final key in ['fullMidiRange', 'positiveReattack']) {
    final value = stress[key]! as Map<String, Object?>;
    final trace = value['traceUs']! as Map<String, Object?>;
    stdout.writeln(
      '  ${(value['id']! as String).padRight(20)}'
      '${(value['eventCount']! as num).toString().padLeft(4)} events, '
      '${(trace['mean']! as num).toStringAsFixed(1).padLeft(9)} us/trace, '
      '${(value['meanUsPerEvent']! as num).toStringAsFixed(2).padLeft(7)} '
      'us/event',
    );
  }
}

void _printUsage() {
  stdout.writeln('''
Polychord product-path performance benchmark.

Usage:
  tool/polychord_benchmark.sh [options]

Options:
  --out=PATH       Write JSON to PATH (default: $_defaultOutPath).
  --check          Exit nonzero unless all three frozen 5% gates pass.
  --validate-only  Validate workload projection without timing or VM service.
  -h, --help       Show this help and exit.
''');
}

String? _argValue(List<String> args, String prefix) {
  for (final arg in args) {
    if (arg.startsWith(prefix)) return arg.substring(prefix.length);
  }
  return null;
}

String _gitOutput(List<String> args) {
  final result = Process.runSync('git', args);
  return result.exitCode == 0 ? (result.stdout as String).trim() : 'unknown';
}

String _sha256File(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();

double _timeMicros(void Function() body) {
  final stopwatch = Stopwatch()..start();
  body();
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds.toDouble();
}

final class _CorpusDiagnostics {
  const _CorpusDiagnostics({
    required this.eventCount,
    required this.candidates,
    required this.finalCandidates,
    required this.displayedFrameCount,
    required this.serializedUtf8Bytes,
  });

  final int eventCount;
  final _Distribution candidates;
  final _Distribution finalCandidates;
  final int displayedFrameCount;
  final int serializedUtf8Bytes;
}

final class _Distribution {
  const _Distribution({
    required this.count,
    required this.min,
    required this.median,
    required this.p90,
    required this.max,
    required this.total,
  });

  factory _Distribution.from(List<int> values) {
    if (values.isEmpty) {
      return const _Distribution(
        count: 0,
        min: 0,
        median: 0,
        p90: 0,
        max: 0,
        total: 0,
      );
    }
    final sorted = values.toList()..sort();
    final middle = sorted.length ~/ 2;
    final median = sorted.length.isOdd
        ? sorted[middle].toDouble()
        : (sorted[middle - 1] + sorted[middle]) / 2;
    final p90Index = (sorted.length * 0.9).ceil() - 1;
    return _Distribution(
      count: sorted.length,
      min: sorted.first,
      median: median,
      p90: sorted[p90Index],
      max: sorted.last,
      total: sorted.fold(0, (sum, value) => sum + value),
    );
  }

  final int count;
  final int min;
  final double median;
  final int p90;
  final int max;
  final int total;

  Map<String, Object> toJson() => {
    'count': count,
    'min': min,
    'median': median,
    'p90': p90,
    'max': max,
    'total': total,
  };
}
