import 'package:whatchord/whatchord.dart';

/// One labeled template tone in the ranking sheet's ledger: its degree and
/// note name stay paired so each tone is read as a unit.
class ToneEntry {
  const ToneEntry({
    required this.degree,
    required this.note,
    this.isBass = false,
  });

  final String degree;
  final String note;
  final bool isBass;
}

/// The template-tone breakdown behind a candidate's cost card: the played
/// tones the name accounts for, the required tones it is missing, and the
/// extra tones played outside the named structure.
class ToneLedger {
  const ToneLedger({
    required this.chordTones,
    required this.missing,
    required this.alsoPlayed,
  });

  final List<ToneEntry> chordTones;
  final List<ToneEntry> missing;
  final List<ToneEntry> alsoPlayed;

  factory ToneLedger.forCandidate(
    ExplainedCandidate row, {
    required Tonality tonality,
    required NoteNameSystem noteNameSystem,
  }) {
    final identity = row.candidate.identity;

    final representedMask = identity.toneRolesByInterval.keys.fold<int>(
      0,
      (mask, interval) => mask | (1 << interval),
    );
    final alsoPlayedMask = identity.presentIntervalsMask & ~representedMask;
    // An implied root belongs in the missing list: the name accounts for it,
    // but nobody played it.
    final missingMask =
        _reasonIntervals(row, CostReasonLabel.missingRequired) |
        _reasonIntervals(row, CostReasonLabel.missingRoot);

    /// Builds (degree, note) entries for the tones in [mask], by degree.
    List<ToneEntry> tonesFor(int mask) {
      final entries = <ToneEntry>[];
      final intervals = ChordToneOrdering.byDegree(
        intervalsFromMask(mask),
        identity: identity,
      );
      for (final interval in intervals) {
        final pitchClass = (identity.rootPc + interval) % 12;
        final pc = {pitchClass};
        final degree = toGlyphAccidentals(
          ChordMemberDegreeFormatter.formatDegrees(
            identity: identity,
            pitchClasses: pc,
          ).first,
        );
        final note = noteDisplayLabel(
          ChordMemberSpeller.spellMembers(
            identity: identity,
            pitchClasses: pc,
            tonality: tonality,
          ).first,
          noteNameSystem: noteNameSystem,
        );
        entries.add(
          ToneEntry(
            degree: degree,
            note: note,
            isBass: pitchClass == identity.bassPc,
          ),
        );
      }
      return entries;
    }

    return ToneLedger(
      chordTones: tonesFor(representedMask),
      missing: tonesFor(missingMask),
      alsoPlayed: tonesFor(alsoPlayedMask),
    );
  }

  static int _reasonIntervals(ExplainedCandidate row, String label) {
    for (final reason in row.costReasons) {
      if (reason.label == label) return reason.intervals ?? 0;
    }
    return 0;
  }
}
