import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/chords/chords.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import 'adaptive_side_sheet.dart';

class ChordRankingDetailsSnapshot {
  ChordRankingDetailsSnapshot._({
    required List<ExplainedCandidate> candidates,
    required this.tonality,
    required this.notation,
    required this.noteNameSystem,
  }) : candidates = List.unmodifiable(candidates);

  factory ChordRankingDetailsSnapshot.capture(WidgetRef ref) {
    return ChordRankingDetailsSnapshot._(
      candidates: ref.read(rankedChordCandidateDebugProvider),
      tonality: ref.read(analysisContextProvider).tonality,
      notation: ref.read(chordNotationStyleProvider),
      noteNameSystem: ref.read(noteNameSystemProvider),
    );
  }

  final List<ExplainedCandidate> candidates;
  final Tonality tonality;
  final ChordNotationStyle notation;
  final NoteNameSystem noteNameSystem;
}

Future<void> showChordRankingDetailsSheet(
  BuildContext context, {
  required ChordRankingDetailsSnapshot snapshot,
}) async {
  if (useHomeSideSheet(context)) {
    await showHomeSideSheet<void>(
      context: context,
      barrierLabel: 'Dismiss chord ranking details',
      builder: (_) => _ChordRankingDetailsContent(
        snapshot: snapshot,
        showCloseButton: true,
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final mq = MediaQuery.of(context);
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: mq.size.height * 0.75),
        child: _ChordRankingDetailsContent(snapshot: snapshot),
      );
    },
  );
}

class _ChordRankingDetailsContent extends StatelessWidget {
  const _ChordRankingDetailsContent({
    required this.snapshot,
    this.showCloseButton = false,
  });

  final ChordRankingDetailsSnapshot snapshot;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSideSheet = showCloseButton;

