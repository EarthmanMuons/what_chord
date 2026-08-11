import 'package:test/test.dart';

import 'package:whatchord/whatchord.dart';

void main() {
  const generator = PolychordRegisterCandidateGenerator();
  const selector = PolychordRegisterSelector();

  test('abstains when no structural candidate exists', () {
    final decision = selector.decide([60, 64, 67]);

    expect(decision.selected, isNull);
    expect(decision.reasonCodes, ['no-structural-candidate']);
  });

  test('removes a compact integrated collection', () {
    final decision = selector.decide([50, 54, 57, 59, 62, 66]);

    expect(decision.candidates.map((candidate) => candidate.symbol), ['Bm|D']);
    expect(decision.selected, isNull);
    expect(decision.reasonCodes, ['not-selected-by-policy']);
    expect(decision.traces.single.integratedTertian.compact, isTrue);
  });

  test('removes every exact assignment of an ambiguous identity', () {
    final decision = selector.decide([48, 52, 55, 67, 71, 74, 79]);

    expect(decision.candidates, hasLength(2));
    expect(decision.selected, isNull);
    expect(
      decision.traces.every((trace) => trace.removedByAssignmentVeto),
      isTrue,
    );
  });

  test('selects the unique widest gap independent of candidate order', () {
    final notes = [36, 40, 43, 76, 80, 83, 87];
    final candidates = generator.generate(notes);

    final forward = selector.decideCandidates(notes, candidates);
    final reverse = selector.decideCandidates(notes, candidates.reversed);

    expect(forward.selected, reverse.selected);
    expect(forward.selected?.symbol, 'Emaj7|C');
    expect(forward.reasonCodes, isEmpty);
  });

  test('abstains when the greatest register gap is tied', () {
    final decision = selector.decide([33, 37, 40, 44, 48, 51, 55]);

    expect(decision.selected, isNull);
    expect(decision.reasonCodes, ['multiple-unresolved-identities']);
  });

  test('without-gap ablation abstains on multiple surviving candidates', () {
    final notes = [36, 40, 43, 76, 80, 83, 87];

    final full = selector.decide(notes);
    final withoutGap = selector.decide(
      notes,
      profile: PolychordRegisterSelectorProfile.withoutGapResolution,
    );

    expect(full.selected, isNotNull);
    expect(withoutGap.selected, isNull);
    expect(withoutGap.reasonCodes, ['multiple-unresolved-identities']);
  });

  test('requires the complete generated candidate set', () {
    final notes = [36, 40, 43, 76, 80, 83, 87];
    final candidates = generator.generate(notes);

    expect(
      () => selector.decideCandidates(notes, [candidates.first]),
      throwsArgumentError,
    );
  });

  test('serializes complete candidate diagnostics and selector identity', () {
    final json = selector.decide([48, 52, 55, 66, 70, 73]).toJson();

    expect(json['schema'], 'polychord-register-selector-decision/1');
    expect(json['selectorId'], 'polychord-register-policy/1');
    expect(json['midiNotes'], [48, 52, 55, 66, 70, 73]);
    expect(json['candidates'], hasLength(1));
    expect(json['traces'], hasLength(1));
    expect(json['selected'], isNotNull);
    expect(json['reasonCodes'], isEmpty);
  });
}
