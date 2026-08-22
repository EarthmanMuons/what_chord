import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:whatchord_app/features/key/key.dart';

import '../../tool/src/chord_id_engine.dart';
import '../../tool/whatkey/src/fixtures.dart';
import '../../tool/whatkey/src/reproducibility.dart';
import '../../tool/whatkey/src/scoring.dart';

Map<String, Object?> _eventJson(
  int index, {
  String? localKey,
  List<String>? acceptableKeys,
  int durationMs = 2000,
}) => {
  'index': index,
  'timestampMs': index * 2000,
  'durationMs': durationMs,
  'midiNotes': [48, 60, 64, 67],
  'pcMask': 0x91,
  'bassPc': 0,
  'noteCount': 4,
  'candidates': [
    {
      'rootPc': 0,
      'bassPc': 0,
      'quality': 'major',
      'extensions': <String>[],
      'presentIntervalsMask': 0x91,
      'cost': 0.0,
    },
  ],
  'labels': {'localKey': localKey, 'acceptableKeys': ?acceptableKeys},
};

LabeledFixture _fixture(List<Map<String, Object?>> events) {
  final dir = Directory.systemTemp.createTempSync('whatkey-scoring-test');
  addTearDown(() => dir.deleteSync(recursive: true));
  File('${dir.path}/manifest.json').writeAsStringSync(
    jsonEncode({
      'schema': 'whatkey-manifest/1',
      'set': 'test-set',
      'context': 'C:maj',
      'source': {'type': 'test'},
      'fixtures': [
        {
          'file': 'fixture.json',
          'id': 'test-set/fixture',
          'events': events.length,
        },
      ],
    }),
  );
  File('${dir.path}/fixture.json').writeAsStringSync(
    jsonEncode({
      'schema': 'whatkey-fixture/1',
      'id': 'test-set/fixture',
      'title': 'fixture',
      'labels': {},
      'events': events,
    }),
  );
  return FixtureSet.load(dir).fixtures.single;
}

KeyEstimateFrame _claim(String wire) {
  final estimate = KeyEstimate(tonality: parseTonality(wire), confidence: 1);
  return KeyEstimateFrame(ranked: [estimate], claim: estimate);
}

KeyEstimateFrame _posteriorFrame(
  Map<String, double> posterior, {
  bool claim = true,
}) {
  final ranked = [
    for (final entry in posterior.entries)
      KeyEstimate(tonality: parseTonality(entry.key), confidence: entry.value),
  ]..sort((a, b) => b.confidence.compareTo(a.confidence));
  return claim
      ? KeyEstimateFrame(ranked: ranked, claim: ranked.first)
      : KeyEstimateFrame.abstain(ranked);
}

const _abstain = KeyEstimateFrame.abstain([]);

