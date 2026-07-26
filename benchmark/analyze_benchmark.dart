// Offline performance baseline for the chord analysis engine.
//
// Measures, by replaying chord corpora through ChordAnalyzer.analyze():
//
//   1. Time, normalized to a fixed CPU reference workload (hardware-stable),
//      for two corpora: the adversarial reviewed-oracle corpus and the common
//      voicing pool (real-playing structures). Sampled adaptively until the
//      mean's 95% CI is tight; stddev reported.
//   2. Memory: allocation churn and retained heap delta (VM-observed).
//   3. Algorithmic operation counters (deterministic; require the counters
//      compile-time define to be set).
//
// Memory and counters are measured on the oracle corpus only -- it is the
// adversarial stress case, so it is the most sensitive regression signal.
//
// Run from the repo root:
//
//   dart run --enable-vm-service --define=whatchord.counters=true \
//     benchmark/analyze_benchmark.dart
//
// Writes full results as JSON to benchmark/last_run.json and prints a summary.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:whatchord/whatchord.dart';
import 'package:whatchord/diagnostics.dart';

import 'src/allocation_probe.dart';
import 'src/common_voicings.dart';
import 'src/corpus.dart';
import 'src/reference.dart';
import 'src/stats.dart';

final _analyzer = ChordAnalyzer();

// Convergence target for adaptive sampling: stop once the mean's 95% CI is
// within this fraction of the mean (or a budget/run cap is hit).
const double _targetRelCi = 0.015;

// The fast warm (cache-hit) pass is far below timer resolution per call, so each
// sample runs the whole corpus this many times and divides, lifting the timed
// region well above the microsecond clock granularity.
const int _warmBatch = 200;

const String _defaultOutPath = 'benchmark/last_run.json';
const String _baselinePath = 'benchmark/baseline.json';
const String _noisePath = 'benchmark/noise.json';

const int _minCalibrationRuns = 10;
const int _maxCalibrationRuns = 50;
const double _calibrationStabilityTarget = 0.10;
const double _timeRegressionThreshold = 0.05;
const double _memoryRegressionThreshold = 0.03;
const int _churnBytesPerCallRegressionThreshold = 1024;
const int _retainedBytesRegressionThreshold = 32 * 1024;

const Map<String, List<String>> _calibrationMetricPaths = {
  'time.oracle.coldNormalized': ['time', 'oracle', 'coldNormalized'],
  'time.oracle.warmNormalized': ['time', 'oracle', 'warmNormalized'],
  'time.common.coldNormalized': ['time', 'common', 'coldNormalized'],
  'time.common.warmNormalized': ['time', 'common', 'warmNormalized'],
  'memory.churnBytesPerCall': ['memory', 'churnBytesPerCall'],
  'memory.retainedBytes': ['memory', 'retainedBytes'],
};

// Accumulates the reference workload result so the compiler cannot elide it.
int _sink = 0;

Future<void> main(List<String> args) async {
  if (args.contains('-h') || args.contains('--help')) {
    _printUsage();
    return;
  }
  if (args.contains('--show-baseline')) {
    _printBaseline();
    return;
  }
  if (args.contains('--calibrate-noise')) {
    await _calibrateNoise();
    return;
  }
  final outPath = _argValue(args, '--out=') ?? _defaultOutPath;
  final printSummary = !args.contains('--no-summary');
  final printComparison = !args.contains('--no-compare');
  final check = args.contains('--check');

  final result = await _runBenchmark();

  File(
    outPath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(result));
  if (printSummary) _printSummary(result);
  final verdict = printComparison
      ? _maybePrintComparison(outPath, result, check: check)
      : _CheckVerdict.pass();
  if (check && !verdict.passed) exitCode = 1;
}

