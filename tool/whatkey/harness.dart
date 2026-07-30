// Offline WhatKey evaluation harness (research/whatkey/PROTOCOL.md).
//
// Replays fixture sets through a causal key detector and reports the protocol
// metrics. Runs the development split by default; the test split requires an
// explicit --split test, and every test-split run needs a dated entry in
// research/whatkey/log/.
//
// Usage:
//   dart run tool/whatkey/harness.dart --fixtures <set-dir> \
//     [--split-file <split.json>] [--split development|test] \
//     [--recipe whatKeyPaper2026|whatKeyPaper2026Reflex] \
//     [--detector profile|evidence|progression|hybrid|hmm|bocpd] \
//     [--profiles krumhanslKessler|temperley|temperleyKostkaPayne|
//                 albrechtShanahan] \
//     [--confidence-weighting on|off] [--functional-blend X] \
//     [--progression-blend X] \
//     [--hysteresis N] [--self-transition X] [--emission-temperature X] \
//     [--weighting duration|flat] [--decay-half-life-seconds N] \
//     [--decay-half-life-events N] \
//     [--min-events N] [--margin-floor X] [--mode-tilt X] \
//     [--relative-tilt X] [--relative-cadence-tilt X] \
//     [--relative-evidence-tilt X] [--relative-evidence-window N] \
//     [--cadence-boost X] [--cadence-triad-boost X] \
//     [--cadence-margin-factor X] [--cold-start-tonic-prior X] \
//     [--relative-switch-factor X] \
//     [--fifths-decay X] [--mode-switch-factor X] \
//     [--hazard X] [--max-run-length N] \
//     [--calibration-temperature X] \
//     [--sweep-calibration-temperatures 1,2,3,...] [--out <dir>] \
//     [--claims-file <claims.json>] [--restrict-to <claims.json>] \
//     [--sweep-margin-floors 0,0.02,0.05,...]
//
// With --claims-file (see tool/whatkey/external_baseline.py), detector flags
// are ignored and the externally produced global claims are scored as a
// constant claim per event through the same metrics.
//
// --restrict-to takes the claims.json artifact of a previous run and computes
// coverage/accuracy over only the events that run claimed on (matched-coverage
// comparison). --sweep-margin-floors adds a coverage-accuracy curve from one
// extra detector pass (detector mode only).

import 'dart:convert';
import 'dart:io';

import 'package:whatkey/whatkey.dart';

import 'src/detector_recipe.dart';
import 'src/fixtures.dart';
import 'src/reproducibility.dart';
import 'src/scoring.dart';

