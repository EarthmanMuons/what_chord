import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';
import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/input/models/input_pedal_state.dart';
import 'package:whatchord_app/features/input/providers/pedal_state_provider.dart';
import 'package:whatchord_app/features/midi/models/midi_message.dart';
import 'package:whatchord_app/features/midi/providers/bluetooth_permission_service_provider.dart';
import 'package:whatchord_app/features/midi/providers/midi_ble_service_provider.dart';
import 'package:whatchord_app/features/midi/providers/midi_note_state_notifier.dart';

import '../midi/fake_midi_ble_service.dart';

/// Bypasses the real demo notifier's enter/exit side effects; tests only need
/// the mode flag to flip.
class _StubDemoModeNotifier extends DemoModeNotifier {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

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
        demoModeProvider.overrideWith(_StubDemoModeNotifier.new),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(ble.dispose);
    final subscription = container.listen(inputPedalStateProvider, (_, _) {});
    addTearDown(subscription.close);
  });

  InputPedalState pedalState() => container.read(inputPedalStateProvider);
  InputPedalController controller() =>
      container.read(inputPedalControllerProvider);

  Future<void> midiPedal(int value) async {
    ble.emitMessage(
      MidiMessage(
        type: MidiMessageType.controlChange,
        ccNumber: 64,
        ccValue: value,
      ),
    );
    await pumpEventQueue();
  }

  test('toggling from idle latches the pedal down as a touch pedal', () async {
    expect(pedalState().isDown, isFalse);

    controller().toggle();
    await pumpEventQueue();
    expect(pedalState().isDown, isTrue);
    expect(pedalState().source, InputPedalSource.touch);
  });

  test(
    'toggling while touch-latched releases the pedal and its sustain',
    () async {
      controller().toggle();
      await pumpEventQueue();

      // Sustain a note under the touch pedal.
      ble.emitMessage(
        const MidiMessage(
          type: MidiMessageType.noteOn,
          note: 60,
          velocity: 100,
        ),
      );
      ble.emitMessage(
        const MidiMessage(type: MidiMessageType.noteOff, note: 60, velocity: 0),
      );
      await pumpEventQueue();
      expect(container.read(midiNoteStateProvider).sustained, {
        60,
      }, reason: 'sustained under the touch pedal');

      controller().toggle();
      await pumpEventQueue();
      expect(pedalState().isDown, isFalse);
      expect(container.read(midiNoteStateProvider).sustained, isEmpty);
      expect(container.read(touchPedalOverrideProvider), isFalse);
    },
  );

  test('toggling while the MIDI pedal is down latches touch over it', () async {
    await midiPedal(127);
    expect(pedalState().isDown, isTrue);
    expect(pedalState().source, InputPedalSource.midi);

    controller().toggle();
    await pumpEventQueue();
    expect(pedalState().isDown, isTrue);
    expect(pedalState().source, InputPedalSource.touch);

    // The physical pedal lifts, but the touch latch holds the sustain.
    await midiPedal(0);
    expect(pedalState().isDown, isTrue, reason: 'latch holds');
    expect(pedalState().source, InputPedalSource.touch);

    // Releasing the touch latch drops the pedal for real.
    controller().toggle();
    await pumpEventQueue();
    expect(pedalState().isDown, isFalse);
  });

  test('demo mode routes the toggle to the demo pedal', () async {
    final demo = container.read(demoModeProvider.notifier);
    (demo as _StubDemoModeNotifier).set(true);
    await pumpEventQueue();

    controller().toggle();
    await pumpEventQueue();
    expect(container.read(demoPedalDownProvider), isTrue);
    expect(pedalState().isDown, isTrue);
    expect(pedalState().source, InputPedalSource.demo);
    expect(
      container.read(midiNoteStateProvider).isPedalDown,
      isFalse,
      reason: 'MIDI pedal untouched',
    );
  });
}
