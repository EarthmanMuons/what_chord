import 'package:material_ui/material_ui.dart';

import '../../models/piano_key_decoration.dart';
import '../../models/piano_palette.dart';
import 'piano_keyboard_painter.dart';

class PianoKeyboard extends StatelessWidget {
  const PianoKeyboard({
    super.key,
    required this.whiteKeyCount,
    this.firstMidiNote = 48, // C3 by default
    this.highlightedNoteNumbers = const <int>{},
    this.impliedNoteNumbers = const <int>{},
    this.scaleNoteNumbers = const <int>{},
    this.normalHighlightPitchClasses,
    this.tonicPitchClass,
    this.height,
    this.decorations = const <PianoKeyDecoration>[],
    this.decorationTextScaleMultiplier = 1.0,
  }) : assert(whiteKeyCount > 0);

  /// Number of white keys to render (e.g., 14, 21, 52).
  final int whiteKeyCount;

  /// MIDI note number of the first *white* key at index 0.
  final int firstMidiNote;

  /// Highlighted *MIDI note numbers* (e.g., 60 for middle C).
  final Set<int> highlightedNoteNumbers;

  /// Implied *MIDI note numbers*, drawn as a hollow outline of the pressed
  /// highlight: named by the analysis but not played (an ensemble rootless
  /// reading's implied root).
  final Set<int> impliedNoteNumbers;

  /// Scale member *MIDI note numbers*. When non-empty, each member key is
  /// marked with a dot so the in-scale notes read at a glance.
  final Set<int> scaleNoteNumbers;

  /// Pitch classes that keep the normal active highlight when highlighted.
  /// Highlighted notes outside this set use the muted active fill. Null means
  /// no pitch-class filter.
  final Set<int>? normalHighlightPitchClasses;

  /// Pitch class (0-11) of the scale tonic, marked with a triangle instead of a
  /// dot. Null marks every member with a dot.
  final int? tonicPitchClass;

  /// If provided, forces a fixed height. Otherwise a default is used.
  final double? height;

  /// Key decorations (e.g., middle C, scale markers).
  final List<PianoKeyDecoration> decorations;
  final double decorationTextScaleMultiplier;

  static const double _defaultHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final palette = buildPianoPalette(cs);
    final resolvedHeight = height ?? _defaultHeight;
    final outOfScaleAccent = cs.outline;
    final outOfScalePressedWhiteKey = Color.alphaBlend(
      outOfScaleAccent.withValues(
        alpha: cs.brightness == Brightness.dark ? 0.30 : 0.16,
      ),
      palette.whiteKey,
    );
    final outOfScalePressedBlackKey = outOfScalePressedWhiteKey;

    final whiteLum = palette.whiteKey.computeLuminance();

    // If the key fill is light, use a dark label; otherwise use a light label.
    final decorationColor = whiteLum > 0.55
        ? Colors.black.withValues(alpha: 0.55)
        : Colors.white.withValues(alpha: 0.80);

    return SizedBox(
      height: resolvedHeight,
      width: double.infinity,
      child: CustomPaint(
        painter: PianoKeyboardPainter(
          whiteKeyCount: whiteKeyCount,
          firstMidiNote: firstMidiNote,
          highlightedNoteNumbers: highlightedNoteNumbers,
          impliedNoteNumbers: impliedNoteNumbers,
          scaleNoteNumbers: scaleNoteNumbers,
          normalHighlightPitchClasses: normalHighlightPitchClasses,
          // Keep the marker accent the same tone in both themes. The light
          // scheme's primary and the dark scheme's inversePrimary are the same
          // tonal value, so swap the role by brightness rather than the color.
          scaleMarkerColor: cs.brightness == Brightness.dark
              ? cs.inversePrimary
              : cs.primary,
          tonicPitchClass: tonicPitchClass,

          whiteKeyColor: palette.whiteKey,
          pressedWhiteKeyColor: palette.pressedWhiteKey,
          pressedBlackKeyColor: palette.pressedBlackKey,
          outOfScalePressedWhiteKeyColor: outOfScalePressedWhiteKey,
          outOfScalePressedBlackKeyColor: outOfScalePressedBlackKey,
          whiteKeyBorderColor: palette.border,
          pressedWhiteKeyBorderColor: palette.pressedWhiteKeyBorder,
          pressedWhiteKeySeparatorColor: palette.pressedWhiteKeySeparator,
          pressedBlackKeySeparatorColor: palette.pressedBlackKeySeparator,
          blackKeyColor: palette.blackKey,
          backgroundColor: palette.background,

          decorations: decorations,
          decorationColor: decorationColor,
          decorationTextScaleMultiplier: decorationTextScaleMultiplier,

          drawBackground: true,
          drawFeltStrip: true,
        ),
      ),
    );
  }
}