Future<Map<String, Object?>> _runBenchmark() async {
  final context = buildContext();
  final oracle = loadCorpus();
  final common = [for (final v in commonVoicings()) v.input];

  // Reference: one fixed CPU unit, measured once. Used only to normalize out
  // hardware speed; a slower machine inflates the engine and reference alike.
  final reference = collect(
    () => _timeMicros(() => _sink ^= referenceWork(referenceIterations)),
    budget: const Duration(seconds: 8),
    targetRelCi: _targetRelCi,
  );

  // --- Time, per corpus -----------------------------------------------------
  final (oracleCold, oracleWarm) = _measureCorpusTime(oracle, context);
  final (commonCold, commonWarm) = _measureCorpusTime(common, context);

  // --- Memory + counters: oracle corpus (the adversarial stress case) -------
  void oraclePass() {
    // Hoisted so the timed loop measures analyze(), not the lazy top-level
    // initialization check on every access.
    final analyzer = _analyzer;
    for (final input in oracle) {
      analyzer.analyze(input, context: context);
    }
  }

  final probe = await AllocationProbe.connect();
  _analyzer.clearCache();
  // Baseline heap with an empty cache, then reset the accumulator so churn
  // covers only the pass. Retained-by-engine is the heap growth from caching
  // the corpus (the after/before heapUsage delta), not the whole isolate heap.
  final baselineHeap = (await probe.sample()).heapUsage;
  await probe.resetAndGc();
  oraclePass();
  final memory = await probe.sample();
  final retainedBytes = memory.heapUsage - baselineHeap;
  await probe.dispose();

  EngineCounters.reset();
  _analyzer.clearCache();
  oraclePass();
  final counters = EngineCounters.snapshot();

  if (_sink == 1) stderr.writeln(); // keep _sink observable; effectively never.

  return <String, Object?>{
    'meta': {
      'oracleSize': oracle.length,
      'commonSize': common.length,
      'dartVersion': Platform.version,
      'targetRelCi95': _targetRelCi,
      'referenceIterations': referenceIterations,
      'referenceDisplayScale': referenceDisplayScale,
      'countersEnabled': engineCountersEnabled,
    },
    'referenceUs': reference.toJson(targetRelCi: _targetRelCi),
    // Compare normalized values across runs, not raw microseconds.
    'time': {
      'oracle': _timeJson(oracleCold, oracleWarm, reference),
      'common': _timeJson(commonCold, commonWarm, reference),
    },
    'memory': {
      'churnBytes': memory.churnBytes,
      'churnObjects': memory.churnObjects,
      'churnBytesPerCall': memory.churnBytes / oracle.length,
      'retainedBytes': retainedBytes,
      'liveHeapBytes': memory.heapUsage,
    },
    'counters': counters,
  };
}

/// Adaptively samples cold (cache-miss) and warm (cache-hit) per-call time for
/// [corpus]. Cold clears the cache outside the timed region; warm batches the
/// pass for timer resolution.
(Stats, Stats) _measureCorpusTime(
  List<ChordInput> corpus,
  AnalysisContext context,
) {
  final n = corpus.length;
  final analyzer = _analyzer;
  void pass() {
    for (final input in corpus) {
      analyzer.analyze(input, context: context);
    }
  }

  final cold = collect(
    () {
      _analyzer.clearCache();
      return _timeMicros(pass) / n;
    },
    budget: const Duration(seconds: 30),
    targetRelCi: _targetRelCi,
  );

  _analyzer.clearCache();
  pass();
  final warm = collect(
    () {
      final us = _timeMicros(() {
        for (var b = 0; b < _warmBatch; b++) {
          pass();
        }
      });
      return us / (_warmBatch * n);
    },
    budget: const Duration(seconds: 8),
    targetRelCi: _targetRelCi,
  );

  return (cold, warm);
}

Map<String, Object?> _timeJson(Stats cold, Stats warm, Stats reference) => {
  // Scaled for readability; see referenceDisplayScale. A uniform factor leaves
  // the relative CIs (and therefore the regression check) unchanged.
  'coldNormalized': referenceDisplayScale * cold.mean / reference.mean,
  'warmNormalized': referenceDisplayScale * warm.mean / reference.mean,
  // CI of a ratio of independent means, propagated in quadrature.
  'coldNormalizedRelCi95': _hypot(cold.relCi95, reference.relCi95),
  'warmNormalizedRelCi95': _hypot(warm.relCi95, reference.relCi95),
  'coldUsPerCall': cold.toJson(targetRelCi: _targetRelCi),
  'warmUsPerCall': warm.toJson(targetRelCi: _targetRelCi),
};

