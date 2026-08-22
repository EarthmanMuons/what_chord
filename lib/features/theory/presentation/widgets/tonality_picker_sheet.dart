import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/core/core.dart';

import '../../state/providers/selected_tonality_notifier.dart';
import '../../state/providers/theory_preferences_notifier.dart';
import 'key_signature_staff_preview.dart';

enum TonalityPickerPresentation { bottomSheet, sideSheet }

class TonalityPickerSheet extends ConsumerStatefulWidget {
  const TonalityPickerSheet({
    super.key,
    this.presentation = TonalityPickerPresentation.bottomSheet,
  });

  final TonalityPickerPresentation presentation;

  @override
  ConsumerState<TonalityPickerSheet> createState() =>
      _TonalityPickerSheetState();
}

class _TonalityPickerSheetState extends ConsumerState<TonalityPickerSheet> {
  static const double _headerHeight = 184.0;
  static const double _sideSheetHeaderHeight = 196.0;

  bool? _lastIsLandscape;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSideSheet =
            widget.presentation == TonalityPickerPresentation.sideSheet;
        final isLandscape = isSideSheet
            ? true
            : constraints.maxWidth > constraints.maxHeight;
        final headerHeight = isSideSheet
            ? _sideSheetHeaderHeight
            : _headerHeight;

        final didOrientationChange =
            _lastIsLandscape != null && _lastIsLandscape != isLandscape;
        _lastIsLandscape = isLandscape;

        final mq = MediaQuery.of(context);

        // Always strip left/right for full-width expansion (existing behavior)
        final mqAdjusted = isLandscape
            ? mq.copyWith(
                padding: mq.padding.copyWith(left: 0, right: 0),
                viewPadding: mq.viewPadding.copyWith(left: 0, right: 0),
              )
            : mq;

        final sideSheetContentHeight =
            _sideSheetHeaderHeight +
            (TonalityPickerBody.rowCount * TonalityPickerBody.rowHeight) +
            12.0;
        final bottomSheetHeight = modalBottomSheetMaxHeight(
          context,
          portraitFraction: 0.56,
          landscapeFraction: 0.92,
        );
        final sheetHeight = isSideSheet
            ? sideSheetContentHeight.clamp(0.0, constraints.maxHeight)
            : bottomSheetHeight.clamp(0.0, constraints.maxHeight);

