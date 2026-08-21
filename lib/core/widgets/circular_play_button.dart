import 'package:material_ui/material_ui.dart';

/// A circular filled-tonal play button, shared by the Explore play affordances.
class CircularPlayButton extends StatelessWidget {
  const CircularPlayButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.tapHint,
  });

  final VoidCallback onPressed;
  final String label;
  final String tapHint;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: label,
      onTapHint: tapHint,
      onTap: onPressed,
      child: Tooltip(
        message: label,
        child: ExcludeSemantics(
          child: IconButton.filledTonal(
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            style: IconButton.styleFrom(
              fixedSize: const Size.square(48),
              shape: const CircleBorder(),
              backgroundColor: cs.secondaryContainer,
              foregroundColor: cs.onSecondaryContainer,
            ),
            onPressed: onPressed,
            icon: const Icon(Icons.play_arrow),
          ),
        ),
      ),
    );
  }
}
