import 'package:meta/meta.dart';

import 'polychord_onset_evidence.dart';
import 'polychord_release_pedal_evidence.dart';

/// Reset-scoped identity of one currently sounding MIDI-note instance.
///
/// The enclosing observation or binding supplies the tracker epoch. A null
/// [onsetEventIndex] preserves a carried-in note whose attack is unknown.
@immutable
final class PolychordSoundingInstanceKey {
  @internal
  const PolychordSoundingInstanceKey.internal({
    required this.midiNote,
    required this.onsetEventIndex,
  });

  @internal
  factory PolychordSoundingInstanceKey.fromOnset(
    PolychordSoundingNoteOnset note,
  ) => PolychordSoundingInstanceKey.internal(
    midiNote: note.midiNote,
    onsetEventIndex: note.origin?.eventIndex,
  );

  @internal
  factory PolychordSoundingInstanceKey.fromHistory(
    PolychordSoundingNoteHistory history,
  ) => PolychordSoundingInstanceKey.internal(
    midiNote: history.midiNote,
    onsetEventIndex: history.onset?.eventIndex,
  );

  final int midiNote;
  final int? onsetEventIndex;

  Map<String, Object?> toJson() => <String, Object?>{
    'midiNote': midiNote,
    'onsetEventIndex': onsetEventIndex,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PolychordSoundingInstanceKey &&
          other.midiNote == midiNote &&
          other.onsetEventIndex == onsetEventIndex;

  @override
  int get hashCode => Object.hash(midiNote, onsetEventIndex);
}
