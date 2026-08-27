import 'package:flutter/material.dart';

import 'package:whatchord/whatchord.dart';

/// Accessible secondary presentation for a selected upper/lower decomposition.
class PolychordAnnotation extends StatelessWidget {
  const PolychordAnnotation({
    super.key,
    required this.presentation,
    required this.noteNameSystem,
    this.alignment = WrapAlignment.center,
    this.textAlign = TextAlign.center,
    this.textScaleMultiplier = 1,
  });

  final PolychordPresentation presentation;
  final NoteNameSystem noteNameSystem;
  final WrapAlignment alignment;
  final TextAlign textAlign;
  final double textScaleMultiplier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final scale = textScaleMultiplier.clamp(1.0, 1.5);
    final labelStyle = (theme.textTheme.labelMedium ?? const TextStyle())
        .copyWith(
          color: colors.onSurface.withValues(alpha: 0.62),
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        );
    final symbolStyle = (theme.textTheme.titleMedium ?? const TextStyle())
        .copyWith(
          color: colors.onSurface.withValues(alpha: 0.82),
          fontSize: ((theme.textTheme.titleMedium?.fontSize ?? 16) + 2) * scale,
          fontWeight: FontWeight.w700,
          height: 1.18,
        );
    final upper = chordSymbolTextLabel(
      presentation.symbol.upper,
      noteNameSystem: noteNameSystem,
    );
    final lower = chordSymbolTextLabel(
      presentation.symbol.lower,
      noteNameSystem: noteNameSystem,
    );

    return Semantics(
      container: true,
      liveRegion: true,
      label: presentation.semanticLabel,
      excludeSemantics: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: switch (alignment) {
          WrapAlignment.start => CrossAxisAlignment.start,
          WrapAlignment.end => CrossAxisAlignment.end,
          _ => CrossAxisAlignment.center,
        },
        children: [
          Text('Polychord', style: labelStyle, textAlign: textAlign),
          const SizedBox(height: 2),
          IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    upper,
                    style: symbolStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 1),
                ColoredBox(
                  color: colors.onSurface.withValues(alpha: 0.82),
                  child: const SizedBox(height: 1.5),
                ),
                const SizedBox(height: 1),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    lower,
                    style: symbolStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
