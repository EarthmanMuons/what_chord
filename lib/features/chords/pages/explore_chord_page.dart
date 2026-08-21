import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/audio/audio.dart';
import 'package:whatchord_app/features/home/home.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/scales/scales.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../providers/explore_preferences_notifier.dart';
import '../widgets/explore_chord_members_section.dart';
import '../widgets/explore_controls.dart';
import '../widgets/explore_summary.dart';
import '../widgets/explore_top_bar.dart';

class ExploreChordPage extends ConsumerStatefulWidget {
  const ExploreChordPage({
    super.key,
    required this.seedIdentity,
    this.seedRoot,
    this.hasExploreParent = false,
  });

  final ChordIdentity seedIdentity;
  final Tonic? seedRoot;

  /// Whether another Explore page is directly beneath this route.
  final bool hasExploreParent;

  static Route<void> route({
    required ChordIdentity seedIdentity,
    Tonic? seedRoot,
    bool hasExploreParent = false,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => ExploreChordPage(
        seedIdentity: seedIdentity,
        seedRoot: seedRoot,
        hasExploreParent: hasExploreParent,
      ),
    );
  }

  @override
  ConsumerState<ExploreChordPage> createState() => _ExploreChordPageState();
}

class _ExploreChordPageState extends ConsumerState<ExploreChordPage> {
  late ChordConstruction _state;
  late final PreviewAnimationController _previewAnimationController;
  PreviewAnimationState _previewAnimation = PreviewAnimationState.idle;
  late bool _hasExploreParent;

  @override
  void initState() {
    super.initState();
    _hasExploreParent = widget.hasExploreParent;
    _previewAnimationController = PreviewAnimationController(
      onChanged: (state) {
        if (!mounted) return;
        setState(() {
          _previewAnimation = state;
        });
      },
    );
    final tonality = ref.read(selectedTonalityProvider);
    final seedRoot =
        widget.seedRoot ??
        Tonic.forPitchClass(
          widget.seedIdentity.rootPc,
          preferredLabel: spellChordRoot(
            widget.seedIdentity,
            tonality: tonality,
          ),
        );
    _state = normalizeChordConstruction(
      ChordConstruction.fromIdentity(widget.seedIdentity, root: seedRoot),
    );
  }