/// Prints a delta against the committed baseline, unless this run *is* the
/// baseline. Counter changes on the same corpus are deterministic; memory is
/// VM-observed and may have small runtime noise; normalized time changes beyond
/// its CI are meaningful.
_CheckVerdict _maybePrintComparison(
  String outPath,
  Map<String, Object?> current, {
  required bool check,
}) {
  if (outPath == _baselinePath) return _CheckVerdict.pass();
  final file = File(_baselinePath);
  if (!file.existsSync()) return _CheckVerdict.pass();
  final base = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  final noise = _loadNoiseModel();
  final failures = <String>[];

  stdout.writeln('');
  stdout.writeln('Comparison to baseline ($_baselinePath)');
  for (final key in ['oracleSize', 'commonSize']) {
    final b = _at(base, ['meta', key]);
    final c = _at(current, ['meta', key]);
    if (b != c) {
      stdout.writeln(
        '    $key differs ($b -> $c): per-call values are not comparable.'
        ' Regenerate the baseline.',
      );
    }
  }

  void addFailure(String message) => failures.add(message);

  String changeText(num baseline, num current, {required bool pct}) {
    if (current == baseline) return 'unchanged';
    if (pct && baseline != 0) {
      final change = (current - baseline) / baseline * 100;
      return '${change >= 0 ? '+' : ''}${change.toStringAsFixed(1)}%';
    }
    final change = current - baseline;
    return '${change >= 0 ? '+' : ''}${_formatInteger(change)}';
  }

  void timeCmp(String corpus, String mode, List<String> path) {
    final b = _at(base, path);
    final c = _at(current, path);
    if (b is! num || c is! num) return;
    final metricKey = path.join('.');
    final relativeChange = _relativeChange(b, c);
    final uncertainty = _combinedTimeUncertainty(base, current, path, noise);
    if (check &&
        relativeChange >= _timeRegressionThreshold &&
        relativeChange > uncertainty) {
      addFailure(
        '$corpus $mode normalized time regressed by '
        '${_formatPercent(relativeChange)}; combined uncertainty '
        '${_formatMagnitudePercent(uncertainty)}',
      );
    }
    stdout.writeln(
      '  ${corpus.padRight(13)}'
      '${mode.padRight(7)}'
      '${_formatNormalized(b).padLeft(10)}'
      '${_formatNormalized(c).padLeft(10)}'
      '${changeText(b, c, pct: true).padLeft(10)}'
      '${check && noise != null ? _noiseSuffix(noise, metricKey).padLeft(12) : ''}',
    );
  }

  void metricCmp(
    String label,
    List<String> path, {
    required String Function(num value) format,
    required bool pct,
  }) {
    final b = _at(base, path);
    final c = _at(current, path);
    if (b is! num || c is! num) return;
    final metricKey = path.join('.');
    final relativeChange = _relativeChange(b, c);
    final noiseRel95 = noise?.metricNoiseRel95(metricKey) ?? 0;
    final practicalThreshold = _practicalRegressionThreshold(metricKey, b);
    if (check &&
        pct &&
        relativeChange >= practicalThreshold &&
        relativeChange > noiseRel95) {
      addFailure(
        '$label increased by ${_formatPercent(relativeChange)}; '
        'VM-observed noise ${_formatMagnitudePercent(noiseRel95)}',
      );
    } else if (check && !pct && c > b) {
      addFailure('$label increased from ${format(b)} to ${format(c)}');
    }
    stdout.writeln(
      '  ${label.padRight(20)}'
      '${format(b).padLeft(15)}'
      '${format(c).padLeft(15)}'
      '${changeText(b, c, pct: pct).padLeft(12)}'
      '${check && pct && noise != null ? _noiseSuffix(noise, metricKey).padLeft(12) : ''}',
    );
  }

  stdout.writeln('  Time');
  stdout.writeln(
    '  ${'Corpus'.padRight(13)}'
    '${'Mode'.padRight(7)}'
    '${'Baseline'.padLeft(10)}'
    '${'Current'.padLeft(10)}'
    '${'Change'.padLeft(10)}'
    '${check && noise != null ? 'Noise95'.padLeft(12) : ''}',
  );
  timeCmp('oracle', 'cold', ['time', 'oracle', 'coldNormalized']);
  timeCmp('oracle', 'warm', ['time', 'oracle', 'warmNormalized']);
  timeCmp('common', 'cold', ['time', 'common', 'coldNormalized']);
  timeCmp('common', 'warm', ['time', 'common', 'warmNormalized']);

  stdout.writeln('  Memory, VM-observed');
  stdout.writeln(
    '  ${'Metric'.padRight(20)}'
    '${'Baseline'.padLeft(15)}'
    '${'Current'.padLeft(15)}'
    '${'Change'.padLeft(12)}'
    '${check && noise != null ? 'Noise95'.padLeft(12) : ''}',
  );
  metricCmp(
    'churn bytes/call',
    ['memory', 'churnBytesPerCall'],
    format: _formatInteger,
    pct: true,
  );
  metricCmp(
    'retained bytes',
    ['memory', 'retainedBytes'],
    format: _formatInteger,
    pct: true,
  );
  stdout.writeln('  Counters, deterministic');
  stdout.writeln(
    '  ${'Metric'.padRight(20)}'
    '${'Baseline'.padLeft(15)}'
    '${'Current'.padLeft(15)}'
    '${'Change'.padLeft(12)}',
  );
  for (final key in (current['counters'] as Map<String, Object?>).keys) {
    metricCmp(
      _counterLabel(key),
      ['counters', key],
      format: _formatInteger,
      pct: false,
    );
  }

  final verdict = failures.isEmpty
      ? _CheckVerdict.pass()
      : _CheckVerdict.fail(failures);
  if (check) _printCheckVerdict(verdict, noise);
  return verdict;
}

