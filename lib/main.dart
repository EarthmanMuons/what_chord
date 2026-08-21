import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/audio/audio.dart';
import 'package:whatchord_app/features/history/history.dart';
import 'package:whatchord_app/features/home/home.dart';
import 'package:whatchord_app/features/key/key.dart';
import 'package:whatchord_app/features/links/links.dart';
import 'package:whatchord_app/features/midi/midi.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kReleaseMode) {
    // Capture debugPrint diagnostics and unhandled errors for the in-app
    // console log viewer (Settings > About), so untethered profile-build
    // sessions can be inspected.
    DebugLogBuffer.instance.install();
    DebugLogBuffer.instance.captureUnhandledErrors();
  }

  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Core app lifecycle hooks.
    ref.watch(appResumeWakeupProvider);
    ref.watch(appMidiLifecycleProvider);
    ref.watch(appAudioMonitorLifecycleProvider);
    ref.watch(appChordHistoryLifecycleProvider);
    ref.watch(appInternalKeyLifecycleProvider);
    ref.watch(appDeepLinkProvider);

    final themeMode = ref.watch(appThemeModeProvider);
    final palette = ref.watch(appPaletteProvider);

    return MaterialApp(
      title: 'WhatChord',
      debugShowCheckedModeBanner: false,
      navigatorKey: ref.watch(appNavigatorKeyProvider),

      themeMode: themeMode,
      theme: buildAppTheme(palette: palette, brightness: Brightness.light),
      darkTheme: buildAppTheme(palette: palette, brightness: Brightness.dark),

      builder: (context, child) {
        return IdleBlackoutOverlay(child: child ?? const SizedBox.shrink());
      },
      home: const HomePage(),
    );
  }
}
