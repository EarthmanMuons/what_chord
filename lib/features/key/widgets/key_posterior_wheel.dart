import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatkey/whatkey.dart';

import 'package:whatchord_app/features/theory/theory.dart';

import '../providers/key_behavior_notifier.dart';

/// The detector's belief over all 24 keys, drawn on the circle of fifths:
/// majors on the outer ring, each relative minor directly inside it, so the
/// layout itself encodes musical similarity (fifth neighbors touch, relative
/// pairs stack). Magnitude uses a single-hue ramp from the surface toward the
/// theme primary; probabilities are display-calibrated before drawing. The
/// current claim carries a ring so it is never marked by color alone.
///
/// Keys with two common spellings (D flat/C sharp, e flat/d sharp, and
/// friends) carry both names, the more common first; minors are lowercase.
/// Tapping a segment shows that key's calibrated probability in the wheel's
/// center; dragging scrubs across segments. Tapping anywhere else clears it.
class KeyPosteriorWheel extends ConsumerStatefulWidget {
  const KeyPosteriorWheel({super.key, required this.ranked, this.claim});

  /// Raw posterior from the detector; calibrated internally for display.
  final List<KeyEstimate> ranked;
  final Tonality? claim;

  @override
  ConsumerState<KeyPosteriorWheel> createState() => _KeyPosteriorWheelState();
}

class _KeyPosteriorWheelState extends ConsumerState<KeyPosteriorWheel> {
  int? _inspectedIndex;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    // Base label style from the theme so painted text keeps the app's font
    // stack (accidental glyphs come from the symbols font).
    final labelBase = theme.textTheme.labelMedium ?? const TextStyle();
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final calibrated = DisplayCalibration.calibrate(
      widget.ranked,
      temperature: ref.watch(keyBehaviorProvider).displayTemperature,
    );

    final byIndex = <int, double>{
      for (final estimate in calibrated)
        KeySpace.index(estimate.tonality): estimate.confidence,
    };

    String tonicLabel(Tonality tonality) =>
        tonalityTonicLabel(tonality, noteNameSystem: noteNameSystem);

    // Both spellings for keys with an enharmonic twin, the more common
    // (fewer accidentals) first. Detection is pitch-class based, so which
    // spelling the detector picked carries no information.
    String keyLabel(Tonality tonality) {
      final spellings = [
        for (final row in keySignatures)
          for (final spelled in [row.relativeMajor, row.relativeMinor])
            if (spelled.mode == tonality.mode &&
                spelled.tonicPitchClass == tonality.tonicPitchClass)
              (row.accidentalCount.abs(), spelled),
      ]..sort((a, b) => a.$1.compareTo(b.$1));
      return spellings.map((s) => tonicLabel(s.$2)).join('/');
    }

    String percentLabel(double confidence) {
      final percent = confidence * 100;
      return percent >= 0.5 ? '${percent.round()}%' : '<1%';
    }

    final inspected = _inspectedIndex;
    String? centerTitle;
    String? centerDetail;
    if (inspected != null) {
      final tonality = KeySpace.canonicalTonalities[inspected];
      centerTitle = keyLabel(tonality);
      centerDetail = percentLabel(byIndex[inspected] ?? 0);
    }

    final top = calibrated.isEmpty ? null : calibrated.first;
    final semanticLabel = top == null
        ? 'Key likelihood wheel: no evidence yet.'
        : 'Key likelihood wheel. Most likely '
              '${tonalitySemanticLabel(top.tonality, noteNameSystem: noteNameSystem)} '
              'at ${(top.confidence * 100).round()} percent. '
              'Tap a segment for its probability.';

