import 'package:flutter_test/flutter_test.dart';

import 'package:whatchord_app/features/theory/theory.dart';

void main() {
  test('covers every analyzer ranking decision', () {
    expect(
      ChordRankingExplanations.decisionRuleNames,
      ChordCandidateRanking.decisionRuleNames,
    );
  });

  test('covers every analyzer cost-reason label', () {
    expect(ChordRankingExplanations.costReasonLabels, CostReasonLabel.values);
  });

  test('keeps ranking decisions concise and easy to scan', () {
    for (final rule in ChordRankingExplanations.decisionRuleNames) {
      final explanation = ChordRankingExplanations.decision(rule);

      expect(explanation, startsWith('It ranks higher because '), reason: rule);
      expect(explanation.length, lessThanOrEqualTo(120), reason: rule);
    }
  });
}
