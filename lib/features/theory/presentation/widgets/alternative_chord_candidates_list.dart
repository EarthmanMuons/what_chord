import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import '../../state/providers/analysis_context_provider.dart';
import '../../state/providers/displayed_chord_provider.dart';
import '../../state/providers/theory_preferences_notifier.dart';

class AlternativeChordCandidatesList extends ConsumerStatefulWidget {
  const AlternativeChordCandidatesList({
    super.key,
    this.enabled = true,
    this.axis = Axis.vertical,
    this.maxItems = 3,
    this.padding = EdgeInsets.zero,
    this.gap = 4.0,
    this.alignment = Alignment.center,
    this.textAlign = TextAlign.center,
    this.styleOverride,
    this.textScaleMultiplier = 1.0,
    this.showScrollbarWhenOverflow = false,
    this.tappableWhenEmpty = false,
    this.onTap,
  });

  final bool enabled;
  final Axis axis;
  final int maxItems;
  final EdgeInsets padding;
  final double gap;
  final Alignment alignment;
  final TextAlign textAlign;
  final TextStyle? styleOverride;
  final double textScaleMultiplier;
  final bool showScrollbarWhenOverflow;

  /// When true, the tap gesture and a minimum-height hit area remain active
  /// even when there are no alternatives to display.
  final bool tappableWhenEmpty;
  final VoidCallback? onTap;

  @override
  ConsumerState<AlternativeChordCandidatesList> createState() =>
      _AlternativeChordCandidatesListState();
}

class _AlternativeChordCandidatesListState
    extends ConsumerState<AlternativeChordCandidatesList> {
  late final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final alternatives = widget.enabled
        ? ref.watch(displayedAlternativeCandidatesProvider)
        : const [];

    final tonality = ref.watch(
      analysisContextProvider.select((c) => c.tonality),
    );
    final notation = ref.watch(chordNotationStyleProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);

    final base =
        widget.styleOverride ??
        theme.textTheme.bodyMedium ??
        const TextStyle(fontSize: 14);
    final scale = widget.textScaleMultiplier.clamp(1.0, 1.5);
    final textStyle = base.copyWith(
      fontSize: ((base.fontSize ?? 14) + 4) * scale,
      fontWeight: FontWeight.w700,
      color: cs.onSurface.withValues(alpha: 0.45),
      height: 1.18,
    );

    final visible = alternatives.take(widget.maxItems).toList(growable: false);
    final hasContent = widget.enabled && visible.isNotEmpty;

    Widget content() {
      final list = ListView.separated(
        key: const ValueKey(
          'ambiguous_list',
        ), // stable key for the "present" state
        primary: false,
        padding: widget.padding,
        shrinkWrap:
            !(widget.axis == Axis.vertical && widget.showScrollbarWhenOverflow),
        controller: _scrollController,
        scrollDirection: widget.axis,
        itemCount: visible.length,
        separatorBuilder: (_, _) => widget.axis == Axis.vertical
            ? SizedBox(height: widget.gap)
            : SizedBox(width: widget.gap),
        itemBuilder: (context, i) {
          final c = visible[i];
          final symbol = ChordSymbolBuilder.fromIdentity(
            identity: c.identity,
            tonality: tonality,
            notation: notation,
          );
          final spokenLabel = ChordLongFormFormatter.format(
            identity: c.identity,
            tonality: tonality,
            noteNameSystem: noteNameSystem,
            accidentalStyle: ChordLongFormAccidentalStyle.plainText,
          );

          return Text(
            chordSymbolDisplayLabel(symbol, noteNameSystem: noteNameSystem),
            semanticsLabel: spokenLabel,
            style: textStyle,
            textAlign: widget.textAlign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          );
        },
      );

      return Align(
        alignment: widget.alignment,
        child: widget.showScrollbarWhenOverflow && widget.axis == Axis.vertical
            ? Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: list,
              )
            : list,
      );
    }

    // Empty state must still occupy an animatable child.
    // Using a key ensures AnimatedSwitcher recognizes state changes.
    Widget empty() {
      if (!widget.tappableWhenEmpty) {
        return const SizedBox(key: ValueKey('ambiguous_empty'));
      }
      return Align(
        key: const ValueKey('ambiguous_empty'),
        alignment: widget.alignment,
        child: Icon(
          Icons.format_list_numbered,
          color: cs.onSurface.withValues(alpha: 0.35),
          size: 20,
        ),
      );
    }

    final canTap =
        (hasContent || widget.tappableWhenEmpty) && widget.onTap != null;

    Widget interactive({required Widget child}) {
      if (!canTap) return child;

      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        child: child,
      );
    }

    return Semantics(
      container: true,
      label: hasContent ? 'Alternative chord candidates' : null,
      button: canTap,
      onTap: canTap ? widget.onTap : null,
      onTapHint: canTap ? 'Show chord ranking details' : null,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        reverseDuration: const Duration(milliseconds: 90),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,

        layoutBuilder: (currentChild, previousChildren) {
          final stackAlignment = widget.axis == Axis.vertical
              ? Alignment.topCenter
              : Alignment.centerLeft;

          return Stack(
            alignment: stackAlignment,
            children: [for (final c in previousChildren) c, ?currentChild],
          );
        },

        transitionBuilder: (child, animation) {
          final fade = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );

          return FadeTransition(
            opacity: fade,
            child: ClipRect(
              child: SizeTransition(
                sizeFactor: animation,
                axis: widget.axis,
                alignment: AlignmentDirectional.topStart,
                child: child,
              ),
            ),
          );
        },

        child: interactive(child: hasContent ? content() : empty()),
      ),
    );
  }
}
