import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';

import 'package:whatchord/whatchord.dart';

class KeySignatureStaffPreview extends StatelessWidget {
  const KeySignatureStaffPreview({
    super.key,
    required this.keySignature,
    this.height = 96,
  });

  /// Natural width of the staff card; narrower hosts shrink to fit. Exposed
  /// so layouts can bound the widget (whose card centers itself) when they
  /// need edge alignment instead.
  static const double previewWidth = 360.0;

  final KeySignature keySignature;
  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final staffBackground = _staffBackgroundColor(cs);
    final borderColor = Color.alphaBlend(
      Colors.black.withValues(
        alpha: cs.brightness == Brightness.dark ? 0.30 : 0.22,
      ),
      staffBackground,
    );

    // Notation is drawn as fixed geometry so system text scaling does not
    // distort staff spacing or accidental placement.
    return Semantics(
      image: true,
      label: 'Treble staff key signature: ${keySignature.label}.',
      child: ExcludeSemantics(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final effectiveWidth =
                constraints.hasBoundedWidth &&
                    constraints.maxWidth < previewWidth
                ? constraints.maxWidth
                : previewWidth;

            return Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: staffBackground,
                  border: Border.all(color: borderColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SizedBox(
                  height: height,
                  width: effectiveWidth,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(7),
                    child: CustomPaint(
                      painter: _KeySignatureStaffPainter(
                        accidentalCount: keySignature.accidentalCount,
                        staffColor: _staffInkColor,
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

const _staffInkColor = Color(0xFF101214);
const _symbolFontFamily = 'WhatChord Symbols';
const _gClef = '\u{1D11E}';
const _sharp = '\u266F';
const _flat = '\u266D';

Color _staffBackgroundColor(ColorScheme cs) {
  if (cs.brightness == Brightness.light) return Colors.white;

  return Color.alphaBlend(cs.surface.withValues(alpha: 0.18), Colors.white);
}

class _KeySignatureStaffPainter extends CustomPainter {
  const _KeySignatureStaffPainter({
    required this.accidentalCount,
    required this.staffColor,
  });

  final int accidentalCount;
  final Color staffColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final lineSpacing = (size.height / 8.1).clamp(7.0, 11.0);
    final staffHeight = lineSpacing * 4;
    final staffTop = (size.height - staffHeight) / 2;
    final staffBottom = staffTop + staffHeight;
    final staffLeft = size.width * 0.055;
    final staffRight = size.width - (size.width * 0.045);
    final lineStroke = (lineSpacing * 0.105).clamp(1.0, 1.5);
    final barX = staffRight - lineSpacing * 0.65;
    final heavyBarX = barX + lineSpacing * 0.42;

    final linePaint = Paint()
      ..color = staffColor
      ..strokeWidth = lineStroke
      ..strokeCap = StrokeCap.square;
    final barLinePaint = Paint()
      ..color = staffColor
      ..strokeWidth = lineStroke
      ..strokeCap = StrokeCap.butt;
    final heavyLinePaint = Paint()
      ..color = staffColor
      ..strokeWidth = lineStroke * 3.0
      ..strokeCap = StrokeCap.butt;

    for (var i = 0; i < 5; i++) {
      final y = staffTop + (i * lineSpacing);
      canvas.drawLine(Offset(staffLeft, y), Offset(heavyBarX, y), linePaint);
    }

    _paintText(
      canvas,
      text: _gClef,
      fontSize: lineSpacing * 3.92,
      color: staffColor,
      offset: Offset(
        staffLeft + lineSpacing * 0.5,
        staffTop - lineSpacing * 0.12 + 1,
      ),
    );

    final accidental = accidentalCount > 0 ? _sharp : _flat;
    final positions = accidentalCount > 0
        ? _trebleSharpStaffSteps
        : _trebleFlatStaffSteps;
    final count = accidentalCount.abs();
    final accidentalFontSize = lineSpacing * 2.85;
    final accidentalLeft = staffLeft + lineSpacing * 4.85;
    final accidentalAdvance = lineSpacing * 1.16;

    for (var i = 0; i < count; i++) {
      final step = positions[i];
      final x = accidentalLeft + (i * accidentalAdvance);
      final y = _staffStepY(staffBottom, lineSpacing, step);
      _paintTextCenteredY(
        canvas,
        text: accidental,
        fontSize: accidentalFontSize,
        color: staffColor,
        x: x,
        centerY: y,
        centerYOffset: accidentalCount > 0
            ? lineSpacing * 0.16
            : -lineSpacing * 0.34,
      );
    }

    canvas.drawLine(
      Offset(barX, staffTop - lineStroke / 2),
      Offset(barX, staffBottom + lineStroke / 2),
      barLinePaint,
    );
    canvas.drawLine(
      Offset(heavyBarX, staffTop - lineStroke / 2),
      Offset(heavyBarX, staffBottom + lineStroke / 2),
      heavyLinePaint,
    );
  }

  static const _trebleSharpStaffSteps = <int>[8, 5, 9, 6, 3, 7, 4];
  static const _trebleFlatStaffSteps = <int>[4, 7, 3, 6, 2, 5, 1];

  double _staffStepY(double staffBottom, double lineSpacing, int step) {
    return staffBottom - (step * lineSpacing / 2);
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required double fontSize,
    required Color color,
    required Offset offset,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: _symbolFontFamily,
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    painter.paint(canvas, offset);
  }

  void _paintTextCenteredY(
    Canvas canvas, {
    required String text,
    required double fontSize,
    required Color color,
    required double x,
    required double centerY,
    required double centerYOffset,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontFamily: _symbolFontFamily,
          fontSize: fontSize,
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: 0, extentOffset: text.length),
      boxHeightStyle: ui.BoxHeightStyle.tight,
    );
    final box = boxes.isEmpty
        ? Rect.fromLTWH(0, 0, painter.width, painter.height)
        : boxes.first.toRect();
    final visualCenterY = box.top + box.height / 2;

    painter.paint(canvas, Offset(x, centerY + centerYOffset - visualCenterY));
  }

  @override
  bool shouldRepaint(covariant _KeySignatureStaffPainter oldDelegate) {
    return oldDelegate.accidentalCount != accidentalCount ||
        oldDelegate.staffColor != staffColor;
  }
}