void main(List<String> arguments) {
  final options = _Options.parse(arguments);

  final fixtureSet = FixtureSet.load(Directory(options.fixturesDir));
  var fixtures = fixtureSet.fixtures;
  if (options.splitFile != null) {
    final split = SplitFile.load(File(options.splitFile!));
    split.validateAgainst(fixtureSet);
    final titles = split.pieceTitles(options.split).toSet();
    fixtures = [
      for (final fixture in fixtures)
        if (titles.contains(fixture.title)) fixture,
    ];
    if (options.split == 'test') {
      stderr.writeln(
        'WARNING: evaluating the TEST split. The protocol requires a dated '
        'log entry in research/whatkey/log/ for this run.',
      );
    }
  }
  if (fixtures.isEmpty) {
    stderr.writeln('No fixtures selected.');
    exitCode = 1;
    return;
  }

  final claims = options.claimsFile == null
      ? null
      : ClaimsFile.load(File(options.claimsFile!));
  final restrictTo = options.restrictTo == null
      ? null
      : ClaimMask.load(File(options.restrictTo!));
  final detector = claims == null ? options.buildDetector() : null;
  final detectorInfo =
      claims?.detector ??
      {'name': detector!.name, 'configuration': detector.configuration};

  final framesByFixture = <String, List<KeyEstimateFrame>>{};
  final pieces = <PieceScore>[];
  for (final fixture in fixtures) {
    List<KeyEstimateFrame> frames;
    if (claims != null) {
      frames = claims.framesFor(fixture);
    } else {
      detector!.reset();
      frames = [for (final event in fixture.events) detector.onEvent(event)];
    }
    framesByFixture[fixture.id] = frames;
    pieces.add(
      PieceScore.compute(
        fixture,
        frames,
        evaluateMask: restrictTo?.maskFor(fixture),
      ),
    );
  }
  final summary = summarize(pieces);
  final calibration = claims == null
      ? posteriorCalibration(
          fixtures,
          framesByFixture,
          temperature: options.calibrationTemperature,
        )
      : null;
  final calibrationSweep = claims == null
      ? [
          for (final temperature in options.sweepCalibrationTemperatures)
            posteriorCalibration(
              fixtures,
              framesByFixture,
              temperature: temperature,
            ),
        ]
      : const <Map<String, Object?>>[];
  final sweep = options.sweepMarginFloors.isEmpty
      ? null
      : _sweep(options, fixtures);

  final report = <String, Object?>{
    'schema': 'whatkey-harness-report/1',
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'command': 'dart run tool/whatkey/harness.dart ${arguments.join(' ')}',
    'engineCommit': _git(['rev-parse', 'HEAD']),
    'engineLibDirty': _git(['status', '--porcelain', '--', 'lib']).isNotEmpty,
    'fixtures': {
      'set': fixtureSet.name,
      'directory': options.fixturesDir,
      'contentSha256': fixtureSet.contentSha256,
      'source': fixtureSet.source,
      'engineCommit': fixtureSet.manifest['engineCommit'],
    },
    'split': options.splitFile == null
        ? null
        : {'file': options.splitFile, 'name': options.split},
    'detector': detectorInfo,
    'detectorRecipe': options.recipe?.name,
    'restrictedTo': options.restrictTo,
    'sweep': sweep,
    'posteriorCalibration': calibration,
    'calibrationSweep': calibrationSweep.isEmpty ? null : calibrationSweep,
    'protocol': 'research/whatkey/PROTOCOL.md, frozen 2026-07-07',
    'summary': summary,
    'perPiece': [for (final piece in pieces) piece.toJson()],
  };

  final outDir = Directory(
    options.outDir ??
        'build/whatkey-harness/${_basename(options.fixturesDir)}-'
            '${options.splitFile == null ? 'all' : options.split}'
            '${claims != null
                ? '-${detectorInfo['name']}'
                : options.detectorName == 'profile'
                ? ''
                : '-${options.detectorName}'}',
  )..createSync(recursive: true);
  final claimsArtifact = _claimsArtifact(
    detectorInfo,
    fixtures,
    framesByFixture,
  );
  final hashes = resultArtifactHashes(report, claimsArtifact);
  File('${outDir.path}/report.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  File('${outDir.path}/claims.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(claimsArtifact)}\n',
  );
  File('${outDir.path}/hashes.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'schema': 'whatkey-result-hashes/1', 'algorithm': 'sha256', 'canonicalization': canonicalization, 'fixtureSetSha256': fixtureSet.contentSha256, ...hashes})}\n',
  );
  final text = _textReport(report, pieces);
  File('${outDir.path}/report.txt').writeAsStringSync(text);
  stdout.write(text);
  stderr.writeln('Report -> ${outDir.path}');
}

/// Per-event claims artifact written next to every report, so later runs can
/// restrict scoring to exactly these events (--restrict-to).
Map<String, Object?> _claimsArtifact(
  Map<String, Object?> detectorInfo,
  List<LabeledFixture> fixtures,
  Map<String, List<KeyEstimateFrame>> framesByFixture,
) {
  String? wire(KeyEstimateFrame frame) => frame.claim == null
      ? null
      : KeyLabel.of(frame.claim!.tonality).toString();
  return {
    'schema': 'whatkey-claims/1',
    'detector': detectorInfo,
    'claims': {
      for (final fixture in fixtures)
        fixture.id: {
          'events': [
            for (final frame in framesByFixture[fixture.id]!) wire(frame),
          ],
        },
    },
  };
}

/// One extra detector pass at marginFloor 0, then post-hoc thresholds: the
/// coverage-accuracy curve for abstention calibration.
List<Map<String, Object?>> _sweep(
  _Options options,
  List<LabeledFixture> fixtures,
) {
  final detector = options.buildDetector(marginFloorOverride: 0);
  final framesByFixture = <String, List<KeyEstimateFrame>>{
    for (final fixture in fixtures)
      fixture.id: (() {
        detector.reset();
        return [for (final event in fixture.events) detector.onEvent(event)];
      })(),
  };

  return [
    for (final floor in options.sweepMarginFloors)
      (() {
        final pieces = [
          for (final fixture in fixtures)
            PieceScore.compute(
              fixture,
              applyMarginFloor(framesByFixture[fixture.id]!, floor),
            ),
        ];
        final summary = summarize(pieces);
        final accuracy = summary['accuracyOnClaimed'] as Map<String, Object?>;
        return <String, Object?>{
          'marginFloor': floor,
          'coverage': (summary['coverage'] as Map)['meanPerPiece'],
          'exactOnClaimed': accuracy['meanExactPerPiece'],
          'mirexOnClaimed': accuracy['meanMirexPerPiece'],
          'piecesWithClaims': accuracy['piecesWithClaims'],
        };
      })(),
  ];
}

