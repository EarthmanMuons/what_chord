import '../models/polychord_candidate.dart';
import '../models/polychord_onset_evidence.dart';
import 'polychord_register_candidate_generator.dart';

/// Attaches threshold-free attack provenance to structural candidates.
///
/// This is the pure-Dart counterpart of `polychord-onset-evidence/1`. It
/// records observable onset facts only: it does not infer streams, apply a
/// millisecond threshold, rank candidates, or authorize a display.
final class PolychordOnsetEvidenceAnalyzer {
  const PolychordOnsetEvidenceAnalyzer();

  /// Generates every register candidate and analyzes each exact assignment.
  List<PolychordCandidateOnsetEvidence> analyzeFrame(
    Iterable<PolychordSoundingNoteOnset> soundingNotes,
  ) {
    final notes = _validateSoundingNotes(soundingNotes);
    final candidates = const PolychordRegisterCandidateGenerator().generate(
      notes.map((note) => note.midiNote),
    );
    return List<PolychordCandidateOnsetEvidence>.unmodifiable(
      candidates.map((candidate) => _analyze(candidate, notes)),
    );
  }

  /// Analyzes one candidate against its complete sounding-note observation.
  PolychordCandidateOnsetEvidence analyzeCandidate(
    PolychordCandidate candidate,
    Iterable<PolychordSoundingNoteOnset> soundingNotes,
  ) {
    final notes = _validateSoundingNotes(soundingNotes);
    final generated = const PolychordRegisterCandidateGenerator().generate(
      notes.map((note) => note.midiNote),
    );
    if (!generated.contains(candidate)) {
      throw ArgumentError.value(
        candidate,
        'candidate',
        'must be an exact generated candidate for soundingNotes',
      );
    }
    return _analyze(candidate, notes);
  }
}

PolychordCandidateOnsetEvidence _analyze(
  PolychordCandidate candidate,
  List<PolychordSoundingNoteOnset> notes,
) {
  final byMidiNote = {for (final note in notes) note.midiNote: note};
  final lower = _summarize(candidate.lower.midiNotes, byMidiNote);
  final upper = _summarize(candidate.upper.midiNotes, byMidiNote);

  return PolychordCandidateOnsetEvidence(
    candidate: candidate,
    lower: lower,
    upper: upper,
  );
}

PolychordLayerOnsetEvidence _summarize(
  List<int> midiNotes,
  Map<int, PolychordSoundingNoteOnset> byMidiNote,
) {
  final notes = [for (final midiNote in midiNotes) byMidiNote[midiNote]!];
  return PolychordLayerOnsetEvidence(notes: notes);
}

List<PolychordSoundingNoteOnset> _validateSoundingNotes(
  Iterable<PolychordSoundingNoteOnset> soundingNotes,
) {
  final notes = List<PolychordSoundingNoteOnset>.of(soundingNotes);
  final originByEventIndex = <int, PolychordOnsetOrigin>{};
  for (var index = 1; index < notes.length; index++) {
    if (notes[index].midiNote <= notes[index - 1].midiNote) {
      throw ArgumentError.value(
        soundingNotes,
        'soundingNotes',
        'must be strictly increasing without duplicate MIDI notes',
      );
    }
  }
  for (final note in notes) {
    final origin = note.origin;
    if (origin == null) continue;
    if (originByEventIndex.containsKey(origin.eventIndex)) {
      throw ArgumentError.value(
        soundingNotes,
        'soundingNotes',
        'must not reuse an onset event index',
      );
    }
    originByEventIndex[origin.eventIndex] = origin;
  }
  final origins = originByEventIndex.values.toList()
    ..sort((a, b) => a.eventIndex.compareTo(b.eventIndex));
  for (var index = 1; index < origins.length; index++) {
    if (origins[index].timestampMs < origins[index - 1].timestampMs) {
      throw ArgumentError.value(
        soundingNotes,
        'soundingNotes',
        'onset timestamps must be nondecreasing in event order',
      );
    }
  }
  return List<PolychordSoundingNoteOnset>.unmodifiable(notes);
}
