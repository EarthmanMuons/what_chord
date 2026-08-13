import '../models/polychord_candidate.dart';
import '../models/polychord_release_pedal_evidence.dart';
import 'polychord_register_candidate_generator.dart';

/// Attaches threshold-free release and pedal provenance to candidates.
///
/// This is the pure-Dart counterpart of
/// `polychord-release-pedal-evidence/1`. It reports causal facts only and does
/// not infer streams, apply a time threshold, rank candidates, or authorize a
/// display.
final class PolychordReleasePedalEvidenceAnalyzer {
  const PolychordReleasePedalEvidenceAnalyzer();

  List<PolychordCandidateReleasePedalEvidence> analyzeFrame(
    PolychordReleasePedalTrackingFrame frame,
  ) {
    final candidates = const PolychordRegisterCandidateGenerator().generate(
      frame.soundingNoteHistories.map((note) => note.midiNote),
    );
    return List<PolychordCandidateReleasePedalEvidence>.unmodifiable(
      candidates.map((candidate) => _analyze(candidate, frame)),
    );
  }

  PolychordCandidateReleasePedalEvidence analyzeCandidate(
    PolychordCandidate candidate,
    PolychordReleasePedalTrackingFrame frame,
  ) {
    final candidates = const PolychordRegisterCandidateGenerator().generate(
      frame.soundingNoteHistories.map((note) => note.midiNote),
    );
    if (!candidates.contains(candidate)) {
      throw ArgumentError.value(
        candidate,
        'candidate',
        'must be an exact generated candidate for the tracking frame',
      );
    }
    return _analyze(candidate, frame);
  }
}

PolychordCandidateReleasePedalEvidence _analyze(
  PolychordCandidate candidate,
  PolychordReleasePedalTrackingFrame frame,
) {
  final byMidiNote = {
    for (final note in frame.soundingNoteHistories) note.midiNote: note,
  };
  PolychordLayerReleasePedalEvidence summarize(List<int> midiNotes) =>
      PolychordLayerReleasePedalEvidence(
        notes: [for (final midiNote in midiNotes) byMidiNote[midiNote]!],
        frameTimestampMs: frame.timestampMs,
        pedalDown: frame.pedalDown,
        pedalTransition: frame.pedalTransition,
      );

  return PolychordCandidateReleasePedalEvidence(
    candidate: candidate,
    pedal: frame.pedalEvidence,
    lower: summarize(candidate.lower.midiNotes),
    upper: summarize(candidate.upper.midiNotes),
  );
}