String _textReport(Map<String, Object?> report, List<PieceScore> pieces) {
  final buffer = StringBuffer();
  final fixtures = report['fixtures'] as Map<String, Object?>;
  final detector = report['detector'] as Map<String, Object?>;
  final split = report['split'] as Map<String, Object?>?;
  final summary = report['summary'] as Map<String, Object?>;

  buffer
    ..writeln('WhatKey harness report')
    ..writeln('=' * 60)
    ..writeln(
      'set:       ${fixtures['set']}'
      '${split == null ? ' (all fixtures)' : ' (${split['name']} split)'}',
    )
    ..writeln('detector:  ${detector['name']}')
    ..writeln('config:    ${detector['configuration']}')
    ..writeln(
      'engine:    ${report['engineCommit']}'
      '${report['engineLibDirty'] == true ? ' (lib dirty)' : ''}',
    )
    ..writeln('generated: ${report['generatedAt']}')
    ..writeln('command:   ${report['command']}');
  if (report['restrictedTo'] != null) {
    buffer.writeln(
      'restricted: coverage/accuracy computed only over events claimed in\n'
      '           ${report['restrictedTo']} (streaming metrics use the '
      'full stream)',
    );
  }
  buffer
    ..writeln()
    ..writeln(_summaryBlock(summary));
  final sweep = report['sweep'] as List?;
  if (sweep != null) {
    buffer
      ..writeln('Coverage-accuracy sweep (margin floor varied post hoc)')
      ..write(_sweepTable(sweep.cast<Map<String, Object?>>()))
      ..writeln();
  }
  final calibration = report['posteriorCalibration'] as Map<String, Object?>?;
  if (calibration != null) {
    buffer
      ..writeln('Posterior calibration (exact-labeled events)')
      ..write(_calibrationBlock(calibration))
      ..writeln();
  }
  buffer
    ..writeln('Per piece')
    ..writeln(
      '  events: chord events\n'
      '  cover: fraction of events with a key claim\n'
      '  exact: exact-match accuracy on claimed events\n'
      '  mirex: MIREX-weighted accuracy on claimed events\n'
      '  ttfc: events before the first claim\n'
      '  sw: key switches\n'
      '  spur: spurious switches\n'
      '  amb-ok: ambiguous events handled acceptably\n',
    )
    ..write(_pieceTable(pieces));
  return buffer.toString();
}

String _calibrationBlock(Map<String, Object?> calibration) {
  final all = calibration['allExactLabeledEvents'] as Map<String, Object?>;
  final claimed =
      calibration['claimedExactLabeledEvents'] as Map<String, Object?>;
  final skipped = calibration['skipped'] as Map<String, Object?>;

  String num3(Object? value) =>
      value == null ? '-' : (value as num).toStringAsFixed(3);
  String row(String label, Map<String, Object?> source) =>
      '  ${label.padRight(8)}'
      '  n=${'${source['events']}'.padLeft(5)}'
      '  conf=${num3(source['meanConfidence']).padLeft(5)}'
      '  acc=${num3(source['accuracy']).padLeft(5)}'
      '  ece=${num3(source['expectedCalibrationError']).padLeft(5)}'
      '  nll=${num3(source['meanNegativeLogLikelihood']).padLeft(5)}'
      '  brier=${num3(source['meanBrier']).padLeft(5)}';

  final buffer = StringBuffer()
    ..writeln(row('all', all))
    ..writeln(row('claimed', claimed))
    ..writeln(
      '  skipped: ${skipped['noExactLocalKey']} without exact local key, '
      '${skipped['nonProbabilisticFrame']} non-probabilistic frames',
    );
  return buffer.toString();
}

