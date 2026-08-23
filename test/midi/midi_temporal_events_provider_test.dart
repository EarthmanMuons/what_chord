import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/midi/models/midi_constants.dart';
import 'package:whatchord_app/features/midi/models/midi_message.dart';
import 'package:whatchord_app/features/midi/providers/bluetooth_permission_service_provider.dart';
import 'package:whatchord_app/features/midi/providers/midi_ble_service_provider.dart';
import 'package:whatchord_app/features/midi/providers/midi_temporal_events_provider.dart';

import 'fake_midi_ble_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeMidiBleService ble;
  late ProviderContainer container;
  late List<InputTemporalEvent> events;
  late int nowMs;

  setUp(() async {
    ble = FakeMidiBleService();
    SharedPreferences.setMockInitialValues(const {});
    final preferences = await SharedPreferences.getInstance();
    nowMs = 0;
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        midiBleServiceProvider.overrideWithValue(ble),
        bluetoothPermissionServiceProvider.overrideWithValue(
          const FakeBluetoothPermissionService(),
        ),
        inputEventClockProvider.overrideWithValue(() => nowMs),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ble.dispose);

    events = [];
    final providerSubscription = container.listen(
      midiTemporalEventsProvider,
      (previous, next) {},
    );
    addTearDown(providerSubscription.close);
    final streamSubscription = container
        .read(midiTemporalEventsProvider)
        .listen(events.add);
    addTearDown(streamSubscription.cancel);
    await pumpEventQueue();

    expect(events, hasLength(1));
    final reset = events.single as InputTemporalResetEvent;
    expect(reset.snapshot.pressedNoteNumbers, isEmpty);
    expect(reset.snapshot.sustainedNoteNumbers, isEmpty);
    expect(reset.snapshot.pedalDown, isFalse);
    events.clear();
  });

  test('preserves note, adopted pedal, and sustain event order', () async {
    ble.emitMessage(
      const MidiMessage(type: MidiMessageType.noteOn, note: 60, velocity: 93),
    );
    await pumpEventQueue();
    nowMs = 25;
    ble.emitMessage(
      const MidiMessage(
        type: MidiMessageType.controlChange,
        ccNumber: MidiConstants.ccSustainPedal,
        ccValue: 127,
      ),
    );
    await pumpEventQueue();
    nowMs = 40;
    ble.emitMessage(
      const MidiMessage(type: MidiMessageType.noteOff, note: 60, velocity: 12),
    );
    await pumpEventQueue();
    nowMs = 70;
    ble.emitMessage(
      const MidiMessage(
        type: MidiMessageType.controlChange,
        ccNumber: MidiConstants.ccSustainPedal,
        ccValue: 0,
      ),
    );
    await pumpEventQueue();

    expect(events, hasLength(4));
    expect(events[0], isA<InputTemporalNoteOnEvent>());
    expect((events[0] as InputTemporalNoteOnEvent).velocity, 93);
    expect(events[1], isA<InputTemporalPedalEvent>());
    expect(events[1].timestampMs, 25);
    expect(events[2], isA<InputTemporalNoteOffEvent>());
    expect((events[2] as InputTemporalNoteOffEvent).velocity, 12);
    expect(events[3], isA<InputTemporalPedalEvent>());
    expect((events[3] as InputTemporalPedalEvent).down, isFalse);
  });

  test(
    'normalizes velocity-zero and duplicate messages without bad frames',
    () async {
      ble.emitMessage(
        const MidiMessage(type: MidiMessageType.noteOn, note: 64, velocity: 90),
      );
      ble.emitMessage(
        const MidiMessage(type: MidiMessageType.noteOn, note: 64, velocity: 91),
      );
      ble.emitMessage(
        const MidiMessage(type: MidiMessageType.noteOn, note: 64, velocity: 0),
      );
      ble.emitMessage(
        const MidiMessage(type: MidiMessageType.noteOff, note: 64, velocity: 0),
      );
      await pumpEventQueue();

      expect(events, hasLength(2));
      expect(events.first, isA<InputTemporalNoteOnEvent>());
      expect(events.last, isA<InputTemporalNoteOffEvent>());
    },
  );

  for (final (ccNumber, name) in const [
    (MidiConstants.ccAllSoundOff, 'all-sound-off'),
    (MidiConstants.ccAllNotesOff, 'all-notes-off'),
  ]) {
    test('turns $name into an explicit empty reset', () async {
      ble.emitMessage(
        const MidiMessage(
          type: MidiMessageType.noteOn,
          note: 60,
          velocity: 100,
        ),
      );
      await pumpEventQueue();
      nowMs = 10;
      ble.emitMessage(
        MidiMessage(
          type: MidiMessageType.controlChange,
          ccNumber: ccNumber,
          ccValue: 0,
        ),
      );
      await pumpEventQueue();

      final reset = events.last as InputTemporalResetEvent;
      expect(reset.timestampMs, 10);
      expect(reset.snapshot.pressedNoteNumbers, isEmpty);
      expect(reset.snapshot.sustainedNoteNumbers, isEmpty);
    });
  }
}
