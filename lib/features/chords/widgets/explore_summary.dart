import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class ExploreSummary extends ConsumerWidget {
  const ExploreSummary({
    super.key,
    required this.presentation,
    required this.chordTones,
    required this.chordDegrees,
  });

  final ChordPresentation presentation;
  final List<String> chordTones;

  /// Member degree labels in interval order (ASCII, e.g. "1", "b3", "5"),
  /// glyphed for the "Chord degrees" copy choice.
  final List<String> chordDegrees;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final displaySymbol = chordSymbolDisplayParts(
      presentation.symbol,
      noteNameSystem: noteNameSystem,
    );
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final symbolStyle = textTheme.headlineMedium?.copyWith(
      color: colorScheme.onSurface,
      height: 1.0,
    );
    final symbolDetailStyle = symbolStyle?.copyWith(
      color: colorScheme.onSurface.withValues(alpha: 0.74),
    );
    final rootStyle = symbolStyle?.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: (symbolStyle.fontSize ?? 14) + 6,
    );
    final copyChoices = [
      CopyChoice(
        title: 'Chord symbol',
        icon: Icons.music_note,
        value: chordSymbolTextLabel(
          presentation.symbol,
          noteNameSystem: noteNameSystem,
        ),
        copiedLabel: 'chord symbol',
      ),
      CopyChoice(
        title: 'Chord tones',
        icon: Icons.piano,
        value: chordTones
            .map(
              (tone) => noteDisplayLabel(tone, noteNameSystem: noteNameSystem),
            )
            .join('-'),
        copiedLabel: 'chord tones',
      ),
      CopyChoice(
        title: 'Chord degrees',
        icon: Icons.numbers,
        value: chordDegrees.map(toGlyphAccidentals).join(', '),
        copiedLabel: 'chord degrees',
      ),
      CopyChoice(
        title: 'Academic name',
        icon: Icons.notes,
        value: presentation.longLabel,
        copiedLabel: 'academic name',
      ),
      CopyChoice(
        title: 'Spoken name',
        icon: Icons.record_voice_over,
        value: presentation.spokenLabel,
        copiedLabel: 'spoken name',
      ),
      CopyChoice(
        title: 'Harte notation',
        icon: Icons.data_object,
        value: HarteChordFormatter.format(
          presentation.identity,
          rootName: presentation.symbol.root,
        ),
        copiedLabel: 'Harte notation',
      ),
    ];

    void showCopyDialog() =>
        unawaited(showCopyChoiceDialog(context, choices: copyChoices));

    return Semantics(
      container: true,
      header: true,
      label: presentation.semanticLabel,
      onTap: showCopyDialog,
      onTapHint: 'Choose chord text to copy',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          excludeFromSemantics: true,
          onTap: showCopyDialog,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: displaySymbol.root, style: rootStyle),
                          if (displaySymbol.quality.isNotEmpty) ...[
                            TextSpan(
                              text: displaySymbol.quality,
                              style: symbolDetailStyle,
                            ),
                          ],
                          if (displaySymbol.hasBass) ...[
                            TextSpan(text: ' / ', style: symbolDetailStyle),
                            TextSpan(
                              text: displaySymbol.bassRequired,
                              style: symbolDetailStyle,
                            ),
                          ],
                        ],
                      ),
                      style: symbolStyle,
                      // Forced strut keeps the line height constant whether or
                      // not the root carries an accidental, so the play button
                      // and chips don't shift while scrubbing the root.
                      strutStyle: StrutStyle(
                        fontSize: rootStyle?.fontSize,
                        height: 1.0,
                        forceStrutHeight: true,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      presentation.longLabel,
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      strutStyle: StrutStyle(
                        fontSize: textTheme.bodyLarge?.fontSize,
                        forceStrutHeight: true,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.copy_outlined,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
