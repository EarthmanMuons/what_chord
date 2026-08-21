import 'package:material_ui/material_ui.dart';

class SubsectionLabel extends StatelessWidget {
  const SubsectionLabel({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Semantics(
        header: true,
        child: Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(color: cs.onSurface),
        ),
      ),
    );
  }
}
