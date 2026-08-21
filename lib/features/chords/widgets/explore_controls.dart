import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/theory/theory.dart';

class ExploreControls extends StatelessWidget {
  const ExploreControls({
    super.key,
    required this.state,
    required this.identity,
    required this.tonality,
    required this.noteNameSystem,
    required this.isLandscape,
    required this.onRootChanged,
    required this.onBaseQualityChanged,
    required this.onSeventhKindChanged,
    required this.onFifthAlterationChanged,
    required this.onExtensionsChanged,
    required this.onBassChanged,
  });

  final ChordConstruction state;
  final ChordIdentity identity;
  final Tonality tonality;
  final NoteNameSystem noteNameSystem;
  final bool isLandscape;
  final ValueChanged<Tonic> onRootChanged;
  final ValueChanged<BaseQuality> onBaseQualityChanged;
  final ValueChanged<SeventhKind> onSeventhKindChanged;
  final ValueChanged<FifthAlteration> onFifthAlterationChanged;
  final ValueChanged<Set<ChordExtension>> onExtensionsChanged;
  final ValueChanged<int> onBassChanged;

  @override
  Widget build(BuildContext context) {
    final extensionGroups = buildExtensionOptionGroups(state.quality);
    final seventhKindChoices = availableSeventhKindsFor(state.baseQuality);
    final fifthAlterationChoices = availableFifthAlterationsFor(
      baseQuality: state.baseQuality,
      seventhKind: state.seventhKind,
    );
    final memberPitchClasses =
        ChordPresentationBuilder.chordMemberPitchClassesFromMask(
          rootPc: identity.rootPc,
          presentIntervalsMask: identity.presentIntervalsMask,
        );

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Explore controls',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final controlWidth = _controlWidthFor(
            availableWidth: constraints.maxWidth,
            isLandscape: isLandscape,
          );

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: controlWidth,
                child: _RootWheel(
                  value: state.root,
                  noteNameSystem: noteNameSystem,
                  onChanged: onRootChanged,
                ),
              ),
              SizedBox(
                width: controlWidth,
                child: _BaseQualitySelector(
                  value: state.baseQuality,
                  onChanged: onBaseQualityChanged,
                ),
              ),
              if (seventhKindChoices.length > 1 ||
                  fifthAlterationChoices.length > 1)
                SizedBox(
                  width: controlWidth,
                  child: _CoreTonesSelector(
                    baseQuality: state.baseQuality,
                    seventhKind: state.seventhKind,
                    seventhKindChoices: seventhKindChoices,
                    fifthAlteration: state.fifthAlteration,
                    fifthAlterationChoices: fifthAlterationChoices,
                    onSeventhKindChanged: onSeventhKindChanged,
                    onFifthAlterationChanged: onFifthAlterationChanged,
                  ),
                ),
              if (extensionGroups.isNotEmpty)
                SizedBox(
                  width: controlWidth,
                  child: _ExtensionBuilder(
                    groups: extensionGroups,
                    selectedExtensions: state.extensions,
                    onChoiceSelected: (group, choice) {
                      onExtensionsChanged(
                        selectExtensionChoice(
                          quality: state.quality,
                          currentExtensions: state.extensions,
                          group: group,
                          choice: choice,
                        ),
                      );
                    },
                  ),
                ),
              SizedBox(
                width: controlWidth,
                child: _BassSelector(
                  value: state.bassPc,
                  choices: [
                    for (final pc in _sortedPitchClasses(
                      memberPitchClasses,
                      identity.rootPc,
                    ))
                      _buildBassChoice(
                        pc: pc,
                        rootPc: identity.rootPc,
                        bassName: _spellBass(
                          pc: pc,
                          identity: identity,
                          tonality: tonality,
                          rootName: state.root.label,
                        ),
                        noteNameSystem: noteNameSystem,
                      ),
                  ],
                  onChanged: onBassChanged,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  double _controlWidthFor({
    required double availableWidth,
    required bool isLandscape,
  }) {
    if (!isLandscape) return double.infinity;
    if (!availableWidth.isFinite) return 420;

    const gap = 12.0;
    const minTwoColumnWidth = 340.0;
    final twoColumnWidth = (availableWidth - gap) / 2;
    if (twoColumnWidth >= minTwoColumnWidth) return twoColumnWidth;

    return availableWidth;
  }

  List<int> _sortedPitchClasses(Set<int> pitchClasses, int rootPc) {
    final values = pitchClasses.toList();
    values.sort((a, b) {
      final intervalA = _normalizedPitchClass(a - rootPc);
      final intervalB = _normalizedPitchClass(b - rootPc);
      return intervalA.compareTo(intervalB);
    });
    return values;
  }

  String _spellBass({
    required int pc,
    required ChordIdentity identity,
    required Tonality tonality,
    required String rootName,
  }) {
    final interval = _normalizedPitchClass(pc - identity.rootPc);
    final role = identity.toneRolesByInterval[interval];
    return spellPitchClass(
      pc,
      tonality: tonality,
      chordRootName: rootName,
      role: role,
    );
  }

  int _normalizedPitchClass(int value) {
    final normalized = value % 12;
    return normalized < 0 ? normalized + 12 : normalized;
  }

  _BassChoice _buildBassChoice({
    required int pc,
    required int rootPc,
    required String bassName,
    required NoteNameSystem noteNameSystem,
  }) {
    if (pc == rootPc) {
      return _BassChoice(pc: pc, label: 'Root', semanticLabel: 'Root position');
    }

    return _BassChoice(
      pc: pc,
      label: '/${noteDisplayLabel(bassName, noteNameSystem: noteNameSystem)}',
      semanticLabel:
          'Bass ${noteSemanticLabel(bassName, noteNameSystem: noteNameSystem)}',
    );
  }
}

class _BaseQualitySelector extends StatelessWidget {
  const _BaseQualitySelector({required this.value, required this.onChanged});

  static const _choices = BaseQuality.values;

  final BaseQuality value;
  final ValueChanged<BaseQuality> onChanged;

  @override
  Widget build(BuildContext context) {
    return _OptionWheel<BaseQuality>(
      label: 'Quality',
      value: value,
      choices: _choices,
      labelFor: _baseQualityLabel,
      semanticLabelFor: _baseQualitySemanticLabel,
      onChanged: onChanged,
    );
  }
}

class _CoreTonesSelector extends StatelessWidget {
  const _CoreTonesSelector({
    required this.baseQuality,
    required this.seventhKind,
    required this.seventhKindChoices,
    required this.fifthAlteration,
    required this.fifthAlterationChoices,
    required this.onSeventhKindChanged,
    required this.onFifthAlterationChanged,
  });

  final BaseQuality baseQuality;
  final SeventhKind seventhKind;
  final List<SeventhKind> seventhKindChoices;
  final FifthAlteration fifthAlteration;
  final List<FifthAlteration> fifthAlterationChoices;
  final ValueChanged<SeventhKind> onSeventhKindChanged;
  final ValueChanged<FifthAlteration> onFifthAlterationChanged;

  @override
  Widget build(BuildContext context) {
    final showFifth = fifthAlterationChoices.length > 1;
    final showSeventh = seventhKindChoices.length > 1;
    final fifthIndex = _selectedIndex(fifthAlterationChoices, fifthAlteration);
    final seventhIndex = _selectedIndex(seventhKindChoices, seventhKind);

    return Semantics(
      container: true,
      label: 'Core tones',
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Core Tones',
          border: OutlineInputBorder(),
        ),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeOutCubic,
                transitionBuilder: _coreToneTransition,
                child: showFifth
                    ? _CoreToneSegmentedControl(
                        key: const ValueKey('fifth'),
                        label: 'Fifth',
                        value: _fifthAlterationSemanticLabel(
                          fifthAlterationChoices[fifthIndex],
                        ),
                        labels: [
                          for (final choice in fifthAlterationChoices)
                            toGlyphAccidentals(_fifthAlterationLabel(choice)),
                        ],
                        semanticLabels: [
                          for (final choice in fifthAlterationChoices)
                            _fifthAlterationSemanticLabel(choice),
                        ],
                        selectedIndex: fifthIndex,
                        onSelected: (index) => onFifthAlterationChanged(
                          fifthAlterationChoices[index],
                        ),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-fifth')),
              ),
              if (showFifth && showSeventh) const SizedBox(height: 12),
              if (showSeventh)
                _CoreToneSegmentedControl(
                  label: 'Sixth / Seventh',
                  value: _seventhKindSemanticLabel(
                    seventhKindChoices[seventhIndex],
                  ),
                  labels: [
                    for (final choice in seventhKindChoices)
                      toGlyphAccidentals(
                        _seventhKindLabel(choice, baseQuality),
                      ),
                  ],
                  semanticLabels: [
                    for (final choice in seventhKindChoices)
                      _seventhKindSemanticLabel(choice),
                  ],
                  selectedIndex: seventhIndex,
                  onSelected: (index) =>
                      onSeventhKindChanged(seventhKindChoices[index]),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _coreToneTransition(Widget child, Animation<double> animation) {
    return SizeTransition(
      sizeFactor: animation,
      alignment: AlignmentDirectional.topStart,
      child: FadeTransition(opacity: animation, child: child),
    );
  }

  int _selectedIndex<T>(List<T> choices, T value) {
    final index = choices.indexOf(value);
    return index < 0 ? 0 : index;
  }
}

class _CoreToneSegmentedControl extends StatelessWidget {
  const _CoreToneSegmentedControl({
    super.key,
    required this.label,
    required this.value,
    required this.labels,
    required this.semanticLabels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final String label;
  final String value;
  final List<String> labels;
  final List<String> semanticLabels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      label: label,
      value: value,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: textTheme.labelMedium),
          const SizedBox(height: 6),
          _ExploreSegmentedChoiceGroup(
            labels: labels,
            semanticLabels: semanticLabels,
            selectedIndex: selectedIndex,
            onSelected: onSelected,
          ),
        ],
      ),
    );
  }
}

