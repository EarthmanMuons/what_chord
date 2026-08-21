import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/features/piano/piano.dart';

// Android keeps the system status bar visible in landscape, leaving less
// vertical room than iOS. These constants reclaim pixels from the chrome.
const kAndroidLandscapeToolbarHeight = 52.0;
const kAndroidLandscapeToolbarBottomInset = 4.0;

enum HomeSizeClass { compact, medium, expanded }

const _compactVisibleWhiteKeyCount = 21;
const _fullKeyboardWhiteKeyCount = PianoGeometry.fullKeyboardWhiteKeyCount;
const _keyboardLowestMidiNote = 21; // A0
const _adaptiveMinWhiteKeyWidth = 18.0;

const _mediumIdentityCardTextScale = 1.2;
const _expandedIdentityTextScale = 1.6;
const _mediumAlternativeTextScale = 1.15;
const _expandedAlternativeTextScale = 1.3;
const _mediumInputDisplayVisualScale = 1.15;
const _expandedInputDisplayVisualScale = 1.28;
const _mediumTonalityButtonTextScale = 1.08;
const _expandedTonalityButtonTextScale = 1.16;
const _mediumScaleDegreesTextScale = 1.1;
const _expandedScaleDegreesTextScale = 1.18;
const _mediumMiddleCLabelTextScale = 1.12;
const _expandedMiddleCLabelTextScale = 1.2;

@immutable
class HomeSideSheetConfig {
  final double widthFactor;
  final double minWidth;
  final double maxWidth;
  final double portraitHeightFactor;
  final double landscapeHeightFactor;
  final double minHeight;
  final double verticalMargin;

  const HomeSideSheetConfig({
    required this.widthFactor,
    required this.minWidth,
    required this.maxWidth,
    required this.portraitHeightFactor,
    required this.landscapeHeightFactor,
    required this.minHeight,
    required this.verticalMargin,
  });
}

@immutable
class HomeLayoutConfig {
  final HomeSizeClass sizeClass;
  final bool isLandscape;

  bool get tightenForStatusBar =>
      isLandscape && defaultTargetPlatform == TargetPlatform.android;

  // Analysis
  final EdgeInsets analysisPadding;
  final double chordCardMaxWidth;
  final EdgeInsets detailsSectionPadding; // right panel (landscape)
  final EdgeInsets inputDisplayPadding;
  final double analysisCardPreferredWidth;
  final double analysisCardHeight;
  final double analysisCardMaxHeight;
  final double analysisTopPadMin;
  final double analysisTopPadMax;
  final double analysisListGap;
  final double identityCardTextScale;
  final double alternativeTextScale;
  final double inputDisplayVisualScale;
  final double tonalityButtonTextScale;
  final double scaleDegreesTextScale;
  final double middleCLabelTextScale;

  // Keyboard
  final int whiteKeyCount;
  final double whiteKeyAspectRatio;
  final int firstMidiNote;

  const HomeLayoutConfig({
    required this.sizeClass,
    required this.isLandscape,
    required this.analysisPadding,
    required this.chordCardMaxWidth,
    required this.detailsSectionPadding,
    required this.inputDisplayPadding,
    required this.analysisCardPreferredWidth,
    required this.analysisCardHeight,
    required this.analysisCardMaxHeight,
    required this.analysisTopPadMin,
    required this.analysisTopPadMax,
    required this.analysisListGap,
    required this.identityCardTextScale,
    required this.alternativeTextScale,
    required this.inputDisplayVisualScale,
    required this.tonalityButtonTextScale,
    required this.scaleDegreesTextScale,
    required this.middleCLabelTextScale,
    required this.whiteKeyCount,
    this.whiteKeyAspectRatio = 7.0,
    required this.firstMidiNote,
  });
}

/// Largest height the resizable keyboard may occupy in the current layout.
///
/// [availableHeight] is the body region shared by the page content and the
/// keyboard. [reservedChrome] is the height of everything the keyboard region
/// stacks above the keys (e.g. a tonality bar + divider) plus any sibling chrome
/// outside the region that must keep its space (e.g. the portrait input display).
/// The resize handle and a per-orientation content minimum are reserved here so
/// growing the keyboard can never starve the content above it.
///
/// [minContent] is the floor reserved for the page content above the keyboard;
/// when null it defaults per orientation. Pages with a fixed-size hero element
/// (the home identity card) should pass a value large enough to keep it intact,
/// e.g. via [portraitAnalysisMinContent].
///
/// The resize handle is overlaid on the keyboard's top edge, so it is not
/// reserved here. The result may be small or negative on short screens; callers
/// feed it to [resolvePianoViewMetrics], which floors the ceiling at the base
/// height so the keyboard simply stops growing rather than overflowing.
double maxKeyboardHeightForLayout({
  required double availableHeight,
  required bool isLandscape,
  required double reservedChrome,
  double? minContent,
}) {
  final resolvedMinContent = minContent ?? (isLandscape ? 96.0 : 150.0);
  return availableHeight - reservedChrome - resolvedMinContent;
}

