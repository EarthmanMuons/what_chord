"""Unit tests for the author-adjudicated polychord internal suite."""

from __future__ import annotations

import unittest
from copy import deepcopy
from pathlib import Path

import internal_suite as subject

REPO_ROOT = Path(__file__).parents[2]
SUITE_PATH = REPO_ROOT / "research/polychord/data/internal-suite/suite-v0.json"


def load_suite() -> dict:
    return subject.load_json(SUITE_PATH)


def case_by_id(payload: dict, case_id: str) -> dict:
    return next(case for case in payload["cases"] if case["id"] == case_id)


class InternalSuiteTest(unittest.TestCase):
    def test_committed_seed_and_every_dependency_validate(self) -> None:
        case_ids = subject.validate_suite(SUITE_PATH)

        self.assertEqual(len(case_ids), 15)
        self.assertEqual(case_ids, sorted(case_ids))

    def test_seed_contains_all_product_policy_classes(self) -> None:
        payload = load_suite()

        self.assertEqual(
            {case["productExpectation"]["class"] for case in payload["cases"]},
            {"positive", "boundary", "negative-guard"},
        )
        self.assertFalse(payload["scoringAllowed"])

    def test_augurs_is_a_positive_construction_not_a_register_miss(self) -> None:
        case = case_by_id(load_suite(), "stravinsky-augurs-r13")

        self.assertEqual(case["productExpectation"]["class"], "positive")
        self.assertEqual(
            case["inputEligibility"]["adjacentRegisterSnapshot"]["status"],
            "ineligible",
        )
        self.assertEqual(case["registerBaseline"]["expectedCandidates"], [])
        self.assertEqual(case["construction"]["notation"]["status"], "unresolved")

    def test_ives_is_a_literature_positive_the_register_baseline_recovers(self) -> None:
        case = case_by_id(load_suite(), "ives-psalm-67-opening")

        self.assertEqual(case["productExpectation"]["class"], "positive")
        self.assertEqual(
            case["productExpectation"]["primarySingleChordAlternatives"],
            ["C9/G"],
        )
        self.assertEqual(
            case["inputEligibility"]["adjacentRegisterSnapshot"]["status"],
            "eligible",
        )
        candidate = case["registerBaseline"]["expectedCandidates"][0]
        self.assertEqual(candidate["symbol"], "C|Gm")
        self.assertEqual(candidate["gapSemitones"], 2)
        self.assertEqual(candidate["sharedPitchClasses"], [7])

    def test_elektra_set_is_a_one_sounded_note_overlap_boundary(self) -> None:
        case = case_by_id(load_suite(), "strauss-elektra-chord-overlap")

        self.assertEqual(case["epistemicStatus"], "theory-derived-boundary")
        self.assertIn("one-sounded-note-overlap", case["scopeFeatures"])
        self.assertEqual(case["construction"]["notation"]["symbol"], "Db|E")
        self.assertEqual(
            [unit["midiNotes"] for unit in case["construction"]["units"]],
            [[40, 47, 56], [49, 53, 56]],
        )
        self.assertEqual(case["productExpectation"]["class"], "boundary")
        self.assertEqual(case["registerBaseline"]["expectedCandidates"], [])

    def test_herrmann_pass_supplies_a_disjoint_literature_positive(self) -> None:
        case = case_by_id(load_suite(), "herrmann-pass-first-a-flat-minor-attack")

        self.assertEqual(case["productExpectation"]["class"], "positive")
        self.assertIn("disjoint-pitch-class-layers", case["scopeFeatures"])
        self.assertEqual(
            case["construction"]["notation"]["symbol"],
            "Gm|Abm",
        )
        self.assertEqual(
            [
                candidate["symbol"]
                for candidate in case["registerBaseline"]["expectedCandidates"]
            ],
            ["Gm|G#m"],
        )

    def test_stravinsky_page_37_supplies_a_seventh_literature_positive(self) -> None:
        case = case_by_id(
            load_suite(), "stravinsky-three-movements-g-over-a-flat-seven"
        )

        self.assertEqual(case["productExpectation"]["class"], "positive")
        self.assertIn("complete-seventh-layer", case["scopeFeatures"])
        self.assertEqual(case["construction"]["notation"]["symbol"], "G|Ab7")
        candidates = case["registerBaseline"]["expectedCandidates"]
        self.assertEqual(
            [candidate["symbol"] for candidate in candidates],
            ["Gmaj7|G#", "G|G#7"],
        )
        self.assertEqual(candidates[1]["lower"]["quality"], "dominant7")
        self.assertEqual(candidates[1]["sharedPitchClasses"], [])

    def test_petrushka_is_admitted_as_a_window_not_a_false_snapshot(self) -> None:
        case = case_by_id(load_suite(), "stravinsky-petrushka-r49-arpeggios")

        self.assertEqual(case["observation"]["kind"], "frame-replay-window")
        self.assertIn("moving-arpeggiated-layers", case["scopeFeatures"])
        self.assertEqual(case["construction"]["notation"]["symbol"], "C|F#")
        self.assertEqual(case["registerBaseline"]["expectedCandidateFrames"], [])
        self.assertEqual(
            case["inputEligibility"]["adjacentRegisterSnapshot"]["status"],
            "ineligible",
        )
        self.assertEqual(
            case["inputEligibility"]["timestampedEventStream"]["status"],
            "eligible",
        )

    def test_common_sevenths_are_exercised_in_both_layer_roles(self) -> None:
        payload = load_suite()
        upper_seventh = case_by_id(payload, "synthetic-d-sharp-seven-over-e")
        lower_seventh = case_by_id(payload, "synthetic-d-over-c-major-seven")

        self.assertEqual(
            upper_seventh["registerBaseline"]["expectedCandidates"][0]["upper"][
                "quality"
            ],
            "dominant7",
        )
        self.assertEqual(
            lower_seventh["registerBaseline"]["expectedCandidates"][0]["lower"][
                "quality"
            ],
            "major7",
        )

    def test_complete_major_seventh_upper_structure_is_a_boundary(self) -> None:
        case = case_by_id(load_suite(), "synthetic-d-over-c-major-seven")

        self.assertEqual(case["construction"]["kind"], "upper-structure")
        self.assertEqual(case["productExpectation"]["class"], "boundary")
        self.assertEqual(case["productExpectation"]["expectedPolychords"], [])
        self.assertEqual(
            case["productExpectation"]["primarySingleChordAlternatives"],
            ["Cmaj13(#11)"],
        )
        self.assertEqual(
            [
                candidate["symbol"]
                for candidate in case["registerBaseline"]["expectedCandidates"]
            ],
            ["D|Cmaj7"],
        )

    def test_doubled_c_major_seventh_accompaniment_is_a_negative_guard(self) -> None:
        case = case_by_id(load_suite(), "synthetic-c-major-seven-accompaniment")

        self.assertEqual(case["construction"]["kind"], "integrated-chord")
        self.assertIn(
            "doubled-integrated-accompaniment",
            case["scopeFeatures"],
        )
        self.assertEqual(
            case["productExpectation"]["primarySingleChordAlternatives"],
            ["Cmaj7"],
        )
        self.assertEqual(case["productExpectation"]["class"], "negative-guard")
        self.assertEqual(
            [
                candidate["symbol"]
                for candidate in case["registerBaseline"]["expectedCandidates"]
            ],
            ["Em|C"],
        )
        self.assertEqual(
            case["registerBaseline"]["expectedCandidates"][0]["sharedPitchClasses"],
            [4, 7],
        )

    def test_integrated_guard_can_require_a_structural_candidate(self) -> None:
        case = case_by_id(load_suite(), "synthetic-integrated-d-six")

        self.assertEqual(case["productExpectation"]["expectedPolychords"], [])
        self.assertEqual(case["productExpectation"]["class"], "negative-guard")
        self.assertEqual(
            [
                candidate["symbol"]
                for candidate in case["registerBaseline"]["expectedCandidates"]
            ],
            ["Bm|D"],
        )

    def test_replay_case_references_the_exact_layered_frame(self) -> None:
        case = case_by_id(load_suite(), "synthetic-layered-c-over-g-minor")

        self.assertEqual(
            case["observation"],
            {
                "kind": "frame-replay",
                "fixtureId": "two-register-held-cohorts",
                "afterEventIndex": 5,
                "spelledNotes": ["G2", "Bb2", "D3", "C4", "E4", "G4"],
            },
        )
        self.assertEqual(
            case["registerBaseline"]["expectedCandidates"][0]["sharedPitchClasses"],
            [7],
        )

    def test_window_baseline_evaluates_each_frame_without_verticalizing_union(
        self,
    ) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-layered-c-over-g-minor")
        final_candidates = case["registerBaseline"]["expectedCandidates"]
        case["observation"] = {
            "kind": "frame-replay-window",
            "fixtureId": "two-register-held-cohorts",
            "firstEventIndex": 0,
            "lastEventIndex": 5,
            "spelledNotes": ["G2", "Bb2", "D3", "C4", "E4", "G4"],
        }
        case["registerBaseline"] = {
            "expectedCandidateFrames": [
                {
                    "afterEventIndex": 5,
                    "timestampMs": 400,
                    "candidates": final_candidates,
                }
            ]
        }

        subject.validate_suite_payload(payload)

    def test_moving_scope_rejects_a_static_complete_frame(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-layered-c-over-g-minor")
        case["scopeFeatures"].append("moving-arpeggiated-layers")
        case["observation"] = {
            "kind": "frame-replay-window",
            "fixtureId": "two-register-held-cohorts",
            "firstEventIndex": 0,
            "lastEventIndex": 5,
            "spelledNotes": ["G2", "Bb2", "D3", "C4", "E4", "G4"],
        }
        case["registerBaseline"] = {
            "expectedCandidateFrames": [
                {
                    "afterEventIndex": 5,
                    "timestampMs": 400,
                    "candidates": case["registerBaseline"]["expectedCandidates"],
                }
            ]
        }

        with self.assertRaisesRegex(ValueError, "contains both complete units"):
            subject.validate_suite_payload(payload)

    def test_resolved_construction_can_remain_a_product_boundary(self) -> None:
        case = case_by_id(load_suite(), "stravinsky-shrovetide-second-attack")

        self.assertEqual(case["construction"]["notation"]["symbol"], "Gm|Bb")
        self.assertEqual(case["productExpectation"]["class"], "boundary")
        self.assertEqual(case["productExpectation"]["expectedPolychords"], [])
        self.assertEqual(
            case["registerBaseline"]["expectedCandidates"][0]["symbol"],
            "Gm|A#",
        )

    def test_score_enharmonics_resolve_across_octave_boundaries(self) -> None:
        self.assertEqual(subject.spelled_note_to_midi("Fb2", "note"), 40)
        self.assertEqual(subject.spelled_note_to_midi("Cb3", "note"), 47)
        self.assertEqual(subject.spelled_note_to_midi("B#2", "note"), 48)
        self.assertEqual(subject.spelled_note_to_midi("F##3", "note"), 55)

    def test_changed_register_expectation_is_rejected(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-integrated-d-six")
        case["registerBaseline"]["expectedCandidates"] = []

        with self.assertRaisesRegex(ValueError, "does not match generation"):
            subject.validate_suite_payload(payload)

    def test_false_disjoint_scope_claim_is_rejected(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "ives-psalm-67-opening")
        case["scopeFeatures"].append("disjoint-pitch-class-layers")

        with self.assertRaisesRegex(ValueError, "claims disjoint.*overlap"):
            subject.validate_suite_payload(payload)

    def test_reused_note_without_overlap_scope_is_rejected(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "strauss-elektra-chord-overlap")
        case["scopeFeatures"].remove("one-sounded-note-overlap")

        with self.assertRaisesRegex(ValueError, "reuse MIDI notes"):
            subject.validate_suite_payload(payload)

    def test_overlap_scope_without_a_reused_note_is_rejected(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "strauss-elektra-chord-overlap")
        case["observation"]["soundingMidiNotes"] = [40, 47, 49, 53, 56, 68]
        case["observation"]["spelledNotes"] = [
            "E2",
            "B2",
            "Db3",
            "F3",
            "Ab3",
            "G#4",
        ]
        case["construction"]["units"][0]["midiNotes"] = [40, 47, 68]
        case["construction"]["units"][0]["spelledNotes"] = ["E2", "B2", "G#4"]

        with self.assertRaisesRegex(ValueError, "reuses 0 notes"):
            subject.validate_suite_payload(payload)

    def test_overlap_scope_rejects_more_than_one_reused_note(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "strauss-elektra-chord-overlap")
        case["observation"]["soundingMidiNotes"] = [40, 49, 53, 56]
        case["observation"]["spelledNotes"] = ["E2", "Db3", "F3", "Ab3"]
        case["construction"]["units"][0]["midiNotes"] = [40, 49, 56]
        case["construction"]["units"][0]["spelledNotes"] = ["E2", "C#3", "G#3"]
        case["construction"]["units"][0]["pitchClasses"] = [1, 4, 8]
        case["construction"]["units"][0]["rootPc"] = 1
        case["construction"]["units"][0]["quality"] = "minor"

        with self.assertRaisesRegex(ValueError, "reuses 2 notes"):
            subject.validate_suite_payload(payload)

    def test_overlap_scope_cannot_be_a_v0_positive(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "strauss-elektra-chord-overlap")
        case["productExpectation"]["class"] = "positive"
        case["productExpectation"]["expectedPolychords"] = [
            {
                "unitIds": ["lower-e-major", "upper-d-flat-major"],
                "symbol": "Db|E",
            }
        ]

        with self.assertRaisesRegex(ValueError, "must keep.*overlap.*boundary"):
            subject.validate_suite_payload(payload)

    def test_overlap_scope_cannot_be_a_negative_guard(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "strauss-elektra-chord-overlap")
        case["productExpectation"]["class"] = "negative-guard"

        with self.assertRaisesRegex(ValueError, "must keep.*overlap.*boundary"):
            subject.validate_suite_payload(payload)

    def test_overlap_scope_requires_a_polychord_construction(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-integrated-d-six")
        case["scopeFeatures"].append("one-sounded-note-overlap")

        with self.assertRaisesRegex(ValueError, "non-polychord construction"):
            subject.validate_suite_payload(payload)

    def test_doubled_accompaniment_scope_requires_a_register_candidate(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-same-root-c-major-registers")
        case["scopeFeatures"].append("doubled-integrated-accompaniment")

        with self.assertRaisesRegex(ValueError, "shared-tone register candidate"):
            subject.validate_suite_payload(payload)

    def test_doubled_accompaniment_scope_requires_two_doubled_pitch_classes(
        self,
    ) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-c-major-seven-accompaniment")
        case["observation"]["soundingMidiNotes"] = [48, 52, 55, 64, 71]
        case["observation"]["spelledNotes"] = ["C3", "E3", "G3", "E4", "B4"]
        unit = case["construction"]["units"][0]
        unit["midiNotes"] = [48, 52, 55, 64, 71]
        unit["spelledNotes"] = ["C3", "E3", "G3", "E4", "B4"]

        with self.assertRaisesRegex(ValueError, "without two doubled pitch classes"):
            subject.validate_suite_payload(payload)

    def test_doubled_accompaniment_scope_requires_a_negative_guard(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-c-major-seven-accompaniment")
        case["productExpectation"]["class"] = "boundary"

        with self.assertRaisesRegex(ValueError, "remain a negative guard"):
            subject.validate_suite_payload(payload)

    def test_doubled_accompaniment_scope_requires_integrated_construction(
        self,
    ) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-layered-c-over-g-minor")
        case["scopeFeatures"].append("doubled-integrated-accompaniment")

        with self.assertRaisesRegex(ValueError, "non-integrated construction"):
            subject.validate_suite_payload(payload)

    def test_false_multiple_identity_scope_claim_is_rejected(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "herrmann-pass-first-a-flat-minor-attack")
        case["scopeFeatures"].append("multiple-structural-identities")

        with self.assertRaisesRegex(ValueError, "claims multiple structural"):
            subject.validate_suite_payload(payload)

    def test_unresolved_notation_cannot_invent_a_symbol(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "stravinsky-augurs-r13")
        case["productExpectation"]["expectedPolychords"][0]["symbol"] = "Fb|Eb7"

        with self.assertRaisesRegex(ValueError, "cannot invent a symbol"):
            subject.validate_suite_payload(payload)

    def test_spelling_mismatch_is_rejected(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-separated-f-sharp-over-c")
        case["observation"]["spelledNotes"][0] = "C4"

        with self.assertRaisesRegex(ValueError, "does not match MIDI notes"):
            subject.validate_suite_payload(payload)

    def test_unit_root_must_be_present_in_its_pitch_classes(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-separated-f-sharp-over-c")
        case["construction"]["units"][1]["rootPc"] = 5

        with self.assertRaisesRegex(ValueError, "rootPc must be present"):
            subject.validate_suite_payload(payload)

    def test_unit_quality_must_match_its_pitch_classes(self) -> None:
        payload = load_suite()
        case = case_by_id(payload, "synthetic-separated-f-sharp-over-c")
        case["construction"]["units"][1]["quality"] = "minor"

        with self.assertRaisesRegex(ValueError, "quality does not match"):
            subject.validate_suite_payload(payload)

    def test_changed_dependency_pin_is_rejected(self) -> None:
        payload = deepcopy(load_suite())
        payload["dependencies"]["outputContract"]["sha256"] = "0" * 64

        with self.assertRaisesRegex(ValueError, "digest does not match"):
            subject.validate_suite_payload(payload)


if __name__ == "__main__":
    unittest.main()
