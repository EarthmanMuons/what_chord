import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/theory/theory.dart';

/// Scroll-safe secondary analysis region: polychord first, alternatives next.
class AnalysisSecondaryResults extends ConsumerStatefulWidget {
  const AnalysisSecondaryResults({
    super.key,
    required this.alignment,
    required this.textAlign,
    required this.alternativeGap,
    required this.textScaleMultiplier,
    required this.tappableWhenAlternativesEmpty,
    required this.onAlternativesTap,
    this.alternativePadding = EdgeInsets.zero,
    this.showScrollbarWhenOverflow = false,
  });

  final Alignment alignment;
  final TextAlign textAlign;
  final double alternativeGap;
  final double textScaleMultiplier;
  final bool tappableWhenAlternativesEmpty;
  final VoidCallback onAlternativesTap;
  final EdgeInsets alternativePadding;
  final bool showScrollbarWhenOverflow;

  @override
  ConsumerState<AnalysisSecondaryResults> createState() =>
      _AnalysisSecondaryResultsState();
}

class _AnalysisSecondaryResultsState
    extends ConsumerState<AnalysisSecondaryResults> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final polychord = ref.watch(polychordPresentationProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final wrapAlignment = switch (widget.alignment) {
      Alignment.topLeft ||
      Alignment.centerLeft ||
      Alignment.bottomLeft => WrapAlignment.start,
      Alignment.topRight ||
      Alignment.centerRight ||
      Alignment.bottomRight => WrapAlignment.end,
      _ => WrapAlignment.center,
    };

    final scrollView = SingleChildScrollView(
      controller: _scrollController,
      primary: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (polychord != null) ...[
            Align(
              alignment: widget.alignment,
              child: PolychordAnnotation(
                presentation: polychord,
                noteNameSystem: noteNameSystem,
                alignment: wrapAlignment,
                textAlign: widget.textAlign,
                textScaleMultiplier: widget.textScaleMultiplier,
              ),
            ),
            const SizedBox(height: 12),
          ],
          AlternativeChordCandidatesList(
            enabled: true,
            alignment: widget.alignment,
            textAlign: widget.textAlign,
            gap: widget.alternativeGap,
            padding: widget.alternativePadding,
            textScaleMultiplier: widget.textScaleMultiplier,
            tappableWhenEmpty: widget.tappableWhenAlternativesEmpty,
            onTap: widget.onAlternativesTap,
          ),
        ],
      ),
    );

    if (!widget.showScrollbarWhenOverflow) return scrollView;
    return Scrollbar(
      controller: _scrollController,
      thumbVisibility: true,
      child: scrollView,
    );
  }
}
