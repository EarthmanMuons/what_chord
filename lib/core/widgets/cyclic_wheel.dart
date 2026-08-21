import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// A horizontally scrubbable, infinitely cyclic picker. The selected value sits
/// centered with faded neighbors; tapping a neighbor or scrubbing selects it.
class CyclicWheel<T> extends StatefulWidget {
  const CyclicWheel({
    super.key,
    required this.label,
    required this.value,
    required this.choices,
    required this.displayLabelFor,
    required this.semanticLabelFor,
    required this.onChanged,
    this.targetItemWidth = 96,
    this.selectedMinWidth = 76,
    this.unselectedMinWidth = 64,
    this.selectedHorizontalPadding = 8,
    this.unselectedHorizontalPadding = 6,
  });

  final String label;
  final T value;
  final List<T> choices;
  final String Function(T value) displayLabelFor;
  final String Function(T value) semanticLabelFor;
  final double targetItemWidth;
  final double selectedMinWidth;
  final double unselectedMinWidth;
  final double selectedHorizontalPadding;
  final double unselectedHorizontalPadding;
  final ValueChanged<T> onChanged;

  @override
  State<CyclicWheel<T>> createState() => _CyclicWheelState<T>();
}

class _CyclicWheelState<T> extends State<CyclicWheel<T>> {
  static const _initialLoop = 500;
  static const _wheelHeight = 64.0;
  static const _wheelContentPadding = EdgeInsets.fromLTRB(8, 10, 8, 6);