    return Material(
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: isSideSheet
            ? const EdgeInsets.fromLTRB(0, 0, 0, 16)
            : const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isSideSheet)
              const ModalPanelHeader(
                title: 'Why This Chord?',
                showCloseButton: true,
              )
            else
              Align(
                alignment: Alignment.centerLeft,
                child: Semantics(
                  header: true,
                  child: Text(
                    'Why This Chord?',
                    style: theme.textTheme.titleLarge,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSideSheet ? 16 : 0),
                child: snapshot.candidates.isEmpty
                    ? const _EmptyRankingDetails()
                    : _RankingDetailsBody(
                        candidates: snapshot.candidates,
                        tonality: snapshot.tonality,
                        notation: snapshot.notation,
                        noteNameSystem: snapshot.noteNameSystem,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RankingDetailsBody extends StatefulWidget {
  const _RankingDetailsBody({
    required this.candidates,
    required this.tonality,
    required this.notation,
    required this.noteNameSystem,
  });

  final List<ExplainedCandidate> candidates;
  final Tonality tonality;
  final ChordNotationStyle notation;
  final NoteNameSystem noteNameSystem;

  @override
  State<_RankingDetailsBody> createState() => _RankingDetailsBodyState();
}

class _RankingDetailsBodyState extends State<_RankingDetailsBody> {
  final _cardKeys = List.generate(
    5,
    (_) => GlobalKey<_CandidateRankCardState>(),
  );

  void _toggleAllCards() {
    for (final key in _cardKeys) {
      key.currentState?._toggleFace();
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleCandidates(widget.candidates);
    final alternativeCount = ChordCandidateRanking.alternativeCount([
      for (final row in widget.candidates) row.candidate,
    ]);

    return FadedScrollView(
      fadeColor: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CandidateRankCard(
            key: _cardKeys[0],
            rank: 1,
            row: visible[0],
            thisCandidate: visible[0].candidate,
            nextDecision: visible.length > 1 ? visible[1].vsPrevious : null,
            isAlternative: false,
            symbol: _symbolFor(visible[0].candidate.identity),
            tonality: widget.tonality,
            noteNameSystem: widget.noteNameSystem,
            longLabel: ChordLongFormFormatter.format(
              identity: visible[0].candidate.identity,
              tonality: widget.tonality,
              noteNameSystem: widget.noteNameSystem,
            ),
            onLongPress: _toggleAllCards,
          ),
          if (visible.length > 1) ...[
            const SizedBox(height: 14),
            const SectionHeader(
              title: 'Ranking Alternatives',
              icon: Icons.format_list_numbered,
            ),
            for (var i = 1; i < visible.length; i++) ...[
              _CandidateRankCard(
                key: _cardKeys[i],
                rank: i + 1,
                row: visible[i],
                thisCandidate: visible[i].candidate,
                nextDecision: i + 1 < visible.length
                    ? visible[i + 1].vsPrevious
                    : null,
                isAlternative: i <= alternativeCount,
                symbol: _symbolFor(visible[i].candidate.identity),
                tonality: widget.tonality,
                noteNameSystem: widget.noteNameSystem,
                longLabel: ChordLongFormFormatter.format(
                  identity: visible[i].candidate.identity,
                  tonality: widget.tonality,
                  noteNameSystem: widget.noteNameSystem,
                ),
                onLongPress: _toggleAllCards,
              ),
              if (i != visible.length - 1) const SizedBox(height: 8),
            ],
          ],
        ],
      ),
    );
  }

  String _symbolFor(ChordIdentity identity) {
    return chordSymbolDisplayLabel(
      ChordSymbolBuilder.fromIdentity(
        identity: identity,
        tonality: widget.tonality,
        notation: widget.notation,
      ),
      noteNameSystem: widget.noteNameSystem,
    );
  }
}

List<ExplainedCandidate> _visibleCandidates(
  List<ExplainedCandidate> candidates,
) {
  return candidates.take(5).toList(growable: false);
}

class _CandidateRankCard extends StatefulWidget {
  const _CandidateRankCard({
    super.key,
    required this.rank,
    required this.row,
    required this.thisCandidate,
    required this.nextDecision,
    required this.isAlternative,
    required this.symbol,
    required this.tonality,
    required this.noteNameSystem,
    required this.longLabel,
    required this.onLongPress,
  });

  final int rank;
  final ExplainedCandidate row;
  final ChordCandidate thisCandidate;
  final RankingDecision? nextDecision;
  final bool isAlternative;
  final String symbol;
  final Tonality tonality;
  final NoteNameSystem noteNameSystem;
  final String longLabel;
  final VoidCallback onLongPress;

  @override
  State<_CandidateRankCard> createState() => _CandidateRankCardState();
}

class _CandidateRankCardState extends State<_CandidateRankCard> {
  bool _showCosts = false;

  void _toggleFace() {
    setState(() => _showCosts = !_showCosts);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final tier = widget.rank == 1
        ? _CandidateTier.chosen
        : (widget.isAlternative
              ? _CandidateTier.possible
              : _CandidateTier.unlikely);
    final disableAnimations =
        MediaQuery.maybeOf(context)?.disableAnimations ??
        WidgetsBinding
            .instance
            .platformDispatcher
            .accessibilityFeatures
            .disableAnimations;

    return Semantics(
      button: true,
      toggled: _showCosts,
      label: '${widget.symbol}, rank ${widget.rank}',
      hint: _showCosts
          ? 'Tap to show the plain-language explanation. '
                'Long press to flip all ranked chords'
          : 'Tap to show cost details. Long press to flip all ranked chords',
      child: Material(
        color: cs.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: widget.rank == 1
              ? BorderSide(color: cs.outlineVariant)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: _toggleFace,
          onLongPress: widget.onLongPress,
          child: AnimatedSize(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: disableAnimations
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) => Stack(
                alignment: Alignment.topCenter,
                children: [...previousChildren, ?currentChild],
              ),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.025),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              ),
              child: Padding(
                key: ValueKey(_showCosts),
                padding: const EdgeInsets.all(12),
                child: _showCosts
                    ? _CandidateCostBack(
                        rank: widget.rank,
                        tier: tier,
                        row: widget.row,
                        symbol: widget.symbol,
                        tonality: widget.tonality,
                        noteNameSystem: widget.noteNameSystem,
                        decision: widget.nextDecision,
                        winner: widget.thisCandidate,
                      )
                    : _CandidateExplanationFront(
                        rank: widget.rank,
                        row: widget.row,
                        symbol: widget.symbol,
                        longLabel: widget.longLabel,
                        tier: tier,
                        nextDecision: widget.nextDecision,
                        winner: widget.thisCandidate,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CandidateExplanationFront extends StatelessWidget {
  const _CandidateExplanationFront({
    required this.rank,
    required this.row,
    required this.symbol,
    required this.longLabel,
    required this.tier,
    required this.nextDecision,
    required this.winner,
  });

  final int rank;
  final ExplainedCandidate row;
  final String symbol;
  final String longLabel;
  final _CandidateTier tier;
  final RankingDecision? nextDecision;
  final ChordCandidate winner;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RankBadge(rank: rank, tier: tier),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(symbol, style: theme.textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    longLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _TierMarker(tier: tier),
          ],
        ),
        const SizedBox(height: 10),
        Text(_evidenceFor(row), style: theme.textTheme.bodyMedium),
        if (nextDecision?.decidedByRule != null) ...[
          const SizedBox(height: 6),
          Text(
            ChordRankingExplanations.decision(
              nextDecision!.decidedByRule,
              winner: winner,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _CandidateCostBack extends StatelessWidget {
  const _CandidateCostBack({
    required this.rank,
    required this.tier,
    required this.row,
    required this.symbol,
    required this.tonality,
    required this.noteNameSystem,
    required this.decision,
    required this.winner,
  });

  final int rank;
  final _CandidateTier tier;
  final ExplainedCandidate row;
  final String symbol;
  final Tonality tonality;
  final NoteNameSystem noteNameSystem;
  final RankingDecision? decision;
  final ChordCandidate winner;

  void _openExplore(BuildContext context) {
    // Push over the open sheet without dismissing it, so returning from Explore
    // reveals the same "Why This Chord?" view (flipped cards and scroll intact).
    unawaited(
      Navigator.of(
        context,
      ).push(ExploreChordPage.route(seedIdentity: row.candidate.identity)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final costContributions = row.costReasons.where(
      (reason) => reason.cost != 0,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RankBadge(rank: rank, tier: tier),
            const SizedBox(width: 10),
            Expanded(child: Text(symbol, style: theme.textTheme.titleMedium)),
            const SizedBox(width: 8),
            Text(
              row.candidate.cost.toStringAsFixed(2),
              style: theme.textTheme.titleMedium?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _TemplateLedger(
          ledger: ToneLedger.forCandidate(
            row,
            tonality: tonality,
            noteNameSystem: noteNameSystem,
          ),
        ),
        const Divider(height: 16),
        for (final reason in costContributions)
          _CostRow(
            label: ChordRankingExplanations.costReasonLabel(reason.label),
            value: reason.cost,
          ),
        _CostRow(
          label: 'Explanation cost',
          value: row.candidate.cost,
          signed: false,
          emphasized: true,
        ),
        if (decision?.decidedByRule != null) ...[
          const SizedBox(height: 10),
          Text(
            ChordRankingExplanations.decision(
              decision!.decidedByRule,
              winner: winner,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => _openExplore(context),
            icon: const Icon(Icons.explore_outlined, size: 18),
            label: const Text('Explore'),
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              foregroundColor: cs.primary,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows the candidate's template tones grouped as played chord tones, missing
/// required tones, and any extra/conflicting tones that were played anyway.
class _TemplateLedger extends StatelessWidget {
  const _TemplateLedger({required this.ledger});

  final ToneLedger ledger;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ToneGroup(label: 'Chord tones', tones: ledger.chordTones),
        if (ledger.missing.isNotEmpty)
          _ToneGroup(label: 'Missing', tones: ledger.missing, muted: true),
        if (ledger.alsoPlayed.isNotEmpty)
          _ToneGroup(label: 'Also played', tones: ledger.alsoPlayed),
      ],
    );
  }
}

class _ToneGroup extends StatelessWidget {
  const _ToneGroup({
    required this.label,
    required this.tones,
    this.muted = false,
  });

  final String label;
  final List<ToneEntry> tones;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final tone in tones) _ToneChip(tone: tone, muted: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ToneChip extends StatelessWidget {
  const _ToneChip({required this.tone, this.muted = false});

  final ToneEntry tone;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isBass = tone.isBass;
    final foreground = isBass
        ? cs.onPrimaryContainer
        : muted
        ? cs.onSurfaceVariant
        : cs.onSurface;
    final fill = isBass
        ? cs.primaryContainer
        : muted
        ? cs.surface
        : cs.surfaceContainer;

    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(
          color: isBass ? cs.primary : cs.outlineVariant.withValues(alpha: 0.6),
          width: 1.5,
        ),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: tone.degree,
              style: theme.textTheme.labelSmall?.copyWith(
                color: foreground.withValues(alpha: 0.7),
              ),
            ),
            const TextSpan(text: '  '),
            TextSpan(
              text: tone.note,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    if (!isBass) return chip;

    return Semantics(
      label: '${tone.note}, ${tone.degree}, bass note',
      child: ExcludeSemantics(child: chip),
    );
  }
}

class _CostRow extends StatelessWidget {
  const _CostRow({
    required this.label,
    required this.value,
    this.signed = true,
    this.emphasized = false,
  });

  final String label;
  final double value;
  final bool signed;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = emphasized
        ? theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyMedium;
    final valueLabel =
        '${signed && value > 0 ? '+' : ''}${value.toStringAsFixed(2)}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(valueLabel, style: style),
        ],
      ),
    );
  }
}

enum _CandidateTier {
  chosen('Chosen'),
  possible('Possible'),
  unlikely('Unlikely');

  const _CandidateTier(this.label);

  final String label;
}

enum _TierDot { filled, hollow, none }

/// Tier marker shown on each candidate card. Color separates the tiers in the
/// six seeded palettes; the dot shape (filled, hollow, or absent) encodes the
/// tier on its own, so all three stay distinguishable in the all-gray Neutral
/// palette where primary, tertiary, and onSurfaceVariant nearly coincide.
class _TierMarker extends StatelessWidget {
  const _TierMarker({required this.tier});

  final _CandidateTier tier;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final (color, dot, weight) = switch (tier) {
      _CandidateTier.chosen => (cs.primary, _TierDot.filled, FontWeight.w700),
      _CandidateTier.possible => (
        cs.tertiary,
        _TierDot.hollow,
        FontWeight.w700,
      ),
      _CandidateTier.unlikely => (
        cs.onSurfaceVariant,
        _TierDot.none,
        FontWeight.w500,
      ),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dot != _TierDot.none) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dot == _TierDot.filled ? color : Colors.transparent,
              border: dot == _TierDot.hollow
                  ? Border.all(color: color, width: 1.5)
                  : null,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          tier.label,
          style: theme.textTheme.labelMedium?.copyWith(
            color: color,
            fontWeight: weight,
          ),
        ),
      ],
    );
  }
}

class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, required this.tier});

  final int rank;
  final _CandidateTier tier;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Mirrors the tier marker: filled for Chosen, a tertiary ring for Possible,
    // and a soft neutral fill for Unlikely.
    final (fill, border, foreground) = switch (tier) {
      _CandidateTier.chosen => (cs.primary, null, cs.onPrimary),
      _CandidateTier.possible => (Colors.transparent, cs.tertiary, cs.tertiary),
      _CandidateTier.unlikely => (
        cs.surfaceContainerHighest,
        null,
        cs.onSurfaceVariant,
      ),
    };

    return ExcludeSemantics(
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: fill,
          shape: BoxShape.circle,
          border: border == null ? null : Border.all(color: border, width: 1.5),
        ),
        child: Text(
          '$rank',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: foreground,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _EmptyRankingDetails extends StatelessWidget {
  const _EmptyRankingDetails();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Text('No chord ranking details are available right now.'),
    );
  }
}

String _evidenceFor(ExplainedCandidate row) {
  final id = row.candidate.identity;
  final degrees = ChordMemberDegreeFormatter.formatDegrees(
    identity: id,
    pitchClasses: ChordPresentationBuilder.chordMemberPitchClassesFromMask(
      rootPc: id.rootPc,
      presentIntervalsMask: id.presentIntervalsMask,
    ),
  ).map(toGlyphAccidentals).toList(growable: false);
  final bassRole = _bassRoleLabel(id);
  final requiredCount = _reasonCount(row, 'required tones');
  final optionalCount = _reasonCount(row, 'optional tones');
  final missingCount = _reasonCount(row, 'missing required');
  final penaltyCount = _reasonCount(row, 'penalty tones');
  final extrasCount = _reasonCount(row, 'extras');
  final parts = <String>[];

  if (degrees.isNotEmpty && requiredCount != null && requiredCount > 0) {
    final matchParts = <String>[
      '${_quantityWord(requiredCount)} matching structural ${requiredCount == 1 ? 'tone' : 'tones'}',
    ];
    if (optionalCount != null && optionalCount > 0) {
      matchParts.add(
        '${_quantityWord(optionalCount)} matching color ${optionalCount == 1 ? 'tone' : 'tones'}',
      );
    }

    parts.add('Uses ${degrees.join(', ')}, with ${matchParts.join(' and ')}');
  } else if (degrees.isNotEmpty) {
    parts.add('Uses ${degrees.join(', ')}');
  } else if (requiredCount != null && requiredCount > 0) {
    parts.add(
      'Matches ${_quantityWord(requiredCount)} structural ${requiredCount == 1 ? 'tone' : 'tones'}',
    );
  }
  if (missingCount != null && missingCount > 0) {
    parts.add(
      '${_quantityWord(missingCount)} expected ${missingCount == 1 ? 'tone is' : 'tones are'} missing',
    );
  }
  if (penaltyCount != null && penaltyCount > 0) {
    parts.add(
      '${_quantityWord(penaltyCount)} conflicting ${penaltyCount == 1 ? 'tone' : 'tones'}',
    );
  }
  if (extrasCount != null && extrasCount > 0) {
    parts.add(
      '${_quantityWord(extrasCount)} additional ${extrasCount == 1 ? 'color increases' : 'colors increase'} complexity',
    );
  }
  parts.add('bass is $bassRole');

  return '${parts.join('; ')}.';
}

String _quantityWord(int quantity) {
  return switch (quantity) {
    0 => 'zero',
    1 => 'one',
    2 => 'two',
    3 => 'three',
    4 => 'four',
    5 => 'five',
    6 => 'six',
    7 => 'seven',
    8 => 'eight',
    9 => 'nine',
    10 => 'ten',
    11 => 'eleven',
    12 => 'twelve',
    _ => '$quantity',
  };
}

String _bassRoleLabel(ChordIdentity id) {
  if (!id.hasSlashBass) return 'the root';

  final interval = (id.bassPc - id.rootPc) % 12;
  final role = id.toneRolesByInterval[interval];
  if (role == null) return 'outside the basic chord';

  return _roleLabel(role);
}

String _roleLabel(ChordToneRole role) {
  return switch (role) {
    ChordToneRole.root => 'the root',
    ChordToneRole.sus2 => 'the suspended second',
    ChordToneRole.flat9 => 'the flat nine',
    ChordToneRole.nine => 'the nine',
    ChordToneRole.sharp9 => 'the sharp nine',
    ChordToneRole.add9 => 'the added nine',
    ChordToneRole.addSharp9 => 'the added sharp nine',
    ChordToneRole.minor3 => 'the minor third',
    ChordToneRole.splitMinor3 => 'the split minor third',
    ChordToneRole.major3 => 'the major third',
    ChordToneRole.sus4 => 'the suspended fourth',
    ChordToneRole.eleven => 'the eleven',
    ChordToneRole.sharp11 => 'the sharp eleven',
    ChordToneRole.add11 => 'the added eleven',
    ChordToneRole.flat5 => 'the flat five',
    ChordToneRole.perfect5 => 'the fifth',
    ChordToneRole.sharp5 => 'the sharp five',
    ChordToneRole.sixth => 'the sixth',
    ChordToneRole.flat13 => 'the flat thirteen',
    ChordToneRole.thirteen => 'the thirteen',
    ChordToneRole.add13 => 'the added thirteen',
    ChordToneRole.dim7 => 'the diminished seventh',
    ChordToneRole.flat7 => 'the flat seven',
    ChordToneRole.major7 => 'the major seventh',
  };
}

int? _reasonCount(ExplainedCandidate row, String label) {
  for (final reason in row.costReasons) {
    if (reason.label != label) continue;
    return reason.count;
  }
  return null;
}
