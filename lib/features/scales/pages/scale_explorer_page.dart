import 'dart:async';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/audio/audio.dart';
import 'package:whatchord_app/features/chords/chords.dart';
import 'package:whatchord_app/features/home/home.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/piano/piano.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../models/scale_menu.dart';
import '../providers/scale_preferences_notifier.dart';
import '../services/scale_explorer_selection.dart';
import '../widgets/scale_degree_chord_list.dart';
import '../widgets/scale_explorer_content_layout.dart';
import '../widgets/scale_explorer_top_bar.dart';
import '../widgets/scale_picker.dart';
import '../widgets/scale_tone_strip.dart';

enum _ScaleView { scales, chords }

const _chordHarmonyUnavailableMessage =
    'Chords are not available for this scale.';

class ScaleExplorerPage extends ConsumerStatefulWidget {
  const ScaleExplorerPage({
    super.key,
    this.seedPresentation,
    this.hasExploreParent = false,
  });

  /// Chord to pre-select a degree from when the page opens. When null the page
  /// falls back to the live sounding chord, so opening from the home page seeds
  /// the current performance. Explore Chords passes its built chord here so it
  /// seeds the same way rather than reaching back to stale live input.
  final ChordPresentation? seedPresentation;

  /// Whether another Explore page is directly beneath this route.
  final bool hasExploreParent;

  static Route<void> route({
    ChordPresentation? seedPresentation,
    bool hasExploreParent = false,
  }) {
    return MaterialPageRoute<void>(
      builder: (_) => ScaleExplorerPage(
        seedPresentation: seedPresentation,
        hasExploreParent: hasExploreParent,
      ),
    );
  }

  @override
  ConsumerState<ScaleExplorerPage> createState() => _ScaleExplorerPageState();
}

class _ScaleExplorerPageState extends ConsumerState<ScaleExplorerPage> {
  late List<Tonic> _tonicChoices;
  late Tonic _tonic;
  late ScaleMenuEntry _scale;
  bool _showSevenths = false;
  int? _selectedOrdinal;
  _ScaleView _view = _ScaleView.chords;
  late bool _hasExploreParent;

  late final PreviewAnimationController _preview;
  PreviewAnimationState _previewState = PreviewAnimationState.idle;

  ScaleKind get _kind => _scale.kind;

