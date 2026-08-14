"""Controls for the expectation-free product prediction projection."""

from __future__ import annotations

import unittest

import product_prediction_projection as subject


def _candidate() -> dict:
    return {
        "splitAfterIndex": 2,
        "lowerTopMidi": 55,
        "upperBottomMidi": 66,
        "gapSemitones": 11,
        "lower": {
            "rootPc": 0,
            "quality": "major",
            "midiNotes": [48, 52, 55],
            "pitchClasses": [0, 4, 7],
        },
        "upper": {
            "rootPc": 6,
            "quality": "major",
            "midiNotes": [66, 70, 73],
            "pitchClasses": [1, 6, 10],
        },
        "sharedPitchClasses": [],
        "symbol": "F#|C",
    }


def _raw_observation() -> dict:
    candidate = _candidate()
    instances = [
        {"midiNote": note, "onsetEventIndex": index}
        for index, note in enumerate([48, 52, 55, 66, 70, 73])
    ]
    frame = {
        "trackerEpoch": 0,
        "afterEventIndex": 5,
        "timestampMs": 80,
        "pressedMidiNotes": [48, 52, 55, 66, 70, 73],
        "sustainedMidiNotes": [],
        "soundingMidiNotes": [48, 52, 55, 66, 70, 73],
        "pedalDown": False,
        "onsetNotes": [
            {
                "midiNote": item["midiNote"],
                "soundingState": "pressed",
                "onsetEventIndex": item["onsetEventIndex"],
                "onsetTimestampMs": 0 if item["midiNote"] < 60 else 80,
                "onsetVelocity": 96,
            }
            for item in instances
        ],
    }
    binding = {
        "trackerEpoch": 0,
        "candidate": candidate,
        "targetInstances": instances,
        "availability": "complete",
    }
    cue = {
        "targetBinding": binding,
        "availability": "complete",
        "support": "positive",
        "reasonCodes": ["separate-coherent-onset-cohorts"],
        "diagnostic": {
            "onsetEvidence": {
                "lower": {
                    "earliestKnownOnsetMs": 0,
                    "latestKnownOnsetMs": 0,
                    "knownOnsetSpanMs": 0,
                },
                "upper": {
                    "earliestKnownOnsetMs": 80,
                    "latestKnownOnsetMs": 80,
                    "knownOnsetSpanMs": 0,
                },
            },
            "onsetInterpretation": {
                "lowerWithinCohortSpanMaximum": True,
                "upperWithinCohortSpanMaximum": True,
                "layerOnsetOrder": "lower-then-upper",
                "betweenLayerOnsetIntervalGapMs": 80,
            },
        },
    }
    key = {
        "trackerEpoch": 0,
        "candidate": candidate,
        "targetInstances": instances,
    }
    decision = {
        "stageSurvivors": {
            "structural": [candidate],
            "assignment": [candidate],
            "integrated": [candidate],
            "positiveSupport": [candidate],
        },
        "candidateTraces": [
            {
                "candidate": candidate,
                "identityAssignmentCount": 1,
                "integratedTertian": {
                    "compact": False,
                    "rootedNinth": False,
                    "rootedSeventhExtension": False,
                },
                "aggregateSupport": "positive",
                "removedAt": None,
                "selected": True,
            }
        ],
        "selected": candidate,
        "reasonCode": None,
    }
    return {
        "observationTimestampMs": 80,
        "frame": frame,
        "candidates": [candidate],
        "candidateRecords": [cue],
        "rawDecision": decision,
        "authorization": {"key": key, "reasonCode": None},
        "display": {
            "state": "pending",
            "transition": "pending",
            "key": key,
            "deadlineMs": 280,
            "reasonCode": "awaiting-display-stability",
        },
    }


class ProductPredictionProjectionTest(unittest.TestCase):
    def test_suite_requests_strip_every_expected_value_before_dart(self) -> None:
        cases = subject.session_requests()

        self.assertEqual(len(cases), 20)
        self.assertEqual(
            sum(len(case["request"]["actions"]) for case in cases),
            202,
        )
        for case in cases:
            request_text = subject.canonical_json(case["request"])
            self.assertNotIn("checkpoint", request_text)
            self.assertNotIn("expected", request_text.lower())
            self.assertNotIn("construction", request_text.lower())

    def test_projection_assigns_candidate_ids_from_output_not_answer_data(self) -> None:
        construction = {
            "class": "positive",
            "candidateId": "candidate-1",
            "reason": "suite-owned metadata",
        }

        value = subject.project_observation(
            _raw_observation(),
            construction=construction,
            identifiers={},
        )

        self.assertIs(value["construction"], construction)
        self.assertEqual(value["candidates"], ["candidate-1"])
        self.assertEqual(value["cueRecords"][0]["candidateId"], "candidate-1")
        self.assertEqual(value["authorization"]["key"]["candidateId"], "candidate-1")
        self.assertEqual(value["display"]["deadlineMs"], 280)
        self.assertNotIn("onsetTimestampMs", value["frame"]["onsetNotes"][0])

    def test_case_projection_retains_only_declared_checkpoint_actions(self) -> None:
        raw = _raw_observation()
        case = {
            "caseId": "synthetic",
            "construction": {
                "class": "positive",
                "candidateId": "candidate-1",
                "reason": "metadata",
            },
            "checkpointActionIds": ["second"],
            "request": {
                "actions": [
                    {"id": "first"},
                    {"id": "second"},
                ]
            },
        }

        value = subject.project_case(
            case,
            [
                {"actionId": "first", "observation": raw},
                {"actionId": "second", "observation": raw},
            ],
        )

        self.assertEqual(value["caseId"], "synthetic")
        self.assertEqual(
            [checkpoint["actionId"] for checkpoint in value["checkpoints"]],
            ["second"],
        )


if __name__ == "__main__":
    unittest.main()