/// Room reserved below the identity card (portrait) for the alternative list.
/// The card rises into its top padding as the keyboard grows
/// so this stays visible; once the top padding bottoms out, the list yields.
const double kPortraitAlternativeListReserve = 60.0;

/// Height of the separator band drawn above the keyboard (the resize splitter
/// sits on it just above the 1px felt line, reading as one splitter line). Layout
/// space, so the keyboard's felt stays visible below it.
const double kPianoSeparatorLineHeight = 7.0;

/// Minimum portrait analysis-lane height that keeps the identity card fully
/// visible with its smallest top padding and room for the alternatives
/// list, so an enlarged keyboard can never squeeze the card into the input
/// chips below it.
double portraitAnalysisMinContent(HomeLayoutConfig config) {
  return config.analysisPadding.vertical +
      config.analysisCardHeight +
      config.analysisTopPadMin +
      config.analysisListGap +
      kPortraitAlternativeListReserve;
}

HomeSizeClass homeSizeClassForSize(Size size) {
  final shortestSide = size.shortestSide;
  if (shortestSide >= 900) return HomeSizeClass.expanded;
  if (shortestSide >= 600) return HomeSizeClass.medium;
  return HomeSizeClass.compact;
}

HomeSizeClass homeSizeClassFor(BoxConstraints constraints) {
  return homeSizeClassForSize(constraints.biggest);
}

HomeSideSheetConfig homeSideSheetConfigForSizeClass(HomeSizeClass sizeClass) {
  return switch (sizeClass) {
    HomeSizeClass.compact => const HomeSideSheetConfig(
      widthFactor: 0.9,
      minWidth: 320,
      maxWidth: 480,
      portraitHeightFactor: 0.92,
      landscapeHeightFactor: 0.94,
      minHeight: 320,
      verticalMargin: 8,
    ),
    HomeSizeClass.medium => const HomeSideSheetConfig(
      widthFactor: 0.48,
      minWidth: 360,
      maxWidth: 540,
      portraitHeightFactor: 0.78,
      landscapeHeightFactor: 0.88,
      minHeight: 340,
      verticalMargin: 10,
    ),
    HomeSizeClass.expanded => const HomeSideSheetConfig(
      widthFactor: 0.42,
      minWidth: 400,
      maxWidth: 620,
      portraitHeightFactor: 0.82,
      landscapeHeightFactor: 0.9,
      minHeight: 360,
      verticalMargin: 12,
    ),
  };
}

HomeLayoutConfig resolveHomeLayoutConfig(BoxConstraints constraints) {
  final isLandscape = constraints.maxWidth > constraints.maxHeight;
  final sizeClass = homeSizeClassFor(constraints);
  final base = switch ((isLandscape, sizeClass)) {
    (false, HomeSizeClass.compact) => portraitCompactLayoutConfig,
    (false, HomeSizeClass.medium) => portraitMediumLayoutConfig,
    (false, HomeSizeClass.expanded) => portraitExpandedLayoutConfig,
    (true, HomeSizeClass.compact) => landscapeCompactLayoutConfig,
    (true, HomeSizeClass.medium) => landscapeMediumLayoutConfig,
    (true, HomeSizeClass.expanded) => landscapeExpandedLayoutConfig,
  };

  final whiteKeyCount = _resolveVisibleWhiteKeyCount(
    constraints: constraints,
    isLandscape: isLandscape,
    sizeClass: sizeClass,
  );

  if (base.whiteKeyCount == whiteKeyCount) return base;

  return HomeLayoutConfig(
    sizeClass: base.sizeClass,
    isLandscape: base.isLandscape,
    analysisPadding: base.analysisPadding,
    chordCardMaxWidth: base.chordCardMaxWidth,
    detailsSectionPadding: base.detailsSectionPadding,
    inputDisplayPadding: base.inputDisplayPadding,
    analysisCardPreferredWidth: base.analysisCardPreferredWidth,
    analysisCardHeight: base.analysisCardHeight,
    analysisCardMaxHeight: base.analysisCardMaxHeight,
    analysisTopPadMin: base.analysisTopPadMin,
    analysisTopPadMax: base.analysisTopPadMax,
    analysisListGap: base.analysisListGap,
    identityCardTextScale: base.identityCardTextScale,
    alternativeTextScale: base.alternativeTextScale,
    inputDisplayVisualScale: base.inputDisplayVisualScale,
    tonalityButtonTextScale: base.tonalityButtonTextScale,
    scaleDegreesTextScale: base.scaleDegreesTextScale,
    middleCLabelTextScale: base.middleCLabelTextScale,
    whiteKeyCount: whiteKeyCount,
    whiteKeyAspectRatio: base.whiteKeyAspectRatio,
    firstMidiNote: base.firstMidiNote,
  );
}

