import 'package:material_ui/material_ui.dart';

/// A compact toggle that switches a tone display between note names and degree
/// numbers. Shared by the Explore Chords and Explore Scales tone strips.
class NameDegreeToggleButton extends StatelessWidget {
  const NameDegreeToggleButton({
    super.key,
    required this.showDegrees,
    required this.onPressed,
  });

  final bool showDegrees;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final value = showDegrees ? 'Degrees' : 'Note names';
    final tooltip = showDegrees ? 'Show note names' : 'Show degrees';
    final activeStyle = theme.textTheme.labelSmall?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w800,
      height: 1.0,
    );
    final inactiveStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.disabledColor,
      fontWeight: FontWeight.w500,
      height: 1.0,
    );

    return Semantics(
      button: true,
      label: 'Tone display',
      value: value,
      onTap: onPressed,
      onTapHint: tooltip,
      child: Tooltip(
        message: tooltip,
        child: ExcludeSemantics(
          child: InkResponse(
            containedInkWell: false,
            highlightShape: BoxShape.circle,
            radius: 24,
            onTap: onPressed,
            child: SizedBox.square(
              dimension: 48,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'name',
                      strutStyle: const StrutStyle(
                        fontSize: 11,
                        height: 1.0,
                        forceStrutHeight: true,
                      ),
                      style: showDegrees ? inactiveStyle : activeStyle,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'deg',
                      strutStyle: const StrutStyle(
                        fontSize: 11,
                        height: 1.0,
                        forceStrutHeight: true,
                      ),
                      style: showDegrees ? activeStyle : inactiveStyle,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
