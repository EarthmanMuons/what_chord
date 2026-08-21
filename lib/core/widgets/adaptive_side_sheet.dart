import 'dart:ui';

import 'package:material_ui/material_ui.dart';

@immutable
class AdaptiveSideSheetConfig {
  final double widthFactor;
  final double minWidth;
  final double maxWidth;
  final double portraitHeightFactor;
  final double landscapeHeightFactor;
  final double minHeight;
  final double verticalMargin;

  const AdaptiveSideSheetConfig({
    required this.widthFactor,
    required this.minWidth,
    required this.maxWidth,
    required this.portraitHeightFactor,
    required this.landscapeHeightFactor,
    required this.minHeight,
    required this.verticalMargin,
  });
}

Future<T?> showAdaptiveSideSheet<T>({
  required BuildContext context,
  required AdaptiveSideSheetConfig config,
  required WidgetBuilder builder,
  String barrierLabel = 'Dismiss',
  String dismissibleKey = 'adaptive_side_sheet',
}) {
  final mq = MediaQuery.of(context);
  final isPortrait = mq.size.height >= mq.size.width;
  final width = clampDouble(
    mq.size.width * config.widthFactor,
    config.minWidth,
    config.maxWidth,
  );
  final effectiveHeightFactor = isPortrait
      ? config.portraitHeightFactor
      : config.landscapeHeightFactor;
  final maxHeight = clampDouble(
    mq.size.height * effectiveHeightFactor,
    config.minHeight,
    mq.size.height,
  );

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, _, _) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: config.verticalMargin),
        child: SafeArea(
          left: false,
          child: Align(
            alignment: Alignment.centerRight,
            child: Dismissible(
              key: ValueKey(dismissibleKey),
              direction: DismissDirection.startToEnd,
              dismissThresholds: const {DismissDirection.startToEnd: 0.22},
              resizeDuration: null,
              onDismissed: (_) => Navigator.of(context).maybePop(),
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                elevation: 2,
                clipBehavior: Clip.antiAlias,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    left: Radius.circular(20),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: config.minHeight,
                    maxHeight: maxHeight,
                  ),
                  child: SizedBox(width: width, child: builder(context)),
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
  );
}
