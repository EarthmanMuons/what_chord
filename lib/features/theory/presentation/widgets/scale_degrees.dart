import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:whatchord/whatchord.dart';

import 'scale_degree_roman_text.dart';

class ScaleDegrees extends StatefulWidget {
  final ScaleDegreeAnalysis? current;
  final TonalityMode mode;
  final String tonalityDisplayName;
  final values = ScaleDegree.values;
  final double? maxHeight;
  final Color? fadeColor;
  final double textScaleMultiplier;

  const ScaleDegrees({
    super.key,
    required this.current,
    required this.mode,
    required this.tonalityDisplayName,
    this.maxHeight,
    this.fadeColor,
    this.textScaleMultiplier = 1.0,
  });

  @override
  State<ScaleDegrees> createState() => _ScaleDegreesState();
}

class _ScaleDegreesState extends State<ScaleDegrees> {
  static const double _fadeWidth = 24.0;
  static const double _defaultIndicatorHeight = 56.0;
  static const Duration _tooltipShowDuration = Duration(seconds: 3);

  final ScrollController _scrollController = ScrollController();
  bool _showLeftFade = false;
  bool _showRightFade = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void didUpdateWidget(covariant ScaleDegrees oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateFades);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    const epsilon = 0.5;
    final maxExtent = position.maxScrollExtent;
    final pixels = position.pixels;

    final nextLeft = maxExtent > epsilon && pixels > epsilon;
    final nextRight = maxExtent > epsilon && pixels < maxExtent - epsilon;

    if (nextLeft == _showLeftFade && nextRight == _showRightFade) return;