  PageController? _controller;
  double? _viewportFraction;
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = _basePageForValue(widget.value);
  }

  @override
  void didUpdateWidget(covariant CyclicWheel<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.choices != widget.choices) {
      // The cycle length changed, so old page positions no longer map to the
      // same values. Rebase and recenter on the current value.
      _currentPage = _basePageForValue(widget.value);
      final controller = _controller;
      if (controller?.hasClients == true) {
        // Jump the live controller; recreating it could restore the stale
        // offset over initialPage and leave the value off-center.
        controller!.jumpToPage(_currentPage);
      } else {
        _resetController();
      }
      return;
    }

    if (oldWidget.value == widget.value) return;

    final visiblePage = _visiblePage;
    if (_valueForPage(visiblePage) == widget.value) return;

    final targetPage = _nearestPageForValue(widget.value);
    _currentPage = targetPage;
    if (_controller?.hasClients != true) return;

    unawaited(
      _controller!.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = widget.semanticLabelFor(widget.value);
    return Semantics(
      container: true,
      label: widget.label,
      value: selectedLabel,
      increasedValue: widget.semanticLabelFor(_nextValue(widget.value)),
      decreasedValue: widget.semanticLabelFor(_previousValue(widget.value)),
      onIncrease: () => widget.onChanged(_nextValue(widget.value)),
      onDecrease: () => widget.onChanged(_previousValue(widget.value)),
      child: ExcludeSemantics(
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: widget.label,
            border: const OutlineInputBorder(),
            contentPadding: _wheelContentPadding,
          ),
          child: SizedBox(
            height: _wheelHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final controller = _controllerForViewport(
                  _wheelViewportFraction(
                    viewportWidth: constraints.maxWidth,
                    targetItemWidth: widget.targetItemWidth,
                  ),
                );

                return Stack(
                  children: [
                    PageView.builder(
                      controller: controller,
                      onPageChanged: _handlePageChanged,
                      itemBuilder: (context, page) {
                        final value = _valueForPage(page);
                        return _WheelItem(
                          label: widget.displayLabelFor(value),
                          selected: value == widget.value,
                          selectedMinWidth: widget.selectedMinWidth,
                          unselectedMinWidth: widget.unselectedMinWidth,
                          selectedHorizontalPadding:
                              widget.selectedHorizontalPadding,
                          unselectedHorizontalPadding:
                              widget.unselectedHorizontalPadding,
                          onTap: () => _selectValue(value),
                        );
                      },
                    ),
                    const Positioned.fill(child: _WheelEdgeFades()),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  PageController _controllerForViewport(double viewportFraction) {
    final existing = _controller;
    if (existing != null &&
        !_viewportFractionChanged(_viewportFraction, viewportFraction)) {
      return existing;
    }

    final page = existing?.hasClients == true
        ? (existing?.page?.round() ?? _currentPage)
        : _currentPage;
    existing?.dispose();
    _currentPage = page;
    _viewportFraction = viewportFraction;
    return _controller = PageController(
      initialPage: _currentPage,
      viewportFraction: viewportFraction,
    );
  }

  void _handlePageChanged(int page) {
    _currentPage = page;
    final value = _valueForPage(page);
    if (value == widget.value) return;
    widget.onChanged(value);
  }

  void _selectValue(T value) {
    final controller = _controller;
    final targetPage = _nearestPageForValue(value);
    _currentPage = targetPage;
    if (controller?.hasClients == true) {
      unawaited(
        controller!.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    }
    if (value != widget.value) widget.onChanged(value);
  }

  int _nearestPageForValue(T value) {
    final currentPage = _visiblePage;
    final currentIndex = _indexForPage(currentPage);
    var delta = _wrapIndex(_indexOf(value) - currentIndex);
    if (delta > widget.choices.length / 2) delta -= widget.choices.length;
    return currentPage + delta;
  }

  int get _visiblePage => _controller?.hasClients == true
      ? (_controller?.page?.round() ?? _currentPage)
      : _currentPage;

  T _valueForPage(int page) => widget.choices[_indexForPage(page)];

  T _nextValue(T value) {
    return widget.choices[(_indexOf(value) + 1) % widget.choices.length];
  }

  T _previousValue(T value) {
    return widget.choices[_wrapIndex(_indexOf(value) - 1)];
  }

  int _indexForPage(int page) => _wrapIndex(page);

  int _wrapIndex(int value) {
    final index = value % widget.choices.length;
    return index < 0 ? index + widget.choices.length : index;
  }

  int _indexOf(T value) {
    final index = widget.choices.indexOf(value);
    return index < 0 ? 0 : index;
  }

  int _basePageForValue(T value) =>
      (_initialLoop * widget.choices.length) + _indexOf(value);

  void _resetController() {
    _controller?.dispose();
    _controller = null;
    _viewportFraction = null;
  }
}

double _wheelViewportFraction({
  required double viewportWidth,
  required double targetItemWidth,
}) {
  if (!viewportWidth.isFinite || viewportWidth <= 0) return 1;
  return (targetItemWidth / viewportWidth).clamp(0.08, 0.92);
}

bool _viewportFractionChanged(double? previous, double next) {
  if (previous == null) return true;
  return (previous - next).abs() > 0.001;
}

class _WheelItem extends StatelessWidget {
  const _WheelItem({
    required this.label,
    required this.selected,
    required this.selectedMinWidth,
    required this.unselectedMinWidth,
    required this.selectedHorizontalPadding,
    required this.unselectedHorizontalPadding,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final double selectedMinWidth;
  final double unselectedMinWidth;
  final double selectedHorizontalPadding;
  final double unselectedHorizontalPadding;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final textStyle =
        (selected ? theme.textTheme.titleLarge : theme.textTheme.titleMedium)
            ?.copyWith(
              color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Center(
        child: Material(
          color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: selected ? selectedMinWidth : unselectedMinWidth,
                minHeight: 48,
              ),
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: selected
                          ? selectedHorizontalPadding
                          : unselectedHorizontalPadding,
                    ),
                    child: Text(label, maxLines: 1, style: textStyle),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WheelEdgeFades extends StatelessWidget {
  const _WheelEdgeFades();

  static const _fadeWidth = 56.0;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;

    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: _fadeWidth,
            child: _WheelFade(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              surface: surface,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: _fadeWidth,
            child: _WheelFade(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              surface: surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelFade extends StatelessWidget {
  const _WheelFade({
    required this.begin,
    required this.end,
    required this.surface,
  });

  final AlignmentGeometry begin;
  final AlignmentGeometry end;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: begin,
          end: end,
          stops: const [0.0, 0.55, 1.0],
          colors: [
            surface,
            surface.withValues(alpha: 0.82),
            surface.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}
