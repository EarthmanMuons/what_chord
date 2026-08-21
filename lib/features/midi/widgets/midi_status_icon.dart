import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/app_colors.dart';
import '../models/midi_connection.dart';
import '../models/midi_connection_status.dart';
import '../models/midi_device.dart';
import '../pages/midi_settings_page.dart';
import '../providers/midi_connection_status_provider.dart';

class MidiStatusIcon extends ConsumerWidget {
  const MidiStatusIcon({super.key, this.onPressed, this.iconButtonKey});

  final VoidCallback? onPressed;
  final Key? iconButtonKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(midiConnectionStatusProvider);
    return _MidiStatusIconButton(
      status: status,
      onPressed: onPressed,
      iconButtonKey: iconButtonKey,
    );
  }
}

class _MidiStatusIconButton extends StatefulWidget {
  const _MidiStatusIconButton({
    required this.status,
    this.onPressed,
    this.iconButtonKey,
  });

  final MidiConnectionStatus status;
  final VoidCallback? onPressed;
  final Key? iconButtonKey;

  @override
  State<_MidiStatusIconButton> createState() => _MidiStatusIconButtonState();
}

class _MidiStatusIconButtonState extends State<_MidiStatusIconButton>
    with SingleTickerProviderStateMixin {
  static const Duration _pulseDuration = Duration(milliseconds: 900);
  static const Duration _pulseInterval = Duration(seconds: 25);
  static const double _maxScaleDelta = 0.08;

  late final AnimationController _pulseController;
  late final Animation<double> _pulseCurve;
  Timer? _pulseTimer;
  bool _hasInteracted = false;

  bool get _shouldPulse =>
      widget.status.phase == MidiConnectionPhase.idle && !_hasInteracted;
  bool get _disableAnimations => WidgetsBinding
      .instance
      .platformDispatcher
      .accessibilityFeatures
      .disableAnimations;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: _pulseDuration,
    );
    _pulseCurve = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _pulseController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        unawaited(_pulseController.reverse());
      }
    });
    _syncPulseTimer();
  }

  @override
  void didUpdateWidget(covariant _MidiStatusIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.phase != widget.status.phase) {
      _syncPulseTimer();
    }
  }

  void _syncPulseTimer() {
    _pulseTimer?.cancel();
    if (_shouldPulse && !_disableAnimations) {
      _pulseTimer = Timer.periodic(_pulseInterval, (_) => _triggerPulse());
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  void _triggerPulse() {
    if (!_shouldPulse || _pulseController.isAnimating) return;
    unawaited(_pulseController.forward(from: 0));
  }

  void _handlePressed() {
    if (!_hasInteracted) {
      setState(() {
        _hasInteracted = true;
      });
      _syncPulseTimer();
    }
    final handler = widget.onPressed;
    if (handler != null) {
      handler();
      return;
    }
    unawaited(
      Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => const MidiSettingsPage())),
    );
  }

  @override
  void dispose() {
    _pulseTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final presentation = _resolvePresentation(context, widget.status, cs);

    return Semantics(
      container: true,
      label: _semanticsLabel(widget.status),
      hint: 'Open MIDI settings.',
      onTapHint: 'Open MIDI settings',
      button: true,
      excludeSemantics: true,
      onTap: _handlePressed,
      child: AnimatedBuilder(
        animation: _pulseCurve,
        builder: (context, child) {
          final scale = 1.0 + (_maxScaleDelta * _pulseCurve.value);
          return Transform.scale(scale: scale, child: child);
        },
        child: IconButton(
          key: widget.iconButtonKey,
          tooltip: presentation.tooltip,
          icon: presentation.icon,
          color: presentation.iconColor,
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          style: IconButton.styleFrom(
            backgroundColor: presentation.backgroundColor,
            side: BorderSide(color: presentation.borderColor),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.all(8),
            minimumSize: const Size(48, 48),
          ),
          onPressed: _handlePressed,
        ),
      ),
    );
  }

  ({
    Widget icon,
    Color iconColor,
    Color backgroundColor,
    Color borderColor,
    String tooltip,
  })
  _resolvePresentation(
    BuildContext context,
    MidiConnectionStatus status,
    ColorScheme cs,
  ) {
    final tooltip = _tooltipFromStatus(status);
    final tone = _toneForPhase(status.phase);
    final (bg, fg, border) = _resolveToneColors(tone, cs);

    switch (status.phase) {
      case MidiConnectionPhase.connected:
        final connectedIcon = switch (status.deviceTransport) {
          MidiTransportType.usb => const Icon(Icons.usb),
          MidiTransportType.network => const Icon(Icons.wifi),
          MidiTransportType.ble ||
          MidiTransportType.unknown ||
          null => const Icon(Icons.bluetooth),
        };
        return (
          icon: connectedIcon,
          iconColor: AppColors.midiConnected(Theme.of(context).brightness),
          backgroundColor: bg,
          borderColor: border,
          tooltip: tooltip,
        );

      case MidiConnectionPhase.connecting:
      case MidiConnectionPhase.retrying:
        return (
          icon: SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator.adaptive(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          iconColor: fg,
          backgroundColor: bg,
          borderColor: border,
          tooltip: tooltip,
        );

      case MidiConnectionPhase.bluetoothUnavailable:
        return (
          icon: _badgeIcon(
            base: const Icon(Icons.bluetooth_disabled),
            badgeColor: cs.error,
          ),
          iconColor: fg,
          backgroundColor: bg,
          borderColor: border,
          tooltip: tooltip,
        );

      case MidiConnectionPhase.deviceUnavailable:
        return (
          icon: _badgeIcon(
            base: const Icon(Icons.bluetooth_disabled),
            badgeColor: cs.error,
          ),
          iconColor: fg,
          backgroundColor: bg,
          borderColor: border,
          tooltip: tooltip,
        );

      case MidiConnectionPhase.error:
        return (
          icon: _badgeIcon(
            base: const Icon(Icons.bluetooth_disabled),
            badgeColor: cs.error,
          ),
          iconColor: fg,
          backgroundColor: bg,
          borderColor: border,
          tooltip: tooltip,
        );

      case MidiConnectionPhase.idle:
        return (
          icon: const Icon(Icons.bluetooth_disabled),
          iconColor: fg,
          backgroundColor: bg,
          borderColor: border,
          tooltip: tooltip,
        );
    }
  }

  _StatusTone _toneForPhase(MidiConnectionPhase phase) {
    switch (phase) {
      case MidiConnectionPhase.connected:
        return _StatusTone.normal;
      case MidiConnectionPhase.connecting:
      case MidiConnectionPhase.retrying:
        return _StatusTone.normal;
      case MidiConnectionPhase.bluetoothUnavailable:
      case MidiConnectionPhase.deviceUnavailable:
      case MidiConnectionPhase.error:
        return _StatusTone.error;
      case MidiConnectionPhase.idle:
        return _StatusTone.muted;
    }
  }

  (Color bg, Color fg, Color border) _resolveToneColors(
    _StatusTone tone,
    ColorScheme cs,
  ) {
    switch (tone) {
      case _StatusTone.normal:
        return (
          cs.secondaryContainer,
          cs.onSecondaryContainer,
          cs.outlineVariant.withValues(alpha: 0.35),
        );
      case _StatusTone.error:
        return (
          cs.errorContainer,
          cs.onErrorContainer,
          cs.outlineVariant.withValues(alpha: 0.35),
        );
      case _StatusTone.muted:
        return (
          cs.surfaceContainerHigh,
          cs.onSurfaceVariant,
          cs.outlineVariant.withValues(alpha: 0.55),
        );
    }
  }

  String _tooltipFromStatus(MidiConnectionStatus status) {
    final name = status.deviceName;
    if (status.phase == MidiConnectionPhase.connected &&
        name != null &&
        name.isNotEmpty) {
      return 'MIDI: Connected to $name';
    }

    return 'MIDI: ${status.title}';
  }

  String _semanticsLabel(MidiConnectionStatus status) {
    final name = status.deviceName;
    if (status.phase == MidiConnectionPhase.connected &&
        name != null &&
        name.isNotEmpty) {
      return 'MIDI connected to $name';
    }
    return 'MIDI ${status.title}';
  }

  Widget _badgeIcon({required Widget base, required Color badgeColor}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          right: -1,
          bottom: -1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: badgeColor,
              shape: BoxShape.circle,
            ),
            child: const Padding(
              padding: EdgeInsets.all(2),
              child: Icon(Icons.priority_high, size: 10, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

enum _StatusTone { normal, error, muted }
