"""Unit tests for the preregistered polychord motion-exposure census."""

from __future__ import annotations

import unittest
from copy import deepcopy
from pathlib import Path

import frame_replay
import motion_exposure_census as subject

REPO_ROOT = Path(__file__).parents[2]
FIXTURE_DIR = REPO_ROOT / "research/polychord/data/frame-replay"


def fixture(name: str) -> dict:
    return frame_replay.load_json(FIXTURE_DIR / name)


class MotionExposureCensusTest(unittest.TestCase):
    def test_measurement_identity_and_endpoint_policy_are_fixed(self) -> None:
        self.assertEqual(subject.REPORT_SCHEMA, "polychord-motion-exposure-census/1")
        self.assertEqual(
            subject.MEASUREMENT_ID,
            "pop909-sample-accompaniment-channel-blind-"
            "timestamp-terminal-rigid-motion/1",
        )
        self.assertNotIn("threshold", subject.MEASUREMENT_ID)

    def test_distribution_summary_uses_nearest_rank(self) -> None:
        self.assertEqual(
            subject.distribution_summary([4, 1, 3, 2]),
            {
                "count": 4,
                "minimum": 1,
                "medianNearestRank": 2,
                "p90NearestRank": 4,
                "maximum": 4,
            },
        )
        self.assertEqual(subject.distribution_summary([])["count"], 0)

    def test_terminal_frames_are_last_at_each_distinct_timestamp(self) -> None:
        records = subject.terminal_frame_records(
            fixture("two-register-contrary-motion.json")
        )

        self.assertEqual([item["timestampMs"] for item in records], [0, 100])
        self.assertEqual([item["lastEventIndex"] for item in records], [5, 17])
        self.assertEqual([item["eventCount"] for item in records], [6, 12])

    def test_contrary_control_is_one_positive_endpoint_transition(self) -> None:
        metrics, details = subject.analyze_fixture(
            fixture("two-register-contrary-motion.json")
        )

        self.assertEqual(metrics["endpointFrames"]["rawEventFrames"], 18)
        self.assertEqual(metrics["endpointFrames"]["timestampTerminal"], 2)
        self.assertEqual(
            metrics["endpointFrames"]["excludedSameTimestampNonterminal"],
            16,
        )
        self.assertEqual(metrics["observationTransitions"]["candidateToCandidate"], 1)
        self.assertEqual(
            metrics["observationTransitions"]["withPositiveMotionSupport"], 1
        )
        self.assertEqual(metrics["candidateInstances"]["positiveHypotheses"], 1)
        window = details["candidateEndpointWindows"][0]
        self.assertEqual(window["window"]["transitionEventCount"], 12)
        self.assertEqual(window["window"]["interveningFrameCount"], 11)
        self.assertEqual(
            [step["event"]["index"] for step in window["window"]["transitionSteps"]],
            list(range(6, 18)),
        )
        self.assertEqual(window["positiveTargetCandidateIndices"], [0])
        self.assertEqual(
            metrics["elapsedMsDistributions"]["positiveMotionSupport"][
                "medianNearestRank"
            ],
            100,
        )
        self.assertEqual(
            metrics["countDistributions"][
                "hypothesisInterpretationsPerEvaluableWindow"
            ]["p90NearestRank"],
            2,
        )

    def test_positive_duration_is_target_terminal_dwell(self) -> None:
        metrics, _ = subject.analyze_fixture(
            fixture("two-register-contrary-motion.json")
        )

        self.assertEqual(metrics["terminalDwellMs"]["withCandidates"], 200)
        self.assertEqual(
            metrics["terminalDwellMs"]["withMotionEvaluablePredecessor"], 100
        )
        self.assertEqual(metrics["terminalDwellMs"]["withPositiveMotionSupport"], 100)

    def test_positive_duration_is_not_elapsed_transition_time(self) -> None:
        payload = fixture("two-register-contrary-motion.json")
        changed = deepcopy(payload)
        changed["endTimestampMs"] = 350

        metrics, details = subject.analyze_fixture(changed)

        self.assertEqual(details["candidateEndpointWindows"][0]["targetDwellMs"], 250)
        self.assertEqual(
            details["candidateEndpointWindows"][0]["window"]["elapsedMs"], 100
        )
        self.assertEqual(metrics["terminalDwellMs"]["withPositiveMotionSupport"], 250)

    def test_positive_duration_noncandidate_frame_breaks_the_chain(self) -> None:
        metrics, details = subject.analyze_fixture(
            fixture("two-register-inner-motion.json")
        )

        transitions = metrics["observationTransitions"]
        self.assertEqual(transitions["candidateExit"], 1)
        self.assertEqual(transitions["candidateEntry"], 1)
        self.assertEqual(transitions["candidateToCandidate"], 0)
        self.assertEqual(transitions["withPositiveMotionSupport"], 0)
        self.assertEqual(
            [item["classification"] for item in details["candidateEndpointWindows"]],
            ["candidate-exit", "candidate-entry"],
        )

    def test_same_sounding_terminal_states_remain_static_and_neutral(self) -> None:
        metrics, _ = subject.analyze_fixture(fixture("two-register-pedal-history.json"))

        transitions = metrics["observationTransitions"]
        self.assertEqual(transitions["candidateToCandidateSameSoundingSet"], 5)
        self.assertEqual(transitions["pitchChangingCandidateToCandidate"], 0)
        self.assertEqual(transitions["withPositiveMotionSupport"], 0)
        self.assertEqual(
            metrics["candidateInstances"]["neutralReasonCounts"][
                "both-layer-translations-static"
            ],
            5,
        )

    def test_nonterminal_candidate_frames_are_counted_but_not_endpoints(self) -> None:
        metrics, details = subject.analyze_fixture(
            fixture("two-register-pedal-history.json")
        )

        endpoints = metrics["endpointFrames"]
        self.assertEqual(endpoints["rawEventFramesWithCandidates"], 10)
        self.assertEqual(endpoints["timestampTerminalWithCandidates"], 6)
        self.assertEqual(endpoints["excludedSameTimestampNonterminalWithCandidates"], 4)
        self.assertEqual(
            len(details["excludedSameTimestampCandidateFrames"]),
            4,
        )

    def test_initial_candidate_has_no_invented_predecessor(self) -> None:
        metrics, details = subject.analyze_fixture(
            fixture("two-register-contrary-motion.json")
        )

        instances = metrics["candidateInstances"]
        self.assertEqual(instances["timestampTerminalTotal"], 2)
        self.assertEqual(instances["motionEvaluable"], 1)
        self.assertEqual(instances["motionUnavailableWithoutCandidatePredecessor"], 1)
        self.assertEqual(len(details["initialCandidateEndpoints"]), 1)

    def test_empty_event_stream_has_no_endpoints_or_distributions(self) -> None:
        payload = {
            "schema": frame_replay.FIXTURE_SCHEMA,
            "id": "empty",
            "description": "An empty normalized stream.",
            "timeBase": "milliseconds",
            "initialState": {
                "pressedMidiNotes": [],
                "sustainedMidiNotes": [],
                "pedalDown": False,
            },
            "events": [],
            "frames": [],
            "endTimestampMs": 0,
        }

        metrics, details = subject.analyze_fixture(payload)

        self.assertEqual(metrics["endpointFrames"]["timestampTerminal"], 0)
        self.assertEqual(metrics["observationTransitions"]["total"], 0)
        self.assertEqual(
            metrics["elapsedMsDistributions"]["observationTransitions"]["count"],
            0,
        )
        self.assertFalse(any(key.startswith("_") for key in metrics))
        self.assertTrue(all(not values for values in details.values()))

    def test_piece_metrics_add_without_adding_derived_shares(self) -> None:
        first_piece, _ = subject.analyze_fixture(
            fixture("two-register-contrary-motion.json"),
            finalize=False,
        )
        second_piece, _ = subject.analyze_fixture(
            fixture("two-register-contrary-motion.json"),
            finalize=False,
        )
        total = subject.empty_metrics()

        subject.add_metrics(total, first_piece)
        subject.add_metrics(total, second_piece)
        finalized = subject.finalize_metrics(total)

        self.assertEqual(finalized["endpointFrames"]["timestampTerminal"], 4)
        self.assertEqual(
            finalized["observationTransitions"]["withPositiveMotionSupport"], 2
        )
        self.assertEqual(finalized["candidateInstances"]["positiveHypotheses"], 2)
        self.assertEqual(
            finalized["endpointFrames"]["positiveShareOfMotionEvaluableTerminalFrames"],
            1.0,
        )
        self.assertEqual(
            finalized["elapsedMsDistributions"]["positiveMotionSupport"]["count"],
            2,
        )

    def test_output_must_remain_below_build(self) -> None:
        self.assertTrue(
            subject.output_is_allowed(
                REPO_ROOT / "build/polychord/motion-exposure.json"
            )
        )
        self.assertFalse(subject.output_is_allowed(REPO_ROOT / "motion.json"))
        self.assertFalse(subject.output_is_allowed(REPO_ROOT / "build"))


if __name__ == "__main__":
    unittest.main()
