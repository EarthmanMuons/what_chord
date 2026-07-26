import 'package:flutter_test/flutter_test.dart';

import 'package:whatchord_app/features/theory/theory.dart';

void main() {
  group('impliedRootMidiBelow', () {
    test('places the root on the nearest key below the bass', () {
      // E4 bass over an implied C root: C4, a major third below.
      expect(impliedRootMidiBelow(bassMidi: 64, rootPc: 0), 60);
      // Eb4 bass over an implied C root: C4.
      expect(impliedRootMidiBelow(bassMidi: 63, rootPc: 0), 60);
      // F4 bass over an implied D root: D4.
      expect(impliedRootMidiBelow(bassMidi: 65, rootPc: 2), 62);
      // B3 bass over an implied G root: G3.
      expect(impliedRootMidiBelow(bassMidi: 59, rootPc: 7), 55);
    });

    test('is always strictly below the bass', () {
      for (var bass = 21; bass <= 108; bass++) {
        for (var rootPc = 0; rootPc < 12; rootPc++) {
          final implied = impliedRootMidiBelow(bassMidi: bass, rootPc: rootPc);
          expect(implied, lessThan(bass));
          expect(implied % 12, rootPc);
          expect(bass - implied, lessThanOrEqualTo(12));
        }
      }
    });
  });
}