class _OptionWheel<T> extends StatelessWidget {
  const _OptionWheel({
    required this.label,
    required this.value,
    required this.choices,
    required this.labelFor,
    required this.semanticLabelFor,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<T> choices;
  final String Function(T value) labelFor;
  final String Function(T value) semanticLabelFor;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return CyclicWheel<T>(
      label: label,
      value: value,
      choices: choices,
      displayLabelFor: (value) => toGlyphAccidentals(labelFor(value)),
      semanticLabelFor: semanticLabelFor,
      onChanged: onChanged,
    );
  }
}

String _baseQualityLabel(BaseQuality quality) {
  return switch (quality) {
    BaseQuality.major => 'maj',
    BaseQuality.minor => 'min',
    BaseQuality.power => '5',
    BaseQuality.diminished => 'dim',
    BaseQuality.augmented => 'aug',
    BaseQuality.sus2 => 'sus2',
    BaseQuality.sus4 => 'sus4',
    BaseQuality.sus2sus4 => 'sus2/4',
  };
}

String _baseQualitySemanticLabel(BaseQuality quality) {
  return switch (quality) {
    BaseQuality.major => 'Major',
    BaseQuality.minor => 'Minor',
    BaseQuality.power => 'Power chord',
    BaseQuality.diminished => 'Diminished',
    BaseQuality.augmented => 'Augmented',
    BaseQuality.sus2 => 'Suspended second',
    BaseQuality.sus4 => 'Suspended fourth',
    BaseQuality.sus2sus4 => 'Suspended second and fourth',
  };
}

String _seventhKindLabel(SeventhKind kind, BaseQuality baseQuality) {
  return switch (kind) {
    SeventhKind.none => 'None',
    SeventhKind.sixth => switch (baseQuality) {
      BaseQuality.minor => 'min6',
      _ => 'maj6',
    },
    SeventhKind.dominant7 => '7',
    SeventhKind.major7 => 'maj7',
    SeventhKind.minor7 => 'min7',
    SeventhKind.minorMajor7 => 'minmaj7',
    SeventhKind.halfDiminished7 => 'hdim7',
    SeventhKind.diminished7 => 'dim7',
  };
}

String _seventhKindSemanticLabel(SeventhKind kind) {
  return switch (kind) {
    SeventhKind.none => 'No sixth or seventh',
    SeventhKind.sixth => 'Sixth',
    SeventhKind.dominant7 => 'Dominant seventh',
    SeventhKind.major7 => 'Major seventh',
    SeventhKind.minor7 => 'Minor seventh',
    SeventhKind.minorMajor7 => 'Minor-major seventh',
    SeventhKind.halfDiminished7 => 'Half-diminished seventh',
    SeventhKind.diminished7 => 'Diminished seventh',
  };
}

String _fifthAlterationLabel(FifthAlteration alteration) {
  return switch (alteration) {
    FifthAlteration.natural => '5',
    FifthAlteration.flat => 'b5',
    FifthAlteration.sharp => '#5',
  };
}

String _fifthAlterationSemanticLabel(FifthAlteration alteration) {
  return switch (alteration) {
    FifthAlteration.natural => 'Natural fifth',
    FifthAlteration.flat => 'Flat fifth',
    FifthAlteration.sharp => 'Sharp fifth',
  };
}

class _RootWheel extends StatelessWidget {
  const _RootWheel({
    required this.value,
    required this.noteNameSystem,
    required this.onChanged,
  });

