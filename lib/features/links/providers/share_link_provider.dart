import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../models/chord_link.dart';

/// A shareable website link for the current voicing and tonality, or null when
/// nothing is sounding (so the share affordance can disable itself).
///
/// Notes use the spelled names shown in the note chips (bass first), so a
/// recipient opening the link sees readable note names rather than MIDI numbers.
final shareLinkProvider = Provider<Uri?>((ref) {
  final notes = ref.watch(soundingNotesProvider);
  if (notes.isEmpty) return null;

  return ChordLink.build(
    orderedNoteNames: [for (final note in notes) note.label],
    tonality: ref.watch(selectedTonalityProvider),
    playingContext: ref.watch(
      analysisContextProvider.select((c) => c.playingContext),
    ),
  );
});
