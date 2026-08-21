import 'package:material_ui/material_ui.dart';

class ModalPanelHeader extends StatelessWidget {
  const ModalPanelHeader({
    super.key,
    required this.title,
    this.showCloseButton = false,
    this.onClose,
  });

  final String title;
  final bool showCloseButton;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final effectiveHeight = showCloseButton ? 52.0 : 40.0;
    final effectivePadding = EdgeInsets.only(
      left: 16,
      top: showCloseButton ? 10 : 0,
      right: showCloseButton ? 12 : 16,
      bottom: showCloseButton ? 6 : 0,
    );

    return SizedBox(
      height: effectiveHeight,
      child: Padding(
        padding: effectivePadding,
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            if (showCloseButton)
              IconButton(
                tooltip: 'Close',
                onPressed: onClose ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }
}
