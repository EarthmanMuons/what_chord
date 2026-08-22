import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';

import 'faded_scroll_view.dart';

/// One selectable line in a [showCopyChoiceDialog], pairing a labeled value with
/// the icon and short name used when confirming the copy.
class CopyChoice {
  const CopyChoice({
    required this.title,
    required this.icon,
    required this.value,
    required this.copiedLabel,
  });

  final String title;
  final IconData icon;
  final String value;
  final String copiedLabel;
}

/// Shared "Copy" picker used wherever a surface offers several texts to copy
/// (e.g. a chord summary or a scale header), so the list, clipboard handling,
/// and confirmation all look and behave the same.
Future<void> showCopyChoiceDialog(
  BuildContext context, {
  required List<CopyChoice> choices,
}) async {
  final choice = await showDialog<CopyChoice>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Copy'),
        titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(0, 8, 0, 0),
        actionsPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        content: FadedScrollView(
          fadeColor: Theme.of(dialogContext).colorScheme.surfaceContainerHigh,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final choice in choices)
                ListTile(
                  leading: Icon(choice.icon),
                  title: Text(choice.title),
                  subtitle: Text(choice.value),
                  trailing: const Icon(Icons.copy),
                  onTap: () => Navigator.of(dialogContext).pop(choice),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    },
  );
  if (choice == null || !context.mounted) return;

  // iOS gives no system confirmation for clipboard writes, so surface one;
  // Android already shows its own, so avoid a duplicate there.
  final messenger = Theme.of(context).platform == TargetPlatform.iOS
      ? ScaffoldMessenger.maybeOf(context)
      : null;

  await Clipboard.setData(ClipboardData(text: choice.value));

  messenger?.hideCurrentSnackBar();
  messenger?.showSnackBar(
    SnackBar(content: Text('Copied ${choice.copiedLabel} to clipboard')),
  );
}