  final Tonic value;
  final NoteNameSystem noteNameSystem;
  final ValueChanged<Tonic> onChanged;

  @override
  Widget build(BuildContext context) {
    return CyclicWheel<Tonic>(
      label: 'Root',
      value: value,
      choices: Tonic.values,
      displayLabelFor: (root) =>
          noteDisplayLabel(root.label, noteNameSystem: noteNameSystem),
      semanticLabelFor: (root) =>
          noteSemanticLabel(root.label, noteNameSystem: noteNameSystem),
      targetItemWidth: 72,
      selectedMinWidth: 46,
      unselectedMinWidth: 40,
      selectedHorizontalPadding: 8,
      unselectedHorizontalPadding: 4,
      onChanged: onChanged,
    );
  }
}

class _BassChoice {
  const _BassChoice({
    required this.pc,
    required this.label,
    required this.semanticLabel,
  });

  final int pc;
  final String label;
  final String semanticLabel;
}

class _BassSelector extends StatelessWidget {
  const _BassSelector({
    required this.value,
    required this.choices,
    required this.onChanged,
  });

  final int value;
  final List<_BassChoice> choices;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedChoice = _selectedChoice();

    return Semantics(
      container: true,
      label: 'Bass Note',
      value: selectedChoice?.semanticLabel,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Bass Note',
          border: OutlineInputBorder(),
        ),
        child: _ExploreSegmentedChoiceGroup(
          labels: [for (final choice in choices) choice.label],
          semanticLabels: [for (final choice in choices) choice.semanticLabel],
          selectedIndex: _selectedIndex(),
          onSelected: (index) => onChanged(choices[index].pc),
        ),
      ),
    );
  }

  _BassChoice? _selectedChoice() {
    for (final choice in choices) {
      if (choice.pc == value) return choice;
    }
    return null;
  }

  int _selectedIndex() {
    for (var index = 0; index < choices.length; index++) {
      if (choices[index].pc == value) return index;
    }
    return 0;
  }
}

