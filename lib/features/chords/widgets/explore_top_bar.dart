import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:whatchord_app/features/midi/midi.dart';
import 'package:whatchord_app/features/settings/settings.dart';

class ExploreTopBar extends StatelessWidget {
  const ExploreTopBar({
    super.key,
    required this.toolbarHeight,
    required this.contentBottomInset,
    required this.horizontalInset,
  });

  final double toolbarHeight;
  final double contentBottomInset;
  final double horizontalInset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleStyle = Theme.of(context).textTheme.titleLarge
        ?.copyWith(letterSpacing: -0.2);

    // Match the standard AppBar leading-control position while the title and
    // content retain their shared horizontal inset.
    const arrowIconDx = -12.0;

    return Material(
      color: cs.surfaceContainerLow,
      child: SizedBox(
        height: toolbarHeight,
        child: Padding(
          padding: EdgeInsets.only(
            left: horizontalInset,
            right: horizontalInset,
            bottom: contentBottomInset,
          ),
          child: Row(
            children: [
              Transform.translate(
                offset: const Offset(arrowIconDx, 0),
                child: IconButton(
                  tooltip: 'Back',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const BackButtonIcon(),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  header: true,
                  namesRoute: true,
                  child: Text(
                    'Explore Chords',
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const MidiStatusIcon(),
              const SizedBox(width: 4),
              Transform.translate(
                offset: const Offset(6, 0),
                child: IconButton(
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  tooltip: 'Settings',
                  onPressed: () {
                    unawaited(
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.settings),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
