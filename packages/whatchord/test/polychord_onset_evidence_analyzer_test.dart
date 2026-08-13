import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const analyzer = PolychordOnsetEvidenceAnalyzer();

  test('keeps structural candidates independent of onset history', () {
    final synchronous = analyzer.analyzeFrame(
      _observations(lowerTimestampMs: 0, upperTimestampMs: 0),
    );
    final separated = analyzer.analyzeFrame(
      _observations(lowerTimestampMs: 0, upperTimestampMs: 400),
    );

    expect(synchronous.map((item) => item.candidate), [
      separated.single.candidate,
    ]);
    expect(synchronous.single.candidate.symbol, 'C|Gm');
  });

  test('reports synchronous attacks without interpreting them', () {
    final evidence = analyzer
        .analyzeFrame(_observations(lowerTimestampMs: 0, upperTimestampMs: 0))
        .single;

    expect(evidence.allCandidateOnsetsKnown, isTrue);
    expect(evidence.lower.knownOnsetSpanMs, 0);
    expect(evidence.upper.knownOnsetSpanMs, 0);
    expect(evidence.upperEarliestMinusLowerLatestMs, 0);
    expect(evidence.upperLatestMinusLowerEarliestMs, 0);
  });

  test('reports separated onset intervals without choosing a threshold', () {
    final evidence = analyzer
        .analyzeFrame(_observations(lowerTimestampMs: 0, upperTimestampMs: 400))
        .single;

    expect(evidence.lower.distinctKnownOnsetTimestampsMs, [0]);
    expect(evidence.upper.distinctKnownOnsetTimestampsMs, [400]);
    expect(evidence.upperEarliestMinusLowerLatestMs, 400);
    expect(evidence.upperLatestMinusLowerEarliestMs, 400);
  });

  test('preserves reverse layer order as signed raw evidence', () {
    final evidence = analyzer
        .analyzeFrame(_observations(lowerTimestampMs: 400, upperTimestampMs: 0))
        .single;

    expect(evidence.upperEarliestMinusLowerLatestMs, -400);
    expect(evidence.upperLatestMinusLowerEarliestMs, -400);
  });

  test('keeps relations unknown when a carried-in onset is unknown', () {
    final observations = _observations(
      lowerTimestampMs: 0,
      upperTimestampMs: 400,
    );
    observations[0] = PolychordSoundingNoteOnset(
      midiNote: observations[0].midiNote,
      soundingState: PolychordSoundingState.sustained,
    );

    final evidence = analyzer.analyzeFrame(observations).single;

    expect(evidence.allCandidateOnsetsKnown, isFalse);
    expect(evidence.lower.knownOnsetCount, 2);
    expect(evidence.lower.unknownOnsetCount, 1);
    expect(evidence.lower.knownOnsetSpanMs, 0);
    expect(evidence.upperEarliestMinusLowerLatestMs, isNull);
    expect(evidence.upperLatestMinusLowerEarliestMs, isNull);
  });

  test('keeps shared pitch classes bound to separate sounded notes', () {
    final evidence = analyzer
        .analyzeFrame(_observations(lowerTimestampMs: 0, upperTimestampMs: 400))
        .single;

    expect(evidence.candidate.sharedPitchClasses, [7]);
    expect(evidence.lower.notes.map((note) => note.midiNote), [43, 46, 50]);
    expect(evidence.upper.notes.map((note) => note.midiNote), [60, 64, 67]);
  });

  test('returns every candidate and leaves noncandidates empty', () {
    final multiple = analyzer.analyzeFrame(
      _observationsForNotes([36, 40, 43, 59, 74, 78, 81]),
    );
    final none = analyzer.analyzeFrame(_observationsForNotes([60, 64, 67]));

    expect(multiple.map((item) => item.candidate.symbol), ['Bm7|C', 'D|Cmaj7']);
    expect(none, isEmpty);
  });

  test('requires exact, sorted candidate-bound observations', () {
    final observations = _observations(
      lowerTimestampMs: 0,
      upperTimestampMs: 400,
    );
    final candidate = analyzer.analyzeFrame(observations).single.candidate;

    expect(
      () => analyzer.analyzeCandidate(candidate, observations.take(5)),
      throwsArgumentError,
    );
    expect(
      () => analyzer.analyzeFrame(observations.reversed),
      throwsArgumentError,
    );
    expect(
      () => analyzer.analyzeFrame([...observations, observations.last]),
      throwsArgumentError,
    );

    final inventedCandidate = PolychordCandidate(
      splitAfterIndex: candidate.splitAfterIndex,
      lowerTopMidi: candidate.lowerTopMidi,
      upperBottomMidi: candidate.upperBottomMidi,
      gapSemitones: candidate.gapSemitones,
      lower: candidate.upper,
      upper: candidate.lower,
      sharedPitchClasses: candidate.sharedPitchClasses,
    );
    expect(
      () => analyzer.analyzeCandidate(inventedCandidate, observations),
      throwsArgumentError,
    );
  });

  test('requires distinct origins with monotonic event timestamps', () {
    final observations = _observations(
      lowerTimestampMs: 0,
      upperTimestampMs: 400,
    );
    final reusedOrigin = [...observations];
    reusedOrigin[1] = PolychordSoundingNoteOnset(
      midiNote: reusedOrigin[1].midiNote,
      soundingState: PolychordSoundingState.pressed,
      origin: reusedOrigin[0].origin,
    );
    final reversedTimestamps = [...observations];
    reversedTimestamps[1] = PolychordSoundingNoteOnset(
      midiNote: reversedTimestamps[1].midiNote,
      soundingState: PolychordSoundingState.pressed,
      origin: PolychordOnsetOrigin(
        eventIndex: 1,
        timestampMs: 500,
        velocity: 80,
      ),
    );

    expect(() => analyzer.analyzeFrame(reusedOrigin), throwsArgumentError);
    expect(
      () => analyzer.analyzeFrame(reversedTimestamps),
      throwsArgumentError,
    );
  });

  test('validates onset origin and MIDI ranges', () {
    expect(
      () => PolychordOnsetOrigin(eventIndex: -1, timestampMs: 0, velocity: 1),
      throwsRangeError,
    );
    expect(
      () => PolychordOnsetOrigin(eventIndex: 0, timestampMs: -1, velocity: 1),
      throwsRangeError,
    );
    expect(
      () => PolychordOnsetOrigin(eventIndex: 0, timestampMs: 0, velocity: 0),
      throwsRangeError,
    );
    expect(
      () => PolychordSoundingNoteOnset(
        midiNote: 128,
        soundingState: PolychordSoundingState.pressed,
      ),
      throwsRangeError,
    );
  });

  test('output models reject contradictory note assignments', () {
    final observations = _observations(
      lowerTimestampMs: 0,
      upperTimestampMs: 400,
    );
    final candidate = analyzer.analyzeFrame(observations).single.candidate;
    final lower = PolychordLayerOnsetEvidence(notes: observations.take(3));
    final upper = PolychordLayerOnsetEvidence(notes: observations.skip(3));

    expect(
      () => PolychordLayerOnsetEvidence(notes: const []),
      throwsArgumentError,
    );
    expect(
      () => PolychordLayerOnsetEvidence(
        notes: observations.take(3).toList().reversed,
      ),
      throwsArgumentError,
    );
    expect(
      () => PolychordCandidateOnsetEvidence(
        candidate: candidate,
        lower: upper,
        upper: lower,
      ),
      throwsArgumentError,
    );
  });

  test('serializes the research contract field names', () {
    final json = analyzer
        .analyzeFrame(_observations(lowerTimestampMs: 0, upperTimestampMs: 400))
        .single
        .toJson();
    final onsetEvidence = json['onsetEvidence']! as Map<String, Object?>;
    final lower = onsetEvidence['lower']! as Map<String, Object?>;
    final firstNote = (lower['notes']! as List).first as Map<String, Object?>;

    expect(json.keys, {'candidate', 'onsetEvidence'});
    expect(onsetEvidence.keys, {
      'allCandidateOnsetsKnown',
      'lower',
      'upper',
      'upperEarliestMinusLowerLatestMs',
      'upperLatestMinusLowerEarliestMs',
    });
    expect(firstNote, {
      'midiNote': 43,
      'soundingState': 'pressed',
      'onsetEventIndex': 0,
      'onsetTimestampMs': 0,
      'onsetVelocity': 80,
    });
  });
}

List<PolychordSoundingNoteOnset> _observations({
  required int lowerTimestampMs,
  required int upperTimestampMs,
}) => [
  for (var index = 0; index < 6; index++)
    PolychordSoundingNoteOnset(
      midiNote: const [43, 46, 50, 60, 64, 67][index],
      soundingState: PolychordSoundingState.pressed,
      origin: PolychordOnsetOrigin(
        eventIndex: lowerTimestampMs <= upperTimestampMs
            ? index
            : index < 3
            ? index + 3
            : index - 3,
        timestampMs: index < 3 ? lowerTimestampMs : upperTimestampMs,
        velocity: 80,
      ),
    ),
];

List<PolychordSoundingNoteOnset> _observationsForNotes(List<int> midiNotes) => [
  for (var index = 0; index < midiNotes.length; index++)
    PolychordSoundingNoteOnset(
      midiNote: midiNotes[index],
      soundingState: PolychordSoundingState.pressed,
      origin: PolychordOnsetOrigin(
        eventIndex: index,
        timestampMs: 0,
        velocity: 80,
      ),
    ),
];
