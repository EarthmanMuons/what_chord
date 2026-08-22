import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/history/history.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../models/inferred_key_state.dart';
import '../providers/inferred_key_notifier.dart';

/// The evidence trail: chords the detector is currently listening to, newest
/// on the left, older sliding right and off into the scroll. Cleared when
/// the detector forgets (the two-minute reset), so nothing on screen looks
/// like it still contributes when it does not.
class RecentChordsStrip extends ConsumerStatefulWidget {
  const RecentChordsStrip({super.key, this.maxChords = 24});

  final int maxChords;

  @override
  ConsumerState<RecentChordsStrip> createState() => _RecentChordsStripState();
}

class _RecentChordsStripState extends ConsumerState<RecentChordsStrip> {
  final _listKey = GlobalKey<AnimatedListState>();
  final _scrollController = ScrollController();
  final List<ChordEvent> _events = []; // newest first
  var _generation = 0;
  var _showLeftFade = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final scrolled =
          _scrollController.hasClients && _scrollController.offset > 4;
      if (scrolled != _showLeftFade) {
        setState(() => _showLeftFade = scrolled);
      }
    });
    // Seed from the events already contributing to the current belief (the
    // page can open mid-session).
    final inferred = ref.read(inferredKeyProvider);
    if (inferred.freshness != InferredKeyFreshness.none) {
      final since = inferred.resetAt;
      final history = ref.read(chordHistoryProvider);
      _events.addAll(
        history
            .where((e) => since == null || e.timestamp.isAfter(since))
            .toList()
            .reversed
            .take(widget.maxChords),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chordHistoryProvider, _onHistory);
    ref.listen(inferredKeyProvider.select((state) => state.freshness), (
      previous,
      next,
    ) {
      if (next == InferredKeyFreshness.none) _clear();
    });

    final notation = ref.watch(chordNotationStyleProvider);
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final empty = _events.isEmpty;

    // Height stays reserved even before the first chord arrives so the rest
    // of the page does not reflow when the strip appears. The reset control
    // overlays the top-right corner rather than sitting in the title row so
    // its 48px accessibility tap target (extending down over the header gap
    // and the untappable end of the chips lane) never disturbs the layout.
    return Stack(
      // The reset pill overflows 4px above the title line to stay centered
      // on it.
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedOpacity(
              opacity: empty ? 0 : 1,
              duration: const Duration(milliseconds: 400),
              child: Text(
                'Recent chords',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(height: 8),
            _chipsLane(notation, empty),
          ],
        ),
        Positioned(
          top: -4,
          right: 0,
          child: IgnorePointer(
            ignoring: empty,
            child: ExcludeSemantics(
              excluding: empty,
              child: AnimatedOpacity(
                opacity: empty ? 0 : 1,
                duration: const Duration(milliseconds: 400),
                child: _ResetButton(
                  onPressed: () =>
                      ref.read(inferredKeyProvider.notifier).reset(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _chipsLane(ChordNotationStyle notation, bool empty) {
    return SizedBox(
      height: 36,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: empty
            ? const SizedBox.expand()
            : ShaderMask(
                key: ValueKey('strip$_generation'),
                shaderCallback: (bounds) => LinearGradient(
                  colors: [
                    _showLeftFade ? Colors.transparent : Colors.white,
                    Colors.white,
                    Colors.white,
                    Colors.transparent,
                  ],
                  stops: const [0, 0.06, 0.92, 1],
                ).createShader(bounds),
                blendMode: BlendMode.dstIn,
                child: AnimatedList(
                  key: _listKey,
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  // Without explicit padding a scrollable adopts the
                  // ambient safe-area insets, indenting the newest chip
                  // in landscape.
                  padding: EdgeInsets.zero,
                  initialItemCount: _events.length,
                  itemBuilder: (context, index, animation) =>
                      _chip(context, _events[index], animation, notation),
                ),
              ),
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    ChordEvent event,
    Animation<double> animation,
    ChordNotationStyle notation,
  ) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final eased = CurvedAnimation(parent: animation, curve: Curves.easeOut);
    final symbol = ChordSymbolBuilder.formatIdentity(
      identity: event.identity,
      tonality: event.tonality,
      notation: notation,
    );
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;
    final resizeDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 90);
    final flipDuration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 340);

    return SizeTransition(
      sizeFactor: eased,
      axis: Axis.horizontal,
      child: FadeTransition(
        opacity: eased,
        child: Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Semantics(
            label: 'Recent chord $symbol',
            child: ExcludeSemantics(
              child: AnimatedSize(
                duration: resizeDuration,
                curve: Curves.easeOutCubic,
                alignment: Alignment.centerLeft,
                child: AnimatedSwitcher(
                  duration: flipDuration,
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  layoutBuilder: (currentChild, previousChildren) {
                    return CurrentSizeSwitcherLayout(
                      currentChild: currentChild,
                      previousChildren: previousChildren,
                    );
                  },
                  transitionBuilder: (child, animation) {
                    return ChipFlipTransition(
                      animation: animation,
                      incoming: child.key == ValueKey(symbol),
                      child: child,
                    );
                  },
                  child: Container(
                    key: ValueKey(symbol),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Text(symbol, style: theme.textTheme.bodyMedium),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onHistory(List<ChordEvent>? previous, List<ChordEvent> next) {
    if (next.isEmpty) return; // reset handled via freshness
    if (previous != null &&
        previous.length == next.length &&
        previous.isNotEmpty &&
        identical(previous.last, next.last)) {
      _replaceChangedEvents(previous, next);
      return;
    }
    setState(() {
      _events.insert(0, next.last);
    });
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 350),
    );
    if (_events.length > widget.maxChords) {
      final removeIndex = _events.length - 1;
      _events.removeLast();
      _listKey.currentState?.removeItem(
        removeIndex,
        (context, animation) => const SizedBox.shrink(),
        duration: Duration.zero,
      );
    }
  }

  /// Reconciles record-only history corrections without treating them as new
  /// chords. A replacement preserves its chronological slot, so matching each
  /// locally displayed event back to the prior list identifies exactly which
  /// chip should flip in place.
  void _replaceChangedEvents(List<ChordEvent> previous, List<ChordEvent> next) {
    final replacements = <int, ChordEvent>{};
    for (var localIndex = 0; localIndex < _events.length; localIndex++) {
      final previousIndex = previous.indexWhere(
        (event) => identical(event, _events[localIndex]),
      );
      if (previousIndex >= 0 &&
          !identical(previous[previousIndex], next[previousIndex])) {
        replacements[localIndex] = next[previousIndex];
      }
    }
    if (replacements.isEmpty) return;

    setState(() {
      for (final replacement in replacements.entries) {
        _events[replacement.key] = replacement.value;
      }
    });
  }

  void _clear() {
    if (_events.isEmpty) return;
    setState(() {
      _events.clear();
      _generation += 1; // rebuild the AnimatedList empty
    });
  }
}

/// Compact reset affordance: the ink stays a small pill centered on the
/// label, while an invisible surrounding box (taps there also reset, without
/// a ripple) brings the effective target up to the 48px accessibility
/// minimum.
class _ResetButton extends StatelessWidget {
  const _ResetButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onPressed,
      child: Container(
        height: 52,
        constraints: const BoxConstraints(minWidth: 48),
        alignment: Alignment.topCenter,
        child: TextButton.icon(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            // The icon glyph carries built-in whitespace, so the trailing
            // side needs extra padding to look optically even.
            padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 12, 0),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Reset', semanticsLabel: 'Reset key detection'),
        ),
      ),
    );
  }
}