String _summaryBlock(Map<String, Object?> summary) {
  final coverage = summary['coverage'] as Map<String, Object?>;
  final accuracy = summary['accuracyOnClaimed'] as Map<String, Object?>;
  final ttfc = summary['timeToFirstClaim'] as Map<String, Object?>;
  final switches = summary['switchesPerPiece'] as Map<String, Object?>;
  final spurious = summary['spuriousSwitchesPerPiece'] as Map<String, Object?>;
  final modulation = summary['modulation'] as Map<String, Object?>;
  final lag = modulation['lagEvents'] as Map<String, Object?>;
  final globalKey = summary['globalKey'] as Map<String, Object?>;

  String num2(Object? value) =>
      value == null ? '-' : (value as num).toStringAsFixed(2);
  String dist(Map<String, Object?> d) => d['n'] == 0
      ? '-'
      : 'median ${_trimNum(d['median'])}, p90 ${_trimNum(d['p90'])}';
  String pieces(Object? count) => '$count piece${count == 1 ? '' : 's'}';

  final lines = <(String, String, String)>[
    ('Coverage (mean per piece)', num2(coverage['meanPerPiece']), ''),
    (
      'Accuracy on claimed, exact (mean per piece)',
      num2(accuracy['meanExactPerPiece']),
      '${pieces(accuracy['piecesWithClaims'])} with claims',
    ),
    (
      'Accuracy on claimed, MIREX (mean per piece)',
      num2(accuracy['meanMirexPerPiece']),
      '',
    ),
    (
      'Global key MIREX, final claim',
      num2(globalKey['meanFinalMirex']),
      '${pieces(globalKey['scoredPieces'])} scored',
    ),
    (
      'Global key MIREX, majority claim',
      num2(globalKey['meanMajorityMirex']),
      '',
    ),
    (
      'Time to first claim (events)',
      dist(ttfc),
      '${pieces(ttfc['neverClaimedPieces'])} never claim',
    ),
    ('Switches per piece', dist(switches), ''),
    ('Spurious switches per piece', dist(spurious), ''),
    (
      'Modulations matched',
      '${modulation['matched']}/${modulation['annotatedChanges']}',
      '${modulation['censored']} censored',
    ),
    ('Modulation lag (events)', dist(lag), ''),
  ];

  final buffer = StringBuffer()
    ..writeln(
      'Summary (${summary['pieces']} pieces, '
      '${summary['events']} events)',
    );
  final labelWidth = lines
      .map((line) => line.$1.length)
      .reduce((a, b) => a > b ? a : b);
  final valueWidth = lines
      .map((line) => line.$2.length)
      .reduce((a, b) => a > b ? a : b);
  for (final (label, value, note) in lines) {
    buffer.writeln(
      '  ${label.padRight(labelWidth)}  ${value.padLeft(valueWidth)}'
      '${note.isEmpty ? '' : '  ($note)'}',
    );
  }
  return buffer.toString();
}

String _pieceTable(List<PieceScore> pieces) {
  final header = [
    'piece',
    'events',
    'cover',
    'exact',
    'mirex',
    'ttfc',
    'sw',
    'spur',
    'amb-ok',
  ];
  final rows = <List<String>>[
    header,
    for (final piece in pieces)
      [
        piece.title,
        '${piece.events}',
        piece.coverage.toStringAsFixed(2),
        piece.labeledClaimed == 0
            ? '-'
            : piece.exactOnClaimed.toStringAsFixed(2),
        piece.labeledClaimed == 0
            ? '-'
            : piece.mirexOnClaimed.toStringAsFixed(2),
        '${piece.timeToFirstClaim ?? '-'}',
        '${piece.switches}',
        '${piece.spuriousSwitches}',
        piece.ambiguousEvents == 0
            ? '-'
            : '${piece.ambiguousOk}/${piece.ambiguousEvents}',
      ],
  ];

  final widths = [
    for (var column = 0; column < header.length; column++)
      rows.map((row) => row[column].length).reduce((a, b) => a > b ? a : b),
  ];
  final buffer = StringBuffer();
  for (final (index, row) in rows.indexed) {
    final cells = [
      // Title column left-aligned, numeric columns right-aligned.
      row[0].padRight(widths[0]),
      for (var column = 1; column < row.length; column++)
        row[column].padLeft(widths[column]),
    ];
    buffer.writeln('  ${cells.join('  ')}'.trimRight());
    if (index == 0) {
      buffer.writeln(
        '  ${[for (final width in widths) '-' * width].join('  ')}',
      );
    }
  }
  return buffer.toString();
}