void main() {
  const cMajor = KeyLabel(0, isMinor: false);
  const aMinor = KeyLabel(9, isMinor: true);

  test('canonical JSON hash ignores map order', () {
    final hash = canonicalJsonSha256({
      'b': 2,
      'a': [1, true],
    });
    expect(
      hash,
      canonicalJsonSha256({
        'a': [1, true],
        'b': 2,
      }),
    );
    expect(
      hash,
      '16a5b9826a81dd3e37eb091f70b193b43807f6f51851ee61fc7ef0ee809b5255',
    );
  });

  test('hashed result fields match the reproduction lock', () {
    // The lock, Python REPORT_DATA_KEYS, and this list must stay identical or
    // `reproducibility.py verify` reports a spurious MISMATCH. Python is checked
    // against the lock at verify time; this pins the Dart side to the same lock.
    final lock = jsonDecode(
      File('research/whatkey/results/reproduction-v2026.7.14.json')
          .readAsStringSync(),
    ) as Map<String, dynamic>;
    expect(lock['resultDataFields'], resultDataFields);
  });

  test(
    'canonical hash rejects floats that Dart and Python format differently',
    () {
      expect(() => canonicalJsonSha256({'cost': 1e-5}), throwsStateError);
      expect(() => canonicalJsonSha256({'cost': 1e16}), throwsStateError);
      expect(() => canonicalJsonSha256({'cost': double.nan}), throwsStateError);
      // In-band values (including zero) hash without complaint.
      expect(
        () => canonicalJsonSha256({'cost': 0.0, 'weight': 2.5}),
        returnsNormally,
      );
    },
  );

  group('mirexWeight', () {
    test('exact match scores 1.0', () {
      expect(mirexWeight(cMajor, cMajor), 1.0);
      expect(mirexWeight(aMinor, aMinor), 1.0);
    });

    test('perfect fifth in either direction scores 0.5', () {
      const gMajor = KeyLabel(7, isMinor: false);
      const fMajor = KeyLabel(5, isMinor: false);
      expect(mirexWeight(gMajor, cMajor), 0.5);
      expect(mirexWeight(fMajor, cMajor), 0.5);
      expect(mirexWeight(KeyLabel(4, isMinor: true), aMinor), 0.5);
      expect(mirexWeight(KeyLabel(2, isMinor: true), aMinor), 0.5);
    });

    test('relative major/minor scores 0.3 both ways', () {
      expect(mirexWeight(aMinor, cMajor), 0.3);
      expect(mirexWeight(cMajor, aMinor), 0.3);
    });

    test('parallel major/minor scores 0.2', () {
      expect(mirexWeight(KeyLabel(0, isMinor: true), cMajor), 0.2);
      expect(mirexWeight(KeyLabel(9, isMinor: false), aMinor), 0.2);
    });

    test('unrelated keys score 0.0', () {
      expect(mirexWeight(KeyLabel(1, isMinor: false), cMajor), 0.0);
      expect(mirexWeight(KeyLabel(6, isMinor: true), cMajor), 0.0);
    });

    test('fifth relation requires matching mode', () {
      expect(mirexWeight(KeyLabel(7, isMinor: true), cMajor), 0.0);
    });
  });

  group('KeyLabel', () {
    test('parses wire format', () {
      expect(KeyLabel.parse('C:maj').matches(cMajor), isTrue);
      expect(KeyLabel.parse('A:min').matches(aMinor), isTrue);
      expect(
        KeyLabel.parse('F#:min').matches(KeyLabel(6, isMinor: true)),
        isTrue,
      );
      expect(
        KeyLabel.parse('Bb:maj').matches(KeyLabel(10, isMinor: false)),
        isTrue,
      );
    });
  });

  group('PieceScore', () {
    test('coverage and accuracy-on-claimed treat abstention as no error', () {
      final fixture = _fixture([
        for (var i = 0; i < 4; i++) _eventJson(i, localKey: 'C:maj'),
      ]);
      final score = PieceScore.compute(fixture, [
        _abstain,
        _claim('C:maj'),
        _claim('G:maj'),
        _claim('C:maj'),
      ]);

      expect(score.coverage, 0.75);
      expect(score.labeledClaimed, 3);
      expect(score.exactOnClaimed, closeTo(2 / 3, 1e-9));
      expect(score.mirexOnClaimed, closeTo((1 + 0.5 + 1) / 3, 1e-9));
      expect(score.timeToFirstClaim, 1);
    });

    test('switches are counted between consecutive claims only', () {
      final fixture = _fixture([
        for (var i = 0; i < 4; i++) _eventJson(i, localKey: 'C:maj'),
      ]);
      final sameAcrossAbstain = PieceScore.compute(fixture, [
        _claim('C:maj'),
        _abstain,
        _claim('C:maj'),
        _abstain,
      ]);
      expect(sameAcrossAbstain.switches, 0);

      final changedAcrossAbstain = PieceScore.compute(fixture, [
        _claim('C:maj'),
        _abstain,
        _claim('G:maj'),
        _abstain,
      ]);
      expect(changedAcrossAbstain.switches, 1);
      // Annotation never changed, so the switch is spurious.
      expect(changedAcrossAbstain.spuriousSwitches, 1);
    });

    test(
      'spurious-switch summaries exclude pieces without an exact reference',
      () {
        final labeled = PieceScore.compute(
          _fixture([
            _eventJson(0, localKey: 'C:maj'),
            _eventJson(1, localKey: 'C:maj'),
          ]),
          [_claim('C:maj'), _claim('G:maj')],
        );
        final unlabeled = PieceScore.compute(
          _fixture([_eventJson(0), _eventJson(1)]),
          [_claim('C:maj'), _claim('G:maj')],
        );

        final summary = summarize([labeled, unlabeled]);
        final switches = summary['switchesPerPiece'] as Map<String, Object?>;
        final spurious =
            summary['spuriousSwitchesPerPiece'] as Map<String, Object?>;

        expect(switches['n'], 2);
        expect(switches['median'], 1);
        expect(spurious['n'], 1);
        expect(spurious['median'], 1);
        expect(unlabeled.switches, 1);
        expect(unlabeled.spuriousSwitches, 0);
      },
    );

    test(
      'modulation lag counts events until the detector reaches the new key',
      () {
        final fixture = _fixture([
          _eventJson(0, localKey: 'C:maj'),
          _eventJson(1, localKey: 'C:maj'),
          _eventJson(2, localKey: 'G:maj'),
          _eventJson(3, localKey: 'G:maj'),
          _eventJson(4, localKey: 'G:maj'),
        ]);
        final matched = PieceScore.compute(fixture, [
          _claim('C:maj'),
          _claim('C:maj'),
          _claim('C:maj'),
          _claim('G:maj'),
          _claim('G:maj'),
        ]);
        expect(matched.annotatedChanges, 1);
        expect(matched.modulationLags, [1]);
        expect(matched.censoredModulations, 0);
        // The C->G switch at the annotated change is not spurious.
        expect(matched.spuriousSwitches, 0);

        final censored = PieceScore.compute(fixture, [
          for (var i = 0; i < 5; i++) _claim('C:maj'),
        ]);
        expect(censored.modulationLags, isEmpty);
        expect(censored.censoredModulations, 1);
      },
    );

    test('ambiguous events accept abstention or acceptable keys and stay out '
        'of accuracy pools', () {
      final fixture = _fixture([
        _eventJson(0, acceptableKeys: ['A:min', 'C:maj']),
        _eventJson(1, acceptableKeys: ['A:min', 'C:maj']),
        _eventJson(2, acceptableKeys: ['A:min', 'C:maj']),
      ]);
      final score = PieceScore.compute(fixture, [
        _abstain,
        _claim('A:min'),
        _claim('D:maj'),
      ]);
      expect(score.ambiguousEvents, 3);
      expect(score.ambiguousOk, 2);
      expect(score.labeledClaimed, 0);
    });

    test('claims file scores a constant global claim on every event', () {
      final fixture = _fixture([
        for (var i = 0; i < 3; i++) _eventJson(i, localKey: 'C:maj'),
      ]);
      final dir = Directory.systemTemp.createTempSync('whatkey-claims-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/stub.claims.json')
        ..writeAsStringSync(
          jsonEncode({
            'schema': 'whatkey-claims/1',
            'detector': {'name': 'stub', 'configuration': 'test'},
            'claims': {
              'test-set/fixture': {'global': 'C:maj'},
            },
          }),
        );
      final claims = ClaimsFile.load(file);

      final frames = claims.framesFor(fixture);
      expect(frames, hasLength(3));
      final score = PieceScore.compute(fixture, frames);
      expect(score.coverage, 1.0);
      expect(score.exactOnClaimed, 1.0);
      expect(score.switches, 0);

      final empty = ClaimsFile.load(
        File('${dir.path}/empty.claims.json')..writeAsStringSync(
          jsonEncode({
            'schema': 'whatkey-claims/1',
            'detector': {'name': 'stub', 'configuration': 'test'},
            'claims': <String, Object?>{},
          }),
        ),
      );
      expect(() => empty.framesFor(fixture), throwsStateError);
    });

    test('claims file replays per-event claims and abstentions', () {
      final fixture = _fixture([
        for (var i = 0; i < 3; i++) _eventJson(i, localKey: 'C:maj'),
      ]);
      final dir = Directory.systemTemp.createTempSync('whatkey-claims-test');
      addTearDown(() => dir.deleteSync(recursive: true));
      final claims = ClaimsFile.load(
        File('${dir.path}/events.claims.json')..writeAsStringSync(
          jsonEncode({
            'schema': 'whatkey-claims/1',
            'detector': {'name': 'stub', 'configuration': 'test'},
            'claims': {
              'test-set/fixture': {
                'events': ['C:maj', null, 'G:maj'],
              },
            },
          }),
        ),
      );

      final score = PieceScore.compute(fixture, claims.framesFor(fixture));

      expect(score.claimed, 2);
      expect(score.timeToFirstClaim, 0);
      expect(score.switches, 1);
      expect(score.spuriousSwitches, 1);

      final mismatched = ClaimsFile.load(
        File('${dir.path}/mismatched.claims.json')..writeAsStringSync(
          jsonEncode({
            'schema': 'whatkey-claims/1',
            'detector': {'name': 'stub', 'configuration': 'test'},
            'claims': {
              'test-set/fixture': {
                'events': ['C:maj'],
              },
            },
          }),
        ),
      );
      expect(() => mismatched.framesFor(fixture), throwsStateError);
    });

    test('evaluate mask restricts coverage and accuracy, not streaming', () {
      final fixture = _fixture([
        for (var i = 0; i < 4; i++) _eventJson(i, localKey: 'C:maj'),
      ]);
      final frames = [
        _claim('C:maj'),
        _claim('G:maj'),
        _abstain,
        _claim('C:maj'),
      ];
      final unrestricted = PieceScore.compute(fixture, frames);
      final restricted = PieceScore.compute(
        fixture,
        frames,
        evaluateMask: const [true, false, false, true],
      );

      expect(restricted.events, 2);
      expect(restricted.claimed, 2);
      expect(restricted.coverage, 1.0);
      // The wrong G claim at index 1 is masked out of the accuracy pool.
      expect(restricted.exactOnClaimed, 1.0);
      expect(unrestricted.exactOnClaimed, closeTo(2 / 3, 1e-9));
      // Streaming metrics are unchanged by the mask.
      expect(restricted.switches, unrestricted.switches);
      expect(restricted.timeToFirstClaim, unrestricted.timeToFirstClaim);
    });

    test('applyMarginFloor abstains claims below the post-hoc floor', () {
      KeyEstimateFrame withMargin(double top, double second) {
        final first = KeyEstimate(
          tonality: parseTonality('C:maj'),
          confidence: top,
        );
        final ranked = [
          first,
          KeyEstimate(tonality: parseTonality('G:maj'), confidence: second),
        ];
        return KeyEstimateFrame(ranked: ranked, claim: first);
      }

      final frames = [withMargin(0.9, 0.8), withMargin(0.9, 0.5), _abstain];
      final floored = applyMarginFloor(frames, 0.2);
      expect(floored[0].isAbstention, isTrue);
      expect(floored[0].ranked, isNotEmpty);
      expect(floored[1].isAbstention, isFalse);
      expect(floored[2].isAbstention, isTrue);
    });

    test('global key scores final and duration-weighted majority claims', () {
      final fixture = _fixture([
        _eventJson(0, localKey: 'C:maj', durationMs: 4000),
        _eventJson(1, localKey: 'C:maj', durationMs: 4000),
        _eventJson(2, localKey: 'C:maj', durationMs: 1000),
      ]);
      final score = PieceScore.compute(fixture, [
        _claim('C:maj'),
        _claim('C:maj'),
        _claim('G:maj'),
      ]);
      expect(score.globalTruth?.matches(cMajor), isTrue);
      expect(score.globalFinalMirex, 0.5);
      expect(score.globalMajorityMirex, 1.0);
    });

    test('posterior calibration reports top-label reliability', () {
      final fixture = _fixture([
        _eventJson(0, localKey: 'C:maj'),
        _eventJson(1, localKey: 'C:maj'),
        _eventJson(2, localKey: 'C:maj'),
        _eventJson(3, acceptableKeys: ['C:maj', 'A:min']),
      ]);
      final calibration = posteriorCalibration(
        [fixture],
        {
          fixture.id: [
            _posteriorFrame({'C:maj': 0.9, 'G:maj': 0.1}),
            _posteriorFrame({'G:maj': 0.8, 'C:maj': 0.2}),
            _posteriorFrame({'C:maj': 0.6, 'G:maj': 0.4}, claim: false),
            _posteriorFrame({'C:maj': 0.7, 'A:min': 0.3}),
          ],
        },
      );

      final all = calibration['allExactLabeledEvents'] as Map<String, Object?>;
      final claimed =
          calibration['claimedExactLabeledEvents'] as Map<String, Object?>;
      final skipped = calibration['skipped'] as Map<String, Object?>;

      expect(all['events'], 3);
      expect(all['accuracy'], closeTo(2 / 3, 1e-9));
      expect(all['meanConfidence'], closeTo((0.9 + 0.8 + 0.6) / 3, 1e-9));
      expect(all['meanTruthProbability'], closeTo((0.9 + 0.2 + 0.6) / 3, 1e-9));
      expect(claimed['events'], 2);
      expect(claimed['accuracy'], 0.5);
      expect(skipped['noExactLocalKey'], 1);
      expect(skipped['nonProbabilisticFrame'], 0);
    });
  });
}