double _combinedTimeUncertainty(
  Map<String, Object?> baseline,
  Map<String, Object?> current,
  List<String> normalizedPath,
  _NoiseModel? noise,
) {
  final relCiPath = [
    ...normalizedPath.take(normalizedPath.length - 1),
    '${normalizedPath.last}RelCi95',
  ];
  final baselineRelCi = _at(baseline, relCiPath) as num? ?? 0;
  final currentRelCi = _at(current, relCiPath) as num? ?? 0;
  final noiseRel95 = noise?.metricNoiseRel95(normalizedPath.join('.')) ?? 0;
  return _hypot(
    _hypot(baselineRelCi.toDouble(), currentRelCi.toDouble()),
    noiseRel95,
  );
}

double _relativeChange(num baseline, num current) {
  if (baseline == 0) return current == 0 ? 0 : double.infinity;
  return (current - baseline) / baseline;
}

/// Relative change that --check treats as a real regression for [metricKey],
/// independent of noise. Time metrics use a flat floor; memory metrics also
/// honor an absolute-bytes floor so tiny heaps do not trip on rounding.
double _practicalRegressionThreshold(String metricKey, num baselineValue) {
  return switch (metricKey) {
    'time.oracle.coldNormalized' ||
    'time.oracle.warmNormalized' ||
    'time.common.coldNormalized' ||
    'time.common.warmNormalized' => _timeRegressionThreshold,
    'memory.churnBytesPerCall' => math.max(
      _memoryRegressionThreshold,
      _churnBytesPerCallRegressionThreshold / baselineValue,
    ),
    'memory.retainedBytes' => math.max(
      _memoryRegressionThreshold,
      _retainedBytesRegressionThreshold / baselineValue,
    ),
    _ => 0.0,
  };
}

String _noiseSuffix(_NoiseModel? noise, String key) {
  final noiseRel95 = noise?.metricNoiseRel95(key);
  if (noiseRel95 == null) return '';
  return _formatMagnitudePercent(noiseRel95);
}

String _formatPercent(num value) =>
    '${value >= 0 ? '+' : ''}${_formatPercentMagnitude(value)}';

String _formatMagnitudePercent(num value) => _formatPercentMagnitude(value);

String _formatPercentMagnitude(num value) {
  final pct = value.abs() * 100;
  final fractionDigits = pct != 0 && pct < 0.1 ? 2 : 1;
  return '${pct.toStringAsFixed(fractionDigits)}%';
}

_NoiseModel? _loadNoiseModel() {
  final file = File(_noisePath);
  if (!file.existsSync()) return null;
  try {
    final json = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    return _NoiseModel(json);
  } on Object catch (error) {
    stderr.writeln('Ignoring unreadable noise model at $_noisePath: $error');
    return null;
  }
}