String _sweepTable(List<Map<String, Object?>> sweep) {
  final buffer = StringBuffer()
    ..writeln('  floor  cover  exact  mirex  pieces');
  for (final point in sweep) {
    buffer.writeln(
      [
        '  ${(point['marginFloor'] as num).toStringAsFixed(2).padLeft(5)}',
        (point['coverage'] as num).toStringAsFixed(2).padLeft(5),
        ((point['exactOnClaimed'] as num?)?.toStringAsFixed(2) ?? '-').padLeft(
          5,
        ),
        ((point['mirexOnClaimed'] as num?)?.toStringAsFixed(2) ?? '-').padLeft(
          5,
        ),
        '${point['piecesWithClaims']}'.padLeft(6),
      ].join('  '),
    );
  }
  return buffer.toString();
}

/// Renders whole numbers without a trailing ".0".
String _trimNum(Object? value) {
  final number = value as num;
  return number == number.truncate()
      ? '${number.truncate()}'
      : number.toStringAsFixed(1);
}

String _git(List<String> arguments) =>
    (Process.runSync('git', arguments).stdout as String).trim();

class _Options {
  final String fixturesDir;
  final String? splitFile;
  final String split;
  final String? claimsFile;
  final String? restrictTo;
  final DetectorRecipe? recipe;
  final List<double> sweepMarginFloors;
  final String detectorName;
  final bool? confidenceWeighted;
  final double? functionalBlend;
  final double? progressionBlend;
  final double selfTransition;
  final double emissionTemperature;
  final int hysteresis;
  final KeyProfilePair profiles;
  final bool durationWeighted;
  final int? decayHalfLifeSeconds;
  final double? decayHalfLifeEvents;
  final int? minEvents;
  final double? marginFloor;
  final double modeTilt;
  final double relativeTilt;
  final double relativeCadenceTilt;
  final double relativeEvidenceTilt;
  final int relativeEvidenceWindow;
  final double cadenceBoost;
  final double cadenceTriadBoost;
  final double cadenceMarginFactor;
  final double coldStartTonicPrior;
  final double relativeSwitchFactor;
  final double fifthsDecay;
  final double modeSwitchFactor;
  final double hazard;
  final int maxRunLength;
  final double calibrationTemperature;
  final List<double> sweepCalibrationTemperatures;
  final String? outDir;

  _Options._({
    required this.fixturesDir,
    required this.splitFile,
    required this.split,
    required this.claimsFile,
    required this.restrictTo,
    required this.recipe,
    required this.sweepMarginFloors,
    required this.detectorName,
    required this.confidenceWeighted,
    required this.functionalBlend,
    required this.progressionBlend,
    required this.selfTransition,
    required this.emissionTemperature,
    required this.hysteresis,
    required this.profiles,
    required this.durationWeighted,
    required this.decayHalfLifeSeconds,
    required this.decayHalfLifeEvents,
    required this.minEvents,
    required this.marginFloor,
    required this.modeTilt,
    required this.relativeTilt,
    required this.relativeCadenceTilt,
    required this.relativeEvidenceTilt,
    required this.relativeEvidenceWindow,
    required this.cadenceBoost,
    required this.cadenceTriadBoost,
    required this.cadenceMarginFactor,
    required this.coldStartTonicPrior,
    required this.relativeSwitchFactor,
    required this.fifthsDecay,
    required this.modeSwitchFactor,
    required this.hazard,
    required this.maxRunLength,
    required this.calibrationTemperature,
    required this.sweepCalibrationTemperatures,
    required this.outDir,
  });

  KeyDetector buildDetector({double? marginFloorOverride}) {
    final base = _buildBase(marginFloorOverride: marginFloorOverride);
    return hysteresis <= 1
        ? base
        : ClaimHysteresisDetector(inner: base, minStreak: hysteresis);
  }

