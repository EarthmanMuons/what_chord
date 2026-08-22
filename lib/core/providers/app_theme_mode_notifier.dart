import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../persistence/core_preferences_keys.dart';
import '../providers/shared_preferences_provider.dart';

final appThemeModeProvider = NotifierProvider<AppThemeModeNotifier, ThemeMode>(
  AppThemeModeNotifier.new,
);

class AppThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final stored = prefs.getString(CorePreferencesKeys.themeMode);

    if (stored == null) return ThemeMode.system;

    return switch (stored) {
      CorePreferencesValues.themeModeSystem => ThemeMode.system,
      CorePreferencesValues.themeModeLight => ThemeMode.light,
      CorePreferencesValues.themeModeDark => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    final serialized = switch (mode) {
      ThemeMode.system => CorePreferencesValues.themeModeSystem,
      ThemeMode.light => CorePreferencesValues.themeModeLight,
      ThemeMode.dark => CorePreferencesValues.themeModeDark,
    };
    await prefs.setString(CorePreferencesKeys.themeMode, serialized);
  }
}
