abstract class MidiConstants {
  /// MIDI note range: 0-127 (middle C = 60)
  static const int minNote = 0;
  static const int maxNote = 127;
  static const int middleC = 60;

  /// Control Change (CC) numbers.
  static const int ccSustainPedal = 64;
  static const int ccAllSoundOff = 120;
  static const int ccAllNotesOff = 123;
  static const int sustainPedalThreshold = 64; // >= 64 is "down"

  /// Whether a CC ends every sounding note.
  ///
  /// All Sound Off and All Notes Off differ in the sound they leave ringing,
  /// but the normalized model tracks what is held, not what is audible, so
  /// both mean the same thing here: nothing carries through.
  static bool endsAllNotes(int? ccNumber) =>
      ccNumber == ccAllSoundOff || ccNumber == ccAllNotesOff;

  /// Velocity range: 0-127 (0 in NoteOn = NoteOff)
  static const int minVelocity = 0;
  static const int maxVelocity = 127;
}
