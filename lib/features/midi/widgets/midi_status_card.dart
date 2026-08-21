import 'package:material_ui/material_ui.dart';

import '../../../core/models/app_colors.dart';
import '../models/midi_connection.dart';
import '../models/midi_connection_status.dart';

class MidiStatusCard extends StatelessWidget {
  const MidiStatusCard({super.key, required this.status});

  final MidiConnectionStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final titleStyle = theme.textTheme.titleMedium;
    final bodyStyle = theme.textTheme.bodyMedium?.copyWith(
      color: cs.onSurfaceVariant,
    );

    // Always a list (possibly empty) so the rendering code is simple.
    final subtitleLines = <String>[
      if (status.phase == MidiConnectionPhase.retrying &&
          status.attempt != null)
        'Attempt ${status.attempt}',
      if (status.phase == MidiConnectionPhase.retrying &&
          status.nextDelay != null)
        'Next retry in ${status.nextDelay!.inSeconds}s',
    ];

    // Text() requires a non-null String.
    final detailText = status.subtitle ?? status.title;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Status', style: titleStyle),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildDotForPhase(context, status, cs),
                const SizedBox(width: 12),
                Expanded(child: Text(detailText)),
              ],
            ),
            if (subtitleLines.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final line in subtitleLines)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(line, style: bodyStyle),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDotForPhase(
    BuildContext context,
    MidiConnectionStatus status,
    ColorScheme cs,
  ) {
    // Keep dot semantics consistent with pill tone mapping:
    // - normal/busy -> secondary
    // - error/unavailable -> error
    // - idle -> muted
    final color = switch (status.phase) {
      MidiConnectionPhase.connected => AppColors.midiConnected(
        Theme.of(context).brightness,
      ),

      MidiConnectionPhase.connecting ||
      MidiConnectionPhase.retrying => cs.secondary,

      MidiConnectionPhase.bluetoothUnavailable ||
      MidiConnectionPhase.deviceUnavailable ||
      MidiConnectionPhase.error => cs.error,

      MidiConnectionPhase.idle => cs.onSurfaceVariant.withValues(alpha: 0.6),
    };

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