    return Semantics(
      label: semanticLabel,
      child: TapRegion(
        onTapOutside: (_) {
          if (_inspectedIndex == null) return;
          setState(() => _inspectedIndex = null);
        },
        child: AspectRatio(
          aspectRatio: 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) => _onTap(details.localPosition, size),
                onPanStart: (details) =>
                    _inspectAt(details.localPosition, size),
                onPanUpdate: (details) =>
                    _inspectAt(details.localPosition, size),
                child: CustomPaint(
                  size: size,
                  painter: _WheelPainter(
                    confidenceByIndex: byIndex,
                    claimIndex: widget.claim == null
                        ? null
                        : KeySpace.index(widget.claim!),
                    inspectedIndex: inspected,
                    centerTitle: centerTitle,
                    centerDetail: centerDetail,
                    keyLabel: keyLabel,
                    labelBase: labelBase,
                    surface: cs.surfaceContainerLow,
                    rampFrom: cs.surfaceContainerHighest,
                    rampTo: cs.primary,
                    inkMuted: cs.onSurfaceVariant,
                    ink: cs.onSurface,
                    inkOnFill: cs.onPrimary,
                    claimRing: cs.onSurface,
                    inspectRing: cs.tertiary,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _onTap(Offset position, Size size) {
    final index = _WheelPainter.segmentIndexAt(position, size);
    setState(() {
      _inspectedIndex = index == _inspectedIndex ? null : index;
    });
  }

  void _inspectAt(Offset position, Size size) {
    final index = _WheelPainter.segmentIndexAt(position, size);
    if (index == null || index == _inspectedIndex) return;
    setState(() => _inspectedIndex = index);
  }
}

class _WheelPainter extends CustomPainter {
  _WheelPainter({
    required this.confidenceByIndex,
    required this.claimIndex,
    required this.inspectedIndex,
    required this.centerTitle,
    required this.centerDetail,
    required this.keyLabel,
    required this.labelBase,
    required this.surface,
    required this.rampFrom,
    required this.rampTo,
    required this.inkMuted,
    required this.ink,
    required this.inkOnFill,
    required this.claimRing,
    required this.inspectRing,
  });

  final Map<int, double> confidenceByIndex;
  final int? claimIndex;
  final int? inspectedIndex;
  final String? centerTitle;
  final String? centerDetail;
  final String Function(Tonality) keyLabel;
  final TextStyle labelBase;
  final Color surface;
  final Color rampFrom;
  final Color rampTo;
  final Color inkMuted;
  final Color ink;
  final Color inkOnFill;
  final Color claimRing;
  final Color inspectRing;

  static const _sweep = 2 * math.pi / 12;
  static const _middleFraction = 0.68;
  static const _innerFraction = 0.36;

  /// The 24-key index of the segment at [position], or null outside the
  /// rings. Inverse of the drawing layout below.
  static int? segmentIndexAt(Offset position, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final vector = position - center;
    final radius = vector.distance;
    if (radius > outer || radius < outer * _innerFraction) return null;

    var angle = math.atan2(vector.dy, vector.dx) + math.pi / 2 + _sweep / 2;
    angle = angle % (2 * math.pi);
    if (angle < 0) angle += 2 * math.pi;
    final i = (angle ~/ _sweep) % 12;
    final pc = KeySpace.pcAtFifthsPosition(i);
    return radius >= outer * _middleFraction
        ? KeySpace.majorIndex(pc)
        : KeySpace.minorIndex(KeySpace.relativeMinorPc(pc));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final outer = size.shortestSide / 2;
    final middle = outer * _middleFraction;
    final inner = outer * _innerFraction;

    final majorFontSize = (outer * 0.115).clamp(11.0, 26.0);
    final minorFontSize = (outer * 0.095).clamp(9.0, 21.0);

    final gap = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = surface;

    Path segment(double rOuter, double rInner, double start) {
      return Path()
        ..addArc(Rect.fromCircle(center: center, radius: rOuter), start, _sweep)
        ..arcTo(
          Rect.fromCircle(center: center, radius: rInner),
          start + _sweep,
          -_sweep,
          false,
        )
        ..close();
    }

    Path segmentForIndex(int index) {
      final pc = index ~/ 2;
      final isMinor = index.isOdd;
      // Minors are drawn inside their relative major's segment.
      final ringPc = isMinor ? KeySpace.relativeMajorPc(pc) : pc;
      final i = KeySpace.fifthsPosition(ringPc);
      final start = -math.pi / 2 - _sweep / 2 + i * _sweep;
      return isMinor
          ? segment(middle, inner, start)
          : segment(outer, middle, start);
    }

    // Ring i sits at pitch class 7*i mod 12, C centered at the top.
    for (var i = 0; i < 12; i++) {
      final pc = KeySpace.pcAtFifthsPosition(i);
      final start = -math.pi / 2 - _sweep / 2 + i * _sweep;
      final majorTonality = KeySpace.majorTonality(pc);
      final minorTonality = KeySpace.minorTonality(
        KeySpace.relativeMinorPc(pc),
      );

      for (final (tonality, rOut, rIn, isMajor) in [
        (majorTonality, outer, middle, true),
        (minorTonality, middle, inner, false),
      ]) {
        final index = KeySpace.index(tonality);
        final confidence = confidenceByIndex[index] ?? 0.0;
        // sqrt keeps the near-uniform "no idea" posterior visible as a faint
        // even wash instead of vanishing; magnitude stays single-hue.
        final t = math.sqrt(confidence).clamp(0.0, 1.0);
        final fill = Color.lerp(rampFrom, rampTo, t)!;
        final path = segment(rOut, rIn, start);
        canvas.drawPath(path, Paint()..color = fill);
        canvas.drawPath(path, gap);

        final labelRadius = (rOut + rIn) / 2;
        final angle = start + _sweep / 2;
        final labelCenter =
            center + Offset(math.cos(angle), math.sin(angle)) * labelRadius;
        final text = keyLabel(tonality);
        TextPainter layoutLabel(double fontSize) => TextPainter(
          text: TextSpan(
            text: text,
            style: labelBase.copyWith(
              fontSize: fontSize,
              fontWeight: index == claimIndex
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: t > 0.45 ? inkOnFill : inkMuted,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        var painter = layoutLabel(isMajor ? majorFontSize : minorFontSize);
        // Enharmonic pair labels can outgrow their segment; shrink to fit
        // the chord width at the label radius.
        final maxLabelWidth = 2 * labelRadius * math.sin(_sweep / 2) * 0.92;
        if (painter.width > maxLabelWidth) {
          painter = layoutLabel(
            (isMajor ? majorFontSize : minorFontSize) *
                maxLabelWidth /
                painter.width,
          );
        }
        painter.paint(
          canvas,
          labelCenter - Offset(painter.width / 2, painter.height / 2),
        );
      }
    }

    final inspected = inspectedIndex;
    if (inspected != null && inspected != claimIndex) {
      canvas.drawPath(
        segmentForIndex(inspected),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = inspectRing,
      );
    }
    final claimed = claimIndex;
    if (claimed != null) {
      canvas.drawPath(
        segmentForIndex(claimed),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = claimRing,
      );
    }

    if (centerTitle != null) {
      final title = TextPainter(
        text: TextSpan(
          text: centerTitle,
          style: labelBase.copyWith(
            fontSize: (outer * 0.16).clamp(13.0, 30.0),
            fontWeight: FontWeight.w600,
            color: ink,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final detail = TextPainter(
        text: TextSpan(
          text: centerDetail,
          style: labelBase.copyWith(
            fontSize: (outer * 0.12).clamp(11.0, 22.0),
            fontWeight: FontWeight.w400,
            color: inkMuted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final totalHeight = title.height + 2 + detail.height;
      title.paint(canvas, center - Offset(title.width / 2, totalHeight / 2));
      detail.paint(
        canvas,
        center + Offset(-detail.width / 2, totalHeight / 2 - detail.height),
      );
    }
  }

  @override
  bool shouldRepaint(_WheelPainter oldDelegate) =>
      oldDelegate.confidenceByIndex != confidenceByIndex ||
      oldDelegate.claimIndex != claimIndex ||
      oldDelegate.inspectedIndex != inspectedIndex ||
      oldDelegate.centerDetail != centerDetail ||
      oldDelegate.labelBase != labelBase ||
      oldDelegate.rampTo != rampTo ||
      oldDelegate.rampFrom != rampFrom ||
      oldDelegate.surface != surface;
}
