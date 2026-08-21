import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';

import '../models/home_layout_config.dart';

bool useHomeSideSheet(BuildContext context) {
  final sizeClass = homeSizeClassForSize(MediaQuery.sizeOf(context));
  return sizeClass != HomeSizeClass.compact;
}

Future<T?> showHomeSideSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  String barrierLabel = 'Dismiss',
}) {
  final sizeClass = homeSizeClassForSize(MediaQuery.sizeOf(context));
  final config = homeSideSheetConfigForSizeClass(sizeClass);

  return showAdaptiveSideSheet<T>(
    context: context,
    barrierLabel: barrierLabel,
    dismissibleKey: 'home_side_sheet',
    config: AdaptiveSideSheetConfig(
      widthFactor: config.widthFactor,
      minWidth: config.minWidth,
      maxWidth: config.maxWidth,
      portraitHeightFactor: config.portraitHeightFactor,
      landscapeHeightFactor: config.landscapeHeightFactor,
      minHeight: config.minHeight,
      verticalMargin: config.verticalMargin,
    ),
    builder: builder,
  );
}
