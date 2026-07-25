import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:whatchord_app/core/core.dart';
import 'package:whatchord_app/features/lookup/lookup.dart';
import 'package:whatchord_app/features/theory/theory.dart';

import '../models/chord_link.dart';
import '../services/deep_link_service.dart';

final deepLinkServiceProvider = Provider<DeepLinkService>(
  (ref) => DeepLinkService(),
);

/// App-lifecycle hook: applies incoming `/try` deep links by seeding the lookup
/// pad and tonality. Watched once near the app root; handles both the
/// cold-start link and warm links delivered while running.
final appDeepLinkProvider = Provider<void>((ref) {
  final service = ref.watch(deepLinkServiceProvider);

  void handle(Uri uri) {
    final seed = ChordLink.parse(uri);
    if (seed == null) return;

    unawaited(
      ref.read(selectedTonalityProvider.notifier).setTonality(seed.tonality),
    );
    // The linked reading only reproduces under the sharer's playing context;
    // the mode change is visible in the tonality bar badge and in Settings.
    unawaited(
      ref.read(playingContextProvider.notifier).setContext(seed.playingContext),
    );

    // Open the pad and replace any prior selection with the linked notes.
    final lookup = ref.read(lookupModeProvider.notifier);
    lookup.enter();
    lookup.clear();
    for (final pc in seed.pitchClasses) {
      lookup.addNote(pc);
    }

    // A link may arrive while an Explore or Scale page sits atop the home
    // page; pop back to it so the seeded chord is actually visible.
    ref
        .read(appNavigatorKeyProvider)
        .currentState
        ?.popUntil((route) => route.isFirst);
  }

  unawaited(
    service.getInitialLink().then((uri) {
      if (uri != null) handle(uri);
    }),
  );

  final sub = service.uriLinkStream.listen(handle);
  ref.onDispose(sub.cancel);
});
