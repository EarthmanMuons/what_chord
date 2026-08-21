import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/home/home.dart';

import '../models/midi_device.dart';
import '../providers/midi_connection_notifier.dart';
import '../providers/midi_connection_status_provider.dart';
import '../widgets/last_connected_device_card.dart';
import '../widgets/midi_device_picker.dart';
import '../widgets/midi_status_card.dart';

class MidiSettingsPage extends ConsumerStatefulWidget {
  const MidiSettingsPage({super.key});

  @override
  ConsumerState<MidiSettingsPage> createState() => _MidiSettingsPageState();
}

class _MidiSettingsPageState extends ConsumerState<MidiSettingsPage> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final status = ref.watch(midiConnectionStatusProvider);

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
          child: const Text('MIDI Settings'),
        ),
        backgroundColor: cs.surfaceContainerLow,
        foregroundColor: cs.onSurface,
        toolbarHeight: toolbarHeight,
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MidiStatusCard(status: status),

            if (status.canOpenSettings) ...[
              const SizedBox(height: 8),
              Card(
                child: Semantics(
                  onTapHint: 'Open system settings',
                  child: ListTile(
                    leading: const Icon(Icons.settings),
                    title: const Text('Open system settings for WhatChord'),
                    onTap: () async {
                      await openAppSettings();
                    },
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),
            const SectionHeader(title: 'Device'),

            const LastConnectedDeviceCard(),
            const SizedBox(height: 12),

            Card(
              child: Semantics(
                onTapHint: 'Open MIDI device picker',
                child: ListTile(
                  leading: const Icon(Icons.add_link),
                  title: Text(
                    status.isConnected
                        ? 'Choose different device'
                        : 'Choose device',
                  ),
                  subtitle: const Text('Scan for available MIDI devices'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await showAdaptiveMidiDevicePicker(context).whenComplete(
                      () {
                        unawaited(
                          ref
                              .read(midiConnectionStateProvider.notifier)
                              .stopScanning(),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<MidiDevice?> showAdaptiveMidiDevicePicker(BuildContext context) {
  Color resolvePanelColor(BuildContext context) {
    final theme = Theme.of(context);
    return theme.bottomSheetTheme.modalBackgroundColor ??
        theme.bottomSheetTheme.backgroundColor ??
        theme.colorScheme.surfaceContainerLow;
  }

  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  final isCompact = shortestSide < 600;

  if (isCompact) {
    return showModalBottomSheet<MidiDevice>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: resolvePanelColor(context),
      builder: (context) {
        final maxSheetHeight = modalBottomSheetMaxHeight(
          context,
          portraitFraction: 0.82,
        );

        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxSheetHeight),
          child: const MidiDevicePicker(showCloseButton: false),
        );
      },
    );
  }

  final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.82;

  return showDialog<MidiDevice>(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: maxDialogHeight,
          ),
          child: Material(
            color: resolvePanelColor(context),
            child: const MidiDevicePicker(showCloseButton: true),
          ),
        ),
      );
    },
  );
}
