import 'package:flutter_riverpod/misc.dart';

import '../models/input_note_event.dart';
import '../models/input_temporal_event.dart';

typedef NoteEventsSource = ProviderListenable<Stream<InputNoteEvent>>;
typedef NoteNumbersSource = ProviderListenable<Set<int>>;
typedef PedalDownSource = ProviderListenable<bool>;
typedef TemporalEventsSource = ProviderListenable<Stream<InputTemporalEvent>>;
