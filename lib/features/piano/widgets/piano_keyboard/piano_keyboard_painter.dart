import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:material_ui/material_ui.dart';

import '../../models/piano_key_decoration.dart';
import '../../services/piano_geometry.dart';

@immutable
class PianoTopEdgeShadowStyle {
  const PianoTopEdgeShadowStyle({
    this.enabled = true,
    this.height = 14.0,
    this.sharedOpacity = 0.14,
    this.whiteKeyExtraOpacity = 0.0,
    this.blackKeyExtraOpacity = 0.06,
    this.color = Colors.black,
  });

  final bool enabled;
  final double height;

  /// Shared band drawn across the full keyboard width for consistent anchoring.
  final double sharedOpacity;

  /// Optional extra depth on white key surfaces only.
  final double whiteKeyExtraOpacity;

  /// Optional extra depth on black key surfaces only.
  final double blackKeyExtraOpacity;

  final Color color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PianoTopEdgeShadowStyle &&
          runtimeType == other.runtimeType &&
          enabled == other.enabled &&
          height == other.height &&
          sharedOpacity == other.sharedOpacity &&
          whiteKeyExtraOpacity == other.whiteKeyExtraOpacity &&
          blackKeyExtraOpacity == other.blackKeyExtraOpacity &&
          color == other.color;

  @override
  int get hashCode => Object.hash(
    enabled,
    height,
    sharedOpacity,
    whiteKeyExtraOpacity,
    blackKeyExtraOpacity,
    color,
  );
}

class PianoKeyboardPainter extends CustomPainter {
  static const double _pressedWhiteEdgeAlpha = 0.08;
  static const double _pressedWhiteBorderWidth = 1.35;
  static const double _impliedStrokeWidth = 2.5;
  // The white-key stroke sits flush against the key boundary so the gray
  // separator line is the outline's outer edge, with no white sliver between
  // them; the black key floats its stroke inside the solid key surface.
  static const double _impliedBlackInset = 2.0;

  PianoKeyboardPainter({
    required this.whiteKeyCount,
    required this.firstMidiNote,
    required this.highlightedNoteNumbers,
    this.impliedNoteNumbers = const <int>{},
    this.scaleNoteNumbers = const <int>{},
    this.normalHighlightPitchClasses,
    this.scaleMarkerColor,
    this.tonicPitchClass,
    required this.whiteKeyColor,
    required this.pressedWhiteKeyColor,
    required this.pressedBlackKeyColor,
    this.outOfScalePressedWhiteKeyColor,
    this.outOfScalePressedBlackKeyColor,
    required this.whiteKeyBorderColor,
    required this.pressedWhiteKeyBorderColor,
    required this.pressedWhiteKeySeparatorColor,
    required this.pressedBlackKeySeparatorColor,
    required this.blackKeyColor,
    required this.backgroundColor,
    this.decorations = const <PianoKeyDecoration>[],
    this.decorationColor,
    this.decorationTextScaleMultiplier = 1.0,
    this.drawBackground = true,
    this.drawFeltStrip = true,
    this.feltColor = const Color(0xFF800020),
    this.feltHeight = 2.0,
    this.topEdgeShadowStyle = const PianoTopEdgeShadowStyle(),
  }) : assert(
         decorationColor != null ||
             !decorations.any((d) => d.style == PianoKeyDecorationStyle.label),
         'decorationTextColor must be provided when label decorations are present',
       ),
       _geometry = PianoGeometry(
         firstWhiteMidi: firstMidiNote,
         whiteKeyCount: whiteKeyCount,
       );

  final int whiteKeyCount;
  final int firstMidiNote;

  /// Highlighted *MIDI note numbers* (e.g., 60 for middle C).
  final Set<int> highlightedNoteNumbers;

  /// Implied *MIDI note numbers*: keys drawn as a hollow outline of the
  /// pressed highlight, marking a tone the analysis names but nobody played
  /// (the implied root of an ensemble rootless reading). A key that is also
  /// highlighted keeps its normal pressed rendering.
  final Set<int> impliedNoteNumbers;