int _resolveVisibleWhiteKeyCount({
  required BoxConstraints constraints,
  required bool isLandscape,
  required HomeSizeClass sizeClass,
}) {
  if (isLandscape) return _fullKeyboardWhiteKeyCount;
  if (sizeClass == HomeSizeClass.compact) return _compactVisibleWhiteKeyCount;

  return PianoGeometry.visibleWhiteKeyCountForViewport(
    viewportWidth: constraints.maxWidth,
    minWhiteKeyWidth: _adaptiveMinWhiteKeyWidth,
    minVisibleWhiteKeyCount: _compactVisibleWhiteKeyCount,
    maxVisibleWhiteKeyCount: _fullKeyboardWhiteKeyCount,
  );
}

const portraitCompactLayoutConfig = HomeLayoutConfig(
  sizeClass: HomeSizeClass.compact,
  isLandscape: false,
  analysisPadding: EdgeInsets.fromLTRB(16, 16, 16, 16),
  chordCardMaxWidth: 520,
  detailsSectionPadding: EdgeInsets.zero,
  inputDisplayPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  analysisCardPreferredWidth: 320,
  analysisCardHeight: 180,
  analysisCardMaxHeight: 172,
  analysisTopPadMin: 32,
  analysisTopPadMax: 82,
  analysisListGap: 18,
  identityCardTextScale: 1.0,
  alternativeTextScale: 1.0,
  inputDisplayVisualScale: 1.0,
  tonalityButtonTextScale: 1.0,
  scaleDegreesTextScale: 1.0,
  middleCLabelTextScale: 1.0,
  whiteKeyCount: _compactVisibleWhiteKeyCount,
  whiteKeyAspectRatio: 7.0,
  firstMidiNote: 48, // C3
);

const portraitMediumLayoutConfig = HomeLayoutConfig(
  sizeClass: HomeSizeClass.medium,
  isLandscape: false,
  analysisPadding: EdgeInsets.fromLTRB(24, 20, 24, 20),
  chordCardMaxWidth: 680,
  detailsSectionPadding: EdgeInsets.zero,
  inputDisplayPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 10),
  analysisCardPreferredWidth: 440,
  analysisCardHeight: 240,
  analysisCardMaxHeight: 240,
  analysisTopPadMin: 40,
  analysisTopPadMax: 92,
  analysisListGap: 20,
  identityCardTextScale: _mediumIdentityCardTextScale,
  alternativeTextScale: _mediumAlternativeTextScale,
  inputDisplayVisualScale: _mediumInputDisplayVisualScale,
  tonalityButtonTextScale: _mediumTonalityButtonTextScale,
  scaleDegreesTextScale: _mediumScaleDegreesTextScale,
  middleCLabelTextScale: _mediumMiddleCLabelTextScale,
  whiteKeyCount: _compactVisibleWhiteKeyCount,
  whiteKeyAspectRatio: 7.0,
  firstMidiNote: 48, // C3
);

