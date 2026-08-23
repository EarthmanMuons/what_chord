import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/midi/models/midi_constants.dart';
import 'package:whatchord_app/features/midi/models/midi_device.dart';
import 'package:whatchord_app/features/midi/models/midi_message.dart';
import 'package:whatchord_app/features/midi/models/midi_note_state.dart';
import 'package:whatchord_app/features/midi/providers/bluetooth_permission_service_provider.dart';
import 'package:whatchord_app/features/midi/providers/midi_ble_service_provider.dart';
import 'package:whatchord_app/features/midi/providers/midi_connection_notifier.dart';
import 'package:whatchord_app/features/midi/providers/midi_note_state_notifier.dart';

import 'fake_midi_ble_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMidiBleService ble;
  late ProviderContainer container;

  setUp(() async {
    silenceDebugPrint();
    ble = FakeMidiBleService();
    SharedPreferences.setMockInitialValues(const {});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        midiBleServiceProvider.overrideWithValue(ble),
        bluetoothPermissionServiceProvider.overrideWithValue(
          const FakeBluetoothPermissionService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ble.dispose);
    final subscription = container.listen(midiNoteStateProvider, (_, _) {});
    addTearDown(subscription.close);
  });

  MidiNoteState noteState() => container.read(midiNoteStateProvider);

  Future<void> emit(MidiMessage message) async {
    ble.emitMessage(message);
    await pumpEventQueue();
  }

  Future<void> noteOn(int note, {int velocity = 100}) => emit(
    MidiMessage(type: MidiMessageType.noteOn, note: note, velocity: velocity),
  );
  Future<void> noteOff(int note) =>
      emit(MidiMessage(type: MidiMessageType.noteOff, note: note, velocity: 0));
  Future<void> pedal(int value) => emit(
    MidiMessage(
      type: MidiMessageType.controlChange,
      ccNumber: 64,
      ccValue: value,
    ),
  );

  test('note on and off track pressed notes', () async {
    await noteOn(60);
    await noteOn(64);
    expect(noteState().pressed, {60, 64});

    await noteOff(60);
    expect(noteState().pressed, {64});
    expect(noteState().soundingNoteNumbers, {64});
  });

  test('a velocity-zero note on releases the note', () async {
    await noteOn(60);
    await noteOn(60, velocity: 0);
    expect(noteState().soundingNoteNumbers, isEmpty);
  });

  test(
    'notes released with the pedal down sustain until the pedal lifts',
    () async {
      await pedal(127);
      expect(noteState().isPedalDown, isTrue);

      await noteOn(60);
      await noteOff(60);
      expect(noteState().pressed, isEmpty);
      expect(noteState().sustained, {60});
      expect(noteState().soundingNoteNumbers, {60});

      await pedal(0);
      expect(noteState().isPedalDown, isFalse);
      expect(noteState().soundingNoteNumbers, isEmpty);
    },
  );

  test('re-pressing a sustained note moves it back to pressed', () async {
    await pedal(127);
    await noteOn(60);
    await noteOff(60);
    expect(noteState().sustained, {60});

    await noteOn(60);
    expect(noteState().pressed, {60});
    expect(noteState().sustained, isEmpty);

    // Lifting the pedal must not silence the re-pressed note.
    await pedal(0);
    expect(noteState().soundingNoteNumbers, {60});
  });

  for (final (ccNumber, name) in const [
    (MidiConstants.ccAllSoundOff, 'all-sound-off'),
    (MidiConstants.ccAllNotesOff, 'all-notes-off'),
  ]) {
    test('the $name controller clears pressed and sustained', () async {
      await pedal(127);
      await noteOn(60);
      await noteOn(64);
      await noteOff(60);

      await emit(
        MidiMessage(
          type: MidiMessageType.controlChange,
          ccNumber: ccNumber,
          ccValue: 0,
        ),
      );
      expect(noteState().soundingNoteNumbers, isEmpty);
      expect(noteState().isPedalDown, isTrue, reason: 'pedal state unaffected');
    });
  }

  test('the pedal latch ignores MIDI pedal releases until cleared', () async {
    final notifier = container.read(midiNoteStateProvider.notifier);
    notifier.setPedalLatch(true);
    notifier.setPedalDown(true);

    await noteOn(60);
    await noteOff(60);
    await pedal(0);
    expect(noteState().isPedalDown, isTrue, reason: 'latched');
    expect(noteState().sustained, {60});

    notifier.setPedalLatch(false);
    await pedal(0);
    expect(noteState().isPedalDown, isFalse);
    expect(noteState().soundingNoteNumbers, isEmpty);
  });

  test('losing the connection resets note state', () async {
    const device = MidiDevice(
      id: 'aaa',
      name: 'JamCorder',
      transport: MidiTransportType.ble,
      isConnected: false,
    );
    ble.discoverable = const [device];
    final connection = container.read(midiConnectionStateProvider.notifier);
    await connection.connect(device);
    await pumpEventQueue();

    await pedal(127);
    await noteOn(60);
    await noteOff(60);
    await noteOn(64);
    expect(noteState().soundingNoteNumbers, {60, 64});

    await connection.disconnect();
    await pumpEventQueue();
    expect(noteState().soundingNoteNumbers, isEmpty);
    expect(noteState().isPedalDown, isFalse);
  });
}