  /// Scale member *MIDI note numbers*. Each member key gets a dot marker in the
  /// lower portion of the key so the in-scale notes are obvious at a glance.
  /// Requires [scaleMarkerColor]; empty means no markers.
  final Set<int> scaleNoteNumbers;

  /// Pitch classes that keep the normal active highlight when highlighted.
  /// Highlighted notes outside this set use the muted active fill. Null falls
  /// back to [scaleNoteNumbers] membership, preserving scale-marker behavior.
  final Set<int>? normalHighlightPitchClasses;

  /// Fill color for the scale member dot markers. Black keys use a lightened
  /// variant for contrast. Required when [scaleNoteNumbers] is non-empty.
  final Color? scaleMarkerColor;

  /// Pitch class (0-11) of the scale tonic. Member keys at this pitch class are
  /// marked with a triangle instead of a dot to anchor the root. Null marks
  /// every member with a dot.
  final int? tonicPitchClass;

  final Color whiteKeyColor;
  final Color pressedWhiteKeyColor;
  final Color pressedBlackKeyColor;

  /// Optional muted pressed colors for highlighted notes outside
  /// [scaleNoteNumbers]. Ignored when [scaleNoteNumbers] is empty.
  final Color? outOfScalePressedWhiteKeyColor;
  final Color? outOfScalePressedBlackKeyColor;

  final Color whiteKeyBorderColor;
  final Color pressedWhiteKeyBorderColor;
  final Color pressedWhiteKeySeparatorColor;
  final Color pressedBlackKeySeparatorColor;
  final Color blackKeyColor;
  final Color backgroundColor;

  /// Key decorations (e.g., middle C marker, scale markers).
  final List<PianoKeyDecoration> decorations;
  final Color? decorationColor;
  final double decorationTextScaleMultiplier;

  final bool drawBackground;

  final bool drawFeltStrip;
  final Color feltColor;
  final double feltHeight;
  final PianoTopEdgeShadowStyle topEdgeShadowStyle;

  final PianoGeometry _geometry;

  int _whiteMidiForIndex(int whiteIndex) =>
      _geometry.whiteMidiForIndex(whiteIndex);

  bool _isHighlighted(int midi) => highlightedNoteNumbers.contains(midi);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    if (whiteKeyCount <= 0 || width <= 0 || height <= 0) return;

    if (drawBackground) {
      final bgPaint = Paint()..color = backgroundColor;
      canvas.drawRect(Offset.zero & size, bgPaint);
    }

    final whiteKeyWidth = width / whiteKeyCount;
    final whiteKeyHeight = height;
    final blackKeyWidth = whiteKeyWidth * PianoGeometry.blackKeyWidthRatio;
    final blackKeyHeight = whiteKeyHeight * PianoGeometry.blackKeyHeightRatio;
    final topInset = (drawFeltStrip ? feltHeight : 0.0).clamp(0.0, height);

