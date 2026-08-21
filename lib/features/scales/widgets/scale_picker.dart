import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';

import '../models/scale_menu.dart';
import 'scale_list_style.dart';

class ScalePicker extends StatelessWidget {
  const ScalePicker({
    super.key,
    required this.selected,
    required this.scrollable,
    required this.onChanged,
  });

  final ScaleMenuEntry selected;
  final bool scrollable;
  final ValueChanged<ScaleMenuEntry> onChanged;

  @override
  Widget build(BuildContext context) {
    return PickerList<ScaleMenuEntry>(
      entries: [
        for (final (sectionIndex, section) in ScaleSection.values.indexed) ...[
          PickerListHeader<ScaleMenuEntry>(
            section.title,
            extent: sectionIndex == 0 ? 30 : null,
          ),
          for (final entry in scaleMenuEntries.where(
            (entry) => entry.section == section,
          ))
            PickerListItem(entry),
        ],
      ],
      selected: selected,
      itemExtent: 48,
      headerExtent: 44,
      scrollable: scrollable,
      onChanged: onChanged,
      itemBuilder: (context, entry, isSelected) => _ScaleKindRow(
        label: entry.label,
        selected: isSelected,
        showSeparator: !_lastInSection.contains(entry),
      ),
      headerBuilder: (context, title) {
        final cs = Theme.of(context).colorScheme;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 16, 8),
              child: Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            ScaleListStyle.headerRule(cs),
          ],
        );
      },
    );
  }
}

final Set<ScaleMenuEntry> _lastInSection = {
  for (final section in ScaleSection.values)
    scaleMenuEntries.lastWhere((entry) => entry.section == section),
};

class _ScaleKindRow extends StatelessWidget {
  const _ScaleKindRow({
    required this.label,
    required this.selected,
    required this.showSeparator,
  });

  final String label;
  final bool selected;
  final bool showSeparator;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? ScaleListStyle.selectedRow(cs) : null,
        border: showSeparator
            ? Border(bottom: ScaleListStyle.separatorSide(cs))
            : null,
      ),
      child: Center(
        child: Text(
          label,
          style: textTheme.titleMedium?.copyWith(
            color: ScaleListStyle.rowText(cs, selected: selected),
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