  @override
  void dispose() {
    _previewAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tonality = ref.watch(selectedTonalityProvider);
    final notation = ref.watch(chordNotationStyleProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final showChordMemberDegrees = ref.watch(exploreChordMemberDegreesProvider);
    final example = ChordExampleBuilder.build(
      state: _state,
      tonality: tonality,
      notation: notation,
      noteNameSystem: noteNameSystem,
    );
    final presentation = example.presentation;

    final cs = Theme.of(context).colorScheme;
    final previewPitchClasses = {
      for (final midiNote in _previewAnimation.activeNotes) midiNote % 12,
    };
    final liveNotes = ref.watch(liveSoundingNoteNumbersProvider);
    final displayedKeyboardNotes = _previewAnimation.isRunning
        ? _previewAnimation.activeNotes
        : liveNotes.isNotEmpty
        ? liveNotes
        : example.normalizedVoicing.toSet();

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
                  child: ExploreTopBar(
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
                          Expanded(
                            child: _buildMainContent(
                              example: example,
                              presentation: presentation,
                              tonality: tonality,
                              noteNameSystem: noteNameSystem,
                              showChordMemberDegrees: showChordMemberDegrees,
                              previewPitchClasses: previewPitchClasses,
                              isLandscape: isLandscape,
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
                            highlightedNotes: displayedKeyboardNotes,
                            normalHighlightPitchClasses:
                                example.memberPitchClasses,
                            hasTonalityBar: true,
                            topBar: TonalityBar(
                              height: kToolbarHeight,
                              scaleDegreeAnalysis:
                                  presentation.scaleDegreeAnalysis,
                              useDetectedScaleDegrees: false,
                              onScaleDegreesTap: () =>
                                  _openScaleExplorer(presentation),
                              horizontalInset: horizontalInset,
                              keyTextScaleMultiplier:
                                  config.tonalityButtonTextScale,
                              scaleDegreesTextScaleMultiplier:
                                  config.scaleDegreesTextScale,
                            ),
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

  void _openScaleExplorer(ChordPresentation presentation) {
    final navigator = Navigator.of(context);
    if (_hasExploreParent) {
      // Keep only the current Explore context before opening the next one.
      navigator.removeRouteBelow(ModalRoute.of(context)!);
      _hasExploreParent = false;
    }
    unawaited(
      navigator.push(
        ScaleExplorerPage.route(
          seedPresentation: presentation,
          hasExploreParent: true,
        ),
      ),
    );
  }

  Widget _buildMainContent({
    required ChordExample example,
    required ChordPresentation presentation,
    required Tonality tonality,
    required NoteNameSystem noteNameSystem,
    required bool showChordMemberDegrees,
    required Set<int> previewPitchClasses,
    required bool isLandscape,
    required double horizontalInset,
  }) {
    if (isLandscape) {
      return Padding(
        padding: EdgeInsets.fromLTRB(horizontalInset, 16, horizontalInset, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 7,
              child: FadedScrollView(
                padding: const EdgeInsets.only(top: 4, right: 12),
                child: _buildSummaryAndMembers(
                  example: example,
                  presentation: presentation,
                  noteNameSystem: noteNameSystem,
                  showChordMemberDegrees: showChordMemberDegrees,
                  previewPitchClasses: previewPitchClasses,
                ),
              ),
            ),
            Expanded(
              flex: 6,
              child: FadedScrollView(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: _buildControls(
                  example: example,
                  tonality: tonality,
                  noteNameSystem: noteNameSystem,
                  isLandscape: true,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryAndMembers(
            example: example,
            presentation: presentation,
            noteNameSystem: noteNameSystem,
            showChordMemberDegrees: showChordMemberDegrees,
            previewPitchClasses: previewPitchClasses,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: FadedScrollView(
              padding: const EdgeInsets.only(top: 4),
              maintainVisualPositionOnResize: true,
              child: _buildControls(
                example: example,
                tonality: tonality,
                noteNameSystem: noteNameSystem,
                isLandscape: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryAndMembers({
    required ChordExample example,
    required ChordPresentation presentation,
    required NoteNameSystem noteNameSystem,
    required bool showChordMemberDegrees,
    required Set<int> previewPitchClasses,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            CircularPlayButton(
              label: 'Play chord',
              tapHint: 'Play the current Explore chord',
              onPressed: () => _playChord(example.normalizedVoicing),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExploreSummary(
                presentation: presentation,
                chordTones: example.members,
                chordDegrees: example.memberDegrees,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ExploreChordMembersSection(
          members: example.members,
          memberDegrees: example.memberDegrees,
          noteNameSystem: noteNameSystem,
          showDegrees: showChordMemberDegrees,
          onShowDegreesChanged: (value) => unawaited(
            ref
                .read(exploreChordMemberDegreesProvider.notifier)
                .setShowDegrees(value),
          ),
          activePitchClasses: previewPitchClasses,
          memberPitchClasses: example.memberPitchClassesInOrder,
        ),
      ],
    );
  }

  Widget _buildControls({
    required ChordExample example,
    required Tonality tonality,
    required NoteNameSystem noteNameSystem,
    required bool isLandscape,
  }) {
    return ExploreControls(
      state: _state,
      identity: example.identity,
      tonality: tonality,
      noteNameSystem: noteNameSystem,
      isLandscape: isLandscape,
      onRootChanged: (value) =>
          _updateState(constructionWithRoot(_state, value)),
      onBaseQualityChanged: (value) =>
          _updateState(constructionWithBaseQuality(_state, value)),
      onSeventhKindChanged: (value) =>
          _updateState(constructionWithSeventhKind(_state, value)),
      onFifthAlterationChanged: (value) =>
          _updateState(constructionWithFifthAlteration(_state, value)),
      onExtensionsChanged: (value) =>
          _updateState(constructionWithExtensions(_state, value)),
      onBassChanged: (value) =>
          _updateState(constructionWithBass(_state, value)),
    );
  }

  void _updateState(ChordConstruction next) {
    _previewAnimationController.cancel();
    setState(() {
      _state = next;
    });
  }

  void _playChord(List<int> notes) {
    _previewAnimationController.startChord(notes);
    ref.read(audioMonitorNotifier.notifier).playRolledPreviewNotes(notes);
  }
}
