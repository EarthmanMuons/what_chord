import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/features/demo/demo.dart';

class DemoModeExplanation extends ConsumerWidget {
  const DemoModeExplanation({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(16, 0, 16, 8),
    this.textAlign = TextAlign.left,
  });

  final EdgeInsets padding;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final demoEnabled = ref.watch(demoModeProvider);
    final demoVariant = ref.watch(demoModeVariantProvider);
    final promptText = ref.watch(
      demoCurrentStepProvider.select((step) => step.promptText),
    );

    final showText =
        demoEnabled &&
        demoVariant == DemoModeVariant.interactive &&
        promptText != null &&
        promptText.isNotEmpty;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: showText
          ? SizedBox(
              key: ValueKey<String>(promptText),
              width: double.infinity,
              child: Padding(
                padding: padding,
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  label: promptText,
                  child: ExcludeSemantics(
                    child: Text(
                      promptText,
                      textAlign: textAlign,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox(
              key: ValueKey<String>('demo_explanation_off'),
              width: double.infinity,
            ),
    );
  }
}
