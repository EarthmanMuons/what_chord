import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/input/input.dart';

import '../../presentation/models/identity_display.dart';
import '../../presentation/services/analysis_details_formatter.dart';
import 'analysis_context_provider.dart';
import 'analysis_mode_provider.dart';
import 'chord_presentation_provider.dart';
import 'displayed_chord_provider.dart';
import 'theory_preferences_notifier.dart';

final identityDisplayProvider = Provider<IdentityDisplay?>((ref) {
  final mode = ref.watch(analysisModeProvider);
  if (mode == AnalysisMode.none) return null;

  final midis = ref.watch(soundingNoteNumbersSortedProvider);
  if (midis.isEmpty) return null;

  final tonality = ref.watch(analysisContextProvider.select((c) => c.tonality));
  final noteNameSystem = ref.watch(noteNameSystemProvider);
  final keyName = tonalityDisplayLabel(
    tonality,
    noteNameSystem: noteNameSystem,
  );

  final appVersion = ref.watch(appVersionProvider).asData?.value;

  switch (mode) {
    case AnalysisMode.single:
      {
        final pc = midis.first % 12;
        final name = noteNameForPitchClass(pc, tonality: tonality);
        final displayName = noteDisplayLabel(
          name,
          noteNameSystem: noteNameSystem,
        );
        final longLabel = NoteLongFormFormatter.format(
          name,
          noteNameSystem: noteNameSystem,
        );

        return NoteDisplay(
          noteName: displayName,
          longLabel: longLabel,
          secondaryLabel: 'Note',
          debugText: analysisDetailsForNote(
            midis: midis,
            keyName: keyName,
            noteName: displayName,
            longLabel: longLabel,
            appVersion: appVersion,
          ),
        );
      }

    case AnalysisMode.dyad:
      {
        if (midis.length < 2) return null;

        final bassMidi = midis.first;
        final upperMidi = midis.last;

        final interval = IntervalFormatter.forMidiNotes(
          bassMidi: bassMidi,
          upperMidi: upperMidi,
          direction: IntervalLabelDirection.fromBass,
        );

        final bassPc = bassMidi % 12;
        final root = noteNameForPitchClass(bassPc, tonality: tonality);
        final displayRoot = noteDisplayLabel(
          root,
          noteNameSystem: noteNameSystem,
        );

        return IntervalDisplay(
          referenceName: displayRoot,
          intervalLabel: interval.long,
          longLabel: interval.long,
          secondaryLabel: 'Interval · above $displayRoot',
          debugText: analysisDetailsForInterval(
            midis: midis,
            keyName: keyName,
            bassMidi: bassMidi,
            upperMidi: upperMidi,
            semitones: interval.semitones,
            intervalLong: interval.long,
            fromRoot: displayRoot,
            appVersion: appVersion,
          ),
        );
      }

    case AnalysisMode.chord:
      {
        final presentation = ref.watch(chordPresentationProvider);
        if (presentation == null) return null;
        final id = presentation.identity;
        final notation = ref.watch(chordNotationStyleProvider);
        final alternatives = ref
            .watch(displayedAlternativeCandidatesProvider)
            .map(
              (c) => chordSymbolTextLabel(
                ChordSymbolBuilder.fromIdentity(
                  identity: c.identity,
                  tonality: tonality,
                  notation: notation,
                ),
                noteNameSystem: noteNameSystem,
              ),
            )
            .toList(growable: false);

        final inversion = InversionFormatter.format(id);
        final secondaryLabel = id.hasImpliedRoot
            ? 'Chord · rootless'
            : (inversion == null || inversion.trim().isEmpty)
            ? 'Chord'
            : 'Chord · $inversion';

        final qualityLabel = id.quality.label(ChordQualityLabelForm.academic);

        final extensions = [...id.extensions]
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

        final extensionLabels = extensions
            .map((e) => toGlyphAccidentals(e.shortLabel))
            .toList();
        final debugText = analysisDetailsForChord(
          midis: midis,
          keyName: keyName,
          chosenSymbol: chordSymbolTextLabel(
            presentation.symbol,
            noteNameSystem: noteNameSystem,
          ),
          longLabel: presentation.longLabel,
          rootPc: id.rootPc,
          quality: qualityLabel,
          extensions: extensionLabels,
          alternatives: alternatives,
          scaleDegreeAnalysis: presentation.scaleDegreeAnalysis,
          members: presentation.members
              .map((m) => noteDisplayLabel(m, noteNameSystem: noteNameSystem))
              .toList(),
          degrees: presentation.memberDegrees.map(toGlyphAccidentals).toList(),
          appVersion: appVersion,
          playingMode: switch (ref.watch(
            analysisContextProvider.select((c) => c.playingContext),
          )) {
            PlayingContext.solo => 'Solo',
            PlayingContext.ensemble => 'Ensemble',
          },
        );

        return ChordDisplay(
          symbol: presentation.symbol,
          longLabel: presentation.longLabel,
          semanticLabel: presentation.semanticLabel,
          secondaryLabel: secondaryLabel,
          debugText: debugText,
        );
      }

    case AnalysisMode.none:
      return null;
  }
});

final heldIdentityDisplayProvider =
    NotifierProvider<HeldIdentityDisplayNotifier, IdentityDisplay?>(
      HeldIdentityDisplayNotifier.new,
    );

/// [identityDisplayProvider] with warmup continuity: while notes sound, the
/// last shown label holds through the display gate's stability window (the
/// note to interval to chord transition would otherwise flash the waiting
/// placeholder for the gate's duration), and it clears when nothing sounds.
class HeldIdentityDisplayNotifier extends Notifier<IdentityDisplay?> {
  @override
  IdentityDisplay? build() {
    ref.listen(identityDisplayProvider, (previous, next) => _refresh());
    ref.listen(
      soundingNoteNumbersSortedProvider,
      (previous, next) => _refresh(),
    );
    return ref.read(identityDisplayProvider);
  }

  /// Deferred between passes like the display gate itself (the same-frame
  /// rebuild rule): listeners fire while a refresh pass may still be
  /// flushing.
  void _refresh() {
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      final display = ref.read(identityDisplayProvider);
      if (display != null) {
        state = display;
        return;
      }
      if (ref.read(soundingNoteNumbersSortedProvider).isEmpty) {
        state = null;
      }
    });
  }
}
