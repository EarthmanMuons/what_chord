import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/audio/audio.dart';
import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/home/home.dart';
import 'package:whatchord_app/features/key/key.dart';
import 'package:whatchord_app/features/midi/midi.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../services/settings_reset_service.dart';
import 'debug_log_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key, this.scrollToPlayingMode = false});

  /// Scrolls to and reveals the Playing Mode section on open; the tonality
  /// bar's ensemble badge deep-links here.
  final bool scrollToPlayingMode;

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isAdjustingAudioVolume = false;
  Timer? _audioVolumeLabelDismissTimer;
  Timer? _volumePreviewDebounceTimer;

  static const int _volumePreviewMidiNote = 60;
  static const Duration _sliderVolumePreviewDebounce = Duration(
    milliseconds: 250,
  );

  // Cached so dispose() can cancel preview notes without touching ref, which is
  // unsafe once the widget is being unmounted.
  late final AudioMonitorNotifier _audioMonitor;

  final _scrollController = ScrollController();
  final _playingModeSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _audioMonitor = ref.read(audioMonitorNotifier.notifier);
    if (widget.scrollToPlayingMode) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_revealPlayingMode());
      });
    }
  }

  /// Scrolls until the Playing Mode section is built (the ListView is lazy,
  /// so its context may not exist until the viewport reaches it), then aligns
  /// it near the top.
  Future<void> _revealPlayingMode() async {
    for (var attempt = 0; attempt < 20; attempt++) {
      if (!mounted) return;
      final sectionContext = _playingModeSectionKey.currentContext;
      if (sectionContext != null && sectionContext.mounted) {
        await Scrollable.ensureVisible(
          sectionContext,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          alignment: 0,
        );
        return;
      }
      if (!_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.pixels >= position.maxScrollExtent) return;
      _scrollController.jumpTo(
        (position.pixels + position.viewportDimension).clamp(
          0,
          position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  @override
  void dispose() {
    _audioVolumeLabelDismissTimer?.cancel();
    _audioVolumeLabelDismissTimer = null;
    _volumePreviewDebounceTimer?.cancel();
    _volumePreviewDebounceTimer = null;
    _audioMonitor.cancelPreviewNotes();
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleVolumePreview(Duration debounce) {
    _volumePreviewDebounceTimer?.cancel();
    final monitor = ref.read(audioMonitorNotifier.notifier);
    monitor.cancelPreviewNotes();
    _volumePreviewDebounceTimer = Timer(debounce, () {
      _volumePreviewDebounceTimer = null;
      if (!mounted) return;
      monitor.playVolumePreviewNote(_volumePreviewMidiNote);
    });
  }

  void _showCurrentVolume() {
    _showAudioVolumePercentLabel();
    _scheduleVolumeLabelDismiss();
  }

  void _showAudioVolumePercentLabel() {
    _audioVolumeLabelDismissTimer?.cancel();
    _audioVolumeLabelDismissTimer = null;
    if (_isAdjustingAudioVolume) return;
    setState(() => _isAdjustingAudioVolume = true);
  }

  void _scheduleVolumeLabelDismiss() {
    _audioVolumeLabelDismissTimer?.cancel();
    _audioVolumeLabelDismissTimer = Timer(
      const Duration(milliseconds: 900),
      () {
        if (!mounted) return;
        setState(() => _isAdjustingAudioVolume = false);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final chordNotationStyle = ref.watch(chordNotationStyleProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final themeMode = ref.watch(appThemeModeProvider);
    final palette = ref.watch(appPaletteProvider);
    final palettes = [...AppPalette.values]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    final midiStatus = ref.watch(midiConnectionStatusProvider);
    final midiConnected = midiStatus.phase == MidiConnectionPhase.connected;
    final audioSettings = ref.watch(audioMonitorSettingsNotifier);
    final audioVolumePercent = (audioSettings.volume * 100).round();

    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final toolbarHeight =
        isLandscape && defaultTargetPlatform == TargetPlatform.android
        ? kAndroidLandscapeToolbarHeight
        : kToolbarHeight;

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          header: true,
          namesRoute: true,
          child: const Text('Settings'),
        ),
        backgroundColor: cs.surfaceContainerLow,
        foregroundColor: cs.onSurface,
        scrolledUnderElevation: 0,
        toolbarHeight: toolbarHeight,
      ),
      body: SafeArea(
        top: false,
        child: Scrollbar(
          controller: _scrollController,
          child: ListView(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              const SectionHeader(title: 'Input', icon: Icons.piano),

              Semantics(
                onTapHint: 'Open MIDI settings',
                child: ListTile(
                  title: const Text('MIDI Settings'),
                  subtitle: Text(midiStatus.subtitle ?? midiStatus.title),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const MidiSettingsPage(),
                        ),
                      ),
                    );
                  },
                ),
              ),

              _AudioMonitorModeControl(
                mode: audioSettings.mode,
                midiAvailable: midiConnected,
                onModeChanged: (mode) {
                  unawaited(
                    ref
                        .read(audioMonitorSettingsNotifier.notifier)
                        .setMode(mode),
                  );
                },
              ),

              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Semantics(
                      button: true,
                      label: 'Playback Volume',
                      hint: 'Show current playback volume',
                      onTapHint: 'Show current playback volume',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _showCurrentVolume,
                        child: const Text('Playback Volume'),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: audioSettings.muted
                          ? const Text(' Muted', key: ValueKey<String>('muted'))
                          : _isAdjustingAudioVolume
                          ? Text(
                              ' $audioVolumePercent%',
                              key: ValueKey<int>(audioVolumePercent),
                            )
                          : const SizedBox.shrink(key: ValueKey<String>('off')),
                    ),
                  ],
                ),
                subtitle: Semantics(
                  container: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          _AudioMuteButton(
                            muted: audioSettings.muted,
                            onPressed: () {
                              unawaited(
                                ref
                                    .read(audioMonitorSettingsNotifier.notifier)
                                    .setMuted(!audioSettings.muted),
                              );
                              unawaited(HapticFeedback.selectionClick());
                            },
                          ),
                          Expanded(
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 150),
                              opacity: audioSettings.muted ? 0.38 : 1,
                              child: IgnorePointer(
                                ignoring: audioSettings.muted,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    tickMarkShape:
                                        SliderTickMarkShape.noTickMark,
                                  ),
                                  child: Slider(
                                    value: audioSettings.volume,
                                    min: 0,
                                    max: 1,
                                    divisions: 20,
                                    onChangeStart: (_) {
                                      _showAudioVolumePercentLabel();
                                    },
                                    onChangeEnd: (_) {
                                      _scheduleVolumeLabelDismiss();
                                    },
                                    onChanged: (value) {
                                      _showAudioVolumePercentLabel();
                                      unawaited(
                                        ref
                                            .read(
                                              audioMonitorSettingsNotifier
                                                  .notifier,
                                            )
                                            .setVolume(value),
                                      );
                                      _scheduleVolumePreview(
                                        _sliderVolumePreviewDebounce,
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Chord Display Options',
                icon: Icons.queue_music_outlined,
              ),

              const SubsectionLabel(title: 'Notation Style'),
              RadioGroup<ChordNotationStyle>(
                groupValue: chordNotationStyle,
                onChanged: (ChordNotationStyle? style) {
                  if (style == null) return;
                  unawaited(
                    ref
                        .read(chordNotationStyleProvider.notifier)
                        .setStyle(style),
                  );
                },
                child: const Column(
                  children: [
                    _SettingsRadioOption<ChordNotationStyle>(
                      title: Text('Textual'),
                      subtitle: Text('Cmaj7, F♯m7(♭5), Bdim7'),
                      value: ChordNotationStyle.textual,
                    ),
                    _SettingsRadioOption<ChordNotationStyle>(
                      title: Text('Symbolic'),
                      subtitle: Text('CΔ7, F♯ø7, B°7'),
                      value: ChordNotationStyle.symbolic,
                    ),
                  ],
                ),
              ),

              const SubsectionLabel(title: 'Note Names'),
              RadioGroup<NoteNameSystem>(
                groupValue: noteNameSystem,
                onChanged: (NoteNameSystem? system) {
                  if (system == null) return;
                  unawaited(
                    ref.read(noteNameSystemProvider.notifier).setSystem(system),
                  );
                },
                child: const Column(
                  children: [
                    _SettingsRadioOption<NoteNameSystem>(
                      title: Text('International'),
                      subtitle: Text('C, F♯, B♭'),
                      value: NoteNameSystem.international,
                    ),
                    _SettingsRadioOption<NoteNameSystem>(
                      title: Text('German'),
                      subtitle: Text('C, Fis, B'),
                      value: NoteNameSystem.german,
                    ),
                    _SettingsRadioOption<NoteNameSystem>(
                      title: Text('Fixed-Do'),
                      subtitle: Text('Do, Fa♯, Si♭'),
                      value: NoteNameSystem.fixedDo,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const SectionHeader(title: 'Key Detection', icon: Icons.key),

              _KeyBehaviorControl(
                behavior: ref.watch(keyBehaviorProvider),
                onChanged: (behavior) {
                  unawaited(
                    ref
                        .read(keyBehaviorProvider.notifier)
                        .setBehavior(behavior),
                  );
                },
              ),

              const SizedBox(height: 16),
              SectionHeader(
                key: _playingModeSectionKey,
                title: 'Playing Mode',
                icon: Icons.groups_outlined,
              ),

              _PlayingContextControl(
                playingContext: ref.watch(playingContextProvider),
                onChanged: (playingContext) {
                  unawaited(
                    ref
                        .read(playingContextProvider.notifier)
                        .setContext(playingContext),
                  );
                },
              ),

              const SizedBox(height: 16),
              const SectionHeader(
                title: 'Appearance',
                icon: Icons.palette_outlined,
              ),

              const SubsectionLabel(title: 'Theme'),
              const SizedBox(height: 8),

              SegmentedButton<ThemeMode>(
                segments: const <ButtonSegment<ThemeMode>>[
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text('System'),
                    icon: Icon(Icons.settings_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text('Light'),
                    icon: Icon(Icons.light_mode_outlined),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text('Dark'),
                    icon: Icon(Icons.dark_mode_outlined),
                  ),
                ],
                selected: <ThemeMode>{themeMode},
                onSelectionChanged: (selection) {
                  unawaited(
                    ref
                        .read(appThemeModeProvider.notifier)
                        .setThemeMode(selection.first),
                  );
                },
              ),

              const SizedBox(height: 8),
              ListTile(
                leading: PaletteSwatch(palette: palette),
                title: const Text('Color Palette'),
                subtitle: Text(palette.label),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  await showAdaptiveSelectionSheet<void>(
                    context: context,
                    title: 'Color Palette',
                    builder: (context) {
                      return _PaletteSelectionList(palettes: palettes);
                    },
                  );
                },
              ),

              const SizedBox(height: 16),
              const SectionHeader(title: 'About'),
              Semantics(
                onLongPressHint: 'Copy app version to clipboard',
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('WhatChord'),
                  subtitle: ref
                      .watch(appVersionProvider)
                      .when(
                        data: (v) => Text('Version $v'),
                        loading: () => const Text('Version —'),
                        error: (_, _) => const Text('Version unavailable'),
                      ),
                  onLongPress: () async {
                    final version = ref.read(appVersionProvider).asData?.value;
                    if (version == null) return;

                    final messenger =
                        Theme.of(context).platform == TargetPlatform.iOS
                        ? ScaffoldMessenger.maybeOf(context)
                        : null;

                    await Clipboard.setData(
                      ClipboardData(text: 'WhatChord v$version'),
                    );

                    messenger?.hideCurrentSnackBar();
                    messenger?.showSnackBar(
                      const SnackBar(
                        content: Text('Copied software version to clipboard'),
                      ),
                    );
                  },
                ),
              ),

              Semantics(
                onTapHint: 'Open help and support',
                child: ListTile(
                  leading: const Icon(Icons.support_agent_outlined),
                  title: const Text('Help & Support'),
                  subtitle: const Text('Instructions, reporting, and contact'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => showSupportSheet(
                    context,
                    onReplayTour: () {
                      ref
                          .read(demoModeProvider.notifier)
                          .setEnabledFor(
                            enabled: true,
                            variant: DemoModeVariant.interactive,
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ),

              Semantics(
                onTapHint: 'Open GitHub repository in browser',
                child: ListTile(
                  leading: const Icon(Icons.code),
                  title: const Text('Source Code'),
                  subtitle: const Text('Browse the repository on GitHub'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    unawaited(
                      openUrl(
                        context,
                        Uri.parse('https://github.com/EarthmanMuons/whatchord'),
                      ),
                    );
                  },
                ),
              ),

              Semantics(
                onTapHint: 'Open privacy policy in browser',
                child: ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  subtitle: const Text('No data collected'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    unawaited(
                      openUrl(
                        context,
                        Uri.parse(
                          'https://github.com/EarthmanMuons/whatchord/blob/main/PRIVACY.md',
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (!kReleaseMode)
                Semantics(
                  onTapHint: 'Open console logs',
                  child: ListTile(
                    leading: const Icon(Icons.terminal),
                    title: const Text('Console Logs'),
                    subtitle: const Text('Captured debug output'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      unawaited(
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const DebugLogPage(),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Reset to Defaults'),
                subtitle: const Text(
                  'Clear all saved preferences and disconnect MIDI',
                ),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Reset to defaults?'),
                      content: const Text(
                        'This will reset your preferences and forget any saved MIDI devices.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.onError,
                          ),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed != true) return;

                  await ref.read(settingsResetProvider).resetAllToDefaults();

                  if (context.mounted) {
                    await HapticFeedback.lightImpact();
                    if (!context.mounted) return;

                    ref
                        .read(demoModeProvider.notifier)
                        .setEnabledFor(
                          enabled: true,
                          variant: DemoModeVariant.interactive,
                        );
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioMonitorModeControl extends StatelessWidget {
  const _AudioMonitorModeControl({
    required this.mode,
    required this.midiAvailable,
    required this.onModeChanged,
  });

  final AudioMonitorMode mode;
  final bool midiAvailable;
  final ValueChanged<AudioMonitorMode> onModeChanged;

  static const String _midiUnavailableMessage =
      'Connect a MIDI device to play through its speakers';

  String get _description => switch (mode) {
    AudioMonitorMode.internal => 'Hear piano sounds through this device',
    AudioMonitorMode.midiOut =>
      'Play previews through the connected MIDI device',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Audio Monitor', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            _description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            label: 'Audio monitor output',
            hint: midiAvailable
                ? 'Choose off, internal, or MIDI out'
                : 'MIDI out disabled. $_midiUnavailableMessage',
            child: SegmentedButton<AudioMonitorMode>(
              // Styling comes from the app's segmentedButtonTheme so this toggle
              // shares the selection accent used across the app.
              showSelectedIcon: false,
              segments: [
                const ButtonSegment(
                  value: AudioMonitorMode.internal,
                  icon: Icon(Icons.volume_up_outlined),
                  label: Text('Internal'),
                ),
                ButtonSegment(
                  value: AudioMonitorMode.midiOut,
                  icon: const Icon(Icons.piano_outlined),
                  label: const Text('MIDI Out'),
                  enabled: midiAvailable,
                  tooltip: midiAvailable ? null : _midiUnavailableMessage,
                ),
              ],
              selected: {mode},
              onSelectionChanged: (selection) => onModeChanged(selection.first),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayingContextControl extends StatelessWidget {
  const _PlayingContextControl({
    required this.playingContext,
    required this.onChanged,
  });

  final PlayingContext playingContext;
  final ValueChanged<PlayingContext> onChanged;

  String get _description => switch (playingContext) {
    PlayingContext.solo => 'Names chords from the notes you play',
    PlayingContext.ensemble => 'Names rootless voicings over a bassist',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<PlayingContext>(
            segments: const <ButtonSegment<PlayingContext>>[
              ButtonSegment(
                value: PlayingContext.solo,
                label: Text('Solo'),
                icon: Icon(Icons.person_outline),
              ),
              ButtonSegment(
                value: PlayingContext.ensemble,
                label: Text('Ensemble'),
                icon: Icon(Icons.groups_outlined),
              ),
            ],
            selected: <PlayingContext>{playingContext},
            onSelectionChanged: (selection) {
              final next = selection.first;
              if (next != playingContext) {
                onChanged(next);
                unawaited(HapticFeedback.selectionClick());
              }
            },
          ),
          const SizedBox(height: 8),
          Text(
            _description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _KeyBehaviorControl extends StatelessWidget {
  const _KeyBehaviorControl({required this.behavior, required this.onChanged});

  final KeyBehavior behavior;
  final ValueChanged<KeyBehavior> onChanged;

  static String _label(KeyBehavior behavior) => switch (behavior) {
    KeyBehavior.stable => 'Stable',
    KeyBehavior.balanced => 'Balanced',
    KeyBehavior.reactive => 'Reactive',
  };

  String get _description => switch (behavior) {
    KeyBehavior.stable => "Holds the song's key steady through detours",
    KeyBehavior.balanced => 'Follows key changes within a few chords',
    KeyBehavior.reactive => 'Closely tracks your current tonal center',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Behavior', style: theme.textTheme.titleMedium),
          const SizedBox(height: 2),
          Text(
            _description,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Semantics(
            label: 'Key detection behavior',
            child: Slider(
              value: behavior.index.toDouble(),
              max: (KeyBehavior.values.length - 1).toDouble(),
              divisions: KeyBehavior.values.length - 1,
              semanticFormatterCallback: (value) =>
                  _label(KeyBehavior.values[value.round()]),
              onChanged: (value) {
                final next = KeyBehavior.values[value.round()];
                if (next != behavior) {
                  onChanged(next);
                  unawaited(HapticFeedback.selectionClick());
                }
              },
            ),
          ),
          // Stop labels aligned under the slider track ends and center;
          // tapping one selects it directly.
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                for (final option in KeyBehavior.values)
                  Expanded(
                    child: _KeyBehaviorStopLabel(
                      label: _label(option),
                      selected: option == behavior,
                      alignment: switch (option.index) {
                        0 => Alignment.centerLeft,
                        _ when option.index == KeyBehavior.values.length - 1 =>
                          Alignment.centerRight,
                        _ => Alignment.center,
                      },
                      onTap: () => onChanged(option),
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

class _KeyBehaviorStopLabel extends StatelessWidget {
  const _KeyBehaviorStopLabel({
    required this.label,
    required this.selected,
    required this.alignment,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Alignment alignment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      onTapHint: 'Set key detection to $label',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? cs.primary : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AudioMuteButton extends StatelessWidget {
  const _AudioMuteButton({required this.muted, required this.onPressed});

  final bool muted;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      onPressed: onPressed,
      tooltip: muted ? 'Unmute playback' : 'Mute playback',
      isSelected: muted,
      icon: const Icon(Icons.volume_off_outlined),
      style: IconButton.styleFrom(
        foregroundColor: muted ? cs.onPrimaryContainer : cs.outline,
        backgroundColor: muted ? cs.primaryContainer : cs.surfaceContainerLow,
        side: BorderSide(
          color: muted ? cs.primary : cs.outlineVariant.withValues(alpha: 0.70),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        fixedSize: const Size(48, 40),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
    );
  }
}

class _SettingsRadioOption<T> extends StatelessWidget {
  const _SettingsRadioOption({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  final Widget title;
  final Widget subtitle;
  final T value;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      contentPadding: EdgeInsets.zero,
      visualDensity: const VisualDensity(vertical: -2),
      title: title,
      subtitle: subtitle,
      value: value,
    );
  }
}

class _PaletteSelectionList extends ConsumerWidget {
  const _PaletteSelectionList({required this.palettes});

  final List<AppPalette> palettes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(appPaletteProvider);
    final cs = Theme.of(context).colorScheme;
    final selectedRowColor = cs.primaryContainer.withValues(alpha: 0.55);

    return ListView(
      shrinkWrap: true,
      children: [
        for (final p in palettes)
          Semantics(
            container: true,
            button: true,
            selected: p == current,
            label: '${p.label} palette',
            onTapHint: 'Apply color palette',
            child: ExcludeSemantics(
              child: Material(
                type: MaterialType.transparency,
                child: ListTile(
                  selected: p == current,
                  selectedColor: cs.onSurface,
                  selectedTileColor: selectedRowColor,
                  textColor: cs.onSurface,
                  iconColor: cs.onSurfaceVariant,
                  leading: PaletteSwatch(palette: p),
                  title: Text(p.label),
                  trailing: p == current
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () =>
                      ref.read(appPaletteProvider.notifier).setPalette(p),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
