import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whatchord_app/core/models/app_palette.dart';
import 'package:whatchord_app/core/services/app_theme_builder.dart';
import 'package:whatchord_app/features/piano/models/piano_palette.dart';

void main() {
  group('buildPianoPalette', () {
    test('uses distinct highlighted colors in light themes', () {
      final colorScheme = colorSchemeFor(AppPalette.blue, Brightness.light);
      final palette = buildPianoPalette(colorScheme);

      expect(palette.pressedWhiteKey, isNot(palette.whiteKey));
      expect(palette.pressedBlackKey, isNot(palette.blackKey));
      expect(
        palette.pressedBlackKey,
        Color.alphaBlend(
          Colors.black.withValues(alpha: 0.20),
          colorScheme.inversePrimary,
        ),
      );
      expect(
        _colorDistance(palette.pressedWhiteKey, palette.whiteKey),
        greaterThan(0.10),
      );
      expect(
        _colorDistance(palette.pressedBlackKey, palette.blackKey),
        greaterThan(0.24),
      );
      expect(
        _colorDistance(palette.pressedWhiteKey, palette.pressedBlackKey),
        greaterThan(0.20),
      );
      expect(palette.pressedWhiteKeyBorder, isNot(palette.border));
      expect(
        palette.pressedWhiteKeySeparator.computeLuminance(),
        lessThan(palette.pressedWhiteKey.computeLuminance()),
      );
      expect(
        palette.pressedBlackKeySeparator.computeLuminance(),
        lessThan(palette.pressedBlackKey.computeLuminance()),
      );
    });

    test('uses distinct highlighted colors in dark themes', () {
      final colorScheme = colorSchemeFor(AppPalette.teal, Brightness.dark);
      final palette = buildPianoPalette(colorScheme);

      expect(palette.pressedWhiteKey, isNot(palette.whiteKey));
      expect(palette.pressedBlackKey, isNot(palette.blackKey));
      expect(
        palette.pressedBlackKey,
        Color.alphaBlend(
          Colors.black.withValues(alpha: 0.22),
          colorScheme.primary,
        ),
      );
      expect(
        _colorDistance(palette.pressedWhiteKey, palette.whiteKey),
        greaterThan(0.09),
      );
      expect(
        _colorDistance(palette.pressedBlackKey, palette.blackKey),
        greaterThan(0.40),
      );
      expect(
        _colorDistance(palette.pressedWhiteKey, palette.pressedBlackKey),
        greaterThan(0.10),
      );
      expect(palette.pressedWhiteKeyBorder, isNot(palette.border));
      expect(
        palette.pressedWhiteKeySeparator.computeLuminance(),
        lessThan(palette.pressedWhiteKey.computeLuminance()),
      );
      expect(
        palette.pressedBlackKeySeparator.computeLuminance(),
        lessThan(palette.pressedBlackKey.computeLuminance()),
      );
    });
  });
}

double _colorDistance(Color a, Color b) {
  final r = a.r - b.r;
  final g = a.g - b.g;
  final blue = a.b - b.b;
  return (r.abs() + g.abs() + blue.abs()) / 3.0;
}
