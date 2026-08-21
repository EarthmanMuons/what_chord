import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/features/demo/demo.dart';

class AppBarTitle extends ConsumerWidget {
  const AppBarTitle({super.key, this.maxHeight});

  final double? maxHeight;

  // Set to true for ad-hoc demo builds (e.g. iOS device untethered from Xcode).
  static const bool kForceDemoSupport = false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseStyle = DefaultTextStyle.of(context).style;
    final titleStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 20) + 2,
      letterSpacing: -0.2,
    );

    final title = Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'What'),
          TextSpan(
            text: 'Chord',
            style: titleStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
      style: titleStyle,
      semanticsLabel: 'What Chord',
      maxLines: 1,
      overflow: TextOverflow.clip,
      softWrap: false,
    );

    final enableGestures = kDebugMode || kProfileMode || kForceDemoSupport;
    if (!enableGestures) return title;

    final demoEnabled = ref.watch(demoModeProvider);
    final demoVariant = ref.watch(demoModeVariantProvider);
    final screenshotDemoEnabled =
        demoEnabled && demoVariant == DemoModeVariant.screenshot;
    final modeNotifier = ref.read(demoModeProvider.notifier);
    final seqNotifier = ref.read(demoSequenceProvider.notifier);

    Future<void> toggleDemoVariant(DemoModeVariant variant) async {
      if (demoEnabled) {
        modeNotifier.setEnabledFor(enabled: false, variant: demoVariant);
        await HapticFeedback.lightImpact();
        return;
      }

      modeNotifier.setEnabledFor(enabled: true, variant: variant);
      await HapticFeedback.lightImpact();
    }

    void prev() {
      if (!screenshotDemoEnabled) return;
      seqNotifier.prev();
      modeNotifier.applyCurrentStep();
    }

    void next() {
      if (!screenshotDemoEnabled) return;
      seqNotifier.next();
      modeNotifier.applyCurrentStep();
    }

    Widget word({
      required String text,
      required TextStyle style,
      required VoidCallback onTap,
      required Future<void> Function() onLongPress,
    }) {
      return GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        onLongPress: () => onLongPress(),
        child: Text(text, style: style),
      );
    }

    final debugTitle = Text.rich(
      TextSpan(
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: word(
              text: 'What',
              style: titleStyle,
              onTap: prev,
              onLongPress: () => toggleDemoVariant(DemoModeVariant.animation),
            ),
          ),
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: word(
              text: 'Chord',
              style: titleStyle.copyWith(fontWeight: FontWeight.w600),
              onTap: next,
              onLongPress: () => toggleDemoVariant(DemoModeVariant.screenshot),
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.clip,
      softWrap: false,
    );
    return _clampToHeight(context, debugTitle);
  }

  Widget _clampToHeight(BuildContext context, Widget title) {
    final maxHeight = this.maxHeight;
    if (maxHeight == null) return title;

    return SizedBox(
      height: maxHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: title,
        ),
      ),
    );
  }
}
