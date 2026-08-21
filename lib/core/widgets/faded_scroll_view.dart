import 'package:material_ui/material_ui.dart';

class FadedScrollView extends StatefulWidget {
  const FadedScrollView({
    super.key,
    required this.child,
    this.padding,
    this.fadeColor,
    this.maintainVisualPositionOnResize = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final Color? fadeColor;
  final bool maintainVisualPositionOnResize;

  @override
  State<FadedScrollView> createState() => _FadedScrollViewState();
}

class _FadedScrollViewState extends State<FadedScrollView> {
  static const _fadeHeight = 24.0;

  final ScrollController _controller = ScrollController();
  bool _showTopFade = false;
  bool _showBottomFade = false;
  double? _lastViewportHeight;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFades();
    });
  }

  @override
  void didUpdateWidget(covariant FadedScrollView oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFades();
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_updateFades);
    _controller.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!_controller.hasClients) return;

    final position = _controller.position;
    if (!position.hasContentDimensions) return;

    const epsilon = 0.5;
    final maxExtent = position.maxScrollExtent;
    final pixels = position.pixels;
    final nextTop = maxExtent > epsilon && pixels > epsilon;
    final nextBottom = maxExtent > epsilon && pixels < maxExtent - epsilon;

    if (nextTop == _showTopFade && nextBottom == _showBottomFade) return;

    setState(() {
      _showTopFade = nextTop;
      _showBottomFade = nextBottom;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fadeColor = widget.fadeColor ?? Theme.of(context).colorScheme.surface;

    final stack = Stack(
      children: [
        SingleChildScrollView(
          controller: _controller,
          padding: widget.padding,
          child: widget.child,
        ),
        if (_showTopFade)
          Positioned(
            left: 0,
            top: 0,
            right: 0,
            height: _fadeHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [fadeColor, fadeColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
        if (_showBottomFade)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: _fadeHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [fadeColor, fadeColor.withValues(alpha: 0)],
                  ),
                ),
              ),
            ),
          ),
      ],
    );

    if (!widget.maintainVisualPositionOnResize) return stack;

    return LayoutBuilder(
      builder: (context, constraints) {
        _handleViewportResize(constraints.maxHeight);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _updateFades();
        });
        return stack;
      },
    );
  }

  void _handleViewportResize(double height) {
    if (!height.isFinite) return;

    final previous = _lastViewportHeight;
    _lastViewportHeight = height;

    if (!widget.maintainVisualPositionOnResize || previous == null) return;

    final delta = previous - height;
    if (delta.abs() <= 0.5) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;

      final position = _controller.position;
      if (!position.hasContentDimensions) return;
      if (position.pixels <= 0.5 && delta < 0) return;

      final target = (position.pixels + delta).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if ((target - position.pixels).abs() <= 0.5) return;

      _controller.jumpTo(target);
      _updateFades();
    });
  }
}
