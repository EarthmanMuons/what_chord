import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/features/chords/chords.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import 'analysis_details_sheet.dart';

class IdentityCard extends ConsumerWidget {
  final IdentityDisplay? identity;

  /// When true, show the idle SVG instead of identity text.
  final bool showIdle;

  /// SVG asset to show when idle.
  final String idleAsset;

  /// Visual scaling applied for larger layout classes.
  final double textScaleMultiplier;

  final bool fill;

  const IdentityCard({
    super.key,
    required this.identity,
    required this.showIdle,
    required this.idleAsset,
    this.textScaleMultiplier = 1.0,
    this.fill = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final exploreSeedIdentity = ref.watch(exploreSeedIdentityProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);

    final hasLabel = identity?.hasSecondaryLabel ?? false;

    final typographyScale = textScaleMultiplier.clamp(1.0, 2.0);
    const autoSizeStep = 0.5;

    TextStyle scaleStyle(TextStyle style) {
      final fontSize = style.fontSize;
      if (fontSize == null) return style;
      return style.copyWith(fontSize: fontSize * typographyScale);
    }

    double snapToStep(double value, {double step = autoSizeStep}) {
      return (value / step).roundToDouble() * step;
    }

    final base = scaleStyle(theme.textTheme.displayMedium!);

    final primaryStyle = base.copyWith(color: cs.onPrimary, height: 1.0);

    final secondaryStyle = scaleStyle(theme.textTheme.titleMedium!)
        .copyWith(color: cs.onPrimary.withValues(alpha: 0.85), height: 1.1);

    final rootStyle = primaryStyle.copyWith(
      fontWeight: FontWeight.w500,
      fontSize: (primaryStyle.fontSize! + 6 * typographyScale),
    );
    final chordDetailStyle = primaryStyle.copyWith(
      color: cs.onPrimary.withValues(alpha: 0.86),
    );
    final intervalStyle = chordDetailStyle.copyWith(
      color: rootStyle.color,
      letterSpacing: -1.0,
    );

    const minCardHeight = 132.0;
    const padding = EdgeInsets.symmetric(horizontal: 20);

    Widget identityBody(IdentityDisplay v) {
      return switch (v) {
        NoteDisplay(:final noteName) => AutoSizeText(
          noteName,
          textAlign: TextAlign.center,
          style: rootStyle,
          maxLines: 1,
          minFontSize: snapToStep(22 * typographyScale),
          stepGranularity: autoSizeStep,
        ),
        IntervalDisplay(:final intervalLabel) => AutoSizeText(
          intervalLabel,
          textAlign: TextAlign.center,
          style: intervalStyle,
          maxLines: 1,
          minFontSize: snapToStep(22 * typographyScale),
          stepGranularity: autoSizeStep,
        ),
        ChordDisplay(:final symbol) => AutoSizeText.rich(
          _chordDisplaySpan(
            symbol: symbol,
            noteNameSystem: noteNameSystem,
            primaryStyle: primaryStyle,
            rootStyle: rootStyle,
            chordDetailStyle: chordDetailStyle,
          ),
          textAlign: TextAlign.center,
          style: primaryStyle,
          maxLines: 1,
          minFontSize: snapToStep(22 * typographyScale),
          stepGranularity: autoSizeStep,
        ),
      };
    }

    Widget idleGlyph() {
      return Opacity(
        opacity: 0.55,
        child: SvgPicture.asset(
          idleAsset,
          width: 72 * typographyScale,
          height: 72 * typographyScale,
          colorFilter: ColorFilter.mode(
            cs.onPrimary.withValues(alpha: 0.9),
            BlendMode.srcIn,
          ),
        ),
      );
    }

    Widget placeholderText(TextStyle style) {
      return AutoSizeText(
        '• • •',
        textAlign: TextAlign.center,
        style: style,
        maxLines: 1,
        minFontSize: snapToStep(22 * typographyScale),
        stepGranularity: autoSizeStep,
      );
    }

    final display = identity;

    final cardShape = CardTheme.of(context).shape;
    final cardBorderRadius = switch (cardShape) {
      RoundedRectangleBorder(:final borderRadius) => borderRadius.resolve(
        Directionality.of(context),
      ),
      _ => BorderRadius.circular(12),
    };

    Widget switchedChild() {
      void openExplore() {
        unawaited(
          Navigator.of(context)
              .push(ExploreChordPage.route(seedIdentity: exploreSeedIdentity)),
        );
      }

      void openAnalysisDetails() {
        final display = identity;
        if (display == null) return;
        unawaited(showAnalysisDetailsSheet(context, identity: display));
      }

      String? semanticsSecondaryValue(IdentityDisplay display) {
        final raw = display.secondaryLabel?.trim();
        if (raw == null || raw.isEmpty) return null;
        // Keep visual separators as-is, but avoid awkward spoken "dot".
        final normalized = raw.replaceAll(RegExp(r'\s*·\s*'), ', ');
        return normalized;
      }

      return AnimatedSwitcher(
        duration: const Duration(milliseconds: 140),
        reverseDuration: const Duration(milliseconds: 90),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
        layoutBuilder: (currentChild, previousChildren) {
          return Stack(
            alignment: Alignment.center,
            fit: StackFit.expand,
            children: [
              for (final c in previousChildren) Center(child: c),
              if (currentChild != null) Center(child: currentChild),
            ],
          );
        },
        child: display != null
            ? KeyedSubtree(
                key: const ValueKey('identity'),
                child: Semantics(
                  container: true,
                  // Announce the meaning in plain English.
                  label: display.semanticLabel,
                  value: semanticsSecondaryValue(display),

                  // Prevent VoiceOver/TalkBack from reading the visual glyph
                  // text in addition to label.
                  excludeSemantics: true,

                  button: true,
                  onTap: openExplore,
                  onTapHint: 'Open Explore',
                  onLongPress: openAnalysisDetails,
                  onLongPressHint: 'Show analysis details',
                  child: hasLabel
                      ? LayoutBuilder(
                          builder: (context, c) {
                            final maxH = c.maxHeight;
                            final hasMax = maxH.isFinite && maxH > 0;
                            final textScale = MediaQuery.textScalerOf(context)
                                .scale(1.0);
                            final gapScale = 1 / textScale.clamp(1.0, 1.6);
                            const gap = 0.0;
                            final maxW = c.maxWidth.isFinite
                                ? c.maxWidth
                                : MediaQuery.sizeOf(context).width -
                                      padding.horizontal;
                            final secondaryLabel = display.secondaryLabel!;

                            if (!hasMax) {
                              return Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  identityBody(display),
                                  const SizedBox(height: gap),
                                  ConstrainedBox(
                                    constraints: BoxConstraints(maxWidth: maxW),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: Text(
                                        secondaryLabel,
                                        textAlign: TextAlign.center,
                                        style: secondaryStyle,
                                        maxLines: 1,
                                        softWrap: false,
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }

                            final textDirection = Directionality.of(context);
                            final secondaryPainter = TextPainter(
                              text: TextSpan(
                                text: secondaryLabel,
                                style: secondaryStyle,
                              ),
                              textDirection: textDirection,
                              maxLines: 1,
                              textScaler: MediaQuery.textScalerOf(context),
                            )..layout(maxWidth: double.infinity);
                            final secondaryHeight = secondaryPainter.height;

                            final isLandscape =
                                MediaQuery.orientationOf(context) ==
                                Orientation.landscape;
                            final bottomPad =
                                (maxH * (isLandscape ? 0.08 : 0.12)).clamp(
                                  isLandscape ? 6.0 : 10.0,
                                  isLandscape ? 12.0 : 18.0,
                                ) *
                                gapScale;

                            return Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                SizedBox(
                                  height:
                                      (maxH - gap - bottomPad - secondaryHeight)
                                          .clamp(0.0, maxH),
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: identityBody(display),
                                    ),
                                  ),
                                ),
                                SizedBox(height: gap),
                                SizedBox(
                                  height: secondaryHeight,
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth: maxW,
                                      ),
                                      child: AutoSizeText(
                                        secondaryLabel,
                                        textAlign: TextAlign.center,
                                        style: secondaryStyle,
                                        maxLines: 1,
                                        minFontSize: snapToStep(
                                          6.0 * typographyScale,
                                        ),
                                        maxFontSize: snapToStep(
                                          secondaryStyle.fontSize ?? 14.0,
                                        ),
                                        stepGranularity: autoSizeStep,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(height: bottomPad),
                              ],
                            );
                          },
                        )
                      : identityBody(display),
                ),
              )
            : showIdle
            ? KeyedSubtree(
                key: const ValueKey('idle_glyph'),
                child: Semantics(
                  container: true,
                  label: 'Waiting for input',
                  hint: 'Open Explore.',
                  button: true,
                  onTap: openExplore,
                  onTapHint: 'Open Explore',
                  child: ExcludeSemantics(child: idleGlyph()),
                ),
              )
            : KeyedSubtree(
                key: const ValueKey('placeholder'),
                child: Semantics(
                  container: true,
                  label: 'No input',
                  hint: 'Open Explore.',
                  button: true,
                  onTap: openExplore,
                  onTapHint: 'Open Explore',
                  child: ExcludeSemantics(child: placeholderText(primaryStyle)),
                ),
              ),
      );
    }

    return Card(
      elevation: 0,
      color: cs.primary,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(ExploreChordPage.route(seedIdentity: exploreSeedIdentity)),
        onLongPress: display == null
            ? null
            : () => showAnalysisDetailsSheet(context, identity: display),
        borderRadius: cardBorderRadius,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minCardHeight),
          child: Padding(
            padding: padding,
            child: fill
                ? SizedBox.expand(child: switchedChild())
                : switchedChild(),
          ),
        ),
      ),
    );
  }
}

TextSpan _chordDisplaySpan({
  required ChordSymbol symbol,
  required NoteNameSystem noteNameSystem,
  required TextStyle primaryStyle,
  required TextStyle rootStyle,
  required TextStyle chordDetailStyle,
}) {
  final display = chordSymbolDisplayParts(
    symbol,
    noteNameSystem: noteNameSystem,
  );

  return TextSpan(
    style: primaryStyle,
    children: <InlineSpan>[
      TextSpan(text: display.root, style: rootStyle),
      if (display.quality.isNotEmpty) ...[
        TextSpan(text: display.quality, style: chordDetailStyle),
      ],
      if (display.hasBass) ...[
        TextSpan(text: ' / ', style: chordDetailStyle),
        TextSpan(text: display.bassRequired, style: chordDetailStyle),
      ],
    ],
  );
}
