import 'package:material_ui/material_ui.dart';

enum AppPalette { blue, teal, green, orange, pink, purple, neutral }

extension AppPaletteProperties on AppPalette {
  String get label => switch (this) {
    AppPalette.blue => 'Blue',
    AppPalette.teal => 'Teal',
    AppPalette.green => 'Green',
    AppPalette.orange => 'Orange',
    AppPalette.pink => 'Pink',
    AppPalette.purple => 'Purple',
    AppPalette.neutral => 'Neutral',
  };

  Color get seedColor => switch (this) {
    AppPalette.blue => Color(0xFF1E90FF),
    AppPalette.teal => const Color(0xFF17CDB9),
    AppPalette.green => const Color(0xFF63A002),
    AppPalette.orange => const Color(0XFFF8A960),
    AppPalette.pink => const Color(0xFFFF69B4),
    AppPalette.purple => const Color(0xFF6750A4),
    AppPalette.neutral => const Color(0xFF6B6B6B),
  };

  int get sortOrder => switch (this) {
    AppPalette.blue => 10,
    AppPalette.teal => 20,
    AppPalette.green => 30,
    AppPalette.orange => 40,
    AppPalette.pink => 50,
    AppPalette.purple => 60,
    AppPalette.neutral => 70,
  };
}

extension AppPalettePersistence on AppPalette {
  String get prefsKey => switch (this) {
    AppPalette.blue => 'blue',
    AppPalette.teal => 'teal',
    AppPalette.green => 'green',
    AppPalette.orange => 'orange',
    AppPalette.pink => 'pink',
    AppPalette.purple => 'purple',
    AppPalette.neutral => 'neutral',
  };

  static AppPalette fromPrefsKey(String key) {
    return AppPalette.values.firstWhere(
      (p) => p.prefsKey == key,
      orElse: () => AppPalette.blue,
    );
  }
}
