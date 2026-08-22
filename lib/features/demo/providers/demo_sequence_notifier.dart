import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/features/theory/theory.dart';

import 'demo_mode_variant_notifier.dart';
import 'demo_tour_targets.dart';

final demoSequenceProvider =
    NotifierProvider<DemoSequenceNotifier, DemoSequenceState>(
      DemoSequenceNotifier.new,
    );

final demoCurrentStepProvider = Provider<DemoStep>((ref) {
  final steps = ref.watch(demoStepsProvider);
  final index = ref.watch(demoSequenceProvider.select((state) => state.index));
  if (steps.isEmpty || index < 0 || index >= steps.length) {
    return const DemoStep();
  }
  return steps[index];
});

final demoStepsProvider = Provider<List<DemoStep>>((ref) {
  final variant = ref.watch(demoModeVariantProvider);
  return switch (variant) {
    DemoModeVariant.animation => DemoSequenceNotifier.animationSteps,
    DemoModeVariant.interactive => DemoSequenceNotifier.interactiveSteps,
    DemoModeVariant.screenshot => DemoSequenceNotifier.screenshotSteps,
  };
});

class DemoSequenceState {
  final int index;

  const DemoSequenceState({required this.index});
}

class DemoStep {
  final Set<int>? notes;
  final bool? pedalDown;
  final ThemeMode? themeMode;
  final Tonality? tonality;
  final bool? showChordMemberDegrees;
  final bool? showScaleDegrees;
  final String? promptText;

  /// Home-screen elements this step points at with callout arrows.
  final List<DemoTarget> targets;

  const DemoStep({
    this.notes,
    this.pedalDown,
    this.themeMode,
    this.tonality,
    this.showChordMemberDegrees,
    this.showScaleDegrees,
    this.promptText,
    this.targets = const [],
  });
}

class DemoSequenceNotifier extends Notifier<DemoSequenceState> {
  static final List<DemoStep> animationSteps = <DemoStep>[
    // Dm7 -- ii chord, root position
    const DemoStep(
      notes: {62, 65, 69, 72},
      themeMode: ThemeMode.dark,
      tonality: Tonality(Tonic.c, TonalityMode.major),
    ),
    // G7/B -- V chord, first inversion
    const DemoStep(
      notes: {59, 62, 65, 67},
      themeMode: ThemeMode.dark,
      tonality: Tonality(Tonic.c, TonalityMode.major),
    ),
    // Cmaj7 -- I chord, root position
    const DemoStep(
      notes: {60, 64, 67, 71},
      themeMode: ThemeMode.dark,
      tonality: Tonality(Tonic.c, TonalityMode.major),
    ),
  ];

  static final List<DemoStep> screenshotSteps = <DemoStep>[
    // 1) SCREENSHOT: portrait, light mode, Key: C major -> Dm7, home
    const DemoStep(
      notes: {62, 65, 69, 72},
      themeMode: ThemeMode.light,
      tonality: Tonality(Tonic.c, TonalityMode.major),
    ),

    // 2) SCREENSHOT: portrait, dark mode, Key: C major -> G7/B, Explore Chords
    // Also home screen for website real_time.webp
    const DemoStep(
      notes: {59, 62, 65, 67},
      themeMode: ThemeMode.dark,
      tonality: Tonality(Tonic.c, TonalityMode.major),
      showChordMemberDegrees: true,
    ),

    // 3) SCREENSHOT: portrait, light mode, Key: C major -> C major, Explore Scales
    const DemoStep(
      notes: {60, 64, 67},
      themeMode: ThemeMode.light,
      tonality: Tonality(Tonic.c, TonalityMode.major),
      showScaleDegrees: false,
    ),

    // 4) SCREENSHOT: portrait, dark mode, Key: C major -> Bm7(b5), manual
    // lookup. Exit screenshot demo, open lookup, then enter B, D, F, A.
    const DemoStep(
      notes: {59, 62, 65, 69},
      pedalDown: true,
      themeMode: ThemeMode.dark,
      tonality: Tonality(Tonic.c, TonalityMode.major),
    ),

    // 5) SCREENSHOT: portrait, dark mode, Key: C major -> Bm7(b5),
    // Why This Chord? Open the modal manually from screenshot 4.

    // 6) SCREENSHOT: landscape, light mode, Key: C major -> G7b9, home
    const DemoStep(
      notes: {55, 59, 62, 65, 68},
      themeMode: ThemeMode.light,
      tonality: Tonality(Tonic.c, TonalityMode.major),
    ),

    // 7) SCREENSHOT: portrait, light mode, Key: A minor -> Am7, Explore Chords
    // For website explore_modes.mp4 (chord/scale mode switch)
    const DemoStep(
      notes: {57, 60, 64, 67},
      themeMode: ThemeMode.light,
      tonality: Tonality(Tonic.a, TonalityMode.minor),
      showChordMemberDegrees: true,
    ),

    // 8) SCREENSHOT: portrait, light mode, Key: C major -> Bm7(b5), Why This Chord?
    // For website why_this_chord.webp
    const DemoStep(
      notes: {59, 62, 65, 69},
      pedalDown: true,
      themeMode: ThemeMode.light,
      tonality: Tonality(Tonic.c, TonalityMode.major),
    ),
  ];