void _printCheckVerdict(_CheckVerdict verdict, _NoiseModel? noise) {
  stdout.writeln('');
  stdout.writeln('Benchmark check');
  if (noise == null) {
    stdout.writeln('  noise model: not found ($_noisePath)');
  } else {
    stdout.writeln(
      '  noise model: $_noisePath (${noise.runs} runs, ${noise.generatedAt})',
    );
  }
  stdout.writeln(
    '  time gate: fail regressions >= '
    '${_formatMagnitudePercent(_timeRegressionThreshold)}'
    ' and outside combined uncertainty',
  );
  stdout.writeln(
    '  memory gate: fail regressions >= '
    '${_formatMagnitudePercent(_memoryRegressionThreshold)}'
    ' and above absolute/noise thresholds',
  );
  stdout.writeln('');
  if (verdict.passed) {
    stdout.writeln('  result: PASS');
  } else {
    for (final failure in verdict.failures) {
      stdout.writeln('  - $failure');
    }
    stdout.writeln('  result: FAIL');
  }
}

class _CheckVerdict {
  const _CheckVerdict._(this.failures);

  factory _CheckVerdict.pass() => const _CheckVerdict._([]);
  factory _CheckVerdict.fail(List<String> failures) =>
      _CheckVerdict._(List.unmodifiable(failures));

  final List<String> failures;

  bool get passed => failures.isEmpty;
}

class _NoiseModel {
  _NoiseModel(this.json);

  final Map<String, Object?> json;

  int get runs => _at(json, ['meta', 'runs']) as int? ?? 0;

  String get generatedAt =>
      _at(json, ['meta', 'generatedAt']) as String? ?? 'unknown date';

  double? metricNoiseRel95(String key) {
    final value = _at(json, ['metrics', key, 'noiseRel95']);
    return value is num ? value.toDouble() : null;
  }
}

Object? _at(Map<String, Object?> map, List<String> path) {
  Object? node = map;
  for (final key in path) {
    if (node is Map && node.containsKey(key)) {
      node = node[key];
    } else {
      return null;
    }
  }
  return node;
}

void _printBaseline() {
  final file = File(_baselinePath);
  if (!file.existsSync()) {
    stderr.writeln('No baseline found at $_baselinePath.');
    exitCode = 1;
    return;
  }
  final baseline = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
  _printSummary(baseline, source: _baselinePath);
}

Future<void> _calibrateNoise() async {
  final baselineFile = File(_baselinePath);
  if (!baselineFile.existsSync()) {
    stderr.writeln('No baseline found at $_baselinePath.');
    exitCode = 1;
    return;
  }
  final baseline =
      jsonDecode(baselineFile.readAsStringSync()) as Map<String, Object?>;
  final tempDir = await Directory.systemTemp.createTemp(
    'whatchord-benchmark-noise-',
  );
  final results = <Map<String, Object?>>[];
  stdout.writeln('Calibrating benchmark noise against $_baselinePath');
  stdout.writeln('  min runs: $_minCalibrationRuns');
  stdout.writeln('  max runs: $_maxCalibrationRuns');
  stdout.writeln(
    '  stop: all noise estimates change by less than '
    '${_formatMagnitudePercent(_calibrationStabilityTarget)}',
  );
  stdout.writeln('  temp: ${tempDir.path}');
  Map<String, Map<String, double>> previousMetrics = const {};
  Map<String, Map<String, double>> metrics = const {};
  var stable = false;
  try {
    for (var i = 1; i <= _maxCalibrationRuns; i++) {
      final outPath = '${tempDir.path}/run-$i.json';
      stdout.writeln('  run $i/$_maxCalibrationRuns');
      final process = await Process.run(Platform.resolvedExecutable, [
        'run',
        '--enable-vm-service',
        '--define=whatchord.counters=true',
        'benchmark/analyze_benchmark.dart',
        '--out=$outPath',
        '--no-summary',
        '--no-compare',
      ]);
      if (process.exitCode != 0) {
        stderr.writeln(process.stdout);
        stderr.writeln(process.stderr);
        stderr.writeln('Calibration run $i failed.');
        exitCode = process.exitCode;
        return;
      }
      results.add(
        jsonDecode(File(outPath).readAsStringSync()) as Map<String, Object?>,
      );
      if (results.length >= _minCalibrationRuns) {
        metrics = _calculateNoiseMetrics(baseline, results);
        if (previousMetrics.isNotEmpty) {
          final unstable = _unstableNoiseMetrics(previousMetrics, metrics);
          if (unstable.isEmpty) {
            stable = true;
            stdout.writeln('  stable after ${results.length} runs');
            break;
          }
          stdout.writeln('    unstable: ${unstable.join(', ')}');
        }
        previousMetrics = metrics;
      }
    }
  } finally {
    try {
      tempDir.deleteSync(recursive: true);
    } on FileSystemException {
      // Temporary calibration runs are best-effort cleanup only.
    }
  }

  metrics = metrics.isEmpty
      ? _calculateNoiseMetrics(baseline, results)
      : metrics;
  final noise = <String, Object?>{
    'meta': {
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'runs': results.length,
      'minRuns': _minCalibrationRuns,
      'maxRuns': _maxCalibrationRuns,
      'stable': stable,
      'stabilityTarget': _calibrationStabilityTarget,
      'baselinePath': _baselinePath,
      'method':
          'Relative deltas against baseline; noiseRel95 = 1.96 * 1.4826 * MAD.',
    },
    'metrics': metrics,
  };
  File(
    _noisePath,
  ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(noise));
  stdout.writeln('Wrote $_noisePath');
  _reportBaselineStaleness(baseline, metrics);
}

