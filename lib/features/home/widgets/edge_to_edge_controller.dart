import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:whatchord_app/core/core.dart';

class EdgeToEdgeController extends StatefulWidget {
  const EdgeToEdgeController({super.key, required this.child});

  final Widget child;

  @override
  State<EdgeToEdgeController> createState() => _EdgeToEdgeControllerState();
}

class _EdgeToEdgeControllerState extends State<EdgeToEdgeController> {
  @override
  void initState() {
    super.initState();
    // Idempotent: safe to call; aligns with Android 15+ default.
    unawaited(SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge));
  }

  @override
  Widget build(BuildContext context) {
    // Keep bars transparent so edge-to-edge looks intentional.
    SystemChrome.setSystemUIOverlayStyle(
      systemUiOverlayStyleFor(Theme.of(context).brightness),
    );

    return widget.child;
  }
}