        return MediaQuery(
          data: mqAdjusted,
          child: SafeArea(
            top: false,
            left: !isLandscape && !isSideSheet,
            right: !isLandscape && !isSideSheet,
            child: ColoredBox(
              color: cs.surfaceContainerLow,
              child: SizedBox(
                height: sheetHeight,
                child: TonalityPickerBody(
                  headerHeight: headerHeight,
                  showPanelTitle: true,
                  showCloseButton: isSideSheet,
                  listBottomPadding: isLandscape || isSideSheet ? 0 : 12,
                  recenterSignal: didOrientationChange,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The key-signature picker's header and scrolling key list, shared by the
/// modal sheet presentations and the full Key page.
class TonalityPickerBody extends ConsumerStatefulWidget {
  const TonalityPickerBody({
    super.key,
    this.headerHeight = 144.0,
    this.showPanelTitle = false,
    this.showCloseButton = false,
    this.showStaffPreview = true,
    this.compact = false,
    this.listBottomPadding = 12.0,
    this.recenterSignal = false,
  });

  /// Header height with neither panel title nor staff preview: only the
  /// column labels and their divider.
  static const double slimHeaderHeight = 36.0;

  static const double rowHeight = 62.0;
  static const double compactRowHeight = 52.0;
  static const int rowCount = 15;

  /// Height of the header block (staff preview and column labels, plus the
  /// panel title when [showPanelTitle] is set).
  final double headerHeight;

  final bool showPanelTitle;
  final bool showCloseButton;

  /// Whether the header includes the key-signature staff preview; layouts
  /// that show the staff elsewhere (the Key page in landscape) disable it
  /// and pass [slimHeaderHeight].
  final bool showStaffPreview;

  /// Tighter metrics for height-constrained layouts: shorter rows
  /// ([compactRowHeight]) and full-bleed dividers.
  final bool compact;
  final double listBottomPadding;

  /// Toggling to true re-centers the selected row on the next frame (the
  /// sheet uses this on orientation changes).
  final bool recenterSignal;

  @override
  ConsumerState<TonalityPickerBody> createState() => _TonalityPickerBodyState();
}

class _TonalityPickerBodyState extends ConsumerState<TonalityPickerBody> {
  static const double _chipWidth = 64.0;

  late final ScrollController _controller;
  late final List<KeySignature> _rows;

  double get _rowHeight => widget.compact
      ? TonalityPickerBody.compactRowHeight
      : TonalityPickerBody.rowHeight;

  @override
  void initState() {
    super.initState();

    _rows = _buildOrderedRows();
    assert(_rows.length == TonalityPickerBody.rowCount);
    _controller = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _centerSelectedRow(animated: false);
    });
  }

  @override
  void didUpdateWidget(TonalityPickerBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A compact change alters the row height, invalidating the offset.
    if ((widget.recenterSignal && !oldWidget.recenterSignal) ||
        widget.compact != oldWidget.compact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _centerSelectedRow(animated: false);
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = ref.watch(selectedTonalityProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final selectedKeySignature = selected.keySignature;

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // The rows sit on the sheet's surfaceContainerLow, so blend the shared
    // selection wash over that shade to match the Scale Explorer's selected row.
    final selectedRowBg = SelectionColors.selectedRow(
      cs,
      surface: cs.surfaceContainerLow,
    );

    return Column(
      children: [
        _TonalityPickerHeader(
          height: widget.headerHeight,
          chipWidth: _chipWidth,
          keySignature: selectedKeySignature,
          showPanelTitle: widget.showPanelTitle,
          showCloseButton: widget.showCloseButton,
          showStaffPreview: widget.showStaffPreview,
          fullBleedDivider: widget.compact,
          backgroundColor: cs.surfaceContainerLow,
        ),
        Expanded(
          child: ListView.builder(
            controller: _controller,
            itemExtent: _rowHeight,
            padding: EdgeInsets.only(bottom: widget.listBottomPadding),
            itemCount: _rows.length,
            itemBuilder: (context, index) {
              final row = _rows[index];
              final major = row.relativeMajor;
              final minor = row.relativeMinor;

              final rowSelected = selected == major || selected == minor;
              final majorSelected = selected == major;
              final minorSelected = selected == minor;

              return DecoratedBox(
                decoration: BoxDecoration(
                  color: rowSelected ? selectedRowBg : Colors.transparent,
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                row.label,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: rowSelected
                                      ? SelectionColors.selectedRowText(cs)
                                      : cs.onSurfaceVariant,
                                  fontWeight: rowSelected
                                      ? FontWeight.w600
                                      : null,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: _chipWidth,
                              child: Align(
                                alignment: Alignment.center,
                                child: _TonalityChoiceChip(
                                  label: _tonalityDisplayLabel(
                                    major,
                                    noteNameSystem,
                                  ),
                                  semanticsLabel: _tonalitySemanticsLabel(
                                    major,
                                    noteNameSystem,
                                  ),
                                  selected: majorSelected,
                                  onTap: () => _selectTonality(major),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: _chipWidth,
                              child: Align(
                                alignment: Alignment.center,
                                child: _TonalityChoiceChip(
                                  label: _tonalityDisplayLabel(
                                    minor,
                                    noteNameSystem,
                                  ),
                                  semanticsLabel: _tonalitySemanticsLabel(
                                    minor,
                                    noteNameSystem,
                                  ),
                                  selected: minorSelected,
                                  onTap: () => _selectTonality(minor),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (index < _rows.length - 1)
                      Padding(
                        padding: widget.compact
                            ? EdgeInsets.zero
                            : const EdgeInsets.symmetric(horizontal: 16),
                        child: const Divider(height: 1),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  List<KeySignature> _buildOrderedRows() {
    KeySignature rowFor(int acc) =>
        keySignatures.firstWhere((r) => r.accidentalCount == acc);

    return <KeySignature>[
      for (var n = 7; n >= 1; n--) rowFor(n), // 7# … 1#
      rowFor(0), // 0
      for (var n = 1; n <= 7; n++) rowFor(-n), // 1b … 7b
    ];
  }

  int _indexForSelected(Tonality selected) {
    final i = _rows.indexWhere(
      (row) => row.relativeMajor == selected || row.relativeMinor == selected,
    );
    if (i >= 0) return i;

    // Fallback: center around 0 accidentals if something unexpected happens.
    return _rows.indexWhere((row) => row.accidentalCount == 0);
  }

  void _centerSelectedRow({required bool animated}) {
    if (!_controller.hasClients) return;

    final selected = ref.read(selectedTonalityProvider);
    final viewport = _controller.position.viewportDimension;

    final index = _indexForSelected(selected);

    final target = (index * _rowHeight) - (viewport / 2) + (_rowHeight / 2);

    final clamped = target.clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );

    if (!animated) {
      _controller.jumpTo(clamped);
      return;
    }

    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    if (disableAnimations) {
      _controller.jumpTo(clamped);
      return;
    }

    unawaited(
      _controller.animateTo(
        clamped,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _selectTonality(Tonality tonality) {
    unawaited(
      ref.read(selectedTonalityProvider.notifier).setTonality(tonality),
    );

    // Recenter after selection so the choice stays visually anchored.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _centerSelectedRow(animated: true);
    });
  }
}

String _tonalityDisplayLabel(Tonality tonality, NoteNameSystem noteNameSystem) {
  return tonalityTonicLabel(tonality, noteNameSystem: noteNameSystem);
}

String _tonalitySemanticsLabel(
  Tonality tonality,
  NoteNameSystem noteNameSystem,
) {
  return tonalitySemanticLabel(tonality, noteNameSystem: noteNameSystem);
}

class _TonalityPickerHeader extends StatelessWidget {
  final double height;
  final double chipWidth;
  final KeySignature keySignature;
  final bool showPanelTitle;
  final bool showCloseButton;
  final bool showStaffPreview;
  final bool fullBleedDivider;
  final Color backgroundColor;

  const _TonalityPickerHeader({
    required this.height,
    required this.chipWidth,
    required this.keySignature,
    required this.showPanelTitle,
    required this.showCloseButton,
    required this.showStaffPreview,
    required this.fullBleedDivider,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    final headerStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
    );
    return SizedBox(
      height: height,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          children: [
            if (showPanelTitle)
              ModalPanelHeader(
                title: 'Key Signature',
                showCloseButton: showCloseButton,
              ),
            if (showStaffPreview)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Center(
                  child: KeySignatureStaffPreview(keySignature: keySignature),
                ),
              ),
            Expanded(
              child: ColoredBox(
                color: backgroundColor,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          header: true,
                          child: Text('Accidentals', style: headerStyle),
                        ),
                      ),
                      SizedBox(
                        width: chipWidth,
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Major',
                            textAlign: TextAlign.center,
                            style: headerStyle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: chipWidth,
                        child: Semantics(
                          header: true,
                          child: Text(
                            'Minor',
                            textAlign: TextAlign.center,
                            style: headerStyle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            ColoredBox(
              color: backgroundColor,
              child: Padding(
                padding: fullBleedDivider
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: 16),
                child: const Divider(height: 1, thickness: 2),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TonalityChoiceChip extends StatelessWidget {
  final String label;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onTap;

  const _TonalityChoiceChip({
    required this.label,
    required this.semanticsLabel,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Highlight the active mode like a filled active note chip: a
    // primaryContainer fill behind onPrimaryContainer bold text, ringed by the
    // primary accent. Unselected chips fall back to the resting note-chip look.
    final side = selected
        ? SelectionColors.selectedChipBorder(cs)
        : SelectionColors.restChipBorder(cs);

    return ChoiceChip(
      label: SizedBox(
        width: 44,
        child: Text(
          label,
          semanticsLabel: semanticsLabel,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: selected ? cs.onPrimaryContainer : cs.onSurface,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      showCheckmark: false,
      // The rows are painted surfaceContainerLow, so fill the unselected chips a
      // shade lighter than the row (rather than the shared note-chip fill, which
      // assumes a darker parent) so each button reads as its own element.
      backgroundColor: cs.surfaceContainerLowest,
      selectedColor: cs.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: side,
      ),
    );
  }
}
