import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/links/links.dart';
import 'package:whatchord_app/features/lookup/lookup.dart';
import 'package:whatchord_app/features/midi/midi.dart';
import 'package:whatchord_app/features/onboarding/onboarding.dart';
import 'package:whatchord_app/features/scales/scales.dart';
import 'package:whatchord_app/features/settings/settings.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../models/home_layout_config.dart';
import '../widgets/analysis_section.dart';
import '../widgets/app_bar_title.dart';
import '../widgets/demo_mode_explanation.dart';
import '../widgets/details_section.dart';
import '../widgets/edge_to_edge_controller.dart';
import '../widgets/resizable_keyboard_area.dart';
import '../widgets/tonality_bar.dart';

const _tonalityBarHeight = kToolbarHeight;

/// Conservative reserve (px) for the portrait demo prompt + input display that
/// sit above the keyboard, so growing the keyboard keeps room for them.
const _portraitInputReserve = 96.0;

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  late final ProviderSubscription<MidiConnectionState> _midiSub;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeStartTour());

    _midiSub = ref.listenManual(midiConnectionStateProvider, (prev, next) {
      if (!mounted) return;
      if (prev?.phase != MidiConnectionPhase.connected &&
          next.phase == MidiConnectionPhase.connected) {
        final demoEnabled = ref.read(demoModeProvider);
        final demoVariant = ref.read(demoModeVariantProvider);
        final disableInteractiveDemo =
            demoEnabled && demoVariant == DemoModeVariant.interactive;
        if (disableInteractiveDemo) {
          ref
              .read(demoModeProvider.notifier)
              .setEnabledFor(
                enabled: false,
                variant: DemoModeVariant.interactive,
              );
        }

        final name = next.device?.displayName;
        final baseText = name != null
            ? 'MIDI connected: $name'
            : 'MIDI connected';
        final text = disableInteractiveDemo
            ? '$baseText\nTour ended'
            : baseText;

        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    });
  }

  @override
  void dispose() {
    _midiSub.close();
    super.dispose();
  }

  /// On first launch only, auto-start the guided tour so its walkthrough is
  /// visible right here on the home screen. Skipped if a MIDI device is already
  /// connected, since live input would immediately end it.
  void _maybeStartTour() {
    if (!mounted) return;
    if (!ref.read(onboardingTourProvider).shouldStartTour) return;

    final connected =
        ref.read(midiConnectionStateProvider).phase ==
        MidiConnectionPhase.connected;
    unawaited(ref.read(onboardingTourProvider.notifier).markSeen());
    if (connected) return;

    ref
        .read(demoModeProvider.notifier)
        .setEnabledFor(enabled: true, variant: DemoModeVariant.interactive);
  }

  void _openMidiSettings() {
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MidiSettingsPage())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.of(context);
        final config = resolveHomeLayoutConfig(constraints);
        final isLandscape = config.isLandscape;

        // Keep the bar a touch taller than the 48px icons and bias the content
        // up, so the icons sit near the status bar with a little room below.
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

        // Symmetric rail inset for top bar and tonality bar. Landscape draws
        // full-bleed horizontally, so add the largest system cutout inset.
        final horizontalInset = barBaseInset + maxHorizontalCutout;

        return EdgeToEdgeController(
          child: WakelockController(
            child: Scaffold(
              body: Stack(
                children: [
                  Column(
                    children: [
                      ColoredBox(
                        color: cs.surfaceContainerLow,
                        child: SafeArea(
                          bottom: false, // only protect status bar
                          left: !isLandscape, // allow full-bleed in landscape
                          right: !isLandscape,
                          child: _HomeTopBar(
                            toolbarHeight: toolbarHeight,
                            contentBottomInset: toolbarBottomInset,
                            horizontalInset: horizontalInset,
                            onOpenMidiSettings: _openMidiSettings,
                          ),
                        ),
                      ),

                      Expanded(
                        child: SafeArea(
                          top: false, // already handled above
                          bottom: false, // piano draws to bottom
                          left: !isLandscape,
                          right: !isLandscape,
                          child: isLandscape
                              ? _HomeLandscape(
                                  config: config,
                                  horizontalInset: horizontalInset,
                                )
                              : _HomePortrait(
                                  config: config,
                                  horizontalInset: horizontalInset,
                                ),
                        ),
                      ),
                    ],
                  ),
                  const DemoCalloutOverlay(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeTopBar extends ConsumerWidget {
  const _HomeTopBar({
    required this.toolbarHeight,
    required this.contentBottomInset,
    required this.horizontalInset,
    required this.onOpenMidiSettings,
  });

  final double toolbarHeight;
  final double contentBottomInset;
  final double horizontalInset;
  final VoidCallback onOpenMidiSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge;
    final demoEnabled = ref.watch(demoModeProvider);
    final demoVariant = ref.watch(demoModeVariantProvider);
    final showInteractiveDemoPill =
        demoEnabled && demoVariant == DemoModeVariant.interactive;
    final tourKeys = ref.watch(demoTourKeysProvider);

    // Optical-only tweak.
    const settingsIconDx = 6.0;

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
              Expanded(
                child: Semantics(
                  header: true,
                  namesRoute: true,
                  label: 'What Chord',
                  child: ExcludeSemantics(
                    child: DefaultTextStyle(
                      style: titleStyle!,
                      child: AppBarTitle(maxHeight: toolbarHeight),
                    ),
                  ),
                ),
              ),
              if (showInteractiveDemoPill)
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 16),
                  child: _DemoModePill(
                    onPressed: () {
                      ref
                          .read(demoModeProvider.notifier)
                          .setEnabledFor(enabled: false, variant: demoVariant);
                    },
                  ),
                ),
              // Hidden during the tour: its "Exit tour" pill needs the room,
              // and demo chords are not the user's to share.
              if (!showInteractiveDemoPill) const _ShareButton(),
              const SizedBox(width: 4),
              MidiStatusIcon(
                onPressed: onOpenMidiSettings,
                iconButtonKey: tourKeys.midiIcon,
              ),
              Transform.translate(
                offset: const Offset(settingsIconDx, 0),
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const Icon(Icons.settings),
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shares a website link to the current voicing via the native share sheet.
/// Disabled when nothing is sounding, so there is nothing to link to.
class _ShareButton extends ConsumerWidget {
  const _ShareButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final link = ref.watch(shareLinkProvider);

    return IconButton(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const Icon(Icons.ios_share),
      tooltip: 'Share chord',
      onPressed: link == null ? null : () => _share(context, link),
    );
  }

  void _share(BuildContext context, Uri link) {
    // Anchor the iPad popover to the button.
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    Rect? origin;
    if (box != null && overlay != null) {
      origin = Rect.fromPoints(
        box.localToGlobal(Offset.zero, ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      );
    }
    unawaited(shareChordLink(link, sharePositionOrigin: origin));
  }
}

class _HomeLandscape extends ConsumerWidget {
  const _HomeLandscape({
    // ignore: unused_element_parameter
    super.key,
    required this.config,
    required this.horizontalInset,
  });
  final HomeLayoutConfig config;
  final double horizontalInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourKeys = ref.watch(demoTourKeysProvider);
    final highlightedNotes = ref.watch(liveSoundingNoteNumbersProvider);
    final impliedNotes = ref.watch(impliedRootNoteNumbersProvider);
    final lookupActive = ref.watch(lookupActiveProvider);

    return LayoutBuilder(
      builder: (context, bodyConstraints) {
        return Column(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(flex: 7, child: AnalysisSection(config: config)),
                  Expanded(flex: 6, child: DetailsSection(config: config)),
                ],
              ),
            ),
            ResizableKeyboardArea(
              config: config,
              maxKeyboardHeight: maxKeyboardHeightForLayout(
                availableHeight: bodyConstraints.maxHeight,
                isLandscape: true,
                reservedChrome: _tonalityBarHeight + 1, // bar + divider
              ),
              highlightedNotes: highlightedNotes,
              impliedNotes: impliedNotes,
              overlay: _LookupOverlay(active: lookupActive),
              hasTonalityBar: true,
              topBar: KeyedSubtree(
                key: tourKeys.tonalityBar,
                child: TonalityBar(
                  height: _tonalityBarHeight,
                  horizontalInset: horizontalInset,
                  keyTextScaleMultiplier: config.tonalityButtonTextScale,
                  scaleDegreesTextScaleMultiplier: config.scaleDegreesTextScale,
                  onScaleDegreesTap: () =>
                      Navigator.of(context).push(ScaleExplorerPage.route()),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HomePortrait extends ConsumerWidget {
  const _HomePortrait({
    // ignore: unused_element_parameter
    super.key,
    required this.config,
    required this.horizontalInset,
  });
  final HomeLayoutConfig config;
  final double horizontalInset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tourKeys = ref.watch(demoTourKeysProvider);
    final highlightedNotes = ref.watch(liveSoundingNoteNumbersProvider);
    final impliedNotes = ref.watch(impliedRootNoteNumbersProvider);
    final lookupActive = ref.watch(lookupActiveProvider);

    return LayoutBuilder(
      builder: (context, bodyConstraints) {
        return Column(
          children: [
            Flexible(
              fit: FlexFit.loose,
              child: AnalysisSection(config: config),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: tourKeys.prompt,
                  child: const DemoModeExplanation(),
                ),
                InputDisplay(
                  padding: config.inputDisplayPadding,
                  visualScaleMultiplier: config.inputDisplayVisualScale,
                  lookupButtonKey: tourKeys.lookupButton,
                ),
                ResizableKeyboardArea(
                  config: config,
                  maxKeyboardHeight: maxKeyboardHeightForLayout(
                    availableHeight: bodyConstraints.maxHeight,
                    isLandscape: false,
                    // Tonality bar + separator band + 1px felt line, plus the
                    // input display / demo prompt above.
                    reservedChrome:
                        _tonalityBarHeight +
                        kPianoSeparatorLineHeight +
                        1 +
                        _portraitInputReserve,
                    // Keep the identity card fully visible above the keyboard.
                    minContent: portraitAnalysisMinContent(config),
                  ),
                  highlightedNotes: highlightedNotes,
                  impliedNotes: impliedNotes,
                  overlay: _LookupOverlay(active: lookupActive),
                  hasTonalityBar: true,
                  topBar: KeyedSubtree(
                    key: tourKeys.tonalityBar,
                    child: TonalityBar(
                      height: _tonalityBarHeight,
                      horizontalInset: horizontalInset,
                      keyTextScaleMultiplier: config.tonalityButtonTextScale,
                      scaleDegreesTextScaleMultiplier:
                          config.scaleDegreesTextScale,
                      onScaleDegreesTap: () =>
                          Navigator.of(context).push(ScaleExplorerPage.route()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Lookup pad overlay. The keyboard stays mounted underneath; the pad slides
/// down from above to cover it (and back up to reveal it). Keeping the keyboard
/// mounted means it never re-centers on the toggle. Sized by the keyboard area
/// it fills.
class _LookupOverlay extends StatelessWidget {
  const _LookupOverlay({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !active,
      child: AnimatedSlide(
        offset: active ? Offset.zero : const Offset(0, -1),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        child: const LookupPad(),
      ),
    );
  }
}

class _DemoModePill extends StatelessWidget {
  const _DemoModePill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontSize: 13,
      letterSpacing: 0.25,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
    );
    final scaler = TextScaler.linear(
      MediaQuery.textScalerOf(context).scale(1.0).clamp(1.0, 1.35),
    );

    return Tooltip(
      message: 'Exit tour',
      child: ActionChip(
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        backgroundColor: cs.surface,
        side: BorderSide(color: cs.outlineVariant),
        avatar: Icon(Icons.close, size: 16, color: cs.onSurface),
        labelPadding: const EdgeInsets.only(right: 8),
        label: Text('Exit tour', textScaler: scaler, style: textStyle),
      ),
    );
  }
}
