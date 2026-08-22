import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/input_pedal_state.dart';
import '../../providers/pedal_state_provider.dart';
import 'input_display_sizing.dart';

class PedalIndicator extends ConsumerStatefulWidget {
  const PedalIndicator({super.key, this.visualScaleMultiplier = 1.0});

  final double visualScaleMultiplier;

  static const double slotWidth = 36;
  static const double glyphSize = 32;
  static const Offset opticalOffset = Offset(0, -3);
  static const double _pressedBaselineNudge = 2.0;

  static double sizeScaleFor(
    BuildContext context, {
    double visualScaleMultiplier = 1.0,
  }) {
    return InputDisplaySizing.pedalScale(
      context,
      visualScaleMultiplier: visualScaleMultiplier,
    );
  }

  static double slotWidthFor(
    BuildContext context, {
    double visualScaleMultiplier = 1.0,
  }) {
    final scaled =
        slotWidth *
        sizeScaleFor(context, visualScaleMultiplier: visualScaleMultiplier);
    return scaled < 48.0 ? 48.0 : scaled;
  }

  static double glyphSizeFor(
    BuildContext context, {
    double visualScaleMultiplier = 1.0,
  }) {
    return glyphSize *
        sizeScaleFor(context, visualScaleMultiplier: visualScaleMultiplier);
  }

  @override
  ConsumerState<PedalIndicator> createState() => _PedalIndicatorState();
}

class _PedalIndicatorState extends ConsumerState<PedalIndicator> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sizeScale = PedalIndicator.sizeScaleFor(
      context,
      visualScaleMultiplier: widget.visualScaleMultiplier,
    );
    final slotWidth = PedalIndicator.slotWidthFor(
      context,
      visualScaleMultiplier: widget.visualScaleMultiplier,
    );
    final glyphSize = PedalIndicator.glyphSizeFor(
      context,
      visualScaleMultiplier: widget.visualScaleMultiplier,
    );
    final pedal = ref.watch(inputPedalStateProvider);
    final isDown = pedal.isDown;
    final source = pedal.source;

    final showManualRing = isDown && source == InputPedalSource.touch;

    final tooltip = isDown
        ? 'Sustain pedal held. Tap to toggle.'
        : 'Sustain pedal. Tap to toggle.';

    final opticalOffset = Offset(
      PedalIndicator.opticalOffset.dx,
      (PedalIndicator.opticalOffset.dy * sizeScale) +
          (isDown ? PedalIndicator._pressedBaselineNudge * sizeScale : 0.0),
    );

    final basePad = EdgeInsets.symmetric(
      horizontal: 4 * sizeScale,
      vertical: 6 * sizeScale,
    );
    final pressPad = _pressed
        ? EdgeInsets.symmetric(
            horizontal: 6 * sizeScale,
            vertical: 7 * sizeScale,
          )
        : basePad;

    final ringColor = cs.outlineVariant.withValues(alpha: 0.78);

    return Semantics(
      label: tooltip,
      toggled: isDown,
      button: true,
      onTapHint: 'Toggle sustain pedal',
      child: Tooltip(
        message: tooltip,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onHighlightChanged: (v) => setState(() => _pressed = v),
            onTap: () => ref.read(inputPedalControllerProvider).toggle(),
            child: SizedBox(
              width: slotWidth,
              height: double.infinity,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: showManualRing
                      ? Border.all(color: ringColor, width: 1.0)
                      : null,
                ),
                child: AnimatedPadding(
                  duration: const Duration(milliseconds: 90),
                  curve: Curves.easeOutCubic,
                  padding: pressPad,
                  child: Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: opticalOffset,
                      child: SvgPicture.asset(
                        'assets/glyphs/keyboard_pedal_ped.svg',
                        width: glyphSize,
                        height: glyphSize,
                        alignment: Alignment.center,
                        colorFilter: ColorFilter.mode(
                          cs.onSurfaceVariant,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
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
