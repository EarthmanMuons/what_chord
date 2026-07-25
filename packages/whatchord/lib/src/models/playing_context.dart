/// The playing situation the analyzer assumes.
///
/// [solo] assumes the player sounds complete chords, root included. [ensemble]
/// assumes another instrument may cover the root, making rootless voicings
/// eligible for implied-root readings.
enum PlayingContext { solo, ensemble }