const portraitExpandedLayoutConfig = HomeLayoutConfig(
  sizeClass: HomeSizeClass.expanded,
  isLandscape: false,
  analysisPadding: EdgeInsets.fromLTRB(32, 24, 32, 24),
  chordCardMaxWidth: 860,
  detailsSectionPadding: EdgeInsets.zero,
  inputDisplayPadding: EdgeInsets.symmetric(horizontal: 32, vertical: 10),
  analysisCardPreferredWidth: 620,
  analysisCardHeight: 340,
  analysisCardMaxHeight: 340,
  analysisTopPadMin: 48,
  analysisTopPadMax: 108,
  analysisListGap: 24,
  identityCardTextScale: 1.55,
  alternativeTextScale: _expandedAlternativeTextScale,
  inputDisplayVisualScale: _expandedInputDisplayVisualScale,
  tonalityButtonTextScale: _expandedTonalityButtonTextScale,
  scaleDegreesTextScale: _expandedScaleDegreesTextScale,
  middleCLabelTextScale: _expandedMiddleCLabelTextScale,
  whiteKeyCount: _compactVisibleWhiteKeyCount,
  whiteKeyAspectRatio: 7.0,
  firstMidiNote: 48, // C3
);

const landscapeCompactLayoutConfig = HomeLayoutConfig(
  sizeClass: HomeSizeClass.compact,
  isLandscape: true,
  analysisPadding: EdgeInsets.fromLTRB(16, 8, 8, 8),
  chordCardMaxWidth: 520,
  detailsSectionPadding: EdgeInsets.fromLTRB(8, 12, 16, 12),
  inputDisplayPadding: EdgeInsets.zero,
  analysisCardPreferredWidth: 320,
  analysisCardHeight: 132,
  analysisCardMaxHeight: 172,
  analysisTopPadMin: 0,
  analysisTopPadMax: 0,
  analysisListGap: 18,
  identityCardTextScale: 1.0,
  alternativeTextScale: 1.0,
  inputDisplayVisualScale: 1.0,
  tonalityButtonTextScale: 1.0,
  scaleDegreesTextScale: 1.0,
  middleCLabelTextScale: 1.0,
  // Full 88-key view: 52 white keys from A0 (MIDI 21) to C8.
  whiteKeyCount: _fullKeyboardWhiteKeyCount,
  whiteKeyAspectRatio: 7.0,
  firstMidiNote: _keyboardLowestMidiNote,
);

const landscapeMediumLayoutConfig = HomeLayoutConfig(
  sizeClass: HomeSizeClass.medium,
  isLandscape: true,
  analysisPadding: EdgeInsets.fromLTRB(24, 12, 12, 12),
  chordCardMaxWidth: 680,
  detailsSectionPadding: EdgeInsets.fromLTRB(12, 16, 24, 16),
  inputDisplayPadding: EdgeInsets.zero,
  analysisCardPreferredWidth: 460,
  analysisCardHeight: 220,
  analysisCardMaxHeight: 240,
  analysisTopPadMin: 0,
  analysisTopPadMax: 0,
  analysisListGap: 20,
  identityCardTextScale: _mediumIdentityCardTextScale,
  alternativeTextScale: _mediumAlternativeTextScale,
  inputDisplayVisualScale: _mediumInputDisplayVisualScale,
  tonalityButtonTextScale: _mediumTonalityButtonTextScale,
  scaleDegreesTextScale: _mediumScaleDegreesTextScale,
  middleCLabelTextScale: _mediumMiddleCLabelTextScale,
  whiteKeyCount: _fullKeyboardWhiteKeyCount,
  whiteKeyAspectRatio: 7.0,
  firstMidiNote: _keyboardLowestMidiNote,
);

const landscapeExpandedLayoutConfig = HomeLayoutConfig(
  sizeClass: HomeSizeClass.expanded,
  isLandscape: true,
  analysisPadding: EdgeInsets.fromLTRB(32, 16, 16, 16),
  chordCardMaxWidth: 860,
  detailsSectionPadding: EdgeInsets.fromLTRB(16, 20, 32, 20),
  inputDisplayPadding: EdgeInsets.zero,
  analysisCardPreferredWidth: 640,
  analysisCardHeight: 300,
  analysisCardMaxHeight: 320,
  analysisTopPadMin: 0,
  analysisTopPadMax: 0,
  analysisListGap: 24,
  identityCardTextScale: _expandedIdentityTextScale,
  alternativeTextScale: _expandedAlternativeTextScale,
  inputDisplayVisualScale: _expandedInputDisplayVisualScale,
  tonalityButtonTextScale: _expandedTonalityButtonTextScale,
  scaleDegreesTextScale: _expandedScaleDegreesTextScale,
  middleCLabelTextScale: _expandedMiddleCLabelTextScale,
  whiteKeyCount: _fullKeyboardWhiteKeyCount,
  whiteKeyAspectRatio: 7.0,
  firstMidiNote: _keyboardLowestMidiNote,
);
