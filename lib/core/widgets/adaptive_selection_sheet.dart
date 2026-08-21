import 'package:material_ui/material_ui.dart';

import 'modal_panel_header.dart';
import 'modal_sheet_sizing.dart';

/// Shows a picker as a bottom sheet on compact screens and a dialog otherwise.
Future<T?> showAdaptiveSelectionSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  required String title,
}) {
  final panelColor = Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFF151515)
      : const Color(0xFFF4F4F4);

  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  final isCompact = shortestSide < 600;

  if (isCompact) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: panelColor,
      builder: (context) {
        final mq = MediaQuery.of(context);
        final isLandscape = mq.size.width > mq.size.height;
        final maxSheetHeight = modalBottomSheetMaxHeight(context);

        return ColoredBox(
          color: panelColor,
          child: SafeArea(
            top: false,
            left: !isLandscape,
            right: !isLandscape,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxSheetHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ModalPanelHeader(title: title),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Divider(height: 1),
                  ),
                  Flexible(child: builder(context)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  final maxDialogHeight = MediaQuery.sizeOf(context).height * 0.72;

  return showDialog<T>(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 440,
            maxHeight: maxDialogHeight,
          ),
          child: Material(
            color: panelColor,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ModalPanelHeader(title: title, showCloseButton: true),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Divider(height: 1),
                ),
                Flexible(child: builder(context)),
              ],
            ),
          ),
        ),
      );
    },
  );
}
