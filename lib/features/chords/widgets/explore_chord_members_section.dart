import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/input/input.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class ExploreChordMembersSection extends StatefulWidget {
  const ExploreChordMembersSection({
    super.key,
    required this.members,
    required this.memberDegrees,
    required this.noteNameSystem,
    required this.showDegrees,
    required this.onShowDegreesChanged,
    required this.activePitchClasses,
    required this.memberPitchClasses,
  });

  final List<String> members;
  final List<String> memberDegrees;
  final NoteNameSystem noteNameSystem;
  final bool showDegrees;
  final ValueChanged<bool> onShowDegreesChanged;
  final Set<int> activePitchClasses;
  final List<int> memberPitchClasses;

  @override
  State<ExploreChordMembersSection> createState() =>
      _ExploreChordMembersSectionState();
}

class _ExploreChordMembersSectionState extends State<ExploreChordMembersSection>
    with TickerProviderStateMixin {
  static const Duration _insertDuration = Duration(milliseconds: 140);
  static const Duration _removeDuration = Duration(milliseconds: 120);
  static const double _fadeWidth = 34.0;

  late List<_ExploreMemberChipEntry> _entries;
  final _scrollController = ScrollController();
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;

  @override
  void initState() {
    super.initState();
    _entries = _createInitialEntries();
    _scrollController.addListener(_updateScrollFade);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollFade();
    });
  }

  @override
  void didUpdateWidget(covariant ExploreChordMembersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showDegrees != widget.showDegrees ||
        oldWidget.members != widget.members ||
        oldWidget.memberDegrees != widget.memberDegrees ||
        oldWidget.noteNameSystem != widget.noteNameSystem ||
        oldWidget.activePitchClasses != widget.activePitchClasses ||
        oldWidget.memberPitchClasses != widget.memberPitchClasses) {
      _applyMemberDiff();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateScrollFade);
    _scrollController.dispose();
    for (final entry in _entries) {
      entry.controller.dispose();
    }
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

  List<_ExploreMemberChipEntry> _createInitialEntries() {
    return [
      for (var i = 0; i < widget.members.length; i++)
        _ExploreMemberChipEntry(
          data: _memberDataAt(i),
          controller: AnimationController(
            vsync: this,
            duration: _insertDuration,
            reverseDuration: _removeDuration,
            value: 1.0,
          ),
        ),
    ];
  }

  _ExploreMemberChipData _memberDataAt(int index) {
    final pitchClass = index < widget.memberPitchClasses.length
        ? widget.memberPitchClasses[index]
        : null;
    final noteLabel = noteDisplayLabel(
      widget.members[index],
      noteNameSystem: widget.noteNameSystem,
    );
    final noteSemantics = noteSemanticLabel(
      widget.members[index],
      noteNameSystem: widget.noteNameSystem,
    );
    final degreeLabel = index < widget.memberDegrees.length
        ? toGlyphAccidentals(widget.memberDegrees[index])
        : noteLabel;
    final id = pitchClass == null
        ? 'label:${widget.members[index]}'
        : 'pc:$pitchClass';

    return _ExploreMemberChipData(
      id: id,
      label: widget.showDegrees ? degreeLabel : noteLabel,
      alternateLabel: widget.showDegrees ? noteLabel : degreeLabel,
      semanticLabel: widget.showDegrees
          ? 'Chord member $noteSemantics, degree $degreeLabel'
          : 'Chord member $noteSemantics',
      active:
          pitchClass != null && widget.activePitchClasses.contains(pitchClass),
    );
  }

  void _applyMemberDiff() {
    final nextData = [
      for (var i = 0; i < widget.members.length; i++) _memberDataAt(i),
    ];

    final stableEntries = _entries.where((entry) => !entry.removing).toList();
    if (stableEntries.length == nextData.length) {
      setState(() {
        for (var i = 0; i < nextData.length; i++) {
          stableEntries[i].data = nextData[i];
        }
        _entries = stableEntries;
      });
      return;
    }

    final nextIds = {for (final data in nextData) data.id};
    final entriesById = {
      for (final entry in _entries)
        if (!entry.removing) entry.data.id: entry,
    };
    final nextEntries = <_ExploreMemberChipEntry>[];

    for (final data in nextData) {
      final existing = entriesById[data.id];
      if (existing != null) {
        existing.data = data;
        nextEntries.add(existing);
        continue;
      }

      final entry = _ExploreMemberChipEntry(
        data: data,
        controller: AnimationController(
          vsync: this,
          duration: _insertDuration,
          reverseDuration: _removeDuration,
        ),
      );
      nextEntries.add(entry);
      unawaited(entry.controller.forward());
    }

    for (final entry in _entries) {
      if (entry.removing || nextIds.contains(entry.data.id)) continue;

      entry.removing = true;
      unawaited(
        entry.controller.reverse().whenComplete(() {
          if (!mounted) return;
          setState(() {
            _entries.remove(entry);
          });
          entry.controller.dispose();
        }),
      );

      final oldIndex = _entries.indexOf(entry);
      final insertIndex = oldIndex.clamp(0, nextEntries.length);
      nextEntries.insert(insertIndex, entry);
    }

    setState(() {
      _entries = nextEntries;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollFade();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateScrollFade();
    });

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Chord members',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NameDegreeToggleButton(
            showDegrees: widget.showDegrees,
            onPressed: () => widget.onShowDegreesChanged(!widget.showDegrees),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < _entries.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i == _entries.length - 1 ? 0 : 5,
                          ),
                          child: _AnimatedExploreMemberChip(
                            key: ObjectKey(_entries[i]),
                            entry: _entries[i],
                          ),
                        ),
                    ],
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
                              cs.surface.withValues(alpha: 0),
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
                              cs.surface.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExploreMemberChipData {
  const _ExploreMemberChipData({
    required this.id,
    required this.label,
    required this.alternateLabel,
    required this.semanticLabel,
    required this.active,
  });

  final String id;
  final String label;
  final String alternateLabel;
  final String semanticLabel;
  final bool active;
}

class _ExploreMemberChipEntry {
  _ExploreMemberChipEntry({required this.data, required this.controller});

  _ExploreMemberChipData data;
  final AnimationController controller;
  bool removing = false;
}

class _AnimatedExploreMemberChip extends StatelessWidget {
  const _AnimatedExploreMemberChip({super.key, required this.entry});

  final _ExploreMemberChipEntry entry;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: entry.controller,
      curve: Curves.easeOutCubic,
    );

    return SizeTransition(
      sizeFactor: curved,
      axis: Axis.horizontal,
      child: FadeTransition(
        opacity: curved,
        child: NoteChip(
          label: entry.data.label,
          alternateLabel: entry.data.alternateLabel,
          semanticLabel: entry.data.semanticLabel,
          state: entry.data.active ? NoteChipState.fill : NoteChipState.plain,
          sizeScale: InputDisplaySizing.noteScale(context),
          verticalScale: InputDisplaySizing.noteVerticalScale(context),
          horizontalPadding: 8,
        ),
      ),
    );
  }
}
