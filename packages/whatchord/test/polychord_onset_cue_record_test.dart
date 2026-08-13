import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const builder = PolychordOnsetCueRecordBuilder();

  test(
    'binds positive onset support to the exact observation and instances',
    () {
      final frame = _frame(lowerTimestampMs: 0, upperTimestampMs: 400);

      final record = builder.build(frame).single;

      expect(record.targetObservation, frame);
      expect(record.targetBinding.candidate.symbol, 'C|Gm');
      expect(record.targetBinding.trackerEpoch, 3);
      expect(record.availability, PolychordCueAvailability.complete);
      expect(record.support, PolychordCueSupport.positive);
      expect(record.reasonCodes, ['separate-coherent-onset-cohorts']);
    },
  );

  test('keeps complete but unsupported timing neutral', () {
    final record = builder
        .build(_frame(lowerTimestampMs: 0, upperTimestampMs: 199))
        .single;

    expect(record.availability, PolychordCueAvailability.complete);
    expect(record.support, PolychordCueSupport.neutral);
    expect(record.reasonCodes, ['between-layer-separation-below-minimum']);
  });

  test('maps incomplete causal history to null cue support', () {
    final complete = _frame(lowerTimestampMs: 0, upperTimestampMs: 400);
    final notes = [...complete.soundingNoteOnsets];
    notes[0] = PolychordSoundingNoteOnset(
      midiNote: notes[0].midiNote,
      soundingState: notes[0].soundingState,
    );
    final frame = PolychordOnsetTrackingFrame(
      trackerEpoch: complete.trackerEpoch,
      afterEventIndex: complete.afterEventIndex,
      timestampMs: complete.timestampMs,
      pedalDown: complete.pedalDown,
      soundingNoteOnsets: notes,
    );

    final record = builder.build(frame).single;

    expect(record.targetBinding.isComplete, isFalse);
    expect(record.availability, PolychordCueAvailability.incomplete);
    expect(record.support, isNull);
    expect(
      record.interpretation.onsetCohortSupport,
      PolychordOnsetCohortSupport.neutral,
    );
    expect(record.reasonCodes, ['onset-history-incomplete']);
  });

  test('retains every candidate without selecting one', () {
    final frame = _frameForNotes([36, 40, 43, 59, 74, 78, 81]);

    final records = builder.build(frame);

    expect(records.map((record) => record.targetBinding.candidate.symbol), [
      'Bm7|C',
      'D|Cmaj7',
    ]);
    expect(records, everyElement(isA<PolychordCandidateOnsetCueRecord>()));
  });

  test(
    'reattack changes the target binding without changing the candidate',
    () {
      final first = builder
          .build(_frame(lowerTimestampMs: 0, upperTimestampMs: 400))
          .single;
      final second = builder
          .build(
            _frame(
              lowerTimestampMs: 0,
              upperTimestampMs: 400,
              firstEventIndex: 10,
            ),
          )
          .single;

      expect(second.targetBinding.candidate, first.targetBinding.candidate);
      expect(second.targetBinding, isNot(first.targetBinding));
    },
  );

  test('serializes the complete diagnostic cue-record shape', () {
    final record = builder
        .build(_frame(lowerTimestampMs: 0, upperTimestampMs: 400))
        .single;

    final json = record.toJson();
    final binding = json['targetBinding']! as Map<String, Object>;

    expect(json.keys, {
      'cueId',
      'evidenceSchemaId',
      'targetObservation',
      'targetBinding',
      'availability',
      'support',
      'reasonCodes',
      'diagnostic',
    });
    expect(json['cueId'], PolychordCandidateOnsetCueRecord.cueId);
    expect(
      json['evidenceSchemaId'],
      PolychordCandidateOnsetCueRecord.evidenceSchemaId,
    );
    expect(binding['availability'], 'complete');
    expect(json['availability'], 'complete');
    expect(json['support'], 'positive');
  });
}

PolychordOnsetTrackingFrame _frame({
  required int lowerTimestampMs,
  required int upperTimestampMs,
  int firstEventIndex = 0,
}) => PolychordOnsetTrackingFrame(
  trackerEpoch: 3,
  afterEventIndex: firstEventIndex + 5,
  timestampMs: upperTimestampMs > lowerTimestampMs
      ? upperTimestampMs
      : lowerTimestampMs,
  pedalDown: false,
  soundingNoteOnsets: [
    for (var index = 0; index < _candidateNotes.length; index++)
      PolychordSoundingNoteOnset(
        midiNote: _candidateNotes[index],
        soundingState: PolychordSoundingState.pressed,
        origin: PolychordOnsetOrigin(
          eventIndex: firstEventIndex + index,
          timestampMs: index < 3 ? lowerTimestampMs : upperTimestampMs,
          velocity: 80,
        ),
      ),
  ],
);

PolychordOnsetTrackingFrame _frameForNotes(List<int> notes) =>
    PolychordOnsetTrackingFrame(
      trackerEpoch: 0,
      afterEventIndex: notes.length - 1,
      timestampMs: notes.length - 1,
      pedalDown: false,
      soundingNoteOnsets: [
        for (var index = 0; index < notes.length; index++)
          PolychordSoundingNoteOnset(
            midiNote: notes[index],
            soundingState: PolychordSoundingState.pressed,
            origin: PolychordOnsetOrigin(
              eventIndex: index,
              timestampMs: index,
              velocity: 80,
            ),
          ),
      ],
    );

const _candidateNotes = [43, 46, 50, 60, 64, 67];
