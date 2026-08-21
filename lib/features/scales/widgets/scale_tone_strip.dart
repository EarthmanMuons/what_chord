import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class ScaleToneStrip extends StatelessWidget {
  const ScaleToneStrip({
    super.key,
    required this.tones,
    required this.noteNameSystem,
    required this.showDegrees,
    required this.playingPitchClasses,
    required this.memberPitchClasses,
  });

  final ScaleToneSet tones;
  final NoteNameSystem noteNameSystem;
  final bool showDegrees;
  final Set<int> playingPitchClasses;
  final Set<int> memberPitchClasses;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Scale tones',
      child: Wrap(
        spacing: 5,
        runSpacing: 8,
        children: [for (var i = 0; i < tones.tones.length; i++) _buildChip(i)],
      ),
    );
  }

  Widget _buildChip(int index) {
    final tone = tones.tones[index];
    final noteName = noteDisplayLabel(
      tone.name,
      noteNameSystem: noteNameSystem,
    );
    final degreeLabel = tone.degreeLabel;
    final pitchClass = tone.pitchClass;

    final state = playingPitchClasses.contains(pitchClass)
        ? NoteChipState.fill
        : memberPitchClasses.contains(pitchClass)
        ? NoteChipState.outline
        : NoteChipState.plain;

    final noteSemantic = noteSemanticLabel(
      tone.name,
      noteNameSystem: noteNameSystem,
    );

    return NoteChip(
      label: showDegrees ? degreeLabel : noteName,
      alternateLabel: showDegrees ? noteName : degreeLabel,
      semanticLabel: '$noteSemantic, scale degree $degreeLabel',
      state: state,
      horizontalPadding: 8,
    );
  }
}
