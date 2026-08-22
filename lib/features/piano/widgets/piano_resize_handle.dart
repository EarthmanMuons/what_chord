import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../providers/piano_view_settings_notifier.dart';
import '../services/piano_view_metrics.dart';

/// Drag-to-resize splitter for the keyboard. Dragging up grows the keyboard's
/// vertical space; double-tapping restores the default size.
///
/// The host pins it to the top edge of the keyboard (on the separator line in
/// portrait / Explore Scales, or on the felt in landscape Home / Explore Chords);
/// the splitter sits at the top and the touch target reaches down over the keys
/// consistently, so only the surrounding visual differs by orientation. The host
/// supplies the current [baseHeight] (default/minimum), the live [currentHeight],
/// and the [maxHeight] available so the drag can be clamped to the room on screen.
class PianoResizeHandle extends ConsumerStatefulWidget {
  const PianoResizeHandle({
    super.key,
    required this.baseHeight,
    required this.currentHeight,
    required this.maxHeight,
  });

  final double baseHeight;
  final double currentHeight;
  final double maxHeight;

  /// Hit-target size. Bounded width (not full width) so that, sitting on the
  /// keys, the rest of the top edge stays free for horizontal scrolling. The
  /// height reaches down over the keys.
  static const double hitWidth = 180.0;
  static const double hitHeight = 30.0;

  /// Splitter dimensions. Thin, with [splitterInset] of breathing room above
  /// it (and matching room below, from the band), so it reads as a handle rather
  /// than a scroll bar. [splitterInset] is also how far the host pins the splitter
  /// down from the top of the hit area.
  static const double splitterWidth = 40.0;
  static const double splitterHeight = 4.0;
  static const double splitterInset = 2.0;

  @override
  ConsumerState<PianoResizeHandle> createState() => _PianoResizeHandleState();
}

class _PianoResizeHandleState extends ConsumerState<PianoResizeHandle> {
  // Tracks the in-flight height across drag updates so deltas accumulate from
  // the live size rather than the (frame-lagged) provider value.
  double? _dragHeight;

  void _onDragStart(DragStartDetails _) {
    _dragHeight = widget.currentHeight;
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final start = _dragHeight ?? widget.currentHeight;
    // Dragging up (negative dy) grows the keyboard.
    final next = (start - details.delta.dy).clamp(
      widget.baseHeight,
      widget.maxHeight,
    );
    _dragHeight = next;
    final scale = heightScaleForHeight(
      height: next,
      baseHeight: widget.baseHeight,
    );
    unawaited(
      ref.read(pianoViewSettingsProvider.notifier).setHeightScale(scale),
    );
  }

  void _onDragEnd(DragEndDetails _) {
    _dragHeight = null;
  }

  void _reset() {
    unawaited(ref.read(pianoViewSettingsProvider.notifier).reset());
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDefault = ref.watch(
      pianoViewSettingsProvider.select((s) => s.isDefault),
    );

    return Semantics(
      container: true,
      slider: true,
      label: 'Resize keyboard',
      hint: 'Drag up or down to resize. Double tap to reset.',
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onDoubleTap: isDefault ? null : _reset,
          child: SizedBox(
            width: PianoResizeHandle.hitWidth,
            height: PianoResizeHandle.hitHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: PianoResizeHandle.splitterInset,
                ),
                child: _splitter(cs),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _splitter(ColorScheme cs) {
    return Container(
      width: PianoResizeHandle.splitterWidth,
      height: PianoResizeHandle.splitterHeight,
      decoration: BoxDecoration(
        // Standard drag-handle treatment: onSurfaceVariant at low opacity.
        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(
          PianoResizeHandle.splitterHeight / 2,
        ),
      ),
    );
  }
}