  @override
  void initState() {
    super.initState();
    _hasExploreParent = widget.hasExploreParent;
    final tonality = ref.read(selectedTonalityProvider);
    final presentation =
        widget.seedPresentation ?? ref.read(chordPresentationProvider);
    final analysis = presentation?.scaleDegreeAnalysis;
    _scale = seedScaleEntry(_seedKindFor(tonality, analysis));
    _tonicChoices = tonicChoicesForKind(_kind);
    _tonic = resolveScaleExplorerTonic(
      choices: _tonicChoices,
      pitchClass: tonality.tonic.pitchClass,
      exact: tonality.tonic,
      preferFlat: tonality.keySignature.prefersFlats,
    );
    _seedSelectionFromChord(presentation, analysis);
    _preview = PreviewAnimationController(
      onChanged: (state) {
        if (!mounted) return;
        setState(() => _previewState = state);
      },
    );
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scale = Scale(_tonic, _kind);
    final tones = ScaleToneBuilder.build(scale);
    final harmony = scale.kind.supportsChordHarmony
        ? ScaleHarmonizer.harmonize(scale)
        : null;
    final notation = ref.watch(chordNotationStyleProvider);
    final noteNameSystem = ref.watch(noteNameSystemProvider);
    final showDegrees = ref.watch(showScaleDegreesProvider);

    final selectedChord = selectedDegreeChordMidi(
      scale: scale,
      harmony: harmony,
      selectedOrdinal: _selectedOrdinal,
      showSevenths: _showSevenths,
    );
    final playing = _previewState.isRunning;
    final liveNotes = ref.watch(liveSoundingNoteNumbersProvider);

    // During playback the keyboard tracks the sounding notes; at rest it holds
    // live input when present, otherwise the selected chord (and is blank after
    // a scale run, which clears the selection).
    final keyboardNotes = playing
        ? _previewState.activeNotes
        : liveNotes.isNotEmpty
        ? liveNotes
        : selectedChord;
    final playingPitchClasses = playing
        ? {for (final n in _previewState.activeNotes) n % 12}
        : const <int>{};
    // The selected chord's members keep their outline throughout playback; the
    // rolling fill (playing) layers on top per chip.
    final memberPitchClasses = {for (final n in selectedChord) n % 12};

    final scalePitchClasses = scale.pitchClasses.toSet();
    final scaleNotes = <int>{
      for (
        int midi = PianoGeometry.fullKeyboardLowestMidi;
        midi <= PianoGeometry.fullKeyboardHighestMidi;
        midi++
      )
        if (scalePitchClasses.contains(midi % 12)) midi,
    };

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
                  child: ScaleExplorerTopBar(
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
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                horizontalInset,
                                16,
                                horizontalInset,
                                12,
                              ),
                              child: _buildContent(
                                scale: scale,
                                tones: tones,
                                harmony: harmony,
                                notation: notation,
                                noteNameSystem: noteNameSystem,
                                showDegrees: showDegrees,
                                playingPitchClasses: playingPitchClasses,
                                memberPitchClasses: memberPitchClasses,
                                isLandscape: isLandscape,
                              ),
                            ),
                          ),
                          ResizableKeyboardArea(
                            config: config,
                            maxKeyboardHeight: maxKeyboardHeightForLayout(
                              availableHeight: bodyConstraints.maxHeight,
                              isLandscape: isLandscape,
                              reservedChrome: kPianoSeparatorLineHeight + 1,
                            ),
                            highlightedNotes: keyboardNotes,
                            scaleNotes: scaleNotes,
                            tonicPitchClass: scale.tonic.pitchClass,
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

  Widget _buildContent({
    required Scale scale,
    required ScaleToneSet tones,
    required ScaleHarmony? harmony,
    required ChordNotationStyle notation,
    required NoteNameSystem noteNameSystem,
    required bool showDegrees,
    required Set<int> playingPitchClasses,
    required Set<int> memberPitchClasses,
    required bool isLandscape,
  }) {
    final scaleName =
        '${noteDisplayLabel(scale.tonic.label, noteNameSystem: noteNameSystem)}'
        ' ${_scale.headerLabel} scale';
    final chordTonality = Tonality(scale.tonic, TonalityMode.major);
    final copyChoices = [
      CopyChoice(
        title: 'Scale name',
        icon: Icons.label_outline,
        value: scaleName,
        copiedLabel: 'scale name',
      ),
      CopyChoice(
        title: 'Scale tones',
        icon: Icons.piano,
        value: [
          for (final tone in tones.tones)
            noteDisplayLabel(tone.name, noteNameSystem: noteNameSystem),
        ].join('-'),
        copiedLabel: 'scale tones',
      ),
      CopyChoice(
        title: 'Scale formula',
        icon: Icons.numbers,
        value: tones.degreeLabels.join(', '),
        copiedLabel: 'scale formula',
      ),
      if (harmony != null)
        CopyChoice(
          title: 'Diatonic chords',
          icon: Icons.music_note,
          value: [
            for (final degree in harmony.degrees)
              '${_showSevenths ? degree.seventhRoman : degree.triadRoman} '
                  '${scaleDegreeChordSymbol(degree: degree, showSevenths: _showSevenths, tonality: chordTonality, notation: notation, noteNameSystem: noteNameSystem)}',
          ].join(', '),
          copiedLabel: 'diatonic chords',
        ),
    ];

    final header = Row(
      children: [
        CircularPlayButton(
          label: 'Play scale',
          tapHint: 'Play the scale up and down',
          onPressed: () => _onPlayScale(scale),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ScaleHeader(
            scale: scale,
            kindLabel: _scale.headerLabel,
            noteNameSystem: noteNameSystem,
            functionLabel: selectedScaleDegreeFunctionLabel(
              scale: scale,
              selectedOrdinal: _selectedOrdinal,
              supportsChordHarmony: scale.kind.supportsChordHarmony,
            ),
            copyChoices: copyChoices,
          ),
        ),
      ],
    );

    final toneRow = Row(
      children: [
        NameDegreeToggleButton(
          showDegrees: showDegrees,
          onPressed: () => unawaited(
            ref
                .read(showScaleDegreesProvider.notifier)
                .setShowDegrees(!showDegrees),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ScaleToneStrip(
            tones: tones,
            noteNameSystem: noteNameSystem,
            showDegrees: showDegrees,
            playingPitchClasses: playingPitchClasses,
            memberPitchClasses: memberPitchClasses,
          ),
        ),
      ],
    );

    final tonicWheel = CyclicWheel<Tonic>(
      label: 'Tonic',
      value: _tonic,
      choices: _tonicChoices,
      displayLabelFor: (tonic) =>
          noteDisplayLabel(tonic.label, noteNameSystem: noteNameSystem),
      semanticLabelFor: (tonic) =>
          noteSemanticLabel(tonic.label, noteNameSystem: noteNameSystem),
      targetItemWidth: 72,
      selectedMinWidth: 46,
      unselectedMinWidth: 40,
      selectedHorizontalPadding: 8,
      unselectedHorizontalPadding: 4,
      onChanged: _onTonicChanged,
    );

    final supportsChordHarmony = harmony != null;
    final effectiveView = supportsChordHarmony || _view != _ScaleView.chords
        ? _view
        : _ScaleView.scales;
    final viewControl = Row(
      children: [
        Semantics(
          label: 'Scale explorer view',
          hint: supportsChordHarmony
              ? 'Choose scales or chords'
              : 'Chords disabled. $_chordHarmonyUnavailableMessage',
          child: SegmentedButton<_ScaleView>(
            // Styling comes from the app's segmentedButtonTheme so this toggle
            // shares the selection accent used across the app.
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(
                value: _ScaleView.scales,
                icon: Icon(Icons.stairs_outlined),
                label: Text('Scales'),
              ),
              ButtonSegment(
                value: _ScaleView.chords,
                icon: const Icon(Icons.music_note),
                label: const Text('Chords'),
                enabled: supportsChordHarmony,
                tooltip: supportsChordHarmony
                    ? null
                    : _chordHarmonyUnavailableMessage,
              ),
            ],
            selected: {effectiveView},
            onSelectionChanged: (selection) =>
                setState(() => _view = selection.first),
          ),
        ),
        const Spacer(),
        if (effectiveView == _ScaleView.chords && harmony != null)
          _SeventhsToggle(
            showSevenths: _showSevenths,
            onShowSeventhsChanged: (value) =>
                setState(() => _showSevenths = value),
          ),
      ],
    );

    final chordsList = harmony == null
        ? const SizedBox.shrink()
        : ScaleDegreeChordList(
            harmony: harmony,
            tonality: chordTonality,
            notation: notation,
            noteNameSystem: noteNameSystem,
            showSevenths: _showSevenths,
            selectedOrdinal: _selectedOrdinal,
            onDegreeTap: _onDegreeSelect,
            onDegreePlay: (degree) => _onDegreePlay(scale, degree),
            onDegreeExplore: _openSelectedChord,
          );

    return ScaleExplorerContentLayout(
      isLandscape: isLandscape,
      showScalePicker: effectiveView == _ScaleView.scales,
      header: header,
      toneRow: toneRow,
      tonicWheel: tonicWheel,
      viewControl: viewControl,
      chordsList: chordsList,
      scalePicker: ({required scrollable}) => ScalePicker(
        selected: _scale,
        scrollable: scrollable,
        onChanged: _onScaleChanged,
      ),
    );
  }

  /// The scale to seed onto for [tonality]. Major keys seed the major scale and
  /// minor keys seed natural minor, except when the seeding chord matched the
  /// key's harmonic minor harmony: then harmonic minor is seeded so the
  /// explorer opens on the same scale the home page's scale-degree strip
  /// adjusted to.
  static ScaleKind _seedKindFor(
    Tonality tonality,
    ScaleDegreeAnalysis? analysis,
  ) {
    if (tonality.isMajor) return ScaleKind.major;
    if (analysis?.source == ScaleDegreeSource.harmonicMinor) {
      return ScaleKind.harmonicMinor;
    }
    return ScaleKind.aeolian;
  }

  /// Pre-selects the degree of the seeding chord so opening the explorer lands
  /// on that chord (e.g. a G7 in C major seeds the V7). The chord is the one
  /// passed in via [ScaleExplorerPage.seedPresentation], or the live sounding
  /// chord when none was given. Only seeds when the chord is diatonic to the
  /// seeded scale, i.e. its source matches the seeded mode; otherwise nothing
  /// is selected and the page opens on the bare tonic/mode.
  void _seedSelectionFromChord(
    ChordPresentation? presentation,
    ScaleDegreeAnalysis? analysis,
  ) {
    if (presentation == null || analysis == null) return;

    final seededSource = switch (_kind) {
      ScaleKind.major => ScaleDegreeSource.major,
      ScaleKind.harmonicMinor => ScaleDegreeSource.harmonicMinor,
      _ => ScaleDegreeSource.naturalMinor,
    };
    if (analysis.source != seededSource) return;

    _selectedOrdinal = analysis.degree.index + 1;
    _showSevenths = presentation.identity.quality.isSeventhFamily;
    _view = _ScaleView.chords;
  }

  void _onDegreeSelect(ScaleDegreeHarmony degree) {
    _preview.cancel();
    setState(() {
      _selectedOrdinal = _selectedOrdinal == degree.ordinal
          ? null
          : degree.ordinal;
    });
  }

  void _onDegreePlay(Scale scale, ScaleDegreeHarmony degree) {
    setState(() => _selectedOrdinal = degree.ordinal);
    final notes = degreeChordMidi(scale, degree, seventh: _showSevenths);
    _preview.startChord(notes);
    ref.read(audioMonitorNotifier.notifier).playRolledPreviewNotes(notes);
  }

  void _openSelectedChord(ScaleDegreeHarmony degree) {
    _preview.cancel();
    final quality = _showSevenths ? degree.seventhQuality : degree.triadQuality;
    final navigator = Navigator.of(context);
    if (_hasExploreParent) {
      // Keep only the current Explore context before opening the next one.
      navigator.removeRouteBelow(ModalRoute.of(context)!);
      _hasExploreParent = false;
    }
    unawaited(
      navigator.push(
        ExploreChordPage.route(
          seedIdentity: ChordIdentity(
            rootPc: degree.rootPc,
            bassPc: degree.rootPc,
            quality: quality,
            presentIntervalsMask: quality.canonicalMask,
          ),
          seedRoot: Tonic.tryFromLabel(degree.rootName),
          hasExploreParent: true,
        ),
      ),
    );
  }

  void _onPlayScale(Scale scale) {
    setState(() => _selectedOrdinal = null);
    final notes = scaleRunMidi(scale);
    _preview.startRun(notes);
    ref.read(audioMonitorNotifier.notifier).playSequencePreviewNotes(notes);
  }

  void _onTonicChanged(Tonic tonic) {
    if (tonic == _tonic) return;
    _preview.cancel();
    // The selected degree is mode-relative, so it stays valid as the tonic
    // moves; keep it so scrubbing transposes the selected chord.
    setState(() => _tonic = tonic);
  }

  void _onScaleChanged(ScaleMenuEntry entry) {
    if (entry == _scale) return;
    _preview.cancel();
    setState(() {
      final pitchClass = _tonic.pitchClass;
      if (!keepsSelectedOrdinalForScaleChange(
        current: _scale.kind,
        next: entry.kind,
      )) {
        _selectedOrdinal = null;
      }
      if (!entry.kind.supportsChordHarmony) {
        _view = _ScaleView.scales;
      }
      _scale = entry;
      // The valid spellings differ by mode (e.g. Cb major but not Cb lydian),
      // so rebuild the choices and keep the root pitch class, re-spelled to a
      // tonic this mode actually offers.
      _tonicChoices = tonicChoicesForKind(entry.kind);
      _tonic = resolveScaleExplorerTonic(
        choices: _tonicChoices,
        pitchClass: pitchClass,
        exact: _tonic,
        preferFlat: _tonic.isFlat,
      );
    });
  }
}

