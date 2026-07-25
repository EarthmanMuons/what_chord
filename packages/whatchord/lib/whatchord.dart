/// Chord identification and harmony analysis: [ChordAnalyzer] names and
/// explains voicings, construction derives canonical examples from a
/// [ChordSpec], and formatters render identities as symbols, spoken names,
/// long-form names, and Harte notation.
library;

// Analysis engine
export 'src/analysis/chord_analyzer.dart';
export 'src/analysis/chord_analysis_profile.dart';
export 'src/analysis/chord_candidate_ranking.dart';

// Domain models
export 'src/models/analysis_context.dart';
export 'src/models/chord_candidate.dart';
export 'src/models/chord_extension.dart';
export 'src/models/chord_identity.dart';
export 'src/models/chord_input.dart';
export 'src/models/chord_tone_role.dart';
export 'src/models/observed_voicing.dart';
export 'src/models/key_signature.dart';
export 'src/models/note_spelling_policy.dart';
export 'src/models/playing_context.dart';
export 'src/models/scale.dart';
export 'src/models/scale_degree.dart';
export 'src/models/tonic.dart';
export 'src/models/tonality.dart';

// Domain services
export 'src/services/chord_member_degree_formatter.dart';
export 'src/services/chord_member_speller.dart';
export 'src/services/chord_quality_intervals.dart';
export 'src/services/chord_tone_ordering.dart';
export 'src/services/bit_masks.dart';
export 'src/services/note_spelling.dart';
export 'src/services/pitch_class.dart';
export 'src/services/scale_degree_classifier.dart';
export 'src/services/scale_degree_function.dart';
export 'src/services/scale_degree_roman_numerals.dart';
export 'src/services/scale_harmonizer.dart';
export 'src/services/scale_tonic_choices.dart';
export 'src/services/scale_voicing.dart';

// Temporal context: committed chords from live play
export 'src/temporal/chord_event.dart';
export 'src/temporal/chord_event_segmenter.dart';

// Construction: canonical chord examples from a selected spec
export 'src/construction/models/chord_example.dart';
export 'src/construction/models/chord_spec.dart';
export 'src/construction/models/chord_construction.dart';
export 'src/construction/services/chord_example_builder.dart';
export 'src/construction/services/extension_options.dart';
export 'src/construction/services/construction_transitions.dart';
export 'src/construction/services/seed_derivation.dart';

// Presentation models
export 'src/formatting/models/chord_presentation.dart';
export 'src/formatting/models/chord_symbol.dart';

// Formatters
export 'src/formatting/services/chord_long_form_formatter.dart';
export 'src/formatting/services/chord_presentation_builder.dart';
export 'src/formatting/services/chord_quality_labels.dart';
export 'src/formatting/services/chord_spoken_name_formatter.dart';
export 'src/formatting/services/chord_symbol_builder.dart';
export 'src/formatting/services/harte_chord_formatter.dart';
export 'src/formatting/services/interval_formatter.dart';
export 'src/formatting/services/inversion_formatter.dart';
export 'src/formatting/services/note_display_formatter.dart';
export 'src/formatting/services/note_long_form_formatter.dart';
export 'src/formatting/services/scale_degree_chord_symbol.dart';
