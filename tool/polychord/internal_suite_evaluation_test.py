"""Controls for the preregistered polychord suite-evaluation harness."""

from __future__ import annotations

import unittest
from unittest import mock

import internal_suite_evaluation as subject
import register_selector


def selected_decision(selector_id: str) -> dict:
    decision = register_selector.decision_document(
        [48, 52, 55, 66, 70, 73],
        selector_id=selector_id,
    )
    assert decision["selected"] is not None
    return decision


class InternalSuiteEvaluationTest(unittest.TestCase):
    def test_profile_filenames_cover_every_preregistered_selector(self) -> None:
        self.assertEqual(
            subject.SELECTOR_IDS,
            tuple(register_selector.SELECTOR_PROFILES),
        )
        self.assertEqual(len(set(subject.SELECTOR_FILES.values())), 4)

    def test_case_frames_preserves_snapshot_notes(self) -> None:
        case = {
            "observation": {
                "kind": "snapshot",
                "soundingMidiNotes": [48, 52, 55],
            }
        }

        self.assertEqual(
            subject.case_frames(case, {}),
            [
                {
                    "frameId": "snapshot",
                    "afterEventIndex": None,
                    "timestampMs": None,
                    "midiNotes": [48, 52, 55],
                }
            ],
        )

    def test_case_frames_selects_exact_replay_window(self) -> None:
        case = {
            "observation": {
                "kind": "frame-replay-window",
                "fixtureId": "control",
                "firstEventIndex": 1,
                "lastEventIndex": 2,
            }
        }
        fixtures = {
            "control": {
                "frames": [
                    {
                        "afterEventIndex": 0,
                        "timestampMs": 10,
                        "soundingMidiNotes": [48],
                    },
                    {
                        "afterEventIndex": 1,
                        "timestampMs": 20,
                        "soundingMidiNotes": [48, 52],
                    },
                    {
                        "afterEventIndex": 2,
                        "timestampMs": 30,
                        "soundingMidiNotes": [48, 52, 55],
                    },
                ]
            }
        }

        self.assertEqual(
            subject.case_frames(case, fixtures),
            [
                {
                    "frameId": "event-1",
                    "afterEventIndex": 1,
                    "timestampMs": 20,
                    "midiNotes": [48, 52],
                },
                {
                    "frameId": "event-2",
                    "afterEventIndex": 2,
                    "timestampMs": 30,
                    "midiNotes": [48, 52, 55],
                },
            ],
        )

    def test_prediction_candidate_removes_selector_diagnostics(self) -> None:
        decision = selected_decision(register_selector.FULL_SELECTOR_ID)

        self.assertEqual(
            subject.prediction_candidate(decision["selected"]),
            {
                "identity": {
                    "upper": {"rootPc": 6, "quality": "major"},
                    "lower": {"rootPc": 0, "quality": "major"},
                },
                "upperMidiNotes": [66, 70, 73],
                "lowerMidiNotes": [48, 52, 55],
            },
        )

    def test_window_has_no_synthetic_aggregate_snapshot(self) -> None:
        decision = selected_decision(register_selector.FULL_SELECTOR_ID)

        self.assertEqual(
            subject.case_prediction("frame-replay-window", [decision, decision]),
            {
                "selected": None,
                "reasonCodes": ["missing-register-evidence"],
            },
        )

    def test_snapshot_prediction_retains_selector_abstention(self) -> None:
        decision = register_selector.decision_document([60, 64, 67])

        self.assertEqual(
            subject.case_prediction("snapshot", [decision]),
            {
                "selected": None,
                "reasonCodes": ["no-structural-candidate"],
            },
        )

    def test_evaluation_compares_every_frame_and_profile(self) -> None:
        suite = {
            "cases": [
                {
                    "id": "selected",
                    "observation": {"kind": "snapshot"},
                },
                {
                    "id": "abstained",
                    "observation": {"kind": "snapshot"},
                },
            ]
        }
        frames = [
            {
                "id": "selected/snapshot",
                "caseId": "selected",
                "observationKind": "snapshot",
                "frameId": "snapshot",
                "afterEventIndex": None,
                "timestampMs": None,
                "midiNotes": [48, 52, 55, 66, 70, 73],
            },
            {
                "id": "abstained/snapshot",
                "caseId": "abstained",
                "observationKind": "snapshot",
                "frameId": "snapshot",
                "afterEventIndex": None,
                "timestampMs": None,
                "midiNotes": [60, 64, 67],
            },
        ]
        dart = {
            frame["id"]: {
                selector_id: register_selector.decision_document(
                    frame["midiNotes"], selector_id=selector_id
                )
                for selector_id in subject.SELECTOR_IDS
            }
            for frame in frames
        }

        with mock.patch.object(subject, "dart_decisions", return_value=dart):
            predictions, diagnostics = subject.evaluate_decisions(suite, frames)

        self.assertEqual(diagnostics["frameCount"], 2)
        self.assertEqual(diagnostics["decisionComparisonCount"], 8)
        self.assertEqual(diagnostics["mismatchCount"], 0)
        self.assertEqual(set(predictions), set(subject.SELECTOR_IDS))
        self.assertTrue(
            all(
                len(profile_predictions) == 2
                for profile_predictions in predictions.values()
            )
        )

    def test_evaluation_rejects_one_python_dart_difference(self) -> None:
        suite = {
            "cases": [
                {
                    "id": "control",
                    "observation": {"kind": "snapshot"},
                }
            ]
        }
        frames = [
            {
                "id": "control/snapshot",
                "caseId": "control",
                "observationKind": "snapshot",
                "frameId": "snapshot",
                "afterEventIndex": None,
                "timestampMs": None,
                "midiNotes": [60, 64, 67],
            }
        ]
        dart = {
            "control/snapshot": {
                selector_id: register_selector.decision_document(
                    [60, 64, 67], selector_id=selector_id
                )
                for selector_id in subject.SELECTOR_IDS
            }
        }
        dart["control/snapshot"][register_selector.FULL_SELECTOR_ID]["reasonCodes"] = [
            "not-selected-by-policy"
        ]

        with (
            mock.patch.object(subject, "dart_decisions", return_value=dart),
            self.assertRaisesRegex(ValueError, "Python/Dart decision mismatch"),
        ):
            subject.evaluate_decisions(suite, frames)


if __name__ == "__main__":
    unittest.main()
