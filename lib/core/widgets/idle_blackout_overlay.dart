import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/app_activity_state.dart';
import '../providers/app_activity_notifier.dart';
import '../services/system_ui_overlay_styles.dart';

class IdleBlackoutOverlay extends ConsumerStatefulWidget {
  const IdleBlackoutOverlay({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<IdleBlackoutOverlay> createState() =>
      _IdleBlackoutOverlayState();
}

class _IdleBlackoutOverlayState extends ConsumerState<IdleBlackoutOverlay> {
  static const _fadeOutDuration = Duration(milliseconds: 180);

  ProviderSubscription<bool>? _idleSubscription;
  Timer? _systemUiResetTimer;
  bool _blackoutSystemUiActive = false;

  @override
  void initState() {
    super.initState();

    _idleSubscription = ref.listenManual<bool>(
      appActivityProvider.select((s) => s.isIdle),
      (_, isIdle) {
        if (!mounted) return;
        _systemUiResetTimer?.cancel();

        if (isIdle) {
          setState(() {
            _blackoutSystemUiActive = true;
          });
          return;
        }

        _systemUiResetTimer = Timer(_fadeOutDuration, () {
          if (!mounted) return;
          setState(() {
            _blackoutSystemUiActive = false;
          });
        });
      },
    );
  }

  @override
  void dispose() {
    _systemUiResetTimer?.cancel();
    _idleSubscription?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIdle = ref.watch(appActivityProvider.select((s) => s.isIdle));
    final useBlackoutSystemUi = isIdle || _blackoutSystemUiActive;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: useBlackoutSystemUi
          ? blackoutSystemUiOverlayStyle
          : systemUiOverlayStyleFor(Theme.of(context).brightness),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => ref
            .read(appActivityProvider.notifier)
            .markActivity(AppActivitySource.pointer),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // IMPORTANT: keep the routed child as a normal Stack child.
            widget.child,

            // Only the overlay is positioned to fill.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true,
                child: AnimatedOpacity(
                  opacity: isIdle ? 1.0 : 0.0,
                  duration: isIdle
                      ? const Duration(milliseconds: 420)
                      : _fadeOutDuration,
                  curve: Curves.easeInOutCubic,
                  child: _BlackoutLayer(applySystemUi: useBlackoutSystemUi),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlackoutLayer extends StatelessWidget {
  const _BlackoutLayer({required this.applySystemUi});

  final bool applySystemUi;

  @override
  Widget build(BuildContext context) {
    const blackout = ColoredBox(color: Colors.black);

    if (!applySystemUi) return blackout;

    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: blackoutSystemUiOverlayStyle,
      child: blackout,
    );
  }
}
