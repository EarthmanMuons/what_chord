import 'package:material_ui/material_ui.dart';

const double kLandscapeBottomSheetHeightFraction = 0.75;

double modalBottomSheetMaxHeight(
  BuildContext context, {
  double portraitFraction = 0.72,
  double landscapeFraction = kLandscapeBottomSheetHeightFraction,
}) {
  final size = MediaQuery.sizeOf(context);
  final isLandscape = size.width > size.height;
  final heightFraction = isLandscape ? landscapeFraction : portraitFraction;
  return size.height * heightFraction;
}
