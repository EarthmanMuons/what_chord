import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:whatchord/whatchord.dart';

import 'package:whatchord_app/core/providers/shared_preferences_provider.dart';

import '../persistence/theory_preferences_keys.dart';

final playingContextProvider =
    NotifierProvider<PlayingContextNotifier, PlayingContext>(
      PlayingContextNotifier.new,
    );

/// Persisted playing context; defaults to solo. Ensemble makes rootless
/// voicings eligible for implied-root readings, so the setting changes live
/// naming globally and the home screen shows an indicator while it is on.
class PlayingContextNotifier extends Notifier<PlayingContext> {
  @override
  PlayingContext build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final saved = prefs.getString(TheoryPreferencesKeys.playingContext);
    return PlayingContext.values.asNameMap()[saved] ?? PlayingContext.solo;
  }

  Future<void> setContext(PlayingContext playingContext) async {
    if (playingContext == state) return;
    state = playingContext;
    await ref
        .read(sharedPreferencesProvider)
        .setString(TheoryPreferencesKeys.playingContext, playingContext.name);
  }
}
