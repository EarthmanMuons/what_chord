import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../../models/sounding_note.dart';
import '../../providers/pedal_state_provider.dart';
import 'input_display_sizing.dart';

/// A live-input chip wrapping the shared [NoteChip] with the note name and
/// sustain-pedal state resolved from providers.
class InputNoteChip extends ConsumerWidget {
  const InputNoteChip({
    super.key,
    required this.note,
    this.visualScaleMultiplier = 1.0,
  });
  final SoundingNote note;
  final double visualScaleMultiplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sizeScale = InputDisplaySizing.noteScale(
      context,
      visualScaleMultiplier: visualScaleMultiplier,
    );
    final verticalScale = InputDisplaySizing.noteVerticalScale(
      context,
      visualScaleMultiplier: visualScaleMultiplier,
    );

    final isPedalDown = ref.watch(
      inputPedalStateProvider.select((s) => s.isDown),
    );
    final noteNameSystem = ref.watch(noteNameSystemProvider);

    final displayLabel = noteDisplayLabel(
      note.label,
      noteNameSystem: noteNameSystem,
    );
    final semanticLabel = NoteLongFormFormatter.format(
      note.label,
      noteNameSystem: noteNameSystem,
    );

    // Visual feedback for sustain state: a heavier outline once the note is held
    // only by the pedal, and a slightly darker outline while it is still pressed
    // with the pedal engaged.
    final state = note.isSustained
        ? NoteChipState.sustained
        : isPedalDown
        ? NoteChipState.engaged
        : NoteChipState.plain;

    return NoteChip(
      label: displayLabel,
      alternateLabel: displayLabel,
      semanticLabel: 'Note $semanticLabel',
      semanticValue: note.isSustained ? 'Sustained' : 'Pressed',
      state: state,
      sizeScale: sizeScale,
      verticalScale: verticalScale,
    );
  }
}
