import 'package:material_ui/material_ui.dart';

/// Shared app-specific color tokens that are not part of Material ColorScheme.
class AppColors {
  AppColors._();

  // Match the previous Cupertino dark-mode green.
  static const Color _midiConnectedDark = Color(0xFF30D158);
  // Slightly darker than Cupertino light-mode green to improve contrast.
  static const Color _midiConnectedLight = Color(0xFF2AA84A);

  static Color midiConnected(Brightness brightness) {
    return brightness == Brightness.dark
        ? _midiConnectedDark
        : _midiConnectedLight;
  }
}
