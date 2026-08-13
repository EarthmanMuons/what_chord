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

// Polychord analysis
export 'src/polychord/models/polychord_candidate.dart';
export 'src/polychord/models/polychord_candidate_instance_binding.dart';
export 'src/polychord/models/polychord_frame_transition_evidence.dart';
export 'src/polychord/models/polychord_motion_support.dart';
export 'src/polychord/models/polychord_onset_evidence.dart';
export 'src/polychord/models/polychord_onset_support.dart';
export 'src/polychord/models/polychord_onset_tracking_frame.dart';
export 'src/polychord/models/polychord_release_pedal_evidence.dart';
export 'src/polychord/models/polychord_sounding_instance_key.dart';
export 'src/polychord/models/polychord_temporal_event.dart';
export 'src/polychord/services/polychord_candidate_instance_binder.dart';
export 'src/polychord/services/polychord_onset_evidence_analyzer.dart';
export 'src/polychord/services/polychord_onset_tracker.dart';
export 'src/polychord/services/polychord_coherent_separated_onset_interpreter.dart';
export 'src/polychord/services/polychord_frame_transition_evidence_analyzer.dart';
export 'src/polychord/services/polychord_register_candidate_generator.dart';
export 'src/polychord/services/polychord_register_selector.dart';
export 'src/polychord/services/polychord_release_pedal_evidence_analyzer.dart';
export 'src/polychord/services/polychord_release_pedal_tracker.dart';
export 'src/polychord/services/polychord_rigid_layer_motion_interpreter.dart';
export 'src/polychord/services/polychord_stable_display_gate.dart';

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