/// Warns when the calibration cloud has a systematic offset from the committed
/// baseline that exceeds both the measured noise and the regression floor. A
/// persistent offset means the baseline no longer represents this runner:
/// regenerate it with --out=$_baselinePath. Do not fold the drift into the
/// noise model, which measures spread, not center.
void _reportBaselineStaleness(
  Map<String, Object?> baseline,
  Map<String, Map<String, double>> metrics,
) {
  final drifted = <String>[];
  for (final key in metrics.keys) {
    final offset = metrics[key]?['medianRelativeDelta'];
    final noiseRel95 = metrics[key]?['noiseRel95'];
    if (offset == null || noiseRel95 == null) continue;
    final baselineValue = _at(baseline, _calibrationMetricPaths[key]!);
    if (baselineValue is! num || baselineValue == 0) continue;
    final floor = _practicalRegressionThreshold(key, baselineValue);
    if (offset.abs() > noiseRel95 && offset.abs() >= floor) {
      drifted.add(
        '    $key ${_formatPercent(offset)} '
        '(noise ${_formatMagnitudePercent(noiseRel95)}, '
        'floor ${_formatMagnitudePercent(floor)})',
      );
    }
  }
  if (drifted.isEmpty) return;
  stdout.writeln(
    'Baseline may be stale: these metrics sit off-center beyond noise and the '
    'regression floor:',
  );
  drifted.forEach(stdout.writeln);
  stdout.writeln(
    'Regenerate with --out=$_baselinePath if the engine or runner changed.',
  );
}

Map<String, Map<String, double>> _calculateNoiseMetrics(
  Map<String, Object?> baseline,
  List<Map<String, Object?>> results,
) {
  final metrics = <String, Map<String, double>>{};
  for (final key in _calibrationMetricPaths.keys) {
    final path = _calibrationMetricPaths[key]!;
    final baselineValue = _at(baseline, path);
    if (baselineValue is! num || baselineValue == 0) continue;
    final deltas = <double>[];
    for (final result in results) {
      final value = _at(result, path);
      if (value is num) {
        deltas.add(((value - baselineValue) / baselineValue).toDouble());
      }
    }
    if (deltas.length < 3) continue;
    final medianDelta = _median(deltas);
    final absDeviations = [
      for (final delta in deltas) (delta - medianDelta).abs(),
    ];
    final mad = _median(absDeviations);
    final robustSigma = 1.4826 * mad;
    final noiseRel95 = 1.96 * robustSigma;
    metrics[key] = {
      'medianRelativeDelta': medianDelta,
      'madRelativeDelta': mad,
      'noiseRel95': noiseRel95,
      'maxAbsRelativeDelta': deltas.map((d) => d.abs()).reduce(math.max),
    };
  }
  return metrics;
}