class _ExtensionBuilder extends StatelessWidget {
  const _ExtensionBuilder({
    required this.groups,
    required this.selectedExtensions,
    required this.onChoiceSelected,
  });

  final List<ExtensionOptionGroup> groups;
  final Set<ChordExtension> selectedExtensions;
  final void Function(ExtensionOptionGroup group, ExtensionChoice choice)
  onChoiceSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Semantics(
      container: true,
      label: 'Extensions',
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Extensions',
          border: OutlineInputBorder(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < groups.length; index++) ...[
              if (index > 0) const SizedBox(height: 12),
              if (groups.length > 1) ...[
                Text(groups[index].label, style: labelStyle),
                const SizedBox(height: 6),
              ],
              if (groups[index].allowsMultiple)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final choice in groups[index].choices)
                      Semantics(
                        button: true,
                        selected: _isSelected(groups[index], choice),
                        label: choice.semanticLabel,
                        child: _ExploreMultiChoiceChip(
                          label: choice.label,
                          selected: _isSelected(groups[index], choice),
                          onSelected: (_) =>
                              onChoiceSelected(groups[index], choice),
                        ),
                      ),
                  ],
                )
              else
                _ExploreSegmentedChoiceGroup(
                  labels: [
                    for (final choice in groups[index].choices) choice.label,
                  ],
                  semanticLabels: [
                    for (final choice in groups[index].choices)
                      choice.semanticLabel,
                  ],
                  selectedIndex: _selectedIndex(groups[index]),
                  onSelected: (choiceIndex) => onChoiceSelected(
                    groups[index],
                    groups[index].choices[choiceIndex],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isSelected(ExtensionOptionGroup group, ExtensionChoice choice) {
    final extension = choice.extension;
    if (extension != null) return selectedExtensions.contains(extension);

    return group.choices
        .where((candidate) => candidate.extension != null)
        .every(
          (candidate) => !selectedExtensions.contains(candidate.extension),
        );
  }

  int _selectedIndex(ExtensionOptionGroup group) {
    for (var index = 0; index < group.choices.length; index++) {
      if (_isSelected(group, group.choices[index])) return index;
    }
    return 0;
  }
}

class _ExploreSegmentedChoiceGroup extends StatelessWidget {
  const _ExploreSegmentedChoiceGroup({
    required this.labels,
    required this.semanticLabels,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final List<String> semanticLabels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final radius = BorderRadius.circular(8);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Material(
        color: cs.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.70)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0)
                SizedBox(
                  height: 40,
                  child: VerticalDivider(
                    width: 1,
                    thickness: 1,
                    color: cs.outlineVariant.withValues(alpha: 0.70),
                  ),
                ),
              _ExploreSegmentedChoice(
                label: labels[index],
                semanticLabel: semanticLabels[index],
                selected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ExploreSegmentedChoice extends StatelessWidget {
  const _ExploreSegmentedChoice({
    required this.label,
    required this.semanticLabel,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semanticLabel;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: selected ? cs.onPrimaryContainer : cs.onSurface,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );

    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? cs.primaryContainer : cs.surfaceContainerLow,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 40, minWidth: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Center(
                  child: Text(label, maxLines: 1, style: labelStyle),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExploreMultiChoiceChip extends StatelessWidget {
  const _ExploreMultiChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final labelStyle = theme.textTheme.labelLarge?.copyWith(
      color: selected ? cs.onPrimaryContainer : cs.onSurface,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      // Selected fills with a checkmark, so it keeps a transparent edge (at the
      // same width) to hold its size; unselected takes the shared rest border.
      side: selected
          ? const BorderSide(color: Colors.transparent)
          : SelectionColors.restChipBorder(cs),
    );

    return FilterChip(
      label: Text(label, style: labelStyle),
      selected: selected,
      onSelected: onSelected,
      showCheckmark: true,
      checkmarkColor: cs.onPrimaryContainer,
      backgroundColor: cs.surfaceContainerLow,
      selectedColor: cs.primaryContainer,
      shape: shape,
    );
  }
}