    setState(() {
      _showLeftFade = nextLeft;
      _showRightFade = nextRight;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fadeColor =
        widget.fadeColor ?? Theme.of(context).colorScheme.surfaceContainerLow;
    final maxHeight = widget.maxHeight ?? _defaultIndicatorHeight;
    final tooltipMessage = _tooltipMessageForCurrent(widget.current);
    final tooltipRichMessage = _tooltipRichMessageForCurrent(widget.current);

    return Semantics(
      container: true,
      label: 'Scale degree',
      value: _semanticsValueForCurrent(widget.current),
      child: ExcludeSemantics(
        child: Tooltip(
          message: tooltipRichMessage == null ? tooltipMessage : null,
          richMessage: tooltipRichMessage,
          showDuration: _tooltipShowDuration,
          child: LayoutBuilder(
            builder: (context, constraints) {
              WidgetsBinding.instance.addPostFrameCallback(
                (_) => _updateFades(),
              );
              final labels = [
                for (final degree in widget.values) _labelForDegree(degree),
              ];
              final indicatorGap = _indicatorGapFor(
                context,
                availableWidth: constraints.maxWidth,
                labels: labels,
                maxHeight: maxHeight,
              );

              final scrollable = SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (int i = 0; i < widget.values.length; i++) ...[
                      _ScaleDegreeIndicator(
                        label: labels[i],
                        isCurrent: widget.values[i] == widget.current?.degree,
                        maxHeight: maxHeight,
                        textScaleMultiplier: widget.textScaleMultiplier,
                      ),
                      if (i < widget.values.length - 1)
                        SizedBox(width: indicatorGap),
                    ],
                  ],
                ),
              );

              return Stack(
                children: [
                  scrollable,
                  if (_showLeftFade)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: _fadeWidth,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                fadeColor,
                                fadeColor.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_showRightFade)
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: _fadeWidth,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerRight,
                              end: Alignment.centerLeft,
                              colors: [
                                fadeColor,
                                fadeColor.withValues(alpha: 0),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  double _indicatorGapFor(
    BuildContext context, {
    required double availableWidth,
    required List<String> labels,
    required double maxHeight,
  }) {
    final labelWidth = labels.indexed.fold<double>(0, (total, entry) {
      final (index, label) = entry;
      return total +
          _indicatorWidth(
            context,
            label: label,
            isCurrent: widget.values[index] == widget.current?.degree,
            maxHeight: maxHeight,
            textScaleMultiplier: widget.textScaleMultiplier,
          );
    });
    final gapCount = labels.length - 1;

    // Keep the normal rhythm whenever the rendered labels fit. Minor-key
    // numerals are measured directly, and 6 remains the readability floor.
    for (final gap in const [10.0, 8.0, 6.0]) {
      if (labelWidth + gap * gapCount <= availableWidth) return gap;
    }
    return 6;
  }

  String _semanticsValueForCurrent(ScaleDegreeAnalysis? analysis) {
    final keyName = widget.tonalityDisplayName;
    if (analysis == null) {
      return 'No scale-degree match in $keyName';
    }

    final source = analysis.source == ScaleDegreeSource.major
        ? ''
        : ', ${analysis.source.displayLabel}';
    return '${analysis.spokenScaleDegree} '
        '(${analysis.functionName}$source) in $keyName';
  }

  String _tooltipMessageForCurrent(ScaleDegreeAnalysis? analysis) {
    if (analysis == null) {
      return 'Scale degree\nNo match';
    }

    final function = _titleCase(analysis.functionName);
    final source = analysis.source == ScaleDegreeSource.major
        ? ''
        : ' · ${analysis.source.displayLabel}';
    return 'Scale degree\n${analysis.romanNumeral} ($function$source)';
  }

  InlineSpan? _tooltipRichMessageForCurrent(ScaleDegreeAnalysis? analysis) {
    if (analysis == null) return null;

    final function = _titleCase(analysis.functionName);
    final source = analysis.source == ScaleDegreeSource.major
        ? ''
        : ' · ${analysis.source.displayLabel}';
    return TextSpan(
      children: [
        const TextSpan(text: 'Scale degree\n'),
        ...scaleDegreeRomanSpans(analysis.romanNumeral),
        TextSpan(text: ' ($function$source)'),
      ],
    );
  }

  String _labelForDegree(ScaleDegree degree) {
    final current = widget.current;
    if (current?.degree == degree) return current!.romanNumeral;
    return degree.romanNumeralForSource(_displaySource);
  }

  ScaleDegreeSource get _displaySource {
    final currentSource = widget.current?.source;
    if (currentSource == ScaleDegreeSource.harmonicMinor) {
      return ScaleDegreeSource.harmonicMinor;
    }
    if (widget.mode == TonalityMode.major) return ScaleDegreeSource.major;
    return ScaleDegreeSource.naturalMinor;
  }

  String _titleCase(String value) {
    final words = value.split(' ');
    return words
        .map((word) {
          if (word.isEmpty) return word;
          final first = word[0].toUpperCase();
          final rest = word.substring(1);
          return '$first$rest';
        })
        .join(' ');
  }
}

class _ScaleDegreeIndicator extends StatelessWidget {
  final String label;
  final bool isCurrent;
  final double maxHeight;
  final double textScaleMultiplier;

  const _ScaleDegreeIndicator({
    required this.label,
    required this.isCurrent,
    required this.maxHeight,
    required this.textScaleMultiplier,
  });

  @override
  Widget build(BuildContext context) {
    final layout = _indicatorLayout(
      context,
      isCurrent: isCurrent,
      maxHeight: maxHeight,
      textScaleMultiplier: textScaleMultiplier,
    );
    const underlineHeight = 3.0;

    return SizedBox(
      height: maxHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ScaleDegreeLabel(
            text: label,
            style: layout.textStyle,
            textScale: layout.textScale,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: layout.underlinePadding),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: underlineHeight,
                width: layout.underlineWidth,
                decoration: BoxDecoration(
                  color: isCurrent
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

double _indicatorWidth(
  BuildContext context, {
  required String label,
  required bool isCurrent,
  required double maxHeight,
  required double textScaleMultiplier,
}) {
  final layout = _indicatorLayout(
    context,
    isCurrent: isCurrent,
    maxHeight: maxHeight,
    textScaleMultiplier: textScaleMultiplier,
  );
  final painter = TextPainter(
    text: TextSpan(
      style: layout.textStyle,
      children: scaleDegreeRomanSpans(label),
    ),
    textDirection: Directionality.of(context),
    textScaler: TextScaler.linear(layout.textScale),
    maxLines: 1,
  )..layout();
  final width = math.max(layout.underlineWidth, painter.width);
  painter.dispose();
  return width;
}

_ScaleDegreeIndicatorLayout _indicatorLayout(
  BuildContext context, {
  required bool isCurrent,
  required double maxHeight,
  required double textScaleMultiplier,
}) {
  final theme = Theme.of(context);
  final cs = theme.colorScheme;
  final baseStyle = theme.textTheme.labelLarge;
  final scale = MediaQuery.textScalerOf(context).scale(1.0);
  final underlinePadding = maxHeight <= 48
      ? 4.0
      : scale > 1.4
      ? 6.0
      : 8.0;
  const underlineHeight = 3.0;
  final scaleMultiplier = textScaleMultiplier.clamp(1.0, 1.3);
  final baseFontSize = ((baseStyle?.fontSize ?? 14) + 2) * scaleMultiplier;
  final baseLineHeight = baseFontSize * (baseStyle?.height ?? 1.2);
  final availableHeight = maxHeight - underlinePadding - underlineHeight;
  final maxScale = (availableHeight / baseLineHeight).clamp(1.0, 3.0);
  final textScale = scale.clamp(1.0, maxScale);
  final textStyle = (baseStyle ?? const TextStyle()).copyWith(
    fontSize: baseFontSize,
    color: isCurrent ? cs.primary : cs.onSurfaceVariant.withValues(alpha: 0.65),
    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
  );

  return _ScaleDegreeIndicatorLayout(
    textStyle: textStyle,
    textScale: textScale,
    underlinePadding: underlinePadding,
    underlineWidth: (18 * scaleMultiplier).clamp(18.0, 24.0),
  );
}

class _ScaleDegreeIndicatorLayout {
  const _ScaleDegreeIndicatorLayout({
    required this.textStyle,
    required this.textScale,
    required this.underlinePadding,
    required this.underlineWidth,
  });

  final TextStyle textStyle;
  final double textScale;
  final double underlinePadding;
  final double underlineWidth;
}

class _ScaleDegreeLabel extends StatelessWidget {
  final String text;
  final TextStyle style;
  final double textScale;

  const _ScaleDegreeLabel({
    required this.text,
    required this.style,
    required this.textScale,
  });

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: scaleDegreeRomanSpans(text)),
      style: style,
      textScaler: TextScaler.linear(textScale),
    );
  }
}