/// Names the metrics whose noise estimate moved more than the stability
/// target since the previous round, with the signed change. Empty means the
/// calibration has settled.
List<String> _unstableNoiseMetrics(
  Map<String, Map<String, double>> previous,
  Map<String, Map<String, double>> current,
) {
  final unstable = <String>[];
  for (final key in current.keys) {
    final oldNoise = previous[key]?['noiseRel95'];
    final newNoise = current[key]?['noiseRel95'];
    if (oldNoise == null || newNoise == null) {
      unstable.add('$key (new)');
      continue;
    }
    final denominator = math.max(oldNoise.abs(), 1e-12);
    final relativeChange = (newNoise - oldNoise) / denominator;
    if (relativeChange.abs() > _calibrationStabilityTarget) {
      unstable.add('$key (${_formatPercent(relativeChange)})');
    }
  }
  for (final key in previous.keys) {
    if (!current.containsKey(key)) unstable.add('$key (dropped)');
  }
  return unstable;
}

void _printUsage() {
  stdout.writeln('''
Chord engine performance benchmark.

Replays two corpora through ChordAnalyzer.analyze and reports normalized time
for each: the adversarial reviewed-oracle corpus and the common voicing pool.
Allocation memory and operation counters are reported for the oracle corpus.

Usage:
  tool/benchmark.sh [options]
  dart run --enable-vm-service --define=whatchord.counters=true \\
    benchmark/analyze_benchmark.dart [options]

Options:
  --out=PATH          Write results JSON to PATH (default: $_defaultOutPath).
                      Use --out=$_baselinePath to update the committed baseline.
  --show-baseline     Print $_baselinePath in the same summary format as a run.
  --check             Exit nonzero on meaningful regressions against the baseline.
  --calibrate-noise   Run repeated subprocess benchmarks and write $_noisePath.
  -h, --help          Show this help and exit.

Unless --out points at the baseline, the run prints a delta against
$_baselinePath when it exists. Compare runs on the same corpora only;
regenerate the baseline after changing a corpus.

--check uses the stored run CIs plus $_noisePath when present. Generate the
noise model with --calibrate-noise on the same runner class where you plan to
gate benchmark regressions.

Memory measurement needs the VM service (--enable-vm-service) and the
operation counters need the whatchord.counters define; tool/benchmark.sh
sets both for benchmark runs.''');
}

