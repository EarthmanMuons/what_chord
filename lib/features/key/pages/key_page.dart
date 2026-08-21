import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/home/home.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/midi/midi.dart';
import 'package:whatchord_app/features/settings/settings.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../providers/inferred_key_notifier.dart';
import '../providers/key_mode_notifier.dart';
import '../providers/key_screenshot_seed_notifier.dart';
import '../widgets/auto_key_status.dart';
import '../widgets/key_posterior_strip.dart';
import '../widgets/key_posterior_wheel.dart';
import '../widgets/recent_chords_strip.dart';

/// The key page: manual key-signature selection and the auto-detected key,
/// as one surface with the live keyboard below, so the detector can be
/// watched while playing (Phase 2 integration spec).
class KeyPage extends ConsumerWidget {
  const KeyPage({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const KeyPage());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(keyModeProvider);
    final liveNotes = ref.watch(liveSoundingNoteNumbersProvider);
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.of(context);
        final config = resolveHomeLayoutConfig(constraints);
        final isLandscape = config.isLandscape;

        final toolbarHeight = config.tightenForStatusBar
            ? kAndroidLandscapeToolbarHeight
            : kToolbarHeight;
        final toolbarBottomInset = config.tightenForStatusBar
            ? kAndroidLandscapeToolbarBottomInset
            : 0.0;

        const barBaseInset = 16.0;
        final maxHorizontalCutout = isLandscape
            ? math.max(mq.viewPadding.left, mq.viewPadding.right)
            : 0.0;
        final horizontalInset = barBaseInset + maxHorizontalCutout;

        return Scaffold(
          body: Column(
            children: [
              ColoredBox(
                color: cs.surfaceContainerLow,
                child: SafeArea(
                  bottom: false,
                  left: !isLandscape,
                  right: !isLandscape,
                  child: _KeyTopBar(
                    toolbarHeight: toolbarHeight,
                    contentBottomInset: toolbarBottomInset,
                    horizontalInset: horizontalInset,
                  ),
                ),
              ),
              Expanded(
                child: SafeArea(
                  top: false,
                  bottom: false,
                  left: !isLandscape,
                  right: !isLandscape,
                  child: LayoutBuilder(
                    builder: (context, bodyConstraints) {
                      return Column(
                        children: [
                          if (!isLandscape) ...[
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontalInset,
                                12,
                                horizontalInset,
                                12,
                              ),
                              child: _ModeSegments(mode: mode),
                            ),
                            Expanded(
                              child: mode == KeyMode.auto
                                  ? _PortraitAutoPane(
                                      horizontalInset: horizontalInset,
                                    )
                                  : const TonalityPickerBody(),
                            ),
                          ] else
                            Expanded(
                              child: _LandscapeBody(
                                mode: mode,
                                horizontalInset: horizontalInset,
                              ),
                            ),
                          ResizableKeyboardArea(
                            config: config,
                            maxKeyboardHeight: maxKeyboardHeightForLayout(
                              availableHeight: bodyConstraints.maxHeight,
                              isLandscape: isLandscape,
                              reservedChrome:
                                  kToolbarHeight +
                                  (isLandscape
                                      ? 1
                                      : kPianoSeparatorLineHeight + 1),
                            ),
                            highlightedNotes: liveNotes,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ModeSegments extends ConsumerWidget {
  const _ModeSegments({required this.mode});

  final KeyMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SegmentedButton<KeyMode>(
      segments: const [
        ButtonSegment(
          value: KeyMode.manual,
          label: Text('Manual'),
          icon: Icon(Icons.music_note),
        ),
        ButtonSegment(
          value: KeyMode.auto,
          label: Text('Auto'),
          icon: Icon(Icons.hdr_auto),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (selection) => unawaited(
        ref.read(keyModeProvider.notifier).setMode(selection.first),
      ),
    );
  }
}

class _PortraitAutoPane extends ConsumerWidget {
  const _PortraitAutoPane({required this.horizontalInset});

  final double horizontalInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inferred = ref.watch(inferredKeyProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // One layout for every height: the wheel absorbs whatever remains,
        // so growing the keyboard eats slack around the wheel before
        // shrinking it. Below [minPaneHeight] the content height freezes and
        // the pane scrolls instead, so the wheel shrinks smoothly to its
        // floor rather than snapping between layouts.
        const minPaneHeight = 340.0;
        const verticalPadding = 4.0;
        final contentHeight =
            math.max(constraints.maxHeight, minPaneHeight) - verticalPadding;

        return FadedScrollView(
          // No top padding: the segments row's 12px bottom padding is the
          // full gap above the status block.
          padding: EdgeInsets.fromLTRB(horizontalInset, 0, horizontalInset, 4),
          child: SizedBox(
            height: contentHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AutoKeyStatus(),
                // Matches the 12px above the status block so the wheel does
                // not crowd the confidence line.
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: KeyPosteriorWheel(
                        ranked: inferred.ranked,
                        claim: inferred.displayKey?.tonality,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const RecentChordsStrip(),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Landscape splits like the Explore pages: mode control and context on the
/// left, the working surface (posterior strip and chords, or the key list)
/// on the right.
class _LandscapeBody extends ConsumerWidget {
  const _LandscapeBody({required this.mode, required this.horizontalInset});

  final KeyMode mode;
  final double horizontalInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inferred = ref.watch(inferredKeyProvider);
    final selected = ref.watch(selectedTonalityProvider);

    // Pane content centers in whatever height the keyboard leaves, so the
    // layout rebalances as the keyboard is resized; it degrades to a plain
    // scroll when the content no longer fits.
    Widget balanced({
      required List<Widget> children,
      required CrossAxisAlignment crossAxisAlignment,
      bool centerGroup = false,
    }) {
      final column = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      );
      return LayoutBuilder(
        builder: (context, paneConstraints) => FadedScrollView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: math.max(0, paneConstraints.maxHeight - 16),
            ),
            // centerGroup shrink-wraps the column and centers it in the
            // pane; the children stay edge-aligned to each other.
            child: centerGroup ? Center(child: column) : column,
          ),
        ),
      );
    }

    final left = balanced(
      centerGroup: true,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ModeSegments(mode: mode),
        const SizedBox(height: 14),
        if (mode == KeyMode.auto)
          const AutoKeyStatus()
        else
          // Bounded so the card's internal centering has no slack and the
          // staff lines up with the mode control above it.
          ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: KeySignatureStaffPreview.previewWidth,
            ),
            child: KeySignatureStaffPreview(
              keySignature: selected.keySignature,
            ),
          ),
      ],
    );

    final right = LayoutBuilder(
      builder: (context, paneConstraints) {
        // Roomy landscape (tablets): the full wheel replaces the unrolled
        // strip and the key list keeps its regular row height.
        final roomy = paneConstraints.maxHeight >= 380;

        if (mode == KeyMode.manual) {
          return TonalityPickerBody(
            showStaffPreview: false,
            compact: !roomy,
            headerHeight: TonalityPickerBody.slimHeaderHeight,
            listBottomPadding: 0,
          );
        }

        if (roomy) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: KeyPosteriorWheel(
                        ranked: inferred.ranked,
                        claim: inferred.displayKey?.tonality,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const RecentChordsStrip(),
              ],
            ),
          );
        }

        return balanced(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            KeyPosteriorStrip(
              ranked: inferred.ranked,
              claim: inferred.displayKey?.tonality,
            ),
            const SizedBox(height: 12),
            const RecentChordsStrip(),
          ],
        );
      },
    );

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 5, child: left),
          const SizedBox(width: 16),
          Expanded(flex: 7, child: right),
        ],
      ),
    );
  }
}

