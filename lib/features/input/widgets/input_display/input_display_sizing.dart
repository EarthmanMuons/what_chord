import 'package:material_ui/material_ui.dart';

class InputDisplaySizing {
  const InputDisplaySizing._();

  static double textScale(BuildContext context) {
    return MediaQuery.textScalerOf(context).scale(1.0);
  }

  static double pedalScale(
    BuildContext context, {
    double visualScaleMultiplier = 1.0,
  }) {
    return _scale(
      context,
      weight: 0.4,
      max: 1.45,
      visualScaleMultiplier: visualScaleMultiplier,
    );
  }

  static double noteScale(
    BuildContext context, {
    double visualScaleMultiplier = 1.0,
  }) {
    return _scale(
      context,
      weight: 0.35,
      max: 1.35,
      visualScaleMultiplier: visualScaleMultiplier,
    );
  }

  static double noteVerticalScale(
    BuildContext context, {
    double visualScaleMultiplier = 1.0,
  }) {
    return _scale(
      context,
      weight: 0.55,
      max: 1.95,
      visualScaleMultiplier: visualScaleMultiplier,
    );
  }

  static double rowHeightScale(
    BuildContext context, {
    double visualScaleMultiplier = 1.0,
  }) {
    final base = _scale(
      context,
      weight: 0.7,
      max: 2.0,
      visualScaleMultiplier: visualScaleMultiplier,
    );
    final vertical = noteVerticalScale(
      context,
      visualScaleMultiplier: visualScaleMultiplier,
    );
    return base > vertical ? base : vertical;
  }

  static double _scale(
    BuildContext context, {
    required double weight,
    required double max,
    double visualScaleMultiplier = 1.0,
  }) {
    final a11yScale = 1.0 + (textScale(context) - 1.0) * weight;
    final scale = a11yScale * visualScaleMultiplier;
    return scale.clamp(1.0, max);
  }
}
