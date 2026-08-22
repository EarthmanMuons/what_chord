import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_midi_command/flutter_midi_command.dart' as fmc;
import 'package:flutter_midi_command/flutter_midi_command_messages.dart' as msg;

import '../models/bluetooth_state.dart';
import '../models/midi_device.dart';
import '../models/midi_message.dart';

/// Low-level MIDI-over-BLE (Bluetooth Low Energy) transport service.
///
/// Wraps flutter_midi_command plugin interactions. Higher-level orchestration
/// (scanning workflow, retries, state management) lives in [MidiDeviceManager]
/// and [MidiConnectionNotifier].
class MidiBleService {
  MidiBleService(this._midi);

  final fmc.MidiCommand _midi;

  // ---- Streams -----------------------------------------------------------

  Stream<BluetoothState> get onBluetoothStateChanged =>
      _midi.onBluetoothStateChanged.map(_mapBluetoothState);

  /// Emits an event whenever the underlying MIDI setup changes.
  ///
  /// Some platforms/versions may not expose this stream; in that case it is empty.
  Stream<void> get onMidiSetupChanged =>
      (_midi.onMidiSetupChanged ?? const Stream.empty()).map((_) {});

  /// Stream of parsed MIDI messages relevant to the app.
  ///
  /// The plugin parses raw bytes into typed messages with per-source state
  /// (running status, multi-message packets); this service translates them
  /// into the app's [MidiMessage] model and drops unused kinds. If the plugin
  /// exposes no MIDI stream on this platform/version, this stream is empty.
  Stream<MidiMessage> get onMidiMessages =>
      _midi.onMidiDataReceived
          ?.map((event) => mapMessage(event.message))
          .where((message) => message != null)
          .cast<MidiMessage>() ??
      const Stream<MidiMessage>.empty();

  /// Translates a plugin message into the app's [MidiMessage] model.
  ///
  /// Returns null for message kinds the app does not consume. Velocity-0 note
  /// on is already delivered by the plugin as a note off.
  static MidiMessage? mapMessage(msg.MidiMessage message) {
    return switch (message) {
      final msg.NoteOnMessage m => MidiMessage(
        type: MidiMessageType.noteOn,
        note: m.note,
        velocity: m.velocity,
      ),
      final msg.NoteOffMessage m => MidiMessage(
        type: MidiMessageType.noteOff,
        note: m.note,
        velocity: m.velocity,
      ),
      final msg.CCMessage m => MidiMessage(
        type: MidiMessageType.controlChange,
        ccNumber: m.controller,
        ccValue: m.value,
      ),
      final msg.PCMessage m => MidiMessage(
        type: MidiMessageType.programChange,
        program: m.program,
      ),
      final msg.PitchBendMessage m => MidiMessage(
        type: MidiMessageType.pitchBend,
        bend: m.bend,
      ),
      _ => null,
    };
  }

  // ---- Bluetooth Central -------------------------------------------------

  BluetoothState get bluetoothState => _mapBluetoothState(_midi.bluetoothState);

