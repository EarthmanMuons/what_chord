import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef InputEventClock = int Function();

/// Monotonic elapsed clock shared by every normalized live-input source.
final inputEventClockProvider = Provider<InputEventClock>((ref) {
  final stopwatch = Stopwatch()..start();
  ref.onDispose(stopwatch.stop);
  return () => stopwatch.elapsedMilliseconds;
});
