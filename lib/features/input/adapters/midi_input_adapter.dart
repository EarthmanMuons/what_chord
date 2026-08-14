import 'package:whatchord_app/features/midi/midi_input_source.dart';

import 'source_types.dart';

final NoteEventsSource midiNoteEventsSource = midiNoteEventsProvider;
final NoteNumbersSource midiNoteNumbersSource = midiSoundingNoteNumbersProvider;
final PedalDownSource midiPedalDownSource = midiPedalDownProvider;
final TemporalEventsSource midiTemporalEventsSource =
    midiTemporalEventsProvider;
