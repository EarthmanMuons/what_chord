import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../providers/lookup_mode_notifier.dart';

/// Manual chord-lookup pad. Replaces the keyboard while lookup mode is active.
///
/// Two rows of buttons: the five accidentals on top and the seven naturals
/// below, offset by half a button so each accidental sits between its
/// neighboring naturals (like a keyboard). Tapping adds a note (repeats
/// allowed); the first note added is the bass. Note names follow the current
/// key.
class LookupPad extends ConsumerWidget {
  const LookupPad({super.key});

  // (x position in button-widths, pitch class).
  static const List<(double, int)> _naturals = [
    (0, 0),
    (1, 2),
    (2, 4),
    (3, 5),
    (4, 7),
    (5, 9),
    (6, 11),
  ];
  static const List<(double, int)> _accidentals = [
    (0.5, 1),
    (1.5, 3),
    (3.5, 6),
    (4.5, 8),
    (5.5, 10),
  ];

  static const double minTapTarget = 48;

  // Each button carries a 2px inset on every side, so adjacent buttons (rows
  // and columns alike) sit a consistent 4px apart. The cell is the button plus
  // its inset; rows grow with available height between the 48px tap-target
  // floor and a cap so they do not balloon to fill the whole section.
  static const double _minCellHeight = minTapTarget + 4;
  // Cap high enough that rows fill the (limited) available height on phones
  // rather than centering with a gap; the keyboard's 200px ceiling and the
  // bottom safe-area inset are the real limiters.
  static const double _maxCellHeight = 120;
  static const double _actionWidth = minTapTarget + 4;

  // Soft top shadow so the pad reads as a raised panel and adds a little
  // thickness to the separator as it slides down over the keyboard.
  static const double _topShadowHeight = 10;
  static const double _topShadowOpacity = 0.12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final pcs = ref.watch(lookupModeProvider.select((s) => s.pitchClasses));
    final names = ref.watch(pitchClassNamesProvider);
    final notifier = ref.read(lookupModeProvider.notifier);

    final counts = <int, int>{};
    for (final pc in pcs) {
      counts[pc] = (counts[pc] ?? 0) + 1;
    }
    final bassPc = pcs.isEmpty ? null : pcs.first;

    String labelFor(int pc) =>
        noteDisplayLabel(normalizeNoteNameToAscii(names[pc]));

    // Keep the buttons clear of the screen's safe areas (home indicator and
    // bottom rounded corners, plus side cutouts in landscape where the section
    // is full-bleed). The gray panel still draws edge-to-edge; only the buttons
    // inset. The bottom inset already provides its margin, so don't stack an
    // extra one on top of it.
    final safeArea = MediaQuery.paddingOf(context);
    final bottomPadding = safeArea.bottom > 8 ? safeArea.bottom : 8.0;
    // Symmetric side inset (largest cutout applied to both sides) to match the
    // app bar and tonality bar.
    final sideInset =
        8 + (safeArea.left > safeArea.right ? safeArea.left : safeArea.right);

    return ColoredBox(
      color: cs.surfaceContainerLow,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              sideInset,
              6,
              sideInset,
              bottomPadding,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Rows grow with available height (capped), vertically
                // centered; shrink below the floor only if the slot is too
                // short to fit them.
                final cellHeight = (constraints.maxHeight / 2).clamp(
                  _minCellHeight,
                  _maxCellHeight,
                );
                final blockHeight = (cellHeight * 2).clamp(
                  0.0,
                  constraints.maxHeight,
                );
                final rowHeight = blockHeight / 2;
                final gridWidth = constraints.maxWidth - _actionWidth - 8;
                final buttonWidth = gridWidth / _naturals.length;

                Widget rowOf(List<(double, int)> keys) => SizedBox(
                  height: rowHeight,
                  child: Stack(
                    children: [
                      for (final (x, pc) in keys)
                        Positioned(
                          left: x * buttonWidth,
                          top: 0,
                          bottom: 0,
                          width: buttonWidth,
                          child: _NoteButton(
                            label: labelFor(pc),
                            count: counts[pc] ?? 0,
                            isBass: pc == bassPc,
                            onTap: () => notifier.addNote(pc),
                          ),
                        ),
                    ],
                  ),
                );

                final naturals = rowOf(_naturals);
                final accidentals = rowOf(_accidentals);

                return Center(
                  child: SizedBox(
                    height: blockHeight,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [accidentals, naturals],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _PadActions(
                          enabled: pcs.isNotEmpty,
                          onUndo: notifier.removeLast,
                          onClear: notifier.clear,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          // A line matching the separator above (so it reads as a slightly
          // thicker divider once the pad slides down) plus a soft shadow so the
          // pad reads as a raised panel.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Divider(height: 1),
                  Container(
                    height: _topShadowHeight,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: _topShadowOpacity),
                          Colors.black.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteButton extends StatelessWidget {
  const _NoteButton({
    required this.label,
    required this.count,
    required this.isBass,
    required this.onTap,
  });

  final String label;

  /// How many times this pitch class is in the selection (0 if unselected).
  final int count;
  final bool isBass;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = count > 0;

    final Color bg;
    final Color fg;
    final BorderSide side;
    if (isBass) {
      bg = cs.primary;
      fg = cs.onPrimary;
      side = BorderSide.none;
    } else if (selected) {
      bg = cs.primaryContainer;
      fg = cs.onPrimaryContainer;
      side = SelectionColors.selectedChipBorder(cs);
    } else {
      bg = cs.surfaceContainerLowest;
      fg = cs.onSurface;
      side = SelectionColors.restChipBorder(cs);
    }

    final semanticLabel = isBass
        ? '$label, bass'
        : count > 1
        ? '$label, added $count times'
        : selected
        ? '$label, selected'
        : label;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: true,
        selected: selected,
        label: semanticLabel,
        onTap: onTap,
        excludeSemantics: true,
        child: Material(
          color: bg,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: side,
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (count > 1)
                  Positioned(
                    top: 3,
                    right: 4,
                    child: Text(
                      '×$count',
                      style: TextStyle(
                        color: fg.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PadActions extends StatelessWidget {
  const _PadActions({
    required this.enabled,
    required this.onUndo,
    required this.onClear,
  });

  final bool enabled;
  final VoidCallback onUndo;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String tooltip, VoidCallback onPressed) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Tooltip(
            message: tooltip,
            child: OutlinedButton(
              onPressed: enabled ? onPressed : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size.square(LookupPad.minTapTarget),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Icon(icon, size: 20, semanticLabel: tooltip),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: LookupPad.minTapTarget + 4,
      child: Column(
        children: [
          action(Icons.backspace_outlined, 'Undo', onUndo),
          action(Icons.clear, 'Clear', onClear),
        ],
      ),
    );
  }
}
