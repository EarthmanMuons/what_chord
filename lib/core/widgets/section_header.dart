import 'package:material_ui/material_ui.dart';

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.icon});

  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final style = theme.textTheme.labelLarge?.copyWith(
      color: cs.onSurfaceVariant,
      letterSpacing: 0.8,
    );

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Row(
        children: [
          if (icon != null) ...[
            ExcludeSemantics(
              child: Icon(icon, size: 20, color: cs.onSurfaceVariant),
            ),
            const SizedBox(width: 10),
          ],
          Semantics(
            header: true,
            child: Text(title.toUpperCase(), style: style),
          ),
        ],
      ),
    );
  }
}
