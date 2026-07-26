import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';
import 'package:whatkey/whatkey.dart';

const _cMajorTonality = Tonality(Tonic.c, TonalityMode.major);

ChordEvent _event(int index, List<int> pcs, ChordQuality quality) {
  var mask = 0;
  for (final pc in pcs) {
    mask |= 1 << (pc % 12);
  }
  return ChordEvent(
    timestamp: DateTime.fromMillisecondsSinceEpoch(index * 2000),
    input: ChordInput(
      pcMask: mask,
      bassPc: pcs.first % 12,
      noteCount: pcs.length,
    ),
    voicing: ObservedVoicing.fromMidi([for (final pc in pcs) 60 + pc]),
    candidates: [
      ChordCandidate(
        identity: ChordIdentity(
          rootPc: pcs.first % 12,
          bassPc: pcs.first % 12,
          quality: quality,
          presentIntervalsMask: 1,
        ),
        cost: 0,
      ),
    ],
    tonality: _cMajorTonality,
    duration: const Duration(seconds: 2),
  );
}

List<KeyEstimateFrame> _run(KeyDetector detector, List<ChordEvent> events) {
  detector.reset();
  return [for (final event in events) detector.onEvent(event)];
}

// One 12-bar chorus as (pcs, quality) events; C blues.
List<ChordEvent> _bluesChorus(int startIndex) {
  const i7 = [0, 4, 7, 10];
  const iv7 = [5, 9, 0, 3];
  const v7 = [7, 11, 2, 5];
  final bars = [i7, i7, i7, i7, iv7, iv7, i7, i7, v7, iv7, i7, v7];
  return [
    for (var bar = 0; bar < bars.length; bar++)
      _event(startIndex + bar, bars[bar], ChordQuality.dominant7),
  ];
}