void _printSummary(Map<String, Object?> result, {String? source}) {
  String f(Object? v, int frac) => (v as num).toStringAsFixed(frac);
  Map<String, Object?> mapAt(List<String> path) =>
      _at(result, path) as Map<String, Object?>;

  final meta = mapAt(['meta']);
  final memory = mapAt(['memory']);
  final counters = mapAt(['counters']);
  final countersEnabled = meta['countersEnabled'] == true;
  final targetRelCi = meta['targetRelCi95'] as num? ?? _targetRelCi;

  void timeLine(
    String corpus,
    String mode,
    Map<String, Object?> time,
    String statsKey,
  ) {
    final stats = time[statsKey] as Map<String, Object?>;
    final relCi95 = stats['relCi95'] as num;
    final normalizedKey = statsKey.replaceFirst('UsPerCall', 'Normalized');
    final conv = relCi95 <= targetRelCi ? 'converged' : 'budget-capped';
    final samples = '${stats['n']} $conv';
    stdout.writeln(
      '  ${corpus.padRight(13)}'
      '${mode.padRight(7)}'
      '${_formatNormalized(time[normalizedKey] as num).padLeft(10)}'
      '${('${f(stats['mean'], 3)} us').padLeft(16)}'
      '${('${f(stats['stddev'], 3)} us').padLeft(13)}'
      '${('${f(relCi95 * 100, 1)}%').padLeft(7)}'
      '   $samples',
    );
  }

  stdout.writeln(
    source == null
        ? 'Chord engine benchmark'
        : 'Chord engine benchmark baseline',
  );
  if (source != null) stdout.writeln('  source: $source');
  stdout.writeln('');
  stdout.writeln('Time, normalized to reference workload');
  stdout.writeln(
    '  ${'Corpus'.padRight(13)}'
    '${'Mode'.padRight(7)}'
    '${'Norm'.padLeft(10)}'
    '${'Raw mean'.padLeft(16)}'
    '${'Stddev'.padLeft(13)}'
    '${'CI95'.padLeft(7)}'
    '   Samples',
  );
  final oracleTime = mapAt(['time', 'oracle']);
  timeLine(
    'oracle (${meta['oracleSize']})',
    'cold',
    oracleTime,
    'coldUsPerCall',
  );
  timeLine(
    'oracle (${meta['oracleSize']})',
    'warm',
    oracleTime,
    'warmUsPerCall',
  );
  final commonTime = mapAt(['time', 'common']);
  timeLine(
    'common (${meta['commonSize']})',
    'cold',
    commonTime,
    'coldUsPerCall',
  );
  timeLine(
    'common (${meta['commonSize']})',
    'warm',
    commonTime,
    'warmUsPerCall',
  );
  stdout.writeln('');
  stdout.writeln('Memory, oracle cold pass');
  final churnBytesPerCall = memory['churnBytesPerCall'] as num;
  final retainedBytes = memory['retainedBytes'] as num;
  final liveHeapBytes = memory['liveHeapBytes'] as num;
  stdout.writeln(
    '  ${'churn'.padRight(16)}'
    '${_formatBytes(churnBytesPerCall)}/call'
    ' (${_formatInteger(churnBytesPerCall)} bytes/call)',
  );
  stdout.writeln(
    '  ${'churn objects'.padRight(16)}'
    '${_formatInteger(memory['churnObjects'] as num)} total',
  );
  stdout.writeln(
    '  ${'retained'.padRight(16)}'
    '${_formatBytes(retainedBytes)} (${_formatInteger(retainedBytes)} bytes)',
  );
  stdout.writeln(
    '  ${'live heap'.padRight(16)}'
    '${_formatBytes(liveHeapBytes)} (${_formatInteger(liveHeapBytes)} bytes)',
  );
  if (countersEnabled) {
    stdout.writeln('');
    stdout.writeln('Counters, oracle cold pass');
    counters.forEach(
      (k, v) => stdout.writeln(
        '  ${_counterLabel(k).padRight(20)}${_formatInteger(v as num)}',
      ),
    );
  } else {
    stdout.writeln('');
    stdout.writeln(
      'Counters: disabled'
      ' (pass --define=whatchord.counters=true to enable)',
    );
  }
}

String _formatNormalized(num value) {
  final abs = value.abs();
  if (abs == 0) return '0';
  // Scores span the cold scores (~20-100) and the near-zero warm sanity line
  // (~0.01). Two decimals reads cleanly for the former; keep more for small
  // values so the warm line stays informative. Display precision only; the
  // regression check uses the full stored value.
  if (abs >= 1) return value.toStringAsFixed(2);
  if (abs >= 0.001) return value.toStringAsFixed(4);
  return value.toStringAsPrecision(3);
}

String _formatBytes(num bytes) {
  final abs = bytes.abs();
  if (abs < 1024) return '${_formatInteger(bytes)} B';
  const units = ['KiB', 'MiB', 'GiB'];
  var value = bytes.toDouble() / 1024;
  var unitIndex = 0;
  while (value.abs() >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  return '${value.toStringAsFixed(1)} ${units[unitIndex]}';
}

String _formatInteger(num value) {
  final text = value.round().toString();
  final negative = text.startsWith('-');
  final digits = negative ? text.substring(1) : text;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return negative ? '-$buffer' : buffer.toString();
}

String _counterLabel(String key) {
  final words = key
      .replaceAllMapped(RegExp(r'([a-z])([A-Z])'), (m) => '${m[1]} ${m[2]}')
      .toLowerCase();
  return words;
}

double _median(List<double> values) {
  final sorted = values.toList()..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

double _timeMicros(void Function() body) {
  final sw = Stopwatch()..start();
  body();
  sw.stop();
  return sw.elapsedMicroseconds.toDouble();
}

double _hypot(double a, double b) => math.sqrt(a * a + b * b);

String? _argValue(List<String> args, String prefix) {
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}