    final whiteFillPaint = Paint()..style = PaintingStyle.fill;
    final whiteBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = whiteKeyBorderColor;
    final pressedWhiteBorderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _pressedWhiteBorderWidth
      ..color = pressedWhiteKeyBorderColor;
    final pressedWhiteSeparatorPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = pressedWhiteKeySeparatorColor;
    final pressedBlackSeparatorPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = pressedBlackKeySeparatorColor;
    final blackFillPaint = Paint()..style = PaintingStyle.fill;
    final pressedWhiteAccentPaint = Paint()..style = PaintingStyle.fill;
    final pressedBlackAccentPaint = Paint()..style = PaintingStyle.fill;
    final pressedWhiteEdgePaint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.black.withValues(alpha: _pressedWhiteEdgeAlpha);
    final impliedWhitePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _impliedStrokeWidth
      ..color = pressedWhiteKeyColor;
    final impliedBlackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _impliedStrokeWidth
      ..color = pressedBlackKeyColor;
    // White keys
    for (int i = 0; i < whiteKeyCount; i++) {
      final x = i * whiteKeyWidth;
      final rect = Rect.fromLTWH(x, 0, whiteKeyWidth, whiteKeyHeight);

      final midi = _whiteMidiForIndex(i);
      final isHighlighted = _isHighlighted(midi);
      final highlightedFill = _pressedWhiteFillFor(midi);

      whiteFillPaint.color = isHighlighted ? highlightedFill : whiteKeyColor;

      canvas.drawRect(rect, whiteFillPaint);
      if (isHighlighted) {
        pressedWhiteAccentPaint.color = Color.lerp(
          highlightedFill,
          Colors.white,
          0.28,
        )!;
        _paintPressedKeyAccents(
          canvas,
          rect,
          topInset: topInset,
          topAccentPaint: pressedWhiteAccentPaint,
          edgeShadowPaint: pressedWhiteEdgePaint,
        );
      }
      canvas.drawRect(rect, whiteBorderPaint);
      if (!isHighlighted && impliedNoteNumbers.contains(midi)) {
        canvas.drawRect(
          Rect.fromLTRB(
            rect.left + _impliedStrokeWidth / 2,
            topInset + _impliedStrokeWidth / 2,
            rect.right - _impliedStrokeWidth / 2,
            rect.bottom - _impliedStrokeWidth / 2,
          ),
          impliedWhitePaint,
        );
      }
      if (isHighlighted && topInset < rect.bottom) {
        pressedWhiteBorderPaint.color = _pressedWhiteBorderFor(
          midi,
          highlightedFill,
        );
        pressedWhiteSeparatorPaint.color = _pressedWhiteSeparatorFor(
          midi,
          highlightedFill,
        );
        canvas.drawRect(
          rect.deflate(_pressedWhiteBorderWidth / 2.0),
          pressedWhiteBorderPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.left, topInset, rect.width, 1.0),
          pressedWhiteAccentPaint,
        );
        final separatorHeight = rect.bottom - topInset;
        canvas.drawRect(
          Rect.fromLTWH(rect.left, topInset, 1.0, separatorHeight),
          pressedWhiteSeparatorPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(rect.right - 1.0, topInset, 1.0, separatorHeight),
          pressedWhiteSeparatorPaint,
        );
      }
    }

    // Black keys
    final blackKeyRects = <Rect>[];

    for (int i = 0; i < whiteKeyCount - 1; i++) {
      final whitePc = _geometry.whitePitchClassForIndex(i);
      if (!PianoGeometry.hasBlackAfterWhitePc(whitePc)) continue;

      final whiteMidi = _whiteMidiForIndex(i);
      final blackMidi = whiteMidi + 1;
      final blackPc = blackMidi % 12;

      final boundaryX = (i + 1) * whiteKeyWidth;
      final centerX =
          boundaryX +
          PianoGeometry.blackCenterBiasForPc(blackPc, whiteKeyWidth);

      double blackLeft = centerX - (blackKeyWidth / 2.0);
      blackLeft = blackLeft.clamp(0.0, width - blackKeyWidth);

      final rect = Rect.fromLTWH(blackLeft, 0, blackKeyWidth, blackKeyHeight);
      blackKeyRects.add(rect);

      final isHighlightedBlack = _isHighlighted(blackMidi);
      final highlightedBlackFill = _pressedBlackFillFor(blackMidi);
      blackFillPaint.color = isHighlightedBlack
          ? highlightedBlackFill
          : blackKeyColor;
      canvas.drawRect(rect, blackFillPaint);
      if (!isHighlightedBlack && impliedNoteNumbers.contains(blackMidi)) {
        canvas.drawRect(rect.deflate(_impliedBlackInset), impliedBlackPaint);
      }
      if (isHighlightedBlack) {
        pressedBlackAccentPaint.color = Color.lerp(
          highlightedBlackFill,
          Colors.white,
          0.20,
        )!;
        pressedBlackSeparatorPaint.color = _pressedBlackSeparatorFor(
          blackMidi,
          highlightedBlackFill,
        );
        _paintPressedKeyAccents(
          canvas,
          rect,
          topInset: topInset,
          topAccentPaint: pressedBlackAccentPaint,
          edgeShadowPaint: pressedBlackSeparatorPaint,
          edgeInset: 0.0,
          edgeWidth: 2.0,
          bottomEdgeHeight: 2.0,
        );
      }
    }

    _paintTopEdgeShadow(canvas, size, blackKeyRects: blackKeyRects);

    // Felt strip LAST so it stays visible.
    if (drawFeltStrip && feltHeight > 0) {
      final feltPaint = Paint()..color = feltColor;
      canvas.drawRect(Rect.fromLTWH(0, 0, width, feltHeight), feltPaint);
    }

    if (scaleNoteNumbers.isNotEmpty && scaleMarkerColor != null) {
      _paintScaleMarkers(
        canvas,
        size,
        whiteKeyWidth: whiteKeyWidth,
        blackKeyHeight: blackKeyHeight,
      );
    }

    if (decorations.isNotEmpty) {
      _paintDecorations(canvas, size, whiteKeyWidth: whiteKeyWidth);
    }
  }

  bool _usesNormalHighlight(int midi) {
    final highlightPcs = normalHighlightPitchClasses;
    if (highlightPcs != null) return highlightPcs.contains(midi % 12);
    return scaleNoteNumbers.isEmpty || scaleNoteNumbers.contains(midi);
  }

  Color _pressedWhiteFillFor(int midi) {
    if (_usesNormalHighlight(midi)) return pressedWhiteKeyColor;
    return outOfScalePressedWhiteKeyColor ?? pressedWhiteKeyColor;
  }

  Color _pressedBlackFillFor(int midi) {
    if (_usesNormalHighlight(midi)) return pressedBlackKeyColor;
    return outOfScalePressedBlackKeyColor ?? pressedBlackKeyColor;
  }

  Color _pressedWhiteBorderFor(int midi, Color fill) {
    if (_usesNormalHighlight(midi)) return pressedWhiteKeyBorderColor;
    return Color.alphaBlend(Colors.black.withValues(alpha: 0.24), fill);
  }

  Color _pressedWhiteSeparatorFor(int midi, Color fill) {
    if (_usesNormalHighlight(midi)) return pressedWhiteKeySeparatorColor;
    return Color.alphaBlend(Colors.black.withValues(alpha: 0.22), fill);
  }

  Color _pressedBlackSeparatorFor(int midi, Color fill) {
    if (_usesNormalHighlight(midi)) return pressedBlackKeySeparatorColor;
    return Color.alphaBlend(Colors.black.withValues(alpha: 0.20), fill);
  }

  /// Draws a dot in the lower portion of each scale member key (a triangle for
  /// the tonic). The marker is kept on highlighted keys too, recolored for
  /// contrast so it stays legible against the pressed fill.
  void _paintScaleMarkers(
    Canvas canvas,
    Size size, {
    required double whiteKeyWidth,
    required double blackKeyHeight,
  }) {
    final markerColor = scaleMarkerColor!;
    final blackMarkerColor = Color.lerp(markerColor, Colors.white, 0.4)!;
    final blackKeyWidth = whiteKeyWidth * PianoGeometry.blackKeyWidthRatio;
    final whiteKeyHeight = size.height;

    // Markers grow with both key width and height (so an enlarged keyboard gets
    // proportionally larger dots), but stay bounded by key width and a hard
    // ceiling so they never overflow horizontally or balloon on a tall keyboard.
    final whiteMaxRadius = math.max(math.min(whiteKeyWidth * 0.30, 11.0), 4.0);
    final blackMaxRadius = math.max(math.min(blackKeyWidth * 0.44, 7.5), 3.0);
    final whiteRadius = math
        .max(whiteKeyWidth * 0.20, whiteKeyHeight * 0.026)
        .clamp(4.0, whiteMaxRadius)
        .toDouble();
    final blackRadius = math
        .max(blackKeyWidth * 0.34, whiteKeyHeight * 0.020)
        .clamp(3.0, blackMaxRadius)
        .toDouble();

    // Reserve room for a bottom label (the middle-C marker) and record its
    // on-key center. The reserve uses a fixed lift rather than the label's own
    // bottomLift so nudging the label for the nav indicator does not move dots.
    const labelClearanceLift = 14.0;
    double bottomClearance = (whiteKeyWidth * 0.18).clamp(4.0, 8.0).toDouble();
    double? labelCenterY;
    for (final d in decorations) {
      if (d.style != PianoKeyDecorationStyle.label) continue;
      if (d.label == null || d.label!.isEmpty) continue;
      final labelFontSize =
          (whiteKeyWidth * 0.52 * decorationTextScaleMultiplier)
              .clamp(9.0, 16.0)
              .toDouble();
      final labelPad = (whiteKeyWidth * 0.18).clamp(4.0, 8.0).toDouble();
      final clearance = labelFontSize * 1.25 + labelPad + labelClearanceLift;
      if (clearance > bottomClearance) bottomClearance = clearance;
      final center =
          size.height - (labelPad + d.bottomLift) - labelFontSize * 1.2 / 2.0;
      if (labelCenterY == null || center > labelCenterY) labelCenterY = center;
    }

    final blackCy = blackKeyHeight - blackRadius - 8.0;
    // Rest the white dots midway between the bottom label and the black-key
    // dots so the three rows read as evenly spaced; fall back to just above the
    // label band when there is no label.
    final labelY = labelCenterY;
    final whiteCy = labelY != null
        ? (blackCy + labelY) / 2.0
        : size.height - bottomClearance - whiteRadius;

    final minMidi = _geometry.whiteMidis.first;
    final maxMidi = _geometry.whiteMidis.last;
    final fill = Paint()..style = PaintingStyle.fill;

    for (final midi in scaleNoteNumbers) {
      if (midi < minMidi || midi > maxMidi) continue;

      final keyRect = _geometry.keyRectForMidi(
        midi: midi,
        whiteKeyWidth: whiteKeyWidth,
        totalWidth: size.width,
      );
      final cx = (keyRect.left + keyRect.right) / 2.0;
      if (cx < 0 || cx > size.width) continue;

      final isBlack = PianoGeometry.isBlackMidi(midi);
      final isTonic = tonicPitchClass != null && midi % 12 == tonicPitchClass;

      // White keys: the saturated accent marker reads well even on the pressed
      // fill (which is light in both themes), so it needs no special case.
      // Black keys: the lightened accent reads on the resting black key, but on
      // a pressed (accent-filled) black key it would blend, so switch to a black
      // marker for a clean cutout.
      if (isBlack) {
        fill.color = _isHighlighted(midi) ? blackKeyColor : blackMarkerColor;
      } else {
        fill.color = markerColor;
      }
      final center = Offset(cx, isBlack ? blackCy : whiteCy);
      final radius = isBlack ? blackRadius : whiteRadius;

      if (isTonic) {
        _drawTonicTriangle(canvas, fill, center, radius);
      } else {
        canvas.drawCircle(center, radius, fill);
      }
    }
  }

  /// Upward triangle centered (by area) on [center], sized to read at about the
  /// same weight as a dot of [radius].
  void _drawTonicTriangle(
    Canvas canvas,
    Paint fill,
    Offset center,
    double radius,
  ) {
    final halfW = radius * 1.3;
    final halfH = radius * 1.2;
    // Shift up so the triangle's centroid (a third of the way up from the base)
    // lands on [center], keeping it aligned with the dots.
    final cy = center.dy - halfH / 3.0;
    final path = Path()
      ..moveTo(center.dx, cy - halfH)
      ..lineTo(center.dx - halfW, cy + halfH)
      ..lineTo(center.dx + halfW, cy + halfH)
      ..close();
    canvas.drawPath(path, fill);
  }

  void _paintTopEdgeShadow(
    Canvas canvas,
    Size size, {
    required List<Rect> blackKeyRects,
  }) {
    if (!topEdgeShadowStyle.enabled) return;

    final topInset = (drawFeltStrip ? feltHeight : 0.0).clamp(0.0, size.height);
    final maxHeight = (size.height - topInset).clamp(0.0, size.height);
    if (maxHeight <= 0) return;

    final shadowHeight = topEdgeShadowStyle.height.clamp(0.0, maxHeight);
    if (shadowHeight <= 0) return;

    final paint = Paint()..style = PaintingStyle.fill;
    final baseColor = topEdgeShadowStyle.color;

    Shader shaderForOpacity(Rect rect, double opacity) {
      final alpha = opacity.clamp(0.0, 1.0);
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[
          baseColor.withValues(alpha: alpha),
          baseColor.withValues(alpha: 0.0),
        ],
      ).createShader(rect);
    }

    void drawGradientRect(Rect rect, double opacity) {
      if (opacity <= 0) return;
      paint.shader = shaderForOpacity(rect, opacity);
      canvas.drawRect(rect, paint);
      paint.shader = null;
    }

    final sharedRect = Rect.fromLTWH(0, topInset, size.width, shadowHeight);
    drawGradientRect(sharedRect, topEdgeShadowStyle.sharedOpacity);

    if (topEdgeShadowStyle.whiteKeyExtraOpacity > 0) {
      final whiteRect = Rect.fromLTWH(0, topInset, size.width, shadowHeight);
      final blackOverlapPath = Path();
      for (final rect in blackKeyRects) {
        final overlap = Rect.fromLTRB(
          rect.left.clamp(whiteRect.left, whiteRect.right),
          rect.top.clamp(whiteRect.top, whiteRect.bottom),
          rect.right.clamp(whiteRect.left, whiteRect.right),
          rect.bottom.clamp(whiteRect.top, whiteRect.bottom),
        );
        if (!overlap.isEmpty) {
          blackOverlapPath.addRect(overlap);
        }
      }

      canvas.save();
      canvas.clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(whiteRect),
          blackOverlapPath,
        ),
      );
      drawGradientRect(whiteRect, topEdgeShadowStyle.whiteKeyExtraOpacity);
      canvas.restore();
    }

    if (topEdgeShadowStyle.blackKeyExtraOpacity > 0) {
      for (final rect in blackKeyRects) {
        final clippedTop = rect.top < topInset ? topInset : rect.top;
        final clippedHeight = (rect.bottom - clippedTop).clamp(
          0.0,
          shadowHeight,
        );
        if (clippedHeight <= 0) continue;
        drawGradientRect(
          Rect.fromLTWH(rect.left, clippedTop, rect.width, clippedHeight),
          topEdgeShadowStyle.blackKeyExtraOpacity,
        );
      }
    }
  }

  void _paintPressedKeyAccents(
    Canvas canvas,
    Rect rect, {
    required double topInset,
    required Paint topAccentPaint,
    required Paint edgeShadowPaint,
    double edgeInset = 1.0,
    double edgeWidth = 1.0,
    double bottomEdgeHeight = 0.0,
  }) {
    if (rect.isEmpty) return;

    final visibleTop = rect.top < topInset ? topInset : rect.top;
    final visibleHeight = rect.bottom - visibleTop;
    if (visibleHeight <= 0) return;

    final accentHeight = visibleHeight >= 1.0 ? 1.0 : visibleHeight;
    if (accentHeight > 0) {
      canvas.drawRect(
        Rect.fromLTWH(rect.left, visibleTop, rect.width, accentHeight),
        topAccentPaint,
      );
    }

    if (rect.width >= 4.0) {
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left + edgeInset,
          visibleTop,
          edgeWidth,
          visibleHeight,
        ),
        edgeShadowPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          rect.right - edgeInset - edgeWidth,
          visibleTop,
          edgeWidth,
          visibleHeight,
        ),
        edgeShadowPaint,
      );
    }

    if (bottomEdgeHeight > 0) {
      final resolvedHeight = bottomEdgeHeight.clamp(0.0, visibleHeight);
      canvas.drawRect(
        Rect.fromLTWH(
          rect.left,
          rect.bottom - resolvedHeight,
          rect.width,
          resolvedHeight,
        ),
        edgeShadowPaint,
      );
    }
  }

  void _paintDecorations(
    Canvas canvas,
    Size size, {
    required double whiteKeyWidth,
  }) {
    final color = decorationColor;
    if (color == null) return;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Place near the bottom of the white key, but leave a small margin.
    final baseBottomPad = (whiteKeyWidth * 0.18).clamp(4.0, 8.0);

    for (final d in decorations) {
      if (d.style != PianoKeyDecorationStyle.label) continue;
      final label = d.label;
      if (label == null || label.isEmpty) continue;

      final whiteIndex = _geometry.whiteIndexForMidi(d.midiNote);
      if (whiteIndex < 0 || whiteIndex >= whiteKeyCount) continue;
      final fontSize = (whiteKeyWidth * 0.52 * decorationTextScaleMultiplier)
          .clamp(9.0, 16.0)
          .toDouble();

      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      );

      textPainter.layout(minWidth: whiteKeyWidth, maxWidth: whiteKeyWidth);

      final dx = whiteIndex * whiteKeyWidth;

      final bottomPad = baseBottomPad + d.bottomLift;
      final dy = size.height - textPainter.height - bottomPad;

      textPainter.paint(canvas, Offset(dx, dy));
    }
  }

  @override
  bool shouldRepaint(covariant PianoKeyboardPainter oldDelegate) {
    return oldDelegate.whiteKeyCount != whiteKeyCount ||
        oldDelegate.firstMidiNote != firstMidiNote ||
        oldDelegate.drawBackground != drawBackground ||
        oldDelegate.drawFeltStrip != drawFeltStrip ||
        oldDelegate.feltColor != feltColor ||
        oldDelegate.feltHeight != feltHeight ||
        oldDelegate.topEdgeShadowStyle != topEdgeShadowStyle ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.whiteKeyColor != whiteKeyColor ||
        oldDelegate.pressedWhiteKeyColor != pressedWhiteKeyColor ||
        oldDelegate.pressedBlackKeyColor != pressedBlackKeyColor ||
        oldDelegate.outOfScalePressedWhiteKeyColor !=
            outOfScalePressedWhiteKeyColor ||
        oldDelegate.outOfScalePressedBlackKeyColor !=
            outOfScalePressedBlackKeyColor ||
        oldDelegate.whiteKeyBorderColor != whiteKeyBorderColor ||
        oldDelegate.pressedWhiteKeyBorderColor != pressedWhiteKeyBorderColor ||
        oldDelegate.pressedWhiteKeySeparatorColor !=
            pressedWhiteKeySeparatorColor ||
        oldDelegate.pressedBlackKeySeparatorColor !=
            pressedBlackKeySeparatorColor ||
        oldDelegate.blackKeyColor != blackKeyColor ||
        oldDelegate.decorationColor != decorationColor ||
        oldDelegate.decorationTextScaleMultiplier !=
            decorationTextScaleMultiplier ||
        !listEquals(oldDelegate.decorations, decorations) ||
        !setEquals(
          oldDelegate.highlightedNoteNumbers,
          highlightedNoteNumbers,
        ) ||
        !setEquals(oldDelegate.impliedNoteNumbers, impliedNoteNumbers) ||
        oldDelegate.scaleMarkerColor != scaleMarkerColor ||
        oldDelegate.tonicPitchClass != tonicPitchClass ||
        !setEquals(
          oldDelegate.normalHighlightPitchClasses,
          normalHighlightPitchClasses,
        ) ||
        !setEquals(oldDelegate.scaleNoteNumbers, scaleNoteNumbers);
  }
}