class _KeyTopBar extends ConsumerWidget {
  const _KeyTopBar({
    required this.toolbarHeight,
    required this.contentBottomInset,
    required this.horizontalInset,
  });

  final double toolbarHeight;
  final double contentBottomInset;
  final double horizontalInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(
      context,
    ).textTheme.titleLarge?.copyWith(letterSpacing: -0.2);

    // Match the standard AppBar leading-control position while the title and
    // content retain their shared horizontal inset.
    const arrowIconDx = -12.0;

    Widget title = Text(
      'Key Signature',
      style: titleStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    // Same gating as the home title's demo gestures: long-pressing the title
    // toggles the screenshot seed for reproducible emulator captures.
    if (kDebugMode || kProfileMode || AppBarTitle.kForceDemoSupport) {
      title = GestureDetector(
        behavior: HitTestBehavior.translucent,
        onLongPress: () {
          ref.read(keyScreenshotSeedProvider.notifier).toggle();
          unawaited(HapticFeedback.lightImpact());
        },
        child: title,
      );
    }

    return Material(
      color: cs.surfaceContainerLow,
      child: SizedBox(
        height: toolbarHeight,
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalInset,
            right: horizontalInset,
            bottom: contentBottomInset,
          ),
          child: Row(
            children: [
              Transform.translate(
                offset: const Offset(arrowIconDx, 0),
                child: IconButton(
                  tooltip: 'Back',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const BackButtonIcon(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(header: true, namesRoute: true, child: title),
              ),
              const SizedBox(width: 4),
              const MidiStatusIcon(),
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(6, 0),
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: 'Settings',
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
