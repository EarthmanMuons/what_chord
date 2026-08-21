import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/features/theory/theory.dart';

import 'scale_list_style.dart';

// Shared column metrics so the pinned [ScaleDegreeColumnHeaders] line up with
// the roman and chord columns of each row below.
const double _rowLeftPadding = 12;
const double _romanColumnWidth = 84;
const double _columnGap = 12;

/// "Degree / Chord" column headers for [ScaleDegreeChordList], styled to match
/// the Scales view's section headers so the two panels feel consistent.
class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.8,
    );

    Widget label(String text) => Semantics(
      header: true,
      child: Text(text.toUpperCase(), semanticsLabel: text, style: style),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(_rowLeftPadding, 4, 0, 8),
          child: Row(
            children: [
              SizedBox(width: _romanColumnWidth, child: label('Degree')),
              const SizedBox(width: _columnGap),
              Expanded(child: label('Chord')),
            ],
          ),
        ),
        ScaleListStyle.headerRule(theme.colorScheme),
      ],
    );
  }
}

class ScaleDegreeChordList extends StatelessWidget {
  const ScaleDegreeChordList({
    super.key,
    required this.harmony,
    required this.tonality,
    required this.notation,
    required this.noteNameSystem,
    required this.showSevenths,
    required this.selectedOrdinal,
    required this.onDegreeTap,
    required this.onDegreePlay,
    required this.onDegreeExplore,
  });

  final ScaleHarmony harmony;
  final Tonality tonality;
  final ChordNotationStyle notation;
  final NoteNameSystem noteNameSystem;
  final bool showSevenths;
  final int? selectedOrdinal;
  final ValueChanged<ScaleDegreeHarmony> onDegreeTap;
  final ValueChanged<ScaleDegreeHarmony> onDegreePlay;
  final ValueChanged<ScaleDegreeHarmony> onDegreeExplore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _ColumnHeaders(),
        for (final (index, degree) in harmony.degrees.indexed) ...[
          if (index > 0) ScaleListStyle.rowSeparator(cs),
          _ScaleDegreeChordTile(
            roman: showSevenths ? degree.seventhRoman : degree.triadRoman,
            symbol: _chordSymbol(degree),
            memberNotes: _memberNotes(degree),
            selected: degree.ordinal == selectedOrdinal,
            onTap: () => onDegreeTap(degree),
            onPlay: () => onDegreePlay(degree),
            onExplore: () => onDegreeExplore(degree),
          ),
        ],
      ],
    );
  }

  String _chordSymbol(ScaleDegreeHarmony degree) => scaleDegreeChordSymbol(
    degree: degree,
    showSevenths: showSevenths,
    tonality: tonality,
    notation: notation,
    noteNameSystem: noteNameSystem,
  );

  String _memberNotes(ScaleDegreeHarmony degree) {
    final n = harmony.toneNames.length;
    final root = degree.ordinal - 1;
    final indices = [
      root,
      (root + 2) % n,
      (root + 4) % n,
      if (showSevenths) (root + 6) % n,
    ];
    return [
      for (final index in indices)
        noteDisplayLabel(
          harmony.toneNames[index],
          noteNameSystem: noteNameSystem,
        ),
    ].join(' · ');
  }
}

class _ScaleDegreeChordTile extends StatelessWidget {
  const _ScaleDegreeChordTile({
    required this.roman,
    required this.symbol,
    required this.memberNotes,
    required this.selected,
    required this.onTap,
    required this.onPlay,
    required this.onExplore,
  });

  final String roman;
  final String symbol;
  final String memberNotes;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onPlay;
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: selected ? ScaleListStyle.selectedRow(cs) : Colors.transparent,
      child: SizedBox(
        height: 48,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Semantics(
                button: true,
                selected: selected,
                label: 'Scale degree $roman, $symbol',
                hint: memberNotes,
                onTap: onTap,
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.only(left: _rowLeftPadding),
                    child: Row(
                      children: [
                        SizedBox(
                          width: _romanColumnWidth,
                          // Left-aligned and scaled down only when a long roman
                          // (e.g. the harmonic-minor bIII+maj7#5) would
                          // otherwise wrap, so the symbol column still starts
                          // at a consistent x.
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text.rich(
                              TextSpan(children: scaleDegreeRomanSpans(roman)),
                              maxLines: 1,
                              style: textTheme.titleMedium?.copyWith(
                                color: ScaleListStyle.rowText(
                                  cs,
                                  selected: selected,
                                ),
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: _columnGap),
                        Expanded(
                          child: Text(
                            symbol,
                            style: textTheme.titleLarge?.copyWith(
                              color: ScaleListStyle.rowText(
                                cs,
                                selected: selected,
                              ),
                              fontWeight: selected ? FontWeight.w600 : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (selected)
              IconButton(
                key: const ValueKey('explore'),
                onPressed: onExplore,
                tooltip: 'Explore this chord',
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: Icon(
                  Icons.explore_outlined,
                  color: ScaleListStyle.rowText(cs, selected: true),
                ),
              ),
            IconButton(
              key: const ValueKey('play'),
              onPressed: onPlay,
              tooltip: 'Play chord',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: Icon(Icons.play_arrow, color: cs.primary),
            ),
          ],
        ),
      ),
    );
  }
}
