import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/demo/demo.dart';
import 'package:whatchord_app/features/lookup/lookup.dart';
import 'package:whatchord_app/features/midi/midi.dart';

import '../../models/sounding_note.dart';
import '../../providers/input_idle_notifier.dart';
import '../../providers/pedal_state_provider.dart';
import '../../providers/sounding_notes_provider.dart';
import 'input_display_sizing.dart';
import 'input_note_chip.dart';
import 'pedal_indicator.dart';

class InputDisplay extends ConsumerStatefulWidget {
  const InputDisplay({
    super.key,
    required this.padding,
    this.visualScaleMultiplier = 1.0,
    this.lookupButtonKey,
  });
  final EdgeInsets padding;
  final double visualScaleMultiplier;

  /// Optional key on the lookup (search) button, used as a tour callout target.
  final Key? lookupButtonKey;

  @override
  ConsumerState<InputDisplay> createState() => _InputDisplayState();
}

class _InputDisplayState extends ConsumerState<InputDisplay>
    with SingleTickerProviderStateMixin {
  final _notesKey = GlobalKey<SliverAnimatedListState>();
  final _scrollController = ScrollController();
  static const double _fadeWidth = 24.0;
  // Keep the followed chip this far inside the edge so it clears the fade.
  static const double _followMargin = _fadeWidth;
  // Trailing gap between chips; the chip box carries it on its right side only.
  static const double _chipTrailingGap = 8.0;
  // Wait for the insert animation to settle so the chip is full-size before
  // it is measured; also coalesces rapid note-ons to a single follow.
  static const Duration _followSettleDelay = Duration(milliseconds: 160);

  late List<SoundingNote> _notes;
  late bool _pedal;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;

  final Map<String, GlobalKey> _chipKeys = {};
  String? _followNoteId;
  Timer? _followTimer;

  ProviderSubscription<List<SoundingNote>>? _notesSubscription;
  ProviderSubscription<bool>? _pedalSubscription;

  late final AnimationController _pedalCtl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 120), // press
    reverseDuration: const Duration(milliseconds: 90), // release
  );

  late final Animation<double> _press = CurvedAnimation(
    parent: _pedalCtl,
    curve: Curves.easeOutCubic,
    reverseCurve: Curves.easeInCubic,
  );

  // Mechanical travel: small downward press + settle.
  late final Animation<double> _travel = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: -6.0,
        end: 1.5,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 70,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.5,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeOutCubic)),
      weight: 30,
    ),
  ]).animate(_press);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.25,
    end: 1.0,
  ).animate(_press);

  late final Animation<double> _scale = Tween<double>(
    begin: 0.98,
    end: 1.0,
  ).animate(_press);

  @override
  void initState() {
    super.initState();

    _notes = [...ref.read(soundingNotesProvider)];
    _pedal = ref.read(inputPedalStateProvider).isDown;
    _pedalCtl.value = _pedal ? 1.0 : 0.0;
    _scrollController.addListener(_updateScrollFade);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollFade();
    });

    _notesSubscription = ref.listenManual<List<SoundingNote>>(
      soundingNotesProvider,
      (prev, next) {
        if (!mounted) return;

        if (!listEquals(prev ?? const <SoundingNote>[], next)) {
          ref
              .read(appActivityProvider.notifier)
              .markActivity(AppActivitySource.midi);
        }

        _applyNotesDiff(next);
      },
    );

    _pedalSubscription = ref.listenManual<bool>(
      inputPedalStateProvider.select((s) => s.isDown),
      (prev, next) {
        if (!mounted) return;

        setState(() => _pedal = next);

        // Interruptible: immediately retarget animation.
        if (next) {
          unawaited(_pedalCtl.forward());
        } else {
          unawaited(_pedalCtl.reverse());
        }
      },
    );
  }

  @override
  void dispose() {
    _followTimer?.cancel();
    _scrollController.removeListener(_updateScrollFade);
    _scrollController.dispose();
    _pedalCtl.dispose();
    _notesSubscription?.close();
    _pedalSubscription?.close();
    super.dispose();
  }

  void _updateScrollFade() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    const epsilon = 0.5;
    final maxExtent = position.maxScrollExtent;
    final pixels = position.pixels;
    final nextLeading = maxExtent > epsilon && pixels > epsilon;
    final nextTrailing = maxExtent > epsilon && pixels < maxExtent - epsilon;

    if (nextLeading == _showLeadingFade && nextTrailing == _showTrailingFade) {
      return;
    }

    setState(() {
      _showLeadingFade = nextLeading;
      _showTrailingFade = nextTrailing;
    });
  }

  // Nudge the most-recently inserted chip into view, scrolling whichever way is
  // needed (the newest note may sit anywhere in the pitch-sorted row) and
  // leaving a margin so it clears the edge fade.
  void _followNewNote() {
    final id = _followNoteId;
    _followNoteId = null;
    if (id == null || !_scrollController.hasClients) return;

    final box = _chipKeys[id]?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return;

    final viewport = RenderAbstractViewport.of(box);
    final leadingOffset = viewport.getOffsetToReveal(box, 0.0).offset;
    final trailingOffset = viewport.getOffsetToReveal(box, 1.0).offset;

    final position = _scrollController.position;
    final current = position.pixels;

    double target;
    if (current > leadingOffset) {
      // Off the leading edge. The chip box has no leading padding (the gap sits
      // on its trailing side), so add it here to clear the fade by the same
      // amount the trailing edge gets for free.
      target = leadingOffset - _followMargin - _chipTrailingGap;
    } else if (current < trailingOffset) {
      target = trailingOffset + _followMargin; // chip is off the trailing edge
    } else {
      return; // already fully visible
    }

    target = target.clamp(position.minScrollExtent, position.maxScrollExtent);
    if ((target - current).abs() < 0.5) return;

    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _applyNotesDiff(Iterable<SoundingNote> next) {
    final nextList = next is List<SoundingNote>
        ? next
        : next.toList(growable: false);
    final nextIdSet = {for (final n in nextList) n.id};
    final nextById = {for (final n in nextList) n.id: n};

    final currentIdSet = _notes.map((e) => e.id).toSet();

    for (int i = _notes.length - 1; i >= 0; i--) {
      final id = _notes[i].id;
      if (!nextIdSet.contains(id)) {
        final removed = _notes.removeAt(i);
        currentIdSet.remove(id);
        _chipKeys.remove(id);

        _notesKey.currentState?.removeItem(
          i,
          (context, animation) => _buildPaddedNoteChip(removed, animation),
          duration: const Duration(milliseconds: 120),
        );
      }
    }

    final insertedIds = <String>[];
    for (int i = 0; i < nextList.length; i++) {
      final id = nextList[i].id;
      if (!currentIdSet.contains(id)) {
        _notes.insert(i, nextList[i]);
        currentIdSet.add(id);
        insertedIds.add(id);

        _notesKey.currentState?.insertItem(
          i,
          duration: const Duration(milliseconds: 140),
        );
      }
    }

    setState(() {
      for (int i = 0; i < _notes.length; i++) {
        final updated = nextById[_notes[i].id];
        if (updated != null) _notes[i] = updated;
      }
    });

    // Notes are sorted by pitch, so the newest can land anywhere. Follow the
    // rightmost (highest) note inserted this frame; that's the last one the
    // forward loop placed.
    if (insertedIds.isNotEmpty) {
      _followNoteId = insertedIds.last;
      _followTimer?.cancel();
      _followTimer = Timer(_followSettleDelay, () {
        if (mounted) _followNewNote();
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollFade();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);
    final safeTrailingInset = mediaQuery.orientation == Orientation.landscape
        ? mediaQuery.viewPadding.right
        : 0.0;
    final padding = widget.padding.copyWith(
      right: widget.padding.right + safeTrailingInset,
    );
    final pedalSlotWidth = PedalIndicator.slotWidthFor(
      context,
      visualScaleMultiplier: widget.visualScaleMultiplier,
    );
    final heightScale = InputDisplaySizing.rowHeightScale(
      context,
      visualScaleMultiplier: widget.visualScaleMultiplier,
    );

    final scaledMinHeight = 44.0 * heightScale;
    final minHeight = scaledMinHeight < 48.0 ? 48.0 : scaledMinHeight;
    final demoEnabled = ref.watch(demoModeProvider);
    final demoVariant = ref.watch(demoModeVariantProvider);
    final interactiveDemoEnabled =
        demoEnabled && demoVariant == DemoModeVariant.interactive;
    final lookupActive = ref.watch(lookupActiveProvider);
    final showPrompt =
        _notes.isEmpty &&
        (lookupActive ||
            (ref.watch(inputIdleEligibleProvider) && !interactiveDemoEnabled));
    final isMidiConnected = ref.watch(
      midiConnectionStatusProvider.select((s) => s.isConnected),
    );
    // Inline MIDI guidance only applies to live mode, not manual lookup.
    final showInlineMidiGuidance = !lookupActive && !isMidiConnected;
    final promptText = lookupActive
        ? 'Tap some notes…'
        : showInlineMidiGuidance
        ? 'Connect a MIDI device to begin…'
        : 'Play some notes…';
    final promptSemantics = lookupActive
        ? 'Tap some notes'
        : showInlineMidiGuidance
        ? 'Connect a MIDI device to begin'
        : 'Play some notes';
    final VoidCallback? onPromptTap = showInlineMidiGuidance
        ? () {
            unawaited(
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const MidiSettingsPage(),
                ),
              ),
            );
          }
        : null;

    return Padding(
      padding: padding,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: SizedBox(
          height: minHeight,
          child: Row(
            children: [
              Expanded(
                child: showPrompt
                    ? Row(
                        children: [
                          SizedBox(
                            width: pedalSlotWidth,
                            child: _buildAnimatedPedal(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Builder(
                              builder: (context) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) _updateScrollFade();
                                });

                                return Stack(
                                  children: [
                                    SingleChildScrollView(
                                      controller: _scrollController,
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Semantics(
                                          button: showInlineMidiGuidance,
                                          onTapHint: showInlineMidiGuidance
                                              ? 'Open MIDI settings'
                                              : null,
                                          child: GestureDetector(
                                            behavior: HitTestBehavior.opaque,
                                            onTap: onPromptTap,
                                            child: Text(
                                              promptText,
                                              semanticsLabel: promptSemantics,
                                              style: theme.textTheme.bodyLarge
                                                  ?.copyWith(
                                                    color: cs.onSurfaceVariant,
                                                    letterSpacing: -0.1,
                                                  ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_showLeadingFade)
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: _fadeWidth,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  cs.surface,
                                                  cs.surface.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_showTrailingFade)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: _fadeWidth,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerRight,
                                                end: Alignment.centerLeft,
                                                colors: [
                                                  cs.surface,
                                                  cs.surface.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          SizedBox(
                            width: pedalSlotWidth,
                            child: _buildAnimatedPedal(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                WidgetsBinding.instance.addPostFrameCallback((
                                  _,
                                ) {
                                  if (mounted) _updateScrollFade();
                                });

                                return Stack(
                                  children: [
                                    CustomScrollView(
                                      controller: _scrollController,
                                      scrollDirection: Axis.horizontal,
                                      physics: const BouncingScrollPhysics(),
                                      slivers: [
                                        SliverAnimatedList(
                                          key: _notesKey,
                                          initialItemCount: _notes.length,
                                          itemBuilder:
                                              (context, index, animation) {
                                                final note = _notes[index];
                                                final key = _chipKeys
                                                    .putIfAbsent(
                                                      note.id,
                                                      GlobalKey.new,
                                                    );
                                                return _buildPaddedNoteChip(
                                                  note,
                                                  animation,
                                                  key: key,
                                                );
                                              },
                                        ),
                                      ],
                                    ),
                                    if (_showLeadingFade)
                                      Positioned(
                                        left: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: _fadeWidth,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerLeft,
                                                end: Alignment.centerRight,
                                                colors: [
                                                  cs.surface,
                                                  cs.surface.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    if (_showTrailingFade)
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        bottom: 0,
                                        width: _fadeWidth,
                                        child: IgnorePointer(
                                          child: DecoratedBox(
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.centerRight,
                                                end: Alignment.centerLeft,
                                                colors: [
                                                  cs.surface,
                                                  cs.surface.withValues(
                                                    alpha: 0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
              _buildModeToggle(context, lookupActive: lookupActive),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeToggle(BuildContext context, {required bool lookupActive}) {
    final cs = Theme.of(context).colorScheme;
    // No outline, so nudge it toward the screen edge to reclaim a little width.
    return Transform.translate(
      offset: const Offset(8, 4),
      child: IconButton(
        key: widget.lookupButtonKey,
        icon: Icon(lookupActive ? Icons.piano : Icons.search),
        tooltip: lookupActive ? 'Back to keyboard' : 'Look up a chord',
        style: IconButton.styleFrom(
          foregroundColor: cs.primary,
          shape: const CircleBorder(),
        ),
        onPressed: () {
          final notifier = ref.read(lookupModeProvider.notifier);
          if (lookupActive) {
            notifier.exit();
          } else {
            notifier.enter();
          }
        },
      ),
    );
  }

  Widget _buildAnimatedPedal() {
    return AnimatedBuilder(
      animation: _pedalCtl,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: Offset(0, _travel.value),
            child: Transform.scale(
              scale: _scale.value,
              alignment: Alignment.centerLeft,
              child: child,
            ),
          ),
        );
      },
      child: Align(
        alignment: Alignment.centerLeft,
        child: PedalIndicator(
          visualScaleMultiplier: widget.visualScaleMultiplier,
        ),
      ),
    );
  }

  Widget _buildPaddedNoteChip(
    SoundingNote note,
    Animation<double> animation, {
    Key? key,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(right: _chipTrailingGap),
      child: _buildNoteChip(note, animation),
    );
  }

  Widget _buildNoteChip(SoundingNote note, Animation<double> animation) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
    );

    return SizeTransition(
      sizeFactor: curved,
      axis: Axis.horizontal,
      child: FadeTransition(
        opacity: curved,
        child: InputNoteChip(
          key: ValueKey(note.id),
          note: note,
          visualScaleMultiplier: widget.visualScaleMultiplier,
        ),
      ),
    );
  }
}
