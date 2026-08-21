import 'package:material_ui/material_ui.dart';

import '../services/open_url.dart';
import 'modal_panel_header.dart';
import 'modal_sheet_sizing.dart';

enum SupportSheetContext { general, analysisDetails }

Future<void> showSupportSheet(
  BuildContext context, {
  SupportSheetContext supportContext = SupportSheetContext.general,
  VoidCallback? onReplayTour,
}) async {
  final shortestSide = MediaQuery.sizeOf(context).shortestSide;
  final isCompact = shortestSide < 600;

  if (isCompact) {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: modalBottomSheetMaxHeight(context),
          ),
          child: _SupportSheetContent(
            supportContext: supportContext,
            onReplayTour: onReplayTour,
          ),
        );
      },
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 480,
            maxHeight: MediaQuery.sizeOf(context).height * 0.72,
          ),
          child: _SupportSheetContent(
            supportContext: supportContext,
            onReplayTour: onReplayTour,
            showCloseButton: true,
          ),
        ),
      );
    },
  );
}

class _SupportSheetContent extends StatelessWidget {
  const _SupportSheetContent({
    required this.supportContext,
    this.onReplayTour,
    this.showCloseButton = false,
  });

  final SupportSheetContext supportContext;
  final VoidCallback? onReplayTour;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = supportContext == SupportSheetContext.analysisDetails
        ? 'Report a Chord Issue'
        : 'Help & Support';

    return Material(
      color: colorScheme.surfaceContainerLow,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ModalPanelHeader(title: title, showCloseButton: showCloseButton),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Divider(height: 1),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              children: [
                if (supportContext == SupportSheetContext.analysisDetails)
                  const _SupportBodyText(
                    'For chord identification reports, copy Analysis Details first when possible. It includes the exact notes, key context, and app version needed to reproduce the result.',
                  )
                else ...[
                  if (onReplayTour != null) ...[
                    Semantics(
                      onTapHint: 'Start the guided tour',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.play_circle_outline),
                        title: const Text('Take a Tour'),
                        subtitle: const Text('Replay the guided walkthrough'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).pop();
                          onReplayTour!();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                  ],
                  const _SupportInstruction(
                    action: 'Tap the chord card',
                    description:
                        'to explore chords with different roots, qualities, extensions, and bass notes.',
                  ),
                  const SizedBox(height: 8),
                  const _SupportInstruction(
                    action: 'Tap an alternative',
                    description:
                        'to see why WhatChord ranked the current chord first.',
                  ),
                  const SizedBox(height: 8),
                  const _SupportInstruction(
                    action: 'Tap the scale-degree strip',
                    description:
                        'to explore scale tones, keyboard patterns, and diatonic chords.',
                  ),
                  const SizedBox(height: 8),
                  const _SupportInstruction(
                    action: 'Long-press the chord card',
                    description:
                        'to show diagnostic details for reporting a chord result.',
                  ),
                  const SizedBox(height: 16),
                  const _SupportSectionTitle('Reference'),
                  const SizedBox(height: 8),
                  _SupportActionTile(
                    icon: Icons.menu_book_outlined,
                    title: 'Chord Symbol Guide',
                    subtitle: 'Notation and formatting conventions',
                    onTapHint: 'Open the chord symbol guide in browser',
                    onTap: () => openUrl(
                      context,
                      Uri.parse(
                        'https://whatchord.earthmanmuons.com/articles/chord-symbols.html',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const _SupportSectionTitle('Get Support'),
                const SizedBox(height: 8),
                _SupportActionTile(
                  icon: Icons.bug_report_outlined,
                  title: 'Report on GitHub',
                  subtitle: 'Best for tracked bugs and chord analysis issues',
                  onTapHint: 'Open GitHub issues in browser',
                  onTap: () => openUrl(
                    context,
                    Uri.parse(
                      'https://github.com/EarthmanMuons/whatchord/issues/new/choose',
                    ),
                  ),
                ),
                _SupportActionTile(
                  icon: Icons.email_outlined,
                  title: 'Email Support',
                  subtitle: 'No GitHub account required',
                  onTapHint: 'Open email app',
                  onTap: () => openUrl(
                    context,
                    Uri.parse('mailto:support@earthmanmuons.com'),
                    failureMessage: 'Could not open email app',
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

class _SupportSectionTitle extends StatelessWidget {
  const _SupportSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

class _SupportBodyText extends StatelessWidget {
  const _SupportBodyText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: Theme.of(context).textTheme.bodyMedium);
  }
}

class _SupportInstruction extends StatelessWidget {
  const _SupportInstruction({required this.action, required this.description});

  final String action;
  final String description;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;

    return Semantics(
      label: '$action $description',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•', style: style),
            const SizedBox(width: 8),
            Expanded(
              child: Text.rich(
                TextSpan(
                  style: style,
                  children: [
                    TextSpan(
                      text: '$action ',
                      style: style?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    TextSpan(text: description),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupportActionTile extends StatelessWidget {
  const _SupportActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTapHint,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String onTapHint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      onTapHint: onTapHint,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.open_in_new),
        onTap: onTap,
      ),
    );
  }
}
