import 'package:material_ui/material_ui.dart';

@immutable
class PianoPalette {
  final Color background;
  final Color whiteKey;
  final Color pressedWhiteKey;
  final Color pressedBlackKey;
  final Color blackKey;
  final Color border;
  final Color pressedWhiteKeyBorder;
  final Color pressedWhiteKeySeparator;
  final Color pressedBlackKeySeparator;

  const PianoPalette({
    required this.background,
    required this.whiteKey,
    required this.pressedWhiteKey,
    required this.pressedBlackKey,
    required this.blackKey,
    required this.border,
    required this.pressedWhiteKeyBorder,
    required this.pressedWhiteKeySeparator,
    required this.pressedBlackKeySeparator,
  });
}

PianoPalette buildPianoPalette(ColorScheme cs) {
  final isDark = cs.brightness == Brightness.dark;

  final background = cs.surfaceContainerLow;

  final whiteKey = isDark
      ? Color.alphaBlend(cs.surface.withValues(alpha: 0.18), Colors.white)
      : Colors.white;

  final blackKey = const Color(0xFF111111);

  final border = Color.alphaBlend(
    Colors.black.withValues(alpha: isDark ? 0.30 : 0.22),
    whiteKey,
  );

  final pressedKeyAccent = isDark ? cs.primary : cs.inversePrimary;

  final pressedWhiteKey = Color.alphaBlend(
    pressedKeyAccent.withValues(alpha: isDark ? 0.78 : 0.66),
    whiteKey,
  );

  final pressedBlackKey = Color.alphaBlend(
    Colors.black.withValues(alpha: isDark ? 0.22 : 0.20),
    pressedKeyAccent,
  );

  final pressedWhiteKeyBorder = Color.alphaBlend(
    pressedKeyAccent.withValues(alpha: isDark ? 0.94 : 0.90),
    border,
  );

  final pressedWhiteKeySeparator = isDark
      ? Color.alphaBlend(Colors.black.withValues(alpha: 0.34), pressedWhiteKey)
      : Color.alphaBlend(Colors.black.withValues(alpha: 0.24), pressedWhiteKey);
  final pressedBlackKeySeparator = isDark
      ? Color.alphaBlend(Colors.black.withValues(alpha: 0.12), pressedBlackKey)
      : Color.alphaBlend(Colors.black.withValues(alpha: 0.10), pressedBlackKey);

  return PianoPalette(
    background: background,
    whiteKey: whiteKey,
    pressedWhiteKey: pressedWhiteKey,
    pressedBlackKey: pressedBlackKey,
    blackKey: blackKey,
    border: border,
    pressedWhiteKeyBorder: pressedWhiteKeyBorder,
    pressedWhiteKeySeparator: pressedWhiteKeySeparator,
    pressedBlackKeySeparator: pressedBlackKeySeparator,
  );
}
