import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/piano/piano.dart';

import '../models/home_layout_config.dart';

/// Keyboard region shared by Home, Explore Chords, and Explore Scales. Renders
/// the keyboard sized from the user's [PianoViewSettings] plus the drag-to-resize
/// affordance, whose placement adapts to the available space:
///
/// - Portrait (any page) and any page without a tonality bar: a full-width
///   separator line with the splitter centered in it, overlaid on the keyboard's
///   top edge (touch target reaches down over the keys).
/// - Landscape with a tonality bar: just the splitter, overlaid in the bar's
///   blank center, leaving the (shorter) keyboard untouched.
///
/// Pinch-to-zoom widens the keys; the splitter grows the vertical space. Both
/// persist globally via [pianoViewSettingsProvider].
class ResizableKeyboardArea extends ConsumerWidget {
  const ResizableKeyboardArea({
    super.key,
    required this.config,
    required this.maxKeyboardHeight,
    required this.highlightedNotes,
    this.impliedNotes = const <int>{},
    this.scaleNotes = const <int>{},
    this.normalHighlightPitchClasses,
    this.tonicPitchClass,
    this.topBar,
    this.hasTonalityBar = false,
    this.overlay,
  });

  final HomeLayoutConfig config;

  /// Ceiling for the keyboard's own height; see [maxKeyboardHeightForLayout].
  final double maxKeyboardHeight;

  final Set<int> highlightedNotes;

  /// Keys drawn as hollow implied notes (an ensemble reading's implied root).
  final Set<int> impliedNotes;

  final Set<int> scaleNotes;
  final Set<int>? normalHighlightPitchClasses;
  final int? tonicPitchClass;

  /// Chrome above the keys (the tonality bar). Null for pages without it.
  final Widget? topBar;

  /// Whether [topBar] is a tonality bar that can host the splitter in landscape.
  final bool hasTonalityBar;

  /// Overlay drawn over the keys (Home's lookup pad). Sized to the keyboard.
  final Widget? overlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(pianoViewSettingsProvider);
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = resolvePianoViewMetrics(
          viewportWidth: constraints.maxWidth,
          baseWhiteKeyCount: config.whiteKeyCount,
          baseAspectRatio: config.whiteKeyAspectRatio,
          tightenForStatusBar: config.tightenForStatusBar,
          maxHeight: maxKeyboardHeight,
          settings: settings,
        );

        final keyboard = ScrollablePianoKeyboard(
          visibleWhiteKeyCount: metrics.visibleWhiteKeyCount,
          height: metrics.height,
          highlightedNoteNumbers: highlightedNotes,
          impliedNoteNumbers: impliedNotes,
          autoCenter: true,
          fullWhiteKeyCount: PianoGeometry.fullKeyboardWhiteKeyCount,
          lowestNoteNumber: PianoGeometry.fullKeyboardLowestMidi,
          scaleNoteNumbers: scaleNotes,
          normalHighlightPitchClasses: normalHighlightPitchClasses,
          tonicPitchClass: tonicPitchClass,
          showMiddleCMarker: true,
          middleCLabel: 'C',
          middleCLabelTextScale: config.middleCLabelTextScale,
          enableZoom: true,
          widthScale: settings.widthScale,
          onWidthScaleChanged: (value) =>
              ref.read(pianoViewSettingsProvider.notifier).setWidthScale(value),
        );

        final canResize = metrics.maxHeight > metrics.baseHeight + 0.5;
        // Landscape Home / Explore Chords host the splitter low in the tonality
        // bar (just above the felt); everywhere else a solid separator band sits
        // above the keys with the splitter on it. Either way the splitter's visual
        // is just above the felt and its touch target reaches down over the keys.
        final useBarLayout = config.isLandscape && hasTonalityBar;

        final clippedKeyboard = SizedBox(
          height: metrics.height,
          child: ClipRect(
            child: Stack(
              children: [
                keyboard,
                if (overlay != null) Positioned.fill(child: overlay!),
              ],
            ),
          ),
        );

        // A crisp 1px line sits directly above the felt in both layouts.
        final feltLine = Container(height: 1, color: cs.outlineVariant);

        // Portrait / Scales: a solid separator band above that line; the splitter
        // rides on it. The felt stays visible below the line.
        final column = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?topBar,
            if (!useBarLayout)
              Container(
                height: kPianoSeparatorLineHeight,
                color: cs.surfaceContainerHighest,
              ),
            feltLine,
            clippedKeyboard,
          ],
        );

        if (!canResize) return column;

        // Overlay the splitter so its bottom sits just above the felt line and
        // its touch target reaches down over the keys. Anchored from the bottom
        // (the keyboard height is known), so it lands correctly whether the room
        // above the felt is a band (portrait) or the tonality bar (landscape).
        const feltGap = 1.0;
        final aboveFelt =
            PianoResizeHandle.splitterInset +
            PianoResizeHandle.splitterHeight +
            feltGap +
            1.0; // the felt line itself
        return Stack(
          clipBehavior: Clip.none,
          children: [
            column,
            Positioned(
              left: 0,
              right: 0,
              height: PianoResizeHandle.hitHeight,
              bottom: metrics.height - PianoResizeHandle.hitHeight + aboveFelt,
              child: Center(
                child: PianoResizeHandle(
                  baseHeight: metrics.baseHeight,
                  currentHeight: metrics.height,
                  maxHeight: metrics.maxHeight,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
