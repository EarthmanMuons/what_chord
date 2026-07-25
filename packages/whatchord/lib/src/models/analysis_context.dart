import 'package:meta/meta.dart';

import '../models/key_signature.dart';
import '../models/note_spelling_policy.dart';
import '../models/playing_context.dart';
import '../models/tonality.dart';

/// Context that can bias chord analysis and control spelling/formatting.
///
/// This keeps the analyzer signature stable as new bias sources are added.
@immutable
class AnalysisContext {
  /// The prevailing key, used to bias ranking and spelling.
  final Tonality tonality;

  /// The key signature, used for enharmonic spelling decisions.
  final KeySignature keySignature;

  /// Fallback spelling preference where the key signature does not decide.
  final NoteSpellingPolicy spellingPolicy;

  /// The assumed playing situation; gates rootless-voicing analysis.
  final PlayingContext playingContext;

  const AnalysisContext({
    required this.tonality,
    required this.keySignature,
    required this.spellingPolicy,
    this.playingContext = PlayingContext.solo,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisContext &&
          tonality == other.tonality &&
          keySignature.accidentalCount == other.keySignature.accidentalCount &&
          spellingPolicy.preferFlats == other.spellingPolicy.preferFlats &&
          playingContext == other.playingContext;

  @override
  int get hashCode => Object.hash(
    tonality,
    keySignature.accidentalCount,
    spellingPolicy.preferFlats,
    playingContext,
  );
}
