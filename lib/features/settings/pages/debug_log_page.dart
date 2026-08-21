import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';

import 'package:whatchord_app/core/core.dart';

/// Viewer for [DebugLogBuffer]: captured debugPrint diagnostics with a
/// copy-to-clipboard action, so untethered profile-build sessions can be
/// inspected and handed off (e.g. via Universal Clipboard).
class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  List<String> _lines = DebugLogBuffer.instance.snapshot();

  void _refresh() {
    setState(() => _lines = DebugLogBuffer.instance.snapshot());
  }

  Future<void> _copyAll() async {
    final messenger = Theme.of(context).platform == TargetPlatform.iOS
        ? ScaffoldMessenger.maybeOf(context)
        : null;

    await Clipboard.setData(ClipboardData(text: _lines.join('\n')));

    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(content: Text('Copied ${_lines.length} log lines')),
    );
  }

  void _clear() {
    DebugLogBuffer.instance.clear();
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Console Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
          IconButton(
            icon: const Icon(Icons.copy_all),
            tooltip: 'Copy all',
            onPressed: _lines.isEmpty ? null : _copyAll,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Clear',
            onPressed: _lines.isEmpty ? null : _clear,
          ),
        ],
      ),
      body: _lines.isEmpty
          ? const Center(child: Text('No diagnostics captured yet.'))
          : Scrollbar(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  // Unwrapped lines scroll horizontally; wrapping makes the
                  // log much harder to scan.
                  scrollDirection: Axis.horizontal,
                  child: SelectableText(
                    _lines.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'Menlo',
                      fontFamilyFallback: ['monospace'],
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
