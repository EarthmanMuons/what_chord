import 'package:material_ui/material_ui.dart';

import '../models/app_palette.dart';

ColorScheme colorSchemeFor(AppPalette palette, Brightness brightness) {
  return switch (palette) {
    AppPalette.neutral =>
      brightness == Brightness.dark
          ? _NeutralSchemes.dark
          : _NeutralSchemes.light,
    _ => ColorScheme.fromSeed(
      seedColor: palette.seedColor,
      brightness: brightness,
    ),
  };
}

ThemeData buildAppTheme({
  required AppPalette palette,
  required Brightness brightness,
}) {
  final cs = colorSchemeFor(palette, brightness);

  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'WhatChord Symbols',
    fontFamilyFallback: const ['Inter'],
    colorScheme: cs,
    appBarTheme: const AppBarTheme(centerTitle: false),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      elevation: 2,
      showCloseIcon: true,
      insetPadding: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: cs.inverseSurface,
      contentTextStyle: TextStyle(color: cs.onInverseSurface),
      actionTextColor: cs.inversePrimary,
      disabledActionTextColor: cs.onInverseSurface.withValues(alpha: 0.38),
      closeIconColor: cs.onInverseSurface,
    ),
  );

  return base.copyWith(
    // Selection accent lives here so every SegmentedButton (the Scale Explorer's
    // Chords/Scales toggle, the settings theme toggle) shares the app's
    // primaryContainer selection accent rather than M3's default
    // secondaryContainer. The custom scrubbers and note chips already use the
    // same accent.
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.surfaceContainerLow.withValues(alpha: 0.48);
          }
          return states.contains(WidgetState.selected)
              ? cs.primaryContainer
              : cs.surfaceContainerLow;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return cs.onSurface.withValues(alpha: 0.38);
          }
          return states.contains(WidgetState.selected)
              ? cs.onPrimaryContainer
              : cs.onSurface;
        }),
        textStyle: WidgetStateProperty.resolveWith(
          (states) => base.textTheme.labelLarge?.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(
            color: cs.outlineVariant.withValues(
              alpha: states.contains(WidgetState.disabled) ? 0.32 : 0.70,
            ),
          ),
        ),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    ),
  );
}

class _NeutralSchemes {
  static const light = ColorScheme(
    brightness: Brightness.light,

    primary: Color(0xFF3A3A3A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFE5E5E5),
    onPrimaryContainer: Color(0xFF1B1B1B),

    secondary: Color(0xFF4A4A4A),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFDEDEDE),
    onSecondaryContainer: Color(0xFF1B1B1B),

    tertiary: Color(0xFF5A5A5A),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFD6D6D6),
    onTertiaryContainer: Color(0xFF1B1B1B),

    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFF9DEDC),
    onErrorContainer: Color(0xFF410E0B),

    surface: Color(0xFFFAFAFA),
    onSurface: Color(0xFF1A1A1A),
    surfaceDim: Color(0xFFEDEDED),
    surfaceBright: Color(0xFFFAFAFA),

    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFF4F4F4),
    surfaceContainer: Color(0xFFEFEFEF),
    surfaceContainerHigh: Color(0xFFE9E9E9),
    surfaceContainerHighest: Color(0xFFE2E2E2),

    onSurfaceVariant: Color(0xFF444444),
    outline: Color(0xFF7A7A7A),
    outlineVariant: Color(0xFFC9C9C9),

    inverseSurface: Color(0xFF2A2A2A),
    onInverseSurface: Color(0xFFF1F1F1),
    inversePrimary: Color(0xFFCFCFCF),

    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Color(0xFF3A3A3A),
  );

  static const dark = ColorScheme(
    brightness: Brightness.dark,

    primary: Color(0xFFD0D0D0),
    onPrimary: Color(0xFF1A1A1A),
    primaryContainer: Color(0xFF2F2F2F),
    onPrimaryContainer: Color(0xFFEAEAEA),

    secondary: Color(0xFFC6C6C6),
    onSecondary: Color(0xFF1A1A1A),
    secondaryContainer: Color(0xFF323232),
    onSecondaryContainer: Color(0xFFEAEAEA),

    tertiary: Color(0xFFBCBCBC),
    onTertiary: Color(0xFF1A1A1A),
    tertiaryContainer: Color(0xFF353535),
    onTertiaryContainer: Color(0xFFEAEAEA),

    error: Color(0xFFF2B8B5),
    onError: Color(0xFF601410),
    errorContainer: Color(0xFF8C1D18),
    onErrorContainer: Color(0xFFF9DEDC),

    surface: Color(0xFF121212),
    onSurface: Color(0xFFE6E6E6),
    surfaceDim: Color(0xFF0F0F0F),
    surfaceBright: Color(0xFF1C1C1C),

    surfaceContainerLowest: Color(0xFF0D0D0D),
    surfaceContainerLow: Color(0xFF151515),
    surfaceContainer: Color(0xFF1A1A1A),
    surfaceContainerHigh: Color(0xFF202020),
    surfaceContainerHighest: Color(0xFF262626),

    onSurfaceVariant: Color(0xFFBDBDBD),
    outline: Color(0xFF8A8A8A),
    outlineVariant: Color(0xFF3A3A3A),

    inverseSurface: Color(0xFFE6E6E6),
    onInverseSurface: Color(0xFF242424),
    inversePrimary: Color(0xFF3A3A3A),

    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Color(0xFFD0D0D0),
  );
}
