import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import 'adaptive_side_sheet.dart';

/// Shows the Analysis Details modal bottom sheet for the given identity.
Future<void> showAnalysisDetailsSheet(
  BuildContext context, {
  required IdentityDisplay identity,
}) async {
  final copyText = identity.debugText?.trimRight();
  final canCopy = copyText != null && copyText.isNotEmpty;

  if (useHomeSideSheet(context)) {
    await showHomeSideSheet<void>(
      context: context,
      barrierLabel: 'Dismiss analysis details',
      builder: (_) => _AnalysisDetailsContent(
        identity: identity,
        canCopy: canCopy,
        copyText: copyText,
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

      final maxHeight = mq.size.height * 0.75;

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: _AnalysisDetailsContent(
          identity: identity,
          canCopy: canCopy,
          copyText: copyText,
        ),
      );
    },
  );
}

class _AnalysisDetailsContent extends StatelessWidget {
  const _AnalysisDetailsContent({
    required this.identity,
    required this.canCopy,
    required this.copyText,
    this.showCloseButton = false,
  });

  final IdentityDisplay identity;
  final bool canCopy;
  final String? copyText;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final isSideSheet = showCloseButton;
    final panelColor = t.colorScheme.surfaceContainerLow;
    final debugBoxColor = t.colorScheme.surface;

    return Material(
      color: panelColor,
      child: Padding(
        padding: isSideSheet
            ? const EdgeInsets.fromLTRB(0, 0, 0, 16)
            : const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSideSheet)
              const ModalPanelHeader(
                title: 'Analysis Details',
                showCloseButton: true,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        header: true,
                        child: Text(
                          'Analysis Details',
                          style: t.textTheme.titleLarge,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Flexible(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: isSideSheet ? 16 : 0),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(
                        identity.longLabel,
                        style: t.textTheme.bodyLarge,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),
                      if (!canCopy)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'No debug info available.',
                            style: t.textTheme.bodyMedium,
                          ),
                        )
                      else
                        _DebugCopyBox(
                          text: copyText!,
                          style: t.textTheme.bodyMedium,
                          background: debugBoxColor,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isSideSheet ? 16 : 0),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: canCopy
                          ? () async {
                              await Clipboard.setData(
                                ClipboardData(text: copyText!),
                              );
                              if (context.mounted) {
                                await SemanticsService.sendAnnouncement(
                                  View.of(context),
                                  'Copied analysis details',
                                  Directionality.of(context),
                                );
                              }

                              await HapticFeedback.lightImpact();
                            }
                          : null,
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Semantics(
                      container: true,
                      button: true,
                      label: 'Report issue. Opens help and support.',
                      onTapHint: 'Open help and support',
                      excludeSemantics: true,
                      child: OutlinedButton.icon(
                        onPressed: () => showSupportSheet(
                          context,
                          supportContext: SupportSheetContext.analysisDetails,
                        ),
                        icon: const Icon(Icons.bug_report_outlined),
                        label: const Row(
                          children: [
                            Text('Report Issue'),
                            Spacer(),
                            Icon(Icons.chevron_right, size: 18),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebugCopyBox extends StatefulWidget {
  const _DebugCopyBox({
    required this.text,
    required this.style,
    required this.background,
  });

  final String text;
  final TextStyle? style;
  final Color background;

  @override
  State<_DebugCopyBox> createState() => _DebugCopyBoxState();
}

class _DebugCopyBoxState extends State<_DebugCopyBox> {
  late final ScrollController debugTextScrollController = ScrollController();

  // Whether to show fade on each side.
  bool _showLeftFade = false;
  bool _showRightFade = false;

  // Width in logical pixels of the fade region.
  static const double _fadeWidth = 24.0;

  @override
  void initState() {
    super.initState();
    debugTextScrollController.addListener(_updateFades);
    // Initial compute happens in the first post-frame callback.
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void didUpdateWidget(covariant _DebugCopyBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      // Recompute after layout when text changes.
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
    }
  }

  @override
  void dispose() {
    debugTextScrollController.removeListener(_updateFades);
    debugTextScrollController.dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!debugTextScrollController.hasClients) return;

    final pos = debugTextScrollController.position;

    // If there is no scroll extent, no fades.
    final hasOverflow = pos.maxScrollExtent > 0.0;

    // Use a small epsilon to avoid flicker near the ends.
    const eps = 0.5;
    final atStart = pos.pixels <= eps;
    final atEnd = pos.pixels >= (pos.maxScrollExtent - eps);

    final nextLeft = hasOverflow && !atStart;
    final nextRight = hasOverflow && !atEnd;

    if (nextLeft != _showLeftFade || nextRight != _showRightFade) {
      setState(() {
        _showLeftFade = nextLeft;
        _showRightFade = nextRight;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const innerPadding = 12.0;

    final baseStyle = widget.style ?? DefaultTextStyle.of(context).style;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(innerPadding),
      decoration: BoxDecoration(
        color: widget.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Recompute fades whenever width changes (rotation, split-screen, etc.).
          WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());

          final scrollable = SingleChildScrollView(
            controller: debugTextScrollController,
            scrollDirection: Axis.horizontal,
            child: Semantics(
              container: true,
              label: 'Debug details',
              hint: 'Horizontally scrollable text.',
              child: Align(
                alignment: Alignment.centerLeft,
                child: SelectableText(widget.text, style: baseStyle),
              ),
            ),
          );

          return Stack(
            children: [
              // The scrollable text.
              scrollable,

              // Left fade overlay (only when not at start).
              if (_showLeftFade)
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
                            widget.background,
                            widget.background.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // Right fade overlay (only when not at end).
              if (_showRightFade)
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
                            widget.background,
                            widget.background.withValues(alpha: 0.0),
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
    );
  }
}