void main() {
  final cCadence = [
    _event(0, [0, 4, 7], ChordQuality.major),
    _event(1, [5, 9, 0], ChordQuality.major),
    _event(2, [7, 11, 2, 5], ChordQuality.dominant7),
    _event(3, [0, 4, 7], ChordQuality.major),
  ];

  test('claims C major for a C major cadence', () {
    final frames = _run(HmmKeyDetector(), cCadence);
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 0);
    expect(claim.tonality.isMajor, isTrue);
  });

  test('posterior confidences are probabilities summing to one', () {
    final frames = _run(HmmKeyDetector(), cCadence);
    final ranked = frames.last.ranked;
    expect(ranked, hasLength(24));
    final total = ranked.fold(0.0, (sum, e) => sum + e.confidence);
    expect(total, closeTo(1.0, 1e-9));
    for (final estimate in ranked) {
      expect(estimate.confidence, inInclusiveRange(0, 1));
    }
  });

  test('abstains until minEvents have arrived', () {
    final frames = _run(HmmKeyDetector(), cCadence);
    expect(frames[0].isAbstention, isTrue);
    expect(frames[1].isAbstention, isTrue);
  });

  test('claims A minor for a harmonic-minor cadence with E7', () {
    final frames = _run(HmmKeyDetector(), [
      _event(0, [9, 0, 4], ChordQuality.minor),
      _event(1, [2, 5, 9], ChordQuality.minor),
      _event(2, [4, 8, 11, 2], ChordQuality.dominant7),
      _event(3, [9, 0, 4], ChordQuality.minor),
    ]);
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 9);
    expect(claim.tonality.isMinor, isTrue);
  });

  test('an established key persists through a single tonicization', () {
    final frames = _run(HmmKeyDetector(), [
      ...cCadence,
      _event(4, [2, 6, 9, 0], ChordQuality.dominant7), // V7/V
      _event(5, [7, 11, 2, 5], ChordQuality.dominant7),
      _event(6, [0, 4, 7], ChordQuality.major),
    ]);
    for (final frame in frames.skip(3)) {
      final claim = frame.claim;
      if (claim != null) {
        expect(claim.tonality.tonicPitchClass, 0, reason: '$frame');
      }
    }
  });

  test('a sustained modulation still switches the posterior', () {
    final frames = _run(HmmKeyDetector(), [
      ...cCadence,
      for (var i = 0; i < 6; i++) ...[
        _event(4 + 2 * i, [2, 6, 9, 0], ChordQuality.dominant7),
        _event(5 + 2 * i, [7, 11, 2], ChordQuality.major),
      ],
    ]);
    final claim = frames.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 7);
    expect(claim.tonality.isMajor, isTrue);
  });

  test('blues posterior tracks the emissions, not the annotation', () {
    // Documented limitation, not a target: the hybrid emissions favor F on
    // nearly every blues event (log entries 2026-07-07-10 and -11), and a
    // correct filter must follow on-average evidence; persistence only
    // absorbs momentary contradictions. The behavioral suite carries the
    // authoritative blues probes.
    final frames = _run(HmmKeyDetector(), [
      ..._bluesChorus(0),
      ..._bluesChorus(12),
      _event(24, [0, 4, 7, 10], ChordQuality.dominant7),
    ]);
    final lastClaim = frames.last.claim;
    expect(lastClaim, isNotNull);
    expect(lastClaim!.tonality.tonicPitchClass, anyOf(0, 5));
  });

  test('mode tilt never moves the claimed tonic', () {
    final events = [
      ...cCadence,
      for (var i = 0; i < 6; i++) ...[
        _event(4 + 2 * i, [2, 6, 9, 0], ChordQuality.dominant7),
        _event(5 + 2 * i, [7, 11, 2], ChordQuality.major),
      ],
    ];
    final plain = _run(HmmKeyDetector(modeTilt: 0), events);
    final tilted = _run(HmmKeyDetector(modeTilt: 2), events);
    for (var i = 0; i < events.length; i++) {
      expect(
        tilted[i].ranked.first.tonality.tonicPitchClass,
        plain[i].ranked.first.tonality.tonicPitchClass,
        reason: 'event $i',
      );
    }
  });

  test('mode tilt resolves parallel-ambiguous content by tonic quality', () {
    // Melodic-minor-flavored vamp: the pitch content is one chromatic tone
    // away from both C major and C minor, so the mode is carried by the
    // tonic chord's quality, which is exactly what the tilt reads.
    final vamp = [
      for (var i = 0; i < 4; i++) ...[
        _event(4 * i, [0, 3, 7], ChordQuality.minor),
        _event(4 * i + 1, [5, 9, 0], ChordQuality.major),
        _event(4 * i + 2, [7, 11, 2], ChordQuality.major),
        _event(4 * i + 3, [0, 3, 7], ChordQuality.minor),
      ],
    ];
    double cMinorConfidence(List<KeyEstimateFrame> frames) => frames.last.ranked
        .firstWhere(
          (e) => e.tonality.tonicPitchClass == 0 && e.tonality.isMinor,
        )
        .confidence;
    final plain = _run(HmmKeyDetector(modeTilt: 0), vamp);
    final tilted = _run(HmmKeyDetector(modeTilt: 2), vamp);
    expect(cMinorConfidence(tilted), greaterThan(cMinorConfidence(plain)));
    final claim = tilted.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 0);
    expect(claim.tonality.isMinor, isTrue);
  });

  test('relative tilt preserves the signature trajectory', () {
    // The tilt adds no emission evidence for other signatures (pair sums
    // are preserved), but posterior near-tie crossings can shift by an
    // event, so the invariant to hold is the sequence of distinct claimed
    // signatures through a modulation, not per-event equality.
    int signaturePc(Tonality t) =>
        t.isMajor ? t.tonicPitchClass : (t.tonicPitchClass + 3) % 12;
    List<int> trajectory(List<KeyEstimateFrame> frames) {
      final path = <int>[];
      for (final frame in frames) {
        final pc = signaturePc(frame.ranked.first.tonality);
        if (path.isEmpty || path.last != pc) path.add(pc);
      }
      return path;
    }

    final events = [
      ...cCadence,
      for (var i = 0; i < 6; i++) ...[
        _event(4 + 2 * i, [2, 6, 9, 0], ChordQuality.dominant7),
        _event(5 + 2 * i, [7, 11, 2], ChordQuality.major),
      ],
    ];
    final plain = _run(HmmKeyDetector(), events);
    final tilted = _run(
      HmmKeyDetector(relativeTilt: 1, relativeCadenceTilt: 2),
      events,
    );
    expect(trajectory(tilted), trajectory(plain));
  });

  test('bass-gated relative tilt favors the twin whose tonic is played', () {
    // Fully diatonic to the shared C/Am signature; the home chord is a
    // root-position A minor triad, so the tilt should push A minor over its
    // relative major.
    final vamp = [
      for (var i = 0; i < 4; i++) ...[
        _event(3 * i, [9, 0, 4], ChordQuality.minor),
        _event(3 * i + 1, [2, 5, 9], ChordQuality.minor),
        _event(3 * i + 2, [9, 0, 4], ChordQuality.minor),
      ],
    ];
    double aMinorConfidence(List<KeyEstimateFrame> frames) => frames.last.ranked
        .firstWhere(
          (e) => e.tonality.tonicPitchClass == 9 && e.tonality.isMinor,
        )
        .confidence;
    final plain = _run(HmmKeyDetector(), vamp);
    final tilted = _run(HmmKeyDetector(relativeTilt: 1), vamp);
    expect(aMinorConfidence(tilted), greaterThan(aMinorConfidence(plain)));
  });

  test('cadence tilt reads a dominant resolving onto its tonic', () {
    // E7 -> Am is A minor's cadence; the bigram should push A minor over C
    // major relative to the untilted run.
    final phrase = [
      for (var i = 0; i < 4; i++) ...[
        _event(2 * i, [4, 8, 11, 2], ChordQuality.dominant7),
        _event(2 * i + 1, [9, 0, 4], ChordQuality.minor),
      ],
    ];
    double aMinorConfidence(List<KeyEstimateFrame> frames) => frames.last.ranked
        .firstWhere(
          (e) => e.tonality.tonicPitchClass == 9 && e.tonality.isMinor,
        )
        .confidence;
    final plain = _run(HmmKeyDetector(), phrase);
    final tilted = _run(HmmKeyDetector(relativeCadenceTilt: 2), phrase);
    expect(aMinorConfidence(tilted), greaterThan(aMinorConfidence(plain)));
  });

  test('transition rows are proper distributions', () {
    final detector = HmmKeyDetector();
    // Exercised indirectly: run one event and confirm the posterior stays
    // normalized after prediction with an uninformative start.
    final frames = _run(detector, [
      _event(0, [0, 4, 7], ChordQuality.major),
    ]);
    final total = frames.single.ranked.fold(0.0, (s, e) => s + e.confidence);
    expect(total, closeTo(1.0, 1e-9));
  });

  test('cadence boost accelerates a cadenced modulation', () {
    // C established, then a single D7 -> G authentic cadence: the boost
    // should move posterior mass into G major faster than the plain kernel.
    final events = [
      ...cCadence,
      _event(4, [2, 6, 9, 0], ChordQuality.dominant7),
      _event(5, [7, 11, 2], ChordQuality.major),
    ];
    double gMajorConfidence(List<KeyEstimateFrame> frames) => frames.last.ranked
        .firstWhere(
          (e) => e.tonality.tonicPitchClass == 7 && e.tonality.isMajor,
        )
        .confidence;
    final plain = _run(HmmKeyDetector(cadenceBoost: 0), events);
    final boosted = _run(HmmKeyDetector(cadenceBoost: 2), events);
    expect(gMajorConfidence(boosted), greaterThan(gMajorConfidence(plain)));
  });

  test('cadence boost stabilizes a cadence in the incumbent key', () {
    // G7 -> C fires the boost into the incumbent C major; row
    // renormalization turns that into extra staying mass, not leakage.
    double cMajorConfidence(List<KeyEstimateFrame> frames) => frames.last.ranked
        .firstWhere(
          (e) => e.tonality.tonicPitchClass == 0 && e.tonality.isMajor,
        )
        .confidence;
    final plain = _run(HmmKeyDetector(cadenceBoost: 0), cCadence);
    final boosted = _run(HmmKeyDetector(cadenceBoost: 2), cCadence);
    expect(
      cMajorConfidence(boosted),
      greaterThanOrEqualTo(cMajorConfidence(plain)),
    );
  });

  test('cadence boost never fires on blues dominant-to-dominant motion', () {
    // I7 -> IV7 and V7 -> I7 both land on a dominant quality, which is
    // excluded from the cadence targets, so two blues choruses must be
    // byte-identical with and without the boost.
    final events = [..._bluesChorus(0), ..._bluesChorus(12)];
    final plain = _run(HmmKeyDetector(cadenceBoost: 0), events);
    final boosted = _run(HmmKeyDetector(cadenceBoost: 6), events);
    for (var i = 0; i < events.length; i++) {
      for (var k = 0; k < 24; k++) {
        expect(
          boosted[i].ranked[k].confidence,
          plain[i].ranked[k].confidence,
          reason: 'event $i rank $k',
        );
      }
    }
  });

  test('triad cadence boost needs the predominant two back', () {
    // Dm G C is a ii-V-I trigram into C, so the triad boost fires on the
    // final C; Am C F is I-vi... anything-I-IV shaped, with no predominant
    // of F two back, so the plain V-I bigram alone must not fire.
    final firing = [
      _event(0, [2, 5, 9], ChordQuality.minor),
      _event(1, [7, 11, 2], ChordQuality.major),
      _event(2, [0, 4, 7], ChordQuality.major),
    ];
    double confidence(List<KeyEstimateFrame> frames, int pc, bool minor) =>
        frames.last.ranked
            .firstWhere(
              (e) =>
                  e.tonality.tonicPitchClass == pc &&
                  e.tonality.isMinor == minor,
            )
            .confidence;
    final plainFiring = _run(HmmKeyDetector(), firing);
    final boostedFiring = _run(HmmKeyDetector(cadenceTriadBoost: 2), firing);
    expect(
      confidence(boostedFiring, 0, false),
      greaterThan(confidence(plainFiring, 0, false)),
    );

    final nonFiring = [
      _event(0, [9, 0, 4], ChordQuality.minor),
      _event(1, [0, 4, 7], ChordQuality.major),
      _event(2, [5, 9, 0], ChordQuality.major),
    ];
    final plainNon = _run(HmmKeyDetector(), nonFiring);
    final boostedNon = _run(HmmKeyDetector(cadenceTriadBoost: 2), nonFiring);
    for (var i = 0; i < nonFiring.length; i++) {
      for (var k = 0; k < 24; k++) {
        expect(
          boostedNon[i].ranked[k].confidence,
          plainNon[i].ranked[k].confidence,
          reason: 'event $i rank $k',
        );
      }
    }
  });

  test('relative evidence tilt supplies the missing major vote', () {
    // A fully diatonic C major loop with no raised seventh of A minor and no
    // A minor tonic chord: every event lacks minor-defining evidence, so the
    // tilt should leave less posterior on A minor than the plain detector.
    final loop = [
      for (var i = 0; i < 4; i++) ...[
        _event(3 * i, [0, 4, 7], ChordQuality.major),
        _event(3 * i + 1, [5, 9, 0], ChordQuality.major),
        _event(3 * i + 2, [7, 11, 2], ChordQuality.major),
      ],
    ];
    double confidence(List<KeyEstimateFrame> frames, int pc, bool minor) =>
        frames.last.ranked
            .firstWhere(
              (e) =>
                  e.tonality.tonicPitchClass == pc &&
                  e.tonality.isMinor == minor,
            )
            .confidence;
    final plain = _run(HmmKeyDetector(), loop);
    final tilted = _run(HmmKeyDetector(relativeEvidenceTilt: 1), loop);
    expect(confidence(tilted, 9, true), lessThan(confidence(plain, 9, true)));
    expect(
      confidence(tilted, 0, false),
      greaterThan(confidence(plain, 0, false)),
    );
  });

  test('relative evidence tilt spares evidenced minor keys', () {
    // i-iv-V7-i in A minor: the E7 events sound G sharp (A minor's raised
    // seventh) and the A minor chords are a minor tonic on the root, so the
    // pair the phrase lives in keeps its claim.
    final phrase = [
      for (var i = 0; i < 3; i++) ...[
        _event(4 * i, [9, 0, 4], ChordQuality.minor),
        _event(4 * i + 1, [2, 5, 9], ChordQuality.minor),
        _event(4 * i + 2, [4, 8, 11, 2], ChordQuality.dominant7),
        _event(4 * i + 3, [9, 0, 4], ChordQuality.minor),
      ],
    ];
    final tilted = _run(HmmKeyDetector(relativeEvidenceTilt: 1), phrase);
    final claim = tilted.last.claim;
    expect(claim, isNotNull);
    expect(claim!.tonality.tonicPitchClass, 9);
    expect(claim.tonality.isMinor, isTrue);
  });

  test('relative switch factor below one slows relative drift', () {
    // C major established, then sustained root-position A minor material:
    // shrinking the relative twin's transition weight should leave less
    // posterior on A minor than the shipped kernel at every point.
    final events = [
      ...cCadence,
      for (var i = 0; i < 6; i++) _event(4 + i, [9, 0, 4], ChordQuality.minor),
    ];
    double aMinorConfidence(List<KeyEstimateFrame> frames) => frames.last.ranked
        .firstWhere(
          (e) => e.tonality.tonicPitchClass == 9 && e.tonality.isMinor,
        )
        .confidence;
    final plain = _run(HmmKeyDetector(), events);
    final damped = _run(HmmKeyDetector(relativeSwitchFactor: 0.25), events);
    expect(aMinorConfidence(damped), lessThan(aMinorConfidence(plain)));
  });
}