  KeyDetector _buildBase({double? marginFloorOverride}) {
    // Per-detector decay defaults: the HMM wants memoryless emissions while
    // the accumulator detectors want the 30 s half-life; 0 disables decay.
    final seconds =
        decayHalfLifeSeconds ??
        (detectorName == 'hmm'
            ? HmmKeyDetector.defaultEmissionHalfLifeSeconds
            : 30);
    // Event-count decay replaces wall-clock decay when set.
    final decay = decayHalfLifeEvents != null || seconds == 0
        ? null
        : Duration(seconds: seconds);
    // The HMM follows current app defaults. Selecting the standalone hybrid
    // explicitly keeps the historical research baseline used by pre-recipe
    // experiment commands (log entries 2026-07-07-04 and -08).
    final hmmDefaults = detectorName == 'hmm';
    final effectiveFunctional =
        functionalBlend ??
        (hmmDefaults
            ? HmmKeyDetector.defaultEmissionFunctionalBlend
            : HybridKeyDetector.researchBaselineFunctionalBlend);
    final effectiveProgression =
        progressionBlend ??
        (hmmDefaults
            ? HmmKeyDetector.defaultEmissionProgressionBlend
            : HybridKeyDetector.researchBaselineProgressionBlend);
    final effectiveConfidence =
        confidenceWeighted ??
        (hmmDefaults ? HmmKeyDetector.defaultEmissionConfidenceWeighted : true);
    // The HMM follows its shipped warmup default (one event; the margin
    // floor is the real gate, whatkey-local log 2026-07-26-15), while the
    // research detectors keep the three-event warmup their constructors and
    // published runs use. The paper contract does not depend on this
    // fallback: recipes pin minEvents explicitly, so recipe runs arrive
    // here non-null.
    final effectiveMinEvents =
        minEvents ?? (hmmDefaults ? HmmKeyDetector.defaultMinEvents : 3);
    return switch (detectorName) {
      'profile' => ProfileCorrelationKeyDetector(
        profiles: profiles,
        durationWeighted: durationWeighted,
        decayHalfLife: decay,
        decayHalfLifeEvents: decayHalfLifeEvents,
        minEvents: effectiveMinEvents,
        marginFloor: marginFloorOverride ?? marginFloor ?? 0.05,
      ),
      'progression' => ProgressionKeyDetector(
        confidenceWeighted: effectiveConfidence,
        durationWeighted: durationWeighted,
        decayHalfLife: decay,
        decayHalfLifeEvents: decayHalfLifeEvents,
        minEvents: effectiveMinEvents,
        marginFloor: marginFloorOverride ?? marginFloor ?? 0.5,
      ),
      'evidence' => WeightedEvidenceKeyDetector(
        confidenceWeighted: effectiveConfidence,
        durationWeighted: durationWeighted,
        decayHalfLife: decay,
        decayHalfLifeEvents: decayHalfLifeEvents,
        minEvents: effectiveMinEvents,
        marginFloor: marginFloorOverride ?? marginFloor ?? 0.5,
      ),
      'hmm' => HmmKeyDetector(
        profiles: profiles,
        durationWeighted: durationWeighted,
        decayHalfLife: decay,
        decayHalfLifeEvents: decayHalfLifeEvents,
        confidenceWeighted: effectiveConfidence,
        functionalBlend: effectiveFunctional,
        progressionBlend: effectiveProgression,
        selfTransition: selfTransition,
        fifthsDecay: fifthsDecay,
        modeSwitchFactor: modeSwitchFactor,
        emissionTemperature: emissionTemperature,
        minEvents: effectiveMinEvents,
        marginFloor:
            marginFloorOverride ??
            marginFloor ??
            HmmKeyDetector.defaultMarginFloor,
        modeTilt: modeTilt,
        relativeTilt: relativeTilt,
        relativeCadenceTilt: relativeCadenceTilt,
        relativeEvidenceTilt: relativeEvidenceTilt,
        relativeEvidenceWindow: relativeEvidenceWindow,
        cadenceBoost: cadenceBoost,
        cadenceTriadBoost: cadenceTriadBoost,
        cadenceMarginFactor: cadenceMarginFactor,
        coldStartTonicPrior: coldStartTonicPrior,
        relativeSwitchFactor: relativeSwitchFactor,
      ),
      'bocpd' => BocpdKeyDetector(
        profiles: profiles,
        durationWeighted: durationWeighted,
        hazard: hazard,
        maxRunLength: maxRunLength,
        emissionTemperature: emissionTemperature,
        modeTilt: modeTilt,
        minEvents: effectiveMinEvents,
        marginFloor:
            marginFloorOverride ??
            marginFloor ??
            HmmKeyDetector.defaultMarginFloor,
      ),
      'hybrid' => HybridKeyDetector(
        profiles: profiles,
        durationWeighted: durationWeighted,
        decayHalfLife: decay,
        decayHalfLifeEvents: decayHalfLifeEvents,
        confidenceWeighted: effectiveConfidence,
        functionalBlend: effectiveFunctional,
        progressionBlend: effectiveProgression,
        minEvents: effectiveMinEvents,
        marginFloor: marginFloorOverride ?? marginFloor ?? 0.05,
      ),
      _ => throw ArgumentError(
        '--detector must be profile, evidence, progression, hybrid, hmm, '
        'or bocpd',
      ),
    };
  }