  Future<void> startCentral({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    // IMPORTANT: startBluetooth can hang; guard it.
    await _midi.startBluetooth().timeout(timeout);
  }

  Future<void> waitUntilInitialized({
    Duration timeout = const Duration(seconds: 2),
  }) => _midi.waitUntilBluetoothIsInitialized().timeout(timeout);

  /// Convenience: start + wait, since callers almost always want both.
  Future<void> ensureCentralReady({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    await startCentral(timeout: timeout);
    await waitUntilInitialized(timeout: timeout);
  }

  // ---- Scanning ----------------------------------------------------------

  Future<void> startScanning({Duration timeout = const Duration(seconds: 3)}) =>
      _midi.startScanningForBluetoothDevices().timeout(timeout);

  Future<void> stopScanning() async {
    // Plugin API is void; keep this Future-returning for call-site symmetry.
    _midi.stopScanningForBluetoothDevices();
  }

  // ---- Devices -----------------------------------------------------------

  Future<List<MidiDevice>> devices() async {
    final nativeDevices = await _midi.devices.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    return nativeDevices?.map(_convertToMidiDevice).toList() ??
        const <MidiDevice>[];
  }

  // ---- Connection --------------------------------------------------------

  Future<void> connect(
    String deviceId, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final native = await _findNativeDevice(deviceId);
    // As of flutter_midi_command 1.0.6, connectToDevice blocks through
    // pairing and notification setup until the device reports connected, and
    // throws a typed MidiConnectionException on any failure, up to
    // awaitConnectionTimeout. Own that budget here so it matches the
    // caller's rather than racing a separate outer timer.
    try {
      await _midi.connectToDevice(native, awaitConnectionTimeout: timeout);
    } on fmc.MidiConnectionException catch (e) {
      throw BleServiceException(connectionFailureMessage(e), e);
    }
  }

  /// User-facing description of a typed connection failure.
  ///
  /// Falls back to the plugin's own stage message for subtypes without a
  /// friendlier wording here.
  @visibleForTesting
  static String connectionFailureMessage(fmc.MidiConnectionException e) {
    return switch (e) {
      fmc.MidiConnectionTimeoutException() =>
        'Connection timed out. Make sure the device is powered on and nearby.',
      fmc.MidiPairingRejectedException() =>
        'Pairing was declined. Try again and accept the pairing request.',
      fmc.MidiPairingFailedException() => 'Pairing failed. Try again, or forget the device in system Bluetooth settings first.',
      fmc.MidiPairingInfoRemovedException() => 'This device no longer recognizes its pairing. Forget it in system Bluetooth settings, then pair again.',
      fmc.MidiServiceDiscoveryException() =>
        'This device does not offer MIDI over Bluetooth.',
      fmc.MidiNotificationSubscriptionException() =>
        'Connected, but could not start receiving notes. Try again.',
      _ => e.message,
    };
  }

  Future<void> disconnect(String deviceId) async {
    final native = await _findNativeDeviceOrNull(deviceId);
    if (native == null) return;
    _midi.disconnectDevice(native);
  }

  Future<bool> isConnected(String deviceId) async {
    final native = await _findNativeDeviceOrNull(deviceId);
    return native?.connected ?? false;
  }

  // ---- Native helpers ----------------------------------------------------

  Future<fmc.MidiDevice> _findNativeDevice(String deviceId) async {
    final native = await _findNativeDeviceOrNull(deviceId);
    if (native == null) {
      throw BleServiceException('Device not found: $deviceId');
    }
    return native;
  }

  Future<fmc.MidiDevice?> _findNativeDeviceOrNull(String deviceId) async {
    final devices = await _midi.devices.timeout(
      const Duration(seconds: 2),
      onTimeout: () => null,
    );
    if (devices == null || devices.isEmpty) return null;

    for (final d in devices) {
      if (d.id == deviceId) return d;
    }
    return null;
  }

  // ---- Type Conversions --------------------------------------------------

  BluetoothState _mapBluetoothState(fmc.BluetoothState state) {
    return switch (state) {
      fmc.BluetoothState.poweredOn => BluetoothState.poweredOn,
      fmc.BluetoothState.poweredOff => BluetoothState.poweredOff,
      fmc.BluetoothState.unauthorized => BluetoothState.unauthorized,
      _ => BluetoothState.unknown,
    };
  }

  MidiDevice _convertToMidiDevice(fmc.MidiDevice device) => MidiDevice(
    id: device.id,
    name: device.name,
    transport: _mapTransport(device.type),
    isConnected: device.connected,
  );

  MidiTransportType _mapTransport(fmc.MidiDeviceType type) {
    return switch (type) {
      fmc.MidiDeviceType.ble => MidiTransportType.ble,
      fmc.MidiDeviceType.serial => MidiTransportType.usb,
      fmc.MidiDeviceType.network => MidiTransportType.network,
      _ => MidiTransportType.unknown,
    };
  }
}

class BleServiceException implements Exception {
  final String message;
  final Object? cause;

  const BleServiceException(this.message, [this.cause]);

  @override
  String toString() =>
      'BleServiceException: $message${cause != null ? ' ($cause)' : ''}';
}
