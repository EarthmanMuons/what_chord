/// Storage keys and persisted values for music theory preferences.
class TheoryPreferencesKeys {
  static const chordNotationStyle = 'theory.chordNotationStyle';
  static const noteNameSystem = 'theory.noteNameSystem';
  static const playingContext = 'theory.playingContext';
  static const selectedTonality = 'theory.selectedTonality';
}

/// Stable serialized values for theory preferences.
class TheoryPreferencesValues {
  static const chordNotationStyleSymbolic = 'symbolic';
  static const chordNotationStyleTextual = 'textual';
  static const noteNameSystemInternational = 'international';
  static const noteNameSystemGerman = 'german';
  static const noteNameSystemFixedDo = 'fixedDo';
  static const tonalityModeMajor = 'major';
  static const tonalityModeMinor = 'minor';
}