  static _Options parse(List<String> arguments) {
    final values = <String, String>{};
    for (var i = 0; i < arguments.length; i += 2) {
      final flag = arguments[i];
      if (!flag.startsWith('--') || i + 1 >= arguments.length) {
        throw ArgumentError('Expected --flag value pairs, got: $flag');
      }
      values[flag.substring(2)] = arguments[i + 1];
    }

    final fixturesDir = values.remove('fixtures');
    if (fixturesDir == null) {
      throw ArgumentError('--fixtures <set-dir> is required');
    }
    final splitFile = values.remove('split-file');
    final splitName = values.remove('split');
    if (splitName != null && splitFile == null) {
      throw ArgumentError('--split requires --split-file');
    }
    final split = splitName ?? 'development';
    if (split != 'development' && split != 'test') {
      throw ArgumentError('--split must be development or test');
    }
    final recipe = switch (values.remove('recipe')) {
      null => null,
      final name => DetectorRecipe.values.byName(name),
    };
    const recipeControlledFlags = <String>{
      'detector',
      'confidence-weighting',
      'functional-blend',
      'progression-blend',
      'self-transition',
      'emission-temperature',
      'hysteresis',
      'profiles',
      'weighting',
      'decay-half-life-seconds',
      'decay-half-life-events',
      'min-events',
      'margin-floor',
      'mode-tilt',
      'relative-tilt',
      'relative-cadence-tilt',
      'relative-evidence-tilt',
      'relative-evidence-window',
      'cadence-boost',
      'cadence-triad-boost',
      'cadence-margin-factor',
      'cold-start-tonic-prior',
      'relative-switch-factor',
      'fifths-decay',
      'mode-switch-factor',
      'hazard',
      'max-run-length',
    };
    final recipeConflicts = recipe == null
        ? const <String>[]
        : [
            for (final flag in recipeControlledFlags)
              if (values.containsKey(flag)) '--$flag',
          ];
    if (recipeConflicts.isNotEmpty) {
      throw ArgumentError(
        '--recipe pins every detector option; remove: '
        '${recipeConflicts.join(', ')}',
      );
    }
    final claimsFile = values.remove('claims-file');
    if (recipe != null && claimsFile != null) {
      throw ArgumentError('--recipe cannot be combined with --claims-file');
    }
    final options = _Options._(
      fixturesDir: fixturesDir,
      splitFile: splitFile,
      split: split,
      claimsFile: claimsFile,
      restrictTo: values.remove('restrict-to'),
      recipe: recipe,
      detectorName:
          recipe?.detectorName ?? values.remove('detector') ?? 'profile',
      confidenceWeighted:
          recipe?.confidenceWeighted ??
          switch (values.remove('confidence-weighting')) {
            null => null,
            final raw => raw != 'off',
          },
      functionalBlend:
          recipe?.functionalBlend ??
          switch (values.remove('functional-blend')) {
            null => null,
            final raw => double.parse(raw),
          },
      progressionBlend:
          recipe?.progressionBlend ??
          switch (values.remove('progression-blend')) {
            null => null,
            final raw => double.parse(raw),
          },
      selfTransition:
          recipe?.selfTransition ??
          double.parse(values.remove('self-transition') ?? '0.9'),
      emissionTemperature:
          recipe?.emissionTemperature ??
          double.parse(values.remove('emission-temperature') ?? '0.25'),
      hysteresis:
          recipe?.hysteresis ?? int.parse(values.remove('hysteresis') ?? '1'),
      sweepMarginFloors: [
        for (final floor in (values.remove('sweep-margin-floors') ?? '').split(
          ',',
        ))
          if (floor.trim().isNotEmpty) double.parse(floor),
      ],
      profiles:
          recipe?.profiles ??
          KeyProfilePair.values.byName(
            values.remove('profiles') ?? 'albrechtShanahan',
          ),
      durationWeighted:
          recipe?.durationWeighted ??
          (values.remove('weighting') ?? 'duration') != 'flat',
      decayHalfLifeSeconds: switch (values.remove('decay-half-life-seconds')) {
        null => recipe?.decayHalfLifeSeconds,
        final raw => int.parse(raw),
      },
      decayHalfLifeEvents: switch (values.remove('decay-half-life-events')) {
        null => recipe?.decayHalfLifeEvents,
        final raw => double.parse(raw),
      },
      minEvents:
          recipe?.minEvents ??
          switch (values.remove('min-events')) {
            null => null,
            final raw => int.parse(raw),
          },
      marginFloor: switch (values.remove('margin-floor')) {
        null => recipe?.marginFloor,
        final raw => double.parse(raw),
      },
      modeTilt:
          recipe?.modeTilt ??
          double.parse(
            values.remove('mode-tilt') ?? '${HmmKeyDetector.defaultModeTilt}',
          ),
      relativeTilt:
          recipe?.relativeTilt ??
          double.parse(
            values.remove('relative-tilt') ??
                '${HmmKeyDetector.defaultRelativeTilt}',
          ),
      relativeCadenceTilt:
          recipe?.relativeCadenceTilt ??
          double.parse(
            values.remove('relative-cadence-tilt') ??
                '${HmmKeyDetector.defaultRelativeCadenceTilt}',
          ),
      relativeEvidenceTilt:
          recipe?.relativeEvidenceTilt ??
          double.parse(
            values.remove('relative-evidence-tilt') ??
                '${HmmKeyDetector.defaultRelativeEvidenceTilt}',
          ),
      relativeEvidenceWindow: int.parse(
        values.remove('relative-evidence-window') ??
            '${HmmKeyDetector.defaultRelativeEvidenceWindow}',
      ),
      cadenceBoost:
          recipe?.cadenceBoost ??
          double.parse(
            values.remove('cadence-boost') ??
                '${HmmKeyDetector.defaultCadenceBoost}',
          ),
      cadenceTriadBoost:
          recipe?.cadenceTriadBoost ??
          double.parse(
            values.remove('cadence-triad-boost') ??
                '${HmmKeyDetector.defaultCadenceTriadBoost}',
          ),
      cadenceMarginFactor:
          recipe?.cadenceMarginFactor ??
          double.parse(
            values.remove('cadence-margin-factor') ??
                '${HmmKeyDetector.defaultCadenceMarginFactor}',
          ),
      coldStartTonicPrior:
          recipe?.coldStartTonicPrior ??
          double.parse(
            values.remove('cold-start-tonic-prior') ??
                '${HmmKeyDetector.defaultColdStartTonicPrior}',
          ),
      relativeSwitchFactor:
          recipe?.relativeSwitchFactor ??
          double.parse(
            values.remove('relative-switch-factor') ??
                '${HmmKeyDetector.defaultRelativeSwitchFactor}',
          ),
      fifthsDecay: double.parse(values.remove('fifths-decay') ?? '0.5'),
      modeSwitchFactor: double.parse(
        values.remove('mode-switch-factor') ?? '0.5',
      ),
      hazard: double.parse(
        values.remove('hazard') ?? '${BocpdKeyDetector.defaultHazard}',
      ),
      maxRunLength: int.parse(
        values.remove('max-run-length') ??
            '${BocpdKeyDetector.defaultMaxRunLength}',
      ),
      calibrationTemperature: double.parse(
        values.remove('calibration-temperature') ?? '1',
      ),
      sweepCalibrationTemperatures: [
        for (final value
            in (values.remove('sweep-calibration-temperatures') ?? '').split(
              ',',
            ))
          if (value.trim().isNotEmpty) double.parse(value),
      ],
      outDir: values.remove('out'),
    );
    if (values.isNotEmpty) {
      throw ArgumentError('Unknown flags: ${values.keys.toList()}');
    }
    if (options.sweepMarginFloors.isNotEmpty && options.claimsFile != null) {
      throw ArgumentError('--sweep-margin-floors needs detector mode');
    }
    if (options.sweepMarginFloors.isNotEmpty && options.hysteresis > 1) {
      // The sweep applies the margin floor post hoc, which is only valid when
      // claims do not feed back into detector state; hysteresis feeds claims
      // into its streak state.
      throw ArgumentError('--sweep-margin-floors cannot combine --hysteresis');
    }
    return options;
  }
}

String _basename(String path) =>
    path.split('/').where((part) => part.isNotEmpty).last;