class _ScaleHeader extends StatelessWidget {
  const _ScaleHeader({
    required this.scale,
    required this.kindLabel,
    required this.noteNameSystem,
    required this.functionLabel,
    required this.copyChoices,
  });

  final Scale scale;

  /// The selected entry's name, already cased for a heading after the tonic
  /// (e.g. "major" or "Ionian"), so the header matches the picked row rather
  /// than the kind's single conventional label.
  final String kindLabel;

  final NoteNameSystem noteNameSystem;

  /// Role and resolution tendency of the selected degree, or null when none is
  /// selected (the line is still laid out so the header height stays fixed).
  final String? functionLabel;

  /// Scale-level texts offered by the copy dialog (scale name, tones, degrees),
  /// reached by tapping the header, mirroring the chord summary's copy menu.
  final List<CopyChoice> copyChoices;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final baseStyle = textTheme.headlineSmall?.copyWith(height: 1.0);
    final tonicStyle = baseStyle?.copyWith(
      color: cs.onSurface,
      fontWeight: FontWeight.w500,
      fontSize: (baseStyle.fontSize ?? 20) + 6,
    );
    final restStyle = baseStyle?.copyWith(
      color: cs.onSurface.withValues(alpha: 0.74),
    );

    final tonicLabel = noteDisplayLabel(
      scale.tonic.label,
      noteNameSystem: noteNameSystem,
    );
    final tonicSemanticLabel = noteSemanticLabel(
      scale.tonic.label,
      noteNameSystem: noteNameSystem,
    );

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              tonicLabel,
              style: tonicStyle,
              maxLines: 1,
              // Forced strut keeps the line height constant whether or not
              // the tonic carries an accidental, so the play button doesn't
              // shift while scrubbing. Anchoring it to the fixed-size tonic
              // lets the suffix shrink without disturbing the row height.
              strutStyle: StrutStyle(
                fontSize: tonicStyle?.fontSize,
                height: 1.0,
                forceStrutHeight: true,
              ),
            ),
            // Naming the scale explicitly keeps a seeded heading like
            // "C major" from reading as the chord of the same name on a
            // page that otherwise mirrors Explore Chords. Only this suffix
            // shrinks to fit, so the tonic stays at full size.
            Expanded(
              child: AutoSizeText(
                ' $kindLabel scale',
                style: restStyle,
                maxLines: 1,
                minFontSize: 13,
                stepGranularity: 0.5,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Always rendered (a space when empty) so selecting or clearing a
        // degree never changes the header height.
        AutoSizeText(
          functionLabel ?? ' ',
          style: textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
          maxLines: 1,
          minFontSize: 13,
          stepGranularity: 0.5,
          overflow: TextOverflow.ellipsis,
          strutStyle: StrutStyle(
            fontSize: textTheme.bodyLarge?.fontSize,
            forceStrutHeight: true,
          ),
        ),
      ],
    );

    final semanticLabel = functionLabel == null
        ? '$tonicSemanticLabel $kindLabel scale'
        : '$tonicSemanticLabel $kindLabel scale. $functionLabel';

    return Semantics(
      container: true,
      header: true,
      label: semanticLabel,
      onTap: () =>
          unawaited(showCopyChoiceDialog(context, choices: copyChoices)),
      onTapHint: 'Choose scale details to copy',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          excludeFromSemantics: true,
          onTap: () =>
              unawaited(showCopyChoiceDialog(context, choices: copyChoices)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: details),
              Padding(
                padding: const EdgeInsets.all(9),
                child: Icon(
                  Icons.copy_outlined,
                  size: 18,
                  color: cs.onSurface.withValues(alpha: 0.38),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SeventhsToggle extends StatelessWidget {
  const _SeventhsToggle({
    required this.showSevenths,
    required this.onShowSeventhsChanged,
  });

  final bool showSevenths;
  final ValueChanged<bool> onShowSeventhsChanged;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: 'Show seventh chords',
      toggled: showSevenths,
      button: true,
      onTap: () => onShowSeventhsChanged(!showSevenths),
      child: ExcludeSemantics(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => onShowSeventhsChanged(!showSevenths),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(start: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('7ths', style: textTheme.labelLarge),
                IgnorePointer(
                  child: Switch(
                    value: showSevenths,
                    onChanged: onShowSeventhsChanged,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
