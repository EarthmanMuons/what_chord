import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/midi_connection.dart';
import '../models/midi_device.dart';
import '../providers/midi_connection_notifier.dart';
import '../providers/midi_device_manager.dart';
import '../providers/midi_preferences_notifier.dart';

class LastConnectedDeviceCard extends ConsumerWidget {
  const LastConnectedDeviceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasLastConnected = ref.watch(hasLastConnectedMidiDeviceProvider);
    final lastConnected = ref.watch(lastConnectedMidiDeviceProvider);

    // Connection semantics from the state machine.
    final isAttemptingConnection = ref.watch(
      midiConnectionStateProvider.select((s) => s.isAttemptingConnection),
    );
    final isConnected = ref.watch(
      midiConnectionStateProvider.select((s) => s.isConnected),
    );
    final connectionDisplayName = ref.watch(
      midiConnectionStateProvider.select((s) => s.deviceDisplayName),
    );

    // Transport snapshot (who is connected).
    final connected = ref.watch(
      midiDeviceManagerProvider.select((s) => s.connectedDevice),
    );
    final connectedDisplayName = connected?.displayName;

    final lastConnectedIdNormalized = ref.watch(
      lastConnectedMidiDeviceIdProvider.select((id) {
        if (id == null) return null;
        final t = id.trim();
        return t.isEmpty ? null : t;
      }),
    );

    // If there is no last-connected device persisted, do not render the card at all
    // (but still show if currently connected, to allow Disconnect).
    if (lastConnectedIdNormalized == null && !isConnected) {
      return const SizedBox.shrink();
    }

    // Prefer the current connection name while busy/connected; otherwise fall back
    // to the transport snapshot.
    final effectiveConnectedName = (isAttemptingConnection || isConnected)
        ? (connectionDisplayName ?? connectedDisplayName)
        : connectedDisplayName;

    // Fall back to persisted last-connected device name.
    final lastConnectedDisplayName = lastConnected?.displayName;

    final title =
        effectiveConnectedName ??
        lastConnectedDisplayName ??
        'Last connected device';
    final displayTransport =
        connected?.transport ??
        lastConnected?.transport ??
        MidiTransportType.ble;
    final leadingIcon = switch (displayTransport) {
      MidiTransportType.ble => Icons.bluetooth,
      MidiTransportType.usb => Icons.usb,
      MidiTransportType.network => Icons.wifi,
      MidiTransportType.unknown => Icons.piano,
    };

    final actionButtonStyle = FilledButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    final forgetButtonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );

    final bool canReconnect = !isConnected && hasLastConnected;
    final String primaryLabel = isAttemptingConnection
        ? 'Cancel'
        : isConnected
        ? 'Disconnect'
        : 'Reconnect';

    final VoidCallback? primaryAction = isAttemptingConnection
        ? () => ref.read(midiConnectionStateProvider.notifier).cancel()
        : isConnected
        ? () async {
            await ref.read(midiConnectionStateProvider.notifier).disconnect();
          }
        : canReconnect
        ? () async {
            await ref
                .read(midiConnectionStateProvider.notifier)
                .tryAutoReconnect(reason: MidiReconnectTrigger.manual);
          }
        : null;

    Future<void> forgetDevice() async {
      final shouldForget = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Forget this device?'),
            content: const Text(
              'This will disconnect your device and it won\'t reconnect automatically next time.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: const Text('Forget'),
              ),
            ],
          );
        },
      );

      if (shouldForget != true) return;

      await ref
          .read(midiConnectionStateProvider.notifier)
          .cancel(reason: MidiCancelReason.forgetDevice);
      await ref.read(midiConnectionStateProvider.notifier).disconnect();

      await ref
          .read(midiPreferencesProvider.notifier)
          .clearLastConnectedDevice();

      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Device forgotten')));
      await HapticFeedback.lightImpact();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(leadingIcon),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: forgetButtonStyle,
                    onPressed: forgetDevice,
                    child: const Text('Forget'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: actionButtonStyle,
                    onPressed: primaryAction,
                    child: Text(primaryLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
