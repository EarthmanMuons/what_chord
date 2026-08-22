import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/key/key.dart';

import '../models/bluetooth_unavailability.dart';
import '../models/midi_connection.dart';
import '../models/midi_connection_status.dart';
import '../models/midi_device.dart';
import 'midi_connection_notifier.dart';

/// Provides UI-friendly presentation of MIDI connection information.
final midiConnectionStatusProvider = Provider<MidiConnectionStatus>((ref) {
  final demoEnabled = ref.watch(demoModeProvider);
  final demoVariant = ref.watch(demoModeVariantProvider);
  // The key page screenshot seed poses as live play, so it shows the same
  // demo connection the screenshot variants do.
  final showDemoConnection =
      ref.watch(keyScreenshotSeedProvider) ||
      (demoEnabled &&
          (demoVariant == DemoModeVariant.screenshot ||
              demoVariant == DemoModeVariant.animation));
  if (showDemoConnection) {
    return const MidiConnectionStatus(
      phase: MidiConnectionPhase.connected,
      title: 'Connected',
      subtitle: 'Connected to Demo MIDI',
      deviceName: 'Demo MIDI',
      deviceTransport: MidiTransportType.unknown,
    );
  }

  final connectionState = ref.watch(midiConnectionStateProvider);
  final name = connectionState.deviceDisplayName;

  return switch (connectionState.phase) {
    MidiConnectionPhase.connected => MidiConnectionStatus(
      phase: connectionState.phase,
      title: 'Connected',
      subtitle: name != null ? 'Connected to $name' : 'Connected',
      deviceName: name,
      deviceTransport: connectionState.device?.transport,
    ),

    MidiConnectionPhase.connecting => const MidiConnectionStatus(
      phase: MidiConnectionPhase.connecting,
      title: 'Connecting…',
      subtitle: 'Connecting…',
    ),

    MidiConnectionPhase.retrying => MidiConnectionStatus(
      phase: MidiConnectionPhase.retrying,
      title: 'Reconnecting…',
      subtitle: connectionState.nextDelay != null
          ? 'Reconnecting (next in ${connectionState.nextDelay!.inSeconds}s)…'
          : 'Reconnecting…',
      attempt: connectionState.attempt,
      nextDelay: connectionState.nextDelay,
    ),

    MidiConnectionPhase.bluetoothUnavailable => () {
      final reason = connectionState.unavailability;
      final isPerm =
          reason == BluetoothUnavailability.permissionPermanentlyDenied;

      final label = switch (reason) {
        BluetoothUnavailability.adapterOff => 'Bluetooth is off',
        BluetoothUnavailability.permissionDenied ||
        BluetoothUnavailability.permissionPermanentlyDenied =>
          'Permissions required',
        BluetoothUnavailability.unsupported => 'Bluetooth unsupported',
        BluetoothUnavailability.notReady || null => 'Bluetooth unavailable',
      };

      final detail = switch (reason) {
        BluetoothUnavailability.adapterOff => 'Turn on Bluetooth to discover wireless MIDI devices. Wired USB MIDI devices may still be available.',
        BluetoothUnavailability.permissionDenied =>
          Platform.isAndroid
              ? 'Allow the Nearby devices permission to scan and connect to wireless Bluetooth MIDI devices.'
              : 'Allow Bluetooth access to discover and connect to wireless Bluetooth MIDI devices.',
        BluetoothUnavailability.permissionPermanentlyDenied =>
          Platform.isAndroid
              ? 'Enable the Nearby devices permission in system settings for this app.'
              : 'Enable Bluetooth access for this app in system settings. Wired USB MIDI devices may still be available.',
        BluetoothUnavailability.unsupported => 'This device does not support Bluetooth MIDI. Wired USB MIDI devices may still be available.',
        BluetoothUnavailability.notReady || null => 'Bluetooth is not ready yet for wireless MIDI discovery. Try again, or connect a wired USB MIDI device.',
      };

      return MidiConnectionStatus(
        phase: MidiConnectionPhase.bluetoothUnavailable,
        title: label,
        subtitle: detail,
        diagnosticMessage: connectionState.message,
        unavailability: reason,
        canOpenSettings: isPerm,
      );
    }(),

    MidiConnectionPhase.deviceUnavailable => MidiConnectionStatus(
      phase: MidiConnectionPhase.deviceUnavailable,
      title: 'Device unavailable',
      subtitle: connectionState.message ?? 'Device unavailable',
      diagnosticMessage: connectionState.message,
    ),

    MidiConnectionPhase.error => MidiConnectionStatus(
      phase: MidiConnectionPhase.error,
      title: 'Error',
      subtitle: connectionState.message ?? 'Error',
      diagnosticMessage: connectionState.message,
    ),

    MidiConnectionPhase.idle => const MidiConnectionStatus(
      phase: MidiConnectionPhase.idle,
      title: 'Not connected',
      subtitle: 'Not connected',
    ),
  };
});
