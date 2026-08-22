import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(
  BuildContext context,
  Uri uri, {
  String failureMessage = 'Could not open link',
}) async {
  final messenger = ScaffoldMessenger.of(context);

  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('launchUrl returned false');
  } catch (_) {
    if (!context.mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(failureMessage)));
  }
}