  static final List<DemoStep> interactiveSteps = <DemoStep>[
    // 1) Welcome / orientation.
    const DemoStep(
      notes: {},
      tonality: Tonality(Tonic.c, TonalityMode.major),
      promptText: 'Take a quick tour by tapping the card arrows.\nConnect a MIDI device anytime to start playing.',
    ),
    // 2) C major -- a chord is named instantly.
    const DemoStep(
      notes: {60, 64, 67},
      tonality: Tonality(Tonic.c, TonalityMode.major),
      // Trailing newline keeps this at two lines so the prompt height matches
      // the other steps and the layout does not shift when it appears.
      promptText: 'Play notes and WhatChord names the chord instantly.\n',
    ),
    // 3) C6/9 -- inversions and extensions; tap the card to explore.
    const DemoStep(
      notes: {60, 64, 67, 69, 74},
      tonality: Tonality(Tonic.c, TonalityMode.major),
      promptText: 'Inversions and extensions are recognized automatically.\nTap the chord card to explore variations.',
      targets: [DemoTarget.chordCard],
    ),
    // 4) Bm7(b5) -- alternative readings.
    const DemoStep(
      notes: {59, 62, 65, 69},
      tonality: Tonality(Tonic.c, TonalityMode.major),
      promptText: 'Some voicings have more than one reading.\nTap any alternative to see how they were ranked.',
      targets: [DemoTarget.alternatives],
    ),
    // 5) Key context and scales. Dm is the ii of C major, so the scale-degree
    // strip highlights ii -- the key context drives what the display shows.
    const DemoStep(
      notes: {62, 65, 69},
      tonality: Tonality(Tonic.c, TonalityMode.major),
      promptText: 'Set your key so chords are named in context.\nTap the scale strip to explore scales.',
      targets: [DemoTarget.tonalityBar],
    ),
    // 6) No MIDI -- manual lookup.
    const DemoStep(
      notes: {},
      tonality: Tonality(Tonic.c, TonalityMode.major),
      promptText: 'No MIDI device? Tap search to pick notes by name.\nConnect a device anytime to play.',
      targets: [DemoTarget.lookupButton, DemoTarget.midiIcon],
    ),
  ];

  @override
  DemoSequenceState build() {
    ref.listen<DemoModeVariant>(demoModeVariantProvider, (previous, next) {
      if (previous == null || previous == next) return;
      reset();
    });

    return const DemoSequenceState(index: 0);
  }

  void next() => _setIndex(state.index + 1);
  void prev() => _setIndex(state.index - 1);

  void goTo(int index) => _setIndex(index);
  void reset() => goTo(0);

  void _setIndex(int index) {
    final len = ref.read(demoStepsProvider).length;
    if (len == 0) return;

    // The user-facing tour has a clear start and end; only the dev-only
    // screenshot/animation variants wrap around.
    final interactive =
        ref.read(demoModeVariantProvider) == DemoModeVariant.interactive;
    final nextIndex = interactive
        ? index.clamp(0, len - 1)
        : ((index % len) + len) % len;
    state = DemoSequenceState(index: nextIndex);
  }
}
