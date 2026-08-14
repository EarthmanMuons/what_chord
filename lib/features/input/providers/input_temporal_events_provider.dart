import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/demo/demo.dart';

import '../adapters/demo_input_adapter.dart';
import '../adapters/midi_input_adapter.dart';
import '../models/input_temporal_event.dart';

/// Ordered live-input events with an explicit reset at every source boundary.
final inputTemporalEventsProvider = StreamProvider<InputTemporalEvent>((ref) {
  final demoEnabled = ref.watch(demoModeProvider);
  final source = demoEnabled
      ? demoTemporalEventsSource
      : midiTemporalEventsSource;
  return ref.watch(source);
});
