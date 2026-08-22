import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whatkey/whatkey.dart';

import 'package:whatchord_app/features/theory/theory.dart';

import '../providers/key_behavior_notifier.dart';

/// The circle of fifths unrolled for height-constrained layouts: one column
/// per pitch class in fifths order, major above its relative minor, so the
/// adjacency story survives (fifth neighbors touch, relative pairs stack).
/// Same single-hue calibrated ramp as the wheel; the claim carries a border
/// so it is never marked by color alone. Cells grow with the available width.
/// Touching scrubs across cells, floating that key's calibrated probability
/// just above the rows (overlapping the space there rather than reserving
/// it), offset left of the finger so it stays visible; the readout lingers
/// briefly after release.
class KeyPosteriorStrip extends ConsumerStatefulWidget {
  const KeyPosteriorStrip({super.key, required this.ranked, this.claim});

  /// Raw posterior from the detector; calibrated internally for display.
  final List<KeyEstimate> ranked;
  final Tonality? claim;

  @override
  ConsumerState<KeyPosteriorStrip> createState() => _KeyPosteriorStripState();
}

const _readoutLaneHeight = 36.0;
const _readoutLeftShift = 56.0;

class _KeyPosteriorStripState extends ConsumerState<KeyPosteriorStrip> {
  static const _gap = 2.0;

  int? _inspectedIndex;
  double _fingerX = 0;
  Timer? _lingerTimer;

  @override
  void dispose() {
    _lingerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final calibrated = DisplayCalibration.calibrate(
      widget.ranked,
      temperature: ref.watch(keyBehaviorProvider).displayTemperature,
    );

    final byIndex = <int, double>{
      for (final estimate in calibrated)
        KeySpace.index(estimate.tonality): estimate.confidence,
    };
    final claimIndex = widget.claim == null
        ? null
        : KeySpace.index(widget.claim!);

    String percentLabel(int index) {
      final percent = (byIndex[index] ?? 0.0) * 100;
      return percent >= 0.5 ? '${percent.round()}%' : '<1%';
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cellWidth = (width - 11 * _gap) / 12;
        final cellHeight = (cellWidth * 0.72).clamp(30.0, 48.0);
        final fontSize = (cellWidth * 0.34).clamp(12.0, 15.0);

        Widget cell(Tonality tonality) {
          final index = KeySpace.index(tonality);
          final confidence = byIndex[index] ?? 0.0;
          final t = math.sqrt(confidence).clamp(0.0, 1.0);
          final fill = Color.lerp(cs.surfaceContainerHighest, cs.primary, t)!;
          // Uppercase majors, lowercase minors; the rows disambiguate.
          final label = tonalityTonicLabel(
            tonality,
            noteNameSystem: noteNameSystem,
          );

          return Semantics(
            label:
                '${tonalitySemanticLabel(tonality, noteNameSystem: noteNameSystem)}'
                ' ${percentLabel(index)}',
            child: Container(
              height: cellHeight,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(4),
                border: index == claimIndex
                    ? Border.all(color: cs.onSurface, width: 2)
                    : index == _inspectedIndex
                    ? Border.all(color: cs.tertiary, width: 2)
                    : null,
              ),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontSize: fontSize,
                  fontWeight: index == claimIndex
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: t > 0.45 ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          );
        }

        final rows = Row(
          children: [
            for (var i = 0; i < 12; i++) ...[
              if (i > 0) const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  children: [
                    cell(
                      KeySpace.majorTonality(KeySpace.pcAtFifthsPosition(i)),
                    ),
                    const SizedBox(height: _gap),
                    cell(
                      KeySpace.minorTonality(
                        KeySpace.relativeMinorPc(
                          KeySpace.pcAtFifthsPosition(i),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

        final inspected = _inspectedIndex;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (details) =>
                  _scrub(details.localPosition, cellWidth, cellHeight),
              onTapUp: (_) => _release(),
              onTapCancel: _release,
              onPanStart: (details) =>
                  _scrub(details.localPosition, cellWidth, cellHeight),
              onPanUpdate: (details) =>
                  _scrub(details.localPosition, cellWidth, cellHeight),
              onPanEnd: (_) => _release(),
              onPanCancel: _release,
              child: rows,
            ),
            if (inspected != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: cellHeight * 2 + _gap + 4,
                child: IgnorePointer(
                  child: CustomSingleChildLayout(
                    delegate: _ReadoutLayoutDelegate(
                      centerX: _fingerX - _readoutLeftShift,
                    ),
                    // Mirrors the framework's default mobile tooltip styling
                    // so the readout matches the app's other tooltips.
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? Colors.white.withValues(alpha: 0.9)
                            : Colors.grey.shade700.withValues(alpha: 0.9),
                        borderRadius: const BorderRadius.all(
                          Radius.circular(4),
                        ),
                      ),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 32),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            '${tonalityDisplayLabel(KeySpace.canonicalTonalities[inspected], noteNameSystem: noteNameSystem)}'
                            ' · ${percentLabel(inspected)}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 14,
                              color: theme.brightness == Brightness.dark
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _scrub(Offset position, double cellWidth, double cellHeight) {
    _lingerTimer?.cancel();
    final column = (position.dx / (cellWidth + _gap)).floor().clamp(0, 11);
    final pc = KeySpace.pcAtFifthsPosition(column);
    final index = position.dy < cellHeight + _gap / 2
        ? KeySpace.majorIndex(pc)
        : KeySpace.minorIndex(KeySpace.relativeMinorPc(pc));
    if (index == _inspectedIndex && position.dx == _fingerX) return;
    setState(() {
      _inspectedIndex = index;
      _fingerX = position.dx;
    });
  }

  void _release() {
    _lingerTimer?.cancel();
    _lingerTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _inspectedIndex = null);
    });
  }
}

/// Centers the readout at [centerX], clamped so it never leaves the strip's
/// bounds (anything further left would be clipped away by the enclosing
/// scroll viewport). Bottom-aligned in its lane so the gap above the rows
/// stays constant.
class _ReadoutLayoutDelegate extends SingleChildLayoutDelegate {
  _ReadoutLayoutDelegate({required this.centerX});

  final double centerX;

  @override
  Size getSize(BoxConstraints constraints) =>
      Size(constraints.maxWidth, _readoutLaneHeight);

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final dx = (centerX - childSize.width / 2)
        .clamp(0.0, math.max(0.0, size.width - childSize.width))
        .toDouble();
    return Offset(dx, size.height - childSize.height);
  }

  @override
  bool shouldRelayout(_ReadoutLayoutDelegate oldDelegate) =>
      oldDelegate.centerX != centerX;
}
