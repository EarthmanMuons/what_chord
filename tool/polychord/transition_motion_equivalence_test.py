"""Controls for the Python/Dart transition/motion equivalence harness."""

from __future__ import annotations

import unittest

import transition_motion_equivalence as subject


class TransitionMotionEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.cases = subject.equivalence_cases()

    def test_enumerates_every_ordered_frame_pair(self) -> None:
        self.assertEqual(len(self.cases), 9)
        self.assertEqual(len({case["id"] for case in self.cases}), 9)
        self.assertEqual(sum(len(case["windows"]) for case in self.cases), 930)

    def test_each_window_has_complete_transition_and_motion_shapes(self) -> None:
        expected_fields = {
            "sourceAfterEventIndex",
            "targetAfterEventIndex",
            "window",
            "sourceCandidates",
            "targetCandidates",
            "candidateTransitions",
            "candidateInterpretations",
        }
        for case in self.cases:
            for window in case["windows"]:
                with self.subTest(
                    fixture=case["id"],
                    source=window["sourceAfterEventIndex"],
                    target=window["targetAfterEventIndex"],
                ):
                    self.assertEqual(set(window), expected_fields)
                    self.assertEqual(
                        window["window"]["transitionEventCount"],
                        window["targetAfterEventIndex"]
                        - window["sourceAfterEventIndex"],
                    )
                    self.assertEqual(
                        len(window["candidateTransitions"]),
                        len(window["sourceCandidates"])
                        * len(window["targetCandidates"]),
                    )
                    self.assertEqual(
                        len(window["candidateInterpretations"]),
                        len(window["candidateTransitions"]),
                    )

    def test_inner_motion_control_preserves_both_unranked_hypotheses(self) -> None:
        case = next(
            case for case in self.cases if case["id"] == "two-register-inner-motion"
        )
        window = next(
            window
            for window in case["windows"]
            if window["sourceAfterEventIndex"] == 5
            and window["targetAfterEventIndex"] == 9
        )
        interpretations = window["candidateInterpretations"][0][
            "hypothesisInterpretations"
        ]

        self.assertEqual(
            [item["hypothesisId"] for item in interpretations],
            ["register-role-preserving", "register-role-exchanging"],
        )
        self.assertEqual(
            [item["motionSupport"] for item in interpretations],
            ["neutral", "neutral"],
        )


if __name__ == "__main__":
    unittest.main()
