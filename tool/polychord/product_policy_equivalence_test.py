"""Controls for the Python/Dart product-policy equivalence harness."""

from __future__ import annotations

import unittest

import product_policy
import product_policy_equivalence as subject


class ProductPolicyEquivalenceTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.sessions = subject.session_cases()
        cls.controls = list(subject.structural_controls())

    def test_sessions_cover_every_frozen_action_without_expectations(self) -> None:
        self.assertEqual(len(self.sessions), 20)
        self.assertEqual(
            sum(len(case["observations"]) for case in self.sessions),
            202,
        )
        for case in self.sessions:
            request = case["request"]
            self.assertEqual(request["mode"], "session")
            self.assertNotIn("expectedCandidates", request)
            for action in request["actions"]:
                self.assertNotIn("checkpoint", action)
                self.assertEqual(
                    set(action),
                    {"id", "type", "timestampMs", "eventIndex", "displayable"},
                )

    def test_python_sessions_emit_the_complete_versioned_output(self) -> None:
        observations = [
            item["observation"]
            for case in self.sessions
            for item in case["observations"]
        ]

        self.assertTrue(
            all(
                value["schema"] == product_policy.OUTPUT_SCHEMA
                for value in observations
            )
        )
        self.assertTrue(
            all(
                value["versionIds"] == product_policy.VERSION_IDS
                for value in observations
            )
        )
        self.assertTrue(
            any(
                value["display"]["transition"] == "appearance" for value in observations
            )
        )
        self.assertTrue(
            any(
                value["display"]["reasonCode"] == "tracker-reset"
                for value in observations
            )
        )

    def test_structural_controls_cover_the_complete_symmetric_matrix(self) -> None:
        self.assertEqual(len(self.controls), 3300)
        self.assertEqual(len({case["id"] for case in self.controls}), 3300)
        self.assertTrue(
            all(case["request"]["mode"] == "decision" for case in self.controls)
        )
        self.assertTrue(
            all(
                len(case["decision"]["stageSurvivors"]["positiveSupport"]) <= 1
                for case in self.controls
            )
        )

    def test_stderr_filter_accepts_only_the_known_dart_hook_notice(self) -> None:
        self.assertEqual(subject._unexpected_stderr("Running build hooks...\n"), "")
        self.assertEqual(subject._unexpected_stderr("unexpected"), "unexpected")


if __name__ == "__main__":
    unittest.main()
