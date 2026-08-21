import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../models/home_layout_config.dart';
import 'chord_ranking_details_sheet.dart';
import 'identity_card.dart';

class AnalysisSection extends ConsumerWidget {
  const AnalysisSection({super.key, required this.config});

  final HomeLayoutConfig config;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final identity = ref.watch(heldIdentityDisplayProvider);
    final showIdle = ref.watch(inputIdleEligibleProvider);
    final demoEnabled = ref.watch(demoModeProvider);
    final demoVariant = ref.watch(demoModeVariantProvider);
    final showDemoControls =
        demoEnabled && demoVariant == DemoModeVariant.interactive;
    final stepIndex = ref.watch(demoSequenceProvider.select((s) => s.index));
    final stepCount = ref.watch(demoStepsProvider).length;
    final tourKeys = ref.watch(demoTourKeysProvider);

    Future<void> stepDemo(
      void Function(DemoSequenceNotifier notifier) step,
    ) async {
      if (!showDemoControls) return;
      step(ref.read(demoSequenceProvider.notifier));
      ref.read(demoModeProvider.notifier).applyCurrentStep();
      await HapticFeedback.selectionClick();
    }

    Widget identityCard({required bool fillCard}) => KeyedSubtree(
      key: tourKeys.chordCard,
      child: _IdentityCardWithChevrons(
        showControls: showDemoControls,
        canGoPrevious: stepIndex > 0,
        canGoNext: stepIndex < stepCount - 1,
        onPrevious: () => stepDemo((notifier) => notifier.prev()),
        onNext: () => stepDemo((notifier) => notifier.next()),
        child: IdentityCard(
          identity: identity,
          showIdle: showIdle,
          idleAsset: 'assets/logos/whatchord_logo_circle.svg',
          textScaleMultiplier: config.identityCardTextScale,
          fill: fillCard,
        ),
      ),
    );

    return Padding(
      padding: config.analysisPadding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isLandscape = config.isLandscape;
          final preferredW = clampDouble(
            config.analysisCardPreferredWidth,
            0.0,
            config.chordCardMaxWidth,
          );
          final cardW = clampDouble(preferredW, 0.0, constraints.maxWidth);

          // Tunables
          final textScale = MediaQuery.textScalerOf(context).scale(1.0);
          final cardH = config.analysisCardHeight;
          final listGap = config.analysisListGap;
          final laneH = constraints.maxHeight;
          final baseTopPad = clampDouble(
            config.analysisTopPadMax - (textScale - 1.0) * 28.0,
            config.analysisTopPadMin,
            config.analysisTopPadMax,
          );
          // As the keyboard grows the lane shrinks; spend the top padding first
          // (raising the card) so the alternative list keeps its
          // reserved room,
          // rather than covering the list while the card sits at its default
          // position. Once the padding bottoms out, the list yields.
          final topPad = isLandscape
              ? 0.0
              : clampDouble(
                  laneH - cardH - listGap - kPortraitAlternativeListReserve,
                  config.analysisTopPadMin,
                  baseTopPad,
                );
          final cardMaxH = clampDouble(
            config.analysisCardMaxHeight,
            0.0,
            laneH,
          );
          final listMaxH = clampDouble(
            laneH - topPad - cardH - listGap,
            0.0,
            laneH,
          );

          return SizedBox.expand(
            child: isLandscape
                ? Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: cardW,
                        maxHeight: cardMaxH,
                      ),
                      child: identityCard(fillCard: true),
                    ),
                  )
                : Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: topPad),
                      child: SizedBox(
                        width: cardW,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: cardW,
                              height: cardH,
                              child: identityCard(fillCard: true),
                            ),

                            if (!isLandscape) ...[
                              SizedBox(height: listGap),
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: listMaxH,
                                ),
                                child: KeyedSubtree(
                                  key: tourKeys.alternatives,
                                  child: AlternativeChordCandidatesList(
                                    enabled: true,
                                    alignment: Alignment.topCenter,
                                    textAlign: TextAlign.center,
                                    gap: 8,
                                    textScaleMultiplier:
                                        config.alternativeTextScale,
                                    tappableWhenEmpty: identity is ChordDisplay,
                                    onTap: () => unawaited(
                                      showChordRankingDetailsSheet(
                                        context,
                                        snapshot:
                                            ChordRankingDetailsSnapshot.capture(
                                              ref,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
          );
        },
      ),
    );
  }
}

class _IdentityCardWithChevrons extends StatelessWidget {
  const _IdentityCardWithChevrons({
    required this.child,
    required this.showControls,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  final Widget child;
  final bool showControls;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    if (!showControls) return child;

    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Align(
          alignment: Alignment.centerLeft,
          child: _DemoStepChevronButton(
            icon: Icons.chevron_left,
            tooltip: 'Previous tour step',
            enabled: canGoPrevious,
            onTap: onPrevious,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: _DemoStepChevronButton(
            icon: Icons.chevron_right,
            tooltip: 'Next tour step',
            enabled: canGoNext,
            onTap: onNext,
          ),
        ),
      ],
    );
  }
}

class _DemoStepChevronButton extends StatefulWidget {
  const _DemoStepChevronButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_DemoStepChevronButton> createState() => _DemoStepChevronButtonState();
}

class _DemoStepChevronButtonState extends State<_DemoStepChevronButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final active = widget.enabled && (_hovered || _pressed);
    final iconColor = cs.onPrimary.withValues(
      alpha: !widget.enabled
          ? 0.32
          : active
          ? 0.96
          : 0.68,
    );

    return MouseRegion(
      onEnter: widget.enabled ? (_) => setState(() => _hovered = true) : null,
      onExit: widget.enabled ? (_) => setState(() => _hovered = false) : null,
      child: Semantics(
        button: true,
        enabled: widget.enabled,
        label: widget.tooltip,
        onTapHint: widget.enabled ? widget.tooltip : null,
        onTap: widget.enabled ? widget.onTap : null,
        child: Tooltip(
          message: widget.enabled ? widget.tooltip : '',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: widget.enabled
                ? (_) => setState(() => _pressed = true)
                : null,
            onTapUp: widget.enabled
                ? (_) => setState(() => _pressed = false)
                : null,
            onTapCancel: widget.enabled
                ? () => setState(() => _pressed = false)
                : null,
            // Keep the boundary hit target opaque so taps cannot reach the
            // identity card and unexpectedly open Explore.
            onTap: widget.enabled ? widget.onTap : () {},
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              opacity: !widget.enabled
                  ? 0.72
                  : active
                  ? 1.0
                  : 0.76,
              child: SizedBox(
                width: 56,
                height: 56,
                child: Icon(widget.icon, color: iconColor, size: 36),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
