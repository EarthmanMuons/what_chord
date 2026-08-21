import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Rotates a switcher child around its horizontal axis, as if a compact chip
/// were flipping to reveal its next label.
class ChipFlipTransition extends StatelessWidget {
  const ChipFlipTransition({
    super.key,
    required this.animation,
    required this.incoming,
    required this.child,
  });

  final Animation<double> animation;
  final bool incoming;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final value = animation.value;
        final angle = (incoming ? 1 - value : value - 1) * (math.pi / 2);

        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle),
          child: child,
        );
      },
    );
  }
}

/// Sizes an [AnimatedSwitcher] from its current child while keeping outgoing
/// children centered within that footprint during their transitions.
class CurrentSizeSwitcherLayout extends StatelessWidget {
  const CurrentSizeSwitcherLayout({
    super.key,
    required this.currentChild,
    required this.previousChildren,
  });

  final Widget? currentChild;
  final List<Widget> previousChildren;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.hardEdge,
      children: [
        for (final child in previousChildren)
          Positioned.fill(
            child: Align(alignment: Alignment.center, child: child),
          ),
        ?currentChild,
      ],
    );
  }
}
